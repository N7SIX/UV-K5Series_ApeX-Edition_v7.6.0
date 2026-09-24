# RX Path Audit — Simplex & Repeater Operation (ApeX Edition)

> **Auditor:** Senior embedded firmware review (static analysis + compile verification)
> **Date:** 2026-09-24
> **Scope:** `radio/`, `app/app.c`, `app/main.c`, `app/menu.c`, `ui/main.c`, `core/settings.c`, `driver/bk4819.c`
> **Target:** Quansheng UV-K5/K5(8)/K6 (DP32G030, Cortex-M0, 64 KB flash / 8 KB RAM)
> **Build used for reference:** ApeX defaults — `ENABLE_FEAT_N7SIX=1`, `ENABLE_WIDE_RX=0`,
> `ENABLE_TX_WHEN_AM=0`, `ENABLE_AM_FIX=0`, `SQL_TONE=550` (see `Makefile:24-32,120,350`)
> **Method:** path tracing of every runtime touch of `freq_config_RX/TX`, `TX_OFFSET_FREQUENCY`,
> squelch/tone state, plus a compile check of the two translation units at the centre of the RX
> path with the project toolchain (`arm-none-eabi-gcc 14.3`, `-Wall -Wextra -Werror -std=c2x`).

---

## 1. Executive summary

The RX implementation is the well-proven DualTachyon/Egzumer lineage: frequency, squelch,
tone and modulation are derived from a per-VFO structure, pushed into the BK4819 by
`RADIO_SetupRegisters()`, and the receive state machine is driven by BK4819 interrupt bits
(`SQ_FOUND/LOST`, `CTCSS/CDCSS found/lost`, `CxCSS_TAIL`, DTMF, VOX).

**Simplex operation (offset = 0)** is implemented correctly and consistently:
`RADIO_ApplyOffset()` is idempotent (it *assigns* `freq_config_TX = f(freq_config_RX, offset, direction)`),
so the TX frequency can never drift even though the function is called from several places
(channel reload, frequency scan, copy-channel-to-VFO).

**Repeater operation (offset ≠ 0)** is architecturally correct — RX always comes from
`pRX`, TX always from `pTX`, so the offset, the frequency-reverse feature (F+8) and the
"Remove Offset" rescue action all compose correctly, and RX CTCSS/DCS decode on a repeater's
output tone works as intended. However, the *offset value itself is not validated anywhere in
the config path*, and two independent defects in `RADIO_ConfigureChannel()`/the VFO edit paths
can leave the radio in a state where **RX demodulation is wrong (AM)** or **TX happens on the
wrong frequency** and/or is silently refused.

### Risk summary

| ID | Severity | Area | Finding |
|----|----------|------|---------|
| RX-1 | **High** | RX config | `Modulation` is derived from the *previous* RX frequency → a memory channel loaded right after tuning in the airband (108–137 MHz) is configured as **AM**, which ruins RX and (with `ENABLE_TX_WHEN_AM=0`) blocks TX. The wrong value is **persisted to EEPROM** by the next full channel save (always, for VFO/frequency channels). |
| RX-2 | **Medium** | TX derivation | `RADIO_ApplyOffset()` has no bounds/underflow guard, while the UI accepts offsets up to ±999.999 MHz (manual says ±10 MHz). A negative (SUB) offset larger than the RX frequency wraps the `uint32_t` TX frequency (e.g. 42.09 GHz) → TX permanently refused with a misleading indication; the power-calibration band lookup then uses the wrong band row. |
| RX-3 | **Medium** | TX derivation | Stepping/entering a VFO frequency updates only `freq_config_RX.Frequency` and calls `BK4819_SetFrequency()` directly; the TX frequency is refreshed only by the deferred (up to 500 ms) save + reconfigure cycle → tapping a new frequency and keying up in that window transmits on the **previous** frequency (simplex *and* repeater). |
| RX-4 | Medium-Low | Config persistence | The airband sanitisation `TX_OFFSET_FREQUENCY_DIRECTION = OFF` mutates the live config object, which `SETTINGS_SaveChannel()` writes back to EEPROM → a programmed offset direction is silently erased after visiting 108–137 MHz. |
| RX-5 | Low | Squelch | Squelch thresholds are per-VFO but are recomputed only for the VFO passed to `RADIO_ConfigureChannel()`; `MENU_SQL` and F+UP/DOWN set `VFO_CONFIGURE` **without** `gFlagResetVfos`, so in dual-watch the other VFO keeps stale thresholds. |
| RX-6 | Low | UI | The "TX locked" padlock is evaluated against the **RX** frequency (`ui/main.c:1558`+`1648`), so cross-band offsets show a wrong lock indication; it should use `pTX->Frequency`. |
| RX-7 | Low | Repeater UX | The TOT (time-out-timer) end-of-TX path does not arm the RP-STE countdown and leaves the receiver muted until PTT release, unlike the PTT/VOX/1750 Hz paths. |
| RX-8 | Info | Build config | In an `ENABLE_AM_FIX=1` build the RX/TX filter is always programmed as "weak signal" variant because the intended conditional is commented out (`radio/radio.c:713-718`, `955-960`). |
| RX-9 | Info | Hygiene | Dead `#else` branch for `SQL_TONE`, large commented-out power-scaling blocks and stale comments in the RX setup path; no functional impact. |

**Shipped-build cross-check.** All findings were re-validated against the actual ApeX release
define set (`tools/defines_aapex.txt`): `ENABLE_FEAT_N7SIX=1`, `ENABLE_SPECTRUM=1`,
`ENABLE_WIDE_RX=0`, `ENABLE_TX_WHEN_AM=0`, `ENABLE_AM_FIX=0`, and
`ENABLE_FMRADIO/NOAA/VOX/ALARM/TX1750/DTMF_CALLING/RESCUE_OPS/COPY_CHAN_TO_VFO/REGA/OVERLAY/WATCHDOG=0`.
Consequences for triage:

* **RX-1, RX-2, RX-3, RX-4, RX-5, RX-6, RX-7 and RX-9 apply to the shipped build.**
* **RX-8 does not** (`ENABLE_AM_FIX=0`).
* Only two end-of-TX paths exist in the release (the VOX and 1750 Hz variants are compiled out), so RX-7 reduces to: PTT release arms RP-STE (`app/generic.c:113-117`) while TOT does not (`app/app.c:982`).
* The "Remove Offset" `gRemoveOffset` talk-around feature and the F+1 copy-channel-to-VFO path are not compiled; `app/beam.c` is not part of any build (`Makefile` `OBJS`), so its `RADIO_ApplyOffset()` call site is dormant.

---

## 2. Reference model of the RX path

### 2.1 Configuration layer — `RADIO_ConfigureChannel()` (`radio/radio.c:161-446`)

| Step | Code | Notes |
|------|------|-------|
| Band/channel selection | `radio/radio.c:165-204` | 350 MHz band is skipped when `gSetting_350EN == 0` |
| Load config bytes | `radio/radio.c:251-363` | only on `VFO_CONFIGURE_RELOAD` **or** for VFO/freq channels |
| Load frequency + offset | `radio/radio.c:365-380` | `{uint32 Frequency; uint32 Offset;}` at `base+0`; offset ≥ 1 GHz is replaced by 10 MHz |
| Band clamping | `radio/radio.c:385-397` | clamp to the channel's band, round VFO frequencies to the step |
| Airband offset kill | `radio/radio.c:399-400` | `RADIO_IsAirbandFrequency()` (108.0–137.0 MHz) → direction = OFF |
| TX frequency | `radio/radio.c:406` | `RADIO_ApplyOffset(pVfo)` → `freq_config_TX = RX ± offset` |
| Reverse / rescue | `radio/radio.c:413-443` | `pRX`/`pTX` swap for `FrequencyReverse`; `gRemoveOffset` forces `pTX = &freq_config_RX` |
| Squelch + power | `radio/radio.c:448-645` | squelch table row selected from **pRX** frequency, TX power interpolation from **pTX** frequency |

`RADIO_ApplyOffset()` itself (`radio/radio.c:649-666`) is a pure, idempotent mapping:

```c
uint32_t Frequency = pInfo->freq_config_RX.Frequency;
switch (pInfo->TX_OFFSET_FREQUENCY_DIRECTION) {
    case TX_OFFSET_FREQUENCY_DIRECTION_OFF: break;
    case TX_OFFSET_FREQUENCY_DIRECTION_ADD: Frequency += pInfo->TX_OFFSET_FREQUENCY; break;
    case TX_OFFSET_FREQUENCY_DIRECTION_SUB: Frequency -= pInfo->TX_OFFSET_FREQUENCY; break;
}
pInfo->freq_config_TX.Frequency = Frequency;
```

### 2.2 RX register setup — `RADIO_SetupRegisters()` (`radio/radio.c:688-883`)

* filter bandwidth — `gRxVfo->CHANNEL_BANDWIDTH` (+ narrower option)
* frequency — `BK4819_SetFrequency(gRxVfo->pRX->Frequency)` (`:742-751`)
* squelch — thresholds from `gRxVfo` (`:753-756`)
* front-end path — `BK4819_PickRXFilterPathBasedOnFrequency()` (< 280 MHz = VHF LNA) (`:758`)
* tone decode — `gRxVfo->pRX->CodeType/Code` (`:778-836`), tail detection (`SQL_TONE`, default 55.0 Hz)
* compander/expander, AGC (`gRxVfo->Modulation == MODULATION_AM`), DTMF, VOX, interrupt mask

### 2.3 Interrupt → state machine

* `CheckRadioInterrupts()` (`app/app.c:654-800`) latches `g_SquelchLost`, `g_CTCSS_Lost`,
  `g_CDCSS_Lost`, `g_CxCSS_TAIL_Found`, DTMF digits, VOX.
* `CheckForIncoming()`/`HandleIncoming()` (`app/app.c:110-244`) decide when to open the audio
  path; tone modes require `g_CTCSS_Lost == false` / `g_CDCSS_Lost == false` to unmute.
* `HandleReceive()` (`app/app.c:246-481`) performs end-of-RX detection including tail-tone
  elimination (`END_OF_RX_MODE_TTE`) and the 1 s tone-lost hang time (`gFoundCTCSSCountdown_10ms`).
* `APP_StartListening()` (`app/app.c:500-585`) opens the audio path and manages dual-watch/bookkeeping.

### 2.4 TX-side derivation as it affects repeater pairs

* `RADIO_PrepareTX()` (`radio/radio.c:1082-1209`) gates TX on `TX_freq_check(gCurrentVfo->pTX->Frequency)`,
  `TX_LOCK`, battery, BCL, AM (`#ifndef ENABLE_TX_WHEN_AM`) and serial-config state.
* `RADIO_SetTxParameters()` (`radio/radio.c:930-999`) programs `gCurrentVfo->pTX->Frequency` and the
  TX CTCSS/DCS code (`pTX->CodeType/Code`) — i.e. the repeater *input* tone.
* `gCurrentVfo` follows the VFO the user is transmitting on: in dual-watch it is `gRxVfo` (the VFO
  the signal was heard on), otherwise `gTxVfo` (`radio/radio.c:668-686`, `1092-1104`).

---

## 3. Findings

### RX-1 (High) — Modulation is latched from a stale frequency; channel can load as AM

**Location:** `radio/radio.c:260-267` (stale read) vs. `radio/radio.c:371-375` (new frequency) and
`radio/radio.c:404` (authoritative re-evaluation); `radio/radio.c:57-66` (helpers);
`core/settings.c:872` (persistence)

```c
// radio/radio.c:264-267  — executed BEFORE the new frequency is read from EEPROM
tmp = data[3] >> 4;
if (tmp >= MODULATION_UKNOWN)
    tmp = MODULATION_FM;
pVfo->Modulation = RADIO_GetModulationForFrequency(pVfo->freq_config_RX.Frequency, tmp);
...
// radio/radio.c:371-375  — the new frequency arrives here
EEPROM_ReadBuffer(base, &info, sizeof(info));
...
pVfo->freq_config_RX.Frequency = info.Frequency;
...
// radio/radio.c:404 — re-applies the airband rule to the NEW frequency,
// but the input is now the possibly-corrupted pVfo->Modulation
pVfo->Modulation = RADIO_GetModulationForFrequency(frequency, pVfo->Modulation);
```

`RADIO_GetModulationForFrequency(f, m)` returns `AM` whenever `f` is in 108.0–137.0 MHz and `m`
otherwise. At line 267 the argument is the **previous** content of `freq_config_RX.Frequency`,
which is only overwritten 100+ lines later.

**Reproduction**

1. In VFO/frequency mode tune to e.g. 120.000 MHz (airband → `Modulation = AM`).
2. Switch to a normal FM memory channel (e.g. channel 5, 145.500 MHz) — `channelMove()`
   (`app/main.c:375-400`) or UP/DOWN (`app/main.c:939-1032`) sets `VFO_CONFIGURE_RELOAD` →
   `RADIO_ConfigureChannel()`:
   * line 267 sees 120.000 MHz → `Modulation = AM`
   * lines 371-375 load 145.500 MHz
   * line 404 asks `RADIO_GetModulationForFrequency(145.5 MHz, AM)` → returns **AM**
3. Result: channel 5 is demodulated with the AM baseband (`BK4819_AF_AM`,
   `radio/radio.c:1009-1011` + `1032`), the CTCSS/DCS decoder is disabled
   (`radio/functions.c:68` → `gCurrentCodeType = CODE_TYPE_OFF`), and with the shipped
   `ENABLE_TX_WHEN_AM=0` **PTT is refused** (`radio/radio.c:1134-1139`).
4. Persistence depends on the save mode (`core/settings.c:845-892`, `Mode >= 2 || IS_FREQ_CHANNEL`):
   * **VFO/frequency channels** — the record block (frequency, offset, direction, modulation) is
     rewritten on *every* save, including the automatic one that each frequency step triggers
     (`app/main.c:996`), so the wrong AM flag is written to EEPROM almost immediately.
   * **Memory channels** — the block is written only for `Mode >= 2` saves: "ChSave"
     (`app/menu.c:645-655`), the CTCSS/DCS scanner's save (`app/scanner.c:226`) or a Beam import
     (`app/beam.c:207`). Without one of those, the RAM value self-heals on the next channel change.
   In both cases the wrong `Modulation` is stored as byte 3 `<7:4>` (`core/settings.c:872`), so the
   channel stays broken until "Mode" is set back to FM (`app/menu.c:940-942`).

Changing the channel a second time self-heals the RAM value (the previous frequency is then
non-airband), which is why this looks like an intermittent "dead channel" bug.

**Fix** — store the EEPROM value verbatim at line 267 and let line 404 do the airband decision:

```diff
         tmp = data[3] >> 4;
         if (tmp >= MODULATION_UKNOWN)
             tmp = MODULATION_FM;
-        pVfo->Modulation = RADIO_GetModulationForFrequency(pVfo->freq_config_RX.Frequency, tmp);
+        pVfo->Modulation = tmp;      /* airband rule is applied after the new frequency is known */
```

This call site is one of the four airband enforcement points introduced by the v7.6.6 airband
work (see [`AIRBAND_MODULATION_INVESTIGATION.md`](AIRBAND_MODULATION_INVESTIGATION.md)). The other
three — `radio/radio.c:156`, `radio/radio.c:404` and `app/action.c:284` — all receive the
*current* frequency, and `:404` runs again with the final, clamped frequency on the very same
reload path. Removing the guard at `:267` therefore keeps the documented airband behaviour intact
while eliminating the corruption.

### RX-2 (Medium) — `RADIO_ApplyOffset()` has no range/underflow guard and the offset limits disagree

**Location:** `radio/radio.c:649-666`; menu entry `app/menu.c:1858-1878` and `app/menu.c:2538-2552`;
loader sanitise `radio/radio.c:377-378`; documentation `Documentation/Owner's Manual - ApeX Edition.md:374`;
TX gate `radio/frequencies.c:162-171`

Three different "maximum offsets" exist:

| Source | Limit |
|--------|-------|
| Owner's manual ("OffSet … ±10.00 MHz") | ±10 MHz |
| Firmware loader (`if (info.Offset >= _1GHz_in_KHz) info.Offset = _1GHz_in_KHz / 100;`) | sanitises only ≥ 1 GHz to 10 MHz |
| UI (6-digit entry, `StrToUL * 100`) | 999.999 MHz |
| UI arrow adjust | wraps to 999.9999 MHz when decrementing below 0 (`app/menu.c:2540-2547`) |

With direction `-` (SUB) and an offset larger than the RX frequency, the `uint32_t` subtraction
wraps (verified numerically):

```
RX 145.000 MHz (14,500,000)  −  offset 999.999 MHz (99,999,900)
    = 4,209,467,396  ⇒ 42,094.674 MHz  (wrapped)
```

Consequences (fail-safe, no memory corruption — `FREQUENCY_GetBand()` saturates to the highest
band, `radio/frequencies.c:118-125`):

* `TX_freq_check()` rejects it → PTT beeps and shows `VFO_STATE_TX_DISABLE` on every attempt;
  the user sees a normal-looking channel that simply cannot transmit.
* `RADIO_ConfigureSquelchAndOutputPower()` then uses `frequencyBandTable[BAND7_470MHz]`
  for the power interpolation, i.e. the 470 MHz calibration row (`0x1ED0 + 6*16`) for a VHF
  channel (`radio/radio.c:517`, `637-644`).
* The same class of input in the *add* direction can push the TX frequency past `F_MAX`
  (600 MHz in the default build, 1300 MHz with `ENABLE_WIDE_RX`), producing the same refusal.

**Fix** — guard the arithmetic (verified by the host harness, see §8.6) and enforce one documented
limit (menu `pMin/pMax`, loader clamp and runtime guard):

```c
void RADIO_ApplyOffset(VFO_Info_t *pInfo)
{
    uint32_t frequency = pInfo->freq_config_RX.Frequency;

    switch (pInfo->TX_OFFSET_FREQUENCY_DIRECTION)
    {
        case TX_OFFSET_FREQUENCY_DIRECTION_ADD:
            /* impossible offset -> mark TX invalid instead of wrapping (RX audit RX-2) */
            frequency = (pInfo->TX_OFFSET_FREQUENCY > (F_MAX - frequency))
                      ? 0xFFFFFFFFu : frequency + pInfo->TX_OFFSET_FREQUENCY;
            break;

        case TX_OFFSET_FREQUENCY_DIRECTION_SUB:
            frequency = (pInfo->TX_OFFSET_FREQUENCY > frequency)
                      ? 0xFFFFFFFFu : frequency - pInfo->TX_OFFSET_FREQUENCY;
            break;

        default:            /* OFF */
            break;
    }

    pInfo->freq_config_TX.Frequency = frequency;
}
```

`0xFFFFFFFF` is already the "frequency off/invalid" sentinel used by
`BK4819_PickRXFilterPathBasedOnFrequency()`; `TX_freq_check()` rejects it under **every** `F_LOCK_*`
mode, so the refusal no longer depends on the band plan. *A plain clamp to `F_MIN`/`F_MAX` (the first
draft) is not sufficient — the harness showed that under `F_LOCK_NONE` the clamped value would be
TX-able; see §8.6.*

(`F_MIN`/`F_MAX` exist in `radio/frequencies.h:47-48`.) Additionally give `MENU_OFFSET` explicit
limits in `MENU_GetLimits()` (`app/menu.c:126-518`) and stop the arrow adjust at 0 instead of
wrapping to 999.9999 MHz.

### RX-3 (Medium) — Interactive VFO frequency edits do not re-derive the TX frequency

**Location:** `app/main.c:986-998` (step up/down) and `app/main.c:593-641` (keypad entry)

```c
const uint32_t frequency = APP_SetFrequencyByStep(gTxVfo, Direction);
...
gTxVfo->freq_config_RX.Frequency = frequency;      // RX only
BK4819_SetFrequency(frequency);
BK4819_RX_TurnOn();
gRequestSaveChannel = 1;                           // TX update deferred to the 500 ms slice
```

`freq_config_TX.Frequency` is refreshed only when the deferred save + reconfigure runs
(`app/app.c:2187-2220`: `SETTINGS_SaveChannel()` → `gVfoConfigureMode = VFO_CONFIGURE` →
`RADIO_ConfigureChannel()` → `RADIO_ApplyOffset()`). That slice runs at most every 500 ms, and the
save is postponed while a key is held (`app/app.c:2196-2201`). Pressing PTT inside that window
therefore transmits on the **old** frequency while the display already shows the new RX frequency
(the TX display line reads `pTX->Frequency`, `ui/main.c:1729-1732`, so it contradicts the RX line).

This affects both simplex (TX on the previous channel) and repeater operation (TX on the previous
repeater input), and is a compliance-relevant defect, not just cosmetic.

**Fix (verified ordering matters)** — re-derive the TX frequency **before** the band-plan check in
`RADIO_PrepareTX()`, not after it:

```c
void RADIO_PrepareTX(void)
{
    ...
    RADIO_SelectCurrentVfo();

    RADIO_ApplyOffset(gCurrentVfo);      /* RX audit RX-3: TX follows the current RX frequency */

    if (TX_freq_check(gCurrentVfo->pTX->Frequency) != 0 && ...)   /* validates the FINAL value */
```

If the offset were re-applied later (e.g. inside `RADIO_SetTxParameters()`), the guard would validate
the **stale** frequency and a freshly derived out-of-band split would be transmitted. The harness
proves the case (`§8.6`): after stepping to 349.900 MHz with a +600 kHz shift and `gSetting_350EN = 0`,
the stale value 349.600 MHz passes `TX_freq_check()` while the derived 350.500 MHz is correctly refused.
`RADIO_ApplyOffset()` is idempotent (also verified), so keeping the existing call in
`RADIO_ConfigureChannel()` is harmless and keeps the EEPROM/display value up to date.

### RX-4 (Medium-Low) — Airband offset sanitisation is written back to EEPROM

**Location:** `radio/radio.c:399-400` + `core/settings.c:872`

```c
if (RADIO_IsAirbandFrequency(frequency))
    pVfo->TX_OFFSET_FREQUENCY_DIRECTION = TX_OFFSET_FREQUENCY_DIRECTION_OFF;
```

This is the correct *runtime* behaviour (airband has no TX shift), but it mutates the config object
that `SETTINGS_SaveChannel()` serialises. Sequence: tune a VFO frequency channel with "TxODir = −"
into 108–137 MHz, step it (freq-mode steps always reload and set `gRequestSaveChannel = 1`,
`app/main.c:996`) → the RAM direction is now OFF → the next save writes direction = 0 into EEPROM →
the stored shift is gone when the user tunes back out of the airband. For an airband *memory*
channel the same happens on the next `Mode >= 2` save (`ChSave` / CSS-scan save / Beam import;
routine attribute saves do not rewrite the record block).

**Fix** — keep the sanitisation out of the persisted object, e.g. apply it where the offset is
consumed:

```c
case TX_OFFSET_FREQUENCY_DIRECTION_ADD:
    if (RADIO_IsAirbandFrequency(pInfo->freq_config_RX.Frequency))
        break;          /* no shift on airband */
    ...
```

or recompute the direction from EEPROM before `SETTINGS_SaveChannel()`.

### RX-5 (Low) — Squelch level changes can leave the non-TX VFO with stale thresholds

**Location:** `app/menu.c:547-553` (`MENU_SQL`), `app/main.c:318-343` (F+UP/DOWN), `app/app.c:2206-2213`

Both paths set `gVfoConfigureMode = VFO_CONFIGURE` without `gFlagResetVfos = true`, so only
`RADIO_ConfigureChannel(gEeprom.TX_VFO, …)` runs and only that VFO's
`RADIO_ConfigureSquelchAndOutputPower()` is recomputed. In dual-watch the RX VFO alternates
(`app/app.c:617-652`, `DualwatchAlternate()` only calls `RADIO_SetupRegisters()`) and keeps the
thresholds of the previous squelch level. The squelch table is also band dependent
(`radio/radio.c:455-479` uses `0x1E60` < 174 MHz, `0x1E00` above), so the effect is
band-specific.

**Fix:** `gFlagResetVfos = true;` for `MENU_SQL` and the F+UP/DOWN squelch path.

### RX-6 (Low) — TX-locked padlock uses the RX frequency

**Location:** `ui/main.c:1558`, `ui/main.c:1648-1652`

```c
uint32_t frequency = gEeprom.VfoInfo[vfo_num].pRX->Frequency;   // :1558
...
if ((gScanStateDir == SCAN_OFF || vfo_num != gEeprom.RX_VFO) &&
    TX_freq_check(frequency) != 0 && gEeprom.VfoInfo[vfo_num].TX_LOCK == true)
    memcpy(p_line0 + 24, BITMAP_VFO_Lock, sizeof(BITMAP_VFO_Lock));
```

`frequency` is replaced by `pTX->Frequency` only while transmitting (`:1729-1732`). For a
cross-band shift (e.g. RX 173.9 MHz "+" to TX 174.5 MHz, or RX 349.9 MHz into 350–400 MHz with
`gSetting_350EN = 0`) the icon state is wrong. Use `pTX->Frequency` for this test.

### RX-7 (Low) — TOT end-of-transmission bypasses RP-STE and holds the receiver muted

**Location:** `app/app.c:947-989` (TOT) vs. `app/app.c:860-866`, `app/generic.c:113-117`,
`app/app.c:2108-2111` (PTT/VOX/1750 Hz)

The PTT, VOX and 1750 Hz end-of-TX paths either select `FUNCTION_FOREGROUND` or arm
`gRTTECountdown_10ms = gEeprom.REPEATER_TAIL_TONE_ELIMINATION * 10`. The TOT path calls
`APP_EndTransmission()` and stops: `gCurrentFunction` stays `FUNCTION_TRANSMIT` (whose handler is
`FUNCTION_NOP`, `app/app.c:485`), so the receiver stays muted until the operator releases PTT —
and when released, `gFlagEndTransmission` short-circuits straight to `FUNCTION_FOREGROUND`
(`app/generic.c:107-108`), i.e. the repeater tail is not suppressed even though RP-STE is enabled.

**Fix (minimal, verified against the countdown gating)** — the RTTE countdown is decremented only
while `gCurrentFunction == FUNCTION_TRANSMIT` (`app/app.c:1435-1493`), which is exactly the state a
TOT leaves behind. So only the `gFlagEndTransmission` branch of the PTT-release handler needs to
honour RP-STE:

```c
if (gFlagEndTransmission) {           /* TOT (or another path) already ended the TX */
    if (gEeprom.REPEATER_TAIL_TONE_ELIMINATION == 0)
        FUNCTION_Select(FUNCTION_FOREGROUND);
    else
        gRTTECountdown_10ms = gEeprom.REPEATER_TAIL_TONE_ELIMINATION * 10;
}
```

No change to the TOT code itself is required, and the VOX / 1750 Hz variants of the same pattern
(`app/app.c:860-866`, `2108-2111`) are compiled out in the shipped build.

### RX-8 (Info) — `ENABLE_AM_FIX` builds always use the "weak signal" filter variant

**Location:** `radio/radio.c:713-718` and `radio/radio.c:955-960`

```c
#ifdef ENABLE_AM_FIX
//  BK4819_SetFilterBandwidth(Bandwidth, gRxVfo->Modulation == MODULATION_AM && gSetting_AM_fix);
    BK4819_SetFilterBandwidth(Bandwidth, true);
#else
    BK4819_SetFilterBandwidth(Bandwidth, false);
#endif
```

The conditional that should decide between the normal and the weak-signal register set is
commented out, so `weak_no_different = true` is passed unconditionally (RX *and* TX): the BK4819 is
told "make the RX bandwidth the same with weak signals" (`driver/bk4819.c:596-598, 606-611`), i.e.
the intended weak-signal bandwidth reduction is disabled at all times. Only relevant if
`ENABLE_AM_FIX=1`; the default ApeX build is unaffected.

### RX-9 (Info) — Hygiene in the RX path

* `radio/radio.c:787-793`: with `SQL_TONE` always defined by the build, the `#else` branch is dead code.
* `radio/radio.c:565-606`: ~40 lines of commented-out TX power scaling; `radio/radio.c:760`
  `// what does this in do ?`.
* `radio/radio.c:828-835`: `#ifdef ENABLE_FEAT_N7SIX` disables scramble RX unconditionally while
  the TX side keeps `SCRAMBLING_TYPE` handling (dead field, `radio/radio.c:275-282`).

---

## 4. Simplex vs. repeater field-by-field behaviour (as implemented)

| Aspect | Simplex (dir = OFF) | Repeater (dir = +/−) | Verdict |
|--------|--------------------|----------------------|---------|
| RX frequency | `freq_config_RX` | `freq_config_RX` | ✅ |
| TX frequency | `freq_config_RX` (offset ignored) | `RX ± offset` via `RADIO_ApplyOffset()` | ✅ idempotent, ⚠️ unvalidated (RX-2), ⚠️ deferred update (RX-3) |
| RX CTCSS/DCS | `freq_config_RX.Code/CodeType` | repeater *output* tone, same source | ✅ |
| TX CTCSS/DCS | `freq_config_TX.Code/CodeType` | repeater *input* tone, same source | ✅ |
| Squelch thresholds | from `pRX` band | from `pRX` band (correct: you listen on the output) | ✅ |
| TX power calibration | from `pTX` band | from `pTX` band | ✅ (⚠️ wrong band if wrap, RX-2) |
| Frequency reverse (F+8) | swaps pointers, no-op for TX freq | swaps to the repeater input for RX / output for TX | ✅ |
| "Remove Offset" (rescue) | no-op | `pTX = &freq_config_RX` (talk-around) | ✅ (UI shows "D", `ui/main.c:2107-2136`) |
| Tail-tone elimination (STE) | TX sends CTCSS/DCS tail | same | ✅ |
| Repeater tail elimination (RP-STE) | delays own RX mute after TX | same | ✅ except TOT path (RX-7) |
| Offset editing (TxOffs/TxODir) | value unused | stored per channel/VFO, saved with the channel | ⚠️ limits inconsistent (RX-2), UI wrap |

---

## 5. Verified-correct behaviour (regression safety net)

1. **No TX/RX cross-contamination**: every RX register decision uses `gRxVfo`/`pRX`
   (`radio/radio.c:690, 742-758, 778-836, 869, 874`), every TX decision uses
   `gCurrentVfo`/`pTX` (`radio/radio.c:932-998`). The reverse feature is therefore
   consistent in both directions.
2. **Idempotent offset**: `RADIO_ApplyOffset()` assigns rather than accumulates, so repeated
   invocation is safe. In the shipped build the live call sites are `radio/radio.c:406` (channel
   load) and `app/chFrScanner.c:244,270` (frequency scan); `app/main.c:173` is compiled only with
   `ENABLE_COPY_CHAN_TO_VFO=1` and `app/beam.c` is not part of any build (`Makefile` `OBJS`).
3. **Fail-safe TX gating**: invalid/out-of-band TX frequencies, busy-channel lock, low battery,
   serial config and AM mode all result in `VFO_STATE_TX_DISABLE` + beep instead of a
   mis-tuned transmission (`radio/radio.c:1107-1154`).
4. **Tone-driven squelch logic** (open on squelch + tone, close on tone lost, 1 s hang,
   tail-tone detection, DCS negative-code handling) matches the upstream design
   (`app/app.c:185-244`, `269-373`; `driver/bk4819.c:671-750`).
5. **Configuration is stored in a CHIRP-compatible layout**: offset in 10 Hz units at
   `base+4`, direction in bits `<3:0>` and modulation in bits `<7:4>` of byte 3
   (`core/settings.c:865-890`) — matches `CHIRP/uvk5_egzumer_n7six_ver_7_6_10.py:484-486,1352-1359`.
6. **Compile sanity of the audited units**: `radio/radio.c` and `app/app.c` compile with the
   project flags and the shipped ARM toolchain (see Appendix A) — no warnings/errors.

---

## 6. Recommended priority order

1. **RX-1** — one-line change, removes a silently broken channel (RX + TX) and EEPROM corruption.
2. **RX-3** — re-derive the TX frequency at PTT time (prevents transmitting on the wrong frequency).
3. **RX-2** — guard `RADIO_ApplyOffset()` and unify the offset limit (±10 MHz as documented).
4. **RX-4 / RX-5** — one-line fixes each (sanitise at use-time; `gFlagResetVfos`).
5. **RX-6 / RX-7 / RX-8 / RX-9** — cosmetic/robustness follow-ups.

---

## 7. Intent vs. defect — per-finding verdict

Not every irregularity above is a bug: several are deliberate design decisions or long-standing
family conventions. This is the reviewer's judgement with the evidence used, so the list can be
triaged on purpose rather than by severity alone.

| ID | Deliberate? | Evidence | Verdict |
|----|-------------|----------|---------|
| RX-1 | **Intent deliberate, implementation defective** | The guard is documented ApeX v7.6.6 work — `Documentation/AIRBAND_MODULATION_INVESTIGATION.md` lists four airband enforcement points: VFO init (`radio/radio.c:156`, correct frequency), channel/VFO reload (`:267`, **previous** frequency — the defect), post-normalisation (`:404`, correct) and the demodulation-cycle action (`app/action.c:284`, correct). The reload point can never produce a correct answer, and deleting it loses nothing because `:404` enforces the rule again with the final clamped frequency on the same path. | **Genuine defect, project-introduced** (not upstream-inherited). One-line fix; highest-value item. |
| RX-2 | **Partly** | Refusing TX for out-of-band or wrapped TX frequencies is *intentional* fail-safe logic (`radio/radio.c:1107-1119`). But the UI wrap (0 − 1 → 999.9999 MHz), the ±999.999 MHz menu range vs. the documented ±10 MHz, and the loader's "≥ 1 GHz → 10 MHz" substitution are three different answers to one question, which no design deliberately intends. | Genuine but low-impact validation gap. If "no TX" is an acceptable outcome for a nonsensical offset, it can be closed as a documentation/limit-consistency issue instead of a bug. |
| RX-3 | **Design deliberate, consequence not** | Updating the RX frequency immediately (autotune) while everything else travels through the deferred save/reconfigure pipeline is a deliberate pattern here; the authors clearly expected the save+configure to have completed before any PTT — which holds except inside the ≤ 500 ms window. | Real but narrow race. Severity depends on how unacceptable a wrong-frequency transmission is for you; it is cheap to close at the PTT point (`RADIO_ApplyOffset()` before use). |
| RX-4 | **Partly** | Forcing airband shift = OFF is deliberate (`radio/radio.c:399-400`). Writing that sanitised RAM value into the persisted record is an unintended consequence of `VFO_Info_t` serving as both the runtime and the stored structure. | Unintended side effect; user-visible as "my shift disappeared". Low impact. |
| RX-5 | **Deliberate thresholds, unintended refresh scope** | Per-band, per-VFO squelch tables are deliberate (`radio/radio.c:455-479`). `gFlagResetVfos = true` exists precisely to reconfigure the *other* VFO and is used by other settings (e.g. `MENU_COMPAND`, `MENU_LIST_CH`), so its absence in `MENU_SQL` / F+UP/DOWN reads as an omission rather than a decision. | Genuine omission, minor. |
| RX-6 | **Probably deliberate simplification** | The icon is drawn from the value already on screen; using `pTX->Frequency` costs an extra lookup, and the same test exists in the upstream lineage. | Cosmetic/inherited; fix opportunistically. |
| RX-7 | **Deliberate behaviour, unintended inconsistency** | Staying "in TX" (muted) until PTT release after a TOT is plausible by design (don't reopen RX while the operator still holds PTT). But the other two end-of-TX paths *do* arm RP-STE, so its absence here is inconsistent rather than chosen. | Minor; align the three end-of-TX paths. |
| RX-8 | **Deliberate** | The line was consciously commented out (author workaround for AM weak-signal behaviour). | Not a defect in itself; record the intent in a comment or make it a build option. |
| RX-9 | **Deliberate leftovers** | Commented-out experiments and stale comments. | Hygiene only. |

**Direct answer to "is it a problem or intentional?":**

* **Unintended defects worth fixing:** RX-1 (high value, one line), RX-4, RX-5, and RX-3 if
  transmitting on a stale frequency is unacceptable to you.
* **Deliberate design that is merely inconsistent or under-documented:** RX-2 (the fail-safe is
  intended, the missing validation/limits are not), RX-7, RX-8.
* **Inherited cosmetics:** RX-6, RX-9.
* **RX-1 is project-introduced** by the v7.6.6 airband work, so the fix must also update
  `AIRBAND_MODULATION_INVESTIGATION.md` (which still lists the defective call site as a fix).
  RX-2/-6/-7 follow patterns inherited from the upstream lineage and RX-3 comes from this
  firmware's deferred save/reconfigure pipeline; those changes intentionally diverge from the
  historical behaviour, so leave a short comment referencing this audit.

---

## 8. Professional recommendations (remediation plan)

### 8.1 Fix list — effort, risk, regression check

**Status (2026-09-24):** priorities 1–7 are **applied** to the source tree, compile-clean and
size-measured — see §8.7 for the exact changes, the flash accounting (+24 B) and the remaining
budget. Priorities 8–9 are deliberately left open and the Appendix A bench runs are outstanding.

| Priority | Action | Effort / risk | Regression check |
|----------|--------|---------------|------------------|
| 1 | **RX-1** — replace the guard at `radio/radio.c:267` with `pVfo->Modulation = tmp;`; leave `:156`, `:404` and `app/action.c:284` untouched. | 1 line / very low | airband still forced to AM; an FM memory channel loaded right after airband stays FM and can TX |
| 2 | **RX-3** — insert `RADIO_ApplyOffset(gCurrentVfo);` in `RADIO_PrepareTX()` after `RADIO_SelectCurrentVfo()` and **before** the `TX_freq_check` (verified: applying it after the check would bypass the guard). | 2 lines / low | step a VFO frequency, key up immediately → TX on the displayed frequency; repeater split unchanged; an out-of-band derived split is still refused |
| 3 | **RX-2** — mark impossible offsets invalid (`0xFFFFFFFF`, verified) instead of letting them wrap; unify the limit: `MENU_OFFSET` min/max in `MENU_GetLimits()`, stop the arrow wrap at 0, clamp in the loader, document the adopted limit (±10 MHz). | ~15 lines / low | nonsensical offsets are refused under every `F_LOCK_*` mode; the manual matches the firmware |
| 4 | **RX-4** — decide the airband direction where the offset is consumed instead of overwriting the persisted field. | ~5 lines / low | a stored "+600 kHz" survives a tune through 108–137 MHz |
| 5 | **RX-5** — add `gFlagResetVfos = true;` to `MENU_SQL` and the F+UP/DOWN squelch path. | 2 lines / very low | Sql change takes effect on both VFOs in dual-watch |
| 6 | **RX-6** — test the padlock against `pTX->Frequency`. | 1 line / very low | lock icon only when TX is really blocked |
| 7 | **RX-7** — honour RP-STE in the `gFlagEndTransmission` branch of the PTT-release handler (`app/generic.c:107-108`) instead of jumping straight to `FUNCTION_FOREGROUND`. | 4 lines / low | TOT then PTT release with RP-STE on suppresses the repeater tail; RP-STE off behaves exactly as before |
| 8 | **RX-8** — restore the commented conditional (or pass `false`); `ENABLE_AM_FIX=1` builds only. | 1 line / low | AM-fix build filter behaviour |
| 9 | **RX-9** — delete dead blocks when the file is next touched; not worth its own release. | cosmetic | compile clean |

Packaging: items 1–6 are small and touch the same subsystem — ship them as one "RX config/offset"
patch set with a single rebuild and one bench pass; 7–9 opportunistically.

### 8.2 Architectural change that prevents recurrence

RX-1 and RX-3 share one root cause: **derived state is cached and kept in sync by many paths**
(`Modulation`, `freq_config_TX.Frequency`). Three structural rules remove the whole class:

1. **Derive, do not cache, the TX frequency.** Treat `freq_config_TX.Frequency` as an
   EEPROM/display artifact and recompute it at the point of use (`RADIO_SetTxParameters()` /
   `RADIO_PrepareTX()`). New frequency-editing paths then cannot forget the offset, and the
   ≤500 ms race disappears by construction.
2. **Keep rule-derived values out of the persisted struct.** Store what EEPROM says
   (`pVfo->Modulation = tmp;`), then apply normalisation exactly once, after the frequency is
   final — exactly what the v7.6.6 airband design already does at `radio/radio.c:404`.
3. **One validation point for offsets.** A single limit constant plus helper used by the menu,
   the loader and the PTT gate prevents the "documented vs. accepted vs. silently substituted"
   divergence seen in RX-2.

### 8.3 Validation

* **Build gate:** `tools/build_k5.ps1 -Link` or `./compile-with-docker.sh ApeX` — must stay clean
  under `-Wall -Wextra -Werror`.
* **Bench matrix:** run the Appendix A checks before/after the patch and attach the results to the
  release notes; add the RX-1 persistence variant (step inside the airband, leave the airband,
  power-cycle).
* **Optional automation:** the offset arithmetic is pure; moving it to `radio/frequencies.c`
  (e.g. `FREQUENCY_ApplyOffset()`) would allow a small host-side test in `tools/`, which is the
  only way to obtain automated coverage without hardware. Otherwise the bench checklist is the test.

### 8.4 Process and documentation

* Add a `/* ApeX RX audit RX-n */` comment at each fix site — RX-2/-3/-6/-7 intentionally diverge
  from the historical/upstream behaviour and must not be silently reverted by a future merge.
* Update [`AIRBAND_MODULATION_INVESTIGATION.md`](AIRBAND_MODULATION_INVESTIGATION.md): it currently
  presents the defective call site as part of the fix, so code and document must be corrected
  together.
* Correct the Owner's Manual's "±10.00 MHz" OffSet entry to match whatever limit RX-2 adopts.
* Link this audit from [`README.md`](README.md) (documentation index) and add a release-note line
  for the user-visible behaviour change ("memory channels no longer load as AM after airband tuning").
* Rebuild and re-package `build/ApeX/*` after the fix — those are the artifacts CI uploads.

### 8.5 What not to change

* The per-VFO/per-band squelch tables, the interrupt-driven squelch/tone state machine, the
  `TX_freq_check`/`TX_LOCK` fail-safe and the idempotent `RADIO_ApplyOffset()` mapping are sound —
  do not restructure them for these fixes.
* Do **not** work around RX-1 by enabling `ENABLE_TX_WHEN_AM`: that would permit airband TX at
  FM/AM instead of fixing the mode latch.
* RX-8/RX-9 are deliberate author choices — record the intent rather than "cleaning up" blindly.

---



### 8.6 Verification of the recommendations (host harness)

The code-level recommendations (RX-1, RX-2/RX-4) were **verified** — not just reasoned — by extracting
the real functions from `radio/radio.c` (current tree and a patched copy) and linking them with the
real `radio/frequencies.c` into a host test. Everything lives in the git-ignored `build/audit/` tree:
`extract_radio_funcs.ps1` (verbatim function extraction), `rx_audit_test.c` (19 checks),
`shim/` (host shims for `settings.h`/`misc.h`) and `radio_fixed.c` (patched copy). The same test
source is compiled twice:

    gcc -std=c2x -Wall -Wextra -Ibuild/audit/shim -I. -DENABLE_FEAT_N7SIX -DVARIANT_NAME=current -o build/audit/test_current.exe build/audit/rx_audit_test.c build/audit/extract_current.c radio/frequencies.c build/audit/shim_globals.c
    gcc -std=c2x -Wall -Wextra -Ibuild/audit/shim -I. -DENABLE_FEAT_N7SIX -DVARIANT_NAME=fixed   -o build/audit/test_fixed.exe   build/audit/rx_audit_test.c build/audit/extract_fixed.c   radio/frequencies.c build/audit/shim_globals.c

| Check | current tree | recommended patch |
|-------|--------------|-------------------|
| RX-1: FM channel loaded after airband stays FM | **FAIL (latches AM)** | PASS |
| RX-1: airband still forces AM (FM/USB normalised) | PASS | PASS |
| RX-1: old chain reproduces the AM latch | PASS (defect reproduced) | PASS |
| RX-2: 145.000 MHz SUB 999.999 MHz | **FAIL — `0xFAE76004` = 42 094.67 MHz (uint32 wrap)** | PASS — `0xFFFFFFFF` (invalid) |
| RX-2: that TX refused under `F_LOCK_DEF` / `F_LOCK_NONE` | PASS / PASS | PASS / PASS |
| RX-2 regressions: ±600 kHz VHF, +5 MHz UHF, simplex | PASS | PASS |
| RX-3: re-derivation yields RX + offset (349.900 + 600 kHz = 350.500) | PASS | PASS |
| RX-3: stale TX passes the band plan (offset after the check bypasses the guard) | PASS (hazard shown) | PASS (hazard shown) |
| RX-3: derived TX refused with `350EN=0` (offset must be applied *before* the check) | PASS | PASS |
| RX-3: `350EN=1` pair allowed (no regression) | PASS | PASS |
| RX-3: `RADIO_ApplyOffset()` idempotent (safe from both call sites) | PASS | PASS |
| RX-4: airband TX == RX, stored direction untouched | **FAIL (shift applied)** | PASS |
| RX-4: non-airband shift still applied | PASS | PASS |

**Totals: current 2 failed / 19, patched 0 failed / 19.**

The harness also corrected two of my own first-draft recommendations:

1. RX-2: clamping to `F_MIN` (the first draft) would still have permitted a transmission of the
   clamped value under `F_LOCK_NONE`; the verified recipe marks the TX frequency **invalid**
   (`0xFFFFFFFF`), which `TX_freq_check()` rejects in every lock mode.
2. RX-3: `RADIO_ApplyOffset()` must be called **before** the `TX_freq_check()` — the first draft
   (re-derive inside `RADIO_SetTxParameters()`) would have validated the stale frequency and
   *weakened* the out-of-band fail-safe.

RX-5/-6/-7 are call-site/UI changes that cannot be host-tested; they were verified statically
(`app/app.c:2206-2212` for the `gFlagResetVfos` flow, `ui/main.c:1558`+`1648` for the padlock,
`app/app.c:1435-1493` for the RTTE countdown gating) and still need the Appendix A bench checks.

The harness itself does not modify firmware sources; the shipped changes and their measured flash
cost are recorded in §8.7.

### 8.7 Implementation status — applied changes and FLASH impact (2026-09-24)

Applied as a single "RX config/offset" patch set (priorities 1–7 of §8.1); five files touched,
+46/−16 lines.

| ID | File (post-patch line) | Change |
|----|------------------------|--------|
| RX-1 | `radio/radio.c:267-271` | `pVfo->Modulation = tmp;` — the EEPROM mode is stored verbatim; the airband rule is applied once, at `:408`, with the final frequency |
| RX-2 | `radio/radio.c:659-675` | `RADIO_ApplyOffset()` guards the `uint32_t` arithmetic: an impossible offset yields `0xFFFFFFFF` (rejected by `TX_freq_check()` under every `F_LOCK_*` mode) instead of wrapping to 42 GHz |
| RX-3 | `radio/radio.c:1119-1123` | `RADIO_ApplyOffset(gCurrentVfo)` inside `RADIO_PrepareTX()`, **before** `TX_freq_check()` — TX always follows the displayed RX frequency + shift |
| RX-4 | `radio/radio.c:403-407` + `:657-663` | the airband "no shift" rule is applied where the offset is consumed (`offset = 0`), so `TX_OFFSET_FREQUENCY_DIRECTION` is no longer erased from the persisted record |
| RX-5 | `app/menu.c:550-552`, `app/main.c:338-340` | `gFlagResetVfos = true;` on both squelch paths, so dual-watch gets the new thresholds on both VFOs |
| RX-6 | `ui/main.c:1648-1651` | the padlock is decided by `pTX->Frequency` (is TX really blocked?), not by the displayed RX frequency |
| RX-7 | `app/generic.c:107-117` | the `gFlagEndTransmission` path (TOT) shares the RP-STE handling instead of jumping straight to `FUNCTION_FOREGROUND` |

Verification performed:

* **Compile gate:** full 58-object build with the project flags (`-Oz -Wall -Wextra -Werror -std=c2x`,
  `-ffunction-sections/-fdata-sections`, single-partition LTO, `--gc-sections`) — clean in both
  tested configurations, via `build/full_build.ps1 -Config shipped|defaults` (scratch script in the
  git-ignored `build/` tree; it rebuilds every object, so a flag change cannot silently reuse
  stale objects).
* **Host harness:** RX-1/-2/-3/-4 verified functionally against the *actual patched tree* — the three
  functions are re-extracted verbatim from `radio/radio.c` and the harness reports **19/19 checks,
  0 failed** (17/19 before the patch; see §8.6). RX-5/-6/-7 are call-site/UI changes verified
  statically.

FLASH accounting (arm-none-eabi 14.3.1, local Windows build; the `.bin` is what must fit 61,440 B):

| Configuration | Base | Patched | Δ |
|---------------|------|---------|----|
| `tools/defines_aapex.txt` release set (SHADE on, PEAK/SMOOTH/RSSI_SQRT/REG_MENU/K1_EXTRAS off, SCAN_RANGES on) | 62,804 B | 62,828 B | **+24 B** |
| plain Makefile `?=` defaults (what `make -s EDITION_STRING=ApeX TARGET=ApeX`, i.e. CI, builds) | 61,960 B | 61,984 B | **+24 B** |

`.bss` is unchanged (3,360 B in the release set, 3,504 B in the defaults set) — **no RAM cost**, and
the patch set touches none of the flash-critical size paths (spectrum, fonts, bitmaps, menu tables).

**Released-image projection:** the shipped `build/ApeX/n7six.ApeX-k5.v7.6.10A.bin` is 61,336 B of
the 61,440 B budget (+104 B). Adding the measured Δ gives ≈ **61,360 B → ~80 B still free**. The
released ELF was built with **Alpine GCC 15.1.0** (Docker; read from the ELF `.comment` section),
whereas the local Windows toolchain is Arm GNU 14.3.1, which emits ~1.5 kB larger images for the
same configuration — so re-run `./compile-with-docker.sh ApeX` for the byte-exact release figure.
The **Δ is what transfers**, and it measured +24 B identically in both configurations above. If the
remaining ~80 B is ever insufficient, the escalation list in [`FLASH_AUDIT_K1.md`](FLASH_AUDIT_K1.md) §6
(cheapest first: `ENABLE_SPECTRUM_SHADE=0` → +32 B) is the lever.

---

## Appendix A — Evidence / reproduction commands

Compile check of the two central translation units with the project configuration
(toolchain 14.3 rel1, `-Wall -Wextra -Werror -std=c2x -mcpu=cortex-m0`):

```powershell
$CC='arm-none-eabi-gcc'
$defs='-DENABLE_UART','-DENABLE_BIG_FREQ','-DENABLE_SMALL_BOLD','-DENABLE_CUSTOM_MENU_LAYOUT',
      '-DENABLE_RSSI_BAR','-DENABLE_AUDIO_BAR','-DENABLE_SCAN_RANGES','-DENABLE_FEAT_N7SIX',
      '-DALERT_TOT=10','-DSQL_TONE=550','-DPRINTF_INCLUDE_CONFIG_H'
$inc='-I.','-I./app','-I./ui','-I./driver','-I./bsp','-I./helper','-I./core','-I./system',
     '-I./graphics','-I./radio','-I./audio','-I./config',
     '-I./external/CMSIS_5/CMSIS/Core/Include','-I./external/CMSIS_5/Device/ARM/ARMCM0/Include'
& $CC -Oz -mcpu=cortex-m0 -fshort-enums -std=c2x -Wall -Wextra -Werror @defs @inc -c radio/radio.c -o build/audit/radio.o
& $CC -Oz -mcpu=cortex-m0 -fshort-enums -std=c2x -Wall -Wextra -Werror @defs @inc -c app/app.c     -o build/audit/app.o
```

Bench checks (no source change required):

| Check | Procedure | Expected (current code) |
|-------|-----------|-------------------------|
| RX-1 | freq mode @120.000 MHz → select an FM memory channel; observe mode indicator and RX audio | mode latches to AM, audio distorted, PTT refused (defect) |
| RX-1 persistence | (a) VFO/freq channel: step the frequency while in airband and re-read the band's stored mode; (b) memory channel: after the AM latch, use ChSave (or accept a CSS scan) and power-cycle | the AM flag is stored in EEPROM (defect) |
| RX-2 | VFO 145.000 MHz, TxODir "−", TxOffs "DOWN" once (wraps to 999.9999), PTT | "TX disabled" beep; TX frequency ≈ 42 GHz internally (defect) |
| RX-3 | freq mode, tap UP once, press PTT immediately (< 500 ms), read TX frequency on the display | TX on the previous frequency (defect) |
| RX-4 | VFO with "+600 kHz" shift, step into 108–137 MHz, step out, re-read TxOffs | shift lost (defect) |
| RX-5 | dual-watch on, change Sql from the menu, wait for DW to switch VFO, evaluate squelch behaviour | other VFO uses the old level (defect) |
| Repeater baseline | +600 kHz / −600 kHz / +5 MHz channels, TX CTCSS/RX CTCSS, STE and RP-STE on | correct split, correct tones, tail suppressed |

## Appendix B — Related documents

* [`AUDIT_REPORT.md`](AUDIT_REPORT.md) — overall source audit (build blockers, UART, MDC-1200)
* [`PERFORMANCE_STABILITY_ANALYSIS.md`](PERFORMANCE_STABILITY_ANALYSIS.md) — performance/stability items
* [`Owner's Manual - ApeX Edition.md`](Owner's%20Manual%20-%20ApeX%20Edition.md) — user-facing
  menu reference (OffSet documented as ±10.00 MHz)






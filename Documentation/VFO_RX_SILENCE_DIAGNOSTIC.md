# VFO B RX silence / garbled MDC — EEPROM diagnostic

## Symptom

* VFO A receives normally (voice, MDC-1200 decodes).
* VFO B in the **same band** produces:
  * no speaker audio at all (RSSI bar and squelch still work, so the radio *is*
    receiving), or
  * very quiet / distorted audio and MDC-1200 reports "no correct preamble".

## Why the code is not the suspect

`radio/radio.c` and `app/app.c` of this tree were diffed against
`armel/uv-k5-firmware-custom`. The RX path is byte identical apart from the
deliberate ApeX changes (AGC register caching removed, squelch delay bit
width). There is therefore no RX logic difference that could make *one* VFO of
*one* band behave differently — the two VFOs of a band run the same code.

## What actually differs between VFO A and VFO B

A band slot is 32 bytes; each VFO owns 16 of them
(`radio/radio.c:249`, store: `core/settings.c:845-890`):

```
base = 0x0C80 + (band * 32) + (VFO * 16)      band = channel - FREQ_CHANNEL_FIRST (200..206)
```

Everything *shared* by both VFOs of a band (band index, compander, scan lists)
lives in a single attribute byte at `0x0D60 + (channel & ~7) + (channel & 7)`
= `0x0E28 + band` (`core/settings.c:963`), so it cannot differ between A and B.

That leaves only the 16 byte per-VFO record:

| offset | field |
|--------|-------|
| +00..03 | RX frequency (uint32 LE, 10 Hz units) |
| +04..07 | TX offset frequency (uint32 LE, 10 Hz units) |
| +08 | RX code index (`CTCSS_Options[]` / `DCS_Options[]`) |
| +09 | TX code index |
| +10 | bit3:0 RX code type, bit7:4 TX code type (0 off, 1 CTCSS, 2 DCS, 3 DCS inverted) |
| +11 | bit3:0 TX offset direction, bit7:4 modulation (0 FM, 1 AM, 2 USB) |
| +12 | bit0 reverse, bit1 bandwidth, bit4:2 power, bit5 busy lock, bit6 TX lock |
| +13 | bit0 DTMF decode, bit3:1 PTT ID |
| +14 | step setting |
| +15 | scrambling type |

Two of those fields reproduce the symptom on their own:

* **code type != off** — `app/app.c:197` `HandleIncoming()` only calls
  `APP_StartListening()` once `gCurrentCodeType == CODE_TYPE_OFF` or the
  programmed tone was detected. Squelch opens, RSSI shows signal, the audio
  path stays shut: *silence with a signal meter*.
* **modulation != FM** — `radio/radio.c:1042` `RADIO_SetModulation()` switches
  the AF path and the AGC to AM/USB. An FM signal then arrives demodulated by
  the wrong detector: *quiet, distorted, MDC preamble unusable*.

Both values are stored per VFO, so a stale tone or mode left on VFO B explains
the symptom without any code difference.

## Second cause: the BK4819 AF enables can be left switched off (RX-12)

Independently of what is stored, the K5 could arm RX with the **amplifier GPIO
only**:

```c
static inline void AUDIO_AudioPathOn(void) { GPIO_SetBit(&GPIOC->DATA, GPIOC_PIN_AUDIO_PATH); }
```

Nothing on the RX entry re-asserted the chip's own audio enables, `REG_30<9>`
(AF DAC) and `REG_47<8>` (AF output). Several code paths legitimately leave
them cleared for a while — most concretely the F4HWN spectrum, which caches
`REG_30` with bit 9 masked out (`app/spectrum.c:857`) and rewrites that cached
value on every sweep step (`SetFScan()`), plus the TX/DTMF exits and tone
playback. If RX then started with the GPIO alone, the BK4819 kept demodulating
(S-meter moves, squelch opens) while nothing reached the speaker. Those bits are
**global, not per VFO**, so with dual watch the leftover state of the other
VFO's session is what the user sees as "VFO B is silent".

v7.6.10C adopts the UV-K1Series ApeX Edition solution: one authoritative switch,
`RADIO_SetAudioPath(bool)` in `radio/radio.c`, called from `APP_StartListening()`.
It re-asserts `REG_30<9>`/`REG_47<8>` and waits 500 µs *before* un-muting the
amp, and on exit mutes the amp *before* dropping the chip bits, so no leftover
chip state can silence the receiver and no pop is added. Detail:
[`RX_SIMPLEX_REPEATER_AUDIT.md`](RX_SIMPLEX_REPEATER_AUDIT.md) §8.8.

**Which of the two causes applies?** If the silence follows a spectrum visit, a
transmit, or a tone/beep, and the S-meter is alive, it is RX-12 (firmware). If it
is simply always there on one VFO of a band, run the tool below and look for a
`CRIT` row — that is the stored cause. Both can be present at once.

## Tool

`tools\rx_probe_vfo.ps1` decodes the 14 VFO records of a raw EEPROM dump and
reports which stored field would silence or garble the audio.

```
k5prog -R -E -f eeprom.bin                      # back the radio up first
powershell -ExecutionPolicy Bypass -File tools\rx_probe_vfo.ps1 eeprom.bin -Bytes
powershell -ExecutionPolicy Bypass -File tools\rx_probe_vfo.ps1 eeprom.bin -Find 147.650,146.520 -Bytes
```

Verdicts:

| verdict | meaning |
|---------|---------|
| `CRIT` | RX tone gate active, or modulation is not FM — the record alone can mute or garble audio |
| `warn` | out-of-range nibbles, reverse mode, narrow bandwidth, frequency outside the slot, locks |
| `empty` | record is 0xFF (band never used) |
| `ok` | nothing suspicious in the record |

The tool never modifies the input image. `-PatchTo` writes a **new** file and
refuses to overwrite an existing one.

## Fixing from the menu (preferred)

1. Switch to VFO B.
2. `RxCTCS` / `RxDCS` -> **OFF** (also check the `MODE` line: must be `FM`).
3. `BW` -> `WIDE`.
4. If `REV` is on, remember that the RX side then uses the *TX* tone field, so
   clear `TxCTCS` / `TxDCS` as well.
5. Save: the VFO record is written on band change, power off, or `ChSave`.

## Fixing the stored image (when the menu cannot be reached)

```
powershell -ExecutionPolicy Bypass -File tools\rx_probe_vfo.ps1 eeprom.bin `
    -Find 147.650 -ForceFM -ClearRxTone -Wide -PatchTo eeprom_fixed.bin
k5prog -W -E -f eeprom_fixed.bin        # radio powered OFF, keep eeprom.bin
```

The patch only rewrites bytes `+08`, `+10`, `+11` (high nibble) and `+12`
(bit1) of the matched record(s); everything else, including the band attribute
byte, is copied verbatim. In reverse mode `-ClearRxTone` clears the TX field
too, because that is the field the RX path actually uses.

## After the fix

Power cycle, then re-read the EEPROM and re-run the tool: the record must come
back `ok` and must match the working VFO byte for byte in `+08`..`+12`.

## Firmware-side check (RX-12)

With the v7.6.10C firmware the RX entry re-asserts the BK4819 AF enables, so
audio can no longer be left dead by leftover chip state. To confirm on a bench
without an EEPROM dump:

1. Flash v7.6.10C.
2. Open the spectrum view on a busy frequency, then leave it while a signal is
   present → speaker must stay live.
3. Transmit on VFO A, let the radio return to receive on VFO B (dual watch) →
   VFO B must produce audio.
4. If audio is still missing, run the EEPROM tool above: a remaining `CRIT` row
   is a stored configuration problem, not a firmware one.

## Notes

* The radio only writes a VFO record on band change / power off / `ChSave`.
  A frequency that was just tuned but never saved will not appear in the dump.
* `-Find` matches on the frequency stored in EEPROM, not on the display; a
  "not found" result usually means the frequency lives in the other VFO of the
  band.
* The decode rules mirror `RADIO_ConfigureChannel()`. If that function changes,
  the script has to follow it.

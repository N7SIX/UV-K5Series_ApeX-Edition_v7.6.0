# Firmware Source Audit — ApeX Edition (folder tag v7.6.0 / build tag v7.6.6)

**Auditor:** Independent senior embedded firmware review (static analysis)
**Date:** 2026-09-11
**Scope:** `c:\Users\sebue\Documents\N7SIX\Software\Quansheng\UV-K5Series_ApeX-Edition_v7.6.0`
**Target:** Quansheng UV-K5 / K5(8) / K6 (DP32G030, Cortex-M0, 64 KB flash / 8 KB RAM)

Method: static review of the 63 in-tree `.c` files / 145 headers (external/ excluded),
build-system analysis, UART protocol comparison against upstream Egzumer `app/uart.c`, and
macro-expansion analysis of the scheduler. The tree is **not a git repository**, and the
analysis host has no `make`, so the audit is static; no build was executed here.

---

## 1. Executive summary

The codebase is a well-organized fork of Egzumer/OneOfEleven/DualTachyon with a sensible
module split (`core/`, `radio/`, `app/`, `driver/`, `ui/`, `audio/`, `graphics/`). It retains
the strong upstream engineering practices: `-Wall -Werror -std=c2x`, `static_assert` table
invariants, and a UART protocol parser that is functionally identical to the battle-tested
upstream implementation (with a documented and *correct* `& 0xFF` ring-buffer optimization).

However, the tree as checked in **cannot compile and cannot even be parsed by GNU make**.
Three independent build blockers exist, and the shipped binaries in `build/ApeX/` are dated
after these defects were introduced — i.e., the binaries were not produced from this source
state. There is no version control (`.git` is missing), so provenance is impossible to
establish. One remotely-triggerable stack overflow (inherited from upstream) exists in the
UART EEPROM-read path, a firmware feature (MDC-1200) is half-integrated with missing symbols,
and a CHIRP-critical UART command (0x052F) is silently compiled out.

### Risk summary

| ID | Severity | Area | Finding |
|----|----------|------|---------|
| B1 | **Blocker** | Build | Tab-indented `TARGET = ApeX` at Makefile top level → `recipe commences before first target` |
| B2 | **Blocker** | Runtime | `scheduler.c:60` applies `--` to an rvalue expression → GCC hard error under `-Werror` |
| B3 | **Blocker** | Build/Link | `UI_DisplayMDCAlert()` called from `ui/main.c` with no prototype; `ui/mdc.c` not compiled; MDC core symbols missing |
| H1 | High | Security | UART CMD_051B: attacker-controlled `Size` (≤255) read into 128-byte stack buffer |
| H2 | High | Robustness | No hardware watchdog enabled anywhere (WWDT/IWDT unused) |
| H3 | High | Process | No `.git`; binaries in `build/ApeX` cannot be traced to source |
| M1–M8 | Medium | Build/Compat/Docs | See §4 |
| L1–L7 | Low | Hygiene | See §5 |

---

## 2. Blocker-level findings (the tree does not build)

### B1 — Makefile line 49: stray tab-indented line

```make
46 | # Thank you @markusb
47 | ENABLE_REGA                     ?= 0
48 | # Thank you @reppad
49 | <TAB>TARGET = ApeX          ← actual TAB in the file
```

GNU make rejects a recipe line (tab-prefixed) that appears before any rule has been declared:
`Makefile:49: *** recipe commences before first target.  Stop.` Even if tolerated by some
make, the assignment is dead code — `TARGET` is unconditionally re-decided at lines 86–90
(`n7six` when `ENABLE_FEAT_N7SIX=1`, which is the default).


### B2 — scheduler.c:60 — decrement of an rvalue (also a broken TOT alert)

```c
// system/scheduler.c:60  (inside #ifdef ENABLE_FEAT_N7SIX)
DECREMENT_AND_TRIGGER(gTxTimerCountdownAlert_500ms - ALERT_TOT * 2, gTxTimeoutReachedAlert);
```

`DECREMENT_AND_TRIGGER(cnt, flag)` expands to `if (--cnt == 0) flag = true;`. With
`cnt = gTxTimerCountdownAlert_500ms - ALERT_TOT * 2` this becomes `--(rvalue)` →
`error: lvalue required as decrement operand` (and the tree builds with `-Werror`).
Beyond the compile error, the *intent* is broken: the alert should fire `ALERT_TOT * 2`
half-second ticks (10 s with `ALERT_TOT=10`) before TOT expiry.

**Fix (suggested):**

```c
// Alert fires exactly once, 10 s before TOT expiry
if (gTxTimerCountdownAlert_500ms > 0 &&
    --gTxTimerCountdownAlert_500ms == (ALERT_TOT * 2))
    gTxTimeoutReachedAlert = true;
```

(`gTxTimerCountdownAlert_500ms` is set equal to `gTxTimerCountdown_500ms` at TX start,
`radio.c:1172`, so a single decrement counter is the correct model. Consider a comment on
the `DECREMENT*` macros warning that they accept lvalues only.)

### B3 — MDC-1200 feature is half-wired (implicit declaration → C2x hard error)

- `ui/main.c:2411` calls `UI_DisplayMDCAlert()` when `center_line == CENTER_LINE_MDC_ALERT`.
- No prototype exists anywhere (no `ui/mdc.h`; nothing declares the function).
- `ui/mdc.c` (which defines it) is **absent from the Makefile's `OBJS` list**.
- `ui/mdc.c` itself references undefined symbols (`MDC_GetOpcodeString`, `g_MDC_DisplayState`,
  `MDC1200_ENABLE_INTEROP`) that are not defined anywhere in the tree.

With `-std=c2x`, implicit function declarations are hard errors; combined with `-Werror`,
`ui/main.c` fails to compile. Even if it compiled, the link would fail.

**Fix (choose one):**
1. Remove the MDC feature: delete `ui/mdc.c`, remove `CENTER_LINE_MDC_ALERT` handling and
   the call site in `ui/main.c`, and remove the `MENU_MDC_ID` menu entry, **or**
2. Complete the feature: restore the MDC-1200 core module defining `MDC_GetOpcodeString`,
   `g_MDC_DisplayState`, `MDC_TriggerDisplay`, add `ui/mdc.o` + a header prototype, and add
   it to the Makefile `OBJS`.

---

## 3. High-severity findings

### H1 — UART command 0x051B (EEPROM read): stack buffer overflow

`app/uart.c`:

```c
typedef struct {
    Header_t Header;
    struct {
        uint16_t Offset;
        uint8_t  Size;          // ← attacker-controlled byte (0..255)
        uint8_t  Padding;
        uint8_t  Data[128];
    } Data;
} REPLY_051B_t;

...
Reply.Header.Size = pCmd->Size + 4;
...
EEPROM_ReadBuffer(pCmd->Offset, Reply.Data.Data, pCmd->Size);   // Size can be 255
SendReply(&Reply, pCmd->Size + 8);
```

`Reply` lives on the stack and is ~140 bytes total. A host (CHIRP, k5prog, or any hostile
USB-serial peer — the UART is unauthenticated apart from the trivial 16-byte XOR key) can set
`Size` > 128 and smash ~127 bytes of stack through `I2C_ReadBuffer`. This is inherited from
upstream Egzumer, but it is a real, remotely-triggerable vulnerability: on a bare-metal M0 it
overwrites stack contents with no stack canaries.

Additional inconsistencies in the same function: `Reply.Header.Size = pCmd->Size + 4` while
`SendReply` sends `pCmd->Size + 8` bytes; there is no validation that `Offset + Size ≤ 0x2000`
(`EEPROM_ReadBuffer` itself performs no bounds checks, unlike its write sibling in
`driver/eeprom.c`).

**Fix:**


---

## 4. Medium findings

**M1 — `ENABLE_EXTRA_UART_CMD` is never defined ⇒ CHIRP-critical 0x052F compiled out.**
`Makefile:508` tests it, but no `ENABLE_EXTRA_UART_CMD ?=` exists in the option table, so the
default build has no 0x0527/0x0529/0x052D/**0x052F** commands. Upstream Egzumer implements
0x052F (session init: disables dual-watch/cross-band/PTT-ID, backs off power-save) *without*
condition — CHIRP drivers for this family rely on it to configure the serial session. Add
`ENABLE_EXTRA_UART_CMD ?= 1` (or restore 0x052F as unconditional), and verify CHIRP
end-to-end with the packed image.

**M2 — CRC object condition is wrong when both UART and AIRCOPY are enabled.**

```make
ifeq ($(filter $(ENABLE_AIRCOPY) $(ENABLE_UART),1),1)
    OBJS += driver/crc.o
```

With both `=1`, `$(filter 1,1 1)` = `1 1` ≠ `1` → `crc.o` omitted → undefined
`CRC_Calculate` at link. Correct form: `$(filter 1,$(ENABLE_AIRCOPY) $(ENABLE_UART))`.

**M3 — Windows pack step calls `python3` unconditionally** (the `fw-pack.py` invocation at
`Makefile:595`) even though `MY_PYTHON` correctly resolves `python` on Windows. Use
`$(MY_PYTHON)`.

**M6 — Version confusion.** Folder name says `v7.6.0`, `Makefile` `VERSION_STRING_2 = v7.6.6`,
`build/ApeX` artifacts say `v7.6.6`, `EDITION_STRING ?= Custom` while artifacts are named
`ApeX`, and `README.md` self-contradicts ("Version 1 Only" headline vs. a table that lists
UV-K5 v2 and K6 v2+ as supported). Pick one source of truth for the version string and one
hardware-compatibility statement.

**M7 — The `bsp` header generation rule is a no-op stub.**

```make
bsp/dp32g030/%.h: hardware/dp32g030/%.def
```

Empty recipe; headers are never generated from the `.def` files (they are just checked in).
Fine in practice, but it masks the real workflow — either implement it (upstream used a
Python generator) or delete it.

**M8 — `tools/eeprom_selective_sync.py` region map does not match the firmware's map.**
The tool places "ANI DTMF ID" at 0x1F40 while firmware reads it at 0x0EE0 (and its contact
region differs from what `core/settings.c`/the CHIRP driver use). Any merge performed with
this script will silently mismatch regions. Re-derive the region table from the firmware's
actual EEPROM layout and add a self-check.

---

## 5. Low findings / hygiene

- **L1** Root clutter: `battery.o`, `main.o`, `misc.o`, `bitmaps.h`, `misc.h` (shim headers),
  empty `build_log.txt`, `MinGW-w64-setup.exe` (148 KB placeholder?), `utils/misc.exe/.res/.bpr`
  — remove or `.gitignore`.
- **L2** `Documentation/` contains ~35 generated analysis documents (~250 KB) that reference
  code states which no longer match the tree (e.g., `PERFORMANCE_STABILITY_ANALYSIS.md`
  quotes the UART parser and band clamps verbatim). Keep the Owner's Manual + release notes;
  archive or delete generated analysis dumps.
- **L3** Typo: `ENABLE_EXPERIMENTAL_CLFAGS` (works, but will bite anyone grepping for
  `CFLAGS`). Also `-funroll-loops -ffat-lto-objects` is enabled by default — on a 64 KB part
  verify this still fits and actually helps (measure with the build's own size report).
- **L4** `ENABLE_UART_RW_BK_REGS` / 0x0602 allow arbitrary BK4819 register writes over UART —
  default-off; if ever enabled, note it is a full radio-control capability (reg 0x30 selects
  demod/TX modes). Same class: 0x05DD `NVIC_SystemReset()` is accepted from any host with no
  authentication — consistent with upstream, but worth documenting as a deliberate risk.
- **L5** `driver/uart.c: UART_IsCableConnected()` (screenshot feature) scans and *clears*
  bytes from the live DMA RX ring — a screenshot poll can destroy a partially-received UART
  command. Default-disabled; if enabled, coordinate with `UART_IsCommandAvailable`.
- **L6** `driver/uart.c: UART_Send()` busy-waits on TX FIFO — fine, but any `_putchar`/debug
  print in the 10 ms path will stretch the tick; keep `LogUart` calls out of hot paths.
- **L7** `CMD_051B` replies with `Reply.Header.Size = pCmd->Size + 4` while sending
  `pCmd->Size + 8` bytes — cosmetic but CHIRP parses the header; keep them identical to
  upstream behavior after fixing H1.

---

## 6. What is done well (keep these)

1. **Compiler hygiene**: `-Wall -Werror -std=c2x -Oz`, LTO with explicit incompatibility
   interlocks (CLANG/LTO/OVERLAY), `static_assert` on every dispatch table
   (`app/app.c:105`, `ui/ui.c:69`, `radio/frequencies.c:115`, `app/action.c:132`).
2. **UART frame parser** is functionally identical to the battle-tested upstream parser;
   the `% sizeof` → `& 0xFF` optimization is safe (256-byte power-of-two buffer) and
   documented. `SendVersion()` upgraded `strcpy` → bounded `strncpy` (upstream actually had
   an unterminated `strcpy` there).
3. **EEPROM write driver** hardened beyond upstream: NULL check, address < 0x2000,
   8-byte alignment, page-overrun check, and read-compare-before-write (flash wear + I²C
   traffic reduction). `EEPROM_ReadBuffer` still lacks the same bounds (see H1).
4. **Settings clamping** is thorough in `SETTINGS_InitEEPROM()` — nearly every EEPROM byte
   is range-checked with sane fallbacks; TX/RX limits enforced via `frequencyBandTable`
   with `TX_freq_check`/band clamps intact.
5. Clear module layering and consistent Apache-2.0 headers; the `core/` reorganization is an
   improvement over upstream's flat layout; build output reports flash/RAM usage percentages.

---

## 7. Prioritized remediation plan

| Priority | Action | Files |
|----------|--------|-------|
| P0 | Fix B1 (delete Makefile:49) | `Makefile` |
| P0 | Fix B2 (scheduler TOT alert) | `system/scheduler.c` |
| P0 | Fix B3 (remove or complete MDC) | `ui/mdc.c`, `ui/main.c`, `Makefile` |
| P0 | Verify a clean build produces `n7six.ApeX-k5.v*.packed.bin` and that shipped `build/ApeX` binaries match a rebuilt image | CI |
| P1 | H1 bounds checks in `CMD_051B`/`CMD_051D`; consistent reply sizes | `app/uart.c` |
| P1 | Init + feed watchdog (H2) | `system/main.c`, `system/scheduler.c` |
| P1 | `git init` + `.gitignore` + clean baseline (H3) | repo root |
| P1 | Re-enable 0x052F for CHIRP (M1); fix CRC filter (M2) | `Makefile` |
| P2 | M3–M8 (pack script, Makefile portability, DTMF snprintf hardening, versions, EEPROM tool) | various |
| P2 | Full rebuild regression: test UART (k5prog/CHIRP), TX limits at band edges, TOT alert timing, spectrum + waterfall soak test | — |

---

## 8. Verification status

- Findings B1–B3, H1, M1–M6 are verified by direct code inspection (file:line cited).
- No build was executed in this audit (no `make` on the analysis host); P0 items should be
  closed by a real `make clean && make` pass (GCC 10.3 and 14.3 toolchains are installed on
  this machine) before flashing anything from this tree.


**M4 — `debug`/`flash` targets are broken**: they hardcode `firmware.bin` (should be
`$(TARGET).bin`) and `/opt/openocd` Linux paths; the `all` target uses `rm -rf`, `mkdir -p`,
`cp`, `bash -c`, `awk` — the documented Windows path (`win_make.bat` + GnuWin32 make) cannot
execute it. Either document the Linux/Docker-only status or provide portable equivalents.

**M5 — DTMF string stack writes are exactly at capacity and depend on EEPROM termination.**
`gDTMF_String[15]` + `DTMF_SEPARATE_CODE` + `gEeprom.ANI_DTMF_ID[8]` into `char String[23]`
(`app/dtmf.c:433`): 14+1+7+NUL = 23 — exactly fits *only* if both strings are terminated.
`DTMF_ValidateCodes()` (dtmf.c:115) does **not** force termination when all `size` bytes are
valid DTMF characters, so a crafted/corrupt EEPROM can yield unterminated strings feeding
`sprintf` → stack overflow. Harden: force `pCode[size-1] = 0` inside
`DTMF_ValidateCodes`, and prefer `snprintf` everywhere (the revive-code path at dtmf.c:309
already does this correctly — apply the same pattern to lines 354/376/433/449).

```c
if (pCmd->Size > sizeof(Reply.Data.Data))            return;
if ((uint32_t)pCmd->Offset + pCmd->Size > 0x2000)    return;
```

and make the header size, payload size, and `Reply.Data.Size` mutually consistent. Audit
`CMD_051D` the same way: its page loop reads `&pCmd->Data[i*8]` up to byte 259 of the
256-byte command buffer for the maximum legal `Size=248` — a 4-byte OOB read; clamp or
re-copy into an 8-byte page buffer.

### H2 — No watchdog

The DP32G030 provides WWDT/IWDT (IRQ 0/1) but nothing in `system/` or `driver/` configures
it. For a handheld RF device that users cannot power-cycle mid-call, a hang (I²C stall in
`EEPROM_ReadBuffer`, SPI wait-loop in `st7565.c`, BK4819 SPI timeout) renders the radio
dead-silent with PTT possibly still keyed. Recommendation: enable the windowed watchdog with
a period comfortably above the longest I²C/SPI transaction, and feed it from the main loop
only (not from an ISR).

### H3 — Release provenance: no VCS, stale binaries

The directory is not a git repository. Consequences observed:

- `build/ApeX/n7six.ApeX-k5.v7.6.6.bin` (timestamped today) **cannot** come from this source
  tree — B1/B2/B3 would fail the build. The release artifact and the source have drifted.
- No changelog can be verified; `Documentation/COMMITS_MESSAGE.txt` is a hand-written
  substitute for git history.
- Stray objects (`battery.o`, `main.o`, `misc.o`) at the repo root prove ad-hoc single-file
  compilation happened (the root `misc.h`/`bitmaps.h` shim headers were presumably created to
  make such standalone compiles resolve includes — they are confusing and should go).

**Fix:** `git init`, commit a verified buildable baseline, add `.gitignore`
(`*.o *.d *.elf *.bin *.exe build/ build_log.txt`), and rebuild the shipped binaries from
the committed source in CI (`.github/workflows/` exists but contains no usable workflow —
verify on the GitHub side).

**Fix:** delete line 49 (and the stray comment above it suggesting an accidental paste).

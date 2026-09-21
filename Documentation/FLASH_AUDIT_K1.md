# Flash-Size Audit — UV-K1 Spectrum Adoption (v7.6.10)

Full deep review of the flash budget performed before/while adopting the
UV-K1 `spectrum.c` / `spectrum.h` into the ApeX Edition tree.
Toolchain: arm-gnu 14.3 (`-Oz` + single-partition LTO + `--gc-sections`),
clean builds for every measurement.

## 1. The real flash budget

| Item | Bytes |
|---|---|
| Total flash | 65,536 (0x0000–0xFFFF) |
| Bootloader region | 0xF000–0xFFFF (owned by UV-K5/K6 bootloader) |
| **Flashable application image** | **61,440 (0x0000–0xEFFF)** |
| Version block inserted by `fw-pack` | 16 B at 0x2000 + 2 B header (payload is *shifted*, packed = image + 18 B) |

**Critical finding:** the pre-audit Makefile report measured `text` only and
claimed `61388/61439, +51 B margin`. The correct figure is `text + data`
and the actual `.bin` size. The old v7.6.10 image was actually
**61,452 B — 12 B over the real limit before the K1 adoption even started**.
The `all:` report has been fixed to measure text+data and the real `.bin`
size, and to emit a hard warning above 61,440 B.

## 2. Adoption cost

The replaced UV-K1 `spectrum.c/.h`, built with the old default toggles
(shade on; peak/smooth/reg-menu/extras off), produced:

- **61,628 B** → +176 B vs. the old build, **188 B over the limit**.

The bare K1 core (every cosmetic toggle off) was still **61,596 B (+156 over)**,
so always-on K1 refinements had to be extracted into Makefile toggles.

## 3. Toggles found dead in the adopted code

The adopted K1 code **ignored** `ENABLE_SPECTRUM_BIDIR` and
`ENABLE_SPECTRUM_BLACKLIST` (both compiled in unconditionally) and
`ENABLE_RSSI_SQRT` had no `#ifndef` default. The Makefile comment promised
"~400 B saved when BIDIR disabled", which was false. Fixed during this audit:

1. `#ifndef` defaults added for `ENABLE_SPECTRUM_BIDIR`,
   `ENABLE_SPECTRUM_BLACKLIST`, `ENABLE_SPECTRUM_RSSI_SQRT` in `spectrum.c`.
2. Reverse-direction branches guarded (InitScanPosition, ResumeSweepInDirection,
   FinalizeCompletedSweep side-alternation, UpdateScan return-sweep block), so
   `scanForward` / `scanStartFromLeft` / `scanReturnPending` fold to constants
   under LTO when BIDIR=0 (declaration guarded to avoid -Werror unused).
3. `iSqrt` + the sqrt-compression blend in `Rssi2PX()` gated behind
   `ENABLE_SPECTRUM_RSSI_SQRT`.
4. `Blacklist()` + its KEY_SIDE1 call site + the reset scan loop gated behind
   `ENABLE_SPECTRUM_BLACKLIST` (kept compatible with `ENABLE_SCAN_RANGES`).

Guard names match the Makefile `-D` flags exactly.

## 4. Measured toggle costs (post-guard, clean builds, additive to a few bytes)

Spectrum-internal toggles (cost when set to 1):

| Toggle | Δ flash | Notes |
|---|---|---|
| `ENABLE_SPECTRUM_SHADE` | +32 | default ON |
| `ENABLE_SPECTRUM_RSSI_SQRT` | +48 | default OFF (61,444 → 4 B over if on) |
| `ENABLE_SPECTRUM_BIDIR` | +184 | bidirectional sweep |
| `ENABLE_SPECTRUM_BLACKLIST` | +528 | needs `ENABLE_SCAN_RANGES` semantics |
| `ENABLE_SPECTRUM_PEAK_HOLD` + `ENABLE_SPECTRUM_SMOOTH` | +100 combined | bss +192 |
| `ENABLE_SPECTRUM_K1_EXTRAS` | +428 | LNA/PGA/VGA reg menu + persistence; persistence calls the PY25Q16 **stub** on UV-K5/K6 (no external NOR) → dead weight, default OFF |
| `ENABLE_SPECTRUM_REG_MENU` | +712 | |

Tree-level toggles (flash *saved* when turned OFF):

| Toggle | Δ |
|---|---|
| `ENABLE_RSSI_BAR` | −580 |
| `ENABLE_AUDIO_BAR` | −560 |
| `ENABLE_SMALL_BOLD` | −100 |
| `ENABLE_BIG_FREQ` | −92 |
| `ENABLE_FLASHLIGHT` | −76 |
| `ENABLE_CUSTOM_MENU_LAYOUT` | ON is 88 B *smaller* |

## 5. Final default configuration (shipped)

UV-K1 spectrum core + SHADE on; BIDIR / BLACKLIST / REG_MENU / K1_EXTRAS /
PEAK_HOLD / SMOOTH / RSSI_SQRT off; SMALL_BOLD + AUDIO_BAR + RSSI_BAR on.

| Metric | Value |
|---|---|
| text + data | 61,396 B |
| `.bin` image | **61,396 / 61,440 B (99.93%, +44 B margin)** |
| packed image | 61,414 B (fits even with the 16-B version block @0x2000) |
| RAM (data + bss) | 3,372 / 8,192 B |
| Warnings | 0 (`-Wall -Wextra -Werror`) |

## 6. Escalation path (if a new feature needs headroom)

Cheapest, least user-visible first — each is one Makefile variable:

1. `ENABLE_SPECTRUM_SHADE=0` → +32 B
2. `ENABLE_FLASHLIGHT=0` → +76 B
3. `ENABLE_BIG_FREQ=0` → +92 B
4. `ENABLE_SMALL_BOLD=0` → +100 B
5. `ENABLE_SPECTRUM_RSSI_SQRT` stays off (+48 if on)
6. `ENABLE_AUDIO_BAR=0` → +560 B
7. `ENABLE_RSSI_BAR=0` → +580 B

Full "everything on" is **61,424 B over** (62,864 B image) and cannot fit;
cosmetic toggles must give way.

## 7. Audit harness

Reproducible sweep scripts (scratch, `build/` is gitignored):

- `build/audit_k1/mk.cmd` — clean-build wrapper (scrubs objects; make has no
  dependency on CFLAGS, so a flag change would silently reuse stale objects).
- `build/audit_k1/sweep.sh` + `runall.sh` — per-toggle variant builds with
  text/data/bss and real `.bin` margin reporting.
- Logs in `build/audit_k1/*.log`.

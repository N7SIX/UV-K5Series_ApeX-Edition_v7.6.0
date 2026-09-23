# Firmware FLASH Audit — v7.6.10 (ApeX Edition)

**Scope:** Reduce FLASH footprint of `build/ApeX/n7six.ApeX-k5.v7.6.10.bin` **without** disabling features, degrading performance, or changing UI/UX.

## 1. Current Baseline (measured)

| Metric | Value |
|---|---|
| `.bin` image | **61,284 B** (`arm-none-eabi-size`: text 61,224 + data 60) |
| Flash budget | 61,440 B (0x0000–0xEFFF) |
| **Margin** | **156 B (99.62%)** |
| RAM (data + bss) | 3,372 B |
| Toolchain | arm-gnu 14.3, `-Oz` + LTO + `--gc-sections`, `-MMD` |
| Warnings | 0 (`-Wall -Wextra -Werror`) |

> **Note on Makefile/default state:** `RELEASE_NOTES.md` (v7.6.10 entry) records that the prior release cycle already flipped `ENABLE_SMALL_BOLD` and `ENABLE_AUDIO_BAR` to `0` as *defaults*, saving 100 B + 560 B. The `build/ApeX/*.bin` committed artifact was produced with those flags **off**, hence 61,284 B. The current `Makefile` still carries `ENABLE_SMALL_BOLD ?= 1` and `ENABLE_AUDIO_BAR ?= 1` — **this is a latent inconsistency**: a clean `make` from this tree would produce a ~61,944 B image that **overfills** the 61,440 B flash window by ~504 B and trip the size warning. The released binary does not reflect these Makefile defaults.

## 2. Compiler/linker flags — exhausted

Confirmed from `Makefile:374-431` and `FLASH_AUDIT_K1.md §5`:

| Flag | Applied? |
|---|---|
| `-Oz`, `-mcpu=cortex-m0` | ✅ |
| `-ffunction-sections -fdata-sections -Wl,--gc-sections` | ✅ |

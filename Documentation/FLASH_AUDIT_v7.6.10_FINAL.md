# Firmware FLASH Audit — v7.6.10 (ApeX Edition)

> **STATUS: SUPERSEDED (see the correction below).** This file is the
> v7.6.10A-era audit, truncated mid-table in §2 and never updated for
> v7.6.10B. Keep it for the flag-exhaustion history in §2, but take every
> number from `FLASH_AUDIT_K1.md` (UV-K1 spectrum adoption) and from the
> release build. The headline claim in §1 was measured with the wrong
> toolchain and must not be used to justify cutting features.

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

> **CORRECTION to the note that used to sit here.** The previous text called the
> `Makefile` defaults a "latent inconsistency" that would "overfill by ~504 B",
> and advised disabling features on that basis. **That is wrong for the release
> build, and the error was the toolchain, not the Makefile.** With the
> `ENABLE_SMALL_BOLD ?= 1` / `ENABLE_AUDIO_BAR ?= 1` defaults in place, the
> *same* source tree and the *same* flags measure two completely different
> things depending on which GCC compiled it (v7.6.10B, both with 3,564 B RAM,
> which confirms the same object set in both cases):
>
> | Toolchain | image | verdict |
> |---|---|---|
> | `arm-none-eabi-gcc (Alpine Linux) 15.1.0` (Docker = **release**) | **61,364 B** | **fits, 76 B free (99.88%)** |
> | Arm GNU Toolchain 14.3.Rel1 (arm-14.174, local Windows) | 61,984 B | 544 B over |
>
> The local 14.3 toolchain emits ~620 B more code for the identical
> configuration, so the shipping configuration *legitimately* overflows locally
> while it fits in the release build. Nothing needs to be cut, and no Makefile
> default needs to be flipped.
>
> **Consequences, both important:**
> 1. Never decide "does this still fit?" from a local toolchain build — the
>    answer will be wrong by ~620 B. Use `compile-with-docker.sh ApeX`.
> 2. `tools/build_k5.ps1` (the local probe) is now a faithful mirror of the
>    `Makefile` defaults and prints the real number, but it is for A/B deltas
>    and bench flashing only. It carries the same warning in its header.

## 2. Compiler/linker flags — exhausted

Confirmed from `Makefile:374-431` and `FLASH_AUDIT_K1.md §5`:

| Flag | Applied? |
|---|---|
| `-Oz`, `-mcpu=cortex-m0` | ✅ |
| `-ffunction-sections -fdata-sections -Wl,--gc-sections` | ✅ |

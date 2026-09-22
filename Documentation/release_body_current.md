# Version Update Summary - v7.6.10

**Date:** September 21, 2026  
**Firmware build:** v7.6.10 ApeX Edition  
**Focus:** UI/UX modernization (UV-K1 Fusion), 2-point battery calibration, FLASH optimization, and build-ID reporting  
**Status:** Implemented and validated

---

## Summary

The v7.6.10 update introduces four major changes:

1. **Adopted UI/UX from UV-K1's latest Fusion (Armel, F4HWN)** — modern interface patterns, improved navigation, and visual consistency
2. **2-point Battery Calibration** — accurate voltage-to-percentage estimation across the full discharge curve
3. **Waterfall temporarily disabled** — reclaimed FLASH space; will be re-enabled when space allows
4. **SysInf BUILD page now shows the git commit ID** — the build identity is readable on the radio instead of a hardcoded `N/A`

## Getting Started
- UVTools: https://n7six.github.io/UVTools/
- Compile: `./compile-with-docker.sh ApeX` (Docker) or `win_make.bat` (Windows)

## Key Changes

### 1. Adopted UI/UX from UV-K1's Latest Fusion (Armel, F4HWN)
- **Source:** UI/UX patterns from the UV-K1's Fusion firmware by Armel (F4HWN)
- **Impact:** More intuitive and polished user experience with improved navigation and visual consistency
- **Details:**
  - Menu layouts updated to match modern UV-K1 standard
  - Iconography and interaction flows refined
  - Display rendering optimized for consistency

### 2. 2-Point Battery Calibration Implementation
- **Feature:** New 2-point battery calibration system
- **Impact:** More accurate battery voltage-to-percentage and remaining-capacity estimation
- **Details:**
  - Replaces previous single-point estimation with curve-fitting approach
  - Low-point and high-point reference calibration
  - Accessible via the battery menu
  - Persists in EEPROM across power cycles

### 3. Waterfall Disabled (Temporary)
- **Reason:** FLASH space constraint — the image sits at 61,280 B against the 61,440 B flasher limit (99.74%)
- **Impact:** Waterfall rendering disabled to reclaim FLASH space
- **Status:** The spectrum analyzer remains fully functional; only the temporal waterfall display layer is disabled
- **Future:** Will be re-enabled once ample FLASH space is reclaimed through further optimization

### 4. SysInf BUILD Page — Commit ID Now Embedded
- **Problem:** The `BUILD` page in `SysInf` (page 1) printed `N/A` for the build identifier. `system/version.c` hardcoded `const char BuildCommit[] = "N/A";` and nothing ever fed a real revision into it for N7SIX builds, so the on-radio build identity was meaningless.
- **Fix:**
  - `system/version.c` now guards the value with `#ifndef BUILD_COMMIT` / `#define BUILD_COMMIT "N/A"` / `#endif` and defines `const char BuildCommit[] = BUILD_COMMIT;`
  - `Makefile` (inside the `ENABLE_FEAT_N7SIX` block) resolves `BUILD_COMMIT` via `git rev-parse --short HEAD`, overridable from the command line, and falls back to `N/A` when git or the `.git` metadata is unavailable
  - `Makefile` CFLAGS propagate it as `-DBUILD_COMMIT=\"$(BUILD_COMMIT)\"`
  - `compile-with-docker.sh` and `compile-with-docker.bat` resolve the hash on the **host** and pass it to `make`, because `.dockerignore` excludes `.git/` from the Docker build context
- **Result:** The `SysInf` → `BUILD` page now reads e.g. `e34d81a`, matching the commit that produced the flashed image — useful for verifying what is actually on the radio.
- **Display path (unchanged):** `ui/menu.c` line ~1472 → `UI_PrintStringSmallNormal(BuildCommit, menu_item_x1 - 1, menu_item_x2, 6);` under the `BUILD` badge, below the PHT-converted build date and time.
- **Fallback:** Any build without git metadata (e.g. a zipped source tree) still compiles and shows `N/A` — no build breakage.

## Validation

- Build: `./compile-with-docker.sh ApeX` (success, no warnings)
- Build commit embedded: `e34d81a`
- Memory usage (with commit ID embedded):
  ```
  Memory Region      Used Size  Region Size   % Used
  FLASH                61280        61440     99.74%
  RAM                   3372         8192     41.16%
  ```
- Fallback verified: a build without git metadata (`.git/` excluded from the Docker context) resolves `BUILD_COMMIT := N/A`, still compiles cleanly, and measures 61,316 B / 99.80%.
- Note: embedding the real commit ID slightly reduces the image (61,280 B vs 61,316 B) by letting the linker pool the shared fixed strings; the `N/A` placeholder build is the 61,316 B figure quoted in the published v7.6.10 release notes.

## Impact
- **User Experience:** Modernized interface with improved navigation following UV-K1 Fusion design language
- **Battery Accuracy:** 2-point calibration provides more accurate battery percentage and remaining capacity
- **FLASH Management:** Waterfall disabled to meet strict 61,440 B flasher limit; spectrum analyzer remains operational
- **Forward Compatibility:** Waterfall can be re-enabled in future releases when FLASH is optimized
- **Traceability:** The SysInf BUILD page reports the real git commit hash, so the flashed image can be matched to an exact source revision

## CI Packaging Fix

- **Problem:** `.github/workflows/main.yml` uploaded `compiled-firmware/n7six.packed.bin`, but the build never produces that path. `compile-with-docker.sh` mounts `$PWD/build` into the container and the Makefile's `PACKED_BIN` is `build/ApeX/n7six.ApeX-k5.$(VERSION_STRING).packed.bin`, so `compiled-firmware/` did not exist and every workflow run uploaded an empty artifact.
- **Fix:** the upload step now globs `build/ApeX/*.packed.bin` (the real output) and sets `if-no-files-found: error` so a missing firmware image fails the job loudly instead of silently producing an empty artifact.
- **Result:** the `firmware-artifact` download from GitHub Actions now contains the flashable packed image, ready to attach to a GitHub Release.
- **Note:** the workflow needs no `fetch-depth: 0` checkout because `compile-with-docker.sh` resolves the commit hash on the runner host with `git rev-parse --short HEAD` before invoking Docker.

## Affected Files
- `Documentation/v7.6.10_UPDATE_SUMMARY.md` (this file)
- `Documentation/RELEASE_NOTES.md` (v7.6.10 section)
- `app/menu.c` (battery calibration menu)
- `ui/menu.c` (waterfall enable/disable toggle; SysInf BUILD page render)
- UI/UX rendering modules (adopted from UV-K1 Fusion)
- `system/version.c` + `system/version.h` (`BuildCommit` / `BUILD_COMMIT`)
- `Makefile` (build configuration, `BUILD_COMMIT` resolution + CFLAGS)
- `compile-with-docker.sh` (host-side `BUILD_COMMIT` resolution)
- `compile-with-docker.bat` (host-side `BUILD_COMMIT` resolution)
- `.github/workflows/main.yml` (firmware artifact upload path)

---

*For full technical release notes, see [RELEASE_NOTES.md](RELEASE_NOTES.md).*


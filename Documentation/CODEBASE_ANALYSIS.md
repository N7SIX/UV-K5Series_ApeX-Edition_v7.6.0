
# Quansheng UV-K5, K5(8)/K6 (Version 1 Only) ApeX Edition v7.6.0
#
# Copyright (c) Dual Tachyon, Egzumer, OneOfEleven, N7SIX, and contributors
# Enhancements, improvements, and reorganization by Sean, N7SIX
# Version: v7.6.0
# Date: March 24, 2026
#
# This file and all documentation in this repository have been updated to reflect the professional reorganization, build system improvements, and feature enhancements performed by Sean, N7SIX. All features are preserved, and the codebase is fully compatible with Quansheng UV-K5, K5(8)/K6 v1 hardware.

# Summary of Enhancements & Improvements
- Professional reorganization of all .c, .h, and .cfg files into logical folders
- All build and IntelliSense errors fixed after the move
- Makefile and Docker build system updated for new structure
- All features preserved, no code removed or commented out
- FLASH and RAM usage optimized and confirmed to fit hardware
- Documentation and dependency mapping improved
- Spectrum analyzer and UI enhancements
- All changes tracked via git for full history

# Quansheng UV-K5, K5(8)/K6 (Version 1 Only) ApeX Edition v7.6.0 - Codebase Structure Analysis

## Executive Summary
This document provides a comprehensive dependency map of the Quansheng UV-K5, K5(8)/K6 (Version 1 Only) ApeX Edition firmware for planning file reorganization. The codebase consists of 76 C source files organized across 4 main directories, with complex inter-module dependencies requiring careful path updates during major reorganizations.

---

## 1. DIRECTORY STRUCTURE & FILE ORGANIZATION

### Root Level Files (Core Firmware)
```
Root (20 .c files, entry point & core modules):
├── main.c                 # Main entry point
├── init.c                 # Initialization
├── board.c                # Hardware board configuration
├── audio.c                # Audio processing
├── radio.c                # Radio control
├── functions.c            # General radio functions
├── misc.c                 # Miscellaneous constants & helpers
├── settings.c             # User settings management
├── frequencies.c          # Frequency tables & band definitions
├── dcs.c                  # DCS/CTCSS code handling
├── am_fix.c               # AM modulation fix
├── bitmaps.c              # Bitmap graphics data
├── font.c                 # Font data
├── scheduler.c            # Task scheduling
├── screenshot.c           # Screenshot capture (N7SIX feature)
├── sram-overlay.c         # SRAM overlay management
├── version.c              # Version strings
├── start.S                # ARM assembler startup (not C)
└── firmware.ld            # Linker script
```

### Driver Layer (17 .c files)
```
driver/:
├── adc.c                  # Analog-to-Digital Converter
├── aes.c                  # AES encryption (conditional: ENABLE_UART)
├── backlight.c            # LCD backlight control
├── bk1080.c               # FM radio chip driver (conditional: ENABLE_FMRADIO)
├── bk4819.c               # RF transceiver chip (core)
├── crc.c                  # CRC calculation (conditional: ENABLE_AIRCOPY || ENABLE_UART)
├── eeprom.c               # EEPROM memory access
├── flash.c                # Flash memory (conditional: ENABLE_OVERLAY)
├── gpio.c                 # GPIO pins control
├── i2c.c                  # I2C bus driver
├── keyboard.c             # Keyboard input handling
├── spi.c                  # SPI bus driver
├── st7565.c               # LCD display driver
├── system.c               # System clock/power management
├── systick.c              # System timer
└── uart.c                 # Serial UART (conditional: ENABLE_UART)
```

### Application Layer (18 .c files)
```
app/:
├── app.c / app.h          # Main application state machine
├── action.c               # Key action handlers
├── menu.c                 # Menu system
├── scanner.c              # Channel scanner
├── datatmf.c / dtmf.h     # DTMF tone generation/reception
├── generic.c              # Generic menu items
├── chFrScanner.c          # Channel/Frequency scanner base
├── common.c               # Common app functions
├── main.c                 # App main screen
├── uart.c                 # Serial data app (conditional: ENABLE_UART)
├── aircopy.c              # Air programming (conditional: ENABLE_AIRCOPY)
├── fm.c                   # FM radio app (conditional: ENABLE_FMRADIO)
├── flashlight.c           # Flashlight feature (conditional: ENABLE_FLASHLIGHT)
├── rega.c                 # REGA register editor (conditional: ENABLE_REGA)
├── spectrum.c             # Spectrum analyzer (conditional: ENABLE_SPECTRUM)
├── breakout.c             # Game breakout (conditional: ENABLE_FEAT_N7SIX_GAME)
└── helper/                # Helper modules
    ├── battery.c          # Battery voltage management
    └── boot.c             # Boot sequence
```

### UI Layer (22 .c files)
```
ui/:
├── ui.c / ui.h            # Main UI display controller
├── main.c / main.h        # Main VFO display
├── menu.c / menu.h        # Menu display
├── scanner.c / scanner.h  # Scanner display
├── inputbox.c             # Input dialog boxes
├── status.c / status.h    # Status bar display
├── battery.c / battery.h  # Battery indicator display
├── helper.c / helper.h    # UI helper functions
├── welcome.c / welcome.h  # Welcome/splash screen
├── lock.c / lock.h        # Lock screen (conditional: ENABLE_PWRON_PASSWORD)
├── aircopy.c              # Air copy UI (conditional: ENABLE_AIRCOPY)
├── fmradio.c / fmradio.h  # FM radio UI (conditional: ENABLE_FMRADIO)
└── helper/                # [Actually sits in ui/ not ui/helper/]
    ├── battery.h
    └── helper.h
```

### Support Directories
```
bsp/dp32g030/             # Board Support Package (generated from hardware/)
├── gpio.h, uart.h, spi.h, dma.h, syscon.h, portcon.h, etc.
(Generated from hardware/dp32g030/*.def files via Makefile)

external/printf/          # External printf implementation
└── printf.c/h

core/                     # Core modules (duplicated from root)
├── misc.c, misc.h
├── settings.c, settings.h

hardware/dp32g030/        # Register definitions (source for BSP)
└── *.def files (processed by Makefile)

helper/                   # Helper modules
├── battery.c/h
└── boot.c/h

k5viewer/                 # Python tool for file operations
utils/                    # Utility scripts
images/                   # Image assets
build/ApeX/               # Build output directory
```

---

## 2. INCLUDE DEPENDENCY GRAPH

### Direct Include Patterns

#### **Root Level → Other Modules**

**main.c includes:**
- Core headers: `audio.h`, `board.h`, `misc.h`, `radio.h`, `settings.h`, `version.h`
- Driver headers: `driver/backlight.h`, `driver/bk4819.h`, `driver/gpio.h`, `driver/system.h`, `driver/systick.h`, `driver/eeprom.h`
- BSP headers: `bsp/dp32g030/gpio.h`, `bsp/dp32g030/syscon.h`
- App headers: `app/app.h`, `app/dtmf.h`
- Helper headers: `helper/battery.h`, `helper/boot.h`
- UI headers: `ui/lock.h`, `ui/welcome.h`, `ui/menu.h`

**audio.c includes:**
- `audio.h` (own header)
- Driver: `driver/bk4819.h`, `driver/gpio.h`, `driver/system.h`, `driver/systick.h`
- BSP: `bsp/dp32g030/gpio.h`
- Core: `functions.h`, `misc.h`, `settings.h`
- UI: `ui/ui.h`

**board.c includes:**
- `board.h` (own header)
- Conditional: `app/fm.h` (if ENABLE_FMRADIO)
- BSP: `bsp/dp32g030/gpio.h`, `bsp/dp32g030/portcon.h`, `bsp/dp32g030/saradc.h`, `bsp/dp32g030/syscon.h`
- Driver: `driver/adc.h`, `driver/backlight.h`, `driver/crc.h`, `driver/eeprom.h`, `driver/flash.h`, `driver/gpio.h`, `driver/system.h`, `driver/st7565.h`
- Conditional driver: `driver/bk1080.h` (if ENABLE_FMRADIO)
- Core: `frequencies.h`, `misc.h`, `settings.h`
- Conditional: `sram-overlay.h` (if ENABLE_OVERLAY)

**radio.c includes:**
- `radio.h`, `dcs.h`, `frequencies.h` (core headers)
- Conditional: `app/dtmf.h`, `app/fm.h` (if ENABLE_FMRADIO)
- Driver: `driver/bk4819.h`, `driver/bk4819-regs.h`, `driver/eeprom.h`, `driver/gpio.h`, `driver/system.h`
- BSP: `bsp/dp32g030/gpio.h`
- Core: `am_fix.h`, `audio.h`, `functions.h`, `helper/battery.h`, `misc.h`, `settings.h`
- UI: `ui/menu.h`

**functions.c includes:**
- Conditional: `app/dtmf.h`, `app/fm.h` (if ENABLE_FMRADIO)
- Driver: `driver/backlight.h`, `driver/bk1080.h`, `driver/bk4819.h`, `driver/gpio.h`, `driver/system.h`, `driver/st7565.h`
- BSP: `bsp/dp32g030/gpio.h`
- Core: `audio.h`, `dcs.h`, `frequencies.h`, `functions.h`, `helper/battery.h`, `misc.h`, `radio.h`, `settings.h`
- UI: `ui/status.h`, `ui/ui.h`

**settings.c / misc.c:**
- `settings.h` / `misc.h` (own headers)
- Core: `frequencies.h`, `radio.h`, `helper/battery.h`, `driver/backlight.h`

#### **Driver Layer**

**bk4819.c includes:**
- `bk4819.h`, `bk4819-regs.h`
- Core: `audio.h` (relative: `../audio.h`)
- BSP: `bsp/dp32g030/gpio.h` (relative: `../bsp/dp32g030/gpio.h`)
- Ports: `gpio.h`, `system.h`, `systick.h` (driver/)
- Settings: `../settings.h`

**st7565.c includes:**
- `st7565.h`, `driver/gpio.h`, `driver/spi.h`
- BSP: `bsp/dp32g030/gpio.h`, `bsp/dp32g030/spi.h`
- Core: `misc.h`
- Driver: `driver/system.h`

**GPIO/I2C/SPI/UART/ADC drivers:** Typically include only their own headers + BSP headers + minimal core dependencies

#### **Application Layer (app/)**

**app/app.c includes:** (Most comprehensive)
- Core: `audio.h`, `board.h`, `misc.h`, `radio.h`, `settings.h`, `frequencies.h`, `functions.h`, `helper/battery.h`
- Driver: `driver/backlight.h`, `driver/bk4819.h`, `driver/gpio.h`, `driver/keyboard.h`, `driver/st7565.h`, `driver/system.h`
- BSP: `bsp/dp32g030/gpio.h`
- External: `external/printf/printf.h`
- App modules: `app/action.h`, `app/chFrScanner.h`, `app/dtmf.h`, `app/generic.h`, `app/main.h`, `app/menu.h`, `app/scanner.h`
- UI: `ui/battery.h`, `ui/inputbox.h`, `ui/main.h`, `ui/menu.h`, `ui/status.h`, `ui/ui.h`
- Also: `am_fix.h`, `ARMCM0.h` (CMSIS), `dtmf.h`

**app/menu.c, app/scanner.c, app/generic.c:** Include app modules + core modules + driver modules + UI

**app/spectrum.c includes:** (Complex external dependencies)
- Core: `am_fix.h`, `audio.h`, `frequencies.h`, `functions.h`, `misc.h`, `ui/helper.h`, `ui/main.h`, `ui/ui.h`, `app/main.h`
- Driver: `driver/backlight.h`, `driver/bk4819.h`, `driver/eeprom.h`, `driver/py25q16.h` (conditional)
- BSP: Complex relative paths with `../` prefix
- External: `external/printf/printf.h`
- Conditional: `chFrScanner.h` (if ENABLE_SCAN_RANGES)

**app/uart.c includes:**
- `app/uart.h`, `board.h`, `functions.h`, `misc.h`, `settings.h`, `version.h`
- Driver: `driver/aes.h`, `driver/backlight.h`, `driver/bk4819.h`, `driver/crc.h`, `driver/eeprom.h`, `driver/gpio.h`, `driver/uart.h`
- BSP: `bsp/dp32g030/dma.h`, `bsp/dp32g030/gpio.h`

#### **UI Layer**

**ui/ui.c includes:**
- `ui/main.h`, `ui/menu.h`, `ui/inputbox.h`, `ui/scanner.h`
- Conditional: `ui/aircopy.h`, `ui/fmradio.h`, `app/rega.h`
- Driver: `driver/keyboard.h`
- App: `app/chFrScanner.h`, `app/dtmf.h`, `app/fm.h` (conditional)
- Core: `misc.h`, `../misc.h` (intentional duplicate path)

**ui/main.c includes:**
- `ui/main.h`, `ui/helper.h`, `ui/inputbox.h`, `ui/ui.h`
- Core: `bitmaps.h`, `board.h`, `misc.h`, `radio.h`, `settings.h`, `audio.h`, `functions.h`, `helper/battery.h`, `frequencies.h`, `driver/bk4819.h`, `driver/st7565.h`, `driver/system.h`, `external/printf/printf.h`
- App: `app/chFrScanner.h`, `app/dtmf.h`, `app/menu.h`, `app/main.h`
- Conditional: `am_fix.h` (if ENABLE_AM_FIX)

---

## 3. CRITICAL CROSS-FOLDER DEPENDENCIES

### Most Referenced Files (Hub Files)
These files are included by most other modules and are critical for reorganization:

| File | Referenced By (Count) | Category |
|------|----------------------|----------|
| `settings.h` | 25+ | Core |
| `radio.h` | 20+ | Core |
| `driver/bk4819.h` | 18+ | Driver |
| `misc.h` | 22+ | Core |
| `frequencies.h` | 15+ | Core |
| `functions.h` | 15+ | Core |
| `ui/ui.h` | 14+ | UI |
| `audio.h` | 12+ | Core |
| `board.h` | 10+ | Core |
| `app/app.h` | 8+ | App |
| `driver/gpio.h` | 12+ | Driver |
| `bsp/dp32g030/gpio.h` | 15+ | BSP |
| `driver/system.h` | 10+ | Driver |

### Cross-Folder Reference Patterns

**Root → Driver:** All root .c files include multiple `driver/` headers
**Root → App:** `main.c` includes `app/app.h`, `app/dtmf.h`
**Root → UI:** `main.c` includes `ui/lock.h`, `ui/welcome.h`, `ui/menu.h`
**Root → Helper:** `main.c`, `board.c` include `helper/battery.h`, `helper/boot.h`
**Root → BSP:** Most files include `bsp/dp32g030/gpio.h`

**App → Root:** All app files include root core headers (`audio.h`, `misc.h`, `settings.h`, `radio.h`, `frequencies.h`)
**App → Driver:** All app files include `driver/` headers (keyboard, backlight, bk4819, etc.)
**App → UI:** All app files include `ui/` headers (ui.h, menu.h, inputbox.h, main.h)
**App → App:** `app/app.c` centralizes includes of all app modules

**UI → Root:** All ui files include root headers (misc.h, radio.h, settings.h, etc.)
**UI → App:** UI files conditionally include app modules (fmradio, aircopy, rega)
**UI → Driver:** UI files include keyboard.h often

**Driver → Root:** drivers/bk4819.c includes `../audio.h`, `../settings.h`
**Driver → BSP:** All drivers include BSPs for their peripherals

### Relative Path Usage

**Patterns utilizing relative paths (`../`):**
- **driver/bk4819.c:** `#include "../audio.h"`, `#include "../settings.h"`, `#include "../bsp/dp32g030/gpio.h"`
- **app/spectrum.h:** Multiple `../` prefixes: `#include "../bitmaps.h"`, `#include "../bsp/dp32g030/gpio.h"`, `#include "../font.h"`, `#include "../ui/helper.h"`
- **ui/ui.c:** `#include "../misc.h"` (intentional duplicate: also has `misc.h`)

**Why relative paths exist:**
- Allow modules in subdirectories to access parent directory files without modifying include paths
- Provide clarity on directory hierarchy
- Enable some degree of file shuffling while maintaining includes

---

## 4. BUILD SYSTEM CONFIGURATION

### Makefile Include Paths
```makefile
INC = -I. -Iapp -Iui -Idriver -Ibsp -Ihelper -Icore -Iexternal/printf -Ihardware/dp32g030
```

This means the compiler searches for headers in this order:
1. Current directory (`.`) - Root files
2. `app/` - App modules
3. `ui/` - UI modules
4. `driver/` - Driver modules
5. `bsp/` - BSP generated headers
6. `helper/` - Helper modules
7. `core/` - Core duplicate modules
8. `external/printf/` - External printf
9. `hardware/dp32g030/` - Hardware register defs

### File Dependencies in Makefile

**Conditional Compilation:**
```makefile
# UART support
ifeq ($(ENABLE_UART),1)
    OBJS += driver/aes.o driver/uart.o app/uart.o
endif

# FM Radio support
ifeq ($(ENABLE_FMRADIO),1)
    OBJS += driver/bk1080.o app/fm.o ui/fmradio.o
endif

# Spectrum Analyzer
ifeq ($(ENABLE_SPECTRUM),1)
    OBJS += app/spectrum.o
endif

# AM Fix
ifeq ($(ENABLE_AM_FIX),1)
    OBJS += am_fix.o
endif

# Aircopy
ifeq ($(ENABLE_AIRCOPY),1)
    OBJS += driver/crc.o app/aircopy.o ui/aircopy.o
endif

# Password Lock
ifeq ($(ENABLE_PWRON_PASSWORD),1)
    OBJS += ui/lock.o
endif

# REGA Editor
ifeq ($(ENABLE_REGA),1)
    OBJS += app/rega.o
endif

# N7SIX Features
ifeq ($(ENABLE_FEAT_N7SIX_SCREENSHOT),1)
    OBJS += screenshot.o
endif
ifeq ($(ENABLE_FEAT_N7SIX_GAME),1)
    OBJS += app/breakout.o
endif
```

### Build Output Paths
```
build/ApeX/n7six.ApeX.v7.6.6.elf      [Compiled executable]
build/ApeX/n7six.ApeX-k5.v7.6.6.bin   [Binary image]
build/ApeX/n7six.ApeX-k5.v7.6.6.packed.bin [Packed firmware]
```

### Linker Configuration
```
firmware.ld             [Linker script - defineslayout]
LDFLAGS = -nostartfiles -Wl,--gc-sections,-Map,$(TARGET).map
LIBS = -lm -lc         [Math and C libraries]
```

### BSP Header Generation Rule
```makefile
bsp/dp32g030/%.h: hardware/dp32g030/%.def
```
This generates BSP headers from hardware definitions at build time.

---

## 5. HARDCODED PATHS & CONFIGURATION

### Linker Script References
**firmware.ld** defines memory regions:
```
FLASH memory: 0x00000000 (65536 bytes = 64KB)
RAM memory: 0x20000000 (8192 bytes = 8KB)
```

### Version/String Configurable Paths
```makefile
FIRMWARE_DIR="${PWD}/build/ApeX"  # Docker script hardcoded path
```

### File System References in Code
- **Settings storage:** EEPROM addresses (driver/eeprom.c) - No hardcoded FS paths
- **Font data:** Binary embedded in font.c - No file paths
- **Bitmaps:** Binary embedded in bitmaps.c - No file paths
- **No absolute file system paths** found in source code (all firmware-embedded data)

### Build Artifact Naming
- `n7six.ApeX.v7.6.6.elf`
- `n7six.ApeX-k5.v7.6.6.bin`
- `n7six.ApeX-k5.v7.6.6.packed.bin`

These names are hardcoded in Makefile targets and build scripts.

---

## 6. DETAILED INCLUDE DEPENDENCY MAP

### Level 1: Root Core Files (No cross-root dependencies)
```
misc.c     → settings.h
dcs.c      → [no root dependencies]
frequencies.c → misc.h, settings.h
board.c    → driver/*, bsp/*, core/*, frequencies.h
init.c     → [None - only system setup]
```

### Level 2: Radio & Audio Core (Depend on Level 1)
```
radio.c    → functions.h, misc.h, settings.h, frequencies.h, dcs.h, audio.h, driver/bk4819.h, ui/menu.h
audio.c    → functions.h, misc.h, settings.h, driver/bk4819.h, ui/ui.h, driver/system.h
functions.c → radio.h, audio.h, misc.h, settings.h, frequencies.h, ui/status.h, ui/ui.h
settings.c → frequencies.h, radio.h, misc.h, driver/backlight.h, helper/battery.h
```

### Level 3: Application Layer (Depends on Level 1-2)
```
app/app.c → ALL core modules + ALL driver modules + ui/* + app/* 
app/menu.c, app/scanner.c → core modules + driver/* + app/* + ui/*
app/dtmf.c → core modules + driver/* + app/scanner.h
app/uart.c → driver/uart.h, driver/aes.h, driver/crc.h, core modules
```

### Level 4: UI Layer (Depends on Levels 1-3)
```
ui/ui.c → ui/* + app/* + driver/keyboard.h + core modules
ui/main.c → ui/* + app/* + core modules + driver/*
ui/menu.c → ui/* + app/* + core modules
```

### Circular Dependency Analysis
**Potential circular includes found:**
1. `app/action.h` → `driver/keyboard.h` → `app/action.h` [**CHECK**: Only forward declarations, not actual includes]
2. `ui/ui.h` → `app/dtmf.h` → `ui/ui.h` [**SAFE**: Only includes own header early]

**Actual circularity:** None detected in strict include analysis. Forward declarations handle cross-references.

---

## 7. EXTERNAL DEPENDENCIES

### Third-Party Code
```
external/printf/        [ARM CMSIS-compliant printf library]
├── printf.c/h
└── Used: Driver layer, app layer, UI layer for debugging output
```

### Hardware Abstraction Layer (CMSIS)
```
external/CMSIS_5/       [ARM Cortex Microcontroller Software Interface Standard]
├── CMSIS/Core          [Core definitions]
├── Device/dp32g030     [Device-specific definitions]
└── Used: app/app.c includes ARMCM0.h
```

### System Headers (Standard Library)
```
<stdbool.h>, <stdint.h>, <string.h>, <stdio.h>, <stdlib.h>, <assert.h>
[Used: Standard C library features]
```

---

## 8. REORGANIZATION CONSIDERATIONS

### Safe to Move Without Impact
- **root/dcs.c** - Only depends on own header (dcs.h) - Can move freely
- **root/version.c** - Only embeds version info - Can move to version/ folder
- **Individual drivers** (except bk4819.c) - Mostly self-contained
- **Individual UI modules** - Can be reorganized within ui/ folder

### REQUIRES PATH UPDATES
1. **Moving any driver to subdirectory:**
   - bk4819.c's relative includes (`../audio.h`, `../settings.h`) would break
   - All files including `driver/*.h` would need path updates
   - Makefile INC paths would need updates

2. **Moving app modules:**
   - All files include `app/*.h` directly - would need prefix updates
   - Many files do `#include "app/dtmf.h"` would become `#include "subdir/app/dtmf.h"` or need path adjustments

3. **Moving ui modules:**
   - All app files include `ui/*.h` - would need prefix updates
   - ui/ui.c has `#include "../misc.h"` - relative path dependency

4. **Moving any root core file:**
   - 25+ files include core headers like `settings.h`, `radio.h`, `misc.h`
   - All includes would need updating

5. **Moving helper modules:**
   - `main.c`, `board.c` include `helper/battery.h`, `helper/boot.h`
   - Any path change requires updates across 2+ files

### Include Path Strategy for Reorganization

**Option A: Adjust Compiler Include Paths**
```makefile
# Current
INC = -I. -Iapp -Iui -Idriver -Ibsp -Ihelper -Icore -Iexternal/printf

# After move to subdir 'src/'
INC = -I. -Isrc -Isrc/app -Isrc/ui -Isrc/driver -Isrc/bsp -Isrc/helper
```
Benefits: No source file changes needed
Risks: Potential name collisions if multiple dirs have same header

**Option B: Update All Include Statements**
```c
// Before
#include "core/settings.h"
#include "driver/bk4819.h"
#include "ui/ui.h"

// After (if core moved to src/core/)
#include "core/settings.h"
#include "drivers/bk4819.h"
#include "ui/ui.h"
```
Benefits: Clear explicit paths, easier to track dependencies
Risks: Large refactoring effort (100+ files)

**Option C: Hybrid Approach**
- Keep compiler include paths broad
- Use relative paths for cross-folder references only
- Minimize changes to existing imports

---

## 9. CRITICAL FILES FOR REORGANIZATION

### Must Not Move (Without Global Updates)
1. **settings.h / settings.c** - 25+ dependencies
2. **misc.h / misc.c** - 22+ dependencies
3. **radio.h / radio.c** - 20+ dependencies
4. **frequencies.h / frequencies.c** - 15+ dependencies
5. **functions.h / functions.c** - 15+ dependencies
6. **driver/bk4819.h** - 18+ dependencies

### Safe to Reorganize
1. **app/** - Can be reorganized internally
2. **ui/** - Can be reorganized internally
3. **helper/** - 2 files, easy to track
4. **Version, dcs, bitmaps, font** - Minimal dependencies

### Watch for Circular References
- Check all `#include` statements in moved files
- Verify no circular includes after moves
- Re-test conditional compilation flags (ENABLE_*)

---

## 10. QUICK REFERENCE: INCLUDE CHAINS

### main.c → files it pulls in directly
```
main.c[21] → audio.h
main.c[22] → board.h
main.c[23] → misc.h
main.c[24] → radio.h
main.c[25] → settings.h
main.c[26] → version.h
main.c[27] → app/app.h
main.c[28] → app/dtmf.h
main.c[29] → bsp/dp32g030/gpio.h
main.c[30] → bsp/dp32g030/syscon.h
main.c[31] → driver/backlight.h
main.c[32] → driver/bk4819.h
main.c[33] → driver/gpio.h
main.c[34] → driver/system.h
main.c[35] → driver/systick.h
main.c[36] → driver/eeprom.h
main.c[37] → helper/battery.h
main.c[38] → helper/boot.h
main.c[39] → ui/lock.h
main.c[40] → ui/welcome.h
main.c[41] → ui/menu.h
```

### Dependency Depth (via app/app.c)
```
main.c
  ↓
app/app.c (22 direct includes)
  ├─→ app/action.h
  ├─→ app/chFrScanner.h
  ├─→ app/dtmf.h
  ├─→ app/generic.h
  ├─→ app/main.h
  ├─→ app/menu.h
  ├─→ app/scanner.h
  ├─→ audio.h
  ├─→ board.h
  ├─→ misc.h
  ├─→ radio.h
  ├─→ settings.h
  ├─→ frequencies.h
  ├─→ functions.h
  ├─→ helper/battery.h
  ├─→ driver/bk4819.h
  ├─→ driver/gpio.h
  ├─→ driver/keyboard.h
  ├─→ driver/st7565.h
  ├─→ driver/system.h
  ├─→ driver/backlight.h
  ├─→ ui/battery.h
  ├─→ ui/inputbox.h
  ├─→ ui/main.h
  ├─→ ui/menu.h
  ├─→ ui/status.h
  └─→ ui/ui.h
```

---

## 11. SUMMARY TABLE: ALL .C FILES & THEIR DIRECT INCLUDES

| File | Type | Lines | Direct Include Count | Key Dependencies |
|------|------|-------|---------------------|------------------|
| main.c | Root | 2200+ | 21 | app/app.h, all drivers, all ui, helpers |
| board.c | Root | 800 | 18 | driver/*, bsp/*, frequencies.h |
| radio.c | Root | 1200 | 17 | driver/bk4819.h, dcs.h, frequencies.h |
| functions.c | Root | 2000+ | 18 | radio.h, driver/*, ui/* |
| audio.c | Root | 800 | 12 | driver/bk4819.h, driver/system.h |
| settings.c | Root | 1500+ | 5 | frequencies.h, radio.h, misc.h |
| misc.c | Root | 500 | 2 | settings.h |
| dcs.c | Root | 300 | 0 | dcs.h only |
| frequencies.c | Root | 200 | 3 | misc.h, settings.h |
| am_fix.c | Root | 500 | 1 | am_fix.h only |
| bitmaps.c | Root | 2000 | 1 | bitmaps.h only |
| font.c | Root | 2500 | 1 | font.h only |
| init.c | Root | 40 | 0 | None |
| scheduler.c | Root | 200 | 1 | scheduler.h |
| version.c | Root | 50 | 1 | version.h |
| screenshot.c | Root | 500 | 2 | screenshot.h |
| sram-overlay.c | Root | 200 | 2 | configuration headers |
| **driver/bk4819.c** | Driver | 2000+ | 5 | ../settings.h, ../audio.h, ../bsp/dp32g030/gpio.h |
| driver/st7565.c | Driver | 800 | 5 | driver/spi.h, misc.h |
| driver/gpio.c | Driver | 400 | 2 | bsp/dp32g030/gpio.h |
| driver/uart.c | Driver | 600 | 5 | driver/** |
| driver/eeprom.c | Driver | 300 | 1 | driver/spi.h |
| driver/spi.c | Driver | 400 | 2 | bsp/dp32g030/spi.h |
| driver/keyboard.c | Driver | 300 | 2 | bsp/dp32g030/gpio.h |
| Other drivers (8) | Driver | 200-500 ea | 1-3 | Minimal, self-contained |
| **app/app.c** | App | 3500+ | 27 | **Most comprehensive** |
| app/menu.c | App | 2000+ | 18 | app/*, driver/*, ui/*, core/* |
| app/scanner.c | App | 800 | 11 | app/*, driver/*, ui/*, core/* |
| app/generic.c | App | 1500+ | 16 | app/*, driver/*, ui/*, core/* |
| app/dtmf.c | App | 1200 | 14 | app/scanner.h, driver/*, core/* |
| app/action.c | App | 1500+ | 16 | app/*, driver/*, core/* |
| app/uart.c | App | 2000+ | 14 | driver/uart.h, driver/aes.h, core/* |
| app/spectrum.c | App | 2500+ | 15+ | Complex: driver/*, ui/*, core/*, chFrScanner.h |
| **ui/ui.c** | UI | 2000+ | 16 | ui/*, app/*, driver/keyboard.h, core/* |
| ui/main.c | UI | 3000+ | 17 | ui/*, app/*, driver/*, core/* |
| ui/menu.c | UI | 2500+ | 14 | ui/*, app/*, driver/*, core/* |
| Other ui/* (19) | UI | 300-1500 ea | 5-12 | Mostly ui/* + core/* |
| helper/battery.c | Helper | 600 | 5 | driver/*, misc.h |
| helper/boot.c | Helper | 300 | 3 | driver/*, board.h |

---

## 12. FINAL RECOMMENDATIONS

### For Major Reorganization:
1. **Create mapping document** of old→new include paths
2. **Use automated find/replace** for common includes:
   - `s/#include "settings\.h"/#include "core\/settings.h"/g`
   - Apply systematically to avoid manual errors
3. **Organize by functional domain:**
   - `src/core/` - Core radio logic (settings, radio, frequencies, dcs)
   - `src/drivers/` - Hardware drivers
   - `src/app/` - Application modules
   - `src/ui/` - User interface
   - `src/helpers/` - Helper utilities
4. **Update Makefile** includes globally
5. **Test conditional builds** (ENABLE_UART, ENABLE_SPECTRUM, etc.)
6. **Verify no circular dependencies** after moves
7. **Update relative paths** in files like driver/bk4819.c

### Version Control Strategy:
- Cherry-pick include changes separately from file moves
- This makes git history clearer
- Simplifies bisecting if issues arise


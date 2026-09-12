
# UV-K5Series ApeX Edition v7.6.0
#
# Copyright (c) Dual Tachyon, Egzumer, OneOfEleven, N7SIX, and contributors
# Enhancements, improvements, and reorganization by Sean, N7SIX
# Version: v7.6.0
# Date: March 24, 2026
#
# This file and all documentation in this repository have been updated to reflect the professional reorganization, build system improvements, and feature enhancements performed by Sean, N7SIX. All features are preserved, and the codebase is fully compatible with Quansheng UV-K5, K5(8)/K6 (Version 1 Only) hardware.

# Summary of Enhancements & Improvements
- Professional reorganization of all .c, .h, and .cfg files into logical folders
- All build and IntelliSense errors fixed after the move
- Makefile and Docker build system updated for new structure
- All features preserved, no code removed or commented out
- FLASH and RAM usage optimized and confirmed to fit hardware
- Documentation and dependency mapping improved
- Spectrum analyzer and UI enhancements
- All changes tracked via git for full history

# UV-K5 ApeX v7.6.0 - Include Dependency Reference Map

## Format: file.c → [includes] | {conditionals}

---

## ROOT LEVEL (20 .c files)

```
main.c
  → audio.h, board.h, misc.h, radio.h, settings.h, version.h
  → app/app.h, app/dtmf.h
  → bsp/dp32g030/gpio.h, bsp/dp32g030/syscon.h
  → driver/backlight.h, driver/bk4819.h, driver/gpio.h, driver/system.h, driver/systick.h, driver/eeprom.h
  → helper/battery.h, helper/boot.h
  → ui/lock.h, ui/welcome.h, ui/menu.h

audio.c
  → audio.h
  → bsp/dp32g030/gpio.h
  → driver/bk4819.h, driver/gpio.h, driver/system.h, driver/systick.h
  → functions.h, misc.h, settings.h
  → ui/ui.h

board.c
  → board.h
  → bsp/dp32g030/gpio.h, bsp/dp32g030/portcon.h, bsp/dp32g030/saradc.h, bsp/dp32g030/syscon.h
  → driver/adc.h, driver/backlight.h, driver/crc.h, driver/eeprom.h, driver/flash.h, driver/gpio.h, driver/system.h, driver/st7565.h
  → driver/bk1080.h {ENABLE_FMRADIO}
  → frequencies.h, misc.h, settings.h
  → app/fm.h {ENABLE_FMRADIO}
  → sram-overlay.h {ENABLE_OVERLAY}

radio.c
  → driver/bk4819-regs.h
  → am_fix.h, app/dtmf.h, app/fm.h {ENABLE_FMRADIO}
  → audio.h, bsp/dp32g030/gpio.h, dcs.h, driver/bk4819.h, driver/eeprom.h, driver/gpio.h, driver/system.h
  → frequencies.h, functions.h, helper/battery.h, misc.h, radio.h, settings.h
  → ui/menu.h

functions.c
  → app/dtmf.h, app/fm.h {ENABLE_FMRADIO}
  → audio.h, bsp/dp32g030/gpio.h, dcs.h
  → driver/backlight.h, driver/bk1080.h {ENABLE_FMRADIO}, driver/bk4819.h, driver/gpio.h, driver/system.h, driver/st7565.h
  → frequencies.h, functions.h, helper/battery.h, misc.h, radio.h, settings.h
  → ui/status.h, ui/ui.h

misc.c
  → misc.h, settings.h

dcs.c
  → dcs.h

frequencies.c
  → frequencies.h, misc.h, settings.h

settings.c
  → settings.h
  → frequencies.h
  → helper/battery.h {implied by header}
  → radio.h
  → driver/backlight.h {implied by header}

am_fix.c
  → am_fix.h

bitmaps.c
  → bitmaps.h

font.c
  → font.h

init.c
  → [No local includes]

scheduler.c
  → scheduler.h

screenshot.c
  → screenshot.h

sram-overlay.c
  → sram-overlay.h

version.c
  → version.h
```

---

## DRIVER LAYER (17 .c files)

```
driver/bk4819.c
  → bk4819.h
  → ../audio.h
  → ../bsp/dp32g030/gpio.h
  → ../settings.h
  → ../bsp/dp32g030/portcon.h
  → driver/gpio.h, driver/system.h, driver/systick.h
  → misc.h

driver/st7565.c
  → bsp/dp32g030/gpio.h, bsp/dp32g030/spi.h
  → driver/gpio.h, driver/spi.h, driver/st7565.h, driver/system.h
  → misc.h

driver/adc.c
  → bsp/dp32g030/saradc.h, bsp/dp32g030/syscon.h
  → driver/adc.h, driver/gpio.h

driver/aes.c
  → driver/aes.h {ENABLE_UART}
  → [Minimal]

driver/backlight.c
  → bsp/dp32g030/gpio.h, bsp/dp32g030/syscon.h
  → driver/backlight.h, driver/gpio.h

driver/bk1080.c
  → bsp/dp32g030/gpio.h {ENABLE_FMRADIO}
  → driver/bk1080.h, driver/bk1080-regs.h, driver/gpio.h, driver/i2c.h, driver/system.h

driver/crc.c
  → driver/crc.h {ENABLE_AIRCOPY || ENABLE_UART}

driver/eeprom.c
  → driver/eeprom.h, driver/spi.h

driver/flash.c
  → driver/flash.h {ENABLE_OVERLAY}
  → bsp/dp32g030/flash.h, bsp/dp32g030/syscon.h

driver/gpio.c
  → bsp/dp32g030/gpio.h
  → driver/gpio.h

driver/i2c.c
  → bsp/dp32g030/gpio.h
  → driver/gpio.h, driver/i2c.h

driver/keyboard.c
  → bsp/dp32g030/gpio.h
  → driver/gpio.h, driver/keyboard.h, driver/systick.h

driver/spi.c
  → bsp/dp32g030/spi.h
  → driver/gpio.h, driver/spi.h, driver/system.h

driver/system.c
  → bsp/dp32g030/syscon.h
  → driver/system.h

driver/systick.c
  → driver/systick.h

driver/uart.c
  → driver/uart.h {ENABLE_UART}
  → bsp/dp32g030/uart.h, bsp/dp32g030/gpio.h
  → driver/gpio.h
```

---

## APPLICATION LAYER (18 .c files)

```
app/app.c
  → am_fix.h
  → app/action.h, app/app.h, app/chFrScanner.h, app/dtmf.h, app/generic.h, app/main.h, app/menu.h, app/scanner.h
  → ARMCM0.h {CMSIS}
  → audio.h, board.h, bsp/dp32g030/gpio.h
  → driver/backlight.h, driver/bk4819.h, driver/gpio.h, driver/keyboard.h, driver/st7565.h, driver/system.h
  → dtmf.h, external/printf/printf.h, frequencies.h, functions.h
  → helper/battery.h
  → misc.h, radio.h, settings.h
  → ui/battery.h, ui/inputbox.h, ui/main.h, ui/menu.h, ui/status.h, ui/ui.h

app/action.c
  → app/action.h, app/app.h, app/chFrScanner.h, app/common.h, app/dtmf.h, app/flashlight.h {ENABLE_FLASHLIGHT}, app/fm.h {ENABLE_FMRADIO}, app/scanner.h
  → audio.h, bsp/dp32g030/gpio.h
  → driver/backlight.h, driver/bk1080.h {ENABLE_FMRADIO}, driver/bk4819.h, driver/gpio.h, driver/keyboard.h
  → functions.h, misc.h, settings.h
  → app/rega.h {ENABLE_REGA}
  → ui/inputbox.h, ui/ui.h

app/menu.c
  → app/dtmf.h, app/generic.h, app/menu.h, app/scanner.h
  → audio.h, board.h, bsp/dp32g030/gpio.h
  → driver/backlight.h, driver/bk4819.h, driver/eeprom.h, driver/gpio.h, driver/keyboard.h
  → frequencies.h, helper/battery.h, misc.h, settings.h
  → ui/inputbox.h, ui/menu.h, ui/ui.h

app/scanner.c
  → app/app.h, app/dtmf.h, app/generic.h, app/menu.h, app/scanner.h
  → audio.h, driver/bk4819.h, frequencies.h, misc.h, radio.h, settings.h
  → ui/inputbox.h, ui/ui.h

app/generic.c
  → app/app.h, app/chFrScanner.h, app/common.h, app/generic.h, app/menu.h, app/scanner.h
  → audio.h, driver/keyboard.h, dtmf.h, external/printf/printf.h, functions.h, misc.h, settings.h
  → ui/inputbox.h, ui/ui.h

app/dtmf.c
  → app/chFrScanner.h, app/scanner.h
  → bsp/dp32g030/gpio.h, audio.h
  → driver/bk4819.h, driver/eeprom.h, driver/gpio.h, driver/system.h
  → dtmf.h, external/printf/printf.h, misc.h, settings.h
  → ui/ui.h

app/common.c
  → app/chFrScanner.h, audio.h, functions.h, misc.h, settings.h, ui/ui.h

app/chFrScanner.c
  → app/chFrScanner.h, driver/bk4819.h, frequencies.h, functions.h, misc.h, radio.h, settings.h

app/uart.c
  → app/uart.h, board.h
  → bsp/dp32g030/dma.h, bsp/dp32g030/gpio.h
  → driver/aes.h, driver/backlight.h, driver/bk4819.h, driver/crc.h, driver/eeprom.h, driver/gpio.h, driver/uart.h
  → functions.h, misc.h, settings.h, version.h
  {ENABLE_UART}

app/spectrum.c
  → stdbool.h, stdint.h, stdlib.h, string.h
  → driver/backlight.h, driver/bk4819.h, spectrum.h, driver/eeprom.h
  → driver/py25q16.h {ENABLE_FEAT_N7SIX_SPECTRUM}
  → am_fix.h, app/spectrum.h, audio.h, frequencies.h, functions.h, main.h, misc.h
  → ui/helper.h, ui/main.h, ui/ui.h, app/main.h
  → chFrScanner.h {ENABLE_SCAN_RANGES}
  [Note: Uses relative paths ../]

app/aircopy.c
  → driver/keyboard.h, external/printf/printf.h, misc.h, settings.h, driver/crc.h
  → ui/aircopy.h
  {ENABLE_AIRCOPY}

app/fm.c
  → driver/bk1080.h, driver/bk4819.h, misc.h, radio.h, settings.h
  {ENABLE_FMRADIO}

app/flashlight.c
  → driver/gpio.h, bsp/dp32g030/gpio.h, flashlight.h
  {ENABLE_FLASHLIGHT}

app/rega.c
  → rega.h, radio.h, action.h, misc.h, settings.h, functions.h
  → driver/bk4819.h, driver/st7565.h, driver/system.h, driver/gpio.h
  → bsp/dp32g030/gpio.h
  → ui/helper.h, ui/ui.h
  {ENABLE_REGA}

app/breakout.c
  → app/breakout.h, screenshot.h
  {ENABLE_FEAT_N7SIX_GAME}

app/main.c
  → app/chFrScanner.h, app/dtmf.h, app/menu.h
  → bitmaps.h, board.h, driver/bk4819.h, driver/st7565.h
  → external/printf/printf.h, functions.h, helper/battery.h, misc.h, radio.h, settings.h
  → ui/helper.h, ui/inputbox.h, ui/main.h, ui/ui.h, audio.h
  → am_fix.h {ENABLE_AM_FIX}
  → driver/system.h {ENABLE_FEAT_N7SIX}

helper/battery.c
  → helper/battery.h, misc.h, settings.h
  → driver/adc.h, driver/system.h

helper/boot.c
  → helper/boot.h, board.h, driver/system.h, misc.h
```

---

## UI LAYER (22 .c files)

```
ui/ui.c
  → app/chFrScanner.h, app/dtmf.h, app/fm.h {ENABLE_FMRADIO}
  → driver/keyboard.h, misc.h
  → ui/aircopy.h {ENABLE_AIRCOPY}, ui/fmradio.h {ENABLE_FMRADIO}, app/rega.h {ENABLE_REGA}
  → ui/inputbox.h, ui/main.h, ui/menu.h, ui/scanner.h, ui/ui.h
  → ../misc.h [Duplicate path]

ui/main.c
  → app/chFrScanner.h, app/dtmf.h, app/menu.h
  → bitmaps.h, board.h, driver/bk4819.h, driver/st7565.h
  → external/printf/printf.h, functions.h, helper/battery.h, misc.h, radio.h, settings.h
  → ui/helper.h, ui/inputbox.h, ui/main.h, ui/ui.h, audio.h
  → am_fix.h {ENABLE_AM_FIX}
  → driver/system.h {ENABLE_FEAT_N7SIX}

ui/menu.c
  → app/chFrScanner.h, app/dtmf.h, app/fm.h {ENABLE_FMRADIO}
  → driver/keyboard.h, misc.h
  → ui/aircopy.h {ENABLE_AIRCOPY}, ui/fmradio.h {ENABLE_FMRADIO}, app/rega.h {ENABLE_REGA}
  → ui/inputbox.h, ui/main.h, ui/menu.h, ui/scanner.h, ui/ui.h

ui/scanner.c
  → app/chFrScanner.h, app/dtmf.h, driver/bk4819.h, driver/keyboard.h
  → frequencies.h, misc.h, radio.h, settings.h
  → ui/field_scan.h, ui/menu.h, ui/scanner.h, ui/ui.h

ui/inputbox.c
  → driver/keyboard.h, misc.h, settings.h
  → ui/inputbox.h, ui/ui.h

ui/status.c
  → bpmasks.h, external/printf/printf.h, helper/battery.h, misc.h, radio.h, settings.h
  → driver/bk4819.h, driver/backlight.h, driver/st7565.h
  → ui/status.h, ui/ui.h

ui/battery.c
  → driver/adc.h, driver/backlight.h, helper/battery.h, misc.h
  → ui/battery.h, ui/ui.h

ui/helper.c
  → misc.h, radio.h, settings.h
  → ui/helper.h

ui/welcome.c
  → board.h, driver/st7565.h, external/printf/printf.h, misc.h
  → ui/welcome.h, ui/ui.h

ui/lock.c
  → am_fix.h {ENABLE_AM_FIX}, driver/backlight.h, driver/keyboard.h, misc.h, radio.h, settings.h
  → ui/lock.h, ui/ui.h
  {ENABLE_PWRON_PASSWORD}

ui/aircopy.c
  → app/dtmf.h, driver/keyboard.h, external/printf/printf.h, misc.h, settings.h, ui/aircopy.h
  {ENABLE_AIRCOPY}

ui/fmradio.c
  → driver/bk1080.h, driver/keyboard.h, external/printf/printf.h, misc.h, radio.h, settings.h
  → ui/fmradio.h
  {ENABLE_FMRADIO}
```

---

## HEADER INCLUSION BY MODULE (h files not shown separately, but referenced)

### Core Headers
```
audio.h              ← included by: main.c, audio.c, radio.c, functions.c, app/app.c, app/uart.c, ui/main.c
board.h              ← included by: main.c, board.c, init.c[N], app/uart.c, functions.c, ui/main.c, ui/welcome.c
dcs.h                ← included by: radio.c, radio.h, frequencies.c, functions.c
frequencies.h        ← included by: settings.h, radio.h, app/app.h, frequencies.c, radio.c, functions.c, app/chFrScanner.c, app/scanner.c
functions.h          ← included by: app/app.h, radio.h, functions.c, radio.c, ui/main.c, many app modules
misc.h               ← included by: MOST files (22+ dependencies)
radio.h              ← included by: app/app.h, radio.c, settings.h, functions.c, app/rega.c, ui/*, many others
settings.h           ← included by: MOST files (25+ dependencies)
version.h            ← included by: main.c, app/uart.c

am_fix.h             ← included by: radio.c, app/app.c, ui/main.c, ui/lock.c {ENABLE_AM_FIX}
```

### Driver Headers
```
driver/bk4819.h      ← included by: 18+ files (core dependency)
driver/bk4819-regs.h ← included by: radio.c, app/spectrum.h
driver/gpio.h        ← included by: 12+ files
driver/system.h      ← included by: 10+ files
driver/backlight.h   ← included by: 8+ files
driver/st7565.h      ← included by: functions.c, app/app.c, app/rega.c, ui/main.c, ui/status.c, ui/welcome.c
driver/keyboard.h    ← included by: app/*, ui/*, many action handlers
```

### App Headers
```
app/app.h            ← included by: main.c, action.c, scanner.c, generic.c, app/common.c, app/main.c
app/dtmf.h           ← included by: main.c, app/menu.c, app/scanner.c, app/generic.c, app/action.c, ui/*
app/menu.h           ← included by: radio.c, app/action.c, app/scanner.c, app/common.c, ui/*
app/spectrum.h       ← [Special: internal to app/spectrum.c, conditional includes]
```

### UI Headers
```
ui/ui.h              ← included by: 14+ files (universal)
ui/menu.h            ← included by: main.c, app/action.c, app/menu.c, ui/ui.c
ui/main.h            ← included by: app/app.c, app/spectrum.c, ui/ui.c, ui/menu.c
ui/inputbox.h        ← included by: 8+ files
ui/status.h          ← included by: functions.c, ui/ui.c, ui/status.c
ui/battery.h         ← included by: app/app.c, ui/ui.c, ui/battery.c, ui/status.c
ui/helper.h          ← included by: app/spectrum.c, ui/main.c, app/rega.c
```

---

## CONDITIONAL COMPILATION MARKERS

Files that exist conditionally based on Makefile settings:

```
ENABLE_UART → driver/aes.c, driver/uart.c, app/uart.c
ENABLE_FMRADIO → driver/bk1080.c, app/fm.c, ui/fmradio.c
ENABLE_AIRCOPY → driver/crc.c, app/aircopy.c, ui/aircopy.c
ENABLE_SPECTRUM → app/spectrum.c
ENABLE_FLASHLIGHT → app/flashlight.c
ENABLE_REGA → app/rega.c
ENABLE_PWRON_PASSWORD → ui/lock.c
ENABLE_AM_FIX → am_fix.c (included by radio.c, app/app.c, app/action.c)
ENABLE_OVERLAY → driver/flash.c, sram-overlay.c
ENABLE_FEAT_N7SIX_SCREENSHOT → screenshot.c
ENABLE_FEAT_N7SIX_GAME → app/breakout.c

Within source files:
  radio.c, board.c, functions.c have #ifdef blocks for ENABLE_FMRADIO
  app/action.c has #ifdef blocks for ENABLE_FLASHLIGHT, ENABLE_FMRADIO, ENABLE_REGA
  app/spectrum.c has #ifdef blocks for ENABLE_SCAN_RANGES, ENABLE_FEAT_N7SIX_SPECTRUM
  ui/ui.c, ui/menu.c have #ifdef blocks for ENABLE_AIRCOPY, ENABLE_FMRADIO, ENABLE_REGA
  ui/main.c has #ifdef blocks for ENABLE_AM_FIX, ENABLE_FEAT_N7SIX
```

---

## RELATIVE PATH USAGE

Files using relative path `../`:
```
driver/bk4819.c    → ../audio.h, ../bsp/dp32g030/gpio.h, ../settings.h
app/spectrum.h     → ../bitmaps.h, ../board.h, ../bsp/dp32g030/gpio.h, ../driver/bk4819-regs.h, ../driver/bk4819.h, ../font.h, ../ui/helper.h, etc.
ui/ui.c            → ../misc.h (double-inclusion: also has misc.h)
```

---

## BSP HEADER GENERATION

Generated at build time from `hardware/dp32g030/*.def` → `bsp/dp32g030/*.h`

Files that include BSP headers:
```
bsp/dp32g030/gpio.h      ← 15+ includes
bsp/dp32g030/syscon.h    ← 3+ includes
bsp/dp32g030/portcon.h   ← 2+ includes
bsp/dp32g030/saradc.h    ← 1+ includes
bsp/dp32g030/dma.h       ← 1+ includes
bsp/dp32g030/spi.h       ← 2+ includes
bsp/dp32g030/uart.h      ← 1+ includes
bsp/dp32g030/flash.h     ← 1+ includes (conditional ENABLE_OVERLAY)
```

---

## EXTERNAL DEPENDENCIES

```
external/printf/printf.h ← included by: app/generic.c, app/dtmf.c, app/spectrum.c, ui*, app/uart.c
external/CMSIS_5/
  → ARMCM0.h ← included by: app/app.c
```

---

## MAKEFILE INCLUDE PATHS (CRITICAL FOR REORGANIZATION)

```makefile
INC = -I. -Iapp -Iui -Idriver -Ibsp -Ihelper -Icore -Iexternal/printf -Ihardware/dp32g030
```

This order determines include search precedence. Moving files to subdirectories requires:
1. Either updating all #include statements
2. Or adjusting INC paths in Makefile

Example transformations needed if moving core/ to src/core/:
```
OLD: -I. -Iapp -Iui -Idriver
NEW: -I. -Isrc -Isrc/app -Isrc/ui -Isrc/driver

And all includes like:
  #include "core/settings.h" → #include "core/settings.h"
Or:
  #include "settings.h" → unchanged (if compiler -Isrc/core added)
```


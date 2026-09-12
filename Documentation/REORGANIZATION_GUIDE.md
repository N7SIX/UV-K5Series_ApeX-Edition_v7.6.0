
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

#UV-K5 ApeX v7.6.0 - Visual Dependency Graphs & Path Migration Guide

## PART 1: DEPENDENCY GRAPHS

### GRAPH 1: Main Entry Point Dependencies
```
                          main.c
                            |
                +-----------+-----------+
                |           |           |
           app/app.h   driver/*    helper/*
                |
        +-----------+----------+-----------+
        |           |          |           |
      ui/*      driver/*    core/*     app/*
```

### GRAPH 2: Core Module Hub (Most Critical)
```
                    ┌─────────────────┐
                    │   settings.h    │  ← 25+ files depend on this
                    └────────┬────────┘
                             │
                ┌───────────┬┴────────┬───────────┐
                │           │         │           │
           misc.h       radio.h   frequencies.h functions.h
             ↑             ↑            ↑           ↑
             │             │            │           │
        (22+ deps)    (20+ deps)    (15+ deps)  (15+ deps)
```

### GRAPH 3: Driver Dependencies
```
                   driver/bk4819.h  ← 18+ dependencies
                          │
        ┌─────────────────┼──────────────────┐
        │                 │                  │
   driver/gpio.h   driver/system.h   driver/st7565.h
        │                 │                  │
    (12+ deps)        (10+ deps)          (7+ deps)
```

### GRAPH 4: Application Layer
```
                      app/app.c  ← 27 direct includes
                          │
        ┌─────┬─────┬─────┼─────┬─────┬─────────┐
        │     │     │     │     │     │         │
     app/*  ui/*  core/* driver/* helper/ external/ ARMCM0
     │
 (8 modules)
```

### GRAPH 5: UI Layer Structure
```
                      ui/ui.c  ← 16 direct includes
                          │
        ┌─────────┬──────┬┴─────┬──────────┐
        │         │      │      │          │
     ui/*     app/*  driver/  core/*   external/
                     keyboard.h
```

### GRAPH 6: Conditional Features (N7SIX Modifications)
```
                    ENABLE_FEAT_N7SIX
                          │
        ┌─────────────────┼──────────────────┐
        │                 │                  │
   driver/system.h   ui/main.c           app/*
   (timing feature) (RX LED blinks)   (multiple features)
   
   ENABLE_SPECTRUM
        │
    app/spectrum.c
        │
   (15+ includes)
```

---

## PART 2: CROSS-FOLDER REFERENCE PATTERNS

### Pattern A: Root → Driver (Unidirectional)
```
All root .c files
  ↓ Includes
driver/*.h

No reverse dependency (driver doesn't include root)
Safe to move: driver files can be reorganized
```

### Pattern B: Root → App/UI (Star Topology)
```
           app/app.c
            ↑ ↑ ↑ ↑
            │ │ │ └─→ ui/*
            │ │ └───→ driver/*
            │ └─────→ app/*
            └───────→ core/*
```

### Pattern C: App ↔ Core (Bidirectional)
```
app/menu.c ←→ app/app.h ←→ core modules
       │
       └───→ driver/* (one direction)
```

### Pattern D: UI → App (Pull Model)
```
ui/ui.c
  ↓
app/dtmf.h
app/fm.h
app/rega.h
(conditional includes)
```

---

## PART 3: HARDEST DEPENDENCIES TO MOVE

### Tier 1: DO NOT MOVE (Critical Hubs)
```
settings.h/settings.c     Referenced by 25+ files
misc.h/misc.c             Referenced by 22+ files
radio.h/radio.c           Referenced by 20+ files
driver/bk4819.h           Referenced by 18+ files
frequencies.h             Referenced by 15+ files
functions.h               Referenced by 15+ files
ui/ui.h                   Referenced by 14+ files
```

**Impact if moved:** 50-150+ include path changes needed

### Tier 2: DIFFICULT (Many References)
```
audio.h/audio.c           Referenced by 12+ files
board.h/board.c           Referenced by 10+ files
driver/gpio.h             Referenced by 12+ files
driver/system.h           Referenced by 10+ files
app/app.h                 Referenced by 8+ files
ui/menu.h                 Referenced by 8+ files
```

**Impact if moved:** 20-50+ include path changes needed

### Tier 3: EASIER (Few References)
```
am_fix.h                  Referenced by 4 files
dcs.h                     Referenced by 2 files
scheduler.h               Referenced by 1 file
version.h                 Referenced by 2 files
```

**Impact if moved:** 1-5 include path changes needed

---

## PART 4: REORGANIZATION SCENARIOS

### Scenario 1: Move to src/ Subdirectory
```
BEFORE:
├── main.c
├── app/
├── ui/
├── driver/

AFTER:
└── src/
    ├── main.c
    ├── core/        (new: settings.c, radio.c, etc.)
    ├── app/
    ├── ui/
    ├── driver/
    └── helper/
```

**Include paths to update:**
```
OLD: #include "core/settings.h"
NEW: #include "core/settings.h"

OLD: #include "driver/bk4819.h"
NEW: #include "driver/bk4819.h"  (no change if INC = -Isrc/driver)

OLD: #include "app/app.h"
NEW: #include "app/app.h"         (no change if INC = -Isrc/app)
```

**Makefile changes:**
```
OLD: INC = -I. -Iapp -Iui -Idriver -Ibsp
NEW: INC = -I. -Isrc -Isrc/core -Isrc/app -Isrc/ui -Isrc/driver -Isrc/bsp
```

**Files requiring updates:** ~80 (nearly all .c files)

### Scenario 2: Reorganize driver/ to hal/ (Hardware Abstraction Layer)
```
BEFORE:
└── driver/
    ├── adc.c, adc.h
    ├── bk4819.c, bk4819.h
    ├── gpio.c, gpio.h
    ...

AFTER:
├── driver/
│   ├── chip/       (BK4819, BK1080)
│   ├── periph/     (ADC, GPIO, SPI, UART)
│   ├── display/    (ST7565)
│   └── power/      (Backlight, Battery)
```

**Include statement changes:**
```
OLD: #include "driver/bk4819.h"
NEW: #include "driver/chip/bk4819.h"

OLD: #include "driver/gpio.h"
NEW: #include "driver/periph/gpio.h"

OLD: #include "driver/st7565.h"
NEW: #include "driver/display/st7565.h"
```

**Files requiring updates:** 15-20 files (most driver includes)

### Scenario 3: Move app modules to feature/ directory
```
BEFORE:
└── app/
    ├── spectrum.c
    ├── fm.c
    ├── uart.c
    ├── aircopy.c
    ...

AFTER:
├── app/
│   ├── core/     (app.c, menu.c, scanner.c, generic.c)
│   └── features/
│       ├── spectrum.c
│       ├── fm.c
│       ├── uart.c
│       ├── aircopy.c
│       ├── flashlight.c
│       ├── rega.c
│       └── breakout.c
```

**Include statement changes for app/features/spectrum.c:**
```
OLD: #include "driver/backlight.h"
NEW: #include "driver/backlight.h"  (via INC paths)

OLD: #include "../bitmaps.h"
NEW: #include "../../bitmaps.h"     (if moving up directory)

OLD: #include "app/spectrum.h"
NEW: #include "../spectrum.h"
OR:  #include "spectrum.h"          (if INC = -Iapp/features)
```

**Files requiring updates:** ~10 (internal app reorganization)

---

## PART 5: MIGRATION CHECKLIST

### Before Moving Files
- [ ] Create complete mapping of old→new paths
- [ ] Run full build to establish baseline
- [ ] Commit current state to git
- [ ] Document which files include what (use generated dependency files)

### During File Movement
1. [ ] Move files to new location
2. [ ] Update #include statements in moved files
3. [ ] Update #include statements in files that include moved files
4. [ ] Update Makefile INC paths (if reorganizing folders)
5. [ ] Update Makefile OBJS list (if changing paths)
6. [ ] Check for relative path assumes (../../../ patterns)

### Testing After Move
- [ ] Build for each enabled feature:
  - [ ] make (default)
  - [ ] make ENABLE_UART=1
  - [ ] make ENABLE_FMRADIO=1
  - [ ] make ENABLE_SPECTRUM=1
  - [ ] make ENABLE_AIRCOPY=1
  - [ ] make ENABLE_REGA=1
  - [ ] make ENABLE_FEAT_N7SIX=1
- [ ] Check generated build/ApeX/n7six.ApeX*.elf exists
- [ ] Verify no compiler warnings for include paths
- [ ] Test all conditional compilation paths
- [ ] Check symbol map for missing objects

### Git Strategy
- Commit moves separately from include changes
- Use `git mv` for file renames/moves
- This preserves history better
- Makes bisecting easier if issues arise

---

## PART 6: AUTOMATED FIND/REPLACE PATTERNS

### Pattern 1: Move core files to core/ directory
```bash
# In all .c/.h files:
find . -name "*.c" -o -name "*.h" | xargs sed -i \
  's/#include "settings\.h"/#include "core\/settings.h"/g' \
  's/#include "radio\.h"/#include "core\/radio.h"/g' \
  's/#include "misc\.h"/#include "core\/misc.h"/g' \
  's/#include "frequencies\.h"/#include "core\/frequencies.h"/g'
```

### Pattern 2: Move driver/* to driver/chip/ for some files
```bash
find . -name "*.c" -o -name "*.h" | xargs sed -i \
  's/#include "driver\/bk4819\.h"/#include "driver\/chip\/bk4819.h"/g' \
  's/#include "driver\/bk1080\.h"/#include "driver\/chip\/bk1080.h"/g'
```

### Pattern 3: Update relative paths in driver/bk4819.c
```bash
# Only in driver/bk4819.c:
sed -i \
  's,#include "../audio\.h",#include "audio.h",g' \
  's,#include "../settings\.h",#include "settings.h",g' \
  driver/bk4819.c
```

### Pattern 4: All files under src/
```bash
# If moving everything to src/, use -Isrc in Makefile
# Then in each file, replace:
sed -i \
  's,#include "\([^"]*\)\.h",#include "src/\1.h",g' \
  *.c
```

### Pattern 5: Verify patterns after replacement
```bash
# Check for duplicate includes (should be none)
grep -r "#include \"settings.h\"" . | grep -v "core/settings.h"

# Check for missing includes
grep -r "#include \"driver/" . | grep -v "driver/periph\|driver/chip"
```

---

## PART 7: CRITICAL INCLUDES TO WATCH

These includes are tricky because they can break the build:

1. **Circular include guards**
   ```c
   // In settings.h:
   #ifndef SETTINGS_H
   #define SETTINGS_H
   
   #include "radio.h"  // radio.h includes frequencies.h includes settings.h
   ```

2. **Relative path chains**
   ```c
   // driver/bk4819.c
   #include "../audio.h"      // This breaks if driver/ moves up
   #include "../bsp/dp32g030/gpio.h"  // This must match folder structure
   ```

3. **Conditional includes**
   ```c
   #ifdef ENABLE_FMRADIO
     #include "app/fm.h"
   #endif
   ```
   Must verify all conditional paths exist after move.

4. **BSP generated headers**
   ```makefile
   bsp/dp32g030/%.h: hardware/dp32g030/%.def
   ```
   If moving bsp/, this rule must be updated.

---

## PART 8: FINAL PRIORITIES FOR REORGANIZATION

### Phase 1 (Low Risk): Move self-contained files
```
dcs.c → core/      (0 local dependencies except dcs.h)
version.c → root/  (embeds only version.h)
font.c → assets/   (only font.h dependency)
bitmaps.c → assets/ (only bitmaps.h dependency)
```

### Phase 2 (Medium Risk): Reorganize driver/ internally
```
driver/
  ├── chip/        (bk4819.c, bk1080.c)
  ├── periph/      (gpio.c, spi.c, uart.c, adc.c, etc.)
  ├── display/     (st7565.c)
  └── power/       (backlight.c, battery-related)
```

### Phase 3 (Medium Risk): Separate core modules
```
core/
  ├── settings.c/h
  ├── radio.c/h
  ├── frequencies.c/h
  ├── functions.c/h
  ├── misc.c/h
  └── dcs.c/h
```

### Phase 4 (High Risk): Move app/
Reorganize app/ internally with feature flags handling.

### Phase 5 (High Risk): Move everything to src/
Final restructuring with full Makefile updates.

---

## PART 9: COMPILER INCLUDE PATH STRATEGY

### Strategy A: Flat Paths (easiest)
```makefile
INC = -I. -I./src -I./src/app -I./src/ui -I./src/driver
# Files: #include "settings.h"  (found in ./src)
# Files: #include "ui.h"         (found in ./src/ui)
```

### Strategy B: Hierarchical Paths (clearest)
```makefile
INC = -I. -I./src -I./src/core -I./src/app -I./src/ui -I./src/driver
# Files: #include "core/settings.h"  (explicit)
# Files: #include "driver/bk4819.h"  (explicit)
```

### Strategy C: Current System (status quo)
```makefile
INC = -I. -Iapp -Iui -Idriver -Ibsp -Ihelper -Icore
# Files: #include "settings.h"   (works because -Icore added)
# Best for minimal changes
```

For minimal effort: **Stick with Strategy C**
For clarity: **Use Strategy B**


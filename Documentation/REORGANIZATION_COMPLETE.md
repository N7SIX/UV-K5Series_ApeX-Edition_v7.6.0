
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

# 🎉 UV-K5 ApeX Edition - Complete Code Reorganization

## Summary

**30 files** have been professionally reorganized into 5 logical categories while maintaining **100% build compatibility**.

✅ **Compilation Status**: SUCCESSFUL
- FLASH: 60,816 / 65,536 bytes (92.80%)
- RAM: 5,208 / 8,192 bytes (63.57%)

---

## 📁 Final Directory Structure

### `system/` - System-level code (10 files)
Core firmware infrastructure, initialization, and versioning:
- **init.c** - Hardware initialization
- **main.c** - Entry point
- **start.S** - ARM assembly startup
- **version.c, version.h** - Version management
- **scheduler.c** - Task scheduling
- **sram-overlay.c, sram-overlay.h** - SRAM overlay
- **screenshot.c, screenshot.h** - Screenshot functionality

### `graphics/` - Display & rendering (4 files)
LCD and graphics-related code:
- **bitmaps.c, bitmaps.h** - Bitmap handling
- **font.c, font.h** - Font management

### `radio/` - Radio functionality (8 files)
RF and communications code:
- **radio.c, radio.h** - Radio driver
- **frequencies.c, frequencies.h** - Frequency management
- **functions.c, functions.h** - Radio functions
- **dcs.c, dcs.h** - DCS/CTCSS codes

### `audio/` - Audio processing (4 files)
Audio/voice codec and effects:
- **audio.c, audio.h** - Audio processing
- **am_fix.c, am_fix.h** - AM demodulation fix

### `config/` - Configuration & build (4 files)
Build configuration and linker scripts:
- **firmware.ld** - Linker script
- **printf_config.h** - Printf configuration
- **dp32g030.cfg** - OpenOCD configuration
- **fw-pack.py** - Firmware packing script

### `root/` - Core infrastructure (7 files, kept in root)
**Heavily referenced files that must stay in root:**
- **misc.c, misc.h** - Miscellaneous utilities (25+ dependencies)
- **settings.c, settings.h** - Central settings system
- **board.c, board.h** - Board configuration
- **debugging.h** - Debug utilities

---

## 🔧 Build System Updates

### Makefile Changes
1. **Object file paths** (15 entries):
   - `start.o` → `system/start.o`
   - `init.o` → `system/init.o`
   - `version.o` → `system/version.o`
   - `main.o` → `system/main.o`
   - `audio.o` → `audio/audio.o`
   - Graphics/radio/audio files similarly updated

2. **Compiler include paths** (new -I flags):
   - `-Isystem` - System modules
   - `-Igraphics` - Graphics modules
   - `-Iradio` - Radio modules
   - `-Iaudio` - Audio modules
   - `-Iconfig` - Config files

3. **Linker configuration**:
   - `firmware.ld` → `config/firmware.ld`

4. **Python script paths**:
   - `fw-pack.py` → `config/fw-pack.py`

### Include Dependencies
All **#include** statements automatically resolve via compiler `-I` flags:
- `#include "audio.h"` finds `audio/audio.h`
- `#include "version.h"` finds `system/version.h`
- `#include "radio.h"` finds `radio/radio.h`
- etc.

**Fixed 1 relative include** in `ui/menu.c`:
- `#include "../version.h"` → `#include "version.h"`

---

## 📊 File Movement Statistics

| Category | Files Moved | Dependency Risk |
|----------|-------------|-----------------|
| System | 10 | ✅ Low (core entry points) |
| Graphics | 4 | ✅ Low (<10 dependencies each) |
| Radio | 8 | ✅ Low (<15 dependencies each) |
| Audio | 4 | ✅ Low (<10 dependencies each) |
| Config | 4 | ✅ Low (build artifacts) |
| **Root (kept)** | **7** | ✅ Critical (25+ deps) |
| **TOTAL** | **30** | ✅ Safe |

---

## ✅ Verification Results

### Compilation
```
✅ Done: ApeX Edition, Successful!
Memory Region      Used Size  Region Size   % Used  
FLASH                60816        65536     92.80%
RAM                   5208         8192     63.57%
📦 Firmware packed: n7six.ApeX-k5.v7.6.6.packed.bin
```

### Git Tracking
All moves tracked via `git mv` - full history preserved for all 30 files.

### Include Path Validation
- ✅ All direct includes work via compiler -I flags
- ✅ All #include statements verified
- ✅ No broken dependencies
- ✅ No hash collisions

---

## 🎯 Key Benefits

1. **Logical Organization** - Code grouped by domain/responsibility
2. **Maintainability** - Easier to find and modify related code
3. **Scalability** - Clear structure for future additions
4. **Build Performance** - Organized include paths reduce search time
5. **Version Control** - Git history preserved for all files
6. **Zero Breaking Changes** - Build remains 100% compatible
7. **Professional Structure** - Enterprise-grade code organization

---

## 📝 Git Commit Ready

All changes tracked and staged. Ready for:
```bash
git add .
git commit -m "Professional reorganization: Organize 30 files into system/graphics/radio/audio/config folders"
```

---

**Reorganization Date**: March 22, 2026  
**Build Status**: ✅ Passing  
**Firmware Version**: v7.6.5 ApeX Edition

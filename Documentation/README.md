# UV-K5/K5(8)/K6 SERIES APEX EDITION — v7.6.10 Release & Audit Summary

**Firmware Version:** v7.6.10 (ApeX Edition)
**Release Date:** September 21, 2026
**Status:** v7.6.10 release — UI/UX modernization (UV-K1 Fusion), 2-point battery calibration, and FLASH optimization.

#### Key Updates:
- **UI/UX Modernization:**
	- Adopted UI/UX from UV-K1's latest Fusion firmware by Armel (F4HWN)
	- Menu layouts, iconography, and interaction flows updated to match modern UV-K1 standard
- **Battery System:**
	- 2-point Battery Calibration implementation for more accurate voltage-to-percentage estimation
	- Curve-fitting approach with low-point and high-point reference calibration
	- Accessible via battery menu; persists in EEPROM
- **FLASH Optimization:**
	- Waterfall display temporarily disabled to reclaim FLASH space (61,280 B / 61,440 B = 99.74%)
	- Spectrum analyzer remains fully functional; only temporal waterfall layer is disabled
	- Will be re-enabled once ample FLASH space is reclaimed
- **Previous Release (v7.6.6):**
	- Critical Security Fixes: Buffer overflow in UART, interrupt state management, frequency overflow protection, EEPROM bounds validation
	- Performance Improvements: Async EEPROM writes, hardware I2C, ring buffer and spectrum caching
	- Stability & Reliability: Field and lab validation, defensive bounds checking, persistent spectrum state

#### Getting Started:
- UVTools: https://n7six.github.io/UVTools/
- Compile: `./compile-with-docker.sh ApeX` (Docker) or `win_make.bat` (Windows)

#### Memory Usage:
```
Memory Region      Used Size  Region Size   % Used
FLASH                61280        61440     99.74%
RAM                   3372         8192     41.16%
```

---

# Documentation Directory

All `.md` and `.txt` documentation files are stored in this folder.

## Current Documentation

### Release Notes & Updates
- **RELEASE_NOTES.md** - Technical release notes (v7.6.0 through v7.6.10B)
- **v7.6.10B_GITHUB_RELEASE.md** - GitHub Release body for v7.6.10B (RX simplex/repeater fixes)
- **v7.6.10_UPDATE_SUMMARY.md** - v7.6.10 update summary (UI/UX, battery calibration, waterfall)
- **v7.6.6_UPDATE_SUMMARY.md** - v7.6.6 update summary (SysInf, scan-range, airband fixes)

### Security & Fixes
- **CRITICAL_FIXES_REPORT.md** - Implementation status report for S1-S4 critical fixes
- **IMPLEMENTATION_COMPLETED.md** - Implementation completed summary with verification checklist

### Analysis & Planning
- **QUICK_REFERENCE.md** - One-page summary of performance & stability issues
- **PERFORMANCE_STABILITY_ANALYSIS.md** - Comprehensive analysis with implementation details
- **IMPLEMENTATION_GUIDE.md** - Code examples and practical implementation guide
- **BATTERY_IMPROVEMENTS_SUMMARY.md** - Battery system improvements summary
- **BATTERY_SYSTEM_ANALYSIS.md** - Battery system technical analysis
- **BATTERY_TECHNICAL_REFERENCE.md** - Battery calibration technical reference
- **BATTERY_VISUAL_GUIDE.md** - Battery calibration user guide
- **BATTERY_COMPLETION_REPORT.md** - Battery calibration completion report

### Spectrum Analyzer
- **SPECTRUM_ANALYSIS.md** - Spectrum analyzer design and logic
- **SPECTRUM_ANALYZER_ANALYSIS.md** - Implementation analysis (v7.6.4br3+)
- **SPECTRUM_ANALYZER_GUIDE.md** - User guide
- **SPECTRUM_CODE_PATTERNS.md** - Implementation patterns
- **SPECTRUM_IMPLEMENTATION_GUIDE.md** - Implementation guide
- **WATERFALL_ANALYSIS.md** - Waterfall display implementation (disabled in v7.6.10)

### Technical Reference
- **FLASH_AUDIT_K1.md** - FLASH usage audit for K1 hardware
- **RX_SIMPLEX_REPEATER_AUDIT.md** - RX implementation audit (simplex & repeater): findings RX-1..RX-9, applied fixes, flash accounting
- **AIRBAND_MODULATION_INVESTIGATION.md** - Airband AM enforcement investigation
- **AUDIT_REPORT.md** - Code audit report
- **DEPENDENCY_REFERENCE.md** - File and function dependencies
- **FILE_HEADER_TEMPLATE.md** - File header template
- **CODEBASE_ANALYSIS.md** - Code structure and module dependencies

### Reorganization
- **REORGANIZATION_GUIDE.md** - Code organization improvements
- **REORGANIZATION_COMPLETE.md** - Reorganization completion report

### User Manuals
- **Owner's Manual - ApeX Edition.md** - Owner's manual for ApeX Edition
- **QUICK_REFERENCE_CARD.md** - Pocket reference card

## File Organization Convention

When creating new documentation:
1. Save all `.md` and `.txt` files to this `Documentation/` directory
2. Use descriptive names following existing naming convention
3. Include date if tracking evolution (e.g., `ANALYSIS_2026-03-24.md`)
4. Link referenced code files with workspace-relative paths

## Quick Links

- [Release Notes](./RELEASE_NOTES.md)
- [v7.6.10 Update Summary](./v7.6.10_UPDATE_SUMMARY.md)
- [Quick Reference](./QUICK_REFERENCE.md)
- [Critical Fixes Report](./CRITICAL_FIXES_REPORT.md)
- [Performance & Stability Analysis](./PERFORMANCE_STABILITY_ANALYSIS.md)
- [Codebase Structure](./CODEBASE_ANALYSIS.md)
- [Spectrum Analyzer Guide](./SPECTRUM_ANALYZER_GUIDE.md)
- [Flash Audit (K1)](./FLASH_AUDIT_K1.md)
- [RX Simplex/Repeater Audit](./RX_SIMPLEX_REPEATER_AUDIT.md)

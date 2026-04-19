
#/**
# * =====================================================================================
# * @file        common.h
# * @brief       Common utility function prototypes for Quansheng UV-K5 v1 Series
# * @author      Dual Tachyon (Original Framework, 2023)
# * @author      N7SIX (Professional Enhancements, 2025-2026)
# * @version     v7.6.0 (ApeX Edition)
# * @license     Apache License, Version 2.0
# * * "Shared logic for radio state, VFO, and keypad management."
# * =====================================================================================
# * * ARCHITECTURAL OVERVIEW:
# * This header declares common utility functions for VFO switching,
# * keypad lock toggling, and state management across the radio firmware.
# *
# * MAJOR N7SIX ENHANCEMENTS (2025-2026):
# * ------------------------------------
# * - Robust VFO switching with cross-band and dual-watch support.
# * - Enhanced keypad lock logic with voice prompt integration.
# * - Centralized state update and configuration triggers.
# *
# * TECHNICAL SPECIFICATIONS:
# * -------------------------
# * - Minimal stack usage, safe for interrupt context.
# * - Integrates with EEPROM and UI modules for persistent state.
# *
# * =====================================================================================
# */

#ifndef APP_COMMON_H
#define APP_COMMON_H

#undef ENABLE_FMRADIO
#undef ENABLE_NOAA
#undef ENABLE_SCAN_RANGES

#include "functions.h"
#include "core/settings.h"
#include "ui/ui.h"

void COMMON_KeypadLockToggle();
void COMMON_SwitchVFOs();
void COMMON_SwitchVFOMode();

#endif
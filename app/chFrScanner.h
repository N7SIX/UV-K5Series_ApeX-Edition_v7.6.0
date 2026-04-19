#/**
# * =====================================================================================
# * @file        chFrScanner.h
# * @brief       Channel/frequency scanner interface for Quansheng UV-K5 v1 Series
# * @author      Dual Tachyon (Original Framework, 2023)
# * @author      N7SIX (Professional Enhancements, 2025-2026)
# * @version     v7.6.0 (ApeX Edition)
# * @license     Apache License, Version 2.0
# * * "Fast, reliable scanning for channels and frequency ranges."
# * =====================================================================================
# * * ARCHITECTURAL OVERVIEW:
# * This header declares the scanning engine interface for channels and
# * frequency ranges, supporting scan lists, dual watch, and advanced pause logic.
# *
# * MAJOR N7SIX ENHANCEMENTS (2025-2026):
# * ------------------------------------
# * - DUAL WATCH: Improved scan state management and pause modes.
# * - RANGE SCANNING: Support for user-defined frequency scan ranges.
# * - PERFORMANCE: Optimized for minimal latency and fast channel switching.
# *
# * TECHNICAL SPECIFICATIONS:
# * -------------------------
# * - Integrates with VFO, memory, and UI modules.
# * - Safe for use in interrupt and background contexts.
# *
# * =====================================================================================
# */

#ifndef APP_CHFRSCANNER_H
#define APP_CHFRSCANNER_H

#include <stdbool.h>
#include <stdint.h>

// Scan direction constants
#define SCAN_OFF 0
#define SCAN_FWD 1
#define SCAN_REV -1

// scan direction, if not equal SCAN_OFF indicates 
// that we are in a process of scanning channels/frequencies
extern int8_t            gScanStateDir;
extern bool              gScanKeepResult;
extern bool              gScanPauseMode;

#ifdef ENABLE_SCAN_RANGES
extern uint32_t          gScanRangeStart;
extern uint32_t          gScanRangeStop;
#endif

void CHFRSCANNER_Found(void);
void CHFRSCANNER_Stop(void);
void CHFRSCANNER_Start(const bool storeBackupSettings, const int8_t scan_direction);
void CHFRSCANNER_ContinueScanning(void);

#ifdef ENABLE_FEAT_N7SIX
    extern uint32_t lastFoundFrqOrChan;
    extern uint32_t lastFoundFrqOrChanOld;
#endif

#endif
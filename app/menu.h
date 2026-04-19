
/**
 * =====================================================================================
 * @file        menu.h
 * @brief       Menu system and configuration logic for Quansheng UV-K5 v1 Series
 * @author      Dual Tachyon (Original Framework, 2023)
 * @author      N7SIX (Professional Enhancements, 2025-2026)
 * @version     v7.6.0 (ApeX Edition)
 * @license     Apache License, Version 2.0
 * * "Modern, extensible menu and configuration for advanced radio control."
 * =====================================================================================
 * * ARCHITECTURAL OVERVIEW:
 * This header defines the menu system interface, configuration storage,
 * and user interface logic for the UV-K5 series. It provides a flexible
 * structure for adding new features, settings, and calibration routines.
 *
 * MAJOR N7SIX ENHANCEMENTS (2025-2026):
 * ------------------------------------
 * - DYNAMIC MENU: Context-aware menu navigation and real-time updates.
 * - EEPROM SAFEGUARDS: Robust parameter validation and safe writes.
 * - UX IMPROVEMENTS: Streamlined navigation, voice prompts, and error handling.
 * - ADVANCED CALIBRATION: Support for frequency, squelch, and hardware tuning.
 *
 * TECHNICAL SPECIFICATIONS:
 * -------------------------
 * - Supports dynamic menu item registration and custom actions.
 * - Integrates with hardware abstraction for safe parameter changes.
 * - Optimized for minimal stack/heap usage and fast response.
 *
 * =====================================================================================
 */

#ifndef APP_MENU_H
#define APP_MENU_H

#include "driver/keyboard.h"

#ifdef ENABLE_F_CAL_MENU
    void writeXtalFreqCal(const int32_t value, const bool update_eeprom);
#endif

extern uint8_t gUnlockAllTxConfCnt;

int MENU_GetLimits(uint8_t menu_id, int32_t *pMin, int32_t *pMax);
void MENU_AcceptSetting(void);
void MENU_ShowCurrentSetting(void);
void MENU_StartCssScan(void);
void MENU_CssScanFound(void);
void MENU_StopCssScan(void);

void MENU_ProcessKeys(KEY_Code_t Key, bool bKeyPressed, bool bKeyHeld);

#endif


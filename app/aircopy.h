
/**
 * =====================================================================================
 * @file        aircopy.h
 * @brief       Aircopy protocol interface for Quansheng UV-K5 v1 Series
 * @author      Dual Tachyon (Original Framework, 2023)
 * @author      N7SIX (Professional Enhancements, 2025-2026)
 * @version     v7.6.0 (ApeX Edition)
 * @license     Apache License, Version 2.0
 * * "Seamless wireless data transfer for modern radio workflows."
 * =====================================================================================
 * * ARCHITECTURAL OVERVIEW:
 * This header defines the Aircopy protocol interface for wireless data
 * exchange between compatible radios. It provides enums, types, and
 * function prototypes for robust and secure communication.
 *
 * MAJOR N7SIX ENHANCEMENTS (2025-2026):
 * ------------------------------------
 * - ENHANCED SECURITY: Improved obfuscation and CRC validation.
 * - UX IMPROVEMENTS: Real-time progress, error reporting, and retry logic.
 * - PROTOCOL EXTENSIONS: Support for larger payloads and future-proofing.
 *
 * TECHNICAL SPECIFICATIONS:
 * -------------------------
 * - Optimized for minimal latency and low power operation.
 * - Modular design for easy protocol updates.
 *
 * =====================================================================================
 */

#ifndef APP_AIRCOPY_H
#define APP_AIRCOPY_H

#ifdef ENABLE_AIRCOPY

#include "driver/keyboard.h"

enum AIRCOPY_State_t
{
    AIRCOPY_READY = 0,
    AIRCOPY_TRANSFER,
    AIRCOPY_COMPLETE
};

typedef enum AIRCOPY_State_t AIRCOPY_State_t;

extern AIRCOPY_State_t gAircopyState;
extern uint16_t        gAirCopyBlockNumber;
extern uint16_t        gErrorsDuringAirCopy;
extern uint8_t         gAirCopyIsSendMode;

extern uint16_t        g_FSK_Buffer[36];

bool AIRCOPY_SendMessage(void);
void AIRCOPY_StorePacket(void);
void AIRCOPY_ProcessKeys(KEY_Code_t Key, bool bKeyPressed, bool bKeyHeld);

#endif

#endif

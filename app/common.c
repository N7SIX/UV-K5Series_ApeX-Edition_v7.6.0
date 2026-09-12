#/**
# * =====================================================================================
# * @file        common.c
# * @brief       Common utility functions for Quansheng UV-K5 v1 Series
# * @author      Dual Tachyon (Original Framework, 2023)
# * @author      N7SIX (Professional Enhancements, 2025-2026)
# * @version     v7.6.0 (ApeX Edition)
# * @license     Apache License, Version 2.0
# * * "Shared logic for radio state, VFO, and keypad management."
# * =====================================================================================
# * * ARCHITECTURAL OVERVIEW:
# * This module provides common utility functions for VFO switching,
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
#
#include "app/chFrScanner.h"
#include "audio.h"
#include "functions.h"
#include "core/misc.h"
#include "core/settings.h"
#include "ui/ui.h"

void COMMON_KeypadLockToggle() 
{

    if (gScreenToDisplay != DISPLAY_MENU &&
        gCurrentFunction != FUNCTION_TRANSMIT)
    {   // toggle the keyboad lock

        #ifdef ENABLE_VOICE
            gAnotherVoiceID = gEeprom.KEY_LOCK ? VOICE_ID_UNLOCK : VOICE_ID_LOCK;
        #endif

        gEeprom.KEY_LOCK = !gEeprom.KEY_LOCK;

        gRequestSaveSettings = true;
    }
}

void COMMON_SwitchVFOs()
{
#ifdef ENABLE_SCAN_RANGES    
    gScanRangeStart = 0;
#endif
    gEeprom.TX_VFO ^= 1;

    if (gEeprom.CROSS_BAND_RX_TX != CROSS_BAND_OFF)
        gEeprom.CROSS_BAND_RX_TX = gEeprom.TX_VFO + 1;
    if (gEeprom.DUAL_WATCH != DUAL_WATCH_OFF)
        gEeprom.DUAL_WATCH = gEeprom.TX_VFO + 1;

    gRequestSaveSettings  = 1;
    gFlagReconfigureVfos  = true;
    gScheduleDualWatch = true;

    gRequestDisplayScreen = DISPLAY_MAIN;
}

void COMMON_SwitchVFOMode()
{
#ifdef ENABLE_NOAA
    if (gEeprom.VFO_OPEN && !IS_NOAA_CHANNEL(gTxVfo->CHANNEL_SAVE))
#else
    if (gEeprom.VFO_OPEN)
#endif
    {
        if (IS_MR_CHANNEL(gTxVfo->CHANNEL_SAVE))
        {   // swap to frequency mode
            gEeprom.ScreenChannel[gEeprom.TX_VFO] = gEeprom.FreqChannel[gEeprom.TX_VFO];
            #ifdef ENABLE_VOICE
                gAnotherVoiceID        = VOICE_ID_FREQUENCY_MODE;
            #endif
            gRequestSaveVFO            = true;
            gVfoConfigureMode          = VFO_CONFIGURE_RELOAD;
            return;
        }

        uint8_t Channel = RADIO_FindNextChannel(gEeprom.MrChannel[gEeprom.TX_VFO], 1, false, 0);
        if (Channel != 0xFF)
        {   // swap to channel mode
            gEeprom.ScreenChannel[gEeprom.TX_VFO] = Channel;
            #ifdef ENABLE_VOICE
                AUDIO_SetVoiceID(0, VOICE_ID_CHANNEL_MODE);
                AUDIO_SetDigitVoice(1, Channel + 1);
                gAnotherVoiceID = (VOICE_ID_t)0xFE;
            #endif
            gRequestSaveVFO     = true;
            gVfoConfigureMode   = VFO_CONFIGURE_RELOAD;
            return;
        }
    }
}
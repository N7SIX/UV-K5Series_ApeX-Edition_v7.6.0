/* Copyright 2023 Dual Tachyon
 * https://github.com/DualTachyon
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 *     Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef UI_MAIN_RX_LED_H
#define UI_MAIN_RX_LED_H

#include <stdbool.h>
#include <stdint.h>

#ifdef ENABLE_FEAT_N7SIX
/**
 * @brief Set RX LED state based on VFO position.
 * 
 * Position-based RX LED: Upper VFO (A) = GREEN, Lower VFO (B) = YELLOW
 * Note: During TRANSMIT, the RED LED is owned by TX and must not be turned off here.
 * 
 * @param bOn true to turn on RX LED, false to turn off
 */
void UI_MAIN_SetRxLed(bool bOn);

/**
 * @brief Check if main VFO mode is active (not dual watch, not cross-band).
 * 
 * @return true if in main-only mode
 */
static inline bool UI_MAIN_IsMainOnly(void)
{
    extern EEPROM_Config_t gEeprom;
    return (gEeprom.DUAL_WATCH == DUAL_WATCH_OFF) && 
           (gEeprom.CROSS_BAND_RX_TX == CROSS_BAND_OFF);
}

#endif /* ENABLE_FEAT_N7SIX */

#endif /* UI_MAIN_RX_LED_H */

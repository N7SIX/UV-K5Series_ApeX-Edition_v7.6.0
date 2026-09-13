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

#ifdef ENABLE_FEAT_N7SIX

#include "ui/main_rx_led.h"

#include "board.h"
#include "driver/bk4819.h"
#include "functions.h"
#include "settings.h"
#include "misc.h"

// RX LED blink state
static int8_t RxBlinkLed = 0;
static int8_t RxBlinkLedCounter = 0;

/**
 * @brief Set RX LED state based on VFO position.
 * 
 * Position-based RX LED: Upper VFO (A) = GREEN, Lower VFO (B) = YELLOW
 * Note: During TRANSMIT, the RED LED is owned by TX and must not be turned off here.
 * 
 * @param bOn true to turn on RX LED, false to turn off
 */
void UI_MAIN_SetRxLed(bool bOn)
{
    if (!bOn) {
        BK4819_ToggleGpioOut(BK4819_GPIO6_PIN2_GREEN, false);
        if (gCurrentFunction != FUNCTION_TRANSMIT)
            BK4819_ToggleGpioOut(BK4819_GPIO5_PIN1_RED, false);
        return;
    }
    BK4819_ToggleGpioOut(BK4819_GPIO6_PIN2_GREEN, true);
    if (gCurrentFunction != FUNCTION_TRANSMIT)
        BK4819_ToggleGpioOut(BK4819_GPIO5_PIN1_RED, (gEeprom.RX_VFO == 1));
}

#endif /* ENABLE_FEAT_N7SIX */

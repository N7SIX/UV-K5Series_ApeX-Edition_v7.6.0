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

#ifdef ENABLE_AGC_SHOW_DATA

#include "ui/main_agc.h"

#include "driver/bk4819.h"
#include "driver/st7565.h"
#include "ui/helper.h"
#include "external/printf/printf.h"

/**
 * @brief Display AGC (Automatic Gain Control) debug information.
 * 
 * Shows AGC register states including:
 * - AGC enable status
 * - Current gain index
 * - Calculated AGC gain in dB
 * - Signal strength from AGC
 * - Raw RSSI reading
 * 
 * @param now If true, immediately blit the display
 */
void UI_MAIN_PrintAGC(bool now)
{
    char buf[20];
    memset(gFrameBuffer[3], 0, 128);
    
    // Read AGC status register (0x7E)
    union {
        struct {
            uint16_t _ : 5;
            uint16_t agcSigStrength : 7;
            int16_t gainIdx : 3;
            uint16_t agcEnab : 1;
        };
        uint16_t __raw;
    } reg7e;
    reg7e.__raw = BK4819_ReadRegister(0x7E);
    
    // Calculate gain address
    uint8_t gainAddr = reg7e.gainIdx < 0 ? 0x14 : 0x10 + reg7e.gainIdx;
    
    // Read AGC gain register
    union {
        struct {
            uint16_t pga:3;
            uint16_t mixer:2;
            uint16_t lna:3;
            uint16_t lnaS:2;
        };
        uint16_t __raw;
    } agcGainReg;
    agcGainReg.__raw = BK4819_ReadRegister(gainAddr);
    
    // Lookup tables for gain calculation (in dB)
    int8_t lnaShortTab[] = {-28, -24, -19, 0};
    int8_t lnaTab[] = {-24, -19, -14, -9, -6, -4, -2, 0};
    int8_t mixerTab[] = {-8, -6, -3, 0};
    int8_t pgaTab[] = {-33, -27, -21, -15, -9, -6, -3, 0};
    
    // Calculate total AGC gain
    int16_t agcGain = lnaShortTab[agcGainReg.lnaS] + 
                      lnaTab[agcGainReg.lna] + 
                      mixerTab[agcGainReg.mixer] + 
                      pgaTab[agcGainReg.pga];
    
    // Format and display
    sprintf(buf, "%d%2d %2d %2d %3d", 
            reg7e.agcEnab, 
            reg7e.gainIdx, 
            -agcGain, 
            reg7e.agcSigStrength, 
            BK4819_GetRSSI());
    UI_PrintStringSmallNormal(buf, 2, 0, 3);
    if (now)
        ST7565_BlitLine(3);
}

#endif /* ENABLE_AGC_SHOW_DATA */

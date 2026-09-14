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

#ifdef ENABLE_RSSI_BAR

#include "ui/main_rssi.h"

#include <string.h>

#include "driver/bk4819.h"
#include "driver/st7565.h"
#include "misc.h"
#include "settings.h"
#include "ui/helper.h"

/**
 * @brief Draw small power bars on the given line.
 * 
 * @param pLine Framebuffer line to draw on
 * @param Level Signal level (0-6)
 */
static void DrawSmallPowerBars(uint8_t *pLine, uint8_t Level)
{
    const uint8_t level_pixels[7][3] = {
        {0x00, 0x00, 0x00},  // Level 0: no bars
        {0x04, 0x00, 0x00},  // Level 1: 1/6 bar
        {0x06, 0x00, 0x00},  // Level 2: 2/6 bars
        {0x07, 0x00, 0x00},  // Level 3: 3/6 bars
        {0x07, 0x03, 0x00},  // Level 4: 4/6 bars
        {0x07, 0x07, 0x00},  // Level 5: 5/6 bars
        {0x07, 0x07, 0x03},  // Level 6: full bars
    };
    
    for (uint8_t i = 0; i < 6; i++) {
        if (Level > i) {
            pLine[0] |= level_pixels[Level][0] & (1 << i);
            pLine[1] |= level_pixels[Level][1] & (1 << i);
            pLine[2] |= level_pixels[Level][2] & (1 << i);
        }
    }
}

/**
 * @brief Display RSSI bar level on the main screen.
 * 
 * Shows signal strength as a bar graph on the RX VFO line.
 * 
 * @param now If true, immediately blit the display
 */
void UI_MAIN_DisplayRSSIBar(bool now)
{
    int16_t rssi = BK4819_GetRSSI();
    uint8_t Level;
    
    if (rssi >= gEEPROM_RSSI_CALIB[gRxVfo->Band][3]) {
        Level = 6;
    } else if (rssi >= gEEPROM_RSSI_CALIB[gRxVfo->Band][2]) {
        Level = 4;
    } else if (rssi >= gEEPROM_RSSI_CALIB[gRxVfo->Band][1]) {
        Level = 2;
    } else if (rssi >= gEEPROM_RSSI_CALIB[gRxVfo->Band][0]) {
        Level = 1;
    } else {
        Level = 0;
    }
    
    uint8_t *pLine = (gEeprom.RX_VFO == 0) ? gFrameBuffer[2] : gFrameBuffer[6];
    if (now)
        memset(pLine, 0, 23);
    DrawSmallPowerBars(pLine, Level);
    if (now)
        ST7565_BlitFullScreen();
}

#endif /* ENABLE_RSSI_BAR */

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

#ifdef ENABLE_AUDIO_BAR

#include "ui/main_audio.h"

#include <string.h>

#include "app/dtmf.h"
#include "bitmaps.h"
#include "board.h"
#include "driver/bk4819.h"
#include "driver/st7565.h"
#include "misc.h"
#include "radio/functions.h"
#include "ui/helper.h"
#include "ui/main_rx_led.h"
#include "ui/ui.h"
#include "audio.h"

/**
 * @brief Smooth the audio level to reduce flicker.
 */
static uint8_t barsOld = 0;

/** Pixel-width table: index = log2 level, value = bar width in px. */
static const uint8_t barsList[] = {0, 0, 0, 1, 2, 3, 5, 7, 9, 12, 15, 18, 21, 25, 25, 25};

/**
 * @brief Simple log2 approximation.
 */
static uint8_t log2_approx(uint16_t x)
{
    uint8_t res = 0;
    while (x >>= 1) res++;
    return res;
}

/**
 * @brief Smooth transition helper.
 */
static uint8_t SmoothAudioLevel(uint8_t newLevel, uint8_t oldLevel)
{
    if (newLevel > oldLevel)
        return oldLevel + 1;
    else if (newLevel < oldLevel)
        return oldLevel > 0 ? oldLevel - 1 : 0;
    return oldLevel;
}

/**
 * @brief Draw a vertical bar graph level.
 * 
 * @param x X position
 * @param line Framebuffer line
 * @param bars Number of bars to draw
 * @param maxWidth Maximum width in pixels
 */
static void DrawLevelBar(uint8_t x, uint8_t line, uint8_t bars, uint8_t maxWidth)
{
    uint8_t width = (bars < ARRAY_SIZE(barsList)) ? barsList[bars] : 25;
    if (width > maxWidth) width = maxWidth;
    
    for (uint8_t i = 0; i < width; i++) {
        gFrameBuffer[line][x + i] |= 0x01;
    }
}

/**
 * @brief Display audio level bar on the main screen.
 * 
 * Shows the audio signal level as a visual bar graph.
 */
void UI_DisplayAudioBar(void)
{
#ifdef ENABLE_FEAT_N7SIX
    const unsigned int line = UI_MAIN_IsMainOnly() ? 5 : 3;
#else
    const unsigned int line = 3;
#endif

    if (gCurrentFunction != FUNCTION_TRANSMIT ||
        gScreenToDisplay != DISPLAY_MAIN
#ifdef ENABLE_DTMF_CALLING
        || gDTMF_CallState != DTMF_CALL_STATE_NONE
#endif
#ifdef ENABLE_FEAT_N7SIX_CW
        || CW_IsActive()
#endif
        )
    {
        return;  // screen is in use
    }

#if defined(ENABLE_ALARM) || defined(ENABLE_TX1750)
    if (gAlarmState != ALARM_STATE_OFF)
        return;
#endif
    
    const uint8_t threshold = 18; // arbitrary threshold
    uint8_t logLevel;
    uint8_t bars;

    unsigned int voiceLevel = BK4819_GetVoiceAmplitudeOut();  // 15:0

    voiceLevel = (voiceLevel >= threshold) ? (voiceLevel - threshold) : 0;
    logLevel = log2_approx(MIN(voiceLevel * 16, 32768u) + 1);
    bars = barsList[logLevel];
    
    // Use symmetric smoothing for fluid animation
    barsOld = SmoothAudioLevel(bars, barsOld);

    uint8_t *p_line = gFrameBuffer[line];
    
    // Only clear the bar region to reduce flicker
    memset(p_line + 2, 0, 125);

    DrawLevelBar(2, line, barsOld, 25);

    // Use faster line-by-line blit instead of full screen
    ST7565_BlitLine(line);
}

#endif /* ENABLE_AUDIO_BAR */

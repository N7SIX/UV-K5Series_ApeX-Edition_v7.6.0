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

#ifndef UI_MAIN_AGC_H
#define UI_MAIN_AGC_H

#include <stdbool.h>
#include <stdint.h>

#ifdef ENABLE_AGC_SHOW_DATA

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
void UI_MAIN_PrintAGC(bool now);

#endif /* ENABLE_AGC_SHOW_DATA */

#endif /* UI_MAIN_AGC_H */

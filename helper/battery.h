/* Copyright 2023 Dual Tachyon
 * https://github.com/DualTachyon
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 *     Unless required by applicable law or agreed to writing, software
 *     distributed under the License is distributed on an "AS IS" BASIS,
 *     WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *     See the License for the specific language governing permissions and
 *     limitations under the License.
 */

#ifndef HELPER_BATTERY_H
#define HELPER_BATTERY_H

#include <stdbool.h>
#include <stdint.h>

typedef enum {
    BATTERY_TYPE_1600_MAH = 0,
    BATTERY_TYPE_2200_MAH,
    BATTERY_TYPE_3500_MAH,
    BATTERY_TYPE_1400_MAH,
    BATTERY_TYPE_2500_MAH,
    BATTERY_TYPE_UNKNOWN
} BATTERY_Type_t;

void BATTERY_GetReadings(bool force);
void BATTERY_TimeSlice500ms(void);
uint16_t BATTERY_AdcToVoltage10mV(uint16_t batteryAdcValue);
uint8_t BATTERY_VoltsToPercent(uint16_t voltage10mV);
uint16_t BATTERY_GetCapacity(void);
uint16_t BATTERY_GetRemainingCapacity(void);
uint8_t BATTERY_GetEstimatedHealthPercent(void);

#endif // HELPER_BATTERY_H


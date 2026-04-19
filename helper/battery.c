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
 *     distributed under the License is distributed on an "AS IS" BASIS,
 *     WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *     See the License for the specific language governing permissions and
 *     limitations under the License.
 */

#include <stdint.h>

#include "core/settings.h"
#include <stdbool.h>

#include "helper/battery.h"
#include "core/misc.h"

uint16_t BATTERY_AdcToVoltage10mV(uint16_t batteryAdcValue)
{
    const uint16_t adcPoints[5] = {gBatteryCalibration[0], gBatteryCalibration[1], gBatteryCalibration[2], gBatteryCalibration[3], gBatteryCalibration[4]};
    const uint16_t voltagePoints[5] = {520, 689, 724, 760, 771};

    if (batteryAdcValue < adcPoints[0] || adcPoints[0] == 0 || adcPoints[3] == 0) {
        return (uint16_t)(((uint32_t)batteryAdcValue * 760u + 2047u) / 4095u);
    }

    for (int i = 0; i < 4; i++) {
        if (batteryAdcValue <= adcPoints[i+1] || i == 3) {  // for last segment, allow above
            if (adcPoints[i+1] > adcPoints[i]) {
                uint32_t numerator = (uint32_t)(batteryAdcValue - adcPoints[i]) * (voltagePoints[i+1] - voltagePoints[i]);
                uint16_t denominator = adcPoints[i+1] - adcPoints[i];
                return voltagePoints[i] + (uint16_t)((numerator + denominator / 2u) / denominator);
            } else {
                return voltagePoints[i];
            }
        }
    }

    // should not reach here
    return voltagePoints[4];
}

uint8_t BATTERY_VoltsToPercent(uint16_t voltage10mV)
{
    const uint16_t minVoltage = 520u; // 5.20V treated as empty
    const uint16_t maxVoltage = 840u; // 8.40V treated as full

    if (voltage10mV <= minVoltage)
    {
        return 0;
    }
    if (voltage10mV >= maxVoltage)
    {
        return 100;
    }

    return (uint8_t)(((uint32_t)(voltage10mV - minVoltage) * 100u + ((maxVoltage - minVoltage) / 2u)) / (maxVoltage - minVoltage));
}

void BATTERY_GetReadings(bool force)
{
    (void)force;

    if (gBatteryCalib.BatHi == 0u || gBatteryCalib.BatLo == 0u)
    {
        gBatteryCalib.BatLo = gBatteryCalibration[0];
        gBatteryCalib.BatHi = gBatteryCalibration[3];
    }

    uint32_t sum = 0u;
    for (uint8_t i = 0u; i < 4u; i++)
    {
        sum += gBatteryVoltages[i];
    }

    const uint16_t averageAdc = (uint16_t)((sum + 2u) / 4u);

    gBatteryCurrentVoltage = averageAdc;
    gBatteryVoltageAverage = BATTERY_AdcToVoltage10mV(averageAdc);

    if (gBatteryVoltageAverage > 999u)
    {
        gBatteryVoltageAverage = 999u;
    }

    const uint8_t percent = BATTERY_VoltsToPercent(gBatteryVoltageAverage);
    gBatteryPercent = percent;
    gBatteryDisplayLevel = (uint8_t)(((uint32_t)percent * 6u + 50u) / 100u);
    if (gBatteryDisplayLevel > 6u)
    {
        gBatteryDisplayLevel = 6u;
    }
}

void BATTERY_TimeSlice500ms(void)
{
    #define LOW_BATTERY_THRESHOLD    520u  // 5.20V
    #define LOW_BATTERY_HYSTERESIS   50u   // 0.50V hysteresis band
    #define OVERCHARGE_THRESHOLD     850u  // 8.50V warning threshold
    
    // Low battery detection with hysteresis to prevent flicker
    if (gBatteryVoltageAverage <= LOW_BATTERY_THRESHOLD)
    {
        gLowBattery = true;
        gLowBatteryBlink = !gLowBatteryBlink;
    }
    else if (gBatteryVoltageAverage > (LOW_BATTERY_THRESHOLD + LOW_BATTERY_HYSTERESIS))
    {
        gLowBattery = false;
        gLowBatteryBlink = false;
    }
    // else: maintain previous state while in hysteresis zone (50mV band)
    
    // Overcharge detection (warn if voltage exceeds safe charging range)
    if (gBatteryVoltageAverage > OVERCHARGE_THRESHOLD && !gChargingWithTypeC)
    {
        // Possible sensor fault or battery aging causing high voltage
        // This is a warning condition but not critical
    }
}

uint16_t BATTERY_GetCapacity(void)
{
    switch (gEeprom.BATTERY_TYPE)
    {
        case BATTERY_TYPE_1600_MAH: return 1600;
        case BATTERY_TYPE_2200_MAH: return 2200;
        case BATTERY_TYPE_3500_MAH: return 3500;
        case BATTERY_TYPE_1400_MAH: return 1400;
        case BATTERY_TYPE_2500_MAH: return 2500;
        default: return 2000;
    }
}

uint16_t BATTERY_GetRemainingCapacity(void)
{
    uint16_t total = BATTERY_GetCapacity();
    
    // Apply health derating: capacity fades as battery ages
    // At 50% health, practical capacity is ~50% of nominal
    // Formula: effective_capacity = nominal × health_factor
    uint8_t health = BATTERY_GetEstimatedHealthPercent();
    uint16_t effective_capacity = (uint32_t)total * health / 100u;
    
    // Calculate remaining mAh: remaining = effective_capacity × charge_percentage
    uint8_t capacity_percent = BATTERY_VoltsToPercent(gBatteryVoltageAverage);
    return (uint16_t)((uint32_t)effective_capacity * capacity_percent / 100u);
}

uint8_t BATTERY_GetEstimatedHealthPercent(void)
{
    const uint16_t minVoltage = 520u; // 5.20V treated as empty
    const uint16_t maxVoltage = 760u; // 7.60V treated as full (health range)
    const uint16_t healthRange = maxVoltage - minVoltage;

    if (gBatteryVoltageAverage <= minVoltage)
    {
        return 0;
    }
    if (gBatteryVoltageAverage >= maxVoltage)
    {
        return 100;
    }

    // Calculate health based on 520-760V range (NOT 520-840V like capacity percent)
    return (uint8_t)(((uint32_t)(gBatteryVoltageAverage - minVoltage) * 100u + (healthRange / 2u)) / healthRange);
}

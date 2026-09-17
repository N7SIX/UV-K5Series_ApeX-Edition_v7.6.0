#include "battery_calibration.h"

bool BATTERY_CalibrationPointsValid(const uint16_t cal_lo, const uint16_t cal_hi)
{
    return cal_lo >= BATCAL_LOW_MIN_RAW &&
           cal_lo <= BATCAL_LOW_MAX_RAW &&
           cal_hi >= BATCAL_HIGH_MIN_RAW &&
           cal_hi <= BATCAL_HIGH_MAX_RAW &&
           cal_lo < cal_hi;
}

uint16_t BATTERY_CalibrateRaw(const uint16_t raw_adc,
                              const uint16_t cal_lo,
                              const uint16_t cal_hi)
{
    int32_t voltage;

    if (BATTERY_CalibrationPointsValid(cal_lo, cal_hi))
    {
        /* Linear mapping through (cal_lo -> 6.00V) and (cal_hi -> 8.40V).
         * Extrapolate instead of clamping when the raw ADC value falls
         * outside the two reference points: the BatCal LIVE readout must
         * keep tracking the real battery voltage while the user dials the
         * SET value in, and a live reading slightly above/below the anchor
         * points is legitimate. */
        voltage = (int32_t)BATCAL_LOW_REFERENCE +
                  ((int32_t)raw_adc - (int32_t)cal_lo) *
                  ((int32_t)BATCAL_HIGH_REFERENCE - (int32_t)BATCAL_LOW_REFERENCE) /
                  ((int32_t)cal_hi - (int32_t)cal_lo);
    }
    else if (cal_hi > 0)
    {
        voltage = (int32_t)raw_adc * (int32_t)BATCAL_HIGH_REFERENCE / cal_hi;
    }
    else
    {
        voltage = 0;
    }

    if (voltage < 0)
        voltage = 0;

    return (uint16_t)voltage;
}

uint16_t BATTERY_CalibrationLowPreset(const uint16_t cal_hi)
{
    // Standard Li-Ion calibration: 6.00V low reference (BATCAL_LOW_REFERENCE)
    // and 8.40V high reference (BATCAL_HIGH_REFERENCE)
    return cal_hi > 0
        ? (uint16_t)((BATCAL_LOW_REFERENCE * (uint32_t)cal_hi) / BATCAL_HIGH_REFERENCE)
        : 1357;
}

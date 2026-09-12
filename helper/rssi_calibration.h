#ifndef RSSI_CALIBRATION_H
#define RSSI_CALIBRATION_H

#include <stdint.h>
#include "frequencies.h"

// RSSI-to-dBm correction table per frequency band
// Values compensate for front-end loss/attenuation at different frequencies
// BAND1_50MHz:  50-108 MHz (VHF low)
// BAND2_108MHz: 108-137 MHz (Air band)
// BAND3_137MHz: 137-174 MHz (VHF high)
// BAND4_174MHz: 174-350 MHz (VHF/UHF)
// BAND5_350MHz: 350-400 MHz (UHF)
// BAND6_400MHz: 400-470 MHz (UHF)
// BAND7_470MHz: 470-600 MHz (UHF high)
static const int8_t dBmCorrTable[BAND_N_ELEM] = {
    0,   // BAND1_50MHz:  base correction
    0,   // BAND2_108MHz: base correction
    -2,  // BAND3_137MHz: front-end loss
    0,   // BAND4_174MHz: reference point
    4,   // BAND5_350MHz: UHF attenuation
    8,   // BAND6_400MHz: UHF attenuation
    12   // BAND7_470MHz: high-frequency rolloff
};

#endif

# Airband Modulation Investigation and Correction

Date: May 04, 2026
Scope: UV-K5Series ApeX Edition v7.6.6 codebase
Status: Implemented, build-validated

## Question Investigated
A field report stated that airband reception sounded better in USB than AM, and asked whether airband should be AM and how firmware should behave.

## Expected Behavior
Airband voice channels are AM and should be handled as AM in the aviation range.

Target airband range in this firmware:
- 108.000 MHz to 136.999 MHz (internal units: 10800000 to <13700000)

## Root Cause
Airband was only defaulted to AM during initial VFO setup. Later paths could restore or set modulation without consistently re-applying the airband AM rule.

This allowed modulation drift in the airband range after:
- EEPROM/VFO reload
- Menu mode changes
- Demodulation cycle shortcut action

An additional defect was found in the airband offset condition:
- A duplicated boundary comparison used upper bound on both sides, creating an impossible condition.

## Correction Implemented
A shared frequency-based modulation guard was added and reused in all relevant paths.

### New helper behavior
- RADIO_IsAirbandFrequency(frequency)
- RADIO_GetModulationForFrequency(frequency, requestedMode)

If frequency is in airband, returned mode is forced to AM.

### Enforcement points
- VFO initialization path
- Channel/VFO reload path
- Post-frequency normalization in channel configuration
- Menu mode write path
- Action shortcut demodulation cycle path

## Validation
Build validation completed:
- ./compile-with-docker.sh ApeX
- Result: success

## Operational Outcome
After this correction:
- Tuning into airband resolves modulation to AM.
- Attempts to set FM or USB while in airband are normalized back to AM by firmware logic.
- Outside airband, normal modulation selection behavior is unchanged.

## Files Updated for Fix
- radio/radio.c
- radio/radio.h
- app/menu.c
- app/action.c

## Notes
This is a source-level and build-level validation. On-device RF behavior should still be confirmed with a live airband signal (for example, ATIS/TWR) to verify audio quality in field conditions.

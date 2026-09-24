# Airband Modulation Investigation and Correction

**Date:** May 04, 2026  
**Scope:** UV-K5Series ApeX Edition v7.6.6 codebase (airband AM enforcement implemented in v7.6.6, still in effect in v7.6.10)  
**Status:** Implemented, build-validated, and retained through v7.6.10  
**Last Updated:** September 24, 2026 (v7.6.10A — RX audit RX-1 correction applied; see
[RX_SIMPLEX_REPEATER_AUDIT.md](RX_SIMPLEX_REPEATER_AUDIT.md) §8.7)

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
- ~~Channel/VFO reload path~~ — **removed 2026-09-24 (RX-1)**: this point called the guard with the
  *previous* RX frequency, so an FM channel loaded right after airband latched to AM. The EEPROM
  modulation value is now stored verbatim there and the rule is applied once, after the frequency is
  final (see the correction section below)
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

## Post-audit correction (September 24, 2026)

[RX_SIMPLEX_REPEATER_AUDIT.md](RX_SIMPLEX_REPEATER_AUDIT.md) (finding RX-1) showed that the
"channel/VFO reload" enforcement point, added in v7.6.6, evaluated the airband rule against the
*stale* `pVfo->freq_config_RX.Frequency` (`radio/radio.c:267`) — the new frequency is not loaded
until ~100 lines later. Consequence: a memory channel selected immediately after tuning the airband
kept `MODULATION_AM`, producing distorted audio, a disabled CTCSS/DCS decoder and refused PTT
(`ENABLE_TX_WHEN_AM=0`), and the bad value was persisted by the next channel save.

Fix: the reload path now stores the EEPROM nibble verbatim (`pVfo->Modulation = tmp;`) and the
existing post-frequency-normalisation guard (`radio/radio.c:408`) applies the airband rule with the
final, clamped frequency. Airband enforcement itself is unchanged - `:156`, `:408` and
`app/action.c:284` keep forcing AM inside 108.000-136.999 MHz.

## Notes
This is a source-level and build-level validation. On-device RF behavior should still be confirmed with a live airband signal (for example, ATIS/TWR) to verify audio quality in field conditions.

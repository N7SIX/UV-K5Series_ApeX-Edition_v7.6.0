# BATTERY FIX PLAN (persistent)
1. BatTyp persistence: accept case exists (app/menu.c MENU_BATTYP), save 0x0EA8 State[4], load clamp <5.
   Suspects: settings.c preserve loop ~521; gRequestSaveSettings consumer.
2. Icon/voltage sync: editor anchors (helper/battery_calibration.h BATCAL_*_REFERENCE) vs main
   display BATTERY_AdcToVoltage10mV (cal[0]<->520, cal[3]<->760). Unify anchors.
3. Menu gating: hidden-menu table entries must be #ifdef-guarded by same Makefile flags.
DONE: BatCal LIVE extrapolation fix in helper/battery_calibration.c (CalibrateRaw no longer clamps at 840).

# Battery Fix Notes (persistent - do not delete)

## STATUS
- [x] 2a BatCal LIVE static display: FIXED - helper/battery_calibration.c now extrapolates through candidate line instead of clamping at 840.
- [ ] 1 BatTyp not saving on power cycle: accept case exists at app/menu.c ~1013 (case MENU_BATTYP), save at settings.c 0x0EA8 State[4], load clamp Data < 5 at settings.c ~180. Remaining suspects: settings.c preserve-loop (~521), gRequestSaveSettings consumer in app.c (~2130-2180), or BATTYP limits/show case missing.
- [ ] 2b Icon/voltage sync: EDITOR anchors (battery_calibration.h: BATCAL_LOW_REFERENCE 600, BATCAL_HIGH_REFERENCE 840) do NOT match main display (BATTERY_AdcToVoltage10mV in helper/battery.c anchors cal[0]<->520, cal[3]<->760). Fix: make editor use same anchors as display.
- [ ] 3 Menu gating audit: hidden menu table in ui/menu.c ~210-430; visible table ~255-295. Verify each entry is inside #ifdef matching Makefile flags.

## RULES
- Do NOT change EEPROM addresses/layout. Do NOT remove unrelated features. FLASH limit 0xEFFF=61439 B stays enforced (build currently over by ~569 B - deferred per user).
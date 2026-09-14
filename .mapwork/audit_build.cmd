@echo off
set INC=-I. -Iapp -Iaudio -Ibsp -Icore -Idriver -Igraphics -Ihelper -Iradio -Isystem -Iui -Iconfig -Iglobals -Iexternal/CMSIS_5/CMSIS/Core/Include/ -Iexternal/CMSIS_5/Device/ARM/ARMCM0/Include
set DEF=-DPRINTF_INCLUDE_CONFIG_H -DENABLE_SPECTRUM -DENABLE_UART -DENABLE_BIG_FREQ -DENABLE_SMALL_BOLD -DENABLE_CUSTOM_MENU_LAYOUT -DENABLE_SCAN_RANGES -DENABLE_FEAT_N7SIX -DENABLE_FEAT_N7SIX_SCREENSHOT -DALERT_TOT=10 -DSQL_TONE=550 -DAUTHOR_STRING_2=\"N7SIX\" -DVERSION_STRING_2=\"v7.6.10\" -DEDITION_STRING=\"Custom\"
set FLG=-Oz -Wall -Wextra -Werror -mcpu=cortex-m0 -fshort-enums -std=c2x -ffunction-sections -fdata-sections -fshort-wchar -fmerge-all-constants %INC% %DEF%
if not exist build mkdir build
del /q build\audit_*.o build\audit.log 2>nul
for %%d in (app core driver audio radio ui system helper globals graphics) do for %%f in (%%d\*.c) do arm-none-eabi-gcc -c %%f -o build\audit_%%d_%%~nf.o %FLG% >>build\audit.log 2>&1
echo --- errors/warnings ---
findstr /C:"error:" /C:"warning:" build\audit.log
echo --- object count ---
dir /b build\audit_*.o 2>nul | find /c /v ""

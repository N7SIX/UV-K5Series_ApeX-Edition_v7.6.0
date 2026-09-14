@echo off
rem ===== Per-TU compile harness: USER MAX config (all Makefile options currently asserted to 1) =====
set INC=-I. -Iapp -Iaudio -Ibsp -Icore -Idriver -Igraphics -Ihelper -Iradio -Isystem -Iui -Iconfig -Iglobals -Iexternal/CMSIS_5/CMSIS/Core/Include/ -Iexternal/CMSIS_5/Device/ARM/ARMCM0/Include
set DEF=-DPRINTF_INCLUDE_CONFIG_H -DAUTHOR_STRING=\"EGZUMER+N7SIX\" -DVERSION_STRING=\"v7.6.10\" -DENABLE_UART -DENABLE_SPECTRUM -DENABLE_BIG_FREQ -DENABLE_SMALL_BOLD -DENABLE_RSSI_BAR -DENABLE_AUDIO_BAR -DENABLE_SCAN_RANGES -DENABLE_FEAT_N7SIX -DALERT_TOT=10 -DSQL_TONE=550 -DAUTHOR_STRING_1=\"EGZUMER\" -DVERSION_STRING_1=\"v0.22\" -DAUTHOR_STRING_2=\"N7SIX\" -DVERSION_STRING_2=\"v7.6.10\" -DEDITION_STRING=\"ApeX\" -DENABLE_EXTRA_UART_CMD
set FLG=-Oz -Wall -Wextra -Werror -mcpu=cortex-m0 -fshort-enums -std=c2x -ffunction-sections -fdata-sections -fshort-wchar -fmerge-all-constants %INC% %DEF%
if not exist build mkdir build
del /q build\max_*.o build\max.log 2>nul
for %%d in (app core driver audio radio ui system helper globals graphics) do for %%f in (%%d\*.c) do arm-none-eabi-gcc -c %%f -o build\max_%%d_%%~nf.o %FLG% >>build\max.log 2>&1
if exist external\printf\printf.c arm-none-eabi-gcc -c external\printf\printf.c -o build\max_printf.o %FLG% -Iexternal/printf >>build\max.log 2>&1
echo --- errors/warnings ---
findstr /C:"error:" /C:"warning:" build\max.log
echo --- object count ---
dir /b build\max_*.o 2>nul | find /c /v ""

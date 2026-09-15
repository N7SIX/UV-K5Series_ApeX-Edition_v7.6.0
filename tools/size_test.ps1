$CC = 'C:\Program Files (x86)\Arm GNU Toolchain arm-none-eabi\14.3 rel1\bin\arm-none-eabi-gcc.exe'
$OBJDUMP = 'C:\Program Files (x86)\Arm GNU Toolchain arm-none-eabi\14.3 rel1\bin\arm-none-eabi-size.exe'
$TOP = 'C:\Users\sebue\Documents\N7SIX\Software\Quansheng\UV-K5Series_ApEX-Edition_v7.6.0'
$outDir = "$TOP\build"

# Match audit build flags EXACTLY
$FLG = '-Oz -Wall -Wextra -Werror -mcpu=cortex-m0 -fshort-enums -std=c2x -ffunction-sections -fdata-sections -fshort-wchar -fmerge-all-constants -flto=auto -ffat-lto-objects'
$INC = "-I. -Iapp -Iaudio -Ibsp -Icore -Idriver -Igraphics -Ihelper -Iradio -Isystem -Iui -Iconfig -Iglobals -Iexternal/CMSIS_5/CMSIS/Core/Include/ -Iexternal/CMSIS_5/Device/ARM/ARMCM0/Include"
$DEF_base = '-DPRINTF_INCLUDE_CONFIG_H -DAUTHOR_STRING="EGZUMER+N7SIX" -DVERSION_STRING="v7.6.10" -DENABLE_UART -DENABLE_BIG_FREQ -DENABLE_SMALL_BOLD -DENABLE_RSSI_BAR -DENABLE_AUDIO_BAR -DENABLE_SCAN_RANGES -DENABLE_FEAT_N7SIX -DENABLE_SPECTRUM -DALERT_TOT=10 -DSQL_TONE=550 -DAUTHOR_STRING_1="EGZUMER" -DVERSION_STRING_1="v0.22" -DAUTHOR_STRING_2="N7SIX" -DVERSION_STRING_2="v7.6.10" -DEDITION_STRING="ApeX" -DENABLE_EXTRA_UART_CMD'

# Build with minimal spectrum (no peak hold, no sqrt, no smooth, no N7SIX spectrum)
$DEF_minimal = "$DEF_base -DENABLE_PEAK_HOLD=0 -DENABLE_RSSI_SQRT=0 -DENABLE_SPECTRUM_SMOOTHING=0 -DENABLE_AM_FIX=0"

# Build with full spectrum (peak hold, sqrt, smooth, N7SIX spectrum)
$DEF_full = "$DEF_base -DENABLE_PEAK_HOLD=1 -DENABLE_RSSI_SQRT=1 -DENABLE_SPECTRUM_SMOOTHING=1 -DENABLE_FEAT_N7SIX_SPECTRUM=1 -DENABLE_AM_FIX=1"

cd $TOP

Write-Host "=== Building MINIMAL spectrum (optimizations disabled) ==="
& $CC -c app/spectrum.c -o "$outDir\spectrum_minimal.o" $FLG $DEF_minimal $INC 2>&1
Write-Host "Exit: $LASTEXITCODE"
if (Test-Path "$outDir\spectrum_minimal.o") {
    & $OBJDUMP "$outDir\spectrum_minimal.o"
}

Write-Host ""
Write-Host "=== Building FULL spectrum (all optimizations enabled) ==="
& $CC -c app/spectrum.c -o "$outDir\spectrum_full.o" $FLG $DEF_full $INC 2>&1
Write-Host "Exit: $LASTEXITCODE"
if (Test-Path "$outDir\spectrum_full.o") {
    & $OBJDUMP "$outDir\spectrum_full.o"
}

Write-Host ""
Write-Host "=== Original audit build (baseline) ==="
if (Test-Path "$outDir\max_app_spectrum.o") {
    & $OBJDUMP "$outDir\max_app_spectrum.o"
}

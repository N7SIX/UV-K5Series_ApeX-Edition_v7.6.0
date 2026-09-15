# size_compare.ps1 - compare HEAD (original) vs current app/spectrum.c object sizes
$CC = 'C:\Program Files (x86)\Arm GNU Toolchain arm-none-eabi\14.3 rel1\bin\arm-none-eabi-gcc.exe'
$SZ = 'C:\Program Files (x86)\Arm GNU Toolchain arm-none-eabi\14.3 rel1\bin\arm-none-eabi-size.exe'
$TOP = 'c:\Users\sebue\Documents\N7SIX\Software\Quansheng\UV-K5Series_ApEX-Edition_v7.6.0'
$out = Join-Path $TOP '.mapwork\sizeout'
New-Item -ItemType Directory -Force $out | Out-Null
Set-Location $TOP

# Same codegen flags as the audit build (LTO dropped so `size` reflects real codegen)
$FLG = '-Oz -Wall -Wextra -Werror -mcpu=cortex-m0 -fshort-enums -std=c2x ' +
       '-ffunction-sections -fdata-sections -fshort-wchar -fmerge-all-constants'
$INC = '-I. -Iapp -Iaudio -Ibsp -Icore -Idriver -Igraphics -Ihelper -Iradio -Isystem -Iui -Iconfig -Iglobals ' +
       '-Iexternal/CMSIS_5/CMSIS/Core/Include/ -Iexternal/CMSIS_5/Device/ARM/ARMCM0/Include'
$BASE = '-DPRINTF_INCLUDE_CONFIG_H -DAUTHOR_STRING="EGZUMER+N7SIX" -DVERSION_STRING="v7.6.10" ' +
        '-DENABLE_UART -DENABLE_BIG_FREQ -DENABLE_SMALL_BOLD -DENABLE_RSSI_BAR -DENABLE_AUDIO_BAR ' +
        '-DENABLE_SCAN_RANGES -DENABLE_FEAT_N7SIX -DENABLE_SPECTRUM -DALERT_TOT=10 -DSQL_TONE=550 ' +
        '-DAUTHOR_STRING_1="EGZUMER" -DVERSION_STRING_1="v0.22" -DAUTHOR_STRING_2="N7SIX" ' +
        '-DVERSION_STRING_2="v7.6.10" -DEDITION_STRING="ApeX" -DENABLE_EXTRA_UART_CMD'

# Config C = your actual Makefile configuration (all spectrum extras off, N7SIX spectrum OFF)
$CFG_C = "$BASE -DENABLE_PEAK_HOLD=0 -DENABLE_RSSI_SQRT=0 -DENABLE_SPECTRUM_SMOOTHING=0"
# Config A = recommended (all spectrum extras off, N7SIX spectrum on)
$CFG_A = "$BASE -DENABLE_PEAK_HOLD=0 -DENABLE_RSSI_SQRT=0 -DENABLE_SPECTRUM_SMOOTHING=0 -DENABLE_FEAT_N7SIX_SPECTRUM=1"
# Config B = everything on
$CFG_B = "$BASE -DENABLE_PEAK_HOLD=1 -DENABLE_RSSI_SQRT=1 -DENABLE_SPECTRUM_SMOOTHING=1 -DENABLE_FEAT_N7SIX_SPECTRUM=1"

# Materialise the original (committed) spectrum.c for a fair baseline
& git show HEAD:app/spectrum.c | Out-File -Encoding utf8 (Join-Path $out 'spectrum_head.c')

function Build-Size($src, $defs, $tag) {
    $obj = Join-Path $out "$tag.o"
    if (Test-Path $obj) { Remove-Item $obj -Force }
    $log = & $CC -c $src -o $obj $FLG.Split(' ') $defs.Split(' ') $INC.Split(' ') 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        Write-Output "==== FAIL $tag ===="
        Write-Output $log.TrimEnd()
        return
    }
    $s = (& $SZ --format=berkeley $obj) -join ' | '
    Write-Output ("{0,-28} {1}" -f $tag, $s)
}

Write-Output "=== CONFIG C - YOUR ACTUAL BUILD (peakhold/sqrt/smooth OFF, N7SIX spectrum OFF) ==="
Build-Size (Join-Path $out 'spectrum_head.c') $CFG_C 'HEAD_C'
Build-Size 'app/spectrum.c' $CFG_C 'NEW_C'

Write-Output ""
Write-Output "=== CONFIG A (peakhold/sqrt/smooth OFF, N7SIX spectrum ON) ==="
Build-Size (Join-Path $out 'spectrum_head.c') $CFG_A 'HEAD_A'
Build-Size 'app/spectrum.c' $CFG_A 'NEW_A'
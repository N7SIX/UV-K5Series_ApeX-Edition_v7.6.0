# check_spectrum.ps1 - compile app/spectrum.c with the Makefile default config and show all errors
$CC = 'C:\Program Files (x86)\Arm GNU Toolchain arm-none-eabi\14.3 rel1\bin\arm-none-eabi-gcc.exe'
$TOP = 'c:\Users\sebue\Documents\N7SIX\Software\Quansheng\UV-K5Series_ApEX-Edition_v7.6.0'
Set-Location $TOP

$FLG = @(
 '-c','-Oz','-Wall','-Werror','-mcpu=cortex-m0','-fshort-enums','-std=c2x',
 '-fno-delete-null-pointer-checks','-fmerge-all-constants','-fno-ipa-cp-clone','-fno-ipa-sra',
 '-fshort-wchar','-Wno-lto-type-mismatch','-ffunction-sections','-fdata-sections',
 '-DPRINTF_INCLUDE_CONFIG_H','-DAUTHOR_STRING="EGZUMER+N7SIX"','-DVERSION_STRING="v7.6.10"',
 '-DENABLE_UART','-DENABLE_BIG_FREQ','-DENABLE_SMALL_BOLD','-DENABLE_RSSI_BAR',
 '-DENABLE_AUDIO_BAR','-DENABLE_SCAN_RANGES','-DENABLE_FEAT_N7SIX','-DENABLE_SPECTRUM',
 '-DALERT_TOT=10','-DSQL_TONE=550','-DAUTHOR_STRING_1="EGZUMER"','-DVERSION_STRING_1="v0.22"',
 '-DAUTHOR_STRING_2="N7SIX"','-DVERSION_STRING_2="v7.6.10"','-DEDITION_STRING="ApeX"'
)
$INC = @('-I.','-Iapp','-Iaudio','-Ibsp','-Icore','-Idriver','-Igraphics','-Ihelper','-Iradio',
 '-Isystem','-Iui','-Iconfig','-Iglobals',
 '-Iexternal/CMSIS_5/CMSIS/Core/Include','-Iexternal/CMSIS_5/Device/ARM/ARMCM0/Include')

New-Item -ItemType Directory -Force '.mapwork\errout' | Out-Null
$log = & $CC @FLG @INC 'app/spectrum.c' -o '.mapwork\errout\spectrum.o' 2>&1 | Out-String
if ($LASTEXITCODE -eq 0) { Write-Output 'COMPILE OK' } else { Write-Output 'COMPILE FAILED' }
Write-Output $log
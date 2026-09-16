# gt_compile.ps1 - syntax-check app/spectrum.c with the real build flags
$gcc = 'C:\Program Files (x86)\Arm GNU Toolchain arm-none-eabi\14.3 rel1\bin\arm-none-eabi-gcc.exe'
$TOP = 'c:\Users\sebue\Documents\N7SIX\Software\Quansheng\UV-K5Series_ApEX-Edition_v7.6.0'
Set-Location $TOP

$inc = @('-I.','-Iapp','-Iaudio','-Ibsp','-Icore','-Idriver','-Igraphics','-Ihelper','-Iradio','-Isystem','-Iui','-Iconfig','-Iglobals',
         '-Iexternal/CMSIS_5/CMSIS/Core/Include','-Iexternal/CMSIS_5/Device/ARM/ARMCM0/Include')
$defs = @('-DPRINTF_INCLUDE_CONFIG_H','-DENABLE_UART','-DENABLE_BIG_FREQ','-DENABLE_SMALL_BOLD','-DENABLE_RSSI_BAR',
          '-DENABLE_AUDIO_BAR','-DENABLE_SCAN_RANGES','-DENABLE_FEAT_N7SIX','-DENABLE_SPECTRUM')
$flg = @('-Oz','-mcpu=cortex-m0','-fshort-enums','-fno-delete-null-pointer-checks','-std=c2x',
         '-ffunction-sections','-fdata-sections','-fshort-wchar','-fsyntax-only','-Werror')

& $gcc @flg @defs @inc 'app/spectrum.c' 2>&1 | Out-File -Encoding utf8 '.mapwork\gt_err.txt'
Write-Output "==== SPECTRUM.C ===="
Get-Content '.mapwork\gt_err.txt' | Select-String -Pattern 'error:' | ForEach-Object { $_.Line.Trim() }
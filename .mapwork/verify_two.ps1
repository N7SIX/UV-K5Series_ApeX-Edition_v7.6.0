$ErrorActionPreference = 'Stop'
Set-Location 'c:\Users\sebue\Documents\N7SIX\Software\Quansheng\UV-K5Series_ApeX-Edition_v7.6.0'
$BIN = 'C:\Program Files (x86)\Arm GNU Toolchain arm-none-eabi\14.3 rel1\bin'
$CC = "$BIN\arm-none-eabi-gcc.exe"
$INC = @('-I.','-Iapp','-Iui','-Idriver','-Ibsp','-Ihelper','-Icore','-Isystem','-Igraphics','-Iradio','-Iaudio','-Iconfig','-Iexternal/CMSIS_5/CMSIS/Core/Include')
# Same LTO + flags as the real build (CFLAGS use -Oz and -flto, LDFLAGS -flto-partition=none)
$BASE = @('-c','-Oz','-std=gnu11','-mcpu=cortex-m0','-mthumb','-fshort-wchar','-Wall','-Wextra','-Werror','-DENABLE_SPECTRUM','-DENABLE_FEAT_N7SIX','-DENABLE_UART','-flto')

foreach ($t in @('ui/main.c','core/misc.c')) {
    $out = "$env:TEMP\" + [IO.Path]::GetFileNameWithoutExtension($t) + "_lto.o"
    & $CC ($BASE + $INC + @($t,'-o',$out))
    if ($LASTEXITCODE -ne 0) { Write-Output "$t : COMPILE FAILED"; exit 1 }
    Write-Output "$t : compiled (LTO)"
}

# Try linking the two objects together - previously this was the failing step
& "$BIN\arm-none-eabi-gcc.exe" @('-mcpu=cortex-m0','-mthumb','-nostartfiles','--specs=nano.specs','-flto-partition=none',
    "$env:TEMP\main_lto.o","$env:TEMP\misc_lto.o",
    '-Wl,--entry=Reset_Handler','-o',"$env:TEMP\link_test.elf") 2>&1 | ForEach-Object { $_ }
if ($LASTEXITCODE -eq 0) {
    Write-Output 'LINK OK: no multiple-definition error'
} else {
    Write-Output "LINK result exit=$LASTEXITCODE (check above; only undefined-symbol refs to other TUs are expected)"
}

Remove-Item "$env:TEMP\main_lto.o","$env:TEMP\misc_lto.o","$env:TEMP\link_test.elf" -ErrorAction SilentlyContinue

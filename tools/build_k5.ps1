# build_k5.ps1 - direct GCC build replicating Makefile default configuration
# Usage: powershell -File tools\build_k5.ps1 [-Link]
param([switch]$Link, [switch]$Clean)

$ErrorActionPreference = 'Continue'
$TOP = Split-Path -Parent $PSScriptRoot
Set-Location $TOP

$CC = 'arm-none-eabi-gcc'
if (-not (Get-Command $CC -ErrorAction SilentlyContinue)) {
    $CC = 'C:\Program Files (x86)\Arm GNU Toolchain arm-none-eabi\14.3 rel1\bin\arm-none-eabi-gcc.exe'
}

$defines = @(
    '-DENABLE_UART','-DENABLE_BIG_FREQ',
    '-DENABLE_SMALL_BOLD','-DENABLE_CUSTOM_MENU_LAYOUT','-DENABLE_RSSI_BAR',
    '-DENABLE_AUDIO_BAR','-DENABLE_SCAN_RANGES','-DENABLE_FEAT_N7SIX',
    '-DALERT_TOT=10','-DSQL_TONE=550',
    "-DAUTHOR_STRING_1=`"EGZUMER`"","-DVERSION_STRING_1=`"v0.22`"",
    "-DAUTHOR_STRING_2=`"N7SIX`"","-DVERSION_STRING_2=`"v7.6.10A`"",
    "-DEDITION_STRING=`"Custom`"",
    '-DPRINTF_INCLUDE_CONFIG_H',
    "-DAUTHOR_STRING=`"EGZUMER+N7SIX`"","-DVERSION_STRING=`"v7.6.10A`""
)

$warnings = @('-Wall','-Wextra','-Werror')

$cflags = @(
    '-Oz','-mcpu=cortex-m0','-fshort-enums','-fno-delete-null-pointer-checks',
    '-std=c2x','-MMD','-fshort-wchar',
    '-ffat-lto-objects','-flto=auto'
) + $warnings + $defines

$inc = @(
    "-I$TOP","-I$TOP\app","-I$TOP\ui","-I$TOP\driver","-I$TOP\bsp","-I$TOP\helper",
    "-I$TOP\core","-I$TOP\system","-I$TOP\graphics","-I$TOP\radio","-I$TOP\audio",
    "-I$TOP\config","-I$TOP\external\CMSIS_5\CMSIS\Core\Include",
    "-I$TOP\external\CMSIS_5\Device\ARM\ARMCM0\Include"
)

# Object list for the default Makefile configuration + new K1 modules
$sources = @(
    'system/start.S','system/init.c','external/printf/printf.c',
    'driver/adc.c','driver/aes.c','driver/backlight.c','driver/bk4819.c','driver/crc.c',
    'driver/eeprom.c','driver/gpio.c','driver/i2c.c','driver/keyboard.c','driver/spi.c',
    'driver/st7565.c','driver/system.c','driver/systick.c','driver/uart.c',
    'app/action.c','app/app.c','app/chFrScanner.c','app/common.c','app/dtmf.c',
    'app/generic.c','app/main.c','app/menu.c',
    'app/spectrum.c','app/waterfall.c','app/scanner.c','app/uart.c',
    'audio/audio.c',
    'graphics/bitmaps.c','core/board.c','radio/dcs.c','graphics/font.c',
    'radio/frequencies.c','radio/functions.c','helper/battery.c','helper/battery_calibration.c',
    'helper/boot.c','core/misc.c','radio/radio.c','system/scheduler.c','core/settings.c',
    'ui/battery.c','ui/helper.c','ui/inputbox.c','ui/main.c','ui/menu.c','ui/mdc.c',
    'ui/scanner.c','ui/status.c','ui/ui.c','ui/welcome.c',
    'system/version.c','system/main.c'
)

$outDir = Join-Path $TOP 'build\k5obj'
if ($Clean) { Remove-Item $outDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force $outDir | Out-Null

$failed = 0
$objs = @()
foreach ($src in $sources) {
    if ($src -like '*.S') {
        $obj = Join-Path $outDir ([IO.Path]::GetFileNameWithoutExtension($src) + '_start.o')
        & $CC -c -mcpu=cortex-m0 -DENABLE_UART "-I$TOP" "-I$TOP\bsp" "-I$TOP\external\CMSIS_5\CMSIS\Core\Include" "-I$TOP\external\CMSIS_5\Device\ARM\ARMCM0\Include" $src -o $obj 2>&1 | Out-String | Write-Output
        if ($LASTEXITCODE -ne 0) { $failed++ } else { $objs += $obj }
        continue
    }
    $obj = Join-Path $outDir (($src -replace '[/\\]','_') + '.o')
    $objs += $obj
    if (Test-Path $obj) { continue }   # incremental
    $log = & $CC @cflags @inc -c $src -o $obj 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        $failed++
        Write-Output "==== FAIL: $src ===="
        Write-Output $log.TrimEnd()
    }
}

Write-Output ("---- compile done: {0} failed, {1} ok ----" -f $failed, ($objs.Count - $failed))

if ($failed -eq 0 -and $Link) {
    $elf = Join-Path $outDir 'firmware.elf'
    $ldflags = @('-z','noexecstack','-mcpu=cortex-m0','-nostartfiles',
        "-Wl,-T,$TOP\config\firmware.ld",' -Wl,--gc-sections'.Trim(),
        '-fshort-wchar','-Wl,--no-warn-mismatch','--specs=nano.specs','-flto=auto')
    & $CC @ldflags ($objs | ForEach-Object { "`"$_`"" }) -o $elf 2>&1 | Out-String | Write-Output
    if ($LASTEXITCODE -eq 0) {
        & arm-none-eabi-size $elf
        & arm-none-eabi-objcopy -O binary $elf (Join-Path $outDir 'firmware.bin')
    } else {
        Write-Output "---- LINK FAILED ----"
    }
}

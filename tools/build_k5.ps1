# build_k5.ps1 - local FLASH/RAM probe that mirrors the Makefile's default config.
#
# WHY THIS EXISTS
#   The authoritative build is ./compile-with-docker.sh ApeX (Alpine GCC 15.1.0);
#   this script needs no Docker so you can get a quick size reading offline.
#
#   !! DO NOT JUDGE FLASH FITNESS FROM THIS SCRIPT.  Measured on v7.6.10B, same
#   !! sources and same flags, same 3,564 B of RAM in both:
#       Docker  arm-none-eabi-gcc (Alpine Linux) 15.1.0 -> 61,364 B  FITS (76 B free)
#       local   Arm GNU Toolchain 14.3.Rel1 (arm-14.174)-> 61,984 B  544 B OVER
#   !! The local GCC emits ~620 B MORE code for the identical configuration, so
#   !! the shipping config legitimately overflows here while it fits in Docker.
#   !! Use this build for A/B work (same toggle flipped both ways), where only
#   !! the DELTA is meaningful, and for bench flashing.  Every release number
#   !! and every "do we still fit?" decision comes from the Docker build.
#
# HOW IT STAYS IN SYNC
#   The version/author/edition strings, SQL_TONE and every ENABLE_* toggle are
#   PARSED FROM THE MAKEFILE at run time, so a version bump or a flipped
#   default needs no edit here.  String macros are handed to the compiler
#   through a generated header (build/k5obj/k5_strings.h, -include) because
#   PowerShell 5.1 strips \" when an array is splatted into a native command,
#   which made the old hard-coded copy fail 3 files.  All of those macros are
#   #ifndef-guarded in system/version.c, so -include behaves exactly like -D.
#   Check the flag set against the real recipe any time the Makefile changes:
#       make -n TARGET=ApeX EDITION_STRING=ApeX        (inside Docker)
#       powershell -File tools\build_k5.ps1 -ShowFlags (here)
#
# USAGE
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\build_k5.ps1 [flags]
#     (no flag)   -Compile
#     -Compile    build every object the default config needs (incremental)
#     -Link       compile + link, then print FLASH/RAM vs the 61,440 B budget
#     -Pack       implies -Link, and also write the flashable .packed.bin
#     -Clean      delete build/k5obj first (runs automatically if flags changed)
#     -ShowFlags  print the exact gcc command lines and exit (audit vs make -n)
#     -Help       show this header and exit
#     -Edition X  EDITION_STRING override (default: whatever the Makefile says)
#
# Objects land in build/k5obj (flat, '/' -> '_'), outputs as
#   build/k5obj/n7six.<Edition>.<ver>.elf / -k5.<ver>.bin / -k5.<ver>.packed.bin
# just like the Makefile names them under build/ApeX/.

param(
    [switch]$Compile, [switch]$Link, [switch]$Pack, [switch]$Clean,
    [switch]$ShowFlags, [switch]$Help,
    [string]$Edition = ''
)

if ($Help) { (Get-Content -LiteralPath $PSCommandPath -TotalCount 37) -replace '^#\s?',''; exit 0 }

$ErrorActionPreference = 'Continue'
$TOP = Split-Path -Parent $PSScriptRoot
Set-Location $TOP
if (-not (Test-Path (Join-Path $TOP 'config\firmware.ld'))) { throw "repo root not found (TOP=$TOP)" }

# ---------------------------------------------------------------- toolchain --
function Find-Tool([string]$name) {
    $c = Get-Command $name -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    $hit = Get-ChildItem 'C:\Program Files (x86)\Arm GNU Toolchain arm-none-eabi',
                         'C:\Program Files\Arm GNU Toolchain arm-none-eabi' `
                         -Filter $name -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($hit) { return $hit.FullName }
    throw "$name not found - install an Arm GNU toolchain or put it on PATH"
}
$CC      = Find-Tool 'arm-none-eabi-gcc.exe'

# ---------------------------------------------- configuration parsed from Makefile
# Reads the FIRST plain assignment of a variable ("X ?= v" / "X = v"), dropping
# a trailing "# comment" and skipping values that still contain $(...).
$MakeLines = Get-Content -LiteralPath (Join-Path $TOP 'Makefile')
function MkVal([string]$name, [string]$fallback = '') {
    foreach ($l in $MakeLines) {
        if ($l -match ('^\s*' + [regex]::Escape($name) + '\s*\??=\s*(.+?)\s*(?:\s#.*)?$')) {
            $v = $Matches[1].Trim()
            if ($v -and $v -notmatch '\$\(') { return $v }
        }
    }
    return $fallback
}
function MkOn([string]$name) { (MkVal $name '0') -eq '1' }

# clang and overlay builds need a different object list / linker; both are off
# in the shipping config, so refuse rather than silently build something else.
if ((MkVal 'ENABLE_CLANG' '0') -ne '0') { throw 'ENABLE_CLANG=1 in Makefile: this helper supports GCC only' }
$LTO = MkOn 'ENABLE_LTO'
# The Makefile forces OVERLAY off whenever LTO is on (Makefile:173-176).
$Overlay = (MkOn 'ENABLE_OVERLAY') -and (-not $LTO)

$Author1 = MkVal 'AUTHOR_STRING_1' 'EGZUMER'
$Ver1    = MkVal 'VERSION_STRING_1' 'v0.22'
$Author2 = MkVal 'AUTHOR_STRING_2' 'N7SIX'
$Ver2    = MkVal 'VERSION_STRING_2' 'v0.0.0'
$N7Six   = MkOn 'ENABLE_FEAT_N7SIX'
if (-not $Edition) { $Edition = MkVal 'EDITION_STRING' 'Custom' }
$git = Get-Command git -ErrorAction SilentlyContinue
$Commit = if ($git) { (& git rev-parse --short HEAD 2>$null | Select-Object -First 1) } else { $null }
if (-not $Commit) { $Commit = 'N/A' }
# Makefile:336-337 - with the N7SIX feature set the banner is "A1+A2" + v2;
# without it VERSION_STRING is the git describe / short-HEAD value.
if ($N7Six) { $Author = "$Author1+$Author2"; $Version = $Ver2 }
else        { $Author = $Author1;            $Version = $Commit }

# Presence-only switches: macro name == Makefile variable name.  Listed in the
# order the Makefile emits them (Makefile:485-684) so -ShowFlags lines up with
# `make -n` for auditing.  A variable the Makefile only tests and never assigns
# (ENABLE_SINGLE_VFO_CHAN, ENABLE_BAND_SCOPE, ENABLE_BACKLIGHT_ON_RX) has no
# default here and therefore resolves to off, exactly as in make.
$Present = @(
    'ENABLE_SWD','ENABLE_AIRCOPY','ENABLE_FMRADIO','ENABLE_UART','ENABLE_BIG_FREQ',
    'ENABLE_SMALL_BOLD','ENABLE_NOAA','ENABLE_VOICE','ENABLE_VOX','ENABLE_ALARM',
    'ENABLE_TX1750','ENABLE_PWRON_PASSWORD','ENABLE_KEEP_MEM_NAME','ENABLE_WIDE_RX',
    'ENABLE_TX_WHEN_AM','ENABLE_F_CAL_MENU','ENABLE_CTCSS_TAIL_PHASE_SHIFT','ENABLE_BOOT_BEEPS',
    'ENABLE_SHOW_CHARGE_LEVEL','ENABLE_REVERSE_BAT_SYMBOL','ENABLE_NO_CODE_SCAN_TIMEOUT',
    'ENABLE_AM_FIX','ENABLE_AM_FIX_SHOW_DATA','ENABLE_SQUELCH_MORE_SENSITIVE',
    'ENABLE_FASTER_CHANNEL_SCAN','ENABLE_RSSI_BAR','ENABLE_AUDIO_BAR','ENABLE_COPY_CHAN_TO_VFO',
    'ENABLE_REDUCE_LOW_MID_TX_POWER','ENABLE_BYP_RAW_DEMODULATORS','ENABLE_BLMIN_TMP_OFF',
    'ENABLE_SCAN_RANGES','ENABLE_DTMF_CALLING','ENABLE_REGA','ENABLE_AGC_SHOW_DATA',
    'ENABLE_FLASHLIGHT','ENABLE_UART_RW_BK_REGS','ENABLE_CUSTOM_MENU_LAYOUT',
    'ENABLE_FEAT_N7SIX','ENABLE_FEAT_N7SIX_MEM','ENABLE_FEAT_N7SIX_QRCODE','ENABLE_FEAT_N7SIX_GAME',
    'ENABLE_FEAT_N7SIX_SCREENSHOT','ENABLE_FEAT_N7SIX_SPECTRUM','ENABLE_FEAT_N7SIX_RX_TX_TIMER',
    'ENABLE_FEAT_N7SIX_CHARGING_C','ENABLE_FEAT_N7SIX_SLEEP','ENABLE_FEAT_N7SIX_RESUME_STATE',
    'ENABLE_FEAT_N7SIX_NARROWER','ENABLE_FEAT_N7SIX_INV','ENABLE_FEAT_N7SIX_CTR','ENABLE_FEAT_N7SIX_VOL',
    'ENABLE_FEAT_N7SIX_RESET_CHANNEL','ENABLE_FEAT_N7SIX_PMR','ENABLE_FEAT_N7SIX_GMRS_FRS_MURS',
    'ENABLE_FEAT_N7SIX_CA','ENABLE_FEAT_N7SIX_DEBUG','ENABLE_EXTRA_UART_CMD','ENABLE_WATCHDOG'
)
# Spectrum toggles whose macro name differs from the Makefile variable, and
# which the Makefile always passes as =0/=1 (Makefile:439-484). Order matters
# only so -ShowFlags lines up with `make -n`.
$Numeric = [ordered]@{
    'ENABLE_PEAK_HOLD'                = 'ENABLE_SPECTRUM_PEAK_HOLD'
    'ENABLE_SPECTRUM_SMOOTHING'       = 'ENABLE_SPECTRUM_SMOOTH'
    'ENABLE_SPECTRUM_SHADE'           = 'ENABLE_SPECTRUM_SHADE'
    'ENABLE_RSSI_SQRT'                = 'ENABLE_SPECTRUM_RSSI_SQRT'
    'ENABLE_SPECTRUM_REG_MENU'        = 'ENABLE_SPECTRUM_REG_MENU'
    'SPECTRUM_INTERLACE_LARGE_SWEEPS' = 'ENABLE_SPECTRUM_INTERLACE'
    'ENABLE_SPECTRUM_BLACKLIST'       = 'ENABLE_SPECTRUM_BLACKLIST'
    'ENABLE_SPECTRUM_BIDIR'           = 'ENABLE_SPECTRUM_BIDIR'
    'ENABLE_SPECTRUM_K1_EXTRAS'       = 'ENABLE_SPECTRUM_K1_EXTRAS'
}

$defines = New-Object System.Collections.Generic.List[string]
$defines.Add('-DPRINTF_INCLUDE_CONFIG_H')
if (MkOn 'ENABLE_SPECTRUM')  { $defines.Add('-DENABLE_SPECTRUM') }
if (MkOn 'ENABLE_WATERFALL') { $defines.Add('-DENABLE_WATERFALL') }
foreach ($macro in $Numeric.Keys) {
    $v = MkVal $Numeric[$macro] '0'
    $defines.Add("-D$macro=$(if ($v -eq '1') { 1 } else { 0 })")
}
foreach ($t in $Present) { if (MkOn $t) { $defines.Add("-D$t") } }
$rescue = MkVal 'ENABLE_FEAT_N7SIX_RESCUE_OPS' '0'
if ($rescue -eq '1' -or $rescue -eq '2') { $defines.Add("-DENABLE_FEAT_N7SIX_RESCUE_OPS=$rescue") }
if ($N7Six) {
    # ALERT_TOT is hard-coded to 10 by Makefile:613 (there is no variable to parse).
    $defines.Add('-DALERT_TOT=10')
    $defines.Add('-DSQL_TONE=' + (MkVal 'SQL_TONE' '550'))
} else {
    $defines.Add('-DSQL_TONE=550')      # Makefile:620
}

$OBJCOPY = Find-Tool 'arm-none-eabi-objcopy.exe'
$SIZE    = Find-Tool 'arm-none-eabi-size.exe'

# -------------------------------------------------------------------- flags --
# Same order as Makefile:374-430.  The duplicate -ffunction-sections
# -fdata-sections the Makefile emits twice is passed once (no behavioural
# difference).  -MMD matches the Makefile but produces no .d handling here, so
# rebuild with -Clean after editing a header.
$cflags = New-Object System.Collections.Generic.List[string]
$cflags.Add('-Oz'); $cflags.Add('-Wall'); $cflags.Add('-Werror'); $cflags.Add('-mcpu=cortex-m0')
$cflags.Add('-fshort-enums'); $cflags.Add('-fno-delete-null-pointer-checks')
$cflags.Add('-std=c2x'); $cflags.Add('-MMD')
$cflags.Add('-fmerge-all-constants'); $cflags.Add('-fno-ipa-cp-clone'); $cflags.Add('-fno-ipa-sra')
$cflags.Add('-fno-inline-small-functions')
$cflags.Add('-fshort-wchar'); $cflags.Add('-Wno-lto-type-mismatch')
$cflags.Add('-ffunction-sections'); $cflags.Add('-fdata-sections')
if ($LTO)    { $cflags.Add('-flto=auto'); $cflags.Add('-ffat-lto-objects'); $cflags.Add('-flto-partition=none') }
if ($Overlay){ $cflags.Add('-DENABLE_OVERLAY') }
$cflags.Add('-Wextra')
foreach ($d in $defines) { $cflags.Add($d) }

$AsFlags = @('-c', '-mcpu=cortex-m0')
if ($Overlay) { $AsFlags += '-DENABLE_OVERLAY' }

# Makefile:702-716 (INC).  Absolute paths with forward slashes; "-I" and the
# path are passed as two separate tokens exactly like -I $(TOP)/app, so a repo
# path containing spaces survives PowerShell's native-argument re-quoting.
$TopF = $TOP -replace '\\','/'
$Inc  = @()
foreach ($d in @('', 'app', 'ui', 'driver', 'bsp', 'helper', 'core', 'system',
                 'graphics', 'radio', 'audio', 'config',
                 'external/CMSIS_5/CMSIS/Core/Include',
                 'external/CMSIS_5/Device/ARM/ARMCM0/Include')) {
    $Inc += '-I'
    $Inc += "$TopF/$d"
}

# ------------------------------------------- object list (Makefile OBJS logic) --
# Mirrors Makefile:182-294 for the toggles that actually add or remove a
# translation unit.  Toggles that only add code inside an existing file do not
# belong here.
$Fm       = MkOn 'ENABLE_FMRADIO'
$Uart     = MkOn 'ENABLE_UART'
$Aircopy  = MkOn 'ENABLE_AIRCOPY'
$Rega     = MkOn 'ENABLE_REGA'
$Flashlit = MkOn 'ENABLE_FLASHLIGHT'
$Spectrum = MkOn 'ENABLE_SPECTRUM'
$Waterfall = MkOn 'ENABLE_WATERFALL'
$AmFix    = MkOn 'ENABLE_AM_FIX'
$PwOn     = MkOn 'ENABLE_PWRON_PASSWORD'
$Shot     = MkOn 'ENABLE_FEAT_N7SIX_SCREENSHOT'
$Game     = MkOn 'ENABLE_FEAT_N7SIX_GAME'

$Sources = @()
$Sources += @(
    'system/start.S', 'system/init.c', 'external/printf/printf.c', 'driver/adc.c')
if ($Overlay) { $Sources += 'system/sram-overlay.c' }
if ($Uart)     { $Sources += 'driver/aes.c' }
$Sources += 'driver/backlight.c'
if ($Fm)       { $Sources += 'driver/bk1080.c' }
$Sources += 'driver/bk4819.c'
if ($Uart -or $Aircopy) { $Sources += 'driver/crc.c' }
$Sources += @('driver/eeprom.c', 'driver/py25q16.c')
if ($Overlay)  { $Sources += 'driver/flash.c' }
$Sources += @('driver/gpio.c', 'driver/i2c.c', 'driver/keyboard.c', 'driver/spi.c',
               'driver/st7565.c', 'driver/system.c', 'driver/systick.c')
if ($Uart)     { $Sources += 'driver/uart.c' }
$Sources += 'app/action.c'
if ($Aircopy)  { $Sources += 'app/aircopy.c' }
$Sources += @('app/app.c', 'app/chFrScanner.c', 'app/common.c', 'app/dtmf.c')
if ($Rega)      { $Sources += 'app/rega.c' }
if ($Flashlit)  { $Sources += 'app/flashlight.c' }
if ($Fm)        { $Sources += 'app/fm.c' }
$Sources += @('app/generic.c', 'app/main.c', 'app/menu.c')
if ($Spectrum) {
    $Sources += 'app/spectrum.c'
    if ($Waterfall) { $Sources += 'app/waterfall.c' }
}
if ($Shot)  { $Sources += 'system/screenshot.c' }
if ($Game)  { $Sources += 'app/breakout.c' }
$Sources += 'app/scanner.c'
if ($Uart)  { $Sources += 'app/uart.c' }
if ($AmFix) { $Sources += 'audio/am_fix.c' }
$Sources += @('audio/audio.c', 'graphics/bitmaps.c', 'core/board.c', 'radio/dcs.c',
               'graphics/font.c', 'radio/frequencies.c', 'radio/functions.c',
               'helper/battery.c', 'helper/battery_calibration.c', 'helper/boot.c',
               'core/misc.c', 'radio/radio.c', 'system/scheduler.c', 'core/settings.c',
               'globals/ui_globals.c')
if ($Aircopy) { $Sources += 'ui/aircopy.c' }
$Sources += 'ui/battery.c'
if ($Fm)      { $Sources += 'ui/fmradio.c' }
$Sources += @('ui/helper.c', 'ui/inputbox.c')
if ($PwOn)    { $Sources += 'ui/lock.c' }
$Sources += @('ui/main.c', 'ui/menu.c', 'ui/scanner.c', 'ui/status.c', 'ui/ui.c',
               'ui/welcome.c', 'system/version.c', 'system/main.c')

$Missing = @($Sources | Where-Object { -not (Test-Path (Join-Path $TOP ($_ -replace '/', '\'))) })
if ($Missing.Count) { throw "source list refers to files that do not exist: $($Missing -join ', ')" }


# ------------------------------------------------------------------ out dir --
$OutDir = Join-Path $TOP 'build\k5obj'
if ($Clean -and (Test-Path $OutDir)) { Remove-Item $OutDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$StrRel = 'build/k5obj/k5_strings.h'          # forward slashes: passed to the compiler
$StrHeader = Join-Path $OutDir 'k5_strings.h'

# String macros (Makefile:431 and 615-618).  Force-included from a generated
# header instead of -D on the command line: PowerShell 5.1 drops the \" when an
# array is splatted into a native program, so "-DAUTHOR_STRING=`"EGZUMER`""
# arrives as -DAUTHOR_STRING=EGZUMER+N7SIX and the compiler reports
#   <command-line>: error: expected ',' or ';' before 'EGZUMER'
# All of these macros are #ifndef-guarded (system/version.c), so a header that
# is in scope before the first line behaves exactly like -D.
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('/* generated by tools/build_k5.ps1 - mirrors the Makefile -D string macros */')
[void]$sb.AppendLine('#ifndef K5_BUILD_STRINGS_H')
[void]$sb.AppendLine('#define K5_BUILD_STRINGS_H')
[void]$sb.AppendLine("#define AUTHOR_STRING `"$Author`"")
[void]$sb.AppendLine("#define VERSION_STRING `"$Version`"")
if ($N7Six) {
    [void]$sb.AppendLine("#define AUTHOR_STRING_1 `"$Author1`"")
    [void]$sb.AppendLine("#define VERSION_STRING_1 `"$Ver1`"")
    [void]$sb.AppendLine("#define AUTHOR_STRING_2 `"$Author2`"")
    [void]$sb.AppendLine("#define VERSION_STRING_2 `"$Ver2`"")
    [void]$sb.AppendLine("#define EDITION_STRING `"$Edition`"")
    [void]$sb.AppendLine("#define BUILD_COMMIT `"$Commit`"")
}
[void]$sb.AppendLine('#endif')
[System.IO.File]::WriteAllText($StrHeader, $sb.ToString())

# Rebuild whenever the flag set changes.  Like make, this script has no CFLAGS
# dependency, so without this guard a toggle flip would silently reuse stale
# objects and a "no size change" measurement would lie (see FLASH_AUDIT_K1.md 7).
$StampFile = Join-Path $OutDir 'flags.stamp'
$Stamp     = (($cflags + $Inc) -join "`n") + "`nstring-macros:`n" + [IO.File]::ReadAllText($StrHeader)
if ((-not $Clean) -and (Test-Path $StampFile) -and ([IO.File]::ReadAllText($StampFile) -ne $Stamp)) {
    Write-Output 'flags changed since the last run -> removing stale objects'
    Get-ChildItem $OutDir -Filter '*.o' -ErrorAction SilentlyContinue | Remove-Item -Force
}
[IO.File]::WriteAllText($StampFile, $Stamp)

# ------------------------------------------------------------------ link line --
# Verbatim LDFLAGS from Makefile:686-694 (the linker script path is relative for
# the same reason it is there: the script runs from the repo root).
# NOTE: the Makefile's LDFLAGS is re-initialised at line 686, so the
# -flto=auto it adds at line 415 is NOT in the link line.  That is intentional
# and verified: -flto-partition=none implies -flto, and passing -flto=auto as
# well measured byte-identical (61,364 B).
$LdFlags = @('-z', 'noexecstack', '-mcpu=cortex-m0', '-nostartfiles',
             '-Wl,-T,config/firmware.ld', '-Wl,--gc-sections', '-fshort-wchar',
             '-Wl,--no-warn-mismatch', '-Wno-lto-type-mismatch',
             '-flto-partition=none', '--specs=nano.specs')
if (MkOn 'DEBUG') { $LdFlags += '-g' }

$Elf = Join-Path $OutDir ('n7six.' + $Edition + '.' + $Version + '.elf')
$Bin = Join-Path $OutDir ('n7six.' + $Edition + '-k5.' + $Version + '.bin')

if ($ShowFlags) {
    Write-Output "== .S =="
    Write-Output (($CC + ' ' + (($AsFlags + $Inc + @('-c', 'system/start.S', '-o', 'build/k5obj/system_start.S.o')) -join ' ')))
    Write-Output "== .c =="
    Write-Output (($CC + ' ' + (($cflags + @('-include', $StrRel) + $Inc + @('-c', 'app/spectrum.c', '-o', 'build/k5obj/app_spectrum.c.o')) -join ' ')))
    Write-Output "== link =="
    Write-Output (($CC + ' ' + (($LdFlags + @('<objects>') + @('-o', $Elf)) -join ' ')))
    Write-Output "== string macros ($StrRel) =="
    Write-Output ([IO.File]::ReadAllText($StrHeader).TrimEnd())
    Write-Output ("== {0} translation units ==" -f $Sources.Count)
    exit 0
}


# ------------------------------------------------------------------- compile --
# Compile errors must not be fatal mid-loop: report every failing TU at once.
$Failed = @()
$Compiled = 0
$Objs = @()
foreach ($src in $Sources) {
    $obj = Join-Path $OutDir (($src -replace '[/\\]', '_') + '.o')
    $Objs += $obj
    $srcFile = Join-Path $TOP ($src -replace '/', '\')
    if ((Test-Path $obj) -and ((Get-Item $obj).LastWriteTime -gt (Get-Item $srcFile).LastWriteTime)) {
        continue                                   # incremental, like make
    }
    # Makefile:834-838
    #   %.o: %.c   ->  $(CC) $(CFLAGS) $(INC) -c $< -o $@
    #   %.o: %.S   ->  $(AS) $(ASFLAGS) $< -o $@          (no CFLAGS, no INC)
    if ($src -like '*.S') {
        $argv = @($AsFlags) + @($src, '-o', $obj)
    } else {
        $argv = @($cflags) + @('-include', $StrRel) + @($Inc) + @('-c', $src, '-o', $obj)
    }
    $out = & $CC @argv 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        $Failed += $src
        Write-Host "==== FAIL: $src ===="
        Write-Host $out.TrimEnd()
    } elseif ($out.Trim()) {
        Write-Host "==== warnings: $src ===="
        Write-Host $out.TrimEnd()
    }
    $Compiled++
}
Write-Host ("compiled {0} TU(s), {1} object(s) up to date, {2} failed" -f `
    $Compiled, ($Objs.Count - $Compiled), $Failed.Count)
if ($Failed.Count) {
    Write-Host ("FAILED: {0}" -f ($Failed -join ', '))
    exit 1
}

# ----------------------------------------------------------------------- link --
if ($Pack) { $Link = $true }             # -Pack needs a .bin
if (-not ($Link -or $Pack)) {
    Write-Host '---- objects in build\k5obj (use -Link for the FLASH budget) ----'
    exit 0
}

$ld  = $LdFlags + @($Objs) + @('-o', $Elf)
# NOTE: not $link - PowerShell variable names are case-insensitive, so $link
# would collide with the -Link switch parameter.
$linkOut = & $CC @ld 2>&1 | Out-String
if ($linkOut.Trim()) { Write-Host $linkOut.TrimEnd() }
if ($LASTEXITCODE -ne 0) { Write-Host '---- LINK FAILED ----'; exit 1 }
& $OBJCOPY -O binary $Elf $Bin
if ($LASTEXITCODE -ne 0) { Write-Host 'objcopy failed'; exit 1 }

# FLASH/RAM exactly as the Makefile's all: recipe measures them:
#   FLASH = text + data, RAM = data + bss, image = the real .bin size.
# "arm-none-eabi-size" prints "  text   data   bss   dec   hex  file", so the
# numbers line has to be trimmed before splitting - otherwise the leading spaces
# produce an empty first field and text/data/bss end up shifted by one.
$rows = (& $SIZE $Elf 2>&1 | Out-String) -split "`r?`n"
$line = $rows | Where-Object { $_ -match '^\s*\d+\s+\d+\s+\d+' } | Select-Object -First 1
if (-not $line) { Write-Host "cannot parse size output:"; $rows | Write-Host; exit 1 }
$row = $line.Trim() -split '\s+'
$text = [int]$row[0]; $data = [int]$row[1]; $bss = [int]$row[2]
$flash = $text + $data
$ram   = $data + $bss
$img   = (Get-Item $Bin).Length
$FLIM  = 61440; $RLIM = 8192

Write-Host ''
Write-Host 'Memory Region      Used Size  Region Size   % Used'
Write-Host ("{0,-15} {1,10} {2,12} {3,9}" -f 'FLASH', $flash, $FLIM, ('{0}%' -f [math]::Round(100 * $flash / $FLIM, 2)))
Write-Host ("{0,-15} {1,10} {2,12} {3,9}" -f 'RAM', $ram, $RLIM, ('{0}%' -f [math]::Round(100 * $ram / $RLIM, 2)))
Write-Host ("{0,-15} {1,10}"   -f 'image (.bin)', $img)
Write-Host ("text {0}  data {1}  bss {2}" -f $text, $data, $bss)
if ($img -gt $FLIM) {
    Write-Host ''
    Write-Host ("  !! WARNING: image {0} B exceeds the flashable limit {1} B (0xEFFF) by {2} B." -f $img, $FLIM, ($img - $FLIM))
    Write-Host  '     The UV-K5/K6 bootloader owns 0xF000-0xFFFF, so UVTools rejects'
    Write-Host  '     application images larger than 0xEFFF.  Disable features or shrink code.'
} else {
    Write-Host ("  OK: {0} B free in the 61440 B flashable window" -f ($FLIM - $img))
}
Write-Host ''
Write-Host ("elf  : {0}" -f $Elf)
Write-Host ("bin  : {0}" -f $Bin)

# ----------------------------------------------------------------------- pack --
if ($Pack) {
    $packPs1 = Join-Path $TOP 'config\fw-pack.ps1'
    if (-not (Test-Path $packPs1)) { Write-Host "missing packer: $packPs1"; exit 1 }
    $Packed = Join-Path $OutDir ('n7six.' + $Edition + '-k5.' + $Version + '.packed.bin')
    & $packPs1 -InBin $Bin -Edition $Edition -Version $Version -OutBin $Packed
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $Packed)) { Write-Host 'fw-pack failed'; exit 1 }
    $plen = (Get-Item $Packed).Length
    Write-Host ("packed : {0} ({1} B)" -f $Packed, $plen)
    # The packer inserts a 16-byte version block at 0x2000 (+2 B CRC), so the
    # flashable image is the .bin + 18 B - that is what has to stay <= 61440.
    if ($plen -gt $FLIM) {
        Write-Host ("  !! WARNING: packed image {0} B exceeds {1} B by {2} B." -f $plen, $FLIM, ($plen - $FLIM))
    }
}
exit 0


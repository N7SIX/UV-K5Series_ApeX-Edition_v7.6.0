<#
.SYNOPSIS
    Decode and audit the UV-K5 VFO (frequency mode) band-slot records of an
    EEPROM dump, and point out which stored field is muting or mangling RX
    audio on one VFO but not the other.

.DESCRIPTION
    Why this tool exists
    --------------------
    In dual watch, VFO A and VFO B are two *separate* 16 byte records inside
    the same 32 byte band slot (radio/radio.c:249, core/settings.c:855):

        base = 0x0C80 + (band * 32) + (VFO * 16)      band = channel - 200

    The fields shared between the two VFOs of a band (band index, compander,
    scan lists) live in one attribute byte at 0x0D60 + (channel -and -bnot 7)
    + (channel -band 7) = 0x0E28 + band, so they are *identical* for VFO A and
    VFO B.

    That leaves exactly one place where a symptom can be VFO-B-only while both
    VFOs sit in the same band and the RSSI bar works: the 16 byte per-VFO
    record below.  RX audio is gated by pRX->CodeType and shaped by
    pVfo->Modulation, both of which come straight out of this record:

        app/app.c:197  HandleIncoming() only calls APP_StartListening() when
                       gCurrentCodeType == CODE_TYPE_OFF, or when the
                       programmed CTCSS/DCSS tone has actually been detected.
                       The squelch can be open (RX icon + RSSI bar) while the
                       speaker stays dead.
        radio/functions.c:68
                       gCurrentCodeType = (Modulation != FM) ? OFF
                                            : pRX->CodeType
        radio/radio.c:1042 RADIO_SetModulation() picks the AF path (FM/AM/USB)
                       from the same byte; a non-FM demodulator on an FM
                       signal gives weak, garbled, "no correct MDC preamble"
                       audio rather than silence.

    Record layout (load: radio/radio.c:258-385, store: core/settings.c:865-890):

        +00..03  RX frequency           uint32 LE, units of 10 Hz
        +04..07  TX offset frequency    uint32 LE, units of 10 Hz
        +08      RX code index          (CTCSS_Options[] / DCS_Options[])
        +09      TX code index
        +10      bit3:0 RX code type, bit7:4 TX code type
                 (0 = off, 1 = CTCSS, 2 = DCS, 3 = DCS inverted)
        +11      bit3:0 TX offset direction, bit7:4 modulation
                 (0 = FM, 1 = AM, 2 = USB)
        +12      bit0 reverse, bit1 bandwidth, bit4:2 power,
                 bit5 busy lock, bit6 TX lock
        +13      bit0 DTMF decode, bit3:1 PTT ID
        +14      step setting
        +15      scrambling type

    This script only reads.  -PatchTo writes a *new* corrected image and never
    touches the input file, so the original k5prog backup stays intact.

.PARAMETER Path
    8 KiB (0x2000) raw EEPROM image, e.g. the file produced by
    "k5prog -R -E -f eeprom.bin" or by the k5prog-win GUI "Read EEPROM".
    Shorter files are padded with 0xFF (unwritten EEPROM).

.PARAMETER Find
    Comma separated frequencies in MHz to look for, e.g. "147.650,146.520".
    Only those records get the full detail block; without -Find, every record
    that produced a finding is detailed.

.PARAMETER Detail
    Detail every record instead of only the ones with findings.

.PARAMETER Bytes
    Hex dump the 16 byte records and, when a band holds two VFOs, show a byte
    level diff between them.

.PARAMETER PatchTo
    Write a corrected copy of the image to this path.  Requires -Find.

.PARAMETER ForceFM
    Patch option: force modulation = FM in the matched record(s).

.PARAMETER ClearRxTone
    Patch option: RX code type = off and RX code = 0 in the matched record(s).

.PARAMETER ClearTxTone
    Patch option: TX code type = off and TX code = 0 in the matched record(s).

.PARAMETER Wide
    Patch option: bandwidth = wide (12.5 kHz) in the matched record(s).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\rx_probe_vfo.ps1 eeprom.bin

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\rx_probe_vfo.ps1 eeprom.bin -Find 147.650 -Bytes

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\rx_probe_vfo.ps1 eeprom.bin `
        -Find 147.650 -ForceFM -ClearRxTone -PatchTo eeprom_fixed.bin

.NOTES
    See Documentation\VFO_RX_SILENCE_DIAGNOSTIC.md for the full procedure.
    The decode rules are taken verbatim from RADIO_ConfigureChannel(); if that
    function ever changes, this script has to follow it.
    Exit code 0 = nothing critical, 2 = at least one CRIT record.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Path,
    [string]$Find = '',
    [switch]$Detail,
    [switch]$Bytes,
    [string]$PatchTo = '',
    [switch]$ForceFM,
    [switch]$ClearRxTone,
    [switch]$ClearTxTone,
    [switch]$Wide
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$EepromSize = 0x2000
$VfoBase    = 0x0C80        # band slot array for frequency channels 200..206
$AttrBase   = 0x0D60 + 200  # gMR_ChannelAttributes[200..206], one byte per band

# radio/frequencies.c frequencyBandTable[], ENABLE_WIDE_RX = 0 (ApeX config).
# Same units as the stored frequencies: 10 Hz.  Verbatim copy of
# radio/frequencies.c frequencyBandTable[] (non-ENABLE_WIDE_RX build).
$BandTable = @(
    @{ lower =  5000000; upper =  7600000; name = ' 50- 76 MHz' },
    @{ lower = 10800000; upper = 13700000; name = '108-137 MHz' },
    @{ lower = 13700000; upper = 17400000; name = '137-174 MHz' },
    @{ lower = 17400000; upper = 35000000; name = '174-350 MHz' },
    @{ lower = 35000000; upper = 40000000; name = '350-400 MHz' },
    @{ lower = 40000000; upper = 47000000; name = '400-470 MHz' },
    @{ lower = 47000000; upper = 60000000; name = '470-600 MHz' }
)

$CodeTypeNames = @('off', 'CTCSS', 'DCS', 'DCS-inv')
$ModulationStr = @('FM', 'AM', 'USB')
$PowerStr      = @('LOW1', 'LOW2', 'MID', 'HIGH', 'HIGH1', 'HIGH2', 'P4', 'P5')

# radio/dcs.c CTCSS_Options[], value = tone * 10 Hz
$CtcssOptions = @(
     670,  693,  719,  744,  770,  797,  825,  854,  885,  915,
     948,  974, 1000, 1035, 1072, 1109, 1148, 1188, 1230, 1273,
    1318, 1365, 1413, 1462, 1514, 1567, 1598, 1622, 1655, 1679,
    1713, 1738, 1773, 1799, 1835, 1862, 1899, 1928, 1966, 1995,
    2035, 2065, 2107, 2181, 2257, 2291, 2336, 2418, 2503, 2541
)

# radio/dcs.c DCS_Options[], shown as D + octal(value) exactly like the menu
$DcsOptions = @(
    0x0013, 0x0015, 0x0016, 0x0019, 0x001A, 0x001E, 0x0023, 0x0027,
    0x0029, 0x002B, 0x002C, 0x0035, 0x0039, 0x003A, 0x003B, 0x003C,
    0x004C, 0x004D, 0x004E, 0x0052, 0x0055, 0x0059, 0x005A, 0x005C,
    0x0063, 0x0065, 0x006A, 0x006D, 0x006E, 0x0072, 0x0075, 0x007A,
    0x007C, 0x0085, 0x008A, 0x0093, 0x0095, 0x0096, 0x00A3, 0x00A4,
    0x00A5, 0x00A6, 0x00A9, 0x00AA, 0x00AD, 0x00B1, 0x00B3, 0x00B5,
    0x00B6, 0x00B9, 0x00BC, 0x00C6, 0x00C9, 0x00CD, 0x00D5, 0x00D9,
    0x00DA, 0x00E3, 0x00E6, 0x00E9, 0x00EE, 0x00F4, 0x00F5, 0x00F9,
    0x0109, 0x010A, 0x010B, 0x0113, 0x0119, 0x011A, 0x0125, 0x0126,
    0x012A, 0x012C, 0x012D, 0x0132, 0x0134, 0x0135, 0x0136, 0x0143,
    0x0146, 0x014E, 0x0153, 0x0156, 0x015A, 0x0166, 0x0175, 0x0186,
    0x018A, 0x0194, 0x0197, 0x0199, 0x019A, 0x01AC, 0x01B2, 0x01B4,
    0x01C3, 0x01CA, 0x01D3, 0x01D9, 0x01DA, 0x01DC, 0x01E3, 0x01EC
)

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

function Format-Freq {
    # stored frequency is in 10 Hz units, exactly like frequencyBandTable[]
    param([uint32]$Raw)
    if ($Raw -eq [uint32]::MaxValue) { return '----- erased' }
    return ('{0,9:F4}' -f ($Raw / 100000.0))
}

function Get-BandIndex {
    # mirrors FREQUENCY_GetBand()
    param([uint32]$Raw)
    for ($i = 0; $i -lt $BandTable.Count; $i++) {
        if ($Raw -lt $BandTable[$i].upper) { return $i }
    }
    return $BandTable.Count - 1
}

function Format-Octal {
    # the firmware prints DCS codes as %03o, .NET has no 'o' format specifier
    param([uint32]$Value)
    $s = ''
    $v = $Value
    while ($v -gt 0) {
        $s = [string]($v % 8) + $s
        $v = $v -shr 3
    }
    return $s.PadLeft(3, '0')
}

function Format-Code {
    # mirrors the clamping in RADIO_ConfigureChannel() lines 291-333
    param([int]$Type, [int]$Index)
    switch ($Type) {
        0            { return 'off' }
        1 {
            if ($Index -gt ($CtcssOptions.Count - 1)) { $Index = 0 }
            return ('CTCSS {0:F1}' -f ($CtcssOptions[$Index] / 10.0))
        }
        2 {
            if ($Index -gt ($DcsOptions.Count - 1)) { $Index = 0 }
            return 'D' + (Format-Octal $DcsOptions[$Index])
        }
        3 {
            if ($Index -gt ($DcsOptions.Count - 1)) { $Index = 0 }
            return 'N' + (Format-Octal $DcsOptions[$Index])
        }
        default { return ("invalid(nib={0})" -f $Type) }
    }
}

function Read-Record {
    param([byte[]]$Img, [int]$Band, [int]$Vfo)
    $base = $VfoBase + ($Band * 32) + ($Vfo * 16)
    $d    = @($Img[$base..($base + 15)])
    $o    = @{}
    $o.addr      = $base
    $o.raw       = $d
    $isEmpty     = $true
    foreach ($x in $d) { if ([int]$x -ne 0xFF) { $isEmpty = $false } }
    $o.empty     = $isEmpty
    $o.freq      = [uint32]($d[0] + ($d[1] * 256) + ($d[2] * 65536) + ([uint64]$d[3] * 16777216))
    $o.offset    = [uint32]($d[4] + ($d[5] * 256) + ($d[6] * 65536) + ([uint64]$d[7] * 16777216))
    $o.rxCode    = [int]$d[8]
    $o.txCode    = [int]$d[9]
    $o.rxType    = [int]($d[10] -band 0x0F)
    $o.txType    = [int](($d[10] -shr 4) -band 0x0F)
    $o.txDirec   = [int]($d[11] -band 0x0F)
    $o.modNibble = [int](($d[11] -shr 4) -band 0x0F)
    $o.d12       = [int]$d[12]
    $o.reverse   = (($d[12] -shr 0) -band 1) -eq 1
    $o.narrow    = (($d[12] -shr 1) -band 1) -eq 1
    $o.power     = [int](($d[12] -shr 2) -band 7)
    $o.busyLock  = (($d[12] -shr 5) -band 1) -eq 1
    $o.txLock    = (($d[12] -shr 6) -band 1) -eq 1
    $o.dtmfDec   = (($d[13] -shr 0) -band 1) -eq 1
    $o.pttId     = [int](($d[13] -shr 1) -band 7)
    $o.step      = [int]$d[14]
    $o.scramble  = [int]$d[15]
    # RADIO_SetModulation() and FUNCTION_Init() work on the *effective* RX
    # side, which is the TX config when reverse is on (radio.c:419-428).
    if ($o.reverse) {
        $o.effRxType = $o.txType
        $o.effRxCode = $o.txCode
    }
    else {
        $o.effRxType = $o.rxType
        $o.effRxCode = $o.rxCode
    }
    if ($o.modNibble -ge 3) { $o.modulation = 0 } else { $o.modulation = $o.modNibble }
    if ($o.effRxType -gt 3) { $o.effRxTypeClamped = 0 } else { $o.effRxTypeClamped = $o.effRxType }
    return $o
}

function Get-Findings {
    param($Rec, [int]$Band, [int]$Vfo)
    $f     = @()
    $label = 'VFO ' + [char](65 + $Vfo)
    if ($Rec.empty) { return ,$f }

    if ($Rec.effRxTypeClamped -ne 0) {
        $f += @{ Level = 'CRIT'; Text = ($label + ' RX audio is GATED by ' +
            (Format-Code $Rec.effRxType $Rec.effRxCode) +
            '. HandleIncoming() (app/app.c:197) does not open the audio path until that tone is detected, so squelch and the RSSI bar work while the speaker stays dead. Fix: RxCTCS / RxDCS = OFF unless the transmitter really sends the tone.') }
    }

    if ($Rec.modulation -ne 0) {
        $f += @{ Level = 'CRIT'; Text = ($label + ' stored modulation is ' + $ModulationStr[$Rec.modulation] +
            '. RADIO_SetModulation() moves the AF path and the AGC to ' + $ModulationStr[$Rec.modulation] +
            ', which makes an FM signal quiet and garbled and mangles an MDC-1200 preamble. Fix: menu MODE -> FM.') }
    }
    elseif ($Rec.modNibble -ge 3) {
        $f += @{ Level = 'WARN'; Text = ($label + ' modulation nibble is ' + $Rec.modNibble +
            ' (out of range); RADIO_ConfigureChannel() repairs it to FM on load, but the byte should be rewritten.') }
    }

    if (($Rec.rxType -gt 3) -or ($Rec.txType -gt 3)) {
        $f += @{ Level = 'WARN'; Text = ($label + ' code-type nibble out of range (RX ' + $Rec.rxType +
            '/TX ' + $Rec.txType + '); the firmware forces it to off on load, but the byte is corrupt.') }
    }

    if ($Rec.reverse) {
        $f += @{ Level = 'WARN'; Text = ($label + ' FREQUENCY REVERSE is ON: the RX side uses the *TX* configuration, so the tone that gates audio is byte +09 with the high nibble of +10, not the RxCTCS/RxDCS the menu shows.') }
    }

    if ($Rec.narrow) {
        $f += @{ Level = 'WARN'; Text = ($label + ' bandwidth is NARROW. Wideband FM and a 1200/1800 Hz MDC-1200 FSK preamble both get clipped by the narrow filter; match the working VFO.') }
    }

    if ($Rec.dtmfDec) {
        $f += @{ Level = 'INFO'; Text = ($label + ' D-DCD bit set in EEPROM (byte +13 bit0). Inert while ENABLE_DTMF_CALLING=0, but a build with DTMF calling would mute RX audio until a matching call is received.') }
    }

    if ($Rec.scramble -ne 0) {
        $f += @{ Level = 'INFO'; Text = ($label + ' scrambling type ' + $Rec.scramble + ' stored; ApeX (ENABLE_FEAT_N7SIX) forces it to 0 on load.') }
    }

    if ($Rec.freq -eq [uint32]::MaxValue) {
        $f += @{ Level = 'INFO'; Text = ($label + ' record is erased (FF FF FF FF); the firmware falls back to the lower band edge.') }
    }
    else {
        if (($Rec.freq -lt $BandTable[$Band].lower) -or ($Rec.freq -gt $BandTable[$Band].upper)) {
            $f += @{ Level = 'WARN'; Text = ($label + ' frequency ' + (Format-Freq $Rec.freq) +
                ' MHz does not fit the range of this slot (' + $BandTable[$Band].name +
                '); the firmware clamps it and re-derives the band (radio.c:392).') }
        }
        if (($Rec.freq -ge 10800000) -and ($Rec.freq -lt 13700000)) {
            $f += @{ Level = 'INFO'; Text = ($label + ' sits in 108-137 MHz, which ApeX forces to AM on purpose (RADIO_GetModulationForFrequency).') }
        }
        if (($Rec.freq -ge 35000000) -and ($Rec.freq -lt 40000000)) {
            $f += @{ Level = 'INFO'; Text = ($label + ' sits in 350-400 MHz: with the 350 band disabled the RX frequency moves to 433.0000 MHz (radio.c:430).') }
        }
    }

    if ($Rec.txLock)   { $f += @{ Level = 'INFO'; Text = ($label + ' TX lock (no transmit) is set.') } }
    if ($Rec.busyLock) { $f += @{ Level = 'INFO'; Text = ($label + ' busy channel lock is set.') } }
    return ,$f
}

# ---------------------------------------------------------------------------
# reporting
# ---------------------------------------------------------------------------

$LevelColor = @{ CRIT = 'Red'; WARN = 'Yellow'; INFO = 'DarkGray' }
$LevelTag   = @{ CRIT = '  !!'; WARN = '   ~ '; INFO = '    ' }

function Write-Findings {
    param($Findings)
    foreach ($x in $Findings) {
        Write-Host ($LevelTag[$x.Level] + ' ' + $x.Text) -ForegroundColor $LevelColor[$x.Level]
    }
}

function Write-Record {
    param($Rec, [int]$Band, [int]$Vfo, [byte[]]$Img)
    $vfoName = [char](65 + $Vfo)
    $att     = [int]$Img[$AttrBase + $Band]
    $attTxt  = 'attr @0x{0:X4} = 0x{1:X2}   band={2} compander={3} scanlist={4}{5}{6}' -f `
        ($AttrBase + $Band), $att, ($att -band 7), (($att -shr 3) -band 1), `
        (($att -shr 4) -band 1), (($att -shr 5) -band 1), (($att -shr 6) -band 1)
    if ($att -eq 0xFF) { $attTxt += '   <-- erased/unused attribute byte' }

    Write-Host ''
    Write-Host ('=== slot {0} ({1}) VFO {2}   record @ 0x{3:X4} ===' -f `
        $Band, $BandTable[$Band].name, $vfoName, $Rec.addr) -ForegroundColor Cyan
    Write-Host $attTxt -ForegroundColor DarkGray

    if ($Bytes) {
        Write-Host ('   raw: ' + (($Rec.raw | ForEach-Object { '{0:X2}' -f $_ }) -join ' ')) -ForegroundColor DarkGray
    }

    $line1 = '   RX ' + (Format-Freq $Rec.freq) + ' MHz   ' +
             'TX offs ' + (Format-Freq $Rec.offset) + ' dir=' + $Rec.txDirec + '   ' +
             'MODE ' + $ModulationStr[$Rec.modulation] + ' (nib ' + $Rec.modNibble + ')'
    Write-Host $line1

    $line2 = '   RxCode ' + (Format-Code $Rec.rxType $Rec.rxCode).PadRight(12) +
             '  TxCode ' + (Format-Code $Rec.txType $Rec.txCode).PadRight(12) +
             '  BW ' + $(if ($Rec.narrow) { 'NARROW' } else { 'WIDE  ' }) +
             '  REV ' + $(if ($Rec.reverse) { 'ON ' } else { 'off' }) +
             '  PWR ' + $PowerStr[$Rec.power] +
             '  step ' + $Rec.step +
             '  scr ' + $Rec.scramble
    Write-Host $line2

    if ($Rec.reverse) {
        Write-Host ('   effective RX tone = TX field: ' + (Format-Code $Rec.effRxType $Rec.effRxCode)) -ForegroundColor Yellow
    }
}

function Write-RecordDiff {
    param($A, $B)
    Write-Host '   A/B byte diff:' -ForegroundColor White
    $names = @{ 0 = 'RX freq'; 1 = 'RX freq'; 2 = 'RX freq'; 3 = 'RX freq'; 4 = 'TX offset'; 5 = 'TX offset';
                6 = 'TX offset'; 7 = 'TX offset'; 8 = 'RX code'; 9 = 'TX code'; 10 = 'code types';
                11 = 'modulation/offset dir'; 12 = 'rev/bw/power/locks'; 13 = 'D-DCD/PTT ID';
                14 = 'step'; 15 = 'scramble' }
    for ($i = 0; $i -lt 16; $i++) {
        if ($A.raw[$i] -ne $B.raw[$i]) {
            Write-Host ('     +{0:D2}  A=0x{1:X2}  B=0x{2:X2}   {3}' -f $i, $A.raw[$i], $B.raw[$i], $names[$i]) -ForegroundColor Yellow
        }
    }
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

if (-not (Test-Path -LiteralPath $Path)) { throw "EEPROM image not found: $Path" }
$src = (Resolve-Path -LiteralPath $Path).Path
$raw = [System.IO.File]::ReadAllBytes($src)

if (($raw.Length -gt 0) -and ($raw[0] -eq 0x3A)) {
    throw 'this looks like Intel HEX, the tool needs the raw binary EEPROM image (k5prog -R -E -f eeprom.bin)'
}

$img = New-Object byte[] $EepromSize
for ($i = 0; $i -lt $EepromSize; $i++) { $img[$i] = 0xFF }
if ($raw.Length -lt ($AttrBase + 7)) {
    throw ("image too small ({0} bytes): the VFO records end at 0x{1:X4} and the band attribute byte of the last slot is at 0x{2:X4}" -f `
        $raw.Length, ($VfoBase + 7 * 32 - 1), ($AttrBase + 6))
}
[System.Array]::Copy($raw, 0, $img, 0, [System.Math]::Min($raw.Length, $EepromSize))

$targets = @()
if ($Find.Trim().Length -gt 0) {
    foreach ($part in ($Find -split ',')) {
        if ($part.Trim().Length -gt 0) { $targets += [double]$part.Trim() }
    }
}

Write-Host ''
Write-Host ('UV-K5 VFO band-slot audit   image: {0} ({1} bytes)' -f $src, $raw.Length) -ForegroundColor White
Write-Host 'VFO records 0x0C80-0x0D5F, band attribute bytes 0x0E28-0x0E2E' -ForegroundColor DarkGray

$all = @()
for ($b = 0; $b -lt 7; $b++) {
    for ($v = 0; $v -lt 2; $v++) {
        $rec = Read-Record -Img $img -Band $b -Vfo $v
        $rec['band']     = $b
        $rec['vfo']      = $v
        $rec['findings'] = (Get-Findings -Rec $rec -Band $b -Vfo $v)
        $rec['match']    = $false
        foreach ($t in $targets) {
            if ($rec.freq -ne 0xFFFFFFFF) {
                if ([System.Math]::Abs(($rec.freq / 100000.0) - $t) -lt 0.00005) { $rec['match'] = $true }
            }
        }
        $all += ,$rec
    }
}

# ---- summary -------------------------------------------------------------
$hdr = ('slot{0}  {1,-15} {2}  {3}  {4,-9}  {5,-4} {6,-12} {7,-12} {8,-6} {9,-3} {10}  {11}' -f `
    ' ', 'band', 'vfo', 'record', 'frequency', 'mode', 'rx code', 'tx code', 'bw', 'rev', 'att', 'verdict')
Write-Host ''
Write-Host $hdr -ForegroundColor White
Write-Host ('-' * $hdr.Length) -ForegroundColor DarkGray

$critTotal = 0
$warnTotal = 0
foreach ($r in $all) {
    $att  = [int]$img[$AttrBase + $r.band]
    $mark = ''
    if ($r.match) { $mark = '>' }

    if ($r.empty) {
        $row = ('{0}   {1,-15} {2}  0x{3:X4}  {4,-9}  {5,-4} {6,-12} {7,-12} {8,-6} {9,-3} 0x{10:X2}  {11}' -f `
            $mark, $BandTable[$r.band].name, [char](65 + $r.vfo), $r.addr, '-', '-', '-', '-', '-', '-', $att, 'empty')
        Write-Host $row -ForegroundColor DarkGray
        continue
    }

    $crit = @($r.findings | Where-Object { $_.Level -eq 'CRIT' }).Count
    $warn = @($r.findings | Where-Object { $_.Level -eq 'WARN' }).Count
    $critTotal += $crit
    $warnTotal += $warn

    $verdict = 'ok'
    $color   = 'Gray'
    if ($crit -gt 0) { $verdict = 'CRIT'; $color = 'Red' }
    elseif ($warn -gt 0) { $verdict = 'warn'; $color = 'Yellow' }

    $bwTxt = 'wide'
    if ($r.narrow) { $bwTxt = 'NARROW' }
    $revTxt = 'off'
    if ($r.reverse) { $revTxt = 'ON' }

    $row = ('{0}   {1,-15} {2}  0x{3:X4}  {4,-9}  {5,-4} {6,-12} {7,-12} {8,-6} {9,-3} 0x{10:X2}  {11}' -f `
        $mark, $BandTable[$r.band].name, [char](65 + $r.vfo), $r.addr, (Format-Freq $r.freq), `
        $ModulationStr[$r.modulation], (Format-Code $r.rxType $r.rxCode), (Format-Code $r.txType $r.txCode), `
        $bwTxt, $revTxt, $att, $verdict)
    Write-Host $row -ForegroundColor $color
}

# ---- detail --------------------------------------------------------------
$show = @()
foreach ($r in $all) {
    if ($r.empty) { continue }
    if ($targets.Count -gt 0) {
        if ($r.match) { $show += ,$r }
    }
    elseif ($Detail -or ($r.findings.Count -gt 0)) {
        $show += ,$r
    }
}

if (($targets.Count -gt 0) -and ($show.Count -eq 0)) {
    Write-Host ''
    Write-Host ('no VFO record holds ' + $Find + ' MHz') -ForegroundColor Yellow
    Write-Host 'the frequency may sit in the other VFO of the band, or the radio never saved it: a VFO'
    Write-Host 'record is only written when the band changes, on power off, or through ChSave.'
    Write-Host 'Power cycle the radio, then read the EEPROM again.' -ForegroundColor Yellow
}

foreach ($r in $show) {
    Write-Record -Rec $r -Band $r.band -Vfo $r.vfo -Img $img
    Write-Findings -Findings $r.findings
}

# ---- A vs B diff --------------------------------------------------------
if ($Bytes) {
    $shownBands = @()
    foreach ($r in $show) {
        if ($shownBands -notcontains $r.band) {
            $shownBands += $r.band
            $ra = $all[($r.band * 2)]
            $rb = $all[($r.band * 2) + 1]
            if ((-not $ra.empty) -and (-not $rb.empty) -and `
                (($ra.freq -ne $rb.freq) -or ($ra.d12 -ne $rb.d12) -or ($ra.raw[10] -ne $rb.raw[10]) -or ($ra.raw[11] -ne $rb.raw[11]))) {
                Write-Host ''
                Write-Host ('--- slot {0} ({1}): VFO A vs VFO B -------------------------------' -f `
                    $r.band, $BandTable[$r.band].name) -ForegroundColor Cyan
                Write-RecordDiff -A $ra -B $rb
            }
        }
    }
}

# ---- optional patch ------------------------------------------------------
function Get-ByteString {
    param([byte[]]$Img, [int]$Base)
    return (($Img[$Base..($Base + 15)] | ForEach-Object { '{0:X2}' -f $_ }) -join ' ')
}

if ($PatchTo.Length -gt 0) {
    if ($targets.Count -eq 0) { throw '-PatchTo needs -Find <MHz> so it is unambiguous which record to repair.' }
    if (-not ($ForceFM -or $ClearRxTone -or $ClearTxTone -or $Wide)) {
        throw 'no patch selected: use -ForceFM / -ClearRxTone / -ClearTxTone / -Wide'
    }
    $dst = [System.IO.Path]::GetFullPath($PatchTo)
    if (Test-Path -LiteralPath $dst) { throw ("refusing to overwrite an existing file: $dst") }

    foreach ($r in $all) {
        if (-not $r.match) { continue }
        $b = $r.addr
        Write-Host ''
        Write-Host ('patching slot {0} VFO {1} @ 0x{2:X4}' -f $r.band, [char](65 + $r.vfo), $b) -ForegroundColor White
        Write-Host ('  before: ' + (Get-ByteString -Img $img -Base $b)) -ForegroundColor DarkGray

        if ($ForceFM) {
            $img[$b + 11] = [byte]($img[$b + 11] -band 0x0F)      # modulation nibble = FM
            Write-Host '  + byte +11 high nibble -> 0 (MODE FM)'
        }
        if ($ClearRxTone) {
            $img[$b + 10] = [byte]($img[$b + 10] -band 0xF0)      # RX code type nibble = off
            $img[$b + 8]  = 0
            Write-Host '  + byte +10 low nibble -> 0, byte +08 -> 0 (RxCTCS/RxDCS off)'
            if ($r.reverse) {
                $img[$b + 10] = [byte]($img[$b + 10] -band 0x0F)
                $img[$b + 9]  = 0
                Write-Host '  + reverse is on, so the TX field that really gates audio is cleared too'
            }
        }
        if ($ClearTxTone) {
            $img[$b + 10] = [byte]($img[$b + 10] -band 0x0F)      # TX code type nibble = off
            $img[$b + 9]  = 0
            Write-Host '  + byte +10 high nibble -> 0, byte +09 -> 0 (TxCTCS/TxDCS off)'
        }
        if ($Wide) {
            $img[$b + 12] = [byte]($img[$b + 12] -band 0xFD)      # bit1 = 0 -> BK4819_FILTER_BW_WIDE
            Write-Host '  + byte +12 bit1 -> 0 (bandwidth wide)'
        }

        Write-Host ('  after : ' + (Get-ByteString -Img $img -Base $b)) -ForegroundColor DarkGray
    }

    [System.IO.File]::WriteAllBytes($dst, $img)
    Write-Host ''
    Write-Host ('wrote patched image: {0}' -f $dst) -ForegroundColor Green
    Write-Host 'write it back with k5prog (radio powered off, keep the original backup):' -ForegroundColor DarkGray
    Write-Host '    k5prog -W -E -f eeprom_fixed.bin' -ForegroundColor DarkGray
    Write-Host 'the radio re-reads this area on every VFO reconfigure, so a power cycle is enough afterwards.' -ForegroundColor DarkGray
}

# ---- footer --------------------------------------------------------------
Write-Host ''
Write-Host ('{0} critical, {1} warning(s) in 14 VFO records' -f $critTotal, $warnTotal) -ForegroundColor White
if ($critTotal -gt 0) {
    Write-Host 'CRIT rows are the ones that can silence or garble RX audio by themselves.' -ForegroundColor Red
    exit 2
}
exit 0

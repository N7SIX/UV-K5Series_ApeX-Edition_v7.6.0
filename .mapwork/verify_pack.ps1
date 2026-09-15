# verify_pack.ps1 - replicates uvtools flash.js unpackLegacyFirmware + size checks
param($PackedBin, $PlainBin)

$OBF = [byte[]](0x47,0x22,0xC0,0x52,0x5D,0x57,0x48,0x94,0xB1,0x60,0x60,0xDB,0x6F,0xE3,0x4C,0x7C,
0xD8,0x4A,0xD6,0x8B,0x30,0xEC,0x25,0xE0,0x4C,0xD9,0x00,0x7F,0xBF,0xE3,0x54,0x05,
0xE9,0x3A,0x97,0x6B,0xB0,0x6E,0x0C,0xFB,0xB1,0x1A,0xE2,0xC9,0xC1,0x56,0x47,0xE9,
0xBA,0xF1,0x42,0xB6,0x67,0x5F,0x0F,0x96,0xF7,0xC9,0x3C,0x84,0x1B,0x26,0xE1,0x4E,
0x3B,0x6F,0x66,0xE6,0xA0,0x6A,0xB0,0xBF,0xC6,0xA5,0x70,0x3A,0xBA,0x18,0x9E,0x27,
0x1A,0x53,0x5B,0x71,0xB1,0x94,0x1E,0x18,0xF2,0xD6,0x81,0x02,0x22,0xFD,0x5A,0x28,
0x91,0xDB,0xBA,0x5D,0x64,0xC6,0xFE,0x86,0x83,0x9C,0x50,0x1C,0x73,0x03,0x11,0xD6,
0xAF,0x30,0xF4,0x2C,0x77,0xB2,0x7D,0xBB,0x3F,0x29,0x28,0x57,0x22,0xD6,0x92,0x8B)

$enc = [System.IO.File]::ReadAllBytes($PackedBin)
$fail = 0

# --- check 1: minimum length (flash.js:739) ---
if ($enc.Length -le 0x2000 + 16 + 2) { Write-Output "FAIL: firmware too short"; $fail++ }
else { Write-Output "PASS: minimum length check" }

# --- check 2: CRC (flash.js:743-749, digest stored swapped) ---
$expectedCrc = ([int]$enc[$enc.Length - 2]) -bor (([int]$enc[$enc.Length - 1]) -shl 8)
$crc = 0
for ($i = 0; $i -lt $enc.Length - 2; $i++) {
    $crc = $crc -bxor ([int]$enc[$i] -shl 8)
    for ($j = 0; $j -lt 8; $j++) {
        if ($crc -band 0x8000) { $crc = (($crc -shl 1) -bxor 0x1021) -band 0xFFFF }
        else { $crc = ($crc -shl 1) -band 0xFFFF }
    }
}
if ($crc -ne $expectedCrc) { Write-Output "FAIL: CRC 0x$($crc.ToString('X4')) != 0x$($expectedCrc.ToString('X4'))"; $fail++ }
else { Write-Output "PASS: CRC16/XMODEM 0x$($crc.ToString('X4'))" }

# --- check 3: un-XOR + strip version block at 0x2000 ---
$body = [byte[]]::new($enc.Length - 2)
[Array]::Copy($enc, $body, $body.Length)
$dec = [byte[]]::new($body.Length)
for ($i = 0; $i -lt $body.Length; $i++) { $dec[$i] = $body[$i] -bxor $OBF[$i % 128] }
$versionInfo = [System.Text.Encoding]::ASCII.GetString($dec, 0x2000, 16).TrimEnd([char]0)
$unpacked = [byte[]]::new($dec.Length - 16)
[Array]::Copy($dec, 0, $unpacked, 0, 0x2000)
[Array]::Copy($dec, 0x2000 + 16, $unpacked, 0x2000, $dec.Length - 0x2000 - 16)
Write-Output ("versionInfo: '{0}'" -f $versionInfo)

# --- check 4: byte-exact match with plain firmware ---
$plain = [System.IO.File]::ReadAllBytes($PlainBin)
if ($unpacked.Length -ne $plain.Length) { Write-Output "FAIL: length $($unpacked.Length) != $($plain.Length)"; $fail++ }
else {
    $same = $true
    for ($i = 0; $i -lt $plain.Length; $i++) { if ($unpacked[$i] -ne $plain[$i]) { $same = $false; Write-Output "FAIL: byte mismatch at 0x$($i.ToString('X'))"; break } }
    if ($same) { Write-Output "PASS: unpacked payload byte-identical to firmware bin ($($plain.Length) bytes)" }
}

# --- check 5: flash.js:903 legacyFirmwareTooLarge (0xEFFF) ---
$LEGACY_MAX = 0xEFFF
if ($unpacked.Length -gt $LEGACY_MAX) { Write-Output "FAIL: unpacked $($unpacked.Length) > $LEGACY_MAX"; $fail++ }
else { Write-Output ("PASS: size check 1 - {0} <= {1} (margin {2} bytes)" -f $unpacked.Length, $LEGACY_MAX, ($LEGACY_MAX - $unpacked.Length)) }

# --- check 6: flash.js:887-892 protocol boundary (0xF000) ---
$finalAddress = ($unpacked.Length + 0xFF) -band (-bnot 0xFF)
if ($finalAddress -gt 0xF000) { Write-Output "FAIL: finalAddress 0x$($finalAddress.ToString('X')) > 0xF000"; $fail++ }
else { Write-Output ("PASS: size check 2 - finalAddress 0x{0} <= 0xF000" -f $finalAddress.ToString('X')) }

Write-Output ""
if ($fail -eq 0) { Write-Output "RESULT: ALL 6 CHECKS PASSED - firmware accepted by n7six UVTools web flasher" }
else { Write-Output "RESULT: $fail check(s) FAILED" }
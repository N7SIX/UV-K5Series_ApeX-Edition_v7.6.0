# sizecheck.ps1 - UV-K5 v1 FLASH budget report for a built firmware ELF.
# Usage: powershell -NoProfile -File .mapwork\sizecheck.ps1 -Elf <path> [-Tag name]
param(
    [Parameter(Mandatory=$true)][string]$Elf,
    [string]$Tag = ''
)
$ErrorActionPreference = 'Stop'

$BIN = 'C:\Program Files (x86)\Arm GNU Toolchain arm-none-eabi\14.3 rel1\bin'
$SIZE    = Join-Path $BIN 'arm-none-eabi-size.exe'
$OBJCOPY = Join-Path $BIN 'arm-none-eabi-objcopy.exe'

# UV-K5 v1 (DP32G030, 64K flash): the bootloader protects nothing above 0xEFFF,
# and the firmware images carry the "flashable" ceiling used by the Makefile
# size target. Anything past this boundary is not flashed -> brick risk.
$FLASHABLE = 0xEFFF      # 61439 B  (Makefile "size" target limit)
$REGION    = 65536       # 64K memory region from config/firmware.ld

if (-not (Test-Path $Elf)) { throw "ELF not found: $Elf" }

$bin = [IO.Path]::ChangeExtension($Elf, '.sizecheck.bin')
& $OBJCOPY -O binary $Elf $bin
$binBytes = (Get-Item $bin).Length

# arm-none-eabi-size output: header line then "text data bss dec hex filename"
$raw = & $SIZE $Elf
$nums = ($raw | Select-Object -Skip 1 -First 1) -split '\s+' | Where-Object { $_ -match '^\d+$' }
$text = [int]$nums[0]; $data = [int]$nums[1]; $bss = [int]$nums[2]

Write-Output ""
Write-Output "=========== UV-K5 v1 FLASH BUDGET ($Tag) ==========="
Write-Output ("  ELF                    : {0,7} B" -f (Get-Item $Elf).Length)
Write-Output ("  .text (code+rodata)    : {0,7} B" -f $text)
Write-Output ("  .data (init in FLASH)  : {0,7} B" -f $data)
Write-Output ("  .bss  (RAM, not FLASH) : {0,7} B" -f $bss)
Write-Output ("  .bin  (copied image)   : {0,7} B" -f $binBytes)
Write-Output ("  ------------------------------------------------")
Write-Output ("  flashable ceiling      : {0,7} B   (0xEFFF)" -f $FLASHABLE)
Write-Output ("  full 64K region        : {0,7} B   (0x10000)" -f $REGION)
Write-Output ("  headroom vs ceiling    : {0,7} B" -f ($FLASHABLE - $binBytes))
Write-Output ("  region usage           : {0,6:N2} %" -f (100.0 * $binBytes / $REGION))
if ($binBytes -gt $FLASHABLE) {
    Write-Output ("  RESULT: OVER by {0} B -- FLASHING THIS WOULD BRICK UV-K5 v1" -f ($binBytes - $FLASHABLE))
} else {
    Write-Output "  RESULT: OK - within the UV-K5 v1 flashable region"
}
Write-Output "===================================================="
Remove-Item $bin -Force -ErrorAction SilentlyContinue

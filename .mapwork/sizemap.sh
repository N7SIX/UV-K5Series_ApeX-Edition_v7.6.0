#!/bin/bash
# Attribute linked FLASH usage per function, and aggregate by module prefix.
export PATH="/c/Program Files (x86)/Arm GNU Toolchain arm-none-eabi/14.3 rel1/bin:/c/Program Files (x86)/GnuWin32/bin:/c/Program Files/Git/usr/bin:/c/Program Files/Git/mingw64/bin:/c/Windows/System32:$PATH"
cd "/c/Users/sebue/Documents/N7SIX/Software/Quansheng/UV-K5Series_ApeX-Edition_v7.6.0" || exit 1

ELF="${1:-n7six}"
OUT=".mapwork/sizemap.txt"

# text symbols (code) only, sized, descending
arm-none-eabi-nm --print-size --size-sort --radix=d "$ELF" 2>/dev/null \
  | awk '$3=="t" || $3=="T" || $3=="w" || $3=="W" {print $2, $4}' > "$OUT"

echo "=== total code bytes (sum of symbols) ==="
awk '{s+=$1} END {print s}' "$OUT"

echo "=== top 60 functions ==="
sort -rn "$OUT" | head -60

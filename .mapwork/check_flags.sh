#!/bin/bash
# Probe the effective build flags (authoritative, forces a rebuild command print).
export PATH="/c/Program Files (x86)/Arm GNU Toolchain arm-none-eabi/14.3 rel1/bin:/c/Program Files (x86)/GnuWin32/bin:/c/Program Files/Git/usr/bin:/c/Program Files/Git/mingw64/bin:/c/Windows/System32:$PATH"
cd "/c/Users/sebue/Documents/N7SIX/Software/Quansheng/UV-K5Series_ApeX-Edition_v7.6.0" || exit 1
echo "=== which make ==="
which make
make --version | head -2
echo "=== forced flags for app/spectrum.o ==="
make -n -B app/spectrum.o 2>&1 | tr ' ' '\n' | grep -iE 'scan_ranges|flashlight|spectrum|werror'
echo "=== ENABLE_SCAN_RANGES value in Makefile ==="
grep -n 'ENABLE_SCAN_RANGES' Makefile
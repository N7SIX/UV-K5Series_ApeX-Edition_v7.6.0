#!/bin/bash
# A/B: HEAD (original) vs current (optimized) app/spectrum.c, via incremental relink.
set -u
export PATH="/c/Program Files (x86)/Arm GNU Toolchain arm-none-eabi/14.3 rel1/bin:/c/Program Files (x86)/GnuWin32/bin:/c/Program Files/Git/usr/bin:$PATH"
cd "/c/Users/sebue/Documents/N7SIX/Software/Quansheng/UV-K5Series_ApEX-Edition_v7.6.0" || exit 1

cp app/spectrum.c .mapwork/spectrum_new.c || exit 1
trap 'cp .mapwork/spectrum_new.c app/spectrum.c' EXIT   # guarantee restore

report() {
  grep -E '^FLASH|^RAM' /tmp/ab.log | tail -2
}

echo "=== A: HEAD (original) spectrum.c ==="
git show HEAD:app/spectrum.c > app/spectrum.c
touch app/spectrum.c
make -j8 > /tmp/ab.log 2>&1; echo "exit=$?"; report

echo "=== B: current (optimized) spectrum.c ==="
cp .mapwork/spectrum_new.c app/spectrum.c
touch app/spectrum.c
make -j8 > /tmp/ab.log 2>&1; echo "exit=$?"; report

echo "=== spectrum symbols in final ELF ==="
NM="/c/Program Files (x86)/Arm GNU Toolchain arm-none-eabi/14.3 rel1/bin/arm-none-eabi-nm.exe"
"$NM" --print-size --size-sort --radix=d build/ApeX/n7six.ApeX.v7.6.10.elf \
  | grep -Ei 'spectrum|Draw|Rssi|Peak|Trigger|Freq|Arrow|Tick|Waterfall|Blacklist|ScanStep' | tail -40
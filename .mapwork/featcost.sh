#!/bin/bash
export PATH="/c/Program Files (x86)/Arm GNU Toolchain arm-none-eabi/14.3 rel1/bin:/c/Program Files (x86)/GnuWin32/bin:/c/Program Files/Git/usr/bin:$PATH"
cd "/c/Users/sebue/Documents/N7SIX/Software/Quansheng/UV-K5Series_ApEX-Edition_v7.6.0" || exit 1
run () {
  label="$1"; shift
  find . -name "*.d" -not -path "./external/*" -not -path "./.mapwork/*" -delete 2>/dev/null
  make clean >/dev/null 2>&1
  out=$(make -j8 "$@" 2>&1)
  used=$(echo "$out" | grep -A2 "Memory Region" | sed -n "2p" | awk "{print \$2}")
  ram=$(echo "$out" | grep -A3 "Memory Region" | sed -n "3p" | awk "{print \$2}")
  err=$(echo "$out" | grep -c "Error\|error:")
  echo "$label => FLASH=$used RAM=$ram errors=$err"
}
echo "=== PER-FEATURE FLASH COST (each built alone vs baseline) ==="
run "BASELINE_as_is"
run "RSSI_BAR_off" ENABLE_RSSI_BAR=0
run "AUDIO_BAR_off" ENABLE_AUDIO_BAR=0
run "SMALL_BOLD_off" ENABLE_SMALL_BOLD=0
run "BIG_FREQ_off" ENABLE_BIG_FREQ=0
run "SCAN_RANGES_off" ENABLE_SCAN_RANGES=0
run "FEAT_N7SIX_off" ENABLE_FEAT_N7SIX=0
echo "=== MEASUREMENT COMPLETE ==="
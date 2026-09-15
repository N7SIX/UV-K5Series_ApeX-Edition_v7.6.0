#!/bin/bash
# Round 3: new gating (interlace/blacklist/bidir default-off) baseline + linker wins
export PATH="/c/Program Files (x86)/Arm GNU Toolchain arm-none-eabi/14.3 rel1/bin:/c/Program Files (x86)/GnuWin32/bin:/c/Program Files/Git/usr/bin:$PATH"
cd "/c/Users/sebue/Documents/N7SIX/Software/Quansheng/UV-K5Series_ApeX-Edition_v7.6.0" || exit 1

run() {  # run <tag> <extraC> <extraLD>
  local tag="$1"; shift
  local ec="$1"; shift
  local el="$1"; shift
  make clean >/dev/null 2>&1
  if make -j8 EXTRA_CFLAGS="$ec" EXTRA_LDFLAGS="$el" >/dev/null 2>&1; then
    echo "$tag: $(stat -c%s build/ApeX/n7six.ApeX-k5.v7.6.10.bin 2>/dev/null)"
  else
    echo "$tag: BUILD FAILED"
  fi
}

echo "--- 1: new baseline (partition=none) ---"
run "default_final" "" ""

echo "--- 2: gold --icf=all ---"


echo "RESULT: flasher limit 61439"



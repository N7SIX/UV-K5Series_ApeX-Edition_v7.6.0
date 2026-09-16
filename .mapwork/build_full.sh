#!/bin/bash
# Full build with the Makefile's real flags.  Extra make variables can be passed
# on the command line, e.g.:   bash .mapwork/build_full.sh ENABLE_SCAN_RANGES=1
export PATH="/c/Program Files (x86)/Arm GNU Toolchain arm-none-eabi/14.3 rel1/bin:/c/Program Files (x86)/GnuWin32/bin:/c/Program Files/Git/usr/bin:/c/Program Files/Git/mingw64/bin:/c/Windows/System32:$PATH"
cd "/c/Users/sebue/Documents/N7SIX/Software/Quansheng/UV-K5Series_ApeX-Edition_v7.6.0" || exit 1

LOG=".mapwork/fullbuild.log"
find . -name '*.d' -not -path './external/*' -delete 2>/dev/null
make -j4 "$@" > "$LOG" 2>&1
RC=$?
echo "make exit=$RC"
if [ $RC -ne 0 ]; then
  echo "--- error/warning lines ---"
  grep -n -E 'error|Error|undefined reference|warning' "$LOG" | head -40
fi

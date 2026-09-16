#!/bin/bash
# Clean full-firmware build with the project's real toolchain/flags.
# Progress is written to .mapwork/fullbuild.log; this script is normally
# launched detached and then polled.
export PATH="/c/Program Files (x86)/Arm GNU Toolchain arm-none-eabi/14.3 rel1/bin:/c/Program Files (x86)/GnuWin32/bin:/c/Program Files/Git/usr/bin:/c/Program Files/Git/mingw64/bin:/c/Windows/System32:$PATH"
cd "/c/Users/sebue/Documents/N7SIX/Software/Quansheng/UV-K5Series_ApeX-Edition_v7.6.0" || exit 1

LOG=".mapwork/fullbuild.log"
: > "$LOG"

echo "=== removing stale objects ===" | tee -a "$LOG"
find . -name '*.d' -not -path './external/*' -delete 2>/dev/null
find . -name '*.o' -not -path './external/*' -delete 2>/dev/null
rm -f n7six n7six.bin n7six.packed.bin

echo "=== make -j4 ===" | tee -a "$LOG"
make -j4 >> "$LOG" 2>&1
STATUS=$?
echo "=== BUILD_EXIT=$STATUS ===" | tee -a "$LOG"
exit $STATUS
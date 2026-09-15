#!/bin/bash
set -o pipefail
export PATH="/c/Program Files (x86)/Arm GNU Toolchain arm-none-eabi/14.3 rel1/bin:/c/Program Files (x86)/GnuWin32/bin:/c/Program Files/Git/usr/bin:$PATH"
cd "/c/Users/sebue/Documents/N7SIX/Software/Quansheng/UV-K5Series_ApEX-Edition_v7.6.0" || exit 1
echo "make: $(command -v make)"
echo "gcc : $(command -v arm-none-eabi-gcc)"
echo "--- clean stale .d ---"
find . -name '*.d' -not -path './external/*' -not -path './.mapwork/*' -delete 2>/dev/null
echo "--- make clean ---"
make clean >/dev/null 2>&1
echo "--- make -j8 ---"
make -j8 2>&1 | tail -60
echo "EXIT=$?"
echo "--- artifacts ---"
ls -l build/ApeX 2>/dev/null
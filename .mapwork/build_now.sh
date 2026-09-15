#!/bin/bash
# Full local rebuild with the local ARM toolchain (Docker .d files must be purged first).
export PATH="/c/Program Files (x86)/Arm GNU Toolchain arm-none-eabi/14.3 rel1/bin:/c/Program Files (x86)/GnuWin32/bin:/c/Program Files/Git/usr/bin:$PATH"
cd "/c/Users/sebue/Documents/N7SIX/Software/Quansheng/UV-K5Series_ApEX-Edition_v7.6.0" || exit 1

echo "make: $(command -v make)"
echo "gcc : $(command -v arm-none-eabi-gcc)"

find . -name '*.d' -not -path './.mapwork/*' -delete 2>/dev/null
make clean >/dev/null 2>&1

echo "--- purging stale objects (Docker/GCC15 leftovers) ---"
find . -name '*.o' -not -path './.mapwork/*' -not -path './build/*' -delete 2>/dev/null
rm -f n7six
find . -name '*.d' -not -path './.mapwork/*' -not -path './build/*' -delete 2>/dev/null
make clean >/dev/null 2>&1

echo "--- make -j8 ---"
make -j8 > /tmp/build.log 2>&1
echo "exit=$?"
grep -E 'warning|error|FLASH|RAM|Region|packed' /tmp/build.log | tail -30
echo "--- last lines ---"
tail -12 /tmp/build.log
echo "--- artifacts ---"
ls -l build/ApeX 2>/dev/null
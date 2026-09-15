#!/bin/bash
export PATH="/c/Program Files (x86)/Arm GNU Toolchain arm-none-eabi/14.3 rel1/bin:/c/Program Files (x86)/GnuWin32/bin:/c/Program Files/Git/usr/bin:$PATH"
cd "/c/Users/sebue/Documents/N7SIX/Software/Quansheng/UV-K5Series_ApEX-Edition_v7.6.0" || exit 1
exec > "/c/Users/sebue/Documents/N7SIX/Software/Quansheng/UV-K5Series_ApEX-Edition_v7.6.0/.mapwork/clean_build.log" 2>&1
echo "START $(date)"
echo "--- manual clean (make clean is broken on Windows: del /Q line too long) ---"
find . -name "*.o" -not -path "./.mapwork/*" -not -path "./external/*" -delete 2>/dev/null
find . -name "*.d" -not -path "./.mapwork/*" -not -path "./external/*" -delete 2>/dev/null
rm -rf build/ApeX bin 2>/dev/null
echo "objects left: $(find . -name "*.o" -not -path "./.mapwork/*" | wc -l)"
echo "--- make -j8 (full) ---"
make -j8 2>&1 | tail -160
echo "--- artifacts ---"
ls -l build/ApeX 2>/dev/null
echo "--- DONE $(date) ---"
#!/bin/bash
export PATH="/c/Program Files (x86)/Arm GNU Toolchain arm-none-eabi/14.3 rel1/bin:/c/Program Files (x86)/GnuWin32/bin:/c/Program Files/Git/usr/bin:/c/Program Files/Git/mingw64/bin:/c/Windows/System32:$PATH"
cd "/c/Users/sebue/Documents/N7SIX/Software/Quansheng/UV-K5Series_ApeX-Edition_v7.6.0" || exit 1

echo "awk path: $(command -v awk)"
echo "awk version: $(awk --version 2>&1 | head -1)"
echo "strtonum: $(echo x | awk '{print strtonum("0x10")}' 2>&1 | head -1)"
echo "sym2obj lines: $(wc -l < .mapwork/sym2obj.txt)"
echo "--- first 3 sym2obj ---"
head -3 .mapwork/sym2obj.txt
echo "--- first 3 nm ELF ---"
arm-none-eabi-nm --print-size n7six 2>/dev/null | head -3
echo "--- does Main resolve? ---"
grep -c '^Main ' .mapwork/sym2obj.txt
grep '^Main ' .mapwork/sym2obj.txt
echo "--- nm .o count ---"
find app driver radio ui audio core system bsp helper graphics globals -name '*.o' | wc -l

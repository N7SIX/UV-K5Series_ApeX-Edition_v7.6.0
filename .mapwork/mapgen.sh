#!/bin/bash
# Re-link the firmware with a linker map so per-file/section FLASH attribution is possible.
export PATH="/c/Program Files (x86)/Arm GNU Toolchain arm-none-eabi/14.3 rel1/bin:/c/Program Files (x86)/GnuWin32/bin:/c/Program Files/Git/usr/bin:/c/Program Files/Git/mingw64/bin:/c/Windows/System32:$PATH"
cd "/c/Users/sebue/Documents/N7SIX/Software/Quansheng/UV-K5Series_ApeX-Edition_v7.6.0" || exit 1

TARGET=$(make -p 2>/dev/null | awk -F' = ' '/^TARGET = /{print $2; exit}')
echo "TARGET=[$TARGET]"

rm -f "$TARGET"
make EXTRA_LDFLAGS="-Wl,-Map=.mapwork/flash.map" "$TARGET" > .mapwork/mapgen.log 2>&1
echo "make exit: $?"
tail -5 .mapwork/mapgen.log

if [ -f .mapwork/flash.map ]; then
  echo "MAP OK: $(wc -l < .mapwork/flash.map) lines"
else
  echo "MAP MISSING"
fi

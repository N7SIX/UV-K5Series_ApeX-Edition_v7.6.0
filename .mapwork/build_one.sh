#!/bin/bash
# Compile a single source with the Makefile's real flags to get the authoritative error list.
export PATH="/c/Program Files (x86)/Arm GNU Toolchain arm-none-eabi/14.3 rel1/bin:/c/Program Files (x86)/GnuWin32/bin:/c/Program Files/Git/usr/bin:/c/Program Files/Git/mingw64/bin:/c/Windows/System32:$PATH"
cd "/c/Users/sebue/Documents/N7SIX/Software/Quansheng/UV-K5Series_ApEX-Edition_v7.6.0" || exit 1
find . -name '*.d' -not -path './external/*' -delete 2>/dev/null
TARGET="${1:-app/spectrum.o}"
rm -f "$TARGET"
echo "=== make $TARGET ==="
make "$TARGET" 2>&1 | head -120
echo "=== exit: $? ==="
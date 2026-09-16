#!/bin/bash
# Attribute the FLASH-overflow warning: build HEAD's app/spectrum.c (commit
# baseline) with everything else identical, then restore the working copy and
# rebuild.  Results are appended to .mapwork/flash_compare.log.
export PATH="/c/Program Files (x86)/Arm GNU Toolchain arm-none-eabi/14.3 rel1/bin:/c/Program Files (x86)/GnuWin32/bin:/c/Program Files/Git/usr/bin:/c/Program Files/Git/mingw64/bin:/c/Windows/System32:$PATH"
cd "/c/Users/sebue/Documents/N7SIX/Software/Quansheng/UV-K5Series_ApeX-Edition_v7.6.0" || exit 1

LOG=".mapwork/flash_compare.log"
: > "$LOG"

clean_objs() {
  find . -name '*.d' -not -path './external/*' -delete 2>/dev/null
  find . -name '*.o' -not -path './external/*' -delete 2>/dev/null
  rm -f n7six n7six.bin n7six.packed.bin
}

# --- 1. Working copy (with the audio-route rewrite) ---
cp app/spectrum.c .mapwork/spectrum_working.c
clean_objs
echo "################ WORKING COPY (current spectrum.c) ################" >> "$LOG"
make -j4 >> "$LOG" 2>&1
echo "WORKING_EXIT=$?" >> "$LOG"
grep -E 'FLASH usage|RAM usage' "$LOG" | tail -2 >> "$LOG"

# --- 2. HEAD baseline spectrum.c ---
git show HEAD:app/spectrum.c > app/spectrum.c
clean_objs
echo "################ HEAD BASELINE spectrum.c ################" >> "$LOG"
make -j4 >> "$LOG" 2>&1
echo "HEAD_EXIT=$?" >> "$LOG"
grep -E 'FLASH usage|RAM usage' "$LOG" | tail -2 >> "$LOG"

# --- 3. restore ---
cp .mapwork/spectrum_working.c app/spectrum.c
clean_objs
echo "################ RESTORED (working copy rebuilt) ################" >> "$LOG"
make -j4 >> "$LOG" 2>&1
echo "RESTORED_EXIT=$?" >> "$LOG"
grep -E 'FLASH usage|RAM usage' "$LOG" | tail -2 >> "$LOG"

echo "=== DONE ===" >> "$LOG"
echo "=== DONE ===" >> .mapwork/flash_compare.done
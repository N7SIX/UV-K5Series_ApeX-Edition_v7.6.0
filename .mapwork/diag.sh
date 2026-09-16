#!/bin/bash
# A/B diagnostic: link errors when disabling ENABLE_FLASHLIGHT / ENABLE_UART
export PATH="/c/Program Files (x86)/Arm GNU Toolchain arm-none-eabi/14.3 rel1/bin:/c/Program Files (x86)/GnuWin32/bin:/c/Program Files/Git/usr/bin:/c/Program Files/Git/mingw64/bin:/c/Windows/System32:$PATH"
cd "/c/Users/sebue/Documents/N7SIX/Software/Quansheng/UV-K5Series_ApeX-Edition_v7.6.0" || exit 1
R=".mapwork"
cp Makefile "$R/Makefile.saved"

flash_size() { arm-none-eabi-size -A "$1" 2>/dev/null | awk '$1=="text"{t=$2} $1=="data"{d=$2} END{print t+d+0}'; }

# ---- Variant A: flashlight off ----
sed -i 's/^ENABLE_FLASHLIGHT ?= 1/ENABLE_FLASHLIGHT ?= 0/' Makefile
grep -n '^ENABLE_FLASHLIGHT' Makefile > "$R/diag_a.txt"
find . -name '*.d' -not -path './external/*' -delete 2>/dev/null
make -j8 > "$R/diag_a.txt" 2>&1
echo "A_EXIT=$?" >> "$R/diag_a.txt"
echo "A_FLASH=$(flash_size build/ApeX/*.elf)" >> "$R/diag_a.txt"
# link errors: keep undefined-reference blocks with context
grep -B2 -A6 'undefined reference' "$R/diag_a.txt" | head -60 >> "$R/diag_a.txt"

# ---- Variant B: flashlight off + uart off ----
sed -i 's/^ENABLE_UART ?= 1/ENABLE_UART ?= 0/' Makefile
find . -name '*.d' -not -path './external/*' -delete 2>/dev/null
make -j8 > "$R/diag_b.txt" 2>&1
echo "B_EXIT=$?" > "$R/diag_b.txt"
echo "B_FLASH=$(flash_size build/ApeX/*.elf)" >> "$R/diag_b.txt"
grep -B2 -A6 'undefined reference' "$R/diag_b.txt" | head -60 >> "$R/diag_b.txt"

# ---- Restore baseline ----
cp "$R/Makefile.saved" Makefile
find . -name '*.d' -not -path './external/*' -delete 2>/dev/null
make -j8 > "$R/diag_restore.txt" 2>&1
echo "RESTORE_EXIT=$?" > "$R/diag_done.txt"
echo "RESTORE_FLASH=$(flash_size build/ApeX/*.elf)" >> "$R/diag_done.txt"

#!/bin/bash
# Consolidated FLASH-audit diagnostic: baseline size + A/B link tests for the
# ENABLE_UART and ENABLE_FLASHLIGHT toggles. Writes a compact report to
# .mapwork/diag_report.txt so results survive context compaction.
export PATH="/c/Program Files (x86)/Arm GNU Toolchain arm-none-eabi/14.3 rel1/bin:/c/Program Files (x86)/GnuWin32/bin:/c/Program Files/Git/usr/bin:$PATH"
cd "/c/Users/sebue/Documents/N7SIX/Software/Quansheng/UV-K5Series_ApeX-Edition_v7.6.0" || exit 1
R=.mapwork/diag_report.txt
: > "$R"

flash_size() { # echo text+data bytes of linked firmware
  arm-none-eabi-size -A build/ApeX/n7six.ApeX.v7.6.10.elf 2>/dev/null |
    awk '$1==".text"||$1==".isr_vector"||$1==".data"||$1==".ARM.exidx"{s+=$2} END{print s}'
}

run_variant() { # $1=label, $2=make line
  echo "===== VARIANT: $1 =====" >> "$R"
  eval "$2" >> "$R" 2>&1
  if [ -f build/ApeX/n7six.ApeX.v7.6.10.elf ]; then
    echo "RESULT: FLASH(text+data)=$(flash_size)" >> "$R"
  else
    echo "RESULT: LINK FAILED" >> "$R"
    grep -E "undefined|error:" build.log 2>/dev/null | head -8 >> "$R"
  fi
}

# Baseline: current flags
make clean > /dev/null 2>&1
run_variant "BASELINE (current Makefile)" "make -j4 2>&1 | tail -2 > build.log; true"

# UART disabled
make clean > /dev/null 2>&1
run_variant "UART=0" "make -j4 ENABLE_UART=0 2>&1 | grep -E 'undefined reference|Error' | head -6 > build.log; true"

# Flashlight disabled
make clean > /dev/null 2>&1
run_variant "FLASHLIGHT=0" "make -j4 ENABLE_FLASHLIGHT=0 2>&1 | grep -E 'undefined reference|Error' | head -6 > build.log; true"

# Restore baseline
make clean > /dev/null 2>&1
make -j4 > /dev/null 2>&1
echo "===== RESTORED BASELINE =====" >> "$R"
echo "RESULT: FLASH(text+data)=$(flash_size)" >> "$R"
echo DONE >> "$R"

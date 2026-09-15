#!/bin/bash
# Controlled firmware-level size comparison: HEAD spectrum.c vs optimized spectrum.c
export PATH="/c/Program Files (x86)/Arm GNU Toolchain arm-none-eabi/14.3 rel1/bin:/c/Program Files/Git/usr/bin:/c/Program Files (x86)/GnuWin32/bin:$PATH"
cd "/c/Users/sebue/Documents/N7SIX/Software/Quansheng/UV-K5Series_ApEX-Edition_v7.6.0" || exit 1
ELF="build/ApeX/n7six.ApeX.v7.6.10.elf"

echo "### STEP 1: HEAD (original) spectrum.c"
git stash push -- app/spectrum.c
make 2>&1 | tail -6
echo "--- HEAD size ---"
arm-none-eabi-size "$ELF"
cp "$ELF" .mapwork/elf_head.elf

echo ""
echo "### STEP 2: optimized spectrum.c"
git stash pop
make 2>&1 | tail -6
echo "--- OPT size ---"
arm-none-eabi-size "$ELF"
cp "$ELF" .mapwork/elf_opt.elf

echo ""
echo "### STEP 3: flash end addresses"
arm-none-eabi-nm .mapwork/elf_head.elf | grep ' _etext$'
arm-none-eabi-nm .mapwork/elf_opt.elf  | grep ' _etext$'
echo "### DONE"
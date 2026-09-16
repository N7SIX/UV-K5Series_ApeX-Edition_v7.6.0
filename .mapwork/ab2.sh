#!/bin/bash
# Honest A/B FLASH measurement: full rebuild per variant, verified size deltas.
export PATH="/c/Program Files (x86)/Arm GNU Toolchain arm-none-eabi/14.3 rel1/bin:/c/Program Files (x86)/GnuWin32/bin:/c/Program Files/Git/usr/bin:/c/Program Files/Git/mingw64/bin:/c/Windows/System32:$PATH"
cd "/c/Users/sebue/Documents/N7SIX/Software/Quansheng/UV-K5Series_ApEX-Edition_v7.6.0" || exit 1

SIZE="$PWD/.mapwork/ab2.out"
: > "$SIZE"

flash_of() {
  # Sum of loadable sections reported by size, or parse the Makefile's own check
  arm-none-eabi-size build/ApeX/*.elf 2>/dev/null | awk 'NR==2{print $1+$2}'
}

build_variant() {
  local tag="$1"; shift
  echo "=== VARIANT: $tag ($*) ===" >> "$SIZE"
  make clean >/dev/null 2>&1
  if make -j4 "$@" 2>"/tmp/ab2_err_$tag.log"; then
    f=$(flash_of)
    echo "$tag FLASH=$((f))" >> "$SIZE"
  else
    echo "$tag FAILED" >> "$SIZE"
    tail -5 "/tmp/ab2_err_$tag.log" >> "$SIZE"
  fi
}

build_variant baseline
build_variant no_flashlight   ENABLE_FLASHLIGHT=0
build_variant no_uart         ENABLE_UART=0
build_variant no_both         ENABLE_UART=0 ENABLE_FLASHLIGHT=0
build_variant restore_baseline
echo "=== ALL DONE ===" >> "$SIZE"

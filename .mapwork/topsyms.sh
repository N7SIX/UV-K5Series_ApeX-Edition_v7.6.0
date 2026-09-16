#!/bin/bash
# List the largest linked symbols (code + rodata + data) with their defining object file.
# Uses .mapwork/sym2obj.txt and .mapwork/elf_syms.txt produced by attrib.sh.
export PATH="/c/Program Files (x86)/Arm GNU Toolchain arm-none-eabi/14.3 rel1/bin:/c/Program Files (x86)/GnuWin32/bin:/c/Program Files/Git/usr/bin:/c/Program Files/Git/mingw64/bin:/c/Windows/System32:$PATH"
cd "/c/Users/sebue/Documents/N7SIX/Software/Quansheng/UV-K5Series_ApeX-Edition_v7.6.0" || exit 1

arm-none-eabi-nm --print-size n7six 2>/dev/null | tr -d '\r' > .mapwork/elf_syms.txt

awk '
  NR==FNR { obj[$1]=$2; next }
  {
    if (NF < 4) next;
    addr = strtonum("0x" $1); size = strtonum("0x" $2); type = $3; name = $4;
    if (type == "U" || type == "u" || size == 0) next;
    key = name; sub(/\.lto_priv\.[0-9]+$/, "", key); sub(/\.constprop\.[0-9]+$/, "", key); sub(/\.part\.[0-9]+$/, "", key);
    f = (key in obj) ? obj[key] : "?";
    akey = key ":" addr ":" size;
    if (seen[akey]++) next;
    printf "%6d %s %-16s %s\n", size, type, f, name;
  }
' .mapwork/sym2obj.txt .mapwork/elf_syms.txt | sort -rn | head -55

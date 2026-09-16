#!/bin/bash
# Attribute linked-ELF code bytes back to the .o file that defines each symbol.
# LTO (with -flto-partition=none) makes the linker map useless for attribution,
# so instead: read symbol sizes from the linked ELF, then resolve each symbol's
# defining object via nm on the per-file .o objects (-ffat-lto-objects keeps the
# real symbol tables in them).
export PATH="/c/Program Files (x86)/Arm GNU Toolchain arm-none-eabi/14.3 rel1/bin:/c/Program Files (x86)/GnuWin32/bin:/c/Program Files/Git/usr/bin:/c/Program Files/Git/mingw64/bin:/c/Windows/System32:$PATH"
cd "/c/Users/sebue/Documents/N7SIX/Software/Quansheng/UV-K5Series_ApeX-Edition_v7.6.0" || exit 1

ELF="${1:-n7six}"

# --- 1. symbol -> defining object file -------------------------------------
# tr -d '\r': nm emits CRLF on Windows and the \r would break every name match.
: > .mapwork/sym2obj.txt
for o in $(find app driver radio ui audio core system bsp helper graphics globals -name '*.o' 2>/dev/null); do
  arm-none-eabi-nm --defined-only "$o" 2>/dev/null | tr -d '\r' | awk -v f="$o" '{print $3, f}'
done | sort -u -k1,1 > .mapwork/sym2obj.txt

arm-none-eabi-nm --print-size "$ELF" 2>/dev/null | tr -d '\r' > .mapwork/elf_syms.txt

# --- 2. join and aggregate --------------------------------------------------
awk '
  NR==FNR { obj[$1]=$2; next }
  {
    size = strtonum("0x" $2); type = $3; name = $4;
    if (type != "t" && type != "T" && type != "w" && type != "W") next;
    key = name;
    sub(/\.lto_priv\.[0-9]+$/, "", key);
    sub(/\.constprop\.[0-9]+$/, "", key);
    sub(/\.part\.[0-9]+$/, "", key);
    if (!(key in obj)) next;
    # Aliases share an address: key on address+size so they are counted once.
    addr = strtonum("0x" $1);
    akey = key ":" addr ":" size;
    if (seen[akey]++) next;
    file[obj[key]] += size;
    total += size;
  }
  END {
    printf "%-26s %8s %6s\n", "FILE", "BYTES", "PCT";
    for (f in file) printf "%-26s %8d %5.1f%%\n", f, file[f], (total ? 100*file[f]/total : 0);
    printf "%-26s %8d\n", "TOTAL(attributed)", total;
  }
' .mapwork/sym2obj.txt .mapwork/elf_syms.txt | sort -k2 -rn > .mapwork/attrib.txt

cat .mapwork/attrib.txt

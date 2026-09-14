#!/bin/bash
# Flash-size experiment matrix for ApeX (runs inside container)
set -e
cd /app
sed -i 's/LENGTH = 64K/LENGTH = 68K/' config/firmware.ld

M() { make clean >/dev/null 2>&1; make -s -j4 EDITION_STRING=ApeX TARGET=ApeX 2>&1 | tail -n 2; }

echo '=== BASELINE ==='
M
echo '--- TOP TEXT/RODATA SYMBOLS ---'
arm-none-eabi-nm --size-sort -S -td ApeX | grep ' [tTrRdD] ' | tail -n 30
echo '--- LIBC / PRINTF MEMBERS ---'
arm-none-eabi-nm -S -td ApeX | grep -iE ' (memcpy|memset|strlen|memcmp|strcmp|strcpy|memmove|sprintf|printf|_vfprintf|__ssputs|__malloc)' || true

echo '=== EXP1: drop -fno-builtin ==='
sed -i 's/ -fno-builtin//g' Makefile
M

echo '=== EXP2: + -Wl,-O2 ==='
sed -i 's/-z noexecstack/-z noexecstack -Wl,-O2/' Makefile
M

echo '=== EXP3: + -fno-unwind-tables -fno-asynchronous-unwind-tables ==='
sed -i 's/-std=c2x -MMD/-std=c2x -MMD -fno-unwind-tables -fno-asynchronous-unwind-tables/g' Makefile
M

echo '=== FINAL: verify at real 64K with current winners ==='
sed -i 's/LENGTH = 68K/LENGTH = 64K/' config/firmware.ld
M

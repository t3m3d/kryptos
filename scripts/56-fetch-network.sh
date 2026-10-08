#!/usr/bin/env bash
# Pinned BLFS-compatible DHCP client; hash from the upstream release page.
set -euo pipefail
: "${LFS:=/mnt/lfs}"
VERSION=10.2.2
SHA256=5f257b02f874b3b8cb031e5be79c99cf9cbd4f65eae2a50c9b1beddafb3f51bc
mkdir -p "$LFS/sources"
cd "$LFS/sources"
FILE="dhcpcd-$VERSION.tar.xz"
if [ ! -s "$FILE" ]; then
    trap 'rm -f "$FILE.part"' EXIT
    curl --fail --location --retry 3 --connect-timeout 20 --max-time 180 \
        "https://github.com/NetworkConfiguration/dhcpcd/releases/download/v$VERSION/$FILE" -o "$FILE.part"
    printf '%s  %s\n' "$SHA256" "$FILE.part" | sha256sum -c -
    mv "$FILE.part" "$FILE"
fi
printf '%s  %s\n' "$SHA256" "$FILE" | sha256sum -c -

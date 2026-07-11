#!/usr/bin/env bash
# Fetch UEFI installer support tools.
set -euo pipefail
: "${LFS:=/mnt/lfs}"
S="$LFS/sources"
mkdir -p "$S"
cd "$S"

fetch() {
    local url="$1" file
    file="$(basename "$url")"
    [ -s "$file" ] && { echo "have  $file"; return 0; }
    echo "fetch $file"
    wget -c --timeout=30 --tries=3 "$url"
}

fetch https://github.com/dosfstools/dosfstools/releases/download/v4.2/dosfstools-4.2.tar.gz

echo "UEFI support sources present in $S"
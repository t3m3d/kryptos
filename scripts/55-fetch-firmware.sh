#!/usr/bin/env bash
# Fetch the pinned upstream firmware used by physical KryptOS hardware images.
set -euo pipefail
: "${LFS:=/mnt/lfs}"
S="$LFS/sources"
VERSION=20260622
ARCHIVE="linux-firmware-$VERSION.tar.xz"
URL="https://www.kernel.org/pub/linux/kernel/firmware/$ARCHIVE"
SHA256=2b9d8a358e76eb766588609135e53fa548b902c551daae33ee32f26f25e60dbb

mkdir -p "$S"
cd "$S"

if [ ! -s "$ARCHIVE" ]; then
    echo "fetch $ARCHIVE"
    timeout 1800 wget -q -c -O "$ARCHIVE" "$URL"
fi

printf '%s  %s\n' "$SHA256" "$ARCHIVE" | sha256sum -c -
echo "firmware source ready: $S/$ARCHIVE"

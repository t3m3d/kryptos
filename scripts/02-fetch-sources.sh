#!/usr/bin/env bash
# Download all LFS sources for $LFS_VERSION into $LFS/sources and verify md5sums.
# Run after env.sh is sourced and $LFS is mounted/writable.
set -euo pipefail

[ -n "${LFS:-}" ] || { echo "source env.sh first"; exit 1; }
[ -d "$LFS" ] || { echo "$LFS does not exist — create/mount it first"; exit 1; }

SRC="$LFS/sources"
BASE="https://www.linuxfromscratch.org/lfs/downloads/${LFS_VERSION}"

mkdir -pv "$SRC"
chmod a+wt "$SRC"   # sticky so the lfs user can write here too

echo "[KryptOS] fetching wget-list + md5sums for LFS ${LFS_VERSION}"
wget -q "$BASE/wget-list" -O "$SRC/wget-list" \
    || { echo "couldn't fetch wget-list — check LFS_VERSION ($LFS_VERSION) / network"; exit 1; }
wget -q "$BASE/md5sums" -O "$SRC/md5sums" || true

echo "[KryptOS] downloading sources (resumable) ..."
wget --input-file="$SRC/wget-list" --continue --directory-prefix="$SRC"

if [ -s "$SRC/md5sums" ]; then
    echo "[KryptOS] verifying md5sums ..."
    ( cd "$SRC" && md5sum -c md5sums ) | (grep -v ': OK$' || true)
    echo "[KryptOS] (any lines above are mismatches/missing — empty = all good)"
else
    echo "[KryptOS] no md5sums file — skipping verify (fetch it manually to be safe)"
fi

echo "[KryptOS] sources in $SRC"

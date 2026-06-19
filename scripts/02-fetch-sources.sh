#!/usr/bin/env bash
# Download all LFS sources for $LFS_VERSION into $LFS/sources, md5-verify.
# Robust against rotten mirrors: GNU URLs routed to kernel.org, each download
# capped by a timeout so one stuck/dead URL can't block the rest, failures
# collected for a retry. (Lessons from the 2026-06-19 first run: ftp.gnu.org
# refused, sourceforge expat 404'd, a sequential wget hung silently.)
set -euo pipefail

[ -n "${LFS:-}" ] || { echo "source env.sh first"; exit 1; }
[ -d "$LFS" ] || { echo "$LFS does not exist — create/mount it first"; exit 1; }

SRC="$LFS/sources"
BASE="https://www.linuxfromscratch.org/lfs/downloads/${LFS_VERSION}"
mkdir -pv "$SRC"; chmod a+wt "$SRC"; cd "$SRC"

echo "[KryptOS] wget-list + md5sums for LFS ${LFS_VERSION}"
wget -q "$BASE/wget-list" -O wget-list
wget -q "$BASE/md5sums" -O md5sums || true

# route flaky GNU hosts to the reliable kernel.org mirror
sed -i -E 's#https?://ftp\.gnu\.org/gnu#https://mirrors.kernel.org/gnu#g; s#https?://ftpmirror\.gnu\.org#https://mirrors.kernel.org/gnu#g' wget-list
# expat on sourceforge prdownloads 404s — use the libexpat GitHub release
sed -i -E 's#https?://prdownloads\.sourceforge\.net/expat/(expat-([0-9.]+)\.tar\.[a-z]+)#https://github.com/libexpat/libexpat/releases/download/R_\2/\1#; ' wget-list
sed -i 's#R_\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)#R_\1_\2_\3#' wget-list   # 2.6.2 -> 2_6_2 in the GitHub tag

: > failed.txt
echo "[KryptOS] downloading (per-file 120s cap, resumable) ..."
while read -r url; do
    [ -z "$url" ] && continue
    f=$(basename "$url")
    [ -s "$f" ] && continue
    if timeout 120 wget -q -c --timeout=25 --tries=3 "$url"; then
        echo "  ok   $f"
    else
        echo "  FAIL $url"; echo "$url" >> failed.txt
    fi
done < wget-list

if [ -s failed.txt ]; then
    echo "[KryptOS] $(wc -l < failed.txt) download(s) FAILED — see $SRC/failed.txt (fix mirror + re-run)"
fi
if [ -s md5sums ]; then
    echo "[KryptOS] md5 check (mismatches/missing below; empty = all good):"
    md5sum -c md5sums 2>/dev/null | grep -v ': OK$' || true
fi
echo "[KryptOS] sources in $SRC"

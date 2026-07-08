#!/usr/bin/env bash
# Fetch first-ISO developer tooling sources. These are outside the strict LFS
# book but required for KryptOS to be useful as a source-first distro: curl for
# HTTPS fetches, Git for source control, and Mozilla CA roots for TLS trust.
set -uo pipefail
: "${LFS:=/mnt/lfs}"
S="$LFS/sources"
mkdir -p "$S"; cd "$S"

URLS=(
  "https://curl.se/download/curl-8.10.1.tar.xz"
  "https://www.kernel.org/pub/software/scm/git/git-2.46.2.tar.xz"
  "https://curl.se/ca/cacert.pem"
)

fail=()
for u in "${URLS[@]}"; do
    f="$(basename "$u")"
    if [ -s "$f" ]; then echo "have $f"; continue; fi
    echo "fetch $f"
    if ! timeout 180 wget -q -c -O "$f" "$u"; then
        echo "  FAILED $u"; rm -f "$f"; fail+=("$u")
    fi
done

echo "----"
if [ ${#fail[@]} -gt 0 ]; then
    printf '%s\n' "${fail[@]}" > "$S/devtools-failed.txt"
    echo "FAILURES (${#fail[@]}) -> $S/devtools-failed.txt:"; printf '  %s\n' "${fail[@]}"
    exit 1
fi
echo "all devtools sources present in $S"

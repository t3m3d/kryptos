#!/usr/bin/env bash
# Fetch pinned Qt and Quickshell sources for the first graphical KryptOS image.
# Qt modules are fetched separately to avoid the much larger qt-everywhere tree.
set -uo pipefail
: "${LFS:=/mnt/lfs}"
S="$LFS/sources"
mkdir -p "$S"; cd "$S"

URLS=(
  "https://download.qt.io/archive/qt/6.7/6.7.3/submodules/qtbase-everywhere-src-6.7.3.tar.xz"
  "https://download.qt.io/archive/qt/6.7/6.7.3/submodules/qtshadertools-everywhere-src-6.7.3.tar.xz"
  "https://download.qt.io/archive/qt/6.7/6.7.3/submodules/qtdeclarative-everywhere-src-6.7.3.tar.xz"
  "https://download.qt.io/archive/qt/6.7/6.7.3/submodules/qtwayland-everywhere-src-6.7.3.tar.xz"
  "https://download.qt.io/archive/qt/6.7/6.7.3/submodules/qtsvg-everywhere-src-6.7.3.tar.xz"
  "https://gitlab.freedesktop.org/wayland/wayland-protocols/-/releases/1.48/downloads/wayland-protocols-1.48.tar.xz"
  "https://github.com/CLIUtils/CLI11/archive/refs/tags/v2.4.2.tar.gz"
  "https://github.com/quickshell-mirror/quickshell/archive/refs/tags/v0.3.0.tar.gz"
)

fail=()
for u in "${URLS[@]}"; do
    f="$(basename "$u")"
    case "$u" in
        *CLIUtils/CLI11*)        f="CLI11-2.4.2.tar.gz" ;;
        *quickshell-mirror*)     f="quickshell-0.3.0.tar.gz" ;;
    esac
    if [ -s "$f" ]; then echo "have $f"; continue; fi
    echo "fetch $f"
    if ! timeout 600 wget -q -c -O "$f" "$u"; then
        echo "  FAILED $u"; rm -f "$f"; fail+=("$u")
    fi
done

echo "----"
if [ ${#fail[@]} -gt 0 ]; then
    printf '%s\n' "${fail[@]}" > "$S/quickshell-failed.txt"
    echo "FAILURES (${#fail[@]}) -> $S/quickshell-failed.txt:"
    printf '  %s\n' "${fail[@]}"
    exit 1
fi
echo "all Qt and Quickshell sources present in $S"

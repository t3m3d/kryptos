#!/usr/bin/env bash
# Fetch the BLFS-level sources for the KryptOS Hyprland/Wayland desktop layer.
# Arch-independent (same tarballs for arm64 + x86_64). Robust per-file wget with
# a timeout + a failed.txt summary, like 02-fetch-sources.sh. Downloads into
# $LFS/sources alongside the base sources.
set -uo pipefail
: "${LFS:=/mnt/lfs}"
S="$LFS/sources"
mkdir -p "$S"; cd "$S"

URLS=(
  # --- build tooling ---
  "https://github.com/Kitware/CMake/releases/download/v3.30.5/cmake-3.30.5.tar.gz"
  "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.44/pcre2-10.44.tar.bz2"
  "https://download.gnome.org/sources/glib/2.82/glib-2.82.2.tar.xz"
  # --- render stack ---
  "https://www.cairographics.org/releases/pixman-0.44.0.tar.gz"
  "https://download.savannah.gnu.org/releases/freetype/freetype-2.13.3.tar.xz"
  "https://www.freedesktop.org/software/fontconfig/release/fontconfig-2.15.0.tar.xz"
  "https://github.com/harfbuzz/harfbuzz/releases/download/10.1.0/harfbuzz-10.1.0.tar.xz"
  "https://www.cairographics.org/releases/cairo-1.18.2.tar.xz"
  "https://download.gnome.org/sources/pango/1.54/pango-1.54.0.tar.xz"
  # --- wayland core ---
  "https://gitlab.freedesktop.org/wayland/wayland/-/releases/1.23.1/downloads/wayland-1.23.1.tar.xz"
  "https://gitlab.freedesktop.org/wayland/wayland-protocols/-/releases/1.38/downloads/wayland-protocols-1.38.tar.xz"
  "https://xkbcommon.org/download/libxkbcommon-1.7.0.tar.xz"
  "https://dri.freedesktop.org/libdrm/libdrm-2.4.123.tar.xz"
  "https://github.com/vcrhonek/hwdata/archive/v0.388/hwdata-0.388.tar.gz"
  "https://gitlab.freedesktop.org/emersion/libdisplay-info/-/releases/0.2.0/downloads/libdisplay-info-0.2.0.tar.xz"
  # --- graphics (software GL for the VM) ---
  "https://github.com/llvm/llvm-project/releases/download/llvmorg-19.1.4/llvm-19.1.4.src.tar.xz"
  "https://github.com/llvm/llvm-project/releases/download/llvmorg-19.1.4/cmake-19.1.4.src.tar.xz"
  "https://github.com/llvm/llvm-project/releases/download/llvmorg-19.1.4/third-party-19.1.4.src.tar.xz"
  "https://archive.mesa3d.org/mesa-24.2.7.tar.xz"
  # --- input / session (sysvinit: seatd, no logind) ---
  "https://www.freedesktop.org/software/libevdev/libevdev-1.13.3.tar.xz"
  "http://bitmath.org/code/mtdev/mtdev-1.1.6.tar.bz2"
  "https://gitlab.freedesktop.org/libinput/libinput/-/archive/1.26.1/libinput-1.26.1.tar.gz"
  "https://git.sr.ht/~kennylevinsen/seatd/archive/0.8.0.tar.gz"
  # --- hypr stack ---
  "https://github.com/hyprwm/hyprwayland-scanner/archive/v0.4.2/hyprwayland-scanner-0.4.2.tar.gz"
  "https://github.com/hyprwm/hyprutils/archive/v0.2.6/hyprutils-0.2.6.tar.gz"
  "https://github.com/hyprwm/hyprlang/archive/v0.5.3/hyprlang-0.5.3.tar.gz"
  "https://github.com/hyprwm/hyprcursor/archive/v0.1.10/hyprcursor-0.1.10.tar.gz"
  "https://github.com/hyprwm/hyprgraphics/archive/v0.1.2/hyprgraphics-0.1.2.tar.gz"
  "https://github.com/hyprwm/aquamarine/archive/v0.6.0/aquamarine-0.6.0.tar.gz"
  "https://github.com/hyprwm/Hyprland/releases/download/v0.45.2/source-v0.45.2.tar.gz"
)

fail=()
for u in "${URLS[@]}"; do
    f="$(basename "$u")"
    # normalise gitlab/sourcehut archive names that come without the version
    case "$u" in
        *libinput*archive*) f="libinput-1.26.1.tar.gz" ;;
        *seatd*archive*)    f="seatd-0.8.0.tar.gz" ;;
        *Hyprland*source-*) f="Hyprland-0.45.2.tar.gz" ;;
        # LLVM aux tarball collides with cmake-* glob → rename
        */cmake-19.1.4.src*) f="llvm-cmake-19.1.4.src.tar.xz" ;;
    esac
    if [ -s "$f" ]; then echo "have $f"; continue; fi
    echo "fetch $f"
    if ! timeout 180 wget -q -c -O "$f" "$u"; then
        echo "  FAILED $u"; rm -f "$f"; fail+=("$u")
    fi
done

echo "----"
if [ ${#fail[@]} -gt 0 ]; then
    printf '%s\n' "${fail[@]}" > "$S/desktop-failed.txt"
    echo "FAILURES (${#fail[@]}) → $S/desktop-failed.txt:"; printf '  %s\n' "${fail[@]}"
    exit 1
fi
echo "all desktop sources present in $S"

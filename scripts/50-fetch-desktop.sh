#!/usr/bin/env bash
# Fetch the BLFS-level sources for the KryptOS Hyprland/Wayland desktop layer.
# Arch-independent (same tarballs for arm64 + x86_64). Robust per-file wget with
# a timeout + a failed.txt summary, like 02-fetch-sources.sh. Downloads into
# $LFS/sources alongside the base sources.
set -uo pipefail
: "${LFS:=/mnt/lfs}"
S="$LFS/sources"
mkdir -p "$S"; cd "$S"

case "$(uname -m)" in
    x86_64)        RUST_ARCH=x86_64 ;;
    aarch64|arm64) RUST_ARCH=aarch64 ;;
    *) echo "unsupported desktop build architecture: $(uname -m)" >&2; exit 1 ;;
esac

URLS=(
  # --- build tooling ---
  "https://github.com/Kitware/CMake/releases/download/v3.30.5/cmake-3.30.5.tar.gz"
  "https://github.com/Kitware/CMake/releases/download/v3.30.5/cmake-3.30.5-linux-${RUST_ARCH}.tar.gz"
  "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.44/pcre2-10.44.tar.bz2"
  "https://download.gnome.org/sources/glib/2.82/glib-2.82.2.tar.xz"
  "https://files.pythonhosted.org/packages/source/m/markupsafe/markupsafe-3.0.2.tar.gz"
  "https://files.pythonhosted.org/packages/source/m/mako/mako-1.3.8.tar.gz"
  "https://files.pythonhosted.org/packages/source/p/pyyaml/pyyaml-6.0.2.tar.gz"
  # --- render stack ---
  "https://www.cairographics.org/releases/pixman-0.44.0.tar.gz"
  "https://download.savannah.gnu.org/releases/freetype/freetype-2.13.3.tar.xz"
  "https://www.freedesktop.org/software/fontconfig/release/fontconfig-2.15.0.tar.xz"
  "https://github.com/harfbuzz/harfbuzz/releases/download/10.1.0/harfbuzz-10.1.0.tar.xz"
  "https://www.cairographics.org/releases/cairo-1.18.2.tar.xz"
  "https://download.gnome.org/sources/pango/1.54/pango-1.54.0.tar.xz"
  "https://download.sourceforge.net/libpng/libpng-1.6.44.tar.xz"
  "https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/3.0.4/libjpeg-turbo-3.0.4.tar.gz"
  "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.4.0.tar.gz"
  "https://github.com/fribidi/fribidi/releases/download/v1.0.16/fribidi-1.0.16.tar.xz"
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
  "https://archive.mesa3d.org/mesa-24.3.4.tar.xz"
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
  # --- Hyprland build dependencies ---
  "https://static.rust-lang.org/dist/rust-1.83.0-${RUST_ARCH}-unknown-linux-gnu.tar.xz"
  "https://download.gnome.org/sources/libxml2/2.13/libxml2-2.13.5.tar.xz"
  "https://download.gnome.org/sources/gdk-pixbuf/2.42/gdk-pixbuf-2.42.12.tar.xz"
  "https://download.gnome.org/sources/librsvg/2.54/librsvg-2.54.7.tar.xz"
  "https://github.com/zeux/pugixml/releases/download/v1.14/pugixml-1.14.tar.gz"
  "https://github.com/marzer/tomlplusplus/archive/v3.4.0/tomlplusplus-3.4.0.tar.gz"
  "https://libzip.org/download/libzip-1.11.2.tar.xz"
  "https://github.com/randy408/libspng/archive/v0.7.4/libspng-0.7.4.tar.gz"
  "https://github.com/hyprwm/hyprland-protocols/archive/v0.4.0/hyprland-protocols-0.4.0.tar.gz"
  # --- cursor and keymap support ---
  "https://www.x.org/pub/individual/util/util-macros-1.20.1.tar.xz"
  "https://xorg.freedesktop.org/archive/individual/proto/xorgproto-2024.1.tar.xz"
  "https://www.x.org/pub/individual/lib/libXau-1.0.11.tar.xz"
  "https://www.x.org/pub/individual/lib/libXdmcp-1.1.5.tar.xz"
  "https://xorg.freedesktop.org/archive/individual/proto/xcb-proto-1.17.0.tar.xz"
  "https://www.x.org/pub/individual/lib/libpthread-stubs-0.5.tar.xz"
  "https://xorg.freedesktop.org/archive/individual/lib/libxcb-1.17.0.tar.xz"
  "https://www.x.org/pub/individual/lib/xtrans-1.5.0.tar.xz"
  "https://www.x.org/pub/individual/lib/libX11-1.8.10.tar.xz"
  "https://www.x.org/pub/individual/lib/libXrender-0.9.11.tar.xz"
  "https://www.x.org/pub/individual/lib/libXfixes-6.0.1.tar.xz"
  "https://www.x.org/pub/individual/lib/libXcursor-1.2.3.tar.xz"
  "https://www.x.org/pub/individual/data/xkeyboard-config/xkeyboard-config-2.43.tar.xz"
  # --- desktop tools ---
  "https://codeberg.org/dnkl/tllist/archive/1.1.0.tar.gz"
  "https://github.com/JuliaStrings/utf8proc/archive/v2.9.0/utf8proc-2.9.0.tar.gz"
  "https://codeberg.org/dnkl/fcft/archive/3.1.9.tar.gz"
  "https://codeberg.org/dnkl/foot/archive/1.18.1.tar.gz"
  "https://gitlab.freedesktop.org/emersion/grim/-/archive/v1.4.1/grim-v1.4.1.tar.gz"
  "https://github.com/dejavu-fonts/dejavu-fonts/releases/download/version_2_37/dejavu-fonts-ttf-2.37.tar.bz2"
)

fail=()
for u in "${URLS[@]}"; do
    f="$(basename "$u")"
    # normalise gitlab/sourcehut archive names that come without the version
    case "$u" in
        *libinput*archive*) f="libinput-1.26.1.tar.gz" ;;
        *seatd*archive*)    f="seatd-0.8.0.tar.gz" ;;
        *Hyprland*source-*) f="Hyprland-0.45.2.tar.gz" ;;
        *cmake-3.30.5-linux-*) f="bootstrap-$(basename "$u")" ;;
        # LLVM aux tarball collides with cmake-* glob → rename
        */cmake-19.1.4.src*) f="llvm-cmake-19.1.4.src.tar.xz" ;;
        *dnkl/tllist*) f="tllist-1.1.0.tar.gz" ;;
        *dnkl/fcft*)   f="fcft-3.1.9.tar.gz" ;;
        *dnkl/foot*)   f="foot-1.18.1.tar.gz" ;;
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

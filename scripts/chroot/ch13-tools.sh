#!/usr/bin/env bash
# Desktop tools — small Wayland utilities. grim: screenshot via wlr-screencopy
# (reads the compositor's rendered buffer directly; used to capture the desktop
# without relying on the VM's DRM page-flip/scanout). Runs inside the chroot.
set -uo pipefail
set +h
export LFS=/ KRYPTOS_ROOT=/root/kryptos
source /root/kryptos/lib/build.sh

mesonb() { local p="$1"; shift; into "$p"; rm -rf build; \
    meson setup build --prefix=/usr --libdir=lib --buildtype=release "$@"; \
    ninja -C build; ninja -C build install; }

# grim bundles the wlr-screencopy protocol; deps = wayland-client, pixman, libpng
b_grim() { mesonb grim- -Dman-pages=disabled; }

# DejaVu fonts — without any font, Hyprland/pango render text as tofu squares
b_fonts() {
    into dejavu-fonts-ttf-
    mkdir -pv /usr/share/fonts/dejavu
    cp -v ttf/*.ttf /usr/share/fonts/dejavu/
    fc-cache -f
}

msg "desktop tools"
step d_grim  b_grim
step d_fonts b_fonts
msg "desktop tools done."

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

msg "desktop tools"
step d_grim b_grim
msg "desktop tools done."

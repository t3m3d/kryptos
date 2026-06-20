#!/usr/bin/env bash
# Desktop terminal — foot (Wayland) + its deps. Gives the Hyprland session an
# actual terminal so SUPER+Return is useful. Runs inside the chroot; resumable.
set -uo pipefail
set +h
export LFS=/ KRYPTOS_ROOT=/root/kryptos
source /root/kryptos/lib/build.sh

mesonb() { local p="$1"; shift; into "$p"; rm -rf build; \
    meson setup build --prefix=/usr --libdir=lib --buildtype=release "$@"; \
    ninja -C build; ninja -C build install; }
cmkb() { local p="$1"; shift; into "$p"; rm -rf b; \
    cmake -S . -B b -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_BUILD_TYPE=Release "$@"; ninja -C b; ninja -C b install; }

b_tllist()   { mesonb tllist- ; }                                  # header-only + .pc
b_utf8proc() { cmkb utf8proc- -DBUILD_SHARED_LIBS=ON; }
b_fcft()     { mesonb fcft- -Ddocs=disabled; }
b_foot()     { mesonb foot- -Ddocs=disabled -Dterminfo=disabled; }

msg "desktop terminal: foot"
step d_tllist   b_tllist
step d_utf8proc b_utf8proc
step d_fcft     b_fcft
step d_foot     b_foot
msg "foot installed."

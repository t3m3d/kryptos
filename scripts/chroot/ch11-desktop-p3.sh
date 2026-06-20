#!/usr/bin/env bash
# Desktop layer, Phase 3 — input + session for a sysvinit Wayland seat.
#   libevdev, mtdev, libinput, seatd (+libseat; no logind on sysvinit).
# Runs inside the chroot; resumable. All deps satisfied by base + Phase 1/2.
set -uo pipefail
set +h
export LFS=/ KRYPTOS_ROOT=/root/kryptos
source /root/kryptos/lib/build.sh

mesonb() { local p="$1"; shift; into "$p"; rm -rf build; \
    meson setup build --prefix=/usr --libdir=lib --buildtype=release "$@"; \
    ninja -C build; ninja -C build install; }

b_libevdev() { into libevdev-; ./configure --prefix=/usr --disable-static; make; make install; }
b_mtdev()    { into mtdev-;    ./configure --prefix=/usr --disable-static; make; make install; }
b_libinput() { mesonb libinput- -Ddebug-gui=false -Dtests=false -Ddocumentation=false -Dlibwacom=false; }
# seatd daemon + libseat (logind disabled — sysvinit). Hyprland uses libseat->seatd.
b_seatd() {
    mesonb seatd- -Dlibseat-logind=disabled -Dlibseat-seatd=enabled -Dserver=enabled \
        -Dman-pages=disabled -Dexamples=disabled
    # seat group + boot enablement
    getent group seat >/dev/null 2>&1 || groupadd -r seat 2>/dev/null || true
}

msg "desktop Phase 3: input + session (libinput, seatd)"
step d_libevdev b_libevdev
step d_mtdev    b_mtdev
step d_libinput b_libinput
step d_seatd    b_seatd
msg "desktop Phase 3 done — next: hypr stack."

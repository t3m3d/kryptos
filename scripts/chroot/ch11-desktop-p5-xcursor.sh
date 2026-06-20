#!/usr/bin/env bash
# Desktop layer, Phase 5 — the minimal X11 chain libXcursor needs (Hyprland
# requires xcursor to load standard cursor themes, independent of XWayland).
# Small, fast autotools/meson libs. Runs inside the chroot; resumable.
set -uo pipefail
set +h
export LFS=/ KRYPTOS_ROOT=/root/kryptos
source /root/kryptos/lib/build.sh

mesonb() { local p="$1"; shift; into "$p"; rm -rf build; \
    meson setup build --prefix=/usr --libdir=lib --buildtype=release "$@"; \
    ninja -C build; ninja -C build install; }
auto()   { local p="$1"; shift; into "$p"; ./configure --prefix=/usr --sysconfdir=/etc --disable-static "$@"; make; make install; }

b_utilmacros() { auto util-macros- ; }
b_xorgproto()  { mesonb xorgproto- ; }
b_libXau()     { auto libXau- ; }
b_libXdmcp()   { auto libXdmcp- ; }
b_xcbproto()   { into xcb-proto-; ./configure --prefix=/usr; make; make install; }
b_pthrstubs()  { auto libpthread-stubs- ; }
b_libxcb()     { auto libxcb- --without-doxygen; }
b_xtrans()     { auto xtrans- ; }
b_libX11()     { auto libX11- ; }
b_libXrender() { auto libXrender- ; }
b_libXfixes()  { auto libXfixes- ; }
b_libXcursor() { auto libXcursor- ; }
# keymap data (/usr/share/X11/xkb) — xkbcommon/Hyprland crash without it
b_xkbconfig()  { into xkeyboard-config-; rm -rf build; meson setup build --prefix=/usr --libdir=lib --buildtype=release; ninja -C build; ninja -C build install; }

msg "desktop Phase 5: minimal X11 chain for libXcursor"
step x_util-macros  b_utilmacros
step x_xorgproto    b_xorgproto
step x_libXau       b_libXau
step x_libXdmcp     b_libXdmcp
step x_xcb-proto    b_xcbproto
step x_pthread-stubs b_pthrstubs
step x_libxcb       b_libxcb
step x_xtrans       b_xtrans
step x_libX11       b_libX11
step x_libXrender   b_libXrender
step x_libXfixes    b_libXfixes
step x_libXcursor   b_libXcursor
step x_xkeyboard-config b_xkbconfig
msg "desktop Phase 5 done — xcursor present. Resume Hyprland (Phase 4)."

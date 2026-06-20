#!/usr/bin/env bash
# Desktop layer, Phase 1 — foundation for Hyprland/Wayland. Build tooling (cmake,
# glib) + wayland core + low-level render libs. All deps satisfied by the base
# system. Runs inside the chroot; resumable. Later phases: graphics (LLVM/Mesa),
# input/session (libinput/seatd), hypr stack.
set -uo pipefail
set +h
export LFS=/ KRYPTOS_ROOT=/root/kryptos
source /root/kryptos/lib/build.sh

# meson/ninja helper (most modern desktop libs use it)
mesonb() { local p="$1"; shift; into "$p"; rm -rf build; \
    meson setup build --prefix=/usr --buildtype=release "$@"; \
    ninja -C build; ninja -C build install; }

b_cmake() {
    into cmake-3
    ./bootstrap --prefix=/usr --parallel=$(nproc)
    make
    make install
}
b_pcre2()  { into pcre2-; ./configure --prefix=/usr --enable-unicode --enable-jit \
    --enable-pcre2-16 --enable-pcre2-32 --disable-static; make; make install; }
b_glib()   { mesonb glib-2 -Dintrospection=disabled -Dman-pages=disabled -Dtests=false -Dsysprof=disabled; }
b_pixman() { mesonb pixman- -Dtests=disabled; }

b_wayland()   { mesonb wayland-1 -Ddocumentation=false -Dtests=false; }
b_wlproto()   { mesonb wayland-protocols- -Dtests=false; }
b_xkbcommon() { mesonb libxkbcommon- -Denable-docs=false -Denable-x11=false -Denable-wayland=true -Denable-xkbregistry=true; }
b_libdrm()    { mesonb libdrm- -Dudev=true -Dvalgrind=disabled; }
b_hwdata()    { into hwdata-; ./configure --prefix=/usr --disable-blacklist; make; make install; }
b_displayinfo(){ mesonb libdisplay-info- ; }

# freetype <-> harfbuzz: build freetype WITHOUT harfbuzz first, then fontconfig,
# then harfbuzz; (optionally rebuild freetype with harfbuzz later for full shaping)
b_freetype() {
    into freetype-
    ./configure --prefix=/usr --enable-freetype-config --disable-static --without-harfbuzz
    make; make install
}
b_fontconfig() {
    into fontconfig-
    ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-docs --docdir=/usr/share/doc/fontconfig
    make; make install
}
b_harfbuzz() { mesonb harfbuzz- -Dgraphite2=disabled -Dtests=disabled -Ddocs=disabled -Dintrospection=disabled; }

msg "desktop Phase 1: foundation (tooling + wayland + render libs)"
step d_cmake        b_cmake
step d_pcre2        b_pcre2
step d_glib         b_glib
step d_pixman       b_pixman
step d_wayland      b_wayland
step d_wayland-protocols b_wlproto
step d_libdrm       b_libdrm
step d_hwdata       b_hwdata
step d_libdisplay-info b_displayinfo
step d_libxkbcommon b_xkbcommon
step d_freetype     b_freetype
step d_fontconfig   b_fontconfig
step d_harfbuzz     b_harfbuzz
msg "desktop Phase 1 done — next: graphics (LLVM/Mesa), input/session, hypr stack."

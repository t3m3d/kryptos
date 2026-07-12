#!/usr/bin/env bash
# Desktop layer, Phase 1 — foundation for Hyprland/Wayland. Build tooling (cmake,
# glib) + wayland core + low-level render libs. All deps satisfied by the base
# system. Runs inside the chroot; resumable. Later phases: graphics (LLVM/Mesa),
# input/session (libinput/seatd), hypr stack.
set -uo pipefail
set +h
export LFS=/ KRYPTOS_ROOT=/root/kryptos
source /root/kryptos/lib/build.sh

# meson/ninja helper. Force --libdir=lib: meson auto-detects lib64 on this
# aarch64 base, but pkg-config only searches /usr/lib/pkgconfig → every meson
# lib (+ its .pc) would be invisible. Pin to /usr/lib for the whole stack.
mesonb() { local p="$1"; shift; into "$p"; rm -rf build; \
    meson setup build --prefix=/usr --libdir=lib --buildtype=release "$@"; \
    ninja -C build; ninja -C build install; }

b_cmake() {
    into cmake-3
    local src="$PWD" boot=/tmp/cmake-bootstrap
    rm -rf "$boot" "$src/build"
    mkdir -p "$boot"
    tar -C "$boot" --strip-components=1 \
        -xf "$(find_src bootstrap-cmake-3.30.5-linux-)"

    # Bootstrap binary only configures the source build. The installed CMake
    # is built here by the target compiler and remains source-built.
    "$boot/bin/cmake" -S "$src" -B "$src/build" -G "Unix Makefiles" \
        -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_USE_OPENSSL=OFF
    "$boot/bin/cmake" --build "$src/build" --parallel "$(nproc)"
    "$boot/bin/cmake" --install "$src/build"

    # Catch the target iostream failure that made bootstrap file(STRINGS)
    # spin forever instead of incorrectly marking CMake complete.
    printf '%s\n' 'file(STRINGS "/etc/os-release" _out)' \
        > /tmp/cmake-strings-smoke.cmake
    timeout 5 /usr/bin/cmake -P /tmp/cmake-strings-smoke.cmake
    /usr/bin/cmake --version
}
b_pcre2()  { into pcre2-; ./configure --prefix=/usr --enable-unicode --enable-jit \
    --enable-pcre2-16 --enable-pcre2-32 --disable-static; make; make install; }
b_glib()   { mesonb glib-2 -Dintrospection=disabled -Dman-pages=disabled -Dtests=false -Dsysprof=disabled; }
b_pixman() { mesonb pixman- -Dtests=disabled; }

b_wayland()   { mesonb wayland-1 -Ddocumentation=false -Dtests=false -Ddtd_validation=false; }
b_wlproto()   { mesonb wayland-protocols- -Dtests=false; }
# xkbregistry pulls libxml2 + is only layout enumeration (Hyprland doesn't need it)
b_xkbcommon() { mesonb libxkbcommon- -Denable-docs=false -Denable-x11=false -Denable-wayland=true -Denable-xkbregistry=false; }
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

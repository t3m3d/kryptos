#!/usr/bin/env bash
# Desktop layer, Phase 4 — the Hyprland stack.
#   Rust (prebuilt, for librsvg) -> librsvg -> pugixml/tomlplusplus ->
#   hyprwayland-scanner -> hyprutils -> hyprlang -> hyprcursor -> hyprgraphics ->
#   aquamarine -> Hyprland.
# Runs inside the chroot; resumable. NO_XWAYLAND=true keeps the X11/xcb deps out.
set -uo pipefail
set +h
export LFS=/ KRYPTOS_ROOT=/root/kryptos
source /root/kryptos/lib/build.sh

mesonb() { local p="$1"; shift; into "$p"; rm -rf build; \
    meson setup build --prefix=/usr --libdir=lib --buildtype=release "$@"; \
    ninja -C build; ninja -C build install; }
cmkb() { local p="$1"; shift; into "$p"; rm -rf build; \
    cmake -S . -B build -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_BUILD_TYPE=Release "$@"; \
    cmake --build build; cmake --install build; }

# --- prebuilt Rust (for librsvg's Cargo build; tarball vendors its crates) ---
b_rust() {
    into rust-1.83
    ./install.sh --prefix=/usr --disable-ldconfig \
        --components=rustc,cargo,rust-std-aarch64-unknown-linux-gnu
    rustc --version; cargo --version
}
# librsvg deps
b_libxml2()   { into libxml2-2; ./configure --prefix=/usr --disable-static --with-history --without-python; make; make install; }
b_gdkpixbuf() { mesonb gdk-pixbuf- -Dintrospection=disabled -Dman=false -Dtests=false -Dinstalled_tests=false -Dgtk_doc=false; }

# librsvg 2.58+ needs cargo-c (needs crates.io → no offline). 2.54 is the last
# autotools release: plain cargo + vendored crates = offline-buildable.
b_librsvg() {
    into librsvg-2.54
    ./configure --prefix=/usr --disable-static --disable-introspection \
        --disable-pixbuf-loader --disable-vala --disable-gtk-doc
    make
    make install
}

# --- small libs the hypr stack needs ---
b_pugixml()      { cmkb pugixml- -DBUILD_SHARED_LIBS=ON; }
b_tomlplusplus() {
    cmkb tomlplusplus- -DBUILD_TESTING=OFF
    # header-only: provide a pkgconfig file (hypr* use pkg_check_modules)
    cat > /usr/lib/pkgconfig/tomlplusplus.pc <<EOF
prefix=/usr
Name: tomlplusplus
Description: header-only TOML++ library
Version: 3.4.0
Cflags: -I\${prefix}/include
EOF
}
b_libzip()  { cmkb libzip- -DBUILD_TOOLS=OFF -DBUILD_EXAMPLES=OFF -DBUILD_DOC=OFF -DBUILD_REGRESS=OFF; }
b_libspng() { cmkb libspng- -DBUILD_SHARED_LIBS=ON -DSPNG_STATIC=OFF; }

# --- hypr libraries (order matters) ---
b_hyprwlscan() { cmkb hyprwayland-scanner- ; }
b_hyprutils()  { cmkb hyprutils- ; }
b_hyprlang()   { cmkb hyprlang- ; }
b_hyprcursor() { cmkb hyprcursor- ; }
b_hyprgraphics(){ cmkb hyprgraphics- ; }
# Mesa is Wayland-only (no glx/glvnd → no legacy libGL); aquamarine renders via
# EGL+GLES, so drop the unneeded OpenGL::OpenGL (libGL) link.
b_aquamarine() {
    into aquamarine-
    sed -i 's/OpenGL::EGL OpenGL::OpenGL/OpenGL::EGL/' CMakeLists.txt
    cmake -S . -B build -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_BUILD_TYPE=Release
    cmake --build build; cmake --install build
}

# --- Hyprland ---
b_hyprlandproto() { mesonb hyprland-protocols- ; }
b_hyprland() {
    into Hyprland-
    # Mesa is Wayland-only (no legacy libGL) → drop OpenGL::GL, keep EGL.
    sed -i 's/OpenGL::EGL OpenGL::GL/OpenGL::EGL/' CMakeLists.txt
    cmake -S . -B build -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release \
        -DNO_XWAYLAND=true -DNO_SYSTEMD=true
    cmake --build build
    cmake --install build
}

msg "desktop Phase 4: Hyprland stack"
step d_rust          b_rust
step d_pugixml       b_pugixml
step d_tomlplusplus  b_tomlplusplus
step d_libzip        b_libzip
step d_libspng       b_libspng
step d_libxml2       b_libxml2
step d_gdk-pixbuf    b_gdkpixbuf
step d_librsvg       b_librsvg
step d_hyprwl-scanner b_hyprwlscan
step d_hyprutils     b_hyprutils
step d_hyprlang      b_hyprlang
step d_hyprcursor    b_hyprcursor
step d_hyprgraphics  b_hyprgraphics
step d_aquamarine    b_aquamarine
step d_hyprland-protocols b_hyprlandproto
step d_hyprland      b_hyprland
msg "desktop Phase 4 done — Hyprland installed. Next: session autostart + image + boot."

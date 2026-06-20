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
b_librsvg() {
    mesonb librsvg- -Ddocs=disabled -Dintrospection=disabled -Dvala=disabled \
        -Dpixbuf=disabled -Dpixbuf-loader=disabled -Dtests=false
}

# --- small libs the hypr stack needs ---
b_pugixml()      { cmkb pugixml- -DBUILD_SHARED_LIBS=ON; }
b_tomlplusplus() { cmkb tomlplusplus- -DBUILD_TESTING=OFF; }

# --- hypr libraries (order matters) ---
b_hyprwlscan() { cmkb hyprwayland-scanner- ; }
b_hyprutils()  { cmkb hyprutils- ; }
b_hyprlang()   { cmkb hyprlang- ; }
b_hyprcursor() { cmkb hyprcursor- ; }
b_hyprgraphics(){ cmkb hyprgraphics- ; }
b_aquamarine() { cmkb aquamarine- ; }

# --- Hyprland ---
b_hyprland() {
    into Hyprland-
    make all PREFIX=/usr 2>/dev/null || {
        cmake -S . -B build -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release \
            -DNO_XWAYLAND=true
        cmake --build build
        cmake --install build
    }
}

msg "desktop Phase 4: Hyprland stack"
step d_rust          b_rust
step d_pugixml       b_pugixml
step d_tomlplusplus  b_tomlplusplus
step d_librsvg       b_librsvg
step d_hyprwl-scanner b_hyprwlscan
step d_hyprutils     b_hyprutils
step d_hyprlang      b_hyprlang
step d_hyprcursor    b_hyprcursor
step d_hyprgraphics  b_hyprgraphics
step d_aquamarine    b_aquamarine
step d_hyprland      b_hyprland
msg "desktop Phase 4 done — Hyprland installed. Next: session autostart + image + boot."

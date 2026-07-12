#!/usr/bin/env bash
# Qt 6 + Quickshell shell layer for KryptOS. Run after Mesa and the Hyprland
# stack. Features without their system services stay off for this first image.
set -uo pipefail
set +h
export LFS=/ KRYPTOS_ROOT=/root/kryptos
source /root/kryptos/lib/build.sh

cmakeb() {
    local p="$1"; shift
    into "$p"
    rm -rf build
    cmake -S . -B build -G Ninja \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_BUILD_TYPE=Release \
        "$@"
    ninja -C build
    ninja -C build install
}

b_wayland_protocols_148() {
    into wayland-protocols-1.48
    rm -rf build
    meson setup build --prefix=/usr --libdir=lib -Dtests=false
    ninja -C build
    ninja -C build install
}

b_cli11() {
    cmakeb CLI11- \
        -DCLI11_BUILD_DOCS=OFF \
        -DCLI11_BUILD_EXAMPLES=OFF \
        -DCLI11_BUILD_TESTS=OFF
}

b_qtbase() {
    cmakeb qtbase-everywhere-src- \
        -DQT_BUILD_EXAMPLES=OFF \
        -DQT_BUILD_TESTS=OFF \
        -DFEATURE_cups=OFF \
        -DFEATURE_dbus=OFF \
        -DFEATURE_gtk3=OFF \
        -DFEATURE_xcb=OFF \
        -DINPUT_opengl=es2
}

b_qtshadertools() {
    cmakeb qtshadertools-everywhere-src- \
        -DQT_BUILD_EXAMPLES=OFF \
        -DQT_BUILD_TESTS=OFF
}

b_qtdeclarative() {
    cmakeb qtdeclarative-everywhere-src- \
        -DQT_BUILD_EXAMPLES=OFF \
        -DQT_BUILD_TESTS=OFF
}

b_qtwayland() {
    cmakeb qtwayland-everywhere-src- \
        -DQT_BUILD_EXAMPLES=OFF \
        -DQT_BUILD_TESTS=OFF
}

b_qtsvg() {
    cmakeb qtsvg-everywhere-src- \
        -DQT_BUILD_EXAMPLES=OFF \
        -DQT_BUILD_TESTS=OFF
}

b_quickshell() {
    cmakeb quickshell- \
        -DBUILD_TESTING=OFF \
        -DCRASH_HANDLER=OFF \
        -DUSE_JEMALLOC=OFF \
        -DSOCKETS=ON \
        -DWAYLAND=ON \
        -DWAYLAND_WLR_LAYERSHELL=ON \
        -DWAYLAND_SESSION_LOCK=ON \
        -DWAYLAND_TOPLEVEL_MANAGEMENT=ON \
        -DHYPRLAND=ON \
        -DSCREENCOPY=OFF \
        -DX11=OFF \
        -DI3=OFF \
        -DSERVICE_STATUS_NOTIFIER=OFF \
        -DSERVICE_PIPEWIRE=OFF \
        -DSERVICE_MPRIS=OFF \
        -DSERVICE_PAM=OFF \
        -DSERVICE_POLKIT=OFF \
        -DSERVICE_GREETD=OFF \
        -DSERVICE_UPOWER=OFF \
        -DSERVICE_NOTIFICATIONS=OFF \
        -DBLUETOOTH=OFF \
        -DNETWORK=OFF \
        -DDISTRIBUTOR=KryptOS \
        -DINSTALL_QML_PREFIX=lib/qt6/qml
}

b_shell_config() {
    install -d /etc/xdg/quickshell/kryptos
    install -m644 /root/kryptos/config/quickshell/kryptos/shell.qml \
        /etc/xdg/quickshell/kryptos/shell.qml
}

b_quickshell_smoke() {
    pkg-config --atleast-version=1.48 wayland-protocols
    test -x /usr/bin/quickshell
    test -x /usr/bin/qs
    test -r /etc/xdg/quickshell/kryptos/shell.qml
    if ldd /usr/bin/quickshell | grep -F 'not found'; then
        echo "Quickshell has unresolved shared libraries" >&2
        return 1
    fi
    /usr/bin/qs --version
}

msg "Quickshell: protocols 1.48, Qt 6.7.3, shell runtime"
step q_wayland_protocols b_wayland_protocols_148
step q_cli11            b_cli11
step q_qtbase           b_qtbase
step q_qtshadertools    b_qtshadertools
step q_qtdeclarative    b_qtdeclarative
step q_qtwayland        b_qtwayland
step q_qtsvg            b_qtsvg
step q_quickshell       b_quickshell
step q_shell_config     b_shell_config
step q_smoke            b_quickshell_smoke
msg "Quickshell done - KryptOS bar and launcher ready."

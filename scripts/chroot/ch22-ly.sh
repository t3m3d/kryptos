#!/usr/bin/env bash
# Display-manager layer — Linux-PAM, the Zig toolchain, and ly.
#   pam: ly authenticates through PAM and this LFS tree has none at all.
#   zig: stable 0.17.x (ly refuses -dev builds) and the toolchain that builds ly.
#   ly:  TUI login manager on tty1; sessions come from wayland-sessions.
# Runs inside the chroot; resumable. Must run after ch12-session.sh so its
# autologin line on tty1 is still there to replace.
set -uo pipefail
set +h
export LFS=/ KRYPTOS_ROOT=/root/kryptos
source /root/kryptos/lib/build.sh

ZIG_VERSION=0.17.1
ZIG_SHA256=3581863e3cbcfd0fce0efc682ce7e9e93da96668a977791d356a26d2a7e9b17a

b_pam() {
    into Linux-PAM-
    ./configure --prefix=/usr --libdir=/usr/lib --sysconfdir=/etc \
        --disable-audit --disable-doc --disable-examples --disable-prelude \
        --disable-lckpwdf --disable-pie
    make -j"$(nproc)"
    make install
    test -e /usr/lib/security/pam_unix.so

    # ly ships a stack of "include login", but LFS never installs a login
    # service file, so give ly its own explicit pam_unix stack.
    install -d /etc/pam.d
    cat > /etc/pam.d/ly <<'EOF'
auth      required  pam_unix.so
account   required  pam_unix.so
password  required  pam_unix.so
session   required  pam_unix.so
EOF
    cp -f /etc/pam.d/ly /etc/pam.d/other
}

b_zig() {
    local src
    src=$(find_src zig-x86_64-linux-)
    echo "$ZIG_SHA256  $src" | sha256sum -c -
    into zig-x86_64-linux-
    install -d /opt
    rm -rf "/opt/zig-$ZIG_VERSION"
    cp -a . "/opt/zig-$ZIG_VERSION"
    ln -sfn "/opt/zig-$ZIG_VERSION/zig" /usr/bin/zig
    /usr/bin/zig version
}

b_ly() {
    into ly-
    # zig fetches its two dependencies on first build; keep the caches out of
    # the source tree and reachable for the next step.
    export ZIG_GLOBAL_CACHE_DIR=/tmp/zig-global ZIG_LOCAL_CACHE_DIR=/tmp/zig-local
    mkdir -p "$ZIG_GLOBAL_CACHE_DIR" "$ZIG_LOCAL_CACHE_DIR"

    # zig fetches ly's two dependencies on first build; the chroot has no
    # resolver by default and trusts nothing without the devtools CA roots.
    [ -s /etc/resolv.conf ] || printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > /etc/resolv.conf
    test -s /etc/ssl/certs/ca-certificates.crt

    local opts=(-Doptimize=ReleaseSafe -Dinit_system=sysvinit
                -Denable_x11_support=false -Ddefault_tty=1 -Dfallback_tty=1)
    zig build "${opts[@]}"
    zig build installexe "${opts[@]}"
    test -x /usr/bin/ly

    # Session entry for the wayland-sessions directory ly scans.
    install -d /usr/share/wayland-sessions
    cat > /usr/share/wayland-sessions/kryptos-hyprland.desktop <<'EOF'
[Desktop Entry]
Name=KryptOS Hyprland
Comment=Hyprland with Quickshell
Exec=/usr/local/bin/start-hypr
Type=Application
EOF

    # tty1 now belongs to ly; tty2/tty3 and the serial getty stay for rescue.
    sed -i 's#^1:2345:respawn:/sbin/agetty .*#1:2345:respawn:/usr/bin/ly#' /etc/inittab
    grep -q '^1:2345:respawn:/usr/bin/ly' /etc/inittab
    grep -q '^s0:2345:respawn' /etc/inittab
}

step d_pam b_pam
step d_zig b_zig
step d_ly  b_ly

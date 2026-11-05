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

    # Session entry for the wayland-sessions directory ly scans. Drop the
    # generic upstream entry so ly shows a single KryptOS session.
    install -d /usr/share/wayland-sessions
    rm -f /usr/share/wayland-sessions/hyprland.desktop
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

# init opens /dev/tty1 for a respawn entry but does not hand the child a
# controlling terminal, so ly's termbox2 init fails on /dev/tty and it dies
# into a respawn loop. setsid -c makes tty1 the controlling terminal again.
b_ly_console() {
    test -x /usr/bin/setsid

    # ly's installexe overwrites /etc/pam.d/ly with its stock stack, which
    # includes `login` and pam_systemd. LFS ships neither, so every login fails
    # with PamPermissionDenied. Rewrite the stack after the install.
    install -d /etc/pam.d
    cat > /etc/pam.d/ly <<'EOF'
auth      required  pam_unix.so
account   required  pam_unix.so
password  required  pam_unix.so
session   required  pam_unix.so
EOF
    cp -f /etc/pam.d/ly /etc/pam.d/other
    grep -q '^auth.*pam_unix.so' /etc/pam.d/ly

    cat > /usr/local/sbin/kryptos-ly <<'EOF'
#!/bin/sh
exec setsid -c /usr/bin/ly </dev/tty1 >/dev/tty1 2>&1
EOF
    chmod 0755 /usr/local/sbin/kryptos-ly

    sed -i 's#^1:2345:respawn:.*#1:2345:respawn:/usr/local/sbin/kryptos-ly#' /etc/inittab
    grep -q '^1:2345:respawn:/usr/local/sbin/kryptos-ly' /etc/inittab

    # type_username=false turns the login field into a user picker that starts
    # on the first account (kryptos, which has no password). KryptOS boots into
    # root, so let people type the name instead of cycling a list.
    sed -i 's/^type_username = .*/type_username = true/' /etc/ly/config.ini
    grep -q '^type_username = true' /etc/ly/config.ini

    # Upstream's generic entry duplicates the KryptOS session in ly's list.
    rm -f /usr/share/wayland-sessions/hyprland.desktop
}

step d_pam b_pam
step d_zig b_zig
step d_ly  b_ly
step d_ly_console b_ly_console

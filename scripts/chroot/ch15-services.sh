#!/usr/bin/env bash
# System services the desktop assumes are present:
#   procps  — ps/pgrep/pgrep -a; the guest currently cannot inspect processes
#   dbus    — the system bus plus its tools. Hyprland calls
#             dbus-update-activation-environment at startup and portals or
#             notification daemons need a bus to own a name on.
# Sources are already in /sources (procps-ng-4.0.4, dbus-1.14.10); expat is
# built, so dbus does not need extra deps. Runs inside the chroot; resumable.
set -uo pipefail
set +h
export LFS=/ KRYPTOS_ROOT=/root/kryptos
source /root/kryptos/lib/build.sh

b_procps() {
    into procps-ng-4.0.4
    # --disable-kill: util-linux already provides kill(1).
    # Do NOT pass --enable-watch8bit: it forces ncursesw, and this tree only
    # ships the narrow ncurses headers (libncursesw exists, ncursesw/ does not),
    # so watch.c fails on <ncursesw/ncurses.h>. The default is off.
    ./configure --prefix=/usr --docdir=/usr/share/doc/procps-ng-4.0.4 \
        --disable-static --disable-kill
    make
    make install
    ps --version | head -1
}

b_dbus() {
    # The system bus runs as an unprivileged user, as upstream intends.
    getent group messagebus >/dev/null || groupadd -g 18 messagebus
    id messagebus >/dev/null 2>&1 || useradd -c 'D-Bus Message Daemon User' \
        -d /run/dbus -u 18 -g messagebus -s /bin/false messagebus
    into dbus-1.14.10
    ./configure --prefix=/usr --libdir=/usr/lib --sysconfdir=/etc \
        --localstatedir=/var \
        --with-system-socket=/run/dbus/system_bus_socket \
        --disable-doxygen-docs --disable-xml-docs \
        --docdir=/usr/share/doc/dbus-1.14.10
    make
    make install
    install -d -m755 -o messagebus -g messagebus /run/dbus
    install -d -m755 /var/lib/dbus
    # A machine-id is required before the system bus will start. The live
    # root is a freshly unpacked tmpfs each boot, so the init script also
    # regenerates this when the baked file is absent.
    dbus-uuidgen --ensure
    install -m644 /var/lib/dbus/machine-id /etc/machine-id
    /usr/bin/dbus-daemon --version | head -1
    command -v dbus-update-activation-environment >/dev/null || \
        die "dbus tools missing: dbus-update-activation-environment not installed"
}

b_dbus_service() {
    install -m755 /root/kryptos/config/kryptos-dbus /etc/rc.d/init.d/dbus
    # Start with the rest of the runlevel services, before networking, so
    # anything that activates on a name finds a bus already listening.
    for level in 2 3 4 5; do
        install -d "/etc/rc.d/rc$level.d"
        ln -sf ../init.d/dbus "/etc/rc.d/rc$level.d/S20dbus"
    done
    for level in 0 1 6; do
        install -d "/etc/rc.d/rc$level.d"
        ln -sf ../init.d/dbus "/etc/rc.d/rc$level.d/K80dbus"
    done
    # Never start a daemon inside the build chroot.
}

msg "system services: procps + dbus"
step s_procps b_procps
step s_dbus b_dbus
step s_dbus_service b_dbus_service
msg "services installed; verify ps/pgrep and the system bus after boot."

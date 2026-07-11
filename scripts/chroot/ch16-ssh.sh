#!/usr/bin/env bash
# Stage 8 addendum - lightweight SSH server for early live ISO access.
# Installs Dropbear and a manual SysV service. It does not auto-start.
set -uo pipefail
set +h
export LFS=/ KRYPTOS_ROOT=/root/kryptos
source /root/kryptos/lib/build.sh

b_dropbear() {
    into dropbear-
    ./configure --prefix=/usr --sysconfdir=/etc --disable-lastlog || return
    make PROGRAMS="dropbear dbclient dropbearkey dropbearconvert scp" || return
    make PROGRAMS="dropbear dbclient dropbearkey dropbearconvert scp" install || return
    install -dv /etc/dropbear || return
    cat > /etc/rc.d/init.d/dropbear <<'EOF'
#!/bin/sh
########################################################################
# Begin dropbear
#
# Description : Dropbear SSH server. Manual start only for early ISOs.
########################################################################

. /lib/lsb/init-functions

KEYDIR=/etc/dropbear
PIDFILE=/run/dropbear.pid
DROPBEAR=/usr/sbin/dropbear

make_keys() {
    mkdir -p "$KEYDIR"
    [ -f "$KEYDIR/dropbear_rsa_host_key" ] || /usr/bin/dropbearkey -t rsa -f "$KEYDIR/dropbear_rsa_host_key" >/dev/null 2>&1
    [ -f "$KEYDIR/dropbear_ecdsa_host_key" ] || /usr/bin/dropbearkey -t ecdsa -f "$KEYDIR/dropbear_ecdsa_host_key" >/dev/null 2>&1
    [ -f "$KEYDIR/dropbear_ed25519_host_key" ] || /usr/bin/dropbearkey -t ed25519 -f "$KEYDIR/dropbear_ed25519_host_key" >/dev/null 2>&1
}

case "$1" in
    start)
        log_info_msg "Starting Dropbear SSH server..."
        make_keys
        start_daemon -p "$PIDFILE" "$DROPBEAR" -R -E -p 22 -P "$PIDFILE"
        evaluate_retval
        ;;
    stop)
        log_info_msg "Stopping Dropbear SSH server..."
        killproc -p "$PIDFILE" "$DROPBEAR"
        evaluate_retval
        ;;
    restart)
        $0 stop
        sleep 1
        $0 start
        ;;
    status)
        statusproc "$DROPBEAR"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac

# End dropbear
EOF
    chmod 755 /etc/rc.d/init.d/dropbear || return
    rm -f /etc/rc.d/rc3.d/*dropbear /etc/rc.d/rc5.d/*dropbear 2>/dev/null || true
}

b_ssh_check() {
    command -v dropbear >/dev/null || { echo "missing dropbear"; exit 1; }
    command -v dbclient >/dev/null || { echo "missing dbclient"; exit 1; }
    command -v dropbearkey >/dev/null || { echo "missing dropbearkey"; exit 1; }
    /usr/sbin/dropbear -V
    [ ! -e /etc/rc.d/rc3.d/S30dropbear ] || { echo "dropbear must not auto-start"; exit 1; }
}

msg "SSH: Dropbear server + client (manual start)"
step dropbear b_dropbear
step ssh-check b_ssh_check
msg "SSH done - manual start: /etc/rc.d/init.d/dropbear start"

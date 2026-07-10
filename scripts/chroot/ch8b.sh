#!/usr/bin/env bash
# Stage 4 addendum — packages missed in the first ch8 pass that surfaced at first
# boot: e2fsprogs (fsck.ext4 / e2fsck) and sysklogd (system log daemon). Runs
# inside the chroot; resumable.
set -uo pipefail
set +h
export LFS=/ KRYPTOS_ROOT=/root/kryptos
source /root/kryptos/lib/build.sh

# --- e2fsprogs (provides fsck.ext4 / e2fsck / mke2fs) ---
b_e2fsprogs() {
    into e2fsprogs-
    mkdir -v build || return; cd build || return
    ../configure --prefix=/usr --sysconfdir=/etc --enable-elf-shlibs \
        --disable-libblkid --disable-libuuid --disable-uuidd --disable-fsck || return
    make || return
    make install || return
    rm -fv /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a 2>/dev/null || true
}

# --- sysklogd (syslogd; klogd merged in 2.x) ---
b_sysklogd() {
    into sysklogd-
    ./configure --prefix=/usr --sysconfdir=/etc --runstatedir=/run --without-logger || return
    make || return
    make install || return
    [ -f /etc/syslog.conf ] || cat > /etc/syslog.conf <<"EOF"
# /etc/syslog.conf — minimal KryptOS default
auth,authpriv.*         -/var/log/auth.log
*.*;auth,authpriv.none  -/var/log/sys.log
kern.*                  -/var/log/kern.log
*.emerg                 *
EOF
}

msg "ch8b: e2fsprogs + sysklogd (first-boot gaps)"
step e2fsprogs b_e2fsprogs
step sysklogd  b_sysklogd
msg "ch8b done — fsck.ext4 + syslogd present."

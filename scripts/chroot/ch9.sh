#!/usr/bin/env bash
# Stage 5 — LFS chapter 9 system configuration, KryptOS-branded. Runs inside the
# chroot. Bootscripts, hostname, network, inittab (with a serial getty for QEMU),
# clock, locale, /etc/os-release. No compiling — fast.
set -uo pipefail
set +h
export LFS=/ KRYPTOS_ROOT=/root/kryptos
source /root/kryptos/lib/build.sh

# --- 9.2 LFS-Bootscripts ---
b_bootscripts() { into lfs-bootscripts-; make install; }

# --- 9.x hostname + hosts ---
b_hostname() {
    echo "kryptos" > /etc/hostname
    cat > /etc/hosts <<"EOF"
127.0.0.1  localhost.localdomain localhost kryptos
::1        localhost ip6-localhost ip6-loopback
ff02::1    ip6-allnodes
ff02::2    ip6-allrouters
EOF
}

# --- 9.x network (DHCP installed by ch21-network.sh; lo handled by bootscripts) ---
b_network() {
    install -dv /etc/sysconfig
    # Do not bake QEMU's private subnet or public DNS into hardware images.
    # ch21-network.sh installs the DHCP client and migrates existing builds.
    bash /usr/lib/udev/init-net-rules.sh 2>/dev/null || true
}

# --- 9.x sysvinit inittab (+ serial getty for the QEMU console; arch-specific) ---
b_inittab() {
    # x86 serial console = ttyS0, arm64 = ttyAMA0
    case "$(uname -m)" in x86_64) STTY=ttyS0;; *) STTY=ttyAMA0;; esac
    install -d /usr/local/sbin
    cat > /usr/local/sbin/kryptos-serial-getty <<"EOF"
#!/bin/sh
device="${1:-ttyS0}"
while [ ! -c "/dev/$device" ]; do
    sleep 30
done
exec /sbin/agetty --keep-baud "$device" 115200,38400,9600 vt100
EOF
    chmod +x /usr/local/sbin/kryptos-serial-getty

    cat > /etc/inittab <<EOF
id:3:initdefault:

si::sysinit:/etc/rc.d/init.d/rc S

l0:0:wait:/etc/rc.d/init.d/rc 0
l1:S1:wait:/etc/rc.d/init.d/rc 1
l2:2:wait:/etc/rc.d/init.d/rc 2
l3:3:wait:/etc/rc.d/init.d/rc 3
l4:4:wait:/etc/rc.d/init.d/rc 4
l5:5:wait:/etc/rc.d/init.d/rc 5
l6:6:wait:/etc/rc.d/init.d/rc 6

ca:12345:ctrlaltdel:/sbin/shutdown -t1 -a -r now

su:S016:once:/sbin/sulogin

1:2345:respawn:/sbin/agetty --noclear tty1 9600
2:2345:respawn:/sbin/agetty tty2 9600
3:2345:respawn:/sbin/agetty tty3 9600
s0:2345:respawn:/usr/local/sbin/kryptos-serial-getty $STTY
EOF
}

# --- 9.x clock + console + locale ---
b_clock() {
    cat > /etc/sysconfig/clock <<"EOF"
UTC=1
CLOCKPARAMS=
EOF
}
b_console() {
    cat > /etc/sysconfig/console <<"EOF"
KEYMAP="us"
FONT="lat0-16 -m 8859-1"
EOF
}
b_profile() {
    cat > /etc/profile <<"EOF"
export LANG=en_US.UTF-8
export PATH=/usr/bin:/usr/sbin
export PS1='\u@\h:\w\$ '
umask 022
EOF
    cat > /etc/inputrc <<"EOF"
set horizontal-scroll-mode Off
set meta-flag On
set input-meta On
set convert-meta Off
set output-meta On
set bell-style none
"\eOd": backward-word
"\eOc": forward-word
"\e[1~": beginning-of-line
"\e[4~": end-of-line
"\e[5~": beginning-of-history
"\e[6~": end-of-history
"\e[3~": delete-char
"\e[2~": quoted-insert
"\eOH": beginning-of-line
"\eOF": end-of-line
"\e[H": beginning-of-line
"\e[F": end-of-line
EOF
    cat > /etc/shells <<"EOF"
/bin/sh
/bin/bash
EOF
}

# --- 9.x /etc/os-release + lsb-release — KryptOS branding ---
b_osrelease() {
    cat > /etc/os-release <<"EOF"
NAME="KryptOS"
PRETTY_NAME="KryptOS v0 (krypt- family)"
ID=kryptos
VERSION="0.1"
VERSION_ID="0.1"
BUILD_ID="lfs-12.2"
HOME_URL="https://krypton-lang.org/"
EOF
    cat > /etc/lsb-release <<"EOF"
DISTRIB_ID="KryptOS"
DISTRIB_RELEASE="0.1"
DISTRIB_CODENAME="genesis"
DISTRIB_DESCRIPTION="KryptOS v0"
EOF
    # a friendly login banner
    cat > /etc/issue <<"EOF"
KryptOS v0  \r  (\l)

EOF
}

# --- 10.2 /etc/fstab ---
b_fstab() {
    cat > /etc/fstab <<"EOF"
# file system  mount-point  type     options             dump  fsck
/dev/vda       /            ext4     defaults             1     1
proc           /proc        proc     nosuid,noexec,nodev  0     0
sysfs          /sys         sysfs    nosuid,noexec,nodev  0     0
devpts         /dev/pts     devpts   gid=5,mode=620       0     0
tmpfs          /run         tmpfs    defaults             0     0
devtmpfs       /dev         devtmpfs mode=0755,nosuid     0     0
tmpfs          /dev/shm     tmpfs    nosuid,nodev         0     0
cgroup2        /sys/fs/cgroup cgroup2 nosuid,noexec,nodev 0     0
EOF
}

msg "ch9 system configuration (KryptOS branding)"
step bootscripts b_bootscripts
step hostname    b_hostname
step network     b_network
step inittab     b_inittab
step clock       b_clock
step console     b_console
step profile     b_profile
step osrelease   b_osrelease
step fstab       b_fstab
msg "ch9 done — system configured as KryptOS. Next: ch10 kernel + boot."

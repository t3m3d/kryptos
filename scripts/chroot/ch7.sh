#!/usr/bin/env bash
# Runs INSIDE the chroot. LFS 7.5 (dirs) + 7.6 (essential files) + ch7 temp tools
# (gettext, bison, perl, Python, texinfo, util-linux). Native builds → install to /.
set -uo pipefail
set +h
export LFS=/ KRYPTOS_ROOT=/root/kryptos
source /root/kryptos/lib/build.sh

pkgver() { basename "$(find_src "$1")" | sed -E "s/^$1([0-9.]+)\.(tar|src).*/\1/"; }

# --- 7.5 Creating directories ---
mkdir -pv /{boot,home,mnt,opt,srv}
mkdir -pv /etc/{opt,sysconfig}
mkdir -pv /lib/firmware
mkdir -pv /media/{floppy,cdrom}
mkdir -pv /usr/{,local/}{include,src}
mkdir -pv /usr/lib/locale
mkdir -pv /usr/local/{bin,lib,sbin}
mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man}
mkdir -pv /usr/{,local/}share/{misc,terminfo,zoneinfo}
mkdir -pv /usr/{,local/}share/man/man{1..8}
mkdir -pv /var/{cache,local,log,mail,opt,spool}
mkdir -pv /var/lib/{color,misc,locate}
ln -sfnvT /run /var/run
ln -sfnvT /run/lock /var/lock
install -dv -m 0750 /root
install -dv -m 1777 /tmp /var/tmp

# --- 7.6 Essential files ---
[ -e /etc/mtab ] || ln -sv /proc/self/mounts /etc/mtab
[ -f /etc/hosts ] || echo "127.0.0.1  localhost kryptos" > /etc/hosts
if [ ! -f /etc/passwd ]; then cat > /etc/passwd <<"EOF"
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/usr/bin/false
daemon:x:6:6:Daemon User:/dev/null:/usr/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/run/dbus:/usr/bin/false
uuidd:x:80:80:UUID Generation Daemon User:/dev/null:/usr/bin/false
nobody:x:65534:65534:Unprivileged User:/dev/null:/usr/bin/false
EOF
fi
if [ ! -f /etc/group ]; then cat > /etc/group <<"EOF"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
input:x:24:
mail:x:34:
kvm:x:61:
uuidd:x:80:
wheel:x:97:
users:x:999:
nogroup:x:65534:
EOF
fi
if ! grep -q '^tester:' /etc/passwd; then
    echo "tester:x:101:101::/home/tester:/bin/bash" >> /etc/passwd
    echo "tester:x:101:" >> /etc/group
    install -o tester -d /home/tester
fi
touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp -v utmp /var/log/lastlog
chmod -v 664 /var/log/lastlog
chmod -v 600 /var/log/btmp

# --- ch7 temporary tools ---
b_gettext() { into gettext-; ./configure --disable-shared; make; cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin; }
b_bison()   { into bison-; ./configure --prefix=/usr --docdir=/usr/share/doc/bison-$(pkgver bison-); make; make install; }
b_perl()    {
    into perl-
    local v; v=$(pkgver perl- | grep -oE '^[0-9]+\.[0-9]+')
    sh Configure -des \
        -Dprefix=/usr -Dvendorprefix=/usr -Duseshrplib \
        -Dprivlib=/usr/lib/perl5/$v/core_perl -Darchlib=/usr/lib/perl5/$v/core_perl \
        -Dsitelib=/usr/lib/perl5/$v/site_perl -Dsitearch=/usr/lib/perl5/$v/site_perl \
        -Dvendorlib=/usr/lib/perl5/$v/vendor_perl -Dvendorarch=/usr/lib/perl5/$v/vendor_perl
    make; make install
}
b_python()  { into Python-; ./configure --prefix=/usr --enable-shared --without-ensurepip; make; make install; }
b_texinfo() { into texinfo-; ./configure --prefix=/usr; make; make install; }
b_utillinux() {
    into util-linux-
    mkdir -pv /var/lib/hwclock
    ./configure --libdir=/usr/lib --runstatedir=/run --disable-chfn-chsh --disable-login \
        --disable-nologin --disable-su --disable-setpriv --disable-runuser --disable-pylibmount \
        --disable-static --disable-liblastlog2 --without-python ADJTIME_PATH=/var/adjtime \
        --docdir=/usr/share/doc/util-linux-$(pkgver util-linux-)
    make; make install
}

# A couple of locales must exist before perl, or perl's Configure can't probe
# glibc's LC_ALL format and miscompiles locale.c (PERL_LC_ALL_CATEGORY_POSITIONS_
# INIT undeclared). With locales present it detects name=value pairs correctly.
# This is an arm/minimal-chroot deviation from the x86 LFS book.
b_locales() {
    mkdir -pv /usr/lib/locale
    localedef -i C       -f UTF-8 C.UTF-8     || true
    localedef -i en_US   -f UTF-8 en_US.UTF-8
    localedef -i de_DE   -f UTF-8 de_DE.UTF-8
}

msg "ch7 temp tools (inside chroot)"
step gettext  b_gettext
step bison    b_bison
step locales  b_locales
step perl     b_perl
step python   b_python
step texinfo  b_texinfo
step util-linux b_utillinux
msg "ch7 done — next: ch8 final system."

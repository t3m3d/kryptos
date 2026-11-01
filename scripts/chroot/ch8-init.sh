#!/usr/bin/env bash
# Stage 4 — ch8 "final system", init tail: util-linux (final), udev-from-systemd
# (LFS sysvinit method), sysvinit. Split out because these are the fiddliest
# packages in the chapter. Runs inside the chroot; resumable via step markers.
# Run after ch8.sh reports "part 1 done".
set -uo pipefail
set +h
export LFS=/ KRYPTOS_ROOT=/root/kryptos
source /root/kryptos/lib/build.sh

# --- 8.x util-linux (final) ---
b_utillinux() {
    into util-linux-
    mkdir -pv /var/lib/hwclock
    ./configure --bindir=/usr/bin --libdir=/usr/lib --runstatedir=/run --sbindir=/usr/sbin \
        --disable-chfn-chsh --disable-login --disable-nologin --disable-su --disable-setpriv \
        --disable-runuser --disable-pylibmount --disable-liblastlog2 --disable-static \
        --without-python --without-systemd --without-systemdsystemunitdir \
        ADJTIME_PATH=/var/lib/hwclock/adjtime \
        --docdir=/usr/share/doc/util-linux-2.40.2
    make || return
    make install || return
}

# --- 8.x udev (built from the systemd source, sysvinit method) ---
b_udev() {
    into systemd-
    sed -i -e 's/GROUP="render"/GROUP="video"/' -e 's/GROUP="sgx", //' rules.d/50-udev-default.rules.in
    sed '/systemd-sysctl/s/^/#/' -i rules.d/99-systemd.rules.in
    sed '/NETWORK_DIRS/s/systemd/udev/' -i src/basic/path-lookup.h

    rm -rf build
    mkdir -p build; cd build
    meson setup .. --prefix=/usr --buildtype=release -D mode=release \
        -D dev-kvm-mode=0660 -D link-udev-shared=false -D logind=false -D vconsole=false

    python3 - <<'PY'
from pathlib import Path
p = Path('../src/shared/ethtool-link-mode.py')
s = p.read_text()
s = s.replace(
    'subprocess.check_output(command, stdin=subprocess.DEVNULL, universal_newlines=True)',
    "subprocess.check_output(command, stdin=subprocess.DEVNULL, universal_newlines=True, errors='replace')",
)
p.write_text(s)
PY

    export udev_helpers=$(grep "'name' :" ../src/udev/meson.build | awk '{print $3}' | tr -d ",'" | grep -v 'udevadm')

    local ninja_cmd=(ninja -v)
    if [ -x /opt/host-ninja/ninja ]; then
        ninja_cmd=(env LD_LIBRARY_PATH=/opt/host-ninja/lib /opt/host-ninja/ninja -v)
    fi
    # systemd 256 generates these metadata files as explicit Ninja targets,
    # rather than during Meson setup. The library targets do not pull them in.
    "${ninja_cmd[@]}" udevadm systemd-hwdb \
        src/libudev/libudev.pc src/udev/udev.pc \
        $(grep -o -E '^build (rules.d|hwdb.d)/[^:]*' build.ninja | awk '{ print $2 }') \
        $(realpath libudev.so --relative-to .) \
        $udev_helpers

    install -vm755 -d {/usr/lib,/etc}/udev/{hwdb.d,rules.d,network}
    install -vm755 -d /usr/{lib,share}/pkgconfig
    install -vm755 udevadm                  /usr/bin/
    install -vm755 systemd-hwdb             /usr/bin/udev-hwdb
    ln      -svfn  ../bin/udevadm           /usr/sbin/udevd
    cp      -av    libudev.so{,*[0-9]}      /usr/lib/
    install -vm644 ../src/libudev/libudev.h /usr/include/
    install -vm644 src/libudev/libudev.pc   /usr/lib/pkgconfig/
    install -vm644 src/udev/udev.pc         /usr/share/pkgconfig/
    install -vm644 ../src/udev/udev.conf    /etc/udev/
    install -vm644 rules.d/* ../rules.d/README /usr/lib/udev/rules.d/
    install -vm644 $(find ../rules.d/*.rules -not -name '*power-switch*') /usr/lib/udev/rules.d/
    install -vm644 hwdb.d/*  ../hwdb.d/{*.hwdb,README} /usr/lib/udev/hwdb.d/
    install -vm755 $udev_helpers            /usr/lib/udev
    install -vm644 ../network/99-default.link /usr/lib/udev/network

    # supplemental config + Makefile install bits from the udev-lfs tarball
    tar -xvf "$(find_src udev-lfs-)"
    make -f udev-lfs-20230818/Makefile.lfs install || return
    # This udev build omits the kmod builtin, so drop rules that would warn every boot.
    sed -i '/kmod load/d' /usr/lib/udev/rules.d/80-drivers.rules || return
    rm -f /usr/lib/udev/rules.d/90-vconsole.rules || return

    # man pages from the systemd-man-pages tarball (udev/libudev only)
    tar -xf "$(find_src systemd-man-pages-)" --no-same-owner --strip-components=1 \
        -C /usr/share/man --wildcards '*/udev*' '*/libudev*' '*/systemd.link.5' \
        '*/systemd-'{hwdb,udevd.service}.8 2>/dev/null || true
    if [ -f /usr/share/man/man5/systemd.link.5 ]; then
        sed 's|systemd/network|udev/network|' /usr/share/man/man5/systemd.link.5 > /usr/share/man/man5/udev.link.5
        sed 's/systemd\(-\?\)/udev\1/' /usr/share/man/man8/systemd-hwdb.8 > /usr/share/man/man8/udev-hwdb.8
        sed 's|lib.*udevd|sbin/udevd|' /usr/share/man/man8/systemd-udevd.service.8 > /usr/share/man/man8/udevd.8
        rm -f /usr/share/man/man*/systemd*
    fi
    unset udev_helpers

    /usr/bin/udev-hwdb update || return
}

# --- 8.x sysvinit ---
b_sysvinit() {
    into sysvinit-
    patch -Np1 -i "$(find_patch sysvinit-3.10-consolidated)"
    make || return
    make install || return
    # The consolidated patch comments out the pidof symlink, but the lfs
    # bootscripts' init-functions call pidof when stopping daemons. killall5
    # dispatches to its pidof implementation when invoked by that name.
    ln -sfv ../sbin/killall5 /usr/bin/pidof
    /usr/bin/pidof 1 >/dev/null
}

msg "ch8 init tail: util-linux final, udev, sysvinit"
step util-linux-final b_utillinux
step udev             b_udev
step sysvinit         b_sysvinit
msg "ch8 init tail done — next: ch8b.sh (fsck/syslog), then ch9 config + ch10 kernel."

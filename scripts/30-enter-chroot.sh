#!/usr/bin/env bash
# Stage 3 setup — own the system, mount virtual kernel fs, and run an inner
# script INSIDE the chroot (LFS ch7.2-7.4). Run as ROOT, outside the chroot.
#   sudo -E bash scripts/30-enter-chroot.sh <inner-script-name>
# e.g.  sudo -E bash scripts/30-enter-chroot.sh ch7.sh
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run as root (sudo -E)"; exit 1; }
: "${LFS:?source env.sh first (sudo -E preserves it)}"
INNER="${1:?usage: 30-enter-chroot.sh <inner-script-name>}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"

echo "[chroot] 7.2 ownership → root:root"
for d in usr lib var etc bin sbin tools lib64; do
    [ -e "$LFS/$d" ] && chown -R root:root "$LFS/$d"
done

echo "[chroot] 7.3 mount virtual kernel filesystems"
mkdir -pv "$LFS"/{dev,proc,sys,run}
mountpoint -q "$LFS/dev"     || mount --bind /dev "$LFS/dev"
mkdir -p "$LFS/dev/pts"
mountpoint -q "$LFS/dev/pts" || mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
mountpoint -q "$LFS/proc"    || mount -t proc proc "$LFS/proc"
mountpoint -q "$LFS/sys"     || mount -t sysfs sysfs "$LFS/sys"
mountpoint -q "$LFS/run"     || mount -t tmpfs tmpfs "$LFS/run"
if [ -h "$LFS/dev/shm" ]; then
    install -d -m 1777 "$LFS$(realpath /dev/shm)"
else
    mkdir -p "$LFS/dev/shm"
    mountpoint -q "$LFS/dev/shm" || mount -t tmpfs -o nosuid,nodev tmpfs "$LFS/dev/shm"
fi

echo "[chroot] copying build framework inside"
mkdir -p "$LFS/root/kryptos/scripts/chroot" "$LFS/root/kryptos/lib"
cp "$REPO/lib/build.sh" "$LFS/root/kryptos/lib/"
cp "$REPO/scripts/chroot/"*.sh "$LFS/root/kryptos/scripts/chroot/"
if [ -d "$REPO/config" ]; then
    mkdir -p "$LFS/root/kryptos/config"
    cp -a "$REPO/config/." "$LFS/root/kryptos/config/"
fi
chmod +x "$LFS/root/kryptos/scripts/chroot/"*.sh

echo "[chroot] entering → /root/kryptos/scripts/chroot/$INNER"
chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM="${TERM:-xterm}" PS1='(kryptos chroot) \u:\w\$ ' \
    PATH=/usr/bin:/usr/sbin \
    MAKEFLAGS="-j$(nproc)" TESTSUITEFLAGS="-j$(nproc)" \
    /bin/bash --login -c "/root/kryptos/scripts/chroot/$INNER"

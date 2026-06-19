#!/usr/bin/env bash
# Stage 6 — LFS chapter 10 (kernel). Builds linux-6.10.5 for aarch64 with the
# default config (arm64 defconfig already carries virtio-blk/net/console, PL011
# serial = ttyAMA0, ext4, devtmpfs — everything to boot on QEMU -M virt). Runs
# inside the chroot; resumable. The boot image + QEMU launch happen on the host.
set -uo pipefail
set +h
export LFS=/ KRYPTOS_ROOT=/root/kryptos
source /root/kryptos/lib/build.sh

KVER_FILE=/boot/kryptos-kernel-version

# arch-specific kernel image path + serial console driver
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64)  KIMG="arch/x86/boot/bzImage";  SERIAL_OPTS="SERIAL_8250 SERIAL_8250_CONSOLE" ;;
    aarch64) KIMG="arch/arm64/boot/Image";  SERIAL_OPTS="SERIAL_AMBA_PL011 SERIAL_AMBA_PL011_CONSOLE" ;;
    *) die "unsupported arch: $ARCH" ;;
esac

b_kernel() {
    into linux-
    make mrproper
    make defconfig
    # brand the kernel + make sure the bits a QEMU guest needs are built in
    scripts/config --set-str LOCALVERSION "-kryptos"
    for opt in VIRTIO VIRTIO_PCI VIRTIO_BLK VIRTIO_NET VIRTIO_CONSOLE \
               $SERIAL_OPTS EXT4_FS DEVTMPFS DEVTMPFS_MOUNT BLK_DEV_INITRD; do
        scripts/config --enable "$opt" 2>/dev/null || true
    done
    make olddefconfig
    make
    make modules_install
    local v; v=$(make -s kernelrelease)
    cp -iv "$KIMG" "/boot/vmlinuz-$v"
    cp -iv System.map "/boot/System.map-$v"
    cp -iv .config "/boot/config-$v"
    printf '%s\n' "$v" > "$KVER_FILE"
    printf '%s\n' "$ARCH" > /boot/kryptos-arch
    install -d /usr/share/doc/linux-$(pkgver linux-)
}
pkgver() { basename "$(find_src "$1")" | sed -E "s/^$1([0-9p.]+)\.(tar|src).*/\1/"; }

msg "ch10 kernel build (linux for aarch64 / QEMU virt)"
step kernel b_kernel
msg "kernel done — image in /boot ($(cat $KVER_FILE 2>/dev/null)). Next: rootfs image + QEMU boot."

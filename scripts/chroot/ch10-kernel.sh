#!/usr/bin/env bash
# Stage 6 - LFS chapter 10 (kernel). Builds linux-6.10.5 for aarch64 with the
# default config (arm64 defconfig already carries virtio-blk/net/console, PL011
# serial = ttyAMA0, ext4, devtmpfs - everything to boot on QEMU -M virt). Runs
# inside the chroot; resumable. The boot image + QEMU launch happen on the host.
set -uo pipefail
set +h
export LFS=/ KRYPTOS_ROOT=/root/kryptos
source /root/kryptos/lib/build.sh

KVER_FILE=/boot/kryptos-kernel-version

# arch-specific kernel image path + serial console driver
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64)  KIMG="arch/x86/boot/bzImage";  SERIAL_OPTS="SERIAL_8250 SERIAL_8250_CONSOLE"; CON=ttyS0 ;;
    aarch64) KIMG="arch/arm64/boot/Image";  SERIAL_OPTS="SERIAL_AMBA_PL011 SERIAL_AMBA_PL011_CONSOLE"; CON=ttyAMA0 ;;
    *) die "unsupported arch: $ARCH" ;;
esac
# Keep a default command line for simple direct-boot testing, but do not force it.
# GRUB/installer boots must be able to pass root=UUID or a real target disk.
# console=tty0 shows boot log on graphical display; keep serial too.
CMDLINE="root=/dev/vda rw console=tty0 console=$CON net.ifnames=0"

b_kernel() {
    into linux-
    make mrproper
    make defconfig
    # brand the kernel + make sure the bits a QEMU guest needs are built in
    # one combined scripts/config call (per-opt loop didn't survive olddefconfig)
    local en=""
    for opt in VIRTIO VIRTIO_PCI VIRTIO_BLK VIRTIO_NET VIRTIO_CONSOLE \
               $SERIAL_OPTS EXT4_FS DEVTMPFS DEVTMPFS_MOUNT BLK_DEV_INITRD \
               DRM DRM_VIRTIO_GPU DRM_FBDEV_EMULATION DRM_SIMPLEDRM SYSFB SYSFB_SIMPLEFB FB FB_EFI FRAMEBUFFER_CONSOLE VT HYPERV VMBUS_HYPERV HYPERV_UTILS HYPERV_BALLOON HYPERV_NET HYPERV_STORAGE HID_HYPERV FB_HYPERV; do
        en+=" --enable $opt"
    done
    if [ "$ARCH" = x86_64 ]; then
        en+=" --enable CMDLINE_BOOL"
    fi
    scripts/config --set-str LOCALVERSION "-kryptos" $en \
        --set-str CMDLINE "$CMDLINE" --disable CMDLINE_FORCE --disable CMDLINE_OVERRIDE
    make olddefconfig
    grep -qE '^CONFIG_DRM_VIRTIO_GPU=y' .config || die "kernel: virtio-gpu DRM not enabled"
    grep -qE '^CONFIG_DRM_SIMPLEDRM=y' .config || die "kernel: simpledrm not enabled"
    grep -qE '^CONFIG_SYSFB_SIMPLEFB=y' .config || die "kernel: sysfb simplefb not enabled"
    grep -qE "^CONFIG_CMDLINE=\"root=/dev/vda" .config || die "kernel: built-in cmdline not set"
    (grep -qE "^# CONFIG_CMDLINE_FORCE is not set" .config || ! grep -qE "^CONFIG_CMDLINE_FORCE=y" .config) || die "kernel: cmdline force must be off"
    (grep -qE "^# CONFIG_CMDLINE_OVERRIDE is not set" .config || ! grep -qE "^CONFIG_CMDLINE_OVERRIDE=y" .config) || die "kernel: cmdline override must be off"
    make
    make modules_install
    local v; v=$(make -s kernelrelease)
    cp -fv "$KIMG" "/boot/vmlinuz-$v"
    cp -fv System.map "/boot/System.map-$v"
    cp -fv .config "/boot/config-$v"
    printf '%s\n' "$v" > "$KVER_FILE"
    printf '%s\n' "$ARCH" > /boot/kryptos-arch
    install -d /usr/share/doc/linux-$(pkgver linux-)
}
pkgver() { basename "$(find_src "$1")" | sed -E "s/^$1([0-9p.]+)\.(tar|src).*/\1/"; }

msg "ch10 kernel build (linux for aarch64 / QEMU virt)"
step kernel b_kernel
msg "kernel done - image in /boot ($(cat $KVER_FILE 2>/dev/null)). Next: rootfs image + QEMU boot."

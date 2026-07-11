#!/usr/bin/env bash
# Stage 7b - make a bootable KryptOS live ISO from the finished $LFS tree.
# The ISO boots a tiny initramfs, finds the CD, extracts the root filesystem to
# RAM, then switch_root's into KryptOS. Use 8 GB+ RAM for QEMU.
set -euo pipefail
: "${LFS:=/mnt/lfs}"
OUT="${OUT:-$PWD/dist}"
WORK="$OUT/iso-work"
STAGE="$LFS/build-tmp/rootstage"
ISO_TREE="$WORK/iso"
INITRD="$WORK/initramfs"
ROOT_TAR="$ISO_TREE/kryptos/rootfs.tar.gz"
ISO="$OUT/kryptos.iso"

msg() { printf '[iso] %s\n' "$*"; }
die() { printf '[iso] ERROR: %s\n' "$*" >&2; exit 1; }

[ -d "$LFS" ] || die "LFS tree missing: $LFS"
[ -x "$LFS/sbin/init" ] || die "missing $LFS/sbin/init - finish ch8/ch9 first"
ls "$LFS"/boot/vmlinuz-* >/dev/null 2>&1 || die "missing kernel - run ch10-kernel.sh first"

need_host() {
    command -v "$1" >/dev/null 2>&1 || die "host tool missing: $1"
}
need_lfs() {
    [ -e "$LFS$1" ] || die "LFS file missing: $1"
}

msg "prune $LFS -> $STAGE"
rm -rf "$STAGE" "$WORK"
mkdir -p "$STAGE" "$ISO_TREE/kryptos" "$ISO_TREE/boot/grub" "$ISO_TREE/EFI/BOOT" "$INITRD"
rsync -aHAX --numeric-ids \
    --exclude '/sources' --exclude '/tools' --exclude '/build-tmp' \
    --exclude '/build-logs' --exclude '/build-state' \
    --exclude '/root/kryptos' --exclude '/tmp/*' \
    --exclude '/proc/*' --exclude '/sys/*' --exclude '/dev/*' --exclude '/run/*' \
    "$LFS"/ "$STAGE"/
mkdir -p "$STAGE"/{proc,sys,dev,run,tmp,boot}
install -Dm755 scripts/live/kryptos-install "$STAGE/usr/sbin/kryptos-install"
chmod 1777 "$STAGE/tmp"

msg "pack rootfs -> $ROOT_TAR"
need_host tar
need_host gzip
tar --numeric-owner --xattrs --acls -C "$STAGE" -cpf - . | gzip -1 > "$ROOT_TAR"

msg "build initramfs"
copy_lfs_path() {
    local src="$1" dst
    need_lfs "$src"
    dst="$INITRD$src"
    mkdir -p "$(dirname "$dst")"
    cp -aL "$LFS$src" "$dst"
}

copy_libs_for() {
    local bin="$1" lib
    while IFS= read -r lib; do
        [ -n "$lib" ] || continue
        [ -e "$LFS$lib" ] || continue
        mkdir -p "$INITRD$(dirname "$lib")"
        cp -aL "$LFS$lib" "$INITRD$lib"
    done < <(chroot "$LFS" /usr/bin/ldd "$bin" 2>/dev/null | sed -n 's/.*=> \(\/[^ ]*\).*/\1/p; s/^[[:space:]]*\(\/[^ ]*\).*/\1/p' | sort -u)
}

add_bin() {
    local bin="$1"
    copy_lfs_path "$bin"
    copy_libs_for "$bin"
}

for bin in \
    /usr/bin/bash \
    /usr/bin/mount \
    /usr/bin/umount \
    /usr/bin/mkdir \
    /usr/bin/sleep \
    /usr/bin/ls \
    /usr/bin/cat \
    /usr/bin/chmod \
    /usr/bin/tar \
    /usr/bin/gzip \
    /usr/sbin/switch_root; do
    add_bin "$bin"
done

# Dynamic loader is not always reported in an easy-to-copy form by ldd.
[ -e "$LFS/lib64/ld-linux-x86-64.so.2" ] && copy_lfs_path /lib64/ld-linux-x86-64.so.2
[ -e "$LFS/lib/ld-linux-x86-64.so.2" ] && copy_lfs_path /lib/ld-linux-x86-64.so.2
mkdir -p "$INITRD"/{dev,proc,sys,run,newroot,tmp,usr/bin,usr/sbin}
chmod 1777 "$INITRD/tmp"

cat > "$INITRD/init" <<'INIT'
#!/usr/bin/bash
set -e
export PATH=/usr/bin:/usr/sbin:/bin:/sbin

echo "[kryptos-init] mount kernel filesystems"
mkdir -p /dev /proc /sys /run/iso /newroot
mount -t devtmpfs devtmpfs /dev 2>/dev/null || true
mount -t proc proc /proc 2>/dev/null || true
mount -t sysfs sysfs /sys 2>/dev/null || true
if [ -c /dev/tty0 ]; then exec >/dev/tty0 2>&1; fi
echo "[kryptos-init] console ready"

echo "[kryptos-init] search ISO rootfs"
found=
for round in 1 2 3 4 5 6 7 8 9 10; do
    for dev in /dev/sr* /dev/cdrom /dev/vd* /dev/sd*; do
        [ -b "$dev" ] || continue
        mount -t iso9660 -o ro "$dev" /run/iso 2>/dev/null || continue
        if [ -f /run/iso/kryptos/rootfs.tar.gz ]; then
            found=1
            break 2
        fi
        umount /run/iso 2>/dev/null || true
    done
    sleep 1
done

if [ "$found" != 1 ]; then
    echo "[kryptos-init] ISO rootfs not found"
    exec /usr/bin/bash
fi

echo "[kryptos-init] extract KryptOS rootfs to RAM"
mount -t tmpfs -o size=85% tmpfs /newroot
echo "[kryptos-init] rootfs unpack start"
gzip -dc /run/iso/kryptos/rootfs.tar.gz | tar -xpf - -C /newroot
echo "[kryptos-init] rootfs unpack done"
mkdir -p /newroot/dev /newroot/proc /newroot/sys /newroot/run /newroot/tmp
mkdir -p /newroot/media/kryptos-live
chmod 1777 /newroot/tmp
cat > /newroot/etc/fstab <<'FSTAB'
proc      /proc          proc     defaults             0 0
sysfs     /sys           sysfs    defaults             0 0
devtmpfs  /dev           devtmpfs mode=0755,nosuid     0 0
tmpfs     /run           tmpfs    defaults             0 0
tmpfs     /dev/shm       tmpfs    defaults             0 0
cgroup2   /sys/fs/cgroup cgroup2  defaults             0 0
tmpfs     /tmp           tmpfs    mode=1777            0 0
FSTAB
mount --move /run/iso /newroot/media/kryptos-live
echo "[kryptos-init] install media available at /media/kryptos-live"

echo "[kryptos-init] switch_root"
exec switch_root /newroot /sbin/init
INIT
chmod +x "$INITRD/init"

if command -v cpio >/dev/null 2>&1; then
    (cd "$INITRD" && find . | cpio -o -H newc | gzip -9 > "$ISO_TREE/boot/initramfs.img")
elif command -v bsdcpio >/dev/null 2>&1; then
    (cd "$INITRD" && find . | bsdcpio -o -H newc | gzip -9 > "$ISO_TREE/boot/initramfs.img")
else
    die "need cpio or bsdcpio for initramfs"
fi

msg "copy kernel + grub config"
cp -v "$LFS"/boot/vmlinuz-* "$ISO_TREE/boot/vmlinuz"
cat > "$ISO_TREE/boot/grub/grub.cfg" <<'GRUB'
set timeout=3
set default=0

menuentry "KryptOS live (RAM root)" {
    linux /boot/vmlinuz console=tty0 loglevel=7 net.ifnames=0
    initrd /boot/initramfs.img
}
GRUB

msg "build UEFI boot image"
if [ -d "$LFS/usr/lib/grub/x86_64-efi" ]; then
    cat > "$LFS/tmp/kryptos-efi-grub.cfg" <<'GRUBEFI'
search --file --set=root /kryptos/rootfs.tar.gz
set prefix=($root)/boot/grub
configfile /boot/grub/grub.cfg
GRUBEFI
    chroot "$LFS" /usr/bin/env PATH=/usr/sbin:/usr/bin:/sbin:/bin \
        grub-mkimage -O x86_64-efi -o /tmp/BOOTX64.EFI \
        -p /boot/grub -c /tmp/kryptos-efi-grub.cfg \
        iso9660 normal linux configfile search search_fs_file part_gpt part_msdos fat ext2
    cp -v "$LFS/tmp/BOOTX64.EFI" "$ISO_TREE/EFI/BOOT/BOOTX64.EFI"

    EFI_IMG_LFS="$LFS/tmp/kryptos-efiboot.img"
    EFI_MNT_LFS="$LFS/tmp/kryptos-efiboot-mnt"
    rm -f "$EFI_IMG_LFS"
    mkdir -p "$EFI_MNT_LFS"
    dd if=/dev/zero of="$EFI_IMG_LFS" bs=1M count=16 status=none
    chroot "$LFS" /usr/sbin/mkfs.fat -F 12 /tmp/kryptos-efiboot.img >/dev/null
    mount -o loop "$EFI_IMG_LFS" "$EFI_MNT_LFS"
    mkdir -p "$EFI_MNT_LFS/EFI/BOOT"
    cp -v "$ISO_TREE/EFI/BOOT/BOOTX64.EFI" "$EFI_MNT_LFS/EFI/BOOT/BOOTX64.EFI"
    umount "$EFI_MNT_LFS"
    cp -v "$EFI_IMG_LFS" "$ISO_TREE/boot/efiboot.img"
else
    die "missing $LFS/usr/lib/grub/x86_64-efi - run ch18-grub-efi.sh"
fi

msg "make ISO -> $ISO"
mkdir -p "$OUT"
rm -f "$ISO"
if command -v xorriso >/dev/null 2>&1; then
    xorriso -as mkisofs -iso-level 3 -full-iso9660-filenames -R -J -V KRYPTOS \
        -o "$ISO" -e boot/efiboot.img -no-emul-boot "$ISO_TREE"
elif command -v grub-mkrescue >/dev/null 2>&1; then
    grub-mkrescue -o "$ISO" "$ISO_TREE"
else
    die "need xorriso or grub-mkrescue to write ISO"
fi

ls -lh "$ISO" "$ROOT_TAR" "$ISO_TREE/boot/initramfs.img"
msg "done - boot with scripts/45-boot-iso.sh or QEMU -cdrom $ISO"

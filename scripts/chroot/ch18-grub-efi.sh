#!/usr/bin/env bash
# Build/install GRUB x86_64-efi modules alongside BIOS modules.
set -uo pipefail
set +h
export LFS=/ KRYPTOS_ROOT=/root/kryptos
source /root/kryptos/lib/build.sh

b_grub_efi() {
    into grub-
    ./configure --prefix=/usr --sysconfdir=/etc --disable-efiemu --disable-werror --with-platform=efi --target=x86_64 || return
    : > grub-core/extra_deps.lst
    make -j1 || return
    make install || return
}

b_grub_efi_check() {
    [ -d /usr/lib/grub/x86_64-efi ] || { echo "missing /usr/lib/grub/x86_64-efi"; exit 1; }
    [ -f /usr/lib/grub/x86_64-efi/normal.mod ] || { echo "missing normal.mod"; exit 1; }
    grub-mkimage -O x86_64-efi -o /tmp/bootx64-test.efi -p /boot/grub normal linux configfile search search_fs_uuid part_gpt fat ext2 || exit 1
    [ -s /tmp/bootx64-test.efi ] || { echo "failed to create EFI image"; exit 1; }
    rm -f /tmp/bootx64-test.efi
}

msg "GRUB x86_64-efi modules"
step grub-efi b_grub_efi
step grub-efi-check b_grub_efi_check
msg "GRUB EFI support done"
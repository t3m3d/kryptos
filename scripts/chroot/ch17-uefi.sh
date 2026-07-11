#!/usr/bin/env bash
# UEFI install support: FAT tools for EFI System Partition formatting.
set -uo pipefail
set +h
export LFS=/ KRYPTOS_ROOT=/root/kryptos
source /root/kryptos/lib/build.sh

b_dosfstools() {
    into dosfstools-
    ./configure --prefix=/usr --enable-compat-symlinks --mandir=/usr/share/man --docdir=/usr/share/doc/dosfstools-4.2 || return
    make || return
    make install || return
}

b_uefi_tools_check() {
    command -v mkfs.fat >/dev/null || { echo "missing mkfs.fat"; exit 1; }
    command -v mkfs.vfat >/dev/null || { echo "missing mkfs.vfat"; exit 1; }
    command -v grub-install >/dev/null || { echo "missing grub-install"; exit 1; }
    grub-install --help | grep -q x86_64-efi || { echo "grub lacks x86_64-efi target"; exit 1; }
}

msg "UEFI support tools"
step dosfstools b_dosfstools
step uefi-tools-check b_uefi_tools_check
msg "UEFI support done - installer can create FAT32 ESP"
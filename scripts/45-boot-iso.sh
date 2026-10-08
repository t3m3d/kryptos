#!/usr/bin/env bash
# Boot KryptOS live ISO in headless UEFI QEMU. Use 8 GB+ RAM: ISO rootfs
# extracts to tmpfs and reports boot progress through ttyS0.
set -euo pipefail
DIST="${1:-dist}"
ISO="$DIST/kryptos.iso"
[ -f "$ISO" ] || { echo "missing $ISO - run scripts/44-make-iso.sh" >&2; exit 1; }

QEMU_BIN="${QEMU_BIN:-qemu-system-x86_64}"
command -v "$QEMU_BIN" >/dev/null 2>&1 || {
    echo "missing $QEMU_BIN" >&2
    exit 1
}

OVMF="${OVMF:-}"
OVMF_VARS="${OVMF_VARS:-}"
if [ -z "$OVMF" ] || [ -z "$OVMF_VARS" ]; then
    for directory in \
        /usr/share/edk2/x64 \
        /usr/share/edk2/ovmf \
        /usr/share/edk2-ovmf \
        /usr/share/OVMF; do
        if [ -f "$directory/OVMF_CODE.fd" ] && [ -f "$directory/OVMF_VARS.fd" ]; then
            [ -n "$OVMF" ] || OVMF="$directory/OVMF_CODE.fd"
            [ -n "$OVMF_VARS" ] || OVMF_VARS="$directory/OVMF_VARS.fd"
            break
        fi
    done
fi
# Linux QEMU and Homebrew QEMU on Apple Silicon / Intel Macs.
for directory in /usr/share/qemu /opt/homebrew/share/qemu /usr/local/share/qemu; do
    if [ -f "$directory/edk2-x86_64-code.fd" ] && [ -f "$directory/edk2-i386-vars.fd" ]; then
        [ -n "$OVMF" ] || OVMF="$directory/edk2-x86_64-code.fd"
        [ -n "$OVMF_VARS" ] || OVMF_VARS="$directory/edk2-i386-vars.fd"
        break
    fi
done
[ -f "$OVMF" ] && [ -f "$OVMF_VARS" ] || {
    echo "missing OVMF firmware; set OVMF and OVMF_VARS" >&2
    exit 1
}

VARS_COPY="${OVMF_VARS_COPY:-$DIST/OVMF_VARS.fd}"
cp "$OVMF_VARS" "$VARS_COPY"

exec "$QEMU_BIN" \
    -M q35 \
    -cpu max \
    -accel "${QEMU_ACCEL:-tcg,thread=multi}" \
    -smp "${SMP:-4}" \
    -m "${MEM:-8192}" \
    -drive "if=pflash,format=raw,unit=0,readonly=on,file=$OVMF" \
    -drive "if=pflash,format=raw,unit=1,file=$VARS_COPY" \
    -cdrom "$ISO" \
    -boot d \
    -netdev user,id=n0 \
    -device virtio-net-pci,netdev=n0 \
    -device virtio-vga \
    -display "${QEMU_DISPLAY:-none}" \
    -monitor none \
    -serial stdio

#!/usr/bin/env bash
# Boot KryptOS live ISO in QEMU. Use 8 GB+ RAM: ISO rootfs extracts to tmpfs.
set -euo pipefail
DIST="${1:-dist}"
ISO="$DIST/kryptos.iso"
[ -f "$ISO" ] || { echo "missing $ISO - run scripts/44-make-iso.sh" >&2; exit 1; }
exec qemu-system-x86_64 \
    -M q35 \
    -cpu max \
    -smp "${SMP:-4}" \
    -m "${MEM:-8192}" \
    -cdrom "$ISO" \
    -boot d \
    -netdev user,id=n0 \
    -device virtio-net-pci,netdev=n0 \
    -nographic


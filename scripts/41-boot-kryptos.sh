#!/usr/bin/env bash
# Stage 7b — boot KryptOS on the Mac with QEMU (aarch64, direct kernel boot, no
# bootloader needed). Uses HVF acceleration (Apple Silicon) so it boots at native
# speed. Expects rootfs.ext4 + a vmlinuz-* in the same dir (default ./dist).
#   ./scripts/41-boot-kryptos.sh [dist-dir]
set -euo pipefail
DIST="${1:-$(cd "$(dirname "$0")/.." && pwd)/dist}"
KERNEL=$(ls "$DIST"/vmlinuz-* 2>/dev/null | head -1) || true
ROOTFS="$DIST/rootfs.ext4"
[ -n "$KERNEL" ] || { echo "no kernel in $DIST (run 40-make-image.sh + pull)"; exit 1; }
[ -f "$ROOTFS" ] || { echo "no rootfs in $DIST"; exit 1; }

echo "booting KryptOS:  kernel=$(basename "$KERNEL")  rootfs=rootfs.ext4"
echo "(login: root / kryptos   —   poweroff with: shutdown -h now, or Ctrl-a x)"
echo

exec qemu-system-aarch64 \
    -M virt -cpu host -accel hvf -smp 4 -m 2048 \
    -kernel "$KERNEL" \
    -append "root=/dev/vda rw console=ttyAMA0 init=/sbin/init" \
    -drive file="$ROOTFS",if=virtio,format=raw \
    -netdev user,id=n0 -device virtio-net-pci,netdev=n0 \
    -nographic

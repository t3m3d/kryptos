#!/usr/bin/env bash
# Stage 7b — boot KryptOS on the Mac with QEMU. Auto-detects the image arch and
# picks the right machine/console/accel:
#   aarch64 -> -M virt -cpu host -accel hvf (native speed on Apple Silicon), ttyAMA0
#   x86_64  -> -M q35 (TCG emulation on an arm Mac — slow but works),       ttyS0
# Expects rootfs.ext4 + a vmlinuz-* in the same dir (default ./dist).
#   ./scripts/41-boot-kryptos.sh [dist-dir]
set -euo pipefail
DIST="${1:-$(cd "$(dirname "$0")/.." && pwd)/dist}"
KERNEL=$(ls "$DIST"/vmlinuz-* 2>/dev/null | head -1) || true
ROOTFS="$DIST/rootfs.ext4"
[ -n "$KERNEL" ] || { echo "no kernel in $DIST (run 40-make-image.sh + pull)"; exit 1; }
[ -f "$ROOTFS" ] || { echo "no rootfs in $DIST"; exit 1; }

# x86 bzImage is a DOS/x86 boot executable; the arm64 Image is a raw blob.
if file "$KERNEL" | grep -qiE 'x86|bzImage|DOS'; then KARCH=x86_64; else KARCH=aarch64; fi
echo "booting KryptOS [$KARCH]:  $(basename "$KERNEL")  +  rootfs.ext4"
echo "(login: root / kryptos   —   quit QEMU: Ctrl-a x)"
echo

if [ "$KARCH" = x86_64 ]; then
    exec qemu-system-x86_64 \
        -M q35 -cpu max -smp 4 -m 2048 \
        -kernel "$KERNEL" \
        -append "root=/dev/vda rw console=ttyS0 init=/sbin/init net.ifnames=0" \
        -drive file="$ROOTFS",if=virtio,format=raw \
        -netdev user,id=n0 -device virtio-net-pci,netdev=n0 \
        -nographic
else
    # Graphical: virtio-gpu + a cocoa window. The window's 60Hz refresh drives
    # the virtio-gpu vblank, which the Hyprland desktop needs to complete DRM
    # page-flips (software/llvmpipe has no virgl). Serial logs still to stdio.
    exec qemu-system-aarch64 \
        -M virt -cpu host -accel hvf -smp 4 -m 4096 \
        -kernel "$KERNEL" \
        -append "root=/dev/vda rw console=ttyAMA0 init=/sbin/init net.ifnames=0" \
        -drive file="$ROOTFS",if=virtio,format=raw \
        -netdev user,id=n0 -device virtio-net-pci,netdev=n0 \
        -device virtio-gpu-pci -display cocoa -serial stdio
fi

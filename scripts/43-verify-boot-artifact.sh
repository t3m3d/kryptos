#!/usr/bin/env bash
# Verify the current KryptOS boot artifact. Today the real boot artifact is a
# QEMU/UTM direct-kernel bundle: rootfs.ext4 + vmlinuz-*. A standalone ISO still
# needs an initramfs/bootloader layer that can mount the ext4 root image.
set -euo pipefail
DIST="${1:-$(cd "$(dirname "$0")/.." && pwd)/dist}"
ROOTFS="$DIST/rootfs.ext4"
KERNEL=$(ls "$DIST"/vmlinuz-* 2>/dev/null | head -1) || true

fail=0
printf 'KryptOS boot artifact check: %s\n' "$DIST"
[ -f "$ROOTFS" ] && printf '[ok]   rootfs.ext4 present\n' || { printf '[miss] rootfs.ext4 missing\n'; fail=1; }
[ -n "$KERNEL" ] && printf '[ok]   kernel present: %s\n' "$(basename "$KERNEL")" || { printf '[miss] vmlinuz-* missing\n'; fail=1; }

if [ -f "$ROOTFS" ]; then
    command -v file >/dev/null 2>&1 && file "$ROOTFS" || true
fi
if [ -n "$KERNEL" ] && command -v file >/dev/null 2>&1; then
    file "$KERNEL" || true
fi

echo
printf 'Boot now with:\n  ./scripts/41-boot-kryptos.sh %q\n' "$DIST"
echo
printf 'ISO status:\n'
printf '  Not a standalone installer ISO yet. Need initramfs/bootloader packaging so\n'
printf '  the kernel can find/mount the root filesystem from ISO media. The current\n'
printf '  verified target is direct-kernel QEMU/UTM boot.\n'

exit "$fail"

#!/usr/bin/env bash
# Stage 7a — build a bootable rootfs image from the finished $LFS tree. Runs in
# the Linux build VM as root (needs to read root-owned files + mkfs). Prunes the
# build-only dirs, then bakes an ext4 image with `mkfs.ext4 -d` (no loop mount,
# no privileges beyond reading the tree). Also copies the kernel out beside it.
#   sudo LFS=/mnt/lfs OUT=/home/<user>/dist bash scripts/40-make-image.sh
set -euo pipefail
: "${LFS:=/mnt/lfs}"
OUT="${OUT:?set OUT to an output dir}"
SIZE="${SIZE:-8G}"
STAGE="$LFS/build-tmp/rootstage"

echo "[image] pruning $LFS -> $STAGE (excluding build-only dirs)"
rm -rf "$STAGE"; mkdir -p "$STAGE"
rsync -aHAX --numeric-ids \
    --exclude '/sources' --exclude '/tools' --exclude '/build-tmp' \
    --exclude '/build-logs' --exclude '/build-state' \
    --exclude '/root/kryptos' --exclude '/tmp/*' \
    "$LFS"/ "$STAGE"/

# kernel modules already under /lib/modules in the tree; make sure the virtual
# mountpoints exist (empty) so fstab mounts have somewhere to land.
mkdir -p "$STAGE"/{proc,sys,dev,run,tmp,boot}
chmod 1777 "$STAGE/tmp"

echo "[image] baking ext4 ($SIZE) -> $OUT/rootfs.ext4"
mkdir -p "$OUT"
rm -f "$OUT/rootfs.ext4"
mkfs.ext4 -q -F -L KRYPTOS -d "$STAGE" "$OUT/rootfs.ext4" "$SIZE"

echo "[image] copying kernel"
cp -v "$LFS"/boot/vmlinuz-* "$OUT"/ 2>/dev/null || { echo "no kernel in $LFS/boot — run ch10-kernel.sh first"; exit 1; }

echo "[image] done:"
ls -lh "$OUT"/rootfs.ext4 "$OUT"/vmlinuz-* 2>/dev/null
echo "[image] pull these to the Mac, then run scripts/41-boot-kryptos.sh"

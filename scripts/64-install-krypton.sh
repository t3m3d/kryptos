#!/usr/bin/env bash
# Host-side (macOS) driver: stage the Krypton 2.4.6 Linux x86_64
# toolchain into the KryptOS LFS tree, run the in-chroot install (ch23),
# repackage the live ISO, and collect it into dist/fast.
#   OUT=$HOME/kryptos-krypton-dist bash scripts/64-install-krypton.sh
# Requires: Lima VM 'krypton' running, /mnt/lfs prepared, passwordless sudo in VM.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
VM="${VM:-krypton}"
MAC_KRYPTON="${MAC_KRYPTON:-$HOME/Documents/GitHub/krypton}"
MAC_CORTEX="${MAC_CORTEX:-$HOME/Documents/GitHub/cortex}"  # Linux Wayland file manager (staging only, optional)
if [ ! -f "$MAC_CORTEX/cortex_wl.k" ] && [ -f "$HOME/Documents/GitHub/cortex-linux/cortex_wl.k" ]; then
    MAC_CORTEX="$HOME/Documents/GitHub/cortex-linux"
fi
# VM-local path readable by the guest user for limactl copy (sudo's $HOME is
# /root, mode 700 — limactl copy fails there). Files are made world-readable
# after the build below.
OUT="${OUT:-/home/t3m3d.guest/kryptos-krypton-dist}"   # inside the VM
KRYPTON_VERSION="${KRYPTON_VERSION:-2.4.6}"
TARBALL="krypton-${KRYPTON_VERSION}.tar.zst"
DIST="$REPO/dist/fast"

[ "$(uname -s)" = Darwin ] || { echo 'Run on macOS.' >&2; exit 1; }
[ -d "$MAC_KRYPTON/bootstrap" ] || { echo "krypton checkout not found at $MAC_KRYPTON" >&2; exit 1; }
command -v limactl >/dev/null || { echo 'limactl missing' >&2; exit 1; }
limactl list --format '{{.Name}} {{.Status}}' | grep -q "^$VM Running" \
    || { echo "VM '$VM' is not running; limactl start $VM first" >&2; exit 1; }

# The VM mounts \$HOME at the same path, so the Mac checkout is visible to it.
VM_KRYPTON="$MAC_KRYPTON"
VM_REPO="$REPO"

STAGE_INPUTS="${STAGE_INPUTS:-/home/t3m3d.guest/staging-inputs}"
limactl shell "$VM" -- bash -lc 'rm -f /home/t3m3d.guest/staging-inputs/* 2>/dev/null; mkdir -p /home/t3m3d.guest/staging-inputs'
# These Linux binaries are built from this checkout on the Linux VM; the Mac
# checkout ships prebuilt ones whose mtime may be stale on the 9p mount.
for f in bootstrap/kcc_driver_linux_x86_64 bootstrap/kcc_seed_linux_x86_64 bootstrap/elf_host_linux_x86_64 bootstrap/optimize_host_linux_x86_64 compiler/linux_x86/elf_host compiler/linux_x86/optimize_host; do
    limactl copy "$MAC_KRYPTON/$f" "$VM:$STAGE_INPUTS/$(basename "$f")" >/dev/null
    echo "[krypton-iso] staged $f via limactl copy (fresh)"
done
if [ -n "${MAC_CORTEX:-}" ] && [ -f "$MAC_CORTEX/cortex_wl.k" ]; then
    limactl copy "$MAC_CORTEX/cortex_wl.k" "$VM:$STAGE_INPUTS/cortex_wl.k" >/dev/null
    limactl copy "$MAC_CORTEX/cortex.k" "$VM:$STAGE_INPUTS/cortex.k" >/dev/null
    echo '[krypton-iso] cortex examples staged via limactl copy (fresh)'
fi
if [ -f "$MAC_KRYPTON/examples/choc_linux_demo.k" ]; then
    limactl copy "$MAC_KRYPTON/examples/choc_linux_demo.k" "$VM:$STAGE_INPUTS/choc_linux_demo.k" >/dev/null
fi
LIMACTL_FILE=$(mktemp /tmp/kryptos-stage.XXXXXX.sh)
cat > "$LIMACTL_FILE" <<'STAGE'
set -euo pipefail
test -d /mnt/lfs || { echo '/mnt/lfs missing' >&2; exit 1; }
test -d /mnt/lfs/sources || { echo '/mnt/lfs/sources missing' >&2; exit 1; }
tmp=$(mktemp -d)
mkdir -p "$tmp/krypton" "$tmp/krypton/examples"
cd "$1"
cp -a bootstrap compiler stdlib headers kr LICENSE examples README.md "$tmp/krypton/"
if ls /home/t3m3d.guest/staging-inputs/*.k >/dev/null 2>&1; then
    cp -a /home/t3m3d.guest/staging-inputs/*.k "$tmp/krypton/examples/" || true
fi
for f in kcc_driver_linux_x86_64 kcc_seed_linux_x86_64 elf_host_linux_x86_64 optimize_host_linux_x86_64 elf_host optimize_host; do
    if [ -f "/home/t3m3d.guest/staging-inputs/$f" ]; then
        if [ "$f" = "elf_host" ] || [ "$f" = "optimize_host" ]; then
            dst="$tmp/krypton/compiler/linux_x86/$f"
        else
            dst="$tmp/krypton/bootstrap/$f"
        fi
        cp -fv "/home/t3m3d.guest/staging-inputs/$f" "$dst"
    fi
done
cd "$tmp/krypton/bootstrap"
rm -f kcc_driver_macos_aarch64 kcc_driver_windows_x86_64.exe \
      kcc_seed_macos_aarch64 kcc_seed_windows_x86_64.exe kcc_seed_linux_aarch64 \
      macho_host_macos_aarch64 x64_host_windows_x86_64.exe \
      optimize_host_windows_x86_64.exe krypton_rt_windows.dll
cd "$tmp"
TARBALL="$2"
rm -f "/mnt/lfs/sources/$TARBALL"
tar --zstd -cpf "/mnt/lfs/sources/$TARBALL" krypton
rm -rf "$tmp"
ls -lh "/mnt/lfs/sources/$TARBALL"
STAGE
limactl copy "$LIMACTL_FILE" "$VM:/tmp/kryptos-stage.sh"
echo "[krypton-iso] staging source tarball inside the VM"
limactl shell "$VM" -- sudo -n bash /tmp/kryptos-stage.sh "$VM_KRYPTON" "$TARBALL"
rm -f "$LIMACTL_FILE"

# Force a fresh in-chroot toolchain install: without this the chroot
# skips when the sentinel is stale, silently shipping the old driver.
limactl shell "$VM" -- sudo -n rm -f /mnt/lfs/build-state/krypton.done
echo '[krypton-iso] installing inside the chroot (ch23-krypton.sh)'
limactl shell "$VM" -- sh -c "cd '$VM_REPO' && exec sudo -n env LFS=/mnt/lfs bash '$VM_REPO/scripts/30-enter-chroot.sh' ch23-krypton.sh"

echo '[krypton-iso] repackaging the live ISO'
limactl shell "$VM" -- sh -c "cd '$VM_REPO' && exec sudo -n env LFS=/mnt/lfs OUT='$OUT' bash '$VM_REPO/scripts/44-make-iso.sh'"
limactl shell "$VM" -- sudo -n chmod -R a+rX "$OUT"

echo '[krypton-iso] collecting ISO into dist/fast'
mkdir -p "$DIST"
limactl copy "$VM:$OUT/kryptos.iso" "$DIST/kryptos.iso"
limactl copy "$VM:$OUT/kryptos.iso.sha256" "$DIST/kryptos.iso.sha256"
bash "$REPO/scripts/43-verify-boot-artifact.sh" "$DIST" iso
echo "[krypton-iso] done -> $DIST/kryptos.iso"
echo '[krypton-iso] boot with: open dist/fast/Start\ KryptOS.command   (or scripts/47-test-macos-iso.sh dist/fast headless)'

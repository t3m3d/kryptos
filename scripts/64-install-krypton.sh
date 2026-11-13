#!/usr/bin/env bash
# Host-side (macOS) driver: stage the Krypton 2.5.0-alpha Linux x86_64
# toolchain into the KryptOS LFS tree, run the in-chroot install (ch23),
# repackage the live ISO, and collect it into dist/fast.
#   OUT=$HOME/kryptos-krypton-dist bash scripts/64-install-krypton.sh
# Requires: Lima VM 'krypton' running, /mnt/lfs prepared, passwordless sudo in VM.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
VM="${VM:-krypton}"
MAC_KRYPTON="${MAC_KRYPTON:-$HOME/Documents/GitHub/krypton}"
MAC_CORTEX="${MAC_CORTEX:-$HOME/Documents/GitHub/cortex}"  # Linux Wayland file manager
if [ ! -f "$MAC_CORTEX/cortex_wl.k" ] && [ -f "$HOME/Documents/GitHub/cortex-linux/cortex_wl.k" ]; then
    MAC_CORTEX="$HOME/Documents/GitHub/cortex-linux"
fi
# VM-local path readable by the guest user for limactl copy (sudo's $HOME is
# /root, mode 700 — limactl copy fails there). Files are made world-readable
# after the build below.
OUT="${OUT:-/home/t3m3d.guest/kryptos-krypton-dist}"   # inside the VM
KRYPTON_VERSION="${KRYPTON_VERSION:-2.5.0-alpha}"
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

echo '[krypton-iso] staging source tarball inside the VM'
limactl shell "$VM" -- sudo -n bash -c "
set -euo pipefail
test -d /mnt/lfs || { echo '/mnt/lfs missing' >&2; exit 1; }
test -d /mnt/lfs/sources || { echo '/mnt/lfs/sources missing' >&2; exit 1; }
tmp=\$(mktemp -d)
mkdir -p \"\$tmp/krypton\"
cd '$VM_KRYPTON'
cp -a bootstrap compiler stdlib headers kr LICENSE examples README.md \"\$tmp/krypton/\"
if [ -f '$MAC_CORTEX/cortex_wl.k' ]; then
    cp -a '$MAC_CORTEX/cortex.k' '$MAC_CORTEX/cortex_wl.k' "\$tmp/krypton/examples/"
    echo '[krypton-iso] cortex sources staged into examples/'
else
    echo '[krypton-iso] note: cortex checkout not found - cortex examples skipped; set MAC_CORTEX'
fi
# Drop non-Linux, non-x86_64 and fat binaries; keep the ELF x86_64 set.
cd \"\$tmp/krypton/bootstrap\"
rm -f kcc_driver_macos_aarch64 kcc_driver_windows_x86_64.exe \
      kcc_seed_macos_aarch64 kcc_seed_windows_x86_64.exe kcc_seed_linux_aarch64 \
      macho_host_macos_aarch64 x64_host_windows_x86_64.exe \
      optimize_host_windows_x86_64.exe krypton_rt_windows.dll
cd \"\$tmp\"
rm -f /mnt/lfs/sources/$TARBALL
tar --zstd -cpf /mnt/lfs/sources/$TARBALL krypton
rm -rf \"\$tmp\"
ls -lh /mnt/lfs/sources/$TARBALL
"

# The VM mounts \$HOME via reverse-sshfs with attribute caching; fresh edits
# are not always visible guest-side. Drop caches so the chroot copies current scripts.
limactl shell "$VM" -- sudo -n sh -c 'echo 3 > /proc/sys/vm/drop_caches' || true

# 9p mounts are read-only but readable; run from the repo path so 44-make-iso's
# relative paths (scripts/live/...) resolve.
# ch23 (lib/build.sh `step`) caches completion in /mnt/lfs/build-state/krypton.done.
# Without removing it, the re-install silently no-ops and a stale /usr/local/krypton
# (without this tree's stdlib changes) ships in the ISO.
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

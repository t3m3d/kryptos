#!/usr/bin/env bash
# Boot the real x86_64 KryptOS ISO on macOS using QEMU software emulation.
# Usage: 47-test-macos-iso.sh [dist-dir] [graphical|headless]
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
DIST="${1:-$REPO/dist}"
MODE="${2:-graphical}"
[ "$(uname -s)" = Darwin ] || { echo 'This launcher targets macOS.' >&2; exit 1; }
case "$MODE" in graphical|headless) ;; *) echo 'Mode must be graphical or headless.' >&2; exit 1 ;; esac
bash "$REPO/scripts/43-verify-boot-artifact.sh" "$DIST" iso
command -v "${QEMU_BIN:-qemu-system-x86_64}" >/dev/null || { echo 'Install QEMU before testing.' >&2; exit 1; }
export QEMU_ACCEL='tcg,thread=multi'
export MEM="${MEM:-8192}"
# Verified on Apple Silicon: four emulated CPUs stalled during early userspace.
# Keep overrides available for diagnostics and other host/QEMU combinations.
export SMP="${SMP:-1}"
export QEMU_MACHINE="${QEMU_MACHINE:-q35,hpet=off}"
cd "$REPO"
if [ "$MODE" = headless ]; then
    export QEMU_DISPLAY=none
    export TIMEOUT="${TIMEOUT:-600}"
    exec bash scripts/46-smoke-iso.sh "$DIST"
fi
export QEMU_DISPLAY="${QEMU_DISPLAY:-cocoa,full-screen=off,zoom-to-fit=on}"
export QEMU_WIDTH="${QEMU_WIDTH:-1600}"
export QEMU_HEIGHT="${QEMU_HEIGHT:-900}"
echo 'Hover over the green window button and choose Fill to keep window controls visible.'
echo 'x86_64 UEFI boot under software emulation; first boot may take several minutes.'
echo 'Base ISO provides a console. For desktop-enabled images, run start-hypr from tty1.'
exec bash scripts/45-boot-iso.sh "$DIST"

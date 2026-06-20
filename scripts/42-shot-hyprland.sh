#!/usr/bin/env bash
# Boot KryptOS graphically (virtio-gpu) and capture the Hyprland desktop via the
# QEMU QMP `screendump` after the compositor comes up. Software-rendered
# (llvmpipe) so give it time. Produces dist/hyprland.png.
#   ./scripts/42-shot-hyprland.sh [dist-dir] [wait-seconds]
set -euo pipefail
DIST="${1:-$(cd "$(dirname "$0")/.." && pwd)/dist}"
WAIT="${2:-110}"
KERNEL=$(ls "$DIST"/vmlinuz-* | head -1)
ROOT="$DIST/rootfs.ext4"
MON=/tmp/kryptos-qmp.sock
PPM=/tmp/kryptos-shot.ppm
PNG="$DIST/hyprland.png"
SER="$DIST/hyprland-serial.log"
rm -f "$MON" "$PPM"

if file "$KERNEL" | grep -qiE 'x86|bzImage|DOS'; then
    QEMU=qemu-system-x86_64; MACH=(-M q35 -cpu max); CON=ttyS0
else
    QEMU=qemu-system-aarch64; MACH=(-M virt -cpu host -accel hvf); CON=ttyAMA0
fi

echo "[shot] booting $QEMU with virtio-gpu; waiting ${WAIT}s for Hyprland…"
"$QEMU" "${MACH[@]}" -smp 4 -m 4096 \
    -kernel "$KERNEL" \
    -append "root=/dev/vda rw console=$CON net.ifnames=0" \
    -drive file="$ROOT",if=virtio,format=raw \
    -device virtio-gpu-pci -display none \
    -serial "file:$SER" \
    -qmp "unix:$MON,server,nowait" &
QPID=$!
trap 'kill $QPID 2>/dev/null || true' EXIT

# wait for the QMP socket, then for Hyprland to come up
for i in $(seq 1 30); do [ -S "$MON" ] && break; sleep 1; done
sleep "$WAIT"

echo "[shot] capturing framebuffer via QMP screendump…"
python3 - "$MON" "$PPM" <<'PY'
import socket, json, sys, time
sock, ppm = sys.argv[1], sys.argv[2]
s = socket.socket(socket.AF_UNIX); s.connect(sock); f = s.makefile('rw')
def cmd(o): f.write(json.dumps(o)+"\r\n"); f.flush(); return f.readline()
f.readline()                                   # greeting
cmd({"execute":"qmp_capabilities"})
print(cmd({"execute":"screendump","arguments":{"filename":ppm}}).strip())
time.sleep(2)
PY

if [ -f "$PPM" ]; then
    if command -v sips >/dev/null; then sips -s format png "$PPM" --out "$PNG" >/dev/null
    elif command -v convert >/dev/null; then convert "$PPM" "$PNG"
    else cp "$PPM" "$PNG"; fi
    echo "[shot] saved $PNG"
else
    echo "[shot] no framebuffer captured — check $SER"
fi
kill $QPID 2>/dev/null || true
echo "[shot] serial tail:"; tail -15 "$SER" 2>/dev/null || true

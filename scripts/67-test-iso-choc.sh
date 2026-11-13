#!/usr/bin/env bash
# Boot the rebuilt ISO headless, log in as root, and verify the choc_linux_demo example
# (k:choc_linux ships in the ISO via scripts/64-install-krypton.sh's
# staged krypton payload) compiles with the in-ISO Linux driver and runs
# headless, exiting via the expected 'connect failed' path (no compositor
# under serial-only QEMU). Requires the ISO to contain
# /usr/local/krypton/examples/choc_linux_demo.k.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
DIST="${1:-$REPO/dist/fast}"
ISO="$DIST/kryptos.iso"
LOG="${LOG:-$DIST/iso-choc.log}"
MEM="${MEM:-8192}" SMP="${SMP:-1}" TIMEOUT="${TIMEOUT:-1500}" QEMU_MACHINE="${QEMU_MACHINE:-q35,hpet=off}"
QEMU_BIN="${QEMU_BIN:-qemu-system-x86_64}"
[ -f "$ISO" ] || { echo "missing $ISO - run scripts/64-install-krypton.sh first" >&2; exit 1; }
command -v "$QEMU_BIN" >/dev/null || { echo "missing $QEMU_BIN" >&2; exit 1; }

OVMF=""
OVMF_VARS=""
for directory in /usr/share/edk2/x64 /usr/share/edk2/ovmf /usr/share/OVMF /usr/share/qemu /opt/homebrew/share/qemu /usr/local/share/qemu; do
    if [ -z "$OVMF" ] && [ -d "$directory" ]; then
        for code in edk2-x86_64-code.fd OVMF_CODE.fd; do
            for vars in edk2-i386-vars.fd OVMF_VARS.fd; do
                if [ -f "$directory/$code" ] && [ -f "$directory/$vars" ]; then
                    OVMF="$directory/$code"; OVMF_VARS="$directory/$vars"
                fi
            done
        done
    fi
done
[ -f "$OVMF" ] && [ -f "$OVMF_VARS" ] || { echo "missing OVMF firmware; set OVMF and OVMF_VARS" >&2; exit 1; }

VARS_COPY="$DIST/OVMF_VARS-choc-test.fd"
cp "$OVMF_VARS" "$VARS_COPY"

rm -f "$LOG"
FIFO="$(mktemp -u /tmp/kryptos-qemu-in.XXXXXX)"
mkfifo "$FIFO"
# Hold the fifo open so qemu does not see EOF.
exec 9>"$FIFO"

"$QEMU_BIN" \
    -M "$QEMU_MACHINE" \
    -cpu max \
    -accel "${QEMU_ACCEL:-tcg,thread=multi}" \
    -smp "$SMP" \
    -m "$MEM" \
    -drive "if=pflash,format=raw,unit=0,readonly=on,file=$OVMF" \
    -drive "if=pflash,format=raw,unit=1,file=$VARS_COPY" \
    -cdrom "$ISO" \
    -boot d \
    -netdev user,id=n0 \
    -device virtio-net-pci,netdev=n0 \
    -device virtio-vga,xres=1280,yres=800 \
    -display none \
    -monitor none \
    -serial stdio \
    <"$FIFO" >"$LOG" 2>&1 &
QEMU_PID=$!

cleanup() {
    kill "$QEMU_PID" 2>/dev/null || true
    wait "$QEMU_PID" 2>/dev/null || true
    exec 9>&- || true
    rm -f "$FIFO"
}
trap cleanup EXIT INT TERM

wait_for() { # wait_for <regex> <timeout_secs> <label>
    local pat="$1" limit="$2" label="$3" start=$SECONDS
    while [ $((SECONDS - start)) -lt "$limit" ]; do
        if grep -qE "$pat" "$LOG" 2>/dev/null; then return 0; fi
        if ! kill -0 "$QEMU_PID" 2>/dev/null; then
            echo "[choc-iso] FAIL: qemu exited while waiting for $label" >&2
            tail -40 "$LOG" >&2 || true
            exit 1
        fi
        sleep 2
    done
    echo "[choc-iso] FAIL: timeout waiting for $label" >&2
    tail -40 "$LOG" >&2 || true
    exit 1
}

wait_for 'kryptos login:' "$TIMEOUT" 'serial login'
printf 'root\n' >&9
wait_for '[Pp]assword:' 60 'password prompt'
printf 'kryptos\n' >&9
wait_for 'root.*#' 90 'root shell prompt'

printf 'kcc --version; echo MARK_KCC_DONE\n' >&9
wait_for 'kcc version' 60 'kcc --version output'
wait_for 'MARK_KCC_DONE' 60 'kcc marker'

printf 'ls /usr/local/krypton/examples/choc_linux_demo.k >/dev/null 2>&1; echo MARKL_C=$?\n' >&9
wait_for 'MARKL_C=[0-9]' 60 'choc source check'
if ! grep -q 'MARKL_C=0' "$LOG"; then echo '[choc-iso] FAIL: /usr/local/krypton/examples/choc_linux_demo.k missing; rebuild via 64-install (the staged krypton examples/payload)' >&2; exit 1; fi
printf 'kcc /usr/local/krypton/examples/choc_linux_demo.k -o /tmp/cortex_demo; echo MARK_COMPILE_DONE\n' >&9
# TCG compile of a ~52KB file takes minutes under emulation.
wait_for 'elf: wrote /tmp/cortex_demo' "$TIMEOUT" 'choc_linux_demo compile'

printf 'ls -la /tmp/cortex_demo; WAYLAND_DISPLAY= timeout 15 /tmp/cortex_demo; echo MARK_CHOC_LINUX_DEMO_RC=$?\n' >&9
wait_for 'connect failed' 60 'headless connect message'
wait_for 'MARK_CHOC_LINUX_DEMO_RC=1' 60 'headless rc=1'

printf 'shutdown -h now\n' >&9
sleep 2
echo '[choc-iso] PASS'
exit 0

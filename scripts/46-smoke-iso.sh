#!/usr/bin/env bash
# Boot the live ISO headlessly and require a serial login prompt.
set -euo pipefail
DIST="${1:-dist}"
TIMEOUT="${TIMEOUT:-180}"
LOG="${LOG:-$DIST/iso-smoke.log}"

mkdir -p "$DIST"
rm -f "$LOG"

MEM="${MEM:-8192}" scripts/45-boot-iso.sh "$DIST" >"$LOG" 2>&1 &
qemu_pid=$!
cleanup() {
    kill "$qemu_pid" 2>/dev/null || true
    wait "$qemu_pid" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

elapsed=0
while kill -0 "$qemu_pid" 2>/dev/null && [ "$elapsed" -lt "$TIMEOUT" ]; do
    if grep -q 'kryptos login:' "$LOG" 2>/dev/null; then
        echo "[smoke] PASS: KryptOS reached serial login in ${elapsed}s"
        exit 0
    fi
    sleep 1
    elapsed=$((elapsed + 1))
done

echo "[smoke] FAIL: no KryptOS serial login after ${elapsed}s" >&2
tail -80 "$LOG" >&2 || true
exit 1

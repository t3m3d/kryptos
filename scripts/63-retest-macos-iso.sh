#!/usr/bin/env bash
# Retest an already-collected ISO without restarting the Linux build VM.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
DIST="${1:?usage: 63-retest-macos-iso.sh <dist-directory>}"
STATUS="$DIST/mac-boot-status.txt"
finish() {
    code=$?
    if [ "$code" -ne 0 ]; then
        printf 'FAILED phase=boot exit=%s date=%s\n' "$code" "$(date -u +%FT%TZ)" > "$STATUS"
    fi
}
trap finish EXIT
if [ -f "$DIST/iso-smoke.log" ]; then
    cp -p "$DIST/iso-smoke.log" "$DIST/iso-smoke.before-retest-$(date -u +%Y%m%dT%H%M%SZ).log"
fi
printf 'TESTING x86_64 base ISO under UEFI QEMU machine=%s\n' "${QEMU_MACHINE:-q35,hpet=off}" > "$STATUS"
bash "$REPO/scripts/47-test-macos-iso.sh" "$DIST" headless
printf 'PASS: x86_64 base ISO reached serial login in macOS QEMU. Desktop not included.\n' > "$STATUS"
cat "$STATUS"

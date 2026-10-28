#!/usr/bin/env bash
# Attach to the running Linux base-ISO pipeline, collect its outputs, boot-test.
# This is one build dependency chain, not a recurring task or scheduler.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
VM="${VM:-krypton}"
DIST="${1:-$REPO/dist/x86_64}"
[ "$(uname -s)" = Darwin ] || { echo 'Run on macOS.' >&2; exit 1; }
mkdir -p "$DIST"
DIST="$(cd "$DIST" && pwd)"
STATUS="$DIST/mac-boot-status.txt"
phase=connect
finish() {
    code=$?
    if [ "$code" -ne 0 ]; then
        printf 'FAILED phase=%s exit=%s date=%s\n' "$phase" "$code" "$(date -u +%FT%TZ)" > "$STATUS"
    fi
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
printf 'CONNECTING date=%s\n' "$(date -u +%FT%TZ)" > "$STATUS"
command -v limactl >/dev/null
GUEST_HOME=$(limactl shell "$VM" -- printenv HOME)
GUEST_OUT="$GUEST_HOME/kryptos-base-dist"
phase=waiting-for-build
printf 'WAITING for Linux base ISO; no artifact or boot success yet\n' > "$STATUS"
while :; do
    state=$(limactl shell "$VM" -- sh -c 'if [ -f "$1" ]; then cat "$1"; else echo WAITING; fi' sh "$GUEST_OUT/build-status.txt")
    case "$state" in
        READY*) break ;;
        FAILED*|INTERRUPTED*) echo "$state" >&2; exit 1 ;;
    esac
    # Detect a failed dependency pipeline instead of waiting indefinitely.
    limactl shell "$VM" -- pgrep -f '^bash scripts/60-build-base-iso.sh$' >/dev/null || {
        echo 'ISO build pipeline exited without a READY result; inspect guest build log.' >&2
        exit 1
    }
    printf '%s checked=%s\n' "$state" "$(date -u +%FT%TZ)" > "$STATUS"
    sleep 30
done
phase=collect
printf 'COLLECTING base ISO\n' > "$STATUS"
limactl copy "$VM:$GUEST_OUT/kryptos.iso" "$DIST/kryptos.iso"
limactl copy "$VM:$GUEST_OUT/kryptos.iso.sha256" "$DIST/kryptos.iso.sha256"
bash "$REPO/scripts/43-verify-boot-artifact.sh" "$DIST" iso
# This VM was started for this build. Release its 10 GiB before the boot guest.
phase=stop-builder
limactl stop "$VM" --tty=false
phase=boot
printf 'TESTING x86_64 base ISO under UEFI QEMU\n' > "$STATUS"
bash "$REPO/scripts/47-test-macos-iso.sh" "$DIST" headless
printf 'PASS: x86_64 base ISO reached serial login in macOS QEMU. Desktop not included.\n' > "$STATUS"
cat "$STATUS"

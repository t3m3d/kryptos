#!/usr/bin/env bash
# Resume a Linux x86_64 LFS tree through a UEFI live ISO with the Hyprland
# desktop (Wayland, Mesa, foot, Quickshell). Resumable via step markers.
# Run as the unprivileged owner of $LFS, with passwordless sudo for chroot.
#   LFS=/mnt/lfs OUT="$HOME/kryptos-base-dist" bash scripts/60-build-base-iso.sh
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"
: "${LFS:=/mnt/lfs}"
: "${OUT:=$HOME/kryptos-base-dist}"
export LFS OUT
mkdir -p "$OUT"
[ "$(uname -s)" = Linux ] && [ "$(uname -m)" = x86_64 ] || { echo 'Run inside the x86_64 Linux build VM.' >&2; exit 1; }
[ "$(id -u)" -ne 0 ] || { echo 'Run as the unprivileged build owner, not root.' >&2; exit 1; }
[ -d "$LFS/build-state" ] || { echo 'A prepared LFS tree is required.' >&2; exit 1; }
command -v flock >/dev/null || { echo 'flock is required.' >&2; exit 1; }
exec 9>"$LFS/base-iso-build.lock"
flock -n 9 || { echo 'Another base ISO pipeline is running.' >&2; exit 1; }
STATUS="$OUT/build-status.txt"
phase=preflight
finish() {
    code=$?
    if [ "$code" -ne 0 ]; then
        result=FAILED
        case "$code" in 130|143) result=INTERRUPTED ;; esac
        printf '%s phase=%s exit=%s date=%s\n' "$result" "$phase" "$code" "$(date -u +%FT%TZ)" > "$STATUS"
    fi
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
printf 'RUNNING phase=preflight date=%s\n' "$(date -u +%FT%TZ)" > "$STATUS"
sudo -n true || { echo 'Passwordless sudo is required for the chroot stages.' >&2; exit 1; }
# Optional dependency only accepts the expected process, never an arbitrary
# PID reused after a reboot. Normal recovery simply resumes completed steps.
if [ -n "${WAIT_FOR_PID:-}" ]; then
    case "$WAIT_FOR_PID" in *[!0-9]*|'') echo 'Invalid WAIT_FOR_PID' >&2; exit 1 ;; esac
    phase=waiting-for-temporary-tools
    printf 'WAITING phase=%s pid=%s date=%s\n' "$phase" "$WAIT_FOR_PID" "$(date -u +%FT%TZ)" > "$STATUS"
    while kill -0 "$WAIT_FOR_PID" 2>/dev/null; do
        tr '\0' '\n' < "/proc/$WAIT_FOR_PID/cmdline" | grep -Fx 'scripts/20-temp-tools.sh' >/dev/null || {
            echo "Dependency PID $WAIT_FOR_PID is not the expected temporary-tools build." >&2
            exit 1
        }
        sleep 10
    done
fi
run() {
    phase="$1"; shift
    printf 'RUNNING phase=%s date=%s\n' "$phase" "$(date -u +%FT%TZ)" > "$STATUS"
    printf '\n[base-iso] %s\n' "$phase"
    "$@"
}
# Additional sources required beyond the core LFS source set.
run fetch-uefi bash scripts/53-fetch-uefi.sh
run fetch-network bash scripts/56-fetch-network.sh
run fetch-desktop bash scripts/50-fetch-desktop.sh
run fetch-quickshell bash scripts/54-fetch-quickshell.sh
run temporary-tools bash scripts/20-temp-tools.sh
for inner in ch7.sh ch8.sh ch8-init.sh ch8b.sh ch9.sh ch21-network.sh ch10-kernel.sh ch18-grub-efi.sh ch17-uefi.sh \
    ch11-desktop-p1.sh ch11-desktop-p2.sh ch11-desktop-p3.sh ch11-desktop-p5-xcursor.sh ch11-desktop-p4.sh \
    ch14-foot.sh ch19-quickshell.sh ch12-session.sh; do
    run "$inner" sudo -n env LFS="$LFS" bash scripts/30-enter-chroot.sh "$inner"
done
run package-iso sudo -n env LFS="$LFS" OUT="$OUT" bash scripts/44-make-iso.sh
run verify-iso bash scripts/43-verify-boot-artifact.sh "$OUT" iso
printf 'READY desktop ISO built; visible desktop unverified date=%s\n' "$(date -u +%FT%TZ)" > "$STATUS"
echo "Desktop ISO: $OUT/kryptos.iso"
echo 'Copy ISO and checksum to Mac; run 47-test-macos-iso.sh, log in as root, then start-hypr.'

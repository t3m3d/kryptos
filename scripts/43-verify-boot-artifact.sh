#!/usr/bin/env bash
# Check ISO integrity or a direct-kernel bundle. This is not a boot test.
# EXPECT_ARCH=x86_64 rejects old ARM64 direct-kernel bundles.
set -euo pipefail
DIST="${1:-$(cd "$(dirname "$0")/.." && pwd)/dist}"
MODE="${2:-auto}"
EXPECT_ARCH="${EXPECT_ARCH:-}"
die() { printf '[fail] %s\n' "$*" >&2; exit 1; }
case "$MODE" in
    auto) if [ -f "$DIST/kryptos.iso" ]; then MODE=iso; else MODE=direct; fi ;;
    iso|direct) ;;
    *) die "usage: $0 [dist-dir] [auto|iso|direct]" ;;
esac
case "$EXPECT_ARCH" in ''|x86_64|aarch64) ;; *) die "unsupported EXPECT_ARCH: $EXPECT_ARCH" ;; esac
printf 'KryptOS artifact check: %s (%s)\n' "$DIST" "$MODE"
if [ "$MODE" = iso ]; then
    [ -s "$DIST/kryptos.iso" ] || die "missing or empty kryptos.iso"
    [ -f "$DIST/kryptos.iso.sha256" ] || die "missing kryptos.iso.sha256"
    command -v python3 >/dev/null || die "python3 is required for checksum verification"
    python3 - "$DIST" <<'CHECKSUM'
import hashlib, pathlib, re, sys
root = pathlib.Path(sys.argv[1])
manifest = (root / 'kryptos.iso.sha256').read_text().strip()
match = re.fullmatch(r'([0-9a-fA-F]{64}) [ *]kryptos\.iso', manifest)
if not match:
    sys.exit('[fail] expected one SHA-256 entry for kryptos.iso')
digest = hashlib.sha256()
with (root / 'kryptos.iso').open('rb') as artifact:
    for chunk in iter(lambda: artifact.read(1024 * 1024), b''):
        digest.update(chunk)
if digest.hexdigest() != match[1].lower():
    sys.exit('[fail] ISO checksum mismatch')
print('[ok] ISO SHA-256 matches')
CHECKSUM
    printf 'Integrity verified only; ISO architecture and UEFI boot remain untested.\n'
    [ -z "$EXPECT_ARCH" ] || die "EXPECT_ARCH requires direct mode; ISO architecture cannot be inferred from checksum"
    printf 'UEFI boot test: MEM=8192 ./scripts/46-smoke-iso.sh %q\n' "$DIST"
else
    command -v file >/dev/null || die "file is required"
    [ -s "$DIST/rootfs.ext4" ] || die "missing or empty rootfs.ext4"
    kernels=("$DIST"/vmlinuz-*)
    [ "${#kernels[@]}" -eq 1 ] && [ -s "${kernels[0]}" ] || die "expected exactly one nonempty vmlinuz-* kernel"
    file -b "$DIST/rootfs.ext4" | grep -q 'ext4 filesystem' || die "rootfs.ext4 is not an ext4 filesystem"
    description=$(file -b "${kernels[0]}")
    case "$description" in
        *ARM64*) arch=aarch64 ;;
        *bzImage*|*x86*) arch=x86_64 ;;
        *) die "unrecognized Linux kernel: $description" ;;
    esac
    printf '[ok] kernel architecture: %s\n' "$arch"
    [ -z "$EXPECT_ARCH" ] || [ "$arch" = "$EXPECT_ARCH" ] || die "expected $EXPECT_ARCH, found $arch"
    printf '[ok] direct-kernel bundle present (does not test GRUB/UEFI)\n'
    printf 'Boot test: ./scripts/41-boot-kryptos.sh %q\n' "$DIST"
fi

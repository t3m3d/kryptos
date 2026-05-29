#!/usr/bin/env bash
# Install kppm (the kryptoport package manager) onto a KryptOS system: the `ayo`
# command, the default /etc/kryptoport.conf, and a seeded recipe tree from the copy
# bundled in this repo (so it works before t3m3d/kryptoport-tree exists remotely).
# Run as root in the target system, or with KPPM_INSTALL_ROOT set to stage onto an
# LFS root (e.g. KPPM_INSTALL_ROOT=/mnt/lfs ./install-kppm.sh).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="${KPPM_INSTALL_ROOT:-/}"

install -Dm755 "$here/ayo" "${root%/}/usr/bin/ayo"

# default config (don't clobber an existing one)
if [ ! -f "${root%/}/etc/kryptoport.conf" ]; then
    install -Dm644 "$here/kryptoport.conf" "${root%/}/etc/kryptoport.conf"
    echo "[install-kppm] wrote ${root%/}/etc/kryptoport.conf"
fi

mkdir -p "${root%/}/var/lib/kryptoport/tree" \
         "${root%/}/var/lib/kryptoport/db" \
         "${root%/}/var/cache/kryptoport/src" \
         "${root%/}/var/cache/kryptoport/bin"

# Seed local recipes if the tree is empty (no git pull needed for v0).
if [ -z "$(ls -A "${root%/}/var/lib/kryptoport/tree" 2>/dev/null)" ]; then
    cp -a "$here/tree/." "${root%/}/var/lib/kryptoport/tree/"
    echo "[install-kppm] seeded recipe tree from bundle"
fi
echo "[install-kppm] ayo (kppm) installed to ${root%/}/usr/bin/ayo"
echo "[install-kppm] try:  ayo help   |   ayo search <term>   |   ayo install <pkg>"

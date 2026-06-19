#!/usr/bin/env bash
# Install the kix engine onto a KryptOS system and seed the recipe tree from the
# copy bundled in this repo (so kix works before t3m3d/kix-tree exists remotely).
# Run as root inside the target system (or with KIX_INSTALL_ROOT set for staging).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="${KIX_INSTALL_ROOT:-/}"

install -Dm755 "$here/kix" "${root%/}/usr/bin/kix"
mkdir -p "${root%/}/var/lib/kix/tree" "${root%/}/var/lib/kix/db" "${root%/}/var/cache/kix/src"

# Seed local recipes if the tree is empty (no git pull needed for v0).
if [ -z "$(ls -A "${root%/}/var/lib/kix/tree" 2>/dev/null)" ]; then
    cp -a "$here/tree/." "${root%/}/var/lib/kix/tree/"
    echo "[install-kix] seeded recipe tree from bundle"
fi
echo "[install-kix] kix installed to ${root%/}/usr/bin/kix"

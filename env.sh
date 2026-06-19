# KryptOS build environment — source before anything:  source env.sh
# Safe to source on any shell; only sets vars + umask.

# --- branding ---
export DISTRO_NAME="KryptOS"
export DISTRO_VERSION="0.1-dev"

# --- LFS target (match the LFS book you are following) ---
export LFS_VERSION="12.2"                       # the LFS release / book version
export LFS="${LFS:-/mnt/lfs}"                    # mount point of the new system
export LFS_TGT="$(uname -m)-lfs-linux-gnu"       # cross-compile target triple

# --- build settings ---
export LC_ALL=POSIX
export PATH="$LFS/tools/bin:/usr/bin:/bin"
export CONFIG_SITE="$LFS/usr/share/config.site"
# Parallel make. Drop to -j1 if a build races/breaks, then re-run.
if command -v nproc >/dev/null 2>&1; then
    export MAKEFLAGS="-j$(nproc)"
else
    export MAKEFLAGS="-j2"
fi

umask 022

# Where this repo lives (for the helper lib).
export KRYPTOS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

echo "[$DISTRO_NAME] env loaded — LFS=$LFS  version=$LFS_VERSION  target=$LFS_TGT  $MAKEFLAGS"

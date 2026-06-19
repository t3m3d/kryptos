#!/usr/bin/env bash
# Stage 0b — create the $LFS dir skeleton + the unprivileged 'lfs' build user with
# a clean env (LFS chapter 4). Run as ROOT on the Linux host, after $LFS is
# mounted.  Usage:  sudo -E bash scripts/03-setup-user-env.sh
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run as root (sudo -E)"; exit 1; }
: "${LFS:?source env.sh first (sudo -E preserves it)}"
[ -d "$LFS" ] || { echo "$LFS not mounted"; exit 1; }

echo "[KryptOS] creating $LFS skeleton"
mkdir -pv "$LFS"/{etc,var,tools} "$LFS"/usr/{bin,lib,sbin}
for i in bin lib sbin; do ln -sfv usr/$i "$LFS/$i"; done
case "$(uname -m)" in x86_64) mkdir -pv "$LFS/lib64";; esac

echo "[KryptOS] creating 'lfs' user"
getent group lfs >/dev/null || groupadd lfs
id lfs >/dev/null 2>&1 || useradd -s /bin/bash -g lfs -m -k /dev/null lfs
chown -v lfs "$LFS"/{usr{,/*},lib,var,etc,bin,sbin,tools} 2>/dev/null || true
case "$(uname -m)" in x86_64) chown -v lfs "$LFS/lib64";; esac
chown -v lfs "$LFS/sources" 2>/dev/null || true

echo "[KryptOS] writing lfs login env (.bash_profile / .bashrc)"
cat > /home/lfs/.bash_profile <<'EOF'
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF
cat > /home/lfs/.bashrc <<EOF
set +h
umask 022
LFS=$LFS
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/usr/bin
if [ ! -L /bin ]; then PATH=/bin:\$PATH; fi
PATH=\$LFS/tools/bin:\$PATH
CONFIG_SITE=\$LFS/usr/share/config.site
export LFS LC_ALL LFS_TGT PATH CONFIG_SITE
export MAKEFLAGS=-j\$(nproc)
EOF
chown lfs:lfs /home/lfs/.bash_profile /home/lfs/.bashrc

echo "[KryptOS] done. Now: 'su - lfs', clone this repo, and run scripts/10-toolchain.sh"
echo "          (set a password with 'passwd lfs' first if you want to log in directly)"

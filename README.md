# KryptOS

A Linux distribution built from scratch - the `krypt-` family's own OS. Boots to a
login shell, built from the toolchain up (Linux From Scratch), branded KryptOS.

> **Goal of v0:** a **bootable base system** - cross-toolchain - ~80 core
> packages - kernel - GRUB - it logs in. Beyond-base (networking stack, desktop,
> Krypton userland) comes later.

## Important: where this runs

The build runs on a **Linux build host** - Agent L's ParrotOS box or a Linux VM -
**not on macOS**. macOS can't compile a Linux toolchain. Agent M writes/maintains
these scripts and debugs failures; L (or Brian) runs them on Linux.

## Approach

This repo is **build automation around the LFS book**, not a fork of it. It does
the parts that are safe to standardize (host check, source fetch + md5 verify,
env, logging, resume) and tracks the chapter-by-chapter build order. Each
chapter's package recipes are filled in and run together - pinned to the exact
LFS book version so versions/patches/md5s line up.

Pick your LFS version in `env.sh` (`LFS_VERSION`) and follow that book.

## Quick start (on the Linux host)

```sh
source env.sh                 # config: $LFS mount, version, target triple, flags
./scripts/00-host-check.sh    # verify the host has the required build tools
#   ... prepare a disk/partition: see scripts/01-prepare-disk.md (DESTRUCTIVE)
sudo mkdir -pv "$LFS" && sudo mount <your-lfs-partition> "$LFS"
./scripts/02-fetch-sources.sh # download + md5-verify all sources
./scripts/51-fetch-devtools.sh # first-ISO source distro tools: curl, git, CA certs
./scripts/52-fetch-zink.sh    # Vulkan bits for Hyprland zink/lavapipe software rendering
#   ... then build chapter by chapter (see manifest/build-order.txt + PROGRESS.md)
```

## Layout

```
env.sh                     all config (source it before anything)
lib/build.sh               helper fns: logging, extract, build-in-dir, checkpoint/resume
scripts/00-host-check.sh   host build-tool + version check
scripts/01-prepare-disk.md GUIDED disk prep (manual - it's destructive)
scripts/02-fetch-sources.sh fetch wget-list + md5sums, verify
manifest/build-order.txt   the full package build order (the roadmap)
PROGRESS.md                checklist - tick chapters as they pass
```

## Status

Scaffold only. Toolchain/system recipes are built + run with M live, chapter by
chapter, on the Linux host. Nothing here is destructive without you setting a
device + confirming.

## Branding

KryptOS - pairs with Krypton, KryptScript, kryptonbytes, yubiKrypt. Codename baked
into `env.sh` (`DISTRO_NAME`); shows up in `/etc/os-release`, the hostname, and
the boot entry when we get there.

## Host prep on Arch Linux

The build host (L's box, or a Linux VM) is Arch. Install the LFS host tools:

```sh
sudo pacman -S --needed base-devel bison gawk texinfo python wget
# base-devel covers gcc, make, binutils, patch, m4, sed, grep, gzip, tar, etc.
sudo ln -sf bash /bin/sh    # if /bin/sh isn't bash; LFS expects bash-y sh during build
```

Then `./scripts/00-host-check.sh` should pass. Arch ships very current tool
versions - if a host-tool version is *ahead* of what the LFS book lists, it's
usually fine, but note it if a build breaks.

## Run order (Linux host)

```sh
source env.sh
./scripts/00-host-check.sh
# prepare + mount $LFS  (scripts/01-prepare-disk.md - VM/loop recommended)
./scripts/02-fetch-sources.sh
sudo -E bash scripts/03-setup-user-env.sh
su - lfs                       # clone this repo as lfs, then:
source env.sh && source lib/build.sh
./scripts/10-toolchain.sh      # Stage 1 (cross toolchain)
./scripts/20-temp-tools.sh     # Stage 2 temporary tools
sudo -E bash scripts/30-enter-chroot.sh ch7.sh
sudo -E bash scripts/30-enter-chroot.sh ch8.sh
sudo -E bash scripts/30-enter-chroot.sh ch8-init.sh
sudo -E bash scripts/30-enter-chroot.sh ch8b.sh
sudo -E bash scripts/30-enter-chroot.sh ch9.sh
sudo -E bash scripts/30-enter-chroot.sh ch10-kernel.sh
sudo -E bash scripts/30-enter-chroot.sh ch15-devtools.sh
sudo -E bash scripts/30-enter-chroot.sh ch16-ssh.sh
sudo -E bash scripts/30-enter-chroot.sh ch17-uefi.sh
OUT="$PWD/dist" LFS="$LFS" sudo -E bash scripts/40-make-image.sh
./scripts/43-verify-boot-artifact.sh dist
./scripts/41-boot-kryptos.sh dist
OUT="$PWD/dist" LFS="$LFS" sudo -E bash scripts/44-make-iso.sh
MEM=8192 ./scripts/45-boot-iso.sh dist
```

## First live ISO

`44-make-iso.sh` creates `dist/kryptos.iso`. The live ISO currently includes
Git, curl, CA certificates, Dropbear SSH, UEFI support tools, and a manual disk installer.

Default live login:

```sh
root
kryptos
```

Install to a VM disk from the live ISO:

```sh
cat /proc/partitions
kryptos-install --yes /dev/sda
halt
```

`kryptos-install` is destructive and expects a whole target disk. It defaults to
UEFI/GPT when the live ISO was booted under UEFI, and BIOS/MBR otherwise. You can
force a mode with `--uefi` or `--bios`:

```sh
kryptos-install --yes /dev/sda --uefi
kryptos-install --yes /dev/sda --bios
```

Hyper-V Generation 2 is the preferred UEFI path. Generation 1 remains BIOS
fallback. Hyper-V usually exposes the first virtual disk as `/dev/sda`. After
install, remove the ISO from the VM DVD drive or move the hard disk first in boot
order.

Dropbear SSH is installed but intentionally does not autostart in this early ISO.
Start it manually after boot when you want remote access:

```sh
/etc/rc.d/init.d/dropbear start
ip addr
```

Then connect from the host with `ssh root@<vm-ip>`.

## The build VM (set up 2026-06-19)

A Lima VM **`kryptos`** is the build host on Brian's Mac: **Ubuntu 25.10,
aarch64, 4 CPU / 8 GB / 60 GB**. (The Arch template crashed on Apple VZ; Ubuntu
boots clean. arm64 native = much faster than emulated x86_64.)

```sh
limactl start kryptos                  # boot it
limactl shell kryptos                  # get a shell
```

Host-prep (Ubuntu/apt - already done on the VM):
```sh
sudo apt-get update
sudo apt-get install -y build-essential bison gawk texinfo m4 patch wget python3 xz-utils gettext
```

Repo lives at `~/kryptos` inside the VM; `$LFS=/mnt/lfs` on the VM disk.

### Heads-up: we're on aarch64, the LFS book is x86_64

Building arm64 means following the **LFS-ARM / cross-lfs deltas** on top of the
mainline 12.2 book - mostly the dynamic-loader symlinks and a few configure bits.
`10-toolchain.sh` already branches on `$ARCH` for the glibc loader; expect to
adjust a couple more `VERIFY` spots live during Stage 1. (Host gcc is 15.2 - newer
than the book; usually fine, occasionally needs a per-package nudge.)


## Hyprland software-rendering fix

For the first graphical image, build the desktop stack with Mesa zink over
lavapipe. Plain llvmpipe EGL has hit native-fence/page-flip failures in
QEMU/UTM. The intended order after desktop phase 1 is:

```sh
./scripts/52-fetch-zink.sh
# inside chroot, after ch11-desktop-p1.sh and before rebuilding Mesa:
bash /root/kryptos/scripts/chroot/ch16-zink.sh
rm -f /build-state/d_mesa.done   # force Mesa rebuild if phase 2 already ran
bash /root/kryptos/scripts/chroot/ch11-desktop-p2.sh
bash /root/kryptos/scripts/chroot/ch12-session.sh
```

`40-make-image.sh` currently creates the bootable `rootfs.ext4` plus kernel for
QEMU/UTM. Verify it with:

```sh
./scripts/43-verify-boot-artifact.sh dist
./scripts/41-boot-kryptos.sh dist
```

`40-make-image.sh` creates the direct QEMU rootfs image. `44-make-iso.sh` creates
a bootable live ISO at `dist/kryptos.iso`; it uses a small initramfs to unpack
the root filesystem to RAM, so test it with 8 GB+ RAM.




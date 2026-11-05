# KryptOS

A Linux distribution built from scratch - the `krypt-` family's own OS. Boots to
the `ly` TUI login manager and a Hyprland desktop, built from the toolchain up
(Linux From Scratch), branded KryptOS.

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
./scripts/54-fetch-quickshell.sh # Qt 6 + native Quickshell shell
./scripts/56-fetch-network.sh # verified DHCP client for wired networking
./scripts/55-fetch-firmware.sh # verified AMD CPU/GPU firmware source
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
./scripts/50-fetch-desktop.sh
./scripts/52-fetch-zink.sh
./scripts/54-fetch-quickshell.sh
./scripts/56-fetch-network.sh # verified DHCP client for wired networking
./scripts/55-fetch-firmware.sh
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
sudo -E bash scripts/30-enter-chroot.sh ch21-network.sh
sudo -E bash scripts/30-enter-chroot.sh ch10-kernel.sh
sudo -E bash scripts/30-enter-chroot.sh ch20-hardware-gpu.sh
sudo -E bash scripts/30-enter-chroot.sh ch15-devtools.sh
sudo -E bash scripts/30-enter-chroot.sh ch16-ssh.sh
sudo -E bash scripts/30-enter-chroot.sh ch17-uefi.sh
sudo -E bash scripts/30-enter-chroot.sh ch18-grub-efi.sh
sudo -E bash scripts/30-enter-chroot.sh ch11-desktop-p1.sh
sudo -E bash scripts/30-enter-chroot.sh ch16-zink.sh
sudo -E bash scripts/30-enter-chroot.sh ch11-desktop-p2.sh
sudo -E bash scripts/30-enter-chroot.sh ch11-desktop-p3.sh
sudo -E bash scripts/30-enter-chroot.sh ch11-desktop-p5-xcursor.sh
sudo -E bash scripts/30-enter-chroot.sh ch11-desktop-p4.sh
sudo -E bash scripts/30-enter-chroot.sh ch13-tools.sh
sudo -E bash scripts/30-enter-chroot.sh ch14-foot.sh
sudo -E bash scripts/30-enter-chroot.sh ch19-quickshell.sh
sudo -E bash scripts/30-enter-chroot.sh ch12-session.sh
OUT="$PWD/dist" LFS="$LFS" sudo -E bash scripts/40-make-image.sh
./scripts/43-verify-boot-artifact.sh dist
./scripts/41-boot-kryptos.sh dist
OUT="$PWD/dist" LFS="$LFS" sudo -E bash scripts/44-make-iso.sh
MEM=8192 ./scripts/45-boot-iso.sh dist
TIMEOUT=240 MEM=8192 ./scripts/46-smoke-iso.sh dist
```

## First live ISO

`44-make-iso.sh` creates `dist/kryptos.iso` plus `dist/kryptos.iso.sha256`.
`46-smoke-iso.sh` boots it with UEFI QEMU and requires a serial login prompt.
The ISO also carries a legacy-BIOS El Torito entry, so it boots on either
firmware. The live ISO currently includes
Git, build tools, the Zig toolchain (`/opt/zig-0.17.1`, also on `PATH`), the
`ly` TUI login manager on tty1, Dropbear SSH, UEFI and BIOS boot, Hyprland with
Quickshell, AMD and Intel GPU firmware, and a manual disk installer.

`ly` draws on tty1 and offers the KryptOS Hyprland session; tty2/tty3 and the
serial console stay available as a rescue shell. Type the user name at the
login field. Default live login:

```sh
root
kryptos
```

It runs as the rc.d service `ly`, the way upstream's sysvinit unit does (LFS has
no `start-stop-daemon`, so the service backgrounds the `setsid -c` launcher and
keeps its pid). Leaving it in `inittab` made every finished session look like a
failed respawn: sysvinit banned tty1 for five minutes. Control it with:

```sh
/etc/rc.d/init.d/ly status
/etc/rc.d/init.d/ly restart
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

The image carries firmware for AMD (`amdgpu`) and Intel (`i915`) graphics, so
one ISO boots on either. AMD gets the native `radeonsi` driver; Intel has no
`iris` driver in this image and falls back to Mesa's llvmpipe software
renderer, because `iris` needs `intel_clc`, which needs `libclc` and clang, and
building clang inside the LLVM tree adds hours to the build. `--gpu` decides
which firmware gets written to the target; it defaults to detecting the GPU the
live system is running on, and prunes the other vendor's payload (about 110 MB
of AMD firmware) to save disk. Pass `--gpu=amd`, `--gpu=intel` or `--gpu=both`
to override, which is useful when installing to a machine other than the one
you booted.

```sh
kryptos-install --yes /dev/sda --gpu=intel
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




## Wired network migration

On the Linux build host, update the repository, fetch the DHCP source with
`./scripts/56-fetch-network.sh`, then run
`sudo -E bash scripts/30-enter-chroot.sh ch21-network.sh` and rebuild the ISO.
The network stage runs its own checkpoints, so existing `ch9` builds need no
checkpoint deletion. It does not start networking inside the build chroot.

The image uses dhcpcd to discover wired `eth*` and `en*` interfaces, including
QEMU and Hyper-V devices. Address, gateway, and DNS come from DHCP; the daemon
starts in the background and handles late carrier. Wi-Fi authentication is not
included. A DHCP server is required; Hyper-V needs a connected virtual switch.

The exact old QEMU static configuration is backed up and removed. Other LFS
`ifconfig.*` files retain ownership of their interfaces and are excluded from
DHCP. The old generated public DNS list is backed up before replacement.

After boot, verify actual networking (a login prompt alone is insufficient):

```sh
ip -br addr
ip route
cat /etc/resolv.conf
curl -I --connect-timeout 10 https://github.com
```

Manual service control: `/etc/rc.d/init.d/kryptos-network start` or `stop`.

## Desktop startup and diagnostics

After updating an existing Linux build, rerun
`sudo -E bash scripts/30-enter-chroot.sh ch12-session.sh` before packaging.
The session stage installs the current launcher and diagnostic command from
`config/`. Start the desktop manually from the graphical console with `start-hypr`.
It currently requires root, prefers AMDGPU, rejects duplicate sessions, and
waits up to 30 seconds for a new Wayland socket. Set `STARTUP_TIMEOUT=60` for
slower software-rendered guests. Socket readiness is not proof of a rendered
frame or a working Quickshell process.

If boot, networking, or desktop startup fails, run `kryptos-diagnose`. It writes
an owner-readable report under `/tmp` containing boot mode, kernel command line,
DRM drivers, network addresses/routes/DNS, process information, and recent
Hyprland/kernel logs. Missing diagnostic tools are reported without aborting.
The command makes no network requests or configuration changes and never
uploads the report. Review the report before sharing: it can include machine
and network information. Existing output files are never overwritten.

Offline regression checks on Mac or Linux:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v
```

These exercise launcher/service behavior with fixtures, not the actual GPU,
DHCP server, GRUB boot, or target Linux build.

## x86_64 ISO testing on macOS

The local base ISO in `dist/x86_64` reached serial login in macOS QEMU on
2026-10-31 (332 seconds). It does not include Hyprland/Quickshell. Launch it:

```sh
./scripts/47-test-macos-iso.sh dist/x86_64 graphical
./scripts/47-test-macos-iso.sh dist/x86_64 headless
```

The launcher checks the checksum, uses Homebrew QEMU's UEFI firmware and
software x86 emulation, and gives the guest 8 GiB RAM, one CPU, and HPET disabled.
These defaults match the successful test; four-CPU attempts stalled during boot.
Graphical mode uses Cocoa and virtio VGA. Images containing desktop packages
can start Hyprland from tty1. Headless mode allows 600 seconds to
reach serial login. Stop other large VMs before booting the ISO. Apple Silicon
cannot use HVF to accelerate an x86 guest; builds and boot tests are slower.

The local Lima `krypton` VM is x86_64 and can build KryptOS independently of
Windows. Current scripts are copied to `~/kryptos-macos-build` inside that VM;
`/mnt/lfs` holds the preserved partial build. Do not mistake its VM disk capacity
for free physical Mac storage. The Mac had about 25 GiB free when work resumed;
check host space before proceeding to the full desktop and ISO staging.

## Resumable base ISO build on the Mac's Linux VM

A smaller first milestone is a boot-validation ISO built from the KryptOS LFS
base, without the Hyprland/Quickshell desktop. In the x86_64 Linux VM, run as the
unprivileged owner of a prepared LFS tree, with passwordless sudo available:

```sh
LFS=/mnt/lfs OUT="$HOME/kryptos-base-dist" bash scripts/60-build-base-iso.sh
```

The pipeline reuses existing package checkpoints, stops on failure, and writes
`build-status.txt` beside the resulting ISO. It installs into the LFS chroot,
not the build host. The UEFI GRUB modules are built before their validation.
After packaging, copy both `kryptos.iso` and `kryptos.iso.sha256` to a Mac
folder, then run `scripts/47-test-macos-iso.sh <folder> headless`. Successful
packaging/checksum verification does not prove a successful boot or desktop.

To attach a Mac-side collector to an already-running base ISO build:

```sh
bash scripts/61-collect-macos-base-iso.sh
```

This waits for the Linux pipeline's READY status, copies the ISO/checksum into
Mac `dist/x86_64`, verifies integrity, stops the `krypton` builder VM to free
memory, then runs the headless QEMU smoke test. Check
`dist/x86_64/mac-boot-status.txt` for the actual outcome. Base ISO contains no
Hyprland/Quickshell; a serial-login PASS validates boot only.

## Durable one-shot Mac runtime

`python3 scripts/62-prepare-macos-jobs.py` prepares explicit launchd definitions
under `~/Library/Application Support/KryptOS/iso-build/launchd`. It does not
start anything. These definitions use KeepAlive=false so successful or failed
builds are not silently restarted. Runtime scripts and logs stay outside
Documents because launchd may not have access to that protected folder.

The current Mac uses these jobs for VM, build, and collector respectively:
`local.kryptos.build-vm`, `local.kryptos.base-build`, `local.kryptos.iso-collect`.
The builder and collector prevent idle system sleep while working. Logout,
shutdown, or deliberate service removal can still interrupt a build; resume
from package checkpoints. Job files are not installed as login items.

`dist/x86_64` links to the runtime artifact folder on this Mac. Its
`mac-boot-status.txt` records connection failures and timestamped live phases.
A saved RUNNING entry alone does not prove a process is still alive; inspect
the relevant launchd job and Linux logs when resuming after interruption.

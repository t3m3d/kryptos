# KryptOS active handoff

**Status (2026-08-01): fresh x86_64 UEFI live ISO boots Hyprland and Quickshell.**

## Verified

- Preserved `/mnt/lfs` build root contains Hyprland, Quickshell, Mesa zink/lavapipe, Vulkan loader, build tools, Git, Dropbear, UEFI GRUB, and AMD firmware.
- `scripts/44-make-iso.sh` produced `dist/kryptos.iso` (2,450,536,448 bytes).
- Windows QEMU + WHPX booted the ISO through EDK2 UEFI, unpacked the RAM root, entered SysV runlevel 3, configured `eth0`, and reached `kryptos login:`.
- A `virtio-vga` boot launched `start-hypr`; both a Wayland socket and Quickshell process were verified. QEMU framebuffer capture rendered the desktop.
- Serial console now works without the old `s0 respawning too fast` failure.
- `dist/kryptos.iso.sha256` records the artifact checksum.

## Next priority

1. Boot the same ISO on Zen 3 + RX 5700 hardware and inspect firmware/DRM logs.
2. Replace fixed `eth0` QEMU networking with hardware-safe DHCP discovery.
3. Add a normal live user and remove root autologin before public distribution.
4. Add Intel graphics support, then NVIDIA support.
5. Retest disk installation from this desktop image.

## Commands

```sh
OUT="$PWD/dist" LFS=/mnt/lfs sudo -E bash scripts/44-make-iso.sh
TIMEOUT=240 MEM=8192 ./scripts/46-smoke-iso.sh dist
```

Historical zink root-cause notes remain in `docs/HANDOFF-L-hyprland-present.md`.

## x86_64 continuation (2026-10-07)

- Focus remains x86_64; ARM64 work is deferred.
- This Mac checkout has the older ARM64 direct-kernel bundle in `dist/`, not
  the August x86_64 ISO. Do not use that bundle as x86_64 boot evidence.
- Artifact verification now prefers the live ISO when present and checks its
  SHA-256 manifest. Use `scripts/43-verify-boot-artifact.sh dist iso` to require
  the ISO explicitly. This verifies integrity, not ISO architecture or boot.
- `EXPECT_ARCH=x86_64 scripts/43-verify-boot-artifact.sh dist direct` rejects
  an ARM64 direct-kernel bundle. Direct mode requires exactly one kernel.
- The UEFI ISO launcher now discovers Homebrew QEMU firmware on Apple Silicon
  and Intel Macs, and preserves explicit firmware overrides.
- Verified shell syntax, checksum success/failure cases, current ARM64
  detection, and firmware argument selection using a fake QEMU executable.
  No new ISO build or actual x86_64 guest boot has been performed on this Mac.
- Next: obtain the August ISO and checksum, verify integrity, then run the
  serial boot smoke test. Hyprland still needs a separate graphical test;
  the serial smoke test proves only that boot reaches login.

## Wired DHCP implementation (2026-10-08)

- `scripts/56-fetch-network.sh` fetches dhcpcd 10.2.2 with the upstream SHA-256.
- `scripts/chroot/ch21-network.sh` builds/tests it with privilege separation,
  installs a background SysV service, and migrates the exact old QEMU defaults.
- Wired `eth*` / `en*` discovery handles device naming and late carrier. Existing
  administrator per-interface configurations are excluded from automatic DHCP.
- Fresh ch9 configuration no longer writes QEMU's static address or public DNS.
- ISO packaging requires the DHCP client and service; update preserved Linux
  builds with ch21 before packaging. README contains the updated sequence.
- Offline service and migration regression tests pass. Source archive downloaded
  and its SHA-256 independently verified. No target Linux compile or live DHCP
  lease test has been performed yet. Hardware networking remains unchecked in
  PROGRESS.md until an updated x86_64 image acquires an address, route, and DNS.

On the Linux host with the preserved `/mnt/lfs` tree:

```sh
LFS=/mnt/lfs ./scripts/56-fetch-network.sh
LFS=/mnt/lfs sudo -E bash scripts/30-enter-chroot.sh ch21-network.sh
OUT="$PWD/dist" LFS=/mnt/lfs sudo -E bash scripts/44-make-iso.sh
./scripts/43-verify-boot-artifact.sh dist iso
TIMEOUT=240 MEM=8192 ./scripts/46-smoke-iso.sh dist
```

Serial login does not prove networking or desktop presentation. Follow README's
post-boot network checks and separately start Hyprland.

## Mac-side desktop preparation (2026-10-08)

- Desktop launcher moved to `config/start-hypr`, installed by ch12. Existing
  GPU selection is preserved. Added root/dependency checks, session locking,
  rejection of existing Wayland sockets, configurable 30-second startup timeout,
  and compositor cleanup on interrupted/failed launches.
- `config/kryptos-diagnose`, also installed by ch12, collects a local-only
  boot/graphics/network report. Output is private and refuses overwrite.
- Rerun ch12 on the preserved Linux build before producing the next ISO.
- Offline fixtures cover early compositor exit, timeout cleanup, duplicate lock,
  existing socket, missing DRM, and report overwrite refusal. Runtime graphics,
  Quickshell, DHCP lease, and ISO boot still need the Windows x86_64 build host.

## Local x86 build recovery (2026-10-08)

- Started the existing x86_64 Lima VM `krypton`; installed standard Linux
  build prerequisites and xorriso. Created separate `~/kryptos-macos-build`
  workspace copied from current Mac scripts (not a Git clone).
- `/mnt/lfs` had ~2 GiB of partial build state. Binutils/GCC cross compilers
  existed, but linux-headers, glibc, and libstdcxx checkpoints were invalid.
  Old header recipe copied headers to `/usr/asm` etc., leaving `/usr/include`
  absent. Old glibc/C++ logs showed failures despite done markers.
- Archived these three markers and their logs under
  `/mnt/lfs/checkpoint-audit-20261008`, restored missing bin/lib/sbin symlinks,
  and launched current Stage 1 to repair headers + glibc + C++ runtime.
  Subsequent progress must be checked in `/mnt/lfs/build-logs` / `build-state`.
- `47-test-macos-iso.sh` provides checked graphical/headless ISO boot commands.
  QEMU argument selection tested with a fake executable; no KryptOS ISO boot
  claimed. The actual ISO still must be built from completed x86 Linux tree.
- Host has ~25 GiB free. Full desktop build may need additional host storage.

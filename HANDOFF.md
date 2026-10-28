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

## Local x86 ISO pipeline (2026-10-22)

- Cross-toolchain recovery from October 8 completed successfully: kernel headers,
  glibc, and libstdc++ installed. Temporary-tools compilation resumed October 22.
- Disabled unused `containerd.user/system` provisioning in local Lima `krypton`
  to avoid a startup download stall. VM remains x86_64, six CPUs, 10 GiB RAM.
- Fixed patch lookup: ch8/ch8-init previously passed `.patch` prefixes to
  tar-archive-only `find_src`. New `find_patch` rejects missing/ambiguous patches.
  Regression tests cover patch lookup and failure checkpoint handling.
- Added `scripts/60-build-base-iso.sh`: Linux x86_64 pipeline for temporary
  tools, ch7, final base, network, kernel, UEFI GRUB, session diagnostics, ISO
  packaging and checksum verification. Stops on errors; existing package
  checkpoints allow resuming. Does not build the Hyprland/Quickshell desktop.
- Pipeline running under nohup in the local VM, waiting for the already-active
  temporary-tools process before continuing. Monitor with:

```sh
limactl shell krypton -- sh -c 'tail -30 "$HOME/kryptos-base-build.log"'
# Determine actual guest HOME with: limactl shell krypton -- printenv HOME
# Log is $HOME/kryptos-base-build.log; status/ISO under $HOME/kryptos-base-dist.
```

- No ISO or QEMU boot success claimed. First milestone is a base boot-validation
  ISO; desktop remains a separate build/test step. Mac now has ~80 GiB free.

- Core source manifest verified in full, including the previously missing
  man-db archive fetched from the LFS mirror. UEFI and DHCP sources available.
- `scripts/61-collect-macos-base-iso.sh` attaches to the running pipeline. When
  READY, it copies ISO/checksum to Mac `dist/x86_64`, verifies the checksum,
  stops the builder VM to release RAM, and runs the headless Mac QEMU test.
  Its local status is `dist/x86_64/mac-boot-status.txt`; log is
  `dist/x86_64/collection.log`. It stops on build/transfer/boot failure.
- Fixed serial-smoke launcher to invoke 45 with bash, since that tracked script
  lacks executable permissions. Fixture integration covers collection, smoke
  success, and failed-build gating. A fixture PASS is not a real guest boot.
- Neither ISO packaging nor actual boot has completed at this handoff.

## Continued Linux validation (2026-10-22)

- Temporary tools progressed through m4, ncurses, and Bash; coreutils is next.
- dhcpcd 10.2.2 configured and compiled separately on the x86 Linux build host
  with the same privilege-separation configuration as ch21. Upstream `make test`
  passed, installation into an isolated DESTDIR succeeded, and the staged
  executable reports `INET ARP ARPing IPv4LL INET6 DHCPv6 AUTH PRIVSEP`.
- Validation tree/logs are under guest `$HOME/kryptos-network-validation`.
  No daemon was started and the VM's network configuration was not changed.
  This proves a Linux host build, not the final LFS-target build or a DHCP lease.
- Linux base-ISO pipeline remains queued behind temporary tools; Mac collector
  remains active, waiting for actual ISO output. No ISO/QEMU success yet.

## Runtime blocker repair (2026-10-27)

- Confirmed GCC pass 2 completed on October 22. Build had reached ch7/gettext
  before VM shutdown; no package failure was recorded at that stop.
- Recovered the VM, removed an orphaned QEMU process after requesting a clean
  guest shutdown, and resumed from completed checkpoints.
- Replaced `launchctl submit` jobs: that interface set KeepAlive, causing
  unwanted restarts. New explicit plists use RunAtLoad=true, KeepAlive=false.
  They are loaded one-shot jobs, not recurring tasks or login items.
- macOS launchd logs confirmed collector spawn failure opening stdout under
  Documents: `Operation not permitted`. Moved runtime scripts, logs, job
  definitions, and artifacts into the user-owned directory:
  `~/Library/Application Support/KryptOS/iso-build`.
- `scripts/62-prepare-macos-jobs.py` reproduces those definitions and copies
  scripts atomically. It prepares files only, never loads or stops jobs.
- Three launchd jobs verified running: `local.kryptos.build-vm`,
  `local.kryptos.base-build`, `local.kryptos.iso-collect`. Builder and collector
  hold idle-sleep assertions while active. A reboot/logout still ends the run;
  package checkpoints remain the recovery mechanism.
- `dist/x86_64` now links to runtime `dist/x86_64`; prior logs preserved under
  `dist/x86_64.before-launchd-*`. `dist/active-macos-run.txt` records the runtime.
- Fixed status handling: collector creates its trap before connecting; a failed
  connection replaces stale WAITING. Polls carry timestamps; interrupted build
  phases are recorded. Optional dependency PIDs are validated against cmdline.
- Fixed ch7 symlink reruns with GNU ln -T, avoiding nested `/var/run/run` links.
- Tests cover stale status on connection failure, one-shot plist properties,
  unprotected runtime paths, and safe atomic script replacement. Existing
  network/build/desktop regressions also pass.
- Current actual stage: ch7/gettext. No ISO build or QEMU boot success claimed.

Read current artifact status with:

```sh
cat dist/x86_64/mac-boot-status.txt
```

Inspect services with `launchctl print gui/$(id -u)/<label>`. Definitions live
under the runtime `launchd/` folder. For a fresh load, bootstrap the VM plist,
wait until `limactl shell krypton -- true` works, then bootstrap builder and
collector plists. For already-loaded inactive jobs use `launchctl kickstart`
instead. Do not use `launchctl submit` for these one-shot jobs.

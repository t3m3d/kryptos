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

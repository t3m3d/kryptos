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

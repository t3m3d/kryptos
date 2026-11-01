# KryptOS v0 progress

- [x] Host and source toolchain prepared
- [x] Stage 1 cross toolchain
- [x] Stage 2 temporary tools
- [x] Stage 3 chroot tools
- [x] Stage 4 final base system
- [x] Stage 5 system configuration
- [x] Stage 6 kernel and UEFI GRUB
- [x] Stage 6b Git, CA certificates, build tools, and Dropbear
- [x] Hyprland, Quickshell, Mesa zink/lavapipe, and AMD firmware built
- [x] UEFI live ISO boots to serial login
- [x] Fresh ISO starts Hyprland and Quickshell with `virtio-vga`
- [x] UEFI disk installer previously boots installed system
- [ ] Zen 3 / RX 5700 physical boot
- [ ] Hardware-safe DHCP networking (build/service implemented; Linux host compile/tests pass; LFS target + lease test pending)
- [ ] Non-root live session and public-release hardening
- [ ] Retest disk installation from current desktop ISO
- [ ] Intel graphics support
- [ ] NVIDIA graphics support

## Latest proof

2026-08-01 Windows QEMU/WHPX smoke reached serial login, launched Hyprland,
verified a Wayland socket and Quickshell process, and captured a rendered frame.
Fresh artifact: `dist/kryptos.iso`, SHA-256 in `dist/kryptos.iso.sha256`.

## Mac x86_64 rebuild (2026-10-27)

- [x] Stage 1 cross toolchain verified and installed
- [x] Stage 2 temporary tools, including GCC pass 2
- [x] One-shot VM/build/collector runtime repaired and verified active
- [x] Stage 3 chroot tools
- [x] Final base, kernel, DHCP target build, UEFI GRUB
- [x] Package current base ISO and verify real macOS QEMU boot
- [ ] Add and verify Hyprland/Quickshell in local x86_64 image

2026-10-29: final GCC and OpenSSL completed. Fixed kmod's missing pkg-config
dependency by moving pkgconf before kmod in ch8; resumed from existing package
checkpoints. Final base system still in progress; no local ISO boot proof yet.

2026-10-31: base ISO reached `kryptos login:` in a real macOS QEMU UEFI
boot in 332 seconds. Verified configuration: one virtual CPU, q35,hpet=off,
TCG, 8192 MiB RAM. Four-CPU attempts stalled. ISO and checksum reside in
dist/x86_64; serial evidence is iso-smoke.log. Hyprland/Quickshell are absent;
DHCP lease and desktop rendering remain unverified. Boot also reported a
missing pidof utility in the syslog startup script; serial login still passed.

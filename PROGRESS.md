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
- [x] Add and verify Hyprland/Quickshell in local x86_64 image
- [x] Bar/dock icons render (Nerd Font + Noto Color Emoji installed in the image)

2026-10-29: final GCC and OpenSSL completed. Fixed kmod's missing pkg-config
dependency by moving pkgconf before kmod in ch8; resumed from existing package
checkpoints. Final base system still in progress; no local ISO boot proof yet.

2026-11-06: icons rendered as empty blocks because the image shipped only DejaVu
while config/quickshell asks for `Symbols Nerd Font` (39 uses) and Noto Color
Emoji. Added both to scripts/50-fetch-desktop.sh and a `d_fonts-nerd` step in
ch13-tools.sh (SymbolsNerdFont tarball + the Noto ttf unpacked from Debian's
fonts-noto-color-emoji .deb), rebuilt the ISO and booted it under QEMU
(virtio-vga): start-hypr from the serial console draws the bar glyphs, workspace
dots, launcher pill and dock icons, and fc-match inside the image resolves both
families to /usr/share/fonts/{nerd-symbols,noto-emoji}. Frames saved as
dist/live-desktop.png and dist/bar-zoom.png.

2026-10-31: base ISO reached `kryptos login:` in a real macOS QEMU UEFI
boot in 332 seconds. Verified configuration: one virtual CPU, q35,hpet=off,
TCG, 8192 MiB RAM. Four-CPU attempts stalled. ISO and checksum reside in
dist/x86_64; serial evidence is iso-smoke.log. Hyprland/Quickshell are absent;
DHCP lease and desktop rendering remain unverified. Boot also reported a
missing pidof utility in the syslog startup script; serial login still passed.

## Krypton toolchain in the ISO (2026-11-12)

- [x] `kcc` (Linux x86_64, 2.4.4 driver) + `kr` installed into the image at
  `/usr/local/krypton`, symlinked into `/usr/bin` and `/usr/local/bin`,
  `KRYPTON_ROOT=/usr/local/krypton` via `/etc/profile.d/krypton.sh`.
- [x] chroot stage: `scripts/chroot/ch23-krypton.sh`; host-side driver:
  `scripts/64-install-krypton.sh` (stages `krypton-2.5.0-alpha.tar.zst` into
  `/mnt/lfs/sources`, installs, repackages the live ISO, collects to `dist/fast`).
- [x] Trap: the driver self-hosts a broken `elf_host` when
  `compiler/linux_x86/elf_host` is missing/stale — emitted binaries drop the
  first byte of every string. ch23 ships the committed
  `bootstrap/elf_host_linux_x86_64` (+ `optimize_host`) so no self-host runs.
- [x] Live ISO boots under macOS QEMU (serial login; 145s on the 2026-11-12
  01:54 ISO, 89s on the 2026-11-12 07:58 rebuild); `kcc --version` OK;
  `kcc -r hello.k` prints `kryptos-krypton-ok`.
  Note: `kr version` prints nothing (not a real subcommand); use `kcc --version`.
- socam: not installed (out of scope this round). Objective-K: installed in
  the 2026-11-12 07:58 rebuild (see follow-up below).

### 2026-11-12 follow-up: Objective-K on Linux x86_64 (macOS verified too)

- [x] The shipped Linux x86_64 hosts predated Objective-K (June/July 2026). The
  Pure-Krypton Obj-K runtime now runs on Linux x86_64 (Lima VM) through the
  repo's standard driver: `test_objk_runtime`, `test_objk_witness`,
  `test_objk_syntax`, `test_objk_protocols`, `test_objk_types`,
  `test_objk_lifetime`, `test_objk_weak`, `test_objk_reuse`,
  `test_objk_static_types` all rc=0 (same on macOS arm64). Refreshed seeds
  committed upstream in `krypton`: `bootstrap/elf_host_linux_x86_64` (globals
  page + bufSet*At; md5 75a0bc0c...) and
  `compiler/linux_x86/kcc-x64` (Obj-K-capable frontend; md5 6b543b72...).
  Cha23 copies the ELF host into the image at ISO build time, so the rebuilt
  ISO ships Obj-K support.
- [x] Linux ELF backend repaired: pure-Krypton runtime wrote arena headers
  through `bufSetWordAt`/`bufSetDwordAt`/`bufSetQwordAt`, which did not exist
  (emitted `UNSUPPORTED` markers) — class registration silently degraded, so
  every Obj-K test died with `Objective-K: invalid handle`. Backend now emits
  the encodings; single `PT_LOAD` is RWX and carries a module-globals page
  (`LOAD_GLOBAL`/`STORE_GLOBAL`) across functions.
- [x] Bootstrapped-verification pipeline: build hosts via the macOS arm64
  toolchain (`kcc --ir <backend.k>`) + committed Linux host, NOT via the
  Linux-FE self-host route — the latter emits one-byte-off CONST immediates
  (`strings` begin shifted by one); root cause not closed.
- [x] `tests/check_stub_sizes.py` → `tests/check_stub_sizes.k` (pure Krypton).
- [x] ISO rebuild with the Obj-K toolchain committed above — reran
  `scripts/64-install-krypton.sh` (needed `/mnt/lfs/build-state/krypton.done`
  removed to force the krypton re-install). Boot smoke PASS in 89s
  (`[smoke] KryptOS reached serial login in 89s`); rootfs md5s match the
  committed hosts (`bootstrap/elf_host_linux_x86_64` = `75a0bc0c...`); the
  shipped toolchain compiles and runs `kcc -r` (`kryptos-krypton-ok`) and
  `tests/macos/test_objk_runtime.k` from the extracted ISO rootfs.
- [ ] Mach-O `@implementation` files exit(16) without running — unexplained;
  milestone 3 verification limited to the Obj-K keyword syntax.
- [ ] `tests/test_bytes.k` SIGSEGV on Linux at `bytesWriteI32LE` — the
  literal `2147483648` (`0x80000000`) is ≥ VADDR_BASE (0x7F000000) so the
  backend tags it as a pointer and `kr_cmpi` dereferences it; known
  pointer-vs-int threshold limitation, not a regression.

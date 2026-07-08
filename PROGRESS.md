# KryptOS v0 — progress

Tick as each phase passes on the Linux host. M debugs failures live.

- [ ] **Host check** — `./scripts/00-host-check.sh` clean
- [ ] **Disk** — partition/VM/loop ready, `$LFS` mounted + writable (01-prepare-disk.md)
- [ ] **Sources** — `./scripts/02-fetch-sources.sh`, md5 clean
- [ ] **lfs user + env** — user created, .bash_profile/.bashrc per book
- [ ] **Stage 1** — cross toolchain (binutils/gcc p1, headers, glibc, libstdc++)
- [ ] **Stage 2** — temporary tools (ch6) + binutils/gcc pass 2
- [ ] **Stage 3** — chroot entered, ch7 temp tools
- [ ] **Stage 4** — final system (~80 pkgs, gcc final builds)
- [ ] **Stage 5** — config (fstab, hostname=kryptos, os-release, network)
- [ ] **Stage 6** — kernel built + GRUB installed (KryptOS boot entry)
- [ ] **Stage 6b** — first-ISO devtools: CA certs, curl, git, build-tool self-check
- [ ] **Stage 6c** — Hyprland software Vulkan: zink/lavapipe Mesa path boots graphical session
- [ ] **Stage 7** — reboot → login shell. **v0: it runs.**

## Notes / blockers

- Hyprland software rendering should now be tested through zink/lavapipe, not raw llvmpipe EGL. Run `scripts/52-fetch-zink.sh`, then in chroot `scripts/chroot/ch16-zink.sh`, then remove `/build-state/d_mesa.done` if present and rebuild Mesa with `scripts/chroot/ch11-desktop-p2.sh`.

(log compile failures + fixes here as we go)

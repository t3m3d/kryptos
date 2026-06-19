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
- [ ] **Stage 7** — reboot → login shell. **v0: it runs.**

## Notes / blockers
(log compile failures + fixes here as we go)

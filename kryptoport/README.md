# kppm — the kryptoport package manager

KryptOS's package manager. **Name:** kppm (kryptoport package manager).
**Command:** `ayo`. **Config:** `/etc/kryptoport.conf`.

apt/dnf-style verbs. **Hybrid** delivery (binary `.kpkg` if available, else build from
source) + **dependency-aware** (walks `depends=()`, installs deps first, blocks removal
of something others need).

## Commands
```
ayo install <pkg>...   install (binary if available, else build from source)
ayo update             refresh recipe tree + binary index
ayo upgrade            upgrade installed packages to the latest recipes
ayo remove [-f] <pkg>  remove (-f forces past reverse-deps)

ayo search <term>      search recipes
ayo info <pkg>         recipe + deps + binary/installed status
ayo list               list installed (name version reason)
ayo files <pkg>        list an installed package's files

ayo build <pkg> [dir]  build a .kpkg from source (for the binary repo / farm)
```
(`update` = refresh metadata, `upgrade` = apply — same split as apt.)

## Config — /etc/kryptoport.conf
Sourced by `ayo` (bash); every key is overridable by the matching `KPPM_*` env var.
```sh
KPPM_TREE_URL="https://github.com/t3m3d/kryptoport-tree.git"  # recipe tree
KPPM_BINREPO_URL=""            # binary .kpkg repo; empty = source-only
# KPPM_ARCH="x86_64"           # default: uname -m
```

## Where packages come from
- **Binaries** (when present): `<name>-<version>.kpkg` (gzipped tar of the staged file
  tree) + an `index` (`<name> <version> <sha256> <file>`) at `KPPM_BINREPO_URL`.
  install = verify sha + merge onto `/`.
- **Source**: upstream tarballs named by the recipe (we host none).
- **Recipes**: a git repo of `.ks` files (`ayo update` pulls it).

## Recipe format (declarative, also valid bash)
```bash
name="less"
version="661"
source="https://www.greenwoodsoftware.com/less/less-661.tar.gz"
sha256="<pinned>"
depends=("ncurses")
build() {
    run "./configure --prefix=/usr --sysconfdir=/etc"
    run "make"
    run "make DESTDIR=\$PKGROOT install"
}
```
**Contract:** a recipe sets only `name/version/source/sha256/depends` + a `build()`
whose sole verb is `run`. That contract lets the engine swap shell→Krypton without
touching the tree.

## Install onto a system
```
sudo ./install-kppm.sh                          # /usr/bin/ayo + /etc/kryptoport.conf + seed tree
KPPM_INSTALL_ROOT=/mnt/lfs ./install-kppm.sh    # stage onto an LFS root
```

## Layout on the running system
```
/usr/bin/ayo
/etc/kryptoport.conf
/var/lib/kryptoport/tree/<pkg>/recipe.ks                 recipe tree (git)
/var/lib/kryptoport/db/<pkg>/{files,version,depends,reason}   installed manifest
/var/lib/kryptoport/index.<arch>                         binary index (if BINREPO set)
/var/cache/kryptoport/{src,bin}                          downloaded tarballs / .kpkg
```

## Engine roadmap
- **v0 (now):** `ayo` is ~250 lines of bash (needs bash 4+, present on KryptOS 5.2).
- **v1:** rewrite the engine in Krypton once the Linux/ELF backend lands. Recipes are
  already `.ks`; the tree and `.kpkg` format carry over untouched.

## Status
Hybrid + dependency-aware engine, apt/dnf-style `ayo` CLI, config-driven via
`/etc/kryptoport.conf`. 4 seed recipes (hello, zlib, ncurses, less — `less` depends on
`ncurses`). `sha256`/binary repo are TODO; `ayo` warns on an empty source hash.

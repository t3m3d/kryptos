# kix — KryptOS package manager

Pacman-style CLI. **Hybrid** delivery + **dependency-aware**.

- **Hybrid:** an install prefers a prebuilt binary package (`.kpkg`) from the
  binary repo and falls back to building the source recipe when no binary matches
  the recipe's version. Set `KIX_BINREPO_URL` to enable binaries; unset = pure
  source mode. (The binary repo / build farm is future infra — the client is
  already hybrid-capable and works source-only today.)
- **Dependency-aware:** recipes declare `depends=(...)`; kix walks the graph and
  installs deps first (post-order), records them, and blocks removal of a package
  others still need.

## CLI (pacman syntax)
```
kix -S <pkg>...    install (binary if available, else build from source)
kix -Sy            refresh recipe tree + binary index
kix -Su            upgrade installed packages
kix -Syu           refresh, then full upgrade
kix -Ss <term>     search recipes
kix -Si <pkg>      recipe + deps + binary/installed status

kix -R <pkg>...    remove (blocked if other packages depend on it)
kix -Rs <pkg>      force remove despite reverse-deps

kix -Q             list installed (name version reason)
kix -Qi <pkg>      info on an installed package
kix -Ql <pkg>      list a package's files
kix -Qs <term>     search installed

kix -B <pkg> [dir] build a .kpkg from source (for the binary repo / farm)
```

## Where packages come from
- **Binaries** (when present): `<name>-<version>.kpkg` files + an `index`
  (`<name> <version> <sha256> <file>`) hosted at `KIX_BINREPO_URL`. A `.kpkg` is
  just a gzipped tar of the staged file tree — install = verify sha + merge onto `/`.
- **Source**: upstream tarballs (gnu mirrors, kernel.org, github) named by the
  recipe. We host none of those.
- **Recipes**: a git repo of `.ks` files (`kix -Sy` pulls it). The only thing the
  project must host besides the binary repo.

## Recipe format (option B: declarative, also valid bash)
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
whose sole verb is `run`. That's what lets the engine swap shell→Krypton without
touching the tree.

## Engine roadmap
- **v0 (now):** `kix` is ~300 lines of bash (needs bash 4+, present on KryptOS).
- **v1:** rewrite the engine in Krypton once the Linux/ELF backend lands. Recipes
  are already `.ks`; the tree (and the `.kpkg` format) carry over untouched.

## Producing binaries
```
kix -B vim /srv/kixrepo      # builds vim-<ver>.kpkg, prints an index line
# append that line to the repo's `index`, publish both → clients get binaries
```

## Install onto a system
```
sudo ./install-kix.sh                 # drops /usr/bin/kix, seeds the tree
KIX_INSTALL_ROOT=/mnt/lfs ./install-kix.sh   # stage onto an LFS root
```

## Layout on the running system
```
/usr/bin/kix
/var/lib/kix/tree/<pkg>/recipe.ks            recipe tree (git)
/var/lib/kix/db/<pkg>/{files,version,depends,reason}   installed manifest
/var/lib/kix/index.<arch>                    binary index (if KIX_BINREPO_URL set)
/var/cache/kix/{src,bin}                     downloaded tarballs / .kpkg
```

## Status
Scaffold: hybrid + dependency-aware engine, pacman CLI, 4 recipes (hello, zlib,
ncurses, less — `less` depends on `ncurses`). `sha256`/binary repo are TODO; kix
warns on an empty source hash. Verified on bash 5.2: search, info (shows deps),
flag parsing.

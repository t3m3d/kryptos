# kix — KryptOS package manager

Source-based, yay-style. kix ships **no binaries**. A recipe names an upstream
tarball and a `build()` block; kix fetches it, verifies the checksum, builds into
a staging root, records the exact file list, then merges it onto `/`. Removal
replays that list, so it stays precise.

## Where packages come from
- **Upstream tarballs** — gnu mirrors, kernel.org, project sites, GitHub releases.
  Same sources the base build already pulls. We host none of them.
- **Recipes** — a git repo of `.ks` build files (`var/lib/kix/tree`), one dir per
  package. `kix sync` pulls it. That tree is the only thing the project hosts.

## Recipe format (option B)
Declarative subset that is **also valid bash**, so the v0 shell engine just
`source`s it and a future Krypton-written engine can parse the same files
unchanged. A recipe sets `name/version/source/sha256` and a `build()` whose only
verb is `run` (logs + executes, with the staging dir exported as `$PKGROOT`):

```bash
name="zlib"
version="1.3.1"
source="https://zlib.net/zlib-1.3.1.tar.gz"
sha256="<pinned>"
build() {
    run "./configure --prefix=/usr"
    run "make"
    run "make DESTDIR=\$PKGROOT install"
}
```

**Contract:** recipes never go beyond those keys + `run`. That's what lets the
engine swap from shell to Krypton without touching the tree.

## Engine roadmap
- **v0 (now):** `kix` is ~250 lines of POSIX-ish bash — boots with the system,
  zero deps beyond coreutils/tar/git/curl.
- **v1:** rewrite the engine in Krypton once the Linux/ELF backend lands. Recipes
  are already `.ks`; the tree carries over untouched. Eats its own dog food.

## Commands
```
kix sync               update the recipe tree
kix install <pkg>...   build + install from source
kix remove  <pkg>...   remove tracked files
kix upgrade            rebuild packages with newer recipes
kix search  <term>     search recipe names
kix list               installed packages
kix info    <pkg>      recipe details
```

## Install onto a system
```
sudo ./install-kix.sh            # drops /usr/bin/kix, seeds the tree
# or stage:  KIX_INSTALL_ROOT=/mnt/lfs ./install-kix.sh
```

## Layout on the running system
```
/usr/bin/kix                 engine
/var/lib/kix/tree/<pkg>/recipe.ks   recipe tree (git)
/var/lib/kix/db/<pkg>/{files,version}   installed manifest
/var/cache/kix/src/          downloaded tarballs
```

## Status
Scaffold. Engine + 3 sample recipes (hello, zlib, less) — sha256 fields are
`TODO`, pin them before real use (kix warns on an empty hash). `hello` is the
smoke test for the full fetch→build→merge→remove path.

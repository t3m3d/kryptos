#!/usr/bin/env bash
# Krypton (kcc + kr) — install the prebuilt Linux x86_64 toolchain into the
# image from the staged source tarball in /sources. No network access; the
# tarball is produced host-side by scripts/64-install-krypton.sh.
#   Runs inside the chroot. Resumable.
set -uo pipefail
set +h
export LFS=/ KRYPTOS_ROOT=/root/kryptos
source /root/kryptos/lib/build.sh

KRYPTON_PREFIX=/usr/local/krypton

b_krypton() {
    local src
    src=$(find_src krypton-)
    rm -rf "$KRYPTON_PREFIX"
    install -d /usr/local
    tar -xf "$src" -C /usr/local
    # Tarball extracts as ./krypton -> $KRYPTON_PREFIX
    [ -x "$KRYPTON_PREFIX/bootstrap/kcc_driver_linux_x86_64" ] || die "kcc driver missing after extract"
    [ -x "$KRYPTON_PREFIX/bootstrap/kcc_seed_linux_x86_64" ]   || die "kcc seed missing after extract"
    [ -x "$KRYPTON_PREFIX/kr" ]                                 || die "kr wrapper missing after extract"
    chmod 0755 "$KRYPTON_PREFIX/bootstrap/kcc_driver_linux_x86_64" \
               "$KRYPTON_PREFIX/bootstrap/kcc_seed_linux_x86_64" \
               "$KRYPTON_PREFIX/bootstrap/elf_host_linux_x86_64" \
               "$KRYPTON_PREFIX/bootstrap/optimize_host_linux_x86_64" \
               "$KRYPTON_PREFIX/kr"

    # The driver self-hosts a broken elf_host if compiler/linux_x86/elf_host is
    # missing (verified: emitted binaries drop the first byte of every string).
    # Ship the known-good bootstrap hosts, same layout as build.sh.
    cp "$KRYPTON_PREFIX/bootstrap/elf_host_linux_x86_64"     "$KRYPTON_PREFIX/compiler/linux_x86/elf_host"
    cp "$KRYPTON_PREFIX/bootstrap/optimize_host_linux_x86_64" "$KRYPTON_PREFIX/compiler/linux_x86/optimize_host"
    chmod 0755 "$KRYPTON_PREFIX/compiler/linux_x86/elf_host" "$KRYPTON_PREFIX/compiler/linux_x86/optimize_host"

    # LFS login shells put /usr/bin and /bin on PATH but not always
    # /usr/local/bin, so link into /usr/bin (same pattern as zig/ly) and keep
    # the /usr/local/bin names for parity with the macOS install.
    ln -sfv "$KRYPTON_PREFIX/bootstrap/kcc_driver_linux_x86_64" /usr/bin/kcc
    ln -sfv "$KRYPTON_PREFIX/kr"                                /usr/bin/kr
    install -d /usr/local/bin
    ln -sfv "$KRYPTON_PREFIX/bootstrap/kcc_driver_linux_x86_64" /usr/local/bin/kcc
    ln -sfv "$KRYPTON_PREFIX/kr"                                /usr/local/bin/kr

    install -d /etc/profile.d
    cat > /etc/profile.d/krypton.sh <<'EOF'
# Krypton toolchain (kcc / kr) — installed at /usr/local/krypton
export KRYPTON_ROOT=/usr/local/krypton
EOF

    # Smoke: version, compile and run a hello-world. KCC_FAST=1 skips the
    # self-host rebuild; export it for the whole smoke, not just one call.
    export KRYPTON_ROOT="$KRYPTON_PREFIX"
    export KCC_FAST=1
    /usr/bin/kcc --version || die "kcc --version failed"
    local tmp=/tmp/krypton-smoke
    rm -rf "$tmp"; install -d "$tmp"
    cat > "$tmp/hello.k" <<'EOF'
just run {
    print("kryptos-krypton-ok")
}
EOF
    /usr/bin/kcc "$tmp/hello.k" -o "$tmp/hello" || die "kcc compile failed"
    "$tmp/hello" | grep -q kryptos-krypton-ok || die "compiled binary produced wrong output"
    rm -rf "$tmp"
}

step krypton b_krypton
msg "krypton done - kcc and kr on PATH, KRYPTON_ROOT=/usr/local/krypton"

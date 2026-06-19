#!/usr/bin/env bash
# Stage 1 — cross toolchain (LFS chapter 5). Run as the 'lfs' user, on the Linux
# host, after sources are fetched.  Usage:
#     source env.sh && source lib/build.sh && ./scripts/10-toolchain.sh
#
# !! UNTESTED until run on a Linux box (M is on macOS). Flags + versions below
# !! follow the standard LFS ch5 procedure but are BOOK-SPECIFIC — verify every
# !! "VERIFY" note against the LFS $LFS_VERSION book before/while running. The
# !! step() wrapper logs each package and lets you resume after a fix.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
source ./env.sh
source ./lib/build.sh

: "${LFS_TGT:?}"; : "${LFS:?}"
[ -d "$LFS/sources" ] || die "no $LFS/sources — run 02-fetch-sources.sh first"
ARCH="$(uname -m)"

build_binutils_pass1() {
    local d; d=$(extract_to /tmp/kb "$(find_src binutils-)"); cd "$d"
    mkdir -v build && cd build
    ../configure --prefix="$LFS/tools" --with-sysroot="$LFS" --target="$LFS_TGT" \
        --disable-nls --enable-gprofng=no --disable-werror --enable-default-hash-style=gnu
    make && make install
    cd /; rm -rf /tmp/kb
}

build_gcc_pass1() {
    local d; d=$(extract_to /tmp/kg "$(find_src gcc-)"); cd "$d"
    # bundle gmp/mpfr/mpc into the gcc tree (names per book)
    tar -xf "$(find_src mpfr-)"; mv -v mpfr-* mpfr
    tar -xf "$(find_src gmp-)";  mv -v gmp-*  gmp
    tar -xf "$(find_src mpc-)";  mv -v mpc-*  mpc
    [ "$ARCH" = x86_64 ] && sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
    mkdir -v build && cd build
    # VERIFY: --with-glibc-version must match the book's glibc.
    ../configure --target="$LFS_TGT" --prefix="$LFS/tools" --with-glibc-version=2.40 \
        --with-sysroot="$LFS" --with-newlib --without-headers \
        --enable-default-pie --enable-default-ssp \
        --disable-nls --disable-shared --disable-multilib --disable-threads \
        --disable-libatomic --disable-libgomp --disable-libquadmath \
        --disable-libssp --disable-libvtv --disable-libstdcxx --enable-languages=c,c++
    make && make install
    # produce the full internal limits.h (book step)
    cd "$d"
    cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
        "$(dirname "$("$LFS/tools/bin/$LFS_TGT-gcc" -print-libgcc-file-name)")/include/limits.h"
    cd /; rm -rf /tmp/kg
}

build_linux_headers() {
    local d; d=$(extract_to /tmp/kh "$(find_src linux-)"); cd "$d"
    make mrproper
    make headers
    find usr/include -type f ! -name '*.h' -delete
    cp -rv usr/include "$LFS/usr"
    cd /; rm -rf /tmp/kh
}

build_glibc() {
    local d; d=$(extract_to /tmp/kc "$(find_src glibc-)"); cd "$d"
    # dynamic-loader symlinks (arch-specific). VERIFY vs the book for your arch:
    case "$ARCH" in
        x86_64)
            ln -sfv ../lib/ld-linux-x86-64.so.2 "$LFS/lib64"
            ln -sfv ../lib/ld-linux-x86-64.so.2 "$LFS/lib64/ld-lsb-x86-64.so.3" ;;
        aarch64)
            # arm64 loader; per the LFS-ARM notes. We build on aarch64 (Lima VM).
            mkdir -pv "$LFS/lib64"
            ln -sfv ../lib/ld-linux-aarch64.so.1 "$LFS/lib64" ;;
    esac
    # VERIFY: apply the FHS patch named in the book, e.g. glibc-*-fhs-1.patch
    patch -Np1 -i "$(ls "$LFS/sources/"glibc-*-fhs-*.patch 2>/dev/null | head -1)" || \
        warn "fhs patch not applied — check the book"
    mkdir -v build && cd build
    echo "rootsbindir=/usr/sbin" > configparms
    # VERIFY: --enable-kernel value is book-specific (host's min supported kernel).
    ../configure --prefix=/usr --host="$LFS_TGT" --build="$(../scripts/config.guess)" \
        --enable-kernel=5.4 --with-headers="$LFS/usr/include" \
        --disable-nscd libc_cv_slibdir=/usr/lib
    make && make DESTDIR="$LFS" install
    sed '/RTLDLIST=/s@/usr@@g' -i "$LFS/usr/bin/ldd"
    cd /; rm -rf /tmp/kc
}

build_libstdcxx() {
    # built from the gcc sources (pass 1 of libstdc++)
    local d; d=$(extract_to /tmp/kx "$(find_src gcc-)"); cd "$d"
    local gccver; gccver=$(basename "$(find_src gcc-)" | sed -E 's/gcc-([0-9.]+)\.tar.*/\1/')
    mkdir -v build && cd build
    ../libstdc++-v3/configure --host="$LFS_TGT" --build="$(../config.guess)" \
        --prefix=/usr --disable-multilib --disable-nls --disable-libstdcxx-pch \
        --with-gxx-include-dir="/tools/$LFS_TGT/include/c++/$gccver"
    make && make DESTDIR="$LFS" install
    rm -v "$LFS"/usr/lib/lib{stdc++{,exp,fs},supc++}.la
    cd /; rm -rf /tmp/kx
}

msg "Stage 1: cross toolchain (resumable; logs in $LFS/build-logs)"
step binutils-pass1 build_binutils_pass1
step gcc-pass1      build_gcc_pass1
step linux-headers  build_linux_headers
step glibc          build_glibc
step libstdcxx      build_libstdcxx
msg "Stage 1 done — next: Stage 2 temporary tools (ch6)."

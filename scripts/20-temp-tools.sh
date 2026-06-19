#!/usr/bin/env bash
# Stage 2 — temporary tools (LFS chapter 6), cross-compiled with the Stage-1
# toolchain into $LFS, plus binutils + gcc pass 2.  Run after 10-toolchain.sh.
#   source env.sh && ./scripts/20-temp-tools.sh
# !! UNTESTED on macOS; flags follow LFS 12.2 ch6 — VERIFY notes are book-pinned.
set -uo pipefail
set +h
cd "$(dirname "$0")/.." || exit 1
source ./env.sh
source ./lib/build.sh
: "${LFS_TGT:?}"; : "${LFS:?}"
ARCH="$(uname -m)"
# Scratch on the REAL disk, not the host's tmpfs /tmp (only ~4G → gcc's
# libstdc++ PCH overflowed it and silently truncated the install once).
W="${KB_WORK:-$LFS/build-tmp/kb2}"
mkdir -p "$W"

# echo the build triple via whichever config.guess the package ships
cfg_build() {
    for p in ./config.guess ./build-aux/config.guess ./support/config.guess; do
        [ -f "$p" ] && { "$p"; return; }
    done
    "$LFS_TGT" 2>/dev/null || gcc -dumpmachine
}
src()  { find_src "$1"; }
into() { rm -rf "$W"; local d; d=$(extract_to "$W" "$(find_src "$1")"); cd "$d"; }

b_m4() { into m4-; ./configure --prefix=/usr --host="$LFS_TGT" --build="$(cfg_build)"; make; make DESTDIR="$LFS" install; }

b_ncurses() {
    into ncurses-
    sed -i s/mawk// configure
    mkdir build; pushd build >/dev/null; ../configure AWK=gawk; make -C include; make -C progs tic; popd >/dev/null
    ./configure --prefix=/usr --host="$LFS_TGT" --build="$(cfg_build)" --mandir=/usr/share/man \
        --with-manpage-format=normal --with-shared --without-normal --with-cxx-shared \
        --without-debug --without-ada --disable-stripping AWK=gawk
    make
    make DESTDIR="$LFS" TIC_PATH="$(pwd)/build/progs/tic" install
    ln -sfv libncursesw.so "$LFS/usr/lib/libncurses.so"
    sed -e 's/^#if.*XOPEN.*$/#if 1/' -i "$LFS/usr/include/curses.h"
}

b_bash() {
    into bash-
    ./configure --prefix=/usr --build="$(cfg_build)" --host="$LFS_TGT" --without-bash-malloc \
        bash_cv_strtold_broken=no
    make; make DESTDIR="$LFS" install
    ln -sfv bash "$LFS/bin/sh"
}

b_coreutils() {
    into coreutils-
    ./configure --prefix=/usr --host="$LFS_TGT" --build="$(cfg_build)" \
        --enable-install-program=hostname --enable-no-install-program=kill,uptime
    make; make DESTDIR="$LFS" install
    mv -v "$LFS/usr/bin/chroot" "$LFS/usr/sbin"
    mkdir -pv "$LFS/usr/share/man/man8"
    mv -v "$LFS/usr/share/man/man1/chroot.1" "$LFS/usr/share/man/man8/chroot.8" 2>/dev/null || true
    sed -i 's/"1"/"8"/' "$LFS/usr/share/man/man8/chroot.8" 2>/dev/null || true
}

b_diffutils() { into diffutils-; ./configure --prefix=/usr --host="$LFS_TGT" --build="$(cfg_build)"; make; make DESTDIR="$LFS" install; }

b_file() {
    into file-
    mkdir build; pushd build >/dev/null
    ../configure --disable-bzlib --disable-libseccomp --disable-xzlib --disable-zlib
    make; popd >/dev/null
    ./configure --prefix=/usr --host="$LFS_TGT" --build="$(cfg_build)"
    make FILE_COMPILE="$(pwd)/build/src/file"
    make DESTDIR="$LFS" install
    rm -v "$LFS/usr/lib/libmagic.la"
}

b_findutils() { into findutils-; ./configure --prefix=/usr --localstatedir=/var/lib/locate --host="$LFS_TGT" --build="$(cfg_build)"; make; make DESTDIR="$LFS" install; }
b_gawk()      { into gawk-; sed -i 's/extras//' Makefile.in; ./configure --prefix=/usr --host="$LFS_TGT" --build="$(cfg_build)"; make; make DESTDIR="$LFS" install; }
b_grep()      { into grep-; ./configure --prefix=/usr --host="$LFS_TGT" --build="$(cfg_build)"; make; make DESTDIR="$LFS" install; }
b_gzip()      { into gzip-; ./configure --prefix=/usr --host="$LFS_TGT"; make; make DESTDIR="$LFS" install; }
b_make()      { into make-; ./configure --prefix=/usr --without-guile --host="$LFS_TGT" --build="$(cfg_build)"; make; make DESTDIR="$LFS" install; }
b_patch()     { into patch-; ./configure --prefix=/usr --host="$LFS_TGT" --build="$(cfg_build)"; make; make DESTDIR="$LFS" install; }
b_sed()       { into sed-; ./configure --prefix=/usr --host="$LFS_TGT" --build="$(cfg_build)"; make; make DESTDIR="$LFS" install; }
b_tar()       { into tar-; ./configure --prefix=/usr --host="$LFS_TGT" --build="$(cfg_build)"; make; make DESTDIR="$LFS" install; }
b_xz()        { into xz-; ./configure --prefix=/usr --host="$LFS_TGT" --build="$(cfg_build)" --disable-static; make; make DESTDIR="$LFS" install; rm -v "$LFS/usr/lib/liblzma.la"; }

b_binutils2() {
    into binutils-
    sed '6031s/$add_dir//' -i ltmain.sh 2>/dev/null || sed '6009s/$add_dir//' -i ltmain.sh 2>/dev/null || true
    mkdir build; cd build
    ../configure --prefix=/usr --build="$(../config.guess)" --host="$LFS_TGT" --disable-nls \
        --enable-shared --enable-gprofng=no --disable-werror --enable-64-bit-bfd \
        --enable-new-dtags --enable-default-hash-style=gnu
    make; make DESTDIR="$LFS" install
    rm -v "$LFS"/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la} 2>/dev/null || true
}

b_gcc2() {
    into gcc-
    tar -xf "$(find_src mpfr-)"; mv -v mpfr-* mpfr
    tar -xf "$(find_src gmp-)";  mv -v gmp-*  gmp
    tar -xf "$(find_src mpc-)";  mv -v mpc-*  mpc
    [ "$ARCH" = x86_64 ] && sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
    mkdir build; cd build
    ../configure --build="$(../config.guess)" --host="$LFS_TGT" --target="$LFS_TGT" \
        LDFLAGS_FOR_TARGET="-L$PWD/$LFS_TGT/libgcc" --prefix=/usr --with-build-sysroot="$LFS" \
        --enable-default-pie --enable-default-ssp --disable-nls --disable-multilib \
        --disable-libatomic --disable-libgomp --disable-libquadmath --disable-libsanitizer \
        --disable-libssp --disable-libvtv --enable-languages=c,c++
    make; make DESTDIR="$LFS" install
    ln -sfv gcc "$LFS/usr/bin/cc"
}

msg "Stage 2: temporary tools (ch6) — resumable; logs in $LFS/build-logs"
step m4         b_m4
step ncurses    b_ncurses
step bash       b_bash
step coreutils  b_coreutils
step diffutils  b_diffutils
step file       b_file
step findutils  b_findutils
step gawk       b_gawk
step grep       b_grep
step gzip       b_gzip
step make       b_make
step patch      b_patch
step sed        b_sed
step tar        b_tar
step xz         b_xz
step binutils-pass2 b_binutils2
step gcc-pass2      b_gcc2
msg "Stage 2 done — next: chroot + ch7 temp tools."

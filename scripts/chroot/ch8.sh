#!/usr/bin/env bash
# Stage 4 — LFS chapter 8 "final system", part 1: man-pages .. Jinja2.
# Runs INSIDE the chroot, native, installs to / (no DESTDIR). Resumable via the
# step() markers in /build-state. The init tail (util-linux final, udev-from-
# systemd, sysvinit) lives in ch8-init.sh so its trickier commands stay isolated.
# Test-only packages (tcl/expect/dejagnu/check) are skipped for v0, and a few
# slow knobs are dropped (Python --enable-optimizations) — bootable, not bench.
set -uo pipefail
set +h
export LFS=/ KRYPTOS_ROOT=/root/kryptos
source /root/kryptos/lib/build.sh

pkgver() { basename "$(find_src "$1")" | sed -E "s/^$1([0-9p.]+)\.(tar|src).*/\1/"; }
doc()    { echo "--docdir=/usr/share/doc/$1-$(pkgver "$1-" 2>/dev/null || echo x)"; }

# --- 8.3 man-pages ---
b_manpages() { into man-pages-; rm -v man3/crypt* 2>/dev/null||true; make -R GIT=false prefix=/usr install; }

# --- 8.4 iana-etc ---
b_ianaetc() { into iana-etc-; cp services protocols /etc; }

# --- 8.5 glibc (final) ---
b_glibc() {
    into glibc-
    patch -Np1 -i "$(find_src glibc-2.40-fhs)"
    mkdir -v build; cd build
    echo "rootsbindir=/usr/sbin" > configparms
    ../configure --prefix=/usr --disable-werror --enable-kernel=4.19 \
        --enable-stack-protector=strong --disable-nscd libc_cv_slibdir=/usr/lib
    make
    touch /etc/ld.so.conf
    sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile
    make install
    sed '/RTLDLIST=/s@/usr@@g' -i /usr/bin/ldd
    # nss + resolv defaults
    cat > /etc/nsswitch.conf <<"EOF"
passwd: files
group: files
shadow: files
hosts: files dns
networks: files
protocols: files
services: files
ethers: files
rpc: files
EOF
    # timezone data
    mkdir -pv /usr/share/zoneinfo/{posix,right}
    tar -xf "$(find_src tzdata)" -C /tmp/tz 2>/dev/null || { mkdir -p /tmp/tz; tar -xf "$(find_src tzdata)" -C /tmp/tz; }
    pushd /tmp/tz >/dev/null
    for tz in etcetera southamerica northamerica europe africa antarctica asia australasia backward; do
        zic -L /dev/null -d /usr/share/zoneinfo       "$tz"
        zic -L /dev/null -d /usr/share/zoneinfo/posix "$tz"
        zic -L leapseconds -d /usr/share/zoneinfo/right "$tz"
    done
    cp -v zone.tab zone1970.tab iso3166.tab /usr/share/zoneinfo
    zic -d /usr/share/zoneinfo -p America/New_York
    popd >/dev/null
    ln -sfv /usr/share/zoneinfo/UTC /etc/localtime
    # minimal locale set (full install-locales is slow; this is enough for v0)
    mkdir -pv /usr/lib/locale
    localedef -i C        -f UTF-8 C.UTF-8     || true
    localedef -i en_US    -f UTF-8 en_US.UTF-8
    localedef -i en_US    -f ISO-8859-1 en_US
    # dynamic loader config
    cat > /etc/ld.so.conf <<"EOF"
/usr/local/lib
/opt/lib
EOF
}

# --- 8.6..8.10 compression libs ---
b_zlib()  { into zlib-; ./configure --prefix=/usr; make; make install; rm -fv /usr/lib/libz.a; }
b_bzip2() {
    into bzip2-
    patch -Np1 -i "$(find_src bzip2-1.0.8-install_docs)"
    sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
    sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile
    make -f Makefile-libbz2_so; make clean
    make; make PREFIX=/usr install
    cp -av libbz2.so.* /usr/lib; ln -sv libbz2.so.1.0.8 /usr/lib/libbz2.so
    cp -v bzip2-shared /usr/bin/bzip2
    for i in /usr/bin/{bzcat,bunzip2}; do ln -sfv bzip2 "$i"; done
    rm -fv /usr/lib/libbz2.a
}
b_xz()   { into xz-; ./configure --prefix=/usr --disable-static $(doc xz); make; make install; }
b_lz4()  { into lz4-; make BUILD_STATIC=no PREFIX=/usr; make BUILD_STATIC=no PREFIX=/usr install; }
b_zstd() { into zstd-; make prefix=/usr; make prefix=/usr install; rm -v /usr/lib/libzstd.a; }

# --- 8.11 file ---
b_file() { into file-; ./configure --prefix=/usr; make; make install; }

# --- 8.12 readline ---
b_readline() {
    into readline-
    sed -i '/MV.*old/d' Makefile.in
    sed -i '/{OLDSUFF}/c:' support/shlib-install
    sed -i 's/-Wl,-rpath,[^ ]*//' support/shobj-conf
    ./configure --prefix=/usr --disable-static --with-curses $(doc readline)
    make SHLIB_LIBS="-lncursesw"
    make SHLIB_LIBS="-lncursesw" install
}

# --- 8.13..8.15 ---
b_m4()   { into m4-; ./configure --prefix=/usr; make; make install; }
b_bc()   { into bc-; CC=gcc ./configure --prefix=/usr -G -O3 -r; make; make install; }
b_flex() { into flex-; ./configure --prefix=/usr $(doc flex) --disable-static; make; make install; ln -sv flex /usr/bin/lex; ln -sv flex.1 /usr/share/man/man1/lex.1; }

# --- 8.17 binutils (final) ---
b_binutils() {
    into binutils-
    mkdir -v build; cd build
    ../configure --prefix=/usr --sysconfdir=/etc --enable-ld=default --enable-plugins \
        --enable-shared --disable-werror --enable-64-bit-bfd --enable-new-dtags \
        --with-system-zlib --enable-default-hash-style=gnu --enable-gprofng=no
    make tooldir=/usr
    make tooldir=/usr install
    rm -fv /usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.a
    rm -fv /usr/share/doc/gprofng/
}

# --- 8.18..8.20 gmp/mpfr/mpc ---
b_gmp()  { into gmp-;  ./configure --prefix=/usr --enable-cxx --disable-static $(doc gmp);  make; make install; }
b_mpfr() { into mpfr-; ./configure --prefix=/usr --disable-static --enable-thread-safe $(doc mpfr); make; make install; }
b_mpc()  { into mpc-;  ./configure --prefix=/usr --disable-static $(doc mpc); make; make install; }

# --- 8.21..8.24 attr/acl/libcap/libxcrypt ---
b_attr() { into attr-; ./configure --prefix=/usr --disable-static --sysconfdir=/etc $(doc attr); make; make install; }
b_acl()  { into acl-;  ./configure --prefix=/usr --disable-static $(doc acl); make; make install; }
b_libcap() {
    into libcap-
    sed -i '/install -m.*STA/d' libcap/Makefile
    make prefix=/usr lib=lib; make prefix=/usr lib=lib install
}
b_libxcrypt() {
    into libxcrypt-
    ./configure --prefix=/usr --enable-hmac-fuzzing --enable-obsolete-api=glibc \
        --disable-static --disable-failure-tokens
    make; make install
}

# --- 8.25 shadow ---
b_shadow() {
    into shadow-
    sed -i 's/groups$(EXEEXT) //' src/Makefile.in
    find man -name Makefile.in -exec sed -i 's/groups\.1 / /'   {} \;
    find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
    find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \;
    sed -e 's:#ENCRYPT_METHOD DES:ENCRYPT_METHOD YESCRYPT:' \
        -e 's:/var/spool/mail:/var/mail:' -e '/PATH=/{s@/sbin:@@;s@/usr/sbin:@@}' \
        -i etc/login.defs
    touch /usr/bin/passwd
    ./configure --sysconfdir=/etc --disable-static --with-{b,yes}crypt \
        --without-libbsd --with-group-name-max-length=32
    make; make exec_prefix=/usr install; make -C man install-man
    pwconv; grpconv
    mkdir -p /etc/default
    useradd -D --gid 999 2>/dev/null || true
    # set a known root password so v0 can actually log in
    echo "root:kryptos" | chpasswd
}

# --- 8.26 gcc (final) ---
b_gcc() {
    into gcc-
    tar -xf "$(find_src mpfr-)"; mv -v mpfr-* mpfr
    tar -xf "$(find_src gmp-)";  mv -v gmp-*  gmp
    tar -xf "$(find_src mpc-)";  mv -v mpc-*  mpc
    mkdir -v build; cd build
    ../configure --prefix=/usr LD=ld --enable-languages=c,c++ --enable-default-pie \
        --enable-default-ssp --enable-host-pie --disable-multilib --disable-bootstrap \
        --disable-fixincludes --with-system-zlib
    make; make install
    ln -svr /usr/bin/cpp /usr/lib
    ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/$(pkgver gcc-)/liblto_plugin.so \
        /usr/lib/bfd-plugins/ 2>/dev/null || { mkdir -p /usr/lib/bfd-plugins; \
        ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/$(pkgver gcc-)/liblto_plugin.so /usr/lib/bfd-plugins/; }
    mkdir -pv /usr/share/gdb/auto-load/usr/lib
    mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib 2>/dev/null || true
}

# --- 8.27 ncurses (final) ---
b_ncurses() {
    into ncurses-
    ./configure --prefix=/usr --mandir=/usr/share/man --with-shared --without-debug \
        --without-normal --with-cxx-shared --enable-pc-files --with-pkg-config-libdir=/usr/lib/pkgconfig
    make; make DESTDIR=/ TIC_PATH=/usr/bin/tic install
    ln -sfv libncursesw.so /usr/lib/libncurses.so
    for lib in ncurses form panel menu; do
        ln -sfv lib${lib}w.so /usr/lib/lib${lib}.so 2>/dev/null || true
        ln -sfv lib${lib}w.a  /usr/lib/lib${lib}.a  2>/dev/null || true
    done
    ln -sfv libncursesw.so /usr/lib/libcurses.so 2>/dev/null || true
}

# --- 8.28..8.39 the long middle ---
b_sed()    { into sed-; ./configure --prefix=/usr; make; make install; }
b_psmisc() { into psmisc-; ./configure --prefix=/usr; make; make install; }
b_gettext(){ into gettext-; ./configure --prefix=/usr --disable-static $(doc gettext); make; make install; chmod -v 0755 /usr/lib/preloadable_libintl.so 2>/dev/null||true; }
b_bison()  { into bison-; ./configure --prefix=/usr $(doc bison); make; make install; }
b_grep()   { into grep-; sed -i "s/echo/printf '%s\\\\n'/" src/egrep.sh 2>/dev/null||true; ./configure --prefix=/usr; make; make install; }
b_bash()   { into bash-; ./configure --prefix=/usr --without-bash-malloc --with-installed-readline $(doc bash); make; make install; ln -sfv bash /usr/bin/sh; }
b_libtool(){ into libtool-; ./configure --prefix=/usr; make; make install; rm -fv /usr/lib/libltdl.a; }
b_gdbm()   { into gdbm-; ./configure --prefix=/usr --disable-static --enable-libgdbm-compat; make; make install; }
b_gperf()  { into gperf-; ./configure --prefix=/usr $(doc gperf); make; make install; }
b_expat()  { into expat-; ./configure --prefix=/usr --disable-static $(doc expat); make; make install; }
b_inetutils(){
    into inetutils-
    sed -i 's/def HAVE_TERMCAP_TGETENT/ 1/' telnet/telnet.c 2>/dev/null||true
    ./configure --prefix=/usr --bindir=/usr/bin --localstatedir=/var --disable-logger \
        --disable-whois --disable-rcp --disable-rexec --disable-rlogin --disable-rsh --disable-servers
    make; make install
    mv -v /usr/{,s}bin/ifconfig 2>/dev/null||true
}
b_less()   { into less-; ./configure --prefix=/usr --sysconfdir=/etc; make; make install; }

# --- 8.40..8.44 perl + build tooling ---
b_perl() {
    into perl-
    export BUILD_ZLIB=False BUILD_BZIP2=0
    local v; v=$(pkgver perl- | grep -oE '^[0-9]+\.[0-9]+')
    sh Configure -des -Dprefix=/usr -Dvendorprefix=/usr -Duseshrplib -Dusethreads \
        -Dprivlib=/usr/lib/perl5/$v/core_perl -Darchlib=/usr/lib/perl5/$v/core_perl \
        -Dsitelib=/usr/lib/perl5/$v/site_perl -Dsitearch=/usr/lib/perl5/$v/site_perl \
        -Dvendorlib=/usr/lib/perl5/$v/vendor_perl -Dvendorarch=/usr/lib/perl5/$v/vendor_perl \
        -Dman1dir=/usr/share/man/man1 -Dman3dir=/usr/share/man/man3 \
        -Dpager="/usr/bin/less -isR" -Duseshrplib -Dusethreads
    make; make install
    unset BUILD_ZLIB BUILD_BZIP2
}
b_xmlparser(){ into XML-Parser-; perl Makefile.PL; make; make install; }
b_intltool() {
    into intltool-
    sed -i 's:\\\${:\\\$\\{:' intltool-update.in
    ./configure --prefix=/usr; make; make install
}
b_autoconf() { into autoconf-; ./configure --prefix=/usr; make; make install; }
b_automake() { into automake-; ./configure --prefix=/usr $(doc automake); make; make install; }

# --- 8.45..8.48 openssl/kmod/elfutils/libffi ---
b_openssl() {
    into openssl-
    ./config --prefix=/usr --openssldir=/etc/ssl --libdir=lib shared zlib-dynamic
    make
    sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
    make MANSUFFIX=ssl install
}
b_kmod() {
    into kmod-
    ./configure --prefix=/usr --sysconfdir=/etc --with-openssl --with-xz --with-zstd --with-zlib
    make; make install
    for t in depmod insmod modinfo modprobe rmmod; do ln -sfv kmod /usr/bin/$t; done
    ln -sfv kmod /usr/bin/lsmod
}
b_elfutils() {
    into elfutils-
    ./configure --prefix=/usr --disable-debuginfod --enable-libdebuginfod=dummy --libdir=/usr/lib
    make
    make -C libelf install
    install -vm644 config/libelf.pc /usr/lib/pkgconfig
    rm -fv /usr/lib/libelf.a
}
b_libffi() { into libffi-; ./configure --prefix=/usr --disable-static --disable-exec-static-tramp; make; make install; }

# --- 8.49..8.54 python stack ---
b_python() {
    into Python-
    # NOTE: ch8 (final) Python must KEEP ensurepip — pip is required by the
    # flit-core/wheel/setuptools/meson/MarkupSafe/Jinja2 steps below. Only the
    # ch7 temp Python uses --without-ensurepip. (--enable-optimizations dropped
    # for v0 build speed; not needed for a bootable system.)
    ./configure --prefix=/usr --enable-shared --with-system-expat
    make; make install
    # make install did not always materialise the pip3 console script here;
    # bootstrap it explicitly from the bundled wheel so the steps below work.
    python3 -m ensurepip --default-pip
    cat > /etc/pip.conf <<"EOF"
[global]
root-user-action = ignore
disable-pip-version-check = true
EOF
}
pip_install() { # $1=src-prefix : build a wheel offline and install it
    into "$1"
    python3 -m pip wheel -w dist --no-cache-dir --no-build-isolation --no-deps "$PWD"
    python3 -m pip install --no-index --find-links dist --no-user "$2"
}
b_flitcore()  { pip_install flit_core- flit_core; }
b_wheel()     { pip_install wheel- wheel; }
b_setuptools(){ pip_install setuptools- setuptools; }
b_ninja() {
    into ninja-
    python3 - <<'PY'
from pathlib import Path
p = Path('src/ninja.cc')
s = p.read_text()
needle = '#include <stdlib.h>\n'
patch = '#include <stdlib.h>\n#define exit(code) do { fflush(NULL); _Exit(code); } while (0)\n'
if patch not in s:
    if needle not in s:
        raise SystemExit('ninja.cc stdlib include needle missing')
    p.write_text(s.replace(needle, patch, 1))
PY
    CXXFLAGS="-O0 -g -fno-pie -no-pie" LDFLAGS="-no-pie" python3 configure.py --bootstrap --force-pselect || return
    ./ninja --version || return
    ./ninja -t list >/dev/null || return
    install -vm755 ninja /usr/bin/ninja.real || return
    cat > /usr/bin/ninja <<'SH'
#!/bin/sh
if [ "$1" = "--version" ]; then
  echo 1.12.1
  exit 0
fi
if [ "$1" = "-t" ] && [ "$2" = "compdb" ]; then
  echo '[]'
  exit 0
fi
exec /usr/bin/ninja.real "$@"
SH
    chmod 755 /usr/bin/ninja || return
}
b_meson() {
    into meson-
    python3 -m pip wheel -w dist --no-cache-dir --no-build-isolation --no-deps "$PWD" || return
    python3 -m pip install --no-index --find-links dist meson || return
    python3 - <<'PY'
from pathlib import Path
p = Path('/usr/lib/python3.12/site-packages/mesonbuild/utils/universal.py')
s = p.read_text()
s = s.replace('encoding=encoding, close_fds=False,', "encoding=encoding, errors='replace', close_fds=True,")
s = s.replace("encoding=encoding, errors='replace', close_fds=False,", "encoding=encoding, errors='replace', close_fds=True,")
s = s.replace('universal_newlines=False, close_fds=False,', 'universal_newlines=False, close_fds=True,')
p.write_text(s)
PY
}
# --- 8.55..8.62 core userland ---
b_coreutils() {
    into coreutils-
    patch -Np1 -i "$(find_src coreutils-9.5-i18n)"
    autoreconf -fiv
    FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr --enable-no-install-program=kill,uptime
    make; make install
    mv -v /usr/bin/chroot /usr/sbin
    mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8 2>/dev/null||true
    sed -i 's/"1"/"8"/' /usr/share/man/man8/chroot.8 2>/dev/null||true
}
b_diffutils(){ into diffutils-; ./configure --prefix=/usr; make; make install; }
b_gawk()     { into gawk-; sed -i 's/extras//' Makefile.in; ./configure --prefix=/usr; make; make install; }
b_findutils(){ into findutils-; ./configure --prefix=/usr --localstatedir=/var/lib/locate; make; make install; }
b_groff()    { into groff-; PAGE=letter ./configure --prefix=/usr; make; make install; }
b_grub() {
    into grub-
    ./configure --prefix=/usr --sysconfdir=/etc --disable-efiemu --disable-werror
    make; make install
    mv -v /etc/bash_completion.d/grub /usr/share/bash-completion/completions 2>/dev/null||true
}
b_gzip() { into gzip-; ./configure --prefix=/usr; make; make install; }

# --- 8.63..8.69 net/console/build ---
b_iproute2() {
    into iproute2-
    sed -i /ARPD/d Makefile; rm -fv man/man8/arpd.8
    make NETNS_RUN_DIR=/run/netns
    make SBINDIR=/usr/sbin install
}
b_kbd() {
    into kbd-
    patch -Np1 -i "$(find_src kbd-2.6.4-backspace)"
    sed -i '/RESIZECONS_PROGS=/s/yes/no/' configure
    sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in
    ./configure --prefix=/usr --disable-vlock
    make; make install
}
b_libpipeline(){ into libpipeline-; ./configure --prefix=/usr; make; make install; }
b_make()  { into make-; ./configure --prefix=/usr; make; make install; }
b_patch() { into patch-; ./configure --prefix=/usr; make; make install; }
b_tar()   { into tar-; FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr; make; make install; }
b_texinfo(){ into texinfo-; ./configure --prefix=/usr; make; make install; }

# --- 8.70..8.72 vim + jinja ---
b_vim() {
    into vim-
    echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
    ./configure --prefix=/usr
    make; make install
    ln -sfv vim /usr/bin/vi
    for L in /usr/share/man/man1/vim.1; do ln -sfv vim.1 /usr/share/man/man1/vi.1; done 2>/dev/null||true
}
b_markupsafe(){ pip_install MarkupSafe- MarkupSafe; }
b_jinja2()    { pip_install jinja2- Jinja2; }

msg "ch8 part 1: final system (man-pages .. Jinja2)"
step man-pages   b_manpages
step iana-etc    b_ianaetc
step glibc-final b_glibc
step zlib        b_zlib
step bzip2       b_bzip2
step xz-final    b_xz
step lz4         b_lz4
step zstd        b_zstd
step file-final  b_file
step readline    b_readline
step m4-final    b_m4
step bc          b_bc
step flex        b_flex
step binutils-final b_binutils
step gmp         b_gmp
step mpfr        b_mpfr
step mpc         b_mpc
step attr        b_attr
step acl         b_acl
step libcap      b_libcap
step libxcrypt   b_libxcrypt
step shadow      b_shadow
step gcc-final   b_gcc
step ncurses-final b_ncurses
step sed-final   b_sed
step psmisc      b_psmisc
step gettext-final b_gettext
step bison-final b_bison
step grep-final  b_grep
step bash-final  b_bash
step libtool     b_libtool
step gdbm        b_gdbm
step gperf       b_gperf
step expat       b_expat
step inetutils   b_inetutils
step less        b_less
step perl-final  b_perl
step xml-parser  b_xmlparser
step intltool    b_intltool
step autoconf    b_autoconf
step automake    b_automake
step openssl     b_openssl
step kmod        b_kmod
step elfutils    b_elfutils
step libffi      b_libffi
step python-final b_python
step flit-core   b_flitcore
step wheel       b_wheel
step setuptools  b_setuptools
step ninja       b_ninja
step meson       b_meson
step coreutils-final b_coreutils
step diffutils-final b_diffutils
step gawk-final  b_gawk
step findutils-final b_findutils
step groff       b_groff
step grub        b_grub
step gzip-final  b_gzip
step iproute2    b_iproute2
step kbd         b_kbd
step libpipeline b_libpipeline
step make-final  b_make
step patch-final b_patch
step tar-final   b_tar
step texinfo-final b_texinfo
step vim         b_vim
step markupsafe  b_markupsafe
step jinja2      b_jinja2
msg "ch8 part 1 done — next: ch8-init.sh (util-linux final, udev, sysvinit)."

#!/usr/bin/env bash
# First-ISO developer tools. Runs inside the chroot after the final LFS system
# is complete. Installs enough tooling for KryptOS to build packages from source
# and clone/fetch upstream code immediately after boot.
set -uo pipefail
set +h
export LFS=/ KRYPTOS_ROOT=/root/kryptos
source /root/kryptos/lib/build.sh

b_ca_certs() {
    install -dv /etc/ssl/certs
    install -vm644 /sources/cacert.pem /etc/ssl/certs/ca-certificates.crt
    ln -sfv certs/ca-certificates.crt /etc/ssl/cert.pem
}

b_curl() {
    into curl-
    ./configure --prefix=/usr --disable-static --with-openssl --without-libpsl --disable-ldap --with-ca-bundle=/etc/ssl/certs/ca-certificates.crt || return
    make || return
    make install || return
    rm -fv /usr/lib/libcurl.la
}

b_git() {
    into git-
    make prefix=/usr gitexecdir=/usr/libexec/git-core all || return
    make prefix=/usr gitexecdir=/usr/libexec/git-core install || return
    install -dvm755 /usr/share/bash-completion/completions
    install -vm644 contrib/completion/git-completion.bash /usr/share/bash-completion/completions/git
}

b_devtools_check() {
    mkdir -pv /var/lib/kryptos
    cat > /var/lib/kryptos/first-iso-devtools.txt <<"EOF"
KryptOS first ISO developer-tool contract:
- gcc/g++/cc/cpp
- binutils: as/ld/ar/ranlib/strip/readelf/objdump
- make, patch, tar, gzip, xz, zstd
- autoconf, automake, libtool
- pkgconf/pkg-config
- python3, pip, meson, ninja
- openssl, curl, git
- CA certificates for HTTPS source fetches
EOF
    for t in gcc g++ cc make patch tar xz zstd autoconf automake libtool pkg-config python3 pip3 meson ninja openssl curl git; do
        command -v "$t" >/dev/null || { echo "missing $t"; exit 1; }
    done
    git --version
    curl --version | head -1
}

msg "first ISO devtools: CA certs, curl, git, self-host build checks"
step ca-certificates b_ca_certs
step curl           b_curl
step git            b_git
step devtools-check b_devtools_check
msg "first ISO devtools done - KryptOS can fetch, clone, and build from source."

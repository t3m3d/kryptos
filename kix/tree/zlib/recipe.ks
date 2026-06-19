# kix recipe — declarative subset, also valid bash (sourced by the v0 engine).
# Keep to: name/version/source/sha256 + a build() that only calls `run`.
name="zlib"
version="1.3.1"
source="https://zlib.net/zlib-1.3.1.tar.gz"
sha256=""   # TODO: pin — sha256sum the tarball and paste here

build() {
    run "./configure --prefix=/usr"
    run "make"
    run "make DESTDIR=\$PKGROOT install"
    run "rm -f \$PKGROOT/usr/lib/libz.a"
}

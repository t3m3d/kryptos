# Tiny GNU package — handy smoke test for the whole fetch/build/merge/remove path.
name="hello"
version="2.12.1"
source="https://mirrors.kernel.org/gnu/hello/hello-2.12.1.tar.gz"
sha256=""   # TODO: pin

build() {
    run "./configure --prefix=/usr"
    run "make"
    run "make DESTDIR=\$PKGROOT install"
}

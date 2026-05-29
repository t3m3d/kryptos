name="ncurses"
version="6.5"
source="https://invisible-mirror.net/archives/ncurses/ncurses-6.5.tar.gz"
sha256=""    # TODO: pin
depends=()

build() {
    run "./configure --prefix=/usr --with-shared --without-debug --enable-pc-files"
    run "make"
    run "make DESTDIR=\$PKGROOT install"
}

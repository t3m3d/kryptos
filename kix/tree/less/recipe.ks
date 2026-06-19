name="less"
version="661"
source="https://www.greenwoodsoftware.com/less/less-661.tar.gz"
sha256=""              # TODO: pin
depends=("ncurses")   # less links terminfo from ncurses

build() {
    run "./configure --prefix=/usr --sysconfdir=/etc"
    run "make"
    run "make DESTDIR=\$PKGROOT install"
}

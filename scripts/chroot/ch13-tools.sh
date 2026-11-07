#!/usr/bin/env bash
# Desktop tools — small Wayland utilities. grim: screenshot via wlr-screencopy
# (reads the compositor's rendered buffer directly; used to capture the desktop
# without relying on the VM's DRM page-flip/scanout). Runs inside the chroot.
set -uo pipefail
set +h
export LFS=/ KRYPTOS_ROOT=/root/kryptos
source /root/kryptos/lib/build.sh

mesonb() { local p="$1"; shift; into "$p"; rm -rf build; \
    meson setup build --prefix=/usr --libdir=lib --buildtype=release "$@"; \
    ninja -C build; ninja -C build install; }

# grim bundles the wlr-screencopy protocol; deps = wayland-client, pixman, libpng
b_grim() { mesonb grim- -Dman-pages=disabled; }

# DejaVu fonts — without any font, Hyprland/pango render text as tofu squares
b_fonts() {
    into dejavu-fonts-ttf-
    mkdir -pv /usr/share/fonts/dejavu
    cp -v ttf/*.ttf /usr/share/fonts/dejavu/
    fc-cache -f
}

# Symbols Nerd Font + Noto Color Emoji — the shell renders bar/dock icons as
# Nerd Font glyphs and emoji via Noto (`font.family: "Symbols Nerd Font"` x39
# in config/quickshell). Missing families show up as tofu blocks.
b_fonts_nerd() {
    # The SymbolsNerdFont package unpacks loose files (no top-level dir), so it
    # cannot go through into().
    local tmp; tmp=$(mktemp -d)
    tar -xf "$(find_src NerdFontsSymbolsOnly)" -C "$tmp"
    install -d /usr/share/fonts/nerd-symbols /usr/share/fonts/noto-emoji
    cp -v "$tmp"/*.ttf /usr/share/fonts/nerd-symbols/
    if [ -f "$tmp/10-nerd-font-symbols.conf" ]; then
        install -Dm644 "$tmp/10-nerd-font-symbols.conf" /etc/fonts/conf.d/10-nerd-font-symbols.conf
    fi
    rm -rf "$tmp"
    # Noto ships as a .deb in $LFS/sources; unpack the ttf out of it when the
    # plain ttf is not already present.
    if [ ! -s "$LFS/sources/NotoColorEmoji.ttf" ]; then
        local deb
        deb=$(ls "$LFS/sources"/fonts-noto-color-emoji_*.deb 2>/dev/null | head -1) || true
        if [ -n "$deb" ]; then
            local tmp; tmp=$(mktemp -d)
            ( cd "$tmp" && ar x "$deb" && tar -xf data.tar.* )
            find "$tmp" -name NotoColorEmoji.ttf -exec cp -v {} /usr/share/fonts/noto-emoji/ \;
            rm -rf "$tmp"
        fi
    else
        cp -v "$LFS/sources/NotoColorEmoji.ttf" /usr/share/fonts/noto-emoji/
    fi
    [ -s /usr/share/fonts/noto-emoji/NotoColorEmoji.ttf ] \
        || warn 'Noto Color Emoji missing — emoji fall back to DejaVu'
    fc-cache -f
    fc-match -f '%{family}\n' 'Symbols Nerd Font' | grep -qi 'symbols nerd font' \
        || die 'Symbols Nerd Font not resolvable after install'
}

msg "desktop tools"
step d_grim  b_grim
step d_fonts b_fonts
step d_fonts-nerd b_fonts_nerd
msg "desktop tools done."

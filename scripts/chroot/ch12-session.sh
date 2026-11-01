#!/usr/bin/env bash
# Desktop launcher: physical GPUs use native Mesa.
# Hyper-V uses Mesa auto-selection; other virtual GPUs use zink/lavapipe.
# Libseat opens DRM/input directly as root for this early single-user image.
set -uo pipefail
export LFS=/ KRYPTOS_ROOT=/root/kryptos
source /root/kryptos/lib/build.sh

# The sysvinit consolidated patch drops the pidof symlink, but the lfs
# bootscripts' init-functions call pidof when stopping daemons. killall5
# dispatches to its pidof implementation when invoked by that name.
[ -e /usr/bin/pidof ] || ln -sfv ../sbin/killall5 /usr/bin/pidof
/usr/bin/pidof 1 >/dev/null

# Hardware-aware launcher. Prefer AMDGPU when multiple DRM cards exist.
install -d /usr/local/bin
install -m755 /root/kryptos/config/start-hypr /usr/local/bin/start-hypr
install -m755 /root/kryptos/config/kryptos-diagnose /usr/local/bin/kryptos-diagnose

# minimal Hyprland config
install -d /root/.config/hypr
cat > /root/.config/hypr/hyprland.conf <<"EOF"
monitor = , preferred, auto, 1
general {
    gaps_in = 5
    gaps_out = 12
    border_size = 2
    col.active_border = rgba(7c3aedff) rgba(2dd4bfff) 45deg
    col.inactive_border = rgba(595959aa)
}
decoration {
    rounding = 8
    blur {
        enabled = false
    }
}
misc {
    force_default_wallpaper = -1
    disable_hyprland_logo = false
}
input {
    kb_layout = us
    follow_mouse = 1
}
# Keep logs for first hardware and VM boots.
debug {
    disable_logs = false
}

# ---- keybinds ----
$mod = SUPER
bind = $mod, Return, exec, foot
bind = $mod, Space, exec, qs -c kryptos ipc call launcher toggle
bind = $mod, Q, killactive,
bind = $mod, M, exit,
bind = $mod, V, togglefloating,
bind = $mod, F, fullscreen,
bind = $mod, left,  movefocus, l
bind = $mod, right, movefocus, r
bind = $mod, up,    movefocus, u
bind = $mod, down,  movefocus, d
bind = $mod, 1, workspace, 1
bind = $mod, 2, workspace, 2
bind = $mod, 3, workspace, 3
bind = $mod SHIFT, 1, movetoworkspace, 1
bind = $mod SHIFT, 2, movetoworkspace, 2
bindm = $mod, mouse:272, movewindow
bindm = $mod, mouse:273, resizewindow

exec-once = qs -c kryptos -d
exec-once = foot
EOF

# Normal user for desktop and day-to-day work. Idempotent: this script has no
# step marker and runs on every pipeline pass.
for group in video input audio tty; do
    getent group "$group" >/dev/null || groupadd --system "$group"
done
if ! id kryptos >/dev/null 2>&1; then
    useradd -m -s /bin/bash -G video,input,audio,tty -c 'KryptOS user' kryptos
fi
install -d -m755 -o kryptos -g kryptos /home/kryptos
install -d -m700 -o kryptos -g kryptos /home/kryptos/.config

# Keep tty1 at a usable shell prompt. Start desktop manually with start-hypr.
cat > /root/.bash_profile <<"EOF"
[ -f /etc/profile ] && . /etc/profile
export PATH="/usr/local/sbin:/usr/local/bin:${PATH:-/usr/sbin:/usr/bin:/sbin:/bin}"
EOF

# tty1 autologin root (graphical VT); keep serial getty for logs
sed -i 's#^1:2345:respawn:/sbin/agetty .*tty1.*#1:2345:respawn:/sbin/agetty --autologin root --noclear tty1 38400 linux#' /etc/inittab

msg "session configured - Hyprland + Quickshell with adaptive GPU selection."

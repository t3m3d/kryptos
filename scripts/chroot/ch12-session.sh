#!/usr/bin/env bash
# Desktop session — autostart Hyprland on tty1 for the VM. Software GL (llvmpipe)
# + libseat builtin backend (opens DRM/input directly as root, no seatd daemon
# needed in a single-user VM). Runs inside the chroot.
set -uo pipefail
export LFS=/ KRYPTOS_ROOT=/root/kryptos
source /root/kryptos/lib/build.sh

# launcher: env for software-rendered Wayland on QEMU virtio-gpu
install -d /usr/local/bin
cat > /usr/local/bin/start-hypr <<"EOF"
#!/bin/sh
export XDG_RUNTIME_DIR=/run/user/0
mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
export XDG_SESSION_TYPE=wayland
export LIBSEAT_BACKEND=builtin          # open DRM/input directly (no seatd in VM)
export WLR_NO_HARDWARE_CURSORS=1
export WLR_RENDERER_ALLOW_SOFTWARE=1
# QEMU/UTM virtio-gpu has no virgl → Mesa can't make a GL context on the hw
# driver and Hyprland crashes at renderer init (right after "Using config").
# FORCE the software GL driver (kms_swrast/llvmpipe) so the context succeeds.
# Keep ATOMIC modeset (do NOT set AQ_NO_ATOMIC — legacy doesn't present in UTM).
export MESA_LOADER_DRIVER_OVERRIDE=kms_swrast
export GALLIUM_DRIVER=llvmpipe
export AQ_DRM_DEVICES=/dev/dri/card0
# v0 runs the VM as root; Hyprland blocks root unless this flag is passed.
exec Hyprland --i-am-really-stupid > /var/log/hypr.log 2>&1
EOF
chmod +x /usr/local/bin/start-hypr

# minimal Hyprland config
install -d /root/.config/hypr
cat > /root/.config/hypr/hyprland.conf <<"EOF"
monitor = , preferred, auto, 1
general {
    gaps_in = 5
    gaps_out = 12
    border_size = 2
    col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
    col.inactive_border = rgba(595959aa)
}
decoration {
    rounding = 8
    blur { enabled = false }
}
misc {
    force_default_wallpaper = -1
    disable_hyprland_logo = false
}
cursor {
    no_hardware_cursors = true
}
input {
    kb_layout = us
    follow_mouse = 1
}
# verbose logs on — software-GL present is still being debugged (see handoff)
debug {
    disable_logs = false
}

# ---- keybinds (ALT = Option on a Mac; UTM passes it, Cmd is eaten by macOS) ----
$mod = ALT
bind = $mod, Return, exec, foot
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

exec-once = foot
EOF

# autostart on tty1: root .bash_profile launches Hyprland on the graphical VT
cat > /root/.bash_profile <<"EOF"
[ -f /etc/profile ] && . /etc/profile
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec /usr/local/bin/start-hypr
fi
EOF

# tty1 autologin root (graphical VT); keep serial getty for logs
sed -i 's#^1:2345:respawn:/sbin/agetty .*tty1.*#1:2345:respawn:/sbin/agetty --autologin root --noclear tty1 38400 linux#' /etc/inittab

msg "session configured — Hyprland autostarts on tty1 (autologin root, software GL)."

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
# Render mode: default GPU (virgl, e.g. UTM). For a host with NO 3D (plain QEMU,
# virtio-gpu cap sets 0) write "software" to /etc/kryptos-render → llvmpipe via
# kms_swrast + legacy non-atomic modeset (llvmpipe can't do EGL fence/atomic).
if [ "$(cat /etc/kryptos-render 2>/dev/null)" = software ]; then
    export MESA_LOADER_DRIVER_OVERRIDE=kms_swrast GALLIUM_DRIVER=llvmpipe AQ_NO_ATOMIC=1
fi
export AQ_DRM_DEVICES=/dev/dri/card0
export AQ_TRACE=1
# v0 runs the VM as root; Hyprland blocks root unless this flag is passed.
# log to a persistent file for post-mortem (software GL bring-up is finicky).
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
render {
    # llvmpipe rejects the EGL native-fence sync (eglCreateSyncKHR EGL_BAD_
    # ATTRIBUTE) → Hyprland crashes compositing clients. Disable explicit sync.
    explicit_sync = 0
    direct_scanout = false
}
input {
    kb_layout = us
    follow_mouse = 1
    sensitivity = 0
}

# ---- keybinds ----
# ALT (Option on a Mac) — UTM passes it reliably; Cmd/SUPER is eaten by macOS
$mod = ALT
bind = $mod, Return, exec, foot
bind = $mod, Q, killactive,
bind = $mod, M, exit,
bind = $mod, V, togglefloating,
bind = $mod, F, fullscreen,
bind = $mod, J, togglesplit,
bind = $mod, P, pseudo,
# move focus
bind = $mod, left,  movefocus, l
bind = $mod, right, movefocus, r
bind = $mod, up,    movefocus, u
bind = $mod, down,  movefocus, d
# move windows
bind = $mod SHIFT, left,  movewindow, l
bind = $mod SHIFT, right, movewindow, r
bind = $mod SHIFT, up,    movewindow, u
bind = $mod SHIFT, down,  movewindow, d
# workspaces 1-9
bind = $mod, 1, workspace, 1
bind = $mod, 2, workspace, 2
bind = $mod, 3, workspace, 3
bind = $mod, 4, workspace, 4
bind = $mod, 5, workspace, 5
bind = $mod, 6, workspace, 6
bind = $mod, 7, workspace, 7
bind = $mod, 8, workspace, 8
bind = $mod, 9, workspace, 9
bind = $mod SHIFT, 1, movetoworkspace, 1
bind = $mod SHIFT, 2, movetoworkspace, 2
bind = $mod SHIFT, 3, movetoworkspace, 3
bind = $mod SHIFT, 4, movetoworkspace, 4
bind = $mod SHIFT, 5, movetoworkspace, 5
# mouse drag move/resize
bindm = $mod, mouse:272, movewindow
bindm = $mod, mouse:273, resizewindow

# spawn a terminal on login so the desktop is usable out of the box
# (log foot's output so a crash can be diagnosed: /var/log/foot.log)
exec-once = foot --log-level=info --log-no-syslog 2> /var/log/foot.log
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

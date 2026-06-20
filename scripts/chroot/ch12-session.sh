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
export WLR_RENDERER_ALLOW_SOFTWARE=1
# QEMU virtio-gpu has no virgl (no 3D). Use Mesa's kms_swrast (llvmpipe) for it.
# NB: do NOT set LIBGL_ALWAYS_SOFTWARE — libEGL rejects it once a hardware DRM
# device is explicitly opened ("failed to create dri2 screen"). The override is
# the correct way to pick software rendering on a specific KMS node.
export MESA_LOADER_DRIVER_OVERRIDE=kms_swrast
export GALLIUM_DRIVER=llvmpipe
export WLR_NO_HARDWARE_CURSORS=1
# llvmpipe can't do EGL fences / atomic explicit-sync ("eglCreateSyncKHR
# EGL_BAD_ATTRIBUTE", "Cannot commit when a page-flip is awaiting") → the frame
# never reaches the scanout. Use legacy (non-atomic) DRM modesetting.
export AQ_NO_ATOMIC=1
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
debug {
    disable_logs = false
}
cursor {
    no_hardware_cursors = true
    no_break_fs_vrr = true
}
render {
    explicit_sync = 0
    direct_scanout = false
}
# spawn a couple of windows so the desktop is obviously alive (if a term exists)
exec-once = foot || true
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

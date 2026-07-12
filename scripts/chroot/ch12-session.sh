#!/usr/bin/env bash
# Desktop launcher: physical GPUs use native Mesa.
# Hyper-V uses Mesa auto-selection; other virtual GPUs use zink/lavapipe.
# Libseat opens DRM/input directly as root for this early single-user image.
set -uo pipefail
export LFS=/ KRYPTOS_ROOT=/root/kryptos
source /root/kryptos/lib/build.sh

# Hardware-aware launcher. Prefer AMDGPU when multiple DRM cards exist.
install -d /usr/local/bin
cat > /usr/local/bin/start-hypr <<"EOF"
#!/bin/sh
export XDG_RUNTIME_DIR=/run/user/0
mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
export XDG_SESSION_TYPE=wayland
export LIBSEAT_BACKEND=builtin

DRM_CARD=
DRM_DRIVER=
for card in /sys/class/drm/card[0-9]*; do
    [ -e "$card/device" ] || continue
    driver=$(basename "$(readlink -f "$card/device/driver" 2>/dev/null)")
    if [ "$driver" = amdgpu ]; then
        DRM_CARD="/dev/dri/${card##*/}"
        DRM_DRIVER="$driver"
        break
    fi
    if [ -z "$DRM_CARD" ]; then
        DRM_CARD="/dev/dri/${card##*/}"
        DRM_DRIVER="$driver"
    fi
done
[ -n "$DRM_CARD" ] || DRM_CARD=/dev/dri/card0
if [ ! -e "$DRM_CARD" ]; then
    echo "KryptOS: no DRM device found; desktop not started." >&2
    exit 1
fi
export AQ_DRM_DEVICES="$DRM_CARD"

case "$DRM_DRIVER" in
    hyperv_drm)
        export WLR_NO_HARDWARE_CURSORS=1
        export WLR_RENDERER_ALLOW_SOFTWARE=1
        # Hyper-V has no render node. Mesa 24.3+ can select its KMS software
        # path automatically; forcing zink or kms_swrast makes EGL reject it.
        unset MESA_LOADER_DRIVER_OVERRIDE GALLIUM_DRIVER LIBGL_ALWAYS_SOFTWARE
        ;;
    virtio_gpu|bochs_drm)
        export WLR_NO_HARDWARE_CURSORS=1
        export WLR_RENDERER_ALLOW_SOFTWARE=1
        export MESA_LOADER_DRIVER_OVERRIDE=zink
        export GALLIUM_DRIVER=zink
        case "$(uname -m)" in
            aarch64|arm64) LVP_ICD=/usr/share/vulkan/icd.d/lvp_icd.aarch64.json ;;
            x86_64)        LVP_ICD=/usr/share/vulkan/icd.d/lvp_icd.x86_64.json ;;
            *)             LVP_ICD=$(ls /usr/share/vulkan/icd.d/lvp_icd*.json 2>/dev/null | head -1) ;;
        esac
        [ -n "${LVP_ICD:-}" ] && [ -f "$LVP_ICD" ] && export VK_ICD_FILENAMES="$LVP_ICD"
        ;;
    amdgpu)
        export LIBVA_DRIVER_NAME=radeonsi
        ;;
esac
# v0 runs the VM as root; Hyprland blocks root unless this flag is passed.
Hyprland --i-am-really-stupid > /var/log/hypr.log 2>&1 &
hypr_pid=$!
tries=0
ready=0
while kill -0 "$hypr_pid" 2>/dev/null && [ "$tries" -lt 15 ]; do
    for socket in "$XDG_RUNTIME_DIR"/wayland-*; do
        if [ -S "$socket" ]; then
            ready=1
            break
        fi
    done
    [ "$ready" -eq 1 ] && break
    sleep 1
    tries=$((tries + 1))
done
if ! kill -0 "$hypr_pid" 2>/dev/null; then
    wait "$hypr_pid"
    status=$?
    echo "KryptOS: Hyprland exited with status $status. See /var/log/hypr.log." >&2
    exit "$status"
fi
if [ "$ready" -ne 1 ]; then
    echo "KryptOS: Hyprland startup timed out. See /var/log/hypr.log." >&2
    kill "$hypr_pid" 2>/dev/null || true
    wait "$hypr_pid" 2>/dev/null || true
    exit 1
fi
wait "$hypr_pid"
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

# Keep tty1 at a usable shell prompt. Start desktop manually with start-hypr.
cat > /root/.bash_profile <<"EOF"
[ -f /etc/profile ] && . /etc/profile
export PATH="/usr/local/sbin:/usr/local/bin:${PATH:-/usr/sbin:/usr/bin:/sbin:/bin}"
EOF

# tty1 autologin root (graphical VT); keep serial getty for logs
sed -i 's#^1:2345:respawn:/sbin/agetty .*tty1.*#1:2345:respawn:/sbin/agetty --autologin root --noclear tty1 38400 linux#' /etc/inittab

msg "session configured - Hyprland + Quickshell with adaptive GPU selection."

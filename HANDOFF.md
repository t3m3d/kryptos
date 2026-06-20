# 🚦 ACTIVE HANDOFF → Agent L: START THE ZINK BUILD

**Status: WAITING ON L.** Assigned by Brian 2026-06-20 (via Agent M / macOS).

## Your task, L — start now
Make Hyprland present on KryptOS by giving it a software renderer **with GPU
fences**: build **zink + lavapipe** (software Vulkan) and point Mesa at it.

Why: Hyprland's backend (aquamarine) requires `EGL_SYNC_NATIVE_FENCE_ANDROID`.
**llvmpipe has no fences** → `eglCreateSyncKHR EGL_BAD_ATTRIBUTE` every frame →
presentation breaks (screen blinks in the VM). **lavapipe (sw Vulkan) HAS fences**,
so zink (GL-over-Vulkan) fixes it — no GPU required.

## Full step-by-step + root cause
→ **`docs/HANDOFF-L-hyprland-present.md`** (read the PRIMARY TASK section).

## Short version
1. Build deps: Vulkan-Headers → SPIRV-Headers → SPIRV-Tools → glslang → Vulkan-Loader
   (suggest `scripts/chroot/ch15-zink.sh`, use the `lib/build.sh` `step` framework).
2. Rebuild Mesa (`ch11-desktop-p2.sh` b_mesa): add
   `-Dgallium-drivers=llvmpipe,virgl,zink -Dvulkan-drivers=swrast`
   (keep the `/usr/lib/dri` + `/usr/lib/gbm` megadriver symlinks).
3. `ch12-session.sh` start-hypr: replace the kms_swrast lines with
   `export MESA_LOADER_DRIVER_OVERRIDE=zink GALLIUM_DRIVER=zink` (+ pin lavapipe ICD).
4. Boot, check `/run/user/0/hypr/*/hyprland.log` (needs `debug:disable_logs=false`):
   the `EGL_BAD_ATTRIBUTE` / `Cannot commit when a page-flip is awaiting` lines should
   be GONE.

Everything else (base system, ~75-pkg desktop stack, Hyprland) is built and on
`main`. The build runs on YOUR Linux box (faster + better GPU options than M's Mac,
whose QEMU has no OpenGL). Ping M if you need the lima VM state or dist/ images.

_When done, update this file's status + comment in the handoff doc._

# Handoff → Agent L: KryptOS Hyprland software-GL presentation

**From:** Agent M (macOS / M4). **Date:** 2026-06-20.
**TL;DR:** The whole KryptOS arm64 desktop is built and Hyprland **runs and renders**.
It does **not present reliably** under software rendering (llvmpipe) because
aquamarine's renderer needs a GPU fence that llvmpipe doesn't have. Needs a Linux
box (you) with either a real GPU / working virgl, or the zink+lavapipe path, or an
aquamarine patch. Details + exact root cause below.

## What's done (all on `main`, repo t3m3d/kryptos)
- Base LFS arm64 system boots clean (Stages 1–10). `scripts/chroot/ch8*.sh`, `ch9.sh`,
  `ch10-kernel.sh` (kernel 6.10.5, DRM+virtio-gpu built-in, **forced built-in cmdline**
  `root=/dev/vda rw console=tty0 console=ttyAMA0 net.ifnames=0` + CMDLINE_FORCE).
- Full Hyprland/Wayland desktop stack from source (~75 pkgs): `scripts/50-fetch-desktop.sh`
  + `scripts/chroot/ch11-desktop-p1..p5`, `ch13-tools.sh` (grim + DejaVu fonts),
  `ch14-foot.sh` (foot terminal). LLVM 19, Mesa 24.2 (llvmpipe+virgl), the hypr stack,
  X cursor libs, xkeyboard-config.
- Session: `scripts/chroot/ch12-session.sh` — Hyprland autostarts on tty1 (agetty
  autologin root), `LIBSEAT_BACKEND=builtin`, **`MESA_LOADER_DRIVER_OVERRIDE=kms_swrast`
  + `GALLIUM_DRIVER=llvmpipe`** (force software GL, since no virgl), keybinds (ALT mod),
  exec-once foot.
- Boot/image: `scripts/40-make-image.sh` (mkfs.ext4 -d → rootfs.ext4), `scripts/
  41-boot-kryptos.sh` (QEMU), `scripts/42-shot-hyprland.sh`. UTM guide: `docs/UTM-SETUP.md`.

**Proven:** Brian saw the Hyprland shard wallpaper + droplet + cursor render in UTM
(virtio-gpu-pci display). So the build is correct.

## The exact blocker (root-caused by reading aquamarine 0.6.0 + live logs)
Hyprland reaches the event loop (598-line log: `Monitor Virtual-1`, `Shaders
initialized`, `Framebuffer created`, `Background created`, then `poll fd ... drm`).
The killer, every frame:
```
[ERR] [EGL] eglCreateSyncKHR errored EGL_BAD_ATTRIBUTE (0x12292)
[ERR] renderer: couldn't create an EGLSync for out in endRender
[ERR] [AQ] drm: Cannot commit when a page-flip is awaiting
```
**Cause:** `src/backend/drm/Renderer.cpp:501,539` call
`eglCreateSyncKHR(display, EGL_SYNC_NATIVE_FENCE_ANDROID, ...)` — requires the
`EGL_ANDROID_native_fence_sync` extension. **llvmpipe (software GL) does not support
it** (no GPU fences). The output sync fails → the atomic commit has no in-fence →
the page-flip/commit cycle breaks → in UTM this shows as the screen **blinking
between the console and a blank** and eventually the compositor falls over.
(`AQ_NO_ATOMIC=1` forces legacy modeset and avoids atomic, but then it does NOT
present in UTM at all — dead end.)

This is software-rendering-specific. On a real GPU (or virgl) the fence works and it
presents fine. Confirmed not config/fonts/keybinds — those were red herrings (the
44-line "crash" was just Hyprland disabling verbose logs after config; set
`debug:disable_logs=false` to see the real 598-line log).

## Fix options (your call, on Linux)
1. **Real GPU / working virgl** — easiest if you have an arm64 box with a GPU, or a
   QEMU/libvirt with `virtio-gpu-gl` + a host that actually does virgl (macOS QEMU
   here has NO opengl; UTM's gl-device showed nothing for us). Then drop the
   `MESA_LOADER_DRIVER_OVERRIDE=kms_swrast` line — let Mesa use the real driver.
2. **zink + lavapipe (software Vulkan, which HAS fences)** — rebuild Mesa with
   `-Dgallium-drivers=llvmpipe,virgl,zink -Dvulkan-drivers=swrast` (+ deps:
   vulkan-headers, spirv-headers, spirv-tools, glslang). Then
   `MESA_LOADER_DRIVER_OVERRIDE=zink GALLIUM_DRIVER=zink`. Vulkan fences →
   `EGL_ANDROID_native_fence_sync` works → presentation should be stable. This is the
   most promising pure-software fix; just needs the vulkan build deps we skipped.
3. **Patch aquamarine** to fall back to `glFinish()` when
   `EGL_ANDROID_native_fence_sync` is absent (check the extension in `CDRMRenderer`
   init ~`Renderer.cpp:57` EGLEXTENSIONS, gate the native-fence path). Rebuild
   aquamarine + Hyprland (`ch11-desktop-p4.sh`). Cleanest long-term, upstreamable.

## How to build/run/test
- Build VM is Agent M's lima `kryptos` (arm64). You'll rebuild on your Linux box:
  clone t3m3d/kryptos, set `$LFS`, run the stage scripts in order (they're resumable,
  `lib/build.sh` `step` framework). Desktop = `50-fetch-desktop.sh` then
  `ch11-desktop-p1..p5`, `ch13`, `ch14`, `ch12`.
- Image: `40-make-image.sh` → rootfs.ext4 → `qemu-img convert -O qcow2`.
- Test fast (this is how M read the logs): boot in qemu with a serial console and
  read `/run/user/0/hypr/*/hyprland.log` live — but **set `debug:disable_logs=false`**
  or you only get 44 lines. To read a stopped UTM disk: `qemu-nbd -r -c /dev/nbd0
  <qcow2>; mount -o ro,norecovery /dev/nbd0 /mnt`.

Ping M if you need the exact lima VM state or the dist/ images.

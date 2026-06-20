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

## >>> PRIMARY TASK (Brian's call): zink + lavapipe <<<
Software **Vulkan** (lavapipe) HAS fences, so zink (GL-over-Vulkan) gives a working
`EGL_ANDROID_native_fence_sync` → aquamarine's `eglCreateSyncKHR` succeeds →
presentation should be stable, no GPU needed. Concrete steps (arm64, in the chroot;
add as `scripts/chroot/ch15-zink.sh` using the `step` framework):

1. **Fetch + build the Vulkan deps** (order matters):
   - `Vulkan-Headers` (cmake, headers only) — github KhronosGroup/Vulkan-Headers
   - `SPIRV-Headers` (cmake, headers) — KhronosGroup/SPIRV-Headers
   - `SPIRV-Tools` (cmake, needs SPIRV-Headers) — `-DSPIRV_SKIP_TESTS=ON`
   - `glslang` (cmake, needs SPIRV-Tools) — `-DENABLE_OPT=1` ; or `-Dglslang` may be
     skippable for lavapipe-only
   - `Vulkan-Loader` (cmake, needs Vulkan-Headers) → libvulkan.so + the ICD loader so
     zink can find lavapipe. `-DVULKAN_HEADERS_INSTALL_DIR=/usr`
2. **Rebuild Mesa** (`ch11-desktop-p2.sh` b_mesa) adding zink + lavapipe:
   `-Dgallium-drivers=llvmpipe,virgl,zink -Dvulkan-drivers=swrast`
   (keep the `/usr/lib/dri` + `/usr/lib/gbm` megadriver symlinks step). This installs
   the lavapipe ICD `/usr/share/vulkan/icd.d/lvp_icd.aarch64.json` + `libvulkan_lvp.so`.
3. **Runtime env** in `ch12-session.sh` start-hypr (replace the kms_swrast lines):
   ```
   export MESA_LOADER_DRIVER_OVERRIDE=zink
   export GALLIUM_DRIVER=zink
   export WLR_RENDERER_ALLOW_SOFTWARE=1
   # if multiple ICDs, pin lavapipe:
   export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.aarch64.json
   ```
4. **Test:** boot (UTM virtio-gpu-pci display, or your GPU/virgl box). Watch
   `/run/user/0/hypr/*/hyprland.log` (with `debug:disable_logs=false`): the
   `eglCreateSyncKHR EGL_BAD_ATTRIBUTE` + `Cannot commit when a page-flip is awaiting`
   lines should be GONE. If zink reports no device, check `vulkaninfo` sees lavapipe.

Notes: zink+lavapipe is slow (sw GL over sw Vulkan) but should be STABLE. If lavapipe
build wants `LLVM` ≥15 — we already have LLVM 19 (`ch11-desktop-p2`). If you hit a
Rust/`bindgen` requirement for some Mesa Vulkan bits, lavapipe (swrast) itself does
not need it.

## Fallback options (only if zink stalls)
- **Real GPU / working virgl** — drop `MESA_LOADER_DRIVER_OVERRIDE` entirely.
- **Patch aquamarine** to `glFinish()` when `EGL_ANDROID_native_fence_sync` is absent
  (check the ext in `CDRMRenderer` init ~`Renderer.cpp:57` EGLEXTENSIONS, gate the
  native-fence path), rebuild aquamarine + Hyprland (`ch11-desktop-p4.sh`).
  Upstreamable.

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

## FYI — the package manager (kix), already on the image
`/usr/bin/kix` — KryptOS's package manager (source `kix/` in this repo). Pacman-style,
hybrid binary/source, dependency-aware. v0 = bash engine (recipes are `.ks`, also valid
bash → future Krypton rewrite). Installed via `kix/install-kix.sh` (`KIX_INSTALL_ROOT=
/mnt/lfs` to stage). Commands:
```
kix -S <pkg>     install (binary .kpkg if available, else build from source)
kix -Sy / -Su / -Syu   refresh tree+index / upgrade / both
kix -Ss <term>   search        kix -Si <pkg>   info + deps
kix -R[s] <pkg>  remove (-Rs forces past reverse-deps)
kix -Q / -Qi / -Ql / -Qs   query installed (list / info / files / search)
kix -B <pkg> [dir]   build a .kpkg for the binary repo
```
No need to reinvent install tooling — use kix. Recipe tree: `/var/lib/kix/tree`.

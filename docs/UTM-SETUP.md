# Running KryptOS + Hyprland visually in UTM (Apple Silicon)

Plain Homebrew QEMU on macOS has **no OpenGL/virgl**, so the Hyprland desktop
can't present (software-only → stuck at the console). UTM bundles a QEMU **with
GPU acceleration (virtio-gpu + virgl)**, which gives the guest real GL — that's
what lets the compositor display.

## Files (already built, in `dist/`)
- `kryptos-disk.qcow2` — the KryptOS system (GPU/virgl render mode by default)
- `vmlinuz-6.10.5-kryptos` — the kernel

## 1. Install UTM
Download the **free** build from <https://getutm.app> (the Mac App Store one is
the same app, paid). Drag UTM to Applications.

## 2. Create the VM
UTM → **+** → **Virtualize** → **Linux**.

- **Uncheck** "Use Apple Virtualization" (we need the QEMU backend for GPU accel).
- Check **"Boot from kernel image"** and set:
  - **Linux kernel:** `dist/vmlinuz-6.10.5-kryptos`
  - **Initial ramdisk:** leave **empty** (the kernel mounts the disk directly)
  - **Boot arguments:** `root=/dev/vda rw console=ttyAMA0 net.ifnames=0`
- **Memory:** 4096 MB   **CPU cores:** 4
- **Storage:** create any small disk now (we replace it next), then **Continue**
  → **Save**.

## 3. Point it at the KryptOS disk + enable the GPU
Select the VM → **Edit** (settings):

- **Drives:** remove the empty drive UTM created. **New Drive → Import** →
  choose `dist/kryptos-disk.qcow2`. Interface: **VirtIO**.
- **Display:** set the emulated display to **`virtio-gpu-gl-pci` (GPU Supported)**
  / enable **GPU Accelerated**. This is the key step.
- (Optional) **Network:** Emulated VirtIO — gives eth0 (10.0.2.15).

Save.

## 4. Boot
Start the VM. Sequence (≈1–2 min):
`kernel → sysvinit → tty1 autologin root → Hyprland`.

You should see the **Hyprland desktop** (gradient borders + cursor) in the UTM
window. Login if asked: `root` / `kryptos`.

> Bare desktop = no apps yet (no terminal built into it). To get a window,
> build **foot** (`scripts/chroot/ch13-tools.sh` can be extended) — ask and it'll
> be added.

## If it still won't present
- Confirm the display really is `virtio-gpu-gl` with GPU acceleration on (not the
  plain `virtio-ramfb`).
- Force software as a fallback: in the VM, `echo software > /etc/kryptos-render`
  then reboot — it switches to llvmpipe + legacy modeset (slower, but UTM's
  display refresh may then carry it).

## Notes
- The disk is `root=/dev/vda` (a bare ext4, no partition table) — that's why the
  kernel boots it directly with no bootloader/initrd.
- Render mode is chosen at login by `/usr/local/bin/start-hypr`: GPU/virgl by
  default; `/etc/kryptos-render=software` forces llvmpipe.

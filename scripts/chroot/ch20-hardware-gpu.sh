#!/usr/bin/env bash
# Physical-hardware firmware gate. The full upstream archive stays outside the
# ISO; only the AMD and Intel CPU/GPU payloads are installed. Both vendors ship
# in the image so it boots on either machine, and kryptos-install prunes the
# GPU firmware the target does not need.
set -uo pipefail
set +h
export LFS=/ KRYPTOS_ROOT=/root/kryptos
source /root/kryptos/lib/build.sh

b_gpu_firmware() {
    into linux-firmware-20260622
    install -d /usr/lib/firmware /usr/share/doc/linux-firmware
    cp -a amdgpu amd-ucode i915 /usr/lib/firmware/
    install -m644 WHENCE /usr/share/doc/linux-firmware/WHENCE
    for lic in LICENSE.amdgpu LICENSE.i915; do
        [ ! -f "$lic" ] || install -m644 "$lic" /usr/share/doc/linux-firmware/
    done

    # AMD: Navi 10 is the reference card; the module ships for every RDNA/GCN part.
    find /usr/lib/firmware/amdgpu -maxdepth 1 -name 'navi10*' -print -quit | grep -q .
    find /usr/lib/firmware/amd-ucode -maxdepth 1 -type f -print -quit | grep -q .
    find /usr/lib/modules -type f -name 'amdgpu.ko*' -print -quit | grep -q .
    # Intel: i915 is built into the kernel, so only the firmware payload can be
    # checked here (GuC/HuC/DMC ship as separate files).
    find /usr/lib/firmware/i915 -maxdepth 1 -type f -print -quit | grep -q .
    du -sh /usr/lib/firmware/amdgpu /usr/lib/firmware/amd-ucode /usr/lib/firmware/i915
}

msg "GPU firmware: AMD (amdgpu + Zen microcode) and Intel (i915)"
step hardware_gpu_firmware b_gpu_firmware
msg "GPU firmware done - Navi 10 and i915 payloads verified; installer picks one at install time."

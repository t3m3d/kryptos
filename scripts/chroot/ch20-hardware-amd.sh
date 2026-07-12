#!/usr/bin/env bash
# AMD physical-hardware firmware gate. The full source archive stays outside
# the ISO; only AMD CPU/GPU firmware is installed into the target root.
set -uo pipefail
set +h
export LFS=/ KRYPTOS_ROOT=/root/kryptos
source /root/kryptos/lib/build.sh

b_amd_firmware() {
    into linux-firmware-20260622
    install -d /usr/lib/firmware /usr/share/doc/linux-firmware
    cp -a amdgpu amd-ucode /usr/lib/firmware/
    install -m644 WHENCE /usr/share/doc/linux-firmware/WHENCE
    [ ! -f LICENSE.amdgpu ] || install -m644 LICENSE.amdgpu /usr/share/doc/linux-firmware/

    find /usr/lib/firmware/amdgpu -maxdepth 1 -name 'navi10*' -print -quit | grep -q .
    find /usr/lib/firmware/amd-ucode -maxdepth 1 -type f -print -quit | grep -q .
    find /usr/lib/modules -type f -name 'amdgpu.ko*' -print -quit | grep -q .
    du -sh /usr/lib/firmware/amdgpu /usr/lib/firmware/amd-ucode
}

msg "AMD hardware firmware: Zen + Navi/RDNA"
step hardware_amd_firmware b_amd_firmware
msg "AMD firmware done - RX 5700/Navi 10 payload verified."

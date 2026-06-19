# 01 — Prepare the disk (DESTRUCTIVE — read carefully)

This step formats a partition for KryptOS. It is **manual on purpose** — a
runaway script here wipes the wrong disk. Do it by hand, with your eyes on the
device names.

## Options

- **Real partition** on a spare disk, or
- **A VM** (recommended for the first build — safest), or
- **A disk image + loop device** (no spare hardware needed).

## A. Spare partition

```sh
lsblk                      # FIND THE RIGHT DEVICE. Twice. e.g. /dev/sdb
# Create a partition with your tool of choice (cfdisk/fdisk/parted), say /dev/sdbN.
sudo mkfs.ext4 /dev/sdbN   # <-- the new partition, NOT a whole disk you need
sudo mkdir -pv "$LFS"
sudo mount /dev/sdbN "$LFS"
```

## B. Disk image + loop (no spare disk)

```sh
mkdir -p ~/kryptos-img
fallocate -l 25G ~/kryptos-img/kryptos.img      # >=20G; toolchain + system need room
mkfs.ext4 ~/kryptos-img/kryptos.img
sudo mkdir -pv "$LFS"
sudo mount -o loop ~/kryptos-img/kryptos.img "$LFS"
```

## After mounting (either path)

```sh
sudo chown "$(whoami)" "$LFS"      # so you can create dirs without sudo for now
mkdir -pv "$LFS/sources"
# you're ready for ./scripts/02-fetch-sources.sh
```

## Notes

- `$LFS` comes from `env.sh` (default `/mnt/lfs`).
- A **swap** partition is optional for the base build; helpful if RAM is tight
  during gcc/glibc.
- Record the device/UUID — you'll need it for `fstab` and GRUB later
  (`blkid /dev/sdbN`).

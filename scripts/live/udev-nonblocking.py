#!/usr/bin/env python3
"""Make the live ISO's udev coldplug unable to block boot forever.

The live root is already mounted from tmpfs and devtmpfs supplies the device
nodes it needs. The upstream LFS udev script runs three synchronous
``udevadm trigger`` passes; if a synthetic uevent write stalls in the kernel,
init waits indefinitely and never reaches udevadm settle. Run coldplug in the
background so the live system can continue to a login prompt. The udev daemon
still runs and processes events normally.
"""

from pathlib import Path
import sys


UDEV_OLD = """      /bin/udevadm trigger --action=add    --type=subsystems
      /bin/udevadm trigger --action=add    --type=devices
      /bin/udevadm trigger --action=change --type=devices

      # Now wait for udevd to process the uevents we triggered
      if ! is_true "$OMIT_UDEV_SETTLE"; then
         /bin/udevadm settle
      fi
"""

UDEV_NEW = """      # KryptOS live boot: do not let a stalled uevent write hold init
      # forever. The live root is already mounted and devtmpfs provides the
      # nodes it needs; let coldplug finish (or time out) in the background.
      (
         echo "KryptOS udev: coldplug started" > /dev/kmsg 2>/dev/null || true
         /bin/udevadm trigger --action=add    --type=subsystems || true
         /bin/udevadm trigger --action=add    --type=devices || true
         /bin/udevadm trigger --action=change --type=devices || true
         if ! is_true "$OMIT_UDEV_SETTLE"; then
            /bin/udevadm settle --timeout=30 || true
         fi
         echo "KryptOS udev: coldplug finished" > /dev/kmsg 2>/dev/null || true
      ) &
"""

UDEV_RETRY_OLD = r"""      /bin/sed -e 's/#.*$//' /etc/sysconfig/udev_retry | /bin/grep -v '^$' | \
      while read line ; do
         for subsystem in $line ; do
            /bin/udevadm trigger --subsystem-match=$subsystem --action=add
         done
      done

      # Now wait for udevd to process the uevents we triggered
      if ! is_true "$OMIT_UDEV_RETRY_SETTLE"; then
         /bin/udevadm settle
      fi
"""

UDEV_RETRY_NEW = r"""      # KryptOS live boot: keep the retry pass non-blocking too.
      (
         /bin/sed -e 's/#.*$//' /etc/sysconfig/udev_retry | /bin/grep -v '^$' | \
         while read line ; do
            for subsystem in $line ; do
               /bin/udevadm trigger --subsystem-match=$subsystem --action=add || true
            done
         done
         if ! is_true "$OMIT_UDEV_RETRY_SETTLE"; then
            /bin/udevadm settle --timeout=30 || true
         fi
      ) &
"""


def patch(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    if text.count(old) != 1:
        raise SystemExit(f"udev-nonblocking: expected exactly one match in {path}")
    path.write_text(text.replace(old, new, 1))


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {sys.argv[0]} <staged-root>")

    root = Path(sys.argv[1])
    patch(root / "etc/rc.d/init.d/udev", UDEV_OLD, UDEV_NEW)
    patch(root / "etc/rc.d/init.d/udev_retry", UDEV_RETRY_OLD, UDEV_RETRY_NEW)


if __name__ == "__main__":
    main()

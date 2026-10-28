#!/usr/bin/env python3
"""Exercise artifact collection and failure gating without booting a VM."""
import hashlib
import os
import pathlib
import subprocess
import tempfile
import unittest

REPO = pathlib.Path(__file__).resolve().parents[1]

@unittest.skipUnless(os.uname().sysname == 'Darwin', 'macOS launcher')
class IsoCollectionTests(unittest.TestCase):
    def test_ready_collects_and_runs_smoke_failed_build_never_stops_vm(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            bindir = root / 'bin'
            bindir.mkdir()
            digest = hashlib.sha256(b'iso-fixture').hexdigest()
            lima = bindir / 'limactl'
            lima.write_text('''#!/bin/sh
case "$1" in
 shell)
  if [ "$4" = printenv ]; then [ "${CONNECT_FAIL:-0}" = 0 ] || exit 1; echo /guest; else echo "${BUILD_STATE:-READY fixture}"; fi ;;
 copy)
  case "$2" in
   *.sha256) printf '%s  kryptos.iso\\n' "$FIXTURE_HASH" > "$3" ;;
   *) printf iso-fixture > "$3" ;;
  esac ;;
 stop) touch "$STOP_MARKER" ;;
 *) exit 2 ;;
esac
''')
            lima.chmod(0o755)
            qemu = bindir / 'fake-qemu'
            qemu.write_text('#!/bin/sh\necho "kryptos login:"\nsleep 3\n')
            qemu.chmod(0o755)
            stop = root / 'stopped'
            env = dict(os.environ, PATH=str(bindir)+':'+os.environ['PATH'], QEMU_BIN=str(qemu),
                       FIXTURE_HASH=digest, STOP_MARKER=str(stop), TIMEOUT='5')
            script = str(REPO / 'scripts/61-collect-macos-base-iso.sh')
            result = subprocess.run(['bash', script, str(root / 'dist')], env=env, capture_output=True, text=True, timeout=15)
            self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
            self.assertTrue(stop.exists())
            self.assertIn('PASS', (root / 'dist/mac-boot-status.txt').read_text())
            stop.unlink()
            env['BUILD_STATE'] = 'FAILED phase=compile exit=1'
            result = subprocess.run(['bash', script, str(root / 'failed')], env=env, capture_output=True, text=True, timeout=15)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(stop.exists())
            self.assertFalse((root / 'failed/kryptos.iso').exists())

    def test_connection_failure_replaces_stale_waiting(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            bindir = root / 'bin'
            bindir.mkdir()
            lima = bindir / 'limactl'
            lima.write_text('#!/bin/sh\necho "VM unavailable" >&2\nexit 1\n')
            lima.chmod(0o755)
            dist = root / 'dist'
            dist.mkdir()
            status = dist / 'mac-boot-status.txt'
            status.write_text('WAITING stale result')
            env = dict(os.environ, PATH=str(bindir)+':'+os.environ['PATH'])
            result = subprocess.run(['bash', str(REPO / 'scripts/61-collect-macos-base-iso.sh'), str(dist)],
                                    env=env, capture_output=True, text=True, timeout=5)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('FAILED phase=connect', status.read_text())
            self.assertNotIn('WAITING', status.read_text())

if __name__ == '__main__':
    unittest.main()

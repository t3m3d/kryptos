#!/usr/bin/env python3
"""Test launcher failure paths with fake guest devices and compositor."""
import os
import pathlib
import socket
import subprocess
import tempfile
import unittest

REPO = pathlib.Path(__file__).resolve().parents[1]

class DesktopTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temp.name)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.runtime = self.root / 'runtime'
        self.runtime.mkdir()
        (self.root / 'dri').mkdir()
        (self.root / 'dri/card0').touch()
        (self.root / 'log').mkdir()
        source = (REPO / 'config/start-hypr').read_text()
        for before, after in [('/run/user/0', str(self.runtime)), ('/dev/dri', str(self.root / 'dri')), ('/sys/class/drm', str(self.root / 'drm')), ('/var/log', str(self.root / 'log'))]:
            source = source.replace(before, after)
        self.launcher = self.root / 'start-hypr'
        self.launcher.write_text(source)
        self.fake('id', 'echo 0')
        self.fake('flock', 'exit "${LOCK_STATUS:-0}"')
        self.env = dict(os.environ, PATH=str(self.bin)+':/usr/bin:/bin', STARTUP_TIMEOUT='1')
        self.env.pop('DBUS_SESSION_BUS_ADDRESS', None)

    def tearDown(self):
        self.temp.cleanup()

    def fake(self, name, body):
        target = self.bin / name
        target.write_text('#!/bin/sh\n'+body+'\n')
        target.chmod(0o755)

    def launch(self):
        return subprocess.run(['sh', str(self.launcher)], env=self.env, capture_output=True, text=True, timeout=5)

    def test_early_exit_keeps_compositor_status(self):
        self.fake('Hyprland', 'echo deliberate-failure; exit 7')
        result = self.launch()
        self.assertEqual(result.returncode, 7)
        self.assertIn('status 7', result.stderr)
        self.assertIn('deliberate-failure', (self.root / 'log/hypr.log').read_text())

    def test_timeout_terminates_compositor(self):
        pidfile = self.root / 'pid'
        self.fake('Hyprland', f'echo $$ > "{pidfile}"; exec sleep 30')
        result = self.launch()
        self.assertEqual(result.returncode, 1)
        self.assertIn('timed out', result.stderr)
        with self.assertRaises(ProcessLookupError):
            os.kill(int(pidfile.read_text()), 0)

    def test_lock_refuses_duplicate(self):
        self.fake('Hyprland', 'exit 0')
        self.env['LOCK_STATUS'] = '1'
        result = self.launch()
        self.assertEqual(result.returncode, 1)
        self.assertIn('already running', result.stderr)

    def test_existing_socket_never_counts_as_ready(self):
        self.fake('Hyprland', 'exit 0')
        with socket.socket(socket.AF_UNIX) as sock:
            sock.bind(str(self.runtime / 'wayland-0'))
            result = self.launch()
        self.assertEqual(result.returncode, 1)
        self.assertIn('existing Wayland socket', result.stderr)
        self.assertFalse((self.root / 'log/hypr.log').exists())

    def test_missing_drm(self):
        self.fake('Hyprland', 'exit 0')
        (self.root / 'dri/card0').unlink()
        result = self.launch()
        self.assertEqual(result.returncode, 1)
        self.assertIn('no DRM device', result.stderr)

    def test_session_bus_address_is_exported(self):
        seen = self.root / 'bus-env'
        self.fake('dbus-daemon', 'echo "unix:path=/fake/bus"')
        self.fake('Hyprland', f'printf "%s" "$DBUS_SESSION_BUS_ADDRESS" > "{seen}"; exit 0')
        result = self.launch()
        self.assertEqual(result.returncode, 0)
        self.assertEqual(seen.read_text(), 'unix:path=/fake/bus')

    def test_report_no_overwrite(self):
        report = self.root / 'report.txt'
        report.write_text('preserve me')
        result = subprocess.run(['bash', str(REPO / 'config/kryptos-diagnose'), str(report)], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(report.read_text(), 'preserve me')

if __name__ == '__main__':
    unittest.main()

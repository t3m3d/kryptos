#!/usr/bin/env python3
"""Offline network-service and existing-build migration regression tests."""
import os
import pathlib
import subprocess
import tempfile
import unittest

REPO = pathlib.Path(__file__).resolve().parents[1]
OLD = "ONBOOT=yes\nIFACE=eth0\nSERVICE=ipv4-static\nIP=10.0.2.15\nGATEWAY=10.0.2.2\nPREFIX=24\nBROADCAST=10.0.2.255\n"

class NetworkTests(unittest.TestCase):
    def test_service_discovers_interfaces_and_excludes_static(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            config = root / "sysconfig"
            config.mkdir()
            (config / "ifconfig.enp3s0").write_text('IFACE="enp3s0"\n')
            (config / "ifconfig.eth0").write_text('IFACE=eth0\n')
            # A migration backup must not be treated as interface config.
            (config / "kryptos-qemu-static.bak").write_text(OLD)
            fake = root / "dhcpcd"
            fake.write_text('#!/bin/sh\nprintf "%s\n" "$@"\n')
            fake.chmod(0o755)
            env = dict(os.environ, DHCPCD=str(fake), SYSCONFIG=str(config))
            script = str(REPO / "config/kryptos-network")
            result = subprocess.run(['sh', script, 'start'], env=env, capture_output=True, text=True, check=True)
            args = result.stdout.splitlines()
            self.assertEqual(args[0], '-b')
            self.assertEqual(args[1::2], ['--denyinterfaces', '--denyinterfaces'])
            self.assertEqual(set(args[2::2]), {'eth0', 'enp3s0'})
            result = subprocess.run(['sh', script, 'stop'], env=env, capture_output=True, text=True, check=True)
            self.assertEqual(result.stdout.strip(), '--exit')
            (config / "ifconfig.enp3s0").unlink()
            (config / "ifconfig.eth0").unlink()
            result = subprocess.run(['sh', script, 'start'], env=env, capture_output=True, text=True, check=True)
            self.assertEqual(result.stdout.strip(), '-b')
            fake.unlink()
            self.assertNotEqual(subprocess.run(['sh', script, 'start'], env=env, capture_output=True).returncode, 0)

    def test_migrate_exact_defaults_preserve_custom(self):
        source = (REPO / 'scripts/chroot/ch21-network.sh').read_text()
        function = source[source.index('b_network_dhcp()'):source.index('msg "wired DHCP')]
        for custom in [False, True]:
            with self.subTest(custom=custom), tempfile.TemporaryDirectory() as temp:
                root = pathlib.Path(temp)
                etc = root / 'etc'
                (etc / 'sysconfig').mkdir(parents=True)
                (etc / 'rc.d/init.d').mkdir(parents=True)
                interface = etc / 'sysconfig/ifconfig.eth0'
                original = OLD.replace('10.0.2.15', '192.168.1.20') if custom else OLD
                interface.write_text(original)
                resolver = etc / 'resolv.conf'
                dns = 'nameserver 192.168.1.1\n' if custom else 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n'
                resolver.write_text(dns)
                # Redirect all target writes into fixture; never touch host /etc.
                redirected = function.replace('/etc', str(etc)).replace('/root/kryptos/config', str(REPO / 'config'))
                subprocess.run(['bash', '-e', '-c', redirected + '\nb_network_dhcp'], check=True)
                if custom:
                    self.assertEqual(interface.read_text(), original)
                    self.assertEqual(resolver.read_text(), dns)
                else:
                    self.assertFalse(interface.exists())
                    self.assertEqual((etc / 'sysconfig/kryptos-qemu-static.bak').read_text(), OLD)
                    self.assertNotIn('1.1.1.1', resolver.read_text())
                for level in [2, 3, 4, 5]:
                    link = etc / f'rc.d/rc{level}.d/S21kryptos-network'
                    self.assertTrue(link.is_symlink())
                    self.assertTrue(link.resolve().is_file())
                for level in [0, 1, 6]:
                    self.assertTrue((etc / f'rc.d/rc{level}.d/K79kryptos-network').is_symlink())

if __name__ == '__main__':
    unittest.main()

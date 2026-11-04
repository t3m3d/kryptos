#!/usr/bin/env python3
"""kryptos-install argument handling. Bad input must be refused before any
partitioning runs, so these cases all exit ahead of the disk checks."""
import pathlib
import subprocess
import unittest

REPO = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = REPO / 'scripts/live/kryptos-install'


def run(*args):
    return subprocess.run(['bash', str(SCRIPT), *args],
                          capture_output=True, text=True, timeout=30)


class InstallArgumentTests(unittest.TestCase):
    def test_unknown_gpu_value_is_refused(self):
        result = run('--yes', '/dev/null', '--gpu=bogus')
        self.assertEqual(result.returncode, 2, result.stdout)
        self.assertIn('--gpu', result.stderr)

    def test_gpu_flag_without_value_is_refused(self):
        result = run('--yes', '/dev/null', '--gpu')
        self.assertEqual(result.returncode, 2, result.stdout)
        self.assertIn('--gpu', result.stderr)

    def test_valid_gpu_values_reach_the_disk_check(self):
        for value in ('auto', 'amd', 'intel', 'both'):
            with self.subTest(gpu=value):
                result = run('--yes', '/dev/null', f'--gpu={value}')
                self.assertEqual(result.returncode, 1, result.stdout)
                self.assertIn('not a block device', result.stderr)

    def test_gpu_flag_may_follow_the_disk(self):
        result = run('--yes', '/dev/null', '--gpu', 'amd')
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn('not a block device', result.stderr)

    def test_extra_positional_is_refused(self):
        result = run('--yes', '/dev/null', 'surplus')
        self.assertEqual(result.returncode, 2, result.stdout)

    def test_missing_yes_is_refused(self):
        result = run('/dev/null')
        self.assertEqual(result.returncode, 2, result.stdout)
        self.assertIn('usage:', result.stdout)


if __name__ == '__main__':
    unittest.main()

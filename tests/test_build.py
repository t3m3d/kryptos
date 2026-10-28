#!/usr/bin/env python3
"""Build framework regressions that otherwise block the ISO build."""
import os
import pathlib
import subprocess
import tempfile
import unittest

REPO = pathlib.Path(__file__).resolve().parents[1]

class BuildTests(unittest.TestCase):
    def run_fixture(self, root, command):
        return subprocess.run(['bash', '-c', 'source "$KRYPTOS_ROOT/lib/build.sh"; ' + command],
                              env=dict(os.environ, LFS=str(root), KRYPTOS_ROOT=str(REPO)),
                              capture_output=True, text=True)

    def test_patch_lookup_and_ambiguity(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            sources = root / 'sources'
            sources.mkdir()
            patch = sources / 'glibc-2.40-fhs-1.patch'
            patch.touch()
            # Archive lookup must not be used for patches.
            (sources / 'glibc-2.40.tar.xz').touch()
            result = self.run_fixture(root, 'find_patch glibc-2.40-fhs')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), str(patch))
            (sources / 'glibc-2.40-fhs-2.patch').touch()
            self.assertNotEqual(self.run_fixture(root, 'find_patch glibc-2.40-fhs').returncode, 0)
            self.assertNotEqual(self.run_fixture(root, 'find_patch missing').returncode, 0)

    def test_failed_recipe_never_creates_done_checkpoint(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            result = self.run_fixture(root, 'recipe() { false; touch "$LFS/incorrect-success"; }; step failure recipe')
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((root / 'incorrect-success').exists())
            self.assertFalse((root / 'build-state/failure.done').exists())
            self.assertTrue((root / 'build-logs/failure.log').exists())

if __name__ == '__main__':
    unittest.main()

#!/usr/bin/env python3
"""Prevent launchd restarts and protected-directory runtime regressions."""
import pathlib
import plistlib
import runpy
import tempfile
import unittest

REPO = pathlib.Path(__file__).resolve().parents[1]
HELPER = runpy.run_path(str(REPO / 'scripts/62-prepare-macos-jobs.py'))


class MacJobsTests(unittest.TestCase):
    def test_jobs_are_one_shot_and_runtime_uses_unprotected_folder(self):
        with tempfile.TemporaryDirectory() as temp:
            runtime = pathlib.Path(temp) / 'runtime with spaces'
            jobs = HELPER['prepare_runtime'](REPO, runtime, pathlib.Path('/opt/homebrew/bin/limactl'))
            self.assertEqual(len(jobs), 3)
            for label in jobs:
                definition = plistlib.loads((runtime / 'launchd' / (label+'.plist')).read_bytes())
                self.assertIs(definition['KeepAlive'], False)
                self.assertIs(definition['RunAtLoad'], True)
                for name in ['StandardOutPath', 'StandardErrorPath']:
                    self.assertEqual(pathlib.Path(definition[name]).parent, runtime / 'logs')
                self.assertNotIn(str(REPO), str(definition))
            self.assertTrue((runtime / 'scripts/61-collect-macos-base-iso.sh').is_file())
            self.assertEqual(runtime.stat().st_mode & 0o777, 0o700)

    def test_script_refresh_does_not_mutate_open_script(self):
        with tempfile.TemporaryDirectory() as temp:
            runtime = pathlib.Path(temp) / 'runtime'
            HELPER['prepare_runtime'](REPO, runtime, pathlib.Path('/opt/homebrew/bin/limactl'))
            script = runtime / 'scripts/61-collect-macos-base-iso.sh'
            script.write_bytes(b'old running script')
            with script.open('rb') as running:
                HELPER['prepare_runtime'](REPO, runtime, pathlib.Path('/opt/homebrew/bin/limactl'))
                self.assertEqual(running.read(), b'old running script')
            self.assertEqual(script.read_bytes(), (REPO / 'scripts/61-collect-macos-base-iso.sh').read_bytes())


if __name__ == '__main__':
    unittest.main()

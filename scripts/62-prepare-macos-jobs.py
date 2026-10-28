#!/usr/bin/env python3
"""Prepare one-shot launchd jobs; loading/stopping them is a separate action.

Runtime lives outside Documents because launchd may lack TCC access there.
No recurring job, login-item installation, or privilege changes are made.
"""
import argparse
import os
from pathlib import Path
import plistlib
import shutil
import tempfile

HOST_SCRIPTS = (
    '43-verify-boot-artifact.sh', '45-boot-iso.sh', '46-smoke-iso.sh',
    '47-test-macos-iso.sh', '61-collect-macos-base-iso.sh',
)


def atomic_write(path, data, mode=0o600):
    fd, temporary = tempfile.mkstemp(dir=path.parent, prefix=path.name+'.')
    try:
        with os.fdopen(fd, 'wb') as output:
            output.write(data)
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def prepare_runtime(repo, runtime, lima):
    runtime.mkdir(parents=True, exist_ok=True)
    runtime.chmod(0o700)
    for folder in ('scripts', 'logs', 'launchd', 'dist/x86_64'):
        (runtime / folder).mkdir(parents=True, exist_ok=True)
    # Atomic replacement lets an already-running shell retain its old script.
    for script in HOST_SCRIPTS:
        atomic_write(runtime / 'scripts' / script,
                     (repo / 'scripts' / script).read_bytes(), 0o700)
    jobs = {
        'local.kryptos.build-vm': [str(lima), 'start', 'krypton', '--foreground', '--tty=false', '--timeout=4m'],
        'local.kryptos.base-build': [
            '/usr/bin/caffeinate', '-i', str(lima), 'shell', 'krypton', '--', 'bash', '-c',
            'cd "$HOME/kryptos-macos-build" && exec env LFS=/mnt/lfs '
            'OUT="$HOME/kryptos-base-dist" bash scripts/60-build-base-iso.sh '
            '> "$HOME/kryptos-base-build.log" 2>&1',
        ],
        'local.kryptos.iso-collect': [
            '/usr/bin/caffeinate', '-i', '/bin/bash',
            str(runtime / 'scripts/61-collect-macos-base-iso.sh'), str(runtime / 'dist/x86_64'),
        ],
    }
    for label, arguments in jobs.items():
        definition = {
            'Label': label, 'ProgramArguments': arguments,
            'RunAtLoad': True, 'KeepAlive': False,
            'EnvironmentVariables': {'PATH': str(lima.parent)+':/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin'},
            'StandardOutPath': str(runtime / 'logs' / (label+'.stdout.log')),
            'StandardErrorPath': str(runtime / 'logs' / (label+'.stderr.log')),
        }
        atomic_write(runtime / 'launchd' / (label+'.plist'), plistlib.dumps(definition))
    return jobs


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-dir', type=Path,
                        default=Path.home() / 'Library/Application Support/KryptOS/iso-build')
    args = parser.parse_args()
    if os.uname().sysname != 'Darwin':
        parser.error('run on macOS')
    lima = shutil.which('limactl')
    if not lima:
        parser.error('limactl is required')
    if os.getuid() == 0:
        parser.error('run as the normal macOS user, not root')
    runtime = args.runtime_dir.expanduser().resolve()
    prepare_runtime(Path(__file__).resolve().parents[1], runtime, Path(lima))
    print(f'Prepared one-shot job definitions: {runtime / "launchd"}')
    print('No jobs loaded. VM must be healthy before loading builder and collector.')


if __name__ == '__main__':
    main()

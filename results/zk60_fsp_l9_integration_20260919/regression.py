#!/usr/bin/env python3
"""Detached full regression; retain timeout/failure status and named test output."""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def run():
    destination = OUT / 'regression-v2.json'
    if destination.exists():
        raise SystemExit('refusing to overwrite regression evidence')
    env = {k: v for k, v in os.environ.items() if not k.startswith(('HL_', 'RUSTFLAGS', 'CARGO_'))}
    env.update(RAYON_NUM_THREADS='2', CARGO_BUILD_JOBS='2',
               M125_EXPORT_DIR=str(ROOT / 'results/m125_ffn_export_wsl'),
               HL_NATIVE_CAPTURE_TEST_BINARY='/tmp/zk60-native-capture-verifier-2b5c65c')
    report = {'state': 'running', 'runs': [], 'runner_sha256': digest(Path(__file__)),
              'previous_attempt': 'python-regression.log',
              'previous_outcome': '240-second timeout; the previous full suite took 861 seconds',
              'source_hashes': {str(p.relative_to(ROOT)): digest(p) for p in sorted(
                  list((ROOT / 'scripts').glob('*.py')) + list((ROOT / 'tests').glob('*.py')))}}

    def save():
        temporary = destination.with_suffix('.json.tmp')
        temporary.write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
        temporary.replace(destination)

    save()
    try:
        with open('/tmp/zk-build.lock', 'w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            for name, command in [('native-freeze', [str(ROOT / 'zkmatrix-rs/target/release/ring_matmul'), 'freeze-check']),
                                  ('python-regression-v2', [sys.executable, '-m', 'unittest', 'discover', '-v', '-s', 'tests'])]:
                report['current'] = name
                save()
                print('START', name, flush=True)
                started = time.monotonic()
                with (OUT / (name + '.log')).open('x') as log:
                    child = subprocess.Popen(command, cwd=ROOT, env=env, stdin=subprocess.DEVNULL,
                                             stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
                    try:
                        status = child.wait(timeout=2400)
                    except subprocess.TimeoutExpired:
                        os.killpg(child.pid, signal.SIGKILL)
                        child.wait()
                        status = 124
                (OUT / (name + '.done')).write_text(str(status) + '\n')
                report['runs'].append({'name': name, 'argv': command, 'exit_code': status,
                                      'elapsed_shared_seconds': time.monotonic() - started})
                save()
                if status:
                    raise RuntimeError(f'{name}: exit {status}')
                print('PASS', name, flush=True)
        for relative, expected in report['source_hashes'].items():
            if digest(ROOT / relative) != expected:
                raise RuntimeError('regression source changed: ' + relative)
        report['state'] = 'passed'
        report['current'] = None
        save()
        (OUT / 'regression-v2.done').write_text('0\n')
    except BaseException as error:
        report['state'] = 'failed'
        report['error'] = str(error)
        save()
        (OUT / 'regression-v2.done').write_text('1\n')
        raise


if __name__ == '__main__':
    if sys.argv[1:] == ['--detach']:
        with (OUT / 'regression-v2-launch.log').open('x') as log:
            child = subprocess.Popen([sys.executable, str(Path(__file__).resolve())], cwd=ROOT,
                                     stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
                                     start_new_session=True)
        (OUT / 'regression-v2-process.json').write_text(json.dumps({'pid': child.pid, 'detached': True}) + '\n')
        print('Detached regression PID', child.pid, flush=True)
        raise SystemExit(child.wait())
    run()

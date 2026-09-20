#!/usr/bin/env python3
"""Check the demo's D21 publication guard without replacing pinned proof binaries."""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent


def sha(p):
    h = hashlib.sha256()
    with Path(p).open('rb') as f:
        for b in iter(lambda: f.read(1024 * 1024), b''):
            h.update(b)
    return h.hexdigest()


def main():
    if (OUT / 'validation.json').exists():
        raise SystemExit('refusing to overwrite evidence')
    baseline = json.loads((ROOT / 'results/zk60_rowfold_20260919/integration/validation.json').read_text())
    pins = {p: sha(ROOT / p) for p in baseline['source_hashes']}
    argv = ['/home/victor/.cargo/bin/cargo', 'test', '--release', '--locked', '--offline', '-j', '2',
            '--manifest-path', 'hashline/Cargo.toml', '--example', 'zk60_private_block', '--', '--test-threads=1', '--nocapture']
    report = dict(state='waiting-build-lock', argv=argv, source_hashes=pins,
                  runner_sha256=sha(Path(__file__)), binary_hashes=baseline['binary_hashes'])

    def save():
        tmp = OUT / 'validation.tmp'
        tmp.write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
        tmp.replace(OUT / 'validation.json')

    save()
    try:
        assert all(sha(ROOT / p) == h for p, h in report['binary_hashes'].items())
        env = {k: v for k, v in os.environ.items() if not k.startswith(('HL_', 'CARGO_', 'RUSTFLAGS'))}
        env.update(CARGO_BUILD_JOBS='2', RAYON_NUM_THREADS='2')
        with open('/tmp/zk-build.lock', 'w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            report['state'] = 'running'
            save()
            with (OUT / 'example-tests.log').open('x') as log:
                child = subprocess.Popen(argv, cwd=ROOT, env=env, stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT)
                report['child_pid'] = child.pid
                save()
                code = child.wait()
        report['exit_code'] = code
        log = (OUT / 'example-tests.log').read_text()
        report['log_sha256'] = sha(OUT / 'example-tests.log')
        assert code == 0 and 'test result: ok. 1 passed; 0 failed; 0 ignored' in log
        assert 'ACCEPT: 2816472 bytes' in log and log.count('refused:') == 3
        for p, h in pins.items(): assert sha(ROOT / p) == h, 'source changed: ' + p
        for p, h in report['binary_hashes'].items(): assert sha(ROOT / p) == h, 'proof binary changed: ' + p
        assert sha(Path(__file__)) == report['runner_sha256']
        report.update(state='passed', child_pid=None)
        save()
        (OUT / 'run.done').write_text('0\n')
    except BaseException as e:
        report.update(state='failed', error=repr(e))
        save()
        (OUT / 'run.done').write_text('1\n')
        raise


if __name__ == '__main__':
    if sys.argv[1:] == ['--detach']:
        with (OUT / 'launch.log').open('x') as log:
            child = subprocess.Popen([sys.executable, str(Path(__file__).resolve())], cwd=ROOT,
                                     stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        (OUT / 'process.json').write_text(json.dumps(dict(pid=child.pid, detached=True)) + '\n')
        print('Detached publication validation PID', child.pid, flush=True)
    else:
        main()

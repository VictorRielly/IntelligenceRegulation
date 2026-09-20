#!/usr/bin/env python3
"""Measure the complete storage-feature test inventory without replacing proof binaries."""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent / 'storage-gate'


def sha(p):
    h = hashlib.sha256()
    with p.open('rb') as f:
        for b in iter(lambda: f.read(1024 * 1024), b''):
            h.update(b)
    return h.hexdigest()


def main():
    OUT.mkdir(exist_ok=True)
    report_path = OUT / 'validation.json'
    if report_path.exists():
        raise SystemExit('refusing to overwrite evidence')
    pins = json.loads((OUT.parent / 'integration/validation.json').read_text())
    files = list(pins['source_hashes'])
    files += [str(p.relative_to(ROOT)) for p in (ROOT / 'hashline/tests').rglob('*.rs')]
    files += [str(p.relative_to(ROOT)) for p in (ROOT / 'hashline/examples').rglob('*.rs')]
    files += [str(p.relative_to(ROOT)) for p in (ROOT / 'zkp-core/tests').rglob('*.rs')]
    hashes = {p: sha(ROOT / p) for p in sorted(set(files))}
    assert all(hashes[p] == h for p, h in pins['source_hashes'].items())
    binaries = pins['binary_hashes']
    assert all(sha(ROOT / p) == h for p, h in binaries.items())
    env = {k: v for k, v in os.environ.items() if not k.startswith(('HL_', 'CARGO_', 'RUSTFLAGS'))}
    extra = dict(CARGO_BUILD_JOBS='2', RAYON_NUM_THREADS='2',
                 M125_EXPORT_DIR=str(ROOT / 'results/m125_ffn_export_wsl'),
                 CARGO_TARGET_DIR=str(ROOT / 'hashline/target/storage-tests'))
    argv = ['/home/victor/.cargo/bin/cargo', 'test', '--release', '--locked', '--offline',
            '--manifest-path', str(ROOT / 'hashline/Cargo.toml'),
            '--features', 'stable-weight-storage', '--', '--test-threads=2']
    report = dict(state='waiting-build-lock', source_hashes=hashes, binary_hashes=binaries,
                  runner_sha256=sha(Path(__file__)), argv=argv, environment=extra)

    def save():
        tmp = report_path.with_suffix('.tmp')
        tmp.write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
        tmp.replace(report_path)

    save()
    try:
        with open('/tmp/zk-build.lock', 'w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            report['state'] = 'running'
            save()
            with (OUT / 'storage-tests.log').open('x') as log:
                child = subprocess.Popen(argv, cwd=ROOT, env=env | extra, stdin=subprocess.DEVNULL,
                                         stdout=log, stderr=subprocess.STDOUT)
                report['child_pid'] = child.pid
                save()
                report['exit_code'] = child.wait()
        log = (OUT / 'storage-tests.log').read_text()
        rows = [list(map(int, m)) for m in re.findall(
            r'test result: ok\. (\d+) passed; (\d+) failed; (\d+) ignored', log)]
        report['result_lines'] = rows
        report['totals'] = dict(zip(['passed', 'failed', 'ignored'], map(sum, zip(*rows))))
        report['log_sha256'] = sha(OUT / 'storage-tests.log')
        assert report['exit_code'] == 0 and rows and report['totals']['failed'] == 0
        assert all(sha(ROOT / p) == h for p, h in hashes.items()), 'source changed'
        assert all(sha(ROOT / p) == h for p, h in binaries.items()), 'proof binary changed'
        assert sha(Path(__file__)) == report['runner_sha256'], 'runner changed'
        report['state'] = 'passed'
        save()
        (OUT / 'run.done').write_text('0\n')
    except BaseException as e:
        report.update(state='failed', error=repr(e))
        save()
        (OUT / 'run.done').write_text('1\n')
        raise


if __name__ == '__main__':
    if sys.argv[1:] == ['--detach']:
        OUT.mkdir(exist_ok=True)
        with (OUT / 'launch.log').open('x') as log:
            p = subprocess.Popen([sys.executable, str(Path(__file__).resolve())], cwd=ROOT,
                                 stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
                                 start_new_session=True)
        (OUT / 'runner.pid').write_text(str(p.pid) + '\n')
        print('detached PID', p.pid, flush=True)
    else:
        main()

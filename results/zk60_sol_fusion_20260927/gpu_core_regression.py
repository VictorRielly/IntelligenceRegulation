#!/usr/bin/env python3
"""Core CPU regression on the frozen GPU candidate; no device/library rerun."""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

HERE = Path(__file__).resolve().parent
OUT = HERE / 'gpu-cpu-regression'
ROOT = Path('/tmp/zk60-sol-gpu-20260927')
PINS = json.loads((HERE.parent / 'zk60_sol_gpu_20260927/attempt-2/pins.json').read_text())
OUT.mkdir(exist_ok=False)
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def pin_check():
    bad = [n for n, h in PINS['sources'].items() if digest(ROOT / n) != h]
    if bad: raise RuntimeError('source pin mismatch: ' + str(bad))
    return len(PINS['sources'])

report = {'state': 'starting', 'candidate': str(ROOT), 'runs': [],
          'runner_sha256': digest(Path(__file__))}
def save(): (OUT / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
try:
    report['source_pins_before'] = pin_check()
    report['state'] = 'waiting-for-build-lock'; save()
    env = dict(os.environ, CARGO_BUILD_JOBS='2', RAYON_NUM_THREADS='2', HL_GPU='0')
    with open('/tmp/zk-build.lock', 'a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        for name, extra in [('core-debug', []), ('core-release', ['--release'])]:
            cmd = ['/home/victor/.cargo/bin/cargo', 'test', '--offline', '--locked', '-j', '2',
                   '--manifest-path', str(ROOT / 'zkp-core/Cargo.toml'), *extra,
                   '--', '--test-threads=2']
            report.update(state='running', current=name); save()
            print('START ' + name, flush=True)
            start = time.monotonic()
            log = OUT / (name + '.log')
            with log.open('w') as f:
                proc = subprocess.run(cmd, cwd=ROOT, env=env, stdout=f, stderr=subprocess.STDOUT)
            report['runs'].append({'name': name, 'command': cmd, 'exit_code': proc.returncode,
                                   'seconds_shared': time.monotonic() - start,
                                   'log_sha256': digest(log)})
            save()
            print('DONE ' + name + ' exit=' + str(proc.returncode), flush=True)
            if proc.returncode: raise RuntimeError(name + ' failed')
    report['source_pins_after'] = pin_check()
    report.update(state='passed', current=None); save()
    (OUT / 'run.done').write_text('0\n')
except BaseException as exc:
    report.update(state='failed', error=str(exc)); save()
    (OUT / 'run.done').write_text('1\n')
    raise

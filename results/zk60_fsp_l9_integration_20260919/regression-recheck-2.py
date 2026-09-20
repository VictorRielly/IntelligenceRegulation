#!/usr/bin/env python3
"""Recheck the floors runner after the outer-build-lock self-deadlock.

The original full-suite failure is retained. No source or test is changed.
Only the affected test class is rerun; its child takes its own build lock.
"""
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


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run():
    destination = OUT / 'regression-recheck-2.json'
    if destination.exists():
        raise SystemExit('refusing to overwrite evidence')
    original = json.loads((OUT / 'regression-v2.json').read_text())
    report = {'state': 'running', 'previous_result': 'regression-v2.json',
              'runner_sha256': sha(Path(__file__)),
              'original_report_sha256': sha(OUT / 'regression-v2.json'),
              'original_log_sha256': sha(OUT / 'python-regression-v2.log'),
              'outer_build_lock_during_tests': False,
              'test_isolation_change': 'tests/test_hashline_cl_gpu_gates.py: missing-cargo leg avoids the real global lock',
              'test_sha256': sha(ROOT / 'tests/test_hashline_cl_gpu_gates.py')}
    original['source_hashes']['tests/test_hashline_cl_gpu_gates.py'] = report['test_sha256']

    def save():
        tmp = destination.with_suffix('.tmp')
        tmp.write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
        tmp.replace(destination)

    def unchanged():
        changed = [p for p, h in original['source_hashes'].items() if sha(ROOT / p) != h]
        if changed:
            raise RuntimeError('source changes require separate assessment: ' + str(changed))

    save()
    try:
        unchanged()
        # No cargo work occurs: the revised test isolates the missing-tool
        # leg from the real build lock. Do not queue behind actual builds.
        env = {k: v for k, v in os.environ.items() if not k.startswith(('HL_', 'CARGO_', 'RUSTFLAGS'))}
        env.update(PYTHONPATH=str(ROOT / 'tests'), RAYON_NUM_THREADS='2', CARGO_BUILD_JOBS='2')
        argv = [sys.executable, '-m', 'unittest', '-v', 'test_hashline_cl_gpu_gates.FloorsRunner']
        report['argv'] = argv
        save()
        start = time.monotonic()
        with (OUT / 'regression-recheck-2.log').open('x') as log:
            child = subprocess.Popen(argv, cwd=ROOT, env=env, stdin=subprocess.DEVNULL,
                                     stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            try:
                code = child.wait(timeout=600)
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait()
                code = 124
        report.update(exit_code=code, elapsed_shared_seconds=time.monotonic() - start,
                      recheck_log_sha256=sha(OUT / 'regression-recheck-2.log'))
        if code:
            raise RuntimeError('targeted recheck exit ' + str(code))
        unchanged()
        report.update(state='passed', source_hashes_rechecked=len(original['source_hashes']))
        save()
        (OUT / 'regression-recheck-2.done').write_text('0\n')
    except BaseException as error:
        report.update(state='failed', error=str(error))
        save()
        (OUT / 'regression-recheck-2.done').write_text('1\n')
        raise


if __name__ == '__main__':
    if sys.argv[1:] == ['--detach']:
        with (OUT / 'regression-recheck-2-launch.log').open('x') as log:
            child = subprocess.Popen([sys.executable, str(Path(__file__).resolve())], cwd=ROOT,
                                     stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
                                     start_new_session=True)
        (OUT / 'regression-recheck-2-process.json').write_text(json.dumps({'pid': child.pid}) + '\n')
        print('Detached regression recheck PID', child.pid, flush=True)
        raise SystemExit(child.wait())
    run()

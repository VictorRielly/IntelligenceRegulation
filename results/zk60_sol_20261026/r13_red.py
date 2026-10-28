#!/usr/bin/env python3
"""Capture failing-first scalar tests from the isolated R13 tree."""
import datetime
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path('/home/victor/IntelligenceRegulation')
OUT = ROOT / 'results/zk60_sol_20261026'
R13 = ROOT / 'results/zk60_1b_native_20261017/r13'
SOURCE = R13 / 'working-tree/hashline/src/private_block/accuracy.rs'
GUARD = ROOT / 'scripts/zk60_resource_guard.py'


def run(name, kind, need, cap, command, expected, *, seconds=180):
    print(datetime.datetime.now(datetime.timezone.utc).isoformat(), name, 'waiting for admission', flush=True)
    deadline = time.monotonic() + 21600
    while time.monotonic() < deadline:
        result = subprocess.run([sys.executable, str(GUARD), 'check', '--class', kind,
                                 '--need-gib', str(need)], capture_output=True, text=True)
        if not (OUT / 'HOLD').exists() and result.returncode == 0 and 'OK to start now' in result.stdout:
            break
        time.sleep(20)
    else:
        raise RuntimeError('admission timeout')
    cmd = [sys.executable, str(GUARD), 'run', '--class', kind, '--need-gib', str(need),
           '--cap-gib', str(cap), '--label', name, '--wait-secs', '30', '--max-secs', str(seconds),
           '--log', str(R13 / f'{name}.log'), '--done', str(R13 / f'{name}.done'),
           '--result-json', str(R13 / f'{name}.guard.json'), '--', *command]
    (R13 / f'{name}.command.json').write_text(json.dumps(cmd, indent=2) + '\n')
    result = subprocess.run(cmd, cwd=ROOT)
    record = json.loads((R13 / f'{name}.guard.json').read_text())
    assert result.returncode == expected and record.get('child_rc') == expected and not record.get('guard_killed'), record


if __name__ == '__main__':
    rc = 1
    try:
        run('r13-red-build', 'build', 0.7, 2,
            ['/home/victor/.cargo/bin/rustc', '--edition=2021', '--test', str(SOURCE), '-o', str(R13 / 'accuracy-red.bin')], 0)
        run('r13-red-tests', 'cpu', 0.5, 1, [str(R13 / 'accuracy-red.bin'), '--test-threads=1'], 101)
        print('Captured expected failing-first R13 scalar tests.', flush=True)
        rc = 0
    finally:
        (R13 / 'red.done').write_text(f'{rc}\n')
    sys.exit(rc)

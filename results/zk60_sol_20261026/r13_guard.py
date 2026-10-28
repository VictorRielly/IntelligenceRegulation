#!/usr/bin/env python3
"""R13 runner for reviewed admission-before-lock guard, without pre-polling."""
import datetime
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path('/home/victor/IntelligenceRegulation')
OUT = ROOT / 'results/zk60_sol_20261026'
R13 = ROOT / 'results/zk60_1b_native_20261017/r13'
GUARD = ROOT / 'scripts/zk60_resource_guard.py'

def run(name, kind, need, cap, command, expected=0, *, seconds=180):
    while (OUT / 'HOLD').exists():
        time.sleep(5)
    cmd = [sys.executable, str(GUARD), 'run', '--class', kind, '--need-gib', str(need),
           '--cap-gib', str(cap), '--label', name, '--wait-secs', '21600', '--max-secs', str(seconds),
           '--log', str(R13 / f'{name}.log'), '--done', str(R13 / f'{name}.done'),
           '--result-json', str(R13 / f'{name}.guard.json'), '--', *command]
    record = R13 / f'{name}.command.json'
    assert not record.exists(), f'Refusing to reuse existing run label {name}'
    record.write_text(json.dumps(cmd, indent=2) + '\n')
    print(datetime.datetime.now(datetime.timezone.utc).isoformat(), name, 'queued directly through reviewed guard', flush=True)
    result = subprocess.run(cmd, cwd=ROOT)
    status = json.loads((R13 / f'{name}.guard.json').read_text())
    assert result.returncode == expected and status.get('child_rc') == expected and not status.get('guard_killed'), status

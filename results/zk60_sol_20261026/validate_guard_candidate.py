#!/usr/bin/env python3
"""Revalidate the retained guard candidate on private test paths."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path('/home/victor/IntelligenceRegulation')
OUT = ROOT / 'results/zk60_sol_20261026'
CANDIDATE = ROOT / 'results/zk60_guard_fix_20261021'
env = dict(os.environ, RUN_SIGNAL_CASES='1', PYTHONDONTWRITEBYTECODE='1')
records = []
for name, script in [('new_tests', 'test_guard_fix.py'),
                     ('existing_on_candidate', 'test_existing_suite_on_copy.py')]:
    log = OUT / f'guard_candidate_{name}.log'
    start = datetime.datetime.now(datetime.timezone.utc).isoformat()
    with log.open('w') as f:
        result = subprocess.run([sys.executable, '-B', str(CANDIDATE / script), '-v'],
                                cwd=ROOT, env=env, stdout=f, stderr=subprocess.STDOUT)
    (OUT / f'guard_candidate_{name}.done').write_text(f'{result.returncode}\n')
    records.append(dict(suite=name, started_utc=start, exit=result.returncode,
                        log=str(log.relative_to(ROOT)),
                        log_sha256=hashlib.sha256(log.read_bytes()).hexdigest()))
    (OUT / 'guard_candidate_tests.json').write_text(json.dumps(records, indent=2) + '\n')
    print(name, result.returncode, flush=True)
    if result.returncode:
        sys.exit(result.returncode)

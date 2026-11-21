#!/usr/bin/env python3
"""Launch one guarded traced job DETACHED (own session): guarded.py writes raw/<label>.done with the exit code.

usage: trace_launch.py <label> <spec> <leg_offset> <need_gib> <cap_gib> <max_secs>
  spec: LANES:THREADS:A36:QUEUES:TIMED[,...]   traces go to raw/traces/<label>_legN.<pid>.tsv (not committed)
"""
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
GUARDED = HERE.parent / 'zk60_a36_core_ahead_20261121' / 'guarded.py'
SCR = '/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/39cab447-559b-4f13-981d-d0346f20681a/scratchpad'
label, spec, offset, need, cap, maxs = sys.argv[1:7]
py = '/Users/victorrielly/zk60-artifacts/a28-tools/venv/bin/python'
(HERE / 'raw' / 'traces').mkdir(parents=True, exist_ok=True)
# guarded.py writes its logs to its own directory's raw/; run it from a copy of its path logic: it uses HERE/raw of guarded.py, so point it at ours by symlink-free wrapper below
cmd = [sys.executable, '-B', str(HERE / 'guarded_here.py'), label, 'gpu', need, cap, maxs, '--', py, str(HERE / 'trace_driver.py'),
       '--out', str(HERE / 'raw' / label), '--scratch', f'{SCR}/{label}', '--spec', spec, '--leg-offset', offset,
       '--trace-prefix', str(HERE / 'raw' / 'traces' / label)]
with (HERE / 'raw' / f'{label}.runner.txt').open('w') as f:
    p = subprocess.Popen(cmd, stdin=subprocess.DEVNULL, stdout=f, stderr=subprocess.STDOUT, start_new_session=True)
print(f'detached {label} pid {p.pid}')

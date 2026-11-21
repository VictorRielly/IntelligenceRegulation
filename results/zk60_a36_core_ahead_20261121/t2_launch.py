#!/usr/bin/env python3
"""Launch one guarded T2 job DETACHED (its own session; survives this session): guarded.py writes raw/<label>.done with the exit code.

usage: t2_launch.py <label> <lanes> <threads> <legs> <timed> <need_gib> <cap_gib> <max_secs> [extra t2_driver args ...]
"""
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCR = '/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/39cab447-559b-4f13-981d-d0346f20681a/scratchpad'
label, lanes, threads, legs, timed, need, cap, maxs, *extra = sys.argv[1:]
py = '/Users/victorrielly/zk60-artifacts/a28-tools/venv/bin/python'
cmd = [sys.executable, '-B', str(HERE / 'guarded.py'), label, 'gpu', need, cap, maxs, '--', py, str(HERE / 't2_driver.py'),
       '--out', str(HERE / 'raw' / label), '--scratch', f'{SCR}/{label}', '--lanes', lanes, '--threads', threads, '--legs', legs, '--timed', timed, *extra]
(HERE / 'raw').mkdir(exist_ok=True)
with (HERE / 'raw' / f'{label}.runner.txt').open('w') as f:
    p = subprocess.Popen(cmd, stdin=subprocess.DEVNULL, stdout=f, stderr=subprocess.STDOUT, start_new_session=True)
print(f'detached {label} pid {p.pid}')

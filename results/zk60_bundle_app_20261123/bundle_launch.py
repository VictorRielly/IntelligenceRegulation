#!/usr/bin/env python3
"""Launch one guarded bundle-test job DETACHED (own session): guarded_here.py writes raw/<label>.done with the exit code.

usage: bundle_launch.py <label> <spec> <need_gib> <cap_gib> <max_secs> <traced 0|1> [ENV=VAL ...]
  spec: ARM:LANES:THREADS:TIMED[,...]  (A = B0 with frs1 sf1; B = B1 with frs1 sf1; C = B1 with frs1 sf1 plus HL_METAL_OPEN_FAST=1 HL_METAL_SPARSE_FOLD_REG8=1)
"""
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCR = '/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/39cab447-559b-4f13-981d-d0346f20681a/scratchpad'
B0 = f'{SCR}/bn-b0/ops/zkp-mvp/gpu-metal/hashline/target/release/examples/zk60_classify'
B1 = f'{SCR}/bn-b1/ops/zkp-mvp/gpu-metal/hashline/target/release/examples/zk60_classify'
label, spec, need, cap, maxs, traced, *extra_env = sys.argv[1:]
py = '/Users/victorrielly/zk60-artifacts/a28-tools/venv/bin/python'
(HERE / 'raw' / 'traces').mkdir(parents=True, exist_ok=True)
cmd = [sys.executable, '-B', str(HERE / 'guarded_here.py'), label, 'gpu', need, cap, maxs, *extra_env, '--', py, str(HERE / 'bundle_driver.py'),
       '--bin0', B0, '--bin1', B1, '--out', str(HERE / 'raw' / label), '--scratch', f'{SCR}/{label}', '--spec', spec, '--leg-offset', '0',
       '--trace-prefix', (str(HERE / 'raw' / 'traces' / label) if traced == '1' else '')]
with (HERE / 'raw' / f'{label}.runner.txt').open('w') as f:
    p = subprocess.Popen(cmd, stdin=subprocess.DEVNULL, stdout=f, stderr=subprocess.STDOUT, start_new_session=True)
print(f'detached {label} pid {p.pid}')

#!/usr/bin/env python3
"""Lane A28: one markdown row per ONE-POST stream run (summary.json + records.json), for the README's table:
the post's latency, proved tok/s, the writer, the three proofs' seconds, the three checks' seconds (verify),
CPU-s per proof, the GPU's utilization.

usage: one_table.py <run tag>...
"""
import json
import sys
from pathlib import Path

R = Path(__file__).resolve().parent
print('| run | binary | env | wall (= the post\'s latency) | proved tok/s | writer | the three proofs at once | the three checks at once (verify) | CPU-s per proof, all | GPU utilization mean |')
print('|---|---|---|---:|---:|---:|---:|---:|---:|---:|')
for tag in sys.argv[1:]:
    s = json.loads((R / f'stream_{tag}' / 'summary.json').read_text())
    recs = json.loads((R / f'stream_{tag}' / 'records.json').read_text())
    w = [r['seconds'] for r in recs if r['kind'] == 'writer']
    p = sorted(r['seconds'] for r in recs if r['kind'] == 'prove')
    c = sorted(r['seconds'] for r in recs if r['kind'] == 'check')
    v = sorted(r['verify_seconds'] for r in recs if r['kind'] == 'check')
    env = ' '.join(f'{k}={v}' for k, v in sorted((s.get('env') or {}).items()) if k not in ('HL_GPU', 'HL_GPU_REQUIRED', 'HL_PB_ORACLE', 'HL_PB_TIMING', 'HL_OWNER_PRIVATE_DIR', 'HL_METAL_QUEUES')) or '-'
    cpu = s.get('cpu') or {}
    g = s.get('gpu') or {}
    ok = '' if s.get('all_checked') else ' NOT ALL CHECKED'
    print(f"| {tag}{ok} | {Path(s['binary']).name} | {env} | {s['wall_s']:.1f} s | {s['proved_tok_per_s']:.2f} | {w[0]:.1f} s | {p[0]:.1f}-{p[-1]:.1f} s | "
          f"{c[0]:.1f}-{c[-1]:.1f} s ({v[0]:.2f}-{v[-1]:.2f}) | {cpu.get('all_cpu_s_per_proof', 0):.1f} | {g.get('mean_pct', 0):.0f}% |")

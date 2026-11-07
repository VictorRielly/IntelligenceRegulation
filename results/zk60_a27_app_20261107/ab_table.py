#!/usr/bin/env python3
"""Lane A27 (from A26): one markdown row per stream run (summary.json), for the README's tables.

usage: ab_table.py <run tag>...
"""
import json
import sys
from pathlib import Path

R = Path(__file__).resolve().parent
print('| run | binary | env | wall s | proved tok/s | steady | per-post latency s | CPU-s / proof (prover, verifier, writer, all) | cores busy | GPU util mean / p50 |')
print('|---|---|---|---:|---:|---:|---|---|---:|---|')
for tag in sys.argv[1:]:
    s = json.loads((R / f'stream_{tag}' / 'summary.json').read_text())
    c, g = s.get('cpu') or {}, s.get('gpu') or {}
    b = Path(s['binary']).name
    env = ' '.join(f'{k}={v}' for k, v in sorted((s.get('env') or {}).items()) if k not in ('HL_GPU', 'HL_GPU_REQUIRED', 'HL_PB_ORACLE', 'HL_PB_TIMING', 'HL_OWNER_PRIVATE_DIR')) or '-'
    d = s.get('deferred')
    if d:
        rate = f"{d['proved_tok_per_s']:.2f} (proof only)"
        wall = f"{d['wall_s']:.1f}"
        steady = f"verifier after: {d['verifier']['wall_s']:.1f} s, {d['verifier']['verified_tok_per_s']:.1f} verified tok/s"
    else:
        rate = f"{s['proved_tok_per_s']:.2f}"
        wall = f"{s['wall_s']:.1f}"
        steady = f"{s['steady']['proved_tok_per_s']:.2f}" if s.get('steady') else '-'
    lat = ', '.join(f"{p['latency_s']:.0f}" for p in s['per_post'])
    cpu = (f"{c['prover_cpu_s_per_proof']:.1f}, {c['checker_cpu_s_per_proof']:.1f}, {c['writer_cpu_s_per_proof']:.1f}, {c['all_cpu_s_per_proof']:.1f}"
           if c else '-')
    busy = f"{(c['prover_cpu_s'] + c['checker_cpu_s'] + c['writer_cpu_s']) / s['wall_s']:.1f}" if c and not d else '-'
    gpu = f"{g['mean_pct']:.0f}% / {g['p50_pct']}%" if g else '-'
    ok = '' if s.get('all_checked') else ' NOT ALL CHECKED'
    print(f"| {tag}{ok} | {b} | {env} | {wall} | {rate} | {steady} | {lat} | {cpu} | {busy} | {gpu} |")

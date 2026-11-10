#!/usr/bin/env python3
"""Lane A28: one line per stream run (summary.json): wall, proved tok/s, second half, first post's
latency, CPU-s per proof (prover / verifier / writer), GPU utilization mean / median.

usage: runsum.py <stream_dir> [...]
"""
import json
import sys

for d in sys.argv[1:]:
    try:
        s = json.load(open(d + '/summary.json'))
    except OSError as e:
        print(d, 'no summary', e)
        continue
    c = s.get('cpu') or {}
    g = s.get('gpu') or {}
    st = s.get('steady') or {}
    first = min((p['latency_s'] for p in s['per_post']), default=0)
    dfr = s.get('deferred')
    extra = f" proof-only {dfr['proved_tok_per_s']:.2f} tok/s ({dfr['wall_s']:.1f} s), verify {dfr['verifier']['wall_s']:.1f} s" if dfr else ''
    print(f"{d.rstrip('/').split('/')[-1]:>14}: wall {s['wall_s']:6.1f} s  {s['proved_tok_per_s']:6.2f} tok/s  half {st.get('proved_tok_per_s') or 0:6.2f}  "
          f"first {first:5.1f} s  cpu/proof {c.get('prover_cpu_s_per_proof', 0):5.1f} / {c.get('checker_cpu_s_per_proof', 0):4.1f} / {c.get('writer_cpu_s_per_proof', 0):4.1f}  "
          f"gpu {g.get('mean_pct', 0):4.1f}% / {g.get('p50_pct', 0)}%  checked {s['all_checked']}{extra}")

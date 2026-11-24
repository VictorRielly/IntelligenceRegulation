#!/usr/bin/env python3
"""Host wave-2 switch (HL_HOST_FAST_W2) app-profile test summary (standard library only; `python3 -I -B hostw2_summary.py <label>`).

Reads raw/<label>/t2_results.json (fields leg, arm, rate). Leg 1 is the discarded lead-in leg and is printed but never read.
After it, two shapes are known:
  A B C C B A      (the verdict set at six lanes by five threads, and the reading at six by eight)
                   C over A: (C1 over A1) and (C2 over A2); B over A: (B1 over A1) and (B2 over A2); the means beside them
  A B B A B A A B  (the default-path set) r = mean of the four B rates over mean of the four A rates, minus one
Nothing here decides; the readings are fixed in the coordination entry that defines each set.
"""
import json
import statistics
import sys
from pathlib import Path

label = sys.argv[1]
d = json.loads((Path(__file__).resolve().parent / 'raw' / label / 't2_results.json').read_text())
rows = d if isinstance(d, list) else d.get('legs', d.get('results', []))
rows = sorted(rows, key=lambda r: r['leg'])
for r in rows:
    vs = r.get('verify_summary') or {}
    print(f"leg {r['leg']} arm {r['arm']} {r['rate']:.3f} tok/s  {r.get('utc_start')} to {r.get('utc_end')}  receipts {vs.get('receipts')} checked {vs.get('checked')} other {vs.get('other')}"
          + ('   (lead-in, not read)' if r['leg'] == 1 else ''))
read = rows[1:]
seq = ''.join(r['arm'] for r in read)
rate = [r['rate'] for r in read]
pc = lambda a, b: (a / b - 1) * 100
print('arms after the lead-in leg:', seq)
if seq == 'ABCCBA':
    a1, b1, c1, c2, b2, a2 = rate
    print(f'C over A: {pc(c1, a1):+.2f}% (first half)  {pc(c2, a2):+.2f}% (second half); mean C over mean A {pc(c1 + c2, a1 + a2):+.2f}%')
    print(f'B over A: {pc(b1, a1):+.2f}% (first half)  {pc(b2, a2):+.2f}% (second half); mean B over mean A {pc(b1 + b2, a1 + a2):+.2f}%')
    hi = max(a1, a2)
    print(f'A legs apart {abs(pc(a1, a2)):.2f}%; C against the higher A leg {pc(c1, hi):+.2f}% {pc(c2, hi):+.2f}%')
elif seq == 'ABBABAAB':
    A = [x for x, r in zip(rate, read) if r['arm'] == 'A']
    B = [x for x, r in zip(rate, read) if r['arm'] == 'B']
    print(f'mean A {statistics.mean(A):.3f}  mean B {statistics.mean(B):.3f}  r = {pc(statistics.mean(B), statistics.mean(A)):+.2f}%')
    print(f'spread inside A {pc(max(A), min(A)):.2f}%, inside B {pc(max(B), min(B)):.2f}%')
else:
    print('unknown shape: no figure computed')

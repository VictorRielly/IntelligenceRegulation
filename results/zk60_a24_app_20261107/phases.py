#!/usr/bin/env python3
"""A24: sum the PB-TIMING phase lines of a prove/verify log by phase (diagnostics only).

usage: phases.py <log> [prove|verify] [top]
"""
import collections
import sys

log, side = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else 'prove')
top = int(sys.argv[3]) if len(sys.argv) > 3 else 15
acc = collections.defaultdict(float)
walls, blocks = 0.0, 0
for line in open(log, errors='replace'):
    if not line.startswith(f'PB-TIMING {side}'):
        continue
    parts = [p.strip() for p in line.split('|')]
    if 'phases, wall' in line:
        blocks += 1
        walls += float(line.split('wall ')[1].split(' s')[0])
        continue
    if len(parts) < 4 or parts[1] == 'phase':
        continue
    try:
        acc[parts[1]] += float(parts[3])
    except ValueError:
        pass
print(f'{blocks} blocks, summed wall {walls:.3f} s')
for k, v in sorted(acc.items(), key=lambda kv: -kv[1])[:top]:
    print(f'{v:8.3f}  {k}')
for line in open(log, errors='replace'):
    if line.startswith('PB-CLI'):
        print(line.rstrip()[:160])

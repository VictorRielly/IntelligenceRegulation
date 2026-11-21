#!/usr/bin/env python3
"""S1 summary (standard library only): reads raw/s1/r1..r3.timing.txt (r0 is the warm-up and is NOT read) and prints, for EVERY phase name that appears in a block's
PB-TIMING table, the median, minimum and maximum in ms over the block rows (26 blocks x 3 timed requests = 78), the sum of the medians against the
median block wall (the recorder's own wall of one block's table), and the stage rows (IN-C, OUT-C) if the log has phase tables for them.

usage: s1_summary.py [DIR]   (default: raw/s1 beside this file)
"""
import statistics
import sys
from pathlib import Path

d = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent / 'raw' / 's1'
SKIP = {'phase', 'SUM OF PHASES', 'WALL CLOCK OF THE CALL', 'unaccounted (wall - sum)'}
rows = {}      # name -> [ms per block row]
order = []     # first appearance
walls = []     # ms, the recorder's wall of one block table
tables = 0
stage_tables = []
other = []
for r in (1, 2, 3):
    p = d / f'r{r}.timing.txt'
    block = 0
    for line in p.read_text(errors='replace').splitlines():
        if line.startswith('PB-TIMING prove ['):
            tables += 1
            block += 1
            walls.append(float(line.split('wall ')[1].split(' s')[0]) * 1000)
            continue
        if line.startswith('PB-TIMING prove | '):
            parts = [x.strip() for x in line.split(' | ')]
            name = parts[1]
            if name in SKIP:
                continue
            try:
                ms = float(parts[3]) * 1000
            except (ValueError, IndexError):
                continue
            if name not in rows:
                rows[name] = []
                order.append(name)
            rows[name].append(ms)
        elif line.startswith('PB-CLI ') and 'prove' in line:
            other.append((r, line))
n_blocks = tables
print(f'block tables read: {n_blocks} (expected 78); phase names: {len(order)}; rows per phase (min/max): {min(len(v) for v in rows.values())}/{max(len(v) for v in rows.values())}')
print(f'{"phase":<62} {"median ms":>10} {"min ms":>9} {"max ms":>9} {"n":>4}')
meds = {}
for name in order:
    v = rows[name]
    meds[name] = statistics.median(v)
    print(f'{name:<62} {meds[name]:>10.3f} {min(v):>9.3f} {max(v):>9.3f} {len(v):>4}')
print(f'{"SUM OF THE MEDIANS":<62} {sum(meds.values()):>10.3f}')
print(f'{"MEDIAN BLOCK WALL (the table\'s own wall)":<62} {statistics.median(walls):>10.3f} {min(walls):>9.3f} {max(walls):>9.3f} {len(walls):>4}')
print()
print('largest phases by median:')
for name in sorted(meds, key=meds.get, reverse=True)[:8]:
    print(f'  {meds[name]:>8.3f} ms  {name}')
print()
print('the five named phases:')
for name in ['sink: segment to disk', 'frame: encode segment', 'run: boundary B_(k-1) opening', 'run: boundary B_k commitment', 'run: block load + statement check']:
    print(f'  {name:<40} median {meds.get(name, float("nan")):.3f} ms')
sink = meds.get('sink: segment to disk')
lc = meds.get('run: block load + statement check')
print()
print('stage rows (IN-C, OUT-C) with phase tables: none in the log' if not stage_tables else stage_tables)
print('PB-CLI prove lines in the timed requests:', len(other))
for r, line in other[:6]:
    print(f'  r{r}: {line[:150]}')
print()
print(f'writer-thread rule: sink median {sink:.3f} ms ->', 'ALIVE (>= 12 ms)' if sink >= 12 else ('DEAD (< 6 ms)' if sink < 6 else 'recorded, not scheduled (6 to 12 ms)'))
print(f'load + check median {lc:.3f} ms ->', 'under 2 ms' if lc < 2 else 'NOT under 2 ms')

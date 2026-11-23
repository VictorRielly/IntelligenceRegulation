#!/usr/bin/env python3
"""Summary of one a22_stream_ab log: steady gap per pass and arm, pairs, the test's own summary lines.

    python3 -I -B summary_8b.py raw/<label>.log [on_arm:off_arm ...]

Steady gap of a pass = (completion[R-2] - completion[1]) / (R-3), from the STREAM line's completion times (the rule of
results/zk60_a35_replication_20261120). Rate = 128 tokens / gap. A pair is given as on_arm:off_arm."""
import re
import statistics
import sys

log = open(sys.argv[1], errors='replace').read().split('\n')
gaps, order = {}, []
for l in log:
    m = re.search(r'A22-AB STREAM \S+ L\d+ N\d+ \[([^\]]+)\] pass (\d+): (\d+) requests in ([0-9.]+) s \(([^)]*)\).*?completions ([0-9., ]+);', l)
    if not m:
        continue
    arm, ps, r, flags = m.group(1), int(m.group(2)), int(m.group(3)), m.group(5)
    c = [float(x) for x in m.group(6).split(',')]
    assert len(c) == r, (arm, ps, len(c), r)
    if arm not in gaps:
        gaps[arm] = {}
        order.append(arm)
        print('arm %-28s flags: %s' % (arm, flags))
    gaps[arm][ps] = (c[r - 2] - c[1]) / (r - 3)
print()
for arm in order:
    g = [gaps[arm][p] for p in sorted(gaps[arm])]
    print('%-28s gap s by pass: %s | median %.3f s = %.2f tok/s' % (arm, ' '.join('%.3f' % x for x in g), statistics.median(g), 128.0 / statistics.median(g)))
for pair in sys.argv[2:]:
    on, off = pair.split(':')
    ps = sorted(set(gaps[on]) & set(gaps[off]))
    d = [gaps[on][p] - gaps[off][p] for p in ps]
    rel = [100.0 * (gaps[on][p] / gaps[off][p] - 1.0) for p in ps]
    print('\npair %s minus %s:' % (on, off))
    print('  per pass (s): %s' % ' '.join('%+.3f' % x for x in d))
    print('  per pass (%%): %s' % ' '.join('%+.2f' % x for x in rel))
    print('  median %+.3f s (%+.2f%% of the off median); lower in %d of %d passes' % (
        statistics.median(d), 100.0 * statistics.median(d) / statistics.median([gaps[off][p] for p in ps]), sum(1 for x in d if x < 0), len(d)))
print()
for l in log:
    if ' SUMMARY ' in l or l.startswith('test result') or 'total ' in l and 'A22-AB' in l:
        print(l[:330])

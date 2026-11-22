#!/usr/bin/env python3
"""What separates the fast and the slow gate/up sealing buffers (research tick 42, section 3)?

    python3 -I -B sealing_pair_check.py <trace.tsv.xz> [...]

Standard library only; reads retained device traces, runs nothing. A trace row is: tag, detail, thread, queue and five
times, t4 (host begin), t5 (submitted), t6 (device start), t7 (device end), t8 (host done). The gate and up products of a
block are the two wprod buffers with k=4096 n=16384; the host submits them within 0.1 ms of each other. A pair is two
such buffers submitted within 0.1 ms. Whole trace, no timed window. A buffer is "slow" above 4.5 ms of execution."""
import lzma, os, statistics, sys

med = statistics.median


def load(f):
    rows = []
    for i, line in enumerate(lzma.open(f, 'rt')):
        p = line.rstrip('\n').split('\t')
        if i == 0 or len(p) != 9:
            continue
        rows.append((p[0], p[1], float(p[4]), float(p[5]), float(p[6]), float(p[7]), float(p[8])))
    return rows


BINS = (('device start offset under 0.1 ms', 0.0, 0.1), ('0.1 to 0.3 ms', 0.1, 0.3), ('0.3 to 0.6 ms', 0.3, 0.6),
        ('0.6 ms or more', 0.6, 1e9))

for f in sys.argv[1:]:
    gu = sorted((r for r in load(f) if r[0] == 'wprod' and 'k=4096 n=16384' in r[1]), key=lambda r: r[3])
    pairs, i = [], 0
    while i + 1 < len(gu):
        a, b = gu[i], gu[i + 1]
        if b[3] - a[3] < 1e-4:
            pairs.append((a, b) if a[4] <= b[4] else (b, a))
            i += 2
        else:
            i += 1
    ex = [(r[5] - r[4]) * 1e3 for r in gu]
    print('%s: %d gate/up buffers, %d slow (%.0f%%); %d pairs by submit time' % (
        os.path.basename(f), len(gu), sum(1 for x in ex if x > 4.5), 100.0 * sum(1 for x in ex if x > 4.5) / len(ex), len(pairs)))
    print('  %-34s %5s %6s %10s %10s %10s %10s %6s' % ('', 'pairs', 'share', 'first wait', 'pair wall', 'host wall', 'buffer', 'slow'))
    for name, lo, hi in BINS:
        sel = [(a, b) for a, b in pairs if lo <= (b[4] - a[4]) * 1e3 < hi]
        if not sel:
            print('  %-34s %5d' % (name, 0))
            continue
        e = [(x[5] - x[4]) * 1e3 for p in sel for x in p]
        print('  %-34s %5d %5.0f%% %10.2f %10.2f %10.2f %10.2f %6.2f' % (
            name, len(sel), 100.0 * len(sel) / len(pairs),
            med([(a[4] - a[3]) * 1e3 for a, b in sel]),                      # first buffer: submitted to device start
            med([(max(a[5], b[5]) - a[4]) * 1e3 for a, b in sel]),           # first device start to last device end
            med([(max(a[6], b[6]) - min(a[2], b[2])) * 1e3 for a, b in sel]),  # host begin to host done, both buffers
            med(e), sum(1 for x in e if x > 4.5) / len(e)))
    print('  (medians, ms; "first wait" = first buffer, submitted to device start)')

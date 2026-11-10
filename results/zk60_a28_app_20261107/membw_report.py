#!/usr/bin/env python3
"""Lane A28 (diagnostics): the one-thread memory-traffic probe (membw_probe.py) against stream runs.

For each run (its summary.json gives the clock's start on the monotonic clock and its length; its GPU trace
gives every command buffer's GPUStartTime..GPUEndTime on the same clock): the probe's rate before the run
(idle), over the run's proving window (from the first proof's start, the first writer's end, to the last
proof), and inside that window split by how many command buffers were executing during the probe's sample
(0, 1, 2 or more).

usage: membw_report.py <probe.tsv> <stream_dir>=<trace.tsv> [...]
"""
import bisect
import json
import sys


def load_probe(path):
    rows = []
    for line in open(path):
        p = line.split()
        if len(p) == 2 and p[0][0].isdigit():
            rows.append((float(p[0]), float(p[1])))
    return rows


def load_spans(path):
    spans = []
    for line in open(path):
        p = line.rstrip('\n').split('\t')
        if len(p) == 9 and p[0] != 'tag':
            spans.append((float(p[6]), float(p[7])))
    spans.sort()
    return spans


def mean(v):
    return sum(v) / len(v) if v else float('nan')


def stats(v):
    if not v:
        return 'no samples'
    s = sorted(v)
    return f'mean {mean(v):6.1f}  median {s[len(s) // 2]:6.1f}  p10 {s[len(s) // 10]:6.1f}  GiB/s  ({len(v)} samples)'


def main():
    probe = load_probe(sys.argv[1])
    print(f'probe: {len(probe)} samples over {probe[-1][0] - probe[0][0]:.0f} s; all: {stats([r for _, r in probe])}')
    for spec in sys.argv[2:]:
        d, trace = spec.split('=', 1)
        s = json.load(open(d + '/summary.json'))
        recs = json.load(open(d + '/records.json'))
        t0 = s['gpu']['t0_monotonic']
        wall0 = min(r['t'] - (r.get('seconds') or 0) for r in recs if r['kind'] == 'writer')
        first = min(r['t'] for r in recs if r['kind'] == 'writer') - wall0
        last = max(r['t'] for r in recs if r['kind'] == 'prove') - wall0
        spans = load_spans(trace)
        starts = [a for a, _ in spans]
        print(f'\n{d.rstrip("/").split("/")[-1]}: clock {s["wall_s"]:.1f} s, {s["category_proofs"]} proofs; proving window {first:.1f}..{last:.1f} s')
        before = [r for t, r in probe if t0 - 75 <= t < t0 - 65]
        print(f'  during the servers\' startup (65-75 s before the clock)   {stats(before)}')
        win = [(t, r) for t, r in probe if t0 + first <= t <= t0 + last]
        print(f'  over the proving window                                 {stats([r for _, r in win])}')
        by = {0: [], 1: [], 2: []}
        dur = 0.33
        for t, r in win:
            # command buffers executing at the middle of the probe's sample (about `dur` seconds long)
            m = t + dur / 2
            k = sum(1 for a, b in spans[max(0, bisect.bisect_left(starts, m - 5.0)):bisect.bisect_right(starts, m)] if a <= m <= b)
            by[min(k, 2)].append(r)
        for k, label in ((0, 'no command buffer executing'), (1, 'one executing'), (2, 'two or more executing')):
            print(f'    {label:<28}                          {stats(by[k])}')
    idle = [r for t, r in probe[:30]]
    print(f'\nthe first 30 samples (the idle machine, before the first server starts): {stats(idle)}')
    tail = [r for t, r in probe[-30:]]
    print(f'the last 30 samples (after the last run):                                {stats(tail)}')


if __name__ == '__main__':
    main()

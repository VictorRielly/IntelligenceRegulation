#!/usr/bin/env python3
"""Lane A28: a stream run's lanes over time (records.json): each prove request's lane, start (its
submit time plus its queued seconds) and end, the writer calls, and each lane's busy share
(diagnostics).

usage: lanes.py <stream_dir>
"""
import collections
import json
import sys


def main():
    d = sys.argv[1]
    recs = json.load(open(d + '/records.json'))
    t0 = min(r['t'] - (r.get('seconds') or 0) if r['kind'] == 'writer' else r['t'] for r in recs)
    sub = {}
    for r in recs:
        if r['kind'] == 'prove-submit':
            sub[(r['post'], r['category'], r['chunk'])] = r['t']
    lanes = collections.defaultdict(list)
    for r in recs:
        if r['kind'] == 'writer':
            print(f"writer post {r['post']}: {r['t'] - r['seconds'] - t0:6.1f} .. {r['t'] - t0:6.1f} s")
        if r['kind'] == 'prove':
            s = sub[(r['post'], r['category'], r['chunk'])] + (r.get('queued') or 0)
            lanes[r['lane']].append((s - t0, r['t'] - t0, r['post'], r['category'], r['seconds']))
    end = max(r['t'] for r in recs) - t0
    print(f'clock {end:.1f} s')
    for ln in sorted(lanes):
        v = sorted(lanes[ln])
        busy = sum(b - a for a, b, *_ in v)
        print(f"lane {ln}: busy {busy:6.1f} s of {end:.1f} ({100 * busy / end:4.1f}%): " + ', '.join(f"p{p}{c[0]} {a:.0f}-{b:.0f} ({sec:.1f})" for a, b, p, c, sec in v))


if __name__ == '__main__':
    main()

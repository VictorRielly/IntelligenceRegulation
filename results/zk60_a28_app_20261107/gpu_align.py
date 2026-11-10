#!/usr/bin/env python3
"""Lane A28: a stream run's GPU picture over time (diagnostics).

For each 2-second ioreg sample of the GPU's own 'Device Utilization %' (stream_driver.py's
`series_monotonic`, the mach clock), the fraction of the same 2 s window in which at least one
command buffer was executing by A27's trace (GPUStartTime..GPUEndTime, the same clock), how many ran
at once on average, and which tags. Then a summary over the whole clock and over its steady middle
(from the first proof to the last post's last proof start).

usage: gpu_align.py <stream_dir> <trace.tsv> [--bin 10]
"""
import argparse
import collections
import json


def load(path):
    rows = []
    for line in open(path):
        if line.startswith('tag\t'):
            continue
        p = line.rstrip('\n').split('\t')
        if len(p) != 9:
            continue
        gs, ge = float(p[6]), float(p[7])
        if gs > 0 and ge >= gs:
            rows.append((p[0], int(p[2]), float(p[4]), float(p[5]), gs, ge, float(p[8]), p[1]))
    return rows


def busy_in(ev, a, b):
    """time in [a, b] with depth >= 1, and the integral of depth"""
    depth, last, busy, integ = 0, a, 0.0, 0.0
    for t, d in ev:
        if t <= a:
            depth += d
            continue
        if t >= b:
            break
        if depth > 0:
            busy += t - last
            integ += depth * (t - last)
        depth += d
        last = t
    if depth > 0:
        busy += b - last
        integ += depth * (b - last)
    return busy, integ


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('stream_dir')
    ap.add_argument('trace')
    ap.add_argument('--bin', type=float, default=10.0)
    a = ap.parse_args()
    s = json.load(open(a.stream_dir + '/summary.json'))
    ser = s['gpu'].get('series_monotonic') or []
    t0 = s['gpu'].get('t0_monotonic')
    rows = load(a.trace)
    ev = []
    for r in rows:
        ev.append((r[4], 1))
        ev.append((r[5], -1))
    ev.sort(key=lambda e: (e[0], -e[1]))
    t_first = min(r[4] for r in rows)
    t_last = max(r[5] for r in rows)
    print(f"stream wall {s['wall_s']:.1f} s, {s['proved_tok_per_s']:.2f} proved tok/s; trace window {t_last - t_first:.1f} s starting {t_first - t0:.1f} s after the first post")
    # per ioreg sample: the 2 s before it
    pairs = []
    for tm, v in ser:
        b, integ = busy_in(ev, tm - 2.0, tm)
        pairs.append((tm - t0, v, b / 2.0, integ / 2.0))
    # binned
    nb = int((t_last - t0) / a.bin) + 1
    agg = collections.defaultdict(list)
    for t, v, b, k in pairs:
        agg[int(t / a.bin)].append((v, b, k))
    print(f"{'window':>11} | ioreg util | trace busy | mean CBs executing")
    for i in range(nb):
        xs = agg.get(i, [])
        if not xs:
            continue
        v = sum(x[0] for x in xs) / len(xs)
        b = sum(x[1] for x in xs) / len(xs)
        k = sum(x[2] for x in xs) / len(xs)
        print(f"{i * a.bin:5.0f}-{(i + 1) * a.bin:4.0f} s | {v:9.1f}% | {100 * b:9.1f}% | {k:5.2f}")
    if pairs:
        v = sum(p[1] for p in pairs) / len(pairs)
        b = sum(p[2] for p in pairs) / len(pairs)
        print(f"whole clock: ioreg mean {v:.1f}%, trace busy mean {100 * b:.1f}% ({len(pairs)} samples)")
        mid = [p for p in pairs if t_first - t0 + 10 <= p[0] <= t_last - t0 - 10]
        if mid:
            v = sum(p[1] for p in mid) / len(mid)
            b = sum(p[2] for p in mid) / len(mid)
            print(f"middle (first CB + 10 s .. last CB - 10 s): ioreg mean {v:.1f}%, trace busy mean {100 * b:.1f}% ({len(mid)} samples)")


if __name__ == '__main__':
    main()

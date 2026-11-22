#!/usr/bin/env python3
"""Threads-per-lane setting test (co-coordinator, 2026-11-22): rates and pair gains of one set, from the raw file.

usage: python3 -I -B lane_threads_summary.py <raw/SET/t2_results.json>
       python3 -I -B lane_threads_summary.py four <raw/SET/t2_results.json> <raw/REPEAT/t2_results.json>

The first form prints one set and the verdict of the first pass of the rule. The second form applies the rule
after the one repeat (the mean of the four pairs); for a repeated set only the second form's verdict counts.

Every leg is arm C (binary B1, both switches on). A set is six legs X, Y, Z, Z, Y, X, where X is the first leg's
setting. The rate of a leg is recomputed here from the completion times (the t_s of each completion record, one
monotonic clock): timed * 128 / (c[N + timed] - c[N]) with N = lane count, and compared with the driver's figure.
Pairs: Y against X = legs (1,2) and (6,5); Z against X = legs (1,3) and (6,4).
"""
import json
import sys


def main():
    d = json.load(open(sys.argv[1]))
    legs = d['legs']
    print('spec', d['spec'])
    rates, names = [], []
    for l in legs:
        n, timed = l['N'], l['timed']
        ts = sorted(r['t_s'] for r in l['completions'])
        mine = timed * 128 / (ts[n + timed - 1] - ts[n - 1])
        assert abs(mine - l['rate']) < 1e-9, (mine, l['rate'])
        proved = sum(1 for r in l['completions'] if r['status'] == 'proved')
        v = l.get('verify_summary') or {}
        ok = l['all_proved'] and v.get('checked') == len(l['completions']) and v.get('other') == 0
        rates.append(mine)
        names.append('%dx%d' % (l['lanes'], l['threads']))
        print('leg %d  %-4s arm %s  rate %.3f tok/s  proved %d/%d  receipts accepted by B0 %s/%s  other %s  GPU busy %.1f%%  start %s  valid %s' % (
            l['leg'], names[-1], l['arm'], mine, proved, len(l['completions']), v.get('checked'), v.get('receipts'), v.get('other'),
            l.get('gpu_util_mean') or 0.0, l.get('utc_start'), ok))
    if len(rates) != 6:
        return
    x1, y1, z1, z2, y2, x2 = rates
    assert names[0] == names[5] and names[1] == names[4] and names[2] == names[3], names

    def pc(a, b):
        return (a / b - 1) * 100

    def verdict(p):
        if min(p) >= 3.0:
            return 'GAIN'
        if min(p) < 1.5:
            return 'NO GAIN'
        return 'REPEAT ONCE'

    for nm, p in ((names[1], (pc(y1, x1), pc(y2, x2))), (names[2], (pc(z1, x1), pc(z2, x2)))):
        print('%s against %s: %+.2f%% and %+.2f%%  -> %s' % (nm, names[0], p[0], p[1], verdict(p)))
    print('%s leg 1 to leg 6: %+.2f%%' % (names[0], pc(x2, x1)))
    print('requests proved %d, receipts accepted %d' % (sum(len(l['completions']) for l in legs), sum((l.get('verify_summary') or {}).get('checked', 0) for l in legs)))


def rates_of(path):
    d = json.load(open(path))
    out = []
    for l in d['legs']:
        n, timed = l['N'], l['timed']
        ts = sorted(r['t_s'] for r in l['completions'])
        out.append((timed * 128 / (ts[n + timed - 1] - ts[n - 1]), '%dx%d' % (l['lanes'], l['threads'])))
    return out


def four_pairs(first, repeat):
    """The posted rule after one repeat: the mean of the four pairs decides (no third set)."""
    a, b = rates_of(first), rates_of(repeat)
    assert [n for _, n in a] == [n for _, n in b], 'the repeat must have the same legs'

    def pc(x, y):
        return (x / y - 1) * 100

    print('four pairs (set, repeat), rule: GAIN if mean >= +3.0% and every pair >= +1.5%; NO GAIN if mean < +1.5%; else gain under the bar')
    for i, j in ((1, 4), (2, 3)):
        p = [pc(a[i][0], a[0][0]), pc(a[j][0], a[5][0]), pc(b[i][0], b[0][0]), pc(b[j][0], b[5][0])]
        m = sum(p) / 4
        v = 'GAIN' if (m >= 3.0 and min(p) >= 1.5) else ('NO GAIN' if m < 1.5 else 'gain under the bar')
        print('%s against %s: %s | mean %+.2f%% | lowest %+.2f%% -> %s' % (a[i][1], a[0][1], ' '.join('%+.2f%%' % x for x in p), m, min(p), v))
    for k, nm in ((0, a[0][1]), (1, a[1][1]), (2, a[2][1])):
        idx = {0: (0, 5), 1: (1, 4), 2: (2, 3)}[k]
        vals = [s[i][0] for s in (a, b) for i in idx]
        print('%s level: %s | mean %.3f tok/s' % (nm, ' '.join('%.3f' % x for x in vals), sum(vals) / 4))


if __name__ == '__main__':
    if len(sys.argv) == 4 and sys.argv[1] == 'four':
        four_pairs(sys.argv[2], sys.argv[3])
    else:
        main()

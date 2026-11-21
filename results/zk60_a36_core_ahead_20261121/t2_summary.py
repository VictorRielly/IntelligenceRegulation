#!/usr/bin/env python3
"""T2 summary (standard library only): reads raw/<set>/t2_results.json for the sets named on the command line (default: t2_setA t2_setB) and prints per leg
the rate (the entry's formula: 48 * 128 / (c[N+48] - c[N]), completion times from one clock, c 1-indexed in order of completion), the mean and median
prove call over the timed completions, the same-lane statistic (mean same-lane completion period over the timed completions; rate = N * 128 / that),
receipts verified / checked / failed; per set the two gains (pairs: leg 1 with 2, leg 4 with 3) and the verdict by the rule (under 3% in either pair: KILL
at that lane count; otherwise "rate half met; GPU busy share unmeasured"; any on-leg verification failure: kill of the whole test).
"""
import json
import statistics
import sys
from pathlib import Path

raw = Path(__file__).resolve().parent / 'raw'
sets = sys.argv[1:] or ['t2_setA', 't2_setB']
for name in sets:
    p = raw / name / 't2_results.json'
    if not p.exists():
        print(name, ': no results')
        continue
    r = json.load(open(p))
    N, T = r['N'], r['timed']
    print(f'== {name}: {r["lanes"]} lanes x {r["lane_threads"]} threads, N = {N}, timed = {T}')
    rates = {}
    bad_verify = False
    for l in r['legs']:
        recs = l['completions']
        c = [x['t_s'] for x in recs]
        rate = T * 128 / (c[N + T - 1] - c[N - 1]) if len(c) >= N + T else None
        timed = recs[N:]
        pr = [x['prove_s'] for x in timed if x['prove_s'] is not None]
        lanes = {}
        for x in recs:
            lanes.setdefault(x['lane'], []).append(x)
        per = []
        for lane, xs in lanes.items():
            xs.sort(key=lambda x: x['t_s'])
            for a, b in zip(xs, xs[1:]):
                if b['n'] > N:
                    per.append(b['t_s'] - a['t_s'])
        same = N * 128 / statistics.mean(per) if per else None
        v = l.get('verify_summary', {})
        failed = v.get('other', 0)
        if l['A36'] and (failed or v.get('checked', 0) != v.get('receipts', 0) or not l['all_proved']):
            bad_verify = True
        rates[l['leg']] = rate
        print(f'leg {l["leg"]} A36 {l["A36"]}: rate {rate:.3f} padded tok/s | prove call mean {statistics.mean(pr):.3f} median {statistics.median(pr):.3f} s | '
              f'same-lane {same:.3f} tok/s ({len(per)} periods) | all proved {l["all_proved"]} | span c[1..{len(c)}] {c[0]:.1f}..{c[-1]:.1f} s | '
              f'receipts verified {v.get("receipts", 0)}, checked {v.get("checked", 0)}, failed {failed}'
              + (' (off leg: deleted unverified)' if not l['A36'] else '') + f' | GPU util mean {l.get("gpu_util_mean")} %')
    if all(k in rates and rates[k] for k in (1, 2, 3, 4)):
        g1 = rates[2] / rates[1] - 1
        g2 = rates[3] / rates[4] - 1
        print(f'pair (leg 1, leg 2): off {rates[1]:.3f} on {rates[2]:.3f} gain {100 * g1:+.2f}%')
        print(f'pair (leg 4, leg 3): off {rates[4]:.3f} on {rates[3]:.3f} gain {100 * g2:+.2f}%')
        if bad_verify:
            verdict = 'KILL OF THE WHOLE TEST: an on-leg receipt failed verification or a request failed (a correctness finding)'
        elif g1 < 0.03 or g2 < 0.03:
            verdict = f'KILL at {r["lanes"]} lanes (a gain under 3% in a pair)'
        else:
            verdict = 'rate half met; GPU busy share unmeasured'
        print('VERDICT:', verdict)
    print()

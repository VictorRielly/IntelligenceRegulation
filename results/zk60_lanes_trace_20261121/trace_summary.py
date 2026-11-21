#!/usr/bin/env python3
"""Lanes-trace summary (standard library only; run as `python3 -I -B trace_summary.py [RAW_DIR]`).

Reads RAW_DIR/tr_leg1/t2_results.json (leg 1) and RAW_DIR/tr_main/t2_results.json (legs 2 to 5), and for each leg the GPU trace
RAW_DIR/traces/<trace_prefix>.<pid>.tsv (columns: tag, detail, thread, queue, begin, committed, gpu_start, gpu_end, done; mach seconds,
the clock of the driver's time.monotonic). Pre-registered definitions (coordination entry of 2026-11-21T15:58:07Z):
  window  = host time from completion N to completion N + timed (buffers cut by their host BEGIN time inside it)
  B       = blocks proved in the window = 26 x timed (DERIVED: the timed requests' blocks)
  wall    = mean prove call over the timed completions / 26
  e = sum(gpu_end - gpu_start) / B ; q = sum(gpu_start - committed) / B ; w = sum(done - gpu_end) / B ; u = union of execution intervals / window
  prover buffers = every tag except wprod; sealing/witness-product buffers = tag wprod (queue 99), reported separately.
Rules: (a) growth of e+q against growth of wall, leg 1 to leg 2: >= 2/3 device-side, <= 1/3 host-side, else mixed; (b) the same, leg 2 to leg 3.
"""
import glob
import json
import statistics
import sys
from collections import defaultdict
from pathlib import Path

raw = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent / 'raw'
T2_RANGE = {(6, 0): (43.0, 43.9), (6, 1): (38.0, 38.9), (8, 0): (44.1, 46.4)}  # lanes, A36 -> T2's untraced rates (tok/s)
BLOCKS = 26
legs = []
for sub in ('tr_leg1', 'tr_main'):
    p = raw / sub / 't2_results.json'
    if p.exists():
        legs += json.load(open(p))['legs']
legs.sort(key=lambda l: l['leg'])


def union_len(iv, lo, hi):
    iv = sorted((max(a, lo), min(b, hi)) for a, b in iv if b > lo and a < hi)
    tot, cur_a, cur_b = 0.0, None, None
    for a, b in iv:
        if cur_b is None or a > cur_b:
            if cur_b is not None:
                tot += cur_b - cur_a
            cur_a, cur_b = a, b
        else:
            cur_b = max(cur_b, b)
    if cur_b is not None:
        tot += cur_b - cur_a
    return tot


def quantities(rows, B, lo, hi):
    n = len(rows)
    if not n:
        return None
    e = sum(r['ge'] - r['gs'] for r in rows) / B
    q = sum(r['gs'] - r['cm'] for r in rows) / B
    w = sum(r['dn'] - r['ge'] for r in rows) / B
    u = union_len([(r['gs'], r['ge']) for r in rows], lo, hi) / (hi - lo)
    return {'e': e * 1000, 'q': q * 1000, 'w': w * 1000, 'u': u, 'per_block': n / B, 'queues': len({r['queue'] for r in rows}), 'threads': len({r['thread'] for r in rows}), 'n': n}


out = {}
tagtab = {}
for l in legs:
    N, timed = l['N'], l['timed']
    recs = sorted(l['completions'], key=lambda x: x['t_abs'])
    lo, hi = recs[N - 1]['t_abs'], recs[N + timed - 1]['t_abs']
    rate = timed * 128 / (hi - lo)
    prove = [x['prove_s'] for x in recs[N:] if x['prove_s'] is not None]
    mean_prove = statistics.mean(prove)
    wall = mean_prove / BLOCKS * 1000
    B = BLOCKS * timed
    files = glob.glob(str(raw / 'traces' / (Path(l['trace_prefix']).name + '.*.tsv')))
    rows = []
    trunc = None
    for f in files:
        for line in open(f):
            p = line.rstrip('\n').split('\t')
            if p[0] == 'tag' or len(p) != 9:
                continue
            rows.append({'tag': p[0], 'detail': p[1], 'thread': p[2], 'queue': p[3], 'bt': float(p[4]), 'cm': float(p[5]), 'gs': float(p[6]), 'ge': float(p[7]), 'dn': float(p[8])})
    win = [r for r in rows if lo <= r['bt'] <= hi]
    prover = [r for r in win if r['tag'] != 'wprod']
    seal = [r for r in win if r['tag'] == 'wprod']
    last_done = max((r['dn'] for r in rows), default=0)
    ref = T2_RANGE.get((l['lanes'], l['A36'])) if l['queues'] == 'thread' and l['lanes'] != 1 else None  # T2 ran per-thread queues only; no reference at one lane or on the shared queue
    pert = None if ref is None else ('PERTURBED (more than 5% under the T2 range)' if rate < 0.95 * ref[0] else 'within or above the T2 range less 5%')
    qs = {'rate': rate, 'mean_prove': mean_prove, 'wall': wall, 'B': B, 'prover': quantities(prover, B, lo, hi), 'sealing': quantities(seal, B, lo, hi), 'perturbation': pert, 'ref': ref,
          'trace_records': len(rows), 'last_record_to_last_completion_s': recs[-1]['t_abs'] - last_done, 'server_exit': l.get('server_exit'), 'all_proved': l['all_proved']}
    out[l['leg']] = qs
    print(f'== leg {l["leg"]}: {l["lanes"]} lanes x {l["threads"]} threads, A36 {l["A36"]}, queues {l["queues"]}, N {N}, timed {timed}; all proved {l["all_proved"]}, server exit {l.get("server_exit")}')
    print(f'   rate {rate:.3f} tok/s | mean prove call {mean_prove:.3f} s | wall {wall:.1f} ms | B {B} | trace records {len(rows)} (last record {recs[-1]["t_abs"] - last_done:.3f} s before the last completion)')
    for name, qq in (('prover', qs['prover']), ('sealing', qs['sealing'])):
        if qq:
            print(f'   {name:8s}: e {qq["e"]:.1f} ms  q {qq["q"]:.1f} ms  w {qq["w"]:.1f} ms  u {100 * qq["u"]:.1f} %  | buffers/block {qq["per_block"]:.2f}, queues {qq["queues"]}, threads {qq["threads"]}')
    print(f'   perturbation: ' + ('no T2 reference at this setting' if ref is None else f'T2 range {ref[0]}..{ref[1]} tok/s: {pert}'))
    if l['leg'] in (1, 2, 3):
        d = defaultdict(float)
        for r in prover:
            d[(r['tag'], r['detail'])] += (r['ge'] - r['gs']) / B * 1000
        tagtab[l['leg']] = d


def verdict(a, b, label):
    if a not in out or b not in out:
        return f'{label}: legs missing'
    dw = out[b]['wall'] - out[a]['wall']
    deq = (out[b]['prover']['e'] + out[b]['prover']['q']) - (out[a]['prover']['e'] + out[a]['prover']['q'])
    if dw <= 0:
        return f'{label}: wall did not grow ({dw:+.1f} ms); rule not applicable; e+q change {deq:+.1f} ms'
    r = deq / dw
    word = 'device-side' if r >= 2 / 3 else ('host-side' if r <= 1 / 3 else 'mixed')
    return f'{label}: wall {out[a]["wall"]:.1f} -> {out[b]["wall"]:.1f} ms ({dw:+.1f}); e+q {out[a]["prover"]["e"] + out[a]["prover"]["q"]:.1f} -> {out[b]["prover"]["e"] + out[b]["prover"]["q"]:.1f} ms ({deq:+.1f}); ratio {r:.2f} -> {word.upper()}'


print()
pa = [out[k]['perturbation'] for k in (1, 2) if k in out]
print('RULE (a), what paces the off stream at six lanes (leg 1 to leg 2):', verdict(1, 2, 'a'))
if out.get(2) and out[2]['perturbation'] and out[2]['perturbation'].startswith('PERTURBED'):
    print('   leg 2 is PERTURBED: not read by rule (a)')
print('RULE (b), why A36 lost (leg 2 to leg 3):', verdict(2, 3, 'b'))
if out.get(3) and out[3]['perturbation'] and out[3]['perturbation'].startswith('PERTURBED'):
    print('   leg 3 is PERTURBED: not read by rule (b)')
print('(leg 1 has no T2 reference at one lane: its perturbation status is not defined by the pre-registration)')
print()
print('legs 4 and 5 beside leg 2 (no verdict; single legs):')
for k in (2, 4, 5):
    if k in out:
        pr = out[k]['prover']
        print(f'  leg {k}: rate {out[k]["rate"]:.2f}  e {pr["e"]:.1f}  q {pr["q"]:.1f}  w {pr["w"]:.1f}  u {100 * pr["u"]:.1f} %  queues {pr["queues"]}')
print()
if tagtab:
    keys = set()
    for d in tagtab.values():
        keys |= set(d)
    ref = tagtab.get(2) or next(iter(tagtab.values()))
    top = sorted(keys, key=lambda k: -max(d.get(k, 0) for d in tagtab.values()))[:12]
    print('e per block by tag (ms per block; the twelve largest by the largest leg value), legs 1, 2, 3:')
    print(f'{"tag | detail":70s} {"leg 1":>8s} {"leg 2":>8s} {"leg 3":>8s}')
    for k in top:
        print(f'{(k[0] + " | " + k[1])[:70]:70s} ' + ' '.join(f'{tagtab.get(i, {}).get(k, 0):8.2f}' for i in (1, 2, 3)))

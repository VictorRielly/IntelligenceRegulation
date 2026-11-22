#!/usr/bin/env python3
"""Fused-RS app-profile test summary (standard library only; `python3 -I -B fused_summary.py [RAW_DIR]`).

RAW_DIR/fu_set/t2_results.json : the set of record, four legs (off, on, on, off) of HL_METAL_FUSED_RS, six lanes x five threads, untraced.
RAW_DIR/fu_trace/t2_results.json + RAW_DIR/traces/*.tsv(.xz) : the traced pair (off, on), same fixture.
Rate = 48 * 128 / (c[N+48] - c[N]) (T2's statistic, one clock). Gains: leg 2 over leg 1 and leg 3 over leg 4, less 1.
Rule (coordination entry 2026-11-21T22:21:03Z): PASS at least +3% in both pairs; NO TRANSFER under +1.5% in either; otherwise INCONCLUSIVE.
Traced quantities (as the lanes trace): window = begin time between completion N and N+48; B = 26 x 48; wall = mean prove call / 26;
e, q, w per block over prover buffers (every tag except wprod); union (u) over ALL buffers.
"""
import glob
import json
import lzma
import statistics
import sys
from collections import defaultdict
from pathlib import Path

raw = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent / 'raw'
T2_OFF = (43.0, 43.9)
BLOCKS = 26


def load(sub):
    p = raw / sub / 't2_results.json'
    return json.load(open(p))['legs'] if p.exists() else []


def rate_of(l):
    N, T = l['N'], l['timed']
    c = sorted(x['t_abs'] for x in l['completions'])
    return T * 128 / (c[N + T - 1] - c[N - 1]), c[N - 1], c[N + T - 1]


def one_set(sub):
    legs = load(sub)
    print(f'== set of record {sub} (HL_METAL_FUSED_RS off, on, on, off; 6 lanes x 5 threads; untraced)')
    rates = {}
    for l in legs:
        rt, lo, hi = rate_of(l)
        rates[l['leg']] = rt
        pr = [x['prove_s'] for x in l['completions'][l['N']:] if x['prove_s'] is not None]
        v = l.get('verify_summary', {})
        sw = l['FUSED_RS']
        ref = ''
        if not sw:
            where = 'inside' if T2_OFF[0] <= rt <= T2_OFF[1] else '%+.1f%% from the nearest end' % (100 * ((rt / T2_OFF[0] if rt < T2_OFF[0] else rt / T2_OFF[1]) - 1))
            ref = f' | T2 untraced off range {T2_OFF[0]} to {T2_OFF[1]}: {where}'
        chk = f'receipts checked {v.get("checked", 0)} of {v.get("receipts", 0)}, other {v.get("other", 0)}' if sw else 'off leg: receipts deleted unverified'
        print(f'leg {l["leg"]} FUSED_RS {sw}: rate {rt:.3f} tok/s | mean prove call {statistics.mean(pr):.3f} s | all proved {l["all_proved"]} | {chk}{ref}')
    gains = None
    if len(rates) == 4:
        gains = (rates[2] / rates[1] - 1, rates[3] / rates[4] - 1)
        print(f'gain pair (leg 1, leg 2): {100 * gains[0]:+.2f}%   gain pair (leg 4, leg 3): {100 * gains[1]:+.2f}%')
        failed = any(l.get('verify_summary', {}).get('other', 0) or not l['all_proved'] for l in legs)
        if failed:
            word = 'CORRECTNESS FINDING: a receipt failed or a request failed; the test ends'
        elif min(gains) >= 0.03:
            word = 'PASS'
        elif min(gains) < 0.015:
            word = 'NO TRANSFER'
        else:
            word = 'INCONCLUSIVE (the set is repeated once)'
        print(f'verdict of this set by the 22:21:03Z rule: {word}')
        far = [r for r in (rates[1], rates[4]) if r < 0.9 * T2_OFF[0] or r > 1.1 * T2_OFF[1]]
        if far:
            print('NOTE: a switch-off rate is more than 10% away from the T2 range:', [round(r, 2) for r in far])
    jp = raw / f'{sub}.guard.json'
    if jp.exists():
        g = json.load(open(jp))
        print(f'peak memory (guard {g["run_id"]}, whole job): RSS {g["peak_rss_gib"]} GiB, VRAM {g["peak_vram_mib"]} MiB, exit {g["exit"]}')
    print()
    return gains


allg = []
for sub in ('fu_set', 'fu_set2'):
    g = one_set(sub)
    if g:
        allg += list(g)
if allg:
    mean = sum(allg) / len(allg)
    print(f'== two sets: {len(allg)} pair gains ' + ', '.join(f'{100 * x:+.2f}%' for x in allg) + f'; mean {100 * mean:+.2f}%')
    if len(allg) == 4:
        if mean >= 0.03 and min(allg) >= 0.015:
            final = 'PASS'
        elif mean < 0.015:
            final = 'NO TRANSFER'
        else:
            final = 'transfers, under the bar'
        print('FINAL VERDICT (23:42:06Z rule: mean of the four pair gains; PASS if mean >= +3% and every pair >= +1.5%; NO TRANSFER if mean < +1.5%; otherwise transfers, under the bar):', final)
    else:
        print('(the repeat set is not in yet: no final verdict)')
print()


def opener(f):
    return lzma.open(f, 'rt') if f.endswith('.xz') else open(f)


def union_len(iv, lo, hi):
    iv = sorted((max(a, lo), min(b, hi)) for a, b in iv if b > lo and a < hi)
    tot, ca, cb = 0.0, None, None
    for a, b in iv:
        if cb is None or a > cb:
            if cb is not None:
                tot += cb - ca
            ca, cb = a, b
        else:
            cb = max(cb, b)
    return tot + (cb - ca if cb is not None else 0.0)


print('== traced pair (off, on; six lanes; HL_A27_GPU_TRACE), no verdict')
tl = load('fu_trace')
res = {}
for l in tl:
    N, T = l['N'], l['timed']
    rt, lo, hi = rate_of(l)
    recs = sorted(l['completions'], key=lambda x: x['t_abs'])
    mean_prove = statistics.mean(x['prove_s'] for x in recs[N:] if x['prove_s'] is not None)
    B = BLOCKS * T
    files = glob.glob(str(raw / 'traces' / (Path(l['trace_prefix']).name + '.*.tsv*')))
    rows = []
    for f in files:
        for line in opener(f):
            p = line.rstrip('\n').split('\t')
            if p[0] == 'tag' or len(p) != 9:
                continue
            rows.append((p[0], p[1], float(p[4]), float(p[5]), float(p[6]), float(p[7]), float(p[8])))
    win = [r for r in rows if lo <= r[2] <= hi]
    prover = [r for r in win if r[0] != 'wprod']
    e = sum(r[5] - r[4] for r in prover) / B * 1000
    q = sum(r[4] - r[3] for r in prover) / B * 1000
    w = sum(r[6] - r[5] for r in prover) / B * 1000
    u = union_len([(r[4], r[5]) for r in win], lo, hi) / (hi - lo)
    big = {'2504': 0.0, '2606': 0.0, 'other': 0.0}
    for r in prover:
        d = (r[5] - r[4]) / B * 1000
        if r[0] == 'commit' and 'rows=2504' in r[1]:
            big['2504'] += d
        elif r[0] == 'commit' and 'rows=2606' in r[1]:
            big['2606'] += d
        else:
            big['other'] += d
    res[l['leg']] = dict(rate=rt, wall=mean_prove / BLOCKS * 1000, e=e, q=q, w=w, u=u, big=big, n=len(rows), tail=recs[-1]['t_abs'] - max(r[6] for r in rows) if rows else None, mean_prove=mean_prove)
    print(f'leg {l["leg"]} FUSED_RS {l["FUSED_RS"]}: rate {rt:.3f} tok/s | mean prove call {mean_prove:.3f} s | wall {mean_prove / BLOCKS * 1000:.1f} ms | prover e {e:.1f} q {q:.1f} w {w:.1f} ms/block | '
          f'union over all buffers {100 * u:.1f} % | e by tag: commit rows 2504 {big["2504"]:.2f}, commit rows 2606 {big["2606"]:.2f}, everything else {big["other"]:.2f} ms/block | '
          f'records {len(rows)}, last record {res[l["leg"]]["tail"]:.3f} s before the last completion')
if len(res) == 2:
    a, b = [res[k] for k in sorted(res)]
    print(f'off against on: rate {a["rate"]:.2f} -> {b["rate"]:.2f} ({100 * (b["rate"] / a["rate"] - 1):+.2f}%), wall {a["wall"]:.1f} -> {b["wall"]:.1f} ms, e {a["e"]:.1f} -> {b["e"]:.1f} ms '
          f'(commit 2504: {a["big"]["2504"]:.2f} -> {b["big"]["2504"]:.2f}; 2606: {a["big"]["2606"]:.2f} -> {b["big"]["2606"]:.2f}; other: {a["big"]["other"]:.2f} -> {b["big"]["other"]:.2f})')

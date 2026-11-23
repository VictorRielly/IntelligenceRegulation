#!/usr/bin/env python3
"""Bundle (fast opening + register-only sparse fold kernel) app-profile test summary (standard library only; `python3 -I -B bundle_summary.py [RAW_DIR]`).

Arms: A = B0 (the pushed head) with HL_METAL_FUSED_RS=1 HL_METAL_SPARSE_FOLD=1; B = B1 (the bundle) with the same two; C = B1 with the same two plus
HL_METAL_OPEN_FAST=1 HL_METAL_SPARSE_FOLD_REG8=1.
One set = six legs in the order A, B, C, C, B, A (raw/bn_set1, raw/bn_set2). Rate = 48 * 128 / (c[N+48] - c[N]), completion times from one clock.
Primary: gain = rate(C) / rate(A) - 1 for the pairs (leg 1, leg 3) and (leg 6, leg 4): PASS at least +3% in both; NO TRANSFER under +1.5% in either; otherwise
repeat once (bn_set2) and read the four primary gains by the 23:42:06Z rule: PASS if mean >= +3% and every pair >= +1.5%; NO TRANSFER if mean < +1.5%;
otherwise "transfers, under the bar". Secondary (no verdict): B over A for (1, 2) and (6, 5); C over B for (2, 3) and (5, 4).
Traced pair (raw/bn_trace + raw/traces/*.tsv.xz): A then C, no verdict.
"""
import glob
import json
import lzma
import statistics
import sys
from pathlib import Path

raw = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent / 'raw'
BLOCKS = 26


def load(sub):
    p = raw / sub / 't2_results.json'
    return json.load(open(p))['legs'] if p.exists() else []


def rate_of(l):
    N, T = l['N'], l['timed']
    c = sorted(x['t_abs'] for x in l['completions'])
    return T * 128 / (c[N + T - 1] - c[N - 1])


def one_set(sub):
    legs = load(sub)
    if not legs:
        return None
    print(f'== {sub}: six legs A, B, C, C, B, A (6 lanes x 5 threads, per-thread queues, N + 48)')
    rate = {}
    failed = False
    for l in legs:
        rt = rate_of(l)
        rate[l['leg']] = rt
        pr = [x['prove_s'] for x in l['completions'][l['N']:] if x['prove_s'] is not None]
        v = l.get('verify_summary', {})
        failed |= bool(v.get('other', 0)) or not l['all_proved']
        chk = f'receipts checked by B0 check-serve {v.get("checked", 0)} of {v.get("receipts", 0)}, other {v.get("other", 0)}' if l['verified_by_B0'] else 'arm A: receipts deleted unverified'
        print(f'leg {l["leg"]} arm {l["arm"]}: rate {rt:.3f} tok/s | mean prove call {statistics.mean(pr):.3f} s | all proved {l["all_proved"]} | {chk} | {l.get("utc_start")} to {l.get("utc_end")}')
    if len(rate) < 6:
        return None
    g = lambda a, b: rate[a] / rate[b] - 1
    prim = (g(3, 1), g(4, 6))
    print(f'PRIMARY, C over A: pair (leg 1, leg 3) {100 * prim[0]:+.2f}%, pair (leg 6, leg 4) {100 * prim[1]:+.2f}%')
    print(f'secondary, B over A: pair (1, 2) {100 * g(2, 1):+.2f}%, pair (6, 5) {100 * g(5, 6):+.2f}%; C over B: pair (2, 3) {100 * g(3, 2):+.2f}%, pair (5, 4) {100 * g(4, 5):+.2f}%')
    if failed:
        word = 'CORRECTNESS FINDING (a receipt or a request failed): the test ends'
    elif min(prim) >= 0.03:
        word = 'PASS'
    elif min(prim) < 0.015:
        word = 'NO TRANSFER'
    else:
        word = 'not decided by this set: the set is repeated once'
    print(f'verdict of this set by the 03:01:33Z rule: {word}')
    jp = raw / f'{sub}.guard.json'
    if jp.exists():
        gj = json.load(open(jp))
        print(f'guard {gj["run_id"]}: exit {gj["exit"]}, peak RSS {gj["peak_rss_gib"]} GiB, peak VRAM {gj["peak_vram_mib"]} MiB, waited {gj.get("waited_s")} s')
    print()
    return prim


prims = []
for sub in ('bn_set1', 'bn_set2'):
    p = one_set(sub)
    if p:
        prims += list(p)
if prims:
    mean = sum(prims) / len(prims)
    print(f'== primary pair gains of the sets read: ' + ', '.join(f'{100 * x:+.2f}%' for x in prims) + f'; mean {100 * mean:+.2f}%')
    if len(prims) == 4:
        final = 'PASS' if (mean >= 0.03 and min(prims) >= 0.015) else ('NO TRANSFER' if mean < 0.015 else 'transfers, under the bar')
        print('FINAL VERDICT (23:42:06Z reading of the repeat):', final)
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


def traced(sub, title):
    legs = load(sub)
    if not legs:
        return
    print(f'== {title} ({sub}), no verdict')
    for l in legs:
        N, T = l['N'], l['timed']
        recs = sorted(l['completions'], key=lambda x: x['t_abs'])
        lo, hi = recs[N - 1]['t_abs'], recs[N + T - 1]['t_abs']
        rt = T * 128 / (hi - lo)
        mp = statistics.mean(x['prove_s'] for x in recs[N:] if x['prove_s'] is not None)
        B = BLOCKS * T
        rows = []
        for f in glob.glob(str(raw / 'traces' / (Path(l['trace_prefix']).name + '.*.tsv*'))):
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
        wall = mp / BLOCKS * 1000
        u = union_len([(r[4], r[5]) for r in win], lo, hi) / (hi - lo)
        big = {'2504': 0.0, '2606': 0.0}
        spf = [r for r in win if r[0] == 'spfold']
        for r in prover:
            if r[0] == 'commit' and 'rows=2504' in r[1]:
                big['2504'] += (r[5] - r[4]) / B * 1000
            elif r[0] == 'commit' and 'rows=2606' in r[1]:
                big['2606'] += (r[5] - r[4]) / B * 1000
        ncommit = sum(1 for r in prover if r[0] == 'commit')
        print(f'leg {l["leg"]} arm {l["arm"]}: rate {rt:.3f} tok/s | wall {wall:.1f} ms/block | prover e {e:.1f} q {q:.1f} w {w:.1f} ms/block | host time (wall - e - q - w, DERIVED) {wall - e - q - w:.1f} ms/block | '
              f'empty-device share (1 - union over all buffers) {100 * (1 - u):.1f} % | commit e: rows 2504 {big["2504"]:.2f}, rows 2606 {big["2606"]:.2f} ms/block | commit buffers/block {ncommit / B:.2f} | '
              f'spfold buffers {len(spf)} ({len(spf) / B:.2f}/block, e {sum(r[5] - r[4] for r in spf) / B * 1000:.2f} ms/block) | records {len(rows)}')
    print()


traced('bn_smoke', 'smoke legs (not timed measurements; evidence for which paths are taken)')
traced('bn_trace', 'traced pair A then C')

#!/usr/bin/env python3
"""Tick 37 (queue item 61): host gaps between consecutive Metal buffers on a request thread, arm A (pushed head,
cm_trace leg 1) against arm C (composed bundle, both switches on, cm_trace leg 2), plus the two smoke traces (arm C, arm B).
Standard library only; run as: python3 -I -B this.py <results/zk60_composed_app_20261122/raw>   (reads the .xz traces and
cm_trace/t2_results.json, cm_smoke/t2_results.json; no model, content or owner-private file).
Definitions (as tick 30's script): a request thread is a thread with >1000 buffers in the whole trace; a request is a run
that starts at the first 'wprod' buffer after a non-wprod buffer (the t=65 start-up products dropped); a block runs from
the begin of one A commit (tag commit, rows=2504) to the begin of the next A commit on the same thread (25 blocks per
request; the 26th has no next A commit). A block is kept when its first A commit BEGINS inside [completion N, completion N+timed].
Per block the period telescopes exactly: sum over its buffers of (done - begin) + sum of gaps (next begin - done) = period,
so the table sums to the period by construction; the check is against the README's separate host figure."""
import collections
import json
import lzma
import os
import re
import statistics as st
import sys

raw = sys.argv[1].rstrip('/')


def load(prefix, pid):
    f = '%s/traces/%s.%d.tsv.xz' % (raw, os.path.basename(prefix), pid)
    rows = []
    for i, line in enumerate(lzma.open(f, 'rt')):
        p = line.rstrip('\n').split('\t')
        if i == 0 or len(p) != 9:
            continue
        rows.append(dict(tag=p[0], det=p[1], th=int(p[2]), q=int(p[3]), beg=float(p[4]), com=float(p[5]),
                         gs=float(p[6]), ge=float(p[7]), dn=float(p[8])))
    return rows


def key(r):
    d, t = r['det'], r['tag']
    if t == 'commit':
        return 'commit ' + d.split(' log_n')[0]
    if t == 'gather':
        return 'gather ' + d.split(' nn')[0]
    if t == 'batch':
        m = re.match(r'slot (\d+)', d)
        return 'batch slot%02d' % int(m.group(1)) if m else 'batch ' + d.split(' (')[0]
    return t


def analyse(L, rows, title, verbose=True):
    N, T = L['N'], L['timed']
    c = sorted(x['t_abs'] for x in L['completions'])
    lo, hi = c[N - 1], c[N + T - 1]
    by = collections.defaultdict(list)
    for r in rows:
        by[r['th']].append(r)
    main = sorted(t for t, v in by.items() if len(v) > 1000)
    # pool-thread (not request thread) prover buffers in the window: e, q, w
    pool = [r for r in rows if r['th'] not in main and r['tag'] != 'wprod' and lo <= r['beg'] <= hi]
    reqs = []
    for t in main:
        v = sorted((r for r in by[t] if not (r['tag'] == 'wprod' and 't=65' in r['det'])), key=lambda r: r['beg'])
        starts = [i for i, r in enumerate(v) if r['tag'] == 'wprod' and (i == 0 or v[i - 1]['tag'] != 'wprod')]
        starts.append(len(v))
        for a, b in zip(starts, starts[1:]):
            reqs.append((t, v[a:b]))
    tot = collections.Counter()
    trans = collections.defaultdict(list)
    nb = 0
    neg = 0
    periods = []
    for t, v in reqs:
        A = [i for i, r in enumerate(v) if r['tag'] == 'commit' and 'rows=2504' in r['det']]
        for i0, i1 in zip(A, A[1:]):
            if not (lo <= v[i0]['beg'] <= hi):
                continue
            seg = v[i0:i1 + 1]
            nb += 1
            periods.append(seg[-1]['beg'] - seg[0]['beg'])
            for r in seg[:-1]:
                tot['encode'] += r['com'] - r['beg']
                tot['queue'] += r['gs'] - r['com']
                tot['exec'] += r['ge'] - r['gs']
                tot['wait'] += r['dn'] - r['ge']
            for p, q in zip(seg, seg[1:]):
                g = q['beg'] - p['dn']
                neg += g < 0
                tot['gap'] += g
                trans[(key(p), key(q))].append(g)
            tot['period'] += seg[-1]['beg'] - seg[0]['beg']
    out = dict(nb=nb, per={k: v / nb * 1e3 for k, v in tot.items()}, trans={k: (sum(g) / nb * 1e3, len(g) / nb, st.median(g) * 1e3) for k, g in trans.items()},
               neg=neg, pool_n=len(pool),
               pool_eqw=sum(r['dn'] - r['com'] for r in pool) / max(nb, 1) * 1e3, nreq=len(reqs), main=main)
    if verbose:
        print('\n=== %s: %d blocks kept (A begin in window), %d request threads, %d requests found, window %.2f s ===' % (title, nb, len(main), len(reqs), hi - lo))
        for k in ('period', 'encode', 'queue', 'exec', 'wait', 'gap'):
            print('  per block %-8s %8.1f ms' % (k, out['per'][k]))
        print('  check: encode+queue+exec+wait+gap = %.1f ms vs period %.1f ms; negative gaps %d' % (
            sum(out['per'][k] for k in ('encode', 'queue', 'exec', 'wait', 'gap')), out['per']['period'], neg))
        print('  host-side time on the request thread (encode + gap) = %.1f ms per block' % (out['per']['encode'] + out['per']['gap']))
        print('  pool-thread prover buffers in window: %d, committed->done %.1f ms per block' % (len(pool), out['pool_eqw']))
    return out


legs = json.load(open(raw + '/cm_trace/t2_results.json'))['legs']
sm = json.load(open(raw + '/cm_smoke/t2_results.json'))['legs']
res = {}
for name, L in (('A', legs[0]), ('C', legs[1]), ('smokeC', sm[0]), ('smokeB', sm[1])):
    rows = load(L['trace_prefix'], L['server_pid'])
    res[name] = analyse(L, rows, name + ' (arm %s, %s)' % (L['arm'], os.path.basename(L['trace_prefix'])))
    res[name]['records'] = len(rows)
    print('  records', len(rows))

# ---- (a) the difference table: A against C, sorted by (A - C)
A, C = res['A'], res['C']
keys = set(A['trans']) | set(C['trans'])
dif = sorted(((A['trans'].get(k, (0, 0, 0))[0] - C['trans'].get(k, (0, 0, 0))[0], k) for k in keys), reverse=True)
print('\n=== (a) gap keys by ms per block, A minus C (positive = C lost it); both arms on the same request-thread definition ===')
print('%8s %8s %8s  %5s %5s  %7s %7s   %s' % ('A-C', 'A', 'C', 'nA', 'nC', 'medA', 'medC', 'key (tag before -> tag after)'))
for d, k in dif[:22]:
    a, c = A['trans'].get(k, (0, 0, 0)), C['trans'].get(k, (0, 0, 0))
    print('%8.2f %8.2f %8.2f  %5.2f %5.2f  %7.3f %7.3f   %s -> %s' % (d, a[0], c[0], a[1], c[1], a[2], c[2], k[0], k[1]))
print('... most negative (C larger):')
for d, k in dif[-8:]:
    a, c = A['trans'].get(k, (0, 0, 0)), C['trans'].get(k, (0, 0, 0))
    print('%8.2f %8.2f %8.2f  %5.2f %5.2f  %7.3f %7.3f   %s -> %s' % (d, a[0], c[0], a[1], c[1], a[2], c[2], k[0], k[1]))
print('sum of A-C over all keys = %.1f ms; A gap total %.1f, C gap total %.1f' % (sum(d for d, k in dif), A['per']['gap'], C['per']['gap']))
pos = sum(d for d, k in dif if d > 0)
print('sum of the positive differences %.1f ms; sum of the top 10 %.1f ms' % (pos, sum(d for d, k in dif[:10])))

# ---- (b) remaining gaps in C alone
print('\n=== (b) the 14 largest remaining gaps in C (ms per block) ===')
cs = sorted(((v[0], v[1], v[2], k) for k, v in C['trans'].items()), reverse=True)
for s, n, med, k in cs[:14]:
    print('%8.2f ms/block  %5.2f/block  median %7.3f ms   %s -> %s' % (s, n, med, k[0], k[1]))
print('top 14 sum %.1f of C gap total %.1f' % (sum(x[0] for x in cs[:14]), C['per']['gap']))
for nm in ('A',):
    ass = sorted(((v[0], v[1], v[2], k) for k, v in A['trans'].items()), reverse=True)
    print('--- A, the 14 largest for comparison')
    for s, n, med, k in ass[:14]:
        print('%8.2f ms/block  %5.2f/block  median %7.3f ms   %s -> %s' % (s, n, med, k[0], k[1]))

# ---- (c) can the smoke traces split the cut
print('\n=== (c) smoke traces against the traced pair (per block, request thread; ms) ===')
print('%-8s %6s %8s %8s %8s %8s %8s %8s' % ('arm', 'blocks', 'period', 'encode', 'queue', 'exec', 'wait', 'gap'))
for nme in ('A', 'C', 'smokeC', 'smokeB'):
    r = res[nme]
    p = r['per']
    print('%-8s %6d %8.1f %8.1f %8.1f %8.1f %8.1f %8.1f' % (nme, r['nb'], p['period'], p['encode'], p['queue'], p['exec'], p['wait'], p['gap']))
# per-block bootstrap-free spread: block-to-block std of gap in each arm, from the keyed lists


# ---- (d) request-level pieces outside the 25 kept block periods: sealing window, hand-over, run edges, lane period
def request_level(L, rows, title):
    N, T = L['N'], L['timed']
    c = sorted(x['t_abs'] for x in L['completions'])
    lo, hi = c[N - 1], c[N + T - 1]
    by = collections.defaultdict(list)
    for r in rows:
        by[r['th']].append(r)
    main = sorted(t for t, v in by.items() if len(v) > 1000)
    seal, hand, run, tail, head, lane = [], [], [], [], [], []
    for t in main:
        v = sorted((r for r in by[t] if not (r['tag'] == 'wprod' and 't=65' in r['det'])), key=lambda r: r['beg'])
        starts = [i for i, r in enumerate(v) if r['tag'] == 'wprod' and (i == 0 or v[i - 1]['tag'] != 'wprod')]
        starts.append(len(v))
        firsts = []
        for a, b in zip(starts, starts[1:]):
            seg = v[a:b]
            wp = [r for r in seg if r['tag'] == 'wprod']
            after = [r for r in seg if r['beg'] > wp[-1]['dn']]
            if not after or not (lo <= wp[0]['beg'] <= hi):
                continue
            A = [r for r in after if r['tag'] == 'commit' and 'rows=2504' in r['det']]
            seal.append(wp[-1]['dn'] - wp[0]['beg'])
            hand.append(after[0]['beg'] - wp[-1]['dn'])
            head.append(A[0]['beg'] - after[0]['beg'])
            run.append(max(r['dn'] for r in after) - after[0]['beg'])
            tail.append(max(r['dn'] for r in after) - A[-1]['beg'])
            firsts.append((wp[0]['beg'], max(r['dn'] for r in after)))
        for (b0, e0), (b1, e1) in zip(firsts, firsts[1:]):
            lane.append(b1 - b0)
    n = len(seal)
    print('%-7s requests %3d | sealing window %.3f s | hand-over %.3f s | run (first run buffer to last done) %.3f s = head before first A %.3f + 25 block periods + last block %.3f | lane period (first wprod to next first wprod, same thread) %.3f s (n=%d)' % (
        title, n, st.mean(seal), st.mean(hand), st.mean(run), st.mean(head), st.mean(tail), st.mean(lane) if lane else float('nan'), len(lane)))
    return dict(seal=st.mean(seal), hand=st.mean(hand), run=st.mean(run), head=st.mean(head), tail=st.mean(tail), n=n)


print('\n=== (d) request-level pieces (per request; sealing window is the wprod run) ===')
rl = {}
for name, L in (('A', legs[0]), ('C', legs[1]), ('smokeC', sm[0]), ('smokeB', sm[1])):
    rows = load(L['trace_prefix'], L['server_pid'])
    rl[name] = request_level(L, rows, name)
for a, b in (('A', 'C'), ('smokeB', 'smokeC')):
    print('%s minus %s: seal %.3f s, hand-over %.3f s, run %.3f s' % (a, b, rl[a]['seal'] - rl[b]['seal'], rl[a]['hand'] - rl[b]['hand'], rl[a]['run'] - rl[b]['run']))
# README wall per block = mean prove_s / 26: compare with run / 26
for name, L in (('A', legs[0]), ('C', legs[1])):
    N = L['N']
    pr = [x['prove_s'] for x in sorted(L['completions'], key=lambda x: x['t_abs'])[N:] if x['prove_s'] is not None]
    print('%s: mean prove_s %.3f s = %.1f ms per block of 26; run from the trace %.3f s = %.1f ms per block of 26' % (
        name, st.mean(pr), st.mean(pr) / 26 * 1e3, rl[name]['run'], rl[name]['run'] / 26 * 1e3))


# ---- (e) grouped by code phase, the four arms side by side (ms per block, request thread)
def group(k):
    a, b = k
    if b.startswith('spfold') or a.startswith('spfold') or (a == 'batch slot22' and b.startswith('gather')) or (a.startswith('gather') and b.startswith('gather')):
        return 'G1 openings tail: slot 22 -> gather 38 (open M, schedule audit, fold, open A/H/B)'
    if (a, b) == ('gather rows=38', 'commit rows=38'):
        return 'G2 gather 38 -> boundary commit (opening tail, segment encode, sink, next block load, boundary prepare)'
    if (a, b) == ('commit rows=38', 'commit rows=2504'):
        return 'G3 boundary commit -> A commit (witness, A rows, histograms, mask draw)'
    if (a, b) == ('commit rows=2504', 'commit rows=2606'):
        return 'G4 A commit -> H commit (M commit, absorbs, helper inverses, H masks)'
    if a == 'batch slot04' and b.startswith('batch slot1') or (a.startswith('batch slot0') and b.startswith('batch slot1') and int(a[-2:]) < 14 and int(b[-2:]) == 14):
        return 'G5 matmul slots 5-13 (host) -> slot 14'
    if a.startswith('batch') or b.startswith('batch'):
        return 'G6 between the other slots and after the H commit'
    return 'G7 other'


grp = {}
for nme in ('A', 'C', 'smokeB', 'smokeC'):
    g = collections.defaultdict(float)
    for k, v in res[nme]['trans'].items():
        g[group(k)] += v[0]
    grp[nme] = g
print('\n=== (e) gaps grouped by the code phase they sit in (ms per block; the four arms) ===')
print('%-102s %7s %7s %7s %7s' % ('group', 'A', 'C', 'smkB', 'smkC'))
for gname in sorted(set().union(*[set(g) for g in grp.values()])):
    print('%-102s %7.1f %7.1f %7.1f %7.1f' % (gname, grp['A'][gname], grp['C'][gname], grp['smokeB'][gname], grp['smokeC'][gname]))
print('%-102s %7.1f %7.1f %7.1f %7.1f' % ('sum', *[sum(grp[n].values()) for n in ('A', 'C', 'smokeB', 'smokeC')]))


# ---- (f) wall of the opening region (slot 22 done -> next boundary commit begin) and the lane remainder
def region(L, rows, title):
    N, T = L['N'], L['timed']
    c = sorted(x['t_abs'] for x in L['completions'])
    lo, hi = c[N - 1], c[N + T - 1]
    by = collections.defaultdict(list)
    for r in rows:
        by[r['th']].append(r)
    main = sorted(t for t, v in by.items() if len(v) > 1000)
    w, ex, n = [], [], 0
    for t in main:
        v = sorted(by[t], key=lambda r: r['beg'])
        for i, r in enumerate(v):
            if r['tag'] == 'batch' and r['det'].startswith('slot 22') and lo <= r['beg'] <= hi:
                j = i + 1
                while j < len(v) and not (v[j]['tag'] == 'commit' and 'rows=38' in v[j]['det']):
                    j += 1
                if j < len(v):
                    w.append(v[j]['beg'] - r['dn'])
                    ex.append(sum(x['ge'] - x['gs'] for x in v[i + 1:j]))
    print('%-7s slot-22-done to boundary-commit-begin: wall %.1f ms per block (n=%d), of which buffer execution %.1f ms' % (title, st.mean(w) * 1e3, len(w), st.mean(ex) * 1e3))
    return st.mean(w) * 1e3


print('\n=== (f) wall of the opening region, and the lane period remainder ===')
rg = {}
for name, L in (('A', legs[0]), ('C', legs[1]), ('smokeB', sm[1]), ('smokeC', sm[0])):
    rows = load(L['trace_prefix'], L['server_pid'])
    rg[name] = region(L, rows, name)
print('region wall A - C = %.1f ms per block (gap cut in G1 was %.1f)' % (rg['A'] - rg['C'], grp['A']['G1 openings tail: slot 22 -> gather 38 (open M, schedule audit, fold, open A/H/B)'] - grp['C']['G1 openings tail: slot 22 -> gather 38 (open M, schedule audit, fold, open A/H/B)']))
for name, lane in (('A', 17.645), ('C', 16.780)):
    r = rl[name]
    print('%s: lane period %.3f - (seal %.3f + hand-over %.3f + run %.3f) = %.3f s outside those three' % (name, lane, r['seal'], r['hand'], r['run'], lane - r['seal'] - r['hand'] - r['run']))

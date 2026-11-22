#!/usr/bin/env python3
"""Tick 39 (queue item 63): the per-request, per-thread tail between the last run buffer's done and the same thread's next
sealing buffer (wprod) begin, in the three full traced arms of one run (cm_trace3 legs 1, 2, 3 = arms A, B, C), with the
head before the first A commit, the sealing window, the hand-over, the run and the lane period beside it.
Standard library only; run as: python3 -I -B this.py <results/zk60_composed_app_20261122/raw>
(reads the .xz traces and cm_trace3/t2_results.json; no model, content or owner-private file).

Definitions (as tick 37, extended):
  request thread = thread with more than 1,000 buffers in the trace (six); the start-up 'wprod' rows with 't=65' are dropped;
  a request = a run of consecutive 'wprod' rows on one thread (the sealing products) plus every later row of that thread up
  to the next such run; for a request k with a next request k+1 on the same thread:
    seal  = last wprod done - first wprod begin           (sealing window)
    hand  = first run row begin - last wprod done         (hand-over)
    head  = first A commit (rows=2504) begin - first run row begin
    run   = latest done among run rows - first run row begin
    tail  = first wprod begin of k+1 - latest done among run rows of k       (directly measured, can be negative only if a row
                                                                           of k+1 precedes; checked)
    lane  = first wprod begin of k+1 - first wprod begin of k
  seal + hand + run + tail = lane identically; the check below is that the numbers computed separately add up.
A request is kept when its first wprod begins inside [completion N, completion N+timed] (N = 6, timed = 48, completion times
from t2_results.json) and it has a successor on the thread."""
import collections
import json
import lzma
import os
import random
import statistics as st
import sys

raw = sys.argv[1].rstrip('/')
sub = sys.argv[2] if len(sys.argv) > 2 else 'cm_trace3'   # 'cm_trace' = tick 37's traced pair (A, C)
random.seed(20261122)


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


def requests(rows):
    by = collections.defaultdict(list)
    for r in rows:
        by[r['th']].append(r)
    main = sorted(t for t, v in by.items() if len(v) > 1000)
    out = {}
    for t in main:
        v = sorted((r for r in by[t] if not (r['tag'] == 'wprod' and 't=65' in r['det'])), key=lambda r: r['beg'])
        starts = [i for i, r in enumerate(v) if r['tag'] == 'wprod' and (i == 0 or v[i - 1]['tag'] != 'wprod')]
        starts.append(len(v))
        out[t] = [v[a:b] for a, b in zip(starts, starts[1:])]
    return by, main, out


def pct(x, q):
    x = sorted(x)
    k = (len(x) - 1) * q
    f = int(k)
    c = min(f + 1, len(x) - 1)
    return x[f] + (x[c] - x[f]) * (k - f)


def boot(a, b, n=20000):
    """unpaired bootstrap of mean(a) - mean(b): 95% interval"""
    d = []
    for _ in range(n):
        ma = sum(random.choice(a) for _ in a) / len(a)
        mb = sum(random.choice(b) for _ in b) / len(b)
        d.append(ma - mb)
    d.sort()
    return d[int(0.025 * n)], d[int(0.975 * n)]


L = json.load(open(raw + '/' + sub + '/t2_results.json'))['legs']
arms = {}
for leg in L:
    name = leg['arm']
    rows = load(leg['trace_prefix'], leg['server_pid'])
    by, main, reqs = requests(rows)
    N, T = leg['N'], leg['timed']
    c = sorted(x['t_abs'] for x in leg['completions'])
    lo, hi = c[N - 1], c[N + T - 1]
    recs = []
    for t, rl in reqs.items():
        for k in range(len(rl) - 1):
            seg, nxt = rl[k], rl[k + 1]
            wp = [r for r in seg if r['tag'] == 'wprod']
            after = [r for r in seg if r['beg'] > wp[-1]['dn']]
            if not after or not (lo <= wp[0]['beg'] <= hi):
                continue
            A = [r for r in after if r['tag'] == 'commit' and 'rows=2504' in r['det']]
            nxt_wp = [r for r in nxt if r['tag'] == 'wprod'][0]
            enda = max(r['dn'] for r in after)
            # the row that finishes last, and the last rows before the tail
            last = max(after, key=lambda r: r['dn'])
            recs.append(dict(
                th=t, seal=wp[-1]['dn'] - wp[0]['beg'], hand=after[0]['beg'] - wp[-1]['dn'],
                head=A[0]['beg'] - after[0]['beg'], run=enda - after[0]['beg'], tail=nxt_wp['beg'] - enda,
                lane=nxt_wp['beg'] - wp[0]['beg'], last=(last['tag'], last['det'][:30]),
                n_after=len(after), nwp=len(wp),
                # blocks inside the run: A commit begin to next A commit begin
                blocks=[(A[i + 1]['beg'] - A[i]['beg']) for i in range(len(A) - 1)],
                lastblock=enda - A[-1]['beg'], t0=wp[0]['beg']))
    # pool-thread (non request thread) buffers that begin inside any kept tail interval
    tails = []
    for t, rl in reqs.items():
        for k in range(len(rl) - 1):
            seg, nxt = rl[k], rl[k + 1]
            wp = [r for r in seg if r['tag'] == 'wprod']
            after = [r for r in seg if r['beg'] > wp[-1]['dn']]
            if not after or not (lo <= wp[0]['beg'] <= hi):
                continue
            tails.append((max(r['dn'] for r in after), [r for r in nxt if r['tag'] == 'wprod'][0]['beg'], t))
    pool_in_tail = 0
    for t, v in by.items():
        if t in main:
            continue
        for r in v:
            for a, b, tt in tails:
                if a <= r['beg'] <= b:
                    pool_in_tail += 1
                    break
    # the same-thread rows that begin inside own tail (should be none by construction)
    arms[name] = dict(recs=recs, leg=leg, lo=lo, hi=hi, pool_in_tail=pool_in_tail, ntails=len(tails))

print('== (1) per arm: kept requests, pieces of the lane period (seconds per request; mean, and sum check) ==')
print('%-4s %4s %7s %7s %7s %7s %7s | %8s %9s %8s | %7s %7s' % ('arm', 'n', 'seal', 'hand', 'run', 'tail', 'lane', 'sum', 'sum-lane', 'rel', 'head', 'meas'))
for nm in sorted(arms):
    a = arms[nm]
    R = a['recs']
    m = {k: st.mean(r[k] for r in R) for k in ('seal', 'hand', 'run', 'tail', 'lane', 'head')}
    s = m['seal'] + m['hand'] + m['run'] + m['tail']
    # measured rate from the leg and the lane-period-implied rate (6 lanes x 128 tokens / lane period)
    print('%-4s %4d %7.3f %7.3f %7.3f %7.3f %7.3f | %8.3f %9.4f %7.3f%% | %7.3f rate %.2f implied %.2f' % (
        nm, len(R), m['seal'], m['hand'], m['run'], m['tail'], m['lane'], s, s - m['lane'], (s - m['lane']) / m['lane'] * 100,
        m['head'], a['leg']['rate'], 6 * 128 / m['lane']))

print('\n== (2) the tail, per request: distribution (ms) ==')
print('%-4s %4s %7s %7s %7s %7s %7s %7s %7s %7s' % ('arm', 'n', 'mean', 'sd', 'min', 'p25', 'median', 'p75', 'p95', 'max'))
for nm in sorted(arms):
    x = [r['tail'] * 1e3 for r in arms[nm]['recs']]
    print('%-4s %4d %7.1f %7.1f %7.1f %7.1f %7.1f %7.1f %7.1f %7.1f' % (nm, len(x), st.mean(x), st.pstdev(x), min(x), pct(x, .25), st.median(x), pct(x, .75), pct(x, .95), max(x)))

print('\n== (3) the tail per thread (ms; mean over the thread\'s kept requests) ==')
for nm in sorted(arms):
    byt = collections.defaultdict(list)
    for r in arms[nm]['recs']:
        byt[r['th']].append(r['tail'] * 1e3)
    print(nm, ' '.join('t%d:%.0f(n=%d)' % (t, st.mean(v), len(v)) for t, v in sorted(byt.items())))

print('\n== (4) what finishes last in the run, and the pool-thread rows in the tails ==')
for nm in sorted(arms):
    c = collections.Counter(r['last'][0] + ' ' + r['last'][1] for r in arms[nm]['recs'])
    print(nm, dict(c.most_common(3)), '| rows of ALL non-request threads (any lane) beginning inside a kept tail (no lane attribution):', arms[nm]['pool_in_tail'], 'of', arms[nm]['ntails'], 'tails')

print('\n== (5) differences with 95%% unpaired bootstrap intervals over requests (s per request; negative = second arm longer) ==')
pieces = ('lane', 'seal', 'hand', 'run', 'tail', 'head')
for a, b in [x for x in (('A', 'C'), ('A', 'B'), ('B', 'C')) if x[0] in arms and x[1] in arms]:
    print('%s minus %s:' % (a, b))
    for k in pieces:
        xa = [r[k] for r in arms[a]['recs']]
        xb = [r[k] for r in arms[b]['recs']]
        d = st.mean(xa) - st.mean(xb)
        lo_, hi_ = boot(xa, xb)
        print('   %-5s %+8.3f  [%+.3f, %+.3f]%s' % (k, d, lo_, hi_, '' if (lo_ > 0 or hi_ < 0) else '  (interval holds 0)'))

print('\n== (6) the run, split: head + block periods + last block (s per request) ==')
for nm in sorted(arms):
    R = arms[nm]['recs']
    nbk = collections.Counter(len(r['blocks']) for r in R)
    print('%-3s head %.3f + blocks %.3f (n per request %s) + last block %.3f = %.3f ; run %.3f ; mean block period %.1f ms' % (
        nm, st.mean(r['head'] for r in R), st.mean(sum(r['blocks']) for r in R), dict(nbk), st.mean(r['lastblock'] for r in R),
        st.mean(r['head'] + sum(r['blocks']) + r['lastblock'] for r in R), st.mean(r['run'] for r in R),
        st.mean(sum(r['blocks']) / len(r['blocks']) for r in R) * 1e3))

print('\n== (7) rate cross-check: the cut in the lane period against the cut in the measured rate ==')
for a, b in [x for x in (('A', 'C'), ('A', 'B'), ('B', 'C')) if x[0] in arms and x[1] in arms]:
    la = st.mean(r['lane'] for r in arms[a]['recs'])
    lb = st.mean(r['lane'] for r in arms[b]['recs'])
    ra, rb = arms[a]['leg']['rate'], arms[b]['leg']['rate']
    print('%s -> %s: lane period %.3f -> %.3f (%+.2f%%; 1/x gives rate %+.2f%%); measured rate %.2f -> %.2f (%+.2f%%)' % (
        a, b, la, lb, (lb / la - 1) * 100, (la / lb - 1) * 100, ra, rb, (rb / ra - 1) * 100))

print('\n== (8) the lane-period cut split into the pieces: A to B (always-on part) and B to C (the two switches) (s) ==')
print('%-8s %8s %8s %8s %8s %8s' % ('step', 'lane', 'seal', 'hand', 'run', 'tail'))
for a, b in [x for x in (('A', 'B'), ('B', 'C'), ('A', 'C')) if x[0] in arms and x[1] in arms]:
    ms = {k: st.mean(r[k] for r in arms[a]['recs']) - st.mean(r[k] for r in arms[b]['recs']) for k in ('lane', 'seal', 'hand', 'run', 'tail')}
    print('%s-%-5s %+8.3f %+8.3f %+8.3f %+8.3f %+8.3f' % (a, b, ms['lane'], ms['seal'], ms['hand'], ms['run'], ms['tail']))

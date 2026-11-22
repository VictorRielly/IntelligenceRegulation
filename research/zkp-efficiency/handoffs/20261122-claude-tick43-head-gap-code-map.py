#!/usr/bin/env python3
"""Tick 43: the gaps inside the head of a request (first run buffer to first A commit, rows=2504), per arm of the three
traced legs, mean / median / p10 / p90 over the kept requests, with the code step each gap holds (by order, from the source
reading in the handoff). Standard library only; run as: python3 -I -B this.py <raw>   (raw = results/zk60_composed_app_20261122/raw)
Also prints, per arm, the hand-over (last sealing product done to the first run buffer begin) and the lane period, so the
shares are computed on one set of requests."""
import collections, json, lzma, os, statistics as st, sys
raw = sys.argv[1].rstrip('/')
legs = json.load(open(raw + '/cm_trace3/t2_results.json'))['legs']
LABEL = {'a': 'endpoint commit -> B_in commit (CLI statement + prove_classify_run_with preamble)',
         'b': 'B_in commit -> IN-C A commit (A data, masks)',
         'c': 'IN-C A commit -> IN-C H commit (M commit, challenges incl. embedding fold, h data)',
         'd': 'IN-C H commit -> first opening fold (four slots, mask_open, check_opening)',
         'e': 'last opening gather -> block 0 boundary commit (ep decommitment, encode, sink, block 0 prelude)',
         'f': 'block 0 boundary commit -> first A commit (G3 of block 0: witness, parity, A rows, histograms, masks)'}
def pct(v, q):
    v = sorted(v); i = q * (len(v) - 1); lo = int(i); hi = min(lo + 1, len(v) - 1)
    return v[lo] + (v[hi] - v[lo]) * (i - lo)
for leg in legs:
    f = '%s/traces/%s.%d.tsv.xz' % (raw, os.path.basename(leg['trace_prefix']), leg['server_pid'])
    rows = []
    for i, line in enumerate(lzma.open(f, 'rt')):
        p = line.rstrip('\n').split('\t')
        if i == 0 or len(p) != 9: continue
        rows.append(dict(tag=p[0], det=p[1], th=int(p[2]), beg=float(p[4]), dn=float(p[8])))
    by = collections.defaultdict(list)
    for r in rows: by[r['th']].append(r)
    main = sorted(t for t, v in by.items() if len(v) > 1000)
    N, T = leg['N'], leg['timed']
    c = sorted(x['t_abs'] for x in leg['completions']); lo, hi = c[N - 1], c[N + T - 1]
    gaps = collections.defaultdict(list); heads = []; hand = []; lane = []
    for t in main:
        v = sorted((r for r in by[t] if not (r['tag'] == 'wprod' and 't=65' in r['det'])), key=lambda r: r['beg'])
        idx = [i for i, r in enumerate(v) if r['tag'] == 'wprod' and (i == 0 or v[i - 1]['tag'] != 'wprod')] + [len(v)]
        for a, b in zip(idx, idx[1:]):
            seg = v[a:b]; wp = [r for r in seg if r['tag'] == 'wprod']
            after = [r for r in seg if r['beg'] > wp[-1]['dn']]
            if not after or not (lo <= wp[0]['beg'] <= hi): continue
            A = next((i for i, r in enumerate(after) if r['tag'] == 'commit' and 'rows=2504' in r['det']), None)
            if A is None: continue
            h = after[:A + 1]
            heads.append(h[-1]['beg'] - h[0]['beg']); hand.append(after[0]['beg'] - wp[-1]['dn'])
            # named gaps: a = after the first commit (rows=6, the endpoint); b = after the first rows=38 commit; c = after rows=41;
            # d = after rows=76; e = the gap before the second rows=38 commit (block 0's boundary); f = the gap after it, to the A commit
            key = {}
            for j in range(A):
                d0, d1 = h[j]['det'], h[j + 1]['det']
                if j == 0: key[j] = 'a'
                elif h[j]['tag'] == 'commit' and 'rows=38' in d0 and 'b' not in key.values(): key[j] = 'b'
                elif h[j]['tag'] == 'commit' and 'rows=41' in d0: key[j] = 'c'
                elif h[j]['tag'] == 'commit' and 'rows=76' in d0: key[j] = 'd'
                elif h[j + 1]['tag'] == 'commit' and 'rows=38' in d1 and 'e' not in key.values(): key[j] = 'e'
                elif h[j]['tag'] == 'commit' and 'rows=38' in d0: key[j] = 'f'
                else: key[j] = 'x'
            for j in range(A): gaps[key[j]].append(h[j + 1]['beg'] - h[j]['dn'])
            if b < len(v) and v[b]['tag'] == 'wprod': lane.append(v[b]['beg'] - wp[0]['beg'])
    print('arm %s: %d requests; head %.1f ms (%.2f%% of lane %.0f ms); hand-over %.1f ms' % (
        leg['arm'], len(heads), 1e3 * st.mean(heads), 100 * st.mean(heads) / st.mean(lane), 1e3 * st.mean(lane), 1e3 * st.mean(hand)))
    for j in sorted(gaps):
        g = [1e3 * x for x in gaps[j]]
        print('  gap %s mean %6.1f  median %6.1f  p10 %6.1f  p90 %6.1f  min %6.1f  max %6.1f   %s' % (
            j, st.mean(g), st.median(g), pct(g, .1), pct(g, .9), min(g), max(g), LABEL.get(j, '')))

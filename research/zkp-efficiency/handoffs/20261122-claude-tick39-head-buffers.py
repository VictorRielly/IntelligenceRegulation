#!/usr/bin/env python3
"""Tick 39, fourth script: the buffers and host gaps inside the head (first run buffer to first A commit, rows=2504) of a
request, mean over the kept requests of one arm. Standard library only; run as: python3 -I -B this.py <raw> [leg index 0..2]"""
import collections, json, lzma, os, statistics as st, sys
raw = sys.argv[1].rstrip('/')
li = int(sys.argv[2]) if len(sys.argv) > 2 else 2
leg = json.load(open(raw + '/cm_trace3/t2_results.json'))['legs'][li]
f = '%s/traces/%s.%d.tsv.xz' % (raw, os.path.basename(leg['trace_prefix']), leg['server_pid'])
rows = []
for i, line in enumerate(lzma.open(f, 'rt')):
    p = line.rstrip('\n').split('\t')
    if i == 0 or len(p) != 9: continue
    rows.append(dict(tag=p[0], det=p[1], th=int(p[2]), beg=float(p[4]), gs=float(p[6]), ge=float(p[7]), dn=float(p[8])))
by = collections.defaultdict(list)
for r in rows: by[r['th']].append(r)
main = sorted(t for t, v in by.items() if len(v) > 1000)
N, T = leg['N'], leg['timed']
c = sorted(x['t_abs'] for x in leg['completions']); lo, hi = c[N - 1], c[N + T - 1]
acc = collections.defaultdict(list)
heads = []
for t in main:
    v = sorted((r for r in by[t] if not (r['tag'] == 'wprod' and 't=65' in r['det'])), key=lambda r: r['beg'])
    idx = [i for i, r in enumerate(v) if r['tag'] == 'wprod' and (i == 0 or v[i - 1]['tag'] != 'wprod')] + [len(v)]
    for a, b in zip(idx, idx[1:]):
        seg = v[a:b]
        wp = [r for r in seg if r['tag'] == 'wprod']
        after = [r for r in seg if r['beg'] > wp[-1]['dn']]
        if not after or not (lo <= wp[0]['beg'] <= hi): continue
        A = next(i for i, r in enumerate(after) if r['tag'] == 'commit' and 'rows=2504' in r['det'])
        h = after[:A + 1]
        heads.append(h[-1]['beg'] - h[0]['beg'])
        for j in range(len(h) - 1):
            acc[(j, h[j]['tag'], h[j]['det'].split(' log_n')[0].split(' nn')[0][:34])].append((h[j]['dn'] - h[j]['beg'], h[j + 1]['beg'] - h[j]['dn']))
print('arm %s: head mean %.1f ms over %d requests; rows (index, buffer, mean time begin..done ms, mean gap to the next buffer ms)' % (leg['arm'], 1e3 * st.mean(heads), len(heads)))
tb = tg = 0
for k in sorted(acc):
    b = 1e3 * st.mean(x[0] for x in acc[k]); g = 1e3 * st.mean(x[1] for x in acc[k]); tb += b; tg += g
    print('  %2d %-8s %-34s buffer %7.1f ms   gap after %7.1f ms   (n=%d)' % (k[0], k[1], k[2], b, g, len(acc[k])))
print('  sum buffers %.1f ms, sum gaps %.1f ms' % (tb, tg))

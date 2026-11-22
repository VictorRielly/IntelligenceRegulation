#!/usr/bin/env python3
"""Tick 39, second script: is the right-hand part of the tail (above the floor of about 125 ms) the A28 start stagger
(HL_A28_STAGGER_MS=300: no two requests start less than 300 ms apart, classify_serve.rs:238-366)?
Uses the first-wprod begin of every request as a proxy for its start (start + a fixed host set-up). Standard library only;
run as: python3 -I -B this.py <raw>. Reads the same three traces as the main script."""
import collections, json, lzma, os, statistics as st, sys
raw = sys.argv[1].rstrip('/')
def load(prefix, pid):
    f = '%s/traces/%s.%d.tsv.xz' % (raw, os.path.basename(prefix), pid)
    rows = []
    for i, line in enumerate(lzma.open(f, 'rt')):
        p = line.rstrip('\n').split('\t')
        if i == 0 or len(p) != 9: continue
        rows.append(dict(tag=p[0], det=p[1], th=int(p[2]), beg=float(p[4]), dn=float(p[8])))
    return rows
L = json.load(open(raw + '/cm_trace3/t2_results.json'))['legs']
for leg in L:
    rows = load(leg['trace_prefix'], leg['server_pid'])
    by = collections.defaultdict(list)
    for r in rows: by[r['th']].append(r)
    main = sorted(t for t, v in by.items() if len(v) > 1000)
    starts = []      # (first wprod begin, thread, tail_before or None)
    for t in main:
        v = sorted((r for r in by[t] if not (r['tag'] == 'wprod' and 't=65' in r['det'])), key=lambda r: r['beg'])
        idx = [i for i, r in enumerate(v) if r['tag'] == 'wprod' and (i == 0 or v[i - 1]['tag'] != 'wprod')]
        for j, i in enumerate(idx):
            tail = None
            if j > 0:
                tail = v[i]['beg'] - max(r['dn'] for r in v[idx[j - 1]:i] if r['tag'] != 'wprod' or True)
            starts.append((v[i]['beg'], t, tail))
    starts.sort()
    gaps = [b[0] - a[0] for a, b in zip(starts, starts[1:])]
    # per request with a tail: distance to the previous start of any thread
    pairs = []
    for k, (tw, t, tail) in enumerate(starts):
        if tail is None or k == 0: continue
        pairs.append((tw - starts[k - 1][0], tail))
    print('arm %s: %d request starts; gap to previous start (any lane): min %.3f, p5 %.3f, median %.3f; share under 0.30 s: %.1f%%, share in [0.30,0.36): %.1f%%' % (
        leg['arm'], len(starts), min(gaps), sorted(gaps)[int(.05 * len(gaps))], st.median(gaps), 100 * sum(g < .30 for g in gaps) / len(gaps), 100 * sum(.30 <= g < .36 for g in gaps) / len(gaps)))
    near = [t for d, t in pairs if d < 0.36]
    far = [t for d, t in pairs if d >= 0.36]
    print('   tail when the previous start (other lane) was < 0.36 s before: n=%d mean %.0f ms median %.0f ; otherwise n=%d mean %.0f ms median %.0f' % (
        len(near), 1e3 * st.mean(near) if near else float('nan'), 1e3 * st.median(near) if near else float('nan'), len(far), 1e3 * st.mean(far), 1e3 * st.median(far)))
    hi = [(d, t) for d, t in pairs if t > 0.2]
    print('   tails above 0.2 s: n=%d; their gap to the previous start: min %.3f max %.3f' % (len(hi), min(d for d, t in hi), max(d for d, t in hi)))

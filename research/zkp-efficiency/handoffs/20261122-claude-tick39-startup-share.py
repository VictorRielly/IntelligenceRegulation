#!/usr/bin/env python3
"""Tick 39, third script: the start-side share of the tail floor. For the six first-wave requests of each arm (they have no
preceding run), start = t_send_abs + queued_s (the server's own wait before it starts a request, the stagger included;
t_send_abs is when the driver wrote the stdin lines, so the read latency is inside the figure), and the figure printed is
first sealing buffer begin minus that start: set-up host work before the first wprod (directories, policy, tied-table check,
content slice, honest IN-C inputs, x_in load, block 0's witness set-up) PLUS the first-wave cold effects. Standard library only;
run as: python3 -I -B this.py <raw>."""
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
for leg in json.load(open(raw + '/cm_trace3/t2_results.json'))['legs']:
    rows = load(leg['trace_prefix'], leg['server_pid'])
    by = collections.defaultdict(list)
    for r in rows: by[r['th']].append(r)
    main = sorted(t for t, v in by.items() if len(v) > 1000)
    first = []
    for t in main:
        v = sorted((r for r in by[t] if not (r['tag'] == 'wprod' and 't=65' in r['det'])), key=lambda r: r['beg'])
        first.append(v[0]['beg'])
    first.sort()
    comp = sorted(leg['completions'], key=lambda x: x['n'])[:6]
    starts = sorted(leg['t_send_abs'] + c['queued_s'] for c in comp)
    d = [f - s for f, s in zip(first, starts)]
    print('arm %s: first sealing buffer minus start (six first-wave requests, s): %s ; mean %.3f median %.3f' % (leg['arm'], ' '.join('%.3f' % x for x in d), st.mean(d), st.median(d)))

"""Independent check of the traced stream legs (co-coordinator). Standard library; run with python3 -I -B <raw dir>.
Recomputes e, q, w, u per leg with code that shares nothing with trace_summary.py, and adds:
the union over ALL buffers, the share of the window with k buffers executing, and the device work per second
in solo units (leg 1's execution time per request as the unit)."""
import json
import lzma
import os
import sys

raw = sys.argv[1].rstrip('/')
legs = []
for name in ('tr_leg1', 'tr_main'):
    legs += json.load(open('%s/%s/t2_results.json' % (raw, name)))['legs']


def open_trace(prefix, pid):
    # the traces are kept beside this script as raw/traces/<name>.<pid>.tsv.xz (or .tsv where they were made)
    name = '%s/traces/%s.%d.tsv' % (raw, os.path.basename(prefix), pid)
    if os.path.exists(name):
        return open(name)
    return lzma.open(name + '.xz', 'rt')


def load(prefix, pid):
    rows = []
    with open_trace(prefix, pid) as f:
        head = f.readline().rstrip('\n').split('\t')
        ix = {h: i for i, h in enumerate(head)}
        for line in f:
            p = line.rstrip('\n').split('\t')
            if len(p) != len(head):
                continue
            rows.append((p[ix['tag']], p[ix['thread']], p[ix['queue']], float(p[ix['begin']]), float(p[ix['committed']]),
                         float(p[ix['gpu_start']]), float(p[ix['gpu_end']]), float(p[ix['done']])))
    return rows


def union_and_levels(iv, t0, t1):
    ev = []
    for a, b in iv:
        a = max(a, t0)
        b = min(b, t1)
        if b > a:
            ev.append((a, 1))
            ev.append((b, -1))
    ev.sort()
    lev = {}
    k = 0
    last = t0
    for t, d in ev:
        lev[k] = lev.get(k, 0.0) + (t - last)
        last = t
        k += d
    lev[k] = lev.get(k, 0.0) + (t1 - last)
    W = t1 - t0
    return 1 - lev.get(0, 0.0) / W, {j: v / W for j, v in sorted(lev.items())}


solo = None
for L in legs:
    N, T = L['N'], L['timed']
    c = sorted(L['completions'], key=lambda x: x['t_abs'])
    t0, t1 = c[N - 1]['t_abs'], c[N + T - 1]['t_abs']
    W = t1 - t0
    B = 26 * T
    rows = load(L['trace_prefix'], L['server_pid'])
    inw = [r for r in rows if t0 <= r[3] < t1]
    pr = [r for r in inw if r[0] != 'wprod']
    se = [r for r in inw if r[0] == 'wprod']
    e = sum(r[6] - r[5] for r in pr) / B * 1e3
    q = sum(r[5] - r[4] for r in pr) / B * 1e3
    w = sum(r[7] - r[6] for r in pr) / B * 1e3
    es = sum(r[6] - r[5] for r in se) / B * 1e3
    up, _ = union_and_levels([(r[5], r[6]) for r in pr], t0, t1)
    ua, lev = union_and_levels([(r[5], r[6]) for r in rows], t0, t1)
    rate = T * 128 / W
    timed = c[N:N + T]
    wall = sum(x['prove_s'] for x in timed) / len(timed) / 26 * 1e3
    if solo is None:
        solo = (e + es) * 26 / 1e3
    work = rate / 128 * solo
    hi = sum(v for k, v in lev.items() if k >= 3)
    print('leg %d %dx%d A36=%d %-6s rate %.2f wall %.1f | prover e %.1f q %.1f w %.1f u %.1f%% | sealing e %.1f | union ALL %.1f%%'
          % (L['leg'], L['lanes'], L['threads'], L['A36'], L['queues'], rate, wall, e, q, w, 100 * up, es, 100 * ua))
    print('      executing at once: none %.1f%%, one %.1f%%, two %.1f%%, three or more %.1f%% | device work %.3f solo-seconds per second (unit: leg 1, %.3f s a request) | while busy %.2f'
          % (100 * lev.get(0, 0), 100 * lev.get(1, 0), 100 * lev.get(2, 0), 100 * hi, work, solo, work / ua))

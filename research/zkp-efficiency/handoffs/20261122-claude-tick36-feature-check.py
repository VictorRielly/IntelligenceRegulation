import sys, json, lzma, os, bisect, collections, math
raw = sys.argv[1]
legs = []
for name in ('tr_leg1', 'tr_main'):
    legs += json.load(open('%s/%s/t2_results.json' % (raw, name)))['legs']
def load(L):
    name = '%s/traces/%s.%d.tsv.xz' % (raw, os.path.basename(L['trace_prefix']), L['server_pid'])
    rows = []
    with lzma.open(name, 'rt') as f:
        h = f.readline().rstrip('\n').split('\t')
        for line in f:
            p = line.rstrip('\n').split('\t')
            if len(p) != len(h): continue
            rows.append(dict(tag=p[0], det=p[1], th=int(p[2]), q=int(p[3]), beg=float(p[4]), com=float(p[5]), gs=float(p[6]), ge=float(p[7]), dn=float(p[8])))
    return rows
def key(r): return (r['tag'], r['det'] if r['tag'] == 'wprod' else r['det'][:60])
rows1 = load(legs[0])
solo = collections.defaultdict(list)
for r in rows1: solo[key(r)].append(r['ge'] - r['gs'])
solo = {k: sorted(v)[len(v)//2] for k, v in solo.items()}
tagm = collections.defaultdict(list)
for r in rows1: tagm[r['tag']].append(r['ge'] - r['gs'])
tagm = {k: sorted(v)[len(v)//2] for k, v in tagm.items()}
def st(r): return solo.get(key(r), tagm.get(r['tag'], r['ge'] - r['gs']))

def window(L, rows):
    c = sorted(x['t_abs'] for x in L['completions'])
    t0, t1 = c[L['N']-1], c[L['N']+L['timed']-1]
    return [r for r in rows if t0 <= r['beg'] < t1]

def features(L):
    rows = load(L)
    for r in rows: r['s'] = st(r); r['cls'] = 'S' if r['tag'] == 'wprod' else 'P'
    # sweep: sorted lists for executing/pending
    n = len(rows)
    gs = sorted((r['gs'], i) for i, r in enumerate(rows)); ge = sorted((r['ge'], i) for i, r in enumerate(rows)); cm = sorted((r['com'], i) for i, r in enumerate(rows))
    gsT = [x[0] for x in gs]; geT = [x[0] for x in ge]; cmT = [x[0] for x in cm]
    out = []
    W = window(L, rows)
    # to get sums of solo work over executing / pending sets cheaply, use prefix sums over sorted orders
    def pref(lst):
        p = [0.0]
        for t, i in lst: p.append(p[-1] + rows[i]['s'])
        return p
    pgs, pge, pcm = pref(gs), pref(ge), pref(cm)
    for r in W:
        t = r['com'] - 1e-7
        a, b, c = bisect.bisect_right(gsT, t), bisect.bisect_right(geT, t), bisect.bisect_right(cmT, t)
        e = a - b; p = c - a
        we = pgs[a] - pge[b]       # solo work of buffers executing (started, not ended)
        wp = pcm[c] - pgs[a]       # solo work committed not started
        out.append((r['cls'], e, p, we, wp, r['s'], r['gs'] - r['com']))
    return out

F = {i: features(legs[i]) for i in (1, 3, 4)}
def r2(pred, act):
    mu = sum(act)/len(act)
    return 1 - sum((p-a)**2 for p, a in zip(pred, act)) / sum((a-mu)**2 for a in act)
def fit(fn, data, min_n=30):
    bins = collections.defaultdict(list)
    for d in data: bins[fn(d)].append(d[6])
    return bins
def predictor(bins, fn, fb):
    mean = {k: sum(v)/len(v) for k, v in bins.items() if len(v) >= 30}
    def f(d):
        k = fn(d)
        while k not in mean:
            k = fb(k)
            if k is None: return None
        return mean[k]
    return f
def qb(x, edges):
    return bisect.bisect_right(edges, x)
# quantile edges of work from leg 2
def quant(vals, n):
    v = sorted(vals); return [v[int(len(v)*i/n)] for i in range(1, n)]
tot2 = [d[3]+d[4] for d in F[1]]
Q = quant(tot2, 10)
own = quant([d[5] for d in F[1]], 4)
QE = quant([x[3] for x in F[1]], 5)
QP = quant([x[4] for x in F[1] if x[4] > 0] or [0, 1], 4)
cands = {
 'e,p': (lambda d: (d[0], min(d[1],5), min(d[2],4)), None),
 'work (exec+pend), 10 quantile bins': (lambda d: (d[0], qb(d[3]+d[4], Q)), None),
 'work exec x work pend (5x4 quantile)': (lambda d: (d[0], qb(d[3], QE), qb(d[4], QP)), None),
 'e,p,own size (4 bins)': (lambda d: (d[0], min(d[1],5), min(d[2],4), qb(d[5], own)), None),
 'work 10 bins x own size': (lambda d: (d[0], qb(d[3]+d[4], Q), qb(d[5], own)), None),
}
for nm, (fn, _) in cands.items():
    bins = fit(fn, F[1])
    mean = {k: sum(v)/len(v) for k, v in bins.items() if len(v) >= 30}
    for lg in (1, 3, 4):
        pr, ac = [], []
        for d in F[lg]:
            k = fn(d)
            if k in mean and d[0] == 'P':
                pr.append(mean[k]); ac.append(d[6])
        cover = len(pr) / sum(1 for d in F[lg] if d[0] == 'P')
        print('%-40s leg %d: R2 %.3f  mean pred %.2f vs actual %.2f ms (ratio %.2f), coverage %.2f' % (nm, lg+1, r2(pr, ac), 1e3*sum(pr)/len(pr), 1e3*sum(ac)/len(ac), sum(pr)/sum(ac), cover))

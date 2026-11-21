"""Tick 34 (queue item 56): the empty device at full lanes, from the five traced stream legs.
Standard library only; run as: python3 -I -B this.py <results/zk60_lanes_trace_20261121/raw>
Reads raw/traces/*.tsv.xz and raw/*/t2_results.json (window rule and union rule as in the co-coordinator's trace_check.py:
buffers with host BEGIN inside [completion N, completion N+timed], execution intervals gpu_start..gpu_end clipped to the window).
Prints (a) empty-stretch statistics, (b) lane positions around the long stretches, (c) work rate by buffers-executing level."""
import bisect
import collections
import json
import lzma
import os
import re
import sys

raw = sys.argv[1].rstrip('/')
legs = []
for name in ('tr_leg1', 'tr_main'):
    legs += json.load(open('%s/%s/t2_results.json' % (raw, name)))['legs']


def load(prefix, pid):
    name = '%s/traces/%s.%d.tsv.xz' % (raw, os.path.basename(prefix), pid)
    rows = []
    with lzma.open(name, 'rt') as f:
        head = f.readline().rstrip('\n').split('\t')
        ix = {h: i for i, h in enumerate(head)}
        for line in f:
            p = line.rstrip('\n').split('\t')
            if len(p) != len(head):
                continue
            rows.append(dict(tag=p[ix['tag']], det=p[ix['detail']], th=int(p[ix['thread']]), q=int(p[ix['queue']]),
                             beg=float(p[ix['begin']]), com=float(p[ix['committed']]), gs=float(p[ix['gpu_start']]),
                             ge=float(p[ix['gpu_end']]), dn=float(p[ix['done']])))
    return rows


def label(r):
    """Short phase label: the slot number, or gather/commit with its row count, or wprod."""
    if r['tag'] == 'batch':
        m = re.match(r'slot (\d+)', r['det'])
        return 'slot%02d' % int(m.group(1)) if m else 'batch?'
    if r['tag'] in ('gather', 'commit'):
        m = re.match(r'rows=(\d+)', r['det'])
        return '%s%s' % (r['tag'], m.group(1)) if m else r['tag']
    return r['tag']


def key(r):
    """Unit key for the solo time: tag plus the first 60 characters of the detail (wprod: the whole detail)."""
    return (r['tag'], r['det'] if r['tag'] == 'wprod' else r['det'][:60])


def window(L, rows):
    N, T = L['N'], L['timed']
    c = sorted(L['completions'], key=lambda x: x['t_abs'])
    t0, t1 = c[N - 1]['t_abs'], c[N + T - 1]['t_abs']
    return t0, t1, [r for r in rows if t0 <= r['beg'] < t1]


def merge(iv, t0, t1):
    iv = sorted((max(a, t0), min(b, t1)) for a, b in iv if min(b, t1) > max(a, t0))
    out = []
    for a, b in iv:
        if out and a <= out[-1][1]:
            out[-1][1] = max(out[-1][1], b)
        else:
            out.append([a, b])
    return out


def pct(xs, p):
    xs = sorted(xs)
    return xs[min(len(xs) - 1, int(p * len(xs)))] if xs else float('nan')


data = {}
for L in legs:
    rows = load(L['trace_prefix'], L['server_pid'])
    t0, t1, inw = window(L, rows)
    data[L['leg']] = (L, rows, t0, t1, inw)

# ---- solo unit times from leg 1
L1, rows1, t01, t11, in1 = data[1]
solo = collections.defaultdict(list)
for r in in1:
    solo[key(r)].append(r['ge'] - r['gs'])
solo_med = {k: sorted(v)[len(v) // 2] for k, v in solo.items()}
tag_med = collections.defaultdict(list)
for r in in1:
    tag_med[r['tag']].append(r['ge'] - r['gs'])
tag_med = {k: sorted(v)[len(v) // 2] for k, v in tag_med.items()}


def solo_t(r):
    return solo_med.get(key(r), tag_med.get(r['tag'], r['ge'] - r['gs']))


print('solo keys from leg 1: %d (unit time = leg-1 median execution of each buffer key)' % len(solo_med))

for leg in (2, 5, 4, 3, 1):
    L, rows, t0, t1, inw = data[leg]
    W = t1 - t0
    allr = inw
    pr = [r for r in inw if r['tag'] != 'wprod']
    mer = merge([(r['gs'], r['ge']) for r in allr], t0, t1)
    # gaps inside the window, including the two edges
    gaps = []
    cur = t0
    for a, b in mer:
        if a > cur:
            gaps.append((cur, a))
        cur = b
    if cur < t1:
        gaps.append((cur, t1))
    lens = [(b - a) * 1e3 for a, b in gaps]
    emp = sum(lens)
    print('\n=== leg %d: %dx%d A36=%d %s; window %.2f s; empty %.1f%% (%d stretches) ===' % (
        leg, L['lanes'], L['threads'], L['A36'], L['queues'], W, 100 * emp / (W * 1e3), len(lens)))
    print('(a) stretch length ms: median %.2f, p90 %.2f, p99 %.2f, max %.1f; mean %.2f' % (
        pct(lens, .5), pct(lens, .9), pct(lens, .99), max(lens), emp / len(lens)))
    for th in (1, 2, 5, 10, 20, 50, 100):
        sel = [x for x in lens if x > th]
        print('    stretches > %3d ms: %5d, holding %.1f%% of the empty time = %.1f%% of the window' % (
            th, len(sel), 100 * sum(sel) / emp, 100 * sum(sel) / (W * 1e3)))

    # (b) lane positions around stretches over a threshold; lanes = prover queues
    pq = sorted({r['q'] for r in pr})
    byq = {q: sorted([r for r in pr if r['q'] == q], key=lambda r: r['gs']) for q in pq}
    startsq = {q: [r['gs'] for r in byq[q]] for q in pq}
    endsq = {q: [r['ge'] for r in byq[q]] for q in pq}
    allsorted_s = sorted(allr, key=lambda r: r['gs'])
    allsorted_e = sorted(allr, key=lambda r: r['ge'])
    for thr in (20, 5):
        stretches = [(a, b) for a, b in gaps if (b - a) * 1e3 > thr and a > t0 and b < t1]
        if not stretches:
            continue
        glast = collections.Counter()
        gfirst = collections.Counter()
        trans = collections.Counter()
        lastc = collections.Counter()
        nextc = collections.Counter()
        waitbefore = []
        waitafter = []
        hostgap = []
        nlanes_wait = []  # lanes with a prover buffer already committed (queued) when the stretch ends
        for a, b in stretches:
            # global last buffer ending at or before a, first starting at or after b
            i = bisect.bisect_right([r['ge'] for r in allsorted_e], a + 1e-9) - 1
            j = bisect.bisect_left([r['gs'] for r in allsorted_s], b - 1e-9)
            if i >= 0:
                glast[label(allsorted_e[i])] += 1
            if j < len(allsorted_s):
                gfirst[label(allsorted_s[j])] += 1
            qw = 0
            for q in pq:
                ie = bisect.bisect_right(endsq[q], a + 1e-9) - 1
                js = bisect.bisect_left(startsq[q], b - 1e-9)
                if ie < 0 or js >= len(byq[q]):
                    continue
                lr, nr = byq[q][ie], byq[q][js]
                lastc[label(lr)] += 1
                nextc[label(nr)] += 1
                trans[(label(lr), label(nr))] += 1
                waitbefore.append((a - lr['ge']) * 1e3)
                waitafter.append((nr['gs'] - b) * 1e3)
                hostgap.append((nr['beg'] - lr['dn']) * 1e3)
                if nr['beg'] < a:
                    qw += 1
            nlanes_wait.append(qw)
        n = len(stretches)
        print('(b) stretches > %d ms: %d; prover lanes = %d queues' % (thr, n, len(pq)))
        print('    global last buffer before (any queue): ' + ', '.join('%s %d' % kv for kv in glast.most_common(8)))
        print('    global first buffer after (any queue): ' + ', '.join('%s %d' % kv for kv in gfirst.most_common(8)))
        print('    per-lane last prover buffer before  : ' + ', '.join('%s %d' % kv for kv in lastc.most_common(10)))
        print('    per-lane next prover buffer after   : ' + ', '.join('%s %d' % kv for kv in nextc.most_common(10)))
        print('    per-lane (last -> next) pairs       : ' + ', '.join('%s>%s %d' % (k[0], k[1], v) for k, v in trans.most_common(8)))
        print('    lane idle before stretch start, ms: median %.1f p90 %.1f; lane first start after stretch end, ms: median %.1f p90 %.1f'
              % (pct(waitbefore, .5), pct(waitbefore, .9), pct(waitafter, .5), pct(waitafter, .9)))
        print('    lane host gap (next.begin - last.done), ms: median %.1f p10 %.1f p90 %.1f' % (pct(hostgap, .5), pct(hostgap, .1), pct(hostgap, .9)))
        print('    lanes whose next buffer was already encoded before the stretch began: mean %.2f of %d' % (sum(nlanes_wait) / n, len(pq)))

    # (b2) lane states during empty time. A prover lane (queue) is IN a buffer from begin to done, else in the host gap
    # between consecutive buffers (state = last label > next label; a gap over 500 ms is the sealing pass / request boundary).
    if leg in (2, 5, 3):
        def lane_states(q):
            seq = byq_b[q]
            st = []
            for x, y in zip(seq, seq[1:]):
                st.append((x['beg'], x['dn'], 'in ' + label(x)))
                g = y['beg'] - x['dn']
                if g > 0:
                    st.append((x['dn'], y['beg'], 'SEAL/BOUNDARY gap' if g > 0.5 else 'gap %s>%s' % (label(x), label(y))))
            return st
        byq_b = {q: sorted([r for r in pr if r['q'] == q], key=lambda r: r['beg']) for q in pq}
        states = {q: lane_states(q) for q in pq}
        starts = {q: [s[0] for s in states[q]] for q in pq}
        emp_time = collections.defaultdict(float)
        all_time = collections.defaultdict(float)
        for q in pq:
            for a, b, nm in states[q]:
                a, b = max(a, t0), min(b, t1)
                if b > a:
                    all_time[nm] += b - a
        for a, b in gaps:
            for q in pq:
                i = max(0, bisect.bisect_right(starts[q], a) - 1)
                while i < len(states[q]) and states[q][i][0] < b:
                    sa, sb, nm = states[q][i]
                    ov = min(sb, b) - max(sa, a)
                    if ov > 0:
                        emp_time[nm] += ov
                    i += 1
        te = sum(emp_time.values())
        ta = sum(all_time.values())
        print('(b2) lane states (prover queues) during the empty time vs over the whole window; ratio = share in empty time / share overall')
        rowsb = sorted(emp_time.items(), key=lambda kv: -kv[1])[:14]
        for nm, v in rowsb:
            print('      %-38s %5.1f%% of lane-time in empty stretches, %5.1f%% overall, ratio %.2f' % (nm, 100 * v / te, 100 * all_time[nm] / ta, (v / te) / (all_time[nm] / ta)))
        # how many lanes are in the same host-gap state at a stretch's midpoint (bunching)
        modal = []
        for a, b in gaps:
            if (b - a) * 1e3 <= 5:
                continue
            m = 0.5 * (a + b)
            c = collections.Counter()
            for q in pq:
                i = max(0, bisect.bisect_right(starts[q], m) - 1)
                c[states[q][i][2]] += 1
            modal.append(c.most_common(1)[0][1])
        print('     stretches over 5 ms: at the midpoint the most common lane state holds on average %.2f of %d lanes' % (sum(modal) / len(modal), len(pq)))
        pin = [sum(sb - sa for sa, sb, nm in states[q] if nm.startswith('in ')) for q in pq]
        print('     fraction of the window a lane has a buffer in flight (begin to done): ' + ', '.join('%.2f' % (x / W) for x in pin)
              + '; independent-lanes empty share (1-p)^n product = %.1f%%' % (100 * __import__('math').prod(1 - x / W for x in pin)))

    # (c) work rate by level: each buffer progresses at solo/dur; level = number of buffers executing
    ev = []
    for r in allr:
        a, b = max(r['gs'], t0), min(r['ge'], t1)
        if b > a:
            w = solo_t(r) / (r['ge'] - r['gs'])
            wp = 0.0 if r['tag'] == 'wprod' else w
            ev.append((a, 1, w, wp))
            ev.append((b, -1, w, wp))
    ev.sort(key=lambda x: (x[0], x[1]))
    lvl = 0
    rate = 0.0
    ratep = 0.0
    last = t0
    tl = collections.defaultdict(float)
    wk = collections.defaultdict(float)
    wkp = collections.defaultdict(float)
    for t, d, w, wp in ev:
        k = min(lvl, 4)
        tl[k] += t - last
        wk[k] += rate * (t - last)
        wkp[k] += ratep * (t - last)
        last = t
        lvl += d
        rate += d * w
        ratep += d * wp
    tl[min(lvl, 4)] += t1 - last
    tot_w = sum(wk.values())
    print('(c) level (buffers executing, all queues): time share | work rate, all buffers | work rate, prover buffers only | share of all work')
    for k in range(0, 5):
        if tl[k] > 0:
            print('    %s%d: %5.1f%% | %.3f | %.3f | %5.1f%%' % ('>=' if k == 4 else '  ', k, 100 * tl[k] / W, wk[k] / tl[k] if k else 0.0, wkp[k] / tl[k] if k else 0.0, 100 * wk[k] / tot_w))
    print('    whole window: %.3f solo-s of work per s (work = leg-1 median time of each buffer key); per busy second %.3f; prover buffers only %.3f per busy second'
          % (tot_w / W, tot_w / (W - tl[0]), sum(wkp.values()) / (W - tl[0])))
    # mean stretch factor of a buffer by the time-weighted mean level it ran at (prover and sealing separately)
    # level at each moment from the merged event list; buffer's mean level = integral of level over its interval / dur
    # step function: level after event i is pts[i+1] value; build breakpoints
    bt = [e[0] for e in ev]
    lvls = []
    lv = 0
    for e in ev:
        lv += e[1]
        lvls.append(lv)
    cum = [0.0]
    for i in range(len(bt) - 1):
        cum.append(cum[-1] + lvls[i] * (bt[i + 1] - bt[i]))

    def integ(x):
        i = bisect.bisect_right(bt, x) - 1
        if i < 0:
            return 0.0
        return cum[i] + lvls[i] * (x - bt[i])

    bins = collections.defaultdict(lambda: [0, 0.0, 0.0])
    for r in allr:
        a, b = max(r['gs'], t0), min(r['ge'], t1)
        if b - a < (r['ge'] - r['gs']) - 1e-12:
            continue
        ml = (integ(b) - integ(a)) / (b - a)
        k = min(int(round(ml)), 4) if ml >= 1 else 1
        s = solo_t(r)
        bins[(r['tag'] == 'wprod', k)][0] += 1
        bins[(r['tag'] == 'wprod', k)][1] += (r['ge'] - r['gs'])
        bins[(r['tag'] == 'wprod', k)][2] += s
    print('    buffer duration / its leg-1 solo time, by its mean level (rounded):')
    for (sealing, k), (n, d, s) in sorted(bins.items()):
        if n > 50:
            print('      %s level %s%d: n=%d, mean duration %.2f x solo' % ('sealing' if sealing else 'prover ', '>=' if k == 4 else ' ', k, n, d / s))

# ---- (b3) host gap per lane transition (done of one prover buffer to begin of the lane's next), median ms, legs 1, 2, 5
print('\n=== (b3) median host gap per lane transition, ms (leg 1 | leg 2 | leg 5) and the sum over the seven gaps of a block ===')
med = {}
for leg in (1, 2, 5):
    L, rows, t0, t1, inw = data[leg]
    pr = [r for r in rows if r['tag'] != 'wprod' and t0 <= r['beg'] < t1]
    per = collections.defaultdict(list)
    for q in {r['q'] for r in pr}:
        seq = sorted([r for r in pr if r['q'] == q], key=lambda r: r['beg'])
        for x, y in zip(seq, seq[1:]):
            per[(label(x), label(y))].append((y['beg'] - x['dn']) * 1e3)
    med[leg] = {k: sorted(v)[len(v) // 2] for k, v in per.items() if len(v) >= 30}
chain = [('slot22', 'gather2504'), ('gather2504', 'gather2606'), ('gather2606', 'gather38'), ('gather38', 'commit38'),
         ('commit38', 'commit2504'), ('commit2504', 'commit2606'), ('commit2606', 'slot00'), ('slot00', 'slot01'), ('slot01', 'slot03'),
         ('slot03', 'slot04'), ('slot04', 'slot14'), ('slot14', 'slot15'), ('slot15', 'slot16'), ('slot16', 'slot17'), ('slot17', 'slot18'),
         ('slot18', 'slot19'), ('slot19', 'slot21'), ('slot21', 'slot22')]
tot = [0.0, 0.0, 0.0]
for k in chain:
    v = [med[l].get(k, float('nan')) for l in (1, 2, 5)]
    print('  %-12s > %-12s %7.1f | %7.1f | %7.1f' % (k[0], k[1], v[0], v[1], v[2]))
    for i in range(3):
        tot[i] += v[i]
print('  sum of the 18 gaps in one block: %.1f | %.1f | %.1f ms' % tuple(tot))

# ---- (b4) bunching test: lanes with a prover buffer in flight (begin to done), sampled every 1 ms, against independent lanes
print('\n=== (b4) number of prover lanes with a buffer in flight, sampled every 1 ms (legs 2 and 5) ===')
for leg in (2, 5):
    L, rows, t0, t1, inw = data[leg]
    pr = [r for r in rows if r['tag'] != 'wprod']
    qs = sorted({r['q'] for r in pr})
    n = len(qs)
    step = 0.001
    ns = int((t1 - t0) / step)
    cnt = [0] * ns
    ps = []
    for q in qs:
        iv = merge([(r['beg'], r['dn']) for r in pr if r['q'] == q], t0, t1)
        p = sum(b - a for a, b in iv) / (t1 - t0)
        ps.append(p)
        for a, b in iv:
            for i in range(int((a - t0) / step), min(ns, int((b - t0) / step) + 1)):
                cnt[i] += 1
    mean = sum(cnt) / ns
    var = sum((c - mean) ** 2 for c in cnt) / ns
    varind = sum(p * (1 - p) for p in ps)
    hist = collections.Counter(cnt)
    print('leg %d: lanes %d, mean in flight %.2f, variance %.2f against %.2f if independent (ratio %.2f); P(none in flight) %.1f%%, independent %.1f%%'
          % (leg, n, mean, var, varind, var / varind, 100 * hist[0] / ns, 100 * __import__('math').prod(1 - p for p in ps)))
    print('   histogram (lanes in flight: share of time): ' + ', '.join('%d: %.1f%%' % (k, 100 * hist[k] / ns) for k in sorted(hist)))

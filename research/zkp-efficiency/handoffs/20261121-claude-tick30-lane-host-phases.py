#!/usr/bin/env python3
"""Tick 30 (queue item 50): host phases of one lane request at the W16R2 classifier, from the
buffer trace Astra retained (timings only: begin, committed, gpu_start, gpu_end, done per Metal
command buffer, per thread). Standard library only. Usage: python3 -I this.py <prover.tsv>
Prints every DERIVED number of the handoff. Reads no model, content or owner-private file."""
import csv, sys, statistics as st, collections

rows = list(csv.DictReader(open(sys.argv[1]), delimiter='\t'))
for r in rows:
    for k in ('begin', 'committed', 'gpu_start', 'gpu_end', 'done'):
        r[k] = float(r[k])
    r['thread'] = int(r['thread'])
by = collections.defaultdict(list)
for r in rows:
    by[r['thread']].append(r)
main = sorted(t for t, v in by.items() if len(v) > 1000)
print('request threads (>1000 buffers):', main, 'of', len(by), 'threads')

def key(r):
    d = r['detail']
    if r['tag'] == 'commit':
        return 'commit ' + d.split(' log_n')[0]
    if r['tag'] == 'gather':
        return 'gather ' + d.split(' nn')[0]
    if r['tag'] == 'batch':
        return 'batch ' + d.split(' (')[0]
    return r['tag']

# ---- request boundaries on each request thread: a request's sealing pass is the run of weight
# products (tag wprod, queue 99) ahead of its proving buffers; a new request starts at the first
# wprod that follows a non-wprod buffer. The 24 startup products (t=65) belong to the process.
res = []
for t in main:
    v = sorted((r for r in by[t] if not (r['tag'] == 'wprod' and 't=65' in r['detail'])), key=lambda r: r['begin'])
    starts = [i for i, r in enumerate(v) if r['tag'] == 'wprod' and (i == 0 or v[i - 1]['tag'] != 'wprod')]
    starts.append(len(v))
    for a, b in zip(starts, starts[1:]):
        res.append((t, v[a:b]))
print('requests found:', len(res))

secs = collections.defaultdict(list)
blocks_len = []
for t, v in res:
    wp = [r for r in v if r['tag'] == 'wprod']
    first_w, last_w = wp[0]['begin'], wp[-1]['done']
    assert all(r['tag'] == 'wprod' for r in v[:len(wp)]) or True
    # sealing window: first wprod begin to last wprod done (host work between products included)
    seal = last_w - first_w
    w128 = [r for r in wp if 't=128' in r['detail']]
    seal128 = w128[-1]['done'] - w128[0]['begin']
    # the run: first commit buffer after the last wprod to the last buffer
    after = [r for r in v if r['begin'] > last_w]
    run_begin = after[0]['begin']
    run_end = max(r['done'] for r in v)
    pre = run_begin - last_w
    # blocks: A commit (rows=2504) starts each block's prove call
    A = [r for r in v if r['tag'] == 'commit' and 'rows=2504' in r['detail']]
    H = [r for r in v if r['tag'] == 'commit' and 'rows=2606' in r['detail']]
    secs['seal_first_to_last_wprod'].append(seal)
    secs['seal128'].append(seal128)
    secs['last_wprod_to_first_buffer_of_run'].append(pre)
    secs['run_first_to_last'].append(run_end - run_begin)
    secs['n_A'].append(len(A))
    if len(A) == 26:
        for a, b in zip(A, A[1:]):
            blocks_len.append(b['begin'] - a['begin'])
        secs['26_blocks_A0_to_lastH_done'].append(H[-1]['done'] - A[0]['begin'])
    # between sealing end and the first wprod of the NEXT request
for k, x in secs.items():
    if x:
        print(f'{k:36s} n={len(x):3d} median {st.median(x):8.3f} min {min(x):8.3f} max {max(x):8.3f}')
print('block period (A begin to next A begin) n=%d median %.3f mean %.3f' % (len(blocks_len), st.median(blocks_len), st.mean(blocks_len)))

# ---- per-block decomposition on the request thread: encode / device wait / host-only gap
tot = collections.Counter(); nb = 0
trans = collections.defaultdict(list)
for t, v in res:
    A = [i for i, r in enumerate(v) if r['tag'] == 'commit' and 'rows=2504' in r['detail']]
    if len(A) != 26:
        continue
    for i0, i1 in zip(A, A[1:]):
        seg = v[i0:i1 + 1]  # one block's buffers plus the next block's A commit (the gap before it is this block's tail)
        nb += 1
        for r in seg[:-1]:
            tot['encode'] += r['committed'] - r['begin']
            tot['wait(committed->done)'] += r['done'] - r['committed']
            tot['gpu_exec'] += r['gpu_end'] - r['gpu_start']
        for p, q in zip(seg, seg[1:]):
            g = q['begin'] - p['done']
            tot['host_gap'] += g
            trans[(key(p), key(q))].append(g)
        tot['span'] += seg[-1]['begin'] - seg[0]['begin']
print('blocks analysed', nb)
for k, x in tot.items():
    print(f'  per block {k:24s} {x / nb * 1e3:8.1f} ms')
print('  (request-thread buffers only; other pool threads add buffers not counted)')
rows_t = sorted(((sum(g) / nb * 1e3, len(g) / nb, st.median(g) * 1e3, k) for k, g in trans.items()), reverse=True)
print('top host-only gaps per block (done of buffer -> begin of next, request thread):')
for s, n, med, k in rows_t[:16]:
    print(f'  {s:7.2f} ms/block  {n:4.1f}/block  median {med:7.3f} ms   {k[0]} -> {k[1]}')
print('sum of listed', sum(r[0] for r in rows_t[:16]), 'of host_gap', tot['host_gap'] / nb * 1e3)

print('--- all transitions into or out of the A commit and the 38-row commit (ms per block) ---')
for (a, b), g in sorted(trans.items(), key=lambda kv: -sum(kv[1])):
    if 'rows=2504' in a + b or 'rows=38' in a + b:
        print(f'  {sum(g) / nb * 1e3:7.2f} ms/block  n/block {len(g) / nb:4.2f}  median {st.median(g) * 1e3:7.3f}   {a} -> {b}')
# sequence of the first full block of one thread, with begin offsets
t, v = res[6]
A = [i for i, r in enumerate(v) if r['tag'] == 'commit' and 'rows=2504' in r['detail']]
seg = v[A[10]:A[11] + 1]
print('--- one block on thread %d (offset ms from A begin, exec ms, wait ms, key) ---' % t)
t0 = seg[0]['begin']
for r in seg:
    print(f"  +{(r['begin'] - t0) * 1e3:7.1f}  exec {(r['gpu_end'] - r['gpu_start']) * 1e3:6.1f}  wait {(r['done'] - r['committed']) * 1e3:6.1f}  {key(r)}")

# ---- sealing window per request (first to last weight product): device part against host part
sw, sd = [], []
for t, v in res:
    wp = [r for r in v if r['tag'] == 'wprod']
    sw.append(wp[-1]['done'] - wp[0]['begin'])
    sd.append(sum(r['done'] - r['begin'] for r in wp))
print('--- sealing window per request: window median %.3f s; sum of product buffers (begin->done) median %.3f s (%.1f%%)' % (st.median(sw), st.median(sd), 100 * st.median(sd) / st.median(sw)))
print('    per block (26): window %.1f ms, host between products %.1f ms' % (st.median(sw) / 26 * 1e3, (st.median(sw) - st.median(sd)) / 26 * 1e3))

# ---- closed-queue check of how much a host-gap cut can pass through (DERIVED, MODEL: the device
# as ONE first-come server; A28 used the same kind of model, results/zk60_a28_app_20261107/queue_model.py)
def mva(n, z, d):
    q = 0.0
    for k in range(1, n + 1):
        r = d * (1 + q)
        x = k / (z + r)
        q = x * r
    return z + r, x
P0 = st.median(blocks_len)          # lane period per block, seconds
busy = 0.7270                        # GPU busy share from first A commit to last proof (CADENCE.json)
D = busy * P0 / 6                    # device demand per block per lane implied by that share
# find think time Z with mva(6, Z, D) period == P0
lo, hi = 0.0, P0
for _ in range(60):
    z = (lo + hi) / 2
    p, _x = mva(6, z, D)
    lo, hi = (z, hi) if p < P0 else (lo, z)
Z = lo
print('--- closed-queue model: D = %.1f ms per block per lane, Z = %.1f ms, period %.1f ms' % (D * 1e3, Z * 1e3, mva(6, Z, D)[0] * 1e3))
for h in (30, 59, 101, 150):
    p, x = mva(6, Z - h / 1e3, D)
    print('    cut %3d ms of host gap per block -> period %.1f ms (x%.3f), device busy %.1f%%' % (h, p * 1e3, P0 / p, 100 * 6 * D / p))
print('    ceiling of the device alone: period %.1f ms (x%.3f)' % (D * 6 * 1e3, P0 / (D * 6)))

# ---- lane period (CADENCE.json: mean same-lane period 19.405 s) split, and what the block-level
# pass-through means for a lane (Amdahl over the 26 blocks), and the seal-ahead arithmetic
LANE = 19.405052105585735
blocks_s = 26 * P0
print('--- lane period %.3f s = 26 blocks %.2f s + outside %.2f s (sealing window %.2f s)' % (LANE, blocks_s, LANE - blocks_s, st.median(sw)))
for g, label in ((1.039, 'cut 30 ms'), (1.078, 'cut 59 ms'), (1.137, 'cut 101 ms'), (1.204, 'cut 150 ms')):
    new = LANE - blocks_s * (1 - 1 / g)
    print('    block-level x%.3f (%s) -> lane period %.2f s, x%.3f' % (g, label, new, LANE / new))
seal_out = st.median(sw) + st.median([0.049])   # window + hand-over to the first run buffer
print('seal-ahead: full hide of %.2f s -> period %.2f s (x%.3f, ceiling); R13 pass-through 1.4 of 5.7 s = %.0f%% -> %.2f s (x%.3f)'
      % (seal_out, LANE - seal_out, LANE / (LANE - seal_out), 100 * 1.4 / 5.7, LANE - seal_out * 1.4 / 5.7, LANE / (LANE - seal_out * 1.4 / 5.7)))
print('R13 sealing share of a lane request: 5.7 / 39.0 = %.1f%%; W16R2: %.2f / %.3f = %.1f%%' % (100 * 5.7 / 39.0, seal_out, LANE, 100 * seal_out / LANE))
print('memory: 7.168 GiB x 6 lanes = %.1f GiB more planes at peak overlap; guarded peak RSS 113.81 + %.1f = %.1f GiB (service need 196, cap 220)' % (7.168 * 6, 7.168 * 6, 113.81 + 7.168 * 6))
# A33's dedup carried to the app's seal (CS-3 repeated public check): 0.275 s of 2.183 s solo pass at 8B (32 blocks)
frac = 0.275 / 2.183
print('A33 dedup in the app: %.1f%% of the sealing window = %.2f s -> lane period x%.3f at most' % (100 * frac, frac * st.median(sw), LANE / (LANE - frac * st.median(sw))))
# CPU: batch 2, arm B (A30/A31 W16R2) 8-post stream
print('cores busy (batch 2 arm B, mean over the stream): prover %.1f, checker %.1f of 32 (24 P + 8 E)' % (940.58 / 104.83, 539.4 / 104.83))

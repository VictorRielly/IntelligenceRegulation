#!/usr/bin/env python3
"""Lane A27: summarize an `HL_A27_GPU_TRACE` file (one line per completed Metal command buffer).

Per call-site tag and per slot label (the generated kernel's first comment line): command buffers,
summed GPU time (GPUEndTime - GPUStartTime), mean, the wait from commit to the GPU's start, and the
host's encode time. Over the trace's window (or `--window a:b` host seconds): the time at least one
command buffer was executing (busy), the idle gaps, how many ran at once, and the summed GPU time
divided by `--proofs` (GPU seconds per category proof).

Note: a command buffer's GPU span includes time it shared the GPU with other queues' command
buffers, so under concurrency the summed spans exceed the busy time (the "mean at once" column).

usage: trace_report.py TRACE.tsv [--proofs N] [--window a:b] [--top 40]
"""
import argparse
import collections
import re
import sys


def load(path):
    rows = []
    with open(path) as f:
        for line in f:
            if line.startswith('tag\t'):
                continue
            p = line.rstrip('\n').split('\t')
            if len(p) != 9:
                continue
            tag, detail = p[0], p[1]
            th, q = int(p[2]), int(p[3])
            begin, committed, gs, ge, done = (float(x) for x in p[4:9])
            rows.append(dict(tag=tag, detail=detail, thread=th, queue=q, begin=begin, committed=committed, gs=gs, ge=ge, done=done))
    return rows


def slot_of(detail):
    m = re.match(r'slot (\d+) \(([^)]*\)?)[^|]*', detail)
    if not m:
        return None
    return f'slot {m.group(1)} ({m.group(2)})'


def kv(detail):
    return dict(re.findall(r'(\w+)=([\w.]+)', detail))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('trace')
    ap.add_argument('--proofs', type=float, default=1.0)
    ap.add_argument('--window', default=None)
    ap.add_argument('--top', type=int, default=40)
    a = ap.parse_args()
    rows = [r for r in load(a.trace) if r['gs'] > 0 and r['ge'] >= r['gs']]
    if not rows:
        print('no command buffers')
        return
    if a.window:
        w0, w1 = (float(x) for x in a.window.split(':'))
    else:
        w0, w1 = min(r['gs'] for r in rows), max(r['ge'] for r in rows)
    rows = [r for r in rows if r['ge'] > w0 and r['gs'] < w1]
    wall = w1 - w0
    # busy / concurrency sweep
    ev = []
    for r in rows:
        ev.append((max(r['gs'], w0), 1))
        ev.append((min(r['ge'], w1), -1))
    ev.sort(key=lambda e: (e[0], -e[1]))
    depth, last, busy = 0, w0, 0.0
    at = collections.Counter()
    gaps = []
    for t, d in ev:
        dt = t - last
        if depth == 0:
            if dt > 0:
                gaps.append(dt)
        else:
            busy += dt
        at[min(depth, 8)] += dt
        depth += d
        last = t
    if w1 > last:
        gaps.append(w1 - last)
        at[0] += w1 - last
    sum_gpu = sum(min(r['ge'], w1) - max(r['gs'], w0) for r in rows)
    print(f'window {wall:.3f} s; {len(rows)} command buffers; GPU busy {busy:.3f} s ({100 * busy / wall:.1f}%); '
          f'summed GPU spans {sum_gpu:.3f} s (mean {sum_gpu / max(busy, 1e-9):.2f} at once while busy); '
          f'per proof (/{a.proofs:g}): busy {busy / a.proofs:.3f} s, summed spans {sum_gpu / a.proofs:.3f} s')
    print('time at k executing: ' + ', '.join(f'{k}: {at[k]:.3f}' for k in range(9)))
    edges = [0, 20e-6, 50e-6, 200e-6, 1e-3, 5e-3, 1e9]
    names = ['<20us', '20-50us', '50-200us', '0.2-1ms', '1-5ms', '>=5ms']
    hist = []
    for i in range(6):
        g = [x for x in gaps if edges[i] <= x < edges[i + 1]]
        hist.append(f'{names[i]} {len(g)} ({sum(g):.3f} s)')
    print(f'idle gaps {len(gaps)} totalling {sum(gaps):.3f} s: ' + ', '.join(hist))
    # per tag
    print('\nper tag: cbs, GPU s (per proof), mean ms, commit->start s, host encode s, done-gpu_end s')
    tags = collections.defaultdict(list)
    for r in rows:
        tags[r['tag']].append(r)
    for t, v in sorted(tags.items(), key=lambda kv_: -sum(r['ge'] - r['gs'] for r in kv_[1])):
        g = sum(r['ge'] - r['gs'] for r in v)
        qd = sum(max(0.0, r['gs'] - r['committed']) for r in v)
        en = sum(max(0.0, r['committed'] - r['begin']) for r in v)
        sd = sum(max(0.0, r['done'] - r['ge']) for r in v)
        print(f'  {t:<8} {len(v):>7} {g:9.3f} ({g / a.proofs:7.3f}) {1e3 * g / len(v):8.3f}  {qd:8.3f} {en:8.3f} {sd:8.3f}')
    # per slot (batch + round + fold + tables of that slot)
    print('\nper slot label (batch/round/fold/tables): cbs, GPU s per proof, share of all GPU span; shapes')
    slots = collections.defaultdict(list)
    for r in rows:
        s = slot_of(r['detail'])
        if s:
            slots[s].append(r)
    tot = sum_gpu
    lines = []
    for s, v in slots.items():
        g = sum(r['ge'] - r['gs'] for r in v)
        shapes = collections.Counter()
        for r in v:
            d = kv(r['detail'])
            if r['tag'] == 'batch':
                shapes[f"batch k={d.get('k')} cap=2^{d.get('log_cap')} deg={d.get('deg')} nd={d.get('nd')}/{d.get('n_vars')}"] += 1
            else:
                shapes[r['tag']] += 1
        lines.append((g, s, len(v), shapes))
    for g, s, n, shapes in sorted(lines, reverse=True)[:a.top]:
        sh = '; '.join(f'{k} x{c}' for k, c in shapes.most_common(4))
        print(f'  {s[:60]:<60} {n:>6} {g / a.proofs:8.4f} s {100 * g / tot:5.1f}%  {sh}')
    # commits by shape
    print('\ncommits by shape: cbs, GPU s per proof, mean ms')
    cm = collections.defaultdict(list)
    for r in tags.get('commit', []):
        cm[r['detail']].append(r)
    for d, v in sorted(cm.items(), key=lambda kv_: -sum(r['ge'] - r['gs'] for r in kv_[1])):
        g = sum(r['ge'] - r['gs'] for r in v)
        print(f'  {d:<50} {len(v):>6} {g / a.proofs:8.4f} {1e3 * g / len(v):8.3f}')
    # other tags by detail
    for t in ('wprod', 'gather', 'devfold', 'tables', 'other'):
        v = tags.get(t, [])
        if not v:
            continue
        print(f'\n{t} by detail (top 8): cbs, GPU s per proof, mean ms')
        dd = collections.defaultdict(list)
        for r in v:
            dd[re.sub(r'^slot \d+ \([^|]*\| ', '', r['detail'])].append(r)
        for d, w in sorted(dd.items(), key=lambda kv_: -sum(r['ge'] - r['gs'] for r in kv_[1]))[:8]:
            g = sum(r['ge'] - r['gs'] for r in w)
            print(f'  {d[:70]:<70} {len(w):>6} {g / a.proofs:8.4f} {1e3 * g / len(w):8.3f}')


if __name__ == '__main__':
    sys.exit(main())

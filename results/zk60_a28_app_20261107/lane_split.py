#!/usr/bin/env python3
"""Lane A28: where ONE prover lane's request thread spends a request (a macOS `sample` call graph of the prover
server; diagnostics only, public code symbols). Every sample of the thread that runs `prove_with_public` is put
in one of three classes:

  gpu wait   the stack passes through `hashline::gpu::metal::wait_done` (a command buffer of this lane is
             committed and not yet complete);
  parallel   below `prove_with_public` the stack passes through a rayon join / parallel iterator (the lane's
             other threads work on the same section);
  serial     everything else (the lane's other threads are idle).

Then the largest serial and parallel sections by their nearest named callers.

usage: lane_split.py <sample.txt> <thread name, e.g. a24-lane0-0> [--top 30] [--cycle SECONDS]
  --cycle: the lane's seconds per request in that run; every share is then also printed as seconds per request
"""
import argparse
import collections
import re

PAR = ('rayon::iter', 'join_context', 'bridge_producer_consumer', 'rayon_core::join', 'in_worker', 'rayon::slice', 'par_')
PAT = re.compile(r'^(\s+[+!:| ]*?)(\d+) (.+?)  \((in [^)]+)\)')


def short(n):
    n = re.sub(r'::h[0-9a-f]{16}$', '', n)
    n = n.replace('hashline::private_block::', 'pb::').replace('hashline::', 'hl::').replace('_$u7b$$u7b$closure$u7d$$u7d$', '{cl}')
    return re.sub(r'\$LT\$|\$GT\$|\$u20\$|\$C\$', '~', n)


def named(n):
    return n.startswith(('pb::', 'hl::', 'zkp_core::')) and '{cl}' not in n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('path')
    ap.add_argument('thread')
    ap.add_argument('--top', type=int, default=30)
    ap.add_argument('--cycle', type=float, default=None)
    a = ap.parse_args()
    nodes = []
    on = False
    with open(a.path, errors='replace') as f:
        for line in f:
            if 'Thread_' in line and line.rstrip().endswith(a.thread):
                on = True
                continue
            if on and re.match(r'\s+\d+ Thread_', line):
                break
            if on:
                m = PAT.match(line.rstrip('\n'))
                if m:
                    nodes.append((len(m.group(1)), int(m.group(2)), short(m.group(3))))
    parent = [-1] * len(nodes)
    below = [0] * len(nodes)
    stack = []
    for i, (d, c, _) in enumerate(nodes):
        while stack and nodes[stack[-1]][0] >= d:
            stack.pop()
        if stack:
            parent[i] = stack[-1]
            below[stack[-1]] += c
        stack.append(i)
    cls = collections.Counter()
    serial = collections.Counter()
    par = collections.Counter()
    total = 0
    for i, (_, c, _) in enumerate(nodes):
        own = c - below[i]
        if own <= 0:
            continue
        chain = []
        j = i
        while j != -1:
            chain.append(nodes[j][2])
            j = parent[j]
        k = next((x for x, n in enumerate(chain) if 'prove_with_public' in n and '{cl}' not in n), None)
        if k is None:
            continue
        total += own
        if any('wait_done' in n for n in chain):
            cls['gpu wait'] += own
            continue
        sub = chain[:k]
        names = [n for n in sub if named(n)][:2]
        key = ' < '.join(n[:64] for n in names) if names else 'prove_with_public (itself)'
        if any(any(p in n for p in PAR) for n in sub):
            cls['parallel'] += own
            par[key] += own
        else:
            cls['serial'] += own
            serial[f'{key}  [{chain[0][:48]}]'] += own
    def secs(v):
        return f'  {a.cycle * v / max(total, 1):6.2f} s' if a.cycle else ''

    print(f'{a.thread}: {total} samples under prove_with_public' + (f'; {a.cycle} s per request' if a.cycle else ''))
    for k in ('gpu wait', 'serial', 'parallel'):
        print(f'  {k:<9} {cls[k]:7d}  {100 * cls[k] / max(total, 1):5.1f}%{secs(cls[k])}')
    for title, table in (('serial', serial), ('parallel', par)):
        print(f'\n{title} sections, by nearest named callers (% of the thread\'s samples' + (', seconds per request' if a.cycle else '') + '):')
        for k, v in table.most_common(a.top):
            print(f'  {v:6d} {100 * v / max(total, 1):5.1f}%{secs(v)}  {k}')


if __name__ == '__main__':
    main()

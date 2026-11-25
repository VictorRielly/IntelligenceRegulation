#!/usr/bin/env python3
"""Which paths a smoke leg ran (standard library only; `python3 -I -B smoke_paths.py RAW_DIR/w2_smoke [zero-expected components]`).

Reads every `leg*_arm*.prover.log.err` of the smoke directory (legs run with HL_METAL_TIMING=1; not timed measurements) and counts
(1) the `[ZK60-HOST-FAST-W2] block hits=K:N,... fallbacks=K:N,...` lines of agy/host-wave2 (summed per component over the leg) and
    any other line with that tag, shown once each with its count;
(2) the `[ZK60-CLASSIFY-HOST-FAST] active=1 req_hits=... req_fallbacks=...` lines and the `[ZK60-HOST-FAST] block` lines (all
    three arms run with both merged host switches) with their fall-back sums;
(3) the batched sumchecks by kind with the fast chain's fall-back line.
Condition (a): arm C shows wave-2 block lines with every component's hit sum non-zero, except the components named on the command
line (default: ad, the async dropper, which is off unless HL_HOST_FAST_ASYNC_DROP=1), and every fall-back sum zero; arms A and B
show no wave-2 line; every arm shows classifier request lines with every hit sum non-zero and zero fall-backs, host-fast block
lines with zero fall-backs, only `sc-chain-fast` batches and no chain fall-back line. The counters are process-wide.
"""
import collections
import re
import sys
from pathlib import Path

d = Path(sys.argv[1])
zero_ok = set(sys.argv[2].split(',')) if len(sys.argv) > 2 else {'ad'}
bat = re.compile(r'\[ZK60-METAL M6\] \d+ of \d+ rounds batched \(degree \d+(?:, ([a-z-]+))?\)')
w2 = re.compile(r'\[ZK60-HOST-FAST-W2\] block hits=(\S+) fallbacks=(\S+)')
blk = re.compile(r'\[ZK60-HOST-FAST\] block hits=(\S+) fallbacks=(\S+)')
req = re.compile(r'\[ZK60-CLASSIFY-HOST-FAST\] active=1 req_hits=(\S+) req_fallbacks=(\S+)')
num = re.compile(r'(?<![A-Za-z_=\d])\d+')


def pairs(s):
    return [(k, int(v)) for k, v in (x.split(':') for x in s.split(','))]


def add(cnt, order, s):
    for n, v in pairs(s):
        if n not in order:
            order.append(n)
        cnt[n] += v


ok = True
for f in sorted(d.glob('leg*_arm*.prover.log.err')):
    arm = f.name.split('_arm')[1][0]
    k, other = collections.Counter(), collections.Counter()
    wh, wf, ch, cf, hf = (collections.Counter() for _ in range(5))
    owh, owf, och, ocf, ohf = [], [], [], [], []
    nw = nreq = nblk = 0
    for line in f.open(errors='replace'):
        m = bat.search(line)
        if m:
            k['batched ' + (m.group(1) or 'no kind printed')] += 1
        if 'fell back to standard sumcheck chain' in line:
            k['chain fall-back line'] += 1
        m = w2.search(line)
        if m:
            nw += 1
            add(wh, owh, m.group(1))
            add(wf, owf, m.group(2))
            continue
        m = blk.search(line)
        if m:
            nblk += 1
            add(hf, ohf, m.group(2))
            continue
        m = req.search(line)
        if m:
            nreq += 1
            add(ch, och, m.group(1))
            add(cf, ocf, m.group(2))
            continue
        for tag in ('[ZK60-HOST-FAST-W2]', '[ZK60-CLASSIFY-HOST-FAST]', '[ZK60-HOST-FAST]'):
            i = line.find(tag)
            if i >= 0:
                other[num.sub('N', line[i:].strip())[:170]] += 1
                break
    fast = k['batched sc-chain-fast']
    notfast = sum(v for n, v in k.items() if n.startswith('batched') and n != 'batched sc-chain-fast')
    w2_other = sum(v for n, v in other.items() if n.startswith('[ZK60-HOST-FAST-W2]'))
    print(f'{f.name}: arm {arm}')
    for n, v in sorted(k.items()):
        print(f'    {v:7d}  {n}')
    for n, v in sorted(other.items()):
        print(f'    {v:7d}  {n}')
    print(f'    {nblk:7d}  [ZK60-HOST-FAST] block lines; fall-backs summed: ' + (', '.join(f'{n} {hf[n]}' for n in ohf) or 'none printed'))
    print(f'    {nreq:7d}  [ZK60-CLASSIFY-HOST-FAST] request lines; hits ' + (', '.join(f'{n} {ch[n]}' for n in och) or 'none') + '; fall-backs ' + (', '.join(f'{n} {cf[n]}' for n in ocf) or 'none'))
    print(f'    {nw:7d}  [ZK60-HOST-FAST-W2] block lines')
    if nw:
        print('             hits, sum over the leg:        ' + ', '.join(f'{n} {wh[n]}' for n in owh))
        print('             fall-backs, sum over the leg:  ' + ', '.join(f'{n} {wf[n]}' for n in owf))
    base_ok = (fast > 0 and notfast == 0 and k['chain fall-back line'] == 0 and nblk > 0 and sum(hf.values()) == 0
               and nreq > 0 and all(ch[n] > 0 for n in och) and sum(cf.values()) == 0)
    if arm == 'C':
        good = base_ok and nw > 0 and all(wh[n] > 0 for n in owh if n not in zero_ok) and sum(wf.values()) == 0
        zeros = [n for n in owh if wh[n] == 0]
        print(f'             components with a zero hit sum: {zeros or "none"} (allowed to be zero: {sorted(zero_ok)})')
    else:
        good = base_ok and nw == 0 and w2_other == 0
    ok &= good
    print(f'    {"as required" if good else "NOT as required"} for arm {arm}')
print('condition (a):', 'MET' if ok else 'NOT MET')

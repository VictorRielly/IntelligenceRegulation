#!/usr/bin/env python3
"""Which paths a smoke leg ran (standard library only; `python3 -I -B smoke_paths.py [RAW_DIR/ch_smoke]`).

Reads every `leg*_arm*.prover.log.err` of the smoke directory (legs run with HL_METAL_TIMING=1; not timed measurements) and counts
(1) the `[ZK60-CLASSIFY-HOST-FAST]` lines of agy/classify-host-opt
    `[ZK60-CLASSIFY-HOST-FAST] active=1 req_hits=C1:N,...,C5:N req_fallbacks=C1:N,...,C5:N total_hits=... total_fallbacks=...`
    (the per-request hit and fall-back counts summed over the leg; the counters are process-wide, so with six lanes a request
    line also counts other lanes' hits: the sums and the fall-back totals are what is established), and any other line with
    that tag, shown once each with its count;
(2) the `[ZK60-HOST-FAST] block` lines (all three arms run with HL_HOST_FAST=1) and their fall-back sum;
(3) the batched sumchecks by kind with the fast chain's fall-back line.
Condition (a) of the coordination entry that defines the set: arm C shows `[ZK60-CLASSIFY-HOST-FAST]` request lines with every
component's hit sum non-zero and every fall-back sum zero; arms A and B show no such line; every arm shows `[ZK60-HOST-FAST]`
block lines with zero fall-backs, only `sc-chain-fast` batches and no chain fall-back line.
"""
import collections
import re
import sys
from pathlib import Path

d = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent / 'raw' / 'ch_smoke'
bat = re.compile(r'\[ZK60-METAL M6\] \d+ of \d+ rounds batched \(degree \d+(?:, ([a-z-]+))?\)')
blk = re.compile(r'\[ZK60-HOST-FAST\] block hits=(\S+) fallbacks=(\S+)')
req = re.compile(r'\[ZK60-CLASSIFY-HOST-FAST\] active=1 req_hits=(\S+) req_fallbacks=(\S+)')
num = re.compile(r'(?<![A-Za-z_=\d])\d+')


def pairs(s):
    return [(k, int(v)) for k, v in (x.split(':') for x in s.split(','))]


ok = True
for f in sorted(d.glob('leg*_arm*.prover.log.err')):
    arm = f.name.split('_arm')[1][0]
    k = collections.Counter()
    other = collections.Counter()
    hits, falls, hf_falls = collections.Counter(), collections.Counter(), collections.Counter()
    order_h, order_f = [], []
    reqs = blocks = 0
    for line in f.open(errors='replace'):
        m = bat.search(line)
        if m:
            k['batched ' + (m.group(1) or 'no kind printed')] += 1
        if 'fell back to standard sumcheck chain' in line:
            k['chain fall-back line'] += 1
        m = blk.search(line)
        if m:
            blocks += 1
            for n, v in pairs(m.group(2)):
                hf_falls[n] += v
            continue
        m = req.search(line)
        if m:
            reqs += 1
            for n, v in pairs(m.group(1)):
                if n not in order_h:
                    order_h.append(n)
                hits[n] += v
            for n, v in pairs(m.group(2)):
                if n not in order_f:
                    order_f.append(n)
                falls[n] += v
            continue
        for tag in ('[ZK60-CLASSIFY-HOST-FAST]', '[ZK60-HOST-FAST]'):
            i = line.find(tag)
            if i >= 0:
                other[num.sub('N', line[i:].strip())[:170]] += 1
    fast = k['batched sc-chain-fast']
    notfast = sum(v for n, v in k.items() if n.startswith('batched') and n != 'batched sc-chain-fast')
    ch_other = sum(v for n, v in other.items() if n.startswith('[ZK60-CLASSIFY-HOST-FAST]'))
    print(f'{f.name}: arm {arm}')
    for n, v in sorted(k.items()):
        print(f'    {v:7d}  {n}')
    for n, v in sorted(other.items()):
        print(f'    {v:7d}  {n}')
    print(f'    {blocks:7d}  [ZK60-HOST-FAST] block lines; fall-backs summed: ' + (', '.join(f'{n} {v}' for n, v in sorted(hf_falls.items())) or 'none printed'))
    print(f'    {reqs:7d}  [ZK60-CLASSIFY-HOST-FAST] request lines')
    if reqs:
        print('             hits, sum over the leg:        ' + ', '.join(f'{n} {hits[n]}' for n in order_h))
        print('             fall-backs, sum over the leg:  ' + ', '.join(f'{n} {falls[n]}' for n in order_f))
    base_ok = fast > 0 and notfast == 0 and k['chain fall-back line'] == 0 and blocks > 0 and sum(hf_falls.values()) == 0
    if arm == 'C':
        good = base_ok and reqs > 0 and all(hits[n] > 0 for n in order_h) and sum(falls.values()) == 0
    else:
        good = base_ok and reqs == 0 and ch_other == 0
    ok &= good
    print(f'    {"as required" if good else "NOT as required"} for arm {arm}')
print('condition (a):', 'MET' if ok else 'NOT MET')

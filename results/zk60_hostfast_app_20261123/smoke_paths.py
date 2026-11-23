#!/usr/bin/env python3
"""Which paths a smoke leg ran (standard library only; `python3 -I -B smoke_paths.py [RAW_DIR/hf_smoke]`).

Reads every `leg*_arm*.prover.log.err` of the smoke directory (legs run with HL_METAL_TIMING=1; not timed measurements) and counts
(1) the `[ZK60-HOST-FAST]` lines: the per-block line of agy/host-g5g4g6 `6b68cb931`
    `[ZK60-HOST-FAST] block hits=h1:N,h2:N,h3:N,h4:N,h5:N,h6g:N,h6c:N,h6d:N fallbacks=h1e:N,h1a:N,h4:N,h5:N,h6:N`
    (summed per component over the leg, with the number of blocks in which each component is non-zero), and any other line
    with that tag (the one-line marker of `67facf460`, a `fallback (<reason>)` line), shown once each with its count;
(2) the batched sumchecks by the kind in their timing line (`sc-chain-fast` or `std`) with the fast chain's fall-back line.
Condition (a) of the coordination entries of 2026-11-23T16:37:35Z and 16:44:50Z: arm C must show `[ZK60-HOST-FAST]` lines
(with the per-block line: at least one block line, and the hit and fall-back sums are reported); arms A and B none; every arm
only `sc-chain-fast` batches and no fall-back line of the chain (all three arms run with HL_METAL_SC_CHAIN_FAST=1).
"""
import collections
import re
import sys
from pathlib import Path

d = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent / 'raw' / 'hf_smoke'
bat = re.compile(r'\[ZK60-METAL M6\] \d+ of \d+ rounds batched \(degree \d+(?:, ([a-z-]+))?\)')
blk = re.compile(r'\[ZK60-HOST-FAST\] block hits=(\S+) fallbacks=(\S+)')
num = re.compile(r'(?<![A-Za-z_=\d])\d+')


def pairs(s):
    return [(k, int(v)) for k, v in (x.split(':') for x in s.split(','))]


ok = True
for f in sorted(d.glob('leg*_arm*.prover.log.err')):
    arm = f.name.split('_arm')[1][0]
    k = collections.Counter()
    hf = collections.Counter()
    hits, hit_blocks, falls = collections.Counter(), collections.Counter(), collections.Counter()
    order_h, order_f = [], []
    blocks = 0
    for line in f.open(errors='replace'):
        m = bat.search(line)
        if m:
            k['batched ' + (m.group(1) or 'no kind printed')] += 1
        if 'fell back to standard sumcheck chain' in line:
            k['fall-back line'] += 1
        m = blk.search(line)
        if m:
            blocks += 1
            for n, v in pairs(m.group(1)):
                if n not in order_h:
                    order_h.append(n)
                hits[n] += v
                hit_blocks[n] += v > 0
            for n, v in pairs(m.group(2)):
                if n not in order_f:
                    order_f.append(n)
                falls[n] += v
            continue
        i = line.find('[ZK60-HOST-FAST]')
        if i >= 0:
            hf[num.sub('N', line[i:].strip())[:160]] += 1
    fast = k['batched sc-chain-fast']
    other = sum(v for n, v in k.items() if n.startswith('batched') and n != 'batched sc-chain-fast')
    nhf = sum(hf.values()) + blocks
    print(f'{f.name}: arm {arm}')
    for n, v in sorted(k.items()):
        print(f'    {v:7d}  {n}')
    for n, v in sorted(hf.items()):
        print(f'    {v:7d}  {n}')
    if blocks:
        print(f'    {blocks:7d}  [ZK60-HOST-FAST] block lines')
        print('             hits, sum over the leg:        ' + ', '.join(f'{n} {hits[n]}' for n in order_h))
        print('             blocks with a non-zero count:  ' + ', '.join(f'{n} {hit_blocks[n]}' for n in order_h))
        print('             fall-backs, sum over the leg:  ' + ', '.join(f'{n} {falls[n]}' for n in order_f))
    good = fast > 0 and other == 0 and k['fall-back line'] == 0 and ((nhf > 0) if arm == 'C' else (nhf == 0))
    ok &= good
    print(f'    host-fast lines {nhf}, fast-chain sumchecks {fast}, other sumchecks {other}, chain fall-back lines {k["fall-back line"]}: {"as required" if good else "NOT as required"} for arm {arm}')
print('condition (a):', 'MET' if ok else 'NOT MET')

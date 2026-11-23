#!/usr/bin/env python3
"""Which paths a smoke leg ran (standard library only; `python3 -I -B smoke_paths.py [RAW_DIR/hf_smoke]`).

Reads every `leg*_arm*.prover.log.err` of the smoke directory (legs run with HL_METAL_TIMING=1; not timed measurements) and counts
(1) the `[ZK60-HOST-FAST]` lines (the branch prints one per process at the first use of a host-fast path, and, if the branch has
them, any further lines with that tag, shown verbatim once each with their count), and (2) the batched sumchecks by the kind in
their timing line (`sc-chain-fast` or `std`) with the fast chain's fall-back line. Condition (a) of the coordination entry that
defines the set: arm C must show at least one `[ZK60-HOST-FAST]` line; arms A and B none; every arm only `sc-chain-fast`
batches and no fall-back line (all three arms run with HL_METAL_SC_CHAIN_FAST=1).
"""
import collections
import re
import sys
from pathlib import Path

d = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent / 'raw' / 'hf_smoke'
bat = re.compile(r'\[ZK60-METAL M6\] \d+ of \d+ rounds batched \(degree \d+(?:, ([a-z-]+))?\)')
num = re.compile(r'\d+')
ok = True
for f in sorted(d.glob('leg*_arm*.prover.log.err')):
    arm = f.name.split('_arm')[1][0]
    k = collections.Counter()
    hf = collections.Counter()
    for line in f.open(errors='replace'):
        m = bat.search(line)
        if m:
            k['batched ' + (m.group(1) or 'no kind printed')] += 1
        if 'fell back to standard sumcheck chain' in line:
            k['fall-back line'] += 1
        i = line.find('[ZK60-HOST-FAST]')
        if i >= 0:
            hf[num.sub('N', line[i:].strip())[:160]] += 1
    fast = k['batched sc-chain-fast']
    other = sum(v for n, v in k.items() if n.startswith('batched') and n != 'batched sc-chain-fast')
    nhf = sum(hf.values())
    print(f'{f.name}: arm {arm}')
    for n, v in sorted(k.items()):
        print(f'    {v:7d}  {n}')
    for n, v in sorted(hf.items()):
        print(f'    {v:7d}  {n}')
    good = fast > 0 and other == 0 and k['fall-back line'] == 0 and ((nhf > 0) if arm == 'C' else (nhf == 0))
    ok &= good
    print(f'    host-fast lines {nhf}, fast-chain sumchecks {fast}, other sumchecks {other}, fall-back lines {k["fall-back line"]}: {"as required" if good else "NOT as required"} for arm {arm}')
print('condition (a):', 'MET' if ok else 'NOT MET')

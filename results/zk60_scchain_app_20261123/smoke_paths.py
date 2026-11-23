#!/usr/bin/env python3
"""Which sumcheck chain a smoke leg ran (standard library only; `python3 -I -B smoke_paths.py [RAW_DIR/sc_smoke]`).

Reads every `leg*_arm*.prover.log.err` of the smoke directory (legs run with HL_METAL_TIMING=1; not timed measurements) and counts
the batched sumchecks by the kind in their timing line (`[ZK60-METAL M6] N of M rounds batched (degree D, <kind>)`, kind `sc-chain-fast`
or `std`, the marker added at agy/sc-chain-opt bcbcb55c2), the unbatched ones (`[ZK60-METAL] sumcheck rounds (<kind>)`) and the
once-per-process fall-back line. Condition (a) of the coordination entries of 2026-11-23T11:08:14Z and 13:29:42Z: arm C must show
only `sc-chain-fast` batches and no fall-back line; arms A and B must show no `sc-chain-fast` line (arm A's binary predates the
marker, so its batched lines carry no kind at all).
"""
import collections
import re
import sys
from pathlib import Path

d = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent / 'raw' / 'sc_smoke'
bat = re.compile(r'\[ZK60-METAL M6\] \d+ of \d+ rounds batched \(degree \d+(?:, ([a-z-]+))?\)')
unb = re.compile(r'\[ZK60-METAL\] sumcheck rounds(?: \(([a-z-]+)\))?:')
ok = True
for f in sorted(d.glob('leg*_arm*.prover.log.err')):
    arm = f.name.split('_arm')[1][0]
    k = collections.Counter()
    for line in f.open(errors='replace'):
        m = bat.search(line)
        if m:
            k['batched ' + (m.group(1) or 'no kind printed')] += 1
        m = unb.search(line)
        if m:
            k['unbatched ' + (m.group(1) or 'no kind printed')] += 1
        if 'fell back to standard sumcheck chain' in line:
            k['fall-back line'] += 1
    fast = sum(v for n, v in k.items() if n.endswith('sc-chain-fast'))
    other = sum(v for n, v in k.items() if n.startswith(('batched', 'unbatched')) and not n.endswith('sc-chain-fast'))
    print(f'{f.name}: arm {arm}')
    for n, v in sorted(k.items()):
        print(f'    {v:7d}  {n}')
    if arm == 'C':
        good = fast > 0 and other == 0 and k['fall-back line'] == 0
    else:
        good = fast == 0 and other > 0 and k['fall-back line'] == 0
    ok &= good
    print(f'    fast-chain sumchecks {fast}, others {other}, fall-back lines {k["fall-back line"]}: {"as required" if good else "NOT as required"} for arm {arm}')
print('condition (a):', 'MET' if ok else 'NOT MET')

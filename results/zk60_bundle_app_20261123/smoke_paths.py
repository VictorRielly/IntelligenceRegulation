#!/usr/bin/env python3
"""Which fold and gather paths a smoke leg took (standard library only; `python3 -I -B smoke_paths.py [RAW_DIR/bn_smoke]`).

Reads every `leg*_arm*.prover.log.err` of the smoke directory (legs run with HL_METAL_TIMING=1; not timed measurements) and counts the
`[ZK60-METAL] store ...` lines by kind: the text between `store ` and the first colon, with digits left as they are (the kinds carry no
numbers). Condition (a) of the coordination entry of 2026-11-23T11:08:14Z: arm C must show fold lines of kind `sparse-gpu-reg8` and
`store columns (host tiled)` lines, and no fold line of an older kind; arms A and B must show neither.
"""
import collections
import re
import sys
from pathlib import Path

d = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent / 'raw' / 'bn_smoke'
pat = re.compile(r'\[ZK60-METAL\] (store [^:]*):')
ok = True
for f in sorted(d.glob('leg*_arm*.prover.log.err')):
    arm = f.name.split('_arm')[1][0]
    kinds = collections.Counter()
    for line in f.open(errors='replace'):
        m = pat.search(line)
        if m:
            kinds[m.group(1)] += 1
    folds = {k: v for k, v in kinds.items() if 'fold' in k}
    cols = {k: v for k, v in kinds.items() if 'columns' in k}
    reg8 = sum(v for k, v in folds.items() if 'sparse-gpu-reg8' in k)
    older = sum(v for k, v in folds.items() if 'sparse-gpu-reg8' not in k)
    tiled = sum(v for k, v in cols.items() if 'host tiled' in k)
    print(f'{f.name}: arm {arm}')
    for k, v in sorted(kinds.items()):
        print(f'    {v:7d}  {k}')
    if arm == 'C':
        good = reg8 > 0 and older == 0 and tiled > 0
    else:
        good = reg8 == 0 and tiled == 0 and older > 0
    ok &= good
    print(f'    reg8 folds {reg8}, older-kind folds {older}, host tiled gathers {tiled}: {"as required" if good else "NOT as required"} for arm {arm}')
print('condition (a):', 'MET' if ok else 'NOT MET')

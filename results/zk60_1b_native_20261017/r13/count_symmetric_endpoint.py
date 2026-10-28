#!/usr/bin/env python3
"""COUNTED correction for the strict symmetric int16 class in the spec."""
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
ROOT = Path('/home/victor/IntelligenceRegulation')
OUT = Path(__file__).resolve().parent
source = ROOT / 'results/zk60_fidelity_parity_20261019/cost/fp_r11_stacks.py'
spec = importlib.util.spec_from_file_location('r13_symmetric_cost', source)
counter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(counter)
counter.r10.anchor()
rows = []
for geometry in counter.GEOMS:
    for dd in (False, True):
        stack = 'LOW16' if geometry.startswith('TinyLlama') else 'LOW16_H24'
        layout, _ = counter.build(geometry, dd, counter.STACKS[stack][1])
        baseline = counter.r10.Layout(counter.GEOMS[geometry], dd=dd).totals()
        planes, lookups = layout.extra['F']
        layout.extra['F'] = planes + 1, lookups
        before = layout.totals()
        for domain, count in [('D', 2), ('Q', 3), ('Kv', 3)]:
            planes, lookups = layout.extra[domain]
            layout.extra[domain] = planes + count, lookups
        after = layout.totals()
        row = dict(geometry=geometry, dd=dd, stack=stack,
                   byte_aligned_before=before, strict_symmetric_after=after,
                   before_pct=100 * (before['committed'] / baseline['committed'] - 1),
                   after_pct=100 * (after['committed'] / baseline['committed'] - 1),
                   delta_points=100 * (after['committed'] - before['committed']) / baseline['committed'])
        rows.append(row)
        print(geometry, 'DD' if dd else 'non-DD', f"{row['before_pct']:.3f}% -> {row['after_pct']:.3f}% (+{row['delta_points']:.3f} points)")
report = dict(scope='COUNTED proposal on the anchored replica, not a native layout/proof',
    problem='Two biased byte limbs admit -32768, while the spec/fidelity evaluator requires [-32767,32767].',
    construction='One auxiliary field inverse per strict symmetric word: (word+32768)*inverse=1 on support; the biased byte decomposition gives signed16 first. No integer interpretation is needed for the auxiliary inverse.',
    additional_a_planes=dict(D=2, Q=3, Kv=3), additional_u8_lookups=0,
    degree='Bilinear exclusion clause, within the existing domain zero-check degrees; native definition still must confirm.',
    constraints=['Use the extra planes only on the new R13 profiles.',
                 'Gate the inverse relation on true coordinates and specify its pad rule.',
                 'Do not include auxiliary field inverses in integer no-wrap bounds.',
                 'Verifier derives counts; capture the -32768 rejection control.'],
    source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(), rows=rows)
(OUT / 'symmetric_endpoint_cost.json').write_text(json.dumps(report, indent=2) + '\n')

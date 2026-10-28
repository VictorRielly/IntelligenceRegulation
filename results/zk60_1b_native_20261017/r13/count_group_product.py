#!/usr/bin/env python3
"""Recount exact group-product scaling on the anchored R10/R11 replica.

COUNTED proposed layout, not a native R13 measurement. A common-denominator
SiLU output table absorbs the power-of-two product coefficient before the
single rounding; no additional public factor enters the product zero-check.
Use uniform two-byte RH on LOW+h24, three-byte RH on LOW. The conservative
variant adds a plane and lookup; byte alignment replaces the old top-pin
lookup by the extra full byte, so only the extra F plane remains.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
ROOT = Path('/home/victor/IntelligenceRegulation')
OUT = Path(__file__).resolve().parent
source = ROOT / 'results/zk60_fidelity_parity_20261019/cost/fp_r11_stacks.py'
spec = importlib.util.spec_from_file_location('r13_cost_replica', source)
counter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(counter)
counter.r10.anchor()
rows = []
for geometry in counter.GEOMS:
    for dd in (False, True):
        name = 'LOW16' if geometry.startswith('TinyLlama') else 'LOW16_H24'
        layout, windows = counter.build(geometry, dd, counter.STACKS[name][1])
        baseline = counter.r10.Layout(counter.GEOMS[geometry], dd=dd).totals()
        before = layout.totals()
        extra_planes, extra_lookups = layout.extra.get('F', (0, 0))
        layout.extra['F'] = (extra_planes + 1, extra_lookups + 1)
        after = layout.totals()
        # Byte-align the common denominator: R=16 (h24) or 24 (h16).
        # All remainder limbs are full bytes, so there is no extra top-pin
        # lookup. Derive table outputs by exact scaling AFTER their existing
        # int16 SiLU quantization; product relation degree stays unchanged.
        layout.extra['F'] = (extra_planes + 1, extra_lookups)
        aligned = layout.totals()
        percent_before = 100 * (before['committed'] / baseline['committed'] - 1)
        percent_after = 100 * (after['committed'] / baseline['committed'] - 1)
        row = dict(geometry=geometry, dd=dd, stack=name,
                   original_product_window=windows['windows']['h'],
                   proposed_product_limbs=3 if name == 'LOW16' else 2,
                   baseline_committed=baseline['committed'], before=before, after=after,
                   committed_pct_before=percent_before, committed_pct_after=percent_after,
                   delta_percentage_points=percent_after - percent_before,
                   byte_aligned=aligned,
                   byte_aligned_shift=24 if name == 'LOW16' else 16,
                   byte_aligned_committed_pct=100 * (aligned['committed'] / baseline['committed'] - 1),
                   byte_aligned_delta_points=100 * (aligned['committed'] - before['committed']) / baseline['committed'])
        rows.append(row)
        print(geometry, 'DD' if dd else 'non-DD', name,
              f'original {percent_before:.3f}%; conservative {percent_after:.3f}%; byte-aligned {row["byte_aligned_committed_pct"]:.3f}% (+{row["byte_aligned_delta_points"]:.3f} points)')
report = dict(scope='COUNTED proposed correction on the anchored replica; native layout not implemented yet',
              replica_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
              construction='derive scaled public SiLU table outputs before the lookup; retain one product rounding and the product slot degree',
              byte_aligned_coefficient_max=1 << 15,
              derived_table_output_abs_max=32767 * (1 << 15),
              note='Aligned counts replace one old top-pin lookup by the extra full-byte lookup; helper count does not increase.',
              obligations=['Recheck the larger derived table-output bound and slot definitions under D24.',
                           'Confirm all final native counts, claim sites, helper thresholds and mask rows.',
                           'Use export-selected LOW for TinyLlama and LOW+h24 for 8B.'], rows=rows)
(OUT / 'group_product_cost.json').write_text(json.dumps(report, indent=2) + '\n')

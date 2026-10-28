#!/usr/bin/env python3
"""Conservative scalar-clause bounds for the planned R13 precision classes.

COUNTED arithmetic, conditional on the listed classes being enforced by the
native validators/range relations. This is not a soundness review.
"""
import json
import math
import hashlib
import re
from pathlib import Path

P = (1 << 64) - (1 << 32) + 1
field_source = Path(__file__).parent / 'working-tree/zkp-core/src/field.rs'
literal = re.search(r'pub const P: u64 = (0x[0-9A-Fa-f_]+);', field_source.read_text()).group(1)
assert P == int(literal.replace('_', ''), 16)
limits = dict(model_width=4096, ff_width=16384, head_dim=128, tokens=512,
              x_abs=1 << 15, norm_abs=1 << 15,
              attention_abs=1 << 15, weight_abs=127,
              silu_abs=(1 << 15) - 1, up_abs=1 << 15, h_abs=1 << 23,
              cn_max=1 << 20, ceps_max=1 << 40,
              expanded_gate_multiplier_max=1 << 14,
              other_multiplier_max=1 << 8, product_scale_max=1 << 15,
              largest_requant_shift=24, product_shift_h24=16, product_shift_low=24)
l = limits
dot_attention = l['model_width'] * l['norm_abs'] * l['weight_abs'] * (1 << 6)
dot_gate = l['model_width'] * l['norm_abs'] * l['weight_abs'] * l['expanded_gate_multiplier_max']
dot_down = l['ff_width'] * l['h_abs'] * l['weight_abs'] * (1 << 6)
dot_ao = 4096 * l['attention_abs'] * l['weight_abs'] * (1 << 8)
product = l['silu_abs'] * l['up_abs'] * l['product_scale_max']
dot_score = l['head_dim'] * l['attention_abs'] ** 2
# Twice each possible absolute accumulator and reconstructed result plus a
# remainder bound: a conservative upper bound on any difference clause.
bounds = {
    'qkv_requant': 2 * dot_attention + (1 << 17) * (1 << 16),
    'gate_requant': 2 * dot_gate + (1 << 13) * (1 << 24),
    'ao_requant': 2 * dot_ao + (1 << 17) * (1 << 24),
    'down_requant': 2 * dot_down + (1 << 17) * (1 << 24),
    'score_requant': 2 * dot_score + (1 << 9) * (1 << 24),
    'rope_requant': 4 * (1 << 7) * l['attention_abs'] + 2 * (1 << 7) * l['attention_abs'] + (1 << 8),
    'pv_requant': 2 * l['tokens'] * (1 << 12) * l['attention_abs'] + (1 << 17) * (1 << 16),
    'up_requant': 2 * l['model_width'] * l['norm_abs'] * l['weight_abs'] * (1 << 4)
                  + (1 << 17) * (1 << 16),
    'derived_table_output': l['silu_abs'] * l['product_scale_max'],
    'product_requant_h24': 2 * product + 4 * l['h_abs'] * (1 << l['product_shift_h24']) + (1 << 18),
    'product_requant_low': 2 * product + 4 * (1 << 15) * (1 << l['product_shift_low']) + (1 << 26),
    'norm_numerator': 4 * l['x_abs'] * l['weight_abs'] * l['cn_max']
                      + (1 << 18) * math.isqrt(l['ceps_max'] + l['model_width'] * l['x_abs'] ** 2),
    'norm_reconstruction': 4 * math.isqrt(l['ceps_max'] + l['model_width'] * l['x_abs'] ** 2)
                           * l['norm_abs'] * (1 << 8) + (1 << 25),
    'softmax_quotient': 2 * (1 << 13) * l['tokens'] * (1 << 16) + (1 << 25),
}
assert all(0 < bound < P for bound in bounds.values())
report = dict(scope='COUNTED conditional scalar bounds, not security acceptance',
              canonical_field_source_sha256=hashlib.sha256(field_source.read_bytes()).hexdigest(),
              field_modulus=P, classes=limits,
              word_domain='R13 amended widened norm/attention class [-32768,32767]; symmetric int8 scores and public weights remain [-127,127].',
              clauses={name: dict(absolute_bound=value, bits=value.bit_length(), below_field=True)
                       for name, value in bounds.items()},
              derived_table_storage='raw registered SiLU output is int16; verifier derives exact scaled table output with abs <= 32767 * 2^15 < 2^30 (signed31)',
              table_derivation='scale the already-quantized int16 word exactly; never quantize the real SiLU value again at a finer step',
              obligations=['Enforce expanded gate multiplier and shift bounds, including group folds.',
                           'R13 rechecks public matrices/gains and rejects -128; the i8 storage type alone is not the symmetric class.',
                           'Verifier recomputes each derived scaled table from pinned/raw registered members and export-selected stack.',
                           'Prove every word and biased remainder range; scalar arithmetic alone is insufficient.',
                           'Recompute norm D_max/wrho from each calibration; tn-8 must yield at most three limbs.',
                           'Recount layout/lookup terms and run D24 review on the actual native implementation.'])
Path(__file__).with_name('nowrap_counted.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))

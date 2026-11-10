"""A29 design census (light, metadata only): the current export's 26 calibrations, the
quantities W16R2's plane list reads, and the candidate uniform sets.

The W16R2 range widths (range16::widths) read the precision derived from the base shifts,
the common gate shift and wrho_s. At this export (LowH24, f_e 9) only four of them move
with a layer: the top limbs of the attention output (sh_ao + 14), the down projection
(sh_z + 14), the score (sh_s + 12) and the gate denominator. The product remainder is fixed
at 16 bits under LowH24 (so sh_h does not enter), and cn_a / cn_m enter only the class check
of NormCalibration::derive_at_width (1..=2^20), not d_max, the norm window or any width.
The mirror below must reproduce lane A25's MEASURED census exactly before it is used.
"""
import itertools
import json

import a29lib as A

np = A.np
A25 = {0: (70, 42), 3: (70, 42)}
A25.update({l: (71, 43) for l in (1, 2, 4, 5, 7, 8, 14, 16, 18, 20, 22, 25)})
A25.update({l: (72, 44) for l in (6, 9, 10, 11, 12, 13, 15, 17, 19, 21, 23, 24)})
SEED = (6, 6, 8, 17)  # the run seed: layer 16's shifts (the loader's base) at the registered gate 17


def planes(sh_ao, sh_s, sh_z, gate):
    n0 = len(A.w16r2_widths(*SEED))  # the seed's W16R2 list is (72, 44) (A25, MEASURED)
    n = len(A.w16r2_widths(sh_ao, sh_s, sh_z, gate))
    return (72 - (n0 - n), 44 - (n0 - n))


def main():
    layers = []
    for l in range(A.LAYERS):
        p, m = A.manifest(A.BASELINE, l); c = m['constants']
        g = A.array(p, m['arrays']['silu_groups']); i = A.array(p, m['arrays']['silu_group_ids'])
        gate = A.gate_common_shift(c, g, i)
        layers.append({'layer': l, 'sh_ao': c['sh_ao'], 'sh_s': c['sh_s'], 'sh_h': c['sh_h'], 'sh_z': c['sh_z'], 'gate': gate,
                       'cn_a': c['norm_cn_a'], 'cn_m': c['norm_cn_m'], 'silu_member': c['silu_member'],
                       'groups': g.tolist(), 'w16r2_planes_own': planes(c['sh_ao'], c['sh_s'], c['sh_z'], gate)})
    A.require(all(tuple(x['w16r2_planes_own']) == A25[x['layer']] for x in layers), 'mirror differs from A25 census')
    count = lambda key: {str(v): sum(1 for x in layers if x[key] == v) for v in sorted({x[key] for x in layers})}
    candidates = []
    for ao, s, z, gate in itertools.product((6, 7, 8), (6, 7, 8), (5, 6, 7, 8), (18, 19, 20)):
        stage, seed = planes(ao, s, z, gate), planes(ao, s, z, 17)
        moved = sum((x['sh_ao'] != ao) + (x['sh_s'] != s) + (x['sh_z'] != z) + (x['gate'] != gate) for x in layers)
        candidates.append({'sh_ao': ao, 'sh_s': s, 'sh_z': z, 'gate': gate, 'stage_planes': stage,
                           'seed_planes_at_gate17': seed, 'one_plane_list_incl_seed': stage == seed,
                           'layer_fields_moved': int(moved)})
    candidates.sort(key=lambda c: (not c['one_plane_list_incl_seed'], c['layer_fields_moved']))
    out = {'layers': layers, 'value_counts': {k: count(k) for k in ('sh_ao', 'sh_s', 'sh_z', 'sh_h', 'gate')},
           'distinct_shift_sets_ao_s_h_z': len({(x['sh_ao'], x['sh_s'], x['sh_h'], x['sh_z']) for x in layers}),
           'distinct_cn_pairs': len({(x['cn_a'], x['cn_m']) for x in layers}),
           'mirror_reproduces_a25_census': True, 'candidates_best_first': candidates[:12],
           'scope': 'CODE mirror of range16::widths for prediction only; the Rust census (census.sh) is the authority'}
    A.record(A.HERE / 'design_census.json', out)
    print(json.dumps({'value_counts': out['value_counts'], 'top': candidates[:6]}, indent=None))


if __name__ == '__main__':
    raise SystemExit(main())

"""Read-only full-layer intake audit for the pending R13 exporter.

Checks actual arrays, not just declared shapes. Native source remains read-only;
this output is a review manifest, not a native profile or acceptance result.
"""
import json
from pathlib import Path

import numpy as np

import calibration_port as P
from accuracy_stack import BITS, group_tables
from amended_evaluator import candidate_pin
from collect_stats import atomic_json, sha
from evaluation_export import EvaluationExport
from shieldstral_geometry import D, LAYERS

HERE = Path(__file__).resolve().parent
NATIVE = HERE.parent / 'zk60_1b_native_20261017/r13'
MEMBERS = {(-5, -13), (-4, -13), (-4, -12), (-3, -12), (-3, -11),
           (-2, -11), (-1, -11), (-1, -10), (-1, -9)}
SHIELDSTRAL_EXTENSION = (0, -8)


def precision(constants):
    """Transcribe the current LOW+h24 public shifts, including c2 bits."""
    c = constants
    values = {'norm_tn': c['norm_tn'] - 8, 'q': c['sh_qkv'] + 7,
              'k': c['sh_qkv'] + 7, 'v': c['sh_qkv'] + 8,
              'score': c['sh_s'] + 12, 'pv': c['sh_o'] + 3,
              'ao': c['sh_ao'] + 14, 'gate_before_group': c['sh_g'] + 10,
              'up': c['sh_u'] + 12, 'product_before_group': c['sh_h'] - 8,
              'down': c['sh_z'] + 14}
    if not (1 <= c['norm_tn'] <= 16 and 1 <= c['sh_qkv'] <= 8 and 1 <= c['sh_s'] <= 8
            and 9 <= c['sh_o'] <= 16 and 0 <= c['sh_ao'] <= 8 and 1 <= c['sh_g'] <= 8
            and c['sh_u'] == 0 and 9 <= c['sh_h'] <= 16 and 1 <= c['sh_z'] <= 8):
        raise ValueError('base shifts outside current native legacy calibration class')
    if not (values['norm_tn'] > 0 and all(9 <= values[n] <= 16 for n in ('q', 'k', 'v', 'pv', 'up'))
            and all(17 <= values[n] <= 24 for n in ('score', 'ao', 'down'))
            and 1 <= values['gate_before_group'] <= 24 and 5 <= values['product_before_group'] <= 8):
        raise ValueError('derived shifts outside current native LOW+h24 windows')
    return values


def audit_layer(root, index, ready_digest, correction):
    directory = root / f'layer_{index:02d}'
    if sha(directory / 'ready.json') != ready_digest:
        raise ValueError('layer manifest changed')
    ready = json.loads((directory / 'ready.json').read_text())
    for name, digest in ready['files'].items():
        if sha(directory / name) != digest:
            raise ValueError('layer bytes changed')
    meta = json.loads((directory / 'arithmetic.json').read_text())
    c = correction['constants'] if index == 25 else meta['constants']
    geo = P.tc.GEO
    width = geo.H * geo.dh
    kv = geo.KV * geo.dh
    shapes = {'q': ('wq', (width, D), width), 'k': ('wk', (kv, D), kv),
              'v': ('wv', (kv, D), kv), 'o': ('wo', (D, width), D),
              'g': ('wg_t', (D, geo.f), geo.f), 'u': ('wu_t', (D, geo.f), geo.f),
              'd': ('wd_t', (geo.f, D), D)}
    result = {'layer': index, 'constants': c, 'derived_shifts': precision(c), 'matrices': {}}
    with np.load(directory / 'arrays.npz', allow_pickle=False) as arrays, \
            np.load(HERE / 'layer25_fix_candidate/candidate.npz', allow_pickle=False) as fix:
        for site, (name, shape, outputs) in shapes.items():
            w = fix['wu_t'] if index == 25 and site == 'u' else arrays['w__' + name]
            m = fix['mult_u'] if index == 25 and site == 'u' else arrays['extra__mult_' + site]
            if w.shape != shape or w.dtype != np.dtype('int8') or np.any(w == -128):
                raise ValueError('matrix shape or symmetric int8 class differs')
            if m.shape != (outputs,) or m.dtype.kind not in 'iu' or np.any(m < 1) or np.any(m > 1 << BITS[site]):
                raise ValueError('multiplier shape or narrow class differs')
            result['matrices'][site] = {'shape': list(w.shape), 'weight_min': int(w.min()), 'weight_max': int(w.max()),
                                       'multiplier_bits': BITS[site], 'multiplier_min': int(m.min()), 'multiplier_max': int(m.max())}
        for name in ('gamma_a', 'gamma_m'):
            w = arrays['w__' + name]
            if w.shape != (D,) or w.dtype != np.dtype('int8') or np.any(w == -128):
                raise ValueError('normalization gains outside native symmetric class')
        get = (lambda key: fix[key]) if index == 25 else (lambda key: arrays['extra__' + key])
        ej, eo = get('group_input_exponents'), get('group_output_exponents')
        if ej.shape != (geo.f,) or eo.shape != (geo.f,):
            raise ValueError('group assignments omit channels')
        members, ids, tables = group_tables(ej, eo)
        expected = correction['group_members'] if index == 25 else meta['group_members']
        if [list(m) for m in members] != expected or not np.array_equal(ids, get('group_ids')) or not np.array_equal(tables, get('group_tables')):
            raise ValueError('group tables or channel assignments changed')
        if not 1 <= len(members) <= 4 or not set(members) <= MEMBERS | {SHIELDSTRAL_EXTENSION}:
            raise ValueError('group count or member outside proposed Shieldstral registry')
        table_evidence = []
        largest_scaled = 0
        for member, table in zip(members, tables):
            oracle = NATIVE / 'working-tree/hashline/src/private_block/r13_vectors' / f'silu_{member[0]}_{member[1]}.bin'
            if member in MEMBERS:
                if not np.array_equal(table, np.fromfile(oracle, dtype='<i2')):
                    raise ValueError('SiLU table differs from independent retained native fixture')
                table_evidence.append({'member': list(member), 'independent_fixture_sha256': sha(oracle)})
            else:
                table_evidence.append({'member': list(member), 'independent_native_fixture': 'pending profile-specific extension'})
            delta = member[1] - c['silu'][1]
            exponent = 24 - c['sh_h'] + delta
            direct_shift = c['sh_h'] - 8 - delta
            if not 4 <= exponent <= 16 or not 1 <= direct_shift <= 12:
                raise ValueError('derived table/product outside proposed Shieldstral window')
            scaled = table.astype(np.int64) * (1 << exponent)
            largest_scaled = max(largest_scaled, int(np.abs(scaled).max()))
            if largest_scaled >= 1 << 31:
                raise ValueError('derived table outside signed32')
            # Every table entry at signed16 up endpoints and either side of zero.
            for up in (-32768, -1, 0, 1, 32767):
                original = (2 * table.astype(np.int64) * up + (1 << direct_shift)) // (2 << direct_shift)
                aligned = (2 * scaled * up + (1 << 16)) // (2 << 16)
                if not np.array_equal(original, aligned):
                    raise ValueError('byte-aligned product changes half-up integer rounding')
        gate_shifts = c['sh_g'] + 10 + ej - c['silu'][0]
        common_gate = max(17, int(gate_shifts.max()))
        gate_m = arrays['extra__mult_g'].astype(np.int64)
        folded = gate_m * np.left_shift(1, common_gate - gate_shifts)
        if np.any(gate_shifts < 1) or common_gate > 24 or np.any(folded > 1 << 14):
            raise ValueError('folded gate outside native shift/coefficient class')
        result.update(group_members=[list(m) for m in members], group_counts=np.bincount(ids).tolist(),
                      group_table_words=len(members) * 4096, table_evidence=table_evidence,
                      gate_common_shift=common_gate, folded_gate_multiplier_max=int(folded.max()),
                      aligned_product_shift=16, derived_table_max_abs=largest_scaled,
                      product_rounding_checks=len(members) * 4096 * 5)
    return result


def main():
    root = HERE / 's2_evaluation_t256'
    export = EvaluationExport(root)
    pin = candidate_pin(HERE / 'layer25_fix_candidate')
    correction = json.loads((HERE / 'layer25_fix_candidate/complete.json').read_text())
    layers = [audit_layer(root, i, digest, correction) for i, digest in enumerate(export.layer_hashes)]
    result = {'schema': 'zk60-shieldstral-native-intake-audit/1', 'scope': 'COUNTED actual public arrays and exact integer checks; not native import/proof/privacy acceptance',
              'layers': layers, 'all_weight_multiplier_and_shift_classes_pass': True,
              'maximum_groups': max(len(row['group_members']) for row in layers),
              'group_cap_fits_T128_and_T256': all(len(row['group_members']) <= 4 for row in layers),
              'product_rounding_checks': sum(row['product_rounding_checks'] for row in layers),
              'candidate': pin, 'evaluation_export_sha256': sha(root / 'complete.json'), 'audit_source_sha256': sha(__file__),
              'native_pending': ['profile-specific (0,-8) generator/oracle', 'native R13 schema/import', 'native recount', 'proof and review gates'],
              'native_reference_sources': {str(p): sha(p) for p in [
                  NATIVE / 'working-tree/hashline/src/private_block/accuracy_precision.rs',
                  NATIVE / 'working-tree/hashline/src/private_block/accuracy_groups.rs',
                  NATIVE / 'aligned-next/accuracy_aligned.green.rs', NATIVE / 'nowrap_shieldstral_counted.json']}}
    atomic_json(HERE / 'native_candidate_audit.json', result)
    print(json.dumps({k: result[k] for k in ('all_weight_multiplier_and_shift_classes_pass', 'maximum_groups', 'product_rounding_checks')}))


if __name__ == '__main__':
    main()

"""Evaluate the proposed layer25 repair on the retained exact layer24 output.

No vendor/native/frozen export edits. Uses one extra registered SiLU member
(0,-8), at most four groups, and halves the calibrated up-weight scale while
decrementing sh_h. The up shift stays zero, as native R13 currently requires.
Quantization never silently clips. This diagnostic does not establish fidelity.
"""
import json
from pathlib import Path
import pickle
import numpy as np
import calibration_port as P
from accuracy_stack import group_tables, common_shift
from collect_stats import atomic_json, sha
from evaluation_export import EvaluationExport
from probe_layer25 import GateRecorder, CHANNELS
from shieldstral_geometry import Rotation

HERE = Path(__file__).resolve().parent


def extended_groups(stats):
    gm = np.asarray(stats['gate_max'], dtype=np.float64)
    bound = np.minimum(8 * gm, 4 * max(stats['gate_pos'], stats['gate_neg']))
    amb = np.minimum(8 * np.asarray(stats['actc_max']), 4 * stats['act_max'])
    ej = np.zeros(gm.shape, dtype=np.int64)
    for e in range(0, -6, -1):
        ej = np.where(127.0 * 2.0**e >= bound, e, ej)
    unique = sorted(np.unique(ej), reverse=True)
    if len(unique) > 4:
        ej = np.maximum(ej, unique[3])
    registry = set(P.b3.SILU_MEMBERS) | {(0, -8)}
    eoj = np.zeros_like(ej)
    for e in np.unique(ej):
        outs = sorted(o for i,o in registry if i == e)
        if not outs:
            raise ValueError('unregistered group input exponent')
        for j in np.flatnonzero(ej == e):
            eoj[j] = next((o for o in outs if amb[j] <= 32767 * 2.0**o), outs[-1])
        eoj[ej == e] = eoj[ej == e].max()
    members, ids, tables = group_tables(ej, eoj)
    if len(members) > 4 or any(tuple(pair) not in registry for pair in members):
        raise ValueError('group registry/cap violation')
    return ej, eoj, members, ids, tables


def requantize_up(real):
    scaled = np.asarray(real, dtype=np.float64) / 2
    multipliers = np.maximum(1, np.ceil(16 * np.abs(scaled).max(axis=0) / 127))
    if np.any(multipliers > 16):
        raise ValueError('up multiplier exceeds four bits')
    words = np.floor(scaled * (16 / multipliers)[None, :] + .5)
    if not np.isfinite(words).all() or np.any(words < -127) or np.any(words > 127):
        raise ValueError('up requantization would clip')
    return words.astype(np.int8), multipliers.astype(np.int64)


def main():
    out = HERE / 'layer25_fix_candidate'
    out.mkdir(exist_ok=False)
    original = HERE / 'layer25_probe/integer'
    prior = json.loads((original / 'complete.json').read_text())
    if any(d['first_refusal'] for layer in prior['summaries'][:25] for d in layer['diagnostics']):
        raise ValueError('upstream input is refused; cannot test clean layer25 repair')
    source = original / 'layer_24.npy'
    if sha(source) != prior['summaries'][24]['output_sha256']:
        raise ValueError('exact integer layer24 checkpoint changed')
    export = EvaluationExport(HERE / 's2_evaluation_t256')
    model = export.layer(25, 256)
    with (HERE / 'stats_t256/stats.pkl').open('rb') as stream:
        stats = pickle.load(stream)[25]
    ej, eoj, members, gids, tables = extended_groups(stats)
    ck = P.tc.open_checkpoint()
    weights = P.bl.load_layer(ck, 25, Rotation())
    with np.load(export.base / 'layer_25/calibration_scales.npz') as arrays:
        fm = weights['post_attention_layernorm.weight'].astype(np.float64) * arrays['ym']
        scale = arrays['u'] / 2.0**int(model.c['sh_u'])
    real_up = ((weights['mlp.up_proj.weight'] * fm[None, :]) / scale[:, None]).T.astype(np.float32)
    words, mult = requantize_up(real_up)
    del weights, real_up
    ck.close()
    model.w['wu_t'] = words
    model.int['u'] = P.fl.Mat(words)
    model.mult['u'] = (mult.astype(np.float64), 4)
    model.c['sh_h'] -= 1
    model.gate_pc = (ej, eoj, np.empty((0, 0)), False)
    gshift, gfactor = common_shift(model.c['sh_g'] + 8 - 4 + 6 + ej - model.c['silu'][0])
    hshift, hfactor = common_shift(model.c['sh_h'] - 8 - (eoj - model.c['silu'][1]))
    np.savez(out / 'candidate.npz', wu_t=words, mult_u=mult, group_input_exponents=ej,
             group_output_exponents=eoj, group_ids=gids, group_tables=tables,
             gate_group_coefficients=gfactor, product_group_coefficients=hfactor)
    x = np.load(source, allow_pickle=False)
    diagnostics = []
    for i, sequence in enumerate(prior['selected_sequences']):
        rec = GateRecorder()
        output = P.fl.rx_block(x[i:i+1].astype(np.float64), model, frozenset(P.fl.SITES), rec)
        np.save(out / f'seq_{sequence}.npy', output.astype('<i2'), allow_pickle=False)
        diagnostics.append({'sequence': sequence, 'first_refusal': rec.first[0],
                            'violations': {k:dict(v) for k,v in rec.sites.items() if v['violations']},
                            'gate': rec.gate})
    result = {'scope': 'MEASURED candidate repair on the exact full integer path for calibration sequence97; not full calibration/held-out fidelity/native acceptance',
              'source_sha256': sha(__file__), 'original_complete_sha256': sha(original / 'complete.json'),
              'input_sha256': sha(source), 'candidate_sha256': sha(out / 'candidate.npz'),
              'native_changes_needed': 'profile-specific SiLU member (0,-8), no new relation; up remains shift0, product shift15',
              'up_scale_factor': .5, 'constants': model.c, 'group_members': members,
              'group_counts': [int((gids == i).sum()) for i in range(len(members))],
              'target_input_exponents': {str(c):int(ej[c]) for c in CHANNELS},
              'gate_common_shift': gshift, 'product_common_shift': hshift,
              'diagnostics': diagnostics}
    atomic_json(out / 'complete.json', result)
    print(json.dumps({k:result[k] for k in ('group_members','group_counts','target_input_exponents')}
                     | {'refused': [d['sequence'] for d in diagnostics if d['first_refusal']]}), flush=True)


if __name__ == '__main__':
    main()

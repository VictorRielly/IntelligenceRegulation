"""A29: build the UNIFORM-CALIBRATION Shieldstral T128 export (route (b), D77 (2)).

One requantization shift set for all 26 layers -- sh_ao 7, sh_s 7, sh_z 8 -- and one
common gate denominator 20, the four quantities W16R2's range families read
(range16::widths). Every other constant is left per layer: the norm constants
cn_a / cn_m, the product shift sh_h, the exp member e_s and the SiLU members only
change coefficients (see README "The design").

Each change is the cheapest one the arithmetic admits, in this order:
  1. EXACT re-expression (bit-identical words): a shift moves by one and its c2
     multiplier doubles / halves (an even multiplier, or a doubled one that stays in
     its class); the SiLU base member moves together with the gate multipliers and
     sh_h, which leaves every per-channel gate and product shift unchanged.
  2. EXACT up to a FINER rounding: a word is produced at twice / four / eight times
     its old resolution (k for sh_s +1; the FFN product h for sh_z +2 / +3) and the
     consumer's shift absorbs it, inside the word's class (headroom checked on the
     calibration sequences by diag_calib.py before and after).
  3. RE-QUANTIZED rows (only where 1 and 2 cannot apply: an odd multiplier to
     halve, or a doubled one leaving its class): the row's words and multiplier are
     re-derived from the float weights with the export pipeline's own c2 rule
     (fp_lib.apply_multipliers: m = clip(ceil(2^b rowmax / 127), 1, 2^b),
     words = clip(round(W 2^b / m))), at the new scale; clipped words are counted.
  4. Layer 12 only: Astra's paired L12 score candidate (sh_s 6 -> 7 with e_s 1 -> 2
     and the regenerated exp member), which removes the six layer-12 score-range
     refusals of the current export; its output is checked byte for byte against
     results/zk60_astra_20261026/mac_score_native_candidate/native_t128/layer_12.

The output is an independent copy of the current export (results/zk60_shieldstral_
export_20261026/native_low_h24_t128, profile 2ba468f9...) with only the changed
payloads, manifests, profile.json and the token-table binding rewritten.

usage: build_uniform.py --out DIR   (DIR must not exist)
"""
import argparse
import copy
from datetime import datetime, timezone
import json
import math
import shutil
import time

import a29lib as A
import shieldstral_weights as SW
from shieldstral_geometry import Rotation
from accuracy_stack import real_words, group_tables
import sys
sys.path.insert(0, str(A.ASTRA / 'mac_export_recovery'))
from recover_export import portable_read_exact  # noqa: E402

np, P = A.np, A.P
SW.read_exact = portable_read_exact
VARIANT = 'shieldstral-s2-uniform-cal-a29-low-h24-t128-dev1'
TARGET = {'sh_ao': 7, 'sh_s': 7, 'sh_z': 8, 'gate': 20}

# Per-layer plan (see README). 'ao': sh_ao target via m_o; 's_k': sh_s target via m_k
# (k doubled or halved); 's_paired': sh_s with e_s (Astra's L12 rule); 'gate_base':
# new SiLU base member (e_in, e_out) with m_g x 2^-(delta e_in) and the given sh_h;
# a product made 2^k finer (H = sh_h + e_out lowered by k) is absorbed by 'sh_z'
# (raised by k) or by 'd_half' (m_d / 2^k).
PLAN = {
    0: {'ao': 7, 'gate_base': (-5, -13), 'sh_h': 16},
    1: {'ao': 7, 's_k': 7, 'gate_base': (-4, -12), 'sh_h': 15},
    2: {'ao': 7, 's_k': 7, 'gate_base': (-3, -11), 'sh_h': 16, 'sh_z': 8},
    3: {'ao': 7, 's_k': 7},
    4: {'ao': 7, 's_k': 7},
    5: {'ao': 7},
    7: {'ao': 7, 's_k': 7},
    8: {'ao': 7, 's_k': 7},
    10: {'s_k': 7, 'gate_base': (-4, -12), 'sh_h': 16, 'd_half': True},
    12: {'s_paired': 7},
    14: {'gate_base': (-4, -12), 'sh_h': 14},
    16: {'ao': 7, 's_k': 7},
    18: {'ao': 7},
    20: {'ao': 7},
    22: {'ao': 7},
    23: {'s_k': 7, 'gate_base': (-3, -11), 'sh_h': 16},
    24: {'s_k': 7, 'gate_base': (-3, -11), 'sh_h': 15},
    25: {'s_k': 7, 'gate_base': (-2, -11), 'sh_h': 14, 'sh_z': 8},
}
SITE = {'o': ('wo', 0, 8), 'k': ('wk', 0, 5), 'g': ('wg_t', 1, 6), 'd': ('wd_t', 1, 6)}


class Real:
    """Float weights in each site's int8 units at the CURRENT export's scales, from the
    pinned checkpoint and the retained solver scales (the recovery's path)."""

    def __init__(self):
        self.ck = SW.Checkpoint(A.CHECKPOINT_DIR)
        self.R = Rotation()
        self.cache = {}

    def layer(self, index):
        if index not in self.cache:
            base = A.EXPORT_LANE / 'dg_base_t256' / f'layer_{index:02d}'
            ready = A.read(base / 'ready.json')
            A.require(A.sha(base / 'manifest.json') == ready['manifest_sha256'], 'base manifest')
            A.require(A.sha(base / 'calibration_scales.npz') == ready['scales_sha256'], 'base scales')
            constants = A.read(base / 'manifest.json')['constants']
            with np.load(base / 'calibration_scales.npz', allow_pickle=False) as saved:
                diag = {k: saved[k] for k in saved.files}
            W = P.bl.load_layer(self.ck, index, self.R)
            self.cache = {index: real_words(W, {'c': constants}, diag)}
        return self.cache[index]


def c2_fit(real_rows, bits):
    """fp_lib.apply_multipliers' rule on rows (each row one output channel)."""
    rowmax = np.abs(real_rows).max(axis=1)
    m = np.clip(np.ceil((2.0 ** bits) * rowmax / 127.0), 1, 2 ** bits)
    values = np.floor(real_rows * ((2.0 ** bits) / m)[:, None] + 0.5)
    clipped = int(np.count_nonzero(np.abs(values) > 127))
    return np.clip(values, -127, 127).astype(np.int8), m.astype(np.int64), clipped


def rescale_site(layer, arrays, real, site, power, log):
    """Multiply site's effective weight scale so its real words scale by 2^power
    (power +1: the consumer shift went up by one; -1: down by one). Exact where the
    multiplier allows, else the c2 rule on the float row at the new scale."""
    key, axis, bits = SITE[site]
    words, m = arrays[key], arrays['m_' + site].copy()
    rows = words if axis == 0 else words.T
    rows = rows.copy()
    if power > 0:
        new = m * (1 << power)
        exact = new <= (1 << bits)
    else:
        div = 1 << (-power)
        exact = (m % div == 0) & (m // div >= 1)
        new = np.where(exact, m // div, m)
    redo = np.nonzero(~exact)[0]
    clipped = 0
    if len(redo):
        rr = real.layer(layer)[key]
        rr = rr if axis == 0 else rr.T
        # The pipeline's own c2 fit, first at the CURRENT scale: it must give back the
        # export's words and multipliers on these rows (proves the float source).
        w0, m0, _ = c2_fit(rr[redo].astype(np.float64), bits)
        same = float(np.mean(np.all(w0 == rows[redo], axis=1) & (m0 == m[redo])))
        w1, m1, clipped = c2_fit(rr[redo].astype(np.float64) * 2.0 ** power, bits)
        rows[redo] = w1
        new[redo] = m1
        log.update({f'{site}_refit_rows': int(len(redo)), f'{site}_refit_source_reproduced': same,
                    f'{site}_refit_clipped_words': clipped})
    log.update({f'{site}_exact_rows': int(exact.sum()), f'{site}_power': power})
    arrays[key] = rows if axis == 0 else np.ascontiguousarray(rows.T)
    arrays['m_' + site] = new.astype(np.int64)


def transform(layer, man, parent, real, l12_candidate):
    plan = PLAN.get(layer, {})
    c = dict(man['constants'])
    arrays = {name: A.checked_array(parent, spec) for name, spec in man['arrays'].items()}
    log = {'layer': layer, 'plan': {k: list(v) if isinstance(v, tuple) else v for k, v in plan.items()},
           'before': {k: c[k] for k in ('sh_ao', 'sh_s', 'sh_h', 'sh_z', 'exp_e_s', 'silu_member')}}
    groups, ids = arrays['silu_groups'], arrays['silu_group_ids']
    log['before']['gate'] = A.gate_common_shift(c, groups, ids)
    if 'ao' in plan:
        rescale_site(layer, arrays, real, 'o', plan['ao'] - c['sh_ao'], log)
        c['sh_ao'] = plan['ao']
    if 's_k' in plan:
        d = plan['s_k'] - c['sh_s']
        A.require(d in (-1, 1), 'one score step')
        rescale_site(layer, arrays, real, 'k', d, log)
        c['sh_s'] = plan['s_k']
    if 's_paired' in plan:
        d = plan['s_paired'] - c['sh_s']
        A.require(d == 1 and layer == 12, 'paired rule only as Astra L12')
        old, old_digest = P.b3.exp_member(c['exp_e_s'], 128, 9)
        A.require(np.array_equal(arrays['exp'].reshape(-1), old), 'exp table')
        new, new_digest = P.b3.exp_member(c['exp_e_s'] + d, 128, 9)
        arrays['exp'] = new.astype(np.int64).reshape(man['arrays']['exp']['shape'])
        c['sh_s'] += d; c['exp_e_s'] += d
        man['tables']['exp'].update(e_s=c['exp_e_s'], spec_digest=new_digest)
        man['metadata_out_of_proof']['scales']['score_scale'] *= 2.0 ** d
        cand = A.manifest(l12_candidate, 12)[1]
        A.require(A.sha_bytes(arrays['exp'].astype('<i8').tobytes()) == cand['arrays']['exp']['sha256']
                  and cand['constants']['sh_s'] == c['sh_s'] and cand['constants']['exp_e_s'] == c['exp_e_s'],
                  "L12 differs from Astra's paired candidate")
        log['score_paired'] = {'e_s': [c['exp_e_s'] - d, c['exp_e_s']], 'equals_astra_l12_candidate': True}
    if 'gate_base' in plan:
        ein0, eout0 = c['silu_member']
        ein1, eout1 = plan['gate_base']
        A.require(ein1 <= ein0, 'base e_in only moves down')
        H0, H1 = c['sh_h'] + eout0, plan['sh_h'] + eout1
        k = H0 - H1
        A.require(k >= 0, 'product never coarser')
        rescale_site(layer, arrays, real, 'g', ein0 - ein1, log)
        c['silu_member'] = [ein1, eout1]; c['sh_h'] = plan['sh_h']
        man['metadata_out_of_proof']['scales'].update(gate_scale=2.0 ** ein1, act_scale=2.0 ** eout1)
        log['product_finer_bits'] = k
        if k:
            if 'sh_z' in plan:
                A.require(plan['sh_z'] - c['sh_z'] == k, 'sh_z absorbs exactly the finer product')
                c['sh_z'] = plan['sh_z']
            else:
                A.require(plan.get('d_half'), 'finer product needs a consumer')
                rescale_site(layer, arrays, real, 'd', -k, log)
    A.require(c['sh_ao'] == TARGET['sh_ao'] and c['sh_s'] == TARGET['sh_s'] and c['sh_z'] == TARGET['sh_z'],
              f'L{layer}: shift set not uniform: {c}')
    gate = A.gate_common_shift(c, groups, ids)
    A.require(gate == TARGET['gate'], f'L{layer}: gate {gate}')
    plo, phi = A.product_shifts(c, groups, ids)
    A.require(0 <= plo and phi <= 13 and 13 <= c['sh_h'] <= 16, f'L{layer}: product shifts {plo}..{phi}')
    ein = c['silu_member'][0]
    own = c['sh_g'] + 10 + groups[ids][:, 0] - ein
    A.require(np.all(arrays['m_g'] * (2 ** (gate - own)) <= 1 << 14) and np.all((arrays['m_g'] >= 1) & (arrays['m_g'] <= 64)),
              'gate fold class')
    for site, (_, _, bits) in SITE.items():
        mm = arrays['m_' + site]
        A.require(np.all((mm >= 1) & (mm <= 1 << bits)), f'multiplier class {site}')
    log['after'] = {k: c[k] for k in ('sh_ao', 'sh_s', 'sh_h', 'sh_z', 'exp_e_s', 'silu_member')}
    log['after']['gate'] = gate
    members, gids, tables = group_tables(*A.decode_groups(groups, ids))
    A.require(np.array_equal(tables, arrays['act']), 'group tables unchanged')
    man['constants'] = c
    return arrays, log


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out', type=A.Path, required=True)
    a = ap.parse_args()
    t0 = time.time()
    src = A.BASELINE
    A.require(A.sha(src / 'profile.json') == A.BASELINE_PROFILE_SHA, 'source profile')
    A.require(shutil.disk_usage(A.ART).free > 50 * 2 ** 30, 'disk floor')
    source_profile = A.read(src / 'profile.json')
    profile = copy.deepcopy(source_profile)
    a.out.mkdir(parents=True, exist_ok=False)
    real = Real()
    logs, layers, changed = [], [], []
    try:
        for index in range(A.LAYERS):
            parent, man = A.manifest(src, index)
            man = copy.deepcopy(man)
            dst = a.out / parent.name; dst.mkdir()
            man['variant'] = VARIANT
            arrays, log = transform(index, man, parent, real, A.L12_CANDIDATE) if index in PLAN else (None, {'layer': index, 'plan': {}})
            if index not in PLAN:
                c = man['constants']
                g = A.array(parent, man['arrays']['silu_groups']); i = A.array(parent, man['arrays']['silu_group_ids'])
                A.require((c['sh_ao'], c['sh_s'], c['sh_z'], A.gate_common_shift(c, g, i)) == (7, 7, 8, 20), f'L{index} not uniform')
            for name, spec in man['arrays'].items():
                target = dst / spec['file']
                if arrays is not None:
                    data = np.ascontiguousarray(arrays[name]).astype(np.dtype(spec['dtype']).newbyteorder('<')).tobytes()
                    digest = A.sha_bytes(data)
                    if digest != spec['sha256']:
                        A.require(list(arrays[name].shape) == spec['shape'], 'shape')
                        target.write_bytes(data)
                        spec['sha256'] = digest
                        changed.append(f'{dst.name}/{spec["file"]}')
                        continue
                shutil.copyfile(parent / spec['file'], target)
                A.require(A.sha(target) == spec['sha256'], 'copy digest')
            A.record(dst / 'manifest.json', man)
            layers.append({'layer': index, 'dir': dst.name, 'manifest_sha256': A.sha(dst / 'manifest.json')})
            logs.append(log)
            print(json.dumps(log), flush=True)
    finally:
        real.ck.close()
    pc = profile['profile_constants']
    for k in ('sh_ao', 'sh_s', 'sh_z'):
        pc[k] = TARGET[k]
    profile['per_layer_constants_differ'] = sorted(k for k, v in pc.items() if v is None)
    profile.update(variant=VARIANT, layers=layers,
                   calibration_tool={'path': 'results/zk60_a29_uniform_calibration_20261110/build_uniform.py',
                                     'sha256': A.sha(A.Path(__file__))},
                   uniform_calibration_derivation={
                       'lane': 'A29 (D77 (2), route (b))', 'source_profile_sha256': A.BASELINE_PROFILE_SHA,
                       'uniform': TARGET, 'per_layer_coefficients': ['norm_cn_a', 'norm_cn_m', 'sh_h', 'exp_e_s', 'silu_member'],
                       'builder_sha256': A.sha(A.Path(__file__)), 'a29lib_sha256': A.sha(A.HERE / 'a29lib.py')},
                   scope='A29 accuracy experiment only: unregistered public development export; no profile, proof, privacy or production claim')
    (a.out / 'token_io').mkdir()
    token_done = A.read(src / 'token_io/complete.json')
    for name, digest in token_done['files'].items():
        shutil.copyfile(src / 'token_io' / name, a.out / 'token_io' / name)
        A.require(A.sha(a.out / 'token_io' / name) == digest, 'token copy')
    shutil.copyfile(src / 'rotation_sign.bin', a.out / 'rotation_sign.bin')
    A.require(A.sha(a.out / 'rotation_sign.bin') == profile['metadata_out_of_proof']['rotation']['sign_sha256'], 'rotation')
    A.record(a.out / 'profile.json', profile)
    profile_sha = A.sha(a.out / 'profile.json')
    A.record(a.out / 'token_io/complete.json', {**token_done, 'profile_sha256': profile_sha,
             'scope': 'same tied public arrays, bound to the A29 uniform-calibration export'})
    result = {'at': datetime.now(timezone.utc).isoformat(), 'profile_sha256': profile_sha,
              'source_profile_sha256': A.BASELINE_PROFILE_SHA, 'variant': VARIANT, 'uniform': TARGET,
              'changed_payloads': changed, 'layers': logs, 'seconds': round(time.time() - t0, 1)}
    A.record(a.out / 'build.json', result)
    print(json.dumps({k: result[k] for k in ('profile_sha256', 'seconds')} | {'changed': len(changed)}), flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

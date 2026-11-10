"""A29 design-time diagnostics on the 192 CALIBRATION sequences only (never the
4,872 evaluation rows): run one or more native-format exports through the
frozen S2 evaluator (rx_block, every range check on) next to the float model in
the same rotated basis, and record per layer
  * every range-checked site's min / max against its class (headroom) and refusals,
  * the relative error of the integer residual (x s_x) against the float residual,
and at the last prompt token of each sequence the classifier margin of both
integer heads and of the float model (logit yes - logit no).

usage: diag_calib.py --out DIR --export NAME=PATH [--export NAME=PATH ...] [--float]
Writes DIR/summary.json and DIR/margins.npz (outside the repository).
"""
import argparse
import json
import time

import a29lib as A
from shieldstral_geometry import Rotation, rope_tables
from signed_word_domain import S2RecPos
import shieldstral_weights as SW
import sys
sys.path.insert(0, str(A.ASTRA / 'mac_export_recovery'))
from recover_export import portable_read_exact  # noqa: E402

np, P = A.np, A.P
SW.read_exact = portable_read_exact  # macOS pread seam, exactly as Astra's recovery
SITES = frozenset(P.fl.SITES)


def merge(into, rec):
    for site, s in rec.sites.items():
        t = into.setdefault(site, {'violations': 0, 'max': -(1 << 62), 'min': 1 << 62, 'lo': s['lo'], 'hi': s['hi']})
        t['violations'] += s['violations']
        t['max'] = max(t['max'], s['max'])
        t['min'] = min(t['min'], s['min'])


def fill(s):
    return max(s['max'] / s['hi'] if s['hi'] > 0 else 0.0, s['min'] / s['lo'] if s['lo'] < 0 else 0.0)


def int_heads(x_last, token_io):
    table = A.read(token_io / 'classifier.json'); norm = table['final_norm']
    margin = np.fromfile(token_io / 'margin_int16.bin', dtype='<i2').astype(np.int64)
    out = {}
    for choice, cn in (('refusal_free', norm['cn']), ('calibrated', table['final_norm_candidates']['cn_calibrated'])):
        values, refused = [], []
        for x in x_last:
            rec = P.tc.Rec(1)
            y, _ = P.tc.i_norm(x.astype(np.int64).reshape(1, 1, A.D), np.full(A.D, norm['g0'], dtype=np.int8), cn,
                               norm['tn'], norm['ceps'], 32, rec, 'final_norm', 0, True)
            scale = float(P.b3.norm_K(cn, norm['tn']) / norm['g0'] * table['margin_vector']['scale'])
            values.append(int(y.reshape(A.D) @ margin) * scale)
            refused.append(rec.first[0] is not None)
        out[choice] = (np.array(values), np.array(refused))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', required=True)
    ap.add_argument('--export', action='append', required=True)
    ap.add_argument('--float', action='store_true')
    ap.add_argument('--batch', type=int, default=8)
    a = ap.parse_args()
    out = A.Path(a.out); out.mkdir(parents=True, exist_ok=True)
    exports = dict(e.split('=', 1) for e in a.export)
    rows, offsets, ids = A.inputs('calibration')
    N, T = len(rows), 256
    ids = ids.reshape(N, T)
    last = np.array([r['length'] - 1 for r in rows])
    A.require(np.all((last >= 0) & (last < T)), 'prompt lengths')
    t0 = time.time()
    xi = {}
    for name, path in exports.items():
        emb = np.memmap(A.Path(path) / 'token_io/embedding_int16.bin', dtype='<i2', mode='r').reshape(-1, A.D)
        xi[name] = np.asarray(emb[ids.reshape(-1)]).reshape(N, T, A.D).copy()
    s_x = A.read(A.Path(next(iter(exports.values()))) / 'profile.json')['metadata_out_of_proof']['residual_scales_in'][0]
    if a.float:
        ck = SW.Checkpoint(A.CHECKPOINT_DIR)
        P.fl._CK = ck
        R = Rotation()
        xf = np.empty((N, T, A.D), dtype=np.float32)
        for s0 in range(0, N, a.batch):
            xf[s0:s0 + a.batch] = R.fwd(P.fl.emb_rows(ids[s0:s0 + a.batch])).astype(np.float32)
        cos, sin = P.tc.rope_f32(T)
    summary = {'scope': 'design-time diagnostics on the 192 calibration sequences only; not held-out',
               'exports': {k: str(v) for k, v in exports.items()}, 'float': a.float, 'layers': []}
    for layer in range(A.LAYERS):
        tick = time.time(); row = {'layer': layer}
        if a.float:
            W = P.bl.load_layer(ck, layer, R)
            for s0 in range(0, N, a.batch):
                xf[s0:s0 + a.batch] = P.tc.f_block(xf[s0:s0 + a.batch], W, cos, sin)
            del W
        for name, path in exports.items():
            model = A.load_model(path, layer)
            model.rope_int = tuple(t.astype(np.float64) for t in rope_tables(T, int(model.c['f_ro'])))
            sites, refused = {}, np.zeros(N, dtype=bool)
            for s0 in range(0, N, a.batch):
                x = xi[name][s0:s0 + a.batch].astype(np.float64)
                rec = S2RecPos(len(x))
                y = P.fl.rx_block(x, model, SITES, rec)
                A.require(np.isfinite(y).all() and np.all(y >= -32768) and np.all(y <= 32767), 'residual not int16')
                xi[name][s0:s0 + a.batch] = y.astype('<i2')
                merge(sites, rec)
                refused[s0:s0 + len(x)] = [f is not None for f in rec.first]
            del model
            entry = {'refused_sequences': int(refused.sum()),
                     'sites': {k: {**v, 'fill': round(fill(v), 4)} for k, v in sorted(sites.items())}}
            if a.float:
                num = den = 0.0
                for s0 in range(0, N, a.batch):
                    d = xi[name][s0:s0 + a.batch].astype(np.float64) * s_x - xf[s0:s0 + a.batch]
                    num += float((d * d).sum()); den += float((xf[s0:s0 + a.batch].astype(np.float64) ** 2).sum())
                entry['rel_err_vs_float'] = (num / den) ** 0.5
            row[name] = entry
        row['seconds'] = round(time.time() - tick, 1)
        summary['layers'].append(row)
        print(json.dumps({'layer': layer, 'seconds': row['seconds'],
                          **{n: {'refused': row[n]['refused_sequences'], 'rel': row[n].get('rel_err_vs_float')}
                             for n in exports}}), flush=True)
        A.record(out / 'summary.json', summary)
    arrays = {'last': last}
    for name, path in exports.items():
        heads = int_heads(xi[name][np.arange(N), last], A.Path(path) / 'token_io')
        for head, (m, r) in heads.items():
            arrays[f'{name}__{head}'] = m; arrays[f'{name}__{head}__refused'] = r
    if a.float:
        prof = A.read(A.Path(next(iter(exports.values()))) / 'profile.json')['classifier_margin_parameters']
        raw = ck.refs['model.embed_tokens.weight'].bf16_rows()
        pair = (raw[np.array([prof['yes_id'], prof['no_id']])].astype(np.uint32) << 16).view(np.float32).astype(np.float64)
        normw = P.tc.tensor_f32(ck.refs['model.norm.weight']).astype(np.float64)
        v = R.fwd((pair[0] - pair[1]) * normw)
        xl = xf[np.arange(N), last]
        xhat = P.tc.f_xhat(xl, P.tc.GEO.eps).astype(np.float64)
        arrays['float'] = xhat @ v
        ck.close()
    np.savez(out / 'margins.npz', **arrays)
    res = {}
    for name in exports:
        res[name] = {}
        for head in ('refusal_free', 'calibrated'):
            m = arrays[f'{name}__{head}']
            d = {'head_refused': int(arrays[f'{name}__{head}__refused'].sum()), 'positive': int((m > 0).sum())}
            if a.float:
                f = arrays['float']; err = np.abs(m - f)
                d.update(sign_agreement_with_float=float(((m > 0) == (f > 0)).mean()),
                         abs_err_vs_float={str(q): float(np.quantile(err, q)) for q in (.5, .9, .99, 1)})
            res[name][head] = d
    summary['margins'] = res
    summary['seconds_total'] = round(time.time() - t0, 1)
    A.record(out / 'summary.json', summary)
    print(json.dumps(res), flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

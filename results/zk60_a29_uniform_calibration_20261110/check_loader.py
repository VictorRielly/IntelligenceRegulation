"""A29 harness check: a29lib.load_model on the CURRENT export equals Astra's pinned
portable evaluator for all 26 layers, and reproduces the original Mac replay's
residual bytes on a prefix of the A1 items at layers 0, 12 and 25.

Reads Astra's directories; writes only under the A29 artifacts directory.
"""
import json
from pathlib import Path
import sys
import time

import a29lib as A

sys.path.insert(0, str(A.ASTRA / 'mac_evaluation'))
import portable_model  # noqa: E402  (Astra's pinned loader; read-only use)
import evaluate_verdicts_cached as original  # noqa: E402
from recover_export import portable_read_exact  # noqa: E402

np = A.np
original.read_exact = portable_read_exact  # the same macOS I/O seam Astra's replay uses
RUN = A.ASTRA / 'mac_evaluation/full'
OUT = A.ART / 'check_loader'


def compare_models(index):
    mine = A.load_model(A.BASELINE, index, verify=True, cache=False)
    ref = portable_model.layer(index)
    diff = {k: (mine.c.get(k), ref.c.get(k)) for k in set(mine.c) | set(ref.c) if mine.c.get(k) != ref.c.get(k)}
    A.require(not diff, f'L{index}: constants differ: {diff}')
    for name in ('wq', 'wk', 'wv', 'wo', 'gamma_a', 'gamma_m', 'wg_t', 'wu_t', 'wd_t'):
        A.require(np.array_equal(mine.w[name], ref.w[name]), f'L{index}: {name} differs')
    A.require(np.array_equal(mine.exp_t, ref.exp_t) and mine.lam == ref.lam, f'L{index}: exp differs')
    A.require(mine.mods == ref.mods, f'L{index}: mods differ')
    for site in A.BITS:
        A.require(np.array_equal(mine.mult[site][0], ref.mult[site][0]) and mine.mult[site][1] == ref.mult[site][1],
                  f'L{index}: multiplier {site} differs')
    for a, b in zip(mine.gate_pc[:2], ref.gate_pc[:2]):
        A.require(np.array_equal(a, b), f'L{index}: group exponents differ')
    return {'layer': index, 'equal': True}


def residual_parity(index, items):
    rows, offsets, ids = A.inputs('evaluation')
    rows, offsets = rows[:items], offsets[:items + 1].copy()
    stage = OUT / f'layer_{index:02d}_first{items}'
    A.require(not stage.exists(), 'fresh parity stage required')
    source = RUN / ('input' if index == 0 else f'layer_{index - 1:02d}') / 'residual.bin'
    model = A.load_model(A.BASELINE, index)
    t0 = time.time()
    done = original.execute_layer(stage, source, rows, offsets, ids, model, None, time.time() + 3600)
    A.require(done, 'parity stage incomplete')
    n = int(offsets[-1]) * A.D * 2
    with (RUN / f'layer_{index:02d}' / 'residual.bin').open('rb') as f:
        want = f.read(n)
    got = (stage / 'residual.bin').read_bytes()
    A.require(got == want, f'L{index}: residual bytes differ from the original Mac replay')
    diags = [d for e in original.read_journal(stage / 'journal.jsonl') for d in e['diagnostics']]
    ref = [d for e in original.read_journal(RUN / f'layer_{index:02d}' / 'journal.jsonl') for d in e['diagnostics']][:items]
    A.require(diags == ref, f'L{index}: diagnostics differ')
    (stage / 'residual.bin').unlink()
    return {'layer': index, 'items': items, 'tokens': int(offsets[-1]), 'bytes_equal': True,
            'diagnostics_equal': True, 'seconds': round(time.time() - t0, 2)}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    report = {'models': [compare_models(i) for i in range(A.LAYERS)]}
    print(json.dumps({'models_equal': len(report['models'])}), flush=True)
    report['residual_parity'] = [residual_parity(i, 64) for i in (0, 12, 25)]
    print(json.dumps(report['residual_parity']), flush=True)
    A.record(A.HERE / 'check_loader.json', {**report, 'scope': 'harness equivalence on the current export; no new model'})
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

"""A29: one resumable stage of the full A1 numerical evaluation (4,872 policy/item rows,
702,006 tokens, no truncation) of a native-format export, with the export lane's frozen
evaluator: evaluate_verdicts_cached.execute_layer (every range check on; a refused
row stays recorded) and score_final (both heads). Only the export directory differs
from Astra's Mac replay (results/zk60_astra_20261026/mac_evaluation/replay.py).

To fit the shared disk, a stage's INPUT residual is deleted once the stage's own
output is complete and digest-checked; journals, diagnostics and ready.json records
(with the deleted residual's SHA-256) are kept. score_final reads only layer 25's
residual and every journal.

usage: eval_stage.py --export DIR --run DIR (input | 0..25 | finish)
"""
import argparse
import json
import sys
import time

import a29lib as A
import evaluate_verdicts_cached as original
sys.path.insert(0, str(A.ASTRA / 'mac_export_recovery'))
from recover_export import portable_read_exact  # noqa: E402

np = A.np
original.read_exact = portable_read_exact  # the macOS pread seam of Astra's replay; arithmetic frozen


def plan(export, run, rows, offsets):
    p = {'schema': 'a29-a1-numerical-replay/1', 'export_profile_sha256': A.sha(export / 'profile.json'),
         'input_sha256': A.sha(A.EXPORT_LANE / 'evaluation_inputs/input.json'), 'items': len(rows),
         'tokens': int(offsets[-1]), 'evaluator_sha256': A.sha(A.EXPORT_LANE / 'evaluate_verdicts_cached.py'),
         'a29lib_sha256': A.sha(A.HERE / 'a29lib.py'), 'stage_tool_sha256': A.sha(A.Path(__file__)),
         'numpy': np.__version__,
         'scope': 'A29 held-out A1 numerical evaluation of an export; no native proof or privacy acceptance'}
    if (run / 'run.json').exists():
        A.require(A.read(run / 'run.json') == p, 'run plan changed')
    else:
        A.record(run / 'run.json', p)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--export', type=A.Path, required=True)
    ap.add_argument('--run', type=A.Path, required=True)
    ap.add_argument('--minutes', type=float, default=25)
    ap.add_argument('stage')
    a = ap.parse_args()
    rows, offsets, ids = A.inputs('evaluation')
    a.run.mkdir(parents=True, exist_ok=True)
    plan(a.export, a.run, rows, offsets)
    token_io = a.export / 'token_io'
    for name, digest in A.read(token_io / 'complete.json')['files'].items():
        A.require(A.sha(token_io / name) == digest, 'token table digest')
    if a.stage == 'finish':
        for i in range(A.LAYERS):
            A.require((a.run / f'layer_{i:02d}' / 'ready.json').exists(), f'layer {i} incomplete')
        last = a.run / f'layer_{A.LAYERS - 1:02d}'
        A.require(A.sha(last / 'residual.bin') == A.read(last / 'ready.json')['residual_sha256'], 'final residual')
        verdicts = original.score_final(a.run, rows, offsets, token_io)
        A.record(a.run / 'complete.json', {
            'items': len(rows), 'verdicts_sha256': A.sha(a.run / 'verdicts.json'), 'run_sha256': A.sha(a.run / 'run.json'),
            'stack_refused': sum(r['stack_refused'] for r in verdicts),
            'head_refused': {h: sum(r['heads'][h]['head_refused'] for r in verdicts) for h in ('refusal_free', 'calibrated')},
            'native_proof': False})
        print(json.dumps({'finish': True, 'stack_refused': sum(r['stack_refused'] for r in verdicts)}), flush=True)
        return 0
    index = -1 if a.stage == 'input' else int(a.stage)
    name = 'input' if index == -1 else f'layer_{index:02d}'
    stage = a.run / name
    if (stage / 'ready.json').exists():
        print(json.dumps({'stage': name, 'already': True}), flush=True)
        return 0
    source = None
    if index >= 0:
        prev = a.run / ('input' if index == 0 else f'layer_{index - 1:02d}')
        source = prev / 'residual.bin'
        A.require(A.sha(source) == A.read(prev / 'ready.json')['residual_sha256'], 'previous residual digest')
    model = None if index == -1 else A.load_model(a.export, index)
    t0 = time.time()
    done = original.execute_layer(stage, source, rows, offsets, ids, model,
                                  token_io / 'embedding_int16.bin' if index == -1 else None, time.time() + a.minutes * 60)
    if not done:
        print(json.dumps({'stage': name, 'checkpoint': True, 'seconds': round(time.time() - t0, 1)}), flush=True)
        return 3
    entries = original.read_journal(stage / 'journal.jsonl')
    diags = [d for e in entries for d in e['diagnostics']]
    A.require([d['item'] for d in diags] == list(range(len(rows))), 'journal coverage')
    refused = sum(d['refused'] for d in diags)
    if source is not None:
        source.unlink()  # its digest stays in the previous stage's ready.json
    print(json.dumps({'stage': name, 'complete': True, 'refused_items': refused,
                      'seconds': round(time.time() - t0, 1)}), flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

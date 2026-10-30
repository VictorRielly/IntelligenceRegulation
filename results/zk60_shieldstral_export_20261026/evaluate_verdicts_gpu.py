"""One GPU layer pass per invocation; reuse the immutable CPU journal/scorer.

Each layer is a separate guarded process so device memory drains between passes.
This runner has its own explicit provenance; it never resumes a CPU run in place.
"""
import argparse
import json
from pathlib import Path
import time

import numpy as np

from amended_evaluator import apply_candidate, candidate_pin
from collect_stats import atomic_json, sha
from evaluation_export import EvaluationExport
from evaluate_verdicts import execute_layer, score_final
from gpu_integer import configure, prepare
from shieldstral_geometry import LAYERS
from signed_word_domain import DOMAIN

HERE = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--input', type=Path, default=HERE / 'evaluation_inputs')
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument('--limit', type=int, default=8)
    selection.add_argument('--all', action='store_true')
    parser.add_argument('--max-minutes', type=float, default=5)
    args = parser.parse_args()
    if not 0 <= args.layer < LAYERS or not 0 < args.max_minutes <= 10 or args.limit <= 0:
        raise ValueError('invalid layer, limit or timebox')
    data = json.loads((args.input / 'input.json').read_text())
    for name, key in (('ids.npy', 'ids_sha256'), ('offsets.npy', 'offsets_sha256')):
        if sha(args.input / name) != data[key]:
            raise ValueError('evaluation inputs changed')
    original_ids = np.load(args.input / 'ids.npy', allow_pickle=False)
    original_offsets = np.load(args.input / 'offsets.npy', allow_pickle=False)
    indexes = list(range(len(data['rows']))) if args.all else list(range(min(args.limit, len(data['rows']))))
    if not indexes:
        raise ValueError('empty selection')
    rows = [data['rows'][i] for i in indexes]
    offsets = np.concatenate(([0], np.array([r['T'] for r in rows]).cumsum()))
    ids = np.concatenate([original_ids[original_offsets[i]:original_offsets[i+1]] for i in indexes])
    export_dir = HERE / 's2_evaluation_t256'
    export = EvaluationExport(export_dir)
    token_io = HERE / 'dg_r12b_t256/token_io'
    tables = json.loads((token_io / 'complete.json').read_text())
    for name, digest in tables['files'].items():
        if sha(token_io / name) != digest:
            raise ValueError('tied token tables changed')
    if sha(token_io.parent / 'profile.json') != tables['profile_sha256']:
        raise ValueError('table profile changed')
    profile = json.loads((token_io.parent / 'profile.json').read_text())
    table = json.loads((token_io / 'classifier.json').read_text())
    if table['final_norm'] != profile['token_io_parameters']['classifier_final_norm'] or table['bos'] != profile['token_io_parameters']['bos']:
        raise ValueError('classifier constants differ from profile')
    amendment = candidate_pin(HERE / 'layer25_fix_candidate')
    torch = configure()
    plan = {'schema': 'zk60-shieldstral-eval-run/1', 'input_sha256': sha(args.input / 'input.json'),
            'evaluation_export_sha256': sha(export_dir / 'complete.json'), 'token_io_sha256': sha(token_io / 'complete.json'),
            'tool_sha256': sha(__file__), 'baseline_tool_sha256': sha(HERE / 'evaluate_verdicts.py'),
            'gpu_engine_sha256': sha(HERE / 'gpu_integer.py'), 'torch_version': torch.__version__,
            'indexes': indexes, 'items': len(rows), 'tokens': int(offsets[-1]),
            'word_domain_amendment': DOMAIN, 'word_domain_source_sha256': sha(HERE / 'signed_word_domain.py'),
            'layer25_calibration_candidate': amendment, 'input_scope': data.get('scope'),
            'scope': 'selected full A1 item sets' if args.all else 'smoke subset'}
    args.out.mkdir(parents=True, exist_ok=True)
    if (args.out / 'run.json').exists():
        if json.loads((args.out / 'run.json').read_text()) != plan:
            raise ValueError('GPU replay resume plan changed')
    else:
        atomic_json(args.out / 'run.json', plan)
    deadline = time.time() + args.max_minutes * 60
    if args.layer == 0:
        if not execute_layer(args.out / 'input', None, rows, offsets, ids, None, token_io / 'embedding_int16.bin', deadline):
            return 3
    previous = args.out / ('input' if args.layer == 0 else f'layer_{args.layer-1:02d}')
    if not (previous / 'ready.json').exists():
        raise ValueError('previous layer is incomplete')
    execute_layer(previous, None, rows, offsets, ids, None, None, deadline)
    stage = args.out / f'layer_{args.layer:02d}'
    model = None
    if not (stage / 'ready.json').exists():
        model = export.layer(args.layer, export.profile['T'])
        if args.layer == 25:
            model = apply_candidate(model, HERE / 'layer25_fix_candidate')
        prepare(model)
    tick = time.perf_counter()
    complete = execute_layer(stage, previous / 'residual.bin', rows, offsets, ids, model, None, deadline)
    torch.cuda.synchronize()
    metrics = {'layer': args.layer, 'stage_complete': complete, 'seconds': time.perf_counter() - tick,
               'gpu_peak_allocated_bytes': torch.cuda.max_memory_allocated(), 'gpu_peak_reserved_bytes': torch.cuda.max_memory_reserved(),
               'device': torch.cuda.get_device_name(), 'run_sha256': sha(args.out / 'run.json')}
    atomic_json(args.out / f'gpu_pass_{args.layer:02d}_{time.time_ns()}.json', metrics)
    print(json.dumps(metrics), flush=True)
    if not complete:
        return 3
    if args.layer == LAYERS - 1:
        if any(not (args.out / f'layer_{i:02d}/ready.json').exists() for i in range(LAYERS)):
            raise ValueError('final scoring lacks a complete layer')
        result = score_final(args.out, rows, offsets, token_io)
        atomic_json(args.out / 'complete.json', {'items': len(rows), 'verdicts_sha256': sha(args.out / 'verdicts.json'),
                    'run_sha256': sha(args.out / 'run.json'), 'stack_refused': sum(r['stack_refused'] for r in result)})
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

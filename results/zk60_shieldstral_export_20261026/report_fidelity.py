"""Audit full replay coverage before rendering the A2 numerical report.

This reader never repairs or truncates a live journal. A progress snapshot is
explicitly incomplete; acceptance requires every residual hash, every sequence
at every layer, final verdicts, and the full paired A1 analysis.
"""
import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path

import numpy as np

from collect_stats import atomic_json, sha
from shieldstral_geometry import D, LAYERS

HERE = Path(__file__).resolve().parent
TEMPLATES = {f'{p}_{c}' for p in ('cat', 'mod') for c in ('sexual', 'violence', 'hate')}


def inventory_inputs(directory, plan):
    data = json.loads((directory / 'input.json').read_text())
    if sha(directory / 'input.json') != plan['input_sha256']:
        raise ValueError('replay input manifest changed')
    for name, key in (('ids.npy', 'ids_sha256'), ('offsets.npy', 'offsets_sha256')):
        if sha(directory / name) != data[key]:
            raise ValueError('replay token inputs changed')
    ids = np.load(directory / 'ids.npy', allow_pickle=False)
    offsets = np.load(directory / 'offsets.npy', allow_pickle=False)
    rows = data['rows']
    if plan['indexes'] != list(range(len(rows))) or plan['items'] != len(rows):
        raise ValueError('full replay omitted, reordered or duplicated an input')
    if offsets.shape != (len(rows) + 1,) or offsets[0] != 0 or offsets[-1] != len(ids):
        raise ValueError('invalid replay token offsets')
    if not np.array_equal(np.diff(offsets), [r['T'] for r in rows]) or np.any(np.diff(offsets) <= 0):
        raise ValueError('replay lengths differ from token offsets')
    if plan['tokens'] != len(ids):
        raise ValueError('replay token count differs')
    calibration = all(r['dataset'] == 'calibration' for r in rows)
    if calibration:
        original = HERE / 'calibration_t256'
        source = json.loads((original / 'input.json').read_text())
        original_ids = np.load(original / 'ids.npy', allow_pickle=False)
        if sha(original / 'input.json') != data['calibration_input_sha256']:
            raise ValueError('original calibration manifest changed')
        if hashlib.sha256(original_ids.astype('<i8').tobytes()).hexdigest() != source['ids_sha256']:
            raise ValueError('original calibration tokens changed')
        if len(rows) != source['sequences'] or not np.array_equal(ids, original_ids.reshape(-1)):
            raise ValueError('calibration replay differs from all original padded rows')
        if [r['calibration_sequence'] for r in rows] != list(range(source['sequences'])):
            raise ValueError('calibration sequence identities differ')
    else:
        groups = Counter((r['dataset'], r['template']) for r in rows)
        expected = {(d, t): n for d, n in (('toxicchat', 200), ('openai_mod', 612)) for t in TEMPLATES}
        if groups != expected or len({(r['dataset'], r['template'], r['id']) for r in rows}) != len(rows):
            raise ValueError('benchmark does not contain all 12 unique A1 sets')
    return rows, offsets, calibration


def audit_journal(raw, offsets):
    """Count only durable, newline-terminated entries; require exact identities."""
    end = raw.rfind(b'\n') + 1
    entries = [json.loads(line) for line in raw[:end].splitlines()]
    next_item = 0
    refused = set()
    sites = Counter()
    for entry in entries:
        stop = entry['end_item']
        if entry['first_item'] != next_item or not next_item < stop < len(offsets):
            raise ValueError('noncontiguous or invalid journal item range')
        if (entry['byte_start'], entry['byte_end']) != (int(offsets[next_item]) * D * 2, int(offsets[stop]) * D * 2):
            raise ValueError('journal byte range differs from token coverage')
        if [r['item'] for r in entry['diagnostics']] != list(range(next_item, stop)):
            raise ValueError('journal omitted or duplicated sequence diagnostics')
        for diagnostic in entry['diagnostics']:
            bad = diagnostic['violations']
            if type(diagnostic['refused']) is not bool or diagnostic['refused'] != bool(bad):
                raise ValueError('refusal flag disagrees with range diagnostics')
            if (diagnostic['first_site'] is not None) != diagnostic['refused']:
                raise ValueError('first refusal site disagrees with refusal flag')
            if bad:
                refused.add(diagnostic['item'])
                for site, counts in bad.items():
                    if type(counts['violations']) is not int or counts['violations'] <= 0:
                        raise ValueError('invalid range violation count')
                    sites[site] += counts['violations']
        next_item = stop
    return {'items': next_item, 'refused_items': sorted(refused), 'violations_by_site': dict(sites),
            'incomplete_journal_tail': end != len(raw)}


def verify_model_artifacts(plan):
    """Full audit only: bind retained results to the actual calibration bytes."""
    from amended_evaluator import candidate_pin
    from evaluation_export import EvaluationExport
    from signed_word_domain import DOMAIN

    export_dir = HERE / 's2_evaluation_t256'
    token_dir = HERE / 'dg_r12b_t256/token_io'
    if sha(export_dir / 'complete.json') != plan['evaluation_export_sha256']:
        raise ValueError('numerical export completion record changed')
    export = EvaluationExport(export_dir)
    for index, expected in enumerate(export.layer_hashes):
        directory = export_dir / f'layer_{index:02d}'
        if sha(directory / 'ready.json') != expected:
            raise ValueError('numerical layer manifest changed')
        for name, digest in json.loads((directory / 'ready.json').read_text())['files'].items():
            if sha(directory / name) != digest:
                raise ValueError('numerical layer data changed')
    if sha(token_dir / 'complete.json') != plan['token_io_sha256']:
        raise ValueError('tied table completion record changed')
    tables = json.loads((token_dir / 'complete.json').read_text())
    for name, digest in tables['files'].items():
        if sha(token_dir / name) != digest:
            raise ValueError('tied table bytes changed')
    if sha(token_dir.parent / 'profile.json') != tables['profile_sha256']:
        raise ValueError('tied table profile changed')
    if candidate_pin(HERE / 'layer25_fix_candidate') != plan['layer25_calibration_candidate']:
        raise ValueError('layer25 calibration or loader changed')
    if plan['word_domain_amendment'] != DOMAIN or sha(HERE / 'signed_word_domain.py') != plan['word_domain_source_sha256']:
        raise ValueError('integer word domains changed')
    runner = HERE / ('evaluate_verdicts_gpu.py' if 'gpu_engine_sha256' in plan else
                     'evaluate_verdicts_cached.py' if 'matrix_cache_sha256' in plan else 'evaluate_verdicts.py')
    if sha(runner) != plan['tool_sha256']:
        raise ValueError('numerical evaluator source changed')
    if 'matrix_cache_sha256' in plan and sha(HERE / 'cached_integer.py') != plan['matrix_cache_sha256']:
        raise ValueError('cached-matrix engine changed')
    if 'gpu_engine_sha256' in plan:
        if sha(HERE / 'gpu_integer.py') != plan['gpu_engine_sha256'] or sha(HERE / 'evaluate_verdicts.py') != plan['baseline_tool_sha256']:
            raise ValueError('GPU engine or shared journal/scorer changed')


def audit_replay(root, inputs, verify_residuals=False):
    if not (root / 'run.json').exists():
        return {'started': False, 'complete': False, 'fully_verified': False}
    plan = json.loads((root / 'run.json').read_text())
    rows, offsets, calibration = inventory_inputs(inputs, plan)
    if verify_residuals:
        verify_model_artifacts(plan)
    stages = {}
    refused = set()
    for name in ['input'] + [f'layer_{i:02d}' for i in range(LAYERS)]:
        directory = root / name
        journal = directory / 'journal.jsonl'
        if not journal.exists():
            continue
        raw = journal.read_bytes()
        result = audit_journal(raw, offsets)
        result['complete'] = False
        result['residual_hash_verified'] = False
        ready = directory / 'ready.json'
        if ready.exists():
            receipt = json.loads(ready.read_text())
            if result['incomplete_journal_tail'] or result['items'] != len(rows) or receipt['items'] != len(rows):
                raise ValueError('completed stage lacks full sequence diagnostics')
            if hashlib.sha256(raw).hexdigest() != receipt['journal_sha256']:
                raise ValueError('completed journal changed')
            residual = directory / 'residual.bin'
            if residual.stat().st_size != int(offsets[-1]) * D * 2:
                raise ValueError('completed residual has the wrong length')
            if verify_residuals:
                if sha(residual) != receipt['residual_sha256']:
                    raise ValueError('completed residual changed')
                result['residual_hash_verified'] = True
            result['complete'] = True
        stages[name] = result
        refused.update(result['refused_items'])
    complete = False
    head_refusals = {}
    if (root / 'complete.json').exists():
        receipt = json.loads((root / 'complete.json').read_text())
        if len(stages) != LAYERS + 1 or not all(s['complete'] for s in stages.values()):
            raise ValueError('completion marker lacks a full layer replay')
        if sha(root / 'run.json') != receipt['run_sha256'] or sha(root / 'verdicts.json') != receipt['verdicts_sha256']:
            raise ValueError('completed replay provenance changed')
        verdicts = json.loads((root / 'verdicts.json').read_text())['rows']
        if receipt['items'] != len(rows) or len(verdicts) != len(rows):
            raise ValueError('final verdicts omit inputs')
        for i, (source, verdict) in enumerate(zip(rows, verdicts)):
            if any(verdict.get(key) != value for key, value in source.items()):
                raise ValueError('final verdict input identity differs')
            if verdict['stack_refused'] != (i in refused):
                raise ValueError('final refusal summary disagrees with layer journals')
        if receipt['stack_refused'] != len(refused):
            raise ValueError('completion refusal count differs')
        head_refusals = {head: sum(r['heads'][head]['head_refused'] for r in verdicts)
                         for head in ('refusal_free', 'calibrated')}
        complete = True
    return {'started': True, 'complete': complete,
            'fully_verified': complete and verify_residuals,
            'model_artifact_hashes_verified': verify_residuals,
            'scope': 'calibration including padded positions' if calibration else 'all 12 A1 sets without truncation',
            'expected_items': len(rows), 'expected_tokens_per_layer': int(offsets[-1]),
            'run_sha256': sha(root / 'run.json'), 'stages': stages,
            'stack_refused_items_so_far': sorted(refused), 'head_refusals': head_refusals,
            'zero_refusals': complete and not refused and not head_refusals.get('refusal_free', 0),
            'note': 'Numerical replay only. Native export, proof and privacy acceptance are separate.'}


def load_pairing(root):
    if not (root / 'fidelity.json').exists():
        return None
    result = json.loads((root / 'fidelity.json').read_text())
    if sha(HERE / 'analyze_verdicts.py') != result['analysis_source_sha256']:
        raise ValueError('paired analysis source changed')
    if sha(root / 'verdicts.json') != result['integer_source_sha256']:
        raise ValueError('paired analysis uses different integer verdicts')
    for path, digest in result['float_source_sha256'].items():
        if sha(path) != digest:
            raise ValueError('paired float reference changed')
    return result


def render(result, path):
    cal, bench = result['calibration'], result['benchmark']
    lines = ['# Shieldstral integer export and fidelity', '',
             '**Status: full-data acceptance remains incomplete.**' if not result['all_data_zero_refusals_verified'] else
             '**Full numerical calibration and benchmark coverage verified with zero refusals.**', '',
             'The separate R12b tied embedding/head tables match the independent full-tensor reference. '
             'Layer 25 required a coarser SiLU group and a compensated up-weight scale. '
             'These are numerical calibration results; native R13 import, proof and privacy acceptance remain separate.', '',
             f"Report generated {result['generated_at']}. Runs are MEASURED, n=1 on a shared box. "
             'Timing is diagnostic, not a quiesced performance benchmark.', '',
             '## Full-data coverage', '',
             '| Replay | Input sequences | Complete layers / 26 | Refused sequences seen | Final scoring |',
             '|---|---:|---:|---:|---|']
    for name, replay in [('Calibration (all padded positions)', cal), ('A1 benchmark (no truncation)', bench)]:
        if not replay['started']:
            lines.append(f'| {name} | Pending | 0 | Not measured | Pending |')
            continue
        layers = sum(s['complete'] for k, s in replay['stages'].items() if k.startswith('layer_'))
        lines.append(f"| {name} | {replay['expected_items']} | {layers} | {len(replay['stack_refused_items_so_far'])} | "
                     f"{'Complete' if replay['complete'] else 'Pending'} |")
    lines += ['', 'A zero count in an incomplete replay is only a progress observation. '
              'Acceptance additionally requires full residual hashes, every input diagnostic, and final-head checks. '
              'The calibrated final-norm alternative is reported separately; the current candidate uses the refusal-free norm.', '',
              'The calibration metadata field `content_tokens` retains the original pre-padding **prompt** length; '
              'it is not a pure content length and is not used for benchmark length shares. '
              'All original calibration token IDs, including padding, are compared byte for byte by the coverage audit.', '',
              '## Held-out verdict agreement', '']
    pairing = result['pairing']
    if pairing is None:
        lines += ['The complete 4,872-decision comparison is pending. '
                  'The earlier eight-item strict-sexual ToxicChat smoke check had zero refusals and 8/8 agreement '
                  'under both final-norm choices. That subset is not an acceptance result. '
                  'Its retained evidence is `fidelity_smoke8_fix1/fidelity.json`.']
    else:
        lines += ['| Dataset / policy | Head | N | Refused | Agreement | Integer F1 | Float F1 | Margin within error |',
                  '|---|---|---:|---:|---:|---:|---:|---:|']
        fmt = lambda x: 'n/a' if x is None else f'{x:.4f}'
        for name, group in sorted(pairing['sets'].items()):
            for head, stats in group['heads'].items():
                scores = stats['diagnostic_all']
                lines.append(f"| {name} | {head} | {stats['n']} | {stats['refused']} | {fmt(scores['agreement'])} | "
                             f"{fmt(scores['integer']['f1'])} | {fmt(scores['float']['f1'])} | {stats['margin_within_integer_error']} |")
        lines += ['', 'The table uses all-item diagnostic metrics. Any refused row includes diagnostic clamps and is '
                  'not an accepted prediction. `fidelity_full_fix1/fidelity.json` also records accepted-only metrics, '
                  'weighted agreement, error quantiles and every borderline or disagreeing item. '
                  'ToxicChat labels are a broad toxicity proxy, not category ground truth.']
    lines += ['', '## Artifact and integration status', '',
              '- Original `dg_base_t256` and `s2_evaluation_t256` remain pinned and unchanged.',
              '- `layer25_probe/integer/complete.json` records the original sequence-97 gate/up refusals; '
              '`layer25_fix_candidate/complete.json` records the tested numerical correction.',
              '- `dg_r12b_t256/reference_crosscheck.json` records bit-identical full embedding, head, multiplier and reference margin digests.',
              '- The active layer-25 candidate keeps `sh_u=0`, halves the up-weight scale and decrements `sh_h` by one. '
              'Its four groups are `(-3,-11), (-2,-11), (-1,-9), (0,-8)`. Native registration of `(0,-8)` is still required.',
              '- Benchmark prompts longer than T256 remain in the numerical comparison. '
              'Their inclusion does not register a native profile or establish a classifier proof at those lengths.',
              '- Real Shieldstral app proofs and Base Sepolia deployment remain pending.', '',
              'Machine-readable coverage, refusal sites, source hashes and the report generator hash are in `fidelity_audit.json`.', '']
    path.write_text('\n'.join(lines))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--verify-residuals', action='store_true', help='hash all residual bytes; run through resource guard for full data')
    parser.add_argument('--out', type=Path, default=HERE / 'fidelity_audit.json')
    args = parser.parse_args()
    calibration = audit_replay(HERE / 'calibration_full_fix1', HERE / 'calibration_replay_inputs', args.verify_residuals)
    benchmark = audit_replay(HERE / 'fidelity_full_fix1', HERE / 'evaluation_inputs', args.verify_residuals)
    result = {'schema': 'zk60-shieldstral-full-replay-audit/1', 'calibration': calibration, 'benchmark': benchmark,
              'all_data_zero_refusals_verified': all(r['fully_verified'] and r['zero_refusals'] for r in (calibration, benchmark)),
              'pairing': load_pairing(HERE / 'fidelity_full_fix1'),
              'generated_at': datetime.now(timezone.utc).isoformat(), 'tool_sha256': sha(__file__)}
    atomic_json(args.out, result)
    render(result, HERE / 'REPORT.md')
    print(json.dumps({k: result[k] for k in ('all_data_zero_refusals_verified', 'tool_sha256')}))


if __name__ == '__main__':
    main()

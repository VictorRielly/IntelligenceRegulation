"""Compare all retained bytes and diagnostics for baseline/cache smoke runs."""
import json
from pathlib import Path

from collect_stats import atomic_json, sha
from shieldstral_geometry import LAYERS

HERE = Path(__file__).resolve().parent


def checked_run(root):
    complete = json.loads((root / 'complete.json').read_text())
    plan = json.loads((root / 'run.json').read_text())
    if sha(root / 'run.json') != complete['run_sha256'] or sha(root / 'verdicts.json') != complete['verdicts_sha256']:
        raise ValueError('completed replay changed')
    return complete, plan


def main():
    baseline = HERE / 'fidelity_smoke8_fix1'
    cached = HERE / 'fidelity_smoke8_cached'
    old_done, old = checked_run(baseline)
    new_done, new = checked_run(cached)
    for key in ('input_sha256', 'evaluation_export_sha256', 'token_io_sha256', 'indexes', 'items', 'tokens',
                'word_domain_amendment', 'word_domain_source_sha256', 'layer25_calibration_candidate'):
        if old[key] != new[key]:
            raise ValueError('comparison uses different inputs/model parameters: ' + key)
    if new['matrix_cache_sha256'] != sha(HERE / 'cached_integer.py') or new['tool_sha256'] != sha(HERE / 'evaluate_verdicts_cached.py'):
        raise ValueError('cached evaluator source changed')
    same = {}
    for name in ['input'] + [f'layer_{i:02d}' for i in range(LAYERS)]:
        receipts = []
        for root in (baseline, cached):
            ready = json.loads((root / name / 'ready.json').read_text())
            if ready['items'] != old['items']:
                raise ValueError('partial stage in completed replay')
            for filename, key in (('residual.bin', 'residual_sha256'), ('journal.jsonl', 'journal_sha256')):
                if sha(root / name / filename) != ready[key]:
                    raise ValueError('retained stage changed')
            receipts.append(ready)
        if receipts[0] != receipts[1]:
            raise ValueError('cache changed integer residuals or refusal diagnostics at ' + name)
        same[name] = receipts[0]
    if old_done['verdicts_sha256'] != new_done['verdicts_sha256']:
        raise ValueError('cache changed final verdicts or head diagnostics')
    atomic_json(HERE / 'cache_parity.json', {'schema': 'zk60-shieldstral-matrix-cache-parity/1',
        'items': old['items'], 'tokens': old['tokens'], 'layers': LAYERS, 'bit_identical': True,
        'stages': same, 'baseline_run_sha256': old_done['run_sha256'], 'cached_run_sha256': new_done['run_sha256'],
        'verdicts_sha256': old_done['verdicts_sha256'], 'comparison_source_sha256': sha(__file__),
        'cached_engine_sha256': new['matrix_cache_sha256'], 'cached_runner_sha256': new['tool_sha256'],
        'scope': 'MEASURED exact-byte parity on the full26-layer eight-item smoke, including T367; not full-data fidelity or native acceptance'})
    print(json.dumps({'bit_identical': True, 'layers': LAYERS, 'items': old['items'], 'tokens': old['tokens']}))


if __name__ == '__main__':
    main()

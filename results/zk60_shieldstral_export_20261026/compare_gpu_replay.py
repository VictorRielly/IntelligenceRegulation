"""Require all26 layers, every diagnostic and both final heads to match CPU."""
import json
from pathlib import Path

from collect_stats import atomic_json, sha
from compare_cached_replay import checked_run
from shieldstral_geometry import LAYERS

HERE = Path(__file__).resolve().parent


def main():
    baseline = HERE / 'fidelity_smoke8_fix1'
    gpu = HERE / 'fidelity_smoke8_gpu'
    old_done, old = checked_run(baseline)
    new_done, new = checked_run(gpu)
    for key in ('input_sha256', 'evaluation_export_sha256', 'token_io_sha256', 'indexes', 'items', 'tokens',
                'word_domain_amendment', 'word_domain_source_sha256', 'layer25_calibration_candidate'):
        if old[key] != new[key]:
            raise ValueError('GPU comparison uses different input/model parameters: ' + key)
    for name, key in (('gpu_integer.py', 'gpu_engine_sha256'), ('evaluate_verdicts_gpu.py', 'tool_sha256'),
                      ('evaluate_verdicts.py', 'baseline_tool_sha256')):
        if sha(HERE / name) != new[key]:
            raise ValueError('GPU execution source changed')
    stages = {}
    for name in ['input'] + [f'layer_{i:02d}' for i in range(LAYERS)]:
        receipts = []
        for root in (baseline, gpu):
            ready = json.loads((root / name / 'ready.json').read_text())
            if ready['items'] != 8:
                raise ValueError('GPU comparison has a missing smoke input')
            for filename, key in (('residual.bin', 'residual_sha256'), ('journal.jsonl', 'journal_sha256')):
                if sha(root / name / filename) != ready[key]:
                    raise ValueError('retained comparison stage changed')
            receipts.append(ready)
        if receipts[0] != receipts[1]:
            raise ValueError('GPU changed integer residuals or refusal diagnostics: ' + name)
        stages[name] = receipts[0]
    if old_done['verdicts_sha256'] != new_done['verdicts_sha256']:
        raise ValueError('GPU changed final-head values or diagnostics')
    result = {'schema': 'zk60-shieldstral-gpu-parity/1', 'bit_identical': True, 'layers': LAYERS,
              'items': old['items'], 'tokens': old['tokens'], 'stages': stages,
              'gpu_engine_sha256': new['gpu_engine_sha256'], 'gpu_runner_sha256': new['tool_sha256'],
              'baseline_helper_sha256': new['baseline_tool_sha256'], 'gpu_run_sha256': new_done['run_sha256'],
              'cpu_run_sha256': old_done['run_sha256'], 'verdicts_sha256': new_done['verdicts_sha256'],
              'comparison_sha256': sha(__file__), 'comparison_helper_sha256': sha(HERE / 'compare_cached_replay.py'),
              'scope': 'MEASURED exact-byte parity for all26 layers of the eight-item smoke, including T367; no full-data or native-proof acceptance'}
    atomic_json(HERE / 'gpu_smoke_parity.json', result)
    print(json.dumps({'bit_identical': True, 'layers': LAYERS, 'items': old['items']}))


if __name__ == '__main__':
    main()

"""One actual layer GPU pass per guarded invocation, paired with baseline CPU."""
import argparse
import hashlib
import json
from pathlib import Path
import time

import numpy as np

import calibration_port as P
from amended_evaluator import apply_candidate
from collect_stats import atomic_json, sha
from evaluation_export import EvaluationExport
from evaluate_verdicts import row_diagnostics
from gpu_integer import configure, prepare
from shieldstral_geometry import D
from signed_word_domain import S2RecPos

HERE = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--case', choices=('layer0', 'original25', 'fixed25'), required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=False)
    export = EvaluationExport(HERE / 's2_evaluation_t256')
    if args.case == 'layer0':
        source = HERE / 'calibration_full_fix1/input/residual.bin'
        x = np.fromfile(source, dtype='<i2', count=256 * D).reshape(1, 256, D).astype(np.float64)
        layer = 0
    else:
        source = HERE / 'layer25_probe/integer/layer_24.npy'
        x = np.load(source, allow_pickle=False).astype(np.float64)
        layer = 25
    model = export.layer(layer, 256)
    if args.case == 'fixed25':
        model = apply_candidate(model, HERE / 'layer25_fix_candidate')
    recorder = S2RecPos(1)
    tick = time.perf_counter()
    baseline = P.fl.rx_block(x, model, frozenset(P.fl.SITES), recorder)
    baseline_seconds = time.perf_counter() - tick
    baseline_diag = row_diagnostics(recorder)
    torch = configure()
    tick = time.perf_counter()
    prepare(model)
    torch.cuda.synchronize()
    setup_seconds = time.perf_counter() - tick
    recorder = S2RecPos(1)
    tick = time.perf_counter()
    result = P.fl.rx_block(x, model, frozenset(P.fl.SITES), recorder)
    torch.cuda.synchronize()
    gpu_seconds = time.perf_counter() - tick
    if not np.array_equal(result, baseline) or row_diagnostics(recorder) != baseline_diag:
        raise ValueError('GPU changed residuals or refusal diagnostics')
    payload = {'case': args.case, 'layer': layer, 'bit_identical': True, 'diagnostics': baseline_diag,
        'baseline_seconds': baseline_seconds, 'gpu_setup_seconds': setup_seconds, 'gpu_seconds': gpu_seconds,
        'gpu_peak_allocated_bytes': torch.cuda.max_memory_allocated(), 'gpu_peak_reserved_bytes': torch.cuda.max_memory_reserved(),
        'device': torch.cuda.get_device_name(), 'torch_version': torch.__version__,
        'result_sha256': hashlib.sha256(result.astype('<i2').tobytes()).hexdigest(), 'input_sha256': sha(source),
        'backend_sha256': sha(HERE / 'gpu_integer.py'), 'probe_sha256': sha(__file__),
        'scope': 'MEASURED one guarded actual-layer pass, n=1 shared box; full26-layer parity and held-out fidelity remain required',
        'upstream_api_source': 'https://github.com/pytorch/pytorch/tree/v2.4.1/aten/src/ATen/native/cuda'}
    atomic_json(args.out / 'complete.json', payload)
    print(json.dumps({k: payload[k] for k in ('case', 'bit_identical', 'baseline_seconds', 'gpu_setup_seconds', 'gpu_seconds', 'gpu_peak_reserved_bytes')}), flush=True)


if __name__ == '__main__':
    main()

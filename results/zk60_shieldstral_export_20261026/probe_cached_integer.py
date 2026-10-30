"""Bounded measured comparison on an actual retained calibration item."""
import argparse
import json
from pathlib import Path
import time

import numpy as np

import calibration_port as P
from cached_integer import prepare
from collect_stats import atomic_json, sha
from evaluation_export import EvaluationExport
from evaluate_verdicts import row_diagnostics
from shieldstral_geometry import D
from signed_word_domain import S2RecPos

HERE = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    args.out.mkdir(exist_ok=False)
    export = EvaluationExport(HERE / 's2_evaluation_t256')
    model = export.layer(0, 256)
    source = HERE / 'calibration_full_fix1/input/residual.bin'
    x = np.fromfile(source, dtype='<i2', count=256 * D).reshape(1, 256, D).astype(np.float64)
    timings = {}
    reference = None
    diagnostics = None
    for cached in (False, True):
        setup = time.perf_counter()
        if cached:
            prepare(model)
        setup = time.perf_counter() - setup
        samples = []
        for _ in range(3):
            recorder = S2RecPos(1)
            start = time.perf_counter()
            out = P.fl.rx_block(x, model, frozenset(P.fl.SITES), recorder)
            samples.append(time.perf_counter() - start)
            diag = row_diagnostics(recorder)
            if reference is None:
                reference, diagnostics = out.copy(), diag
            elif not np.array_equal(reference, out) or diag != diagnostics:
                raise ValueError('cache changed integer residuals or refusal diagnostics')
        timings['cached' if cached else 'baseline'] = {'setup_seconds': setup, 'samples_seconds': samples}
    atomic_json(args.out / 'complete.json', {'timings': timings, 'bit_identical': True,
        'diagnostics': diagnostics, 'source_residual_sha256': sha(source),
        'cache_source_sha256': sha(HERE / 'cached_integer.py'), 'probe_source_sha256': sha(__file__),
        'scope': 'MEASURED n=1 shared box; one actual calibration sequence at layer0; broader parity still required'})
    print(json.dumps(timings), flush=True)


if __name__ == '__main__':
    main()

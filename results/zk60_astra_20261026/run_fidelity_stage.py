"""Bounded full-data continuation with a per-dataset kernel lock and HOLDs.

Run in a yielded foreground tool session. Each attempt retains distinct logs;
the evaluator's hashed journal resumes the SAME full-data objective, not a subset.
Missing handles never authorize overlap: each worker takes a nonblocking lock.
"""
import argparse
import fcntl
import json
from pathlib import Path
import subprocess
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
EXPORT = ROOT / 'results/zk60_shieldstral_export_20261026'
GUARD = ROOT / 'scripts/zk60_resource_guard.py'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('stage', choices=('calibration', 'benchmark'))
    ap.add_argument('--attempt', type=int, required=True)
    ap.add_argument('--max-minutes', type=float, default=25)
    args = ap.parse_args()
    if args.attempt < 1 or not 0 < args.max_minutes <= 25:
        raise ValueError('invalid attempt/timebox')
    directory = HERE / 'fidelity_jobs' / f'{args.stage}-{args.attempt}'
    directory.mkdir(parents=True, exist_ok=False)
    command = ['/usr/bin/env', 'OPENBLAS_NUM_THREADS=2', 'OMP_NUM_THREADS=2', 'python3',
               str(EXPORT / 'evaluate_verdicts.py'), '--all', '--max-minutes', str(args.max_minutes),
               '--token-io', str(EXPORT / 'dg_r12b_t256/token_io'),
               '--layer25-fix', str(EXPORT / 'layer25_fix_candidate'),
               '--out', str(EXPORT / ('calibration_full_fix1' if args.stage == 'calibration' else 'fidelity_full_fix1'))]
    if args.stage == 'calibration':
        command += ['--input', str(EXPORT / 'calibration_replay_inputs')]
    # The complete26-layer smoke measured RSS1.14GiB (including T367).
    # Calibration uses T256:1.45GiB gives27% margin, including its final layer.
    # Keep the previous longer-input CPU benchmark declaration separate.
    need, cap = (1.45 if args.stage == 'calibration' else 1.6), 4.0
    (directory / 'plan.json').write_text(json.dumps({'stage': args.stage, 'attempt': args.attempt,
        'command': command, 'need_gib': need, 'cap_gib': cap, 'threads': 2,
        'measurement_basis': ('full26-layer smoke8 1.14GiB plus27%; calibration T256' if args.stage == 'calibration'
                              else 'smoke8 1.14GiB plus40%; exact-length per-item processing')}, indent=2)+'\n')
    with (directory.parent / 'evaluation.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        holds = (EXPORT / 'HOLD', ROOT / 'results/zk60_shieldstral_prep_20261021/HOLD')
        while any(p.exists() for p in holds):
            time.sleep(15)
        rc = subprocess.run(['python3', str(GUARD), 'run', '--class', 'light',
            '--need-gib', str(need), '--cap-gib', str(cap), '--label', 'astra-full-' + args.stage,
            '--wait-secs', '60', '--max-secs', '1800', '--log', str(directory / 'leaf.log'),
            '--done', str(directory / 'leaf.done'), '--result-json', str(directory / 'guard.json'),
            '--', *command]).returncode
        (directory / 'worker.done').write_text(str(rc)+'\n')
        return rc


if __name__ == '__main__':
    raise SystemExit(main())

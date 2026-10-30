"""Bounded one-pass GPU parity checks; shared guard, HOLDs and durable receipts."""
import argparse
import fcntl
import hashlib
import json
from pathlib import Path
import subprocess
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
EXPORT = ROOT / 'results/zk60_shieldstral_export_20261026'
GUARD = ROOT / 'scripts/zk60_resource_guard.py'
HOLDS = (EXPORT / 'HOLD', ROOT / 'results/zk60_shieldstral_prep_20261021/HOLD')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('case', choices=('layer0', 'original25', 'fixed25'))
    parser.add_argument('--attempt', type=int, required=True)
    args = parser.parse_args()
    if args.attempt < 1:
        raise ValueError('positive attempt required')
    directory = HERE / 'gpu_jobs' / f'{args.case}-{args.attempt}'
    directory.mkdir(parents=True, exist_ok=False)
    command = ['/usr/bin/env', 'OPENBLAS_NUM_THREADS=2', 'OMP_NUM_THREADS=2',
               'CUDA_CACHE_PATH=/tmp/zk60_astra_cuda_cache', 'python3', str(EXPORT / 'probe_gpu_integer.py'),
               '--case', args.case, '--out', str(EXPORT / 'gpu_probe' / f'{args.case}-{args.attempt}')]
    plan = {'case': args.case, 'command': command, 'need_gib': 2.5, 'cap_gib': 4.5,
            'measurement_basis': 'baseline1.14GiB + estimated0.5GiB Torch +0.3GiB copies, plus29% margin',
            'gpu_allocator_cap_gib': 3, 'required_total_vram_max_mib': 4096,
            'source_sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                              for p in (Path(__file__), EXPORT / 'gpu_integer.py', EXPORT / 'probe_gpu_integer.py')}}
    (directory / 'plan.json').write_text(json.dumps(plan, indent=2) + '\n')
    with (directory.parent / 'probe.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        while True:
            if any(p.exists() for p in HOLDS):
                time.sleep(15)
                continue
            ready = subprocess.run(['python3', str(GUARD), 'check', '--class', 'gpu', '--need-gib', '2.5'], capture_output=True, text=True)
            (directory / 'precheck.txt').write_text(ready.stdout + ready.stderr)
            if ready.returncode == 0 and 'OK to start now' in ready.stdout and not any(p.exists() for p in HOLDS):
                break
            time.sleep(15)
        subprocess.run(['python3', str(GUARD), 'status'], check=True)
        result = subprocess.run(['python3', str(GUARD), 'run', '--class', 'gpu', '--need-gib', '2.5', '--cap-gib', '4.5',
            '--label', 'astra-gpu-parity-' + args.case, '--wait-secs', '60', '--max-secs', '300',
            '--log', str(directory / 'leaf.log'), '--done', str(directory / 'leaf.done'),
            '--result-json', str(directory / 'guard.json'), '--', *command])
        (directory / 'worker.done').write_text(str(result.returncode) + '\n')
        if result.returncode == 0:
            evidence = json.loads((directory / 'guard.json').read_text())
            if evidence['peak_vram_mib'] is None or evidence['peak_vram_mib'] > 4096:
                raise ValueError('GPU parity pass exceeded the project VRAM limit or lacks telemetry')
        return result.returncode


if __name__ == '__main__':
    raise SystemExit(main())

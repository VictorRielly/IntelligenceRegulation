"""One bounded GPU layer replay, with provenance gates and shared admission."""
import argparse
import fcntl
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
EXPORT = ROOT / 'results/zk60_shieldstral_export_20261026'
GUARD = ROOT / 'scripts/zk60_resource_guard.py'
HOLDS = (EXPORT / 'HOLD', ROOT / 'results/zk60_shieldstral_prep_20261021/HOLD')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=('smoke', 'benchmark'))
    parser.add_argument('--layer', type=int, required=True)
    parser.add_argument('--attempt', type=int, required=True)
    parser.add_argument('--max-minutes', type=float, default=5)
    parser.add_argument('--detach', action='store_true', help='Launch one durable bounded worker and return its PID')
    args = parser.parse_args()
    if not 0 <= args.layer < 26 or args.attempt < 1 or not 0 < args.max_minutes <= 10:
        raise ValueError('invalid layer, attempt or timebox')
    if args.detach:
        directory = HERE / 'gpu_replay_jobs' / f'{args.mode}-l{args.layer:02d}-{args.attempt}'
        directory.parent.mkdir(exist_ok=True)
        if directory.exists():
            raise ValueError('attempt already exists; inspect its worker.done before resuming')
        # Exclusive launch record prevents duplicate detached starts. The worker
        # independently reserves its directory and holds replay.lock throughout.
        with directory.with_suffix('.launch.json').open('x') as record:
            with directory.with_suffix('.launcher.log').open('xb') as output:
                process = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), args.mode,
                    '--layer', str(args.layer), '--attempt', str(args.attempt),
                    '--max-minutes', str(args.max_minutes)], cwd=ROOT, stdin=subprocess.DEVNULL,
                    stdout=output, stderr=subprocess.STDOUT, start_new_session=True, close_fds=True)
            state = {'pid': process.pid, 'boot_id': Path('/proc/sys/kernel/random/boot_id').read_text().strip(),
                     'worker_done': str(directory / 'worker.done'), 'log': str(directory.with_suffix('.launcher.log'))}
            record.write(json.dumps(state, indent=2) + '\n')
        print(json.dumps(state))
        return 0
    backend = digest(EXPORT / 'gpu_integer.py')
    for name in ('layer0', 'original25', 'fixed25'):
        proof = json.loads((EXPORT / 'gpu_probe' / f'{name}-1/complete.json').read_text())
        if not proof['bit_identical'] or proof['backend_sha256'] != backend:
            raise ValueError('current backend lacks an actual-layer parity gate')
    if args.mode == 'benchmark':
        proof = json.loads((EXPORT / 'gpu_smoke_parity.json').read_text())
        if (not proof['bit_identical'] or proof['layers'] != 26 or proof['items'] != 8
                or proof['gpu_engine_sha256'] != backend
                or proof['gpu_runner_sha256'] != digest(EXPORT / 'evaluate_verdicts_gpu.py')
                or proof['baseline_helper_sha256'] != digest(EXPORT / 'evaluate_verdicts.py')):
            raise ValueError('current GPU runner lacks the full26-layer smoke parity gate')
    directory = HERE / 'gpu_replay_jobs' / f'{args.mode}-l{args.layer:02d}-{args.attempt}'
    directory.mkdir(parents=True, exist_ok=False)
    output = EXPORT / ('fidelity_smoke8_gpu' if args.mode == 'smoke' else 'fidelity_full_fix1')
    command = ['/usr/bin/env', 'OPENBLAS_NUM_THREADS=2', 'OMP_NUM_THREADS=2',
               'CUDA_CACHE_PATH=/tmp/zk60_astra_cuda_cache', 'python3', str(EXPORT / 'evaluate_verdicts_gpu.py'),
               '--layer', str(args.layer), '--out', str(output), '--max-minutes', str(args.max_minutes)]
    command += ['--limit', '8'] if args.mode == 'smoke' else ['--all']
    need = 2.8 if args.mode == 'benchmark' else 2.1
    basis = ('Full benchmark layer2 measured peak2.23GiB plus25% margin, rounded up' if args.mode == 'benchmark'
             else 'GPU layer25 peak1.10GiB +0.52GiB for T533 attention, plus29% margin')
    plan = {'command': command, 'need_gib': need, 'cap_gib': 4.5,
            'measurement_basis': basis,
            'gpu_allocator_cap_gib': 3, 'total_vram_limit_mib': 4096,
            'source_sha256': {p.name: digest(p) for p in (Path(__file__), EXPORT / 'evaluate_verdicts_gpu.py', EXPORT / 'gpu_integer.py')}}
    (directory / 'plan.json').write_text(json.dumps(plan, indent=2) + '\n')
    with (directory.parent / 'replay.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        # The installed guard admits before taking the shared heavy lock.
        # Queue directly so short gaps between other jobs are not missed.
        while any(p.exists() for p in HOLDS):
            time.sleep(15)
        subprocess.run(['python3', str(GUARD), 'status'], check=True)
        result = subprocess.run(['python3', str(GUARD), 'run', '--class', 'gpu', '--need-gib', str(need), '--cap-gib', '4.5',
            '--label', f'astra-gpu-{args.mode}-l{args.layer:02d}', '--wait-secs', '1800', '--max-secs', str(int(args.max_minutes * 60 + 120)),
            '--log', str(directory / 'leaf.log'), '--done', str(directory / 'leaf.done'),
            '--result-json', str(directory / 'guard.json'), '--', *command])
        (directory / 'worker.done').write_text(str(result.returncode) + '\n')
        evidence = json.loads((directory / 'guard.json').read_text())
        if result.returncode in (0, 3) and (evidence['peak_vram_mib'] is None or evidence['peak_vram_mib'] > 4096):
            raise ValueError('device VRAM limit exceeded or telemetry unavailable')
        return result.returncode


if __name__ == '__main__':
    raise SystemExit(main())

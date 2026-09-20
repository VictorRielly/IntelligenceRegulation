#!/usr/bin/env python3
"""Validate the shared integer-row fold in main; no model-scale timing claim.

CPU and GPU builds are serialized separately from proof runs. GPU kernels
are unchanged by this patch: the device gate is twelve complete frozen
proofs, not a repeat of every unrelated kernel-oracle switch combination.
Private native profiles additionally prove/verify in fresh processes with
both fold implementations, including their existing corruption controls.
"""
import fcntl
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
BASE = Path(__file__).resolve().parent
OUT = BASE / 'integration'
CARGO = '/home/victor/.cargo/bin/cargo'
CUDA_LD = '/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib'


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for b in iter(lambda: f.read(1024 * 1024), b''):
            h.update(b)
    return h.hexdigest()


def main():
    OUT.mkdir(exist_ok=True)
    if (OUT / 'validation.json').exists():
        raise SystemExit('refusing to overwrite integration evidence')
    bench = json.loads((BASE / 'attempt-4/validation.json').read_text())
    if bench['state'] != 'passed':
        raise SystemExit('final candidate arithmetic/benchmark gate has not passed')
    for name, expected in bench['source_hashes'].items():
        if sha(ROOT / name) != expected:
            raise SystemExit('candidate source differs from benchmark: ' + name)
    spec = importlib.util.spec_from_file_location('frozen_reference', ROOT / 'results/zk60_fsp_l9_integration_20260919/run.py')
    reference = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(reference)
    sources = sorted(p for crate in ['hashline', 'zkp-core', 'private-block-kernel'] for p in (ROOT / crate / 'src').rglob('*')
                     if p.is_file() and p.suffix in ('.rs', '.cu'))
    sources += [ROOT / c / f for c in ['hashline', 'zkp-core'] for f in ['Cargo.toml', 'Cargo.lock']]
    sources += [ROOT / 'hashline/examples' / ('zk60_private_' + kind + '.rs') for kind in ['attention', 'block']]
    report = {'state': 'running', 'runs': [], 'proof_gates': [], 'native_proofs': [],
              'source_hashes': {str(p.relative_to(ROOT)): sha(p) for p in sources},
              'runner_sha256': sha(Path(__file__)), 'reference_runner_sha256': sha(ROOT / 'results/zk60_fsp_l9_integration_20260919/run.py'),
              'benchmark_report_sha256': sha(BASE / 'attempt-4/validation.json'),
              'binary_hashes': {}, 'model_scale_speed_claim': False, 'privacy_acceptance': False}
    env = {k: v for k, v in os.environ.items() if not k.startswith(('HL_', 'CARGO_', 'RUSTFLAGS'))}
    env.update(CARGO_BUILD_JOBS='2', RAYON_NUM_THREADS='2', CUDA_ROOT='/home/victor/cuda-root',
               LD_LIBRARY_PATH=CUDA_LD, M125_EXPORT_DIR=str(ROOT / 'results/m125_ffn_export_wsl'))
    scratch = Path(tempfile.mkdtemp(prefix='zk60-rowfold-proof-gates-'))
    report['scratch'] = str(scratch)

    def save():
        tmp = OUT / 'validation.tmp'
        tmp.write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
        tmp.replace(OUT / 'validation.json')

    def run(name, argv, extra=None):
        argv = list(map(str, argv))
        report['current'] = name
        save()
        print('START', name, flush=True)
        start = time.monotonic()
        with (OUT / (name + '.log')).open('x') as log:
            child = subprocess.Popen(argv, cwd=ROOT, env=env | (extra or {}), stdin=subprocess.DEVNULL,
                                     stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            try:
                code = child.wait(timeout=1800)
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait()
                code = 124
        report['runs'].append({'name': name, 'argv': argv, 'environment': extra or {}, 'exit_code': code,
                               'elapsed_shared_seconds': time.monotonic() - start,
                               'log_sha256': sha(OUT / (name + '.log'))})
        (OUT / (name + '.done')).write_text(str(code) + '\n')
        save()
        if code:
            raise RuntimeError(f'{name}: exit {code}')
        print('PASS', name, flush=True)
        return (OUT / (name + '.log')).read_text()

    def idle(name):
        samples = []
        streak = 0
        for i in range(60):
            p = subprocess.run(['nvidia-smi', '--query-gpu=name,memory.total,memory.used,utilization.gpu', '--format=csv,noheader'],
                               capture_output=True, text=True, timeout=20, check=True)
            fields = p.stdout.strip().split(',')
            if len(fields) != 4:
                raise RuntimeError('expected one device')
            _, total, used, util = fields
            q = subprocess.run(['nvidia-smi', '--query-compute-apps=pid,used_gpu_memory', '--format=csv,noheader'],
                               capture_output=True, text=True, timeout=20, check=True)
            ok = int(total.split()[0]) >= 8000 and int(used.split()[0]) <= 512 and int(util.split()[0]) <= 2 and not q.stdout.strip()
            samples.append({'device': p.stdout.strip(), 'apps': q.stdout.strip(), 'idle': ok})
            streak = streak + 1 if ok else 0
            if streak == 2:
                break
            time.sleep(1)
        (OUT / (name + '-idle.json')).write_text(json.dumps(samples, indent=2) + '\n')
        if streak != 2:
            raise RuntimeError(name + ': device idle preflight failed')

    save()
    try:
        with open('/tmp/zk-build.lock', 'w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            core = run('core-tests', [CARGO, 'test', '--release', '--offline', '--locked', '-j', '2', '--manifest-path', 'zkp-core/Cargo.toml', '--', '--test-threads=2'])
            if 'test result: ok. 35 passed; 0 failed; 0 ignored' not in core:
                raise RuntimeError('unexpected core test coverage')
            tests = run('hashline-tests', [CARGO, 'test', '--release', '--offline', '--locked', '-j', '2', '--manifest-path', 'hashline/Cargo.toml', '--', '--test-threads=2'])
            totals = [tuple(map(int, m)) for m in re.findall(r'test result: ok\. (\d+) passed; (\d+) failed; (\d+) ignored', tests)]
            if sum(t[0] for t in totals) != 261 or sum(t[1] for t in totals) != 0 or sum(t[2] for t in totals) != 2:
                raise RuntimeError('unexpected hashline test coverage: ' + str(totals))
            build = [CARGO, 'build', '--release', '--offline', '--locked', '-j', '2', '--manifest-path', 'hashline/Cargo.toml']
            run('cpu-build', build + ['--bin', 'hashline', '--example', 'zk60_private_attention', '--example', 'zk60_private_block'])
            run('gpu-build', build + ['--bin', 'hashline', '--features', 'gpu-cuda'], {'CARGO_TARGET_DIR': str(ROOT / 'hashline/target-gpu')})
        cpu = ROOT / 'hashline/target/release/hashline'
        gpu = ROOT / 'hashline/target-gpu/release/hashline'
        binaries = [cpu, gpu] + [ROOT / 'hashline/target/release/examples' / ('zk60_private_' + kind) for kind in ['attention', 'block']]
        report['binary_hashes'] = {str(p.relative_to(ROOT)): sha(p) for p in binaries}
        save()
        with open('/tmp/zk-heavy.lock', 'w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            for kind, size in [('attention', 2245800), ('block', 2816472)]:
                binary = ROOT / 'hashline/target/release/examples' / ('zk60_private_' + kind)
                for mode in ['1', '0']:
                    name = f'native-{kind}-{mode}'
                    dest = OUT / name
                    run(name + '-prove', [binary, 'prove', dest], {'HL_FSP_ROW_FOLD': mode})
                    receipt = dest / (kind + '_receipt.bin')
                    if receipt.stat().st_size != size:
                        raise RuntimeError(name + ': native size changed')
                    # Verify each receipt through BOTH implementations in fresh
                    # processes, including the example's three corruptions.
                    for vm in ['0', '1']:
                        text = run(name + '-verify-' + vm, [binary, 'verify', dest], {'HL_FSP_ROW_FOLD': vm})
                        if f'ACCEPT: {size} bytes' not in text or text.count('refused:') != 3:
                            raise RuntimeError(name + ': native verifier/negative controls missing')
                    report['native_proofs'].append({'profile': kind, 'fold_mode': mode, 'bytes': size, 'sha256': sha(receipt),
                                                   'policy_sha256': sha(dest / (kind + '_expected.bin')), 'verified_modes': ['0', '1']})
                    save()
            for arm, binary, extra in [('cpu', cpu, {}), ('gpu', gpu, {'HL_GPU': '1'}),
                                       ('gpu-chunked', gpu, {'HL_GPU': '1', 'HL_GPU_CHUNK_BYTES': '100000000', 'HL_GPU_CHUNK_ROWS': '128', 'HL_ZK_CHUNK': '1', 'HL_GPU_VERBOSE': '1'})]:
                for profile, (digest, size, args) in reference.REFERENCE.items():
                    name = arm + '-' + profile
                    if arm != 'cpu':
                        idle(name)
                    receipt = scratch / (name + '.proof')
                    text = run(name, [binary, 'pass', '12', '512', '--threads', '2', '--proof-out', receipt, *args], extra)
                    if not re.search(r'PASS(?:-V3)? ACCEPT', text) or sha(receipt) != digest or receipt.stat().st_size != size:
                        raise RuntimeError(name + ': frozen proof gate failed')
                    if arm != 'cpu' and 'gpu: ON' not in text:
                        raise RuntimeError(name + ': device was not enabled')
                    if arm == 'gpu-chunked':
                        if profile.startswith('legacy'):
                            if 'CHUNKED (forced)' not in text:
                                raise RuntimeError(name + ': hiding chunk path did not run')
                        elif not re.search(r'chunked commits [1-9][0-9]*', text):
                            raise RuntimeError(name + ': public chunk path did not run')
                    report['proof_gates'].append({'name': name, 'sha256': digest, 'bytes': size, 'accepted': True})
                    receipt.unlink()  # only this job's successfully checked scratch output
                    save()
        for p, expected in report['source_hashes'].items():
            if sha(ROOT / p) != expected:
                raise RuntimeError('source changed during validation: ' + p)
        for p, expected in report['binary_hashes'].items():
            if sha(ROOT / p) != expected:
                raise RuntimeError('binary changed during validation: ' + p)
        if sha(Path(__file__)) != report['runner_sha256']:
            raise RuntimeError('runner changed during validation')
        report.update(state='passed', current=None)
        save()
        (OUT / 'run.done').write_text('0\n')
    except BaseException as error:
        report.update(state='failed', error=str(error))
        save()
        (OUT / 'run.done').write_text('1\n')
        raise


if __name__ == '__main__':
    if sys.argv[1:] == ['--detach']:
        OUT.mkdir(exist_ok=True)
        with (OUT / 'launch.log').open('x') as log:
            p = subprocess.Popen([sys.executable, str(Path(__file__).resolve())], cwd=ROOT,
                                 stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        (OUT / 'process.json').write_text(json.dumps({'pid': p.pid, 'detached': True}) + '\n')
        print('Detached row-fold integration PID', p.pid, flush=True)
        raise SystemExit(p.wait())
    main()

#!/usr/bin/env python3
"""CPU/GPU correctness integration, serialized; no model-width proof run."""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
SCRATCH = Path('/tmp/zk60-fsp-l9-integration-20260919')
CUDA_LD = '/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib'
CARGO = '/home/victor/.cargo/bin/cargo'
REFERENCE = {
    'v2': ('50cf7bdfd6b5b182f9c029c3d62087ca9e0e273be218d017609323c15146a17d', 66844928, []),
    'v3': ('5f368db6240e061428a90eccdb22ff456b1507708ef95f1bed39615042973c1d', 70758084, ['--profile', 'v3', '--export', '/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export']),
    'legacy-zk': ('021485e4f80ec695ddc0b05423a941e1a165c222efe12aca5bf3cd2f0d02282d', 87228528, ['--zk', '--seed', '1']),
    'legacy-zkv3': ('40eb54795e023c77382a31020aac728485daaae2e1b5ec58c3c82d04f94aac17', 87697008, ['--zk', '--seed', '1', '--profile', 'v3', '--export', '/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export']),
}


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


class Runner:
    def __init__(self):
        self.report = {'delivery_commit': 'f0d34812e0653310eee9a87457f1df03d2ab77d6',
                       'integration_base': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                       'state': 'running', 'runs': [], 'gates': [], 'binary_hashes': {},
                       'privacy_acceptance': False, 'model_scale_speed_claim': False}
        self.env = {k: v for k, v in os.environ.items() if not k.startswith(('HL_', 'CARGO_', 'RUSTFLAGS'))}
        self.env.update(CARGO_BUILD_JOBS='2', RAYON_NUM_THREADS='2', CUDA_ROOT='/home/victor/cuda-root', LD_LIBRARY_PATH=CUDA_LD,
                        M125_EXPORT_DIR=str(ROOT / 'results/m125_ffn_export_wsl'))
        paths = [ROOT / p for p in ('hashline/src/gpu/cuda.rs', 'hashline/src/gpu/kernels.cu', 'hashline/src/gpu/mod.rs',
                                   'hashline/tests/zk60_gpu_commit.rs', 'hashline/tests/zk60_gpu_cache.rs',
                                   'hashline/Cargo.toml', 'hashline/Cargo.lock')]
        self.report['source_hashes'] = {str(p.relative_to(ROOT)): sha(p) for p in paths}
        self.report['runner_sha256'] = sha(Path(__file__))
        self.save()

    def save(self):
        temporary = OUT / 'validation.json.tmp'
        temporary.write_text(json.dumps(self.report, indent=2, sort_keys=True) + '\n')
        temporary.replace(OUT / 'validation.json')

    def run(self, name, argv, extra=None, timeout=1800):
        print('START', name, flush=True)
        self.report['current'] = name
        self.save()
        started = time.monotonic()
        with (OUT / (name + '.log')).open('w') as log:
            p = subprocess.run([str(a) for a in argv], cwd=ROOT, env=self.env | (extra or {}), stdout=log,
                               stderr=subprocess.STDOUT, timeout=timeout)
        record = {'name': name, 'argv': [str(a) for a in argv], 'environment': extra or {},
                  'exit_code': p.returncode, 'elapsed_shared_seconds': time.monotonic() - started}
        self.report['runs'].append(record)
        (OUT / (name + '.done')).write_text(str(p.returncode) + '\n')
        self.save()
        if p.returncode:
            raise RuntimeError(f'{name}: exit {p.returncode}')
        print('PASS', name, flush=True)
        return (OUT / (name + '.log')).read_text()

    def gpu_preflight(self, name):
        text = self.run(name + '-gpu-idle', ['nvidia-smi', '--query-gpu=name,memory.total,memory.used,utilization.gpu', '--format=csv,noheader'])
        lines = [line for line in text.splitlines() if line.strip()]
        if len(lines) != 1:
            raise RuntimeError('expected one GPU')
        _, total, used, util = [part.strip() for part in lines[0].split(',')]
        if int(used.split()[0]) > 512 or int(util.split()[0]) > 2 or int(total.split()[0]) < 8000:
            raise RuntimeError('GPU not idle or below the planned memory capacity; no job launched')
        apps = self.run(name + '-gpu-apps', ['nvidia-smi', '--query-compute-apps=pid,used_gpu_memory', '--format=csv,noheader'])
        if apps.strip():
            raise RuntimeError('another GPU compute process is present; no job launched')

    def finish(self):
        # The lock releases automatically even if a child fails or the process exits.
        with open('/tmp/zk-build.lock', 'w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            self.run('cpu-tests', [CARGO, 'test', '--release', '--offline', '-j', '2', '--manifest-path', 'hashline/Cargo.toml', '--', '--test-threads=2'])
            self.run('cpu-build', [CARGO, 'build', '--release', '--offline', '-j', '2', '--manifest-path', 'hashline/Cargo.toml', '--bin', 'hashline'])
            artifacts = self.run('gpu-test-build', [CARGO, 'test', '--release', '--offline', '-j', '2', '--features', 'gpu-cuda',
                '--manifest-path', 'hashline/Cargo.toml', '--test', 'zk60_gpu_commit', '--test', 'zk60_gpu_cache', '--no-run', '--message-format=json'],
                {'CARGO_TARGET_DIR': str(ROOT / 'hashline/target-gpu')})
            binaries = {}
            for line in artifacts.splitlines():
                try:
                    message = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if message.get('reason') == 'compiler-artifact' and message.get('executable') and 'test' in message['target']['kind']:
                    binaries[message['target']['name']] = message['executable']
            if set(binaries) != {'zk60_gpu_commit', 'zk60_gpu_cache'}:
                raise RuntimeError('missing GPU test executable')
            self.run('gpu-build', [CARGO, 'build', '--release', '--offline', '-j', '2', '--features', 'gpu-cuda',
                '--manifest-path', 'hashline/Cargo.toml', '--bin', 'hashline'], {'CARGO_TARGET_DIR': str(ROOT / 'hashline/target-gpu')})
        cpu, gpu = ROOT / 'hashline/target/release/hashline', ROOT / 'hashline/target-gpu/release/hashline'
        self.report['binary_hashes'] = {str(Path(p).relative_to(ROOT)): sha(Path(p)) for p in [cpu, gpu, *binaries.values()]}
        self.save()
        with open('/tmp/zk-heavy.lock', 'w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            for arm, switches in [('default', {}), ('compact-off', {'HL_GPU_P1_COMPACT': '0'}),
                                  ('pad-skip-off', {'HL_GPU_PAD_SKIP': '0'}),
                                  ('swizzles-on', {'HL_GPU_SMEM_SWZ': '1', 'HL_GPU_SMEM_SWZ_PB': '1'})]:
                self.gpu_preflight(arm)
                environment = {'HL_GPU': '1', 'HL_GPU_REQUIRED': '1'} | switches
                text = self.run(arm + '-oracles', [gpu, 'gpu-probe'], environment)
                for required in ('mul/add/sub mismatches 0', 'blake3 checks GREEN', 'ntt checks GREEN', 'chunked-commit checks GREEN'):
                    if required not in text:
                        raise RuntimeError(arm + ': absent oracle: ' + required)
                # The two new paths and their documented fallbacks all run the
                # boundary/allocation/device-negative suite, not a skip-only gate.
                self.gpu_preflight(arm + '-commit')
                text = self.run(arm + '-commit', [binaries['zk60_gpu_commit'], '--test-threads=1', '--nocapture'], environment)
                if not re.search(r'test result: ok\. 34 passed; 0 failed; 0 ignored', text) or 'ZK60_CL4_SUMMARY' not in text:
                    raise RuntimeError(arm + ': vacuous/incomplete commit suite')
            self.gpu_preflight('cache')
            text = self.run('gpu-cache', [binaries['zk60_gpu_cache'], '--test-threads=1', '--nocapture'], {'HL_GPU': '1', 'HL_GPU_REQUIRED': '1'})
            if 'test result: ok. 12 passed; 0 failed; 0 ignored' not in text:
                raise RuntimeError('incomplete cache suite')
            for arm, binary, switches in [('cpu', cpu, {}), ('gpu', gpu, {'HL_GPU': '1'}),
                                          ('gpu-chunked', gpu, {'HL_GPU': '1', 'HL_GPU_CHUNK_BYTES': '100000000', 'HL_GPU_CHUNK_ROWS': '128'})]:
                for profile, (want, size, args) in REFERENCE.items():
                    name = arm + '-' + profile
                    if arm != 'cpu':
                        self.gpu_preflight(name)
                    proof = SCRATCH / (name + '.proof')
                    if proof.exists():
                        raise RuntimeError('refusing a preexisting proof output')
                    text = self.run(name, [binary, 'pass', '12', '512', '--threads', '8', '--proof-out', proof, *args], switches)
                    if not re.search(r'PASS(?:-V3)? ACCEPT', text) or sha(proof) != want or proof.stat().st_size != size:
                        raise RuntimeError(name + ': verifier or frozen digest/length mismatch')
                    self.report['gates'].append({'name': name, 'sha256': want, 'bytes': size, 'accepted': True})
                    proof.unlink()  # only this runner's checked temporary output
                    self.save()
        for relative, expected in self.report['source_hashes'].items():
            if sha(ROOT / relative) != expected:
                raise RuntimeError('source changed during validation: ' + relative)
        self.report['state'] = 'passed'
        self.report['current'] = None
        self.save()


if __name__ == '__main__':
    if (OUT / 'validation.json').exists() or SCRATCH.exists():
        raise SystemExit('refusing to overwrite an integration run')
    SCRATCH.mkdir()
    runner = Runner()
    try:
        runner.finish()
    except BaseException as error:
        runner.report['state'] = 'failed'
        runner.report['error'] = str(error)
        runner.save()
        (OUT / 'run.done').write_text('1\n')
        raise
    (OUT / 'run.done').write_text('0\n')

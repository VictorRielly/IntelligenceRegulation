#!/usr/bin/env python3
"""Rebuild integrated binaries and cross-check native receipts and private IO."""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OUT = HERE / 'main-gate'
CARGO = '/home/victor/.cargo/bin/cargo'


def sha(p):
    h = hashlib.sha256()
    with p.open('rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()


def main():
    assert not (OUT / 'validation.json').exists(), 'existing evidence'
    candidate = json.loads((HERE / 'validation/validation.json').read_text())
    assert candidate['state'] == 'passed'
    publication = json.loads((ROOT / 'results/zk60_publication_20260920/validation.json').read_text())
    pins = dict(candidate['source_hashes'])
    pins['hashline/examples/zk60_private_block.rs'] = publication['source_hashes']['hashline/examples/zk60_private_block.rs']
    for p, h in pins.items():
        assert sha(ROOT / p) == h, 'integrated source differs: ' + p
    for p, h in candidate['main_binary_hashes'].items():
        assert sha(ROOT / p) == h, 'baseline binary already moved: ' + p
    scratch = Path(tempfile.mkdtemp(prefix='zk60-host-main-'))
    prior = {}
    for profile in ('attention', 'block'):
        old = ROOT / f'hashline/target/release/examples/zk60_private_{profile}'
        prior[profile] = scratch / ('old-' + profile)
        shutil.copy2(old, prior[profile])
    report = dict(state='waiting-build-lock', source_hashes=pins, runs=[], native_receipts=[],
                  runner_sha256=sha(Path(__file__)), scratch=str(scratch),
                  prior_verifier_hashes={p: sha(f) for p, f in prior.items()},
                  model_scale_speed_claim=False, privacy_extension=False)
    env = {k: v for k, v in os.environ.items() if not k.startswith(('HL_', 'CARGO_', 'RUSTFLAGS'))}
    env.update(CARGO_BUILD_JOBS='2', RAYON_NUM_THREADS='2', CUDA_ROOT='/home/victor/cuda-root',
               LD_LIBRARY_PATH='/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib')

    def save():
        p = OUT / 'validation.tmp'
        p.write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
        p.replace(OUT / 'validation.json')

    def run(name, argv, extra=None):
        report.update(state='running', current=name)
        save()
        started = time.monotonic()
        with (OUT / (name + '.log')).open('x') as log:
            child = subprocess.Popen(list(map(str, argv)), cwd=ROOT, env=env | (extra or {}),
                                     stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            report['child_pid'] = child.pid
            save()
            try:
                code = child.wait(timeout=1800)
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait()
                code = 124
        report['runs'].append(dict(name=name, argv=list(map(str, argv)), environment=extra or {},
                                   exit_code=code, elapsed_shared_seconds=time.monotonic() - started,
                                   log_sha256=sha(OUT / (name + '.log'))))
        report.pop('child_pid', None)
        (OUT / (name + '.done')).write_text(str(code) + '\n')
        save()
        assert code == 0, name
        return (OUT / (name + '.log')).read_text()

    def verify(name, binary, directory, size):
        log = run(name, [binary, 'verify', directory])
        assert f'ACCEPT: {size} bytes' in log and log.count('refused:') == 3, name

    save()
    try:
        with open('/tmp/zk-build.lock', 'w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            build = [CARGO, 'build', '--release', '--locked', '--offline', '-j', '2', '--manifest-path', 'hashline/Cargo.toml', '--bin', 'hashline']
            for profile in ('private_attention', 'private_block', 'repaired_mask_probe'):
                build += ['--example', 'zk60_' + profile]
            run('cpu-build', build)
            gpu_env = {'CARGO_TARGET_DIR': str(ROOT / 'hashline/target-gpu')}
            run('gpu-build', build + ['--features', 'gpu-cuda'], gpu_env)
            log = run('gpu-test-build', [CARGO, 'test', '--release', '--locked', '--offline', '-j', '2',
                      '--manifest-path', 'hashline/Cargo.toml', '--features', 'gpu-cuda', '--lib', '--no-run', '--message-format=json'], gpu_env)
            artifacts = []
            for line in log.splitlines():
                try:
                    row = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if row.get('reason') == 'compiler-artifact' and row.get('executable') and row.get('profile', {}).get('test'):
                    artifacts.append(Path(row['executable']))
            assert len(artifacts) == 1
        binaries = [ROOT / 'hashline' / target / 'release' / name
                    for target in ('target', 'target-gpu')
                    for name in ('hashline', 'examples/zk60_private_attention', 'examples/zk60_private_block', 'examples/zk60_repaired_mask_probe')]
        report['binary_hashes'] = {str(p.relative_to(ROOT)): sha(p) for p in binaries + artifacts}
        save()
        for profile, size in [('attention', 2245800), ('block', 2816472)]:
            new = {target: ROOT / f'hashline/{target}/release/examples/zk60_private_{profile}' for target in ('target', 'target-gpu')}
            directory = scratch / ('fresh-' + profile)
            run(profile + '-prove', [new['target'], 'prove', directory])
            for label, binary in [('old', prior[profile]), *new.items()]:
                verify(profile + '-verify-' + label, binary, directory, size)
            paths = sorted(directory.iterdir())
            assert {p.name for p in paths} == {profile + '_receipt.bin', profile + '_expected.bin'}
            assert (directory / (profile + '_receipt.bin')).stat().st_size == size
            # Only after acceptance do these public receipt/policy files enter
            # the retained evidence directory.
            dest = OUT / ('native-' + profile)
            shutil.copytree(directory, dest)
            report['native_receipts'].append(dict(profile=profile, bytes=size,
                files={str(p.relative_to(OUT)): sha(p) for p in dest.iterdir()}, verified_by=['prior-cpu', 'new-cpu', 'new-gpu-feature']))
            for mode in ('0', '1'):
                archived = ROOT / f'results/zk60_rowfold_20260919/integration/native-{profile}-{mode}'
                for target, binary in new.items():
                    verify(profile + '-archived-' + mode + '-' + target, binary, archived, size)
        with open('/tmp/zk-heavy.lock', 'w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            for pool in ('0', '1'):
                for fold in ('0', '1'):
                    log = run('gpu-feature-private-io-' + pool + fold,
                              [artifacts[0], 'zk::fresh_poc::io::tests', '--test-threads=2', '--nocapture'],
                              {'HL_GPU': '1', 'HL_GPU_REQUIRED': '1', 'HL_FSP_POOL': pool, 'HL_FSP_I8FOLD': fold})
                    assert 'test result: ok. 6 passed; 0 failed; 0 ignored' in log
                    assert 'BOUND_FFN privacy=P1' in log and 'BOUND_FFN privacy=P3' in log
        for p, h in pins.items():
            assert sha(ROOT / p) == h, 'source changed: ' + p
        for p, h in report['binary_hashes'].items():
            assert sha(ROOT / p) == h, 'binary changed: ' + p
        assert sha(Path(__file__)) == report['runner_sha256']
        report.update(state='passed', current=None)
        save()
        (OUT / 'run.done').write_text('0\n')
    except BaseException as e:
        report.update(state='failed', error=repr(e))
        save()
        (OUT / 'run.done').write_text('1\n')
        raise


if __name__ == '__main__':
    OUT.mkdir(exist_ok=True)
    if sys.argv[1:] == ['--detach']:
        with (OUT / 'launch.log').open('x') as log:
            child = subprocess.Popen([sys.executable, str(Path(__file__).resolve())], cwd=ROOT,
                                     stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        (OUT / 'process.json').write_text(json.dumps(dict(pid=child.pid, detached=True)) + '\n')
        print('Detached main integration gate PID', child.pid, flush=True)
    else:
        main()

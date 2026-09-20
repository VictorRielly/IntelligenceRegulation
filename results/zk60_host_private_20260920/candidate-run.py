#!/usr/bin/env python3
"""Combined host/private optimization gates; no model-width timing run."""
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
OUT = Path(__file__).resolve().parent
CARGO = '/home/victor/.cargo/bin/cargo'
MAIN = Path('/home/victor/IntelligenceRegulation')


def sha(p):
    h = hashlib.sha256()
    with Path(p).open('rb') as f:
        for b in iter(lambda: f.read(1024 * 1024), b''):
            h.update(b)
    return h.hexdigest()


def totals(text):
    rows = [tuple(map(int, m)) for m in re.findall(r'test result: ok\. (\d+) passed; (\d+) failed; (\d+) ignored', text)]
    return tuple(map(sum, zip(*rows))) if rows else (0, 0, 0)


def main():
    if (OUT / 'validation.json').exists():
        raise SystemExit('refusing to overwrite evidence')
    sources = sorted(p for c in ['hashline', 'zkp-core', 'private-block-kernel']
                     for sub in ['src', 'tests', 'examples'] for p in (ROOT / c / sub).rglob('*')
                     if p.is_file() and p.suffix in ('.rs', '.cu'))
    sources += [ROOT / c / f for c in ['hashline', 'zkp-core', 'private-block-kernel']
                for f in ['Cargo.toml', 'Cargo.lock'] if (ROOT / c / f).exists()]
    baseline = json.loads((MAIN / 'results/zk60_rowfold_20260919/integration/validation.json').read_text())
    spec = importlib.util.spec_from_file_location('frozen_reference', ROOT / 'results/zk60_fsp_l9_integration_20260919/run.py')
    reference = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(reference)
    report = dict(state='running', runs=[], proof_gates=[], probes=[], binary_hashes={},
                  source_hashes={str(p.relative_to(ROOT)): sha(p) for p in sources},
                  runner_sha256=sha(Path(__file__)), reference_sha256=sha(Path(spec.origin)),
                  base='4bf1fa0', deliveries=['04894c7', 'a328dea', 'ad0b55c'],
                  main_binary_hashes=baseline['binary_hashes'], privacy_acceptance=False,
                  model_scale_speed_claim=False)
    env = {k: v for k, v in os.environ.items() if not k.startswith(('HL_', 'CARGO_', 'RUSTFLAGS'))}
    env.update(CARGO_BUILD_JOBS='2', RAYON_NUM_THREADS='2', CUDA_ROOT='/home/victor/cuda-root',
               LD_LIBRARY_PATH='/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib',
               M125_EXPORT_DIR=str(MAIN / 'results/m125_ffn_export_wsl'))
    scratch = Path(tempfile.mkdtemp(prefix='zk60-host-private-'))
    report['scratch'] = str(scratch)

    def save():
        tmp = OUT / 'validation.tmp'
        tmp.write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
        tmp.replace(OUT / 'validation.json')

    def run(name, argv, extra=None):
        report['current'] = name
        save()
        print('START', name, flush=True)
        argv = list(map(str, argv))
        start = time.monotonic()
        with (OUT / (name + '.log')).open('x') as log:
            child = subprocess.Popen(argv, cwd=ROOT, env=env | (extra or {}), stdin=subprocess.DEVNULL,
                                     stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            report['child_pid'] = child.pid
            save()
            try:
                code = child.wait(timeout=1800)
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait()
                code = 124
        report['runs'].append(dict(name=name, argv=argv, environment=extra or {}, exit_code=code,
                                   elapsed_shared_seconds=time.monotonic() - start,
                                   log_sha256=sha(OUT / (name + '.log'))))
        (OUT / (name + '.done')).write_text(str(code) + '\n')
        report.pop('child_pid', None)
        save()
        if code:
            raise RuntimeError(name + ': exit ' + str(code))
        print('PASS', name, flush=True)
        return (OUT / (name + '.log')).read_text()

    def idle(name):
        samples, streak = [], 0
        for _ in range(60):
            d = subprocess.check_output(['nvidia-smi', '--query-gpu=name,memory.total,memory.used,utilization.gpu', '--format=csv,noheader'], text=True, timeout=20)
            apps = subprocess.check_output(['nvidia-smi', '--query-compute-apps=pid,used_gpu_memory', '--format=csv,noheader'], text=True, timeout=20)
            fields = d.strip().split(',')
            assert len(fields) == 4, 'expected one device'
            _, total, used, util = fields
            ok = int(total.split()[0]) >= 8000 and int(used.split()[0]) <= 512 and int(util.split()[0]) <= 2 and not apps.strip()
            samples.append(dict(device=d.strip(), apps=apps.strip(), idle=ok))
            streak = streak + 1 if ok else 0
            if streak == 2:
                break
            time.sleep(1)
        (OUT / (name + '-idle.json')).write_text(json.dumps(samples, indent=2) + '\n')
        assert streak == 2, name + ': device preflight not idle'

    def artifacts(text):
        out = {}
        for line in text.splitlines():
            try:
                d = json.loads(line)
            except json.JSONDecodeError:
                continue
            if d.get('reason') == 'compiler-artifact' and d.get('executable') and d.get('profile', {}).get('test'):
                out[d['target']['name']] = Path(d['executable'])
        return out

    def proof(name, binary, profile, extra, args=()):
        if extra.get('HL_GPU') == '1':
            idle(name)
        digest, size, profile_args = reference.REFERENCE[profile]
        output = scratch / (name + '.proof')
        text = run(name, [binary, 'pass', '12', '512', '--threads', '2', '--proof-out', output, *profile_args, *args], extra)
        assert re.search(r'PASS(?:-V3)? ACCEPT', text), name + ': no ACCEPT'
        assert output.stat().st_size == size and sha(output) == digest, name + ': frozen bytes differ'
        if extra.get('HL_GPU') == '1':
            assert 'gpu: ON' in text, name + ': no device'
        report['proof_gates'].append(dict(name=name, sha256=digest, bytes=size, accepted=True))
        save()
        output.unlink()  # only this job's successfully checked scratch proof
        return text

    save()
    try:
        with open('/tmp/zk-build.lock', 'w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            test = [CARGO, 'test', '--release', '--locked', '--offline', '-j', '2', '--manifest-path', 'hashline/Cargo.toml']
            text = run('storage-tests', test + ['--features', 'stable-weight-storage', '--', '--test-threads=2'],
                       {'CARGO_TARGET_DIR': str(ROOT / 'hashline/target-storage')})
            report['storage_totals'] = totals(text)
            assert totals(text) == (307, 0, 2), 'unexpected complete storage inventory: ' + str(totals(text))
            cpu_tests = artifacts(run('cpu-lib-build', test + ['--lib', '--no-run', '--message-format=json']))['hashline']
            build = [CARGO, 'build', '--release', '--locked', '--offline', '-j', '2', '--manifest-path', 'hashline/Cargo.toml']
            examples = ['zk60_repaired_mask_probe', 'zk60_private_attention', 'zk60_private_block']
            example_args = [x for n in examples for x in ['--example', n]]
            run('cpu-build', build + ['--bin', 'hashline', *example_args])
            gpu_env = {'CARGO_TARGET_DIR': str(ROOT / 'hashline/target-gpu')}
            gpu_tests = artifacts(run('gpu-test-build', test + ['--features', 'gpu-cuda', '--lib', '--test', 'zk60_gpu_commit', '--test', 'zk60_gpu_cache', '--no-run', '--message-format=json'], gpu_env))
            assert set(gpu_tests) == {'hashline', 'zk60_gpu_commit', 'zk60_gpu_cache'}
            run('gpu-build', build + ['--features', 'gpu-cuda', '--bin', 'hashline', *example_args], gpu_env)
        cpu = ROOT / 'hashline/target/release/hashline'
        gpu = ROOT / 'hashline/target-gpu/release/hashline'
        binaries = [cpu, gpu, cpu_tests, *gpu_tests.values()]
        binaries += [ROOT / 'hashline' / target / 'release/examples' / n for target in ['target', 'target-gpu'] for n in examples]
        report['binary_hashes'] = {str(p.relative_to(ROOT)): sha(p) for p in binaries}
        save()
        # Fresh processes isolate all OnceLock switches. Both private modes
        # and adversarial endpoint controls run through every pool/fold arm.
        for pool in ['0', '1']:
            for fold in ['0', '1']:
                extra = {'HL_FSP_POOL': pool, 'HL_FSP_I8FOLD': fold}
                for group, count in [('zk::fresh_poc::io::tests', 6), ('zk::mr1_probe_tests', 6)]:
                    text = run('cpu-' + group.replace('::', '-') + '-' + pool + fold,
                               [cpu_tests, group, '--test-threads=2', '--nocapture'], extra)
                    assert totals(text) == (count, 0, 0), group + ': incomplete execution'
        for group, count in [('zk::zkhostbuf::tests', 1), ('gpu::planes::tests', 5), ('wcache::tests', 3), ('private_block::norm_alias', 5)]:
            text = run('cpu-' + group.replace('::', '-'), [cpu_tests, group, '--test-threads=2', '--nocapture'])
            assert totals(text) == (count, 0, 0), group + ': incomplete execution'
        text = run('gpu-upload-host-oracles', [gpu_tests['hashline'], 'gpu::cuda::fsp4_plane_oracle', '--test-threads=2', '--nocapture'])
        assert totals(text) == (3, 0, 0)
        with open('/tmp/zk-heavy.lock', 'w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            idle('device')
            text = run('gpu-oracles', [gpu, 'gpu-probe'], {'HL_GPU': '1', 'HL_GPU_REQUIRED': '1'})
            for needed in ['mul/add/sub mismatches 0', 'blake3 checks GREEN', 'ntt checks GREEN', 'chunked-commit checks GREEN']:
                assert needed in text, needed
            idle('commit')
            text = run('gpu-commit', [gpu_tests['zk60_gpu_commit'], '--test-threads=1', '--nocapture'], {'HL_GPU': '1', 'HL_GPU_REQUIRED': '1'})
            assert totals(text) == (34, 0, 0)
            summaries = [json.loads(s.split('ZK60_CL4_SUMMARY ', 1)[1]) for s in text.splitlines() if s.startswith('ZK60_CL4_SUMMARY ')]
            assert len(summaries) == 1 and summaries[0]['executed_cases'] == 189
            assert summaries[0]['gpu_enabled'] and summaries[0]['gpu_required']
            idle('cache')
            text = run('gpu-cache', [gpu_tests['zk60_gpu_cache'], '--test-threads=1', '--nocapture'], {'HL_GPU': '1', 'HL_GPU_REQUIRED': '1'})
            assert totals(text) == (12, 0, 0)
            for arm, binary, extra in [('cpu', cpu, {}), ('gpu', gpu, {'HL_GPU': '1'}),
                ('gpu-chunked', gpu, {'HL_GPU': '1', 'HL_GPU_CHUNK_BYTES': '100000000', 'HL_GPU_CHUNK_ROWS': '128', 'HL_ZK_CHUNK': '1', 'HL_GPU_VERBOSE': '1'})]:
                for profile in reference.REFERENCE:
                    text = proof(arm + '-' + profile, binary, profile, extra)
                    if arm == 'gpu-chunked':
                        assert ('CHUNKED (forced)' in text if profile.startswith('legacy') else re.search(r'chunked commits [1-9][0-9]*', text))
            # The standard 100 MB threshold does not stream W. These 10 MB
            # cases assert the source route as well as full proof bytes.
            for route, flags in [('resident', {'HL_GPU_STREAM_COMMIT': '0'}), ('streamed', {'HL_GPU_CHUNK_BYTES': '10000000', 'HL_GPU_CHUNK_ROWS': '128'})]:
                for arm, switches, planes in [('planes', {}, True), ('planes-off', {'HL_FSP4_PLANES': '0'}, False), ('narrow-off', {'HL_GPU_NARROW': '0'}, False)]:
                    text = proof(route + '-' + arm, gpu, 'v3', {'HL_GPU': '1', 'HL_FSP4_TIMING': '1', 'HL_CONV_VERBOSE': '1'} | flags | switches)
                    w_lines = [s for s in text.splitlines() if 'conv W ' in s]
                    assert len(w_lines) == 12 and all(('[planes]' in s) == planes for s in w_lines)
                    if planes:
                        marker = 'whole-buffer narrow upload' if route == 'resident' else 'streamed commit rows'
                        assert any(marker in s and '(int8 planes)' in s for s in text.splitlines())
                    else:
                        assert '(int8 planes)' not in text
            cache_dir = scratch / 'wcache'
            for arm in ['cold', 'warm']:
                text = proof('gpu-plane-cache-' + arm, gpu, 'v3', {'HL_GPU': '1', 'HL_WCACHE_VERBOSE': '1', 'HL_CONV_VERBOSE': '1'}, ['--wcache', cache_dir])
                assert ('hits 0 | misses 12' if arm == 'cold' else 'hits 12 | misses 0') in text
                w_lines = [s for s in text.splitlines() if 'conv W ' in s]
                assert len(w_lines) == 12 and all(('[planes]' in s) == (arm == 'cold') for s in w_lines)
            # One diagnostic run per backend, not a timing comparison or
            # privacy claim. This proves all three arms on the same fixture.
            for arm, target, extra in [('cpu', 'target', {}), ('gpu', 'target-gpu', {'HL_GPU': '1'})]:
                if arm == 'gpu': idle('repaired-probe')
                text = run(arm + '-repaired-probe', [ROOT / 'hashline' / target / 'release/examples/zk60_repaired_mask_probe', '12', '512', 'all', '--threads', '2', '--export', reference.REFERENCE['v3'][2][-1]], extra)
                rows = [json.loads(s[len('PROBE_JSON '):]) for s in text.splitlines() if s.startswith('PROBE_JSON ')]
                assert {r['arm'] for r in rows} == {'public', 'legacy', 'repaired'} and len(rows) == 3
                assert all(r['accept'] and r['layers'] == 12 and r['tokens'] == 512 for r in rows)
                assert all(r['gpu'] == (arm == 'gpu') for r in rows)
                report['probes'].append(dict(backend=arm, rows=rows))
                save()
        for p, h in report['source_hashes'].items(): assert sha(ROOT / p) == h, 'source changed: ' + p
        for p, h in report['binary_hashes'].items(): assert sha(ROOT / p) == h, 'binary changed: ' + p
        for p, h in report['main_binary_hashes'].items(): assert sha(MAIN / p) == h, 'main binary changed: ' + p
        assert sha(Path(__file__)) == report['runner_sha256'], 'runner changed'
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
                                     stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
                                     start_new_session=True)
        (OUT / 'process.json').write_text(json.dumps(dict(pid=child.pid, detached=True)) + '\n')
        print('Detached combined validation PID', child.pid, flush=True)
    else:
        main()

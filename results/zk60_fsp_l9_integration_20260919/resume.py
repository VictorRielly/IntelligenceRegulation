#!/usr/bin/env python3
"""Resume GPU gates after a terminal idle-preflight refusal; reuse pinned builds."""
import importlib.util
import json
from pathlib import Path
import re
import time
import fcntl

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('fsp_integration_original', HERE / 'run.py')
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
PRIOR = json.loads((HERE / 'validation.json').read_text())
OUT = HERE / 'attempt-2'
SCRATCH = Path('/tmp/zk60-fsp-l9-integration-20260919-attempt-2')


class Resume(base.Runner):
    def __init__(self):
        super().__init__()
        self.report['prior_report'] = '../validation.json'
        self.report['runner_sha256'] = base.sha(Path(__file__))
        self.report['imported_runner_sha256'] = base.sha(HERE / 'run.py')
        self.report['binary_hashes'] = PRIOR['binary_hashes']
        self.report['reused_builds'] = [r['name'] for r in PRIOR['runs'] if r['name'] in ('cpu-tests', 'cpu-build', 'gpu-test-build', 'gpu-build')]
        self.save()

    def gpu_preflight(self, name):
        consecutive = 0
        for attempt in range(60):
            result = self.run(name + f'-gpu-idle-{attempt:02d}', ['nvidia-smi', '--query-gpu=name,memory.total,memory.used,utilization.gpu', '--format=csv,noheader'])
            lines = [line for line in result.splitlines() if line.strip()]
            if len(lines) != 1:
                raise RuntimeError('expected one GPU')
            _, total, used, utilization = [p.strip() for p in lines[0].split(',')]
            if int(total.split()[0]) < 8000:
                raise RuntimeError('insufficient GPU memory capacity')
            idle = int(used.split()[0]) <= 512 and int(utilization.split()[0]) <= 2
            consecutive = consecutive + 1 if idle else 0
            if consecutive == 2:
                apps = self.run(name + '-gpu-apps', ['nvidia-smi', '--query-compute-apps=pid,used_gpu_memory', '--format=csv,noheader'])
                if not apps.strip():
                    return
                consecutive = 0
            time.sleep(1)
        raise RuntimeError('no two consecutive idle readings with empty compute-process list; no job launched')

    def finish(self):
        cpu = base.ROOT / 'hashline/target/release/hashline'
        gpu = base.ROOT / 'hashline/target-gpu/release/hashline'
        binaries = {}
        for relative in PRIOR['binary_hashes']:
            name = Path(relative).name
            for target in ('zk60_gpu_commit', 'zk60_gpu_cache'):
                if name.startswith(target + '-'):
                    binaries[target] = base.ROOT / relative
        if set(binaries) != {'zk60_gpu_commit', 'zk60_gpu_cache'}:
            raise RuntimeError('missing pinned GPU test executable')
        with open('/tmp/zk-heavy.lock', 'w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            for relative, digest in PRIOR['binary_hashes'].items():
                if base.sha(base.ROOT / relative) != digest:
                    raise RuntimeError('binary changed while queued: ' + relative)
            for arm, switches in [('default', {}), ('compact-off', {'HL_GPU_P1_COMPACT': '0'}),
                                  ('pad-skip-off', {'HL_GPU_PAD_SKIP': '0'}),
                                  ('swizzles-on', {'HL_GPU_SMEM_SWZ': '1', 'HL_GPU_SMEM_SWZ_PB': '1'})]:
                self.gpu_preflight(arm)
                environment = {'HL_GPU': '1', 'HL_GPU_REQUIRED': '1'} | switches
                text = self.run(arm + '-oracles', [gpu, 'gpu-probe'], environment)
                for required in ('mul/add/sub mismatches 0', 'blake3 checks GREEN', 'ntt checks GREEN', 'chunked-commit checks GREEN'):
                    if required not in text:
                        raise RuntimeError(arm + ': absent oracle: ' + required)
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
                for profile, (want, size, args) in base.REFERENCE.items():
                    name = arm + '-' + profile
                    if arm != 'cpu':
                        self.gpu_preflight(name)
                    proof = SCRATCH / (name + '.proof')
                    if proof.exists():
                        raise RuntimeError('refusing a preexisting proof output')
                    text = self.run(name, [binary, 'pass', '12', '512', '--threads', '8', '--proof-out', proof, *args], switches)
                    if not re.search(r'PASS(?:-V3)? ACCEPT', text) or base.sha(proof) != want or proof.stat().st_size != size:
                        raise RuntimeError(name + ': verifier or frozen digest/length mismatch')
                    self.report['gates'].append({'name': name, 'sha256': want, 'bytes': size, 'accepted': True})
                    proof.unlink()
                    self.save()
        for relative, expected in PRIOR['source_hashes'].items():
            if base.sha(base.ROOT / relative) != expected:
                raise RuntimeError('source changed during validation: ' + relative)
        self.report['state'] = 'passed'
        self.report['current'] = None
        self.save()


if __name__ == '__main__':
    if (HERE / 'run.done').read_text().strip() != '1' or PRIOR['state'] != 'failed' or PRIOR['current'] != 'default-gpu-idle' or PRIOR['gates']:
        raise SystemExit('prior job was not the expected terminal preflight refusal')
    if base.sha(HERE / 'run.py') != PRIOR['runner_sha256']:
        raise SystemExit('original runner changed')
    for relative, digest in (PRIOR['source_hashes'] | PRIOR['binary_hashes']).items():
        if base.sha(base.ROOT / relative) != digest:
            raise SystemExit('pinned input changed: ' + relative)
    if OUT.exists() or SCRATCH.exists():
        raise SystemExit('refusing to overwrite a retry')
    OUT.mkdir()
    SCRATCH.mkdir()
    base.OUT = OUT
    runner = Resume()
    try:
        runner.finish()
    except BaseException as error:
        runner.report['state'] = 'failed'
        runner.report['error'] = str(error)
        runner.save()
        (OUT / 'run.done').write_text('1\n')
        raise
    (OUT / 'run.done').write_text('0\n')

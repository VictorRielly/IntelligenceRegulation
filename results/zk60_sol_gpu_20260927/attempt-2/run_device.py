#!/usr/bin/env python3
"""Source-pinned, bounded RTX 4070 device correctness gate; no build or network."""
from __future__ import annotations
import fcntl
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
SRC = Path('/tmp/zk60-sol-gpu-20260927')
LD = '/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib'

def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main() -> int:
    pins = json.loads((HERE / 'pins.json').read_text())
    for rel, expected in pins['sources'].items():
        got = sha(SRC / rel)
        if got != expected:
            raise RuntimeError(f'source drift: {rel}: {got} != {expected}')
    tests = {name: SRC / rel for name, rel in pins['binaries'].items()}
    for name, path in tests.items():
        got = sha(path)
        if got != pins['binary_sha256'][name]:
            raise RuntimeError(f'binary drift: {name}: {got}')
    env = {k: v for k, v in os.environ.items() if not k.startswith('HL_')}
    env.update(CUDA_ROOT='/home/victor/cuda-root', LD_LIBRARY_PATH=LD,
               HL_GPU_REQUIRED='1', HL_GPU_CHUNK_ROWS='128', RAYON_NUM_THREADS='2')
    cases = []
    oracle = 'tagged_column_hashes_and_full_commitment_match_cpu'
    receipt = 'private_block::dense_tests::an_honest_dense_block_proves_and_verifies_from_bytes_at_the_rung_g'
    for mode, compact in (('off', '0'), ('force', '0'), ('force', '1')):
        e = dict(env, HL_GPU='1', HL_ZK_CHUNK=mode, HL_ZK_COMPACT_PAD=compact)
        name = f'keyed-{mode}' + ('-compact' if compact == '1' else '')
        cases.append((name, tests['oracle'], [oracle, '--exact', '--nocapture'], e, 180))
    # Both ends of the same full tagged rung-G receipt path. These tests
    # verify from bytes and reject truncation; entropy is fresh per process,
    # so receipt byte identity is not claimed across processes.
    cases.append(('receipt-cpu', tests['lib'], [receipt, '--exact', '--nocapture'], dict(env, HL_GPU='0', HL_GPU_REQUIRED='0'), 600))
    cases.append(('receipt-gpu', tests['lib'], [receipt, '--exact', '--nocapture'], dict(env, HL_GPU='1', HL_ZK_CHUNK='force'), 600))
    report = {'status': 'running', 'device': 'NVIDIA GeForce RTX 4070 Laptop GPU (8188 MiB, driver 566.14; root inventory)',
              'pins': pins, 'cases': [], 'started_unix': time.time()}
    (HERE / 'device_report.json').write_text(json.dumps(report, indent=2))
    with open('/tmp/zk-heavy.lock', 'w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        for name, binary, args, case_env, timeout in cases:
            # Recheck after the heavy lock and before every binary: a queued
            # build must not change the source or executable under this gate.
            for rel, expected in pins['sources'].items():
                if sha(SRC / rel) != expected:
                    raise RuntimeError(f'source changed while waiting: {rel}')
            if sha(binary) != pins['binary_sha256']['oracle' if name.startswith('keyed-') else 'lib']:
                raise RuntimeError(f'binary changed while waiting: {binary}')
            started = time.time()
            log = HERE / f'{name}.log'
            with log.open('w') as output:
                output.write(f'binary={binary}\nsha256={sha(binary)}\nargs={args!r}\nmode={case_env.get("HL_ZK_CHUNK")}\n')
                output.flush()
                try:
                    proc = subprocess.run([str(binary), *args], cwd=SRC/'hashline', env=case_env,
                                          stdout=output, stderr=subprocess.STDOUT, timeout=timeout, check=False)
                    code = proc.returncode
                except subprocess.TimeoutExpired:
                    code = 124
            body = log.read_text(errors='replace')
            valid = code == 0 and 'test result: ok.' in body and '1 passed; 0 failed' in body
            accepted = body.count('[ZK60] keyed gpu zk commit accepted')
            if name.startswith('keyed-'):
                valid = valid and accepted >= 1 and 'SKIP tagged GPU oracle' not in body
            if name == 'receipt-gpu':
                # Two endpoints plus A and H use the tagged backend. The
                # separate mask remains on its existing CPU implementation.
                valid = valid and accepted >= 4
            if 'keyed gpu zk commit declined' in body:
                valid = False
            report['cases'].append({'name': name, 'exit_code': code, 'passed': valid,
                                    'seconds': time.time()-started, 'accepted_keyed_commits': accepted,
                                    'log': log.name, 'log_sha256': sha(log)})
            (HERE / 'device_report.json').write_text(json.dumps(report, indent=2))
            if not valid:
                report['status'] = 'failed'
                (HERE / 'device_report.json').write_text(json.dumps(report, indent=2))
                return 1
    report['status'] = 'passed'
    report['ended_unix'] = time.time()
    (HERE / 'device_report.json').write_text(json.dumps(report, indent=2))
    return 0

if __name__ == '__main__':
    try:
        rc = main()
    except Exception as exc:
        (HERE / 'device_error.txt').write_text(f'{type(exc).__name__}: {exc}\n')
        rc = 1
    (HERE / 'device.done').write_text(str(rc) + '\n')
    sys.exit(rc)

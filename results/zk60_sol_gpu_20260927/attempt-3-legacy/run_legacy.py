#!/usr/bin/env python3
"""Pinned legacy CUDA oracle, full library, and eight frozen proof-byte gates."""
from __future__ import annotations
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
SRC = Path('/tmp/zk60-sol-gpu-20260927')
LD = '/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib'
EXPORT = '/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export'
FROZEN = {
    'v2': ('50cf7bdfd6b5b182f9c029c3d62087ca9e0e273be218d017609323c15146a17d', 66844928),
    'v3': ('5f368db6240e061428a90eccdb22ff456b1507708ef95f1bed39615042973c1d', 70758084),
    'zk': ('021485e4f80ec695ddc0b05423a941e1a165c222efe12aca5bf3cd2f0d02282d', 87228528),
    'zkv3': ('40eb54795e023c77382a31020aac728485daaae2e1b5ec58c3c82d04f94aac17', 87697008),
}

def sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()

def check_pins(pins: dict) -> None:
    for rel, expected in pins['sources'].items():
        if sha(SRC/rel) != expected:
            raise RuntimeError(f'source drift: {rel}')
    for name, rel in pins['binaries'].items():
        if sha(SRC/rel) != pins['binary_sha256'][name]:
            raise RuntimeError(f'binary drift: {name}')

def main() -> int:
    pins = json.loads((HERE/'pins.json').read_text())
    check_pins(pins)
    env = {k:v for k,v in os.environ.items() if not k.startswith('HL_')}
    env.update(CUDA_ROOT='/home/victor/cuda-root', LD_LIBRARY_PATH=LD,
               HL_GPU='1', HL_GPU_REQUIRED='1', RAYON_NUM_THREADS='2')
    cases = [('legacy-oracle', pins['binaries']['legacy_oracle'], ['--test-threads=1','--nocapture'], 300, None),
             ('full-gpu-lib', pins['binaries']['lib'], ['--test-threads=1','--nocapture'], 900, None)]
    for mode in ('resident','chunked'):
        for profile in ('v2','v3','zk','zkv3'):
            proof = HERE/f'{mode}-{profile}.proof'
            args = ['pass','12','512','--threads','2','--proof-out',str(proof)]
            if profile in ('zk','zkv3'): args += ['--zk','--seed','1']
            if profile in ('v3','zkv3'): args += ['--profile','v3','--export',EXPORT]
            cases.append((f'{mode}-{profile}', pins['binaries']['hashline_bin'], args, 240, proof))
    report = {'status':'running','pins':pins,'frozen_source':'scripts/hashline_cl_gpu_gates.py FROZEN at workspace 2026-09-27',
              'device':'RTX 4070 Laptop GPU, driver 566.14 (root inventory)','cases':[],'started_unix':time.time()}
    (HERE/'report.json').write_text(json.dumps(report,indent=2))
    with open('/tmp/zk-heavy.lock','w') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        for name, rel, args, timeout, proof in cases:
            check_pins(pins)
            binary = SRC/rel
            case_env = dict(env, HL_ZK_CHUNK=('force' if name.startswith('chunked-') else 'off'))
            log = HERE/f'{name}.log'
            started = time.time()
            with log.open('w') as output:
                output.write(f'binary={binary}\nsha256={sha(binary)}\nargs={args!r}\n')
                output.flush()
                try:
                    code = subprocess.run([str(binary),*args],cwd=SRC/'hashline',env=case_env,
                                          stdout=output,stderr=subprocess.STDOUT,timeout=timeout).returncode
                except subprocess.TimeoutExpired:
                    code = 124
            body = log.read_text(errors='replace')
            row = {'name':name,'exit_code':code,'seconds':time.time()-started,
                   'log':log.name,'log_sha256':sha(log)}
            valid = code == 0
            if name == 'legacy-oracle':
                matches = re.findall(r'ZK60_CL4_SUMMARY (\{[^\n]+\})',body)
                summary = json.loads(matches[-1]) if matches else None
                row['summary'] = summary
                valid = valid and summary is not None and summary.get('executed_cases') == 189 and summary.get('gpu_enabled') is True and summary.get('gpu_required') is True and 'test result: ok.' in body
            elif name == 'full-gpu-lib':
                m = re.search(r'test result: ok\. (\d+) passed; 0 failed; (\d+) ignored;',body)
                row['library_result'] = list(map(int,m.groups())) if m else None
                valid = valid and m is not None and sum(map(int,m.groups())) == 509
            else:
                expected_sha, expected_size = FROZEN[name.split('-',1)[1]]
                if proof and proof.exists():
                    row['proof_sha256'] = sha(proof)
                    row['proof_bytes'] = proof.stat().st_size
                    valid = valid and row['proof_sha256'] == expected_sha and row['proof_bytes'] == expected_size
                    proof.unlink()  # the full digest/size and the prover/verifier log are retained
                else:
                    valid = False
                valid = valid and 'gpu: ON' in body and 'PASS ACCEPT' in body
            valid = valid and 'gpu commit declined' not in body and 'gpu zk commit declined' not in body
            row['passed'] = bool(valid)
            report['cases'].append(row)
            (HERE/'report.json').write_text(json.dumps(report,indent=2))
            if not valid:
                report['status']='failed'
                (HERE/'report.json').write_text(json.dumps(report,indent=2))
                return 1
    report['status']='passed';report['ended_unix']=time.time()
    (HERE/'report.json').write_text(json.dumps(report,indent=2))
    return 0

if __name__ == '__main__':
    try: rc=main()
    except Exception as exc:
        (HERE/'error.txt').write_text(f'{type(exc).__name__}: {exc}\n')
        rc=1
    (HERE/'done').write_text(str(rc)+'\n')
    sys.exit(rc)

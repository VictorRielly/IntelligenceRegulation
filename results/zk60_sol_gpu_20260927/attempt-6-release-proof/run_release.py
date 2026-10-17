#!/usr/bin/env python3
"""Pinned missing-fixture library repair and frozen proof gates, reusing prior gates."""
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
PRIOR = HERE.parent/'attempt-3-legacy'
PRIOR_FULL = HERE.parent/'attempt-4-release'
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
        for block in iter(lambda: f.read(1<<20), b''):
            h.update(block)
    return h.hexdigest()

def check_pins(pins: dict, fixtures: dict) -> None:
    for rel, expected in pins['sources'].items():
        if sha(SRC/rel) != expected: raise RuntimeError(f'source drift: {rel}')
    for name, rel in pins['binaries'].items():
        if sha(SRC/rel) != pins['binary_sha256'][name]: raise RuntimeError(f'binary drift: {name}')
    for rel, spec in fixtures.items():
        p = SRC/rel
        if sha(p) != spec['sha256'] or p.stat().st_size != spec['bytes']:
            raise RuntimeError(f'fixture drift: {rel}')

def prior_oracle(pins: dict) -> dict:
    prior = json.loads((PRIOR/'report.json').read_text())
    oracle = next((x for x in prior['cases'] if x['name']=='legacy-oracle'), None)
    if oracle is None or not oracle['passed'] or oracle['exit_code'] != 0 or oracle['summary']['executed_cases'] != 189 or oracle['summary']['gpu_enabled'] is not True or oracle['summary']['gpu_required'] is not True:
        raise RuntimeError('the prior 189-case device oracle did not pass')
    if prior['pins']['sources'] != pins['sources']:
        raise RuntimeError('source changed since prior device oracle')
    if prior['pins']['binary_sha256']['legacy_oracle'] != pins['binary_sha256']['legacy_oracle']:
        raise RuntimeError('prior device oracle binary changed')
    if sha(PRIOR/oracle['log']) != oracle['log_sha256']:
        raise RuntimeError('prior device oracle log changed')
    return {'report':str(PRIOR/'report.json'),'report_sha256':sha(PRIOR/'report.json'),
            'log':str(PRIOR/oracle['log']),'log_sha256':oracle['log_sha256'],
            'binary_sha256':pins['binary_sha256']['legacy_oracle'],'executed_cases':189}

def prior_full_library(pins: dict) -> dict:
    prior = json.loads((PRIOR_FULL/'report.json').read_text())
    cases = prior.get('cases', [])
    if prior.get('status') != 'failed' or len(cases) != 1 or cases[0]['name'] != 'full-gpu-lib':
        raise RuntimeError('prior release library report changed')
    lib = cases[0]
    if lib['exit_code'] != 101 or lib['passed'] or prior['pins']['sources'] != pins['sources']:
        raise RuntimeError('prior release library source/result changed')
    if prior['pins']['binary_sha256']['release_lib'] != pins['binary_sha256']['release_lib']:
        raise RuntimeError('prior release library binary changed')
    body = (PRIOR_FULL/lib['log']).read_text(errors='replace')
    if sha(PRIOR_FULL/lib['log']) != lib['log_sha256']:
        raise RuntimeError('prior release library log changed')
    if not re.search(r'test result: FAILED\. 491 passed; 1 failed; 17 ignored; 0 measured; 0 filtered out;',body):
        raise RuntimeError('prior release library counts changed')
    failure = 'private_block::review_tests::a_toy_receipt_made_before_the_lane_still_verifies'
    if not re.search(r'failures:\s+failures:\s+'+re.escape(failure)+r'\s+test result:',body):
        raise RuntimeError('prior release library failure changed')
    if 'no pre-lane toy receipt was found: this check did not run' not in body:
        raise RuntimeError('prior release library failure cause changed')
    return {'report':str(PRIOR_FULL/'report.json'),'report_sha256':sha(PRIOR_FULL/'report.json'),
            'log':str(PRIOR_FULL/lib['log']),'log_sha256':lib['log_sha256'],
            'binary_sha256':pins['binary_sha256']['release_lib'],
            'passed_cases':491,'missing_fixture_failure':failure,'ignored_cases':17}

def main() -> int:
    pins = json.loads((HERE/'pins.json').read_text())
    fixtures = json.loads((HERE/'fixture_pins.json').read_text())
    check_pins(pins,fixtures)
    reused = prior_oracle(pins)
    reused_library = prior_full_library(pins)
    env = {k:v for k,v in os.environ.items() if not k.startswith('HL_')}
    env.update(CUDA_ROOT='/home/victor/cuda-root',LD_LIBRARY_PATH=LD,
               HL_GPU='1',HL_GPU_REQUIRED='1',RAYON_NUM_THREADS='2')
    cases = [('missing-fixture-legacy-test','release_lib',
              ['private_block::review_tests::a_toy_receipt_made_before_the_lane_still_verifies',
               '--exact','--test-threads=1','--nocapture'],120,None)]
    for mode in ('resident','chunked'):
        for profile in ('v2','v3','zk','zkv3'):
            proof = HERE/f'{mode}-{profile}.proof'
            args=['pass','12','512','--threads','2','--proof-out',str(proof)]
            if profile in ('zk','zkv3'): args += ['--zk','--seed','1']
            if profile in ('v3','zkv3'): args += ['--profile','v3','--export',EXPORT]
            cases.append((f'{mode}-{profile}','release_bin',args,120,proof))
    report={'status':'running','pins':pins,'fixtures':fixtures,'reused_oracle':reused,
            'reused_library':reused_library,
            'frozen_source':'scripts/hashline_cl_gpu_gates.py FROZEN at workspace 2026-09-27',
            'cases':[],'started_unix':time.time()}
    (HERE/'report.json').write_text(json.dumps(report,indent=2))
    with open('/tmp/zk-heavy.lock','w') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        for name, role, args, timeout, proof in cases:
            check_pins(pins,fixtures)
            prior_oracle(pins)
            prior_full_library(pins)
            binary=SRC/pins['binaries'][role]
            case_env=dict(env,HL_ZK_CHUNK=('force' if name.startswith('chunked-') else 'off'))
            log=HERE/f'{name}.log';started=time.time()
            with log.open('w') as output:
                output.write(f'binary={binary}\nsha256={sha(binary)}\nargs={args!r}\n')
                output.flush()
                try:
                    code=subprocess.run([str(binary),*args],cwd=SRC/'hashline',env=case_env,
                                        stdout=output,stderr=subprocess.STDOUT,timeout=timeout).returncode
                except subprocess.TimeoutExpired:code=124
            body=log.read_text(errors='replace')
            row={'name':name,'exit_code':code,'seconds':time.time()-started,
                 'log':log.name,'log_sha256':sha(log)}
            valid=code==0
            if name=='missing-fixture-legacy-test':
                m=re.search(r'test result: ok\. (\d+) passed; 0 failed; (\d+) ignored; 0 measured; 508 filtered out;',body)
                row['library_result']=list(map(int,m.groups())) if m else None
                valid=valid and m is not None and list(map(int,m.groups())) == [1,0]
                valid=valid and 'PRE-LANE: 1 archived toy receipts still verify' in body
            else:
                expect_sha,expect_bytes=FROZEN[name.split('-',1)[1]]
                if proof and proof.exists():
                    row['proof_sha256']=sha(proof);row['proof_bytes']=proof.stat().st_size
                    valid=valid and row['proof_sha256']==expect_sha and row['proof_bytes']==expect_bytes
                else:valid=False
                valid=valid and 'gpu: ON' in body and 'PASS ACCEPT' in body
            valid=valid and 'gpu commit declined' not in body and 'gpu zk commit declined' not in body
            if valid and proof: proof.unlink()
            row['passed']=bool(valid);report['cases'].append(row)
            (HERE/'report.json').write_text(json.dumps(report,indent=2))
            if not valid:
                report['status']='failed';(HERE/'report.json').write_text(json.dumps(report,indent=2))
                return 1
    report['status']='passed';report['ended_unix']=time.time()
    (HERE/'report.json').write_text(json.dumps(report,indent=2));return 0

if __name__=='__main__':
    try:rc=main()
    except Exception as exc:
        (HERE/'error.txt').write_text(f'{type(exc).__name__}: {exc}\n');rc=1
    (HERE/'done').write_text(str(rc)+'\n');sys.exit(rc)

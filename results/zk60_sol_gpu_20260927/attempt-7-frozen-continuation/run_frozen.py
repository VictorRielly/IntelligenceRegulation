#!/usr/bin/env python3
"""Pinned continuation after a profile-marker parser false negative."""
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
PRIOR_PARTIAL = HERE.parent/'attempt-6-release-proof'
LD = '/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib'
EXPORT = '/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export'
FROZEN = {
    'v2': ('50cf7bdfd6b5b182f9c029c3d62087ca9e0e273be218d017609323c15146a17d', 66844928),
    'v3': ('5f368db6240e061428a90eccdb22ff456b1507708ef95f1bed39615042973c1d', 70758084),
    'zk': ('021485e4f80ec695ddc0b05423a941e1a165c222efe12aca5bf3cd2f0d02282d', 87228528),
    'zkv3': ('40eb54795e023c77382a31020aac728485daaae2e1b5ec58c3c82d04f94aac17', 87697008),
}
ACCEPT = {'v2':'PASS ACCEPT:', 'v3':'PASS-V3 ACCEPT:',
          'zk':'PASS ACCEPT [ZK]:', 'zkv3':'PASS-V3 ACCEPT [ZK]:'}
PRIOR_RUNNER_SHA = '9bed28c26f4c9e46f4bc2bbf2d53e748363d528eb9ddb4225683decc4f8f2e0e'

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

def timing(body: str, expected_bytes: int) -> dict:
    lines = re.findall(r'^HASHLINE_TIMING (\{.*\})$',body,re.MULTILINE)
    if len(lines) != 1: raise RuntimeError('expected exactly one complete timing record')
    record = json.loads(lines[0])
    if (record.get('verified') is not True or record.get('gpu_requested') is not True or
        record.get('gpu_enabled') is not True or record.get('proof_bytes') != expected_bytes or
        record.get('layers') != 12 or record.get('tokens') != 512):
        raise RuntimeError('timing record does not confirm verified device proof')
    return record

def prior_partial(pins: dict) -> dict:
    p = PRIOR_PARTIAL/'report.json'; prior = json.loads(p.read_text())
    if prior.get('status') != 'failed' or [c['name'] for c in prior['cases']] != [
        'missing-fixture-legacy-test','resident-v2','resident-v3']:
        raise RuntimeError('prior partial gate result changed')
    if (prior['pins']['sources'] != pins['sources'] or
        prior['pins']['binary_sha256']['release_lib'] != pins['binary_sha256']['release_lib'] or
        prior['pins']['binary_sha256']['release_bin'] != pins['binary_sha256']['release_bin'] or
        prior['fixtures'] != json.loads((HERE/'fixture_pins.json').read_text()) or
        sha(PRIOR_PARTIAL/'run_release.py') != PRIOR_RUNNER_SHA or
        (PRIOR_PARTIAL/'done').read_text().strip() != '1'):
        raise RuntimeError('prior partial source, binary, fixture, runner or terminal marker changed')
    legacy,v2,v3 = prior['cases']
    for c in (legacy,v2,v3):
        if c['exit_code'] != 0 or sha(PRIOR_PARTIAL/c['log']) != c['log_sha256']:
            raise RuntimeError(f'prior partial exit/log changed: {c["name"]}')
    lb=(PRIOR_PARTIAL/legacy['log']).read_text(errors='replace')
    if not legacy['passed'] or legacy.get('library_result') != [1,0] or 'PRE-LANE: 1 archived toy receipts still verify' not in lb:
        raise RuntimeError('prior filtered legacy fixture test was not passed')
    for row,profile in ((v2,'v2'),(v3,'v3')):
        body=(PRIOR_PARTIAL/row['log']).read_text(errors='replace')
        expected_sha,expected_bytes=FROZEN[profile]
        if (row['proof_sha256'] != expected_sha or row['proof_bytes'] != expected_bytes or
            'gpu: ON' not in body or ACCEPT[profile] not in body or
            'gpu commit declined' in body or 'gpu zk commit declined' in body):
            raise RuntimeError(f'prior {profile} frozen proof evidence changed')
        timing(body,expected_bytes)
    if not v2['passed'] or v3['passed']:
        raise RuntimeError('prior parser false-negative state changed')
    v3_proof=PRIOR_PARTIAL/'resident-v3.proof'
    if sha(v3_proof) != FROZEN['v3'][0] or v3_proof.stat().st_size != FROZEN['v3'][1]:
        raise RuntimeError('retained resident-v3 proof changed')
    return {'report':str(p),'report_sha256':sha(p),'runner_sha256':PRIOR_RUNNER_SHA,
            'legacy_test':{'log_sha256':legacy['log_sha256'],'passed':True},
            'resident_v2':{'log_sha256':v2['log_sha256'],'proof_sha256':v2['proof_sha256'],'passed':True},
            'resident_v3':{'log_sha256':v3['log_sha256'],'proof_sha256':v3['proof_sha256'],
                           'retained_proof_sha256':sha(v3_proof),
                           'adjudication':'exact frozen proof and size; verified GPU timing; PASS-V3 ACCEPT marker; old runner required PASS ACCEPT'}}

def main() -> int:
    pins = json.loads((HERE/'pins.json').read_text())
    fixtures = json.loads((HERE/'fixture_pins.json').read_text())
    check_pins(pins,fixtures)
    reused = prior_oracle(pins)
    reused_library = prior_full_library(pins)
    reused_partial = prior_partial(pins)
    env = {k:v for k,v in os.environ.items() if not k.startswith('HL_')}
    env.update(CUDA_ROOT='/home/victor/cuda-root',LD_LIBRARY_PATH=LD,
               HL_GPU='1',HL_GPU_REQUIRED='1',RAYON_NUM_THREADS='2')
    cases = []
    for mode in ('resident','chunked'):
        for profile in ('v2','v3','zk','zkv3'):
            if mode == 'resident' and profile in ('v2','v3'): continue
            proof = HERE/f'{mode}-{profile}.proof'
            args=['pass','12','512','--threads','2','--proof-out',str(proof)]
            if profile in ('zk','zkv3'): args += ['--zk','--seed','1']
            if profile in ('v3','zkv3'): args += ['--profile','v3','--export',EXPORT]
            cases.append((f'{mode}-{profile}','release_bin',args,120,proof))
    report={'status':'running','pins':pins,'fixtures':fixtures,'reused_oracle':reused,
            'reused_library':reused_library,'reused_partial':reused_partial,
            'frozen_source':'scripts/hashline_cl_gpu_gates.py FROZEN at workspace 2026-09-27',
            'cases':[],'started_unix':time.time()}
    (HERE/'report.json').write_text(json.dumps(report,indent=2))
    with open('/tmp/zk-heavy.lock','w') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        for name, role, args, timeout, proof in cases:
            check_pins(pins,fixtures)
            prior_oracle(pins)
            prior_full_library(pins)
            prior_partial(pins)
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
            profile=name.split('-',1)[1]
            expect_sha,expect_bytes=FROZEN[profile]
            if proof and proof.exists():
                row['proof_sha256']=sha(proof);row['proof_bytes']=proof.stat().st_size
                valid=valid and row['proof_sha256']==expect_sha and row['proof_bytes']==expect_bytes
            else:valid=False
            valid=valid and 'gpu: ON' in body and ACCEPT[profile] in body
            if valid:
                try: row['timing']=timing(body,expect_bytes)
                except RuntimeError:valid=False
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
        report_path=HERE/'report.json'
        if report_path.exists():
            report=json.loads(report_path.read_text())
            report['status']='failed';report['error']=f'{type(exc).__name__}: {exc}'
            report_path.write_text(json.dumps(report,indent=2))
    (HERE/'done').write_text(str(rc)+'\n');sys.exit(rc)

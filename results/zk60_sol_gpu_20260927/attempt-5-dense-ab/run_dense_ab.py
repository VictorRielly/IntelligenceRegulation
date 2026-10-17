#!/usr/bin/env python3
"""Shared-box synthetic 125M CPU/GPU keyed-commit diagnostic; no 8B claim."""
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
from statistics import mean

HERE=Path(__file__).resolve().parent
SRC=Path('/tmp/zk60-sol-gpu-20260927')
PRIOR_ORACLE=HERE.parent/'attempt-3-legacy'
PRIOR_LIB=HERE.parent/'attempt-4-release'
PRIOR_PARTIAL=HERE.parent/'attempt-6-release-proof'
PRIOR_PROOFS=HERE.parent/'attempt-7-frozen-continuation'
LD='/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib'
TEST='private_block::rulings_tests::private_block_125m_one_block'
PAT=re.compile(r'125M ONE BLOCK: prove ([0-9.]+) s, verify from bytes ([0-9.]+) s, receipt (\d+) B, peak RSS ([0-9.]+) MiB .* witness build ([0-9.]+) s')
SCHEDULE=[('warm-cpu','cpu'),('warm-gpu','gpu'),('a1-cpu','cpu'),('b1-gpu','gpu'),('b2-gpu','gpu'),('a2-cpu','cpu')]
FROZEN={'v2':('50cf7bdfd6b5b182f9c029c3d62087ca9e0e273be218d017609323c15146a17d',66844928),
        'v3':('5f368db6240e061428a90eccdb22ff456b1507708ef95f1bed39615042973c1d',70758084),
        'zk':('021485e4f80ec695ddc0b05423a941e1a165c222efe12aca5bf3cd2f0d02282d',87228528),
        'zkv3':('40eb54795e023c77382a31020aac728485daaae2e1b5ec58c3c82d04f94aac17',87697008)}

def sha(p:Path)->str:
 h=hashlib.sha256()
 with p.open('rb') as f:
  for b in iter(lambda:f.read(1<<20),b''):h.update(b)
 return h.hexdigest()

def check(pins,fixtures):
 for rel,h in pins['sources'].items():
  if sha(SRC/rel)!=h:raise RuntimeError(f'source drift: {rel}')
 for name,rel in pins['binaries'].items():
  if sha(SRC/rel)!=pins['binary_sha256'][name]:raise RuntimeError(f'binary drift: {name}')
 for rel,item in fixtures.items():
  p=SRC/rel
  if sha(p)!=item['sha256'] or p.stat().st_size!=item['bytes']:raise RuntimeError(f'fixture drift: {rel}')

def readiness(pins):
 oracle_p=PRIOR_ORACLE/'report.json';oj=json.loads(oracle_p.read_text())
 oc=next((x for x in oj['cases'] if x['name']=='legacy-oracle'),None)
 if oc is None or not oc['passed'] or oc['exit_code']!=0 or oc['summary']['executed_cases']!=189 or oc['summary']['gpu_enabled'] is not True or oc['summary']['gpu_required'] is not True:
  raise RuntimeError('189-case legacy GPU oracle gate is not passed')
 if oj['pins']['sources']!=pins['sources'] or oj['pins']['binary_sha256']['legacy_oracle']!=pins['binary_sha256']['legacy_oracle'] or sha(PRIOR_ORACLE/oc['log'])!=oc['log_sha256']:
  raise RuntimeError('legacy GPU oracle source/binary/log changed')
 lib_p=PRIOR_LIB/'report.json';lj=json.loads(lib_p.read_text())
 if lj['status']!='failed' or len(lj['cases'])!=1 or lj['cases'][0]['name']!='full-gpu-lib':
  raise RuntimeError('release library diagnostic changed')
 lc=lj['cases'][0];body=(PRIOR_LIB/lc['log']).read_text(errors='replace')
 if lc['exit_code']!=101 or lc['passed'] or sha(PRIOR_LIB/lc['log'])!=lc['log_sha256'] or lj['pins']['sources']!=pins['sources'] or lj['pins']['binary_sha256']['release_lib']!=pins['binary_sha256']['release_lib']:
  raise RuntimeError('release library source/binary/log changed')
 if 'test result: FAILED. 491 passed; 1 failed; 17 ignored; 0 measured; 0 filtered out;' not in body or 'no pre-lane toy receipt was found: this check did not run' not in body:
  raise RuntimeError('release library failure is not the missing fixture')
 partial_p=PRIOR_PARTIAL/'report.json';qj=json.loads(partial_p.read_text())
 if qj['status']!='failed' or [x['name'] for x in qj['cases']]!=['missing-fixture-legacy-test','resident-v2','resident-v3']:
  raise RuntimeError('partial fixture/proof gate result changed')
 legacy,v2,v3=qj['cases']
 if not legacy['passed'] or legacy['library_result']!=[1,0] or not v2['passed'] or v3['passed'] or v3['exit_code']!=0:
  raise RuntimeError('partial fixture/proof gate adjudication changed')
 if qj['pins']['sources']!=pins['sources'] or qj['pins']['binary_sha256']['release_lib']!=pins['binary_sha256']['release_lib'] or qj['pins']['binary_sha256']['release_bin']!=pins['binary_sha256']['release_bin']:
  raise RuntimeError('partial fixture/proof gate source or binaries differ')
 for x in qj['cases']:
  if sha(PRIOR_PARTIAL/x['log'])!=x['log_sha256']:raise RuntimeError(f'partial gate log changed: {x["name"]}')
 if sha(PRIOR_PARTIAL/'resident-v3.proof')!=v3['proof_sha256'] or v3['proof_sha256']!='5f368db6240e061428a90eccdb22ff456b1507708ef95f1bed39615042973c1d' or v3['proof_bytes']!=70758084:
  raise RuntimeError('retained resident v3 frozen proof changed')
 for row,profile in ((v2,'v2'),(v3,'v3')):
  body=(PRIOR_PARTIAL/row['log']).read_text(errors='replace')
  marker={'v2':'PASS ACCEPT:','v3':'PASS-V3 ACCEPT:'}[profile]
  timing_lines=re.findall(r'^HASHLINE_TIMING (\{.*\})$',body,re.MULTILINE)
  if marker not in body or 'gpu: ON' not in body or len(timing_lines)!=1:
   raise RuntimeError(f'partial {profile} acceptance/timing changed')
  t=json.loads(timing_lines[0]);digest,size=FROZEN[profile]
  if row['proof_sha256']!=digest or row['proof_bytes']!=size or t.get('verified') is not True or t.get('gpu_enabled') is not True or t.get('proof_bytes')!=size:
   raise RuntimeError(f'partial {profile} proof/timing changed')
 proof_p=PRIOR_PROOFS/'report.json';pj=json.loads(proof_p.read_text())
 expected=['resident-zk','resident-zkv3','chunked-v2','chunked-v3','chunked-zk','chunked-zkv3']
 if pj['status']!='passed' or [x['name'] for x in pj['cases']]!=expected or any(not x['passed'] for x in pj['cases']):
  raise RuntimeError('remaining six frozen proof gates are not all passed')
 if pj['pins']['sources']!=pins['sources'] or pj['pins']['binary_sha256']['release_lib']!=pins['binary_sha256']['release_lib'] or pj['pins']['binary_sha256']['release_bin']!=pins['binary_sha256']['release_bin']:
  raise RuntimeError('frozen proof gate source/binary differs from this A/B')
 if qj['fixtures']!=pj['fixtures'] or pj['fixtures']!=json.loads((HERE/'fixture_pins.json').read_text()):
  raise RuntimeError('frozen gate fixture pins differ from this A/B')
 if pj['reused_oracle']['report_sha256']!=sha(oracle_p) or pj['reused_library']['report_sha256']!=sha(lib_p) or pj['reused_partial']['report_sha256']!=sha(partial_p):
  raise RuntimeError('proof gate reused records changed')
 for x in pj['cases']:
  if sha(PRIOR_PROOFS/x['log'])!=x['log_sha256']:raise RuntimeError(f'frozen gate log changed: {x["name"]}')
  profile=x['name'].split('-',1)[1];digest,size=FROZEN[profile]
  if x.get('proof_sha256')!=digest or x.get('proof_bytes')!=size or x.get('timing',{}).get('verified') is not True or x['timing'].get('gpu_enabled') is not True:
   raise RuntimeError(f'frozen proof/timing changed: {x["name"]}')
 return {'legacy_oracle_report':str(oracle_p),'legacy_oracle_report_sha256':sha(oracle_p),
         'release_library_report':str(lib_p),'release_library_report_sha256':sha(lib_p),
         'fixture_repair_and_partial_proofs_report':str(partial_p),'fixture_repair_and_partial_proofs_report_sha256':sha(partial_p),
         'remaining_proofs_report':str(proof_p),'remaining_proofs_report_sha256':sha(proof_p),
         'coverage':'189 legacy GPU oracle cases; 491 release library passes plus 1 fixture-repaired test; 17 ignored; 2 prior resident and 6 continuation frozen proofs',
         'full_library_single_run_passed':False}

def main():
 pins=json.loads((HERE/'pins.json').read_text());fixtures=json.loads((HERE/'fixture_pins.json').read_text())
 check(pins,fixtures);gate=readiness(pins)
 binary=SRC/pins['binaries']['release_lib']
 env={k:v for k,v in os.environ.items() if not k.startswith('HL_')}
 env.update(CUDA_ROOT='/home/victor/cuda-root',LD_LIBRARY_PATH=LD,RAYON_NUM_THREADS='2',
            HL_PB_WEIGHTS='dense',HL_PB_TIMING='1',HL_GPU_CHUNK_ROWS='128')
 report={'status':'waiting-for-heavy-lock','pins':pins,'fixtures':fixtures,'readiness':gate,
         'hardware':'RTX 4070 Laptop GPU (8188MiB, driver566.14); shared host, two CPU threads',
         'scope':'one synthetic dense 125M private block; CPU fallback vs keyed GPU forced chunk; no 8B/speed target or privacy acceptance',
         'complete_model_passes':0,'complete_model_proved_tokens_per_second':None,
         'separate_process_each_sample':True,'fresh_gpu_initialization_each_gpu_sample':True,
         'warmups_excluded_from_arm_means':True,
         'amortized_startup_or_steady_state_claim':False,
         'wall_includes_process_start_and_verify':True,
         'prove_seconds_excludes_endpoint_prep_and_receipt_serialization':True,
         'peak_rss_is_host_process_not_vram':True,'byte_verify_is_same_process':True,
         'schedule':SCHEDULE,'runs':[],'started_unix':time.time()}
 def save():(HERE/'report.json').write_text(json.dumps(report,indent=2)+'\n')
 save()
 with open('/tmp/zk-heavy.lock','w') as lock:
  fcntl.flock(lock,fcntl.LOCK_EX)
  for name,arm in SCHEDULE:
   check(pins,fixtures);readiness(pins)
   mem=dict(line.split(':',1) for line in Path('/proc/meminfo').read_text().splitlines())
   available=int(mem['MemAvailable'].split()[0])*1024
   if available<11*1024**3:raise RuntimeError(f'less than 11GiB host RAM available ({available} bytes)')
   cfg=dict(env,HL_GPU='1' if arm=='gpu' else '0',HL_GPU_REQUIRED='1' if arm=='gpu' else '0',
            HL_ZK_CHUNK='force' if arm=='gpu' else 'off')
   cmd=[str(binary),'--ignored','--exact',TEST,'--nocapture','--test-threads=1']
   report.update(status='running',current=name);save()
   log=HERE/f'{name}.log';started=time.monotonic()
   with log.open('w') as output:
    output.write(f'binary={binary}\nsha256={sha(binary)}\ncmd={cmd!r}\narm={arm}\n')
    output.flush()
    try:code=subprocess.run(cmd,cwd=SRC/'hashline',env=cfg,stdout=output,stderr=subprocess.STDOUT,timeout=300).returncode
    except subprocess.TimeoutExpired:code=124
   wall=time.monotonic()-started;body=log.read_text(errors='replace');m=PAT.search(body)
   accepted=body.count('[ZK60] keyed gpu zk commit accepted')
   row={'name':name,'arm':arm,'warmup':name.startswith('warm-'),'exit_code':code,'wall_seconds':wall,
        'log':log.name,'log_sha256':sha(log),'accepted_keyed_commits':accepted,'available_before_bytes':available}
   if m:
    row.update(prove_seconds=float(m[1]),verify_seconds=float(m[2]),receipt_bytes=int(m[3]),
               peak_rss_mib=float(m[4]),witness_seconds=float(m[5]))
    # The retained native test does not time `receipt.to_bytes_at` separately.
    # Raw residual includes serialization, endpoint prep, checks, runner
    # overhead and rounding; it can be negative at displayed precision.
    row['serialize_and_other_seconds']=wall-row['witness_seconds']-row['prove_seconds']-row['verify_seconds']
   valid=code==0 and m is not None and '1 passed; 0 failed' in body and row.get('receipt_bytes')==40783352
   valid=valid and ('gpu zk commit declined' not in body) and ('gpu commit declined' not in body)
   if arm=='gpu':valid=valid and accepted>=4
   else:valid=valid and accepted==0
   row['passed']=bool(valid);report['runs'].append(row);save()
   if not valid:
    report.update(status='failed',current=None);save();return 1
 nonwarm=[r for r in report['runs'] if not r['warmup']]
 if len(nonwarm)!=4 or sum(r['arm']=='cpu' for r in nonwarm)!=2 or sum(r['arm']=='gpu' for r in nonwarm)!=2:
  raise RuntimeError('ABBA nonwarm run count changed')
 fields=('wall_seconds','witness_seconds','prove_seconds','verify_seconds',
         'serialize_and_other_seconds','peak_rss_mib')
 means={arm:{field:mean(r[field] for r in nonwarm if r['arm']==arm) for field in fields}
        for arm in ('cpu','gpu')}
 report['nonwarm_arm_means']=means
 report['nonwarm_cpu_over_gpu_ratios']={field:(means['cpu'][field]/means['gpu'][field]
     if means['gpu'][field]!=0 else None) for field in ('wall_seconds','prove_seconds')}
 report.update(status='passed',current=None,ended_unix=time.time());save();return 0

if __name__=='__main__':
 try:rc=main()
 except Exception as exc:
  (HERE/'error.txt').write_text(f'{type(exc).__name__}: {exc}\n');rc=1
  report_path=HERE/'report.json'
  if report_path.exists():
   report=json.loads(report_path.read_text())
   report['status']='failed';report['error']=f'{type(exc).__name__}: {exc}'
   report_path.write_text(json.dumps(report,indent=2)+'\n')
 (HERE/'done').write_text(str(rc)+'\n');sys.exit(rc)

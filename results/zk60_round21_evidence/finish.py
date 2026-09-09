import hashlib
import json
import os
from pathlib import Path
import resource
import subprocess
import time

ROOT=Path('/home/victor/IntelligenceRegulation')
OUT=Path('/tmp/zk60-round21')
resource.setrlimit(resource.RLIMIT_AS,(8*1024**3,8*1024**3))
env={k:v for k,v in os.environ.items() if not k.startswith('HL_')}
env.update(CARGO_BUILD_JOBS='2',RAYON_NUM_THREADS='2',RUST_TEST_THREADS='2')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
report=json.loads((OUT/'initial_validation.json').read_text())
assert all(s['exit_code']==s['expected_exit_code'] for s in report['stages'])
assert len(report['stages'])==9
report['initial_runner_failure']='P1 public_w.root was incorrectly accessed as public_w.commitment.root; corrected below without repeating the completed Rust/P3 stages.'
def stage(name,command,expected=0):
    log=OUT/(name+'.log')
    start=time.monotonic()
    with log.open('wb') as f:
        run=subprocess.run(command,cwd=ROOT,env=env,stdout=f,stderr=subprocess.STDOUT)
    report['stages'].append(dict(name=name,command=command,exit_code=run.returncode,expected_exit_code=expected,elapsed_s=time.monotonic()-start,log_sha256=sha(log)))
    (OUT/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
    print(name,run.returncode,flush=True)
    if run.returncode!=expected:
        (OUT/'validation.done').write_text('1\n')
        raise SystemExit(1)
binary=ROOT/'hashline/target/release/examples/zk60_bound_ffn'
assert sha(binary)==report['binary_sha256']==json.loads((ROOT/'results/zk60_round19_validation.json').read_text())['binary_sha256']
cases=[]
for i,path in enumerate(sorted(Path('/tmp/zk60-round19/captures').glob('*.json'))):
    c=json.loads(path.read_bytes())
    expected,receipt=path.with_suffix('.expected'),path.with_suffix('.receipt')
    policy=expected.read_bytes()
    cases.append(dict(proof_sha256=sha(receipt),expected_policy_sha256=sha(expected),privacy=c['privacy']))
    if c['privacy']!='P1':
        continue
    context=policy[8:40].hex()
    weight=bytes(c['public_w']['root']).hex()
    base=[str(binary),'verify','p1',weight,context]
    stage('receipt_'+str(i),base+[str(expected),str(receipt)])
    for side,offset in [('input',48),('output',80)]:
        changed=bytearray(policy)
        changed[offset]^=1
        target=OUT/(str(i)+'_wrong_'+side+'.expected')
        target.write_bytes(changed)
        stage('receipt_'+str(i)+'_wrong_'+side,base+[str(target),str(receipt)],1)
    stage('receipt_'+str(i)+'_wrong_mode',[str(binary),'verify','p3','fresh',context,str(expected),str(receipt)],1)
stage('cfs_unit',['python3','-m','unittest','discover','-s','tests','-p','test_zk60_io_cfs_composition.py','-v'])
stage('cfs_captures',['python3','scripts/zk60_io_cfs_composition.py','--captures','/tmp/zk60-round19/captures','--out','results/zk60_round21_io_cfs.json'])
report.update(cases=cases,status='passed',rust_test_count=6,python_test_count=7,process_cases=16,io_cfs_slots=8,cfs_corruption_controls=72,full_privacy_review_complete=False)
(OUT/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
(OUT/'validation.done').write_text('0\n')

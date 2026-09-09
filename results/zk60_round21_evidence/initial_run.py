import hashlib
import json
import os
from pathlib import Path
import resource
import subprocess
import time

ROOT = Path('/home/victor/IntelligenceRegulation')
OUT = Path('/tmp/zk60-round21')
OUT.mkdir(exist_ok=True)
resource.setrlimit(resource.RLIMIT_AS, (8*1024**3, 8*1024**3))
env = {k:v for k,v in os.environ.items() if not k.startswith('HL_')}
env.update(CARGO_BUILD_JOBS='2', RAYON_NUM_THREADS='2', RUST_TEST_THREADS='2', CARGO_TARGET_DIR=str(ROOT/'hashline/target/storage-tests'))
report = {'schema': 1, 'reviewed_head': subprocess.check_output(['git','rev-parse','HEAD'], cwd=ROOT, text=True).strip(), 'stages': [], 'rlimit_as': 8*1024**3}
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
def stage(name, command, expected=0):
    log = OUT/(name+'.log')
    start = time.monotonic()
    with log.open('wb') as f:
        result = subprocess.run(command, cwd=ROOT, env=env, stdout=f, stderr=subprocess.STDOUT)
    entry = dict(name=name, command=command, exit_code=result.returncode, expected_exit_code=expected, elapsed_s=time.monotonic()-start, log_sha256=sha(log))
    report['stages'].append(entry)
    (OUT/'validation.json').write_text(json.dumps(report, indent=2)+'\n')
    print(name, result.returncode, flush=True)
    if result.returncode != expected:
        (OUT/'validation.done').write_text('1\n')
        raise SystemExit(1)

stage('rust_bound_io', ['/home/victor/.cargo/bin/cargo','test','--release','--locked','--offline','--manifest-path','hashline/Cargo.toml','--features','stable-weight-storage','bound_ffn_','--','--test-threads=2','--nocapture'])
binary = ROOT/'hashline/target/release/examples/zk60_bound_ffn'
report['binary_sha256'] = sha(binary)
cases=[]
for i, path in enumerate(sorted(Path('/tmp/zk60-round19/captures').glob('*.json'))):
    c=json.loads(path.read_bytes())
    expected=path.with_suffix('.expected')
    receipt=path.with_suffix('.receipt')
    policy=expected.read_bytes()
    context=policy[8:40].hex()
    weight='fresh' if c['privacy']=='P3' else bytes(c['public_w']['commitment']['root']).hex()
    base=[str(binary),'verify',c['privacy'].lower(),weight,context]
    stage('receipt_'+str(i), base+[str(expected),str(receipt)])
    for side, offset in [('input',48),('output',80)]:
        changed=bytearray(policy)
        changed[offset] ^= 1
        target=OUT/(str(i)+'_wrong_'+side+'.expected')
        target.write_bytes(changed)
        stage('receipt_'+str(i)+'_wrong_'+side,base+[str(target),str(receipt)],1)
    mode='p1' if c['privacy']=='P3' else 'p3'
    wrong_weight='00'*32 if mode=='p1' else 'fresh'
    stage('receipt_'+str(i)+'_wrong_mode',[str(binary),'verify',mode,wrong_weight,context,str(expected),str(receipt)],1)
    cases.append(dict(proof_sha256=sha(receipt),expected_policy_sha256=sha(expected),privacy=c['privacy']))
report['cases']=cases
report['status']='passed'
(OUT/'validation.json').write_text(json.dumps(report, indent=2)+'\n')
(OUT/'validation.done').write_text('0\n')

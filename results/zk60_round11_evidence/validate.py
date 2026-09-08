import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import resource
import subprocess
import time
import traceback

ROOT=Path('/home/victor/IntelligenceRegulation')
OUT=Path('/tmp/zk60-round11')
os.chdir(ROOT)
ENV={k:v for k,v in os.environ.items() if not k.startswith('HL_')}
ENV.update(CARGO_BUILD_JOBS='2',RAYON_NUM_THREADS='2',ZK_THREADS='2',CARGO_NET_OFFLINE='true',
           M125_EXPORT_DIR=str(ROOT/'results/m125_ffn_export_wsl'))
HEAD=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
assert HEAD.startswith('c8a342f'),HEAD
REPORT={'schema_version':1,'source_commit':HEAD,'scope':'round11 A/H/W diagnostics, integrated Fable work and canonical CPU primitive extraction',
        'threads':2,'heavy_lock':'/tmp/zk-heavy.lock','stages':[],'gpu_executed':False,
        'gpu_scope':'bounded oracle and frozen 12x512 FFN correctness; no throughput qualification'}

def digest(path):
    h=hashlib.sha256()
    with open(path,'rb') as f:
        for b in iter(lambda:f.read(1<<20),b''):h.update(b)
    return {'bytes':Path(path).stat().st_size,'sha256':h.hexdigest()}

def save(): (OUT/'summary.json').write_text(json.dumps(REPORT,indent=2)+'\n')
def cap(): resource.setrlimit(resource.RLIMIT_AS,(8<<30,8<<30))
def stage(name,cmd,timeout=900,env=None,cpu_cap=True):
    print('START '+name,flush=True)
    log=OUT/(name+'.log');metrics=OUT/(name+'.time');start=time.monotonic()
    with log.open('w') as f:
        p=subprocess.run(['/usr/bin/time','-v','-o',str(metrics)]+cmd,
            env=env or ENV,stdout=f,stderr=subprocess.STDOUT,timeout=timeout,preexec_fn=cap if cpu_cap else None)
    REPORT['stages'].append({'stage':name,'command':cmd,'exit_code':p.returncode,'elapsed_s':time.monotonic()-start,
        'log':str(log),'log_sha256':digest(log)['sha256'],'resource_log':str(metrics),
        'address_space_limit_bytes':8<<30 if cpu_cap else None})
    save();print('END '+name+' exit='+str(p.returncode),flush=True)
    if p.returncode:raise RuntimeError(name+' failed: '+str(log))
    return log.read_text()

def counts(log):
    rows=re.findall(r'test result: ok\. (\d+) passed; (\d+) failed; (\d+) ignored',log)
    assert rows
    return dict(zip(('passed','failed','ignored'),[sum(int(r[i]) for r in rows) for i in range(3)]))

paths=subprocess.check_output(['git','ls-files','hashline','zkp-core','scripts','tests'],text=True).splitlines()
paths=[p for p in paths if Path(p).suffix in ('.rs','.cu','.toml','.lock','.py','.sh')]
before={p:digest(ROOT/p)['sha256'] for p in paths}
rc=1
try:
    print('WAIT shared heavy lock',flush=True)
    with open('/tmp/zk-heavy.lock','a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        print('ACQUIRED shared heavy lock',flush=True)
        assert subprocess.check_output(['git','diff','HEAD','--','hashline','zkp-core'])==b''
        # The existing floors manifest binds hashline. This outer record also
        # binds the extracted path dependency and all validation scripts.
        log=stage('core_tests',['cargo','test','--release','--locked','--offline','--manifest-path','zkp-core/Cargo.toml','--all-targets','--','--test-threads=2'])
        REPORT['core_tests']=counts(log)
        assert REPORT['core_tests']==dict(passed=19,failed=0,ignored=0)
        stage('core_example',['cargo','run','--release','--locked','--offline','--manifest-path','zkp-core/Cargo.toml','--example','public_sumcheck'])
        stage('core_dependencies',['cargo','tree','--offline','--locked','--manifest-path','zkp-core/Cargo.toml'])
        # The runner acquires its own build lock. Never acquire that lock here.
        log=stage('combined_floors',['bash','results/cl1_floors.sh','--repo',str(ROOT),
            '--threads','2','--build-jobs','2','--rayon-threads','2','--suite-version','3',str(OUT/'floors')],2400,cpu_cap=False)
        manifest=json.loads((OUT/'floors/manifest.json').read_text())
        assert manifest['verdict']['green'] is True and manifest['source']['head']==HEAD
        assert manifest['source']['dirty_delta_sha256']==hashlib.sha256(b'').hexdigest()
        REPORT['combined_manifest']={'path':str(OUT/'floors/manifest.json'),**digest(OUT/'floors/manifest.json'),'verdict':manifest['verdict']}
        REPORT['gpu_executed']=True
        REPORT['hashline_tests']=counts((OUT/'floors/cargo_test_cpu.out').read_text())
        REPORT['rust_tests_total']={k:REPORT['core_tests'][k]+REPORT['hashline_tests'][k] for k in REPORT['core_tests']}
        assert REPORT['rust_tests_total']['failed']==REPORT['rust_tests_total']['ignored']==0
        REPORT['frozen_artifacts']=[{'case':r['id'],**r['proof']} for r in manifest['cases'] if r['kind']=='byte_gate']
        assert len(REPORT['frozen_artifacts'])==12
        obs_env={**ENV,'HL_GPU':'0','HL_TEST_FFN_OBSERVATIONS':str(OUT/'final-observations')}
        log=stage('final_observations',['cargo','test','--release','--locked','--offline','--manifest-path','hashline/Cargo.toml','--lib','mask_diagnostic','--','--nocapture','--test-threads=2'],env=obs_env)
        REPORT['focused_retest']=counts(log)
        REPORT['observation_files']=[]
        for path in sorted((OUT/'final-observations').glob('*.json')):
            d=json.loads(path.read_text());assert d['fully_verified'] is True
            assert [r['role'] for r in d['roles']]==(['W','A','H'] if d['privacy']=='P3' else ['A','H'])
            for r in d['roles']:
                n=1<<r['params']['log_cols'];q=r['params']['num_col_checks'];rows=r['commitment']['rows']
                assert len(r['proximity_rhos'])==rows and len(r['proximity_vector'])==n+q
                assert len(r['columns'])==q and all(len(c['values'])==rows for c in r['columns'])
                assert all(len(g['vector'])==n+q for g in r['groups'])
            REPORT['observation_files'].append({'path':str(path),**digest(path),'proof_sha256':d['proof_sha256'],
                'privacy':d['privacy'],'shape':d['shape'],'roles':[r['role'] for r in d['roles']]})
        assert len(REPORT['observation_files'])==12
        stage('receipt_build',['cargo','build','--release','--locked','--offline','--manifest-path','hashline/Cargo.toml','--example','zk60_block_receipt','--example','zk60_chain_receipt'])
        b4=str(ROOT/'hashline/target/release/examples/zk60_block_receipt')
        stage('b4_reprove',[b4,'prove',str(ROOT/'results/zk60_round4_expected.bin'),str(OUT/'b4.proof')])
        original=ROOT/'results/zk60_round4_receipt.proof'
        assert digest(OUT/'b4.proof')==digest(original)
        REPORT['b4']=digest(OUT/'b4.proof')
        baseline=json.loads((ROOT/'results/zk60_round8_validation.json').read_text())
        cmd=next(s['command'] for s in baseline['stages'] if s['stage']=='chain_verify')
        stage('chain_verify',[str(ROOT/'hashline/target/release/examples/zk60_chain_receipt')]+cmd[1:])
        stage('native_build',['cargo','build','--release','--offline','--manifest-path','zkmatrix-rs/Cargo.toml'])
        log=stage('python_full',['python3','-m','unittest','discover','-s','tests','-v'],2400)
        REPORT['python_tests']=int(re.search(r'Ran (\d+) tests?',log).group(1))
        assert 'skipped=' not in log and '\nOK\n' in log
        assert {p:digest(ROOT/p)['sha256'] for p in paths}==before
        REPORT['source_sha256']=before
        REPORT['validation_status']='complete';rc=0
except BaseException:
    REPORT['error']=traceback.format_exc();print(REPORT['error'],flush=True)
finally:
    REPORT['exit_code']=rc;save();(OUT/'validation.done').write_text(str(rc)+'\n')
raise SystemExit(rc)

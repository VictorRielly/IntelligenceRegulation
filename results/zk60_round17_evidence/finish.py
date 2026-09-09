import fcntl, hashlib, json, os, pathlib, resource, subprocess, sys, traceback
ROOT=pathlib.Path('/home/victor/IntelligenceRegulation');OUT=pathlib.Path('/tmp/zk60-round17')
HEAD=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
assert HEAD.startswith('53e831c')
report=json.loads((OUT/'summary.json').read_text())
report['initial_status']=report.pop('status');report['initial_error']=report.pop('error');report['status']='running'
report['completion_source_commit']=HEAD;report['legacy_floors']=[]
env={k:v for k,v in os.environ.items() if not k.startswith('HL_')}
env.update(RAYON_NUM_THREADS='2',CARGO_BUILD_JOBS='2',M125_EXPORT_DIR=str(ROOT/'results/m125_ffn_export_wsl'))
def sha(p): return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
def save(): (OUT/'final_summary.json').write_text(json.dumps(report,indent=2)+'\n')
def cap(): resource.setrlimit(resource.RLIMIT_AS,(8<<30,8<<30))
def stage(name,cmd):
    print('START '+name,flush=True)
    with (OUT/(name+'.log')).open('w') as log:
        p=subprocess.run(['/usr/bin/time','-v','-o',str(OUT/(name+'.time'))]+cmd,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,preexec_fn=cap,timeout=600)
    report['stages'].append({'name':name,'command':cmd,'exit_code':p.returncode,'log_sha256':sha(OUT/(name+'.log'))})
    save();print('END '+name+' exit='+str(p.returncode),flush=True)
    if p.returncode: raise RuntimeError(name+' failed')
try:
    with open('/tmp/zk-heavy.lock','a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        assert subprocess.check_output(['git','diff',report['source_commit'],HEAD,'--','hashline','zkp-core'],cwd=ROOT)==b''
        test=(OUT/'affected_python_final.log').read_text()
        assert 'Ran 87 tests' in test and test.rstrip().endswith('OK')
        report['stages'].append({'name':'affected_python_corrected','exit_code':0,'test_count':87,'log_sha256':sha(OUT/'affected_python_final.log'),'source_commit':HEAD})
        sys.path.insert(0,str(ROOT/'scripts'))
        import hashline_cl_gpu_gates as gates
        binary=ROOT/'hashline/target/release/hashline'
        report['cpu_binary_sha256']=sha(binary)
        for profile in ('v2','v3','zk','zkv3'):
            path=OUT/(profile+'.proof')
            cmd=[str(binary),'pass','12','512','--threads','2','--proof-out',str(path)]
            if profile in ('zk','zkv3'):cmd+=['--zk','--seed','1']
            if profile in ('v3','zkv3'):cmd+=['--profile','v3','--export','/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export']
            stage('frozen_'+profile,cmd)
            actual=(sha(path),path.stat().st_size)
            assert actual==gates.FROZEN[profile],(profile,actual)
            report['legacy_floors'].append({'profile':profile,'sha256':actual[0],'bytes':actual[1],'frozen_match':True})
        stage('native_freeze',[str(ROOT/'zkmatrix-rs/target/release/ring_matmul'),'freeze-check'])
        assert 'freeze-check passed' in (OUT/'native_freeze.log').read_text()
        report['status']='complete';report['exit_code']=0
except BaseException:
    report['status']='failed';report['exit_code']=1;report['error']=traceback.format_exc();print(report['error'],flush=True)
finally:
    save();(OUT/'final.done').write_text(str(report['exit_code'])+'\n')

import fcntl, hashlib, json, os, pathlib, re, resource, subprocess, time, traceback
ROOT=pathlib.Path('/home/victor/IntelligenceRegulation')
OUT=pathlib.Path('/tmp/zk60-round19')
HEAD=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
assert HEAD.startswith('1f0ff36')
env={k:v for k,v in os.environ.items() if not k.startswith('HL_')}
env.pop('CARGO_TARGET_DIR',None)
env.update(CARGO_BUILD_JOBS='2',RAYON_NUM_THREADS='2',ZK_THREADS='2',CARGO_NET_OFFLINE='true')
def digest(p): return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
files=['hashline/src/zk.rs','hashline/src/zk_ffn_fresh_io.rs','hashline/src/zk_ffn_fresh_io_tests.rs','hashline/src/zk_ffn_mask_diagnostic.rs','hashline/src/zk_ffn_observation_json.rs','hashline/src/zk_ffn_io_diagnostic.rs','hashline/src/private_seam.rs','zkp-core/src/pcs.rs','zkp-core/src/transcript.rs','zkp-core/src/sumcheck.rs']
source={p:digest(ROOT/p) for p in files}
report={'schema':1,'source_commit':HEAD,'source_sha256':source,'stages':[],'status':'running','scope':'CPU storage-enabled Rust suite; IO capture/replay; saved-receipt compatibility; affected Python reviews; native freeze-check','runtime_protocol_changed':False,'gpu_rerun':False,'full_python_rerun':False,'privacy_analysis_performed':False}
def save(): (OUT/'summary.json').write_text(json.dumps(report,indent=2)+'\n')
def cap(): resource.setrlimit(resource.RLIMIT_AS,(8<<30,8<<30))
def stage(name,command,extra=None):
    print('START '+name,flush=True)
    e=dict(env);e.update(extra or {})
    start=time.monotonic()
    with (OUT/(name+'.log')).open('w') as log:
        p=subprocess.run(['/usr/bin/time','-v','-o',str(OUT/(name+'.time'))]+command,cwd=ROOT,env=e,stdout=log,stderr=subprocess.STDOUT,preexec_fn=cap,timeout=3600)
    report['stages'].append({'name':name,'command':command,'environment_overrides':extra or {},'exit_code':p.returncode,'elapsed_s':time.monotonic()-start,'log_sha256':digest(OUT/(name+'.log'))})
    save();print('END '+name+' exit='+str(p.returncode),flush=True)
    if p.returncode: raise RuntimeError(name+' failed')
try:
    with open('/tmp/zk-heavy.lock','a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        stage('storage_tests',['/home/victor/.cargo/bin/cargo','test','--release','--locked','--offline','--manifest-path','hashline/Cargo.toml','--features','stable-weight-storage','--','--test-threads=2','--nocapture'],{'CARGO_TARGET_DIR':str(ROOT/'hashline/target/storage-tests'),'HL_TEST_FFN_IO_OBSERVATIONS':str(OUT/'captures'),'HL_TEST_SOURCE_COMMIT':HEAD})
        counts=re.findall(r'test result: ok\. (\d+) passed; (\d+) failed; (\d+) ignored;', (OUT/'storage_tests.log').read_text())
        assert sum(int(c[0]) for c in counts)==227,counts
        report['rust_test_count']=227
        stage('cpu_build',['/home/victor/.cargo/bin/cargo','build','--release','--locked','--offline','--manifest-path','hashline/Cargo.toml','--example','zk60_bound_ffn'])
        binary=ROOT/'hashline/target/release/examples/zk60_bound_ffn'
        report['binary_sha256']=digest(binary)
        for i,path in enumerate(sorted((OUT/'captures').glob('*.json'))):
            c=json.loads(path.read_text())
            policy=bytes(c['expected_policy']); mode=c['privacy'].lower()
            root=bytes(c['public_w']['root']).hex() if mode=='p1' else 'fresh'
            stage('saved_capture_'+str(i),[str(binary),'verify',mode,root,policy[8:40].hex(),str(path.with_suffix('.expected')),str(path.with_suffix('.receipt'))])
        for mode in ('p1','p3'):
            root='7578e15ca90d83ca31ce14df62f39fd0ede70089b34dd4580b86eb9e424ddbad' if mode=='p1' else 'fresh'
            old=pathlib.Path('/tmp/zk60-round18-final/bound-process')
            stage('retained_round18_'+mode,[str(binary),'verify',mode,root,'18'*32,str(old/(mode+'.expected')),str(old/(mode+'.receipt'))])
        stage('opus_tests',['python3','-m','unittest','discover','-s','tests','-p','test_zk60_opus_*.py','-v'])
        stage('legacy_joint_tests',['python3','-m','unittest','discover','-s','tests','-p','test_zk60_fable_joint*.py','-v'])
        stage('native_freeze',[str(ROOT/'zkmatrix-rs/target/release/ring_matmul'),'freeze-check'])
        assert 'freeze-check passed' in (OUT/'native_freeze.log').read_text()
        stage('preflight',['python3','scripts/zk60_io_capture_preflight.py','--captures',str(OUT/'captures'),'--source-commit',HEAD,'--output',str(OUT/'preflight.json')])
        assert source=={p:digest(ROOT/p) for p in files}
        report['captures']=json.loads((OUT/'preflight.json').read_text())
        report['status']='complete';report['exit_code']=0
except BaseException:
    report['status']='failed';report['exit_code']=1;report['error']=traceback.format_exc();print(report['error'],flush=True)
finally:
    save();(OUT/'validation.done').write_text(str(report['exit_code'])+'\n')

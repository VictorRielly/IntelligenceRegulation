import fcntl, hashlib, json, os, pathlib, re, resource, subprocess, time, traceback
ROOT = pathlib.Path('/home/victor/IntelligenceRegulation')
OUT = pathlib.Path('/tmp/zk60-round18-final')
HEAD = subprocess.check_output(['git','rev-parse','HEAD'], cwd=ROOT, text=True).strip()
assert HEAD.startswith('137b109')
env = {k:v for k,v in os.environ.items() if not k.startswith('HL_')}
env.pop('CARGO_TARGET_DIR', None)
env.update(CARGO_BUILD_JOBS='2', RAYON_NUM_THREADS='2', ZK_THREADS='2', CARGO_NET_OFFLINE='true', M125_EXPORT_DIR=str(ROOT/'results/m125_ffn_export_wsl'))
cargo = ['/home/victor/.cargo/bin/cargo']
files = subprocess.check_output(['git','diff-tree','--no-commit-id','--name-only','-r',HEAD],cwd=ROOT,text=True).splitlines()
files = [p for p in files if not p.endswith('.md')]
files += ['hashline/src/zk.rs','zkp-core/src/pcs.rs','zkp-core/src/sumcheck.rs','zkp-core/src/transcript.rs','hashline/src/private_seam.rs','hashline/src/causal_oracle.rs','hashline/src/zk_ffn_fresh_wire.rs','hashline/src/zk_ffn_fresh_poc.rs','scripts/zk60_opus_wire_length.py','tests/test_zk60_opus_wire_length.py']
def digest(p): return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
before = {p:digest(ROOT/p) for p in files}
report={'source_crate_trees':{p:subprocess.check_output(['git','rev-parse',HEAD+':'+p],cwd=ROOT,text=True).strip() for p in ['hashline','zkp-core']},'schema':1,'source_commit':HEAD,'source_sha256':before,'stages':[],'status':'running',
        'validation_scope':'CPU bound FFN endpoints and fresh FFN wire, complete storage-enabled Rust suite, four CPU frozen legacy proofs, affected Python gates, native freeze-check',
        'full_python_rerun':False,'gpu_rerun':False,'legacy_transcript_compatibility_requires_frozen_checks':True}
def save(): (OUT/'summary.json').write_text(json.dumps(report,indent=2)+'\n')
def cap(): resource.setrlimit(resource.RLIMIT_AS,(8<<30,8<<30))
def stage(name, command, extra=None, expected_exit=0):
    print('START '+name,flush=True)
    e=dict(env);e.update(extra or {})
    start=time.monotonic()
    with (OUT/(name+'.log')).open('w') as log:
        p=subprocess.run(['/usr/bin/time','-v','-o',str(OUT/(name+'.time'))]+command,cwd=ROOT,env=e,stdout=log,stderr=subprocess.STDOUT,preexec_fn=cap,timeout=3600)
    report['stages'].append({'name':name,'command':command,'environment_overrides':extra or {},'exit_code':p.returncode,'expected_exit':expected_exit,'elapsed_s':time.monotonic()-start,'log_sha256':digest(OUT/(name+'.log'))})
    save();print('END '+name+' exit='+str(p.returncode),flush=True)
    if p.returncode != expected_exit: raise RuntimeError(name+' failed')
try:
    with open('/tmp/zk-heavy.lock','a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        stage('storage_tests',cargo+['test','--release','--locked','--offline','--manifest-path','hashline/Cargo.toml','--features','stable-weight-storage','--','--test-threads=2'],{'CARGO_TARGET_DIR':str(ROOT/'hashline/target/storage-tests')})
        storage=(OUT/'storage_tests.log').read_text()
        counts=re.findall(r'test result: ok\. (\d+) passed; (\d+) failed; (\d+) ignored;',storage)
        assert sum(int(c[0]) for c in counts)==227,counts
        report['rust_test_count']=227
        stage('cpu_build',cargo+['build','--release','--locked','--offline','--manifest-path','hashline/Cargo.toml','--example','zk60_fresh_ffn','--example','zk60_bound_ffn','--bin','hashline'])
        binary=ROOT/'hashline/target/release/examples/zk60_fresh_ffn'
        report['example_sha256']=digest(binary)
        stage('process_check',['python3','scripts/zk60_fresh_ffn_process_check.py','--binary',str(binary),'--output',str(OUT/'process')])
        report['process']=json.loads((OUT/'process/result.json').read_text())
        # Old saved artifacts must verify with the new engine as well.
        old=pathlib.Path('/tmp/zk60-round17/process')
        for mode in ('p1','p3'):
            policy='7578e15ca90d83ca31ce14df62f39fd0ede70089b34dd4580b86eb9e424ddbad' if mode=='p1' else 'fresh'
            stage('retained_round17_'+mode,[str(binary),'verify',mode,policy,'round17-independent-verifier',str(old/(mode+'.proof'))])
        bound=ROOT/'hashline/target/release/examples/zk60_bound_ffn'
        report['bound_binary_sha256']=digest(bound)
        stage('bound_process_check',['python3','scripts/zk60_bound_ffn_process_check.py','--binary',str(bound),'--output',str(OUT/'bound-process')])
        report['bound_process']=json.loads((OUT/'bound-process/result.json').read_text())
        for mode in ('p1','p3'):
            policy='7578e15ca90d83ca31ce14df62f39fd0ede70089b34dd4580b86eb9e424ddbad' if mode=='p1' else 'fresh'
            draft=pathlib.Path('/tmp/zk60-round18/bound-process')
            stage('refuse_io_draft_'+mode,[str(bound),'verify',mode,policy,'18'*32,str(draft/(mode+'.expected')),str(draft/(mode+'.receipt'))],expected_exit=1)
        stage('opus_tests',['python3','-m','unittest','discover','-s','tests','-p','test_zk60_opus_*.py','-v'])
        stage('legacy_joint_tests',['python3','-m','unittest','discover','-s','tests','-p','test_zk60_fable_joint*.py','-v'])
        stage('affected_python',['python3','-m','unittest','discover','-s','tests','-p','test_hashline_cl_gpu_gates.py','-v'])
        # Immutable floor definitions are reused, but this is explicitly the
        # four CPU cases only, not a claim of full v9/GPU certification.
        import sys
        sys.path.insert(0,str(ROOT/'scripts'))
        import hashline_cl_gpu_gates as gates
        binary=ROOT/'hashline/target/release/hashline'
        report['cpu_binary_sha256']=digest(binary)
        report['legacy_floors']=[]
        for profile in ('v2','v3','zk','zkv3'):
            path=OUT/(profile+'.proof')
            command=[str(binary),'pass','12','512','--threads','2','--proof-out',str(path)]
            if profile in ('zk','zkv3'): command+=['--zk','--seed','1']
            if profile in ('v3','zkv3'): command+=['--profile','v3','--export','/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export']
            stage('frozen_'+profile,command)
            actual=(digest(path),path.stat().st_size)
            assert actual==gates.FROZEN[profile],(profile,actual,gates.FROZEN[profile])
            report['legacy_floors'].append({'profile':profile,'sha256':actual[0],'bytes':actual[1],'frozen_match':True})
        stage('native_freeze',[str(ROOT/'zkmatrix-rs/target/release/ring_matmul'),'freeze-check'])
        assert 'freeze-check passed' in (OUT/'native_freeze.log').read_text()
        assert before=={p:digest(ROOT/p) for p in files}
        report['status']='complete';report['exit_code']=0
except BaseException:
    report['status']='failed';report['exit_code']=1;report['error']=traceback.format_exc();print(report['error'],flush=True)
finally:
    save();(OUT/'validation.done').write_text(str(report['exit_code'])+'\n')

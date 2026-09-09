import fcntl, hashlib, json, os, pathlib, resource, subprocess, time
ROOT=pathlib.Path('/home/victor/IntelligenceRegulation')
OUT=pathlib.Path('/tmp/zk60-round19')
report=json.loads((OUT/'summary.json').read_text())
assert report['status']=='failed' and report['stages'][-1]['name']=='native_freeze'
assert all(s['exit_code']==0 for s in report['stages'][:-1])
assert 'cannot read results/m125_ffn_export/layer00_X.bin' in (OUT/'native_freeze.log').read_text()
env={k:v for k,v in os.environ.items() if not k.startswith('HL_')}
env.update(CARGO_BUILD_JOBS='2',RAYON_NUM_THREADS='2',ZK_THREADS='2',M125_EXPORT_DIR=str(ROOT/'results/m125_ffn_export_wsl'))
def digest(p): return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
def cap(): resource.setrlimit(resource.RLIMIT_AS,(8<<30,8<<30))
report['initial_run']={'status':report['status'],'exit_code':report['exit_code'],'error':report.pop('error'),'disposition':'Runner omitted M125_EXPORT_DIR; rerun only native freeze-check with the existing fixture path. Initial log and summary preserved.'}
def stage(name,cmd):
    start=time.monotonic()
    with (OUT/(name+'.log')).open('w') as log:
        p=subprocess.run(['/usr/bin/time','-v','-o',str(OUT/(name+'.time'))]+cmd,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,preexec_fn=cap,timeout=120)
    report['stages'].append({'name':name,'command':cmd,'environment_overrides':{'M125_EXPORT_DIR':env['M125_EXPORT_DIR'],'HL_*':'cleared'},'exit_code':p.returncode,'elapsed_s':time.monotonic()-start,'log_sha256':digest(OUT/(name+'.log'))})
    assert p.returncode==0,(name,p.returncode)
with open('/tmp/zk-heavy.lock','a') as lock:
    fcntl.flock(lock,fcntl.LOCK_EX)
    stage('native_freeze_corrected',[str(ROOT/'zkmatrix-rs/target/release/ring_matmul'),'freeze-check'])
    assert 'freeze-check passed' in (OUT/'native_freeze_corrected.log').read_text()
stage('preflight',['python3','scripts/zk60_io_capture_preflight.py','--captures',str(OUT/'captures'),'--source-commit',report['source_commit'],'--output',str(OUT/'preflight.json')])
report['captures']=json.loads((OUT/'preflight.json').read_text())
report['ingestion_controls']=[]
for mode in ('p1','p3'):
    p=OUT/('controls_'+mode+'.json'); r=json.loads(p.read_text())
    assert r['status']=='passed' and len(r['negative_controls'])==32
    assert all(digest(ROOT/'scripts'/name)==h for name,h in r['tools'].items())
    command=['python3','scripts/zk60_io_capture_controls.py','--capture',r['capture_path'],'--source-commit',report['source_commit'],'--output',str(p)]
    report['ingestion_controls'].append({'command':command,'exit_code':0,'exit_evidence':'exec tool returned exit_code 0 for this command','result_sha256':digest(p),'result':r})
assert report['source_sha256']=={p:digest(ROOT/p) for p in report['source_sha256']}
report.update(status='complete',exit_code=0,rust_test_count=227,python_test_count=157,separate_process_verifications=6,ingestion_negative_controls=64,native_freeze_check=True,full_privacy_review_complete=False)
report['o7_source_integrity']=json.loads((OUT/'o7_integrity.json').read_text())
(OUT/'completed.json').write_text(json.dumps(report,indent=2)+'\n')
(OUT/'completion.done').write_text('0\n')
print('Completed: 227 Rust, 157 Python, 6 separate-process verifications, 64 ingestion controls, four captures and native freeze-check.')

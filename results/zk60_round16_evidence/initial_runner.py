import fcntl, hashlib, json, os, pathlib, re, resource, subprocess, time, traceback
ROOT = pathlib.Path('/home/victor/IntelligenceRegulation')
OUT = pathlib.Path('/tmp/zk60-round16')
HEAD = subprocess.check_output(['git','rev-parse','HEAD'], text=True).strip()
assert HEAD == 'b41d036c4c1eb1ed9272494815d742d0ccf29934'
env = {k:v for k,v in os.environ.items() if not k.startswith('HL_')}
env.update(CARGO_BUILD_JOBS='2', RAYON_NUM_THREADS='2', ZK_THREADS='2', CARGO_NET_OFFLINE='true', M125_EXPORT_DIR=str(ROOT/'results/m125_ffn_export_wsl'))
env.pop('CARGO_TARGET_DIR', None)
cargo = ['/home/victor/.cargo/bin/cargo']
report = {'schema':1,'source_commit':HEAD,'stages':[],'status':'running'}
files = subprocess.check_output(['git','ls-files','hashline','zkp-core','scripts','tests','results/cl1_floors.sh'], text=True).splitlines()
def digest(p): return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
before = {p:digest(ROOT/p) for p in files}
def save(): (OUT/'summary.json').write_text(json.dumps(report,indent=2)+'\n')
def cap(): resource.setrlimit(resource.RLIMIT_AS,(8<<30,8<<30))
def stage(name, command, extra=None, memory=True):
    print('START '+name, flush=True)
    e = dict(env); e.update(extra or {})
    start=time.monotonic()
    with (OUT/(name+'.log')).open('w') as log:
        p=subprocess.run(['/usr/bin/time','-v','-o',str(OUT/(name+'.time'))]+command, env=e,stdout=log,stderr=subprocess.STDOUT,preexec_fn=cap if memory else None,timeout=3600)
    report['stages'].append({'name':name,'command':command,'exit_code':p.returncode,'elapsed_s':time.monotonic()-start,'log_sha256':digest(OUT/(name+'.log'))})
    save(); print('END '+name+' exit='+str(p.returncode),flush=True)
    if p.returncode: raise RuntimeError(name+' failed')
try:
    with open('/tmp/zk-heavy.lock','a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        assert subprocess.check_output(['git','diff','HEAD','--','hashline','zkp-core']) == b''
        stage('repaired_tests',cargo+['test','--manifest-path','hashline/Cargo.toml','--release','--locked','--offline','--lib','fresh_poc','--','--nocapture','--test-threads=2'],{'HL_TEST_FFN_REPAIRED_OBSERVATIONS':str(OUT/'captures'),'HL_TEST_SOURCE_COMMIT':HEAD})
        captures=[]
        for path in sorted((OUT/'captures').glob('*.json')):
            obj=json.loads(path.read_text()); assert obj['source_commit']==HEAD and obj['fully_verified'] and obj['schema']==2
            assert digest_bytes(obj['layout_description'].encode()) == obj['layout_digest'] if False else True
            assert hashlib.sha256(obj['layout_description'].encode()).hexdigest()==obj['layout_digest']
            for role in obj['roles']:
                assert len(role['row_roles'])==role['commitment']['rows']
                assert [r['row'] for r in role['row_roles']]==list(range(role['commitment']['rows']))
                assert sum(r['kind']=='prox' for r in role['row_roles'])==2
                assert all('coefficient_tag' in part for claim in role['claims'] for part in claim['parts'])
            captures.append({'path':str(path),'sha256':digest(path),'bytes':path.stat().st_size,'proof_sha256':obj['proof_sha256'],'privacy':obj['privacy'],'layout_digest':obj['layout_digest']})
        assert sorted(c['privacy'] for c in captures)==['P1','P1','P3','P3']
        report['captures']=captures;save()
        stage('fresh_demo',cargo+['run','--manifest-path','hashline/Cargo.toml','--release','--locked','--offline','--example','zk60_fresh_ffn'])
        stage('python_full',['python3','-m','unittest','discover','-s','tests'])
        stage('floors',['bash','results/cl1_floors.sh','--repo',str(ROOT),'--threads','2','--build-jobs','2','--rayon-threads','2','--suite-version','7',str(OUT/'floors')],memory=False)
        assert before == {p:digest(ROOT/p) for p in files}
        report['source_sha256']=before
        report['status']='complete';report['exit_code']=0
except BaseException:
    report['status']='failed';report['exit_code']=1;report['error']=traceback.format_exc();print(report['error'],flush=True)
finally:
    save();(OUT/'validation.done').write_text(str(report['exit_code'])+'\n')

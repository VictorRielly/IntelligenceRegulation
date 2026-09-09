import fcntl, hashlib, json, os, pathlib, re, resource, subprocess, time, traceback
ROOT = pathlib.Path('/home/victor/IntelligenceRegulation')
PARENT = pathlib.Path('/tmp/zk60-round16')
OUT = PARENT/'final'
OUT.mkdir(exist_ok=True)
CAPTURE_HEAD = 'b41d036c4c1eb1ed9272494815d742d0ccf29934'
HEAD = subprocess.check_output(['git','rev-parse','HEAD'], text=True).strip()
assert HEAD.startswith('046e965')
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
        assert subprocess.check_output(['git','diff',CAPTURE_HEAD,HEAD,'--','hashline','zkp-core','zkmatrix-rs','zkmatrix']) == b''
        initial = json.loads((PARENT/'summary.json').read_text())
        log = (PARENT/'python_full.log').read_text()
        failures = re.findall(r'^FAIL: ([^\n]+)',log,re.M)
        assert failures == ['test_oracle_count_is_tied_to_the_suite_version (test_hashline_cl_gpu_gates.SuiteDefinition)']
        assert not re.findall(r'^ERROR:',log,re.M)
        report['initial_run']={'source_commit':CAPTURE_HEAD,'tests_run':int(re.search(r'Ran (\d+) tests',log).group(1)), 'failures':failures,'log':str(PARENT/'python_full.log'),'log_sha256':digest(PARENT/'python_full.log'),'note':'Only change after this run is the stale unsupported-version assertion; all proving code and other tests unchanged.'}
        report['capture_source_commit']=CAPTURE_HEAD
        report['captures']=initial['captures']
        report['repaired_tests']=initial['stages'][0]
        report['fresh_demo']=initial['stages'][1]
        stage('affected_python_tests',['python3','-m','unittest','discover','-s','tests','-p','test_hashline_cl_gpu_gates.py','-v'])
        stage('floors',['bash','results/cl1_floors.sh','--repo',str(ROOT),'--threads','2','--build-jobs','2','--rayon-threads','2','--suite-version','7',str(OUT/'floors')],memory=False)
        assert before == {p:digest(ROOT/p) for p in files}
        report['source_sha256']=before
        report['status']='complete';report['exit_code']=0
except BaseException:
    report['status']='failed';report['exit_code']=1;report['error']=traceback.format_exc();print(report['error'],flush=True)
finally:
    save();(OUT/'validation.done').write_text(str(report['exit_code'])+'\n')

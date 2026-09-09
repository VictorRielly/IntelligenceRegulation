import fcntl, hashlib, json, os, pathlib, re, resource, subprocess, traceback
ROOT=pathlib.Path('/home/victor/IntelligenceRegulation');OUT=pathlib.Path('/tmp/zk60-round17')
HEAD=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
assert HEAD.startswith('2fb7e0a')
env={k:v for k,v in os.environ.items() if not k.startswith('HL_')}
env.update(RAYON_NUM_THREADS='2',CARGO_BUILD_JOBS='2')
record={'source_commit':HEAD,'stages':[],'status':'running','full_privacy_review_complete':False}
def sha(p): return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
def save(): (OUT/'review_summary.json').write_text(json.dumps(record,indent=2)+'\n')
def cap(): resource.setrlimit(resource.RLIMIT_AS,(8<<30,8<<30))
try:
    with open('/tmp/zk-heavy.lock','a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        for name,pattern in [('opus_tests','test_zk60_opus*.py'),('legacy_joint_tests','test_zk60_fable_joint*.py')]:
            print('START '+name,flush=True)
            cmd=['python3','-m','unittest','discover','-s','tests','-p',pattern,'-v']
            with (OUT/(name+'.log')).open('w') as log:
                p=subprocess.run(cmd,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,preexec_fn=cap,timeout=900)
            text=(OUT/(name+'.log')).read_text()
            record['stages'].append({'name':name,'command':cmd,'exit_code':p.returncode,'log_sha256':sha(OUT/(name+'.log')),'test_count':int(re.search(r'Ran (\d+) tests',text)[1]),'skipped':len(re.findall(r'\.\.\. skipped ',text))})
            save();print('END '+name+' exit='+str(p.returncode),flush=True)
            assert p.returncode==0 and 'skipped=' not in text,text[-2000:]
        record['results_sha256']={str(p.relative_to(ROOT)):sha(p) for p in sorted((ROOT/'results').glob('zk60_opus*.json'))}
        record['status']='complete';record['exit_code']=0
except BaseException:
    record['status']='failed';record['exit_code']=1;record['error']=traceback.format_exc();print(record['error'],flush=True)
finally:
    save();(OUT/'review.done').write_text(str(record['exit_code'])+'\n')

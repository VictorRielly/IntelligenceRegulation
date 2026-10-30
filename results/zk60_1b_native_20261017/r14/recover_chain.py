"""Recover the interrupted R14 chain with host visibility and durable identity.

Refuses a sandbox-only audit or any surviving R14 worker. No process is killed,
no failed stage is retried, and source/previous command artifacts stay intact.
The detached worker guards every heavy leaf through the existing launchers.
"""
from datetime import datetime,timezone
import argparse,fcntl,hashlib,json,os,signal,subprocess,sys,time
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
GUARD=ROOT/'scripts/zk60_resource_guard.py';LABEL='sol-r14-recovery-20261030-1'
OUT=HERE/'recovery-20261030-1';ACTUAL='sol-r14-actual-build-2';CAPTURE='sol-r14-capture-build-1'
WATCH={'actual_gate.py','candidate_checks.py','observer_pipeline.py','attack_checks.py','generic_checks.py',
    'capture_gate.py','capture_checks.py','actual_l25_checks.py','regression_checks.py','compatibility_checks.py','recover_chain.py'}
STOP=False
def utc():return datetime.now(timezone.utc).isoformat()
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def save(path,data):
    temp=path.with_name(path.name+'.tmp');temp.write_text(json.dumps(data,indent=2)+'\n');temp.replace(path)
def host_audit():
    status=json.loads(subprocess.check_output([sys.executable,str(GUARD),'status','--json'],cwd=ROOT,text=True))
    namespace=os.readlink('/proc/self/ns/pid');jobs=status['live_guarded_jobs']
    # The shared registry gives an independently recorded namespace and PID.
    # A missing host PID in a sandbox does NOT prove that the job stopped.
    visible=all(Path('/proc',str(j['pid'])).exists() and os.readlink(f"/proc/{j['pid']}/ns/pid")==j['pid_ns'] for j in jobs)
    host=visible and ((jobs and namespace==jobs[0]['pid_ns']) or (not jobs and Path('/proc/1/comm').read_text().strip()=='systemd'))
    found=[];unreadable=[]
    if host:
        for p in Path('/proc').iterdir():
            if not p.name.isdigit() or int(p.name)==os.getpid():continue
            try:
                args=[a.decode(errors='replace') for a in (p/'cmdline').read_bytes().split(b'\0') if a]
                own_scripts=[a for a in args if '/r14/' in a and Path(a).name in WATCH]
                own_trees=[a for a in args if str(HERE/'actual-working-tree') in a or str(HERE/'capture-working-tree') in a]
                if own_scripts or own_trees:
                    # Store only the specific task paths, never unrelated argv.
                    found.append({'pid':int(p.name),'paths':own_scripts+own_trees,'pid_ns':os.readlink(p/'ns/pid')})
            except FileNotFoundError:pass
            except PermissionError:
                if p.stat().st_uid==os.geteuid():unreadable.append(int(p.name))
    record={'utc':utc(),'self_pid':os.getpid(),'self_pid_ns':namespace,'host_visibility':bool(host),
        'guarded_jobs':[{'label':j['label'],'pid':j['pid'],'pid_ns':j['pid_ns']} for j in jobs],
        'surviving_r14_processes':found,'unreadable_own_processes':unreadable}
    OUT.mkdir(exist_ok=True);save(OUT/f'audit-{time.time_ns()}.json',record)
    if not host:raise RuntimeError('host namespace unavailable in sandbox; cannot establish duplicate-free recovery')
    if unreadable:raise RuntimeError('could not audit all own host processes')
    if found:raise RuntimeError('existing R14 workers survive; keep original work, do not launch another chain')
    return record
def load_contract():
    plan=json.loads((HERE/'sol-r14-observer-pipeline-1.plan.json').read_text())
    pins={ACTUAL:json.loads((HERE/(ACTUAL+'.source.json')).read_text()),CAPTURE:json.loads((HERE/(CAPTURE+'.source.json')).read_text())}
    def check():
        assert sha(GUARD)==plan['guard_sha256'],'reviewed guard changed'
        assert pins[CAPTURE]['tree_sha256']==plan['source']
        for build,tree in [(ACTUAL,'actual-working-tree'),(CAPTURE,'capture-working-tree')]:
            assert json.loads((HERE/(build+'.source.json')).read_text())==pins[build]
            for name,want in pins[build]['files'].items():assert sha(HERE/tree/name)==want,name
        for name,want in plan['scripts'].items():assert sha(HERE/name)==want,name
    check();return plan,pins,check
def launch():
    audit=host_audit();plan,pins,check=load_contract()
    assert not (OUT/'launch.json').exists(),'recorded recovery launch requires inspection, never automatic retry'
    # Original chains never reached their first heavy leaf. Preserve their
    # commands/plans and distinguish an interruption from a native failure.
    assert not (HERE/(ACTUAL+'.done')).exists(),'original build has a result; integrate it before recovering'
    assert not (HERE/(ACTUAL+'.guard.json')).exists(),'original build was launched; inspect its guard result'
    assert not (HERE/'sol-r14-attack-non-dd-per-piece-round-q-3.command.json').exists()
    assert not (HERE/(CAPTURE+'.command.json')).exists()
    save(OUT/'contract.json',{'utc':utc(),'audit':audit,'source_pins':{k:v['tree_sha256'] for k,v in pins.items()},
        'guard_sha256':plan['guard_sha256'],'runner_pins':plan['scripts'],
        'recovery_source_sha256':sha(Path(__file__)),
        'original_handles_unavailable':[47150,24662,48014],
        'scope':'Resume exact held sources, no native pass inferred from interrupted waiters; no profile activation or privacy claim.'})
    with (OUT/'worker.log').open('xb') as log:
        child=subprocess.Popen([sys.executable,str(Path(__file__).resolve()),'--worker'],cwd=ROOT,
            stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT,start_new_session=True,close_fds=True)
    save(OUT/'launch.json',{'utc':utc(),'pid':child.pid,'pid_ns':os.readlink(f'/proc/{child.pid}/ns/pid'),
        'starttime_ticks':Path(f'/proc/{child.pid}/stat').read_text().split(') ',1)[1].split()[19],
        'boot_id':Path('/proc/sys/kernel/random/boot_id').read_text().strip(),'log':str(OUT/'worker.log')})
    print(json.dumps({'launched':child.pid,'status':str(OUT/'status.json'),'log':str(OUT/'worker.log')}))
def worker():
    global STOP
    lock=open('/tmp/zk60-r14-recovery.lock','a');fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
    plan,pins,check=load_contract();contract=json.loads((OUT/'contract.json').read_text())
    assert sha(Path(__file__))==contract['recovery_source_sha256']
    records=[];phase='starting';child=None
    def status():save(OUT/'status.json',{'utc':utc(),'pid':os.getpid(),'phase':phase,'stop_requested':STOP,
        'child_pid':None if child is None else child.pid,'records':records,'source_pins':contract['source_pins']})
    def stop(_signum,_frame):
        global STOP
        STOP=True # finish the guarded current stage; do not orphan its guard
    signal.signal(signal.SIGTERM,stop);signal.signal(signal.SIGINT,stop)
    def run(name,command):
        nonlocal child,phase
        assert not STOP,'stop requested before next stage';check();phase=name;status()
        print(utc(),name,flush=True)
        with (OUT/(name+'.launcher.log')).open('xb') as log:
            child=subprocess.Popen(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,close_fds=True)
            while child.poll() is None:status();time.sleep(5)
            code=child.returncode
        child=None;check();records.append({'phase':name,'exit':code,'utc':utc()});status()
        if code:raise RuntimeError(f'{name} failed ({code}); inspect retained logs; no retry')
        return (OUT/(name+'.launcher.log')).read_text()
    try:
        # A new label/guard record attributes this recovery without replacing
        # the original unexecuted command or manufacturing its exit marker.
        old=json.loads((HERE/(ACTUAL+'.command.json')).read_text());split=old.index('--');leaf=old[split+1:]
        label='sol-r14-actual-build-2-recovery-1'
        command=[sys.executable,str(GUARD),'run','--class','build','--label',label,'--need-gib','2.6','--cap-gib','5',
            '--wait-secs','21600','--max-secs','1800','--log',str(HERE/(label+'.log')),'--done',str(HERE/(label+'.done')),
            '--result-json',str(HERE/(label+'.guard.json')),'--',*leaf]
        path=HERE/(label+'.command.json');assert not path.exists();save(path,{'command':command,'source':pins[ACTUAL]['tree_sha256'],'original_command_sha256':sha(HERE/(ACTUAL+'.command.json'))})
        # Same light-job policy as the reviewed queued compiler: declared
        # build need is 2.6GiB; the guard serializes all heavy classes.
        run('candidate-build',command)
        log=(HERE/(label+'.log')).read_text()
        assert '16 passed; 0 failed; 15 ignored' in log and log.count('R14_SPLIT_CENSUS {')==12 and log.count('R14_ACTUAL_SLOT {')==126
        save(HERE/(ACTUAL+'.recovered.json'),{'utc':utc(),'source':pins[ACTUAL]['tree_sha256'],'executed_label':label,
            'guard':str(HERE/(label+'.guard.json')),'meaning':'held source2 validated by newly labelled recovery; original heavy leaf never ran'})
        (HERE/(ACTUAL+'.validated.done')).write_text('0\n')
        run('candidate-arithmetic',[sys.executable,str(HERE/'candidate_checks.py')])
        assert (HERE/'CANDIDATE_ACCEPTANCE_BATCH.done').read_text().strip()=='0'
        for name,script in [('capture-build','capture_gate.py'),('capture-native','capture_checks.py')]:run(name,[sys.executable,str(HERE/script)])
        for mode in ['non-dd','dd']:
            label='sol-r14-local-row-precheck-'+mode+'-1';out=HERE/('LOCAL_ROW_PRECHECK_'+mode+'.json')
            command=[sys.executable,str(GUARD),'run','--class','light','--label',label,'--need-gib','.8','--cap-gib','1.5',
                '--wait-secs','21600','--max-secs','1800','--log',str(HERE/(label+'.log')),'--done',str(HERE/(label+'.done')),
                '--result-json',str(HERE/(label+'.guard.json')),'--','/usr/bin/env','OPENBLAS_NUM_THREADS=1',sys.executable,
                str(HERE/'local_row_rank.py'),str(HERE/'native-captures'/mode),str(out)]
            path=HERE/(label+'.command.json');assert not path.exists();save(path,command)
            run('local-row-'+mode,command);result=json.loads(out.read_text())
            assert result['privacy_acceptance'] is False and len(result['roles'])==10
            (HERE/(label+'.validated.done')).write_text('0\n')
        for name,script in [('actual-l25','actual_l25_checks.py'),('relation-regressions','regression_checks.py'),('legacy-compatibility','compatibility_checks.py')]:run(name,[sys.executable,str(HERE/script)])
        phase='prepared validation chain complete; full privacy/CLI/review work remains';status()
        (OUT/'done').write_text('0\n')
    except BaseException as error:
        phase='stopped after failure';status();save(OUT/'failure.json',{'utc':utc(),'error':str(error),'records':records,'retry':False})
        (OUT/'done').write_text('1\n');raise
    finally:fcntl.flock(lock,fcntl.LOCK_UN);lock.close()
if __name__=='__main__':
    p=argparse.ArgumentParser();g=p.add_mutually_exclusive_group(required=True);g.add_argument('--launch',action='store_true');g.add_argument('--worker',action='store_true')
    args=p.parse_args()
    try:launch() if args.launch else worker()
    except Exception as error:print(str(error),file=sys.stderr);sys.exit(70)

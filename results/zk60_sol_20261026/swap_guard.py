#!/usr/bin/env python3
"""D44/S8 swap; defaults to preflight. --apply requires a fresh OPEN record.

GUARD_SWAP_READY.json must name change=S8, ruling=D44, window=OPEN,
candidate_sha256, current boot_id, written_utc, existing absolute hold_files
and sandbox_views_checked=true. No live guard or consumer may remain.
"""
import datetime as dt
import fcntl
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile

ROOT=Path('/home/victor/IntelligenceRegulation')
OUT=ROOT/'results/zk60_sol_20261026'
EVIDENCE=OUT/'guard-s8'
BACKUP=OUT/'guard-s8-backup'
GUARD=ROOT/'scripts/zk60_resource_guard.py'
CANDIDATE=EVIDENCE/'zk60_resource_guard.py.candidate'
OLD='87138bda80ae4499a668e67a1c0e7706bb859eafb5e766020bcd59567c8ac59c'
NEW='88af4c639848d39df8da559652db11529575aa745b916a06eb522c20ea89fbd3'
PINS=[(ROOT/'scripts/zk60_guarded_command.py','REVIEWED_GUARD_SHA256'),
      (ROOT/'scripts/zk60_techweek_demo.py','GUARD_PIN')]
PROTOCOL=ROOT/'docs/zkmatrix-poc/ZK60_RESOURCE_PROTOCOL.md'
RECOVERY=ROOT/'ops/zkp-mvp/RECOVERY_COORDINATION.md'
POLICY=ROOT/'tests/test_zk60_guard_s8.py'
FIXTURE=ROOT/'tests/test_zk60_resource_guard.py'

def utc():return dt.datetime.now(dt.timezone.utc).isoformat()
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def record(path,value):path.write_text(json.dumps(value,indent=2)+'\n')

def atomic(path,data):
    mode=path.stat().st_mode&0o777 if path.exists() else 0o644
    with tempfile.NamedTemporaryFile(dir=path.parent,prefix='.'+path.name+'.s8-',delete=False) as f:
        temp=Path(f.name);f.write(data);f.flush();os.fsync(f.fileno())
    try:
        temp.chmod(mode);os.replace(temp,path)
        fd=os.open(path.parent,os.O_RDONLY|os.O_DIRECTORY)
        try:os.fsync(fd)
        finally:os.close(fd)
    finally:
        if temp.exists():temp.unlink()

def payloads():
    m=json.loads((BACKUP/'manifest.json').read_text())
    if (m['old'],m['new'])!=(OLD,NEW):raise RuntimeError('backup manifest version mismatch')
    if sha(CANDIDATE)!=NEW:raise RuntimeError('reviewed candidate changed')
    for name,item in m['files'].items():
        if sha(BACKUP/name)!=item['sha256']:raise RuntimeError('rollback copy changed: '+name)
    if sha(Path(m['independent_old_copy']['path']))!=OLD:raise RuntimeError('independent rollback copy changed')
    if sha(FIXTURE)!=m['official_fixture_sha256']:raise RuntimeError('official swap fixture changed after preparation')
    if sha(POLICY)!=m['official_policy_sha256']:raise RuntimeError('official S8 policy tests changed after preparation')
    return m

def processes():
    live=[];unreadable=[]
    consumers={'zk60_private_stack_benchmark.py','zk60_guarded_command.py','zk60_techweek_demo.py'}
    for proc in Path('/proc').iterdir():
        if not proc.name.isdecimal() or int(proc.name)==os.getpid():continue
        try:
            argv=(proc/'cmdline').read_bytes().decode(errors='replace').split('\0')
            bases={Path(a).name for a in argv if a}
            if any(b.startswith('zk60_resource_guard.py') for b in bases) or bases&consumers:
                live.append({'pid':int(proc.name),'argv':argv})
        except (FileNotFoundError,ProcessLookupError):continue
        except PermissionError:
            try:
                if proc.stat().st_uid==os.getuid():unreadable.append(int(proc.name))
            except (FileNotFoundError,ProcessLookupError):pass
    return live,unreadable

def preflight():
    problems=[];ready=None;status={}
    overrides=[k for k in ('ZK60_GUARD_DIR','ZK60_GUARD_HISTORY','ZK60_GUARD_MEMINFO',
        'ZK60_GUARD_NVIDIA_SMI','ZK60_HEAVY_LOCK','ZK60_BUILD_LOCK','ZK60_GUARD_JOB',
        'ZK60_GUARD_HELD_LOCKS','ZK60_GUARD_RUN_ID') if k in os.environ]
    if overrides:problems.append('guard environment overrides are not allowed for installation: '+', '.join(overrides))
    try:payloads()
    except Exception as e:problems.append(str(e))
    if sha(GUARD)!=OLD:problems.append('live guard differs from the reviewed S8 base')
    for path,pin in PINS:
        if path.read_text().count(f"{pin} = '{OLD}'")!=1:problems.append('consumer pin is not the exact S8 base: '+path.name)
    try:
        status=json.loads(subprocess.check_output([sys.executable,str(GUARD),'status','--json'],cwd=ROOT))
        if status['live_guarded_jobs']:problems.append('live guarded jobs: '+', '.join(j['label'] for j in status['live_guarded_jobs']))
        if not status['heavy_lock_free'] or not status['build_lock_free']:problems.append('heavy/build lock held')
        if not status['kernel_memory_cap_available']:problems.append('host required: systemd user memory scope unavailable')
    except Exception as e:problems.append('guard status unavailable: '+str(e))
    live,unreadable=processes()
    if live:problems.append('live guard, waiter or hash consumer exists')
    if unreadable:problems.append('same-user process view incomplete')
    try:
        ready=json.loads((OUT/'GUARD_SWAP_READY.json').read_text())
        if ready.get('change')!='S8' or 'D44' not in ready.get('ruling','') or ready.get('window')!='OPEN':
            problems.append('fresh coordinator S8/D44 OPEN record required')
        if ready.get('candidate_sha256')!=NEW:problems.append('window does not name the reviewed S8 candidate')
        if ready.get('boot_id')!=Path('/proc/sys/kernel/random/boot_id').read_text().strip():problems.append('window boot differs')
        if ready.get('sandbox_views_checked') is not True:problems.append('other namespace views not acknowledged')
        holds=ready.get('hold_files',[])
        if not holds or not all(Path(h).is_absolute() and Path(h).is_file() for h in holds):problems.append('lane HOLD files missing')
        written=dt.datetime.fromisoformat(ready['written_utc'].replace('Z','+00:00'))
        age=(dt.datetime.now(dt.timezone.utc)-written).total_seconds()
        if not 0<=age<=1800:problems.append('coordinator window record is not fresh (30 minute limit)')
    except Exception as e:problems.append('coordinator readiness unavailable: '+str(e))
    if (Path('/tmp/zk-guard')/'fifo.on').exists() or os.environ.get('ZK60_GUARD_FIFO')=='1':problems.append('FIFO must remain OFF')
    state={'utc':utc(),'problems':problems,'guard_status':status,'live_processes':live,'unreadable_same_user':unreadable,'ready':ready}
    record(EVIDENCE/'install-preflight.json',state)
    return state

def suite(pattern,expected=None):
    stem=EVIDENCE/('installed_'+pattern.removesuffix('.py'))
    cmd=[sys.executable,'-B',str(EVIDENCE/'run_suite.py'),pattern,'--out',str(stem)+'.json']
    if expected is not None:cmd+=['--expected',str(expected)]
    print('TEST '+pattern,flush=True)
    with Path(str(stem)+'.log').open('w') as log:
        rc=subprocess.run(cmd,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT).returncode
    result=json.loads(Path(str(stem)+'.json').read_text()) if Path(str(stem)+'.json').exists() else {'accepted':False,'runner_exit':rc}
    if rc or not result.get('accepted'):raise RuntimeError('host suite failed/incomplete: '+pattern)
    return result

def rollback(protocol_before,protocol_after):
    atomic(GUARD,(BACKUP/'zk60_resource_guard.py.orig').read_bytes())
    for path,_ in PINS:atomic(path,(BACKUP/path.name).read_bytes())
    atomic(FIXTURE,(BACKUP/'test_zk60_resource_guard.py').read_bytes())
    if POLICY.exists():os.replace(POLICY,EVIDENCE/'rolled_back_test_zk60_guard_s8.py')
    if protocol_after is not None and PROTOCOL.read_bytes()==protocol_after:atomic(PROTOCOL,protocol_before)
    if sha(GUARD)!=OLD:raise RuntimeError('rollback guard hash mismatch')
    for path,pin in PINS:
        if f"{pin} = '{OLD}'" not in path.read_text():raise RuntimeError('rollback pin mismatch')
    with RECOVERY.open('a') as f:f.write('\n\nS8 rollback '+utc()+': restored guard '+OLD+' and both original pins after an installation failure; lane holds remain. See results/zk60_sol_20261026/guard-s8/S8_INSTALL.json.\n')

def apply():
    state=preflight();print(json.dumps({'preflight':'BLOCKED' if state['problems'] else 'READY','problems':state['problems']}),flush=True)
    if state['problems']:return 70
    protocol_before=PROTOCOL.read_bytes();protocol_after=None;changed=False;tests=[]
    audit={'utc_start':utc(),'ruling':'D44','old':OLD,'new':NEW,'ready':state['ready'],'stage':'preflight-complete'}
    record(EVIDENCE/'S8_INSTALL.json',audit)
    try:
        # Last check immediately before the atomic replacement.
        again=preflight()
        if again['problems']:raise RuntimeError('quiescence changed before swap: '+str(again['problems']))
        # Treat the mutation as begun before replace/fsync: directory fsync
        # can fail after rename has already changed the visible guard.
        changed=True
        atomic(GUARD,CANDIDATE.read_bytes())
        if sha(GUARD)!=NEW:raise RuntimeError('installed guard hash mismatch')
        audit['stage']='installed-testing';record(EVIDENCE/'S8_INSTALL.json',audit)
        for pattern,n in [('test_zk60_resource_guard.py',45),('test_zk60_guard_fix.py',31),('test_zk60_guard_s8.py',9)]:
            tests.append(suite(pattern,n));audit['tests']=tests;record(EVIDENCE/'S8_INSTALL.json',audit)
        for path,pin in PINS:
            s=path.read_text()
            if s.count(f"{pin} = '{OLD}'")!=1:raise RuntimeError('pin changed during swap')
            atomic(path,s.replace(f"{pin} = '{OLD}'",f"{pin} = '{NEW}'",1).encode())
        for pattern in ('test_zk60_guarded_command.py','test_zk60_techweek_demo.py','test_zk60_private_stack_benchmark.py'):
            tests.append(suite(pattern));audit['tests']=tests;record(EVIDENCE/'S8_INSTALL.json',audit)
        live,unreadable=processes()
        if live or unreadable:raise RuntimeError('guard/consumer process or unreadable same-user PID remains after tests')
        final_status=json.loads(subprocess.check_output([sys.executable,str(GUARD),'status','--json'],cwd=ROOT))
        if final_status['live_guarded_jobs'] or not final_status['heavy_lock_free'] or not final_status['build_lock_free']:
            raise RuntimeError('live guarded job or shared lock remains after tests')
        if sha(GUARD)!=NEW:raise RuntimeError('guard changed during validation')
        for path,pin in PINS:
            if path.read_text().count(f"{pin} = '{NEW}'")!=1:raise RuntimeError('final pin mismatch')
        note=(EVIDENCE/'protocol_note.draft.md').read_text().replace('must all pass on the host without systemd skips before completion.','passed on the host without systemd skips.')
        protocol_after=protocol_before+note.encode();atomic(PROTOCOL,protocol_after)
        with RECOVERY.open('a') as f:f.write('\n\n## Sol S8 installed — '+utc()+'\n\nD44: atomically installed reviewed guard `'+NEW+'` in the coordinator quiet window. Official 45 + S3/FIFO 31 + S8 policy 9 cases and all three consumer suites passed on the host, zero skips. Both static pins updated; FIFO OFF. VM-only memory visibility is documented. Backup/audit: `results/zk60_sol_20261026/guard-s8-backup/` and `guard-s8/`. Coordinator must verify and close the window before new work resumes.\n')
        audit.update(utc_end=utc(),stage='complete',tests=tests,guard_sha256=sha(GUARD),pins={p.name:sha(p) for p,_ in PINS},fifo_on=False,final_status=final_status)
        record(EVIDENCE/'S8_INSTALL.json',audit);(EVIDENCE/'S8_INSTALL.done').write_text('0\n')
        print('S8 SWAPPED '+NEW+'; tests passed without skips; holds retained for coordinator close.',flush=True)
        return 0
    except BaseException as e:
        audit.update(utc_end=utc(),stage='aborted',error=str(e),tests=tests)
        if changed:
            try:rollback(protocol_before,protocol_after);audit['rollback']='complete'
            except Exception as failure:audit['rollback']='FAILED: '+str(failure)
        record(EVIDENCE/'S8_INSTALL.json',audit);(EVIDENCE/'S8_INSTALL.done').write_text('1\n')
        print('S8 ABORTED '+str(e),flush=True);return 1

def main():
    if '--apply' not in sys.argv:
        s=preflight();print(json.dumps({'preflight':'BLOCKED' if s['problems'] else 'READY','problems':s['problems']}));return 0
    with (EVIDENCE/'install.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        return apply()

if __name__=='__main__':
    signal.signal(signal.SIGTERM,lambda signum,frame:(_ for _ in ()).throw(InterruptedError('installation interrupted')))
    sys.exit(main())

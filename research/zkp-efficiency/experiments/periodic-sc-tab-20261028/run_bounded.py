"""Single low-priority core, <=45s experiment, 256MiB AS, 96MiB estimate."""
import datetime,hashlib,json,os,resource,signal,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parent
def limits():
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
    resource.setrlimit(resource.RLIMIT_CPU,(45,45));resource.setrlimit(resource.RLIMIT_AS,(256*1024**2,256*1024**2));signal.alarm(45)
name=sys.argv[1];assert name in ('probe.py','audit.py','artifact_audit.py')
start=time.monotonic()
with (ROOT/(name+'.stdout')).open('w') as out,(ROOT/(name+'.stderr')).open('w') as err:
    r=subprocess.run([sys.executable,'-B',str(ROOT/name)],cwd=ROOT,stdout=out,stderr=err,timeout=50,preexec_fn=limits)
entry={'command':[sys.executable,'-B',str(ROOT/name)],'exit_code':r.returncode,'elapsed_seconds':time.monotonic()-start,'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'entry_sha256':hashlib.sha256((ROOT/name).read_bytes()).hexdigest(),'threads':1,'estimated_memory_mib':96,'address_space_mib':256,'cpu_seconds':45,'alarm_seconds':45,'parent_timeout_seconds':50,'nice':19}
with (ROOT/'commands.jsonl').open('a') as f:f.write(json.dumps(entry)+'\n')
print(json.dumps(entry));print((ROOT/(name+'.stderr')).read_text() if r.returncode else (ROOT/(name+'.stdout')).read_text());sys.exit(r.returncode)

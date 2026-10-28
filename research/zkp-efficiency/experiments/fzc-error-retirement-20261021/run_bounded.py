"""Run one diagnostic at a time on one CPU, below the research resource caps."""
from pathlib import Path
import datetime,json,os,resource,signal,subprocess,sys,time
ROOT=Path(__file__).resolve().parent
def limits():
    os.nice(19)
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    resource.setrlimit(resource.RLIMIT_CPU,(30,30))
    resource.setrlimit(resource.RLIMIT_AS,(256*1024*1024,256*1024*1024))
    signal.alarm(30)
script=sys.argv[1]
assert script in ['probe.py','source_audit.py','artifact_audit.py']
t=time.monotonic()
with (ROOT/(script+'.stdout')).open('w') as out,(ROOT/(script+'.stderr')).open('w') as err:
    r=subprocess.run([sys.executable,str(ROOT/script)],stdout=out,stderr=err,cwd=str(ROOT),preexec_fn=limits,timeout=35,
                     env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1','OMP_NUM_THREADS':'1','OPENBLAS_NUM_THREADS':'1','MKL_NUM_THREADS':'1','RAYON_NUM_THREADS':'1'})
entry={'script':script,'command':[sys.executable,str(ROOT/script)],'exit_code':r.returncode,'elapsed_seconds':time.monotonic()-t,
       'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'limits':'1worker/core,nice19,30sCPU/alarm,35sparent,256MiBAS,estimated32MiB'}
with (ROOT/'commands.jsonl').open('a') as f:f.write(json.dumps(entry)+'\n')
print(json.dumps(entry));sys.exit(r.returncode)

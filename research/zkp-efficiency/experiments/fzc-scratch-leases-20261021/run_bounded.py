"""One child at a time; single CPU, nice19, 59s alarm/CPU, 512MiB AS."""
from pathlib import Path
import datetime,json,os,resource,subprocess,sys,time
ROOT=Path(__file__).resolve().parent
def limits():
    import signal
    os.nice(19)
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    resource.setrlimit(resource.RLIMIT_CPU,(59,59))
    resource.setrlimit(resource.RLIMIT_AS,(512*1024*1024,512*1024*1024))
    signal.alarm(59)
script=sys.argv[1]
assert script in ['probe.py','audit.py','census.py','artifact_audit.py']
t=time.monotonic()
with (ROOT/(script+'.stdout')).open('w') as out,(ROOT/(script+'.stderr')).open('w') as err:
    r=subprocess.run([sys.executable,str(ROOT/script)],stdout=out,stderr=err,
                     cwd=str(ROOT),preexec_fn=limits,timeout=60,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1','OMP_NUM_THREADS':'1','OPENBLAS_NUM_THREADS':'1','MKL_NUM_THREADS':'1','RAYON_NUM_THREADS':'1'})
entry=dict(script=script,command=[sys.executable,str(ROOT/script)],exit_code=r.returncode,
           elapsed_s=time.monotonic()-t,utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
           limits='1worker/core,nice19,59sCPU+alarm,60sparent,512MiBAS;estimated128MiBcensus/64MiBprobe+audit')
with (ROOT/'commands.jsonl').open('a') as f:f.write(json.dumps(entry)+'\n')
print(json.dumps(entry));sys.exit(r.returncode)

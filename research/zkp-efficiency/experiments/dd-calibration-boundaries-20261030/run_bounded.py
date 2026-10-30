"""No build/GPU; each child <=30 CPU seconds,40s alarm,45s parent,256MiB AS."""
import datetime,json,os,resource,signal,subprocess,sys,time,hashlib
from pathlib import Path
E=Path(__file__).resolve().parent
mode=sys.argv[1];assert mode in ('experiment','audit')
def limits():
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
    resource.setrlimit(resource.RLIMIT_CPU,(30,30))
    resource.setrlimit(resource.RLIMIT_AS,(256*1024**2,256*1024**2));signal.alarm(40)
env=dict(os.environ,OMP_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1',MKL_NUM_THREADS='1',RAYON_NUM_THREADS='1',PYTHONDONTWRITEBYTECODE='1')
cmd=[sys.executable,'-B',str(E/(mode+'.py'))];start=time.monotonic()
pins={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in E.glob('*.py')}
with (E/(mode+'.stdout.log')).open('w') as out,(E/(mode+'.stderr.log')).open('w') as err:
    p=subprocess.run(cmd,stdout=out,stderr=err,env=env,preexec_fn=limits,timeout=45)
r=dict(command=cmd,utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),returncode=p.returncode,wall_s=time.monotonic()-start,child_maxrss_kib=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,source_sha256=pins,limits=dict(threads=1,cpu_s=30,wall_alarm_s=40,parent_timeout_s=45,address_space_mib=256,estimated_memory_mib=64))
(E/(mode+'-execution.json')).write_text(json.dumps(r,indent=2)+'\n')
with (E/'commands.jsonl').open('a') as f:f.write(json.dumps(r)+'\n')
print(json.dumps(r));print((E/(mode+'.stdout.log')).read_text());print((E/(mode+'.stderr.log')).read_text());sys.exit(p.returncode)

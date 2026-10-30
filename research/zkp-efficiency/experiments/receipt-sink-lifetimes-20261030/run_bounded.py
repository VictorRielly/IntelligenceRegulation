"""One affinity, low priority, bounded leaf; no native builds or GPU jobs."""
import datetime,json,os,resource,signal,subprocess,sys,time
from pathlib import Path
E=Path(__file__).resolve().parent
which=sys.argv[1]
assert which in ['experiment','audit']
def limits():
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
    resource.setrlimit(resource.RLIMIT_CPU,(30,30));resource.setrlimit(resource.RLIMIT_AS,(256*1024*1024,256*1024*1024));signal.alarm(40)
env=dict(os.environ,OMP_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1',MKL_NUM_THREADS='1',RAYON_NUM_THREADS='1',PYTHONDONTWRITEBYTECODE='1')
started=time.monotonic();cmd=[sys.executable,'-B',str(E/(which+'.py'))]
with (E/(which+'.stdout.log')).open('w') as out,(E/(which+'.stderr.log')).open('w') as err:
    p=subprocess.run(cmd,stdout=out,stderr=err,env=env,preexec_fn=limits,timeout=45)
record=dict(command=cmd,utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),returncode=p.returncode,wall_s=time.monotonic()-started,child_maxrss_kib=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,limits=dict(threads=1,cpu_s=30,alarm_s=40,parent_s=45,address_space_mib=256,estimated_memory_mib=64),device='CPU only, no GPU')
(E/(which+'-execution.json')).write_text(json.dumps(record,indent=2)+'\n')
with (E/'commands.jsonl').open('a') as f:f.write(json.dumps(record)+'\n')
print(json.dumps(record));print((E/(which+'.stdout.log')).read_text());print((E/(which+'.stderr.log')).read_text());sys.exit(p.returncode)

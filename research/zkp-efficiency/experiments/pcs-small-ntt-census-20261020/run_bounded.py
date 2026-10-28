"""One passive parent and one one-thread experiment leaf, <=60s/512MiB."""
from pathlib import Path
import os, sys, json, resource, signal, subprocess, time

HERE=Path(__file__).resolve().parent

def limits():
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
    resource.setrlimit(resource.RLIMIT_CPU,(59,59))
    signal.alarm(59)
    allowed=sorted(os.sched_getaffinity(0))
    os.sched_setaffinity(0,{allowed[0]})
    os.nice(19)

env=os.environ.copy()
for key in ('OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','MKL_NUM_THREADS','NUMEXPR_NUM_THREADS'):
    env[key]='1'
env['PYTHONDONTWRITEBYTECODE']='1'
name=sys.argv[1] if len(sys.argv)>1 else 'probe.py'
assert name in ('probe.py','validate.py')
cmd=[sys.executable,str(HERE/name)]
t=time.monotonic()
with (HERE/(name+'.stdout.log')).open('w') as out,(HERE/(name+'.stderr.log')).open('w') as err:
    p=subprocess.run(cmd,cwd=HERE,env=env,preexec_fn=limits,stdout=out,stderr=err,timeout=60)
record={'argv':cmd,'returncode':p.returncode,'parent_elapsed_s':time.monotonic()-t,
        'limits':{'CPU_s':59,'alarm_s':59,'parent_s':60,'address_space_MiB':512,'threads':1,'nice':19}}
path=HERE/'commands.json'
records=json.loads(path.read_text()) if path.exists() else []
records.append(record);path.write_text(json.dumps(records,indent=2)+'\n')
print(json.dumps(record))
raise SystemExit(p.returncode)

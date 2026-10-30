"""One CPU, <=50 wall seconds, no native build or GPU."""
import json,os,pathlib,resource,signal,subprocess,sys,time
HERE=pathlib.Path(__file__).resolve().parent
assert len(sys.argv)==2 and sys.argv[1] in ('probe.py','audit.py')
def limits():
    os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    resource.setrlimit(resource.RLIMIT_CPU,(40,40))
    resource.setrlimit(resource.RLIMIT_AS,(256*1024**2,256*1024**2));signal.alarm(45)
name=sys.argv[1][:-3];start=time.monotonic()
with (HERE/(name+'.stdout.log')).open('w') as out,(HERE/(name+'.stderr.log')).open('w') as err:
    p=subprocess.run([sys.executable,'-B',str(HERE/sys.argv[1])],cwd=HERE,stdout=out,stderr=err,
        preexec_fn=limits,timeout=50,env={**os.environ,'OMP_NUM_THREADS':'1','OPENBLAS_NUM_THREADS':'1','MKL_NUM_THREADS':'1','RAYON_NUM_THREADS':'1'})
record={'argv':[sys.executable,'-B',str(HERE/sys.argv[1])],'exit_code':p.returncode,'elapsed_s':time.monotonic()-start,
    'threads':1,'cpu_seconds_cap':40,'alarm_s':45,'parent_timeout_s':50,'address_space_cap_bytes':256*1024**2,
    'estimated_memory_bytes':96*1024**2,'native_build':False,'gpu':False}
(HERE/(name+'-execution.json')).write_text(json.dumps(record,indent=2)+'\n');print(json.dumps(record))
print((HERE/(name+'.stdout.log')).read_text()[-1800:])
if p.returncode:print((HERE/(name+'.stderr.log')).read_text())
raise SystemExit(p.returncode)

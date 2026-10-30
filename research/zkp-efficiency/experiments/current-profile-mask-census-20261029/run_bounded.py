"""One CPU, bounded standard-library work; no Cargo, GPU or dependencies."""
import hashlib,json,os,pathlib,resource,signal,subprocess,sys,time
HERE=pathlib.Path(__file__).resolve().parent
stage=sys.argv[1];assert stage in ('prepare','compile','probe','audit','final_audit')
cmd=['/usr/bin/rustc','--edition=2021','-C','opt-level=1','-C','codegen-units=1','-C','debuginfo=0',str(HERE/'metadata.rs'),'-o',str(HERE/'metadata')] if stage=='compile' else [sys.executable,'-B',str(HERE/(stage+'.py'))]
def limits():
 os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
 resource.setrlimit(resource.RLIMIT_CPU,(40,40));resource.setrlimit(resource.RLIMIT_AS,(384*1024**2,384*1024**2));signal.alarm(45)
start=time.monotonic()
with (HERE/(stage+'.stdout.log')).open('w') as out,(HERE/(stage+'.stderr.log')).open('w') as err:
 p=subprocess.run(cmd,cwd=HERE,stdout=out,stderr=err,preexec_fn=limits,timeout=50,env={**os.environ,'OMP_NUM_THREADS':'1','RAYON_NUM_THREADS':'1','OPENBLAS_NUM_THREADS':'1','MKL_NUM_THREADS':'1'})
record=dict(command=cmd,exit_code=p.returncode,elapsed_s=time.monotonic()-start,max_rss_kib=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,threads=1,affinity=[min(os.sched_getaffinity(0))],nice=19,cpu_limit_s=40,alarm_s=45,parent_timeout_s=50,address_space_limit_bytes=384*1024**2,estimated_memory_bytes=(320 if stage=='compile' else 96)*1024**2,gpu=False,cargo=False,compiler_auxiliary_os_threads='not measured; one codegen unit and one CPU affinity')
(HERE/(stage+'-execution.json')).write_text(json.dumps(record,indent=2)+'\n');print(json.dumps(record))
print((HERE/(stage+'.stdout.log')).read_text()[-2000:])
if p.returncode:print((HERE/(stage+'.stderr.log')).read_text())
raise SystemExit(p.returncode)

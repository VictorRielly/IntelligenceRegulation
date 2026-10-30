"""One pinned numeric CPU; each command <=50s wall, <=384 MiB AS."""
import json,os,pathlib,resource,signal,subprocess,sys,time
HERE=pathlib.Path(__file__).resolve().parent
stage=sys.argv[1]; assert stage in ('compile','probe','account','audit')
cmd=({'compile':['/usr/bin/rustc','--edition=2021','-C','opt-level=1','-C','codegen-units=1','-C','debuginfo=0',str(HERE/'harness.rs'),'-o',str(HERE/'probe')], 'probe':[str(HERE/'probe')]}.get(stage) or [sys.executable,'-B',str(HERE/(stage+'.py'))])
def limits():
 os.nice(19); os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
 resource.setrlimit(resource.RLIMIT_CPU,(40,40)); resource.setrlimit(resource.RLIMIT_AS,(384*1024**2,384*1024**2));signal.alarm(45)
start=time.monotonic()
with (HERE/(stage+'.stdout.log')).open('w') as out,(HERE/(stage+'.stderr.log')).open('w') as err:
 p=subprocess.run(cmd,cwd=HERE,stdout=out,stderr=err,preexec_fn=limits,timeout=50,env={**os.environ,'OMP_NUM_THREADS':'1','RAYON_NUM_THREADS':'1','OPENBLAS_NUM_THREADS':'1','MKL_NUM_THREADS':'1'})
record=dict(command=cmd,exit_code=p.returncode,elapsed_s=time.monotonic()-start,max_rss_kib=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,one_cpu_affinity=True,nice=19,cpu_cap_s=40,alarm_s=45,parent_timeout_s=50,address_space_limit_bytes=384*1024**2,estimated_memory_mib=320 if stage=='compile' else 128,gpu=False,cargo=False,compiler_auxiliary_threads='unmeasured; codegen-units1 and one CPU affinity')
(HERE/(stage+'-execution.json')).write_text(json.dumps(record,indent=2)+'\n')
if stage=='probe' and p.returncode==0:(HERE/'result.json').write_text((HERE/'probe.stdout.log').read_text())
print(json.dumps(record));print((HERE/(stage+'.stdout.log')).read_text()[:1800])
if p.returncode: print((HERE/(stage+'.stderr.log')).read_text())
raise SystemExit(p.returncode)

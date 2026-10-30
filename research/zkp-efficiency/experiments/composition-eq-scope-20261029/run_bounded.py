import os,pathlib,sys,subprocess,resource,signal,time,json
D=pathlib.Path(__file__).resolve().parent
stage=sys.argv[1];assert stage in ['prepare','compile','probe','account','audit']
cmd={'compile':['/usr/bin/rustc','--edition=2021','-C','opt-level=1','-C','codegen-units=1','-C','debuginfo=0',str(D/'harness.rs'),'-o',str(D/'probe')],'probe':[str(D/'probe')]}.get(stage,[sys.executable,'-B',str(D/(stage+'.py'))])
def cap():
 os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});resource.setrlimit(resource.RLIMIT_CPU,(40,40));resource.setrlimit(resource.RLIMIT_AS,(384*1024**2,384*1024**2));signal.alarm(45)
t=time.monotonic()
with (D/(stage+'.stdout.log')).open('w') as out,(D/(stage+'.stderr.log')).open('w') as err:
 p=subprocess.run(cmd,cwd=D,stdout=out,stderr=err,preexec_fn=cap,timeout=50,env={**os.environ,'RAYON_NUM_THREADS':'1','OMP_NUM_THREADS':'1','OPENBLAS_NUM_THREADS':'1','MKL_NUM_THREADS':'1'})
r=dict(command=cmd,exit_code=p.returncode,elapsed_s=time.monotonic()-t,max_rss_kib=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,cpu_affinity='one available CPU',nice=19,cpu_cap_s=40,alarm_s=45,parent_timeout_s=50,address_space_bytes=384*1024**2,estimated_memory_mib=320 if stage=='compile' else 96,gpu=False,compiler_auxiliary_threads='not measured; one CPU affinity and codegen-units=1')
(D/(stage+'-execution.json')).write_text(json.dumps(r,indent=2)+'\n')
if stage=='probe' and p.returncode==0:(D/'result.json').write_text((D/'probe.stdout.log').read_text())
print(json.dumps(r));print((D/(stage+'.stdout.log')).read_text()[:5000])
if p.returncode:print((D/(stage+'.stderr.log')).read_text()[-6000:])
raise SystemExit(p.returncode)

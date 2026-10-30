import json, os, pathlib, resource, signal, subprocess, sys, time
D=pathlib.Path(__file__).resolve().parent
stage=sys.argv[1]
commands={
 'prepare':[sys.executable,'-B',str(D/'prepare.py')],
 'compile':['/usr/bin/rustc','--edition=2021','-C','opt-level=2','-C','codegen-units=1',str(D/'census.rs'),'-o',str(D/'census')],
 'audit':[sys.executable,'-B',str(D/'reference.py')],
 'close':[sys.executable,'-B',str(D/'close.py')],
 'final-audit':[sys.executable,'-B',str(D/'final_audit.py')],
}
def caps():
 os.nice(19); os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
 resource.setrlimit(resource.RLIMIT_CPU,(30,30)); resource.setrlimit(resource.RLIMIT_AS,(384*1024**2,384*1024**2)); signal.alarm(40)
t=time.monotonic()
with (D/(stage+'.stdout.log')).open('w') as out, (D/(stage+'.stderr.log')).open('w') as err:
 p=subprocess.run(commands[stage],cwd=D,stdout=out,stderr=err,timeout=45,preexec_fn=caps,env={**os.environ,'OMP_NUM_THREADS':'1','RAYON_NUM_THREADS':'1','OPENBLAS_NUM_THREADS':'1','MKL_NUM_THREADS':'1'})
record=dict(stage=stage,command=commands[stage],exit_code=p.returncode,wall_s=time.monotonic()-t,max_rss_kib=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,cpu_affinity_count=1,nice=19,cpu_limit_s=30,alarm_s=40,parent_timeout_s=45,address_space_mib=384,estimated_memory_mib=300 if stage=='compile' else 64,gpu=False)
(D/(stage+'-execution.json')).write_text(json.dumps(record,indent=2)+'\n')
with (D/'commands.jsonl').open('a') as f:f.write(json.dumps(record)+'\n')
print(json.dumps(record)); print((D/(stage+('.stderr.log' if p.returncode else '.stdout.log'))).read_text()[-2500:])
raise SystemExit(p.returncode)

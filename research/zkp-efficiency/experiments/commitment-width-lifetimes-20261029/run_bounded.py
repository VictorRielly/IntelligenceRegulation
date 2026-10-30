"""Single-thread std-only component compile/run; no Cargo/dependencies/GPU."""
import hashlib, json, os, pathlib, resource, signal, subprocess, sys, time
HERE=pathlib.Path(__file__).resolve().parent
stage=sys.argv[1]
assert stage in ('compile','probe','audit','final_audit')
if stage=='compile': cmd=['/usr/bin/rustc','--edition=2021','-C','opt-level=1','-C','codegen-units=1','-C','debuginfo=0',str(HERE/'harness.rs'),'-o',str(HERE/'probe')]
elif stage=='probe': cmd=[str(HERE/'probe')]
else: cmd=[sys.executable,'-B',str(HERE/(stage+'.py'))]
def limits():
 os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
 resource.setrlimit(resource.RLIMIT_CPU,(40,40))
 resource.setrlimit(resource.RLIMIT_AS,(384*1024**2,384*1024**2));signal.alarm(45)
start=time.monotonic()
inputs={str(p.relative_to(HERE)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(HERE.rglob('*.rs')) if 'initial-' not in str(p)} if stage=='compile' else {}
with (HERE/(stage+'.stdout.log')).open('w') as out,(HERE/(stage+'.stderr.log')).open('w') as err:
 p=subprocess.run(cmd,cwd=HERE,stdout=out,stderr=err,preexec_fn=limits,timeout=50,env={**os.environ,'OMP_NUM_THREADS':'1','RAYON_NUM_THREADS':'1','OPENBLAS_NUM_THREADS':'1','MKL_NUM_THREADS':'1'})
r={'stage':stage,'command':cmd,'exit_code':p.returncode,'elapsed_s':time.monotonic()-start,'max_rss_kib':resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,'threads':1,'nice':19,'affinity':[min(os.sched_getaffinity(0))],'cpu_cap_s':40,'alarm_s':45,'parent_timeout_s':50,'address_space_cap_bytes':384*1024**2,'estimated_memory_bytes':320*1024**2 if stage=='compile' else 64*1024**2,'cargo':False,'gpu':False,'rust_source_sha256':inputs,'binary_sha256':hashlib.sha256((HERE/'probe').read_bytes()).hexdigest() if (HERE/'probe').exists() else None}
r['thread_limit_kind']='Single-thread harness; compiler one codegen unit and one-CPU affinity. Auxiliary OS thread count not measured.'
(HERE/(stage+'-execution.json')).write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r));print((HERE/(stage+'.stdout.log')).read_text()[-4000:])
if p.returncode:print((HERE/(stage+'.stderr.log')).read_text())
if stage=='probe' and not p.returncode:
 result=json.loads((HERE/(stage+'.stdout.log')).read_text());result['max_rss_kib']=r['max_rss_kib'];(HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
raise SystemExit(p.returncode)

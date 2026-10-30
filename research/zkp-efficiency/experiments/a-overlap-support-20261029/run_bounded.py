import os, pathlib, resource, signal, subprocess, sys, time, json
D = pathlib.Path(__file__).resolve().parent
stage = sys.argv[1]
assert stage in ('prepare', 'make_cases', 'compile', 'probe', 'census', 'cost', 'audit')
cmd = {'compile': ['/usr/bin/rustc', '--edition=2021', '-C', 'opt-level=1', '-C', 'codegen-units=1', str(D/'harness.rs'), '-o', str(D/'probe')], 'probe': [str(D/'probe')]}.get(stage, [sys.executable, '-B', str(D/(stage+'.py'))])
def cap():
    os.nice(19)
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    resource.setrlimit(resource.RLIMIT_CPU, (40,40))
    resource.setrlimit(resource.RLIMIT_AS, (384*1024**2,384*1024**2))
    signal.alarm(45)
t = time.monotonic()
with (D/(stage+'.stdout.log')).open('w') as out, (D/(stage+'.stderr.log')).open('w') as err:
    p = subprocess.run(cmd, cwd=D, stdout=out, stderr=err, preexec_fn=cap, timeout=50, env={**os.environ, 'RAYON_NUM_THREADS':'1','OMP_NUM_THREADS':'1','OPENBLAS_NUM_THREADS':'1','MKL_NUM_THREADS':'1'})
r = dict(command=cmd, exit_code=p.returncode, wall_s=time.monotonic()-t, max_rss_kib=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss, one_cpu_affinity=True, nice=19, cpu_limit_s=40, alarm_s=45, parent_timeout_s=50, address_space_mib=384, estimated_memory_mib=300 if stage=='compile' else 96, gpu=False)
(D/(stage+'-execution.json')).write_text(json.dumps(r,indent=2)+'\n')
print(json.dumps(r));
if stage!='probe': print((D/(stage+'.stdout.log')).read_text()[:5000])
else:
 data=json.loads((D/(stage+'.stdout.log')).read_text()) if p.returncode==0 else {}
 print(json.dumps({k:v for k,v in data.items() if k!='profiles'}))
if p.returncode: print((D/(stage+'.stderr.log')).read_text()[-4500:])
if stage=='probe' and p.returncode==0: (D/'result.json').write_text((D/(stage+'.stdout.log')).read_text())
raise SystemExit(p.returncode)

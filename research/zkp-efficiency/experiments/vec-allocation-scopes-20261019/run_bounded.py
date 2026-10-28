"""All experiment leaves: single CPU affinity, nice19,59s CPU/wall,512MiB AS."""
import datetime, hashlib, json, os, resource, signal, subprocess, sys, time
from pathlib import Path
HERE=Path(__file__).resolve().parent
RUSTC='/home/victor/.rustup/toolchains/1.90.0-x86_64-unknown-linux-gnu/bin/rustc'
name=sys.argv[1]
if name in ['compile0','compile3']:
    opt=name[-1]
    source=HERE/'probe.rs'
    argv=[RUSTC,'--edition=2021','-C','opt-level='+opt,'-C','codegen-units=1',str(source),'-o',str(HERE/('probe-o'+opt))]
elif name in ['probe0','probe3']:
    opt=name[-1]
    source=HERE/'probe.rs'
    outdir=HERE/('outputs-o'+opt)
    outdir.mkdir(exist_ok=True)
    argv=[str(HERE/('probe-o'+opt)),str(outdir),'2026101991']
elif name in ['audit.py','validate.py']:
    source=HERE/name
    argv=['python3','-B',str(source)]
else:
    raise ValueError(name)
def limit():
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2)
    resource.setrlimit(resource.RLIMIT_CPU,(59,59))
    signal.alarm(59)
    os.nice(19)
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
p=HERE/'commands.json'
rows=json.loads(p.read_text()) if p.exists() else []
i=len(rows)
started=datetime.datetime.now(datetime.timezone.utc).isoformat()
t=time.perf_counter()
r=subprocess.run(argv,preexec_fn=limit,capture_output=True,text=True,timeout=60)
wall=time.perf_counter()-t
out=f'{i:02d}-{name}.stdout.log';err=f'{i:02d}-{name}.stderr.log'
(HERE/out).write_text(r.stdout);(HERE/err).write_text(r.stderr)
row=dict(name=name,argv=argv,started_at=started,exit_code=r.returncode,wall_seconds=wall,
         child_maxrss_kib=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,
         source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),stdout=out,stderr=err,
         limits=dict(single_cpu_affinity=True,nice=19,cpu_seconds=59,wall_alarm_seconds=59,
                     address_space_bytes=512*1024**2,compiler_codegen_units=1,
                     compiler_helper_thread_count='not observed; one CPU affinity'))
if name.startswith('probe'):
    row['binary_sha256']=hashlib.sha256(Path(argv[0]).read_bytes()).hexdigest()
rows.append(row)
p.write_text(json.dumps(rows,indent=2)+'\n')
print(json.dumps({k:row[k] for k in ['name','exit_code','wall_seconds','child_maxrss_kib','stdout','stderr']}))
if r.returncode: print(r.stderr[:3000],file=sys.stderr)
sys.exit(r.returncode)

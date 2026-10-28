"""One low-priority CPU, <=59s leaf, <=512MiB AS. No external code executed."""
import datetime,hashlib,json,os,resource,signal,subprocess,sys,time
from pathlib import Path
HERE=Path(__file__).resolve().parent
rustc='/home/victor/.rustup/toolchains/1.90.0-x86_64-unknown-linux-gnu/bin/rustc'
name=sys.argv[1]
if name=='compile':
    argv=[rustc,'--edition=2021','-C','opt-level=1','-C','codegen-units=1',str(HERE/'drop_probe.rs'),'-o',str(HERE/'drop_probe')]
    source=HERE/'drop_probe.rs'
elif name=='probe': argv=[str(HERE/'drop_probe')];source=HERE/'drop_probe.rs'
else:
    assert name in ['experiment.py','audit.py','validate.py']
    argv=['python3','-B',str(HERE/name)];source=HERE/name
def limit():
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2)
    resource.setrlimit(resource.RLIMIT_CPU,(59,59))
    signal.alarm(59)
    os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
p=HERE/'commands.json';rows=json.loads(p.read_text()) if p.exists() else []
i=len(rows);start=datetime.datetime.now(datetime.timezone.utc).isoformat();t=time.perf_counter()
r=subprocess.run(argv,preexec_fn=limit,capture_output=True,text=True,timeout=60)
out=f'{i:02d}-{name}.stdout.log';err=f'{i:02d}-{name}.stderr.log'
(HERE/out).write_text(r.stdout);(HERE/err).write_text(r.stderr)
rows.append(dict(argv=argv,started=start,wall_seconds=time.perf_counter()-t,exit_code=r.returncode,
 source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),stdout=out,stderr=err,
 limits=dict(single_cpu_affinity=True,python_and_probe_threads=1,compiler_codegen_units=1,
 compiler_internal_thread_count='not observed',cpu_seconds=59,wall_alarm_seconds=59,address_space_bytes=512*1024**2,nice=19)))
p.write_text(json.dumps(rows,indent=2)+'\n')
print(r.stdout,end='');print(r.stderr,end='',file=sys.stderr);sys.exit(r.returncode)

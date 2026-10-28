"""One-thread authored Python leaves; no native builds, dependencies or GPU."""
import datetime, hashlib, json, os, pathlib, resource, signal, subprocess, sys, time
HERE=pathlib.Path(__file__).resolve().parent
name=sys.argv[1]
assert name in ['capacity_model.py','audit.py','validate.py']
source=HERE/name
argv=['python3','-B',str(source)]
def limits():
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2)
    resource.setrlimit(resource.RLIMIT_CPU,(59,59))
    signal.alarm(59)
    os.nice(19)
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
started=datetime.datetime.now(datetime.timezone.utc).isoformat(); t=time.perf_counter()
r=subprocess.run(argv,capture_output=True,text=True,preexec_fn=limits,timeout=60)
cmds=HERE/'commands.json'; rows=json.loads(cmds.read_text()) if cmds.exists() else []
stem=f'{len(rows):02d}-{name}'
(HERE/(stem+'.stdout.log')).write_text(r.stdout)
(HERE/(stem+'.stderr.log')).write_text(r.stderr)
row=dict(argv=argv,started_at=started,exit_code=r.returncode,wall_seconds=time.perf_counter()-t,
         maxrss_kib=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,
         source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),stdout=stem+'.stdout.log',stderr=stem+'.stderr.log',
         limits=dict(cpu_seconds=59,wall_alarm_seconds=59,address_space_bytes=512*1024**2,threads=1,single_cpu_affinity=True,nice=19))
rows.append(row);cmds.write_text(json.dumps(rows,indent=2)+'\n');print(json.dumps(row))
if r.returncode: print(r.stderr[:5000],file=sys.stderr)
sys.exit(r.returncode)

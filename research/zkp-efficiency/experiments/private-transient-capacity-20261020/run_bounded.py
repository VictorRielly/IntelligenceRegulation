"""One CPU, one authored leaf, <=59 s CPU/wall and 512 MiB address space."""
import datetime,hashlib,json,os,pathlib,resource,signal,subprocess,sys,time
H=pathlib.Path(__file__).resolve().parent
name=sys.argv[1]
assert name in ['model.py','audit.py','layout_probe.py','validate.py']
def limits():
 resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2)
 resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
 os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
t=time.perf_counter(); start=datetime.datetime.now(datetime.timezone.utc).isoformat()
r=subprocess.run(['python3','-B',str(H/name)],capture_output=True,text=True,timeout=60,preexec_fn=limits)
p=H/'commands.json'; rows=json.loads(p.read_text()) if p.exists() else []
stem=f'{len(rows):02d}-{name}'
(H/(stem+'.stdout.log')).write_text(r.stdout);(H/(stem+'.stderr.log')).write_text(r.stderr)
row=dict(leaf=name,started_at=start,exit_code=r.returncode,wall_seconds=time.perf_counter()-t,maxrss_kib=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,sha256=hashlib.sha256((H/name).read_bytes()).hexdigest(),stdout=stem+'.stdout.log',stderr=stem+'.stderr.log',limits=dict(cpu_s=59,alarm_s=59,address_space_bytes=512*1024**2,threads=1,nice=19))
rows.append(row);p.write_text(json.dumps(rows,indent=2)+'\n');print(json.dumps(row))
print(r.stdout[:2400]);print(r.stderr[:2400] if r.returncode else '',end='')
sys.exit(r.returncode)

"""Retain exact command/log/exit status; no shell invocation."""
from pathlib import Path
import datetime,json,os,resource,signal,subprocess,sys,time
H=Path(__file__).resolve().parent
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
resource.setrlimit(resource.RLIMIT_AS,(512*2**20,512*2**20));resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
name=sys.argv[1];assert name in ['run.py','audit.py','account.py']
argv=['python3',str(H/name)];start=time.perf_counter();begin=datetime.datetime.now(datetime.timezone.utc).isoformat()
p=subprocess.run(argv,cwd=H,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=58)
(H/(name.removesuffix('.py')+'.log')).write_text(p.stdout)
path=H/'commands.json';data=json.loads(path.read_text())if path.exists()else[]
data.append(dict(argv=argv,cwd=str(H),exit_code=p.returncode,elapsed_s=time.perf_counter()-start,started_at_utc=begin,log=name.removesuffix('.py')+'.log',threads=1,cpu_affinity=list(os.sched_getaffinity(0)),niceness_inherited_and_increased_by_child=True,memory_cap_mib=512,wall_cap_s=58))
path.write_text(json.dumps(data,indent=2)+'\n');print(p.stdout);sys.exit(p.returncode)

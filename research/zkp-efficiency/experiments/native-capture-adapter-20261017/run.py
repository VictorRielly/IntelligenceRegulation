"""Retain source hashes, command, bounded subprocess, log and exit status."""
import datetime,hashlib,json,pathlib,subprocess,sys,time
here=pathlib.Path(__file__).resolve().parent
command=[sys.executable,'-B',str(here/'experiment.py')]
record={'argv':command,'cwd':str(here.parents[1]),'start_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'timeout_seconds':60,'source_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(here.glob('*.py'))}}
(here/'command.json').write_text(json.dumps(record,indent=2)+'\n');start=time.perf_counter()
with (here/'run.log').open('w') as log:
    try:code=subprocess.run(command,cwd=here.parents[1],stdout=log,stderr=subprocess.STDOUT,timeout=60).returncode
    except subprocess.TimeoutExpired:code=124
r={'exit_code':code,'wrapper_wall_seconds':time.perf_counter()-start,'end_utc':datetime.datetime.now(datetime.timezone.utc).isoformat()}
(here/'execution.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r));print((here/'run.log').read_text()[-6200:]);sys.exit(code)

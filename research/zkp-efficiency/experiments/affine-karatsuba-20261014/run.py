"""One bounded process, retained command, source hashes, log and actual exit."""
import datetime,hashlib,json,pathlib,subprocess,sys,time
here=pathlib.Path(__file__).resolve().parent
command=[sys.executable,'-B',str(here/'experiment.py')]
start=time.perf_counter()
record=dict(argv=command,cwd=str(here.parents[1]),start_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
    timeout_seconds=60,source_sha256={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(here.glob('*.py'))})
(here/'command.json').write_text(json.dumps(record,indent=2)+'\n')
with (here/'run.log').open('w') as log:
    try:
        p=subprocess.run(command,cwd=here.parents[1],stdout=log,stderr=subprocess.STDOUT,timeout=60)
        code=p.returncode
    except subprocess.TimeoutExpired:code=124
record=dict(exit_code=code,wrapper_wall_seconds=time.perf_counter()-start,end_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
(here/'execution.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(record))
print((here/'run.log').read_text()[-13000:])
sys.exit(code)

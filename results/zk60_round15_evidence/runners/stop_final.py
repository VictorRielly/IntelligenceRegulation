import json,os,signal,time
from pathlib import Path
pid=int(Path('/tmp/zk60-round15/worker_final.pid').read_text())
cmd=Path(f'/proc/{pid}/cmdline').read_bytes()
assert b'/tmp/zk60-round15/validate_final.py' in cmd, cmd
assert os.getpgid(pid)==pid
os.killpg(pid,signal.SIGTERM)
p=Path('/tmp/zk60-round15/final/summary.json')
r=json.loads(p.read_text())
r.update(exit_code=143, validation_status='interrupted', error='Stopped by Codex before proof cases: storage-feature tests share the CPU binary target and may overwrite its recorded artifact. Isolate the storage target before the final floors run.')
p.write_text(json.dumps(r,indent=2)+'\n')
Path('/tmp/zk60-round15/final/validation.done').write_text('143\n')
print('Stopped owned validation process group',pid,'and recorded exit 143; completed stage logs retained.')

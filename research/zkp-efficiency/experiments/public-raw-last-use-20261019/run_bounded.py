"""Run ONLY the local authored experiments; retain exit codes and both streams."""
import datetime
import hashlib
import json
from pathlib import Path
import subprocess
import sys

here=Path(__file__).resolve().parent
name=sys.argv[1]
assert name in ['experiment.py','audit.py','validate.py']
argv=['python3','-B',str(here/name)]
p=here/'commands.json'
rows=json.loads(p.read_text()) if p.exists() else []
index=len(rows)
started=datetime.datetime.now(datetime.timezone.utc).isoformat()
r=subprocess.run(argv,capture_output=True,text=True,timeout=60)
outname=f'{index:02d}-{name}.stdout.log'
errname=f'{index:02d}-{name}.stderr.log'
(here/outname).write_text(r.stdout)
(here/errname).write_text(r.stderr)
rows.append(dict(argv=argv,started=started,exit_code=r.returncode,source_sha256=hashlib.sha256((here/name).read_bytes()).hexdigest(),stdout=outname,stderr=errname))
p.write_text(json.dumps(rows,indent=2)+'\n')
print(r.stdout,end='')
print(r.stderr,end='',file=sys.stderr)
sys.exit(r.returncode)

import subprocess
from pathlib import Path
base=Path('/tmp/zk60-round14/core-review')
with (base/'runner.log').open('w') as log:
 p=subprocess.Popen(['python3',str(base/'run.py')],stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
print('Detached committed-source review probes PID',p.pid)

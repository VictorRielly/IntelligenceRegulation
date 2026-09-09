import subprocess
from pathlib import Path
out=Path('/tmp/zk60-round15')
with (out/'launcher.log').open('ab', buffering=0) as log:
    p=subprocess.Popen(['python3', str(out/'validate.py')], stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT, start_new_session=True, close_fds=True)
(out/'worker.pid').write_text(str(p.pid)+'\n')
print('Detached validation PID',p.pid,'log',out/'launcher.log','marker',out/'complete/validation.done')

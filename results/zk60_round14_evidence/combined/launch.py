import subprocess
from pathlib import Path
out = Path('/tmp/zk60-round14/complete')
with (out / 'runner.log').open('wb') as log:
    child = subprocess.Popen(['python3', str(out / 'validate.py')], stdin=subprocess.DEVNULL,
                             stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
(out / 'runner.pid').write_text(str(child.pid) + '\n')
print('Detached round14 validator PID', child.pid)

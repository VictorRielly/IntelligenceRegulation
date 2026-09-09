import hashlib
import json
import os
from pathlib import Path
import resource
import subprocess
import time

root = Path('/home/victor/IntelligenceRegulation')
out = Path('/tmp/zk60-round14')
env = {k: v for k, v in os.environ.items() if not k.startswith('HL_')}
env.update(CARGO_BUILD_JOBS='2', RAYON_NUM_THREADS='2', ZK_THREADS='2')
def cap(): resource.setrlimit(resource.RLIMIT_AS, (8 << 30, 8 << 30))
cmd = ['python3', '-m', 'unittest', 'discover', '-s', 'tests', '-p', 'test_hashline_cl_*.py', '-v']
start = time.monotonic()
with (out / 'python_consumers.log').open('w') as log:
    r = subprocess.run(['/usr/bin/time', '-v', '-o', str(out / 'python_consumers.time')] + cmd,
                       cwd=root, env=env, stdout=log, stderr=subprocess.STDOUT,
                       timeout=240, preexec_fn=cap)
record = {'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
          'command': cmd, 'exit_code': r.returncode, 'elapsed_s': time.monotonic() - start,
          'log_sha256': hashlib.sha256((out / 'python_consumers.log').read_bytes()).hexdigest(),
          'scope': 'Six CPU-only GPU/tooling consumer test modules; no hardware job or native full-suite run'}
(out / 'python_consumers.json').write_text(json.dumps(record, indent=2) + '\n')
(out / 'python_consumers.done').write_text(str(r.returncode) + '\n')
print(json.dumps(record, indent=2))
print((out / 'python_consumers.log').read_text()[-600:])
raise SystemExit(r.returncode)

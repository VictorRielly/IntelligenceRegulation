import json
import os
import resource
import signal
import subprocess
import sys
import time
from pathlib import Path

D = Path(__file__).resolve().parent
stage = sys.argv[1]
assert stage in ('experiment', 'audit')


def caps():
    os.nice(19)
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    resource.setrlimit(resource.RLIMIT_CPU, (30, 30))
    resource.setrlimit(resource.RLIMIT_AS, (256*1024**2, 256*1024**2))
    signal.alarm(40)


argv = [sys.executable, '-B', str(D / (stage + '.py'))]
t = time.monotonic()
with (D/(stage+'.stdout.log')).open('w') as out, (D/(stage+'.stderr.log')).open('w') as err:
    p = subprocess.run(argv, cwd=D, stdout=out, stderr=err, timeout=45, preexec_fn=caps,
                       env={**os.environ, 'OMP_NUM_THREADS':'1', 'OPENBLAS_NUM_THREADS':'1', 'RAYON_NUM_THREADS':'1', 'PYTHONDONTWRITEBYTECODE':'1'})
record = dict(stage=stage, command=argv, exit_code=p.returncode, wall_s=time.monotonic()-t,
              max_rss_kib=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,
              cpu_limit_s=30, alarm_s=40, parent_timeout_s=45, address_space_mib=256,
              estimated_memory_mib=64, cpu_affinity_count=1, nice=19, gpu=False)
(D/(stage+'-execution.json')).write_text(json.dumps(record,indent=2)+'\n')
with (D/'commands.jsonl').open('a') as f:
    f.write(json.dumps(record)+'\n')
print(json.dumps(record))
print((D/(stage+'.stdout.log')).read_text()[-3000:])
if p.returncode:
    print((D/(stage+'.stderr.log')).read_text()[-4000:])
raise SystemExit(p.returncode)

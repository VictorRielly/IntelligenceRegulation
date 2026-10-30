"""One low-priority CPU, hard time/memory bounds; only local authored scripts."""
import json
import os
from pathlib import Path
import resource
import signal
import subprocess
import sys
from time import perf_counter

HERE = Path(__file__).resolve().parent
script = sys.argv[1]
if script not in ('experiment.py', 'audit.py', 'pair_table_recurrence.py'):
    raise SystemExit('only named local experiments permitted')


def bounds():
    os.nice(19)
    allowed = os.sched_getaffinity(0)
    os.sched_setaffinity(0, {min(allowed)})
    resource.setrlimit(resource.RLIMIT_AS, (256*1024**2, 256*1024**2))
    resource.setrlimit(resource.RLIMIT_CPU, (40, 42))
    signal.alarm(45)


started = perf_counter()
with (HERE/(script+'.stdout.log')).open('w') as out, (HERE/(script+'.stderr.log')).open('w') as err:
    proc = subprocess.run([sys.executable, '-B', str(HERE/script)], cwd=HERE,
                          stdout=out, stderr=err, preexec_fn=bounds, timeout=50)
usage = resource.getrusage(resource.RUSAGE_CHILDREN)
record = {'command': [sys.executable, '-B', str(HERE/script)], 'exit_code': proc.returncode,
          'wall_s': perf_counter()-started, 'peak_rss_kib': usage.ru_maxrss,
          'one_cpu_affinity': True, 'nice': 19, 'address_space_cap_mib': 256,
          'cpu_soft_hard_s': [40, 42], 'alarm_s': 45, 'parent_timeout_s': 50,
          'memory_estimate_mib': 64, 'scope': 'CPU arithmetic, not native proving'}
(HERE/(script+'.execution.json')).write_text(json.dumps(record, indent=2)+'\n')
print(json.dumps(record))
raise SystemExit(proc.returncode)

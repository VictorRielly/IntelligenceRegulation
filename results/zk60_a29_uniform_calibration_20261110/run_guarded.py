#!/usr/bin/env python3
"""Lane A29: run one command under the zk60 resource guard, detached from this session
(macOS has no setsid / flock; `start_new_session` survives the session). Returns at once;
the guard writes <done> (the exit code) and <done>.json (its terminal record) when the job
ends. The guard's own floors apply. Eight BLAS threads, as Astra's evaluation leaves.

usage: run_guarded.py <class> <need_gib> <cap_gib> <max_secs> <label> <logfile> <donefile> <cmd...>
"""
import os
import subprocess
import sys

cls, need, cap, max_secs, label, log, done = sys.argv[1:8]
cmd = sys.argv[8:]
for stale in (done, done + '.json'):
    if os.path.exists(stale):
        os.remove(stale)
env_cmd = ['/usr/bin/env', 'OPENBLAS_NUM_THREADS=8', 'OMP_NUM_THREADS=8', 'VECLIB_MAXIMUM_THREADS=8',
           'PYTHONDONTWRITEBYTECODE=1'] + cmd
guard = ['python3', '/Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py', 'run',
         '--class', cls, '--need-gib', need, '--cap-gib', cap, '--max-secs', max_secs,
         '--wait-secs', '14400', '--label', label, '--log', log, '--done', done,
         '--result-json', done + '.json', '--'] + env_cmd
p = subprocess.Popen(guard, stdin=subprocess.DEVNULL, stdout=open(log + '.guard', 'w'),
                     stderr=subprocess.STDOUT, start_new_session=True)
print('started', p.pid, flush=True)

#!/usr/bin/env python3
"""Host-side durable launch; reuse a live acceptance worker rather than duplicate it."""
import datetime
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys

OUT = Path(__file__).resolve().parent
WORKER = OUT / 'accept_r12.py'
with (OUT / 'launch.lock').open('a') as lock:
    fcntl.flock(lock, fcntl.LOCK_EX)
    found = []
    for proc in Path('/proc').iterdir():
        if not proc.name.isdecimal():
            continue
        try:
            argv = (proc / 'cmdline').read_bytes().split(b'\0')
            if len(argv) > 1 and os.fsencode(WORKER) in argv and b'python' in argv[0]:
                found.append(int(proc.name))
        except (FileNotFoundError, PermissionError, ProcessLookupError):
            continue
    if found:
        print(json.dumps({'live_acceptance_pids': found, 'action': 'reuse; no new worker',
                          'processes': {pid: (Path('/proc') / str(pid) / 'stat').read_text() for pid in found}}))
    elif (OUT / 'acceptance.done').exists():
        print(json.dumps({'terminal': (OUT / 'acceptance.done').read_text().strip(), 'action': 'inspect before any retry'}))
    elif '--status-only' in sys.argv or (OUT / 'acceptance.host-launch.json').exists():
        print(json.dumps({'live_acceptance_pids': [], 'action': 'worker absent; inspect interruption before any retry'}))
    else:
        log = (OUT / 'acceptance.log').open('ab', buffering=0)
        child = subprocess.Popen(['python3', '-u', str(WORKER)], cwd=OUT.parents[1],
                                 stdin=subprocess.DEVNULL, stdout=log,
                                 stderr=subprocess.STDOUT, start_new_session=True)
        proc = Path('/proc') / str(child.pid)
        record = {'pid': child.pid, 'written_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                  'pid_ns': os.readlink(proc / 'ns/pid'),
                  'starttime_ticks': int((proc / 'stat').read_text().rsplit(')', 1)[1].split()[19]),
                  'boot_id': Path('/proc/sys/kernel/random/boot_id').read_text().strip(),
                  'command': child.args}
        (OUT / 'acceptance.host-launch.json').write_text(json.dumps(record, indent=2) + '\n')
        print(json.dumps(record))

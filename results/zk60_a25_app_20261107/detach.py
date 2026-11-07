#!/usr/bin/env python3
"""Lane A25: run a command detached from this session (macOS: no setsid; start_new_session),
its output appended to <log>. usage: detach.py <log> <cmd...>"""
import subprocess
import sys

log = sys.argv[1]
p = subprocess.Popen(sys.argv[2:], stdin=subprocess.DEVNULL, stdout=open(log, 'a'), stderr=subprocess.STDOUT,
                     start_new_session=True)
print('detached', p.pid, flush=True)

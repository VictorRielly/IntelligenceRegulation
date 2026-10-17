#!/usr/bin/env python3
"""Stop only our attempt-3 debug library child; retain its runner's report."""
import json
import os
from pathlib import Path
import signal

base = Path('/home/victor/IntelligenceRegulation/results/zk60_sol_gpu_20260927/attempt-3-legacy')
pins = json.loads((base / 'pins.json').read_text())
binary = str(Path('/tmp/zk60-sol-gpu-20260927') / pins['binaries']['lib'])
runner = str(base / 'run_legacy.py')


def argv(pid):
    return (Path('/proc') / str(pid) / 'cmdline').read_bytes().rstrip(b'\0').decode().split('\0')


matches = []
for proc in Path('/proc').iterdir():
    if not proc.name.isdigit():
        continue
    try:
        args = argv(proc.name)
        if args != [binary, '--test-threads=1', '--nocapture']:
            continue
        fields = dict(line.split(':', 1) for line in (proc / 'status').read_text().splitlines() if ':' in line)
        parent = argv(int(fields['PPid']))
        if len(parent) == 2 and parent[1] == runner:
            matches.append(int(proc.name))
    except (OSError, ValueError, UnicodeError):
        continue
if len(matches) != 1:
    raise SystemExit(f'Refusing signal: expected one exact library child, found {len(matches)}')
pid = matches[0]
# Recheck the exact child command immediately before signalling.
assert argv(pid) == [binary, '--test-threads=1', '--nocapture']
os.kill(pid, signal.SIGTERM)
print(f'Sent SIGTERM to only attempt-3 debug library child {pid}; runner records interruption.')

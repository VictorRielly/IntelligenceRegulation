#!/usr/bin/env python3
"""Bounded continuation of the already queued validation; never duplicate it.

Run in a yielded execution session. This is not a restart-persistent service.
The benchmark itself owns the heavy lock and checks source/binary pins.
"""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
STATUS = HERE / 'continuation.json'
MARKER = HERE / 'validation-1/run.done'
STATE = {'state': 'waiting-for-validation', 'started_unix': time.time(),
         'runner_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
         'no_restart_persistence_claim': True}


def save():
    STATUS.write_text(json.dumps(STATE, indent=2) + '\n')


try:
    save()
    print('Waiting for the existing native validation; no duplicate validation launched', flush=True)
    deadline = time.monotonic() + 3600
    while not MARKER.exists():
        if time.monotonic() >= deadline:
            raise TimeoutError('Validation has not completed within one hour; inspect its existing session/lock')
        time.sleep(5)
    if MARKER.read_text().strip() != '0':
        raise RuntimeError('Validation failed; benchmark refused')
    validation = HERE / 'validation-1/validation.json'
    assert json.loads(validation.read_text())['state'] == 'passed'
    STATE.update(state='benchmark-running', validation_sha256=hashlib.sha256(validation.read_bytes()).hexdigest())
    save()
    code = subprocess.call([sys.executable, str(HERE / 'benchmark.py')])
    if code:
        raise RuntimeError(f'Benchmark exit {code}; retain its failure record')
    STATE.update(state='passed', finished_unix=time.time())
    save()
except BaseException as exc:
    STATE.update(state='failed', error=str(exc), finished_unix=time.time())
    save()
    raise

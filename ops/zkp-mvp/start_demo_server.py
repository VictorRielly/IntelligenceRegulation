#!/usr/bin/env python3
"""Restore the tested localhost demo, detached, without duplicate servers."""
import fcntl
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import time
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from scripts.zk60_guarded_command import atomic_json

RUNTIME = ROOT / 'results/zk60_crash_recovery_20260930/demo/server-runtime'
CONTROL = RUNTIME / 'server.json'
URL = 'http://127.0.0.1:8765'


def identity(pid):
    raw = Path(f'/proc/{pid}/stat').read_text()
    fields = raw[raw.rindex(')') + 2:].split()
    if fields[0] == 'Z':
        raise ProcessLookupError('server has exited')
    return {'pid': pid, 'start_ticks': int(fields[19]),
            'pid_namespace': os.readlink(f'/proc/{pid}/ns/pid'),
            'boot_id': Path('/proc/sys/kernel/random/boot_id').read_text().strip()}


def health():
    with urlopen(URL + '/api/status', timeout=1) as response:
        value = json.loads(response.read(4096))
        return response.status == 200 and isinstance(value.get('token'), str)


def main():
    RUNTIME.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (RUNTIME / 'launcher.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        previous = None
        if CONTROL.exists():
            previous = json.loads(CONTROL.read_text())
            try:
                if identity(previous['process']['pid']) == previous['process']:
                    if not health():
                        raise RuntimeError('recorded live server is not healthy; no duplicate launched')
                    print(json.dumps({'state': 'already-running', 'url': URL, 'process': previous['process']}))
                    return 0
            except (OSError, KeyError):
                # A missing/reused PID in this host namespace is authoritative.
                pass
        # An unknown listener is not an authorization to replace its process.
        with socket.socket() as probe:
            probe.settimeout(1)
            if probe.connect_ex(('127.0.0.1', 8765)) == 0:
                raise RuntimeError('port 8765 already has a listener; no duplicate launched')
        attempt = RUNTIME / ('start-' + str(time.time_ns()))
        attempt.mkdir(mode=0o700)
        if previous is not None:
            atomic_json(attempt / 'previous-record.json', previous)
        command = [sys.executable, str(ROOT / 'scripts/zk60_techweek_server.py'),
                   '--port', '8765', '--output', str(ROOT / 'results/zk60_techweek_demo')]
        with (attempt / 'server.log').open('xb') as log:
            child = subprocess.Popen(command, cwd=ROOT, stdin=subprocess.DEVNULL,
                                     stdout=log, stderr=subprocess.STDOUT,
                                     start_new_session=True, close_fds=True)
        record = {'state': 'starting', 'url': URL, 'command': command,
                  'process': identity(child.pid), 'log': str(attempt / 'server.log')}
        atomic_json(CONTROL, record)
        try:
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline:
                if child.poll() is not None:
                    raise RuntimeError('demo server exited during startup')
                try:
                    ready = health()
                except (OSError, ValueError):
                    ready = False
                if ready and child.poll() is None:
                    record['state'] = 'running'
                    atomic_json(CONTROL, record)
                    atomic_json(attempt / 'startup.json', record)
                    print(json.dumps(record), flush=True)
                    return 0
                time.sleep(.05)
            raise RuntimeError('demo server startup health check timed out')
        except BaseException as exc:
            if child.poll() is None:
                child.terminate()
            child.wait()
            record.update(state='failed', error=str(exc))
            atomic_json(CONTROL, record)
            atomic_json(attempt / 'startup.json', record)
            raise


if __name__ == '__main__':
    raise SystemExit(main())

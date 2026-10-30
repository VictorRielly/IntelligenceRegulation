"""Supervise the final category after the existing violence supervisor succeeds.

Never starts or restarts violence, and never retries a failed category. The
native work still runs through the app's detached, guarded pipeline.
"""
from datetime import datetime, timezone
import fcntl
import json
from pathlib import Path
import sqlite3
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
OUT = HERE / 'real_app_demo_1'


def main():
    plan = json.loads((OUT/'plan.json').read_text())
    private = Path(plan['private_root'])
    with (private/'hate-supervisor.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        if (OUT/'hate.done').exists():
            raise RuntimeError('hate category already finished; inspect retained evidence')
        print(json.dumps({'step': 'waiting for accepted violence category', 'next': 'hate'}), flush=True)
        deadline = time.monotonic() + 7200
        while not (OUT/'violence.done').exists():
            if time.monotonic() > deadline:
                raise RuntimeError('upstream category supervision wait timed out')
            db = sqlite3.connect(f'file:{private / "app.sqlite3"}?mode=ro', uri=True)
            try:
                row = db.execute('SELECT status FROM jobs WHERE post_id=? AND kind=? AND chunk=1',
                                 (plan['post_id'], 'prove')).fetchone()
            finally:
                db.close()
            if row is None or row[0] not in ('queued', 'running', 'done'):
                raise RuntimeError('upstream category failed; no automatic retry or downstream run')
            time.sleep(1)
        if (OUT/'violence.done').read_text().strip() != '0':
            raise RuntimeError('upstream supervisor did not succeed')
        print(json.dumps({'step': 'starting final category', 'category': 'hate', 'native_threads': 8}), flush=True)
        return subprocess.run([sys.executable, str(HERE/'run_real_app_demo.py'),
                               'category', '--category', 'hate', '--native-threads', '8']).returncode


if __name__ == '__main__':
    rc = 1
    try:
        rc = main()
    finally:
        (OUT/'hate_supervisor.done').write_text(str(rc)+'\n')
        (OUT/'hate_supervisor_finished.json').write_text(json.dumps({
            'at': datetime.now(timezone.utc).isoformat(), 'exit': rc})+'\n')
    raise SystemExit(rc)

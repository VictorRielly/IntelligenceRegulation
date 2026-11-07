"""Client side of the shieldstral-fast service (DEVELOPMENT CANDIDATE, lane A24).

The service (`tools/fast_service.py`) is ONE long-lived guarded job that holds the two
resident native servers. The app talks to it through files in the private service
directory only:

  service.lock     flock held by the live service (the kernel drops it when it dies)
  heartbeat.json   the live service's pid, run id, state and last beat
  spool/           job requests, one owner-only JSON file each, written atomically
  STOP             ask the service to finish its in-flight jobs and exit
  launch.json      the last launch (who, when, the guard command)

A job's own directory gets the results (`step.current`, `logs/*`, `checked.json`,
`pipeline.done`), as the reviewed pipeline writes them. A job the service has claimed is
alive only while that very service run lives; after a crash it is not retried (no
automatic retry after proof work started) and fails closed.
"""
from __future__ import annotations

import fcntl
import json
import os
from pathlib import Path
import subprocess
import time

from . import config, records
from .classifier_cli import require

HEARTBEAT_STALE_S = 90


def _dirs(root: Path) -> dict:
    return {'root': root, 'spool': root / 'spool', 'lock': root / 'service.lock', 'beat': root / 'heartbeat.json',
            'stop': root / 'STOP', 'launch': root / 'launch.json', 'log': root / 'service.log'}


def ensure_dirs(root: Path) -> dict:
    d = _dirs(root)
    for p in (d['root'], d['spool']):
        p.mkdir(mode=0o700, parents=True, exist_ok=True)
        os.chmod(p, 0o700)
    return d


def service_live(root: Path) -> bool:
    """True while a service process holds the lock (a dead process holds nothing)."""
    lock = _dirs(root)['lock']
    if not lock.exists():
        return False
    fd = os.open(lock, os.O_RDWR | os.O_CREAT, 0o600)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        return True
    else:
        fcntl.flock(fd, fcntl.LOCK_UN)
        return False
    finally:
        os.close(fd)


def heartbeat(root: Path) -> dict | None:
    try:
        return json.loads(_dirs(root)['beat'].read_text())
    except (OSError, ValueError):
        return None


def health(root: Path) -> dict:
    hb = heartbeat(root)
    live = service_live(root)
    fresh = bool(hb) and time.time() - float(hb.get('beat_at', 0)) < HEARTBEAT_STALE_S
    return {'live': live, 'fresh': fresh, 'heartbeat': hb,
            'launching': (not live) and _recent_launch(root)}


def _recent_launch(root: Path, within_s: float = 120.0) -> bool:
    """a launch whose guard process still lives (it may wait for admission), or one just made"""
    try:
        launch = json.loads(_dirs(root)['launch'].read_text())
    except (OSError, ValueError):
        return False
    if (root / 'service.guard.done').exists() and float(launch.get('at', 0)) < (root / 'service.guard.done').stat().st_mtime:
        return False
    pid = launch.get('pid')
    if isinstance(pid, int) and pid > 0:
        try:
            os.kill(pid, 0)
            return True
        except ProcessLookupError:
            return False
        except PermissionError:
            return True
    return time.time() - float(launch.get('at', 0)) < within_s


def guard_command(root: Path, runtime) -> list[str]:
    """The service's one guarded leaf: its resident servers and writers are its children."""
    python = os.environ.get('PM_FAST_SERVICE_PYTHON', os.sys.executable)
    return ['python3', str(config.GUARD), 'run', '--class', 'gpu', '--need-gib', str(runtime.SERVICE_NEED_GIB),
            '--cap-gib', str(runtime.SERVICE_CAP_GIB), '--max-secs', str(runtime.SERVICE_MAX_SECONDS),
            '--wait-secs', str(config.GUARD_WAIT_SECS), '--label', 'pm-fast-service',
            '--log', str(root / 'service.guard.log'), '--done', str(root / 'service.guard.done'), '--',
            python, str(config.TOOLS_DIR / 'fast_service.py'), str(root)]


def ensure_running(root: Path, runtime, *, launcher=None) -> dict:
    """Start the service when none is live (or launching); returns its health."""
    d = ensure_dirs(root)
    h = health(root)
    if h['live'] or h['launching']:
        return h
    if d['stop'].exists():
        d['stop'].unlink()
    argv = guard_command(root, runtime)
    if launcher is not None:
        pid = launcher(argv)
    else:
        fd = os.open(root / 'service.out', os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
        with os.fdopen(fd, 'ab') as out:
            pid = subprocess.Popen(argv, stdin=subprocess.DEVNULL, stdout=out, stderr=subprocess.STDOUT,
                                   close_fds=True, start_new_session=True).pid
    tmp = d['launch'].with_suffix('.tmp')
    tmp.write_text(json.dumps({'at': time.time(), 'argv': argv, 'pid': pid if isinstance(pid, int) else None}))
    os.replace(tmp, d['launch'])
    return health(root)


def submit(root: Path, job: Path, op: str) -> Path:
    """Queue one job for the service (atomic, owner-only); the service claims it by rename."""
    require(op in ('prove', 'recheck'), 'unknown service operation')
    d = ensure_dirs(root)
    job = Path(job).resolve()
    require(job.is_dir() and (job / 'classifier-job.json').is_file(), 'service job directory is incomplete')
    name = f'{time.time_ns():020d}-{os.getpid()}-{job.parent.name}-{job.name}.json'
    tmp = d['spool'] / ('.' + name + '.tmp')
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'wb') as f:
        f.write(records.canonical({'schema': 'pm-fast-request/1', 'op': op, 'job': str(job)}))
    final = d['spool'] / name
    os.replace(tmp, final)
    (job / 'service.request').write_text(final.name + '\n')
    return final


def stop(root: Path) -> None:
    d = ensure_dirs(root)
    d['stop'].write_text(str(time.time()) + '\n')


def job_status(root: Path, job: Path) -> dict:
    """A job's state from its files and the service's liveness (works across app restarts)."""
    job = Path(job)
    st = {'done': False, 'exit': None, 'step': 'queued', 'step_since': None, 'waiting_for_machine': False,
          'guard_line': '', 'alive': None}
    done = job / 'pipeline.done'
    if done.exists():
        try:
            st['exit'] = int(done.read_text().strip() or '1')
        except ValueError:
            st['exit'] = 1
        st.update(done=True, step='done')
        return st
    try:
        name, since = (job / 'step.current').read_text().split()[:2]
        st['step'], st['step_since'] = name, float(since)
    except (OSError, ValueError):
        pass
    h = health(root)
    try:
        claim = json.loads((job / 'service.claim').read_text())
    except (OSError, ValueError):
        claim = None
    if claim is None:
        # not yet claimed: alive while its request waits for a live (or launching) service, or
        # while the live service has just taken it (renamed into claimed/, claim being written)
        req = job / 'service.request'
        name = req.read_text().strip() if req.exists() else None
        queued = bool(name) and (_dirs(root)['spool'] / name).exists()
        taken = bool(name) and any((root / 'claimed').glob('*-' + name)) if (root / 'claimed').is_dir() else False
        st['alive'] = bool((queued and (h['live'] or h['launching'])) or (taken and h['live']))
        st['waiting_for_machine'] = bool(queued and not h['live'])
        if st['waiting_for_machine']:
            st['guard_line'] = 'waiting for the fast service (its guard admission or startup)'
        return st
    hb = h['heartbeat'] or {}
    st['alive'] = bool(h['live'] and hb.get('run_id') == claim.get('run_id'))
    return st

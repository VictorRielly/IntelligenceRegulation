"""Client for reviewed resource-guard commands; never launch a leaf directly."""
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

GUARD = Path(__file__).resolve().with_name('zk60_resource_guard.py')
# Claude's scope-corrected release, accepted by both independent Codex reviews.
# Announce/review changes in RECOVERY_COORDINATION.md before updating this pin.
REVIEWED_GUARD_SHA256 = '87138bda80ae4499a668e67a1c0e7706bb859eafb5e766020bcd59567c8ac59c'


class GuardInterrupted(RuntimeError):
    pass


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def atomic_json(path, value):
    path = Path(path)
    temporary = path.with_name('.' + path.name + '.tmp')
    temporary.write_text(json.dumps(value, indent=2) + '\n')
    temporary.replace(path)


def log_tail(path, limit=16384):
    try:
        with Path(path).open('rb') as source:
            source.seek(0, os.SEEK_END)
            source.seek(max(0, source.tell() - limit))
            return source.read(limit).decode(errors='replace')
    except OSError:
        return ''


def run(command, *, cwd, env, output, label, wait_seconds=900, max_seconds=900):
    """Run one build through the pinned guard, returning its terminal record.

    An interrupt requests guard cleanup with SIGTERM and waits. No external
    hard timeout can kill only the monitor and leave the native child alive.
    """
    output = Path(output)
    if sha(GUARD) != REVIEWED_GUARD_SHA256:
        raise RuntimeError('resource guard has not been released or its source changed')
    log = output / (label + '.log')
    result = output / (label + '.guard.json')
    argv = [sys.executable, str(GUARD), 'run', '--class', 'build', '--label', label,
            '--wait-secs', str(wait_seconds), '--max-secs', str(max_seconds),
            '--result-json', str(result), '--done', str(output / (label + '.guard.done')),
            '--log', str(log), '--', *[str(x) for x in command]]
    handlers = {}
    child = None
    started = time.monotonic()
    def interrupted(signum, _frame):
        raise GuardInterrupted(f'build launcher received signal {signum}')
    try:
        for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
            handlers[sig] = signal.signal(sig, interrupted)
        fd = os.open(output / (label + '.guard.log'),
                     os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        try:
            child = subprocess.Popen(argv, cwd=cwd, env=env, stdin=subprocess.DEVNULL,
                                     stdout=fd, stderr=fd, start_new_session=True, close_fds=True)
        finally:
            os.close(fd)
        code = child.wait()
    except BaseException:
        # A second signal must not bypass the guard's cleanup wait.
        for sig in handlers:
            signal.signal(sig, signal.SIG_IGN)
        if child is not None:
            if child.poll() is None:
                child.terminate()
            child.wait()
        raise
    finally:
        for sig, previous in handlers.items():
            signal.signal(sig, previous)
    if sha(GUARD) != REVIEWED_GUARD_SHA256:
        raise RuntimeError('resource guard changed during the build')
    with result.open('rb') as source:
        body = source.read(1024 * 1024 + 1)
    if len(body) > 1024 * 1024:
        raise ValueError('oversize resource guard terminal record')
    record = json.loads(body)
    if not isinstance(record, dict) or type(record.get('exit')) is not int or record['exit'] != code:
        raise ValueError('resource guard terminal record disagrees with its exit')
    if code == 0 and (type(record.get('child_rc')) is not int or record['child_rc'] != 0 or record.get('guard_killed')
                      or record.get('guard_error') or record.get('refused')):
        raise ValueError('resource guard did not establish successful native execution')
    return {'command': [str(x) for x in command], 'guard_command': argv,
            'exit_code': code, 'guard_result': record,
            'elapsed_seconds_including_queue_and_cleanup': time.monotonic() - started,
            'guard_sha256': REVIEWED_GUARD_SHA256,
            'log_sha256': sha(log) if log.exists() else None}

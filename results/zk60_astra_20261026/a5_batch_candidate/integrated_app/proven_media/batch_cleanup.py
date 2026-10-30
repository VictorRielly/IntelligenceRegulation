"""A5 failed-batch quarantine. No native receipt is accepted by this module.

The scope is fixed before launching the child. All paths derive from the app's
job/post/receipt roots; cleanup never follows paths from a failed child's log.
Receipts stay on their original filesystem in a mode0700 quarantine. Owners
stay outside the repository in the private job tree. Moves are restartable.
"""
from dataclasses import asdict, dataclass
import fcntl
import json
import os
from pathlib import Path
import re
import stat
import uuid


@dataclass(frozen=True)
class CleanupScope:
    post_id: str
    job: str
    receipts: str
    count: int
    manifest_sha256: str

    def __post_init__(self):
        if (not re.fullmatch(r'[A-Za-z0-9_-]{1,80}', self.post_id)
                or type(self.count) is not int or not 1 <= self.count <= 24
                or not re.fullmatch(r'[0-9a-f]{64}', self.manifest_sha256)):
            raise ValueError('invalid batch cleanup scope')
        for raw in (self.job, self.receipts):
            p = Path(raw)
            if not p.is_absolute() or p != p.resolve() or not p.is_dir():
                raise ValueError('cleanup roots must be existing canonical directories')
        if Path(self.job) == Path(self.receipts) or Path(self.receipts) in Path(self.job).parents:
            raise ValueError('private cleanup root is under receipts')

    def paths(self):
        job, receipts = Path(self.job), Path(self.receipts)
        for i in range(self.count):
            for suffix, label in (('', 'run'), ('.incomplete', 'incomplete'), ('.unverified-statement', 'statement')):
                yield f'c{i}-{label}', receipts / f'{self.post_id}-c{i}{suffix}', 'receipt'
            yield f'c{i}-owner', job / 'owners' / f'c{i}', 'owner'


def _private_dir(path):
    if path.is_symlink():
        raise ValueError('quarantine directory is a symlink')
    path.mkdir(mode=0o700, exist_ok=True)
    m = path.stat()
    if not stat.S_ISDIR(m.st_mode) or m.st_uid != os.getuid() or m.st_mode & 0o077:
        raise ValueError('quarantine directory must be owner-only')


def _atomic_private(path, value):
    tmp = path.with_name(path.name + '.' + uuid.uuid4().hex + '.tmp')
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'w') as f:
        json.dump(value, f, sort_keys=True); f.write('\n'); f.flush(); os.fsync(f.fileno())
    os.replace(tmp, path)
    directory=os.open(path.parent,os.O_RDONLY|os.O_DIRECTORY)
    try:os.fsync(directory)
    finally:os.close(directory)


def quarantine(scope, *, terminal_confirmed):
    """Call after the supervisor observes child termination, including recovery
    from a kill. Never call against a live prover. No implicit retry is enabled.
    A cleanup error keeps publication blocked and permits later cleanup only.
    """
    if terminal_confirmed is not True or not isinstance(scope, CleanupScope):
        raise ValueError('terminal batch supervisor result and prepared cleanup scope required')
    job, receipts = Path(scope.job), Path(scope.receipts)
    # Recheck parent resolution after the job, but do not resolve the final
    # outputs: a malicious symlink is moved as a link, never followed.
    if job.resolve() != job or receipts.resolve() != receipts or (job / 'owners').resolve() != job / 'owners':
        raise ValueError('batch cleanup parent changed')
    lock_fd = os.open(job / 'batch-finalize.lock', os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    with os.fdopen(lock_fd, 'r+b') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        roots = {'owner': job / 'failed-batch-owners'}
        _private_dir(roots['owner'])
        public_base = receipts / '.batch-quarantine'
        _private_dir(public_base)
        roots['receipt'] = public_base / (scope.post_id + '-' + scope.manifest_sha256[:16])
        _private_dir(roots['receipt'])
        moves, errors = [], []
        for name, source, kind in scope.paths():
            target = roots[kind] / name
            try:
                if not os.path.lexists(source):
                    state = 'already-quarantined' if os.path.lexists(target) else 'absent'
                else:
                    if os.path.lexists(target):
                        raise ValueError('quarantine target already exists while source remains')
                    os.rename(source, target)
                    state = 'quarantined'
                moves.append({'path': str(source), 'destination': str(target), 'status': state})
            except (OSError, ValueError) as exc:
                errors.append({'path': str(source), 'error': str(exc)})
        result = {'schema': 'pm-failed-batch-quarantine/1', 'scope': asdict(scope),
                  'publication_allowed': False, 'complete': not errors, 'moves': moves, 'errors': errors}
        _atomic_private(job / 'failed-batch-quarantine.json', result)
        if errors:
            raise ValueError('batch quarantine incomplete; publication and retries remain blocked')
        return result

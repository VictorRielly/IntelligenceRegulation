"""Archive a finished demo's database and empty its feed without rescreening.

This is an operator reset, not content erasure. Receipts, private job files,
screening reservations, app keys, wallet configuration and chain history stay.
No app worker, publisher, RPC client or prover is initialized here.
"""
from contextlib import ExitStack, closing, contextmanager
from datetime import datetime, timezone
import fcntl
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import stat
import uuid


class ResetRefused(ValueError):
    pass


def _require(ok, reason):
    if not ok:
        raise ResetRefused(reason)


def _roots(private, public):
    private, public = Path(private).resolve(), Path(public).resolve()
    _require(private.is_dir() and public.is_dir(), 'Both existing data roots are required.')
    _require(private != public and private not in public.parents and public not in private.parents,
             'Private and public data roots must be separate trees.')
    info = private.stat()
    _require(info.st_uid == os.getuid() and not info.st_mode & 0o077, 'Private root must be owned and mode 0700.')
    db = private / 'app.sqlite3'
    _require(db.is_file() and not db.is_symlink(), 'Existing regular app.sqlite3 required.')
    _require(not db.stat().st_mode & 0o077, 'Database must be owner-only.')
    return private, public, db


def _open(db, *, readonly):
    conn = sqlite3.connect(db.as_uri() + ('?mode=ro' if readonly else '?mode=rw'), uri=True, timeout=0)
    conn.row_factory = sqlite3.Row
    expected = {'posts', 'jobs', 'checks', 'chunk_proofs', 'screenings'}
    found = {r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}
    if not expected <= found:
        conn.close()
        raise ResetRefused('Database lacks the current screening-reservation schema; reset refused.')
    return conn


def _publisher_blockers(public):
    blockers = []
    for chain in (public / 'chain', public / 'base-sepolia/chain'):
        _require(public in chain.resolve().parents, 'Publisher chain path escapes the public root.')
        pending, inflight = chain / 'pending.jsonl', chain / 'inflight.json'
        if inflight.exists() or inflight.is_symlink():
            blockers.append('A publisher transaction is still in flight.')
        if pending.exists() or pending.is_symlink():
            _require(not pending.is_symlink() and pending.is_file(), 'Publisher pending file is not regular.')
            if pending.stat().st_size:
                # The publisher uses an empty file for a drained queue. Refuse
                # any nonempty state rather than parsing or discarding it.
                blockers.append('A publisher queue has unanchored receipts.')
    return blockers


def _inspect(conn, private, public):
    blockers = _publisher_blockers(public)
    pending = conn.execute("SELECT COUNT(*) FROM jobs WHERE status NOT IN ('done','failed')").fetchone()[0]
    screening = conn.execute("SELECT COUNT(*) FROM posts WHERE status IN ('queued','screening')").fetchone()[0]
    if pending or screening:
        blockers.append('Queued or running proof/check jobs must finish before reset.')
    # A terminal database row must not hide a surviving detached pipeline.
    for row in conn.execute("SELECT j.job_dir,p.status AS post_status FROM jobs j LEFT JOIN posts p ON p.id=j.post_id WHERE j.job_dir IS NOT NULL"):
        if row['post_status'] == 'deleted':
            continue  # normal deletion already erased its private job tree
        job = Path(row['job_dir']).resolve()
        _require((private / 'jobs') in job.parents, 'A job directory is outside the private jobs tree.')
        marker = job / 'pipeline.done'
        if (not marker.is_file() or marker.is_symlink() or marker.stat().st_size > 32
                or not marker.read_text().strip().lstrip('-').isdigit()):
            blockers.append('A detached pipeline has no terminal marker.')
    counts = {t: conn.execute(f'SELECT COUNT(*) FROM {t}').fetchone()[0]
              for t in ('posts', 'jobs', 'checks', 'chunk_proofs', 'screenings')}
    return {'ready': not blockers, 'blockers': sorted(set(blockers)), 'counts': counts,
            'effect': 'Archive the database and clear the feed; retain all screening reservations, keys, files and chain history.'}


def preview(private, public):
    private, public, db = _roots(private, public)
    with closing(_open(db, readonly=True)) as conn:
        return _inspect(conn, private, public)


@contextmanager
def _publisher_locks(public):
    with ExitStack() as stack:
        for chain in (public / 'chain', public / 'base-sepolia/chain'):
            _require(public in chain.resolve().parents, 'Publisher chain path escapes the public root.')
            if not chain.exists():
                continue
            _require(chain.is_dir() and not chain.is_symlink(), 'Publisher chain directory is not regular.')
            fd = os.open(chain / '.lock', os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW | os.O_NONBLOCK, 0o600)
            stream = stack.enter_context(os.fdopen(fd, 'r+b'))
            _require(stat.S_ISREG(os.fstat(stream.fileno()).st_mode), 'Publisher lock is not regular.')
            try:
                fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError as exc:
                raise ResetRefused('Publisher is busy; reset refused.') from exc
        yield


def _reservations_digest(conn):
    digest = hashlib.sha256()
    for row in conn.execute('SELECT item_key,context,post_id FROM screenings ORDER BY item_key'):
        data = json.dumps(tuple(row), ensure_ascii=True, separators=(',', ':')).encode()
        digest.update(len(data).to_bytes(8, 'little')); digest.update(data)
    return digest.digest()  # never included in public/operator output


def reset(private, public):
    private, public, db = _roots(private, public)
    with _publisher_locks(public), closing(_open(db, readonly=False)) as conn:
        try:
            conn.execute('BEGIN IMMEDIATE')
        except sqlite3.OperationalError as exc:
            raise ResetRefused('Database is busy; reset refused.') from exc
        try:
            before = _inspect(conn, private, public)
            _require(before['ready'], ' '.join(before['blockers']))
            reservations = _reservations_digest(conn)
            if not any(before['counts'][t] for t in ('posts', 'jobs', 'checks', 'chunk_proofs')):
                conn.execute('ROLLBACK')
                return {**before, 'reset': False, 'already_empty': True}
            archives = private / 'demo-archives'
            _require(not archives.is_symlink(), 'Archive directory is a symlink.')
            archives.mkdir(mode=0o700, exist_ok=True)
            info = archives.stat()
            _require(info.st_uid == os.getuid() and not info.st_mode & 0o077, 'Archive directory must be owned and mode 0700.')
            name = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + uuid.uuid4().hex[:12]
            backup = archives / (name + '.sqlite3')
            fd = os.open(backup, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
            os.close(fd)
            # A separate read connection can back up while our RESERVED write
            # lock excludes other writers. Backing up the write connection's
            # active transaction itself would wait on its own lock.
            with closing(_open(db, readonly=True)) as source, closing(sqlite3.connect(backup)) as dest:
                source.backup(dest)
                _require(dest.execute('PRAGMA quick_check').fetchone()[0] == 'ok', 'Database archive failed validation.')
                _require(_reservations_digest(dest) == reservations, 'Archive reservation mismatch.')
            with backup.open('rb') as stream:
                os.fsync(stream.fileno())
            directory_fd = os.open(archives, os.O_RDONLY | os.O_DIRECTORY)
            try:
                os.fsync(directory_fd)
            finally:
                os.close(directory_fd)
            for table in ('checks', 'chunk_proofs', 'jobs', 'posts'):
                conn.execute(f'DELETE FROM {table}')
            _require(_reservations_digest(conn) == reservations, 'Reset altered a screening reservation; rolling back.')
            conn.execute('COMMIT')
            return {'reset': True, 'archive': str(backup), 'archived_counts': before['counts'],
                    'reservations_retained': before['counts']['screenings'], 'files_and_chain_history_retained': True}
        except BaseException:
            if conn.in_transaction:
                conn.execute('ROLLBACK')
            raise

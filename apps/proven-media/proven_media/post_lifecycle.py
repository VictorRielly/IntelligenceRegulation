"""Durable deletion and publication retries for the current per-category queue.

Forward-port of L3/M3 semantics; no legacy one-shot batch registry or prover.
All mutations share Store.lock with queue ticks and HTTP rechecks.
"""
import json
import logging
import os
from pathlib import Path
import re
import shutil
import time

from . import config
from .provers import ProverError

log = logging.getLogger('proven_media.lifecycle')
SCHEMA = '''
CREATE TABLE IF NOT EXISTS post_publications(
    post_id TEXT PRIMARY KEY, failures INTEGER NOT NULL, next_attempt REAL NOT NULL);
CREATE TABLE IF NOT EXISTS post_deletions(
    post_id TEXT PRIMARY KEY, paths TEXT NOT NULL);
'''
PUBLICATION_MAX_FAILURES = 5
PUBLICATION_BACKOFF_SECONDS = 30


def publication_due(store, pid):
    row = store.one('SELECT * FROM post_publications WHERE post_id=?', (pid,))
    return row is None or (row['failures'] < PUBLICATION_MAX_FAILURES
                           and time.time() >= row['next_attempt'])


def publication_failed(store, pid):
    with store.lock:
        post = store.post(pid)
        if not post or post['status'] in ('deleted', 'deleting'):
            return
        row = store.one('SELECT * FROM post_publications WHERE post_id=?', (pid,))
        failures = (row['failures'] if row else 0) + 1
        parked = failures >= PUBLICATION_MAX_FAILURES
        due = time.time() + PUBLICATION_BACKOFF_SECONDS * 2 ** (failures - 1)
        store.db.execute('BEGIN IMMEDIATE')
        try:
            store.x('INSERT OR REPLACE INTO post_publications VALUES(?,?,?)', (pid, failures, due))
            store.update_post(pid, status='failed' if parked else 'publishing', prove_attempted=1,
                              status_message='Could not be verified.' if parked else 'Publication pending.')
            store.db.execute('COMMIT')
        except BaseException:
            store.db.execute('ROLLBACK')
            raise
        log.warning('Publication deferred for %s: failure %s; parked=%s', pid, failures, parked)


def retry_publications(worker):
    # Also recover a crash after committing the last proof and before finalize.
    # One due item per tick leaves room for other queue work and publisher ticks.
    rows = worker.store.q('''SELECT p.id FROM posts p
        LEFT JOIN post_publications r ON r.post_id=p.id
        WHERE p.status IN ('screening','publishing')
          AND (r.post_id IS NULL OR (r.failures < ? AND r.next_attempt <= ?))
          AND EXISTS(SELECT 1 FROM chunk_proofs c WHERE c.post_id=p.id)
          AND NOT EXISTS(SELECT 1 FROM jobs j WHERE j.post_id=p.id
                         AND j.status IN ('queued','running'))
        ORDER BY COALESCE(r.next_attempt,0), p.created_at, p.id LIMIT 1''',
        (PUBLICATION_MAX_FAILURES, time.time()))
    for row in rows:
        try:
            worker.finalize(row['id'])
        except Exception:
            log.exception('Publication retry failed for %s', row['id'])
            publication_failed(worker.store, row['id'])


class DeleteBlocked(ProverError):
    pass


def checked_path(path, pid):
    """Only this item's jobs/media and explicitly named public runs are erasable.

    Final symlinks are unlinked. No parent symlink can redirect an erasure.
    This intentionally refuses an old record pointing outside current roots.
    """
    path = Path(path)
    if not path.is_absolute() or '..' in path.parts:
        raise DeleteBlocked('The saved deletion path needs operator review.')
    roots = [Path(config.JOBS_DIR).resolve(), Path(config.RUNS_DIR).resolve(), Path(config.MEDIA_DIR).resolve()]
    job_root = roots[0] / pid
    allowed = path == job_root or path.is_relative_to(job_root)
    allowed |= path.parent == roots[1] and re.fullmatch(re.escape(pid) + r'(?:-c[0-9]+)?(?:\.incomplete|\.unverified-statement)?', path.name) is not None
    allowed |= (path.parent in (roots[2], roots[2] / 'thumbs')
                and re.fullmatch(re.escape(pid) + r'(?:[.-][A-Za-z0-9_.-]+)', path.name) is not None)
    if not allowed or path.parent.resolve() != path.parent:
        raise DeleteBlocked('The saved deletion path needs operator review.')
    return path


def deletion_paths(store, post):
    pid = post['id']
    if not re.fullmatch(r'[A-Za-z0-9_-]{1,80}', pid):
        raise DeleteBlocked('Invalid deletion identity.')
    paths = {Path(config.JOBS_DIR).resolve() / pid}
    records = [json.loads(row['record']) for row in store.q(
        'SELECT record FROM chunk_proofs WHERE post_id=? AND record IS NOT NULL', (pid,))]
    item = json.loads(post['record']) if post.get('record') else {}
    records.extend(ch['record'] for ch in item.get('chunks', []) if ch.get('record'))
    if item.get('receipt'):
        records.append(item)  # pre-chunk record
    for rec in records:
        run = rec.get('receipt', {}).get('run_dir')
        if run:
            paths.add(Path(run))
    plan = json.loads(post['chunks']) if post.get('chunks') else [{'index': 0}]
    if not isinstance(plan, list) or len(plan) > 24:
        raise DeleteBlocked('The saved deletion plan needs operator review.')
    for chunk in plan:
        index = chunk.get('index')
        if type(index) is not int or not 0 <= index < 24:
            raise DeleteBlocked('The saved deletion plan needs operator review.')
        for suffix in ('', '.incomplete', '.unverified-statement'):
            paths.add(Path(config.RUNS_DIR).resolve() / f'{pid}-c{index}{suffix}')
    if post.get('media_name'):
        paths.add(Path(config.MEDIA_DIR).resolve() / post['media_name'])
        paths.add(Path(config.MEDIA_DIR).resolve() / f'{pid}-canvas.png')
        paths.update((Path(config.MEDIA_DIR).resolve() / 'thumbs').glob(f'{pid}-*'))
    checked = {checked_path(p, pid) for p in paths}
    # Remove children first; a retry remains valid after a parent has disappeared.
    return [str(p) for p in sorted(checked, key=lambda p: (-len(p.parts), str(p)))]


def sync_parent(path):
    parent = path.parent
    while not parent.exists() and parent != parent.parent:
        parent = parent.parent
    fd = os.open(parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def remove_leaf(path):
    if path.is_symlink():
        path.unlink()
    elif path.is_dir():
        if not shutil.rmtree.avoids_symlink_attacks:
            raise DeleteBlocked('Safe directory erasure is unavailable.')
        shutil.rmtree(path)
    elif os.path.lexists(path):
        path.unlink()
    # Repeat the directory durability barrier even when an earlier attempt
    # removed the entry and failed before fsync.
    sync_parent(path)


def finish_deletion(store, publisher, pid):
    post = store.post(pid)
    row = store.one('SELECT paths FROM post_deletions WHERE post_id=?', (pid,))
    if not post or post['status'] != 'deleting' or not row:
        raise DeleteBlocked('Deletion has no committed author request.')
    paths = [checked_path(p, pid) for p in json.loads(row['paths'])]
    for anchor in publisher.anchors_of(pid).values():
        # Authenticate the retained manifest before deleting addressed objects.
        # Repeating these barriers is safe after an interrupted CAS erasure.
        manifest = json.loads(publisher.get_bytes(anchor.manifest_sha256))
        object_paths = []
        for segment in manifest['segments']:
            digest = segment['sha256']
            if not re.fullmatch(r'[0-9a-f]{64}', digest):
                raise DeleteBlocked('The publication deletion inventory needs review.')
            object_paths.append(publisher._obj(digest))
        publisher.delete_receipt(anchor)
        for path in object_paths:
            sync_parent(path)
    for path in paths:
        remove_leaf(path)
    store.db.execute('BEGIN IMMEDIATE')
    try:
        store.update_post(pid, status='deleted', text=None, salt_enc=None, content_key=None, media_name=None,
            record=None, manifest=None, labels=None,
            status_message='Deleted by the author. The anchored leaf and private screening reservation remain.')
        store.x('DELETE FROM chunk_proofs WHERE post_id=?', (pid,))
        store.x('UPDATE jobs SET job_dir=NULL, result=NULL, error=NULL WHERE post_id=?', (pid,))
        store.x('DELETE FROM post_publications WHERE post_id=?', (pid,))
        store.x('DELETE FROM post_deletions WHERE post_id=?', (pid,))
        store.db.execute('COMMIT')
    except BaseException:
        store.db.execute('ROLLBACK')
        raise


def request_deletion(store, publisher, pid):
    with store.lock:
        post = store.post(pid)
        if post['status'] == 'deleted':
            return
        if post['status'] in ('queued', 'screening') or store.one(
                "SELECT id FROM jobs WHERE post_id=? AND status IN ('queued','running')", (pid,)):
            raise DeleteBlocked('Wait for pending screening or verification before deleting this post.')
        if post['status'] != 'deleting':
            paths = deletion_paths(store, post)
            store.db.execute('BEGIN IMMEDIATE')
            try:
                store.x('INSERT INTO post_deletions VALUES(?,?)', (pid, json.dumps(paths)))
                store.update_post(pid, status='deleting')
                store.x('DELETE FROM post_publications WHERE post_id=?', (pid,))
                store.db.execute('COMMIT')
            except BaseException:
                store.db.execute('ROLLBACK')
                raise
        finish_deletion(store, publisher, pid)


def resume_deletions(store, publisher):
    with store.lock:
        for row in store.q("SELECT id FROM posts WHERE status='deleting'"):
            try:
                finish_deletion(store, publisher, row['id'])
            except Exception:
                log.exception('Deletion remains pending for %s', row['id'])

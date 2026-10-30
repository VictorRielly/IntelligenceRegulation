"""Staged queue registration and startup recovery; no batch launcher enabled.

The registration is committed before launch. A same-boot missing PID is never
termination evidence. The future supervisor must write pipeline-terminal.json
only after all guarded children have been reaped; until then recovery blocks.
"""
import json
import os
from pathlib import Path
import uuid

from .batch_queue_gate import recover_batch
from . import config, proof_plans, records
from .classifier_cli import require

SCHEMA = """
CREATE TABLE IF NOT EXISTS batch_runs(
 post_id TEXT PRIMARY KEY, job_dir TEXT NOT NULL, receipts TEXT NOT NULL,
 plan TEXT NOT NULL, context TEXT NOT NULL, boot_id TEXT NOT NULL,
 launch_id TEXT NOT NULL UNIQUE, status TEXT NOT NULL, collection TEXT, scope TEXT NOT NULL);
"""


def boot_id():
    return Path('/proc/sys/kernel/random/boot_id').read_text().strip()


def register_prepared(store, post_id):
    """Atomically claim every queued category before any batch child starts.

    Preparation itself does not prove. Existing registration, partial claims,
    or completed category rows forbid registering the post a second time.
    """
    post = store.post(post_id)
    require(post is not None, 'batch post is missing')
    store.check_screening(post)
    plan = json.loads(post['chunks'])
    require(proof_plans.is_category_plan(plan), 'complete category plan required')
    job = (config.JOBS_DIR/post_id/'batch').resolve()
    receipts = config.RUNS_DIR.resolve()
    scope = json.loads((job/'cleanup-scope.json').read_text())
    prepared = json.loads((job/'prepared.json').read_text())
    require(scope['post_id'] == post_id and scope['job'] == str(job)
            and scope['receipts'] == str(receipts) and scope['count'] == len(plan),
            'prepared scope differs from queue roots')
    require(prepared['post_id'] == post_id and prepared['reserved_plan'] == plan
            and prepared['screening_context'] == post['screening_context'],
            'prepared batch differs from original reservation')
    # Persist owner inputs and the trusted cleanup scope before the SQLite
    # claim can authorize any child. Recovery also keeps scope in the DB.
    for path in job.iterdir():
        if path.is_file():
            with path.open('rb') as stream:os.fsync(stream.fileno())
    for path in (job/'owners',job,job.parent):
        fd=os.open(path,os.O_RDONLY|os.O_DIRECTORY)
        try:os.fsync(fd)
        finally:os.close(fd)
    launch_id = uuid.uuid4().hex
    with store.lock:
        store.db.execute('BEGIN IMMEDIATE')
        try:
            store.check_screening(store.post(post_id))
            require(not store.one('SELECT post_id FROM batch_runs WHERE post_id=?', (post_id,)),
                    'batch is already registered; no retry')
            jobs = store.q("SELECT * FROM jobs WHERE post_id=? AND kind='prove' ORDER BY chunk", (post_id,))
            require(len(jobs) == len(plan) and all(j['status'] == 'queued' and j['chunk'] == p['index']
                    for j, p in zip(jobs, plan)), 'batch needs every original queued category')
            require(not store.one('SELECT post_id FROM chunk_proofs WHERE post_id=?', (post_id,)),
                    'a category was already attempted')
            store.x('INSERT INTO batch_runs VALUES(?,?,?,?,?,?,?,?,NULL,?)',
                    (post_id, str(job), str(receipts), records.canonical(plan).decode(),
                     post['screening_context'], boot_id(), launch_id, 'active',records.canonical(scope).decode()))
            store.x("UPDATE jobs SET status='running',job_dir=?,started_at=? WHERE post_id=? AND kind='prove'",
                    (str(job), records.now_iso(), post_id))
            store.update_post(post_id, status='screening', prove_attempted=1)
            store.db.execute('COMMIT')
        except BaseException:
            store.db.execute('ROLLBACK')
            raise
    return launch_id


def terminal_known(row):
    # Reboot is sufficient even when a crash left no terminal marker. Merely
    # losing visibility of a process in another namespace is insufficient.
    path = Path(row['job_dir'])/'pipeline-terminal.json'
    if not path.exists():
        return row['boot_id'] != boot_id(), None
    terminal = json.loads(path.read_text())
    require(terminal.get('schema') == 'pm-batch-terminal/1'
            and terminal.get('launch_id') == row['launch_id']
            and terminal.get('boot_id') == row['boot_id']
            and terminal.get('children_reaped') is True
            and type(terminal.get('exit')) is int, 'batch terminal identity is invalid')
    return True, terminal['exit']


def _failed(store, row, result):
    """Persist failure without releasing the original D45 reservation."""
    with store.lock:
        store.db.execute('BEGIN IMMEDIATE')
        try:
            store.x('UPDATE batch_runs SET status=?,collection=? WHERE post_id=?',
                    ('quarantined', records.canonical(result).decode(), row['post_id']))
            store.x("UPDATE jobs SET status='failed',finished_at=?,error=? WHERE post_id=? AND kind='prove'",
                    (records.now_iso(), 'Batch failed; quarantined; no retry.', row['post_id']))
            store.x("UPDATE chunk_proofs SET status='failed',attempted=1,error=? WHERE post_id=?",
                    ('Batch quarantined; no accepted proof.', row['post_id']))
            store.update_post(row['post_id'], status='failed', prove_attempted=1,
                              status_message='Could not be verified.')
            store.db.execute('COMMIT')
        except BaseException:
            store.db.execute('ROLLBACK')
            raise


def recover_registered_batches(worker):
    """Quarantine all failed terminal batches before any publication or launch.

    Unknown/live jobs hold the queue. Successful transport needs fresh native
    checks from the batch adapter before the entire category set is committed.
    Publication can resume after a crash, but native proof work never restarts.
    """
    store = worker.store
    blocked, ready = False, []
    for row in store.q("SELECT * FROM batch_runs WHERE status NOT IN ('quarantined','finished') ORDER BY post_id"):
        post_id = row['post_id']
        job = (config.JOBS_DIR/post_id/'batch').resolve()
        require(row['job_dir'] == str(job) and row['receipts'] == str(config.RUNS_DIR.resolve()),
                'registered batch roots differ from deployment')
        require(row['status'] in ('active', 'unverified', 'verified'), 'unknown batch state blocks queue')
        terminal, terminal_exit = terminal_known(row)
        if not terminal:
            blocked = True
            continue
        post = store.post(post_id)
        require(post is not None and (post['status'] != 'published' or row['status'] == 'verified'),
                'unverified batch post already published or missing')
        require(json.loads(post['chunks']) == json.loads(row['plan'])
                and post['screening_context'] == row['context'], 'original batch reservation changed')
        result = recover_batch(job, config.RUNS_DIR, post_id=post_id,
                               reserved_plan=json.loads(row['plan']), reserved_context=row['context'],
                               terminal_confirmed=True, terminal_exit=terminal_exit,
                               reserved_scope=json.loads(row['scope']))
        if result['status'] == 'quarantined':
            _failed(store, row, result)
        else:
            # Preserve 'verified' across a crash after publication but before
            # the final DB transition; ordinary unverified data cannot do so.
            if row['status'] != 'verified':
                store.x("UPDATE batch_runs SET status='unverified',collection=? WHERE post_id=?",
                        (records.canonical(result).decode(), post_id))
            ready.append((row, post))
            if getattr(worker.prover, 'batch_proving', False) is not True:
                blocked = True
    if blocked:
        return True
    verified=[]
    for row, post in ready:
        plan=json.loads(row['plan'])
        try:
            store.check_screening(post)
            recs=worker.prover.collect_batch(post,Path(row['job_dir']),row)
            require(len(recs)==len(plan), 'batch did not return every category record')
            for chunk, rec in zip(plan,recs):
                proof_plans.check_category_record(rec.to_dict(),post['id'],chunk,require_verdict=True)
            from .items import TextItem
            worker.prover.check_final_records(TextItem(post['text']),[r.to_dict() for r in recs])
        except Exception:
            failed=recover_batch(Path(row['job_dir']),config.RUNS_DIR,post_id=row['post_id'],
                reserved_plan=plan,reserved_context=row['context'],terminal_confirmed=True,
                terminal_exit=1,reserved_scope=json.loads(row['scope']))
            _failed(store,row,failed)
            continue
        with store.lock:
            store.db.execute('BEGIN IMMEDIATE')
            try:
                store.check_screening(store.post(post['id']))
                for chunk, rec in zip(plan,recs):
                    worker._set_chunk(post['id'],chunk['index'],'done',rec.to_dict(),None,True)
                    store.x("UPDATE jobs SET status='done',finished_at=?,result=? WHERE post_id=? AND kind='prove' AND chunk=?",
                            (records.now_iso(),records.canonical({'chunk':chunk['index'],
                             'labels':records.effective_labels(rec.to_dict())}).decode(),post['id'],chunk['index']))
                store.x("UPDATE batch_runs SET status='verified' WHERE post_id=?",(post['id'],))
                store.db.execute('COMMIT')
            except BaseException:
                store.db.execute('ROLLBACK')
                raise
        verified.append((row,post))
    # No publisher call occurs until every known terminal failure above has
    # been quarantined and every accepted category set committed atomically.
    for row, post in verified:
        worker.finalize(post['id'], require_publication=True)
        if store.post(post['id'])['status']!='published':
            failed=recover_batch(Path(row['job_dir']),config.RUNS_DIR,post_id=row['post_id'],
                reserved_plan=json.loads(row['plan']),reserved_context=row['context'],
                terminal_confirmed=True,terminal_exit=1,reserved_scope=json.loads(row['scope']))
            _failed(store,row,failed)
        else:
            store.x("UPDATE batch_runs SET status='finished' WHERE post_id=?",(post['id'],))
    return False

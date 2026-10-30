"""Staged queue registration and startup recovery; no batch launcher enabled.

The registration is committed before launch. A same-boot missing PID is never
termination evidence. The future supervisor must write pipeline-terminal.json
only after all guarded children have been reaped; until then recovery blocks.
"""
import json
from pathlib import Path
import uuid

from batch_queue_gate import recover_batch
from proven_media import config, proof_plans, records
from proven_media.classifier_cli import require

SCHEMA = """
CREATE TABLE IF NOT EXISTS batch_runs(
 post_id TEXT PRIMARY KEY, job_dir TEXT NOT NULL, receipts TEXT NOT NULL,
 plan TEXT NOT NULL, context TEXT NOT NULL, boot_id TEXT NOT NULL,
 launch_id TEXT NOT NULL UNIQUE, status TEXT NOT NULL, collection TEXT);
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
            store.x('INSERT INTO batch_runs VALUES(?,?,?,?,?,?,?,?,NULL)',
                    (post_id, str(job), str(receipts), records.canonical(plan).decode(),
                     post['screening_context'], boot_id(), launch_id, 'active'))
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
    if row['boot_id'] != boot_id():
        return True, None
    path = Path(row['job_dir'])/'pipeline-terminal.json'
    if not path.exists():
        return False, None
    terminal = json.loads(path.read_text())
    require(terminal.get('schema') == 'pm-batch-terminal/1'
            and terminal.get('launch_id') == row['launch_id']
            and terminal.get('boot_id') == row['boot_id']
            and terminal.get('children_reaped') is True
            and type(terminal.get('exit')) is int, 'batch terminal identity is invalid')
    return True, terminal['exit']


def recover_registered_batches(worker):
    """Called before publisher.tick, ordinary polling, or new queue launches.

    Return True to hold the queue. Successful transport stays unverified and
    holds too: fresh-check integration is deliberately not implemented here.
    Any exception also prevents the caller reaching publication or launch.
    """
    store = worker.store
    blocked = False
    for row in store.q("SELECT * FROM batch_runs WHERE status!='quarantined' ORDER BY post_id"):
        post_id = row['post_id']
        job = (config.JOBS_DIR/post_id/'batch').resolve()
        require(row['job_dir'] == str(job) and row['receipts'] == str(config.RUNS_DIR.resolve()),
                'registered batch roots differ from deployment')
        require(row['status'] in ('active', 'unverified'), 'unknown batch state blocks queue')
        terminal, terminal_exit = terminal_known(row)
        if not terminal:
            blocked = True
            continue
        post = store.post(post_id)
        require(post is not None and post['status'] != 'published', 'batch post already published or missing')
        require(json.loads(post['chunks']) == json.loads(row['plan'])
                and post['screening_context'] == row['context'], 'original batch reservation changed')
        result = recover_batch(job, config.RUNS_DIR, post_id=post_id,
                               reserved_plan=json.loads(row['plan']), reserved_context=row['context'],
                               terminal_confirmed=True, terminal_exit=terminal_exit)
        with store.lock:
            store.db.execute('BEGIN IMMEDIATE')
            try:
                store.x('UPDATE batch_runs SET status=?,collection=? WHERE post_id=?',
                        (result['status'], records.canonical(result).decode(), post_id))
                if result['status'] == 'quarantined':
                    store.x("UPDATE jobs SET status='failed',finished_at=?,error=? WHERE post_id=? AND kind='prove'",
                            (records.now_iso(), 'Batch failed; quarantined; no retry.', post_id))
                    store.update_post(post_id, status='failed', prove_attempted=1,
                                      status_message='Could not be verified.')
                    # Keep screenings and the original policy reservation.
                else:
                    blocked = True
                store.db.execute('COMMIT')
            except BaseException:
                store.db.execute('ROLLBACK')
                raise
    return blocked

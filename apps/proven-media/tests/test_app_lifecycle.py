"""Real SQLite/filesystem queue tests; synthetic records, no native proof/network."""
import json
import hashlib
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

import test_app  # fixture environment and app import path
import test_category_queue as fixtures
from proven_media import app, config, post_lifecycle as lifecycle, records
from proven_media.app_instance import AppInstanceLock
from proven_media.jobs import Worker
from proven_media.provers import ProverError
from proven_media.publisher import PublishError
from proven_media.store import Store


class LifecycleTests(unittest.TestCase):
    setUp = fixtures.CategoryQueueTests.setUp
    submit = fixtures.CategoryQueueTests.submit
    drain = fixtures.CategoryQueueTests.drain

    def prepare(self):
        for key in ('RUNS_DIR', 'MEDIA_DIR'):
            patcher = patch.object(config, key, (self.root / key.lower()).resolve())
            patcher.start()
            self.addCleanup(patcher.stop)
            getattr(config, key).mkdir()
        pid, plan = self.submit()
        return pid, plan

    def test_partial_publication_is_hidden_then_resumes_without_reproving(self):
        pid, plan = self.prepare()
        publish = self.pub.publish

        def fail_one(row):
            if row.category == 'hate':
                raise PublishError('temporary fixture outage')
            return publish(row)

        with patch.object(self.pub, 'publish', side_effect=fail_one):
            self.drain()
        self.assertEqual(self.store.post(pid)['status'], 'publishing')
        self.assertIsNone(self.store.post(pid)['manifest'])
        self.assertLess(len(self.pub.anchors_of(pid)), len(plan))
        due = self.store.one('SELECT * FROM post_publications')['next_attempt']
        self.store.db.close()
        self.store = Store(self.root / 'app.sqlite3')
        self.worker = Worker(self.store, self.prover, self.pub)
        with patch.object(self.prover, 'start', side_effect=AssertionError('no reproof')), \
             patch.object(self.prover, 'collect', side_effect=AssertionError('already committed')), \
             patch.object(lifecycle.time, 'time', return_value=due):
            self.worker.tick()
        self.assertEqual(self.store.post(pid)['status'], 'published')
        self.assertEqual(len(self.pub.anchors_of(pid)), len(plan))
        self.assertEqual(self.store.q('SELECT * FROM post_publications'), [])

    def test_backoff_does_not_rehash_or_stall_publisher_ticks(self):
        pid, _ = self.prepare()
        with patch.object(self.pub, 'publish', side_effect=PublishError('offline')):
            self.drain()
        with patch('proven_media.jobs.chunk_publication_records', side_effect=AssertionError('too early')), \
             patch.object(self.pub, 'tick', wraps=self.pub.tick) as ticks:
            for _ in range(4):
                self.worker.tick()
        self.assertEqual(ticks.call_count, 4)
        self.assertEqual(self.store.one('SELECT * FROM post_publications')['failures'], 1)
        self.assertEqual(self.store.post(pid)['status'], 'publishing')

    def test_five_failures_park_with_exact_backoff_and_never_restart_proofs(self):
        pid, _ = self.prepare()
        with patch.object(self.pub, 'publish', side_effect=PublishError('offline')), \
             patch.object(lifecycle.time, 'time', return_value=1000):
            self.drain()
        self.assertEqual(self.store.one('SELECT * FROM post_publications')['next_attempt'], 1030)
        previous = 1000
        for count in range(1, 5):
            row = self.store.one('SELECT * FROM post_publications')
            self.assertEqual(row['next_attempt'] - previous, 30 * 2 ** (count - 1))
            previous = row['next_attempt']
            with patch.object(lifecycle.time, 'time', return_value=previous), \
                 patch.object(self.pub, 'publish', side_effect=PublishError('offline')), \
                 patch.object(self.prover, 'start', side_effect=AssertionError('no reproof')):
                self.worker.tick()
        self.assertEqual(self.store.post(pid)['status'], 'failed')
        self.assertEqual(self.store.post(pid)['prove_attempted'], 1)
        with patch.object(lifecycle.time, 'time', return_value=10**12), \
             patch.object(self.pub, 'publish', side_effect=AssertionError('parked')):
            self.worker.tick()
        self.assertEqual(self.store.one('SELECT * FROM post_publications')['failures'], 5)

    def test_restart_recovers_last_proof_commit_before_finalization(self):
        pid, _ = self.prepare()
        with patch.object(self.worker, 'finalize'):
            self.drain()
        self.assertEqual(self.store.post(pid)['status'], 'screening')
        with patch.object(self.prover, 'collect', side_effect=AssertionError('no recollection')):
            Worker(self.store, self.prover, self.pub).tick()
        self.assertEqual(self.store.post(pid)['status'], 'published')

    def test_retry_rechecks_receipt_bytes_even_if_anchor_already_exists(self):
        pid, _ = self.prepare()
        def receipt(rec):
            run = config.RUNS_DIR / f'{pid}-c{rec.chunk["index"]}'
            (run / 'statement').mkdir(parents=True)
            statement = records.canonical(rec.statement)
            (run / 'statement/statement.json').write_bytes(statement)
            rec.statement_sha256 = hashlib.sha256(statement).hexdigest()
            segment = b'synthetic receipt bytes ' + str(rec.chunk['index']).encode()
            (run / 'segment-000.bin').write_bytes(segment)
            rec.receipt = {'run_dir': str(run), 'segments': 1, 'bytes': len(segment),
                'files': [{'file': 'segment-000.bin', 'bytes': len(segment),
                           'sha256': hashlib.sha256(segment).hexdigest()}]}
        self.prover.mutate = receipt
        publish = self.pub.publish
        def fail_one(row):
            if row.category == 'hate':
                raise PublishError('temporary fixture outage')
            return publish(row)
        with patch.object(self.pub, 'publish', side_effect=fail_one):
            self.drain()
        self.assertIsNotNone(self.pub.anchor_of(pid, 'sexual', 0))
        (config.RUNS_DIR / f'{pid}-c0/segment-000.bin').write_bytes(b'corrupted')
        due = self.store.one('SELECT * FROM post_publications')['next_attempt']
        with patch.object(lifecycle.time, 'time', return_value=due):
            self.worker.tick()
        self.assertEqual(self.store.post(pid)['status'], 'publishing')
        self.assertEqual(self.store.one('SELECT * FROM post_publications')['failures'], 2)

    def test_deletion_resumes_after_erasure_before_durability_barrier(self):
        pid, _ = self.prepare()
        self.drain()
        job = config.JOBS_DIR / pid
        saved = self.store.q('SELECT * FROM screenings')
        remove = lifecycle.remove_leaf

        def fail_after_remove(path):
            remove(path)
            if path == job.resolve():
                raise OSError('interrupted after removing job directory')

        with patch.object(lifecycle, 'remove_leaf', side_effect=fail_after_remove), self.assertRaises(OSError):
            lifecycle.request_deletion(self.store, self.pub, pid)
        self.assertFalse(job.exists())
        self.assertEqual(self.store.post(pid)['status'], 'deleting')
        self.assertIsNotNone(self.store.post(pid)['text'])
        self.store.db.close()
        self.store = Store(self.root / 'app.sqlite3')
        lifecycle.resume_deletions(self.store, self.pub)
        post = self.store.post(pid)
        self.assertEqual(post['status'], 'deleted')
        self.assertIsNone(post['text'])
        self.assertIsNone(post['salt_enc'])
        self.assertEqual(self.store.q('SELECT * FROM screenings'), saved)
        self.assertEqual(self.store.q('SELECT * FROM chunk_proofs'), [])
        self.assertEqual(self.store.q('SELECT * FROM post_deletions'), [])
        lifecycle.request_deletion(self.store, self.pub, pid)  # idempotent

    def test_live_recheck_blocks_delete_before_tombstone(self):
        pid, _ = self.prepare()
        self.drain()
        self.store.add_job(pid, 'recheck', 0)
        with self.assertRaises(lifecycle.DeleteBlocked):
            lifecycle.request_deletion(self.store, self.pub, pid)
        self.assertEqual(self.store.post(pid)['status'], 'published')
        self.assertEqual(self.store.q('SELECT * FROM post_deletions'), [])

    def test_delete_unlinks_final_symlink_without_touching_target(self):
        pid, _ = self.prepare()
        self.drain()
        outside = self.root / 'unrelated'
        outside.mkdir()
        (outside / 'keep').write_text('untouched')
        run = config.RUNS_DIR / f'{pid}-c0'
        run.symlink_to(outside, target_is_directory=True)
        lifecycle.request_deletion(self.store, self.pub, pid)
        self.assertFalse(run.is_symlink())
        self.assertEqual((outside / 'keep').read_text(), 'untouched')

    def test_foreign_record_path_refuses_before_any_delete(self):
        pid, _ = self.prepare()
        self.drain()
        row = self.store.one('SELECT * FROM chunk_proofs LIMIT 1')
        rec = json.loads(row['record'])
        rec['receipt']['run_dir'] = str(self.root / 'unrelated')
        self.store.x('UPDATE chunk_proofs SET record=? WHERE post_id=? AND chunk=?',
                     (json.dumps(rec), pid, row['chunk']))
        with patch.object(self.pub, 'delete_receipt', side_effect=AssertionError('must validate first')), \
             self.assertRaises(lifecycle.DeleteBlocked):
            lifecycle.request_deletion(self.store, self.pub, pid)
        self.assertEqual(self.store.post(pid)['status'], 'published')

    def test_deleted_post_cannot_be_finalized_again(self):
        pid, _ = self.prepare()
        self.drain()
        stale = self.store.one('SELECT * FROM jobs LIMIT 1')
        lifecycle.request_deletion(self.store, self.pub, pid)
        self.worker.finalize(pid)
        with patch.object(self.prover, 'start', side_effect=AssertionError('deleted')), \
             patch.object(self.prover, 'collect', side_effect=AssertionError('deleted')):
            self.worker.start_job(stale)
            self.worker.finish(stale)
        self.assertEqual(self.store.post(pid)['status'], 'deleted')

    def test_legacy_queued_job_for_deleted_post_cannot_block_the_queue(self):
        pid, _ = self.prepare()
        self.store.update_post(pid, status='deleted')  # a legacy inconsistent row
        with patch.object(self.prover, 'start', side_effect=AssertionError('deleted')):
            self.drain()
        self.assertFalse(self.store.q("SELECT id FROM jobs WHERE status IN ('queued','running')"))
        self.assertEqual(self.store.post(pid)['status'], 'deleted')


class LockTests(unittest.TestCase):
    def test_alias_and_separate_process_exclusion_and_death_release(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            alias = root / 'alias'
            alias.symlink_to(root, target_is_directory=True)
            lock = AppInstanceLock(root)
            inode = (root / 'app-instance.lock').stat().st_ino
            self.assertFalse(os.get_inheritable(lock.fd))
            with self.assertRaises(ProverError):
                AppInstanceLock(alias)
            code = 'from proven_media.app_instance import AppInstanceLock; import sys; AppInstanceLock(sys.argv[1])'
            env = dict(os.environ, PYTHONPATH=str(Path(app.__file__).resolve().parents[1]))
            denied = subprocess.run([sys.executable, '-B', '-c', code, str(root)], env=env, capture_output=True)
            self.assertNotEqual(denied.returncode, 0)
            self.assertIn(b'Another app instance', denied.stderr)
            lock.close()
            child = subprocess.run([sys.executable, '-B', '-c', code, str(root)], env=env, capture_output=True)
            self.assertEqual(child.returncode, 0, child.stderr)
            again = AppInstanceLock(root)
            again.close()
            self.assertEqual((root / 'app-instance.lock').stat().st_ino, inode)

    def test_lock_rejects_symlink_fifo_and_public_mode(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = root / 'target'
            target.write_text('untouched')
            path = root / 'app-instance.lock'
            path.symlink_to(target)
            with self.assertRaises(OSError):
                AppInstanceLock(root)
            path.unlink()
            os.mkfifo(path, 0o600)
            with self.assertRaises(ProverError):
                AppInstanceLock(root)
            path.unlink()
            path.write_text('')
            path.chmod(0o644)
            with self.assertRaises(ProverError):
                AppInstanceLock(root)
            self.assertEqual(target.read_text(), 'untouched')

    def test_startup_failure_releases_lock_and_shutdown_waits_for_worker(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            state = app.State()
            with patch.object(app, 'S', state), patch.object(config, 'PRIVATE_DIR', root), \
                 patch.object(app, 'validate_storage'), patch.object(app.provers, 'ensure_private_roots'), \
                 patch.object(app, '_init_state_locked', side_effect=RuntimeError('failed init')):
                with self.assertRaisesRegex(RuntimeError, 'failed init'):
                    app.init_state(False)
                self.assertIsNone(state.instance_lock)
                state.instance_lock = AppInstanceLock(root)
                state.worker = Mock()
                state.worker.is_alive.return_value = True
                with self.assertRaisesRegex(RuntimeError, 'has not stopped'):
                    app.close_state()
                with self.assertRaises(ProverError):
                    AppInstanceLock(root)
                state.worker.is_alive.return_value = False
                app.close_state()
                self.assertIsNone(state.instance_lock)

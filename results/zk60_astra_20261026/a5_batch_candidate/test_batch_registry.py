"""Exercise staged real Store and Worker with retained native log fixtures."""
import json
from pathlib import Path
import unittest
from unittest.mock import Mock, patch

import batch_registry as registry
import test_batch_queue_gate as fixtures
from proven_media import config
from proven_media.provers import ProverError
from queue_candidate.jobs import Worker
from queue_candidate.store import Store, ScreeningConflict


class RegistryTests(unittest.TestCase):
    def setUp(self):
        self.fixture = fixtures.QueueGateTests()
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        self.job = self.fixture.job
        self.plan = self.fixture.plan
        for obj, attr, value in ((config, 'JOBS_DIR', self.job.parent.parent),
                                  (config, 'RUNS_DIR', self.fixture.receipts)):
            p = patch.object(obj, attr, value)
            p.start(); self.addCleanup(p.stop)
        p = patch.object(registry, 'boot_id', return_value='boot-original')
        self.boot = p.start(); self.addCleanup(p.stop)
        self.store = Store(self.fixture.fixture.private/'queue.sqlite')
        self.addCleanup(self.store.db.close)
        self.store.add_screened_post('public fixture text', self.plan,
            id='test-post', author='test', kind='text', text='public fixture text',
            status='queued', chunks=json.dumps(self.plan))
        self.prover = Mock(); self.publisher = Mock()
        self.worker = Worker(self.store, self.prover, self.publisher)

    def register(self):
        self.launch_id = registry.register_prepared(self.store, 'test-post')
        return self.launch_id

    def terminal(self, **changes):
        value = {'schema':'pm-batch-terminal/1', 'launch_id':self.launch_id,
                 'boot_id':'boot-original', 'children_reaped':True, 'exit':0}
        value.update(changes)
        (self.job/'pipeline-terminal.json').write_text(json.dumps(value))

    def assert_blocked(self):
        self.publisher.tick.assert_not_called()
        self.prover.poll.assert_not_called()
        self.prover.start.assert_not_called()

    def test_atomic_claim_and_registration_cannot_repeat(self):
        self.register()
        rows = self.store.q('SELECT * FROM jobs')
        self.assertEqual(len(rows), len(self.plan))
        self.assertTrue(all(r['status']=='running' and r['job_dir']==str(self.job) for r in rows))
        with self.assertRaises(ProverError): self.register()
        self.assertEqual(len(self.store.q('SELECT * FROM batch_runs')), 1)

    def test_partial_category_claim_refused_without_registration(self):
        self.store.x("UPDATE jobs SET status='done' WHERE chunk=1")
        with self.assertRaises(ProverError): self.register()
        self.assertEqual(self.store.q('SELECT * FROM batch_runs'), [])
        self.assertEqual(self.store.q("SELECT * FROM jobs WHERE status='queued'").__len__(), 2)

    def test_same_boot_missing_pid_or_marker_blocks_before_anchor(self):
        self.register()
        (self.job/'pipeline.pid').write_text('999999999\n')
        self.worker.tick()
        self.assert_blocked()
        self.assertTrue(all(Path(r['out']).exists() for r in self.fixture.manifest['jobs']))

    def test_reboot_crash_quarantines_before_any_anchor_or_launch(self):
        self.register(); self.boot.return_value = 'boot-after-restart'
        def check_order():
            self.assertTrue(all(not Path(r['out']).exists() for r in self.fixture.manifest['jobs']))
            self.assertEqual(self.store.post('test-post')['status'], 'failed')
        self.publisher.tick.side_effect = check_order
        self.worker.tick()
        self.publisher.tick.assert_called_once()
        self.prover.poll.assert_not_called(); self.prover.start.assert_not_called()
        self.assertTrue(all(r['status']=='failed' for r in self.store.q('SELECT * FROM jobs')))

    def test_original_d45_reservation_survives_quarantine(self):
        self.register(); self.boot.return_value = 'reboot'
        reservation = self.store.q('SELECT * FROM screenings')
        self.worker.tick()
        self.assertEqual(self.store.q('SELECT * FROM screenings'), reservation)
        with self.assertRaises(ScreeningConflict):
            self.store.add_screened_post('public fixture text', self.plan, id='second-post',
                author='test', kind='text', text='public fixture text', status='queued')

    def test_terminal_marker_must_match_launch_and_reaped_children(self):
        self.register()
        for changes in ({'launch_id':'different'}, {'boot_id':'other'}, {'children_reaped':False}, {'exit':True}):
            with self.subTest(changes=changes):
                self.terminal(**changes)
                with self.assertRaises(ProverError): self.worker.tick()
                self.assert_blocked()

    def test_valid_terminal_marker_routes_failure_through_collector(self):
        self.register(); self.terminal()
        with patch.object(registry, 'recover_batch', wraps=registry.recover_batch) as collect:
            self.worker.tick()
        collect.assert_called_once()
        self.assertEqual(self.store.one('SELECT * FROM batch_runs')['status'], 'quarantined')

    def test_complete_native_transport_remains_unverified_and_blocks(self):
        self.register(); self.fixture.terminal(); self.terminal()
        self.worker.tick()
        self.assertEqual(self.store.one('SELECT * FROM batch_runs')['status'], 'unverified')
        self.assert_blocked()
        self.assertEqual(self.store.q('SELECT * FROM chunk_proofs'), [])

    def test_supervisor_failure_quarantines_even_with_success_stdout(self):
        self.register(); self.fixture.terminal(); self.terminal(exit=1)
        self.worker.tick()
        self.assertEqual(self.store.one('SELECT * FROM batch_runs')['status'], 'quarantined')

    def test_corrupt_registered_roots_block_without_moving_outputs(self):
        self.register(); self.boot.return_value='reboot'
        self.store.x("UPDATE batch_runs SET receipts='/tmp/unrelated'")
        with self.assertRaises(ProverError): self.worker.tick()
        self.assert_blocked()
        self.assertTrue(all(Path(r['out']).exists() for r in self.fixture.manifest['jobs']))

    def test_quarantine_recovery_is_idempotent_and_never_requeues(self):
        self.register(); self.boot.return_value='reboot'
        self.worker.tick(); self.worker.tick()
        self.assertEqual(self.store.one('SELECT * FROM batch_runs')['status'], 'quarantined')
        self.prover.start.assert_not_called()
        self.assertTrue(all(r['status']=='failed' for r in self.store.q('SELECT * FROM jobs')))


if __name__ == '__main__': unittest.main()

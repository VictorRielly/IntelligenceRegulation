"""R18-1 crash recovery and quarantine publication boundary controls."""
import json
from pathlib import Path
import unittest
from unittest.mock import patch

import batch_queue_gate as gate
import batch_request as batch
import test_batch_request as fixture_module
from proven_media.provers import ProverError


class QueueGateTests(unittest.TestCase):
    def setUp(self):
        self.fixture=fixture_module.BatchTests();self.fixture.setUp();self.addCleanup(self.fixture.doCleanups)
        self.fixture.job=self.fixture.private/'test-post'/'batch'
        self.fixture.job.parent.mkdir(mode=0o700)
        self.manifest=self.fixture.prepare(17)
        self.job=self.fixture.job;self.receipts=self.fixture.receipts
        self.plan=batch.proof_plans.category_work_plan(17,batch.runtime.templates())
        self.context=batch.records.screening_context()
        self.logs=self.job/'logs';self.logs.mkdir(mode=0o700)
        for row in self.manifest['jobs']:
            for key in ('out','owner_dir'):
                p=Path(row[key]);p.mkdir(parents=True);(p/'retained').write_text('test fixture')

    def terminal(self,events=None,guard=None):
        events=self.frozen_events()[:-1] if events is None else events
        (self.logs/'prove-batch.log').write_text(self.fixture.stream(events))
        (self.logs/'prove-batch.guard.done').write_text('0\n')
        (self.logs/'prove-batch.guard.json').write_text(json.dumps(guard or {'exit':0,'child_rc':0}))

    def recover(self,**kwargs):
        return gate.recover_batch(self.job,self.receipts,post_id='test-post',reserved_plan=self.plan,
            reserved_context=self.context,terminal_confirmed=kwargs.get('terminal_confirmed',True))

    def test_crash_missing_terminal_evidence_quarantines_before_retry(self):
        result=self.recover()
        self.assertEqual(result['status'],'quarantined')
        self.assertFalse(result['publication_allowed']);self.assertFalse(result['retry_allowed'])
        self.assertTrue(all(not Path(row['out']).exists() for row in self.manifest['jobs']))

    def test_complete_looking_prefix_without_batch_proved_quarantines(self):
        self.terminal(self.frozen_events()[:-2])
        self.assertEqual(self.recover()['status'],'quarantined')

    def test_success_always_uses_terminal_collector_and_stays_unverified(self):
        self.terminal()
        with patch.object(gate,'collect_batch_result',wraps=batch.collect_batch_result) as collect:
            result=self.recover()
        collect.assert_called_once()
        self.assertEqual(result['status'],'unverified');self.assertFalse(result['publication_allowed'])
        self.assertTrue(all(Path(row['out']).exists() for row in self.manifest['jobs']))

    def test_guard_kill_with_success_stdout_still_quarantines(self):
        self.terminal(guard={'exit':75,'child_rc':-15,'guard_killed':'host drive low'})
        self.assertEqual(self.recover()['status'],'quarantined')

    def test_unknown_or_live_child_blocks_without_moving_receipts(self):
        with self.assertRaises(ProverError):self.recover(terminal_confirmed=False)
        self.assertTrue(all(Path(row['out']).exists() for row in self.manifest['jobs']))

    def test_corrupted_request_cleans_only_original_scope(self):
        (self.job/'batch-request.json').write_text('partial JSON')
        self.assertEqual(self.recover()['status'],'quarantined')
        self.assertTrue((self.job/'failed-batch-owners/c0-owner/retained').exists())

    def test_quarantine_is_restartable_and_success_cannot_resurrect_it(self):
        self.recover();self.terminal()
        self.assertEqual(self.recover()['status'],'quarantined')
        self.assertTrue((self.job/'failed-batch-owners/c0-owner/retained').exists())

    def test_modified_cleanup_root_blocks_without_touching_foreign_paths(self):
        p=self.job/'cleanup-scope.json';scope=json.loads(p.read_text())
        other=self.fixture.root/'unrelated';other.mkdir()
        scope['receipts']=str(other);p.write_text(json.dumps(scope))
        with self.assertRaises(ProverError):self.recover()
        self.assertEqual(list(other.iterdir()),[])

    def test_publication_rejects_direct_and_symlink_quarantine_paths(self):
        self.recover();target=next((self.receipts/'.batch-quarantine').iterdir())/'c0-run/retained'
        alias=self.fixture.root/'alias';alias.symlink_to(target)
        for p in (target,alias):
            with self.subTest(path=p),self.assertRaises(ProverError):gate.reject_quarantined_source(p)
        gate.reject_quarantined_source(self.receipts/'ordinary-run/segment.bin')

    def frozen_events(self):
        source=batch.REPO/'results/zk60_token_io_r1_20261017/r18/logs/eq/batch.log'
        events=[json.loads(line) for line in source.read_text().splitlines() if line.strip()]
        # The entropy harness appends its own event after native stdout. It is
        # test-only instrumentation, never part of the production CLI stream.
        self.assertEqual(events[-1]['event'],'fixed-entropy')
        index=None
        for e in events:
            if e['event']=='batch-job-start':index=e['index']
            if e['event']=='proved':
                e['run']=self.manifest['jobs'][index]['out']
                e['owner_dir']=self.manifest['jobs'][index]['owner_dir']
        return events

    def test_frozen_r18_native_payloads_pass_transport_only(self):
        self.terminal(self.frozen_events()[:-1])
        self.assertEqual(self.recover()['status'],'unverified')

    def test_harness_or_other_trailing_events_are_not_accepted_as_production(self):
        self.terminal(self.frozen_events())
        self.assertEqual(self.recover()['status'],'quarantined')


if __name__=='__main__':unittest.main()

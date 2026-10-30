import copy
from dataclasses import asdict
import json
import os
from pathlib import Path
import unittest

import batch_request as batch
from batch_cleanup import CleanupScope, quarantine
import test_batch_request as fixtures
from proven_media.provers import ProverError


class CleanupTests(unittest.TestCase):
    def setUp(self):
        self.fixture = fixtures.BatchTests()
        self.fixture.setUp(); self.addCleanup(self.fixture.doCleanups)
        self.m = self.fixture.prepare()
        self.scope = CleanupScope(**json.loads((self.fixture.job / 'cleanup-scope.json').read_text()))
        self.good_log = self.fixture.stream(self.fixture.recorded_log(self.m))
        self.guard = {'exit': 0, 'child_rc': 0, 'guard_killed': None, 'refused': None}

    def populate(self):
        for _, path, kind in self.scope.paths():
            path.mkdir()
            (path / ('input.dec' if kind == 'owner' else 'part.bin')).write_bytes(b'private-test-fixture')

    def finish(self, log=None, rc=0, guard=None):
        return batch.collect_batch_result(self.good_log if log is None else log, rc, self.m, 35,
                                          self.guard if guard is None else guard, self.scope, terminal_confirmed=True)

    def test_missing_terminal_event_quarantines_every_path_and_opening(self):
        self.populate()
        with self.assertRaises(ProverError): self.finish(log='')
        self.assertTrue(all(not os.path.lexists(p) for _, p, _ in self.scope.paths()))
        report = json.loads((self.fixture.job / 'failed-batch-quarantine.json').read_text())
        self.assertTrue(report['complete']); self.assertFalse(report['publication_allowed'])
        self.assertEqual(len(report['moves']), 12)
        for moved in report['moves']:
            self.assertTrue(Path(moved['destination']).is_dir())
        for i in range(3):
            self.assertTrue((self.fixture.job / 'failed-batch-owners' / f'c{i}-owner/input.dec').is_file())

    def test_guard_failure_cannot_be_hidden_by_complete_stdout(self):
        for field, value in [('exit', 137), ('child_rc', 137), ('guard_killed', 'memory'), ('refused', 'admission'),
                             ('guard_error', 'watchdog'), ('hard_killed', 1), ('stragglers_killed', 1)]:
            g = {**self.guard, field: value}
            with self.assertRaises(ProverError): self.finish(guard=g)

    def test_bad_guard_shape_or_boolean_exit_refused(self):
        for g in ({}, [], {**self.guard, 'exit': False}, {**self.guard, 'child_rc': None}):
            with self.assertRaises(ProverError): self.finish(guard=g)

    def test_clean_completion_remains_unverified(self):
        self.populate()
        result = self.finish()
        self.assertEqual(result['status'], 'unverified')
        self.assertTrue(all(p.exists() for _, p, _ in self.scope.paths()))
        self.assertFalse((self.fixture.job / 'failed-batch-quarantine.json').exists())

    def test_nonterminal_child_is_never_cleaned_up(self):
        self.populate()
        with self.assertRaises(ProverError):
            batch.collect_batch_result('', 137, self.m, 35, {}, self.scope, terminal_confirmed=False)
        self.assertTrue(all(p.exists() for _, p, _ in self.scope.paths()))

    def test_recovery_is_idempotent_after_some_moves(self):
        self.populate()
        quarantine(self.scope, terminal_confirmed=True)
        restored_scope = CleanupScope(**asdict(self.scope))
        result = quarantine(restored_scope, terminal_confirmed=True)
        self.assertTrue(result['complete'])
        self.assertTrue(all(row['status'] == 'already-quarantined' for row in result['moves']))

    def test_symlink_output_is_moved_without_following_target(self):
        target = self.fixture.root / 'untouched'; target.mkdir(); (target / 'safe').write_text('retain')
        Path(self.m['jobs'][0]['out']).symlink_to(target, target_is_directory=True)
        quarantine(self.scope, terminal_confirmed=True)
        self.assertEqual((target / 'safe').read_text(), 'retain')
        self.assertFalse(os.path.lexists(self.m['jobs'][0]['out']))

    def test_changed_request_cleans_original_scope_only(self):
        self.populate()
        other = self.fixture.root / 'unrelated'; other.mkdir(); (other / 'safe').write_text('retain')
        self.m['jobs'][0]['out'] = str(other)
        with self.assertRaises(ProverError): self.finish()
        self.assertTrue((other / 'safe').exists())
        self.assertTrue(all(not os.path.lexists(p) for _, p, _ in self.scope.paths()))

    def test_scope_cannot_claim_arbitrary_paths(self):
        changed = copy.deepcopy(self.m); changed['jobs'][0]['out'] = str(self.fixture.root / 'unrelated')
        with self.assertRaises(ProverError):
            batch.cleanup_scope(changed, 35, 'test-post', self.fixture.job, self.fixture.receipts)

    def test_cleanup_error_blocks_result_and_other_moves_continue(self):
        self.populate()
        public_base = self.fixture.receipts / '.batch-quarantine'; public_base.mkdir(mode=0o700)
        q = public_base / (self.scope.post_id + '-' + self.scope.manifest_sha256[:16]); q.mkdir(mode=0o700)
        (q / 'c0-run').mkdir()
        with self.assertRaises(ProverError): self.finish(log='')
        result = json.loads((self.fixture.job / 'failed-batch-quarantine.json').read_text())
        self.assertFalse(result['complete']); self.assertFalse(result['publication_allowed'])
        self.assertTrue(Path(self.m['jobs'][0]['out']).exists())
        self.assertFalse(Path(self.m['jobs'][2]['owner_dir']).exists())


if __name__ == '__main__':
    unittest.main()

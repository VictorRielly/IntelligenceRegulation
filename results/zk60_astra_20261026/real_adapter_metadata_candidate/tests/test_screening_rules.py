import json
from pathlib import Path
import tempfile
import threading
import unittest
from unittest.mock import patch

from proven_media import config, records
from proven_media.store import ScreeningConflict, Store


class ScreeningRules(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        self.private = patch.object(config, 'PRIVATE_DIR', self.root)
        self.private.start()
        self.store = Store(self.root / 'app.sqlite3')
        self.plan = [{'index': 0, 'start': 0, 'end': 10}]

    def tearDown(self):
        self.store.db.close()
        self.private.stop()
        self.directory.cleanup()

    def submit(self, pid='first', store=None):
        (store or self.store).add_screened_post('The same item', self.plan, id=pid, author='@author',
            kind='text', text='The same item', status='queued', content_key=records.content_key('The same item'),
            chunks=json.dumps(self.plan))

    def test_changed_policy_or_threshold_never_creates_another_query(self):
        self.submit()
        categories = [dict(c) for c in config.CATEGORIES]
        categories[0]['policy_id'] = 'changed-policy'
        for field, value in (('TAU', 0.75), ('CATEGORY_SET_ID', 'new-set'), ('CATEGORIES', categories)):
            with self.subTest(field=field), patch.object(config, field, value):
                with self.assertRaises(ScreeningConflict):
                    self.submit('second')
                with self.assertRaises(ScreeningConflict):
                    self.store.check_screening(self.store.post('first'))
        self.assertEqual(len(self.store.q('SELECT * FROM posts')), 1)
        self.assertEqual(len(self.store.q('SELECT * FROM jobs')), 1)

    def test_deleted_item_reservation_survives_restart(self):
        self.submit()
        self.store.update_post('first', status='deleted', text=None, content_key=None)
        self.store.db.close()
        self.store = Store(self.root / 'app.sqlite3')
        with self.assertRaises(ScreeningConflict):
            self.submit('after-delete')
        claim = self.store.one('SELECT * FROM screenings')
        self.assertNotIn('The same item', str(claim))
        with patch.object(config, 'TAU', 0.9), self.assertRaises(ScreeningConflict):
            self.submit('changed-after-delete')

    def test_retry_only_before_work_under_same_context(self):
        self.submit()
        self.store.update_post('first', status='failed', prove_attempted=0)
        self.store.x("UPDATE jobs SET status='failed'")
        with patch.object(config, 'TAU', 0.9), self.assertRaises(ScreeningConflict):
            self.submit('changed-retry')
        self.submit('retry')
        self.store.check_screening(self.store.post('retry'))
        with self.assertRaises(ScreeningConflict):
            self.store.check_screening(self.store.post('first'))
        self.store.update_post('retry', status='failed', prove_attempted=1)
        with self.assertRaises(ScreeningConflict):
            self.submit('after-work')

    def test_concurrent_submissions_reserve_once_across_connections(self):
        records.screening_key('text', 'initialize the private key')
        other = Store(self.root / 'app.sqlite3')
        barrier = threading.Barrier(2)
        outcomes = []
        def submit(pid, store):
            barrier.wait()
            try:
                self.submit(pid, store)
                outcomes.append('created')
            except ScreeningConflict:
                outcomes.append('refused')
        threads = [threading.Thread(target=submit, args=('one', self.store)),
                   threading.Thread(target=submit, args=('two', other))]
        for t in threads: t.start()
        for t in threads: t.join(10)
        other.db.close()
        self.assertFalse(any(t.is_alive() for t in threads))
        self.assertCountEqual(outcomes, ['created', 'refused'])
        self.assertEqual(len(self.store.q('SELECT * FROM jobs')), 1)

    def test_retained_legacy_text_is_migrated_without_changing_its_policy(self):
        text = 'The same item'
        self.store.add_post(id='legacy', author='@old', kind='text', text=text, status='queued',
                            content_key=records.content_key(text))
        self.store.db.close()
        self.store = Store(self.root / 'app.sqlite3')
        self.store.check_screening(self.store.post('legacy'))
        with self.assertRaises(ScreeningConflict):
            self.submit('duplicate')

    def test_unresolved_legacy_policy_is_not_rebound_to_current_settings(self):
        self.store.add_post(id='legacy', author='@old', kind='text', text='The same item', status='queued',
                            content_key='unknown old policy')
        self.store.db.close()
        self.store = Store(self.root / 'app.sqlite3')
        with self.assertRaises(ScreeningConflict):
            self.store.check_screening(self.store.post('legacy'))
        with self.assertRaises(ScreeningConflict):
            self.submit('duplicate')

    def test_legacy_early_failure_does_not_hide_a_later_proof(self):
        for pid, status, attempted in (('early', 'failed', 0), ('later', 'published', 1)):
            self.store.add_post(id=pid, author='@old', kind='text', text='The same item', status=status,
                                prove_attempted=attempted, content_key=records.content_key('The same item'))
        self.store.db.close()
        self.store = Store(self.root / 'app.sqlite3')
        self.assertEqual(self.store.one('SELECT * FROM screenings')['post_id'], 'later')
        with self.assertRaises(ScreeningConflict):
            self.submit('third-query')


if __name__ == '__main__':
    unittest.main()

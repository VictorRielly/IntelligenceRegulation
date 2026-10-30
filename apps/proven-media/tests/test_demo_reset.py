import fcntl
import json
import os
from pathlib import Path
import sqlite3
import tempfile
import unittest
from unittest.mock import patch

from proven_media import config, demo_reset, hardware_profiles, records
from proven_media.provers import ProverError
from proven_media.store import Store, ScreeningConflict


class ResetTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='pm-reset-test-')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.private, self.public = self.root / 'private', self.root / 'public'
        self.private.mkdir(mode=0o700); self.public.mkdir()
        self.env = patch.object(config, 'PRIVATE_DIR', self.private)
        self.env.start(); self.addCleanup(self.env.stop)
        self.store = Store(self.private / 'app.sqlite3')
        self.addCleanup(self.store.db.close)
        self.store.add_screened_post('finished demo content', id='finished', author='@demo', kind='text',
                                    text='finished demo content', status='published', prove_attempted=1)
        self.job = self.store.add_job('finished', 'prove')
        self.store.update_job(self.job, status='done')
        (self.private / 'wallet-sentinel.json').write_text('keep private configuration')
        self.before_reservations = self.store.q('SELECT * FROM screenings')

    def test_preview_is_read_only(self):
        before = self.store.q('SELECT * FROM posts')
        result = demo_reset.preview(self.private, self.public)
        self.assertTrue(result['ready'])
        self.assertEqual(result['counts']['posts'], 1)
        self.assertEqual(self.store.q('SELECT * FROM posts'), before)
        self.assertFalse((self.private / 'demo-archives').exists())

    def test_reset_archives_and_preserves_reservation_keys_and_files(self):
        key_files = {p: p.read_bytes() for p in self.private.iterdir() if p.is_file() and p.suffix != '.sqlite3'}
        receipt = self.public / 'receipt.bin'; receipt.write_bytes(b'retained receipt')
        result = demo_reset.reset(self.private, self.public)
        self.assertTrue(result['reset'])
        self.assertEqual(self.store.q('SELECT * FROM posts'), [])
        self.assertEqual(self.store.q('SELECT * FROM jobs'), [])
        self.assertEqual(self.store.q('SELECT * FROM screenings'), self.before_reservations)
        with sqlite3.connect(result['archive']) as archive:
            self.assertEqual(archive.execute('SELECT text FROM posts').fetchone()[0], 'finished demo content')
            self.assertEqual(archive.execute('SELECT COUNT(*) FROM screenings').fetchone()[0], 1)
        self.assertEqual(Path(result['archive']).stat().st_mode & 0o777, 0o600)
        self.assertEqual(Path(result['archive']).parent.stat().st_mode & 0o777, 0o700)
        self.assertEqual(receipt.read_bytes(), b'retained receipt')
        for p, content in key_files.items():
            if not p.name.startswith('app.sqlite3-'):
                self.assertEqual(p.read_bytes(), content)

    def test_reset_does_not_allow_second_screening(self):
        demo_reset.reset(self.private, self.public)
        with self.assertRaises(ScreeningConflict):
            self.store.add_screened_post('finished demo content', id='retry', author='@another', kind='text',
                                        text='finished demo content', status='queued', prove_attempted=0)
        self.assertEqual(self.store.q('SELECT * FROM posts'), [])

    def test_pending_jobs_refuse_without_archiving_or_withdrawing(self):
        for state in ('queued', 'running'):
            self.store.update_job(self.job, status=state)
            self.assertFalse(demo_reset.preview(self.private, self.public)['ready'])
            with self.assertRaises(demo_reset.ResetRefused): demo_reset.reset(self.private, self.public)
            self.assertEqual(self.store.job(self.job)['status'], state)
        self.assertFalse((self.private / 'demo-archives').exists())

    def test_screening_post_refused_even_if_queue_is_terminal(self):
        self.store.update_post('finished', status='screening')
        with self.assertRaises(demo_reset.ResetRefused): demo_reset.reset(self.private, self.public)

    def test_unanchored_or_inflight_publisher_refused(self):
        chain = self.public / 'base-sepolia/chain'; chain.mkdir(parents=True)
        for filename in ('pending.jsonl', 'inflight.json'):
            p = chain / filename; p.write_text('{}\n')
            with self.assertRaises(demo_reset.ResetRefused): demo_reset.reset(self.private, self.public)
            self.assertIsNotNone(self.store.post('finished'))
            p.unlink()

    def test_busy_publisher_refused(self):
        chain = self.public / 'chain'; chain.mkdir()
        with (chain / '.lock').open('w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            with self.assertRaises(demo_reset.ResetRefused): demo_reset.reset(self.private, self.public)

    def test_busy_database_refused(self):
        self.store.db.execute('BEGIN IMMEDIATE')
        try:
            with self.assertRaises(demo_reset.ResetRefused): demo_reset.reset(self.private, self.public)
        finally:
            self.store.db.execute('ROLLBACK')
        self.assertIsNotNone(self.store.post('finished'))

    def test_publisher_parent_symlink_escape_refused(self):
        (self.public / 'base-sepolia').symlink_to(self.private, target_is_directory=True)
        with self.assertRaises(demo_reset.ResetRefused): demo_reset.reset(self.private, self.public)

    def test_missing_detached_completion_refused(self):
        job = self.private / 'jobs/finished/prove'; job.mkdir(parents=True)
        self.store.update_job(self.job, job_dir=str(job))
        with self.assertRaises(demo_reset.ResetRefused): demo_reset.reset(self.private, self.public)
        (job / 'pipeline.done').write_text('not finished\n')
        with self.assertRaises(demo_reset.ResetRefused): demo_reset.reset(self.private, self.public)
        (job / 'pipeline.done').write_text('0\n')
        self.assertTrue(demo_reset.reset(self.private, self.public)['reset'])

    def test_archive_symlink_refused(self):
        (self.private / 'demo-archives').symlink_to(self.public, target_is_directory=True)
        with self.assertRaises(demo_reset.ResetRefused): demo_reset.reset(self.private, self.public)
        self.assertIsNotNone(self.store.post('finished'))
        self.assertFalse(any(self.public.iterdir()))

    def test_reservation_trigger_rolls_back_reset(self):
        self.store.x('CREATE TRIGGER bad_reset AFTER DELETE ON posts BEGIN DELETE FROM screenings; END')
        with self.assertRaises(demo_reset.ResetRefused): demo_reset.reset(self.private, self.public)
        self.assertIsNotNone(self.store.post('finished'))
        self.assertEqual(self.store.q('SELECT * FROM screenings'), self.before_reservations)

    def test_second_reset_is_noop(self):
        demo_reset.reset(self.private, self.public)
        before = list((self.private / 'demo-archives').iterdir())
        self.assertTrue(demo_reset.reset(self.private, self.public)['already_empty'])
        self.assertEqual(list((self.private / 'demo-archives').iterdir()), before)


class HardwareTests(unittest.TestCase):
    def test_checked_laptop_profile(self):
        result = hardware_profiles.classifier_profile()
        self.assertEqual(result['category_geometry']['hate']['chunk_tokens'], 49)
        self.assertEqual(result['max_content_tokens'], 336)
        self.assertEqual(result['device'], 'cpu')
        self.assertTrue(result['validated_against_runtime'])

    def test_geometry_resources_identity_and_boolean_floor_refused(self):
        for key, value in [('context_tokens', 256), ('min_bits', True), ('binary_sha256', '0' * 64),
                           ('guard_resources', {}), ('category_geometry', {})]:
            with tempfile.TemporaryDirectory() as tmp:
                data = json.loads(config.DEPLOY_FILE.read_text())
                data['classifier_profiles']['shieldstral-laptop'][key] = value
                path = Path(tmp) / 'deploy.json'; path.write_text(json.dumps(data))
                with self.assertRaises(ProverError): hardware_profiles.classifier_profile(path)


if __name__ == '__main__':
    unittest.main()

"""P7/P8 authorization and disclosure regression tests. Fake prover only."""
import json
from pathlib import Path
import secrets
import sqlite3
import stat
import tempfile
import unittest
from unittest.mock import patch

import test_app  # shared isolated fake-prover configuration, before app imports
from fastapi.testclient import TestClient
from proven_media import app, auth, config
from proven_media.jobs import Worker


class CredentialTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / 'private' / 'auth.sqlite3'
        self.auth = auth.AuthorAuth(self.path)

    def test_only_hashes_stored_and_private_permissions(self):
        key = self.auth.provision('alice')
        token, session = self.auth.login(key)
        self.assertEqual(session.author, '@alice')
        self.assertFalse(session.operator)
        self.assertEqual(stat.S_IMODE(self.path.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(self.path.parent.stat().st_mode), 0o700)
        data = self.path.read_bytes()
        self.assertNotIn(key.encode(), data)
        self.assertNotIn(token.encode(), data)
        self.assertIsNone(self.auth.login('alice'))
        self.assertIsNone(self.auth.login(secrets.token_urlsafe(32)))
        self.assertIsNone(self.auth.session(secrets.token_urlsafe(32)))

    def test_rotation_revokes_old_key_and_sessions(self):
        key = self.auth.provision('alice', operator=True)
        token, session = self.auth.login(key)
        self.assertTrue(session.operator)
        with self.assertRaises(ValueError): self.auth.provision('alice')
        new = self.auth.provision('alice', rotate=True)
        self.assertIsNone(self.auth.login(key))
        self.assertIsNone(self.auth.session(token))
        self.assertIsNotNone(self.auth.login(new))

    def test_expiry_logout_and_unique_sessions(self):
        key = self.auth.provision('alice')
        token, session = self.auth.login(key)
        other, second = self.auth.login(key)
        self.assertNotEqual(token, other)
        self.assertNotEqual(session.csrf, second.csrf)
        self.auth.logout(token)
        self.assertIsNone(self.auth.session(token))
        self.assertIsNotNone(self.auth.session(other))
        with patch('proven_media.auth.time.time', return_value=10**12):
            self.assertIsNone(self.auth.session(other))

    def test_symlink_db_refused_without_touching_target(self):
        target = self.path.parent / 'target'
        target.write_text('do not change')
        link = self.path.parent / 'link'
        link.symlink_to(target)
        with self.assertRaises(OSError): auth.AuthorAuth(link)
        self.assertEqual(target.read_text(), 'do not change')


class PrivacyRoutes(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.context = TestClient(app.app)
        cls.context.__enter__()
        cls.keys = {name: app.S.auth.provision(name, operator=name == 'auth_operator', rotate=True)
                    for name in ('auth_alice', 'auth_bob', 'auth_operator')}

    @classmethod
    def tearDownClass(cls):
        cls.context.__exit__(None, None, None)

    def setUp(self):
        self.client = TestClient(app.app)
        self.guest = TestClient(app.app)
        self.addCleanup(self.client.close)
        self.addCleanup(self.guest.close)

    def sign_in(self, name='auth_alice', client=None):
        client = client or self.client
        r = client.post('/api/session', json={'access_key': self.keys[name]})
        self.assertEqual(r.status_code, 200, r.text)
        client.headers['X-PM-CSRF'] = r.json()['csrf']
        return r

    def submit(self):
        self.sign_in()
        secret = 'Private fixture ' + secrets.token_hex(12)
        r = self.client.post('/api/posts', data={'author': 'auth_alice', 'text': secret})
        self.assertEqual(r.status_code, 200, r.text)
        return r.json()['post_id'], secret

    def drain(self):
        worker = Worker(app.S.store, app.S.prover, app.S.publisher)
        for _ in range(15): worker.tick()

    def test_handle_query_and_forged_cookie_cannot_read_unpublished(self):
        pid, secret = self.submit()
        self.sign_in('auth_bob', self.guest)
        for status in ('queued', 'screening', 'failed', 'in-development', 'deleted'):
            app.S.store.update_post(pid, status=status, status_message='layer 7 chunk 3 input overflow')
            anon = TestClient(app.app)
            self.addCleanup(anon.close)
            for client in (self.guest, anon):
                for query in ('', '?author=auth_alice', '?author=@auth_alice'):
                    r = client.get('/api/posts/' + pid + query)
                    self.assertEqual(r.status_code, 404, r.text)
                    self.assertNotIn(secret, r.text)
                    self.assertEqual(r.json(), {'detail': 'no such post'})
        self.guest.cookies.clear()
        self.guest.cookies.set(auth.COOKIE, '@auth_alice')
        self.assertEqual(self.guest.get('/api/posts/' + pid).status_code, 404)

    def test_submissions_require_real_author_and_ignore_claims(self):
        pid, secret = self.submit()
        self.assertEqual(self.guest.get('/api/submissions?author=auth_alice').status_code, 401)
        self.sign_in('auth_bob', self.guest)
        self.assertEqual(self.guest.get('/api/submissions?author=auth_alice').status_code, 403)
        self.assertNotIn(secret, self.guest.get('/api/submissions').text)
        own = self.client.get('/api/submissions').json()['posts']
        self.assertEqual(next(p['text'] for p in own if p['id'] == pid), secret)

    def test_failure_exact_one_bit_even_with_stale_manifest_and_record(self):
        pid, secret = self.submit()
        app.S.store.update_post(pid, status='failed', status_message='chunk 2 category hate layer 17 attempt 3',
            record=json.dumps({'timings': {'work_s': 123}, 'chunks': [{'error': 'overflow'}]}),
            manifest=json.dumps({'private': secret}))
        expected = {'id': pid, 'status': 'failed', 'status_message': 'Could not be verified.'}
        self.assertEqual(self.client.get('/api/posts/' + pid).json(), expected)
        own = self.client.get('/api/submissions').json()['posts']
        self.assertEqual(next(p for p in own if p['id'] == pid), expected)
        for client in (self.client, self.guest):
            for suffix in ('manifest.json', 'record.json', 'bundle.tar', 'canvas.png'):
                self.assertEqual(client.get(f'/api/posts/{pid}/{suffix}?author=auth_alice').status_code, 404)
            for suffix in ('verify-manifest', 'verify-publication'):
                self.assertEqual(client.post(f'/api/posts/{pid}/{suffix}').status_code, 404)
        for audience in ('minor', 'adult'):
            self.assertNotIn(pid, [p['id'] for p in self.guest.get('/api/feed?audience=' + audience).json()['posts']])

    def test_pending_owner_has_text_without_partial_results(self):
        pid, secret = self.submit()
        for status in ('queued', 'screening'):
            app.S.store.update_post(pid, status=status)
            p = self.client.get('/api/posts/' + pid).json()
            self.assertEqual(p, {'id': pid, 'status': 'pending', 'author': '@auth_alice', 'kind': 'text',
                                 'text': secret, 'status_message': 'Verification pending.'})

    def test_submission_requires_session_matching_author_and_csrf(self):
        data = {'author': 'auth_alice', 'text': 'never submitted ' + secrets.token_hex(6)}
        self.assertEqual(self.client.post('/api/posts', data=data).status_code, 401)
        self.sign_in('auth_bob')
        self.assertEqual(self.client.post('/api/posts', data=data).status_code, 403)
        self.sign_in()
        self.client.headers.pop('X-PM-CSRF')
        self.assertEqual(self.client.post('/api/posts', data=data).status_code, 403)
        self.assertEqual(self.client.post('/api/tokenize', json={'text': 'private'}).status_code, 403)
        self.assertFalse(app.S.store.q('SELECT id FROM posts WHERE text=?', (data['text'],)))

    def test_foreign_origin_and_non_json_login_refused(self):
        self.assertEqual(self.client.post('/api/session', data={'access_key': self.keys['auth_alice']}).status_code, 415)
        self.assertEqual(self.client.post('/api/session', json={'access_key': self.keys['auth_alice']},
            headers={'Origin': 'https://foreign.invalid'}).status_code, 403)
        self.assertEqual(self.client.post('/api/session', json={'access_key': 'x' * 2000}).status_code, 413)
        self.sign_in()
        self.assertEqual(self.client.delete('/api/session', headers={'Origin': 'https://foreign.invalid'}).status_code, 403)

    def test_session_cookie_and_cache_policy(self):
        r = self.sign_in()
        cookie = r.headers['set-cookie'].lower()
        self.assertIn('httponly', cookie)
        self.assertIn('samesite=strict', cookie)
        self.assertIn('path=/', cookie)
        self.assertEqual(r.headers['cache-control'], 'no-store')
        self.assertEqual(r.headers['vary'], 'Cookie')
        self.assertEqual(self.client.get('/api/session').json()['author'], '@auth_alice')
        token = self.client.cookies.get(auth.COOKIE)
        self.assertEqual(self.client.delete('/api/session').status_code, 200)
        self.client.cookies.set(auth.COOKIE, token)
        self.assertIsNone(self.client.get('/api/session').json()['author'])
        secure = TestClient(app.app, base_url='https://testserver')
        self.addCleanup(secure.close)
        r = self.sign_in(client=secure)
        self.assertIn('secure', r.headers['set-cookie'].lower())

    def test_queue_status_and_batch_close_are_operator_only(self):
        for path in ('/api/queue', '/api/status'):
            self.assertEqual(self.client.get(path).status_code, 401)
        self.sign_in()
        for path in ('/api/queue', '/api/status'):
            self.assertEqual(self.client.get(path).status_code, 403)
        self.assertEqual(self.client.post('/api/ledger/close-batch').status_code, 403)
        self.sign_in('auth_operator')
        self.assertEqual(self.client.get('/api/status').status_code, 200)

    def test_other_author_cannot_delete_or_recheck(self):
        pid, secret = self.submit()
        self.sign_in('auth_bob', self.guest)
        self.assertEqual(self.guest.delete('/api/posts/' + pid + '?author=auth_alice').status_code, 404)
        self.assertEqual(self.guest.post('/api/posts/' + pid + '/verify').status_code, 404)
        self.assertEqual(app.S.store.post(pid)['text'], secret)

    def test_public_records_strip_timings_recursively_without_mutating_operator_record(self):
        pid, _ = self.submit()
        self.drain()
        p = app.S.store.post(pid)
        self.assertEqual(p['status'], 'published')
        private = json.loads(p['record'])
        private['timings'] = {'work_s': 999}
        private['proved_at'] = 'sensitive-time'
        private['chunks'][0]['record']['timings'] = {'work_s': 111}
        private['chunks'][0]['record']['proved_at'] = 'another-time'
        app.S.store.update_post(pid, record=json.dumps(private))
        for suffix in ('', '/record.json'):
            r = self.guest.get('/api/posts/' + pid + suffix)
            self.assertEqual(r.status_code, 200)
            # The already signed manifest has its own documented timestamp fields.
            record = r.json().get('record') if not suffix else r.json()
            text = json.dumps(record)
            self.assertNotIn('timings', text)
            self.assertNotIn('proved_at', text)
        self.assertEqual(json.loads(app.S.store.post(pid)['record']), private)
        self.assertTrue(self.guest.post(f'/api/posts/{pid}/verify-manifest').json()['accepted'])


if __name__ == '__main__':
    unittest.main()

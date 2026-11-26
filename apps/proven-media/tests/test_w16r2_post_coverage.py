"""Whole-post decisions and ranges for differently sized category chunks."""
from copy import deepcopy
from contextlib import ExitStack
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import Mock, patch

from proven_media import config, manifest, proof_plans, records, shieldstral_fast_runtime as baseline
from proven_media import w16r2_runtime as w16
from proven_media.publisher import LocalChainPublisher, PublicationRecord

sys.path.insert(0, str(config.APP_DIR/'tools'))
from verify_manifest import verify_proofs


class PublicPostFixture(unittest.TestCase):
    def setUp(self):
        stack = ExitStack()
        self.addCleanup(stack.close)
        root = Path(stack.enter_context(tempfile.TemporaryDirectory()))
        stack.enter_context(patch.dict(os.environ, {'PM_PROVER':w16.KIND}))
        stack.enter_context(patch.object(config, 'SIGNING_KEY', root/'test-key'))
        self.publisher = LocalChainPublisher(root/'public')
        identity = w16.authority()
        descriptor = {'kind':w16.KIND, 'model_digest':identity['statement_identity'],
                      'token_profile_digest':w16.PROFILE_SHA, 'binary_sha256':identity['binary_sha256']}
        post = {'id':'ab'*16, 'kind':'text', 'created_at':'fixture'}
        plan = proof_plans.category_work_plan(99, baseline.templates())
        policies = {p['id']:p for p in baseline.categories()}
        chunks, anchors = [], {}
        segment = root/'segment-000.bin'
        segment.write_bytes(b'synthetic publication bytes')
        for ch in plan:
            i, cat = ch['index'], ch['category']
            value = 'yes' if i == 6 else 'no'
            statement = records.canonical({'fixture_chunk':i})
            record = {'prover':descriptor, 'statement_sha256':hashlib.sha256(statement).hexdigest(),
                      'labels':{cat:{'value':value,'proof':'accepted','bound_by_proof':True}}}
            chunks.append({**ch,'record':record})
            anchors[f'c{i}.{cat}'] = self.publisher.publish(PublicationRecord(
                post['id'],cat,statement,[segment],value,descriptor['model_digest'],policies[cat]['sha256'],
                w16.PROFILE_SHA,descriptor['binary_sha256'],'12'*32,chunk=i,token_range=(ch['start'],ch['end'])))
        self.publisher.tick(force=True)
        geometry = {'profile':'per-category','n_chunks':7,'categories':{
            t.category:{'chunk_tokens':t.chunk_size,'overlap_tokens':8,'chunks':3 if t.category=='hate' else 2}
            for t in baseline.templates()}}
        labels = {c:{'value':'yes' if c=='hate' else 'no','proof':'accepted'} for c in policies}
        self.signed = manifest.build_manifest(post, {'content_length':99,'chunks':chunks,'chunking':geometry,
                                                     'labels':labels}, anchors, {}, '12'*32)
        self.key = manifest.public_key_hex()


class WholePostTests(PublicPostFixture):
    def check(self, m):
        return manifest.verify_manifest(m, self.publisher, self.key)

    def test_standalone_cli_with_a_public_store_and_an_unproved_report(self):
        public = self.publisher.store.parent
        path = public/'downloaded-manifest.json'
        argv = [sys.executable, '-B', str(config.APP_DIR/'tools/verify_manifest.py'), str(path),
                '--public-dir', str(public), '--public-key', self.key, '--rehash']
        path.write_text(json.dumps(self.signed))
        env = dict(os.environ, PM_PROVER='stub', PM_PRIVATE_DIR=str(public.parent/'absent-owner'))
        good = subprocess.run(argv,capture_output=True,text=True,env=env,timeout=15,check=True)
        report = json.loads(good.stdout)
        self.assertTrue(report['checks']['w16r2_signed_post_coverage'])
        self.assertEqual(report['signed_post_coverage']['content_tokens'], 99)
        self.assertFalse(report['pending_anchor'])
        m = deepcopy(self.signed)
        m['entries'] = []
        m['labels'] = {cat:{'value':'unproved','proof':'none'} for cat in m['labels']}
        path.write_text(json.dumps(manifest.sign(m)))
        empty = subprocess.run(argv + ['--run-verifier'],capture_output=True,text=True,env=env,timeout=15)
        self.assertEqual(empty.returncode, 1)
        refused = json.loads(empty.stdout)
        self.assertFalse(refused['checks']['complete_post_proof_replay'])
        self.assertEqual(refused['proof_verifier_runs'], {})
        self.assertFalse((public.parent/'absent-owner').exists())

    def test_signed_coverage_and_verified_total(self):
        self.signed['entries'].reverse()
        m = manifest.sign(self.signed)
        report = self.check(m)
        self.assertTrue(report['accepted'], report['reasons'])
        self.assertEqual(report['signed_post_coverage']['planned_chunks'], 7)
        self.assertEqual(report['signed_post_coverage']['labels']['hate']['value'], 'yes')
        def evidence(pub, publication, pid):
            return {'ok':True,'content_tokens':99,'statement_sha256':publication['statement_sha256']}
        good = deepcopy(report)
        verify_proofs(m,self.publisher,good,evidence)
        self.assertTrue(good['checks']['complete_post_proof_replay'])
        def wrong_extent(pub, publication, pid):
            result = evidence(pub,publication,pid)
            if publication['chunk'] == 1:
                result['content_tokens'] = 98
            return result
        verify_proofs(m,self.publisher,report,wrong_extent)
        self.assertFalse(report['accepted'])
        self.assertFalse(report['checks']['c1.sexual.proved_post_extent'])
        self.assertFalse(report['checks']['complete_post_proof_replay'])

    def test_resigned_inconsistent_claims(self):
        changes = {
            'missing tail':lambda m:m['entries'].pop(),
            'repeated slot':lambda m:m['entries'][-1].update(chunk=0),
            'repeated statement':lambda m:m['entries'][-1].update(statement_sha256=m['entries'][0]['statement_sha256']),
            'switched policy':lambda m:m['entries'][0].update(policy_id=m['entries'][-1]['policy_id']),
            'crossed commitment':lambda m:m['entries'][0].update(content_commitment='14'*32),
            'different total':lambda m:m['item'].update(content_length_tokens=98),
            'boolean as index':lambda m:m['entries'][0].update(chunk=False),
            'false group count':lambda m:m['chunking']['categories']['hate'].update(chunks=2),
            'lost positive tail':lambda m:m['labels']['hate'].update(value='no'),
            'different inventory':lambda m:m['entries'][0]['bundle'].update(manifest_sha256='00'*32),
            'different set':lambda m:m['category_set'].update(id='another-set')}
        for name, change in changes.items():
            with self.subTest(name=name):
                value = deepcopy(self.signed)
                change(value)
                report = self.check(manifest.sign(value))
                self.assertTrue(report['checks']['signature'])
                self.assertFalse(report['accepted'])

    def test_explicitly_unproved_tail_cannot_finish_full_replay(self):
        m = deepcopy(self.signed)
        m['entries'][-1].update(verdict='unproved', proof_status='none', verdict_bound_by_proof=False,
                                statement_sha256=None, anchor=None, bundle=None)
        m['labels']['hate'] = {'value':'unproved','proof':'none'}
        m = manifest.sign(m)
        report = self.check(m)
        self.assertTrue(report['accepted'], report['reasons'])
        self.assertEqual(report['signed_post_coverage']['accepted_chunks'], 6)
        verify_proofs(m,self.publisher,report,lambda _, p, pid:{
            'ok':True,'statement_sha256':p['statement_sha256'],'content_tokens':99})
        self.assertFalse(report['accepted'])
        self.assertFalse(report['checks']['complete_post_proof_replay'])


class GuestDownloadTests(PublicPostFixture):
    def setUp(self):
        # A long post can straddle multiple ledger batches.
        with patch('proven_media.publisher.MAX_BATCH', 3):
            super().setUp()
            while self.publisher.pending_list():
                self.publisher.tick(force=True)
        from fastapi.testclient import TestClient
        from proven_media import app
        pid = self.signed['item']['post_id']
        self.url = f'/api/posts/{pid}/verification-store.tar'
        self.post = {'status':'published', 'manifest':json.dumps(self.signed)}
        stack = ExitStack()
        self.addCleanup(stack.close)
        stack.enter_context(patch.object(app.S, 'store', Mock(post=Mock(return_value=self.post)), create=True))
        stack.enter_context(patch.object(app.S, 'publisher', self.publisher, create=True))
        self.client = TestClient(app.app)
        self.addCleanup(self.client.close)

    def test_guest_download_is_a_standalone_store_for_this_post(self):
        pid = self.signed['item']['post_id']
        pub = self.publisher
        unrelated = pub.put_bytes(b'public object for a different post')
        # A later batch has its own receipts, anchor file and block.
        other = 'cd'*16
        entry = self.signed['entries'][0]
        fixture = pub.store.parent.parent/'segment-000.bin'
        pub.publish(PublicationRecord(other, 'sexual', b'{}', [fixture], 'yes', entry['model_id'],
                    entry['policy_sha256'], w16.PROFILE_SHA, entry['verifier_id'], '34'*32))
        pub.tick(force=True)
        dest = pub.store.parent.parent/'received'
        response = self.client.get(self.url)
        response.raise_for_status()
        raw = response.content
        self.assertEqual(int(response.headers['content-length']),len(raw))
        with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
            names = archive.getnames()
            self.assertEqual(len(names),len(set(names)))
            self.assertTrue(all(m.isfile() for m in archive.getmembers()))
            self.assertFalse(any(unrelated in n or other in n or 'pending.jsonl' in n for n in names))
            archive.extractall(dest,filter='data')
        bundle = dest/f'proven-media-{pid}'
        received = LocalChainPublisher(bundle/'public-store')
        self.assertEqual(len(received.blocks_list()),3)
        self.assertEqual(len(received.anchors_of(pid)),7)
        self.assertFalse(received.anchors_of(other))
        guide = (bundle/'VERIFY.md').read_text()
        command, = [line.strip() for line in guide.splitlines() if line.strip().endswith('--rehash')]
        env = dict(os.environ, PM_PUBLISHER_KEY=self.key, GUEST_APP_DIR=str(config.APP_DIR),
                   PM_PROVER='stub', PM_PRIVATE_DIR=str(dest/'absent-private'),
                   PATH=os.path.dirname(sys.executable)+os.pathsep+os.environ['PATH'])
        checked = subprocess.run(['/bin/sh','-c',command],cwd=bundle,env=env,capture_output=True,text=True,check=True)
        report = json.loads(checked.stdout)
        self.assertEqual(report['signed_post_coverage']['planned_chunks'],7)
        self.assertFalse(report['pending_anchor'])
        self.assertTrue(report['accepted'])
        digest = records.sha256_file(fixture)
        self.assertEqual(sum(n.endswith('/'+digest) for n in names),1)
        received._obj(digest).write_bytes(b'broken')
        failed = subprocess.run(['/bin/sh','-c',command],cwd=bundle,env=env,capture_output=True,text=True)
        self.assertEqual(failed.returncode,1)
        self.assertFalse(json.loads(failed.stdout)['accepted'])
        self.assertFalse((dest/'absent-private').exists())

    def test_verification_store_excludes_unpublished_posts_and_pending_batches(self):
        pid = self.signed['item']['post_id']
        self.post['status'] = 'pending'
        self.assertEqual(self.client.head(self.url).status_code, 404)
        self.post['status'] = 'published'
        anchor = self.publisher.anchor_of(pid,'sexual',0)
        anchor.status = 'pending'
        self.publisher._write_anchor(anchor)
        self.assertEqual(self.client.get(self.url, headers={'Range':'bytes=0-0'}).status_code, 409)

    def test_ranges_resume_exact_archive_bytes_across_tar_boundaries(self):
        original = self.client.get(self.url)
        raw, tag = original.content, original.headers['etag']
        head = self.client.head(self.url, headers={'Range':'bytes=0-0'})
        self.assertEqual((head.status_code, head.content), (200, b''))
        self.assertEqual(head.headers['content-length'], str(len(raw)))
        self.assertEqual(head.headers['accept-ranges'], 'bytes')
        self.assertEqual(head.headers['etag'], tag)
        pieces = []
        for start, stop in ((0, 511), (511, 515), (515, len(raw) - 1000), (len(raw) - 1000, len(raw))):
            value = f'bytes={start}-' if stop == len(raw) else f'bytes={start}-{stop-1}'
            response = self.client.get(self.url, headers={'Range':value, 'If-Range':tag})
            self.assertEqual(response.status_code, 206)
            self.assertEqual(response.headers['etag'], tag)
            self.assertEqual(response.headers['content-range'], f'bytes {start}-{stop-1}/{len(raw)}')
            self.assertEqual(int(response.headers['content-length']), len(response.content))
            pieces.append(response.content)
        self.assertEqual(b''.join(pieces), raw)
        suffix = self.client.get(self.url, headers={'Range':'bytes=-513'})
        self.assertEqual((suffix.status_code, suffix.content), (206, raw[-513:]))
        for value in (f'bytes={len(raw)}-', 'bytes=-0'):
            refused = self.client.get(self.url, headers={'Range':value})
            self.assertEqual((refused.status_code, refused.content), (416, b''))
            self.assertEqual(refused.headers['content-range'], f'bytes */{len(raw)}')
        for headers in ({'Range':'bytes=0-0', 'If-Range':'"previous"'},
                        {'Range':'bytes=0-0', 'If-Range':'W/'+tag}, {'Range':'bytes=0-1,4-5'}):
            full = self.client.get(self.url, headers=headers)
            self.assertEqual((full.status_code, full.content), (200, raw))
        self.assertEqual(self.client.get(self.url, headers={'If-None-Match':'W/'+tag}).status_code, 304)
        self.assertEqual(self.client.get(self.url, headers={'If-Match':'"previous"'}).status_code, 412)

    def test_a_changed_representation_invalidates_the_resume_token(self):
        from proven_media import public_store_download
        previous = self.client.head(self.url).headers['etag']
        members = public_store_download.store_members(self.publisher, self.signed['item']['post_id'], self.signed)
        name, _, size = members[-1]
        self.assertTrue(name.endswith('VERIFY.md'))
        members[-1] = (name, b'.' * size, size)
        with patch.object(public_store_download, 'store_members', return_value=members):
            response = self.client.get(self.url, headers={'Range':'bytes=-16', 'If-Range':previous})
        self.assertEqual(response.status_code, 200)
        self.assertNotEqual(response.headers['etag'], previous)

    def test_tail_range_skips_earlier_payload_files(self):
        from proven_media import tar_download
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            later = folder/'later'
            later.write_bytes(b'0123456789')
            # An attempted read of the first part would fail immediately.
            parts = [(folder/'absent', 10_000_000_000), (later, 10)]
            self.assertEqual(b''.join(tar_download._stream(parts, 10_000_000_003, 10_000_000_007)), b'3456')

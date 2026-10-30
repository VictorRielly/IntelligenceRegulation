"""Real-mode metadata must identify the reviewed category, model and verifier."""
import os
import asyncio
import io
import json
from pathlib import Path
import tarfile
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from proven_media import config, manifest, records, shieldstral_runtime as runtime


class RealManifestMetadata(unittest.TestCase):
    def setUp(self):
        mode = patch.dict(os.environ, {'PM_PROVER': 'shieldstral'})
        mode.start(); self.addCleanup(mode.stop)
        self.prover = {'kind': 'shieldstral', 'model_digest': runtime.IDENTITY,
                       'token_profile_digest': runtime.PROFILE_SHA, 'binary_sha256': runtime.BINARY_SHA}
        self.chunks = []
        for i, category in enumerate(runtime.categories()):
            record = {'prover': self.prover, 'statement_sha256': f'{i:064x}',
                      'labels': {category['id']: {'value': 'no', 'proof': 'accepted', 'bound_by_proof': True}}}
            self.chunks.append({'index': i, 'category_chunk_index': 0, 'category': category['id'],
                                'start': 0, 'end': 17, 'record': record})

    def test_signed_manifest_names_real_registered_policies_and_verifier(self):
        item = {'chunks': self.chunks, 'content_length': 17, 'labels': {}, 'proved_at': '2026-10-29T00:00:00Z'}
        post = {'id': 'fixture', 'kind': 'text', 'created_at': '2026-10-29T00:00:00Z'}
        with patch.object(manifest, 'sign', side_effect=lambda obj: obj):
            result = manifest.build_manifest(post, item, {}, {}, None)
        self.assertEqual(result['category_set']['id'], config.category_set_id())
        for entry, category in zip(result['entries'], runtime.categories()):
            self.assertEqual(entry['policy_id'], category['policy_id'])
            self.assertEqual(entry['policy_sha256'], category['sha256'])
            self.assertEqual(entry['verifier_id'], runtime.BINARY_SHA)
            self.assertTrue(entry['verdict_bound_by_proof'])

    def test_config_endpoint_names_real_policy_set_and_context(self):
        from proven_media import app
        with patch.object(app.S, 'prover', SimpleNamespace(describe=lambda: self.prover), create=True), \
             patch.object(app.S, 'publisher', SimpleNamespace(name='test',description='fixture'), create=True), \
             patch.object(manifest, 'public_key_hex', return_value='00'*32):
            cfg = app.api_config()
        self.assertEqual(cfg['category_set']['id'], config.category_set_id())
        self.assertEqual(cfg['limits']['T'], 128)
        self.assertEqual(cfg['deploy']['category_geometry']['hate']['chunk_tokens'], 49)
        self.assertFalse(cfg['deploy']['capped_by_prover'])

    def test_bundle_instructions_match_every_category_and_native_file_layout(self):
        from proven_media import app
        with tempfile.TemporaryDirectory() as tmp:
            chunks = []
            for i, category in enumerate(runtime.categories()):
                run = Path(tmp)/f'run-{i}'; (run/'statement').mkdir(parents=True)
                (run/'segment-000.bin').write_bytes(b'UNIT FIXTURE, NOT A PROOF')
                (run/'statement/statement.json').write_text('{}')
                rec = {**self.chunks[i]['record'], 'chunk': {'category': category['id']},
                       'statement': {'policy': category['policy_id']},
                       'receipt': {'run_dir': str(run), 'files': [{'file': 'segment-000.bin'}]}}
                chunks.append({'index': i, 'record': rec})
            record = {'chunks': chunks, 'verify_with': app.provers.verify_instructions(chunks[0]['record'])}
            post = {'status': 'published', 'manifest': None}
            with patch.object(app.S, 'store', SimpleNamespace(post=lambda _: post), create=True), \
                 patch.object(app.S, 'publisher', SimpleNamespace(anchors_of=lambda _: {}), create=True), \
                 patch.object(app, 'public_record', return_value=record):
                response = app.api_bundle('fixture')
                async def consume():
                    return b''.join([part async for part in response.body_iterator])
                raw = asyncio.run(consume())
            self.assertEqual(len(raw), int(response.headers['content-length']))
            with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
                readme = archive.extractfile('proven-media-fixture/VERIFY.md').read().decode()
                self.assertIn('Privacy statement pending', readme)
                self.assertNotIn('DEMO STUB', readme)
                for i, category in enumerate(runtime.categories()):
                    command = next(line for line in readme.splitlines() if '--policy '+category['policy_id'] in line)
                    self.assertIn(f'--artifact proven-media-fixture/chunk-{i}/run', command)
                    self.assertIn('--min-bits 95', command)
                self.assertEqual(len(archive.getnames()), 8)

    def test_signed_metadata_must_match_publication_profile_and_verifier(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(config, 'SIGNING_KEY', Path(tmp)/'key'):
            entry = {'category': 'sexual', 'chunk': 0, 'verdict': 'no', 'statement_sha256': '11'*32,
                     'policy_sha256': runtime.POLICY_SHAS['sexual'], 'model_id': runtime.IDENTITY,
                     'profile_id': runtime.PROFILE_SHA, 'verifier_id': runtime.BINARY_SHA,
                     'content_commitment': '22'*32, 'token_range': [0,17], 'anchor': {'leaf_hash': '33'*32}}
            publication = {**entry, 'policy_id': entry['policy_sha256']}
            publisher = SimpleNamespace(anchor_of=lambda *_: SimpleNamespace(leaf_hash='33'*32),
                verify_publication=lambda *a, **kw: {'accepted': True, 'manifest': publication})
            def checked(e):
                m = manifest.sign({'schema': manifest.SCHEMA, 'item': {'post_id': 'fixture'}, 'entries': [e]})
                return manifest.verify_manifest(m, publisher)
            self.assertTrue(checked(entry)['accepted'])
            for field in ('profile_id', 'verifier_id'):
                for value in ('00'*32, None):
                    with self.subTest(field=field, value=value):
                        result = checked({**entry, field: value})
                        self.assertFalse(result['accepted'])
                        self.assertTrue(result['checks']['signature'])


if __name__ == '__main__': unittest.main()

"""Real-mode metadata must identify the reviewed category, model and verifier."""
import os
import asyncio
import io
import json
from copy import deepcopy
import shlex
import subprocess
import sys
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

    def test_download_commands_keep_historical_verifier_pins_after_runtime_upgrade(self):
        from proven_media import provers
        for kind in ('shieldstral', 'shieldstral-fast'):
            record = {'prover': {'kind': kind, 'model_digest': '12' * 32,
                       'binary_sha256': '34' * 32, 'token_profile_digest': '56' * 32,
                       'run_profile': 'historical/2'},
                      'statement': {'trained_statement_identity': '12' * 32, 'run_profile': 'historical/2',
                                    'policy': 'shieldstral-1.0-3b-moderate-hate/1'}}
            before = deepcopy(record)
            instructions = provers.verify_instructions(record)
            command = shlex.split(instructions['command'])
            self.assertEqual(command[command.index('--expect-statement') + 1], '12' * 32)
            self.assertIn('34' * 32, instructions['binary'])
            self.assertNotIn(runtime.BINARY_SHA, instructions['binary'])
            self.assertEqual(instructions['expect_token_profile'], '56' * 32)
            self.assertFalse(instructions['privacy_statement']['accepted'])
            self.assertEqual(record, before)

    def test_incomplete_or_conflicting_record_never_gets_current_runtime_defaults(self):
        from proven_media import provers
        base = {'prover': self.prover, 'statement': {'policy': 'shieldstral-1.0-3b-moderate-hate/1'}}
        variants = []
        for key in ('model_digest', 'binary_sha256', 'token_profile_digest'):
            for value in (None, 'not-a-digest', 'a' * 64 + '; echo wrong'):
                bad = deepcopy(base); bad['prover'][key] = value; variants.append(bad)
        bad = deepcopy(base); bad['statement']['trained_statement_identity'] = '00' * 32; variants.append(bad)
        bad = deepcopy(base); bad['statement']['run_profile'] = 'unrecorded/2'; variants.append(bad)
        bad = deepcopy(base); bad['statement'].pop('policy'); variants.append(bad)
        for record in variants:
            with self.subTest(record=record):
                instructions = provers.verify_instructions(record)
                self.assertEqual(instructions['command'], '')
                self.assertNotIn('expect_statement', instructions)

    def test_policy_is_a_single_shell_argument(self):
        from proven_media import provers
        policy = 'historical policy; $(echo wrong)'
        instructions = provers.verify_instructions({'prover': self.prover, 'statement': {'policy': policy}})
        command = shlex.split(instructions['command'])
        self.assertEqual(command[command.index('--policy') + 1], policy)

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
            post = {'status': 'published', 'manifest': None, 'record': json.dumps(record)}
            with patch.object(app.S, 'store', SimpleNamespace(post=lambda _: post), create=True), \
                 patch.object(app.S, 'publisher', SimpleNamespace(anchors_of=lambda _: {}), create=True):
                response = app.api_bundle('fixture')
                async def consume():
                    return b''.join([part async for part in response.body_iterator])
                raw = asyncio.run(consume())
            self.assertEqual(len(raw), int(response.headers['content-length']))
            with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
                readme = archive.extractfile('proven-media-fixture/VERIFY.md').read().decode()
                self.assertIn(record['verify_with']['privacy_statement']['status'], readme)
                public_record = archive.extractfile('proven-media-fixture/record.json').read()
                self.assertNotIn(b'run_dir', public_record)
                self.assertNotIn(tmp.encode(), public_record)
                self.assertNotIn('DEMO STUB', readme)
                for i, category in enumerate(runtime.categories()):
                    command = next(line for line in readme.splitlines() if '--policy '+category['policy_id'] in line)
                    self.assertIn(f'--artifact proven-media-fixture/chunk-{i}/run', command)
                    self.assertIn('--min-bits 95', command)
                self.assertEqual(len(archive.getnames()), 8)

    def test_signature_only_cli_uses_trusted_key_without_operator_state(self):
        tool = Path(__file__).resolve().parents[1] / 'tools/verify_manifest.py'
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            with patch.object(config, 'SIGNING_KEY', root / 'signer'):
                signed = manifest.sign({'schema': manifest.SCHEMA, 'item': {'post_id': 'example'}})
                trusted = manifest.public_key_hex()
            with patch.object(config, 'SIGNING_KEY', root / 'different-signer'):
                other = manifest.public_key_hex()
            path = root / 'manifest.json'
            env = dict(os.environ, PM_PUBLIC_DIR=str(root/'absent-public'), PM_PRIVATE_DIR=str(root/'absent-private'))
            def run(*flags):
                return subprocess.run([sys.executable, '-B', str(tool), str(path), '--signature-only', *flags],
                                      capture_output=True, text=True, env=env, timeout=15)
            path.write_text(json.dumps(signed))
            good = run('--public-key', trusted.upper())
            self.assertEqual(good.returncode, 0, good.stderr)
            self.assertEqual(json.loads(good.stdout), {'accepted': True, 'scope': 'publisher_signature_only',
                'checks': {'schema': True, 'issuer_key': True, 'signature': True}, 'reasons': []})
            wrong = run('--public-key', other)
            self.assertEqual(wrong.returncode, 1)
            self.assertFalse(json.loads(wrong.stdout)['checks']['issuer_key'])
            self.assertEqual(run().returncode, 2)
            for flags in (['--rehash'], ['--run-verifier'], ['--public-dir', str(root)], ['--sepolia-config', 'rpc']):
                self.assertEqual(run('--public-key', trusted, *flags).returncode, 2)
            signed['item']['post_id'] = 'changed'
            path.write_text(json.dumps(signed))
            tampered = run('--public-key', trusted)
            self.assertEqual(tampered.returncode, 1)
            self.assertFalse(json.loads(tampered.stdout)['checks']['signature'])
            for invalid in ('{"schema": "one", "schema": "two"}', '{"value": NaN}', '{'):
                path.write_text(invalid)
                malformed = run('--public-key', trusted)
                self.assertEqual(malformed.returncode, 1)
                result = json.loads(malformed.stdout)
                self.assertFalse(result['accepted'])
                self.assertEqual(result['scope'], 'publisher_signature_only')
            self.assertFalse((root/'absent-public').exists())
            self.assertFalse((root/'absent-private').exists())

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

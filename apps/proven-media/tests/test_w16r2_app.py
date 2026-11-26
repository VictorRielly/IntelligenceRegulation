"""W16R2 routing/refusal checks. All native authority here is synthetic test data."""
from contextlib import ExitStack
from dataclasses import replace
import asyncio
import hashlib
import importlib.util
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

import test_app
from proven_media import config, fast_service, hardware_profiles, records, resident_writer, provers
from proven_media import shieldstral_fast_runtime as baseline, w16r2_runtime as w16
from proven_media.classifier_cli import ClassifierCLI
from proven_media.classifier_privacy import statement_info
from proven_media.fast_runtime_selection import runtime_for
from proven_media.items import TextItem
from proven_media.provers import ProverError
from proven_media.shieldstral_fast_prover import ShieldstralFastProver
from proven_media.shieldstral_text import TEKKEN_SHA256


class PendingIntakeTests(unittest.TestCase):
    def test_pending_mode_refuses_before_prover_or_service_creation(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'pending-intake.json'
            authority = json.loads(w16.INTAKE.read_text())
            authority.update(status='awaiting_native_binary', binary_sha256=None,
                             statement_identity=None, run_profile=None)
            path.write_bytes(records.canonical(authority))
            with patch.object(w16, 'INTAKE', path), \
                patch.object(w16, 'INTAKE_SHA', records.sha256_file(path)), \
                patch.dict(os.environ, {'PM_PROVER': w16.KIND}), \
                patch.object(ShieldstralFastProver, '__init__', side_effect=AssertionError('must not construct')):
                with self.assertRaisesRegex(ProverError, 'pending'):
                    provers.make_prover()

    def test_baseline_selection_never_reads_w16_authority(self):
        with patch.object(w16, 'authority', side_effect=AssertionError('unexpected intake')):
            self.assertIs(runtime_for('shieldstral-fast'), baseline)
        with self.assertRaisesRegex(ProverError, 'unknown'):
            runtime_for('automatic')

    def test_distinct_screening_context_keeps_registered_policy_geometry(self):
        contexts = []
        for mode in ('shieldstral', 'shieldstral-fast', w16.KIND):
            with patch.dict(os.environ, {'PM_PROVER': mode}):
                contexts.append(config.category_set_id())
                self.assertTrue(config.is_shieldstral_mode())
                self.assertEqual(config.deploy()['max_content_tokens'], 336)
                self.assertEqual(len(config.registered_categories()), 3)
        self.assertEqual(len(set(contexts)), 3)


class W16Tests(unittest.TestCase):
    def setUp(self):
        self.stack = ExitStack()
        self.addCleanup(self.stack.close)
        self.root = Path(self.stack.enter_context(tempfile.TemporaryDirectory())).resolve()
        self.binary = self.root / 'NOT-A-NATIVE-BINARY'
        self.binary.write_bytes(b'SYNTHETIC TEST ONLY; NEVER EXECUTE\n')
        self.prover_binary = self.root / 'test-producer'
        self.prover_binary.write_bytes(b'Synthetic producer fixture\n')
        self.authority = json.loads(w16.INTAKE.read_text())
        self.authority.update(status='candidate_native_cli_ready', binary=str(self.binary),
            binary_sha256=records.sha256_file(self.binary), statement_identity='a' * 64,
            run_profile='synthetic-w16r2-test-only/1')
        self.intake = self.root / 'intake.json'
        self.intake.write_bytes(records.canonical(self.authority))
        for obj, name, value in ((w16, 'INTAKE', self.intake), (w16, 'INTAKE_SHA', records.sha256_file(self.intake)),
                (w16, 'BINARY', self.binary), (w16, 'PROVER_BINARY', self.prover_binary),
                (w16, 'PROVER_BINARY_SHA', records.sha256_file(self.prover_binary)),
                (config, 'PRIVATE_DIR', self.root / 'private'),
                (config, 'PUBLIC_DIR', self.root / 'public'), (config, 'RUNS_DIR', self.root / 'public/runs')):
            self.stack.enter_context(patch.object(obj, name, value))
        self.stack.enter_context(patch.dict(os.environ, {'PM_PROVER': w16.KIND, 'PM_FAST_WRITER_MODE': 'resident'}))
        self.runtime = w16.Runtime()
        self.pending_deploy_file = config.DEPLOY_FILE
        settings = json.loads(self.pending_deploy_file.read_text())
        settings['classifier_profiles'][hardware_profiles.W16_FAST_PROFILE].update(
            binary_sha256=self.runtime.BINARY_SHA, statement_identity=self.runtime.IDENTITY,
            prover_binary_sha256=self.runtime.PROVER_BINARY_SHA,
            native_intake_sha256=self.runtime.intake_sha)
        fixture_deploy_file = self.root / 'fixture-deploy.json'
        fixture_deploy_file.write_text(json.dumps(settings))
        self.stack.enter_context(patch.object(config, 'DEPLOY_FILE', fixture_deploy_file))
        self.runtime.EXPORT = self.root / 'prover-export'
        for directory in (self.runtime.EXPORT, self.runtime.VERIFIER_EXPORT):
            (directory / 'token_io').mkdir(parents=True)
            (directory / 'profile.json').write_bytes((w16.EXPORT / 'profile.json').read_bytes())
        self.deployment = self.runtime.deployment(self.runtime.templates()[0])

    def rewrite_intake(self, changes):
        data = {**self.authority, **changes}
        self.intake.write_bytes(records.canonical(data))
        return patch.object(w16, 'INTAKE_SHA', records.sha256_file(self.intake))

    def test_intake_content_drift_refuses_even_when_well_formed(self):
        self.intake.write_text(json.dumps(self.authority))
        with self.assertRaisesRegex(ProverError, 'source pin'):
            w16.Runtime()

    def test_reviewed_intake_cannot_transfer_baseline_or_remove_public_scope(self):
        cases = [{'statement_identity': baseline.IDENTITY}, {'binary_sha256': baseline.BINARY_SHA},
                 {'run_profile': baseline.RUN_PROFILE}, {'statement_identity': None}, {'min_bits': 94},
                 {'public_content_only': False}, {'public_content_only': 1}, {'production': True},
                 {'native_flag': ''}, {'commands': ['serve']}, {'profile_sha256': baseline.PROFILE_SHA}]
        for changes in cases:
            with self.subTest(changes=changes), self.rewrite_intake(changes):
                with self.assertRaises(ProverError):
                    w16.Runtime()

    def test_intake_symlink_and_oversize_refuse(self):
        linked = self.root / 'link.json'
        linked.symlink_to(self.intake)
        with patch.object(w16, 'INTAKE', linked), self.assertRaises(ProverError):
            w16.Runtime()
        self.intake.write_bytes(b' ' * ((1 << 20) + 1))
        with self.assertRaises(ProverError):
            w16.Runtime()

    def test_review_changed_after_construction_refuses_existing_runtime(self):
        with self.rewrite_intake({'run_profile': 'another-synthetic-test/1'}):
            with self.assertRaisesRegex(ProverError, 'changed'):
                self.runtime.service_binding()
            with self.assertRaisesRegex(ProverError, 'changed'):
                self.runtime.validate(self.deployment)

    def test_resident_required_no_oneshot_or_automatic_fallback(self):
        for mode in ('oneshot', 'auto', ''):
            with patch.dict(os.environ, {'PM_FAST_WRITER_MODE': mode}), self.assertRaises(ProverError):
                w16.Runtime()

    def test_pinned_runtime_validation_and_binary_profile_changes(self):
        self.runtime.validate(self.deployment)
        for changes in ({'min_bits': 94}, {'statement_identity': baseline.IDENTITY},
                        {'chunk_size': 54}, {'prover_export': baseline.EXPORT}):
            with self.subTest(changes=changes), self.assertRaises(ProverError):
                self.runtime.validate(replace(self.deployment, **changes))
        self.binary.write_bytes(b'changed')
        with self.assertRaisesRegex(ProverError, 'binary hash'):
            self.runtime.validate(self.deployment)

    def test_verifier_profile_cannot_be_baseline(self):
        (self.runtime.VERIFIER_EXPORT / 'profile.json').write_bytes((baseline.EXPORT / 'profile.json').read_bytes())
        with self.assertRaisesRegex(ProverError, 'profile differs'):
            self.runtime.validate(self.deployment)

    def test_all_cli_commands_and_both_servers_require_native_flag(self):
        cli = self.runtime.make_cli(self.deployment)
        for command in ('prove', 'verify', 'input-owner', 'label'):
            argv = cli._base(command)
            self.assertEqual(argv.count(w16.FLAG), 1)
            self.assertEqual(argv[0], str(self.prover_binary if command == 'prove' else self.binary))
            self.assertEqual(argv[argv.index('--export') + 1], str(
                self.runtime.EXPORT if command == 'prove' else self.runtime.VERIFIER_EXPORT))
        for kind in ('prove', 'check'):
            argv = self.runtime.server_argv(kind)
            self.assertEqual(argv.count(w16.FLAG), 1)
            self.assertEqual(argv[0], str(self.prover_binary if kind == 'prove' else self.binary))
            self.assertEqual(argv[argv.index('--lane-threads') + 1], '8' if kind == 'prove' else '4')
            if kind == 'check':
                self.assertEqual(argv[argv.index('--min-bits') + 1], '95')
                self.assertEqual(argv[argv.index('--expect-statement') + 1], self.runtime.IDENTITY)
        with self.assertRaises(ProverError):
            self.runtime.server_argv('auto')

    def test_producer_identity_checked_before_launch(self):
        self.prover_binary.write_text('different producer fixture')
        with self.assertRaisesRegex(ProverError, 'prover binary'):
            self.runtime.server_argv('prove')
        self.assertEqual(self.runtime.server_argv('check')[0], str(self.binary))

    def test_completed_proofs_bind_their_original_producer(self):
        descriptor = self.runtime.descriptor()
        current = self.runtime.service_binding()
        self.assertTrue(self.runtime.matches_proof_binding(current, descriptor))
        old = {k: v for k, v in current.items() if k not in ('prover_binary_sha256', 'prover_lane_threads')}
        old['native_settings'] = dict(w16.ORIGINAL_SETTINGS)
        historical = {k: v for k, v in descriptor.items() if k != 'prover_binary_sha256'}
        self.assertTrue(self.runtime.matches_proof_binding(old, historical))
        self.assertFalse(self.runtime.matches_proof_binding(old, descriptor))
        self.assertFalse(self.runtime.matches_proof_binding(current, historical))
        composed = dict(current, prover_binary_sha256=w16.COMPOSED_PROVER_SHA, native_settings=dict(w16.COMPOSED_SETTINGS))
        signed = dict(descriptor, prover_binary_sha256=w16.COMPOSED_PROVER_SHA)
        self.assertTrue(self.runtime.matches_proof_binding(composed, signed))
        self.assertFalse(self.runtime.matches_proof_binding(composed, descriptor))
        self.assertFalse(self.runtime.matches_proof_binding(dict(composed, prover_lane_threads=5), signed))

    def test_collector_requires_native_run_profile_and_marks_public_scope(self):
        cli = self.runtime.make_cli(self.deployment)
        with patch.object(ClassifierCLI, 'collect_verified', return_value={
                'statement': {'run_profile': self.runtime.RUN_PROFILE}, 'development_only': False}):
            result = cli.collect_verified()
            self.assertIs(result['public_content_only'], True)
            self.assertIs(result['development_only'], False)
            self.assertIs(result['development_candidate'], True)
            self.assertIs(result['production'], False)
        with patch.object(ClassifierCLI, 'collect_verified', return_value={'statement': {'run_profile': baseline.RUN_PROFILE}}):
            with self.assertRaises(ProverError):
                cli.collect_verified()

    def test_aggregate_mixed_mode_refuses_before_legacy_collector(self):
        cli = self.runtime.make_cli(self.deployment)
        row = {'public_content_only': True, 'development_only': False, 'development_candidate': True,
               'production': False, 'statement': {'run_profile': self.runtime.RUN_PROFILE}}
        with patch.object(ClassifierCLI, 'check_label_records', return_value='checked') as check:
            self.assertEqual(cli.check_label_records([row], 5), 'checked')
            check.reset_mock()
            for changed in ({**row, 'public_content_only': False}, {**row, 'development_only': True},
                            {**row, 'production': True}, {**row, 'development_candidate': False},
                            {**row, 'statement': {'run_profile': baseline.RUN_PROFILE}}):
                with self.assertRaises(ProverError):
                    cli.check_label_records([row, changed], 5)
            check.assert_not_called()

    def test_service_binding_has_distinct_sources_paths_authority_and_budget(self):
        binding = self.runtime.service_binding()
        old = baseline.service_binding()
        self.assertNotEqual(binding['resident_source_digest'], old['resident_source_digest'])
        self.assertNotEqual(self.runtime.service_dir(), baseline.service_dir())
        self.assertEqual(binding['native_settings']['HL_A26_KEPT'], '1')
        self.assertEqual(binding['native_settings']['HL_A30_B3PAR'], '1')
        with patch.object(baseline, 'native_environment', return_value={'HL_A30_B3PAR': '0'}):
            self.assertEqual(self.runtime.native_environment()['HL_A30_B3PAR'], '1')
        self.assertEqual(binding['profile_sha256'], w16.PROFILE_SHA)
        self.assertIs(binding['public_content_only'], True)
        argv = fast_service.guard_command(self.runtime.service_dir(), self.runtime)
        self.assertEqual(argv[argv.index('--prover-mode') + 1], w16.KIND)
        self.assertEqual(argv[argv.index('--cap-gib') + 1], '220')
        self.assertEqual(argv[argv.index('--writer-mode') + 1], 'resident')

    def test_live_baseline_service_refuses_without_launch_enqueue_or_stop(self):
        root = self.runtime.service_dir()
        launch = Mock()
        with patch.object(fast_service, 'health', return_value={
                'live': True, 'launching': False, 'heartbeat': {'writer_binding': baseline.service_binding()}}):
            with self.assertRaises(ProverError):
                fast_service.ensure_running(root, self.runtime, launcher=launch)
        launch.assert_not_called()
        self.assertFalse((root / 'STOP').exists())
        self.assertFalse(list((root / 'spool').glob('*')))

    def test_ambient_shortcuts_cannot_change_w16_service_environment(self):
        with patch.dict(os.environ, {'HL_A26_VERIFY_ONCE': '1', 'HL_A28_SEAL_AHEAD': '1'}), \
                patch.object(baseline, 'native_environment', return_value={
                    'HL_A26_VERIFY_ONCE': '1', 'HL_A28_SEAL_AHEAD': '1'}):
            environment = dict(os.environ, **self.runtime.native_environment())
        for key in ('HL_A26_VERIFY_ONCE', 'HL_A28_SEAL_AHEAD'):
            self.assertEqual(environment[key], '0')
            self.assertEqual(self.runtime.service_binding()['native_settings'][key], '0')
            self.assertEqual(hardware_profiles.fast_classifier_profile(
                runtime_module=self.runtime)['native_settings'][key], '0')

    def test_hardware_profile_needs_reviewed_native_pins_and_public_scope(self):
        data = json.loads(config.DEPLOY_FILE.read_text())
        name = hardware_profiles.W16_FAST_PROFILE
        profile = data['classifier_profiles'][name]
        with self.assertRaises(ProverError):
            hardware_profiles.fast_classifier_profile(self.pending_deploy_file, runtime_module=self.runtime)
        profile.update(binary_sha256=self.runtime.BINARY_SHA, statement_identity=self.runtime.IDENTITY,
            prover_binary_sha256=self.runtime.PROVER_BINARY_SHA,
                       native_intake_sha256=self.runtime.intake_sha)
        path = self.root / 'hardware.json'
        path.write_text(json.dumps(data))
        self.assertEqual(hardware_profiles.fast_classifier_profile(path, runtime_module=self.runtime)['name'], name)
        profile['public_content_only'] = False
        path.write_text(json.dumps(data))
        with self.assertRaises(ProverError):
            hardware_profiles.fast_classifier_profile(path, runtime_module=self.runtime)

    def test_prover_injection_and_prepared_job_bind_w16_without_launch(self):
        with patch.object(w16, 'Runtime', return_value=self.runtime):
            prover = provers.make_prover()
        self.assertIs(prover.runtime, self.runtime)
        descriptor = prover.describe()
        self.assertEqual(descriptor['kind'], w16.KIND)
        self.assertIs(descriptor['public_content_only'], True)
        self.assertIs(descriptor['production'], False)
        item = TextItem('A calm afternoon in the garden.')
        chunk = prover.plan_text(item.text)[0]
        job = self.root / 'private/jobs/first'
        prover.prepare('first', item, job, chunk)
        spec = json.loads((job / 'classifier-job.json').read_text())
        self.assertEqual(spec['writer_binding'], self.runtime.service_binding())
        self.assertEqual(spec['deployment']['statement_identity'], self.runtime.IDENTITY)
        self.assertFalse((prover.service / 'launch.json').exists())

    def test_final_records_from_other_mode_refuse_before_coverage(self):
        prover = object.__new__(ShieldstralFastProver)
        prover.runtime = self.runtime
        prover.kind = w16.KIND
        with self.assertRaisesRegex(ProverError, 'mixes'):
            prover.check_final_records(TextItem('public test'), [{'prover': {'kind': baseline.KIND}}])

    def test_privacy_scope_cannot_inherit_acceptance(self):
        descriptor = self.runtime.descriptor()
        descriptor.update(privacy_status='CPU privacy statement accepted', privacy_statement={'accepted': True})
        info = statement_info(descriptor)
        self.assertFalse(info['accepted'])
        self.assertIsNone(info['decision'])
        self.assertFalse(info['permits_non_public_posts'])
        self.assertIn('Public content only', info['status'])

    def test_recorded_verifier_pins_survive_current_runtime_changes(self):
        descriptor = self.runtime.descriptor()
        record = {'prover': descriptor, 'statement': {'policy': self.deployment.policy,
                  'run_profile': self.runtime.RUN_PROFILE, 'trained_statement_identity': self.runtime.IDENTITY}}
        with patch.object(baseline, 'IDENTITY', 'b' * 64), patch.object(w16, 'authority', side_effect=AssertionError):
            instruction = provers.verify_instructions(record)
        self.assertIn(w16.FLAG, instruction['command'])
        self.assertEqual(instruction['expect_statement'], self.runtime.IDENTITY)
        self.assertNotIn('CPU privacy statement accepted', instruction['privacy_status'])
        for changes in ({'public_content_only': False}, {'production': True}, {'native_cli_flags': []}):
            invalid = {**record, 'prover': {**descriptor, **changes}}
            self.assertEqual(provers.verify_instructions(invalid)['command'], '')

    def test_child_mode_mismatch_refuses_before_any_service_directory(self):
        root = self.root / 'unstarted'
        result = subprocess.run([sys.executable, str(config.TOOLS_DIR / 'fast_service.py'),
            '--prover-mode', 'shieldstral-fast', '--writer-mode', 'resident', str(root)],
            capture_output=True, text=True, timeout=10)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('guarded prover mode differs', result.stderr)
        self.assertFalse(root.exists())

    def test_downloaded_bundle_commands_use_the_received_kit_for_every_category(self):
        from proven_media import app

        kit = self.root / 'received kit'
        executable = kit / 'bin/zk60_classify'
        executable.parent.mkdir(parents=True)
        executable.write_text('#!/bin/sh\nprintf "%s\\n" "$ZK60_MODELS" "$@"\n')
        executable.chmod(0o755)
        run = self.root/'fixture'
        (run/'statement').mkdir(parents=True)
        (run/'statement/statement.json').write_text('{}')
        chunks = []
        for index, category in enumerate(self.runtime.categories()):
            rec = {'prover': self.runtime.descriptor(), 'chunk': {'category': category['id']},
                   'statement': {'policy': category['policy_id'], 'run_profile': self.runtime.RUN_PROFILE},
                   'receipt': {'run_dir': str(run), 'files': []}}
            chunks.append({'index': index, 'record': rec})
        record = {'chunks': chunks, 'verify_with': provers.verify_instructions(chunks[0]['record'])}
        post = {'status': 'published', 'record': json.dumps(record), 'manifest': None}
        with patch.object(app.S, 'store', Mock(post=Mock(return_value=post)), create=True), \
                patch.object(app.S, 'publisher', Mock(anchors_of=Mock(return_value={})), create=True):
            response = app.api_bundle('fixture')
            async def body():
                return b''.join([piece async for piece in response.body_iterator])
            raw = asyncio.run(body())
        with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
            readme = archive.extractfile('proven-media-fixture/VERIFY.md').read().decode()
        self.assertIn('prepare_w16r2_verifier.py --check "$PM_W16R2_VERIFIER_KIT"', readme)
        for index, category in enumerate(self.runtime.categories()):
            command, = [line for line in readme.splitlines() if '--policy '+category['policy_id'] in line]
            result = subprocess.run(['/bin/sh', '-c', command], cwd=self.root, capture_output=True, text=True,
                                    env={'PM_W16R2_VERIFIER_KIT': str(kit)}, check=True, timeout=5)
            self.assertEqual(result.stdout.splitlines(), [str(kit/'models'), 'verify', '--export', str(kit/'export'),
                '--tables', str(kit/'export/token_io'), '--policy', category['policy_id'], '--label',
                'zk60-classify-verdict', '--artifact', f'proven-media-fixture/chunk-{index}/run',
                '--expect-statement', self.runtime.IDENTITY, '--min-bits', '95', w16.FLAG])

    def test_public_development_scope_preserves_real_policy_publication_metadata(self):
        # Synthetic receipt bytes exercise the transport contract, never native verification.
        from proven_media.jobs import chunk_publication_records
        cli = self.runtime.make_cli(self.deployment)
        with patch.object(ClassifierCLI, 'collect_label', return_value={
                'value': 'no', 'proof': 'accepted', 'bound_by_proof': True,
                'policy_id': self.deployment.policy, 'development_only': False}):
            label = cli.collect_label()
        self.assertIs(label['public_content_only'], True)
        self.assertIs(label['development_candidate'], True)
        self.assertIs(label['production'], False)
        self.assertIs(label['development_only'], False, 'legacy flag vetoes synthetic-policy publication')
        category = self.runtime.templates()[0].category
        label['policy_sha256'] = next(c['sha256'] for c in self.runtime.categories() if c['id'] == category)
        run = self.root / 'synthetic-receipt'
        (run / 'statement').mkdir(parents=True)
        (run / 'statement/statement.json').write_text('{"synthetic_test_only":true}')
        (run / 'proof.bin').write_bytes(b'NOT A NATIVE PROOF')
        record = {'prover': self.runtime.descriptor(), 'labels': {category: label},
                  'checks': {'verify': {'ok': True}},
                  'statement_sha256': records.sha256_file(run / 'statement/statement.json'),
                  'receipt': {'run_dir': str(run), 'files': [{'file': 'proof.bin', 'bytes': 18,
                                                            'sha256': records.sha256_file(run / 'proof.bin')}]}}
        chunk = {'index': 0, 'start': 0, 'end': 5, 'category': category, 'category_chunk_index': 0}
        published = chunk_publication_records({'id': 'synthetic-fixture'}, record, chunk, '0' * 64)
        self.assertEqual(len(published), 1)
        self.assertIs(published[0].development_only, False)
        self.assertEqual(published[0].model_id, self.runtime.IDENTITY)
        self.assertEqual(published[0].verifier_id, self.runtime.BINARY_SHA)

    def test_manifest_retains_public_content_development_notice(self):
        from proven_media import manifest
        category = self.runtime.templates()[0].category
        item = {'chunks': [{'index': 0, 'start': 0, 'end': 5, 'category': category,
                           'category_chunk_index': 0, 'record': {'prover': self.runtime.descriptor(), 'labels': {}}}]}
        with patch.object(manifest, 'sign', side_effect=lambda x: x):
            result = manifest.build_manifest({'id': 'synthetic', 'kind': 'text', 'created_at': 'test'}, item, {}, {}, None)
        self.assertIn('Public content only; privacy not claimed', ' '.join(result['notes']))
        self.assertIn('not production', ' '.join(result['notes']))
        self.assertEqual(result['category_set']['id'], 'shieldstral-moderate-w16r2-public-dev-v1')

    def synthetic_sources(self, mutation=None):
        source = self.root / 'sources'
        source.mkdir()
        for name in ('engine.py', 'pipe_worker.py', 'export_selection.py'):
            (source / name).write_text('# synthetic fixture, no model loading\n')
        pins = {p.name: records.sha256_file(p) for p in source.iterdir()}
        ready = {'event': 'ready', 'profile_sha256': self.runtime.PROFILE_SHA,
                 'original_writer_sha256': self.runtime.WRITER_SHA, 'writer_sha256': pins['engine.py'],
                 'tokenizer_sha256': TEKKEN_SHA256, 'layers_loaded': 26, 'numpy': resident_writer.NUMPY_VERSION,
                 'selection_sha256': pins['export_selection.py'], 'export': {
                     'name': 'a29-uniform-u1', 'profile_sha256': self.runtime.PROFILE_SHA,
                     'loader_sha256': resident_writer.W16_LOADER_SHA, 'layers': 26, 'T': 128}}
        if mutation:
            ready.update(mutation)
        (source / 'client.py').write_text('from pathlib import Path\nfrom types import SimpleNamespace\n'
            'class Pool:\n'
            ' def __init__(self, python, root, logs, count, export):\n'
            '  self.root=Path(root)\n'
            '  (self.root/"selected-export").write_text(str(export))\n'
            f'  self.clients=[SimpleNamespace(ready={ready!r}) for _ in range(count)]\n'
            ' def close(self):\n'
            '  (self.root/"pool-closed").write_text("closed")\n')
        pins['client.py'] = records.sha256_file(source / 'client.py')
        self.stack.enter_context(patch.object(resident_writer, 'W16_ROOT', source))
        self.stack.enter_context(patch.object(resident_writer, 'W16_SOURCE_PINS', pins))
        return source, pins

    def test_writer_pool_receives_selected_export_and_records_private_readiness(self):
        self.synthetic_sources()
        pool = resident_writer.open_pool(self.runtime, self.root, self.root, 'good')
        try:
            self.assertEqual((self.root / 'selected-export').read_text(), str(self.runtime.EXPORT))
            ready = self.root / 'resident-good/ready.json'
            self.assertEqual(ready.stat().st_mode & 0o777, 0o600)
            self.assertEqual(len(json.loads(ready.read_text())), 2)
        finally:
            pool.close()

    def test_writer_source_drift_refuses_before_import_or_log_creation(self):
        source, _ = self.synthetic_sources()
        (source / 'client.py').write_text('raise AssertionError("must not execute")')
        with self.assertRaisesRegex(ProverError, 'source changed'):
            resident_writer.open_pool(self.runtime, self.root, self.root, 'drift')
        self.assertFalse((self.root / 'resident-drift').exists())
        self.assertFalse((self.root / 'selected-export').exists())

    def test_stale_export_readiness_closes_pool_before_use(self):
        self.synthetic_sources({'export': {'name': 'baseline'}})
        with self.assertRaisesRegex(ProverError, 'export identity'):
            resident_writer.open_pool(self.runtime, self.root, self.root, 'wrong-export')
        self.assertTrue((self.root / 'pool-closed').exists())
        self.assertFalse((self.root / 'resident-wrong-export/ready.json').exists())

    def test_stale_selection_readiness_closes_pool_before_use(self):
        self.synthetic_sources({'selection_sha256': '0' * 64})
        with self.assertRaisesRegex(ProverError, 'export identity'):
            resident_writer.open_pool(self.runtime, self.root, self.root, 'wrong-selector')
        self.assertTrue((self.root / 'pool-closed').exists())

    def test_selected_service_closes_workers_and_both_flagged_servers(self):
        from test_resident_integration import Native, Pool
        spec = importlib.util.spec_from_file_location('w16_synthetic_service', config.TOOLS_DIR / 'fast_service.py')
        tool = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(tool)
        tool.runtime = self.runtime
        root = self.runtime.service_dir()
        fast_service.ensure_dirs(root)
        (root / 'STOP').touch()
        pool = Pool()
        Native.instances = []
        with patch.object(resident_writer, 'open_pool', return_value=pool) as factory, \
                patch.object(tool, 'Native', side_effect=Native) as native, \
                patch.dict(os.environ, {k:'ambient' for k in w16.PROVER_ONLY_SETTINGS}), \
                patch.object(baseline, 'native_environment', return_value={}):
            service = tool.Service(root)
            self.assertEqual(service.main(), 0)
        self.assertIs(factory.call_args.args[0], self.runtime)
        self.assertEqual(len(native.call_args_list), 2)
        for call in native.call_args_list:
            self.assertIn(w16.FLAG, call.args[1])
        prover_env, checker_env = (call.args[2] for call in native.call_args_list)
        self.assertEqual({k:prover_env[k] for k in w16.PROVER_ONLY_SETTINGS}, w16.PROVER_ONLY_SETTINGS)
        self.assertTrue(w16.PROVER_ONLY_SETTINGS.keys().isdisjoint(checker_env))
        self.assertTrue(all(n.closed for n in Native.instances))
        self.assertEqual(pool.closed, 1)
        self.assertFalse(fast_service.service_live(root))
        heartbeat = json.loads((root / 'heartbeat.json').read_text())
        self.assertEqual(heartbeat['writer_binding'], self.runtime.service_binding())


if __name__ == '__main__':
    unittest.main()

"""Public-store verifier routing with synthetic receipts and mocked native execution."""
from copy import deepcopy
import importlib.util
import io
import json
import os
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

import test_w16r2_app as app_fixtures
from proven_media import config, records, resident_writer, w16r2_public_verifier as verifier
from proven_media import shieldstral_fast_runtime as baseline, w16r2_runtime as w16
from proven_media.classifier_cli import R_C3_SCHEMA
from proven_media.publisher import LocalChainPublisher, PublicationRecord


class PublicVerifierTests(unittest.TestCase):
    def setUp(self):
        app_fixtures.W16Tests.setUp(self)
        self.stack.enter_context(patch.object(baseline, 'native_environment', return_value={
            'ZK60_MODELS': str(self.root / 'public-checkpoint'), 'HL_GPU': '1', 'HL_A26_KEPT': '1'}))
        self.pub = LocalChainPublisher(config.PUBLIC_DIR)
        self.post_id = 'ab' * 16
        self.template = self.runtime.templates()[0]
        self.category = next(c for c in self.runtime.categories() if c['id'] == self.template.category)
        self.statement = {'schema': R_C3_SCHEMA, 'run_profile': self.runtime.RUN_PROFILE,
            'trained_statement_identity': self.runtime.IDENTITY, 'policy': self.category['policy_id'],
            'context_label': 'zk60-classify-verdict', 'blocks': 26, 'T': 128, 'verdict_bit': 0,
            'whole_run_floor_bits': 96, 'input_token_endpoint_root': 'b' * 64,
            'template_prefix_ids': list(self.template.prefix), 'template_suffix_ids': list(self.template.suffix),
            'chunk': {'index': 0, 'count': 1, 'range': [0, 14], 'content_total': 14,
                      'chunk_size': self.template.chunk_size, 'overlap': self.template.overlap}}
        self.manifest = {'post_id': self.post_id, 'category': self.category['id'], 'chunk': 0, 'token_range': [0, 14],
            'verifier_id': self.runtime.BINARY_SHA, 'model_id': self.runtime.IDENTITY,
            'profile_id': self.runtime.PROFILE_SHA, 'policy_id': self.category['sha256'], 'verdict': 'no',
            'segments_json_sha256': None, 'segments': []}
        self.set_statement(self.statement)
        for index, name in enumerate(verifier.NAMES):
            data = f'SYNTHETIC RECEIPT ONLY, SEGMENT {index}\n'.encode()
            self.manifest['segments'].append({'file': name, 'bytes': len(data), 'sha256': self.pub.put_bytes(data)})
        spec = importlib.util.spec_from_file_location('w16_publication_tool_test', config.TOOLS_DIR / 'verify_publication.py')
        self.tool = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.tool)
        self.commands = []
        self.snapshots = []

    def set_statement(self, value):
        self.statement = deepcopy(value)
        self.manifest['statement_sha256'] = self.pub.put_bytes(records.canonical(value))

    def event(self):
        return {'event': 'classified', 'trained_statement_identity': self.runtime.IDENTITY,
                'policy': self.category['policy_id'], 'verdict': 'not-flagged', 'whole_run_floor_bits': 96,
                'chunk': self.statement['chunk']['index'], 'chunks': self.statement['chunk']['count'],
                'input_token_endpoint_root': self.statement['input_token_endpoint_root']}

    def execute(self, command, **kwargs):
        self.commands.append((command, kwargs))
        if command[2] == 'check':
            return SimpleNamespace(returncode=0, stdout='OK to start now\n')
        assert command[2] == 'run'
        run = Path(command[command.index('--artifact') + 1])
        self.snapshots.append(run)
        self.assertEqual(set(p.name for p in run.iterdir()), set(verifier.NAMES) | {'statement'})
        self.assertEqual(set(p.name for p in (run / 'statement').iterdir()), {'statement.json'})
        for row in self.manifest['segments']:
            self.assertEqual(records.sha256_file(run / row['file']), row['sha256'])
            self.assertNotEqual((run / row['file']).stat().st_ino, self.pub._obj(row['sha256']).stat().st_ino)
        Path(command[command.index('--log') + 1]).write_text(json.dumps(self.event()) + '\n')
        Path(command[command.index('--done') + 1]).write_text('0\n')
        Path(command[command.index('--result-json') + 1]).write_text(json.dumps({
            'exit': 0, 'child_rc': 0, 'stragglers_killed': 0, 'hard_killed': 0,
            'guard_killed': None, 'guard_error': None, 'peak_rss_gib': 0.01, 'fixture_only': True}))
        return SimpleNamespace(returncode=0, stdout='')

    def run_fixture(self, execute=None):
        with patch.object(verifier.subprocess, 'run', side_effect=execute or self.execute):
            return self.tool.run_verifier(self.pub, self.manifest, self.post_id)

    def assert_refused_before_guard(self, manifest=None):
        with patch.object(verifier.subprocess, 'run') as native:
            result = self.tool.run_verifier(self.pub, manifest or self.manifest, self.post_id)
        self.assertFalse(result['ok'], result)
        native.assert_not_called()
        return result

    def test_public_store_reconstruction_and_guarded_flagged_cli(self):
        with patch.dict(os.environ, w16.PROVER_ONLY_SETTINGS):
            result = self.run_fixture()
        self.assertTrue(result['ok'], result)
        self.assertEqual(result['content_tokens'], self.statement['chunk']['content_total'])
        self.assertEqual([x[0][2] for x in self.commands], ['check', 'run'])
        command, kwargs = self.commands[-1]
        self.assertEqual(command[command.index('--class') + 1], 'gpu')
        self.assertEqual(command[command.index('--need-gib') + 1], '12')
        self.assertEqual(command[command.index('--cap-gib') + 1], '16')
        self.assertEqual(command[command.index('--max-secs') + 1], '900')
        self.assertEqual(command[command.index('--expect-statement') + 1], self.runtime.IDENTITY)
        self.assertEqual(command[command.index('--export') + 1], str(self.runtime.VERIFIER_EXPORT))
        self.assertEqual(command[command.index('--min-bits') + 1], '95')
        self.assertEqual(command.count(w16.FLAG), 1)
        self.assertEqual(kwargs['env']['HL_A26_VERIFY_ONCE'], '0')
        self.assertEqual(kwargs['env']['HL_A26_KEPT'], '1')
        self.assertEqual(kwargs['env']['HL_A30_B3PAR'], '1')
        self.assertNotIn('HL_OWNER_PRIVATE_DIR', kwargs['env'])
        self.assertTrue(w16.PROVER_ONLY_SETTINGS.keys().isdisjoint(kwargs['env']))
        self.assertFalse(result['fresh_input_owner_check'])
        self.assertIs(result['public_content_only'], True)
        self.assertIs(result['production'], False)
        self.assertTrue(all(not p.exists() for p in self.snapshots))
        evidence = Path(result['evidence_dir'])
        self.assertTrue((evidence / 'verification.json').is_file())
        self.assertFalse(list(evidence.glob('receipt-*')))

    def test_public_verification_needs_no_writer_or_private_state(self):
        with patch.object(w16, 'Runtime', side_effect=AssertionError('app runtime not needed')), \
                patch.object(resident_writer, 'authenticate', side_effect=AssertionError('writer not needed')), \
                patch.dict(os.environ, {'PM_PROVER': 'stub', 'PM_FAST_WRITER_MODE': 'oneshot',
                                        'HL_OWNER_PRIVATE_DIR': '/must-not-be-used'}):
            result = self.run_fixture()
        self.assertTrue(result['ok'], result)
        self.assertFalse(config.PRIVATE_DIR.exists())

    def test_pending_intake_refuses_before_reconstruction(self):
        path = self.root / 'pending-intake.json'
        authority = {**self.authority, 'status': 'awaiting_native_binary',
                     'binary_sha256': None, 'statement_identity': None, 'run_profile': None}
        path.write_bytes(records.canonical(authority))
        with patch.object(w16, 'INTAKE', path), patch.object(w16, 'INTAKE_SHA', records.sha256_file(path)):
            result = self.assert_refused_before_guard()
        self.assertIn('pending', result['why'])
        self.assertFalse((config.PUBLIC_DIR / 'verify-from-store').exists())

    def test_changed_publication_pins_category_or_range_refuse(self):
        for changes in ({'model_id': baseline.IDENTITY}, {'verifier_id': '0' * 64},
                {'profile_id': baseline.PROFILE_SHA}, {'policy_id': '0' * 64}, {'category': 'unknown'},
                {'verdict': 'unproved'}, {'post_id': 'different'}, {'chunk': True}, {'chunk': 1},
                {'token_range': [-1, 14]}, {'token_range': [0, 13]}):
            with self.subTest(changes=changes):
                self.assert_refused_before_guard({**self.manifest, **changes})

    def test_changed_native_binary_or_public_export_refuses(self):
        self.binary.write_bytes(b'changed binary')
        self.assertIn('binary differs', self.assert_refused_before_guard()['why'])
        self.binary.write_bytes(b'SYNTHETIC TEST ONLY; NEVER EXECUTE\n')
        (self.runtime.VERIFIER_EXPORT / 'profile.json').write_text('{}')
        self.assertIn('profile differs', self.assert_refused_before_guard()['why'])

    def test_relocated_kit_selects_only_its_pinned_binary_and_public_inputs(self):
        kit = self.root / 'reader kit'
        binary = kit / verifier.KIT_BINARY
        binary.parent.mkdir(parents=True)
        self.binary.rename(binary)
        self.runtime.VERIFIER_EXPORT.rename(kit / 'export')
        with patch.dict(os.environ, PM_W16R2_VERIFIER_KIT=str(kit)):
            result = self.run_fixture()
            self.assertTrue(result['ok'], result)
            command = self.commands[-1][0]
            self.assertEqual(command[command.index('--') + 1], str(binary))
            self.assertEqual(command[command.index('--export') + 1], str(kit / 'export'))
            baseline.native_environment.assert_called_with(models=kit / 'models')
            binary.write_bytes(b'wrong verifier')
            self.assertIn('binary differs', self.assert_refused_before_guard()['why'])

    def test_hardware_public_scope_and_resource_changes_refuse(self):
        original = json.loads(config.DEPLOY_FILE.read_text())
        for changes in ({'public_content_only': False}, {'production': True}, {'min_bits': 94},
                        {'native_intake_sha256': '0' * 64}, {'guard_resources': {'service': {'need_gib': 110}}}):
            value = deepcopy(original)
            value['classifier_profiles']['shieldstral-mac-fast-w16r2'].update(changes)
            config.DEPLOY_FILE.write_text(json.dumps(value))
            with self.subTest(changes=changes):
                self.assert_refused_before_guard()

    def test_malformed_hardware_is_a_structured_refusal(self):
        for value in ([], {'classifier_profiles': []}, {'classifier_profiles': {'shieldstral-mac-fast-w16r2': []}}):
            config.DEPLOY_FILE.write_text(json.dumps(value))
            self.assert_refused_before_guard()

    def test_native_statement_scope_geometry_floor_and_template_refuse(self):
        original = deepcopy(self.statement)
        cases = [{'run_profile': baseline.RUN_PROFILE}, {'trained_statement_identity': baseline.IDENTITY},
            {'schema': 'zk60-classify-run/2'}, {'policy': 'other'}, {'T': 64}, {'blocks': 25},
            {'verdict_bit': True}, {'whole_run_floor_bits': 94}, {'whole_run_floor_bits': True},
            {'template_prefix_ids': [1]}, {'input_token_endpoint_root': 'bad'},
            {'chunk': {**original['chunk'], 'content_total': 10**30}},
            {'chunk': {**original['chunk'], 'index': 1}}]
        for changes in cases:
            self.set_statement({**original, **changes})
            with self.subTest(changes=changes):
                self.assert_refused_before_guard()

    def test_global_queue_index_maps_to_category_local_native_index(self):
        template = self.runtime.templates()[1]
        self.template = template
        self.category = next(c for c in self.runtime.categories() if c['id'] == template.category)
        self.manifest.update(category=self.category['id'], policy_id=self.category['sha256'], chunk=1)
        self.set_statement({**self.statement, 'policy': self.category['policy_id'],
                            'template_prefix_ids': list(template.prefix), 'template_suffix_ids': list(template.suffix)})
        result = self.run_fixture()
        self.assertTrue(result['ok'], result)
        self.assertEqual(result['verified']['chunk'], 0)

    def test_missing_duplicate_unsafe_or_oversized_segments_refuse(self):
        original = deepcopy(self.manifest['segments'])
        variants = [original[:-1], original + [original[0]], [original[0]] + original[:-1]]
        for changes in ({'file': '../escape'}, {'file': '/absolute'}, {'bytes': True},
                        {'bytes': verifier.MAX_SEGMENT + 1}, {'sha256': '../bad'}):
            rows = deepcopy(original); rows[0].update(changes); variants.append(rows)
        for rows in variants:
            with self.subTest(rows=rows[:1]):
                self.assert_refused_before_guard({**self.manifest, 'segments': rows})
        self.assert_refused_before_guard({**self.manifest, 'segments_json_sha256': 'c' * 64})

    def test_cas_statement_changed_or_duplicate_json_refuses(self):
        path = self.pub._obj(self.manifest['statement_sha256'])
        path.write_bytes(b'{}')
        self.assertIn('statement digest', self.assert_refused_before_guard()['why'])
        self.manifest['statement_sha256'] = self.pub.put_bytes(b'{"schema":1,"schema":2}')
        self.assertIn('duplicate JSON', self.assert_refused_before_guard()['why'])

    def test_cas_segment_tamper_and_symlink_refuse_before_admission(self):
        row = self.manifest['segments'][0]
        path = self.pub._obj(row['sha256'])
        original = path.read_bytes()
        path.write_bytes(b'X' * len(original))
        self.assertIn('segment digest', self.assert_refused_before_guard()['why'])
        target = self.root / 'symlink-target'; target.write_bytes(original)
        path.unlink(); path.symlink_to(target)
        self.assert_refused_before_guard()
        evidence = config.PUBLIC_DIR / 'verify-from-store'
        self.assertFalse(list(evidence.glob('*/receipt-*')))

    def test_changed_cas_after_copy_cannot_change_verified_snapshot(self):
        def execute(command, **kwargs):
            result = self.execute(command, **kwargs)
            if command[2] == 'run':
                row = self.manifest['segments'][0]
                self.pub._obj(row['sha256']).write_bytes(b'changed published source after snapshot')
                run = Path(command[command.index('--artifact') + 1])
                self.assertEqual(records.sha256_file(run / row['file']), row['sha256'])
            return result
        result = self.run_fixture(execute)
        self.assertTrue(result['ok'], result)

    def test_admission_wait_then_success_launches_one_guard(self):
        checks = 0
        def execute(command, **kwargs):
            nonlocal checks
            if command[2] == 'check':
                self.assertEqual(command[command.index('--need-gib') + 1], '12')
                checks += 1
                if checks == 1:
                    return SimpleNamespace(returncode=1, stdout='WOULD WAIT/REFUSE: fixture lock held\n')
            return self.execute(command, **kwargs)
        with patch.object(verifier.time, 'sleep') as sleep:
            result = self.run_fixture(execute)
        self.assertTrue(result['ok'], result)
        sleep.assert_called_once_with(5)
        self.assertEqual(sum(c[0][2] == 'run' for c in self.commands), 1)

    def test_admission_failure_or_expiry_never_launches_native(self):
        for rc, stdout in ((0, 'wrong check output'), (1, 'WOULD WAIT/REFUSE: busy'), (2, 'failure')):
            with self.subTest(rc=rc), patch.object(config, 'GUARD_WAIT_SECS', 0), \
                    patch.object(verifier.subprocess, 'run', return_value=SimpleNamespace(returncode=rc, stdout=stdout)) as run:
                result = self.tool.run_verifier(self.pub, self.manifest, self.post_id)
            self.assertFalse(result['ok'])
            self.assertTrue(all(c.args[0][2] == 'check' for c in run.call_args_list))

    def test_authority_change_while_waiting_refuses_before_native(self):
        def execute(command, **kwargs):
            result = self.execute(command, **kwargs)
            if command[2] == 'check':
                (self.runtime.VERIFIER_EXPORT / 'profile.json').write_text('{}')
            return result
        result = self.run_fixture(execute)
        self.assertFalse(result['ok'])
        self.assertEqual(len(self.commands), 1)

    def test_app_lane_hold_refuses_without_guard_or_native_launch(self):
        held = self.root / 'HOLD'
        held.touch()
        with patch.object(config, 'HOLD_FILE', held):
            result = self.assert_refused_before_guard()
        self.assertIn('lane is held', result['why'])

    def test_authority_changed_during_native_check_cannot_accept(self):
        def execute(command, **kwargs):
            result = self.execute(command, **kwargs)
            if command[2] == 'run':
                self.binary.write_bytes(b'changed binary during check')
            return result
        result = self.run_fixture(execute)
        self.assertFalse(result['ok'])
        self.assertIn('binary differs', result['why'])

    def test_success_line_does_not_mask_refusal_duplicate_or_changed_verdict(self):
        for events in ([self.event(), {'event': 'refused'}], [self.event(), self.event()],
                       [{**self.event(), 'verdict': 'flagged'}], [{**self.event(), 'whole_run_floor_bits': 94}],
                       [{**self.event(), 'chunk': 2}], [{**self.event(), 'input_token_endpoint_root': 'd' * 64}]):
            def execute(command, **kwargs):
                result = self.execute(command, **kwargs)
                if command[2] == 'run':
                    Path(command[command.index('--log') + 1]).write_text('\n'.join(json.dumps(e) for e in events) + '\n')
                return result
            with self.subTest(events=events):
                self.assertFalse(self.run_fixture(execute)['ok'])

    def test_missing_or_unclean_guard_terminal_cannot_accept(self):
        for field, value in [('exit', 1), ('child_rc', 1), ('hard_killed', 1), ('stragglers_killed', 1),
                             ('guard_killed', 'cap'), ('guard_error', 'failure'), ('exit', False)]:
            def execute(command, **kwargs):
                result = self.execute(command, **kwargs)
                if command[2] == 'run':
                    path = Path(command[command.index('--result-json') + 1])
                    terminal = json.loads(path.read_text()); terminal[field] = value
                    path.write_text(json.dumps(terminal))
                return result
            with self.subTest(field=field, value=value):
                self.assertFalse(self.run_fixture(execute)['ok'])

    def test_native_mutation_of_snapshot_refuses_and_scratch_is_removed(self):
        def execute(command, **kwargs):
            result = self.execute(command, **kwargs)
            if command[2] == 'run':
                run = Path(command[command.index('--artifact') + 1])
                (run / 'statement/statement.json').write_text('{}')
            return result
        result = self.run_fixture(execute)
        self.assertFalse(result['ok'])
        self.assertIn('statement changed', result['why'])
        self.assertTrue(all(not p.exists() for p in self.snapshots))

    def test_main_never_runs_native_after_rejected_publication(self):
        publisher = Mock()
        publisher.anchor_of.return_value = SimpleNamespace(post_id=self.post_id, to_dict=lambda: {})
        publisher.verify_publication.return_value = {'accepted': False, 'reasons': ['bad anchor'],
                                                     'checks': {}, 'manifest': self.manifest}
        argv = ['verify_publication.py', '--post-id', self.post_id, '--category', self.category['id'], '--run-verifier']
        output = io.StringIO()
        with patch.object(self.tool, 'make_publisher', return_value=publisher), patch.object(self.tool.sys, 'argv', argv), \
                patch.object(self.tool, 'run_verifier') as native, patch('sys.stdout', output):
            rc = self.tool.main()
        self.assertEqual(rc, 1)
        native.assert_not_called()
        result = json.loads(output.getvalue())
        self.assertIs(result['proof_verifier']['skipped'], True)

    def test_complete_local_publication_and_tool_path_with_simulated_native(self):
        directory = self.root / 'synthetic-publication-inputs'; directory.mkdir()
        for row in self.manifest['segments']:
            (directory / row['file']).write_bytes(self.pub._obj(row['sha256']).read_bytes())
        publication = PublicationRecord(post_id=self.post_id, category=self.category['id'],
            statement=records.canonical(self.statement), receipt_segments=[str(directory / n) for n in verifier.NAMES],
            verdict='no', model_id=self.runtime.IDENTITY, policy_id=self.category['sha256'],
            profile_id=self.runtime.PROFILE_SHA, verifier_id=self.runtime.BINARY_SHA, content_commitment='e' * 64,
            receipt_inventory=self.manifest['segments'], proof_verified=True, verdict_bound=True,
            development_only=False, chunk=0, token_range=(0, 14))
        self.pub.publish(publication)
        self.pub.tick(force=True)
        argv = ['verify_publication.py', '--post-id', self.post_id, '--category', self.category['id'], '--run-verifier']
        output = io.StringIO()
        with patch.object(self.tool, 'make_publisher', return_value=self.pub), patch.object(self.tool.sys, 'argv', argv), \
                patch.object(verifier.subprocess, 'run', side_effect=self.execute), patch('sys.stdout', output):
            rc = self.tool.main()
        result = json.loads(output.getvalue())
        self.assertEqual(rc, 0, result)
        self.assertIs(result['accepted'], True)
        self.assertIs(result['checks']['proof_verifier'], True)
        self.assertIs(result['proof_verifier']['public_content_only'], True)


if __name__ == '__main__':
    unittest.main()

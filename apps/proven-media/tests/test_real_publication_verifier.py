"""Check public verifier routing with synthetic bytes and mocked CLI outcomes."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from types import SimpleNamespace
from native_fixtures import native_binary_fixture, use_context

from proven_media import config, records, shieldstral_runtime as runtime

spec = importlib.util.spec_from_file_location('verify_publication_real_test', config.TOOLS_DIR/'verify_publication.py')
tool = importlib.util.module_from_spec(spec); spec.loader.exec_module(tool)


class RealPublicationVerifierControls(unittest.TestCase):
    def setUp(self):
        use_context(self, native_binary_fixture())
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name); store = self.root/'objects'; store.mkdir()
        for digest in ('11'*32, '22'*32): (store/digest).write_bytes(b'UNIT FIXTURE NOT A PROOF')
        self.pub = SimpleNamespace(store=store, _obj=lambda digest: store/digest)
        self.manifest = {'verifier_id': runtime.BINARY_SHA, 'category': 'sexual', 'model_id': runtime.IDENTITY,
            'profile_id': runtime.PROFILE_SHA, 'policy_id': runtime.POLICY_SHAS['sexual'],
            'statement_sha256': '11'*32, 'segments': [{'file': 'segment-000.bin', 'sha256': '22'*32}],
            'verdict': 'no', 'chunk': 0}

    def test_real_verifier_uses_pinned_model_policy_floor_and_guard(self):
        calls = []
        def execute(command, **kwargs):
            calls.append(command)
            log = Path(command[command.index('--log')+1])
            log.write_text(json.dumps({'event': 'classified', 'trained_statement_identity': runtime.IDENTITY,
                'policy': 'shieldstral-1.0-3b-moderate-sexual/1', 'verdict': 'not-flagged',
                'whole_run_floor_bits': 96})+'\n')
            return SimpleNamespace(returncode=0)
        with patch.object(tool.subprocess, 'run', side_effect=execute):
            result = tool.run_verifier(self.pub, self.manifest, 'fixture')
        self.assertTrue(result['ok'])
        cmd = calls[0]
        self.assertEqual(cmd[cmd.index('--need-gib')+1], '2.9')
        self.assertEqual(cmd[cmd.index('--min-bits')+1], '95')
        self.assertEqual(cmd[cmd.index('--expect-statement')+1], runtime.IDENTITY)
        self.assertIn('RAYON_NUM_THREADS=2', cmd)
        self.assertTrue((Path(result['rebuilt_run'])/'statement/statement.json').exists())

    def test_wrong_publication_pins_never_launch_a_verifier(self):
        for changes in ({'category':'missing'}, {'model_id':'00'*32}, {'policy_id':runtime.POLICY_SHAS['hate']},
                        {'verifier_id':'00'*32}, {'profile_id':'00'*32}, {'verdict': 'unproved'}, {'verdict': None}):
            with self.subTest(changes=changes), patch.object(tool.subprocess, 'run') as run:
                self.assertFalse(tool.run_verifier(self.pub, {**self.manifest, **changes}, 'fixture')['ok'])
                run.assert_not_called()

    def test_success_line_cannot_mask_a_native_refusal(self):
        def execute(command, **kwargs):
            Path(command[command.index('--log')+1]).write_text('\n'.join(map(json.dumps,
                [{'event':'classified'}, {'event':'refused'}]))+'\n')
            return SimpleNamespace(returncode=0)
        with patch.object(tool.subprocess, 'run', side_effect=execute):
            self.assertFalse(tool.run_verifier(self.pub,self.manifest,'fixture')['ok'])


if __name__ == '__main__': unittest.main()

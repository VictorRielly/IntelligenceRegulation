"""Adapter controls using explicit token/statement fixtures, never native proofs."""
from copy import deepcopy
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from native_fixtures import native_binary_fixture, use_context

from proven_media import config, records, shieldstral_runtime as runtime
from proven_media.items import TextItem
from proven_media.provers import ProverError
from proven_media.shieldstral_prover import ShieldstralProver
from proven_media.shieldstral_text import ShieldstralTextEncoder


class RealAdapterControls(unittest.TestCase):
    def setUp(self):
        use_context(self, native_binary_fixture())
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        patches = [patch.dict(os.environ, {'PM_PROVER': 'shieldstral'}),
                   patch.object(config, 'RUNS_DIR', self.root/'public/runs')]
        # Same encoder interface/type; fixture IDs deliberately avoid dependence
        # on optional tokenizer packages. The real encoder has its own A1 gate.
        self.encoder = object.__new__(ShieldstralTextEncoder)
        self.encoder.content_ids = lambda text: tuple(range(1000, 1000+len(text.split())))
        patches.append(patch('proven_media.shieldstral_prover.ShieldstralTextEncoder', return_value=self.encoder))
        for p in patches:
            p.start(); self.addCleanup(p.stop)
        self.prover = ShieldstralProver()
        self.text = 'a calm afternoon in the garden'

    def fixtures(self, text=None):
        text = text or self.text
        rows = []
        for ch in self.prover.plan_text(text):
            t = next(t for t in self.prover.templates if t.category == ch['category'])
            n = ch['end']-ch['start']; length = len(t.prefix)+n+len(t.suffix)
            statement = {'schema': 'zk60-classify-run/3', 'policy': t.policy_id, 'verdict_bit': 0,
                'content_length_n': n, 'T': 128, 'item_length': length, 'pad_id': 11,
                'pad_positions': 128-length, 'verdict_row': length-1,
                'template_prefix_ids': list(t.prefix), 'template_suffix_ids': list(t.suffix),
                'chunk': {'index': ch['category_chunk_index'], 'count': ch['category_chunks'],
                          'content_total': ch['content_total'], 'chunk_size': ch['chunk_tokens'],
                          'overlap': 8, 'range': [ch['start'], ch['end']]}}
            rows.append({'chunk': ch, 'statement': statement, 'statement_sha256': f'{ch["index"]:064x}', 'checks': {}})
        for t in self.prover.templates:
            group = [r for r in rows if r['chunk']['category'] == t.category]
            group[-1]['checks']['category_aggregate'] = {'total': len(text.split()),
                'statement_sha256': [r['statement_sha256'] for r in group],
                'result': {'value': 'no', 'proof': 'accepted', 'bound_by_proof': True,
                           'chunks': len(group), 'policy_id': t.policy_id}}
        return rows

    def test_real_preparation_uses_whole_post_and_separate_category_jobs(self):
        item = TextItem(self.text); plan = self.prover.plan_text(item.text)
        artifacts = []
        for ch in plan:
            job = self.root/'private/post'/('prove' if ch['index']==0 else f'prove-c{ch["index"]}')
            self.prover.prepare('post', item, job, ch)
            spec = json.loads((job/'classifier-job.json').read_text())
            request = json.loads((job/'activation-request.json').read_text())
            self.assertEqual(spec['chunk'], 0)
            self.assertEqual(spec['total'], len(item.text.split()))
            self.assertEqual(request[0]['policy_id'], ch['policy_id'])
            self.assertEqual(spec['deployment']['binary_sha256'], runtime.BINARY_SHA)
            self.assertTrue(spec['last_category_chunk'])
            self.assertEqual((job/'content.ids').stat().st_mode & 0o777, 0o600)
            self.assertEqual(tuple(map(int,(job/'content.ids').read_text().split(','))), self.encoder.content_ids(item.text))
            self.assertFalse((job/'activations').exists())
            artifacts.append(spec['artifact'])
        self.assertEqual(len(set(artifacts)), 3)

    def test_queue_slot_cannot_change_category_or_total_before_preparation(self):
        base = self.prover.plan_text(self.text)[0]
        for change in ({'category': 'hate'}, {'content_total': 1}, {'category_chunk_index': 1}, {'index': True}):
            job = self.root/'bad'
            with self.subTest(change=change), self.assertRaises(ProverError):
                self.prover.prepare('post', TextItem(self.text), job, {**base, **change})
            self.assertFalse(job.exists())

    def test_registered_threshold_change_refuses_before_any_job(self):
        with patch.object(config, 'TAU', 0.6), self.assertRaises(ProverError):
            self.prover.prepare('post', TextItem(self.text), self.root/'bad', self.prover.plan_text(self.text)[0])
        self.assertFalse((self.root/'bad').exists())

    def test_native_aggregate_required_for_each_category_and_exact_proof_set(self):
        clean = self.fixtures()
        self.prover.check_final_records(TextItem(self.text), clean)
        for mode in ('missing', 'wrong-total', 'wrong-hash', 'unbound', 'wrong-policy', 'wrong-verdict'):
            rows = deepcopy(clean); check = rows[-1]['checks']['category_aggregate']
            if mode == 'missing': rows[-1]['checks'].clear()
            elif mode == 'wrong-total': check['total'] -= 1
            elif mode == 'wrong-hash': check['statement_sha256'] = ['ff'*32]
            elif mode == 'unbound': check['result']['bound_by_proof'] = False
            elif mode == 'wrong-policy': check['result']['policy_id'] = runtime.deployment(self.prover.templates[0]).policy
            else: check['result']['value'] = 'yes'
            with self.subTest(mode=mode), self.assertRaises(ProverError):
                self.prover.check_final_records(TextItem(self.text), rows)

    def test_multichunk_coverage_refuses_prefix_and_template_changes(self):
        text = ' '.join(['word']*60); rows = self.fixtures(text)
        self.prover.check_final_records(TextItem(text), rows)
        with self.assertRaises(ValueError):
            self.prover.check_final_records(TextItem(text+' more'), rows)
        rows[-1]['statement']['template_prefix_ids'][0] = 2
        with self.assertRaises(ValueError):
            self.prover.check_final_records(TextItem(text), rows)

    def test_runtime_refuses_unreviewed_binary_and_wrong_profile(self):
        from dataclasses import replace
        deployment = runtime.deployment(self.prover.templates[0])
        for changes in ({'binary_sha256': '00'*32}, {'min_bits': 94}, {'statement_identity': '00'*32},
                        {'policy': 'shieldstral-1.0-3b-card-unsafe/1'}, {'chunk_size': 49}):
            with self.subTest(changes=changes), self.assertRaises(ProverError):
                runtime.validate(replace(deployment, **changes))

    def test_recheck_reaches_native_verifier_even_if_receipt_is_missing(self):
        from types import SimpleNamespace
        ch = self.prover.plan_text(self.text)[0]
        original = self.root/'private/post/prove'
        self.prover.prepare('post', TextItem(self.text), original, ch)
        spec = json.loads((original/'classifier-job.json').read_text())
        record = SimpleNamespace(post_id='post', prover=self.prover.describe(), chunk=ch,
                                 receipt={'run_dir': spec['artifact']})
        self.assertFalse(Path(spec['artifact']).exists())
        target = self.root/'private/post/recheck'
        self.prover.prepare_recheck(record, original, target)
        self.assertEqual(json.loads((target/'classifier-job.json').read_text())['mode'], 'recheck')
        (target/'pipeline.done').write_text('1\n')
        result = self.prover.collect_recheck(record, target)
        self.assertFalse(result.proof_valid)
        self.assertTrue(result.details['rejected'])


if __name__ == '__main__': unittest.main()

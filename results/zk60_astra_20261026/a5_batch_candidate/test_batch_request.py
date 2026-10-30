"""Light transport/negative controls; these tests do not produce native proofs."""
import copy
import json
import os
from pathlib import Path
import stat
import sys
import tempfile
import unittest
from unittest.mock import patch

import batch_request as batch
from proven_media.provers import ProverError
from proven_media.prompting import ContentRefused


class BatchTests(unittest.TestCase):
    def setUp(self):
        self.env = patch.dict(os.environ, {'PM_PROVER': 'shieldstral'})
        self.env.start(); self.addCleanup(self.env.stop)
        self.tmp = tempfile.TemporaryDirectory(prefix='astra-a5-test-')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.receipts = self.root / 'receipts'; self.receipts.mkdir()
        self.private = self.root / 'private'; self.private.mkdir(mode=0o700)
        self.job = self.private / 'batch'

    def prepare(self, total=35, **kwargs):
        plan = batch.proof_plans.category_work_plan(total, batch.runtime.templates())
        return batch.prepare_ids('test-post', (1500,) * total, kwargs.pop('plan', plan), self.job, self.receipts,
                                 reserved_context=kwargs.pop('context', batch.records.screening_context()), **kwargs)

    def recorded_log(self, manifest):
        # Native R16 real log payloads are read unchanged except for the
        # destination paths. Batch wrapper events below are transport fixtures.
        # No receipt is read, accepted, regenerated, or published by this test.
        result = [{'event': 'batch-loaded', 'jobs': len(manifest['jobs']), 'model_loads': 1, 'table_loads': 1,
                   'load_seconds': 0, 'trained_statement_identity': batch.runtime.IDENTITY, 'context_label': batch.CONTEXT}]
        for i, row in enumerate(manifest['jobs']):
            cat = row['policy_id'].split('-moderate-')[1].split('/')[0]
            source = batch.REPO / f'results/zk60_token_io_r1_20261017/r16/logs/real-prove-{cat}.log'
            events = [json.loads(line) for line in source.read_text().splitlines() if line.strip()]
            events[-1]['run'], events[-1]['owner_dir'] = row['out'], row['owner_dir']
            result.append({'event': 'batch-job-start', 'index': i, 'name': row['name'],
                           'policy': row['policy_id'], 'chunk': row['chunk_index']})
            result.extend(events)
            result.append({'event': 'batch-job-proved', 'index': i, 'name': row['name']})
        result.append({'event': 'batch-proved', 'jobs': len(manifest['jobs']), 'total_seconds': 0, 'verified': False})
        return result

    @staticmethod
    def stream(events):
        return '\n'.join(json.dumps(e) for e in events) + '\n'

    def test_one_private_content_and_activation_request_for_all_categories(self):
        m = self.prepare()
        request = json.loads((self.job / 'activation-request.json').read_text())
        self.assertEqual(len(request), 3)
        self.assertEqual({r['content_file'] for r in request}, {str(self.job / 'content.ids')})
        self.assertEqual([r['policy_id'] for r in request], [r['policy_id'] for r in m['jobs']])
        for path in self.job.glob('*.json'):
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE((self.job / 'content.ids').stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(self.job.stat().st_mode), 0o700)
        self.assertFalse(any(self.receipts.iterdir()))

    def test_all_chunk_geometries_and_tail(self):
        m = self.prepare(336)
        work = batch.validate_manifest(m, 336)
        counts = [len([ch for ch in work if ch['category'] == c]) for c in ('sexual', 'violence', 'hate')]
        self.assertEqual(counts, [7, 7, 8])
        self.assertEqual(len(m['jobs']), 22)
        for c in ('sexual', 'violence', 'hate'):
            self.assertEqual([ch for ch in work if ch['category'] == c][-1]['end'], 336)

    def test_over_limit_refused_before_writes(self):
        with self.assertRaises((ProverError, ContentRefused)): self.prepare(337)
        self.assertFalse(self.job.exists())

    def test_changed_reservation_refused_before_writes(self):
        plan = batch.proof_plans.category_work_plan(17, batch.runtime.templates())
        with self.assertRaises((ProverError, ContentRefused)): self.prepare(35, plan=plan)
        self.assertFalse(self.job.exists())

    def test_changed_policy_context_refused_before_writes(self):
        with self.assertRaises(ProverError): self.prepare(context='another reservation')
        self.assertFalse(self.job.exists())

    def test_no_automatic_retry_or_overwrite(self):
        self.prepare()
        before = (self.job / 'content.ids').read_bytes()
        with self.assertRaises(ProverError): self.prepare()
        self.assertEqual((self.job / 'content.ids').read_bytes(), before)

    def test_dangling_job_symlink_refused(self):
        self.job.symlink_to(self.private / 'absent')
        with self.assertRaises(ProverError): self.prepare()
        self.assertFalse((self.private / 'absent').exists())

    def test_existing_receipt_refused(self):
        (self.receipts / 'test-post-c1.unverified-statement').mkdir()
        with self.assertRaises(ProverError): self.prepare()
        self.assertFalse(self.job.exists())

    def test_missing_repeated_or_reordered_category(self):
        original = self.prepare()
        for mutate in (lambda m: m['jobs'].pop(), lambda m: m['jobs'].__setitem__(1, m['jobs'][0]),
                       lambda m: m['jobs'].reverse()):
            m = copy.deepcopy(original); mutate(m)
            with self.assertRaises(ProverError): batch.validate_manifest(m, 35)

    def test_truncated_count_boolean_and_changed_identity(self):
        original = self.prepare()
        for key, value in [('content_total', 17), ('content_total', True), ('expect_statement', '0' * 64)]:
            m = copy.deepcopy(original); m[key] = value
            with self.assertRaises(ProverError): batch.validate_manifest(m, 35)

    def test_owner_under_other_receipt_parent_refused(self):
        m = self.prepare(); m['jobs'][0]['owner_dir'] = str(self.receipts / 'private-owner')
        with self.assertRaises(ProverError): batch.validate_manifest(m, 35)

    def test_valid_native_payloads_route_as_unverified(self):
        m = self.prepare(); result = batch.split_unverified_log(self.stream(self.recorded_log(m)), 0, m, 35)
        self.assertEqual(result['status'], 'unverified')
        self.assertEqual(list(result['logs']), ['c0', 'c1', 'c2'])
        self.assertFalse('accepted' in result)

    def test_partial_batch_and_failed_exit_never_succeed(self):
        m = self.prepare(); events = self.recorded_log(m)
        for partial in (events[:-1], events[:33] + events[-1:], events[1:]):
            with self.assertRaises(ProverError): batch.split_unverified_log(self.stream(partial), 0, m, 35)
        with self.assertRaises(ProverError): batch.split_unverified_log(self.stream(events), 1, m, 35)

    def test_refusal_cannot_be_hidden_by_success(self):
        m = self.prepare(); events = self.recorded_log(m)
        for kind in ('refused', 'app-outcome', 'REMOVAL-FAILED', 'classified'):
            changed = copy.deepcopy(events); changed.insert(3, {'event': kind})
            with self.assertRaises(ProverError): batch.split_unverified_log(self.stream(changed), 0, m, 35)

    def test_duplicate_or_reordered_segment_refused(self):
        m = self.prepare(); events = self.recorded_log(m)
        changed = copy.deepcopy(events); changed[4]['index'] = changed[3]['index']
        with self.assertRaises(ProverError): batch.split_unverified_log(self.stream(changed), 0, m, 35)

    def test_swapped_policy_floor_or_receipt_size_refused(self):
        m = self.prepare(); events = self.recorded_log(m)
        for key, value in [('policy', m['jobs'][1]['policy_id']), ('whole_run_floor_bits', 94), ('receipt_bytes', 1)]:
            changed = copy.deepcopy(events)
            next(e for e in changed if e['event'] == 'proved')[key] = value
            with self.assertRaises(ProverError): batch.split_unverified_log(self.stream(changed), 0, m, 35)

    def test_prover_cannot_claim_verified(self):
        m = self.prepare(); events = self.recorded_log(m); events[-1]['verified'] = True
        with self.assertRaises(ProverError): batch.split_unverified_log(self.stream(events), 0, m, 35)

    def test_duplicate_json_keys_and_nonfinite_refused(self):
        m = self.prepare(); original = self.stream(self.recorded_log(m))
        for changed in (original.replace('"jobs": 3', '"jobs": 4, "jobs": 3', 1),
                        original.replace('"load_seconds": 0', '"load_seconds": NaN', 1)):
            with self.assertRaises(ProverError): batch.split_unverified_log(changed, 0, m, 35)

    def test_preparation_uses_existing_writer_batch_interface(self):
        self.prepare(56)
        sys.path.insert(0, str(batch.runtime.EXPORT_ROOT))
        import write_item_activations as writer
        rows = json.loads((self.job / 'activation-request.json').read_text())
        prepared = writer.prepare_requests(rows)
        self.assertEqual(len(prepared), 6)
        self.assertEqual([p['name'] for p in prepared], [r['name'] for r in rows])

    def test_pinned_tokenizer_preparation(self):
        text = 'Today I planted basil and watered the garden. The afternoon was quiet and sunny.'
        plan = batch.proof_plans.category_work_plan(17, batch.runtime.templates())
        m = batch.prepare_text('encoding-only', text, plan, self.job, self.receipts,
                               reserved_context=batch.records.screening_context())
        self.assertEqual(m['content_total'], 17)
        self.assertEqual(len(m['jobs']), 3)


if __name__ == '__main__':
    unittest.main()

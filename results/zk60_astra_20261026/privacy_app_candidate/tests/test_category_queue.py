"""Queue/HTTP-handler regression tests with a word-count fixture, never a native proof.

The fixture is unavailable from make_prover. It deliberately uses the local
test ledger and unbound labels to exercise publication addressing only.
"""
import asyncio
from copy import deepcopy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from proven_media import auth, config, proof_plans, records
from proven_media.items import TextItem
from proven_media.jobs import Worker
from proven_media.provers import ClassifierProver
from proven_media.publisher import LocalChainPublisher
from proven_media.shieldstral_text import CategoryTemplate
from proven_media.store import Store, loads


class CategoryFixture(ClassifierProver):
    kind = 'category-queue-test-only'
    label = 'TEST FIXTURE: no native proof'
    separate_categories = True
    supports = frozenset({'text'})

    def __init__(self):
        self.templates = tuple(CategoryTemplate(c['id'], c['policy_id'],
            (1,) + (1000,) * (126 - size), (4,), 128, 2, 8)
            for c, size in zip(config.CATEGORIES, (8, 11, 15)))
        self.reject_rechecks = False
        self.mutate = lambda record: None

    def content_length(self, text):
        return len(text.split())

    def plan_text(self, text):
        return proof_plans.category_work_plan(self.content_length(text), self.templates)

    def start(self, post_id, item, job, chunk=None):
        job.mkdir(parents=True)
        (job / 'pipeline.done').write_text('0\n')

    def collect(self, post_id, item, job, chunk=None):
        ch = deepcopy(chunk)
        cat = next(c for c in config.CATEGORIES if c['id'] == ch['category'])
        bit = int(cat['id'] == 'violence' and ch['category_chunk_index'] == 1)
        st = {'schema': 'zk60-classify-run/3', 'policy': cat['policy_id'], 'verdict_bit': bit,
              'content_length_n': ch['end'] - ch['start'],
              'chunk': {'index': ch['category_chunk_index'], 'count': ch['category_chunks'],
                        'range': [ch['start'], ch['end']], 'content_total': ch['content_total'],
                        'chunk_size': ch['chunk_tokens'], 'overlap': ch['overlap_tokens']}}
        rec = records.ProofRecord(post_id=post_id, item_kind='text', prover=self.describe(),
            labels={cat['id']: {'value': 'yes' if bit else 'no', 'proof': 'accepted', 'bound_by_proof': False,
                               'policy_id': cat['policy_id'], 'policy_sha256': cat['sha256'],
                               'source': 'TEST FIXTURE: no native proof'}},
            policies=[], threshold=records.threshold(), content_commitment={}, statement=st,
            statement_sha256=None, receipt={'run_dir': '', 'files': [], 'segments': 0, 'bytes': 0},
            timings={}, security={}, checks={'verify': {'ok': False}}, chunk=ch)
        self.mutate(rec)
        return rec

    def start_recheck(self, record, prove_job, job):
        self.start(record.post_id, None, job)

    def collect_recheck(self, record, job):
        return records.Verdict('re-check', not self.reject_rechecks, False, 'TEST FIXTURE',
                               details={'rejected': self.reject_rechecks})


class CategoryQueueTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.addCleanup(self.tmp.cleanup)
        for key, path in {'PRIVATE_DIR': self.root / 'private', 'JOBS_DIR': self.root / 'jobs',
                          'SIGNING_KEY': self.root / 'private/key', 'HOLD_FILE': self.root / 'HOLD'}.items():
            p = patch.object(config, key, path)
            p.start()
            self.addCleanup(p.stop)
        self.store = Store(self.root / 'app.sqlite3')
        self.addCleanup(lambda: self.store.db.close())
        self.prover = CategoryFixture()
        self.pub = LocalChainPublisher(self.root / 'public')
        self.worker = Worker(self.store, self.prover, self.pub)
        self.text = ' '.join(f'word{i}' for i in range(20))

    def submit(self, text=None):
        text = text or self.text
        plan = self.prover.plan_text(text)
        self.store.add_screened_post(text, plan, id='ab' * 16, author='@test', kind='text', text=text,
            status='queued', prover_kind=self.prover.kind, chunks=json.dumps(plan),
            content_key=records.content_key(text), salt_enc=records.new_salt_enc('ab' * 16))
        return 'ab' * 16, plan

    def drain(self):
        for _ in range(40):
            if not self.store.one("SELECT id FROM jobs WHERE status IN ('queued','running')"):
                return
            self.worker.tick()
        self.fail('fixture jobs did not terminate')

    def test_distinct_geometry_survives_worker_and_database_restart(self):
        pid, plan = self.submit()
        self.assertEqual([sum(ch['category'] == c for ch in plan) for c in records.category_ids()], [3, 2, 2])
        self.worker.tick()  # first job has a completion marker, but has not been collected
        self.store.db.close()
        self.store = Store(self.root / 'app.sqlite3')
        self.worker = Worker(self.store, self.prover, self.pub)
        self.drain()
        post = self.store.post(pid)
        self.assertEqual(post['status'], 'published')
        self.assertEqual(loads(post['labels']), {'sexual': 'no', 'violence': 'yes', 'hate': 'no'})
        item = loads(post['record'])
        self.assertEqual(item['content_length'], 20)
        self.assertEqual([len(item['labels'][c]['chunks']) for c in records.category_ids()], [3, 2, 2])
        entries = loads(post['manifest'])['entries']
        self.assertEqual(len(entries), 7)  # one entry per planned proof, never 7 * 3
        self.assertEqual(len(self.pub.anchors_of(pid)), 7)
        for ch, entry in zip(plan, entries):
            self.assertEqual((entry['category'], entry['category_chunk_index'], entry['token_range']),
                             (ch['category'], ch['category_chunk_index'], [ch['start'], ch['end']]))
            anchor = self.pub.anchor_of(pid, ch['category'], ch['index'])
            published = self.pub.resolve(anchor)['manifest']
            self.assertEqual(published['token_range'], [ch['start'], ch['end']])
            self.assertFalse(item['labels'][ch['category']]['bound_by_proof'])

    def test_missing_category_proof_never_partially_publishes(self):
        pid, plan = self.submit()
        dropped = next(ch['index'] for ch in plan if ch['category'] == 'hate')
        self.store.x('DELETE FROM jobs WHERE chunk=?', (dropped,))
        self.drain()
        self.assertEqual(self.store.post(pid)['status'], 'failed')
        self.assertEqual(self.pub.anchors_of(pid), {})

    def test_failed_final_native_aggregate_cannot_publish(self):
        from proven_media.provers import ProverError
        pid, _ = self.submit()
        self.prover.check_final_records = lambda item, rows: (_ for _ in ()).throw(ProverError('native aggregate missing'))
        self.drain()
        self.assertEqual(self.store.post(pid)['status'], 'failed')
        self.assertEqual(self.pub.anchors_of(pid), {})

    def test_classifier_path_requires_real_verification_and_input_binding(self):
        pid, plan = self.submit()
        self.prover.proves_verdict = True
        self.drain()
        self.assertEqual(self.store.post(pid)['status'], 'failed')
        self.assertEqual(self.pub.anchors_of(pid), {})

    def test_truncated_or_downgraded_plan_never_launches(self):
        for mode in ('prefix', 'drop-category', 'downgrade', 'duplicate-index'):
            with self.subTest(mode=mode):
                text = self.text + ' ' + mode
                # Reset only the isolated fixture DB, retaining no real user data.
                for table in ('posts', 'jobs', 'screenings', 'chunk_proofs'):
                    self.store.x(f'DELETE FROM {table}')
                pid, plan = self.submit(text)
                if mode == 'prefix':
                    plan = self.prover.plan_text(' '.join(text.split()[:-1]))
                elif mode == 'drop-category':
                    plan = [ch for ch in plan if ch['category'] != 'hate']
                elif mode == 'downgrade':
                    plan = [{k: ch[k] for k in ('index', 'start', 'end')} for ch in plan]
                else:
                    plan[1]['index'] = 0
                self.store.update_post(pid, chunks=json.dumps(plan))
                self.drain()
                self.assertEqual(self.store.post(pid)['status'], 'failed')
                self.assertEqual(self.pub.anchors_of(pid), {})
                self.assertFalse((config.JOBS_DIR / pid).exists())

    def test_wrong_receipt_range_policy_total_or_label_fails_closed(self):
        pid, plan = self.submit()
        original = self.prover.collect(pid, TextItem(self.text), None, plan[0]).to_dict()
        for field in ('category', 'range', 'total', 'policy', 'label', 'threshold', 'index'):
            rec = deepcopy(original)
            if field == 'category': rec['labels']['hate'] = rec['labels'].pop('sexual')
            if field == 'range': rec['statement']['chunk']['range'] = [1, 9]
            if field == 'total': rec['statement']['chunk']['content_total'] -= 1
            if field == 'policy': rec['labels']['sexual']['policy_sha256'] = '00' * 32
            if field == 'label': rec['labels']['sexual']['value'] = 'yes'
            if field == 'threshold': rec['threshold']['tau'] = 0.9
            if field == 'index': rec['statement']['chunk']['index'] = True
            with self.subTest(field=field), self.assertRaises(ValueError):
                proof_plans.check_category_record(rec, pid, plan[0])
        self.prover.mutate = lambda rec: rec.statement['chunk'].update(content_total=19)
        self.drain()
        self.assertEqual(self.store.post(pid)['status'], 'failed')
        self.assertEqual(self.pub.anchors_of(pid), {})

    def test_recheck_withdraws_whole_item_and_retains_existing_anchors(self):
        pid, plan = self.submit()
        self.drain()
        self.prover.reject_rechecks = True
        self.store.add_job(pid, 'check', plan[-1]['index'])
        self.drain()
        self.assertEqual(self.store.post(pid)['status'], 'failed')
        self.assertEqual(loads(self.store.post(pid)['record'])['labels']['hate']['proof'], 'none')
        self.assertEqual(len(self.pub.anchors_of(pid)), len(plan))

    def test_plan_changed_while_job_runs_terminates_without_relaunch(self):
        pid, plan = self.submit()
        self.worker.tick()
        self.store.update_post(pid, chunks=json.dumps(self.prover.plan_text('shorter post')))
        self.worker = Worker(self.store, self.prover, self.pub)
        self.drain()
        self.assertEqual(self.store.post(pid)['status'], 'failed')
        self.assertEqual(self.pub.anchors_of(pid), {})
        self.assertEqual(len(list((config.JOBS_DIR / pid).iterdir())), 1)

    def test_http_handlers_use_prover_encoder_and_exact_proof_count(self):
        from proven_media import app
        class Request:
            async def json(_self): return {'text': self.text}
        with patch.object(app.S, 'store', self.store, create=True), patch.object(app.S, 'prover', self.prover, create=True), patch.object(app, 'require_session', return_value=auth.Session('@test', False, 'test-only')):
            count = asyncio.run(app.api_tokenize(Request()))
            self.assertEqual((count['count'], count['proofs'], count['category_chunks']),
                             (20, 7, {'sexual': 3, 'violence': 2, 'hate': 2}))
            response = asyncio.run(app.api_create_post(req=Request(), author='test', kind='text', text=self.text, file=None))
            self.assertEqual((response['chunks'], response['proofs']), (7, 7))
            self.assertEqual(len(self.store.q('SELECT * FROM jobs')), 7)

    def test_short_item_has_one_padded_proof_per_category(self):
        pid, plan = self.submit('three short words')
        self.drain()
        self.assertEqual(len(plan), 3)
        self.assertTrue(all((c['start'], c['end'], c['category_chunk_index']) == (0, 3, 0) for c in plan))
        self.assertEqual(self.store.post(pid)['status'], 'published')


if __name__ == '__main__':
    unittest.main()

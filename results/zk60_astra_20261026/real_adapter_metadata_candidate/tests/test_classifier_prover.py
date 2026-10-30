"""Interface orchestration with mocked leaf commands; no real proof is produced."""
import importlib.util
import json
from pathlib import Path
import unittest
from unittest.mock import patch

import test_classifier_cli as contract
from proven_media.classifier_prover import RungClassifierProver, RungTokenItem, PIPELINE
from proven_media.items import TextItem
from proven_media.provers import NotSupported, ProverError

spec=importlib.util.spec_from_file_location('test_classifier_worker',PIPELINE)
worker=importlib.util.module_from_spec(spec);spec.loader.exec_module(worker)


class ClassifierProverTests(unittest.TestCase):
    contract_class=contract.ClassifierContractTests

    def setUp(self):
        self.fixture=self.contract_class();self.fixture.setUp();self.addCleanup(self.fixture.doCleanups)
        self.root=self.fixture.root;self.prover=RungClassifierProver(self.fixture.d,self.root/'public-runs')
        self.seq=self.root/'seq';self.seq.mkdir()
        self.item=RungTokenItem(tuple(range(9,32)),(self.seq,))

    def make_job(self):
        job=self.root/'private/job'
        with patch('proven_media.classifier_prover.launch_pipeline') as launcher:
            self.prover.start('fixture',self.item,job);launcher.assert_called_once_with(job)
        job_spec=json.loads((job/'classifier-job.json').read_text())
        run,stmt,verify,owner=self.fixture.fixture()
        run.rename(job_spec['artifact'])
        (job/'logs').mkdir()
        calls=[]
        def leaf(job,name,command,cli):
            calls.append((name,command))
            log={'prove':contract.line('proved',verdict='not-flagged'),'verify':verify,'inowner':owner}[name]
            (job/f'logs/{name}.log').write_text(log)
            (job/f'logs/{name}.exit').write_text('0\n')
            (job/f'logs/{name}.guard.json').write_text(json.dumps({'exit':0,'child_rc':0}))
        with patch.object(worker,'run_step',side_effect=leaf):worker.worker(job)
        (job/'pipeline.done').write_text('0\n')
        return job,calls

    def test_full_interface_requires_fresh_verifier_and_owner_then_keeps_synthetic_category(self):
        job,calls=self.make_job()
        self.assertEqual([c[0] for c in calls],['prove','verify','inowner'])
        rec=self.prover.collect('fixture',self.item,job)
        self.assertEqual(set(rec.labels),{'synthetic'})
        self.assertTrue(rec.labels['synthetic']['bound_by_proof'])
        self.assertTrue(rec.prover['development_only'])
        self.assertFalse(self.prover.can_prove(TextItem('real text')))
        with self.assertRaises(NotSupported):self.prover.start('text',TextItem('real text'),self.root/'private/text')
        (job/'logs/inowner.guard.json').write_text(json.dumps({'exit':75,'child_rc':0}))
        with self.assertRaises(ProverError):self.prover.collect('fixture',self.item,job)

    def test_changed_segment_or_content_does_not_reuse_worker_success(self):
        job,_=self.make_job();spec=json.loads((job/'classifier-job.json').read_text())
        with self.assertRaises(ProverError):
            self.prover.collect('fixture',RungTokenItem(tuple(range(10,33)),(self.seq,)),job)
        segment=Path(spec['artifact'])/'segment-000.bin';segment.write_bytes(b'changed')
        with self.assertRaises(ProverError):self.prover.collect('fixture',self.item,job)

    def test_native_aggregate_is_a_separate_guarded_step_and_missing_chunk_refuses(self):
        job,_=self.make_job();rec=self.prover.collect('fixture',self.item,job)
        aggregate=self.root/'private/aggregate'
        with patch('proven_media.classifier_prover.launch_pipeline'):
            self.prover.start_label([rec],aggregate,item=self.item)
        (aggregate/'logs').mkdir()
        events=contract.line('label',policy=self.fixture.d.policy,label='not-flagged',chunks=1,content_total=23,expect_total=23,
                    chunk_size=23,overlap=4,flagged_ranges=[])
        def leaf(job,name,command,cli):
            self.assertEqual(name,'label');self.assertEqual(command[1],'label')
            (job/'logs/label.log').write_text(events);(job/'logs/label.exit').write_text('0\n')
            (job/'logs/label.guard.json').write_text(json.dumps({'exit':0,'child_rc':0}))
        with patch.object(worker,'run_step',side_effect=leaf):worker.worker(aggregate)
        (aggregate/'pipeline.done').write_text('0\n')
        self.assertEqual(self.prover.collect_label(aggregate)['value'],'no')
        with self.assertRaises(ProverError):self.prover.start_label([rec,rec],self.root/'private/repeated',item=self.item)

    def test_prefix_receipts_refuse_against_original_item_before_launch(self):
        job,_=self.make_job();rec=self.prover.collect('fixture',self.item,job)
        longer=RungTokenItem(self.item.ids+(99,),(self.seq,))
        target=self.root/'private/truncated'
        with patch('proven_media.classifier_prover.launch_pipeline') as launch:
            with self.assertRaises(ProverError):self.prover.start_label([rec],target,item=longer)
            launch.assert_not_called()
        self.assertFalse(target.exists())


class ClassifierC2ProverTests(ClassifierProverTests):
    contract_class=contract.ClassifierC2ContractTests


class ClassifierC3ProverTests(ClassifierProverTests):
    contract_class=contract.ClassifierC3ContractTests


if __name__=='__main__':unittest.main()

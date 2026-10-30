"""Exercise staged publisher implementations; no network, proof or real key."""
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock,patch

HERE=Path(__file__).resolve().parent;APP=HERE.parents[2]/'apps/proven-media'
sys.path[:0]=[str(HERE),str(APP),str(APP/'tests')]
from publication_candidate.publisher import LocalChainPublisher,PublicationRecord
from publication_candidate.testnet_publisher import BaseSepoliaPublisher
import test_testnet_publisher as fixtures


class PublicationExclusionTests(unittest.TestCase):
    def setUp(self):
        self.fixture=fixtures.TestBaseSepolia();self.fixture.setUp();self.addCleanup(self.fixture.doCleanups)
        self.root=self.fixture.root
        self.pub=LocalChainPublisher(self.root/'local')
        self.testnet=BaseSepoliaPublisher(self.fixture.rpc,self.root/'testnet')
        self.record=self.fixture.record()
        q=self.root/'runs/.batch-quarantine/failed';q.mkdir(parents=True)
        self.source=q/Path(self.record.receipt_segments[0]).name
        Path(self.record.receipt_segments[0]).rename(self.source)
        self.record.receipt_segments=[self.source]
        self.alias=self.root/'alias';self.alias.symlink_to(q,target_is_directory=True)

    def snapshot(self):
        return {str(p.relative_to(self.root)):p.read_bytes() for p in self.root.rglob('*') if p.is_file()}

    def test_local_and_testnet_refuse_quarantine_before_any_publication_side_effect(self):
        for pub in (self.pub,self.testnet):
            for path in (self.source,self.alias/self.source.name):
                self.record.receipt_segments=[path]
                before=self.snapshot();calls=list(self.fixture.rpc.calls)
                with self.subTest(publisher=type(pub).__name__,path=path),self.assertRaisesRegex(ValueError,'quarantined'):
                    pub.publish(self.record)
                self.assertEqual(self.snapshot(),before)
                self.assertEqual(self.fixture.rpc.calls,calls)
                self.assertEqual(self.fixture.rpc.sends,0)

    def test_direct_cas_ingestion_is_also_blocked_without_a_temporary_object(self):
        before=self.snapshot()
        for path in (self.source,self.alias/self.source.name):
            with self.assertRaisesRegex(ValueError,'quarantined'):self.pub.put_file(path)
        self.assertEqual(self.snapshot(),before)

    def test_ordinary_verified_receipt_still_publishes(self):
        record=self.fixture.record(2)
        for pub in (self.pub,self.testnet):
            anchor=pub.publish(record)
            self.assertEqual(anchor.status,'pending')
            self.assertEqual(anchor.post_id,record.post_id)

    def bundle(self,run):
        from publication_candidate import app
        rec={'chunks':[{'index':0,'record':{'prover':{'kind':'fixture'},
             'receipt':{'run_dir':str(run),'files':[{'file':self.source.name}]}}}],
             'verify_with':{'command':'fixture'}}
        state=Mock();state.store.post.return_value={'status':'published','manifest':None}
        state.publisher.anchors_of.return_value={}
        with patch.object(app,'S',state),patch.object(app,'public_record',return_value=rec):
            return app.api_bundle('fixture')

    def test_download_refuses_quarantined_roots_before_creating_a_stream(self):
        for path in (self.source.parent,self.alias):
            with self.subTest(path=path),self.assertRaisesRegex(ValueError,'quarantined'):
                self.bundle(path)

    def test_download_refuses_individual_segment_alias_into_quarantine(self):
        run=self.root/'ordinary';run.mkdir()
        (run/self.source.name).symlink_to(self.source)
        with self.assertRaisesRegex(ValueError,'quarantined'):self.bundle(run)

    def test_download_refuses_statement_alias_into_quarantine(self):
        run=self.root/'ordinary';run.mkdir()
        (run/self.source.name).write_bytes(b'fixture')
        (run/'statement').mkdir()
        (run/'statement/statement.json').symlink_to(self.source)
        with self.assertRaisesRegex(ValueError,'quarantined'):self.bundle(run)


if __name__=='__main__':unittest.main()

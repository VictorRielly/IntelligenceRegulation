"""Collector/publication boundary with synthetic bytes; no real proof or RPC."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from proven_media.jobs import chunk_publication_records
from proven_media.publisher import PublishError

def sha(data):return hashlib.sha256(data).hexdigest()

class PublicationBundleTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.run=Path(self.tmp.name);(self.run/'statement').mkdir()
        statement=b'{"synthetic":true}';segment=b'synthetic receipt bytes'
        (self.run/'statement/statement.json').write_bytes(statement)
        (self.run/'segment-000.bin').write_bytes(segment)
        self.rec={'prover':{'kind':'transport-test'},'statement_sha256':sha(statement),
            'receipt':{'run_dir':str(self.run),'files':[{'file':'segment-000.bin','bytes':len(segment),'sha256':sha(segment)}]},
            'checks':{'verify':{'ok':True}},
            'labels':{'sexual':{'proof':'accepted','value':'no','bound_by_proof':True,'policy_sha256':'02'*32}}}

    def collect(self):
        return chunk_publication_records({'id':'ab'*16},self.rec,{'index':0,'start':0,'end':23},'03'*32)

    def test_absent_native_inventory_preserves_only_collector_inventory(self):
        record=self.collect()[0]
        self.assertIsNone(record.segments_json)
        self.assertEqual(record.receipt_inventory,self.rec['receipt']['files'])
        self.assertFalse((self.run/'statement/segments.json').exists())
        (self.run/'statement/statement.json').write_bytes(b'changed statement')
        with self.assertRaises(PublishError):self.collect()

    def test_segment_and_native_inventory_mutations_are_not_new_verified_data(self):
        native=json.dumps(self.rec['receipt']['files']).encode();path=self.run/'statement/segments.json'
        path.write_bytes(native);self.rec['receipt']['segments_json_sha256']=sha(native)
        self.assertEqual(self.collect()[0].segments_json,native)
        path.write_bytes(native+b' ')
        with self.assertRaises(PublishError):self.collect()
        path.write_bytes(native)
        (self.run/'segment-000.bin').write_bytes(b'changed receipt')
        with self.assertRaises(PublishError):self.collect()

    def test_development_record_is_not_sent_to_publication(self):
        self.rec['prover']['development_only']=True
        self.assertEqual(self.collect(),[])

if __name__=='__main__':unittest.main()

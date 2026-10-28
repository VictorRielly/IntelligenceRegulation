import json
from pathlib import Path
import tempfile
import types
import unittest
from unittest.mock import patch
import numpy as np
from evaluate_verdicts import execute_layer,read_journal
from shieldstral_geometry import D


class EvaluationCheckpointTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name);self.emb=self.root/'embedding.bin'
        self.table=np.arange(4*D,dtype=np.int16).reshape(4,D);self.table.tofile(self.emb)
        self.ids=np.array([1,2,3,2,1]);self.offsets=np.array([0,2,5]);self.rows=[{'T':2},{'T':3}]

    def test_timebox_resume_and_torn_journal_do_not_repeat_or_drop_items(self):
        stage=self.root/'input'
        with patch('evaluate_verdicts.time.time',side_effect=[100.,102.]):
            self.assertFalse(execute_layer(stage,None,self.rows,self.offsets,self.ids,None,self.emb,101.))
        self.assertEqual(read_journal(stage/'journal.jsonl')[0]['end_item'],1)
        with (stage/'journal.jsonl').open('ab') as f:f.write(b'{"incomplete":')
        with patch('evaluate_verdicts.time.time',return_value=100.):
            self.assertTrue(execute_layer(stage,None,self.rows,self.offsets,self.ids,None,self.emb,101.))
        got=np.fromfile(stage/'residual.bin',dtype='<i2').reshape(-1,D)
        np.testing.assert_array_equal(got,self.table[self.ids])
        self.assertEqual([r['first_item'] for r in read_journal(stage/'journal.jsonl')],[0,1])
        # A completed checkpoint is read-only and verified, including its journal.
        with (stage/'residual.bin').open('r+b') as f:f.write(b'xx')
        with self.assertRaises(ValueError):execute_layer(stage,None,self.rows,self.offsets,self.ids,None,self.emb,101.)

    def test_partial_output_mutation_is_detected_before_resume(self):
        stage=self.root/'input'
        with patch('evaluate_verdicts.time.time',side_effect=[100.,102.]):
            execute_layer(stage,None,self.rows,self.offsets,self.ids,None,self.emb,101.)
        with (stage/'residual.partial').open('r+b') as f:f.write(b'xx')
        with self.assertRaises(ValueError):execute_layer(stage,None,self.rows,self.offsets,self.ids,None,self.emb,101.)

    def test_exact_lengths_and_refusal_diagnostics_survive_checkpoint(self):
        source=self.root/'source.bin';self.table[self.ids].tofile(source)
        model=types.SimpleNamespace(c={'f_ro':7});seen=[]
        def block(x,model,exact,rec):
            seen.append(x.shape[1]);self.assertEqual(model.rope_int[0].shape[0],x.shape[1])
            rec.check('score',np.array([[[200]]]),-127,127,0,True)
            return x+1
        stage=self.root/'layer'
        with patch('evaluate_verdicts.time.time',return_value=100.),patch('evaluate_verdicts.P.fl.rx_block',side_effect=block):
            self.assertTrue(execute_layer(stage,source,self.rows,self.offsets,self.ids,model,None,101.))
        self.assertEqual(seen,[2,3])
        diagnostics=read_journal(stage/'journal.jsonl')[0]['diagnostics']
        self.assertTrue(all(r['refused'] and r['first_site']=='score' for r in diagnostics))
        self.assertEqual(diagnostics[0]['violations']['score']['violations'],1)


if __name__=='__main__':unittest.main()

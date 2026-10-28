"""Transport contract tests with synthetic files; these are NOT proof tests."""
import copy
from dataclasses import replace
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from proven_media.classifier_cli import ClassifierCLI, Deployment, DEV_POLICY, VERIFIER_WRITER, chunk_plan, one_event
from proven_media.provers import ProverError


def line(event, **fields):
    return json.dumps({'event': event, **fields})+'\n'


class ClassifierContractTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(dir='/tmp');self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)
        self.binary=self.root/'synthetic-binary';self.binary.write_bytes(b'NOT A PROVER')
        sha=hashlib.sha256(self.binary.read_bytes()).hexdigest()
        self.pin=patch('proven_media.classifier_cli.R_C1_BINARY_SHA256',sha);self.pin.start();self.addCleanup(self.pin.stop)
        for name in ('export','public','tables'): (self.root/name).mkdir()
        self.d=Deployment(self.binary,sha,self.root/'export',self.root/'public',self.root/'tables','1'*64,
                          DEV_POLICY,23,4,min_bits=93,development=True)
        self.cli=ClassifierCLI(self.d)

    def fixture(self,total=23,index=0,flagged=False):
        plan=chunk_plan(total,23,4);bounds=plan[index];verdict='flagged' if flagged else 'not-flagged'
        run=self.root/f'run-{index}';(run/'statement').mkdir(parents=True)
        stmt={'schema':'zk60-classify-run/1','statement_written_by':VERIFIER_WRITER,
              'trained_statement_identity':'1'*64,'policy':DEV_POLICY,'context_label':'zk60-classify-verdict',
              'verdict_bit':int(flagged),'verdict':verdict,'blocks':1,'content_length_n':23,
              'input_token_endpoint_root':'2'*64,'whole_run_floor_bits':93,
              'chunk':{'index':index,'count':len(plan),'range':list(bounds),'content_total':total,'chunk_size':23,'overlap':4}}
        (run/'statement/statement.json').write_text(json.dumps(stmt))
        for k in range(3): (run/f'segment-{k:03}.bin').write_bytes(b'SYNTHETIC RECEIPT '+bytes([k]))
        verify=line('classified',verdict=verdict,chunk=index,chunks=len(plan),policy=DEV_POLICY,
                    trained_statement_identity='1'*64,input_token_endpoint_root='2'*64,whole_run_floor_bits=93,published_by='this verifier')
        owner=line('content-checked',verdict=verdict,chunk=index,range=list(bounds),content_total=total)
        return run,stmt,verify,owner

    def test_native_inventory_and_commands_keep_private_ids_off_argv(self):
        run,stmt,v,o=self.fixture()
        result=self.cli.collect_verified(run,23,0,v,0,o,0)
        self.assertEqual([x['file'] for x in result['files']],[f'segment-{k:03}.bin' for k in range(3)])
        self.assertEqual([x.name for x in (run/'statement').iterdir()],['statement.json'])
        content=self.root/'ids';content.write_text(','.join(str(n) for n in range(9,32)));content.chmod(0o600)
        owner=self.root/'private/owner'
        command=self.cli.prove_command(content,0,self.root/'seq',self.root/'public-runs/run',owner)
        self.assertIn('--content-file',command);self.assertNotIn(content.read_text(),command)
        self.assertIn('93',self.cli.verify_command(run))
        content.chmod(0o644)
        with self.assertRaises(ProverError):self.cli.prove_command(content,0,self.root/'seq',run,owner)

    def test_prover_output_or_refusal_never_becomes_an_accepted_label(self):
        run,stmt,v,o=self.fixture()
        for bad in (line('proved',verdict='not-flagged'),v+line('refused',error='refused'),v+v,'not json\n'+v):
            with self.subTest(bad=bad),self.assertRaises(ProverError):self.cli.collect_verified(run,23,0,bad,0,o,0)
        with self.assertRaises(ProverError):self.cli.collect_verified(run,23,0,v,1,o,0)
        stmt['statement_written_by']='zk60_classify prove, WITHOUT a verification (unverified)'
        (run/'statement/statement.json').write_text(json.dumps(stmt))
        with self.assertRaises(ProverError):self.cli.collect_verified(run,23,0,v,0,o,0)

    def test_pins_floor_owner_and_native_directory_fail_closed(self):
        run,original,v,o=self.fixture()
        for key,value in (('policy','different'),('trained_statement_identity','3'*64),('whole_run_floor_bits',92),('verdict_bit',True)):
            stmt=copy.deepcopy(original);stmt[key]=value
            (run/'statement/statement.json').write_text(json.dumps(stmt))
            with self.subTest(key=key),self.assertRaises(ProverError):self.cli.collect_verified(run,23,0,v,0,o,0)
        (run/'statement/statement.json').write_text(json.dumps(original))
        with self.assertRaises(ProverError):self.cli.collect_verified(run,23,0,v,0,o.replace('not-flagged','flagged'),0)
        extra=run/'statement/segments.json';extra.write_text('[]')
        with self.assertRaises(ProverError):self.cli.collect_verified(run,23,0,v,0,o,0)
        extra.unlink();(run/'segment-000.bin').unlink();(run/'segment-000.bin').symlink_to(run/'segment-001.bin')
        with self.assertRaises(ProverError):self.cli.collect_verified(run,23,0,v,0,o,0)

    def test_end_aligned_unordered_aggregation_missing_and_duplicate_refuse(self):
        plan=chunk_plan(50,23,4);self.assertEqual(plan,[(0,23),(19,42),(27,50)])
        collected=[]
        for i in range(3):
            run,s,v,o=self.fixture(50,i,i!=1)
            collected.append(self.cli.collect_verified(run,50,i,v,0,o,0))
        fields={'policy':DEV_POLICY,'label':'flagged','chunks':3,'content_total':50,'chunk_size':23,'overlap':4,
                'flagged_ranges':[[27,50],[0,23]]}
        label=line('label',**fields)
        result=self.cli.collect_label(collected[::-1],label,0,50)
        self.assertEqual(result['flagged_ranges'],[[0,23],[27,50]])
        for records in (collected[:2],[collected[0],collected[0],collected[2]]):
            with self.assertRaises(ProverError):self.cli.collect_label(records,label,0,50)
        fields['flagged_ranges']=[[0,23],[0,23]]
        with self.assertRaises(ProverError):self.cli.collect_label(collected,line('label',**fields),0,50)

    def test_dev_floor_cannot_be_used_for_production(self):
        for deployment in (replace(self.d,development=False),replace(self.d,min_bits=92),
                           replace(self.d,development=False,policy='production/1',min_bits=93),
                           replace(self.d,development=False,policy='production/1',min_bits=95)):
            with self.assertRaises(ProverError):deployment.validate()
        (self.root/'public/seq_000').mkdir()
        with self.assertRaises(ProverError):self.d.validate()


if __name__=='__main__':unittest.main()

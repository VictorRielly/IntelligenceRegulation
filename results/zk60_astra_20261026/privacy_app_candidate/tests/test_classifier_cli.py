"""Transport contract tests with synthetic files; these are NOT proof tests."""
import copy
from dataclasses import replace
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from proven_media.classifier_cli import (ClassifierCLI, Deployment, DEV_POLICY, DEV_TIED_SOURCE,
                                        R_C1_SCHEMA, R_C2_SCHEMA, R_C3_SCHEMA, VERIFIER_WRITER, chunk_plan, one_event)
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
        plan=chunk_plan(total,23,4,allow_short=self.d.statement_schema==R_C3_SCHEMA)
        bounds=plan[index];verdict='flagged' if flagged else 'not-flagged'
        run=self.root/f'run-{index}';(run/'statement').mkdir(parents=True)
        stmt={'schema':'zk60-classify-run/1','statement_written_by':VERIFIER_WRITER,
              'trained_statement_identity':'1'*64,'policy':DEV_POLICY,'context_label':'zk60-classify-verdict',
              'verdict_bit':int(flagged),'verdict':verdict,'blocks':1,'content_length_n':bounds[1]-bounds[0],
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
        fields={'policy':DEV_POLICY,'label':'flagged','chunks':3,'content_total':50,'expect_total':50,'chunk_size':23,'overlap':4,
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


class ClassifierC2ContractTests(ClassifierContractTests):
    def setUp(self):
        super().setUp()
        self.binary.write_bytes(b'NOT A PROVER; SEPARATE C2 TRANSPORT FIXTURE')
        digest=hashlib.sha256(self.binary.read_bytes()).hexdigest()
        pin=patch('proven_media.classifier_cli.R_C2_BINARY_SHA256',digest);pin.start();self.addCleanup(pin.stop)
        self.d=replace(self.d,binary_sha256=digest,statement_schema=R_C2_SCHEMA)
        self.cli=ClassifierCLI(self.d)
        self.norm={'g0':127,'cn':2048,'tn':11,'ceps':33554467}
        self.profile={'classifier_margin_parameters':{'yes_id':40,'no_id':41,'public_scale':1/256,'threshold_c':0},
                      'token_io_parameters':{'bos':1,'classifier_final_norm':self.norm}}
        (self.root/'public/profile.json').write_text(json.dumps(self.profile))

    def fixture(self,*args,**kwargs):
        run,stmt,verify,owner=super().fixture(*args,**kwargs)
        stmt.update(schema=R_C2_SCHEMA,yes_id=40,no_id=41,threshold_c=0,margin_scale=1/256,
                    bos=1,final_norm=self.norm,tied_source=DEV_TIED_SOURCE,
                    margin_vector_digest='3'*64,embedding_digest='4'*64,classifier_profile_digest='5'*64)
        (run/'statement/statement.json').write_text(json.dumps(stmt))
        return run,stmt,verify,owner

    def test_binary_schema_pair_and_downgrade_fail_closed(self):
        with self.assertRaises(ProverError):replace(self.d,statement_schema=R_C1_SCHEMA).validate()
        run,stmt,v,o=self.fixture();stmt['schema']=R_C1_SCHEMA
        (run/'statement/statement.json').write_text(json.dumps(stmt))
        with self.assertRaises(ProverError):self.cli.collect_verified(run,23,0,v,0,o,0)

    def test_bound_authorities_and_tied_source_cannot_be_changed(self):
        run,original,v,o=self.fixture()
        changes=[('yes_id',41),('no_id',40),('threshold_c',1),('margin_scale',1/512),('margin_scale',float('nan')),
                 ('yes_id',True),('bos',2),('final_norm',{**self.norm,'tn':10}),
                 ('tied_source','unbound table'),('embedding_digest',None)]
        for key,value in changes:
            stmt=copy.deepcopy(original);stmt[key]=value
            (run/'statement/statement.json').write_text(json.dumps(stmt))
            with self.subTest(key=key,value=value),self.assertRaises(ProverError):
                self.cli.collect_verified(run,23,0,v,0,o,0)
        (run/'statement/statement.json').write_text(json.dumps(original))
        self.profile['classifier_margin_parameters']['threshold_c']=1
        (self.root/'public/profile.json').write_text(json.dumps(self.profile))
        with self.assertRaises(ProverError):self.cli.collect_verified(run,23,0,v,0,o,0)

    def test_serialization_preserves_c2_and_retained_c1_jobs(self):
        from proven_media.classifier_prover import deployment_json,deployment_from_json
        encoded=deployment_json(self.d)
        self.assertEqual(encoded['statement_schema'],self.d.statement_schema)
        self.assertEqual(deployment_from_json(encoded),self.d)
        legacy=replace(self.d,statement_schema=R_C1_SCHEMA)
        encoded=deployment_json(legacy)
        self.assertNotIn('statement_schema',encoded)
        self.assertEqual(deployment_from_json(encoded),legacy)


class ClassifierC3ContractTests(ClassifierC2ContractTests):
    def setUp(self):
        super().setUp()
        self.binary.write_bytes(b'NOT A PROVER; SEPARATE C3 TRANSPORT FIXTURE')
        digest=hashlib.sha256(self.binary.read_bytes()).hexdigest()
        pin=patch('proven_media.classifier_cli.R_C3_BINARY_SHA256',digest);pin.start();self.addCleanup(pin.stop)
        self.d=replace(self.d,binary_sha256=digest,statement_schema=R_C3_SCHEMA)
        self.cli=ClassifierCLI(self.d)

    def fixture(self,*args,**kwargs):
        run,stmt,v,o=super().fixture(*args,**kwargs)
        n=stmt['content_length_n']
        stmt.update(schema=R_C3_SCHEMA,template_prefix_ids=list(range(1,9)),template_suffix_ids=[32],
                    T=32,item_length=n+9,pad_id=2,pad_positions=23-n,verdict_row=n+8)
        (run/'statement/statement.json').write_text(json.dumps(stmt))
        return run,stmt,v,o

    def test_short_content_and_native_expected_total(self):
        run,stmt,v,o=self.fixture(11)
        rec=self.cli.collect_verified(run,11,0,v,0,o,0)
        self.assertEqual(rec['chunk'],{'index':0,'start':0,'end':11})
        command=self.cli.label_command([run],11)
        self.assertEqual(command[-2:],['--expect-total','11'])
        fields={'policy':DEV_POLICY,'label':'not-flagged','chunks':1,'content_total':11,'expect_total':11,
                'chunk_size':23,'overlap':4,'flagged_ranges':[]}
        self.assertEqual(self.cli.collect_label([rec],line('label',**fields),0,11)['value'],'no')
        for value in (None,True,10):
            with self.subTest(value=value),self.assertRaises(ProverError):
                self.cli.collect_label([rec],line('label',**{**fields,'expect_total':value}),0,11)
        for total in (0,True,'11'):
            with self.assertRaises(ProverError):self.cli.label_command([run],total)

    def test_short_prefix_proof_is_not_a_whole_post_proof(self):
        run,stmt,v,o=self.fixture(11)
        rec=self.cli.collect_verified(run,11,0,v,0,o,0)
        # Both posts still have one chunk: a chunk-count check alone is insufficient.
        for total in (12,23,50):
            with self.subTest(total=total),self.assertRaises(ProverError):
                self.cli.check_label_records([rec],total)
            with self.assertRaises(ProverError):self.cli.collect_verified(run,total,0,v,0,o,0)

    def test_full_chunk_prefix_set_and_statement_geometry_refuse(self):
        run,stmt,v,o=self.fixture(23)
        rec=self.cli.collect_verified(run,23,0,v,0,o,0)
        with self.assertRaises(ProverError):self.cli.check_label_records([rec],50)
        for key,value in (('range',[0,22]),('count',2),('chunk_size',22),('overlap',3),('index',True)):
            changed=copy.deepcopy(rec);changed['statement']['chunk'][key]=value
            with self.subTest(key=key),self.assertRaises(ProverError):self.cli.check_label_records([changed],23)
        changed=copy.deepcopy(rec);changed['value']='yes'
        with self.assertRaises(ProverError):self.cli.check_label_records([changed],23)

    def test_short_padding_or_verdict_row_cannot_be_changed(self):
        run,original,v,o=self.fixture(11)
        for key,value in (('schema',R_C2_SCHEMA),('item_length',32),('pad_positions',0),('pad_id',11),
                          ('verdict_row',31),('T',31),('content_length_n',23),('template_suffix_ids',[2])):
            stmt=copy.deepcopy(original);stmt[key]=value
            (run/'statement/statement.json').write_text(json.dumps(stmt))
            with self.subTest(key=key),self.assertRaises(ProverError):self.cli.collect_verified(run,11,0,v,0,o,0)


if __name__=='__main__':unittest.main()

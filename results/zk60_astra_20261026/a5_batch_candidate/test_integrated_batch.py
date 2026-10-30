"""Integrated app/queue controls with simulated native execution.

The real SQLite store, Worker, batch adapter/pipeline, collector, publisher and
manifest code execute. Native proof/check execution is explicitly replaced:
small fixture files and retained native transport events are not new proofs.
"""
from copy import deepcopy
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE/'integrated_app'))
from proven_media import config, records, shieldstral_runtime as runtime, storage_policy
from proven_media import batch_pipeline as pipeline, batch_registry as registry
from proven_media.batch_prover import BatchShieldstralProver, LaunchNotStarted
from proven_media.batch_supervisor import BatchSupervisor
from proven_media.classifier_cli import ClassifierCLI
from proven_media.jobs import Worker
from proven_media.provers import ProverError
from proven_media.publisher import LocalChainPublisher, PublishError
from proven_media.shieldstral_text import ShieldstralTextEncoder
from proven_media.store import Store, ScreeningConflict

assert Path(sys.modules['proven_media.jobs'].__file__).parent==HERE/'integrated_app/proven_media'


class IntegratedBatchTests(unittest.TestCase):
    def setUp(self):
        tmp=tempfile.TemporaryDirectory(prefix='astra-integrated-batch-')
        self.addCleanup(tmp.cleanup);self.root=Path(tmp.name)
        private=self.root/'private';private.mkdir(mode=0o700)
        paths={'PRIVATE_DIR':private,'JOBS_DIR':private/'jobs','DB_PATH':private/'app.sqlite3',
               'RUNS_DIR':self.root/'public/runs','PUBLIC_DIR':self.root/'public',
               'SIGNING_KEY':private/'signing.key','HOLD_FILE':self.root/'HOLD'}
        for name,value in paths.items():
            p=patch.object(config,name,value);p.start();self.addCleanup(p.stop)
        p=patch.dict(os.environ,{'PM_PROVER':'shieldstral'});p.start();self.addCleanup(p.stop)
        # Temporary roots are explicitly allowed only in this mocked suite.
        p=patch.object(storage_policy,'validate_storage');p.start();self.addCleanup(p.stop)
        self.encoder=object.__new__(ShieldstralTextEncoder)
        self.encoder.content_ids=lambda text:(1500,)*len(text.split())
        for target in ('proven_media.shieldstral_prover.ShieldstralTextEncoder',
                       'proven_media.batch_request.ShieldstralTextEncoder'):
            p=patch(target,return_value=self.encoder);p.start();self.addCleanup(p.stop)
        self.prover=BatchShieldstralProver(max_prove_seconds=2700)
        self.prover._launch=Mock()
        self.store=Store(config.DB_PATH);self.addCleanup(self.store.db.close)
        self.pub=LocalChainPublisher(config.PUBLIC_DIR)
        self.worker=Worker(self.store,self.prover,self.pub)
        self.pid='ab'*16;self.text=' '.join(['word']*17)
        self.plan=self.prover.plan_text(self.text)
        self.store.add_screened_post(self.text,self.plan,id=self.pid,author='@test',kind='text',text=self.text,
            status='queued',prover_kind='shieldstral',chunks=json.dumps(self.plan),
            content_key=records.content_key(self.text),salt_enc=records.new_salt_enc(self.pid))
        self.job=config.JOBS_DIR/self.pid/'batch'
        self.calls=[];self.fail_step=None;self.transport_mode=None;self.checked={}
        p=patch.object(BatchSupervisor,'step',new=lambda sup,*args:self.fake_step(sup,*args))
        p.start();self.addCleanup(p.stop)
        def collect_verified(cli,artifact,total,chunk,*args):
            value=deepcopy(self.checked[str(artifact)])
            self.assertEqual(value['statement']['chunk']['content_total'],total)
            self.assertEqual(value['statement']['chunk']['index'],chunk)
            return value
        def collect_label(cli,parts,stdout,code,total):
            cli.check_label_records(parts,total)
            return {'value':'no','proof':'accepted','bound_by_proof':True,'chunks':len(parts),
                    'policy_id':cli.deployment.policy}
        for name,value in (('collect_verified',collect_verified),('collect_label',collect_label)):
            p=patch.object(ClassifierCLI,name,new=value);p.start();self.addCleanup(p.stop)

    def start(self):
        self.worker.tick()
        self.prover._launch.assert_called_once_with(self.job)
        self.assertTrue(all(r['status']=='running' for r in self.store.q('SELECT * FROM jobs')))

    def payloads(self):
        request=json.loads((self.job/'batch-request.json').read_text())
        for row,ch in zip(request['jobs'],self.plan):
            template=next(t for t in runtime.templates() if t.category==ch['category'])
            run=Path(row['out']);(run/'statement').mkdir(parents=True,exist_ok=True)
            owner=Path(row['owner_dir']);owner.mkdir(parents=True,exist_ok=True)
            (owner/'input.dec').write_text('TEST ONLY: no native opening');(owner/'input.dec').chmod(0o600)
            data=b'TEST ONLY: simulated receipt '+ch['category'].encode()
            segment=run/'segment.bin';segment.write_bytes(data)
            n=ch['end']-ch['start'];length=len(template.prefix)+n+len(template.suffix)
            st={'schema':'zk60-classify-run/3','policy':template.policy_id,'verdict_bit':0,
                'content_length_n':n,'T':128,'item_length':length,'pad_id':11,
                'pad_positions':128-length,'verdict_row':length-1,'blocks':26,
                'template_prefix_ids':list(template.prefix),'template_suffix_ids':list(template.suffix),
                'input_token_endpoint_root':'00'*32,'whole_run_floor_bits':95,
                'chunk':{'index':ch['category_chunk_index'],'count':ch['category_chunks'],
                         'content_total':ch['content_total'],'chunk_size':ch['chunk_tokens'],
                         'overlap':8,'range':[ch['start'],ch['end']]}}
            # Retain the public model/table authorities from the earlier
            # 17-token real receipt. Cryptographic verification remains mocked.
            native=config.REPO/'results/zk60_astra_20261026/real_app_demo_1/public/runs'/(
                'd1800de17fffed4565733d12e5c30f52-c'+str(ch['index']))/'statement/statement.json'
            st={**json.loads(native.read_text()),**st}
            raw=records.canonical(st);(run/'statement/statement.json').write_bytes(raw)
            self.checked[row['out']]={'statement':st,'statement_sha256':hashlib.sha256(raw).hexdigest(),
                'run_dir':row['out'],'files':[{'file':'segment.bin','bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}],
                'value':'no','proof':'accepted','bound_by_proof':True,'policy_id':template.policy_id,
                'development_only':False,'content_binding':True,'verifier_sha256':runtime.BINARY_SHA,
                'chunk':{'index':ch['category_chunk_index'],'start':ch['start'],'end':ch['end']}}
        return request

    def transport(self,request):
        source=config.TOKEN_IO/'r18/logs/eq/batch.log'
        events=[json.loads(line) for line in source.read_text().splitlines() if line.strip()]
        self.assertEqual(events[-1]['event'],'fixed-entropy');events=events[:-1]
        index=None
        for event in events:
            if event['event']=='batch-job-start':index=event['index']
            if event['event']=='proved':
                event['run']=request['jobs'][index]['out'];event['owner_dir']=request['jobs'][index]['owner_dir']
        if self.transport_mode=='prefix':events=events[:-1]
        return '\n'.join(json.dumps(event) for event in events)+'\n'

    def fake_step(self,supervisor,name,argv,need,cap,maximum):
        self.calls.append((name,argv,need,cap,maximum));logs=self.job/'logs'
        if name=='prove-batch':
            request=self.payloads();(logs/(name+'.log')).write_text(self.transport(request))
        else:(logs/(name+'.log')).write_text('TEST ONLY: mocked native check\n')
        if self.transport_mode=='unknown-cleanup' and name=='prove-batch':
            supervisor.children_reaped=False
            raise ProverError('TEST: guard lost without cleanup evidence')
        fail=name==self.fail_step or (name=='prove-batch' and self.transport_mode=='guard-kill')
        code=75 if fail else 0
        (logs/(name+'.guard.done')).write_text(str(code)+'\n')
        (logs/(name+'.guard.json')).write_text(json.dumps({'exit':code,'child_rc':code,'cmd':argv,
            'need_gib':need,'cap_gib':cap,'child_wall_seconds':.25,'peak_rss_gib':.01,
            'enforcement':'simulated guard; no native proof','waited_s':0,
            'guard_killed':'simulated failure' if fail else None}))
        if name==self.fail_step:raise ProverError('TEST: check failed')

    def run_pipeline(self):
        return pipeline.run_registered(self.job)

    def assert_failed_closed(self):
        self.assertEqual(self.store.post(self.pid)['status'],'failed')
        self.assertEqual(self.pub.anchors_of(self.pid),{})
        self.assertTrue(all(r['status']=='failed' for r in self.store.q('SELECT * FROM jobs')))
        self.assertEqual(self.store.one('SELECT * FROM batch_runs')['status'],'quarantined')
        with self.assertRaises(ScreeningConflict):
            self.store.add_screened_post(self.text,(),id='cd'*16,author='@test',kind='text',text=self.text,status='queued')

    def test_whole_pipeline_publishes_only_after_every_fresh_check(self):
        self.start();self.assertEqual(self.run_pipeline(),0)
        self.assertEqual(self.pub.anchors_of(self.pid),{})
        self.worker.tick()
        self.assertEqual(self.store.post(self.pid)['status'],'published')
        self.assertEqual(self.store.one('SELECT * FROM batch_runs')['status'],'finished')
        self.assertEqual(len(self.pub.anchors_of(self.pid)),3)
        names=[x[0] for x in self.calls]
        self.assertEqual(names.count('prove-batch'),1)
        self.assertEqual(sum(n.endswith('-verify') for n in names),3)
        self.assertEqual(sum(n.endswith('-inowner') for n in names),3)
        self.assertEqual(sum(n.endswith('-label') for n in names),3)
        records_=[json.loads(r['record']) for r in self.store.q('SELECT * FROM chunk_proofs')]
        self.assertEqual(sum(r['timings']['work_s'] for r in records_),len(self.calls)*.25)
        self.assertTrue(all(r['prover']['binary_sha256']==runtime.BINARY_SHA for r in records_))
        self.worker.tick();self.prover._launch.assert_called_once()

    def test_successful_prefix_without_batch_proved_is_quarantined(self):
        self.start();self.transport_mode='prefix';self.assertEqual(self.run_pipeline(),1)
        self.worker.tick();self.assert_failed_closed()
        self.assertEqual([r[0] for r in self.calls],['seqgen','prove-batch'])

    def test_guard_kill_with_complete_stdout_is_quarantined(self):
        self.start();self.transport_mode='guard-kill';self.assertEqual(self.run_pipeline(),1)
        self.worker.tick();self.assert_failed_closed()

    def test_last_label_failure_cannot_publish_earlier_categories(self):
        self.start();self.fail_step='hate-label';self.assertEqual(self.run_pipeline(),1)
        self.worker.tick();self.assert_failed_closed()
        self.assertEqual(self.store.q('SELECT * FROM chunk_proofs'),[])

    def test_unknown_child_state_holds_until_reboot_without_touching_outputs(self):
        self.start();self.transport_mode='unknown-cleanup';self.assertEqual(self.run_pipeline(),1)
        self.assertFalse((self.job/'pipeline-terminal.json').exists())
        self.worker.tick();self.assertEqual(self.store.post(self.pid)['status'],'screening')
        self.assertTrue(all(Path(p).exists() for p in self.checked))
        with patch.object(registry,'boot_id',return_value='after-reboot'):self.worker.tick()
        self.assert_failed_closed()

    def test_database_scope_recovers_missing_cleanup_file_after_crash(self):
        self.start();self.payloads();(self.job/'cleanup-scope.json').unlink()
        with patch.object(registry,'boot_id',return_value='after-reboot'):self.worker.tick()
        self.assert_failed_closed()
        self.assertTrue(all(not Path(p).exists() for p in self.checked))

    def test_publication_failure_resumes_without_repeating_native_work(self):
        self.start();self.assertEqual(self.run_pipeline(),0)
        real=self.pub.publish
        def publish(record):
            if record.category=='hate':raise PublishError('TEST: store temporarily unavailable')
            return real(record)
        with patch.object(self.pub,'publish',side_effect=publish),self.assertRaises(PublishError):self.worker.tick()
        self.assertEqual(self.store.post(self.pid)['status'],'screening')
        self.assertEqual(self.store.one('SELECT * FROM batch_runs')['status'],'verified')
        calls=deepcopy(self.calls);self.worker.tick()
        self.assertEqual(self.store.post(self.pid)['status'],'published')
        self.assertEqual(len(self.pub.anchors_of(self.pid)),3);self.assertEqual(self.calls,calls)

    def test_record_commit_is_atomic_when_database_write_fails(self):
        self.start();self.assertEqual(self.run_pipeline(),0)
        real=self.worker._set_chunk
        def write(pid,index,*args):
            if index==1:raise RuntimeError('TEST: database failure')
            return real(pid,index,*args)
        with patch.object(self.worker,'_set_chunk',side_effect=write),self.assertRaises(RuntimeError):self.worker.tick()
        self.assertEqual(self.store.q('SELECT * FROM chunk_proofs'),[])
        self.assertTrue(all(r['status']=='running' for r in self.store.q('SELECT * FROM jobs')))
        self.assertEqual(self.pub.anchors_of(self.pid),{})
        self.worker.tick();self.assertEqual(self.store.post(self.pid)['status'],'published')

    def test_changed_original_content_cannot_be_accepted(self):
        self.start();self.assertEqual(self.run_pipeline(),0)
        (self.job/'content.ids').write_text(','.join(['1501']*17))
        self.worker.tick();self.assert_failed_closed()

    def test_recheck_uses_shared_batch_owner_and_original_content(self):
        self.start();self.assertEqual(self.run_pipeline(),0);self.worker.tick()
        self.store.add_job(self.pid,'recheck',1)
        with patch('proven_media.shieldstral_prover.launch_pipeline') as launch:self.worker.tick()
        target=launch.call_args.args[0]
        spec=json.loads((target/'classifier-job.json').read_text())
        self.assertEqual(spec['mode'],'recheck')
        self.assertEqual(spec['content_file'],str(self.job/'content.ids'))
        self.assertEqual(spec['owner_dir'],str(self.job/'owners/c1'))

    def test_same_boot_startup_never_relaunches_an_uncertain_batch(self):
        self.start();self.worker.tick();self.worker.tick()
        self.prover._launch.assert_called_once()
        self.assertEqual(self.pub.anchors_of(self.pid),{})
        self.assertEqual(self.store.one('SELECT * FROM batch_runs')['status'],'active')

    def test_failed_popen_quarantines_whole_claim_without_category_finalization(self):
        self.prover._launch.side_effect=LaunchNotStarted('TEST: no child')
        with self.assertLogs('proven_media.jobs',level='ERROR'):self.worker.tick()
        self.assertTrue(all(r['status']=='running' for r in self.store.q('SELECT * FROM jobs')))
        self.assertEqual(self.store.q('SELECT * FROM chunk_proofs'),[])
        self.worker.tick();self.assert_failed_closed()

    def test_post_launch_metadata_failure_preserves_uncertain_whole_claim(self):
        # An ordinary OSError can occur after Popen. It is not proof that no
        # child ran, and must not enter the per-category failure path.
        self.prover._launch.side_effect=OSError('TEST: launched.json fsync failed')
        with self.assertLogs('proven_media.jobs',level='ERROR'):self.worker.tick()
        self.assertFalse((self.job/'pipeline-terminal.json').exists())
        self.assertFalse((self.job/'failed-batch-quarantine.json').exists())
        self.assertEqual(self.store.q('SELECT * FROM chunk_proofs'),[])
        self.worker.tick()
        self.assertTrue(all(r['status']=='running' for r in self.store.q('SELECT * FROM jobs')))
        self.prover._launch.assert_called_once()

    def test_popen_error_is_distinct_from_metadata_write_after_child_return(self):
        from proven_media import batch_prover
        launch=BatchShieldstralProver._launch
        first=self.root/'no-child';first.mkdir()
        with patch.object(batch_prover.subprocess,'Popen',side_effect=OSError('TEST: exec failed')):
            with self.assertRaises(LaunchNotStarted):launch(self.prover,first)
        second=self.root/'child-exists';second.mkdir()
        with patch.object(batch_prover.subprocess,'Popen',return_value=Mock(pid=12345)) as popen, \
                patch.object(batch_prover,'_atomic_private',side_effect=OSError('TEST: metadata failed')):
            with self.assertRaises(OSError):launch(self.prover,second)
        popen.assert_called_once()

    def test_failure_terminal_stays_failed_after_reboot_despite_complete_stdout(self):
        self.start();self.assertEqual(self.run_pipeline(),0)
        marker=self.job/'pipeline-terminal.json'
        value=json.loads(marker.read_text());value['exit']=1;marker.write_text(json.dumps(value))
        with patch.object(registry,'boot_id',return_value='after-reboot'):self.worker.tick()
        self.assert_failed_closed()

    def test_crash_after_publication_before_finished_state_does_not_republish(self):
        self.start();self.assertEqual(self.run_pipeline(),0);self.worker.tick()
        self.store.x("UPDATE batch_runs SET status='verified'")
        with patch.object(self.pub,'publish',side_effect=AssertionError('must reuse existing publication')):
            self.worker.tick()
        self.assertEqual(self.store.post(self.pid)['status'],'published')
        self.assertEqual(self.store.one('SELECT * FROM batch_runs')['status'],'finished')
        self.prover._launch.assert_called_once()

    def test_installed_factory_still_selects_reviewed_single_path(self):
        from proven_media.provers import make_prover
        self.assertIsNot(type(make_prover()),BatchShieldstralProver)


if __name__=='__main__':unittest.main()

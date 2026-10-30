"""Explicit batch adapter candidate; make_prover still selects r16b singles."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

from .batch_cleanup import _atomic_private
from .batch_pipeline import BATCH_BINARY, BATCH_BINARY_SHA, SCHEMA, collect_checks, load_spec, source_pins
from .batch_request import prepare_text, validate_manifest
from .batch_registry import register_prepared
from .batch_queue_gate import recover_batch
from . import config, proof_plans, records, storage_policy
from .classifier_cli import require
from .items import TextItem
from .provers import ProverError, write_private
from .shieldstral_prover import ShieldstralProver
from .shieldstral_text import TEKKEN_SHA256


class LaunchNotStarted(ProverError):
    """Only raised when Popen never returned a child."""


class BatchShieldstralProver(ShieldstralProver):
    batch_proving = True

    def __init__(self, *, max_prove_seconds, large_batch_window=None):
        super().__init__()
        require(type(max_prove_seconds) is int and max_prove_seconds>=2700,
                'explicit batch time cap required')
        self.max_prove_seconds=max_prove_seconds
        self.large_batch_window=large_batch_window

    def describe(self):
        return {**super().describe(), 'prover_binary_sha256':BATCH_BINARY_SHA,
                'cli':'candidate r18 prove-batch; reviewed r16b fresh verification',
                'batch_proving':True, 'adoption_status':'candidate; coordinator review required'}

    def start(self, *args, **kwargs):
        raise ProverError('Batch proving requires one atomic whole-post queue claim.')

    def collect(self, *args, **kwargs):
        raise ProverError('A batch is collected atomically for the entire post.')

    def start_batch(self, store, post):
        storage_policy.validate_storage(store)
        require(store.path.resolve()==config.DB_PATH.resolve(), 'batch queue database differs from deployment')
        store.check_screening(post)
        plan=json.loads(post['chunks'])
        proof_plans.check_plan(plan,self.plan_text(post['text']))
        require(self.max_prove_seconds>=900*len(plan), 'batch time cap is too short for this post')
        require(len(plan)*848412096<=10_000_000_000 or bool(self.large_batch_window),
                'announce a D46 window before preparing a batch over10GB')
        holds=(config.HOLD_FILE,config.REPO/'results/zk60_shieldstral_prep_20261021/HOLD',
               config.REPO/'results/zk60_shieldstral_export_20261026/HOLD')
        require(not any(p.exists() for p in holds), 'coordinator HOLD active')
        job=config.JOBS_DIR/post['id']/'batch'
        job.parent.mkdir(mode=0o700,parents=True,exist_ok=True)
        config.RUNS_DIR.mkdir(parents=True,exist_ok=True)
        request=prepare_text(post['id'],post['text'],plan,job,config.RUNS_DIR,
                             reserved_context=post['screening_context'])
        launch_id=register_prepared(store,post['id'])
        row=store.one('SELECT * FROM batch_runs WHERE post_id=?',(post['id'],))
        spec={'schema':SCHEMA,'post_id':post['id'],'launch_id':launch_id,'boot_id':row['boot_id'],
              'context':row['context'],'plan':plan,'total':request['content_total'],
              'request_sha256':hashlib.sha256(records.canonical(request)).hexdigest(),
              'prover_binary':str(BATCH_BINARY),'prover_sha256':BATCH_BINARY_SHA,
              'native_threads':8,'max_prove_seconds':self.max_prove_seconds,
              'large_batch_window':self.large_batch_window,'source_sha256':source_pins()}
        def no_child_failure():
            recover_batch(job,config.RUNS_DIR,post_id=post['id'],reserved_plan=plan,
                          reserved_context=post['screening_context'],terminal_confirmed=True,
                          terminal_exit=1,reserved_scope=json.loads(row['scope']))
            _atomic_private(job/'pipeline-terminal.json',{'schema':'pm-batch-terminal/1',
                'launch_id':launch_id,'boot_id':row['boot_id'],'children_reaped':True,'exit':1})
        try:
            _atomic_private(job/'batch-pipeline.json',spec)
        except Exception:
            no_child_failure()
            raise
        try:
            self._launch(job)
        except LaunchNotStarted:
            # Popen failed before returning a child; no guard could have run.
            no_child_failure()
            raise

    def _launch(self, job):
        # The isolated package and the eventual installed package share the
        # same module entry point; the factory is deliberately not modified.
        package_root=Path(__file__).resolve().parents[1]
        env=dict(os.environ, PYTHONPATH=str(package_root))
        try:
            output=(job/'pipeline.out').open('xb')
        except OSError as exc:
            raise LaunchNotStarted('Cannot open the private batch log.') from exc
        try:
            try:
                child=subprocess.Popen([sys.executable,'-m','proven_media.batch_pipeline',str(job)],
                    env=env,stdin=subprocess.DEVNULL,stdout=output,stderr=subprocess.STDOUT,
                    start_new_session=True,close_fds=True)
            except OSError as exc:
                raise LaunchNotStarted('Batch supervisor could not be launched.') from exc
        finally:
            output.close()
        _atomic_private(job/'launched.json',{'pid':child.pid,'boot_id':Path('/proc/sys/kernel/random/boot_id').read_text().strip()})

    def poll(self, job):
        job=Path(job)
        if not (job/'batch-request.json').exists():return super().poll(job)
        result={'done':False,'exit':None,'alive':None,'step':'queued','step_since':None,
                'waiting_for_machine':False}
        progress=job/'batch-progress.json'
        if progress.exists():result.update(json.loads(progress.read_text()))
        marker=job/'pipeline-terminal.json'
        if marker.exists():
            terminal=json.loads(marker.read_text())
            result.update(done=True,exit=terminal['exit'],step='done')
        return result

    def collect_batch(self, post, job, row):
        require(isinstance(post.get('text'),str), 'batch post text is missing')
        spec,request=load_spec(job,row)
        ids=tuple(int(x) for x in (Path(job)/'content.ids').read_text().strip().split(','))
        require(ids==self.encoder.content_ids(post['text']), 'batch input differs from original post')
        proof_plans.check_plan(spec['plan'],self.plan_text(post['text']))
        current=collect_checks(job,spec,request)
        require(current==json.loads((Path(job)/'batch-verified.json').read_text()),
                'batch verification artifacts changed after supervisor completion')
        result=[]
        for chunk,r in zip(spec['plan'],current['checked']):
            category=chunk['category'];st=r['statement']
            policy=next(c['policy'] for c in records.categories() if c['id']==category)
            checks={'verify':{'ok':True,'by':'pinned r16b fresh process'},'content_binding':{'ok':True}}
            if chunk['category_chunk_index']==chunk['category_chunks']-1:
                checks['category_aggregate']=current['aggregates'][category]
            # The shared guard is charged exactly once to the item. Per-job
            # native prove timings remain in the original private batch log.
            timings={'work_s':current['work_s'] if chunk['index']==0 else 0,
                     'shared_batch':spec['launch_id']}
            if chunk['index']==0:timings['steps']=current['steps']
            rec=records.ProofRecord(post_id=post['id'],item_kind='text',prover=self.describe(),
                labels={category:{k:r[k] for k in ('value','proof','bound_by_proof','policy_id','development_only')}},
                policies=[{**policy,'category':category}],threshold=records.threshold(),
                content_commitment={'kind':'sealed native input-token endpoint','value':st['input_token_endpoint_root']},
                statement=st,statement_sha256=r['statement_sha256'],
                receipt={'run_dir':r['run_dir'],'files':r['files'],'segments':len(r['files']),
                         'bytes':sum(f['bytes'] for f in r['files'])},timings=timings,
                security={'whole_run_floor_bits':st['whole_run_floor_bits'],'min_bits_required':95,
                          'privacy_status':'privacy statement pending'},checks=checks,
                content_length={'tokens':chunk['end']-chunk['start'],'total_tokens':spec['total'],
                                'tokenizer':'pinned Tekken','tokenizer_sha256':TEKKEN_SHA256},
                chunk=chunk,created_at=records.now_iso(),proved_at=records.now_iso(),
                notes=['Batch candidate; classifier privacy acceptance and product policy remain pending.'])
            rec.labels[category]['policy_sha256']=policy['sha256']
            proof_plans.check_category_record(rec.to_dict(),post['id'],chunk,require_verdict=True)
            result.append(rec)
        self.check_final_records(TextItem(post['text']),[r.to_dict() for r in result])
        return result

    def prepare_recheck(self, record, prove_job, job):
        prove_job=Path(prove_job)
        if not (prove_job/'batch-request.json').exists():return super().prepare_recheck(record,prove_job,job)
        original=json.loads((prove_job/'batch-pipeline.json').read_text())
        request=json.loads((prove_job/'batch-request.json').read_text())
        plan=validate_manifest(request,original['total']);ci=record.chunk['index'];chunk=plan[ci]
        row=request['jobs'][ci];category=chunk['category'];cli=self.clis[category]
        require(record.post_id==original['post_id'] and record.chunk==chunk
                and record.receipt['run_dir']==row['out'] and record.prover['kind']==self.kind
                and record.prover['binary_sha256']==cli.deployment.binary_sha256
                and record.prover.get('prover_binary_sha256')==BATCH_BINARY_SHA,
                'batch recheck record differs from original scope')
        spec={'mode':'recheck','post_id':record.post_id,'category':category,'queue_chunk':chunk,
              'artifact':row['out'],'total':original['total'],'chunk':chunk['category_chunk_index'],
              'content_file':str(prove_job/'content.ids'),'owner_dir':row['owner_dir'],
              'sequence_dir':row['sequence_dir'],'prior_jobs':[], 'last_category_chunk':False}
        return self._job(job,cli,spec)

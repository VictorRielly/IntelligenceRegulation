"""Version-pinned development implementation of the ClassifierProver interface.

Only explicitly supplied synthetic token fixtures are admitted. This class is
not registered in the web app's prover factory and does not label real text.
The production Shieldstral deployment awaits its export and reviewed binary.
"""
from __future__ import annotations

from dataclasses import asdict, dataclass
import json
import os
from pathlib import Path
import re
import subprocess
import sys

from . import config, records
from .classifier_cli import ClassifierCLI, Deployment, R_C1_SCHEMA, R_C2_SCHEMA, R_C3_SCHEMA, chunk_plan, require
from .provers import ClassifierProver, NotSupported, ProverError, boot_id, poll, write_private

PIPELINE=config.TOOLS_DIR/'classifier_pipeline.py'
PATH_FIELDS=('binary','prover_export','verifier_export','tables')


def deployment_json(deployment):
    obj=asdict(deployment)
    for key in PATH_FIELDS:obj[key]=str(obj[key])
    # Preserve retained R-C1 private job descriptions byte-for-byte in meaning.
    if deployment.statement_schema==R_C1_SCHEMA:obj.pop('statement_schema')
    return obj


def deployment_from_json(obj):
    obj=dict(obj)
    for key in PATH_FIELDS:obj[key]=Path(obj[key])
    return Deployment(**obj)


@dataclass(frozen=True)
class RungTokenItem:
    ids: tuple[int,...]
    sequence_dirs: tuple[Path,...]
    kind: str='classifier-dev-tokens'


def launch_pipeline(job):
    with (job/'pipeline.out').open('ab') as output:
        p=subprocess.Popen(['setsid','-f','nohup',sys.executable,str(PIPELINE),str(job)],
                           stdin=subprocess.DEVNULL,stdout=output,stderr=subprocess.STDOUT,close_fds=True)
        p.wait(timeout=30)


class RungClassifierProver(ClassifierProver):
    kind='classifier-dev-rung'
    label='Synthetic R-C1 classifier development fixture'
    supports=frozenset({'classifier-dev-tokens'})
    proves_verdict=True

    def __init__(self,deployment:Deployment,public_runs:Path):
        require(deployment.development,'RungClassifierProver requires the development deployment')
        self.cli=ClassifierCLI(deployment)
        self.protocol={R_C1_SCHEMA:'R-C1',R_C2_SCHEMA:'R-C2',R_C3_SCHEMA:'R-C3'}[deployment.statement_schema]
        self.label=f'Synthetic {self.protocol} classifier development fixture'
        self.public_runs=Path(public_runs).resolve()

    def describe(self):
        return {**super().describe(),'development_only':True,'policy':self.cli.deployment.policy,
                'binary_sha256':self.cli.deployment.binary_sha256,
                'what_is_proved':'Synthetic token fixture verdict; no real-text, Shieldstral or privacy acceptance.'}

    def _job(self,job,spec):
        job=Path(job).resolve()
        job.parent.mkdir(parents=True,mode=0o700,exist_ok=True)
        job.mkdir(mode=0o700,exist_ok=False)
        spec={'schema':'pm-classifier-job/1','deployment':deployment_json(self.cli.deployment),**spec}
        write_private(job/'classifier-job.json',records.canonical(spec))
        return job

    def start(self,post_id,item,job,chunk=None):
        prepared=self.prepare(post_id,item,job,chunk)
        launch_pipeline(prepared)

    def prepare(self,post_id,item,job,chunk=None):
        """Write a concrete private job without launching it (bounded CLI runner)."""
        if not isinstance(item,RungTokenItem):raise NotSupported(f'{self.protocol} development accepts synthetic token fixtures only')
        require(re.fullmatch(r'[A-Za-z0-9_-]{1,80}',post_id) is not None,'invalid development run identifier')
        require(all(type(x) is int and 5<=x<300 for x in item.ids),'invalid synthetic content token')
        d=self.cli.deployment;plan=chunk_plan(len(item.ids),d.chunk_size,d.overlap,allow_short=d.statement_schema==R_C3_SCHEMA)
        require(len(item.sequence_dirs)==len(plan) and all(Path(p).is_dir() for p in item.sequence_dirs),
                'one private sequence directory is required per chunk')
        if chunk is None:
            require(len(plan)==1,'explicit chunk required for a multi-chunk fixture')
            chunk={'index':0,'start':plan[0][0],'end':plan[0][1]}
        i=chunk['index'];require(type(i) is int and 0<=i<len(plan) and
                (chunk['start'],chunk['end'])==plan[i],'chunk differs from the registered split')
        artifact=self.public_runs/f'{post_id}-c{i}'
        job=Path(job).resolve();content=job/'content.ids';owner=job/'owner'
        self.public_runs.mkdir(parents=True,exist_ok=True)
        spec={'mode':'prove','post_id':post_id,'artifact':str(artifact),'total':len(item.ids),'chunk':i,
              'content_file':str(content),'owner_dir':str(owner),'sequence_dir':str(item.sequence_dirs[i])}
        job=self._job(job,spec)
        write_private(content,(','.join(str(x) for x in item.ids)+'\n').encode())
        # Validate all paths/permissions before starting a detached worker.
        self.cli.prove_command(content,i,item.sequence_dirs[i],artifact,owner)
        return job

    def poll(self,job):
        out=poll(job)
        if not out['done']:
            try:
                pid=int((job/'pipeline.pid').read_text())
                out['alive']=(job/'pipeline.boot_id').read_text().strip()==boot_id() and \
                    b'classifier_pipeline.py' in Path(f'/proc/{pid}/cmdline').read_bytes()
            except (OSError,ValueError):out['alive']=None
        return out

    def _checked(self,job):
        status=self.poll(job)
        require(status['done'] and status['exit']==0,'classifier pipeline has not succeeded')
        spec=json.loads((job/'classifier-job.json').read_text())
        require(spec['deployment']==deployment_json(self.cli.deployment),'job deployment differs')
        logs=job/'logs'
        for step in ('verify','inowner'):
            require((logs/f'{step}.exit').read_text().strip()=='0','fresh verifier or owner check failed')
            guard=json.loads((logs/f'{step}.guard.json').read_text())
            require(guard.get('exit')==0 and guard.get('child_rc')==0 and not guard.get('refused')
                    and not guard.get('guard_killed'),'guard did not report a successful verification')
        result=self.cli.collect_verified(spec['artifact'],spec['total'],spec['chunk'],
                 (logs/'verify.log').read_text(),0,(logs/'inowner.log').read_text(),0)
        retained=json.loads((job/'checked.json').read_text())
        require(result==retained,'verified artifact changed since the worker collected it')
        return spec,result

    def collect(self,post_id,item,job,chunk=None):
        spec,r=self._checked(job)
        require(spec['post_id']==post_id and isinstance(item,RungTokenItem) and len(item.ids)==spec['total'],
                'collected job differs from fixture')
        private_ids=tuple(int(x) for x in Path(spec['content_file']).read_text().strip().split(','))
        require(private_ids==item.ids,'collected job content differs from fixture')
        if chunk is not None:require(r['chunk']==chunk,'collected chunk differs')
        statement=r['statement'];d=self.cli.deployment
        return records.ProofRecord(post_id=post_id,item_kind=item.kind,prover=self.describe(),
            labels={'synthetic':{k:r[k] for k in ('value','proof','bound_by_proof','policy_id','development_only')}},
            policies=[{'id':d.policy,'category':'synthetic','development_only':True}],
            threshold={'margin_gt':statement.get('threshold_c')},
            content_commitment={'kind':'synthetic fixture input endpoint','value':statement['input_token_endpoint_root']},
            statement=statement,statement_sha256=r['statement_sha256'],
            receipt={'run_dir':r['run_dir'],'files':r['files'],'segments':len(r['files']),
                     'bytes':sum(f['bytes'] for f in r['files']),'inventory_source':f'app record; native {self.protocol} has no segments.json'},
            timings={},security={'whole_run_floor_bits':statement['whole_run_floor_bits'],'min_bits_required':d.min_bits,
                                 'note':'Development floor only; no production or privacy acceptance.'},
            checks={'verify':{'ok':True,'by':f'pinned {self.protocol} fresh process'},'content_binding':{'ok':True}},
            content_length={'tokens':r['chunk']['end']-r['chunk']['start'],'total_tokens':spec['total'],'tokenizer':'synthetic IDs, not text'},
            chunk=r['chunk'],created_at=records.now_iso(),proved_at=records.now_iso(),
            notes=['Development fixture only; never use these labels for media categories or testnet publication.'])

    def start_recheck(self,record,prove_job,job):
        launch_pipeline(self.prepare_recheck(record,prove_job,job))

    def prepare_recheck(self,record,prove_job,job):
        require(record.prover.get('kind')==self.kind and record.prover.get('development_only') is True,
                'recheck requires a development classifier record')
        original=json.loads((prove_job/'classifier-job.json').read_text())
        require(original['deployment']==deployment_json(self.cli.deployment) and
                original['artifact']==record.receipt['run_dir'] and original['post_id']==record.post_id,
                'recheck proof job differs')
        spec={k:original[k] for k in ('post_id','artifact','total','chunk','content_file','owner_dir')}
        return self._job(job,{'mode':'recheck',**spec})

    def collect_recheck(self,record,job):
        try:
            _,r=self._checked(job)
            require(r['statement_sha256']==record.statement_sha256 and r['files']==record.receipt['files'] and
                    r['value']==record.labels['synthetic']['value'],'rechecked record differs')
        except (ProverError,OSError,ValueError,KeyError) as exc:
            return records.Verdict('re-check',False,False,'classifier recheck failed',records.now_iso(),
                                   {'development_only':True,'message':str(exc)})
        return records.Verdict(r['value'],True,True,f'fresh {self.protocol} verifier and input-owner',records.now_iso(),
                               {'development_only':True,'content_binding':True})

    def start_label(self,chunk_records,job,*,item):
        launch_pipeline(self.prepare_label(chunk_records,job,item=item))

    def prepare_label(self,chunk_records,job,*,item):
        """Fresh native verification and OR for every chunk of ONE synthetic item."""
        require(isinstance(item,RungTokenItem) and item.ids and
                all(type(x) is int and 5<=x<300 for x in item.ids),'original synthetic item required for whole-post count')
        total=len(item.ids)
        require(bool(chunk_records),'no chunks to aggregate')
        first=chunk_records[0];normalized=[]
        for rec in chunk_records:
            require(rec.post_id==first.post_id and rec.prover==self.describe() and
                    rec.content_length['total_tokens']==total,
                    'aggregate mixes items or deployments')
            normalized.append({**rec.labels['synthetic'],'chunk':rec.chunk,'statement':rec.statement})
        # Structural checks happen before any native launch; native label still
        # verifies all segments afresh and supplies the final aggregate event.
        self.cli.check_label_records(normalized,total)
        runs=[r.receipt['run_dir'] for r in chunk_records];self.cli.label_command(runs,total)
        return self._job(job,{'mode':'label','post_id':first.post_id,'total':total,
                       'records':normalized,'runs':runs})

    def collect_label(self,job):
        status=self.poll(job);require(status['done'] and status['exit']==0,'aggregate pipeline has not succeeded')
        spec=json.loads((job/'classifier-job.json').read_text())
        require(spec['mode']=='label' and spec['deployment']==deployment_json(self.cli.deployment),'aggregate deployment differs')
        logs=job/'logs';guard=json.loads((logs/'label.guard.json').read_text())
        require((logs/'label.exit').read_text().strip()=='0' and guard.get('exit')==0 and guard.get('child_rc')==0
                and not guard.get('refused') and not guard.get('guard_killed'),'aggregate verification failed')
        result=self.cli.collect_label(spec['records'],(logs/'label.log').read_text(),0,spec['total'])
        require(result==json.loads((job/'checked.json').read_text()),'aggregate changed after collection')
        return result

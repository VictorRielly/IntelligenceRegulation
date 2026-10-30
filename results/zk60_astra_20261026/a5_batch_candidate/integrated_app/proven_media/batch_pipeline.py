"""Candidate batch pipeline: one guarded prove, then separate fresh checks.

Not registered in the app factory. Every confirmed terminal path calls the
same quarantine collector before exposing the supervisor completion marker.
"""
import hashlib
import json
import math
import os
from pathlib import Path
import sqlite3
import sys

from .batch_cleanup import _atomic_private
from .batch_request import prove_command, validate_manifest
from .batch_queue_gate import recover_batch
from .batch_supervisor import BatchSupervisor
from . import config, proof_plans, records, shieldstral_runtime as runtime
from .classifier_cli import ClassifierCLI, require

BATCH_BINARY = config.TOKEN_IO/'cli/zk60_classify.r18.release.bin'
BATCH_BINARY_SHA = '110f0c53c56f691c301fe4f47d13afc1ccc9898efbaaf8506f1e0d5cde5f4496'
SCHEMA = 'pm-classifier-batch-pipeline/1'


def source_pins():
    files=[Path(__file__).with_name(name) for name in ('batch_pipeline.py','batch_prover.py',
        'batch_request.py','batch_cleanup.py','batch_queue_gate.py','batch_registry.py','batch_supervisor.py')]
    from . import classifier_cli, shieldstral_prover
    files += [Path(m.__file__) for m in (config,proof_plans,records,runtime,classifier_cli,shieldstral_prover)]
    return {str(p.resolve()):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}


def registration(job):
    """Read the original atomic queue claim without opening a writable store."""
    job=Path(job).resolve()
    require(job == (config.JOBS_DIR/job.parent.name/'batch').resolve(), 'batch job outside configured root')
    with sqlite3.connect('file:'+str(config.DB_PATH)+'?mode=ro',uri=True) as db:
        db.row_factory=sqlite3.Row
        row=db.execute('SELECT * FROM batch_runs WHERE job_dir=?',(str(job),)).fetchone()
    require(row is not None, 'batch launch has no original queue claim')
    row=dict(row)
    require(row['post_id']==job.parent.name and row['receipts']==str(config.RUNS_DIR.resolve())
            and row['status']=='active', 'batch registration is not launchable')
    return row


def load_spec(job, row):
    job=Path(job)
    spec=json.loads((job/'batch-pipeline.json').read_text())
    request=json.loads((job/'batch-request.json').read_text())
    require(spec['schema']==SCHEMA and spec['post_id']==row['post_id']
            and spec['launch_id']==row['launch_id'] and spec['boot_id']==row['boot_id']
            and spec['context']==row['context']==records.screening_context()
            and spec['plan']==json.loads(row['plan']), 'batch pipeline differs from queue claim')
    require(spec['source_sha256']==source_pins(), 'batch pipeline sources changed')
    require(spec['prover_binary']==str(BATCH_BINARY) and spec['prover_sha256']==BATCH_BINARY_SHA
            and records.sha256_file(BATCH_BINARY)==BATCH_BINARY_SHA, 'batch prover pin changed')
    ids=tuple(int(x) for x in (job/'content.ids').read_text().strip().split(','))
    require(type(spec['total']) is int and len(ids)==spec['total'], 'whole-post content length changed')
    work=validate_manifest(request,len(ids));proof_plans.check_plan(spec['plan'],work)
    require(spec['request_sha256']==hashlib.sha256(records.canonical(request)).hexdigest(),
            'batch manifest changed after queue claim')
    require(spec['native_threads']==8 and type(spec['native_threads']) is int,
            'batch candidate currently requires the explicit eight-thread profile')
    require(type(spec['max_prove_seconds']) is int and spec['max_prove_seconds']>=900*len(work),
            'batch time cap must include per-job margin')
    require(len(work)*848412096<=10_000_000_000 or bool(spec['large_batch_window']),
            'batch over10GB requires an announced D46 window')
    for template in runtime.templates():runtime.validate(runtime.deployment(template))
    return spec,request


def commands(job, spec, request):
    job=Path(job);total=spec['total']
    def wrapped(argv, threads=8):
        return ['/usr/bin/env','RAYON_NUM_THREADS='+str(threads),'OPENBLAS_NUM_THREADS=2','OMP_NUM_THREADS=2',*map(str,argv)]
    need,cap,maximum=runtime.RESOURCES['seqgen']
    out=[('seqgen',wrapped([config.SYSTEM_PYTHON,runtime.WRITER,'--request',job/'activation-request.json',
                           '--out',job/'activations'],2),need,cap,maximum)]
    need,cap,_=runtime.RESOURCES['prove']
    out.append(('prove-batch',wrapped(prove_command(request,total,job,BATCH_BINARY,BATCH_BINARY_SHA)),
                need,cap,spec['max_prove_seconds']))
    clis={t.policy_id:ClassifierCLI(runtime.deployment(t)) for t in runtime.templates()}
    for row in request['jobs']:
        cli=clis[row['policy_id']]
        for suffix,argv in [('verify',cli.verify_command(row['out'])),
            ('inowner',cli.owner_command(row['out'],Path(row['owner_dir'])/'input.dec',job/'content.ids'))]:
            out.append((row['name']+'-'+suffix,wrapped(argv),*runtime.RESOURCES[suffix]))
    for t in runtime.templates():
        paths=[r['out'] for r in request['jobs'] if r['policy_id']==t.policy_id]
        out.append((t.category+'-label',wrapped(clis[t.policy_id].label_command(paths,total)),
                    *runtime.RESOURCES['label']))
    return out


def clean_guard(job, step):
    name,argv,need,cap,maximum=step
    logs=Path(job)/'logs';g=json.loads((logs/(name+'.guard.json')).read_text())
    require((logs/(name+'.guard.done')).read_text().strip()=='0'
            and all(type(g.get(k)) is int and g[k]==0 for k in ('exit','child_rc'))
            and not any(g.get(k) for k in ('guard_killed','refused','guard_error','hard_killed',
                'stragglers_killed','foreign_cgroups_refused','gpu_drain_failed')),
            'required batch/check step did not cleanly succeed')
    require(g.get('cmd')==argv and g.get('need_gib')==need and g.get('cap_gib')==cap,
            'guard ran a different batch/check command')
    require(type(g.get('child_wall_seconds')) in (int,float)
            and math.isfinite(g['child_wall_seconds']) and g['child_wall_seconds']>=0,
            'invalid measured batch work')
    return g


def collect_checks(job, spec, request):
    """Parse fresh native checks and rehash every receipt with the existing CLI."""
    job=Path(job);total=spec['total'];steps=commands(job,spec,request)
    guards={step[0]:clean_guard(job,step) for step in steps}
    templates={t.policy_id:t for t in runtime.templates()}
    checked=[]
    for row,chunk in zip(request['jobs'],spec['plan']):
        template=templates[row['policy_id']];cli=ClassifierCLI(runtime.deployment(template))
        r=cli.collect_verified(row['out'],total,chunk['category_chunk_index'],
            (job/'logs'/(row['name']+'-verify.log')).read_text(),0,
            (job/'logs'/(row['name']+'-inowner.log')).read_text(),0)
        st=r['statement']
        require(st['template_prefix_ids']==list(template.prefix)
                and st['template_suffix_ids']==list(template.suffix) and st['blocks']==26,
                'batch receipt model/template differs')
        checked.append(r)
    aggregates={}
    for t in runtime.templates():
        parts=[r for r,ch in zip(checked,spec['plan']) if ch['category']==t.category]
        cli=ClassifierCLI(runtime.deployment(t))
        result=cli.collect_label(parts,(job/'logs'/(t.category+'-label.log')).read_text(),0,total)
        aggregates[t.category]={'result':result,'statement_sha256':[p['statement_sha256'] for p in parts],
                                'total':total}
    return {'schema':'pm-batch-verified/1','post_id':spec['post_id'],'launch_id':spec['launch_id'],
            'checked':checked,'aggregates':aggregates,'work_s':sum(g['child_wall_seconds'] for g in guards.values()),
            'steps':{k:{n:g.get(n) for n in ('child_wall_seconds','peak_rss_gib','enforcement','waited_s')}
                     for k,g in guards.items()}}


def run_registered(job):
    job=Path(job).resolve();row=registration(job)
    def collect_terminal(code):
        result=recover_batch(job,config.RUNS_DIR,post_id=row['post_id'],
            reserved_plan=json.loads(row['plan']),reserved_context=row['context'],
            terminal_confirmed=True,terminal_exit=code,reserved_scope=json.loads(row['scope']))
        require(code!=0 or result['status']=='unverified', 'successful batch was quarantined')
        return result
    def steps():
        spec,request=load_spec(job,row)
        from .batch_registry import boot_id
        require(row['boot_id']==boot_id(), 'an old batch cannot launch after reboot')
        for step in commands(job,spec,request):
            yield step
            if step[0]=='prove-batch':
                result=collect_terminal(0)
                require(result['status']=='unverified', 'batch transport was quarantined')
        _atomic_private(job/'batch-verified.json',collect_checks(job,spec,request))
    return BatchSupervisor(job,row['launch_id']).run(steps(),on_terminal=collect_terminal)


if __name__=='__main__':
    os.umask(0o077)
    raise SystemExit(run_registered(Path(sys.argv[1])))

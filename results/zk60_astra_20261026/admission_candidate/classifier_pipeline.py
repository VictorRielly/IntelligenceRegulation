#!/usr/bin/env python3
"""Private detached R-C1 worker. Every native CLI leaf passes the shared guard."""
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import time

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from proven_media import config,records
from proven_media.classifier_cli import ClassifierCLI,require
from proven_media.classifier_prover import deployment_from_json

HOLDS=(config.HOLD_FILE,config.REPO/'results/zk60_shieldstral_prep_20261021/HOLD',
       config.REPO/'results/zk60_shieldstral_export_20261026/HOLD')
# Retained R-C1 one-block bootstrap measured0.16GiB RSS in2s on2026-10-26.
# 0.7GiB adds0.54GiB; native token-lane captures separately measured0.19GiB.
# This is a bounded development-rung declaration, never a Shieldstral one.
NEED_GIB=0.7
CAP_GIB=1.5


def atomic(path,data):
    temporary=path.with_suffix(path.suffix+'.tmp')
    temporary.write_text(data);os.replace(temporary,path)


def execution_settings(native_threads):
    require(type(native_threads) is int and native_threads in (2, 8), 'unsupported native thread count')
    from proven_media import shieldstral_runtime as runtime
    limits = {name: maximum for name, (_, _, maximum) in runtime.RESOURCES.items()}
    # Coordinator 2026-10-30T01:02: >=1.5x expected work. At two threads
    # current measured segment pace predicts ~18min; reserve at least27min.
    limits['prove'] = max(limits['prove'], 1620 if native_threads == 2 else 900)
    return {'schema': 'pm-classifier-execution/1', 'native_threads': native_threads,
            'numpy_threads': 2, 'max_seconds': limits}


def freeze_execution(job):
    raw = os.environ.get('PM_CLASSIFIER_NATIVE_THREADS', '2')
    require(raw in ('2', '8'), 'unsupported native thread count')
    execution = execution_settings(int(raw))
    path = job/'execution.json'
    if path.exists():
        require(json.loads(path.read_text()) == execution, 'job execution settings changed')
    else:
        atomic(path, json.dumps(execution, sort_keys=True)+'\n')
    return execution


def prove_preflight_busy(status):
    """Honor the lean rule while allowing existing light jobs of at most1GiB.

    The unchanged guard still performs memory, disk and shared-lock admission.
    Unknown status data fails closed; this is not permission to overlap heavy jobs.
    """
    require(type(status) is dict and type(status.get('live_guarded_jobs')) is list,
            'invalid guarded-job status')
    busy = False
    for job in status['live_guarded_jobs']:
        require(type(job) is dict and job.get('class') in ('light','cpu','build','gpu')
                and type(job.get('need_gib')) in (int,float)
                and 0 < job['need_gib'] < float('inf'), 'invalid guarded-job declaration')
        busy |= job['class'] != 'light' or job['need_gib'] > 1
    return busy


def run_step(job,name,command,cli):
    logs=job/'logs';deadline=time.monotonic()+config.GUARD_WAIT_SECS
    while True:
        require(time.monotonic()<deadline,'admission wait timed out')
        held=any(p.exists() for p in HOLDS)
        atomic(job/'step.current',f'{"held" if held else name} {time.time()}\n')
        if held:time.sleep(15);continue
        if not cli.deployment.development and name == 'prove':
            status = subprocess.run(['python3', str(config.GUARD), 'status', '--json'],
                                    capture_output=True, text=True, timeout=15)
            require(status.returncode == 0, 'cannot inspect shared machine admission')
            if prove_preflight_busy(json.loads(status.stdout)):
                atomic(job/'step.current', f'held {time.time()}\n')
                time.sleep(5)
                continue
        # S3 is installed; coordinator20:04:30 recommends direct admission.
        # The guard waits without a heavy lock and polls roughly once a second.
        break
    cli.deployment.validate()
    need, cap, maximum = NEED_GIB, CAP_GIB, 1200
    if not cli.deployment.development:
        from proven_media import shieldstral_runtime as runtime
        runtime.validate(cli.deployment)
        need, cap, maximum = runtime.RESOURCES[name]
        execution = json.loads((job/'execution.json').read_text())
        raw_threads = os.environ.get('PM_CLASSIFIER_NATIVE_THREADS', '2')
        require(raw_threads in ('2', '8') and execution == execution_settings(int(raw_threads)),
                'job execution settings differ from this process')
        maximum = execution['max_seconds'][name]
        threads = 2 if name == 'seqgen' else execution['native_threads']
        command = ['/usr/bin/env', 'RAYON_NUM_THREADS='+str(threads), 'OPENBLAS_NUM_THREADS=2', 'OMP_NUM_THREADS=2', *command]
    argv=['python3',str(config.GUARD),'run','--class','cpu','--need-gib',str(need),'--cap-gib',str(cap),
          '--label','pm-classify-'+name,'--wait-secs',str(config.GUARD_WAIT_SECS),'--max-secs',str(maximum),'--log',str(logs/f'{name}.log'),
          '--done',str(logs/f'{name}.guard.done'),'--result-json',str(logs/f'{name}.guard.json'),'--',*command]
    with (logs/f'{name}.guard.out').open('wb') as output:
        result=subprocess.run(argv,stdout=output,stderr=subprocess.STDOUT)
    atomic(logs/f'{name}.exit',str(result.returncode)+'\n')
    require(result.returncode==0,'guarded '+name+' failed')


def worker(job):
    spec=json.loads((job/'classifier-job.json').read_text())
    require(spec['schema']=='pm-classifier-job/1','unknown worker schema')
    cli=ClassifierCLI(deployment_from_json(spec['deployment']))
    real = not cli.deployment.development
    if real:
        from proven_media import shieldstral_runtime as runtime
        runtime.validate(cli.deployment)
        freeze_execution(job)
    require(spec['mode'] in ('prove','recheck','label'),'unknown worker mode')
    if spec['mode']=='label':
        cli.check_label_records(spec['records'],spec['total'])
        run_step(job,'label',cli.label_command(spec['runs'],spec['total']),cli)
        checked=cli.collect_label(spec['records'],(job/'logs/label.log').read_text(),0,spec['total'])
        atomic(job/'checked.json',json.dumps(checked,sort_keys=True)+'\n')
        return
    artifact=spec['artifact'];owner=Path(spec['owner_dir']);content=spec['content_file']
    if spec['mode']=='prove':
        if real:
            run_step(job, 'seqgen', ['/usr/bin/env', 'OPENBLAS_NUM_THREADS=2', 'OMP_NUM_THREADS=2',
                config.SYSTEM_PYTHON, str(runtime.WRITER), '--request', spec['activation_request'],
                '--out', str(Path(spec['sequence_dir']).parent)], cli)
        run_step(job,'prove',cli.prove_command(content,spec['chunk'],spec['sequence_dir'],artifact,owner),cli)
    run_step(job,'verify',cli.verify_command(artifact),cli)
    run_step(job,'inowner',cli.owner_command(artifact,owner/'input.dec',content),cli)
    logs=job/'logs'
    checked=cli.collect_verified(artifact,spec['total'],spec['chunk'],(logs/'verify.log').read_text(),0,
                                 (logs/'inowner.log').read_text(),0)
    if real and spec['mode'] == 'prove' and spec['last_category_chunk']:
        prior = []
        for previous in spec['prior_jobs']:
            previous = Path(previous)
            ps = json.loads((previous/'classifier-job.json').read_text())
            require((previous/'pipeline.done').read_text().strip() == '0'
                    and ps['deployment'] == spec['deployment'] and ps['post_id'] == spec['post_id']
                    and Path(ps['content_file']).read_bytes() == Path(content).read_bytes(),
                    'category aggregate belongs to different content or deployment')
            prior.append(json.loads((previous/'checked.json').read_text()))
        parts = prior + [checked]
        cli.check_label_records(parts, spec['total'])
        run_step(job, 'label', cli.label_command([p['run_dir'] for p in parts], spec['total']), cli)
        aggregate = cli.collect_label(parts, (logs/'label.log').read_text(), 0, spec['total'])
        atomic(job/'label-checked.json', json.dumps({'result': aggregate,
            'statement_sha256': [p['statement_sha256'] for p in parts], 'total': spec['total']}, sort_keys=True)+'\n')
    atomic(job/'checked.json',json.dumps(checked,sort_keys=True)+'\n')


def main():
    os.umask(0o077);job=Path(sys.argv[1]).resolve()
    with (job/'pipeline.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        require(not (job/'pipeline.done').exists(),'worker already terminal')
        (job/'logs').mkdir(mode=0o700,exist_ok=True)
        atomic(job/'pipeline.pid',str(os.getpid())+'\n')
        atomic(job/'pipeline.boot_id',Path('/proc/sys/kernel/random/boot_id').read_text())
        code=1
        try:
            worker(job);code=0
        except Exception as exc:
            # Logs stay private. Public callers receive only a generic refusal.
            atomic(job/'logs/error.json',json.dumps({'type':type(exc).__name__,'message':str(exc)})+'\n')
        finally:
            atomic(job/'step.current',f'done {time.time()}\n')
            atomic(job/'pipeline.done',str(code)+'\n')
        return code


if __name__=='__main__':raise SystemExit(main())

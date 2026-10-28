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


def run_step(job,name,command,cli):
    logs=job/'logs';deadline=time.monotonic()+config.GUARD_WAIT_SECS
    while True:
        require(time.monotonic()<deadline,'admission wait timed out')
        held=any(p.exists() for p in HOLDS)
        atomic(job/'step.current',f'{"held" if held else name} {time.time()}\n')
        if held:time.sleep(15);continue
        # S3 is installed; coordinator20:04:30 recommends direct admission.
        # The guard waits without a heavy lock and polls roughly once a second.
        break
    cli.deployment.validate()
    argv=['python3',str(config.GUARD),'run','--class','cpu','--need-gib',str(NEED_GIB),'--cap-gib',str(CAP_GIB),
          '--label','pm-classify-'+name,'--wait-secs',str(config.GUARD_WAIT_SECS),'--max-secs','1200','--log',str(logs/f'{name}.log'),
          '--done',str(logs/f'{name}.guard.done'),'--result-json',str(logs/f'{name}.guard.json'),'--',*command]
    with (logs/f'{name}.guard.out').open('wb') as output:
        result=subprocess.run(argv,stdout=output,stderr=subprocess.STDOUT)
    atomic(logs/f'{name}.exit',str(result.returncode)+'\n')
    require(result.returncode==0,'guarded '+name+' failed')


def worker(job):
    spec=json.loads((job/'classifier-job.json').read_text())
    require(spec['schema']=='pm-classifier-job/1','unknown worker schema')
    cli=ClassifierCLI(deployment_from_json(spec['deployment']))
    require(cli.deployment.development,'worker declarations cover the development rung only')
    require(spec['mode'] in ('prove','recheck','label'),'unknown worker mode')
    if spec['mode']=='label':
        run_step(job,'label',cli.label_command(spec['runs']),cli)
        checked=cli.collect_label(spec['records'],(job/'logs/label.log').read_text(),0,spec['total'])
        atomic(job/'checked.json',json.dumps(checked,sort_keys=True)+'\n')
        return
    artifact=spec['artifact'];owner=Path(spec['owner_dir']);content=spec['content_file']
    if spec['mode']=='prove':
        run_step(job,'prove',cli.prove_command(content,spec['chunk'],spec['sequence_dir'],artifact,owner),cli)
    run_step(job,'verify',cli.verify_command(artifact),cli)
    run_step(job,'inowner',cli.owner_command(artifact,owner/'input.dec',content),cli)
    logs=job/'logs'
    checked=cli.collect_verified(artifact,spec['total'],spec['chunk'],(logs/'verify.log').read_text(),0,
                                 (logs/'inowner.log').read_text(),0)
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

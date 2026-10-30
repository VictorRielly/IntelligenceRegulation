"""One detached finalizer: anchor, verify stored bytes, check app, capture, report.

Each native verification keeps its own guard. The screenshot server has no
worker and is stopped by its helper. A failed step is retained and never retried
automatically. This script cannot launch any new proof.
"""
import argparse
from datetime import datetime,timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];OUT=HERE/'real_app_demo_2'
RUN=OUT/'finalization'


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--detach',action='store_true')
    parser.add_argument('--wait',action='store_true',help='Wait for all three accepted categories; never launch a proof')
    a=parser.parse_args()
    assert (OUT/'plan.json').exists()

    def categories_ready():
        ready=True
        for category in ('sexual','violence','hate'):
            done=OUT/(category+'.supervisor.done')
            if done.exists() and done.read_text().strip()!='0':
                raise RuntimeError(category+' supervisor failed; finalization refused')
            ready &= done.exists() and (OUT/(category+'.done')).exists()
        return ready

    if not a.wait:assert categories_ready()
    if a.detach:
        RUN.mkdir(exist_ok=False)
        with (RUN/'supervisor.log').open('xb') as log:
            child=subprocess.Popen([sys.executable,str(Path(__file__).resolve()),*(['--wait'] if a.wait else [])],cwd=ROOT,
                stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
        launch={'pid':child.pid,'boot_id':Path('/proc/sys/kernel/random/boot_id').read_text().strip(),
                'worker_done':str(RUN/'worker.done')}
        (RUN/'launch.json').write_text(json.dumps(launch,indent=2)+'\n');print(json.dumps(launch));return
    assert RUN.is_dir() and not (RUN/'worker.done').exists()
    steps=[('anchor','run_durable_app_demo.py',['anchor']),
           ('stored-verify','verify_durable_app_store.py',[]),
           ('app-checks','check_durable_app_demo.py',[]),
           ('screenshots','capture_durable_demo.py',[]),
           ('report','report_durable_demo.py',[])]
    evidence={'started':datetime.now(timezone.utc).isoformat(),'steps':[],
              'source_sha256':{name:hashlib.sha256((HERE/name).read_bytes()).hexdigest() for _,name,_ in steps}}
    (RUN/'plan.json').write_text(json.dumps(evidence,indent=2)+'\n')
    code=1
    try:
        if a.wait:
            print(json.dumps({'status':'waiting for all three accepted categories; no proof launched'}),flush=True)
            while not categories_ready():time.sleep(10)
        for script,pin in evidence['source_sha256'].items():
            assert hashlib.sha256((HERE/script).read_bytes()).hexdigest()==pin,'finalization source changed while waiting'
        for name,script,args in steps:
            print(json.dumps({'step':name,'status':'starting'}),flush=True)
            with (RUN/(name+'.log')).open('xb') as log:
                result=subprocess.run([sys.executable,str(HERE/script),*args],cwd=ROOT,
                                      stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT)
            row={'step':name,'exit':result.returncode,'at':datetime.now(timezone.utc).isoformat()}
            evidence['steps'].append(row);print(json.dumps(row),flush=True)
            (RUN/(name+'.done')).write_text(str(result.returncode)+'\n')
            if result.returncode:raise RuntimeError(name+' failed; inspect retained log before any continuation')
        code=0
    finally:
        evidence['exit']=code;evidence['finished']=datetime.now(timezone.utc).isoformat()
        (RUN/'result.json').write_text(json.dumps(evidence,indent=2)+'\n')
        (RUN/'worker.done').write_text(str(code)+'\n')


if __name__=='__main__':main()

"""Own-lane detached job launcher with admission polling and coordinator HOLDs.

Only the named fixed leaf commands below are launchable. Never signals processes,
never reuses a finished job directory, and never interprets a missing PID as exit.
"""
import argparse
from datetime import datetime,timezone
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import time

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
EXPORT=ROOT/'results/zk60_shieldstral_export_20261026'
GUARD=ROOT/'scripts/zk60_resource_guard.py'
HOLDS=(ROOT/'results/zk60_shieldstral_prep_20261021/HOLD',EXPORT/'HOLD')
JOBS={
 'compile-anchor':('build',.5,1.0,600,['python3',str(ROOT/'apps/proven-media/tools/compile_anchor.py'),
                   '--out',str(HERE/'testnet/anchor_contract.json')]),
 'checkpoint-smoke':('light',1.8,3.0,600,['/usr/bin/env','OPENBLAS_NUM_THREADS=4','OMP_NUM_THREADS=4',
                   'python3',str(EXPORT/'smoke_checkpoint.py'),'--out',str(EXPORT/'checkpoint_smoke.json')]),
 'layer25-locate':('light',2.4,4.5,1800,['/usr/bin/env','OPENBLAS_NUM_THREADS=2','OMP_NUM_THREADS=2',
                   'python3',str(EXPORT/'probe_layer25.py'),'locate']),
 'layer25-integer-probe':('light',3.2,5.0,1800,['/usr/bin/env','OPENBLAS_NUM_THREADS=2','OMP_NUM_THREADS=2',
                   'python3',str(EXPORT/'probe_layer25.py'),'integer','--max-minutes','0.25']),
 'layer25-integer-continue1':('light',1.3,3.0,1800,['/usr/bin/env','OPENBLAS_NUM_THREADS=2','OMP_NUM_THREADS=2',
                   'python3',str(EXPORT/'probe_layer25.py'),'integer']),
}
# Continuation1 measured peak RSS1.86 GiB; 2.4 GiB includes29% margin.
# Each continuation resumes hash-checked completed layers, exits3 at its timebox.
for number in range(1,5):
    JOBS['stats-continue-'+str(number)]=('light',2.4,4.5,2400,
        ['/usr/bin/env','OPENBLAS_NUM_THREADS=6','OMP_NUM_THREADS=6',
         'python3',str(EXPORT/'collect_stats.py'),'--max-minutes','25'])


def main():
    ap=argparse.ArgumentParser(); ap.add_argument('action',choices=['start','worker','status'])
    ap.add_argument('job',choices=JOBS); a=ap.parse_args()
    directory=HERE/'jobs'/a.job
    if a.action=='start':
        directory.mkdir(parents=True,exist_ok=False)
        with (directory/'launcher.log').open('ab') as log:
            p=subprocess.Popen(['nohup','python3',str(Path(__file__).resolve()),'worker',a.job],
                 cwd=ROOT,stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT,start_new_session=True,close_fds=True)
        info={'pid':p.pid,'boot_id':Path('/proc/sys/kernel/random/boot_id').read_text().strip(),
              'started':datetime.now(timezone.utc).isoformat(),'job':a.job}
        (directory/'launch.json').write_text(json.dumps(info,indent=2)+'\n');print(json.dumps(info));return
    if a.action=='status':
        out={'job':a.job,'launch':json.loads((directory/'launch.json').read_text()) if (directory/'launch.json').exists() else None,
             'done':(directory/'worker.done').read_text().strip() if (directory/'worker.done').exists() else None}
        print(json.dumps(out));return
    klass,need,cap,seconds,command=JOBS[a.job]
    directory.mkdir(parents=True,exist_ok=True)
    with (directory/'worker.lock').open('w') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        if (directory/'worker.done').exists():raise SystemExit('job already terminal')
        while True:
            if any(p.exists() for p in HOLDS):time.sleep(15);continue
            checked=subprocess.run(['python3',str(GUARD),'check','--class',klass,'--need-gib',str(need)],capture_output=True,text=True)
            (directory/'precheck.txt').write_text(checked.stdout+checked.stderr)
            if checked.returncode==0 and 'OK to start now' in checked.stdout and not any(p.exists() for p in HOLDS):break
            time.sleep(15)
        cmd=['python3',str(GUARD),'run','--class',klass,'--need-gib',str(need),'--cap-gib',str(cap),
             '--label','astra-'+a.job,'--wait-secs','60','--max-secs',str(seconds),
             '--log',str(directory/'leaf.log'),'--done',str(directory/'leaf.done'),
             '--result-json',str(directory/'guard.json'),'--',*command]
        rc=subprocess.run(cmd,cwd=ROOT).returncode
        (directory/'worker.done').write_text(str(rc)+'\n')
        raise SystemExit(rc)


if __name__=='__main__':main()

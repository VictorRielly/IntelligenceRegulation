"""One guarded synthetic proof to record this retained export's native identity.

This bootstrap is deliberately separate from the app test. Its receipt remains
unverified. A subsequent app pipeline must prove and independently verify again
against the recorded identity and unchanged fixture/source/binary hashes.
"""
import hashlib
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
FIX=HERE/'classifier_fixture';PRIVATE=Path('/tmp/zk60-astra-classifier-owner-20261026')
BIN=ROOT/'results/zk60_token_io_r1_20261017/cli/zk60_classify.r12.release.bin'
PIN='04036e269a5c0984c70dd2b391dc9e045156d87dfd9c41ccccad4088a204bb76'
GUARD=ROOT/'scripts/zk60_resource_guard.py'
HOLDS=[ROOT/('results/'+lane+'/HOLD') for lane in ('zk60_media_app_20261021','zk60_shieldstral_prep_20261021','zk60_shieldstral_export_20261026')]


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--attempt',type=int,default=2);args=ap.parse_args()
    if args.attempt<2:raise ValueError('original attempt is retained')
    name='bootstrap-'+str(args.attempt)
    logs=FIX/name;logs.mkdir(exist_ok=False)
    source=sha(FIX/'fixture.json')
    if sha(BIN)!=PIN:raise ValueError('classifier binary pin differs')
    while True:
        if any(p.exists() for p in HOLDS):time.sleep(10);continue
        check=subprocess.run(['python3',str(GUARD),'check','--class','cpu','--need-gib','0.5'],capture_output=True,text=True)
        (logs/'precheck.txt').write_text(check.stdout+check.stderr)
        if check.returncode==0 and 'OK to start now' in check.stdout and not any(p.exists() for p in HOLDS):break
        time.sleep(10)
    # The token lane's retained classifier rung captures measured0.19GiB RSS
    # and2–4s on this geometry (PROGRESS19:07); use0.5GiB plus1GiB hard cap.
    command=[str(BIN),'prove','--export',str(FIX/'prover-export'),'--tables',str(FIX/'tables'),
        '--policy','rung-tc-synthetic-policy-dev/1','--content-file',str(PRIVATE/'content.ids'),'--chunk','0',
        '--seq','s0','--out',str(FIX/(name+'-run')),'--owner-dir',str(PRIVATE/(name+'-owner')),
        '--label','zk60-classify-verdict']
    rc=subprocess.run(['python3',str(GUARD),'run','--class','cpu','--need-gib','0.5','--cap-gib','1.0',
        '--label','astra-classifier-bootstrap','--wait-secs','60','--max-secs','300',
        '--log',str(logs/'prove.log'),'--done',str(logs/'prove.done'),'--result-json',str(logs/'guard.json'),'--',*command]).returncode
    if rc:
        (logs/'worker.done').write_text(str(rc)+'\n')
        return rc
    events=[json.loads(line) for line in (logs/'prove.log').read_text().splitlines() if line.startswith('{')]
    loaded=[e for e in events if e.get('event')=='loaded'];proved=[e for e in events if e.get('event')=='proved']
    if len(loaded)!=1 or len(proved)!=1 or any(e.get('event')=='refused' for e in events):raise ValueError('bootstrap CLI contract differs')
    identity=loaded[0]['trained_statement_identity']
    if sha(BIN)!=PIN or sha(FIX/'fixture.json')!=source:raise ValueError('fixture or binary changed')
    pin={'trained_statement_identity':identity,'binary_sha256':PIN,'fixture_manifest_sha256':source,
         'scope':'synthetic model identity recorded by pinned native CLI; receipt NOT VERIFIED; app fresh verification still required'}
    (FIX/'native_model_pin.json').write_text(json.dumps(pin,indent=2)+'\n');print(json.dumps(pin))
    (logs/'worker.done').write_text('0\n')
    return 0


if __name__=='__main__':raise SystemExit(main())

"""Frozen native CLI acceptance of Astra's T128 candidate, actual L00 only.

One public synthetic input; does not claim a full-stack or classifier proof.
Each native leaf is separately admitted under the common resource guard.
"""
import argparse
from datetime import datetime,timezone
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
EXPORT=ROOT/'results/zk60_shieldstral_export_20261026/native_low_h24_t128'
NATIVE=ROOT/'results/zk60_1b_native_20261017/r13'
CLI=NATIVE/'zk60_trained_block.release.bin'
CLI_SHA='899d7c01a1abc8839156d29d4667536a9eb43cb3b5285ff6f698c6b2cf549cf1'

def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda:f.read(1<<20),b''):h.update(block)
    return h.hexdigest()

def save(path,obj):path.write_text(json.dumps(obj,indent=2)+'\n')

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--attempt',type=int,required=True);args=parser.parse_args()
    assert args.attempt>0
    holds=[ROOT/'results'/name/'HOLD' for name in ('zk60_shieldstral_export_20261026','zk60_shieldstral_prep_20261021','zk60_media_app_20261021')]
    assert not any(p.exists() for p in holds),'coordinator hold active'
    complete=json.loads((EXPORT/'complete.json').read_text());profile_pin=complete['profile_sha256']
    assert len(complete['layers'])==26 and sha(EXPORT/'profile.json')==profile_pin
    assert sha(CLI)==CLI_SHA
    seq=NATIVE/'actual-t128-public-sequence';oracle=NATIVE/'actual-t128-smoke-export/PUBLIC_ORACLE.json'
    assert sha(oracle)=='9fe10a9c257bd18baf1dd00d752ddfa4e46ef0db914027fcc715d26f2d8e59b2'
    seqpins={'x_in_L00.bin':'95edfa4b878bb34c92290ac8021af90a62c82f84898456e0de1518a4831b2348',
             'x_out_L00.bin':'dd55ad657278bafdae0cb62855cd233ffef52e24d15d7d524225733c54ebaa7b'}
    for name,digest in seqpins.items():assert sha(seq/name)==digest
    out=HERE/f'native_t128_check_{args.attempt}';out.mkdir(exist_ok=False)
    record={'schema':'zk60-astra-native-t128-check/1','at':datetime.now(timezone.utc).isoformat(),
        'scope':'Actual L00/T128 with public synthetic input from independent19-site oracle; no full26/classifier/fidelity/privacy acceptance',
        'cli_sha256':CLI_SHA,'profile_sha256':profile_pin,'oracle_sha256':sha(oracle),
        'input_output_sha256':seqpins,'tool_sha256':sha(Path(__file__)),'steps':{}}
    artifact=out/'receipt'
    def step(name,need,cap,argv,expected=0):
        assert sha(CLI)==CLI_SHA and sha(EXPORT/'profile.json')==profile_pin
        assert not any(p.exists() for p in holds),'coordinator hold active'
        prefix=out/name
        command=['python3',str(ROOT/'scripts/zk60_resource_guard.py'),'run','--class','cpu',
            '--label','astra-native-t128-'+name,'--need-gib',str(need),'--cap-gib',str(cap),
            '--wait-secs','1800','--max-secs','600','--log',str(prefix.with_suffix('.log')),
            '--done',str(prefix.with_suffix('.done')),'--result-json',str(prefix.with_suffix('.guard.json')),
            '--','/usr/bin/env','RAYON_NUM_THREADS=2','OPENBLAS_NUM_THREADS=1',str(CLI),*argv]
        save(prefix.with_suffix('.command.json'),command)
        rc=subprocess.run(command).returncode
        guard=json.loads(prefix.with_suffix('.guard.json').read_text())
        assert rc==guard['exit']==guard['child_rc']==expected and not guard['guard_killed'],name
        events=[json.loads(line) for line in prefix.with_suffix('.log').read_text().splitlines() if line.startswith('{')]
        record['steps'][name]={'exit':rc,'guard':{k:guard[k] for k in ('child_wall_seconds','peak_rss_gib','peak_cgroup_gib','enforcement')},
                             'events':events,'log_sha256':sha(prefix.with_suffix('.log'))}
        save(out/'partial.json',record)
        return events
    try:
        # Prior normal-release actual L00 peak7.67GiB plus25% ->9.6GiB.
        events=step('prove',9.6,11,['prove','--export',str(EXPORT),'--layer','0','--seq-dir',str(seq),'--out',str(artifact)])
        proved=[e for e in events if e.get('event')=='proved'];assert len(proved)==1
        identity=proved[0]['statement_identity'];record['statement_identity']=identity
        verify=['verify','--export',str(EXPORT),'--layer','0','--expect-statement',identity]
        events=step('verify',0.9,1.5,[*verify,'--artifact',str(artifact)])
        assert sum(e.get('event')=='verified' for e in events)==1
        tampered=out/'tampered-receipt';shutil.copytree(artifact,tampered)
        path=tampered/'segment-000.bin'
        with path.open('r+b') as f:
            f.seek(path.stat().st_size//2);value=f.read(1);f.seek(-1,1);f.write(bytes([value[0]^1]))
        events=step('tamper',0.9,1.5,[*verify,'--artifact',str(tampered)],expected=1)
        assert any(e.get('event')=='rejected' for e in events) and not any(e.get('event')=='verified' for e in events)
        record['finished_at']=datetime.now(timezone.utc).isoformat();save(out/'complete.json',record)
        (out/'worker.done').write_text('0\n')
    except Exception as error:
        save(out/'failure.json',{'type':type(error).__name__,'message':str(error)});(out/'worker.done').write_text('1\n');raise
    print(json.dumps({'complete':str(out/'complete.json'),'scope':'actual L00 only; public input'}),flush=True)

if __name__=='__main__':main()

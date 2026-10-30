"""Bounded, resumable R12b acceptance. All heavy leaves use the shared guard."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT=Path('/home/victor/IntelligenceRegulation')
HERE=Path(__file__).resolve().parent
NATIVE=ROOT/'ops/zkp-mvp/trained-1b'
CARGO=Path('/home/victor/.cargo/bin/cargo')
MANIFEST=NATIVE/'hashline/Cargo.toml'
GUARD=ROOT/'scripts/zk60_resource_guard.py'
TEST=NATIVE/'hashline/target/release/deps/hashline-a876d33e95d2a941'
EXAMPLES=NATIVE/'hashline/target/release/examples'
SOURCE=json.loads((HERE/'source_candidate.json').read_text())

def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as stream:
        while data:=stream.read(1<<20):h.update(data)
    return h.hexdigest()

def check_source():
    for name,want in SOURCE['files'].items():assert sha(NATIVE/name)==want,f'source moved: {name}'

def stage(name,kind,need,cap,command,seconds=900):
    check_source()
    stem=HERE/name
    record=stem.with_suffix('.guard.json')
    done=stem.with_suffix('.done')
    if done.exists():
        data=json.loads(record.read_text())
        assert done.read_text().strip()=='0' and data['exit']==0 and data['child_rc']==0 and not data.get('guard_killed'),name
        print(name,'already passed',flush=True);return
    assert not stem.with_suffix('.command.json').exists(),f'{name}: inspect incomplete prior attempt before retry'
    while (ROOT/'results/zk60_sol_20261026/HOLD').exists():time.sleep(5)
    env=['/usr/bin/env','RAYON_NUM_THREADS=16',f'ZK60_R12_EVIDENCE_DIR={HERE}/dense-receipts',
         f'ZK60_NATIVE_TINY_EXPORT_DIR={HERE}/tiny-exports',f'ZK60_R12B_TIED_FIXTURE={HERE}/tied-fixture']
    cmd=[sys.executable,str(GUARD),'run','--class',kind,'--need-gib',str(need),'--cap-gib',str(cap),
         '--label','sol-r12b-'+name,'--wait-secs','21600','--max-secs',str(seconds),
         '--log',str(stem.with_suffix('.log')),'--done',str(done),'--result-json',str(record),'--',*env,*map(str,command)]
    stem.with_suffix('.command.json').write_text(json.dumps(cmd,indent=2)+'\n')
    rc=subprocess.run(cmd,cwd=ROOT).returncode
    data=json.loads(record.read_text())
    assert rc==0 and data['exit']==0 and data['child_rc']==0 and not data.get('guard_killed'),(name,data)
    print(name,'PASS',data['child_wall_seconds'],'s',data['peak_rss_gib'],'GiB',data['enforcement'],flush=True)

def main():
    final=json.loads((HERE/'build-6.guard.json').read_text())
    assert final['exit']==0 and final['child_rc']==0 and not final.get('guard_killed'),'final test build not passed'
    stage('focused-final','cpu',2,5,[TEST,'private_block::r12','--test-threads=1','--nocapture'])
    stage('source-pins-final','cpu',0.6,1.5,[TEST,'the_capture_writer_pins_every_run_layer_source_it_depends_on','--test-threads=1','--nocapture'])
    stage('tied-final','cpu',0.6,1.5,[TEST,'pinned_tied_tables_accept_honest_and_refuse_rehashed_forgery','--ignored','--test-threads=1','--nocapture'])
    stage('cli-build-final','build',2.3,5,[CARGO,'build','--release','--offline','--locked','-j2','--manifest-path',MANIFEST,'--example','zk60_trained_block','--example','zk60_tied_tables'])
    reference=json.loads((HERE/'reference_tables.json').read_text())
    stage('margin-fixture-final','cpu',0.6,1.5,[EXAMPLES/'zk60_tied_tables',HERE/'tied-fixture',reference['yes'],reference['no'],reference['margin_scale']])
    policy=json.loads((HERE/'policy_margin_reference.json').read_text())
    stage('margin-policy-final','cpu',0.6,1.5,[EXAMPLES/'zk60_tied_tables',HERE/'tied-fixture',policy['yes'],policy['no'],policy['scale']])
    for suffix,expected in [('fixture',reference),('policy',policy)]:
        events=[json.loads(line) for line in (HERE/f'margin-{suffix}-final.log').read_text().splitlines() if line.startswith('{')]
        assert len(events)==1 and events[0]['margin_sha256']==expected['margin_sha256'],suffix
        for key in ['embedding_sha256','head_sha256','multipliers_sha256']:
            assert events[0][key]==reference[key],(suffix,key)
    stage('golden-final','cpu',8,10.5,[TEST,'r12_golden_tests','--ignored','--test-threads=1','--nocapture'])
    stage('dense-final','cpu',8.5,11,[TEST,'f2_a_generic_dense_shieldstral','--ignored','--test-threads=1','--nocapture'])
    stage('fresh-final','cpu',3,6,[TEST,'f2_saved_shieldstral','--ignored','--test-threads=1','--nocapture'])
    for suffix in ['tl','8b','tl-dd','8b-dd']:
        old=json.loads((ROOT/f'results/zk60_sol_20261026/r12-compat-{suffix}.command.json').read_text())
        index=next(i for i,arg in enumerate(old) if str(arg).endswith('zk60_trained_block.release.bin'))
        stage('compat-'+suffix+'-final','cpu',2.5 if suffix.startswith('tl') else 3,8,[EXAMPLES/'zk60_trained_block',*old[index+1:]])
    stage('suite-final','cpu',4.2,8,[CARGO,'test','--release','--offline','--locked','-j2','--manifest-path',MANIFEST,'--','--test-threads=1'],1800)
    check_source()
    (HERE/'ACCEPTANCE_STAGES.done').write_text('0\n')
    print('R12b acceptance stages passed; independent packaging/audit required before freeze delivery.',flush=True)

if __name__=='__main__':
    try:main()
    except BaseException as error:
        (HERE/'acceptance-error.json').write_text(json.dumps({'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'error':str(error)},indent=2)+'\n')
        raise

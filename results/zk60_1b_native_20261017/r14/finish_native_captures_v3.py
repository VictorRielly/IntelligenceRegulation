"""Guarded three-stage native R14 observations and explicit schema6 validation."""
from datetime import datetime,timezone
import hashlib,json,shutil,subprocess,sys,time
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2];TREE=HERE/'capture-working-tree';GUARD=ROOT/'scripts/zk60_resource_guard.py'
BUILD='sol-r14-capture-build-1';TEST='private_block::argument::split_capture_tests::split_capture_t128_three_stage_native_verifier_view_and_rejected_bundle_suppression'
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    assert (HERE/(BUILD+'.validated.done')).read_text().strip()=='0'
    pin=json.loads((HERE/(BUILD+'.source.json')).read_text());checkpoint=HERE/'checkpoints/capture-build-1'
    def check():
        assert sha(GUARD)=='67e9478f55518c2808ff65e5f303f70e155a5f21c5987243a39cf579d1a9a6f3','guard changed'
        for name,want in pin['files'].items():assert sha(TREE/name)==want,name
    check();binary=checkpoint/'hashline.test.bin'
    if not checkpoint.exists():
        for name in pin['files']:
            path=checkpoint/'tree'/name;path.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(TREE/name,path)
        bins=[p for p in (TREE/'hashline/target/release/deps').glob('hashline-*') if p.is_file() and p.stat().st_mode&0o111];assert len(bins)==1
        shutil.copy2(bins[0],binary)
    for name,want in pin['files'].items():assert sha(checkpoint/'tree'/name)==want,name
    assert json.loads((HERE/'NATIVE_CAPTURE_non-dd_VALIDATION_v3.json').read_text())['status'].startswith('PASS native capture')
    binary_sha=sha(binary);records=[{'label':n,'guard':json.loads((HERE/(n+'.guard.json')).read_text())} for n in ['sol-r14-native-capture-non-dd-2','sol-r14-capture-transport-non-dd-v3']]
    assert all(r['guard']['exit']==0 for r in records)
    def run(label,leaf,need,cap):
        command=[sys.executable,str(GUARD),'run','--class','cpu' if need>=3 else 'light','--label',label,'--need-gib',str(need),'--cap-gib',str(cap),
            '--wait-secs','21600','--max-secs','1800','--log',str(HERE/(label+'.log')),'--done',str(HERE/(label+'.done')),
            '--result-json',str(HERE/(label+'.guard.json')),'--',*leaf]
        record=HERE/(label+'.command.json');assert not record.exists();record.write_text(json.dumps({'command':command,'source':pin['tree_sha256'],'binary_sha256':binary_sha,'runner_sha256':sha(Path(__file__))},indent=2)+'\n')
        while True:
            check();assert sha(binary)==binary_sha
            status=json.loads(subprocess.check_output([sys.executable,str(GUARD),'status','--json'],cwd=ROOT,text=True))
            lean=need<3 or all(j['class']!='light' or j['need_gib']<=1 for j in status['live_guarded_jobs'])
            if lean:break  # reviewed guard queues memory/disk/heavy admission without holding locks
            print(datetime.now(timezone.utc).isoformat(),label,'waiting outside heavy lock / lean-memory admission',flush=True);time.sleep(10)
        r=subprocess.run(command,cwd=ROOT);check();assert sha(binary)==binary_sha
        if r.returncode:sys.exit(r.returncode)
        row={'label':label,'guard':json.loads((HERE/(label+'.guard.json')).read_text())};records.append(row);return (HERE/(label+'.log')).read_text()
    for dd in [True]:
        mode='dd' if dd else 'non-dd';directory=HERE/'native-captures'/mode
        label='sol-r14-native-capture-'+mode+'-3'
        log=run(label,['/usr/bin/env','RAYON_NUM_THREADS=2','OPENBLAS_NUM_THREADS=1','HL_R14_DD='+str(int(dd)),
            'HL_R14_CAPTURE_OUTPUT='+str(directory),str(binary),TEST,'--exact','--ignored','--nocapture','--test-threads=1'],8,11)
        assert '1 passed; 0 failed' in log and 'R14_NATIVE_CAPTURE {' in log
        (HERE/(label+'.validated.done')).write_text('0\n')
        record=HERE/('NATIVE_CAPTURE_'+mode+'_VALIDATION_v3.json')
        label='sol-r14-native-capture-'+mode+'-validate-3'
        run(label,['/usr/bin/env','OPENBLAS_NUM_THREADS=1',sys.executable,str(HERE/'validate_capture_v3.py'),str(directory),str(record)],.3,.8)
        validation=json.loads(record.read_text());assert validation['source']==pin['tree_sha256'] and validation['status'].startswith('PASS native capture')
        (HERE/(label+'.validated.done')).write_text('0\n')
    report={'utc':datetime.now(timezone.utc).isoformat(),'source':pin['tree_sha256'],'binary_sha256':binary_sha,'cases':records,
        'scope':'Native three-stage R14 DD/nonDD verifier observers, independent transcript/PCS/M replay, same receipt accepted without recorder, rejected scalar forgery cannot produce bundle, schema/source/array/public allow-list validation. Not a rank/CFS/NL1/joint-view privacy approval.'}
    (HERE/'NATIVE_CAPTURE_ACCEPTANCE.json').write_text(json.dumps(report,indent=2)+'\n');(HERE/'NATIVE_CAPTURE_ACCEPTANCE.done').write_text('0\n')
    print('Native R14 observer/capture gates PASS; rank/CFS/NL1/joint privacy review remains required',flush=True)
if __name__=='__main__':main()

"""Actual public S2 layer native R14 parity/proof/fresh/corruption gates."""
from datetime import datetime,timezone
import hashlib,json,shutil,subprocess,sys,time
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2];TREE=HERE/'actual-working-tree';GUARD=ROOT/'scripts/zk60_resource_guard.py'
BUILD='sol-r14-actual-build-1';STEM='private_block::argument::split_actual_tests::'
EXPORT=HERE.parent/'r13/actual-t128-smoke-export'
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    assert (HERE/(BUILD+'.validated.done')).read_text().strip()=='0'
    pin=json.loads((HERE/(BUILD+'.source.json')).read_text())
    def check():
        for name,want in pin['files'].items():assert sha(TREE/name)==want,name
    check();checkpoint=HERE/'checkpoints/actual-build-1';binary=checkpoint/'hashline.test.bin'
    if not checkpoint.exists():
        for name in pin['files']:
            target=checkpoint/'tree'/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(TREE/name,target)
        bins=[p for p in (TREE/'hashline/target/release/deps').glob('hashline-*') if p.is_file() and p.stat().st_mode&0o111];assert len(bins)==1
        shutil.copy2(bins[0],binary)
    binary_sha=sha(binary);records=[]
    def run(mode,test,proof,env):
        label='sol-r14-actual-'+mode+'-'+('prove' if proof else ('corrupt' if 'corruption' in test else 'fresh'))+'-1'
        need,cap=(9.6,11.5) if proof else (2.5,5)
        check();assert sha(binary)==binary_sha
        command=[sys.executable,str(GUARD),'run','--class','cpu','--label',label,'--need-gib',str(need),'--cap-gib',str(cap),
            '--wait-secs','21600','--max-secs','1800','--log',str(HERE/(label+'.log')),'--done',str(HERE/(label+'.done')),
            '--result-json',str(HERE/(label+'.guard.json')),'--','/usr/bin/env','RAYON_NUM_THREADS=2','OPENBLAS_NUM_THREADS=1',
            'HL_R14_DD='+('1' if mode=='dd' else '0'),'HL_R14_ACTUAL_EXPORT='+str(EXPORT),*[f'{k}={v}' for k,v in env.items()],
            str(binary),STEM+test,'--exact','--ignored','--nocapture','--test-threads=1']
        record=HERE/(label+'.command.json');assert not record.exists(),'do not duplicate recorded stage'
        record.write_text(json.dumps({'command':command,'source':pin['tree_sha256'],'binary_sha256':binary_sha},indent=2)+'\n')
        while True:
            check();status=json.loads(subprocess.check_output([sys.executable,str(GUARD),'status','--json'],cwd=ROOT,text=True))
            lean=need<3 or all(j['class']=='light' and j['need_gib']<=1 for j in status['live_guarded_jobs'])
            r=subprocess.run([sys.executable,str(GUARD),'check','--class','cpu','--need-gib',str(need)],cwd=ROOT,capture_output=True,text=True)
            if lean and r.returncode==0 and 'OK to start now' in r.stdout:break
            print(datetime.now(timezone.utc).isoformat(),label,'waiting outside heavy lock / lean-memory admission',flush=True);time.sleep(10)
        r=subprocess.run(command,cwd=ROOT);check();assert sha(binary)==binary_sha
        if r.returncode:sys.exit(r.returncode)
        log=(HERE/(label+'.log')).read_text();assert '1 passed; 0 failed' in log
        row={'label':label,'source':pin['tree_sha256'],'binary_sha256':binary_sha,'guard':json.loads((HERE/(label+'.guard.json')).read_text())}
        if proof:
            sites=[json.loads(line.split('R14_ACTUAL_TRACE ',1)[1]) for line in log.splitlines() if 'R14_ACTUAL_TRACE ' in line]
            assert len(sites)==19 and len({r['site'] for r in sites})==19
            assert all(s['reference_and_physical_match'] for s in sites)
            results=[json.loads(line.split('R14_ACTUAL_NATIVE_PROOF ',1)[1]) for line in log.splitlines() if 'R14_ACTUAL_NATIVE_PROOF ' in line]
            assert len(results)==1 and results[0]['test_synthetic_waiver'] is False
            row.update(trace_sites=sites,proof=results[0])
        (HERE/(label+'.result.json')).write_text(json.dumps(row,indent=2)+'\n');records.append(row)
        (HERE/(label+'.validated.done')).write_text('0\n');print(label,'PASS',flush=True)
        (HERE/'ACTUAL_CHECKS.progress.json').write_text(json.dumps({'utc':datetime.now(timezone.utc).isoformat(),'cases':records},indent=2)+'\n')
    for mode in ['non-dd','dd']:
        directory=HERE/'actual-native-fixtures'/mode
        run(mode,'split_actual_s2_t128_all19_sites_and_optional_native_proof',True,{'HL_R14_ACTUAL_PROVE':'1','HL_R14_ACTUAL_OUTPUT':str(directory)})
        for name in ['statement.txt','segment0.bin']:assert (directory/name).is_file(),name
        run(mode,'split_actual_s2_t128_fresh_native_verifier',False,{'HL_R14_ACTUAL_INPUT':str(directory)})
        bad=directory.with_name(mode+'-corrupt');assert not bad.exists();shutil.copytree(directory,bad)
        path=bad/'segment0.bin';data=bytearray(path.read_bytes());offset=120+3*32;prime=0xffffffff00000001
        old=int.from_bytes(data[offset:offset+8],'little');assert old<prime
        data[offset:offset+8]=((old+1)%prime).to_bytes(8,'little');path.write_bytes(data)
        (bad/'MUTATION.json').write_text(json.dumps({'kind':'canonical first-slot scalar+1','offset':offset,'same_length':True,'metadata_unchanged':True},indent=2)+'\n')
        assert sha(directory/'statement.txt')==sha(bad/'statement.txt')
        run(mode,'split_actual_s2_t128_fresh_native_corruption_refusal',False,{'HL_R14_ACTUAL_INPUT':str(bad)})
    report={'utc':datetime.now(timezone.utc).isoformat(),'source':pin['tree_sha256'],'binary_sha256':binary_sha,'cases':records,
        'scope':'Actual S2 public weights/calibration at Shieldstral L00/T128, public synthetic input:19independent exact trace-site hashes match reference and physical split witness, strict trained-model native R14 one-stage proof, fresh native verification, canonical scalar corruption rejected. Explicit test synthetic waiver FALSE. Not26block/CLI/classifier/fidelity/privacy acceptance.'}
    (HERE/'ACTUAL_S2_NATIVE_ACCEPTANCE.json').write_text(json.dumps(report,indent=2)+'\n');(HERE/'ACTUAL_S2_NATIVE_ACCEPTANCE.done').write_text('0\n')
    print('Actual S2 native R14 DD/nonDD gates PASS6/0,19sites each',flush=True)
if __name__=='__main__':main()

"""Guarded generic true-support dense R14 proof + independent19-site arithmetic."""
from datetime import datetime,timezone
import hashlib,json,subprocess,sys,time
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2];TREE=HERE/'actual-working-tree';GUARD=ROOT/'scripts/zk60_resource_guard.py'
BUILD='sol-r14-actual-build-2';CHECKPOINT=HERE/'checkpoints/actual-build-2';BINARY=CHECKPOINT/'hashline.test.bin'
TEST='private_block::argument::split_dense_tests::split_generic_dense_t128_native_receipt_and_physical_trace'
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    assert (HERE/(BUILD+'.validated.done')).read_text().strip()=='0'
    pin=json.loads((HERE/(BUILD+'.source.json')).read_text());binary_sha=sha(BINARY)
    def check():
        for name,want in pin['files'].items():
            assert sha(TREE/name)==want,name
            assert sha(CHECKPOINT/'tree'/name)==want,name
        assert sha(BINARY)==binary_sha
    check();records=[]
    def run(label,leaf,need,cap):
        command=[sys.executable,str(GUARD),'run','--class','cpu','--label',label,'--need-gib',str(need),'--cap-gib',str(cap),
            '--wait-secs','21600','--max-secs','1800','--log',str(HERE/(label+'.log')),'--done',str(HERE/(label+'.done')),
            '--result-json',str(HERE/(label+'.guard.json')),'--',*leaf]
        record=HERE/(label+'.command.json');assert not record.exists(),'do not duplicate recorded stage'
        record.write_text(json.dumps({'command':command,'source':pin['tree_sha256'],'binary_sha256':binary_sha},indent=2)+'\n')
        while True:
            check();status=json.loads(subprocess.check_output([sys.executable,str(GUARD),'status','--json'],cwd=ROOT,text=True))
            lean=need<3 or all(j['class']=='light' and j['need_gib']<=1 for j in status['live_guarded_jobs'])
            r=subprocess.run([sys.executable,str(GUARD),'check','--class','cpu','--need-gib',str(need)],cwd=ROOT,capture_output=True,text=True)
            if lean and r.returncode==0 and 'OK to start now' in r.stdout:break
            print(datetime.now(timezone.utc).isoformat(),label,'waiting outside heavy lock / lean-memory admission',flush=True);time.sleep(10)
        result=subprocess.run(command,cwd=ROOT);check()
        if result.returncode:sys.exit(result.returncode)
        return (HERE/(label+'.log')).read_text()
    for dd in [False,True]:
        mode='dd' if dd else 'non-dd';directory=HERE/'generic-dense'/mode
        label='sol-r14-generic-dense-'+mode+'-1'
        log=run(label,['/usr/bin/env','RAYON_NUM_THREADS=2','OPENBLAS_NUM_THREADS=1','HL_R14_DD='+str(int(dd)),
            'HL_R14_DENSE_TRACE_OUTPUT='+str(directory),str(BINARY),TEST,'--exact','--ignored','--nocapture','--test-threads=1'],7.2,10)
        assert '1 passed; 0 failed' in log
        traces=[json.loads(line.split('R14_GENERIC_TRACE ',1)[1]) for line in log.splitlines() if 'R14_GENERIC_TRACE ' in line]
        assert len(traces)==19 and len({r['site'] for r in traces})==19
        receipts=[json.loads(line.split('R14_MALICIOUS_RECEIPT ',1)[1]) for line in log.splitlines() if 'R14_MALICIOUS_RECEIPT ' in line]
        assert len(receipts)==1 and receipts[0]['expected_accept'] and receipts[0]['canonical_frame_decoded'] and receipts[0]['native_verifier_used']
        row={'mode':mode,'traces':traces,'receipt':receipts[0],'guard':json.loads((HERE/(label+'.guard.json')).read_text())}
        records.append(row);(HERE/(label+'.validated.done')).write_text('0\n');print(label,'PASS',flush=True)
        if not dd:
            reference=HERE/'GENERIC_INDEPENDENT_REFERENCE.json'
            label='sol-r14-generic-independent-reference-1'
            run(label,['/usr/bin/env','OPENBLAS_NUM_THREADS=1',sys.executable,str(HERE/'generic_reference.py'),str(directory),str(reference)],1.4,3)
            data=json.loads(reference.read_text());assert data['differences']==0 and len(data['sites'])==19
            (HERE/(label+'.validated.done')).write_text('0\n');print(label,'PASS19sites',flush=True)
    # DD changes the private dictionary packing, not the reference arithmetic.
    # Check its full trace against the independent result without rerunning GEMMs.
    reference=json.loads((HERE/'GENERIC_INDEPENDENT_REFERENCE.json').read_text())
    want={r['site']:r['sha256'] for r in reference['sites']}
    for row in records:
        assert {r['site']:r['sha256'] for r in row['traces']}==want
    report={'utc':datetime.now(timezone.utc).isoformat(),'source':pin['tree_sha256'],'binary_sha256':binary_sha,'cases':records,
        'independent_reference':'GENERIC_INDEPENDENT_REFERENCE.json',
        'scope':'Full true-support signed dense matrices, varying public input, both nonzero score signs and both D/F pieces live. Native DD/nonDD T128 one-stage canonical receipts verify;19physical trace sites match independent exact integer arithmetic. Public synthetic only; no trained-model or privacy acceptance.'}
    (HERE/'GENERIC_DENSE_ACCEPTANCE.json').write_text(json.dumps(report,indent=2)+'\n');(HERE/'GENERIC_DENSE_ACCEPTANCE.done').write_text('0\n')
    print('Generic dense native receipts PASS2/0; independent19sites0differences in both DD variants',flush=True)
if __name__=='__main__':main()

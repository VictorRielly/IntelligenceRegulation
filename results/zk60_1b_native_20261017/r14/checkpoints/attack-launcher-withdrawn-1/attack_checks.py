"""Pinned, guarded complete malicious receipt tests; no routing-only passes."""
from datetime import datetime, timezone
import hashlib, json, shutil, subprocess, sys, time
from pathlib import Path
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
TREE = HERE / 'working-tree'
BUILD = 'sol-r14-run-build-5'
GUARD = ROOT / 'scripts/zk60_resource_guard.py'
TEST = 'private_block::argument::split_attack_tests::split_run_t128_malicious_arithmetic_receipt_from_env'
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    assert (HERE / (BUILD + '.validated.done')).read_text().strip() == '0'
    pin = json.loads((HERE / (BUILD + '.source.json')).read_text())
    def check():
        for name,want in pin['files'].items(): assert sha(TREE/name) == want,name
    check()
    checkpoint = HERE / 'checkpoints/run-build-5'
    binary = checkpoint / 'hashline.test.bin'
    if not checkpoint.exists():
        for name in pin['files']:
            target=checkpoint/'tree'/name;target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(TREE/name,target)
        bins=[p for p in (TREE/'hashline/target/release/deps').glob('hashline-*') if p.is_file() and p.stat().st_mode&0o111]
        assert len(bins)==1
        shutil.copy2(bins[0],binary)
    binary_sha=sha(binary)
    cases=[]
    attacks=['per-piece-round-q','local-c2-ao','one-piece-norm','wrong-omitted-source-bit','missing-public-lift-gate','local-group-reset']
    for dd in [False,True]:
        mode='dd' if dd else 'non-dd'
        for attack in attacks:
            check();assert sha(binary)==binary_sha
            label=f'sol-r14-attack-{mode}-{attack}-1'
            out=HERE/'attack-fixtures'/mode/attack
            need=9 if attack=='local-group-reset' else 7.5
            cap=11.5 if attack=='local-group-reset' else 10
            command=[sys.executable,str(GUARD),'run','--class','cpu','--label',label,'--need-gib',str(need),'--cap-gib',str(cap),
                '--wait-secs','21600','--max-secs','1200','--log',str(HERE/(label+'.log')),'--done',str(HERE/(label+'.done')),
                '--result-json',str(HERE/(label+'.guard.json')),'--','/usr/bin/env','RAYON_NUM_THREADS=2','OPENBLAS_NUM_THREADS=1',
                'HL_R14_ATTACK='+attack,'HL_R14_DD='+str(int(dd)),'HL_R14_ATTACK_OUTPUT='+str(out),
                str(binary),TEST,'--exact','--ignored','--nocapture','--test-threads=1']
            record=HERE/(label+'.command.json');assert not record.exists(),'do not duplicate a recorded stage'
            record.write_text(json.dumps({'command':command,'source':pin['tree_sha256'],'binary_sha256':binary_sha},indent=2)+'\n')
            while True:
                check()
                r=subprocess.run([sys.executable,str(GUARD),'check','--class','cpu','--need-gib',str(need)],cwd=ROOT,capture_output=True,text=True)
                if r.returncode==0 and 'OK to start now' in r.stdout:break
                print(datetime.now(timezone.utc).isoformat(),label,'waiting outside heavy lock',flush=True);time.sleep(10)
            result=subprocess.run(command,cwd=ROOT)
            check();assert sha(binary)==binary_sha
            if result.returncode:sys.exit(result.returncode)
            log=(HERE/(label+'.log')).read_text()
            assert '1 passed; 0 failed' in log and 'R14_ATTACK_REFUSAL '+attack+':' in log
            receipts=[json.loads(line.split('R14_MALICIOUS_RECEIPT ',1)[1]) for line in log.splitlines() if 'R14_MALICIOUS_RECEIPT ' in line]
            assert len(receipts)==(3 if attack=='local-group-reset' else 1)
            assert sum(not r['expected_accept'] for r in receipts)==1
            assert all(r['canonical_frame_decoded'] and r['native_verifier_used'] for r in receipts)
            assert (out/'segment0.bin').stat().st_size==receipts[-1]['bytes']
            row={'label':label,'case':attack,'dd':dd,'receipts':receipts,'receipt_sha256':sha(out/'segment0.bin'),
                'guard':json.loads((HERE/(label+'.guard.json')).read_text())}
            (HERE/(label+'.validated.done')).write_text('0\n');cases.append(row)
            (HERE/'ATTACK_CHECKS.progress.json').write_text(json.dumps({'utc':datetime.now(timezone.utc).isoformat(),
                'source':pin['tree_sha256'],'binary_sha256':binary_sha,'cases':cases},indent=2)+'\n')
            print(label,'PASS',flush=True)
    report={'utc':datetime.now(timezone.utc).isoformat(),'source':pin['tree_sha256'],'binary_sha256':binary_sha,'cases':cases,
        'scope':'DD/nonDD emitted native T128 one-stage R14 receipts: six split-specific attacks, two honest group contexts per DD variant before wrong global-group witness. All native argument/PCS checks remain on; test-only definition faults or ACT host-miss bypass affect prover only. Not trained-model or privacy acceptance.',
        'pending':'additional joint-boundary transcript/commitment controls, actual19site parity/generic dense, old compatibility, actual trained CLI, native captures/rank/NL1, whole-run bound review, freeze/D24/privacy'}
    (HERE/'NATIVE_MALICIOUS_RECEIPTS.json').write_text(json.dumps(report,indent=2)+'\n')
    (HERE/'NATIVE_MALICIOUS_RECEIPTS.done').write_text('0\n')
    print('Native malicious R14 receipts PASS12/0; group-context honest controls PASS4/0',flush=True)
if __name__=='__main__':main()

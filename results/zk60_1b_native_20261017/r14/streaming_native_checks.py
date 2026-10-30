"""Source-pinned C3 controls and native one-block public-cache proof tests."""
from datetime import datetime, timezone
import hashlib, json, subprocess, sys, time
from pathlib import Path
HERE=Path(__file__).resolve().parent; ROOT=HERE.parents[2]
TREE=HERE/'streaming-working-tree'; GUARD=ROOT/'scripts/zk60_resource_guard.py'
BUILD='sol-r14-streaming-build-1'; OUT=HERE/'streaming-native-1'
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    assert not OUT.exists(), 'inspect existing native attempt, never automatically retry'
    assert (HERE/(BUILD+'.validated.done')).read_text().strip()=='0'
    OUT.mkdir();pin=json.loads((HERE/(BUILD+'.source.json')).read_text())
    cp=HERE/'checkpoints/streaming-build-1';binary=cp/'hashline.test.bin';binary_sha=sha(binary)
    def check():
        assert sha(GUARD)=='67e9478f55518c2808ff65e5f303f70e155a5f21c5987243a39cf579d1a9a6f3'
        assert sha(binary)==binary_sha
        for n,w in pin['files'].items():
            assert sha(TREE/n)==sha(cp/'tree'/n)==w,n
    check();records=[]
    for dd in [False,True]:
        mode='dd' if dd else 'non-dd'
        for case in ['wrong-feature-axis','wrong-global-fold-offset','source-prover']:
            name=mode+'-'+case;label='sol-r14-streaming-'+name+'-1'
            if case=='source-prover':
                test='private_block::argument::split_streaming_tests::split_streaming_t128_source_prover_and_both_verifiers'
                env=['HL_R14_STREAM_SOURCE_CONTROLS=1','HL_R14_RUN_OUTPUT='+str(OUT/name)]
            else:
                test='private_block::argument::split_attack_tests::split_run_t128_malicious_arithmetic_receipt_from_env'
                env=['HL_R14_ATTACK='+case,'HL_R14_ATTACK_OUTPUT='+str(OUT/name)]
            command=[sys.executable,str(GUARD),'run','--class','cpu','--label',label,'--need-gib','8','--cap-gib','10.5',
                     '--wait-secs','7200','--max-secs','1800','--log',str(OUT/(name+'.log')),'--done',str(OUT/(name+'.done')),
                     '--result-json',str(OUT/(name+'.guard.json')),'--','/usr/bin/env','RAYON_NUM_THREADS=8','OPENBLAS_NUM_THREADS=1',
                     'HL_R14_DD='+str(int(dd)),*env,str(binary),test,'--exact','--ignored','--nocapture','--test-threads=1']
            path=OUT/(name+'.command.json');assert not path.exists()
            path.write_text(json.dumps({'command':command,'source':pin['tree_sha256'],'binary_sha256':binary_sha,'runner_sha256':sha(Path(__file__))},indent=2)+'\n')
            while True:
                check();status=json.loads(subprocess.check_output([sys.executable,str(GUARD),'status','--json'],cwd=ROOT,text=True))
                if all(j['class']!='light' or j['need_gib']<=1 for j in status['live_guarded_jobs']) and not (HERE/'HOLD').exists() and not (HERE.parent/'HOLD').exists():break
                print(datetime.now(timezone.utc).isoformat(),name,'waiting for light budget/hold',flush=True);time.sleep(10)
            result=subprocess.run(command,cwd=ROOT);check()
            if result.returncode:sys.exit(result.returncode)
            log=(OUT/(name+'.log')).read_text();assert '1 passed; 0 failed' in log
            if case=='source-prover':
                assert 'R14_STREAM_SOURCE_PROVE stages=2 peak_owned_public_blocks=1' in log
                assert 'R14_STREAM_SOURCE_VERIFY stages=2 peak_owned_public_blocks=1 reload_changes_refused=2' in log
                assert all((OUT/name/f'segment{k}.bin').is_file() for k in range(2))
            else:
                assert 'R14_ATTACK_REFUSAL '+case+':' in log
                receipts=[json.loads(l.split('R14_MALICIOUS_RECEIPT ',1)[1]) for l in log.splitlines() if 'R14_MALICIOUS_RECEIPT ' in l]
                assert len(receipts)==1 and receipts[0]['expected_accept'] is False
                assert receipts[0]['canonical_frame_decoded'] and receipts[0]['native_verifier_used']
                assert (OUT/name/'segment0.bin').stat().st_size==receipts[0]['bytes']
            row={'case':name,'guard':json.loads((OUT/(name+'.guard.json')).read_text()),'log_sha256':sha(OUT/(name+'.log'))}
            records.append(row);(OUT/(name+'.validated.done')).write_text('0\n')
            (OUT/'progress.json').write_text(json.dumps({'source':pin['tree_sha256'],'cases':records},indent=2)+'\n')
            print(name,'PASS',flush=True)
    (OUT/'ACCEPTANCE.json').write_text(json.dumps({'utc':datetime.now(timezone.utc).isoformat(),'source':pin['tree_sha256'],'binary_sha256':binary_sha,'cases':records,
        'scope':'Four emitted C3 feature-axis/global-fold-offset malformed receipts reject; two native2block source-based proofs verify with resident and one-owned-block-cache verifiers, and post-preflight replacement refuses at both stages. Public synthetic only; original fixture remains resident, so cache count is not whole-model RSS. Not CLI/full26/privacy acceptance.'},indent=2)+'\n')
    (OUT/'done').write_text('0\n')
if __name__=='__main__':main()

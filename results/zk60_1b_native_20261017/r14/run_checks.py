"""Pinned serial native R14 stream gates; all CPU work uses the common guard."""
from datetime import datetime,timezone
import hashlib,json,shutil,subprocess,sys,time
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2];TREE=HERE/'working-tree';GUARD=ROOT/'scripts/zk60_resource_guard.py'
BUILD='sol-r14-run-build-3';STEM='private_block::argument::split_run_tests::'

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    assert (HERE/(BUILD+'.validated.done')).read_text().strip()=='0'
    pin=json.loads((HERE/(BUILD+'.source.json')).read_text())
    def check():
        for name,want in pin['files'].items():assert sha(TREE/name)==want,name
    check();checkpoint=HERE/'checkpoints/run-build-3';binary=checkpoint/'hashline.test.bin'
    if not checkpoint.exists():
        for name in pin['files']:
            target=checkpoint/'tree'/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(TREE/name,target)
        bins=[p for p in (TREE/'hashline/target/release/deps').glob('hashline-*') if p.is_file() and p.stat().st_mode&0o111];assert len(bins)==1
        shutil.copy2(bins[0],binary)
    binary_sha=sha(binary);cases=[]
    def run(label,test,need,cap,env):
        check();assert sha(binary)==binary_sha
        command=[sys.executable,str(GUARD),'run','--class','cpu','--label',label,'--need-gib',str(need),'--cap-gib',str(cap),'--wait-secs','21600','--max-secs','1800',
            '--log',str(HERE/(label+'.log')),'--done',str(HERE/(label+'.done')),'--result-json',str(HERE/(label+'.guard.json')),'--',
            '/usr/bin/env','RAYON_NUM_THREADS=2','OPENBLAS_NUM_THREADS=1',*[f'{k}={v}' for k,v in env.items()],str(binary),STEM+test,'--exact','--ignored','--nocapture','--test-threads=1']
        record=HERE/(label+'.command.json');done=HERE/(label+'.done')
        if record.exists():
            saved=json.loads(record.read_text());assert saved['source']==pin['tree_sha256'] and saved['binary_sha256']==binary_sha
            assert done.exists(),'existing nonterminal stage: poll original tool/guard, do not duplicate'
            assert done.read_text().strip()=='0','prior failure requires diagnosis/new attempt, not an automatic retry'
        else:
            record.write_text(json.dumps({'command':command,'source':pin['tree_sha256'],'binary_sha256':binary_sha},indent=2)+'\n')
            while True:
                check();assert sha(binary)==binary_sha
                r=subprocess.run([sys.executable,str(GUARD),'check','--class','cpu','--need-gib',str(need)],cwd=ROOT,capture_output=True,text=True)
                if r.returncode==0 and 'OK to start now' in r.stdout:break
                print(datetime.now(timezone.utc).isoformat(),label,'waiting outside heavy lock',flush=True);time.sleep(10)
            result=subprocess.run(command,cwd=ROOT)
            if result.returncode:sys.exit(result.returncode)
        check();assert sha(binary)==binary_sha
        log=(HERE/(label+'.log')).read_text();assert '1 passed; 0 failed' in log,label
        (HERE/(label+'.validated.done')).write_text('0\n');cases.append({'label':label,'test':test,'guard':json.loads((HERE/(label+'.guard.json')).read_text())})
        print(label,'PASS',flush=True)
        (HERE/'RUN_CHECKS.progress.json').write_text(json.dumps({'utc':datetime.now(timezone.utc).isoformat(),'source':pin['tree_sha256'],'binary_sha256':binary_sha,'completed':cases},indent=2)+'\n')
    artifacts=HERE/'stream-fixtures';artifacts.mkdir(exist_ok=True)
    for mode in ['non-dd','dd']:
        code=mode.replace('-','_');out=artifacts/mode
        run('sol-r14-stream-'+mode+'-1','split_run_t128_'+code+'_serialized_two_blocks_with_own_calibration_verify',9.5,11.5,{'HL_R14_RUN_OUTPUT':str(out)})
        for name in ['statement.txt','segment0.bin','segment1.bin']:assert (out/name).is_file(),name
        run('sol-r14-stream-'+mode+'-fresh-1','split_run_t128_'+code+'_fresh_verify_from_dir',2.5,4.5,{'HL_R14_RUN_INPUT':str(out)})
        bad=artifacts/(mode+'-corrupt')
        if not bad.exists():
            shutil.copytree(out,bad);path=bad/'segment0.bin';data=bytearray(path.read_bytes());offset=120+32+3*32
            prime=0xffffffff00000001;old=int.from_bytes(data[offset:offset+8],'little');assert old<prime
            data[offset:offset+8]=((old+1)%prime).to_bytes(8,'little');path.write_bytes(data)
            (bad/'MUTATION.json').write_text(json.dumps({'kind':'canonical first-slot scalar+1','offset':offset,'same_length':True,'same_header_and_metadata':True,'source':pin['tree_sha256']},indent=2)+'\n')
        assert sha(bad/'statement.txt')==sha(out/'statement.txt')
        run('sol-r14-stream-'+mode+'-corrupt-fresh-1','split_run_t128_'+code+'_fresh_rejects_corrupt_stream',2.5,4.5,{'HL_R14_RUN_INPUT':str(bad)})
        run('sol-r14-stream-'+mode+'-boundary-forgery-1','split_run_t128_'+code+'_narrow_boundary_forgery_emits_and_refuses',9.5,11.5,{})
    report={'utc':datetime.now(timezone.utc).isoformat(),'source':pin['tree_sha256'],'binary_sha256':binary_sha,'cases':cases,
        'scope':'DD/nonDD T128 two-block native R14 run/segment path, different layer calibration, fresh-process honest verifier, canonical scalar corruption refused at native round0, emitted narrow-boundary mutation refused at physical30 IO constraint. Public synthetic model with explicit native test-only waiver; not CLI/approved trained model/privacy acceptance.',
        'pending':'remaining mandated rounding/c2/group/norm/inner-piece attacks, all19site parity/generic dense, old compatibility, actual trained import/CLI, whole-run bits, native capture/rank/NL1, freeze/D24/privacy'}
    (HERE/'NATIVE_STREAM_ACCEPTANCE.json').write_text(json.dumps(report,indent=2)+'\n');(HERE/'NATIVE_STREAM_ACCEPTANCE.done').write_text('0\n')
    print('R14 native stream component gates PASS8/0',flush=True)
if __name__=='__main__':main()

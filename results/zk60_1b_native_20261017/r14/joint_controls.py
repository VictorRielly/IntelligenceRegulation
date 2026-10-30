"""Fresh native verifier controls on retained complete R14 two-stage receipts.

Expected child101 is a negative-test harness unwrap; success here requires the
precise intended native root/PCS/SC refusal, never merely any test failure.
"""
from datetime import datetime,timezone
import hashlib,json,shutil,subprocess,sys,time
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2];GUARD=ROOT/'scripts/zk60_resource_guard.py'
BUILD='sol-r14-run-build-4';CHECKPOINT=HERE/'checkpoints/run-build-4';BINARY=CHECKPOINT/'hashline.test.bin'
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    pin=json.loads((HERE/(BUILD+'.source.json')).read_text());binary_sha=sha(BINARY)
    def check():
        for name,want in pin['files'].items():assert sha(CHECKPOINT/'tree'/name)==want,name
        assert sha(BINARY)==binary_sha
    check();native=json.loads((HERE/'NATIVE_BUILDERS_CENSUS.json').read_text());cases=[]
    for dd in [False,True]:
        mode='dd' if dd else 'non-dd';source=HERE/'stream-fixtures'/mode
        frames=[(source/f'segment{k}.bin').read_bytes() for k in range(2)]
        metadata=dict(line.split('=',1) for line in (source/'statement.txt').read_text().splitlines()[1:])
        endpoint=bytes.fromhex(metadata['input_root'])
        profile=('hashline-zk-mr1/private-block-shieldstral-3b-t128-lowh24-'+('ddict1' if dd else 'blocks')+'/1')
        shape=next(r for r in native['inventory'] if r['base_profile']==profile and r['f_e']==9)
        groups=next(r for r in native['groups'] if r['base']==profile)
        n=shape['n'];q=256;path=16
        def opening(g,r):return (g+1)*(n+q)*16+q*(8+r*8+32+path*32)
        slots=[r for r in native['slot_definitions'] if r['base']==profile]
        slot_bytes=sum((1+(s['main']+s['ext'])*(s['degree']+1)+s['terminals'])*16 for s in slots)
        mask_bytes=2*1024*16+q*(8+shape['m_rows']*8+32+12*32)
        incoming=120+96+slot_bytes+mask_bytes+opening(groups['a_groups'],shape['a_rows'])+opening(groups['h_groups'],shape['h_rows'])
        assert len(frames[1])==incoming+opening(4,shape['joint_internal_rows'])+opening(2,shape['joint_external_rows'])+32
        vector=(n+q)*16
        controls=[
            ('a-h-same-root',0,184,frames[0][152:184],'repeated commitment root'),
            ('a-m-same-root',0,216,frames[0][152:184],'repeated commitment root'),
            ('boundary-input-same-root',0,120,endpoint,'repeated commitment root'),
            ('cross-stage-a-root',1,120,frames[0][152:184],'repeated commitment root'),
            ('cross-stage-h-root',1,152,frames[0][216:248],'repeated commitment root'),
            ('cross-stage-m-root',1,184,frames[0][120:152],'repeated commitment root'),
            ('boundary-piece0-reused-for-piece1',1,incoming+vector,frames[1][incoming:incoming+vector],'pcs zk: group'),
            ('boundary-piece2-reused-for-piece3',1,incoming+3*vector,frames[1][incoming+2*vector:incoming+3*vector],'pcs zk: group'),
        ]
        other=(HERE/'matched-r14'/mode/'segment1.bin').read_bytes()
        assert len(other)==len(frames[1]) and other[8:40]!=frames[1][8:40]
        controls.extend([
            ('cross-run-next-frame',1,0,other,'another run binding'),
            ('cross-run-reheadered-next-frame',1,0,frames[1][:120]+other[120:],'sumcheck round'),
        ])
        for name,stage,offset,replacement,expected in controls:
            label=f'sol-r14-joint-{mode}-{name}-1';directory=HERE/'joint-controls'/mode/name
            assert not directory.exists();directory.mkdir(parents=True)
            shutil.copy2(source/'statement.txt',directory/'statement.txt')
            changed=[bytearray(v) for v in frames]
            changed[stage][offset:offset+len(replacement)]=replacement
            assert [len(v) for v in changed]==[len(v) for v in frames]
            assert changed[0][:120]==frames[0][:120] and changed[1][:120]==(other[:120] if name=='cross-run-next-frame' else frames[1][:120])
            for k,data in enumerate(changed):(directory/f'segment{k}.bin').write_bytes(data)
            (directory/'MUTATION.json').write_text(json.dumps({'case':name,'stage':stage,'offset':offset,
                'bytes_changed_region':len(replacement),'same_frame_lengths':True,'metadata_unchanged':True,
                'expected_refusal':expected,'source':pin['tree_sha256']},indent=2)+'\n')
            test='private_block::argument::split_run_tests::split_run_t128_'+mode.replace('-','_')+'_fresh_verify_from_dir'
            command=[sys.executable,str(GUARD),'run','--class','light','--label',label,'--need-gib','0.65','--cap-gib','1.5',
                '--wait-secs','21600','--max-secs','300','--log',str(HERE/(label+'.log')),'--done',str(HERE/(label+'.done')),
                '--result-json',str(HERE/(label+'.guard.json')),'--','/usr/bin/env','RAYON_NUM_THREADS=2','OPENBLAS_NUM_THREADS=1',
                'HL_R14_RUN_INPUT='+str(directory),str(BINARY),test,'--exact','--ignored','--nocapture','--test-threads=1']
            record=HERE/(label+'.command.json');assert not record.exists()
            record.write_text(json.dumps({'command':command,'source':pin['tree_sha256'],'binary_sha256':binary_sha,
                'expected_child_exit':101,'expected_native_error':expected},indent=2)+'\n')
            check();result=subprocess.run(command,cwd=ROOT);check()
            log=(HERE/(label+'.log')).read_text()
            assert result.returncode==101 and '0 passed; 1 failed' in log and expected in log,(name,result.returncode,log[-2000:])
            guard=json.loads((HERE/(label+'.guard.json')).read_text())
            assert guard['child_rc']==101 and guard['guard_killed'] is None and guard['guard_error'] is None
            cases.append({'label':label,'case':name,'dd':dd,'expected_exit':101,'observed_native_error':expected,
                'metadata_sha256':sha(directory/'statement.txt'),'mutant_frame_sha256':sha(directory/f'segment{stage}.bin'),'guard':guard})
            (HERE/(label+'.validated.done')).write_text('0\n')
            (HERE/'JOINT_CONTROLS.progress.json').write_text(json.dumps({'utc':datetime.now(timezone.utc).isoformat(),'cases':cases},indent=2)+'\n')
            print(label,'PASS expected native refusal',flush=True)
    report={'utc':datetime.now(timezone.utc).isoformat(),'source':pin['tree_sha256'],'binary_sha256':binary_sha,'cases':cases,
        'scope':'20fresh-process controls on previously verified complete native two-stage R14 public synthetic receipts. Six repeated-root roles, two reused joint-boundary piece group-vectors, cross-run binding and reheadered cross-run native SC refusal, for each DD variant. Expected101 is explicit negative-harness panic with required specific native error, not a passing Rust test.',
        'pending':'author controls only; no independent soundness/privacy acceptance; rank/CFS/NL1/joint-view captures still owed'}
    (HERE/'NATIVE_JOINT_CONTROLS.json').write_text(json.dumps(report,indent=2)+'\n');(HERE/'NATIVE_JOINT_CONTROLS.done').write_text('0\n')
    print('Native joint/root fresh controls PASS20/0',flush=True)
if __name__=='__main__':main()

"""R14 candidate's full legacy suite, seeded byte goldens and retained receipts.

This checks the legacy dispatch after the argument driver refactor. It does
not register R14 or expose an R14 release CLI. All heavy leaves use the guard.
"""
from datetime import datetime,timezone
import hashlib,json,re,shutil,subprocess,sys,time
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2];OLD=HERE.parent/'r13'
TREE=HERE/'compatibility-working-tree';GUARD=ROOT/'scripts/zk60_resource_guard.py'
BUILD='sol-r14-legacy-full-suite-3';CARGO='/home/victor/.cargo/bin/cargo'
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    pin=json.loads((HERE/(BUILD+'.source.json')).read_text())
    def check():
        assert sha(GUARD)=='67e9478f55518c2808ff65e5f303f70e155a5f21c5987243a39cf579d1a9a6f3','guard changed'
        for name,want in pin['files'].items():assert sha(TREE/name)==want,name
    check();checkpoint=HERE/'checkpoints/compatibility-suite-3';binary=checkpoint/'hashline.test.bin'
    binary_sha=None;records=[]
    def run(label,leaf,job_class,need,cap,limit=1800):
        check();assert binary_sha is None or sha(binary)==binary_sha
        command=[sys.executable,str(GUARD),'run','--class',job_class,'--label',label,'--need-gib',str(need),'--cap-gib',str(cap),
            '--wait-secs','21600','--max-secs',str(limit),'--log',str(HERE/(label+'.log')),'--done',str(HERE/(label+'.done')),
            '--result-json',str(HERE/(label+'.guard.json')),'--',*leaf]
        record=HERE/(label+'.command.json');assert not record.exists(),'do not duplicate recorded stage'
        record.write_text(json.dumps({'command':command,'source':pin['tree_sha256'],'test_binary_sha256':binary_sha,'runner_sha256':sha(Path(__file__))},indent=2)+'\n')
        while True:
            check();status=json.loads(subprocess.check_output([sys.executable,str(GUARD),'status','--json'],cwd=ROOT,text=True))
            lean=need<3 or all(j['class']!='light' or j['need_gib']<=1 for j in status['live_guarded_jobs'])
            holds=(HERE/'HOLD').exists() or (HERE.parent/'HOLD').exists()
            if lean and not holds:break  # reviewed admission-before-lock guard
            print(datetime.now(timezone.utc).isoformat(),label,'waiting outside heavy lock / lean admission',flush=True);time.sleep(10)
        r=subprocess.run(command,cwd=ROOT);check();assert binary_sha is None or sha(binary)==binary_sha
        if r.returncode:sys.exit(r.returncode)
        log=(HERE/(label+'.log')).read_text()
        row={'label':label,'guard':json.loads((HERE/(label+'.guard.json')).read_text())};return log,row
    def finish(log,row,**facts):
        row.update(facts);records.append(row)
        (HERE/(row['label']+'.result.json')).write_text(json.dumps(row,indent=2)+'\n')
        (HERE/(row['label']+'.validated.done')).write_text('0\n');print(row['label'],'PASS',flush=True)
    env=['/usr/bin/env','RAYON_NUM_THREADS=2','OPENBLAS_NUM_THREADS=1',
        'ZK60_R12_EVIDENCE_DIR='+str(HERE/'compatibility/attempt3/generated-r12-receipts'),
        'ZK60_NATIVE_TINY_EXPORT_DIR='+str(HERE/'compatibility/attempt3/generated-tiny-exports')]
    manifest=['--release','--offline','--locked','-j2','--manifest-path',str(TREE/'hashline/Cargo.toml')]
    # Adopt the already successful leaf only after comparing every baseline
    # test name/status/multiplicity, rather than repeating a passing suite.
    from validate_suite_census import validate
    label='sol-r14-legacy-full-suite-3'
    assert (HERE/(label+'.done')).read_text().strip()=='0'
    guard=json.loads((HERE/(label+'.guard.json')).read_text())
    assert guard['exit']==guard['child_rc']==0 and not guard['refused'] and not guard['guard_killed']
    command=json.loads((HERE/(label+'.command.json')).read_text())
    assert command['source']==pin['tree_sha256']
    check();log=(HERE/(label+'.log')).read_text()
    census=validate(HERE/(label+'.log'),OLD/'release-2-suite.log')
    row={'label':label,'guard':guard,'adopted_successful_leaf':True,
         'census_checker_sha256':sha(HERE/'validate_suite_census.py')}
    finish(log,row,**census)
    for name in pin['files']:
        path=checkpoint/'tree'/name;path.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(TREE/name,path)
    match=re.search(r'Running unittests src/lib\.rs \(([^\n]+)\)',log);assert match
    compiled=Path(match.group(1));compiled=compiled if compiled.is_absolute() else ROOT/compiled
    assert compiled.is_file();shutil.copy2(compiled,binary);binary_sha=sha(binary)
    (HERE/(BUILD+'.validated.done')).write_text('0\n')
    log,row=run('sol-r14-legacy-goldens-4',[*env,str(binary),'r12_golden_tests','--ignored','--test-threads=1','--nocapture'],'cpu',8,10.5)
    assert '5 passed; 0 failed' in log;finish(log,row,seeded_block_byte_goldens=4,statement_identity_goldens=1)
    log,row=run('sol-r14-legacy-cli-build-4',[*env,CARGO,'build',*manifest,'--example','zk60_trained_block'],'build',2.6,5)
    cli=TREE/'hashline/target/release/examples/zk60_trained_block';assert cli.is_file()
    pinned_cli=checkpoint/'zk60_trained_block.legacy-cli.bin';assert not pinned_cli.exists();shutil.copy2(cli,pinned_cli)
    cli_sha=sha(pinned_cli);finish(log,row,cli_sha256=cli_sha)
    # Use only the already verified legacy commands' read-only verification
    # arguments. Never promote or rewrite an old statement directory.
    names=['compat-tl','compat-tl-dd','compat-8b','compat-8b-dd']
    names += ['cli-verify-'+f'{fixture}-{mode}' for fixture in ['r13-low-dense','r13-h24-wide'] for mode in ['plain','dd']]
    for name in names:
        previous=OLD/('release-2-'+name+'.command.json');old=json.loads(previous.read_text())
        ix=next(i for i,v in enumerate(old) if Path(v).name=='zk60_trained_block')
        args=old[ix+1:];assert args[0] in ['verify','stack-verify'] and '--promote' not in args
        assert '--expect-statement' in args and '--artifact' in args
        want=args[args.index('--expect-statement')+1]
        assert sha(pinned_cli)==cli_sha
        log,row=run('sol-r14-legacy-'+name+'-4',['/usr/bin/env','RAYON_NUM_THREADS=2','OPENBLAS_NUM_THREADS=1',str(pinned_cli),*args],'cpu',2.5,5,900)
        assert sha(pinned_cli)==cli_sha
        events=[json.loads(line) for line in log.splitlines() if line.startswith('{')]
        verified=[e for e in events if e.get('event')=='verified'];assert len(verified)==1 and verified[0]['statement_identity']==want
        if args[0]=='stack-verify':assert sum(e.get('event')=='statement-checked' for e in events)==1
        finish(log,row,cli_sha256=cli_sha,statement_identity=want,verified=verified[0],prior_command_sha256=sha(previous))
    log,row=run('sol-r14-legacy-r12-shield-4',['/usr/bin/env','RAYON_NUM_THREADS=2',
        'ZK60_R12_EVIDENCE_DIR='+str(HERE.parent/'r12b/dense-receipts'),str(binary),'f2_saved_shieldstral','--ignored','--test-threads=1','--nocapture'],'light',1,2,180)
    assert '1 passed; 0 failed' in log;finish(log,row,retained_R12_Shieldstral_receipt=True)
    report={'utc':datetime.now(timezone.utc).isoformat(),'source':pin['tree_sha256'],'test_binary_sha256':binary_sha,
        'legacy_cli_sha256':cli_sha,'cases':records,'preserved_failed_attempts':['sol-r14-legacy-full-suite-1','sol-r14-legacy-full-suite-2'],'count_wrapper_failure':'WRAPPER3_COUNT_FAILURE.json',
        'scope':'Full legacy Rust suite, four seeded pre-R14 receipt byte goldens and statement identities, fresh retained TinyLlama/8B R8/R9 and R13 Low/H24 DD/nonDD receipts, retained R12 Shieldstral receipt. Legacy dispatch remains compatible after the shared argument driver refactor. No R14 CLI registration/trained26layer/privacy acceptance.'}
    (HERE/'LEGACY_COMPATIBILITY_ACCEPTANCE.json').write_text(json.dumps(report,indent=2)+'\n')
    (HERE/'LEGACY_COMPATIBILITY_ACCEPTANCE.done').write_text('0\n');print('R14 candidate legacy compatibility gates PASS',flush=True)
if __name__=='__main__':main()

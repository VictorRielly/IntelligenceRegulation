"""Continue the pinned independent branch after the existing candidate batch.

This orchestrator is small; child scripts guard their own leaves. No duplicate
builds, automatic retries, source edits, registration or privacy approval.
"""
from datetime import datetime,timezone
import hashlib,json,subprocess,sys,time
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2];GUARD=ROOT/'scripts/zk60_resource_guard.py'
LABEL='sol-r14-observer-pipeline-1';BUILD='sol-r14-capture-build-1'
GUARD_SHA='88af4c639848d39df8da559652db11529575aa745b916a06eb522c20ea89fbd3'
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    pin=json.loads((HERE/(BUILD+'.source.json')).read_text())
    runners=['capture_gate.py','capture_checks.py','validate_capture.py','local_row_rank.py','actual_l25_checks.py','regression_checks.py','compatibility_checks.py']
    script_pins={name:sha(HERE/name) for name in runners}
    def check():
        assert sha(GUARD)==GUARD_SHA,'reviewed guard changed'
        assert json.loads((HERE/(BUILD+'.source.json')).read_text())==pin,'capture source pin changed'
        for name,want in pin['files'].items():assert sha(HERE/'capture-working-tree'/name)==want,name
        for name,want in script_pins.items():assert sha(HERE/name)==want,name
    check();plan=HERE/(LABEL+'.plan.json');assert not plan.exists(),'poll existing pipeline; never duplicate'
    plan.write_text(json.dumps({'utc':datetime.now(timezone.utc).isoformat(),'source':pin['tree_sha256'],'files':pin['count'],
        'guard_sha256':GUARD_SHA,'scripts':script_pins,'dependency':'CANDIDATE_ACCEPTANCE_BATCH.done=0 from existing original24662',
        'order':['capture build','three-stage captures/transport validation','limited local row precheck','actualL25gates','50relation regressions','legacy compatibility'],
        'source_edits_held':True,'scope':'Uncompiled observer branch is now queued and held. No native capture/acceptance/privacy result follows from this plan.'},indent=2)+'\n')
    records=[]
    def progress(phase):
        (HERE/(LABEL+'.progress.json')).write_text(json.dumps({'utc':datetime.now(timezone.utc).isoformat(),'phase':phase,
            'source':pin['tree_sha256'],'records':records},indent=2)+'\n')
    progress('waiting for existing candidate batch; no heavy leaf launched')
    deadline=time.monotonic()+21600;last_notice=0
    while not (HERE/'CANDIDATE_ACCEPTANCE_BATCH.done').exists():
        check();assert time.monotonic()<deadline,'dependency wait limit; inspect original handles'
        paths=[HERE/'sol-r14-actual-build-2.done']
        paths.extend(HERE.glob('sol-r14-attack-*-3.done'))
        paths.extend(HERE.glob('sol-r14-generic-*-1.done'))
        for path in paths:
            if path.exists():assert path.read_text().strip()=='0',f'existing candidate stage failed: {path.name}'
        if time.monotonic()-last_notice>=60:
            print(datetime.now(timezone.utc).isoformat(),'observer pipeline waits for original candidate batch',flush=True);last_notice=time.monotonic()
        time.sleep(10)
    assert (HERE/'CANDIDATE_ACCEPTANCE_BATCH.done').read_text().strip()=='0'
    candidate=json.loads((HERE/'CANDIDATE_ACCEPTANCE_BATCH.json').read_text())
    assert candidate['source']=='7152ef1a269b2aca5b0ec7ee507a8591db46225466653aaa3113789bfce24262'
    stages=[('capture build','capture_gate.py'),('native capture gates','capture_checks.py')]
    def script_stage(phase,script):
        check();progress(phase);r=subprocess.run([sys.executable,str(HERE/script)],cwd=ROOT);check()
        records.append({'phase':phase,'exit':r.returncode});progress(phase+' terminal')
        if r.returncode:raise RuntimeError(f'{phase} failed ({r.returncode}); retained artifacts, no retry')
    for phase,script in stages:script_stage(phase,script)
    assert (HERE/'NATIVE_CAPTURE_ACCEPTANCE.done').read_text().strip()=='0'
    # This is deliberately labelled a local precheck, never full P1/privacy.
    for mode in ['non-dd','dd']:
        check();label='sol-r14-local-row-precheck-'+mode+'-1';out=HERE/('LOCAL_ROW_PRECHECK_'+mode+'.json')
        command=[sys.executable,str(GUARD),'run','--class','light','--label',label,'--need-gib','.8','--cap-gib','1.5',
            '--wait-secs','21600','--max-secs','1800','--log',str(HERE/(label+'.log')),'--done',str(HERE/(label+'.done')),
            '--result-json',str(HERE/(label+'.guard.json')),'--','/usr/bin/env','OPENBLAS_NUM_THREADS=1',sys.executable,
            str(HERE/'local_row_rank.py'),str(HERE/'native-captures'/mode),str(out)]
        record=HERE/(label+'.command.json');assert not record.exists();record.write_text(json.dumps(command,indent=2)+'\n')
        progress('limited local row precheck '+mode);r=subprocess.run(command,cwd=ROOT);check()
        if r.returncode:raise RuntimeError(f'{label} failed ({r.returncode}); no retry')
        report=json.loads(out.read_text());assert report['privacy_acceptance'] is False and len(report['roles'])==10
        (HERE/(label+'.validated.done')).write_text('0\n');records.append({'phase':'limited local row precheck '+mode,'exit':0,'privacy_acceptance':False})
    for phase,script in [('actualL25gates','actual_l25_checks.py'),('relation regressions','regression_checks.py'),('legacy compatibility','compatibility_checks.py')]:script_stage(phase,script)
    progress('prepared native validation chain complete; full privacy/CLIintegration/reviews still owed')
    (HERE/(LABEL+'.done')).write_text('0\n');print('Observer/actualL25/regression/legacy chain complete; no full privacy acceptance',flush=True)
if __name__=='__main__':
    try:main()
    except Exception as error:
        (HERE/(LABEL+'.failure.json')).write_text(json.dumps({'utc':datetime.now(timezone.utc).isoformat(),'error':str(error),'retry':False},indent=2)+'\n')
        (HERE/(LABEL+'.done')).write_text('1\n');raise

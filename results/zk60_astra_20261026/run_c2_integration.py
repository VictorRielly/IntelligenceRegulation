"""Exercise the app adapter with the frozen synthetic R-C2 CLI and attacks.

Each native leaf uses the app's resource guard and HOLD checks. This is not
Shieldstral, product policy selection, or classifier/privacy review acceptance.
"""
import argparse
from dataclasses import asdict, replace
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import struct
import subprocess
import sys

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];APP=ROOT/'apps/proven-media'
sys.path.insert(0,str(APP))
from proven_media.classifier_cli import ClassifierCLI,Deployment,DEV_POLICY,R_C2_BINARY_SHA256,R_C2_SCHEMA,chunk_plan,one_event,require
from proven_media.classifier_prover import RungClassifierProver,RungTokenItem,PIPELINE
from proven_media.provers import ProverError,write_private

spec=importlib.util.spec_from_file_location('c2_app_worker',PIPELINE)
worker=importlib.util.module_from_spec(spec);spec.loader.exec_module(worker)
FIX=HERE/'classifier_c2_fixture'

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,obj):p.write_text(json.dumps(obj,indent=2)+'\n')

def pipeline(job):
    rc=subprocess.run([sys.executable,str(PIPELINE),str(job)]).returncode
    require(rc==0,'native app pipeline failed at '+job.name)

def attack(job,command,cli,reason):
    job.mkdir(mode=0o700);(job/'logs').mkdir(mode=0o700)
    try: worker.run_step(job,'verify',command,cli)
    except ProverError: pass
    else: raise AssertionError('forgery unexpectedly passed native verification')
    guard=json.loads((job/'logs/verify.guard.json').read_text())
    require(guard['exit']==1 and guard['child_rc']==1 and not guard['guard_killed'],'attack failed for an unrelated guard reason')
    events=[json.loads(line) for line in (job/'logs/verify.log').read_text().splitlines() if line.startswith('{')]
    refusals=[event for event in events if event.get('event')=='refused']
    require(len(refusals)==1 and not any(event.get('event')=='classified' for event in events),'attack was not a clean native refusal')
    require(reason in json.dumps(refusals[0]),'unexpected refusal reason')
    return {'guard':{k:guard[k] for k in ('exit','child_rc','peak_rss_gib')},'refusal':refusals[0]}

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--attempt',type=int,required=True);args=parser.parse_args()
    require(args.attempt>0 and not any(p.exists() for p in worker.HOLDS),'invalid attempt or coordinator HOLD active')
    manifest=json.loads((FIX/'fixture.json').read_text())
    for name,digest in manifest['files'].items():require(sha(FIX/name)==digest,'fixture changed: '+name)
    for case in manifest['cases']:
        for directory,hashes in zip(case['sequence_dirs'],case['sequence_sha256']):
            for name,digest in hashes.items():require(sha(Path(directory)/name)==digest,'candidate sequence changed')
    out=HERE/f'classifier_c2_integration_{args.attempt}';out.mkdir(exist_ok=False)
    private=Path(manifest['private_root'])/f'integration-{args.attempt}';private.mkdir(mode=0o700)
    deployment=Deployment(ROOT/'results/zk60_token_io_r1_20261017/cli/zk60_classify.r13.release.bin',R_C2_BINARY_SHA256,
        FIX/'prover-export',FIX/'verifier-export',FIX/'tables','1'*64,DEV_POLICY,23,4,93,True,R_C2_SCHEMA)
    cli=ClassifierCLI(deployment)
    evidence={'schema':'pm-r-c2-native-app-integration/1','at':datetime.now(timezone.utc).isoformat(),
        'scope':'Synthetic R-C2 app integration only; no Shieldstral, product or privacy acceptance',
        'binary_sha256':R_C2_BINARY_SHA256,'fixture_sha256':sha(FIX/'fixture.json'),'tool_sha256':sha(Path(__file__)),
        'candidate_search':manifest['candidate_search'],'cases':[],'attacks':{}}
    try:
        with (out/'guard_status.txt').open('w') as log:
            subprocess.run(['python3',str(worker.config.GUARD),'status'],stdout=log,stderr=subprocess.STDOUT,check=True)
        # Bootstrap pins the model identity from the unchanged synthetic export.
        # Its unverified receipt is separate from all app acceptance cases.
        boot=private/'bootstrap';boot.mkdir(mode=0o700);(boot/'logs').mkdir(mode=0o700)
        first=manifest['cases'][0];content=boot/'content.ids'
        write_private(content,(','.join(map(str,first['content_ids']))+'\n').encode())
        command=cli.prove_command(content,0,first['sequence_dirs'][0],out/'bootstrap-run',boot/'owner')
        worker.run_step(boot,'prove',command,cli)
        loaded=one_event((boot/'logs/prove.log').read_text(),0,'loaded')
        deployment=replace(deployment,statement_identity=loaded['trained_statement_identity'])
        evidence['trained_statement_identity']=deployment.statement_identity
        prover=RungClassifierProver(deployment,out/'public-runs');records=[]
        for case in manifest['cases']:
            item=RungTokenItem(tuple(case['content_ids']),tuple(Path(p) for p in case['sequence_dirs']))
            collected=[]
            for index,(start,end) in enumerate(chunk_plan(len(item.ids),23,4)):
                chunk={'index':index,'start':start,'end':end};job=private/f'{case["name"]}-c{index}'
                pipeline(prover.prepare(case['name'],item,job,chunk))
                record=prover.collect(case['name'],item,job,chunk)
                require(record.statement['verdict_bit']==int(case['margins'][index]>0),'native verdict differs from independent integer candidate')
                recheck=private/f'{case["name"]}-c{index}-recheck'
                pipeline(prover.prepare_recheck(record,job,recheck))
                verdict=prover.collect_recheck(record,recheck)
                require(verdict.proof_valid and verdict.bound_by_proof,'app fresh recheck failed')
                collected.append(record);records.append(record)
            label=private/f'{case["name"]}-label'
            pipeline(prover.prepare_label(collected[::-1],label,item=item));aggregate=prover.collect_label(label)
            evidence['cases'].append({'name':case['name'],'records':[asdict(r) for r in collected],'aggregate':aggregate})
            save(out/'partial.json',evidence)
            print(json.dumps({'case':case['name'],'native_bits':[r.statement['verdict_bit'] for r in collected],'aggregate':aggregate['value']}),flush=True)
        forged=out/'forged-tables';shutil.copytree(FIX/'tables',forged)
        path=forged/'margin_int16.bin';raw=bytearray(path.read_bytes());value=struct.unpack_from('<h',raw)[0]
        struct.pack_into('<h',raw,0,value+1);path.write_bytes(raw)
        meta=json.loads((forged/'classifier.json').read_text());meta['margin_vector']['sha256']=sha(path);save(forged/'classifier.json',meta)
        attacker=ClassifierCLI(replace(deployment,tables=forged))
        evidence['attacks']['rehashed_margin']=attack(private/'attack-margin',attacker.verify_command(records[0].receipt['run_dir']),attacker,'recomputed')
        forged_run=out/'forged-verdict-run';shutil.copytree(records[0].receipt['run_dir'],forged_run)
        path=forged_run/'statement/statement.json';statement=json.loads(path.read_text())
        statement['verdict_bit']^=1;statement['verdict']='flagged' if statement['verdict_bit'] else 'not-flagged';save(path,statement)
        evidence['attacks']['changed_verdict']=attack(private/'attack-verdict',prover.cli.verify_command(forged_run),prover.cli,'')
        save(out/'complete.json',evidence);(out/'worker.done').write_text('0\n')
    except Exception as error:
        save(out/'failure.json',{'type':type(error).__name__,'message':str(error)});(out/'worker.done').write_text('1\n');raise
    print(json.dumps({'complete':str(out/'complete.json'),'real_classifier_enabled':False}),flush=True)

if __name__=='__main__':main()

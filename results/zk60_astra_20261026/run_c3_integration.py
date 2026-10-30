"""Actual frozen r15 CLI integration, including whole-post truncation refusals.

Every native process is a separately guarded leaf. Public evidence contains
synthetic proof records; input openings and worker logs remain private.
"""
import argparse
from dataclasses import asdict
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import sys

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sys.path.insert(0,str(ROOT/'apps/proven-media'))
from proven_media.classifier_cli import Deployment,DEV_POLICY,R_C3_BINARY_SHA256,R_C3_SCHEMA,chunk_plan,require
from proven_media.classifier_prover import RungClassifierProver,RungTokenItem
from proven_media.provers import ProverError
from run_c2_integration import pipeline,worker,attack

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,obj):p.write_text(json.dumps(obj,indent=2)+'\n')

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--attempt',type=int,required=True);args=parser.parse_args()
    require(args.attempt>0 and not any(p.exists() for p in worker.HOLDS),'invalid attempt or coordinator HOLD')
    source=HERE/'classifier_c2_fixture';fixture_path=HERE/'classifier_c3_fixture/fixture.json'
    fixture=json.loads(fixture_path.read_text());base=json.loads((source/'fixture.json').read_text())
    require(sha(source/'fixture.json')==fixture['source_fixture_sha256'],'source fixture changed')
    for name,digest in base['files'].items():require(sha(source/name)==digest,'public fixture changed')
    for case in fixture['cases']:
        for directory,hashes in zip(case['sequence_dirs'],case['sequence_sha256']):
            for name,digest in hashes.items():require(sha(Path(directory)/name)==digest,'private witness candidate changed')
    out=HERE/f'classifier_c3_integration_{args.attempt}';out.mkdir(exist_ok=False)
    private=Path(fixture['private_root'])/f'integration-{args.attempt}';private.mkdir(mode=0o700)
    identity=json.loads((HERE/'classifier_c2_integration_1/complete.json').read_text())['trained_statement_identity']
    deployment=Deployment(ROOT/'results/zk60_token_io_r1_20261017/cli/zk60_classify.r15.release.bin',R_C3_BINARY_SHA256,
        source/'prover-export',source/'verifier-export',source/'tables',identity,DEV_POLICY,23,4,93,True,R_C3_SCHEMA)
    prover=RungClassifierProver(deployment,out/'public-runs')
    paths=[Path(__file__),ROOT/'apps/proven-media/proven_media/classifier_cli.py',
           ROOT/'apps/proven-media/proven_media/classifier_prover.py',ROOT/'apps/proven-media/tools/classifier_pipeline.py']
    evidence={'schema':'pm-r-c3-native-app-integration/1','at':datetime.now(timezone.utc).isoformat(),
        'scope':'MEASURED synthetic r15 app integration; no real Shieldstral, policy registration or privacy acceptance',
        'binary_sha256':R_C3_BINARY_SHA256,'fixture_sha256':sha(fixture_path),
        'source_sha256':{str(p.relative_to(ROOT)):sha(p) for p in paths},'cases':[],'truncation_controls':[]}
    retained={}
    try:
        for case in fixture['cases']:
            item=RungTokenItem(tuple(case['content_ids']),tuple(Path(p) for p in case['sequence_dirs']))
            collected=[]
            for index,(start,end) in enumerate(chunk_plan(len(item.ids),23,4,allow_short=True)):
                chunk={'index':index,'start':start,'end':end};job=private/f'{case["name"]}-c{index}'
                pipeline(prover.prepare(case['name'],item,job,chunk))
                record=prover.collect(case['name'],item,job,chunk)
                require(record.statement['verdict_bit']==int(case['margins'][index]>0),'native verdict differs from integer witness')
                require(record.content_length['tokens']==end-start,'record length includes pad positions')
                collected.append(record)
                if case['name']=='short11':
                    recheck=private/'short11-recheck';pipeline(prover.prepare_recheck(record,job,recheck))
                    verdict=prover.collect_recheck(record,recheck)
                    require(verdict.proof_valid and verdict.bound_by_proof,'short input recheck failed')
            label=private/f'{case["name"]}-label'
            pipeline(prover.prepare_label(collected[::-1],label,item=item))
            aggregate=prover.collect_label(label)
            evidence['cases'].append({'name':case['name'],'content_total':len(item.ids),
                                     'records':[asdict(r) for r in collected],'aggregate':aggregate})
            retained[case['name']]=collected
            save(out/'partial.json',evidence)
            print(json.dumps({'case':case['name'],'tokens':len(item.ids),'chunks':len(collected),'label':aggregate['value']}),flush=True)
        for name,total in [('short1',11),('short11',22),('negative',27),('multi',50)]:
            rows=retained[name];item=RungTokenItem(tuple(range(9,9+total)),())
            target=private/f'prefix-app-{name}'
            try:prover.prepare_label(rows,target,item=item)
            except ProverError:pass
            else:raise AssertionError('adapter accepted a truncated proof set')
            require(not target.exists(),'adapter started work before rejecting a truncated set')
            command=prover.cli.label_command([r.receipt['run_dir'] for r in rows],total)
            native=attack(private/f'prefix-native-{name}',command,prover.cli,'but the post has')
            evidence['truncation_controls'].append({'case':name,'proved_total':rows[0].statement['chunk']['content_total'],
                'actual_post_total':total,'app_refused_before_launch':True,'native':native})
        guards=[]
        for path in private.glob('*/logs/*.guard.json'):
            obj=json.loads(path.read_text())
            guards.append({k:obj[k] for k in ('label','exit','child_rc','child_wall_seconds','peak_rss_gib','enforcement','guard_killed')})
        evidence['guarded_steps']=guards
        evidence['finished_at']=datetime.now(timezone.utc).isoformat()
        save(out/'complete.json',evidence);(out/'worker.done').write_text('0\n')
    except Exception as error:
        save(out/'failure.json',{'type':type(error).__name__,'message':str(error)})
        (out/'worker.done').write_text('1\n');raise
    print(json.dumps({'complete':str(out/'complete.json'),'native_steps':len(guards),'production_enabled':False}),flush=True)

if __name__=='__main__':main()

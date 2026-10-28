"""Retained app/native integration, synthetic R-C1 only; guarded CLI leaves.

Run in a foreground yielded tool session. Private inputs/decommitments remain
outside the repository; only native public receipts and redacted results stay.
"""
from dataclasses import asdict
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
APP=ROOT/'apps/proven-media';sys.path.insert(0,str(APP))
from proven_media.classifier_cli import Deployment,R_C1_BINARY_SHA256,DEV_POLICY,require
from proven_media.classifier_prover import RungClassifierProver,RungTokenItem,PIPELINE

FIX=HERE/'classifier_fixture'
PRIVATE=Path('/tmp/zk60-astra-classifier-owner-20261026')

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def run(job):
    rc=subprocess.run([sys.executable,str(PIPELINE),str(job)]).returncode
    if rc:
        error=job/'logs/error.json'
        if error.exists():print(error.read_text(),flush=True)
        raise RuntimeError('private app pipeline failed: '+job.name)

def main():
    out=HERE/'classifier_integration';out.mkdir(exist_ok=False)
    pin=json.loads((FIX/'native_model_pin.json').read_text())
    require(pin['fixture_manifest_sha256']==sha(FIX/'fixture.json'),'fixture manifest changed')
    fixture=json.loads((FIX/'fixture.json').read_text())
    for name,digest in fixture['generated_files'].items():
        require(sha(FIX/name)==digest,'fixture member changed: '+name)
    evidence={'schema':'pm-r-c1-native-integration/1','scope':'MEASURED synthetic R-C1 app integration, n=1 shared host; no real text, Shieldstral, production security or privacy acceptance',
              'binary_sha256':R_C1_BINARY_SHA256,'fixture_manifest_sha256':sha(FIX/'fixture.json'),
              'tool_sha256':sha(Path(__file__)),'cases':[]}
    for name,tables in (('positive','tables'),('negative','tables-neg')):
        tick=time.monotonic()
        deployment=Deployment(binary=ROOT/'results/zk60_token_io_r1_20261017/cli/zk60_classify.r12.release.bin',
            binary_sha256=R_C1_BINARY_SHA256,prover_export=FIX/'prover-export',verifier_export=FIX/'verifier-export',
            tables=FIX/tables,statement_identity=pin['trained_statement_identity'],policy=DEV_POLICY,
            chunk_size=23,overlap=4,min_bits=93,development=True)
        prover=RungClassifierProver(deployment,out/'public-runs')
        item=RungTokenItem(tuple(range(9,32)),(FIX/'prover-export/seq_s0',))
        post='retained-'+name;job=PRIVATE/(post+'-app')
        run(prover.prepare(post,item,job))
        record=prover.collect(post,item,job)
        recheck=PRIVATE/(post+'-recheck');run(prover.prepare_recheck(record,job,recheck))
        checked=prover.collect_recheck(record,recheck)
        require(checked.proof_valid and checked.bound_by_proof,'fresh app recheck did not verify')
        label=PRIVATE/(post+'-label');run(prover.prepare_label([record],label))
        aggregate=prover.collect_label(label)
        case={'name':name,'record':asdict(record),'recheck':asdict(checked),'aggregate':aggregate,
              'seconds':time.monotonic()-tick,'guard':{}}
        for prefix,directory,steps in (('prove',job,('prove','verify','inowner')),
                                      ('recheck',recheck,('verify','inowner')),('label',label,('label',))):
            for step in steps:
                guard=json.loads((directory/f'logs/{step}.guard.json').read_text())
                # Paths in private jobs are intentionally excluded from the public summary.
                case['guard'][prefix+'-'+step]={k:v for k,v in guard.items() if k in
                    ('exit','child_rc','child_wall_seconds','peak_rss_gib','peak_cgroup_gib','enforcement','refused','guard_killed')}
        evidence['cases'].append(case)
        (out/'partial.json').write_text(json.dumps(evidence,indent=2)+'\n')
        print(json.dumps({'case':name,'verdict':record.labels['synthetic']['value'],'seconds':case['seconds']}),flush=True)
    require({c['record']['statement']['verdict_bit'] for c in evidence['cases']}=={0,1},'both verdict bits required')
    # A short tail produces end-aligned ranges[0,23) and[4,27), exercising
    # overlap and a real two-receipt native aggregate in reverse run order.
    multi=json.loads((HERE/'rung_chunk_inputs.json').read_text())
    require(multi['source_manifest_sha256']==sha(FIX/'fixture.json'),'multi-chunk fixture differs')
    for seq in multi['sequences']:
        for name,digest in seq['sha256'].items():require(sha(Path(seq['dir'])/name)==digest,'candidate sequence changed')
    mixed=json.loads((HERE/'rung_chunk_mixed_tables.json').read_text())
    require(mixed['input_manifest_sha256']==sha(HERE/'rung_chunk_inputs.json'),'mixed fixture inputs changed')
    for name,digest in mixed['files'].items():require(sha(Path(mixed['table_dir'])/name)==digest,'mixed classifier table changed')
    deployment=Deployment(binary=ROOT/'results/zk60_token_io_r1_20261017/cli/zk60_classify.r12.release.bin',
        binary_sha256=R_C1_BINARY_SHA256,prover_export=FIX/'prover-export',verifier_export=FIX/'verifier-export',
        tables=Path(mixed['table_dir']),statement_identity=pin['trained_statement_identity'],policy=DEV_POLICY,
        chunk_size=23,overlap=4,min_bits=93,development=True)
    prover=RungClassifierProver(deployment,out/'public-runs')
    item=RungTokenItem(tuple(multi['content_ids']),tuple(Path(s['dir']) for s in multi['sequences']))
    records=[];tick=time.monotonic()
    for index,(start,end) in enumerate(multi['ranges']):
        chunk={'index':index,'start':start,'end':end};job=PRIVATE/f'retained-multi-c{index}-app'
        run(prover.prepare('retained-multi',item,job,chunk))
        records.append(prover.collect('retained-multi',item,job,chunk))
    require([r.statement['verdict_bit'] for r in records]==mixed['expected_chunk_verdict_bits'],'expected mixed verdicts differ')
    label=PRIVATE/'retained-multi-label';run(prover.prepare_label(records[::-1],label))
    aggregate=prover.collect_label(label)
    require((aggregate['value']=='yes')==any(r.labels['synthetic']['value']=='yes' for r in records),'aggregate OR differs')
    evidence['multi_chunk']={'records':[asdict(r) for r in records],'aggregate':aggregate,
        'seconds':time.monotonic()-tick,'input_manifest_sha256':sha(HERE/'rung_chunk_inputs.json'),
        'mixed_tables_sha256':sha(HERE/'rung_chunk_mixed_tables.json'),'run_order':[1,0],'range_count':2}
    (out/'complete.json').write_text(json.dumps(evidence,indent=2)+'\n')
    print(json.dumps({'multi_chunk':True,'aggregate':aggregate}),flush=True)
    return 0

if __name__=='__main__':raise SystemExit(main())

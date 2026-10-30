"""Bounded, resumable native R14 relation regressions; no early-refusal passes.

Every case emits/decodes a complete one-stage receipt before native refusal.
Groups may run separately; aggregate acceptance requires all 50 cases.
"""
from datetime import datetime,timezone
import argparse,hashlib,json,shutil,subprocess,sys,time
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
TREE=HERE/'capture-working-tree';GUARD=ROOT/'scripts/zk60_resource_guard.py'
BUILD='sol-r14-capture-build-1'
TEST='private_block::argument::split_attack_tests::split_run_t128_relation_regression_receipt_from_env'
LIMBS=[f'limb-{role}-{piece}' for role in ['y','ym','rao','rd','rg','up','h','rh'] for piece in ['wide','narrow']]
LIMBS += [f'limb-{role}-whole' for role in ['q','k','v','o','rs']]
TABLES=['table-byte-support','table-exp-support','table-act-support']
GROUPS={
    'non-dd-limbs':[(False,c) for c in LIMBS],
    'dd-limbs':[(True,c) for c in LIMBS],
    'non-dd-tables':[(False,c) for c in TABLES],
    'dd-tables':[(True,c) for c in TABLES],
    'dd-dictionary':[(True,c) for c in ['dictionary-unused','dictionary-counts']],
}
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--group',choices=['all',*GROUPS],default='all')
    args=parser.parse_args()
    assert (HERE/(BUILD+'.validated.done')).read_text().strip()=='0'
    pin=json.loads((HERE/(BUILD+'.source.json')).read_text())
    def check():
        assert sha(GUARD)=='67e9478f55518c2808ff65e5f303f70e155a5f21c5987243a39cf579d1a9a6f3','guard changed'
        for name,want in pin['files'].items():assert sha(TREE/name)==want,name
    check();checkpoint=HERE/'checkpoints/capture-build-1';binary=checkpoint/'hashline.test.bin'
    if not checkpoint.exists():
        for name in pin['files']:
            target=checkpoint/'tree'/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(TREE/name,target)
        bins=[p for p in (TREE/'hashline/target/release/deps').glob('hashline-*') if p.is_file() and p.stat().st_mode&0o111]
        assert len(bins)==1;shutil.copy2(bins[0],binary)
    for name,want in pin['files'].items():assert sha(checkpoint/'tree'/name)==want,name
    binary_sha=sha(binary)
    def label_for(dd,case):return 'sol-r14-regression-'+('dd' if dd else 'non-dd')+'-'+case+'-1'
    def read_case(dd,case):
        label=label_for(dd,case);path=HERE/(label+'.result.json')
        assert (HERE/(label+'.validated.done')).read_text().strip()=='0'
        row=json.loads(path.read_text());assert row['source']==pin['tree_sha256'] and row['binary_sha256']==binary_sha
        assert row['case']==case and row['dd']==dd
        assert sha(HERE/row['fixture']/'segment0.bin')==row['receipt_sha256']
        return row
    for group,cases in GROUPS.items():
        if args.group not in ['all',group]:continue
        records=[]
        for dd,case in cases:
            label=label_for(dd,case)
            if (HERE/(label+'.validated.done')).exists():
                records.append(read_case(dd,case));continue
            check();assert sha(binary)==binary_sha
            out=HERE/'regression-fixtures'/('dd' if dd else 'non-dd')/case
            command=[sys.executable,str(GUARD),'run','--class','cpu','--label',label,'--need-gib','7.5','--cap-gib','10',
                '--wait-secs','21600','--max-secs','1200','--log',str(HERE/(label+'.log')),'--done',str(HERE/(label+'.done')),
                '--result-json',str(HERE/(label+'.guard.json')),'--','/usr/bin/env','RAYON_NUM_THREADS=8','OPENBLAS_NUM_THREADS=1',
                'HL_R14_REGRESSION='+case,'HL_R14_DD='+str(int(dd)),'HL_R14_ATTACK_OUTPUT='+str(out),
                str(binary),TEST,'--exact','--ignored','--nocapture','--test-threads=1']
            record=HERE/(label+'.command.json');assert not record.exists(),'recorded incomplete/failed case needs diagnosis and a new attempt label'
            record.write_text(json.dumps({'command':command,'source':pin['tree_sha256'],'binary_sha256':binary_sha,'runner_sha256':sha(Path(__file__)), 'rayon_threads':8},indent=2)+'\n')
            while True:
                check();status=json.loads(subprocess.check_output([sys.executable,str(GUARD),'status','--json'],cwd=ROOT,text=True))
                lean=all(j['class']!='light' or j['need_gib']<=1 for j in status['live_guarded_jobs'])
                holds=(HERE/'HOLD').exists() or (HERE.parent/'HOLD').exists()
                if lean and not holds:break  # guard owns admission before locks
                print(datetime.now(timezone.utc).isoformat(),label,'waiting outside heavy lock / lean admission',flush=True);time.sleep(10)
            r=subprocess.run(command,cwd=ROOT);check();assert sha(binary)==binary_sha
            if r.returncode:sys.exit(r.returncode)
            log=(HERE/(label+'.log')).read_text()
            assert '1 passed; 0 failed' in log and 'R14_ATTACK_REFUSAL '+case+':' in log
            receipts=[json.loads(line.split('R14_MALICIOUS_RECEIPT ',1)[1]) for line in log.splitlines() if 'R14_MALICIOUS_RECEIPT ' in line]
            assert len(receipts)==1;receipt=receipts[0]
            assert receipt['case']==case and receipt['dd']==dd and receipt['expected_accept'] is False
            assert receipt['canonical_frame_decoded'] and receipt['native_verifier_used']
            assert (out/'segment0.bin').stat().st_size==receipt['bytes']
            guard=json.loads((HERE/(label+'.guard.json')).read_text())
            row={'label':label,'source':pin['tree_sha256'],'binary_sha256':binary_sha,'case':case,'dd':dd,
                'fixture':str(out.relative_to(HERE)),'receipt':receipt,'receipt_sha256':sha(out/'segment0.bin'),'guard':guard}
            (HERE/(label+'.result.json')).write_text(json.dumps(row,indent=2)+'\n')
            (HERE/(label+'.validated.done')).write_text('0\n');records.append(row)
            print(label,'PASS',flush=True)
        report={'utc':datetime.now(timezone.utc).isoformat(),'source':pin['tree_sha256'],'binary_sha256':binary_sha,'group':group,'cases':records}
        (HERE/('REGRESSION_'+group+'.json')).write_text(json.dumps(report,indent=2)+'\n')
        (HERE/('REGRESSION_'+group+'.done')).write_text('0\n')
    all_cases=[case for cases in GROUPS.values() for case in cases];assert len(all_cases)==50
    complete=all((HERE/(label_for(dd,case)+'.validated.done')).exists() for dd,case in all_cases)
    if complete:
        report={'utc':datetime.now(timezone.utc).isoformat(),'source':pin['tree_sha256'],'binary_sha256':binary_sha,
            'cases':[read_case(dd,case) for dd,case in all_cases],
            'scope':'50 complete native R14 T128 malicious receipts: 13 R13 high-byte families, both D/F pieces where applicable, DD/nonDD; unused DD quotient, displaced DD counts; byte/exp/ACT3 support-tail moves with consistent paired helpers. No builder/routing-only passes. Public synthetic, no privacy/trained CLI acceptance.'}
        (HERE/'NATIVE_RELATION_REGRESSIONS.json').write_text(json.dumps(report,indent=2)+'\n')
        (HERE/'NATIVE_RELATION_REGRESSIONS.done').write_text('0\n');print('Native R14 relation regressions PASS50/0',flush=True)
    else:print('Requested regression group complete; aggregate still pending',flush=True)
if __name__=='__main__':main()

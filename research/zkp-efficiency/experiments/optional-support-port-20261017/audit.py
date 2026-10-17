"""Evidence integrity/accounting audit, not a native proof or new benchmark."""
import datetime,hashlib,json
from collections import Counter
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
checks=[]
def check(label,condition):
    assert condition,label
    checks.append(label)
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()

r=json.loads((HERE/'result.json').read_text())
cmd=json.loads((HERE/'command.json').read_text())
ex=json.loads((HERE/'execution.json').read_text())
check('result passed',r['status']=='passed')
check('actual exit zero',ex['exit_code']==0)
check('wall limit',r['wall_seconds']<59 and ex['wrapper_wall_seconds']<60)
check('resident memory limit',r['max_rss_kib']<512*1024)
check('one low priority CPU thread',r['hardware']['threads']==1 and r['hardware']['nice']==19)
check('one CPU affinity',len(r['hardware']['affinity'])==1)
check('seed retained',r['seed']==2026101753)
for name,sha in cmd['source_sha256'].items():
    check('executed source '+name,digest(HERE/name)==sha)
for pin in json.loads((HERE/'native-pins.json').read_text()):
    check('native snapshot '+pin['snapshot'],digest(HERE/pin['snapshot'])==pin['sha256'])
    check('native still current '+pin['snapshot'],digest(Path(pin['path']))==pin['sha256'])
    if not pin.get('new_pin'):check('prior pin preserved '+pin['snapshot'],pin['matches_cycle52'])
check('all four abstract combinations',len(r['presence_fixture_counts'])==4)
check('100 fixtures',sum(r['presence_fixture_counts'].values())==r['counts']['fixtures']==100)
check('six chunk/debug schedules per fixture',r['counts']['full_schedules']==600)
# Independent envelope arithmetic from the stated fixture products:
# n0..3 * two limb settings * three data modes; one unpad/three pad patterns.
# Four h/t/j shapes have n4; one unpad and three pad patterns.
samples=6*(sum(range(4))*2*3*(5+3*6)+4*(5+3*6))
check('original outer sample counts',r['counts']['independent_round_samples']==samples==5520)
check('extension equations',r['counts']['independent_extension_clause_values']==4*2*4*3*4)
check('nonzero and zero-factor recovery covered',r['recoveries']>0 and r['zero_factor_fallbacks']>0)
check('ported S-only refusal covered',r['counts']['native_construction_refusals']==8)
check('P3 S-only port refusal covered',r['counts']['P3_S_only_size_policy_refusals']==19)
check('no complete proofs credited',r['proof_accounting']['accepted_complete_private_8b_proofs']==0)
check('no tokens/passes credited',r['proof_accounting']['proved_tokens']==r['proof_accounting']['passes']==0)
for key,val in r['proof_accounting'].items():
    if key not in ('accepted_complete_private_8b_proofs','proved_tokens','passes'):
        check('unmeasured proof accounting '+key,val is None)
for i,p in enumerate(r['projections']):
    check('no native speedup claimed '+str(i),p['native_speedup_claim'] is False)
    for label,total in p['bracket_only_totals'].items():
        detail=p['details'][label];want=Counter()
        for j in range(p['cube_log']):
            for g,d in enumerate(detail['bracket_degrees']):
                calls=(1<<(p['cube_log']-j-1))*(d+1-int(j>0))
                for k,v in detail['scalar_per_group'][g].items():want[k]+=v*calls
        check('scalar census arithmetic '+str(i)+' '+label,dict(want)==total)
        check('support payload formula '+str(i)+' '+label,
              detail['support_table_payload_bytes']==sum(detail['supports'])*(1<<p['cube_log'])*16)
    actual=p['details']['correct_optional_port']
    if p['shape']['query_heads']==32:
        check('full domains omit supports '+str(i),actual['supports']==[False,False] and not actual['pad_on'])
        check('native unpad declared widths '+str(i),actual['bracket_degrees']==[3,1,1] and actual['group0_coefficient_width']==4)
        check('conditional factory inactive '+str(i),p['factory_metadata']['correct_optional_port']['selected_groups']==[])
        check('no unpad padding setup '+str(i),actual['literal_native_pad_weight_setup_mul']==0)
    else:
        check('padded census unchanged '+str(i),p['bracket_only_totals']['legacy_always_padded_formula']==p['bracket_only_totals']['correct_optional_port'])
        check('literal setup recurrence '+str(i),actual['literal_native_pad_weight_setup_mul']==actual['pad_weight_words']+2)
prefix=json.loads((HERE/'source-ledger-prefix.json').read_text())
ledger=(ROOT/'sources.jsonl').read_bytes()
check('all prior source bytes preserved',hashlib.sha256(ledger[:prefix['bytes']]).hexdigest()==prefix['sha256'])
records=[json.loads(x) for x in ledger.splitlines()]
new=json.loads((HERE/'sources-cycle53.json').read_text())
check('five source records appended',len(records)==269 and records[-5:]==new)
check('unique source IDs',len({x['id'] for x in records if 'id' in x})==sum('id' in x for x in records))
old=(HERE/'startup/FINDINGS.md').read_bytes()
check('all prior findings bytes preserved',(ROOT/'FINDINGS.md').read_bytes().startswith(old))
check('dated progress equals current report',(ROOT/'PROGRESS.md').read_bytes()==(ROOT/'progress'/ (r['run_id']+'.md')).read_bytes())
for directory in ('initial-before-P3-domain-ownership-correction','before-native-outer-degree-accounting'):
    for name in ('result.json','command.json','execution.json','run.log'):
        check('superseded evidence '+directory+'/'+name,(HERE/directory/name).is_file())
for name in ('README.md','source-diff.patch','copy-provenance.json','startup-manifest.json'):
    check('required artifact '+name,(HERE/name).is_file())
report=dict(status='passed',checks=len(checks),checked_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
            labels=checks,limits='Integrity/accounting audit only; no additional experiment or native performance/security validation.')
(HERE/'checkpoint-audit.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k!='labels'}))

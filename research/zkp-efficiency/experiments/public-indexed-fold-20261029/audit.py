from pathlib import Path
import json,hashlib
D=Path(__file__).resolve().parent
checks=0
def check(x,why=''):
    global checks
    assert x,why
    checks+=1
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def extract(s,name):
    at=s.index('fn '+name+'(');start=s.rfind('\n',0,at)+1;brace=s.index('{',at);dep=1;i=brace+1
    while dep:dep+=(s[i]=='{')-(s[i]=='}');i+=1
    return s[start:i]+'\n'

for collection in ('native-pins.json','seam-pins.json'):
    for pin in json.loads((D/collection).read_text()):
        check(digest(D/pin['snapshot'])==pin['sha256'],'snapshot')
        check(digest(Path(pin['path']))==pin['sha256'],'read-only source drift')
arg=(D/'native/hashline/src/private_block/argument.rs').read_text()
pcs=(D/'native/zkp-core/src/pcs.rs').read_text()
prot=(D/'native/hashline/src/private_block/protocol.rs').read_text()
mle=(D/'native/zkp-core/src/mle.rs').read_text()
check((D/'a_builder.rs').read_text()=="impl<'a>B<'a>{\n"+extract(arg,'a_slice')+'}\n')
for file,src,names in [('builder.rs',arg,['build_claim']),('claim_point.rs',arg,['claim_point']),('native_groups.rs',pcs,['zpart_weights','zkey_weights','group_zclaims','zk_rhos']),('native_audit.rs',prot,['part_rows','audit_claims'])]:
    check((D/file).read_text()=='\n'.join(extract(src,n) for n in names),'exact helper')
check((D/'serial_eq.rs').read_text()=='\n'.join(extract(mle,n) for n in ['eq_table','eq_table_msb']).replace('.par_iter_mut()', '.iter_mut()'))
prior_dir=D.parent/'a-overlap-support-20261029'
for n in ['a_constants.rs','a_ids.rs','a_domains.rs','a_offsets.rs','cases.rs','packing_plans.rs','case-metadata.json']:
    check((D/n).read_bytes()==(prior_dir/n).read_bytes(),'retained public wrapper')
new_prefix=(D/'harness.rs').read_text().split('include!("indexed.rs");')[0]
check(new_prefix==(prior_dir/'harness.rs').read_text().split('fn main()')[0],'unchanged public setup definitions')
r=json.loads((D/'result.json').read_text());c=json.loads((D/'census-result.json').read_text());cost=json.loads((D/'cost-result.json').read_text())
check(r['status']==c['status']==cost['status']=='PASS')
check(c['fixtures']==14 and c['checked_values']==109512 and c['source_checked_values']==16416)
check(c['negative_controls']==376 and c['checks']==1206)
check(r['seed']==202610290151)
for p in r['profiles']:
    check(p['checked_values']==p['rho_vectors']*p['width']*len(p['plans'])*9,'comparison accounting')
    check(p['width']==8 if p['source'] else p['width']>=4,'pad scope')
for p in cost['profiles']:
    check(p['membership_total_B']==p['indexed_matrix_B']+p['indexed_membership_rho_B']+p['index_logical_reads_B'])
    check(p['plan_upload_payload_B']==p['union_visits']*4)
    check(p['index_logical_reads_B']==p['plan_upload_payload_B']*p['n'])
    check(p['rho_upload_B_unchanged']==p['groups']*p['rows']*16)
base,rev=cost['profiles'][:2]
check(rev['union_visits']<base['union_visits'] and rev['plain_union_total_B']>base['plain_union_total_B'],'negative objective result')
check(all(p['rho_membership_reads_per_column']==(9561 if p['dd'] else 9804) for p in cost['profiles']))
for stage in ['compile','probe','census','cost']:
    x=json.loads((D/(stage+'-execution.json')).read_text())
    check(x['exit_code']==0 and x['wall_s']<60)
    check(x['max_rss_kib']<512*1024 and x['address_space_mib']<=512 and x['one_cpu_affinity'])
old=json.loads((D/'startup/prior-hypotheses.json').read_text());h=json.loads((D/'hypotheses.json').read_text())
check(len(old)==72 and len(h)==74 and h[:72]==old,'preserved ranked hypotheses')
sources=[json.loads(x) for x in (D/'sources-cycle.jsonl').read_text().splitlines()]
all_sources=[json.loads(x) for x in (D.parent.parent/'sources.jsonl').read_text().splitlines()]
check(len(sources)==5 and all_sources[-5:]==sources and len(all_sources)==1010)
check(all(x['access_date']=='2026-10-29' and not x['external_execution'] and x['inspected_commit_id'] is None for x in sources))
check(all(cost[k]==0 for k in ['new_verified_full_stack_proofs','new_model_passes','new_proved_positions']))
check(all(x is None for x in cost['clocks'].values()))
recheck=[]
for pin in json.loads((D/'memory-index.json').read_text()):
    p=Path(pin['path'])
    if p.name in ('STATE.md','PROGRESS.md','FINDINGS.md','sources.jsonl'): continue
    now=digest(p);recheck.append(dict(path=str(p),start=pin['sha256'],end=now,unchanged=now==pin['sha256']))
check(all(x['unchanged'] for x in recheck),'mandate/owner drift')
(D/'owner-document-recheck.json').write_text(json.dumps(recheck,indent=2)+'\n')
summary=dict(status='PASS',checks=checks,exact_native_helpers=True,prior_hypotheses_preserved=72,ranked_hypotheses=74,owner_and_mandate_documents_unchanged=len(recheck),new_verified_full_stack_proofs=0,new_model_passes=0,new_proved_positions=0)
(D/'audit-result.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary))

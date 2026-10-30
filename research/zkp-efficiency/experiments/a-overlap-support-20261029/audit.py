from pathlib import Path
import json,hashlib,re
D=Path(__file__).resolve().parent;checks=0

def check(x,label=''):
 global checks
 assert x,label
 checks+=1

def extract(s,name):
 at=s.index('fn '+name+'(');start=s.rfind('\n',0,at)+1;brace=s.index('{',at);dep=1;i=brace+1
 while dep:dep+=(s[i]=='{')-(s[i]=='}');i+=1
 return s[start:i]+'\n'
for pin in json.loads((D/'native-pins.json').read_text()):
 check(hashlib.sha256((D/pin['snapshot']).read_bytes()).hexdigest()==pin['sha256'],'snapshot')
 check(hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()==pin['sha256'],'source')
arg=(D/'native/hashline/src/private_block/argument.rs').read_text();pcs=(D/'native/zkp-core/src/pcs.rs').read_text();prot=(D/'native/hashline/src/private_block/protocol.rs').read_text();mle=(D/'native/zkp-core/src/mle.rs').read_text();acc=(D/'native/hashline/src/private_block/accuracy_layout.rs').read_text()
check((D/'a_builder.rs').read_text()=="impl<'a>B<'a>{\n"+extract(arg,'a_slice')+'}\n')
for file,src,names in [('builder.rs',arg,['build_claim']),('claim_point.rs',arg,['claim_point']),('native_groups.rs',pcs,['zpart_weights','zkey_weights','group_zclaims','zk_rhos']),('native_audit.rs',prot,['part_rows','audit_claims'])]:
 check((D/file).read_text()=='\n'.join(extract(src,n) for n in names))
check((D/'serial_eq.rs').read_text()=='\n'.join(extract(mle,n) for n in ['eq_table','eq_table_msb']).replace('.par_iter_mut()', '.iter_mut()'))
check((D/'a_ids.rs').read_text()=='use super::accuracy_precision::Stack;\nuse super::layout::*;\n'+acc[acc.index('#[derive'):acc.index('    /// Emit byte and exact top-bit pins')]+'}\n')
sh=(D/'native/hashline/src/private_block/shape.rs').read_text();check((D/'a_domains.rs').read_text()=='impl Shape{\n'+extract(sh,'a_plane_doms')+'}\n')
r=json.loads((D/'result.json').read_text());c=json.loads((D/'census-result.json').read_text());cost=json.loads((D/'cost-result.json').read_text())
check(r['status']==c['status']==cost['status']=='PASS');check(r['fixtures']==14);check(r['independent_coefficients']==27540288);check(r['restored_message_plus_pad_values']==5172);check(r['source_row_narrow5_packed_values']==380);check(r['negative_controls']==62);check(c['checks']==517)
check(all(p['multiply_claimed_data_rows']>0 for p in r['profiles']))
# Exact same plan inputs used by the native-helper run and independent model.
plans=[[i for batch in p['packing_plan'] for i in batch] for p in c['profiles']]
check((D/'packing_plans.rs').read_text()=='fn source_order(dd:bool)->Vec<usize>{if dd{vec!'+str(plans[1])+'}else{vec!'+str(plans[0])+'}}\n')
prior=json.loads((D/'startup/prior-hypotheses.json').read_text());hyp=json.loads((D/'hypotheses.json').read_text());check(hyp[:70]==prior);check(len(hyp)==72)
check(len((D/'sources-cycle.jsonl').read_text().splitlines())==5);check(len(list(D.glob('web*.json')))==8)
for stage in ['prepare','compile','probe','census','cost']:
 x=json.loads((D/(stage+'-execution.json')).read_text());check(x['exit_code']==0);check(x['wall_s']<60);check(x['max_rss_kib']<512*1024);check(x['address_space_mib']<=512 and x['one_cpu_affinity'])
recheck=[]
for pin in json.loads((D/'memory-index.json').read_text())['pins']:
 p=Path(pin['path'])
 if p.name in ('STATE.md','PROGRESS.md','FINDINGS.md','sources.jsonl'):continue
 now=hashlib.sha256(p.read_bytes()).hexdigest();recheck.append(dict(path=str(p),start=pin['sha256'],end=now,unchanged=now==pin['sha256']))
check(all(x['unchanged'] for x in recheck),'owner/mandate document drift')
(D/'owner-document-recheck.json').write_text(json.dumps(recheck,indent=2)+'\n')
manifest=[]
for p in sorted(D.rglob('*')):
 if p.is_file() and p.name not in ['artifact-manifest.json'] and '__pycache__' not in p.parts:
  manifest.append(dict(path=str(p.relative_to(D)),bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
(D/'artifact-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
(D/'audit-result.json').write_text(json.dumps(dict(status='PASS',checks=checks,native_helpers_exact=True,prior_hypotheses_unchanged=70,owner_documents_unchanged=len(recheck),full_stack_proofs=0,model_passes=0,proved_positions=0),indent=2)+'\n')
print(json.dumps(dict(status='PASS',checks=checks,native_helpers_exact=True,owner_documents_unchanged=len(recheck))))

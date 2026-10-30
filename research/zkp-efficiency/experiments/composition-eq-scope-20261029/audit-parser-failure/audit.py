from pathlib import Path
import hashlib,json,re,time,resource
D=Path(__file__).resolve().parent;root=D.parent.parent;t=time.monotonic();checks=0
def ck(v,label):
 global checks
 checks+=1
 if not v:raise AssertionError(label)
def sha(b):return hashlib.sha256(b).hexdigest()
def extract(s,name):
 at=s.index('fn '+name+'(');start=s.rfind('\n',0,at)+1;i=s.index('{',at)+1;dep=1
 while dep:dep+=(s[i]=='{')-(s[i]=='}');i+=1
 return s[start:i]+'\n'
pins=json.loads((D/'native-pins.json').read_text())
for p in pins:
 ck(sha(Path(p['path']).read_bytes())==p['sha256'],'live source pin');ck(sha((D/p['snapshot']).read_bytes())==p['sha256'],'snapshot pin')
s=(D/'native/zkp-core/src/pcs.rs').read_text();m=(D/'native/zkp-core/src/mle.rs').read_text()
ck((D/'native_groups.rs').read_text()=='\n'.join(extract(s,n)for n in ['zpart_weights','zkey_weights','group_zclaims','zk_rhos']),'four unchanged native extracts')
ck((D/'serial_eq.rs').read_text()==(extract(m,'eq_table')+'\n'+extract(m,'eq_table_msb')).replace('.par_iter_mut()', '.iter_mut()'),'only serial Eq adaptation')
old=extract(s,'group_zclaims');expected=old.replace('fn group_zclaims(', 'fn group_zclaims_with_columns(').replace('log_cols: u32) ->','log_cols: u32, columns: bool) ->').replace('let cw = zkey_weights(&key, log_cols);','let cw = if columns { zkey_weights(&key, log_cols) } else { Vec::new() };')
ck((D/'candidate.rs').read_text()==expected,'candidate only name/parameter/column branch')
for word in ['unsafe','static','cache','random','Transcript','ZkRng','fs::']:
 ck(word not in expected,'candidate no effect '+word)
# Apply the saved unified patch IN MEMORY; no Git or production edits.
src=s.splitlines(True);patch=(D/'native-prover-columns.patch').read_text().splitlines(True);res=[];pos=0;i=2
while i<len(patch):
 match=re.match(r'@@ -(\d+)(?:,\d+)? \+\d+(?:,\d+)? @@',patch[i]);ck(match is not None,'patch hunk');start=int(match[1])-1;res.extend(src[pos:start]);pos=start;i+=1
 while i<len(patch) and not patch[i].startswith('@@ '):
  line=patch[i];prefix=line[0];body=line[1:]
  if prefix in ' -':ck(src[pos]==body,'patch old/context bytes');pos+=1
  if prefix in ' +':res.append(body)
  i+=1
res.extend(src[pos:]);patched=''.join(res)
for name in ['zpart_weights','zkey_weights','zk_rhos','fold_rows_multi_zk','assert_mask_sites','verify_zk','verify_zk_tagged','zk_groups_for_record']:
 ck(extract(s,name)==extract(patched,name),'unchanged '+name)
ck(extract(patched,'group_zclaims_with_columns')==expected,'patched helper same compiled candidate')
ck('log_cols, true)'in extract(patched,'group_zclaims'),'verifier wrapper retains columns')
op=extract(s,'open_zk');want=op.replace('group_zclaims(claims, rows, cm.params.log_cols)','group_zclaims_with_columns(claims, rows, cm.params.log_cols, false)')
ck(extract(patched,'open_zk')==want,'only prover preparation call changed')
ck(op.count('groups')==2,'open group dataflow only declaration/rhos')
ck('for (_, members) in groups {'in extract(s,'zk_rhos'),'native rhos ignores columns')
proto=(D/'native/hashline/src/private_block/protocol.rs').read_text();run=(D/'native/hashline/src/private_block/run.rs').read_text();boundary=(D/'native/hashline/src/private_block/boundary.rs').read_text()
ck('zk_groups_for_record'not in proto+run+boundary,'legacy reporting duplicate absent current private callers')
ck('group_zclaims'not in proto+run+boundary,'private schedule uses metadata grouping')
ck('let groups = opening_groups_at(claims, log_n)?;'in proto,'compact native group audit')
ck('pcs::open_zk(&a, &ac, tr)'in proto and 'pcs::open_zk(&h, &hc, tr)'in proto,'actual recurring A/H seam')
ck('pcs::open_zk(&self.committed, claims, tr)'in boundary,'consuming boundary opening seam')
ck('n_groups_zk'not in s+proto+run+boundary,'correct absent historical spelling')
# Source dependency controls: fail if columns become a consumer requirement.
def contract(open_source,rhos_source):return open_source.count('groups')==2 and 'for (_, members) in groups {'in rhos_source
ck(not contract(op+'\nlet _ = groups[0].0.len();',extract(s,'zk_rhos')),'new opening column consumer detected')
ck(not contract(op,extract(s,'zk_rhos').replace('for (_, members)','for (cw, members)')),'new rhos column consumer detected')
r=json.loads((D/'result.json').read_text());a=json.loads((D/'account-result.json').read_text())
for obj in [r,a]:ck(obj['status']=='PASS'and obj['full_stack_proofs']==obj['model_passes']==obj['proved_positions']==0,'no model credit')
ck(r['fixtures']==162 and r['matched_panic_cases']==r['negative_controls']==8,'fixture/control counts')
ck(len(r['sized'])==4,'four public-dimension consumer cases')
for obj in r['sized']:
 ck(len(obj['baseline_group_plus_rhos_drop_ns'])==len(obj['candidate_group_plus_rhos_drop_ns'])==3,'alternating serial samples')
 ck(obj['rows']>4000 and obj['claims']>50,'actual census-sized row/member dimensions')
for n in ['prepare','compile','probe','account']:
 e=json.loads((D/(n+'-execution.json')).read_text());ck(e['exit_code']==0 and e['elapsed_s']<60,'bounded success');ck(e['address_space_bytes']<=512*1024**2 and not e['gpu'],'resource caps')
failed=json.loads((D/'failed-unrolled-sized/compile-execution.json').read_text());ck(failed['exit_code']!=0 and failed['address_space_bytes']==384*1024**2,'memory-cap failure retained')
ck('memory allocation of 2097152 bytes failed'in(D/'failed-unrolled-sized/compile.stderr.log').read_text(),'exact compile blocker retained')
prior=json.loads((D/'startup/prior-hypotheses.json').read_text());now=json.loads((D/'hypotheses.json').read_text());ck(now[:len(prior)]==prior and len(now)>len(prior),'prior hypothesis objects unchanged')
ck((root/'FINDINGS.md').read_bytes().startswith((D/'startup/FINDINGS.md').read_bytes()),'findings prefix preserved')
ck((root/'sources.jsonl').read_bytes().startswith((D/'startup/sources.jsonl').read_bytes()),'sources prefix preserved')
new=[json.loads(l)for l in(D/'sources-cycle.jsonl').read_text().splitlines()]
for rec in new:
 for key in ['access_date','url','publication_date','verified_update_date','implementation_license','inspected_commit_id']:ck(key in rec,'source field '+key)
 ck(not rec['external_execution'] and not rec['reproduced_performance'],'external claims separate')
owner=[]
for p in json.loads((D/'startup-manifest.json').read_text()):
 if '/docs/'in p['path']or p['path'].endswith('/CLAUDE.md'):
  b=Path(p['path']).read_bytes();owner.append(dict(path=p['path'],start=p['sha256'],current=sha(b),unchanged=sha(b)==p['sha256']));ck(sha(b)==p['sha256'],'owner document pin unchanged')
(D/'owner-document-recheck.json').write_text(json.dumps(owner,indent=2)+'\n')
result=dict(status='PASS',checks=checks,native_and_prior_model_pins=len(pins),native_functions_unchanged=4,all_prior_hypotheses_preserved=True,source_records_added=len(new),elapsed_s=time.monotonic()-t,max_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,external_review=False,full_stack_proofs=0)
(D/'audit-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))

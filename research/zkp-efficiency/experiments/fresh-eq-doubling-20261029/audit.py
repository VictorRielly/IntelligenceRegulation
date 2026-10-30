from pathlib import Path
import hashlib,json,time,resource
H=Path(__file__).resolve().parent;start=time.monotonic();checks=0
def ck(v,label):
 global checks
 checks+=1
 if not v:raise AssertionError(label)
def sha(b):return hashlib.sha256(b).hexdigest()
def extract(s,prefix):
 a=s.index(prefix);i=s.index('{',a)+1;depth=1
 while depth:depth+=(s[i]=='{')-(s[i]=='}');i+=1
 return s[a:i]
pins=json.loads((H/'native-pins.json').read_text())+json.loads((H/'consumer-pins.json').read_text())
for p in pins:
 ck(sha(Path(p['path']).read_bytes())==p['sha256'],'source pin');ck(sha((H/p['snapshot']).read_bytes())==p['sha256'],'snapshot pin')
for n in ['field','mle']:ck((H/f'native/zkp-core__src__{n}.rs').read_bytes()==(H/f'consumers/zkp-core__src__{n}.rs').read_bytes(),'actual frozen core matches adapter')
arg=(H/'native/argument.rs').read_text()
for prefix,name in [('pub(super) fn priv_table(','native_priv_table'),('fn claim_point(','native_claim_point'),('fn mask_eval(','native_mask_eval')]:
 oldname=prefix.split('fn ')[1].split('(')[0];expect=extract(arg,prefix).replace('pub(super) ','').replace('fn '+oldname+'(','fn '+name+'(',1)+'\n';ck((H/(name+'.rs')).read_text()==expect,'exact native extraction')
for n in ['priv_table','mask_eval']:
 expected=(H/('native_'+n+'.rs')).read_text().replace('fn native_'+n+'(','fn changed_'+n+'(',1).replace('= eq_table_msb(','= candidate::eq_table_msb(',1)
 ck(expected==(H/('changed_'+n+'.rs')).read_text(),'only Eq call adapter')
native=(H/'consumers/zkp-core__src__mle.rs').read_text();a=native.index('pub fn eq_table(');b=native.index('/// eq(r, s)')
ck(native[a:b].replace('lo.par_iter_mut().zip(hi.par_iter_mut())','lo.iter_mut().zip(hi.iter_mut())').strip()==(H/'serial_eq.rs').read_text().strip(),'only serial Rayon adaptation')
candidate=(H/'candidate.rs').read_text()
for forbidden in ['unsafe','static','random','cache','Transcript','ZkRng','std::fs','thread_local']:ck(forbidden not in candidate,'no side effects '+forbidden)
ck('let product = e.mul(ri);'in candidate and '*a = e.sub(product);'in candidate,'exact product complement')
patched=(H/'candidate-native-mle.rs').read_text();ck(patched.count('let product = e.mul(ri);')==2,'both native seq/parallel branches patched')
ck(native.count('par_iter_mut')==patched.count('par_iter_mut'),'Rayon scheduling preserved in proposed patch')
r=json.loads((H/'result.json').read_text());a=json.loads((H/'account-result.json').read_text())
for obj in [r,a]:ck(obj['status']=='PASS','complete experiment');ck(obj['full_stack_proofs']==obj['model_passes']==obj['proved_positions']==0,'no model credit')
ck(r['eq_cases']==13*9*2,'Eq fixture count');ck(r['priv_table_cases']==10*5*3*4,'table count');ck(r['fresh_mask_cases']==r['priv_table_cases'],'one fresh mask per table case');ck(r['negative_controls']==8,'controls')
for x in r['bench']:
 ck(len(x['native_ns'])==len(x['candidate_ns'])==3,'raw diagnostic samples');ck(x['entries']==1<<x['log'],'dimensions')
for c in json.loads((H/'costs.json').read_text()):
 for key in ['fixed_eq','mask_eval_eq','pcs_data_row_eq_partial']:
  d=c[key];hist={int(k):v for k,v in d['log_histogram'].items()};nodes=sum(v*((1<<k)-1)for k,v in hist.items());dims=sum(k*v for k,v in hist.items())
  ck(nodes==d['removed_fp2_products'],'independent histogram nodes');ck(2*nodes==d['native_fp2_products']and nodes==d['candidate_fp2_products'],'product delta');ck(nodes-dims==d['net_added_fp2_subtractions'],'sub cost');ck(5*nodes==d['removed_base_products'],'source base product expansion')
prior=json.loads((H/'startup/prior-hypotheses.json').read_text());now=json.loads((H/'hypotheses.json').read_text());ck(now[:-1]==prior and len(now)==62,'prior hypotheses exact')
old=(H/'startup/sources.jsonl').read_bytes();allbytes=(H.parent.parent/'sources.jsonl').read_bytes();ck(allbytes.startswith(old),'prior sources unchanged');ck(len(allbytes.splitlines())==971,'seven new records')
for row in [json.loads(x)for x in (H/'sources-cycle.jsonl').read_text().splitlines()]:
 for k in ['access_date','publication_date','verified_update_date','url','implementation_license','inspected_commit_id']:ck(k in row,'source schema')
 ck(row['external_execution']==row['reproduced_performance']==False,'no external performance adoption')
for n in ['compile','probe','account']:
 e=json.loads((H/(n+'-execution.json')).read_text());ck(e['exit_code']==0 and e['elapsed_s']<60,'bounded successful stage');ck(e['one_cpu_affinity']and e['address_space_limit_bytes']<=512*1024**2,'resources');ck(e['gpu']==e['cargo']==False,'no heavy device/build')
owner=[]
for row in json.loads((H/'required-reading-index.json').read_text()):
 if '/docs/'in row['path']or row['path'].endswith('/CLAUDE.md'):
  current=sha(Path(row['path']).read_bytes());owner.append(dict(path=row['path'],start_sha256=row['sha256'],current_sha256=current,unchanged=current==row['sha256']));ck(current==row['sha256'],'owner document unchanged')
(H/'owner-document-recheck.json').write_text(json.dumps(owner,indent=2)+'\n')
result=dict(status='PASS',checks=checks,native_pins=len(pins),extracted_native_functions=3,source_records=971,all_prior_hypotheses_preserved=True,elapsed_s=time.monotonic()-start,max_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,external_review=False,full_stack_proofs=0)
(H/'audit-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))

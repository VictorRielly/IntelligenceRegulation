from pathlib import Path
import hashlib,json
D=Path(__file__).resolve().parent;checks=0
def check(x):
 global checks
 assert x;checks+=1
def extract(s,needle):
 at=s.index(needle);start=s.rfind('\n',0,at)+1;br=s.index('{',at);end=br+1;depth=1
 while depth:depth+=(s[end]=='{')-(s[end]=='}');end+=1
 return s[start:end]+'\n'
for manifest in ['native-pins.json','prior-pins.json']:
 for x in json.loads((D/manifest).read_text()):
  check(hashlib.sha256((D/x['snapshot']).read_bytes()).hexdigest()==x['sha256'])
  if not x.get('mutable_owner_report'):check(hashlib.sha256(Path(x['path']).read_bytes()).hexdigest()==x['sha256'])
pcs=(D/'native/zkp-core/src/pcs.rs').read_text();gpu=(D/'native/hashline/src/gpu/kernels.cu').read_text();adapter=(D/'native/hashline/src/gpu/cuda.rs').read_text()
host=extract(pcs,'fn fold_rows_host(')
check((D/'native_host.rs').read_text()==host.replace('.into_par_iter()','.into_iter()'))
old=extract(gpu,'extern "C" __global__ void k_fold_rows(');new=(D/'candidate_kernel.cu').read_text().split('\n',1)[1]
check((D/'baseline_kernel.cu').read_text()=='#define FR_MAX_K 4\n'+old)
check((D/'kernels_host.cpp.inc').read_text()=='#define FR_MAX_K 4\n'+old.replace('void k_fold_rows(','void baseline_fold_rows(')+new.replace('void k_fold_rows(','void candidate_fold_rows('))
check('FR_MAX_K 4'in gpu);check('rhos.chunks(4)'in extract(pcs,'fn fold_rows_multi_zk<'));check('k >= 1 && k <= 4'in extract(adapter,'pub fn dev_fold_rows('))
# Replay exact generated unified diff in memory, rejecting misplaced hunks.
original_lines=gpu.splitlines(True);patch=(D/'native-public-rho-skip.patch').read_text().splitlines(True);out=[];pos=0
import re
i=2
while i<len(patch):
 m=re.match(r'@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@',patch[i]);check(m is not None);at=int(m[1])-1;out.extend(original_lines[pos:at]);pos=at;i+=1
 while i<len(patch)and not patch[i].startswith('@@'):
  line=patch[i];tag=line[0];val=line[1:]
  if tag in ' -':check(original_lines[pos]==val);pos+=1
  if tag in ' +':out.append(val)
  i+=1
out.extend(original_lines[pos:]);patched=''.join(out)
check(patched==gpu.replace(old,new));check(patched.replace(new,old)==gpu)
check('if (!any) continue;'in new);check('rw[g].c0 != 0ULL || rw[g].c1 != 0ULL'in new)
check(new.count('data[(size_t)i * n + j]')==1)
for st in ['prepare','compile','probe','compile-cpp','probe-cpp','account']:
 x=json.loads((D/(st+'-execution.json')).read_text());check(x['exit_code']==0);check(x['elapsed_s']<=60);check(x['max_rss_kib']<=512*1024);check(x['address_space_bytes']<=512*1024**2);check(x['gpu']is False)
r=json.loads((D/'result.json').read_text());c=json.loads((D/'cpp-result.json').read_text());a=json.loads((D/'account-result.json').read_text())
for x in [r,c,a]:check(x['status']=='PASS')
check(r['fixtures']==1120);check(r['negative_controls']==8);check(r['matched_emulator_panics']==4);check(c['fixtures']==288);check(c['controls']==3)
check(r['full_stack_proofs']==r['model_passes']==r['proved_positions']==0)
for x in a['profile_accounting']:
 for y in x['cases']:
  check(y['dispatch_supported']==(y['batch']<=4))
  check(y['rho_h2d_bytes']==x['rhos']*x['rows']*16)
  check(y['output_d2h_bytes']==x['rhos']*x['cols']*16)
check(all(json.loads((D/'extraction.json').read_text())['r14_checkpoint_seam'].values()))
result=dict(status='PASS',checks=checks,source_pins=13,prior_pins=2,patch_replayed_in_memory=True,production_patch_applied=False,independent_external_review=False)
(D/'audit-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))

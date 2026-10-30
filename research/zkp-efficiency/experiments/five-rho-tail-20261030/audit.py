from pathlib import Path
import json,hashlib,math,re
D=Path(__file__).resolve().parent
P=2**64-2**32+1
checks=0
def check(x):
 global checks
 assert x
 checks+=1
rust=json.loads((D/'probe.stdout.log').read_text());cpp=json.loads((D/'probe-cpp.stdout.log').read_text())
check(rust['status']==cpp['status']=='PASS')
check(rust['full_stack_proofs']==rust['passes']==rust['positions']==0)
vector_limbs=0
for line in (D/'cpp-public-vectors.jsonl').read_text().splitlines():
 x=json.loads(line);r,n,k=x['rows'],x['n'],x['k'];want=[]
 # Arbitrary-precision integer sum, one reduction after the full dot product.
 for g in range(k):
  for j in range(n):
   for limb in range(2):
    want.append(sum(x['rho'][2*(g*r+i)+limb]*x['data'][i*n+j] for i in range(r))%P)
 check(len(want)==len(x['out']))
 for a,b in zip(want,x['out']):check(a==b);vector_limbs+=1
 # A dropped imaginary output must be caught on the imaginary-only fixtures.
 if x['mode']==2 and k==5:
  bad=x['out'].copy();bad[1::2]=[0]*(len(bad)//2);check(bad!=want)
def plan(k):
 if k<=4:return [k] if k else []
 # Independent recurrence looking ahead from the beginning.
 if k==5:return [5]
 return [4]+plan(k-4)
for k in range(130):
 v=plan(k);check(sum(v)==k);check(all(1<=a<=4 for a in v[:-1]));check(not v or 1<=v[-1]<=5)
 count=(k+3)//4-int(k>=5 and k%4==1);check(len(v)==count)
 # Explicit offset/order coverage; no duplicate or omitted output index.
 spans=[];pos=0
 for w in v:spans.extend(range(pos,pos+w));pos+=w
 check(spans==list(range(k)))
profiles=json.loads((D.parent/'r14-fold-geometry-20261029/result.json').read_text())['profiles']
study=[]
for p in profiles:
 if 'conditional_generic_group_fold_model' not in p:continue
 parts=[]
 for c in p['conditional_generic_group_fold_model']:
  rows,n,k=c['rows'],p['n'],c['rhos_including_fresh_proximity'];a=c['batch_widths'];b=plan(k)
  check(sum(a)==sum(b)==k);check(len(a)-len(b)==int(k>=5 and k%4==1))
  parts.append(dict(role=c['cm'],rows=rows,n=n,rho_count=k,baseline_widths=a,candidate_widths=b,
   baseline_matrix_source_B=len(a)*rows*n*8,candidate_matrix_source_B=len(b)*rows*n*8,
   avoided_matrix_source_B=(len(a)-len(b))*rows*n*8,
   unchanged_rho_source_B=k*rows*n*16,unchanged_base_multiplies=2*k*rows*n,
   unchanged_rho_h2d_B=k*rows*16,unchanged_output_d2h_B=k*n*16,
   baseline_largest_rho_output_device_B=max(a)*(rows+n)*16,
   candidate_largest_rho_output_device_B=max(b)*(rows+n)*16))
 a=sum(v['baseline_matrix_source_B'] for v in parts);b=sum(v['candidate_matrix_source_B'] for v in parts)
 check(a>b)
 study.append(dict(t=p['t'],dd=p['dd'],fe=p['fe'],scope='historical generic groups in standalone core with two external endpoints; not current grouping or full run',parts=parts,
  baseline_matrix_source_B=a,candidate_matrix_source_B=b,avoided_matrix_source_B=a-b,
  matrix_source_reduction=(a-b)/a,all_matrix_source_only_speedup_bound=a/b,
  warning='source operands, not DRAM traffic or runtime; rho accesses are warp broadcasts/cache candidates; all other work remains'))
native_pins=json.loads((D/'native-pins.json').read_text());drift=[]
for p in native_pins:
 b=Path(p['path']).read_bytes();equal=hashlib.sha256(b).hexdigest()==p['sha256'];check(equal)
 if p.get('matches_prior') is False:drift.append(p['path'])
check(len(drift)==1 and drift[0].endswith('CURRENT_DEV_STATE.json'))
pcs=(D/'native/zkp-core/src/pcs.rs').read_text();cu=(D/'native/hashline/src/gpu/cuda.rs').read_text()
check('rhos.chunks(4)' in pcs);check('k >= 1 && k <= 4' in cu)
check('let prox_rho = tr.challenge_fp2_vec(rows);\n    rhos.push(prox_rho);' in pcs)
check((D/'candidate_kernel.cu').read_text().replace('#define FR_MAX_K 5','#define FR_MAX_K 4').replace('k_fold_rows_tail5(','k_fold_rows(')==(D/'baseline_kernel.cu').read_text())
for stage in ['prepare','compile','probe','compile-cpp','probe-cpp']:
 x=json.loads((D/(stage+'-execution.json')).read_text());check(x['exit_code']==0);check(x['wall_s']<60);check(x['max_rss_kib']<512*1024)
# Old exact-SpMV floating/deferred-reduction screen: one full-size native
# Goldilocks product already exceeds exact integer capacity of binary64.
check(float(P-2)!=P-2);check(float((P-1)**2)!=(P-1)**2);check(2*(P-1)**2>2**128-1)
field_filter=dict(binary64_exact_integer_bits=53,full_goldilocks_product_bits=((P-1)**2).bit_length(),two_max_products_exceed_u128=True,
 conclusion='2010 small-modulus floating/deferred-reduction implementation is not a native full-width replacement; limb splitting/carry-aware accumulation requires separate exact proof and cost')
(D/'field-filter.json').write_text(json.dumps(field_filter,indent=2)+'\n')
(D/'cost-study.json').write_text(json.dumps(study,indent=2)+'\n')
result=dict(status='PASS',python_assertions=checks,independent_python_scalar_limb_outputs=vector_limbs,rust=rust,cpp=cpp,
 rust_controls_breakdown=dict(public_planner_cases=130,shape_refusals=3,fault_detection_controls=8),
 native_source_pins=len(native_pins),owner_delta_since_prior=drift,
 exactness_scope='synthetic native scalar field/host fold, extracted kernel control flow, arbitrary-precision independent reference; no CUDA arithmetic/ABI/registers or native PCS proofs',
 new_full_stack_proofs=0,new_passes=0,new_proved_positions=0)
(D/'result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))

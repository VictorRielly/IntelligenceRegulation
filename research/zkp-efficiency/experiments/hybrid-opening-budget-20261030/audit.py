from pathlib import Path
import json,itertools,hashlib
D=Path(__file__).resolve().parent
P=2**64-2**32+1
M=2**64-1
assertions=0
def check(v):
 global assertions
 assertions+=1
 assert v
vectors=[json.loads(s) for s in (D/'public-vectors.jsonl').read_text().splitlines()]
limbs=0
for v in vectors:
 rows,n,q,k=[v[x] for x in ['rows','n','q','k']]
 for g in range(k):
  want=[]
  # Python arbitrary-size sum, independent of Rust iterative modular reduction.
  for data,width in [(v['data'],n),(v['pads'],q)]:
   for j in range(width):
    for c in range(2):want.append(sum(v['rho'][g][2*i+c]*data[i*width+j] for i in range(rows))%P)
  check(want==v['out'][g]);limbs+=len(want)
 # Explicit sensitivity controls of the independently reconstructed public vectors.
 if v['m']==0 and k>4:
  check(v['out'][0]!=v['out'][4])
plans=[json.loads(s) for s in (D/'public-plans.jsonl').read_text().splitlines()]
for v in plans:
 rows,n,k,budget=[v[x] for x in ['rows','n','k','budget']]
 cap=min(4,k);serial_r=2*cap*rows;out=2*cap*n;serial=8*(serial_r+out);hybrid_r=2*k*rows;hybrid=8*(hybrid_r+out)
 valid=n>0 and serial_r<=M and out<=M and serial<=min(M,budget)
 check(('error' not in v)==valid)
 if not valid:continue
 use_full=hybrid_r<=M and hybrid<=min(M,budget)
 check(v['mode']==('Hybrid' if use_full else 'Serial'))
 check(v['rho_limbs']==(hybrid_r if use_full else serial_r));check(v['out_limbs']==out);check(v['scratch']==(hybrid if use_full else serial));check(v['scratch']<=budget)
 if k<=57:
  seen=[]
  for start in range(0,k,4):
   batch=list(range(start,min(start+4,k)));seen.extend(batch)
   rho_off=2*rows*start if use_full else 0
   check(rho_off+2*len(batch)*rows<=v['rho_limbs'])
   check(2*len(batch)*n<=v['out_limbs'])
  check(seen==list(range(k)))

# Every permutation of independent H2D destinations is safe. Reusing the
# same destination in one unordered batch gives schedule-dependent results.
def batched(copies):
 results=[]
 for order in itertools.permutations(range(len(copies))):
  dst=[None]*4
  for i in order:
   off,source=copies[i];dst[off:off+len(source)]=source
  results.append(dst)
 return results
distinct=batched([(0,[10,11]),(2,[20,21])]);alias=batched([(0,[10,11]),(0,[20,21])])
check(all(x==[10,11,20,21] for x in distinct));check(alias[0]!=alias[1])

costs=[]
historical=[('A_nonDD',3517,16384,57),('H_nonDD',3272,16384,12),('A_DD',3395,16384,59),('H_DD',3116,16384,13)]
for label,rows,n,k in historical:
 b=(k+3)//4;common={'kernel_launches':b,'h2d_payload_bytes':16*k*rows,'d2h_payload_bytes':16*k*n,'matrix_operand_bytes':8*b*rows*n}
 modes={}
 for name in ['baseline','serial','hybrid','full']:
  scratch=16*(min(k,4)*(rows+n) if name in ['baseline','serial'] else k*(rows+n) if name=='full' else k*rows+min(k,4)*n)
  modes[name]={**common,'device_scratch_requested_bytes':scratch,'rho_host_flat_requested_bytes':16*rows*(k if name in ['hybrid','full'] else min(k,4)),'allocation_submissions':2*b if name=='baseline' else 2,'h2d_submissions':1 if name in ['hybrid','full'] else b,'d2h_submissions':1 if name=='full' else b}
 check(modes['serial']['device_scratch_requested_bytes']<=modes['hybrid']['device_scratch_requested_bytes']<=modes['full']['device_scratch_requested_bytes'])
 costs.append({'label':label,'rows':rows,'columns':n,'rhos_including_proximity':k,'context':128,'historical_standalone_fe9_only':True,'modes':modes})
(D/'cost-study.json').write_text(json.dumps({'scope':'Conditional historical R14 T128 standalone fe9 groups; not current full run or 8B; requested bytes exclude allocator rounding and matrix/host output coexistence','cases':costs,'ceiling':'N/(T-C_removed_exclusive+A_added), exclusive costs unknown'},indent=2)+'\n')
rust=json.loads((D/'probe.stdout.log').read_text())
result={'status':'PASS','rust':rust,'python_assertions':assertions,'python_bigint_vectors':len(vectors),'python_bigint_limbs':limbs,'rust_plans_checked_by_bigint_reference':len(plans),'batched_copy_negative_control':{'nonoverlapping_permutations':len(distinct),'aliasing_permutations':len(alias),'alias_results':alias},'scope':'Synthetic synchronous CPU-buffer model and exact native scalar host body; no CUDA/PCS/transcript/receipt/privacy acceptance','full_stack_proofs':0,'passes':0,'positions':0}
(D/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))

"""Independent interval model of public H descriptors and chunk4 unions."""
from pathlib import Path
import json,platform,hashlib,itertools,functools
D=Path(__file__).resolve().parent
r=json.loads((D/'result.json').read_text());meta=json.loads((D/'source-metadata.json').read_text())
prior=json.loads((D/'startup/prior-census-result.json').read_text());checks=0;out=[]
def check(x):
 global checks
 assert x
 checks+=1
for native,geometry in zip(r['profiles'],meta):
 n=1<<geometry['log_cols'];logs=geometry['logs'];hs=geometry['helpers'];dd=geometry['dd']
 # Independent H ordered-domain inventory, offset summation, and H slot map.
 inventory=[]
 for dom in ['L','D','Q','Kv','S','F']+(['Dd'] if dd else [])+['Tab']:
  count=4 if dom=='Tab' else hs[dom]+(1+int(dd) if dom=='S' else 1 if dom in ['F','Dd'] else 0)
  inventory.extend([dom]*count)
 offsets=[];base=0
 for dom in inventory:
  words=1<<logs[dom];offsets.append((base,base+words));base+=2*words
 check(base//n==native['data_rows']==geometry['expected_data']);check(base%n==0)
 slot_dom={3:'L',14:'D',15:'Q',16:'Kv',17:'S',18:'F',19:'Tab',20:'Tab',23:'Dd'}
 schedule=[]
 for slot in sorted(slot_dom):
  dom=slot_dom[slot]
  if dom=='Dd' and not dd:continue
  planes=[i for i,d in enumerate(inventory) if d==dom]
  if slot==19:planes=planes[:3]
  if slot==20:planes=planes[-1:]
  schedule.extend((slot,plane) for plane in planes)
 check(len(schedule)==native['sites']==geometry['expected_sites']);check(sorted(p for _,p in schedule)==list(range(len(inventory))))
 sets={};expected=[]
 for site,(slot,p) in enumerate(schedule):
  dom=inventory[p];re,im=offsets[p];mask=base//n+2*site;ls=logs[dom]
  expected.append([slot,ls,re,im,mask]);check(native['descriptors'][site]==expected[-1])
  s=sets.setdefault(slot,set());s.update(range(re//n,(re+(1<<ls))//n));s.update(range(im//n,(im+(1<<ls))//n));s.update([mask,mask+1])
 check(native['rows']==geometry['expected_rows']==base//n+2*len(schedule)+2)
 union=set();lengthsum=0
 for s in sets.values():check(not union&s);union|=s;lengthsum+=len(s)
 check(union==set(range(native['rows']-2)));check(lengthsum==native['rows']-2)
 support=list(sets.values())+[set(range(base//n)),set(range(native['rows']))]
 check([len(s) for s in support]==native['rho_support_sizes']);check([len(s) for s in support]==native['numeric_nonzeros'])
 chunks=[len(set().union(*support[j:j+4])) for j in range(0,len(support),4)]
 check(chunks==native['chunk_union_visits']);check(sum(chunks)==native['structural_visits'])
 # Exhaustive DP over all legal fixed-three-batch partitions. The physical
 # permutation is only a plan; outputs must be restored before transcript use.
 bits=[sum(1<<r for r in s) for s in support];calls=[0]
 @functools.lru_cache(None)
 def optimal(mask,batches):
  calls[0]+=1
  if not mask:return (0,()) if batches==0 else (10**12,())
  if batches==0 or mask.bit_count()>4*batches or mask.bit_count()<batches:return (10**12,())
  first=(mask&-mask).bit_length()-1;rest=[i for i in range(len(bits)) if mask>>i&1 and i!=first];best=(10**12,())
  for count in range(4):
   for extra in itertools.combinations(rest,count):
    batch=(first,)+extra;sub=sum(1<<i for i in batch);u=0
    for i in batch:u|=bits[i]
    cost,tail=optimal(mask^sub,batches-1);candidate=(u.bit_count()+cost,(batch,)+tail)
    if candidate<best:best=candidate
  return best
 best,partition=optimal((1<<len(bits))-1,3)
 partition=tuple(sorted(partition,key=lambda b:-len(b)))
 flat=[i for b in partition for i in b];check(sorted(flat)==list(range(len(bits))));check(all(0<len(b)<=4 for b in partition))
 check(all(len(b)==4 for b in partition[:-1]));check([tuple(flat[i:i+4]) for i in range(0,len(flat),4)]==list(partition))
 check(best==sum(len(set().union(*(support[i] for i in b))) for b in partition));check(best<=sum(chunks))
 # A second constructive result: put sum+prox with the two largest disjoint
 # eval supports, keeping six/seven remaining supports in two <=4 batches.
 largest=sorted(range(len(support)-2),key=lambda i:-len(support[i]))[:2]
 constructive=native['rows']+native['rows']-2-sum(len(support[i]) for i in largest)
 check(best==constructive)
 # Generic noDD: eight disjoint eval groups, sum/prox last. DD: ninth
 # evaluation group shares the sum/prox batch and is absorbed in its scan.
 formula=2*native['rows']-2-(len(support[-3]) if dd else 0)
 check(formula==sum(chunks));check(native['baseline_visits']==3*native['rows'])
 baseline=native['baseline_visits']*n*8;upper=sum(chunks)*n*8
 check(baseline==native['baseline_bytes']);check(upper==native['structural_bytes_upper'])
 pa=next(x for x in prior['profiles'] if x['label']==('DD' if dd else 'nonDD')+'-A')
 ph=next(x for x in prior['profiles'] if x['label']==('DD' if dd else 'nonDD')+'-H')
 check(baseline==ph['baseline_logical_matrix_bytes']);check(upper<=ph['mask_only_logical_matrix_byte_upper_bound'])
 ab=pa['baseline_logical_matrix_bytes'];askip=pa['guaranteed_skipped_row_visits']*n*8
 out.append(dict(dd=dd,context=128,commitment='H',baseline_bytes=baseline,structural_upper_bytes=upper,guaranteed_skipped_bytes=baseline-upper,guaranteed_logical_matrix_read_reduction=(baseline-upper)/baseline,chunk_union_visits=chunks,structural_fp2_base_mac_upper=sum(map(len,support))*n,baseline_fp2_base_macs=len(support)*native['rows']*n,combined_A_prior_conservative_H_current_baseline_bytes=ab+baseline,combined_A_prior_conservative_H_current_skipped_bytes=askip+baseline-upper,combined_A_prior_conservative_H_current_reduction=(askip+baseline-upper)/(ab+baseline),exact_three_batch_support_optimum_visits=best,exact_partition=partition,partition_dp_states=calls[0],packed_structural_upper_bytes=best*n*8,packed_reduction_from_dense_baseline=(baseline-best*n*8)/baseline,largest_evaluation_groups=largest,native_define_executed=False,native_FS_executed=False,device_test=False,scope='frozen R13 source-derived H schedule and extracted offsets/builders, synthetic generic challenges. Structural support upper bound; no physical DRAM/time or R14 assertion.'))
# Edge-point grouping is expressly not frozen at the generic group count:
# source fixtures use independent random slot points; small fixtures cover
# coinciding zero/one tails and random tails through native grouping.
check(r['fixtures']==20);check(r['full_stack_proofs']==0)
(D/'census-result.json').write_text(json.dumps(dict(status='PASS',checks=checks,profiles=out,seed=r['seed'],full_stack_proofs=0,model_passes=0,proved_positions=0,end_to_end_ceiling='N/(T-C_removed_exclusive+A_added). Native exclusive H-rowfold fraction unknown; free deletion<=1/(1-f).'),indent=2)+'\n')
cpu=next((s.split(':',1)[1].strip() for s in Path('/proc/cpuinfo').read_text().splitlines() if s.startswith('model name')),'unknown')
(D/'hardware.json').write_text(json.dumps(dict(cpu=cpu,os=platform.platform(),python=platform.python_version(),affinity=1,worker_threads=1,gpu_jobs=0,actual_model_context=None,model_passes=0,modeled_context=128),indent=2)+'\n')
print(json.dumps(dict(status='PASS',checks=checks,profiles=out),indent=2))

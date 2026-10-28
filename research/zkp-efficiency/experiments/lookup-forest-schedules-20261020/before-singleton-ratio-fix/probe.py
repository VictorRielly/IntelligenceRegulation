from pathlib import Path
import json,time,resource,random,hashlib,os,platform
from schedule import plan,serve,combine
from reference import layers,direct,enumerate_cost
HERE=Path(__file__).resolve().parent;start=time.monotonic();checks=0;controls=[]
def check(x):
 global checks
 assert x
 checks+=1
def control(name,x):
 check(x);controls.append(name)
old=json.loads((HERE.parent/'lookup-helper-census-20261020/census.json').read_text())
rows=[]
for row in old:
 if row['norm_window']!=32 or row['f_e']!=9:continue
 sizes=[x['size'] for x in row['domains'] for j in range(x['u8_columns'])]+[256]
 full=32*(2*sum(sizes)-1)
 check(full==row['topology_costs']['exact_column_forest_all_nodes_bytes'])
 plans=[]
 for b in [0,4,8,12,16,32]:
  a=plan(sizes,b);ref=enumerate_cost(sizes,b)
  for key,value in ref.items():check(a[key]==value)
  check(a['original_ordered_A_column_links']==row['topology_costs']['ordered_column_links'])
  plans.append(a)
 initial=sum(sizes)-1
 # First reduce all roots, then rebuild one complete column at a time.
 rebuild=initial+sum(n-1 for n in sizes)
 one=dict(arithmetic_peak_upper_bytes=32*(2*len(sizes)-1+max(2*n-1 for n in sizes)+max(n.bit_length() for n in sizes)),
   total_internal_nodes=rebuild,internal_work_ratio=rebuild/initial,
   leaf_generations=2*sum(sizes),leaf_generation_ratio=2,
   exclusions=plans[0]['exclusions'])
 rows.append(dict(model=row['model'],T=row['T'],dd=row['dd'],scope=row['scope'],
   original_U8_helper_data_bytes=row['u8_helper_data_bytes'],
   full_forest_arithmetic_bytes=full,column_count=len(sizes)-1,
   one_column_full_rebuild=one,cut_recompute=plans))
rng=random.Random(20261020104);p=65537;cases=0
for h in range(0,8):
 for trial in range(4):
  leaves=[(rng.randrange(p),rng.randrange(1,p)) for j in range(2**h)]
  ref=layers(leaves,p);want=direct(leaves,p)
  for b in sorted(set([0,1,3,h])):
   root,out,counter=serve(leaves.__getitem__,len(leaves),b,p)
   check(root==ref[0][0]);check(out==ref[1:]);check(root[0]*pow(root[1],-1,p)%p==want)
   cost=plan([len(leaves)],b)
   check(counter['internal']==cost['total_internal_nodes']);check(counter['leaves']==cost['leaf_generations'])
   cases+=1
# Ordered leaf links are REQUIRED: symmetric roots do not bind sites/order.
leaves=[(1,17),(1,23),(1,31),(1,43)]
permuted=[leaves[1],leaves[0],leaves[2],leaves[3]]
control('wrong_site_survives_root_only_check',layers(leaves,p)[0]==layers(permuted,p)[0])
tag=lambda v:hashlib.sha256(json.dumps(list(enumerate(v))).encode()).hexdigest()
control('ordered_leaf_binding_detects_wrong_site',tag(leaves)!=tag(permuted))
control('drop_multiplicity',direct([(3,17),(2,23)],p)!=direct([(1,17),(1,23)],p))
control('duplicate_global_histogram',direct([(3,17),(2,23)],p)!=direct([(6,17),(4,23)],p))
bad=False
try:direct([(0,0),(0,7)],p)
except ValueError:bad=True
control('zero_denominator_even_if_multiplicity_zero',bad)
control('degenerate_fraction_root_can_erase_nonzero_refusal',layers([(0,0),(0,7)],p)[0]==[(0,0)])
control('fresh_challenge_changes_cached_denominators',pow(19-3,-1,p)!=pow(20-3,-1,p))
control('stack_all_floor_width_is_not_geometric',sum(2**t for t in range(22))<22*2**21)
control('cross_field_does_not_authorize_native_privacy',p!=2**64-2**32+1)
result=dict(seed=20261020104,checks=checks,tiny_schedule_cases=cases,fixtures=len(rows),negative_controls=controls,
 elapsed_s=time.monotonic()-start,maxrss_KiB=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
 scope='Integer arithmetic-layer lifetime/work upper bounds and tiny synthetic F65537 equality/refusal controls. No actual GKR/mask/PCS/native proof.',
 full_stack=dict(proofs=0,passes=0,positions=0,context_length=None,device=None,witness_s=None,proof_s=None,serialization_s=None,verification_s=None,startup_s=None,startup_fraction=None,steady_rate=None,total_rate=None))
(HERE/'census.json').write_text(json.dumps(rows,indent=2)+'\n');(HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
(HERE/'hardware.json').write_text(json.dumps(dict(platform=platform.platform(),cpu=platform.processor(),affinity=list(os.sched_getaffinity(0)),threads=1,accelerator_invoked=False),indent=2)+'\n')
print(json.dumps(result,indent=2))

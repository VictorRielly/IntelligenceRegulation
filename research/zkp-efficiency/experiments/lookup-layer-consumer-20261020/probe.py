from pathlib import Path
import json,random,time,resource,hashlib,os,platform
from consumer import allocation_trace,serve,consume,reduce_at
from reference import tree,mle,direct_samples,cost,verify_arithmetic
HERE=Path(__file__).resolve().parent;start=time.monotonic();rng=random.Random(20261020105)
checks=0;cases=0;layer_cases=0;controls=[]
def check(ok):
    global checks
    assert ok
    checks+=1
def control(name,ok):check(ok);controls.append(name)
rows=[]
old=json.loads((HERE.parent/'lookup-helper-census-20261020/census.json').read_text())
for row in old:
    if row['norm_window']!=32 or row['f_e']!=9:continue
    sizes=[d['size'] for d in row['domains'] for j in range(d['u8_columns'])]+[256]
    plans=[]
    for mode in ['forest','column']:
        for b in [0,4,8,12,16,32]:
            a=allocation_trace(sizes,b,mode);want=cost(sizes,b,mode)
            check((a['modeled_peak_bytes'],a['tree_internal_nodes'],a['leaf_generations'])==want)
            a.pop('events');plans.append(a)
    # Exhaustive public cut frontier; per-column b common across heterogeneous trees.
    candidates=[]
    for b in range(max(sizes).bit_length()):
        a=allocation_trace(sizes,b,'column');a.pop('events')
        candidates.append(a)
    frontier=[a for a in candidates if not any(x['modeled_peak_bytes']<=a['modeled_peak_bytes'] and x['tree_internal_nodes']<=a['tree_internal_nodes'] and (x['modeled_peak_bytes']<a['modeled_peak_bytes'] or x['tree_internal_nodes']<a['tree_internal_nodes']) for x in candidates)]
    rows.append(dict(model=row['model'],T=row['T'],dd=row['dd'],scope=row['scope'],
      sizes=sizes,old_U8_helper_bytes=row['u8_helper_data_bytes'],plans=plans,
      column_cut_candidates=frontier,consumer_floor_if_regenerated_bytes=72*max(sizes),
      full_forest_bytes=32*(2*sum(sizes)-1)))
for h in range(1,7):
    for trial in range(3):
        leaves=[(rng.randrange(1,8),rng.randrange(1,65537)) for j in range(2**h)]
        ref=tree(leaves,65537)
        for b in sorted({0,2,h}):
            for depth,child,root,counter in serve(leaves.__getitem__,len(leaves),b,65537):
                before=hashlib.sha256(repr(child).encode()).hexdigest()
                check(child==ref[depth]);check(root==ref[0][0])
                k=depth-1;point=[rng.randrange(65537) for j in range(k)]
                challenges=[rng.randrange(65537) for j in range(k)];lam=rng.randrange(1,65537)
                claim,samples,terminal,planes=consume(child,point,challenges,lam,65537)
                want=sum(mle([z[c] for z in ref[depth-1]],point,65537)*(1 if c==0 else lam) for c in range(2))%65537
                check(claim==want)
                rs,rt=direct_samples(child,point,challenges,lam,65537)
                check(samples==rs);check(terminal==rt)
                check(verify_arithmetic(claim,samples,terminal,challenges,65537))
                check(before==hashlib.sha256(repr(child).encode()).hexdigest())
                layer_cases+=1
            # Tiny service excludes the separate all-roots pass in column plan.
            model=allocation_trace([len(leaves)],b,'forest')
            check(counter['internal']==model['tree_internal_nodes']);check(counter['leaves']==model['leaf_generations'])
            cases+=1
p=65537;leaves=[(1,17),(1,23),(1,31),(1,43),(1,47),(1,59),(1,61),(1,71)]
control('wrong_site_permutation_preserves_fraction_root',tree(leaves,p)[0]==tree([leaves[1],leaves[0]]+leaves[2:],p)[0])
control('ordered_leaf_digest_detects_permutation',hashlib.sha256(repr(leaves).encode()).digest()!=hashlib.sha256(repr([leaves[1],leaves[0]]+leaves[2:]).encode()).digest())
bad=False
try:reduce_at([(0,0),(0,7)].__getitem__,0,2,p,dict(leaves=0,internal=0))
except ValueError:bad=True
control('zero_denominator_refused_even_zero_multiplicity',bad)
control('fresh_challenges_prevent_denominator_reuse',pow(19-3,-1,p)!=pow(20-3,-1,p))
a=allocation_trace([1024,256],0,'column')
control('omitting_fold_capacity_understates_peak',a['modeled_peak_bytes']>32*(2*2-1)+32*1024+32*12)
old=allocation_trace([1024]*8,12,'forest');small=allocation_trace([1024]*8,12,'column')
control('per_column_cache_has_cost_not_free_reuse',small['tree_internal_nodes']>old['tree_internal_nodes'])
claim,rs,term,_=consume(leaves,[3,7],[11,13],17,p)
wrong=[list(x) for x in rs];wrong[0][2]=(wrong[0][2]+1)%p
control('altered_cubic_sample_rejected',not verify_arithmetic(claim,wrong,term,[11,13],p))
control('altered_terminal_rejected',not verify_arithmetic(claim,rs,(term+1)%p,[11,13],p))
control('wrong_equality_point_changes_claim',consume(leaves,[7,3],[11,13],17,p)[0]!=claim)
direct=lambda v:sum(a*pow(d,-1,p) for a,d in v)%p
control('duplicated_global_histogram_rejected',direct([(3,17),(2,23)])!=direct([(6,17),(4,23)]))
mut=list(leaves);mut[0]=(mut[0][0]+1,mut[0][1])
control('altered_multiplicity_changes_root_value',tree(mut,p)[0]!=tree(leaves,p)[0])
control('native_field_and_privacy_not_certified',p!=2**64-2**32+1)
result=dict(seed=20261020105,checks=checks,fixtures=len(rows),tiny_column_cases=cases,tiny_layer_consumers=layer_cases,
 negative_controls=controls,elapsed_s=time.monotonic()-start,maxrss_KiB=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
 scope='Explicit chosen immutable-child/five-plane consumer. Symbolic Fp2 bytes plus tiny F65537 cubic fold arithmetic, not native GKR or proof.',
 full_stack=dict(proofs=0,passes=0,positions=0,context_length=None,device=None,witness_s=None,proof_s=None,serialization_s=None,verification_s=None,startup_s=None,startup_fraction=None,steady_rate=None,total_rate=None))
(HERE/'census.json').write_text(json.dumps(rows,indent=2)+'\n')
(HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
(HERE/'hardware.json').write_text(json.dumps(dict(platform=platform.platform(),cpu=platform.processor(),affinity=list(os.sched_getaffinity(0)),threads=1,accelerator_invoked=False),indent=2)+'\n')
print(json.dumps(result,indent=2))

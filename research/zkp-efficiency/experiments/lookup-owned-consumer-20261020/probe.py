from pathlib import Path
import importlib.util,json,random,time,resource,hashlib,os,platform
from owned import serve,consume,OwnedPlanes,allocation_trace,reduce_at
HERE=Path(__file__).resolve().parent;OLD=HERE.parent/'lookup-layer-consumer-20261020'
def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
prior=load('prior_consumer',OLD/'consumer.py');ref=load('independent_original_mle',OLD/'reference.py')
start=time.monotonic();rng=random.Random(20261020106);checks=0;cases=0;layers=0;controls=[]
def check(x):
    global checks
    assert x
    checks+=1
def control(name,x):check(x);controls.append(name)
p=65537
for h in range(1,7):
    for trial in range(4):
        leaves=tuple((rng.randrange(8),rng.randrange(1,p)) for _ in range(1<<h))
        original=repr(leaves);tree=ref.tree(leaves,p)
        for b in sorted({0,2,h}):
            access=[]
            def read(j):access.append(j);return leaves[j]
            gen=serve(read,len(leaves),b,p)
            for d,owner,cache,count in gen:
                frozen=repr(cache);raw=tree[d];w=len(raw)
                check(all(owner.planes[2*s+c]==[raw[2*j+s][c] for j in range(w//2)] for s in (0,1) for c in (0,1)))
                point=[rng.choice([0,1,rng.randrange(p)]) for _ in range(d-1)]
                rs=[rng.choice([0,1,rng.randrange(p)]) for _ in range(d-1)];lam=rng.randrange(p)
                got=consume(owner,point,rs,lam,p);old=prior.consume(raw,point,rs,lam,p)
                expected,terminal=ref.direct_samples(raw,point,rs,lam,p)
                check(got[:3]==old[:3]);check(got[1]==expected and got[2]==terminal)
                check(all(got[3][j][0]==old[3][j][0] for j in range(4)))
                check(ref.verify_arithmetic(*got[:3],rs,p));check(repr(cache)==frozen)
                check(repr(leaves)==original)
                used=False
                try:consume(owner,point,rs,lam,p)
                except ValueError:used=True
                check(used);layers+=1
            check(access==list(range(len(leaves)))*(count['leaves']//len(leaves)))
            model=allocation_trace([len(leaves)],b,'forest')
            check((count['internal'],count['leaves'],count['checkpoint_scalar_copies'])==(model['tree_internal_nodes'],model['leaf_generations'],model['checkpoint_scalar_copies']))
            cases+=1
leaves=tuple((j+1,17+j) for j in range(8))
for name,action in [
 ('borrowed_buffers_refused',lambda:OwnedPlanes([[1],[2],[3],[4]],'borrowed')),
 ('aliased_planes_refused',lambda:OwnedPlanes([[1]]*4,'regenerated')),
 ('zero_denominator_zero_multiplicity_refused',lambda:reduce_at([(0,0),(0,7)].__getitem__,0,2,p,dict(leaves=0,internal=0)))]:
    bad=False
    try:action()
    except ValueError:bad=True
    control(name,bad)
def run(point,rs):
    owner=next(x[1] for x in serve(leaves.__getitem__,8,0,p) if x[0]==3)
    return consume(owner,point,rs,17,p)
g=run([3,7],[11,13]);bad=[x[:] for x in g[1]];bad[0][2]=(bad[0][2]+1)%p
control('altered_round_rejected',not ref.verify_arithmetic(g[0],bad,g[2],[11,13],p))
control('altered_terminal_rejected',not ref.verify_arithmetic(g[0],g[1],(g[2]+1)%p,[11,13],p))
control('wrong_equality_order_detected',run([7,3],[11,13])[0]!=g[0])
control('zero_equality_factor_no_inverse',run([0,1],[1,0])[2]==0)
control('wrong_site_swap_survives_root',ref.tree(leaves,p)[0]==ref.tree((leaves[1],leaves[0])+leaves[2:],p)[0])
control('ordered_source_digest_detects_swap',hashlib.sha256(repr(leaves).encode()).digest()!=hashlib.sha256(repr((leaves[1],leaves[0])+leaves[2:]).encode()).digest())
control('fresh_challenge_changes_inverse',pow(19-3,-1,p)!=pow(20-3,-1,p))
control('histogram_duplication_changes_fraction',sum(a*pow(b,-1,p) for a,b in leaves)%p!=sum(2*a*pow(b,-1,p) for a,b in leaves)%p)
rows=[]
for old in json.loads((OLD/'census.json').read_text()):
    sizes=old['sizes'];plans=[];candidates=[]
    for mode in ('forest','column'):
        for b in range(max(sizes).bit_length()):
            x=allocation_trace(sizes,b,mode);base=prior.allocation_trace(sizes,b,mode)
            check(x['tree_internal_nodes']==base['tree_internal_nodes']);check(x['leaf_generations']==base['leaf_generations'])
            check(x['modeled_peak_bytes']<=base['modeled_peak_bytes'])
            x.pop('events');x['prior_peak_bytes']=base['modeled_peak_bytes'];candidates.append(x)
            if b in (0,4,8,12,16,max(sizes).bit_length()-1):plans.append(x)
    frontier=[x for x in candidates if not any(y['modeled_peak_bytes']<=x['modeled_peak_bytes'] and y['tree_internal_nodes']<=x['tree_internal_nodes'] and (y['modeled_peak_bytes']<x['modeled_peak_bytes'] or y['tree_internal_nodes']<x['tree_internal_nodes']) for y in candidates)]
    rows.append(dict(model=old['model'],T=old['T'],dd=old['dd'],scope=old['scope'],sizes=sizes,old_U8_helper_bytes=old['old_U8_helper_bytes'],plans=plans,frontier=frontier))
result=dict(seed=20261020106,status='PASS',checks=checks,tiny_column_services=cases,tiny_layer_consumers=layers,negative_controls=controls,
 elapsed_s=time.monotonic()-start,maxrss_KiB=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
 scope='Unmasked tiny F65537 arithmetic plus symbolic Fp2 capacity. No native GKR, masks, CFS, PCS, privacy, full proof or timing gain.',
 full_stack=dict(proofs=0,passes=0,positions=0,context_length=None,device=None,witness_s=None,proof_s=None,serialization_s=None,verification_s=None,startup_s=None,startup_fraction=None,steady_rate=None,total_rate=None))
(HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n');(HERE/'census.json').write_text(json.dumps(rows,indent=2)+'\n')
(HERE/'hardware.json').write_text(json.dumps(dict(platform=platform.platform(),affinity=list(os.sched_getaffinity(0)),threads=1,accelerator_invoked=False),indent=2)+'\n')
print(json.dumps(result,indent=2))

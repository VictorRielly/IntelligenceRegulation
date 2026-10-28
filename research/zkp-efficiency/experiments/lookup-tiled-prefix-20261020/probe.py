from pathlib import Path
import hashlib, json, random, resource, time
from tiled import execute, model, consumer, term
from prior_owned import OwnedPlanes, consume, allocation_trace
from reference import tree, direct_samples, mle, verify_arithmetic

HERE=Path(__file__).resolve().parent
start=time.monotonic(); rng=random.Random(20261020107); p=65537
checks=cases=0; controls=[]
def check(v):
    global checks
    assert v
    checks+=1
def control(name,v):
    check(v);controls.append(name)

for h in range(1,8):
    n=1<<h
    for rep in range(3):
        leaves=tuple((rng.randrange(p),rng.randrange(1,p)) for _ in range(n))
        frozen=hashlib.sha256(repr(leaves).encode()).hexdigest()
        levels=tree(leaves,p)
        for d in range(1,min(h,6)+1):
            raw=levels[d];m=len(raw)//2;k=d-1
            point=[rng.choice([0,1,rng.randrange(p)]) for _ in range(k)]
            challenges=[rng.choice([0,1,rng.randrange(p)]) for _ in range(k)]
            lam=rng.randrange(p)
            expected,terminal=direct_samples(raw,point,challenges,lam,p)
            planes=[[raw[2*j+s][c] for j in range(m)] for s,c in [(0,0),(0,1),(1,0),(1,1)]]
            old=consume(OwnedPlanes([v[:] for v in planes],'regenerated'),point,challenges,lam,p)
            check(old[1:3]==(expected,terminal))
            for q in range(min(k,4)+1):
                seen=[]
                def read(i):seen.append(i);return leaves[i]
                rows,end,final,stats=execute(read,n,d,point,challenges,q,lam,p)
                check(rows==expected and end==terminal)
                check(final==tuple(mle(v,challenges,p) for v in planes))
                check(seen==list(range(n))*(q+1))
                check(stats['scans']==q+1 and stats['leaves']==(q+1)*n)
                check(stats['internal']==(q+1)*(n-(1<<d)))
                folds=sum(4*(m-(m>>t)) for t in range(q+1))+4*((m>>q)-1)
                check(stats['fold_scalar_updates']==folds)
                check(stats['stream_eq_products']==sum(m>>(t+1) for t in range(q)))
                direct=execute(leaves.__getitem__,n,d,point,challenges,q,lam,p,'direct')
                check(direct[:3]==(rows,end,final))
                check(direct[3]['stream_eq_products']==sum((m>>(t+1))*(k-t-1) for t in range(q)))
                check(stats['eq_table_entries']==old[4]['eq_entries'])
                if k:check(verify_arithmetic((rows[0][0]+rows[0][1])%p,rows,end,challenges,p))
                check(hashlib.sha256(repr(leaves).encode()).hexdigest()==frozen)
                cases+=1

# Controls compare to original relation, not merely self-consistency.
n=32;d=5;point=[2,3,5,7];challenges=[11,13,17,19];lam=23
leaves=tuple((rng.randrange(p),rng.randrange(1,p)) for _ in range(n))
raw=tree(leaves,p)[d]
good=execute(leaves.__getitem__,n,d,point,challenges,2,lam,p)
bad=list(leaves);bad[0]=(bad[0][0]+1,bad[0][1])
control('changed_original_leaf',execute(bad.__getitem__,n,d,point,challenges,2,lam,p)[:3]!=good[:3])
bad=list(leaves);bad[0],bad[2]=bad[2],bad[0]
control('wrong_site_swap_preserves_root',tree(bad,p)[0]==tree(leaves,p)[0])
control('wrong_site_order_detected_by_original_MLE',execute(bad.__getitem__,n,d,point,challenges,2,lam,p)[:3]!=good[:3])
control('changed_point_bit_order',execute(leaves.__getitem__,n,d,point[::-1],challenges,2,lam,p)[:2]!=good[:2])
control('guessed_future_challenges_fail',execute(leaves.__getitem__,n,d,point,[0]*4,2,lam,p)[:3]!=good[:3])
changed=[r[:] for r in good[0]];changed[1][2]=(changed[1][2]+1)%p
claim=sum(good[0][0][:2])%p
control('changed_sample_rejected',not verify_arithmetic(claim,changed,good[1],challenges,p))
control('changed_terminal_rejected',not verify_arithmetic(claim,good[0],good[1]+1,challenges,p))
bad=list(leaves);bad[0]=(0,0)
try:execute(bad.__getitem__,n,d,point,challenges,2,lam,p);refused=False
except ValueError:refused=True
control('zero_denominator_at_zero_multiplicity_refused',refused)
for badq in [-1,5]:
    try:execute(leaves.__getitem__,n,d,point,challenges,badq,lam,p);refused=False
    except ValueError:refused=True
    control('invalid_prefix_refused_'+str(badq),refused)
zero=execute(leaves.__getitem__,n,d,[0,1,0,1],[1,0,1,0],2,lam,p)
expect=direct_samples(raw,[0,1,0,1],[1,0,1,0],lam,p)
control('zero_equality_no_inverse',zero[:2]==expect)
g=consumer(lambda: iter(raw),16,point,2,lam,p,dict(fold_scalar_updates=0,stream_eq_products=0))
next(g)
try:g.send(None);refused=False
except ValueError:refused=True
control('missing_global_challenge_refused',refused)
# Product of already summed rows is not the sum of their products.
v=[(1,2,3,4),(5,6,7,8)]
control('aggregate_product_shortcut_wrong',term(tuple(sum(z) for z in zip(*v)),lam,p)!=sum(term(x,lam,p) for x in v)%p)
accesses=0
def drifting_source(i):
    global accesses
    scan=accesses//n;accesses+=1
    a,b=leaves[i]
    return ((a+1)%p,b) if scan and i==0 else (a,b)
drift=execute(drifting_source,n,d,point,challenges,2,lam,p)
control('source_drift_across_scans_detected_by_original_oracle',drift[:3]!=good[:3])

fixtures=json.loads((HERE/'inputs.json').read_text());models=[]
for f in fixtures:
    selected=[]
    for mode,b in [('column',16),('forest',12),('column',0),('column',max(x.bit_length()-1 for x in f['sizes']))]:
        previous=allocation_trace(f['sizes'],b,mode)
        for q in [0,1,2,3,4]:
            got=model(f['sizes'],b,mode,q)
            got.pop('phases')
            got['previous_modeled_peak_bytes']=previous['modeled_peak_bytes']
            if q==0:
                for key in ['tree_internal_nodes','leaf_generations','checkpoint_scalar_copies','fold_scalar_updates']:
                    check(got[key]==previous[key])
            selected.append(got)
    for cap in [32*2**20,16*2**20,8*2**20]:
        got=model(f['sizes'],16,'column',4,cap)
        got['streamed_layer_services']=sum(x['prefix_rounds']>0 for x in got['phases'])
        got.pop('phases')
        selected.append(got)
    models.append({k:f[k] for k in ['model','T','dd','scope','old_U8_helper_bytes']}|{'plans':selected})
(HERE/'model-result.json').write_text(json.dumps(models,indent=2)+'\n')
result=dict(status='PASS',seed=20261020107,checks=checks,layer_consumers=cases,
 negative_controls=controls,elapsed_s=time.monotonic()-start,maxrss_KiB=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
 scope='Unmasked F65537 challenge-causal tiled arithmetic and symbolic Fp2 arrays; no native protocol/proof/privacy or performance reproduction.',
 full_stack=dict(proofs=0,passes=0,positions=0,context_length=None,device=None,witness_s=None,proof_s=None,serialization_s=None,verification_s=None,startup_s=None,startup_fraction=None,steady_rate=None,total_rate=None))
(HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))

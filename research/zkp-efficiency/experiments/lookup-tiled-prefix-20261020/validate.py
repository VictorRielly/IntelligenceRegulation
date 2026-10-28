"""Independent bottom-up tree, explicit Boolean basis, phase and work audit."""
from pathlib import Path
import hashlib,itertools,json,random,resource,time
from tiled import execute,model,consumer,layer_source

HERE=Path(__file__).resolve().parent;start=time.monotonic();rng=random.Random(20261020108)
checks=cost_cases=arithmetic_cases=mutations=0;p=65537
def check(v):
    global checks
    assert v
    checks+=1

def expected(sizes,b,mode,qmax,cap=None):
    heights=[n.bit_length()-1 for n in sizes]
    roots=32*(2*len(sizes)-1)
    cache=[32*sum(1<<j for j in range(min(b,h)+1)) for h in heights]
    forest=sum(cache) if mode=='forest' else 0
    phases=[roots+forest+32*(max(heights)+1)]
    treework=sum(sizes)-1;leaves=sum(sizes);copies=folds=eqops=scans=0
    for i,n in enumerate(sizes):
        h=heights[i];base=roots+(forest if mode=='forest' else cache[i])
        phases.append(base+32*(h+1))
        if mode=='column':treework+=n-1;leaves+=n
        for depth in range(1,h+1):
            width=2**depth;entries=width//2;bits=depth-1
            uncached=depth>b
            prefix=min(qmax,bits) if uncached else 0
            if cap is not None and uncached:
                # For powers of two: exact bit-length difference, no loop.
                prefix=min(qmax,bits,max(0,(64*entries).bit_length()-cap.bit_length()))
            if uncached:
                # Explicit per-pass sequence; no zero-cost reconstruction.
                for scan in range(prefix+1):
                    treework+=n-width;leaves+=n;scans+=1
            else:copies+=2*width
            for scan in range(prefix+1):
                for t in range(scan):folds+=4*(entries//(2**(t+1)))
            for t in range(prefix,bits):folds+=4*(entries//(2**(t+1)))
            for t in range(prefix):eqops+=entries//(2**(t+1))
            base+=0
            resident=4*16*(entries//(2**prefix))
            constant=256+64*(bits+1)
            dfs=32*(h-depth+1) if uncached else 0
            # Materialization and resident-round phases are distinct.
            phases.append(base+resident+64*2**prefix+dfs+constant)
            for t in range(prefix,bits):
                rem=bits-t-1
                equality=16*(2**(rem//2)+2**(rem-rem//2))
                phases.append(base+resident+equality+constant)
            for t in range(prefix):
                remaining=bits-t-1
                eqbytes=16*(2**(remaining//2)+2**(remaining-remaining//2))
                phases.append(base+64*2**(t+1)+dfs+eqbytes+constant)
    return (max(phases),treework,leaves,copies,folds,eqops,scans)

keys=['modeled_peak_bytes','tree_internal_nodes','leaf_generations','checkpoint_scalar_copies','fold_scalar_updates','stream_eq_products','uncached_layer_scans']
for _ in range(240):
    sizes=[1<<rng.randrange(1,13) for _ in range(rng.randrange(1,8))]
    b=rng.randrange(14);mode=rng.choice(['forest','column']);q=rng.randrange(5)
    cap=rng.choice([None,2**rng.randrange(6,19)])
    got=model(sizes,b,mode,q,cap);v=tuple(got[k] for k in keys);want=expected(sizes,b,mode,q,cap)
    check(v==want)
    if cap is not None:
        for phase in got['phases']:
            remaining=2**(phase['depth']-1-phase['prefix_rounds'])
            if 64*remaining>cap:
                check(got['fold_cap_satisfied'] is False)
                break
        else:check(got['fold_cap_satisfied'] is True)
    for j in range(len(keys)):
        bad=list(v);bad[j]+=1;check(tuple(bad)!=want);mutations+=1
    cost_cases+=1

def multilinear(v,pt):
    z=0
    for bits,value in zip(itertools.product([0,1],repeat=len(pt)),v):
        # itertools order puts the first index bit high; reverse to local LSB.
        w=value
        for bit,r in zip(bits[::-1],pt):w=w*(r if bit else 1-r)%p
        z=(z+w)%p
    return z

for case in range(70):
    h=rng.randrange(1,7);n=2**h;depth=rng.randrange(1,h+1)
    original=tuple((rng.randrange(p),rng.randrange(1,p)) for _ in range(n))
    level=list(original)
    while len(level)>2**depth:
        nxt=[]
        for j in range(0,len(level),2):
            a,b=level[j];c,d=level[j+1]
            nxt.append(((a*d+c*b)%p,b*d%p))
        level=nxt
    k=depth-1;m=2**k
    a,b,c,d=([level[2*j+side][coord] for j in range(m)] for side,coord in [(0,0),(0,1),(1,0),(1,1)])
    pt=[rng.choice([0,1,rng.randrange(p)]) for _ in range(k)]
    rs=[rng.choice([0,1,rng.randrange(p)]) for _ in range(k)]
    lam=rng.randrange(p);q=rng.randrange(min(4,k)+1)
    def polynomial(x):
        av,bv,cv,dv=[multilinear(v,x) for v in [a,b,c,d]]
        eq=1
        for r,z in zip(pt,x):eq=eq*((1-r)*(1-z)+r*z)%p
        return eq*(av*dv+cv*bv+lam*bv*dv)%p
    expected_rows=[]
    for t in range(k):
        expected_rows.append([sum(polynomial(rs[:t]+[x]+list(tail)) for tail in itertools.product([0,1],repeat=k-t-1))%p for x in range(4)])
    got=execute(original.__getitem__,n,depth,pt,rs,q,lam,p)
    check(got[0]==expected_rows);check(got[1]==polynomial(rs))
    check(got[2]==tuple(multilinear(v,rs) for v in [a,b,c,d]))
    # Observe challenge causality from scan boundaries, without future challenges.
    stats=dict(scans=0,leaves=0,internal=0,fold_scalar_updates=0,stream_eq_products=0)
    source=lambda:layer_source(original.__getitem__,n,depth,p,stats)
    g=consumer(source,m,pt,q,lam,p,stats)
    try:
        row=next(g)
        for t in range(k):
            check(row==expected_rows[t]);check(stats['scans']==min(t+1,q+1))
            row=g.send(rs[t])
    except StopIteration as done:check(done.value[0]==polynomial(rs))
    check(stats['scans']==q+1);arithmetic_cases+=1

pins=json.loads((HERE/'source-pins.json').read_text())
for pin in pins:check(hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()==pin['sha256'])
result=dict(status='PASS',seed=20261020108,checks=checks,cost_schedules=cost_cases,cost_mutations=mutations,
 independent_original_MLE_cases=arithmetic_cases,verified_pins=len(pins),elapsed_s=time.monotonic()-start,
 maxrss_KiB=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
 scope='Independent original Boolean basis and source-challenge schedule; symbolic Fp2 capacity/cost, not private protocol.')
(HERE/'validation-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))

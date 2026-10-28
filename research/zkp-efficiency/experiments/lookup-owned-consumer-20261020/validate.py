"""Independent closed-form phase maxima and direct Boolean-basis samples."""
from pathlib import Path
import random,json,time,resource,hashlib,itertools
from owned import allocation_trace,serve,consume
HERE=Path(__file__).resolve().parent;start=time.monotonic();rng=random.Random(20261020107)
checks=0;cost_cases=0;arithmetic_cases=0;mutations=0
def check(x):
    global checks
    assert x
    checks+=1
def expected(sizes,b,mode):
    hs=[x.bit_length()-1 for x in sizes];root=32*(2*len(sizes)-1)
    cache=[32*sum(2**i for i in range(min(b,h)+1)) for h in hs]
    initial=root+(sum(cache) if mode=='forest' else 0)+32*(max(hs)+1)
    phases=[initial];work=sum(sizes)-1;leaves=sum(sizes);copies=0;entries=0
    for i,(n,h) in enumerate(zip(sizes,hs)):
        base=root+(sum(cache) if mode=='forest' else cache[i])
        if mode=='column':work+=n-1;leaves+=n;phases.append(base+32*(h+1))
        for d in range(1,h+1):
            capacity=32*(2**d);extra=0
            if d>min(b,h):
                extra=32*(h-d+1);work+=n-2**d;leaves+=n
            else:copies+=2*(2**d)
            eqsizes=[2**((q-1)//2)+2**((q-1)-((q-1)//2)) for q in range(d-1,0,-1)]
            entries+=sum(eqsizes)
            phases.append(base+capacity+max(extra,16*max(eqsizes,default=0)))
    return max(phases),work,leaves,copies,entries
for _ in range(260):
    sizes=[1<<rng.randrange(1,11) for _ in range(rng.randrange(1,9))];b=rng.randrange(12);mode=rng.choice(['forest','column'])
    a=allocation_trace(sizes,b,mode)
    got=tuple(a[k] for k in ['modeled_peak_bytes','tree_internal_nodes','leaf_generations','checkpoint_scalar_copies','eq_factor_table_entries'])
    want=expected(sizes,b,mode);check(got==want);live={};peak=0
    for op,key,size,total in a['events']:
        if op=='alloc':check(key not in live);live[key]=size
        else:check(live.pop(key)==size)
        check(sum(live.values())==total);peak=max(peak,total)
    check(peak==a['modeled_peak_bytes'])
    for k in range(5):
        bad=list(got);bad[k]+=1;check(tuple(bad)!=want);mutations+=1
    cost_cases+=1
def mle(v,point,p):
    s=0
    for j,y in enumerate(v):
        c=y
        for bit,r in enumerate(point):c=c*(r if (j>>bit)&1 else 1-r)%p
        s=(s+c)%p
    return s
p=65537
for case in range(90):
    d=rng.randrange(1,7);n=1<<d
    leaves=tuple((rng.randrange(p),rng.randrange(1,p)) for _ in range(n))
    source_hash=hashlib.sha256(repr(leaves).encode()).digest()
    point=[rng.choice([0,1,rng.randrange(p)]) for _ in range(d-1)];rs=[rng.choice([0,1,rng.randrange(p)]) for _ in range(d-1)];lam=rng.randrange(p)
    original=[[leaves[2*j+side][coord] for j in range(n//2)] for side,coord in [(0,0),(0,1),(1,0),(1,1)]]
    def direct(pt):
        a,b,c,e=[mle(v,pt,p) for v in original];weight=1
        for x,z in zip(pt,point):weight=weight*((1-x)*(1-z)+x*z)%p
        return weight*(a*e+c*b+lam*b*e)%p
    b=rng.randrange(d+1);service=serve(leaves.__getitem__,n,b,p)
    for depth,owner,cache,count in service:
        if depth!=d:continue
        before=repr(cache);got=consume(owner,point,rs,lam,p)
        expect=[]
        for t in range(d-1):
            expect.append([sum(direct(rs[:t]+[x]+list(tail)) for tail in itertools.product([0,1],repeat=d-2-t))%p for x in range(4)])
        claim=sum(direct(list(pt)) for pt in itertools.product([0,1],repeat=d-1))%p
        check(got[:3]==(claim,expect,direct(rs)))
        check(all(got[3][j][0]==mle(original[j],rs,p) for j in range(4)))
        check(repr(cache)==before);check(hashlib.sha256(repr(leaves).encode()).digest()==source_hash)
        # Wrong order and a dropped original leaf are compared against the oracle,
        # not treated as successful checks merely because sumcheck self-consists.
        altered=[v[:] for v in original];altered[0][0]=(altered[0][0]+1)%p
        check(any(mle(altered[0],pt,p)!=mle(original[0],pt,p) for pt in itertools.product([0,1],repeat=d-1)))
        arithmetic_cases+=1
pins=json.loads((HERE/'prior-pins.json').read_text())
pins+=json.loads((HERE.parent/'lookup-layer-consumer-20261020/source-manifest.json').read_text())
for pin in pins:check(hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()==pin['sha256'])
result=dict(status='PASS',seed=20261020107,checks=checks,allocation_schedules=cost_cases,cost_mutations=mutations,
 independent_original_mle_cases=arithmetic_cases,source_pins=len(pins),elapsed_s=time.monotonic()-start,maxrss_KiB=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
 scope='Independent phase maxima/event replay and original Boolean-basis arithmetic, not native proof/privacy validation.')
(HERE/'validation-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))

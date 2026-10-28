from pathlib import Path
import json,random,time,resource,hashlib
from fp2 import E,Attempt,OrderedLookup,P
import reference as ref
from reversible import Tree,consume,capacities

HERE=Path(__file__).resolve().parent
SEED=20261020110
checks=0
def check(x):
    global checks
    assert x
    checks+=1
def tup(x):return tuple(x.pair())
def pair(x):return tuple(tup(c) for c in x)
def rejected(f):
    try:f()
    except ValueError:return True
    return False

def main():
    start=time.monotonic();rng=random.Random(SEED);cases=[];fixtures=[]
    for n in [2,4,8,16,32,64,256]:
      for kind in ['looked','table','extension']:
        attempt=Attempt(E(1001,3),E(17,5))
        values=[rng.randrange(256) for _ in range(n)]
        if kind=='looked':
            planes=[values,[0]*n];lookup=OrderedLookup(attempt,planes,[(0,1),(1,-256)])
            leaves=[lookup.read(i) for i in range(n)]
        elif kind=='table':leaves=[attempt.leaf(i%256,0 if i%3==0 else rng.randrange(9)) for i in range(n)]
        else:leaves=[(E(rng.getrandbits(64),rng.getrandbits(64)),E(rng.getrandbits(64),rng.getrandbits(64))) for _ in range(n)]
        native=[pair(x) for x in leaves];levels=ref.tree(native)
        fixtures.append({'n':n,'kind':kind,'leaves':native,'immutable_root':levels[0][0]})
        for mode in ['individual','batch']:
            t=Tree(lambda j:leaves[j],n);check(pair(t.build())==levels[0][0])
            digest=hashlib.sha256();consumers=0
            for d in range(1,t.depth+1):
                t.expand(mode);child=list(t.layer());check([pair(x) for x in child]==levels[d])
                before=list(t.data);k=d-1
                point=[E(0) if j%3==0 else E(1) if j%3==1 else E(31+j,8+j) for j in range(k)]
                challenges=[E(1) if j%3==0 else E(0) if j%3==1 else E(13+j,9) for j in range(k)]
                lam=E(15,9)
                for q in sorted(set([0,min(2,k)])):
                    rows,terminal,ends,stats=consume(t,point,challenges,lam,q)
                    rrows,rt,rends=ref.direct(levels[d],[tup(x) for x in point],[tup(x) for x in challenges],tup(lam))
                    check([[tup(x) for x in row] for row in rows]==rrows)
                    check(tup(terminal)==rt and tuple(tup(x) for x in ends)==rends)
                    check(t.data==before)
                    parent=ref.mle([ref.add(x[0],ref.mul(tup(lam),x[1])) for x in levels[d-1]],[tup(x) for x in point])
                    check(ref.verify(parent,rrows,rt,[tup(x) for x in challenges]))
                    check(stats['scans']==q+1 and stats['tree_node_reads']==(q+1)*(1<<d))
                    digest.update(json.dumps(rrows).encode());consumers+=1
                if d==t.depth and n>=4:
                    bad=levels[d][:];bad[0],bad[-1]=bad[-1],bad[0]
                    check(ref.tree(bad)[0]==levels[0])
                    # Original ordered MLE catches a swap that root cannot.
                    pt=[(7+i,11) for i in range(d)]
                    check(any(ref.mle([x[c] for x in bad],pt)!=ref.mle([x[c] for x in levels[d]],pt) for c in [0,1]))
            check(t.data==leaves and t.count['source_reads']==n)
            check(t.count['build_mul']==3*(n-1) and t.count['build_add']==n-1)
            check(t.count['recover_sub']==n-1)
            check(t.count['inversions']==(t.depth if mode=='batch' else n-1))
            check(t.count['recover_mul']==(6*(n-1)-3*t.depth if mode=='batch' else 3*(n-1)))
            # Same buffer can be built/restored again; no source reread.
            t.build()
            for _ in range(t.depth):t.expand(mode)
            check(t.data==leaves and t.count['source_reads']==n)
            cases.append(dict(n=n,kind=kind,mode=mode,consumer_cases=consumers,counts=t.count,consumer_digest=digest.hexdigest()))
    controls=[]
    for n in [2,4,8,16,32,64,256]:
      for index in range(n):
        for numerator in [0,1]:
            leaves=[(E(1),E(3,4)) for _ in range(n)];leaves[index]=(E(numerator),E())
            check(rejected(lambda:Tree(lambda j:leaves[j],n)));controls.append('zero_denominator_even_zero_numerator')
    base=[(E(i+1),E(i+5,3)) for i in range(16)]
    for mutation in ['wrong_right','changed_parent','aliased_fold']:
        t=Tree(lambda j:base[j],16);t.build()
        if mutation=='wrong_right':t.data[8]=(t.data[8][0],t.data[8][1]+1)
        elif mutation=='changed_parent':t.data[0]=(t.data[0][0]+1,t.data[0][1])
        else:t.data[8]=(t.data[8][0]+E(11,5),t.data[8][1])
        for _ in range(t.depth):t.expand()
        check(t.data!=base);controls.append(mutation)
    check(rejected(lambda:Tree(lambda j:(E(0),E(1)),3)))
    models=[capacities(1<<p,q) for p in [8,14,21] for q in range(5)]
    (HERE/'fixtures.json').write_text(json.dumps(fixtures,indent=2)+'\n')
    (HERE/'cases.json').write_text(json.dumps(cases,indent=2)+'\n')
    (HERE/'capacity-result.json').write_text(json.dumps(models,indent=2)+'\n')
    out=dict(status='PASS',seed=SEED,checks=checks,tree_cases=len(cases),consumer_cases=sum(c['consumer_cases'] for c in cases),negative_control_instances=len(controls)+1,negative_control_families=sorted(set(controls)|{'non_power_of_two'}),elapsed_s=time.monotonic()-start,maxrss_KiB=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,scope='Synthetic native-Fp2 reversible storage and unmasked layer consumers only; no private proof')
    (HERE/'result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))

if __name__=='__main__':main()

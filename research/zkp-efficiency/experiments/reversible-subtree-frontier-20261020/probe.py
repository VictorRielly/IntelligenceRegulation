from pathlib import Path
import random,json,time,resource
from fp2 import E,P,Attempt
from frontier import Frontier,model,schedule
import reference as ref

HERE=Path(__file__).resolve().parent
start=time.monotonic();rng=random.Random(20261020111)
checks=controls=consumers=layers=0;fixtures=[]
def check(v):
    global checks
    checks+=1
    if not v:raise AssertionError(checks)
def tup(x):return x.a,x.b
def packed(v):return [[list(tup(x)) for x in pair] for pair in v]
def normal(result):return [[list(map(tup,row)) for row in result[0]],tup(result[1]),tuple(map(tup,result[2]))]
def drive(obj,d,pt,ch,q,lam):return obj.consume(d,pt,ch,q,lam)

for kind in ['u8','multiplicity','extension']:
    for n in [2,4,8,16,32,64]:
        h=n.bit_length()-1;attempt=Attempt(E(987654,42),E(777,13))
        values=[rng.randrange(256) for _ in range(n)]
        if kind=='extension':leaves=[(E(rng.randrange(P),rng.randrange(P)),E(rng.randrange(P),rng.randrange(1,P))) for _ in range(n)]
        else:leaves=[attempt.leaf(v,0 if kind=='multiplicity' and i%3==0 else (i%7 if kind=='multiplicity' else 1)) for i,v in enumerate(values)]
        expected=ref.tree([(tup(a),tup(b)) for a,b in leaves])
        for f in sorted({0,h//2,max(0,h-1)}):
            def cache(i,d):
                check(d==attempt.denominator(values[i]))
                return attempt.helper(values[i])
            modes=['direct','batch']+(['cached'] if kind!='extension' else [])
            objs={mode:Frontier(lambda i:leaves[i],n,f,mode,cache if mode=='cached' else None) for mode in modes}
            for mode,obj in objs.items():
                check(packed(obj.levels[0])==[[list(x) for x in expected[0][0]]])
                for d in range(h+1):
                    got=list(obj.layer(d));check(packed(got)==[[list(x) for x in y] for y in expected[d]]);layers+=1
            # Fresh objects: exactly one consumer sequence per layer for accounting.
            objs={mode:Frontier(lambda i:leaves[i],n,f,mode,cache if mode=='cached' else None) for mode in modes}
            for d,q in schedule(n,f,qmax=2,cap_bytes=256):
                k=d-1;pt=[E(0) if j==0 else E(rng.randrange(20),rng.randrange(20)) for j in range(k)]
                ch=[E(1) if j==0 else E(rng.randrange(20),rng.randrange(20)) for j in range(k)]
                lam=E(9,11)
                results={mode:drive(obj,d,pt,ch,q,lam) for mode,obj in objs.items()}
                base=normal(results['direct'])
                for mode,r in results.items():check(normal(r)==base);consumers+=1
                # Expensive independent Boolean reference only at <=16 leaves.
                if n<=16:
                    r=ref.direct(expected[d],list(map(tup,pt)),list(map(tup,ch)),tup(lam))
                    check(base==[r[0],r[1],r[2]])
            for mode,obj in objs.items():
                predicted=model(n,f,mode,cap_bytes=256,qmax=2)['counts']
                for key,val in predicted.items():check(obj.count[key]==val)
            snap=dict(kind=kind,n=n,f=f,leaves=packed(leaves),counts={mode:obj.count for mode,obj in objs.items()})
            fixtures.append(snap)

# Refusal, ordering and stale-cache controls. Root symmetry is insufficient.
for n in [2,4,8,16]:
    for j in range(n):
        v=[(E(1),E(i+1,2)) for i in range(n)];v[j]=(E(0),E(0))
        for mode in ['direct','batch']:
            try:Frontier(lambda i:v[i],n,0,mode)
            except ValueError:controls+=1
            else:raise AssertionError('zero denominator admitted')
v=[attempt.leaf(i) for i in range(8)]
honest=Frontier(lambda i:v[i],8,1,'batch')
swapped=v[:];swapped[0],swapped[1]=swapped[1],swapped[0]
bad=Frontier(lambda i:swapped[i],8,1,'batch')
check(honest.levels[0]==bad.levels[0]);check(list(honest.layer(3))!=list(bad.layer(3)));controls+=1
stale=Attempt(E(987655,42),E(777,13))
bad=Frontier(lambda i:v[i],8,1,'cached',lambda i,d:stale.helper(i))
check(list(bad.layer(3))!=list(honest.layer(3)));controls+=1
# A zero at an ABSENT looked value still appears in the global table, m=0.
bad_attempt=Attempt(E(77),E(12));check(bad_attempt.helper(0)!=0)
try:bad_attempt.table_helper([0]*256)
except ValueError:controls+=1
else:raise AssertionError('global table absent-zero skipped')

out=dict(status='PASS',seed=20261020111,checks=checks,negative_controls=controls,
         consumer_cases=consumers,layer_cases=layers,fixtures=len(fixtures),
         elapsed_s=time.monotonic()-start,maxrss_KiB=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
         scope='Synthetic native-field ordered factories and unmasked cubic consumer; no native private proof')
(HERE/'fixtures.json').write_text(json.dumps(fixtures)+'\n')
(HERE/'result.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(out))

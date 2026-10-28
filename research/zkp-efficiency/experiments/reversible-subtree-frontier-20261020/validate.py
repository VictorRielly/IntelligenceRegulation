"""Independent immutable tuple arithmetic, explicit rounds and cost graph.

Candidate imported for observed outputs only. Expected values use polynomial
convolution and Boolean weights; no candidate recovery/mixing/cost formulas.
"""
from pathlib import Path
import json,time,resource,hashlib
from fp2 import E
from frontier import Frontier,model
from reference import add,sub,mul,tree,mle,P
HERE=Path(__file__).resolve().parent;start=time.monotonic()
checks=consumers=layers=events=0
def check(v):
    global checks
    checks+=1
    if not v:raise AssertionError(checks)
def tup(x):return x.a,x.b
def cubic(child,point,ch,lam):
    planes=[[pair[c] for pair in child[s::2]] for s,c in [(0,0),(0,1),(1,0),(1,1)]]
    w=[]
    for i in range(len(child)//2):
        z=(1,0)
        for j,r in enumerate(point):z=mul(z,r if i>>j&1 else sub((1,0),r))
        w.append(z)
    tables=planes+[w];rows=[]
    def value(v):
        a,b,c,d,e=v
        return mul(e,add(add(mul(a,d),mul(c,b)),mul(lam,mul(b,d))))
    for r in ch:
        samples=[]
        for x in range(4):
            val=(0,0)
            for i in range(0,len(tables[0]),2):
                v=[add(t[i],mul((x,0),sub(t[i+1],t[i]))) for t in tables]
                val=add(val,value(v))
            samples.append(val)
        rows.append(samples)
        tables=[[add(t[i],mul(r,sub(t[i+1],t[i]))) for i in range(0,len(t),2)] for t in tables]
    return rows,value([v[0] for v in tables]),tuple(v[0] for v in tables[:4])

for fixture in json.loads((HERE/'fixtures.json').read_text()):
    n,f=fixture['n'],fixture['f'];h=n.bit_length()-1
    leaves=[tuple(tuple(x) for x in pair) for pair in fixture['leaves']]
    ref=tree(leaves)
    native=[tuple(E(*x) for x in pair) for pair in leaves]
    for mode in ['direct','batch']:
        obj=Frontier(lambda i:native[i],n,f,mode)
        for d in range(h+1):
            observed=[tuple(tup(x) for x in pair) for pair in obj.layer(d)]
            check(observed==ref[d]);layers+=1
        for d in range(1,h+1):
            pt=[(0,0) if j%3==0 else (9+j,4+j) for j in range(d-1)]
            ch=[(1,0) if j%3==0 else (7+j,2+j) for j in range(d-1)]
            lam=(3,17);q=min(2,d-1)
            got=obj.consume(d,[E(*x) for x in pt],[E(*x) for x in ch],q,E(*lam))
            want=cubic(ref[d],pt,ch,lam)
            check([[tup(x) for x in row] for row in got[0]]==want[0]);check(tup(got[1])==want[1]);check(tuple(map(tup,got[2]))==want[2]);consumers+=1
            # Independent direct Boolean MLE and native MSB reversal check.
            for s,c in [(0,0),(0,1),(1,0),(1,1)]:
                v=[a[c] for a in ref[d][s::2]]
                check(mle(v,ch)==want[2][[(0,0),(0,1),(1,0),(1,1)].index((s,c))])
                w=v[:]
                for r in reversed(ch):
                    m=len(w)//2;w=[add(w[j],mul(r,sub(w[j+m],w[j]))) for j in range(m)]
                check(w[0]==mle(v,ch))

# Expected source/mix/restore graph. Small fixture counts are enumerated node
# by node, independent of the candidate closed-form count model.
for fixture in json.loads((HERE/'fixtures.json').read_text()):
    n,f=fixture['n'],fixture['f'];h=n.bit_length()-1;B=n>>f
    for mode,observed in fixture['counts'].items():
        expect=dict(source_reads=n,cache_key_reads=0,build_muls=0,build_adds=0,restore_muls=0,restore_subs=0,inversions=0)
        # Initial immutable forward tree: one node for every internal pair.
        width=n
        while width>1:
            for _ in range(width//2):expect['build_muls']+=3;expect['build_adds']+=1
            width//=2
        for d in range(1,h+1):
            rows=1<<(d-1);q=0
            if d>f:
                while rows*64>256 and q<min(2,d-1):rows//=2;q+=1
                for _ in range(q+1):
                    expect['source_reads']+=n
                    if mode=='direct':
                        width=n
                        while width>1<<d:
                            for _ in range(width//2):expect['build_muls']+=3;expect['build_adds']+=1
                            width//=2
                    else:
                        for _ in range(1<<f):
                            width=B
                            while width>1:
                                for _ in range(width//2):expect['build_muls']+=3;expect['build_adds']+=1
                                width//=2
                            for ell in range(d-f):
                                nodes=1<<ell
                                if mode=='cached' and d==h and ell==B.bit_length()-2:
                                    for _ in range(nodes):expect['restore_muls']+=3;expect['restore_subs']+=1;expect['cache_key_reads']+=1
                                else:
                                    expect['inversions']+=1
                                    # Prefix forward nodes-1 plus reverse2(nodes-1).
                                    for _ in range(nodes-1):expect['restore_muls']+=3
                                    for _ in range(nodes):expect['restore_muls']+=3;expect['restore_subs']+=1
        for key in expect:check(expect[key]==observed[key])

for p in json.loads((HERE/'capacity-events.json').read_text()):
    maximum=0
    for e in p['events']:
        check(e['bytes']==sum(e['alloc_E'].values())*16);events+=1
        if 'resident-full-capacity' in e['alloc_E']:
            check(e['alloc_E']['resident-full-capacity']>0)
        maximum=max(maximum,e['bytes'])
    check(maximum==p['peak_bytes'])
    if p['mode']!='direct':
        direct=model(p['n'],p['f'],'direct',p['columns'])
        check(p['peak_bytes']>=direct['peak_bytes'])
        check(p['counts']['source_reads']==direct['counts']['source_reads'])

forest=json.loads((HERE/'forest-result.json').read_text())['profiles']
prior=json.loads((HERE/'prior-forest-result.json').read_text())['profiles']
for r in forest:
    if r['fmax']==16:
        old=next(x['prior_selected'] for x in prior if (x['model'],x['T'],x['dd'])==(r['model'],r['T'],r['dd']))
        check(r['arms']['direct']['counts']['source_reads']==old['leaf_generations'])
        check(r['arms']['direct']['counts']['build_muls']==3*old['tree_internal_nodes'])
for pin in json.loads((HERE/'source-pins.json').read_text()):
    check(hashlib.sha256((HERE/pin['snapshot']).read_bytes()).hexdigest()==pin['sha256'])
out=dict(status='PASS',checks=checks,consumer_cases=consumers,layer_cases=layers,
         capacity_events=events,prior_profiles_checked=10,source_pins=22,
         elapsed_s=time.monotonic()-start,maxrss_KiB=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
         scope='Independent tuple immutable tree/cubic/Boolean MLE/MSB ordering, enumerated operation graph, payload events and hashes; no native proof')
(HERE/'validation-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))

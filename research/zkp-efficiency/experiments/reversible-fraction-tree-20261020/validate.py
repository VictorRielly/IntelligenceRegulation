"""Independent immutable tuple-field tree and allocation event audit.

No candidate field/mix/tree/capacity helper is used to compute expected values.
Candidate imported only as the subject of differential tests.
"""
from pathlib import Path
import json,hashlib,time,resource
from reversible import Tree,capacities
from fp2 import E

HERE=Path(__file__).resolve().parent
P=0xffffffff00000001
Z=(0,0);O=(1,0)
checks=0
def check(x):
    global checks
    assert x
    checks+=1
def add(x,y):return tuple((a+b)%P for a,b in zip(x,y))
def sub(x,y):return tuple((a-b)%P for a,b in zip(x,y))
def mul(x,y):
    polynomial=[0,0,0]
    for i,a in enumerate(x):
        for j,b in enumerate(y):polynomial[i+j]+=a*b
    return ((polynomial[0]+7*polynomial[2])%P,polynomial[1]%P)
def power(x,n):
    y=O
    for bit in bin(n)[2:]:
        y=mul(y,y)
        if bit=='1':y=mul(y,x)
    return y
def mix(left,right):
    return add(mul(left[0],right[1]),mul(left[1],right[0])),mul(left[1],right[1])
def immutable(leaves):
    levels=[list(leaves)]
    while len(levels[-1])>1:
        old=levels[-1];levels.append([mix(old[j],old[j+1]) for j in range(0,len(old),2)])
    return levels[::-1]
def msb_mle(values,point):
    data=values[:]
    for x in point:
        half=len(data)//2
        data=[add(a,mul(x,sub(b,a))) for a,b in zip(data[:half],data[half:])]
    return data[0]
def native(x):return tuple(x.pair())

def audit_capacity(n,q):
    # Each event reserves array capacity, not its shrinking active length.
    log=n.bit_length()-1;events=[]
    def event(label,allocations):events.append((sum(allocations.values()),label,allocations))
    event('build',{'leaf_buffer':2*n})
    for depth in range(1,log+1):
        m=2**(depth-1);rounds=depth-1;early=min(q,rounds)
        event(f'd{depth}/restore',{'leaf_buffer':2*n,'prefix':m})
        for t in range(early):
            bits=rounds-t-1
            event(f'd{depth}/stream{t}',{'leaf_buffer':2*n,'tile':4*2**(t+1),'eqlo':2**(bits//2),'eqhi':2**(bits-bits//2)})
        event(f'd{depth}/load',{'leaf_buffer':2*n,'resident':4*(m>>early),'tile':4*2**early})
        for t in range(early,rounds):
            bits=rounds-t-1
            event(f'd{depth}/round{t}',{'leaf_buffer':2*n,'resident':4*(m>>early),'eqlo':2**(bits//2),'eqhi':2**(bits-bits//2)})
    return max(events,key=lambda row:row[0]),events

def main():
    start=time.monotonic();fixture_count=layer_count=mle_count=0
    pins=json.loads((HERE/'source-pins.json').read_text())
    for r in pins:
        check(hashlib.sha256(Path(r['path']).read_bytes()).hexdigest()==r['sha256'])
        check(hashlib.sha256((HERE/r['snapshot']).read_bytes()).hexdigest()==r['sha256'])
    for fixture in json.loads((HERE/'fixtures.json').read_text()):
        leaves=[tuple(tuple(v) for v in pair) for pair in fixture['leaves']]
        levels=immutable(leaves);check(levels[0][0]==tuple(tuple(x) for x in fixture['immutable_root']))
        expected_q=O
        for _,d in leaves:expected_q=mul(expected_q,d)
        check(expected_q==levels[0][0][1])
        for mode in ['batch','individual']:
            t=Tree(lambda j:tuple(E(*x) for x in leaves[j]),len(leaves));t.build()
            for depth in range(1,t.depth+1):
                # Assert every right subtree survives BEFORE inversion.
                stride=len(leaves)//(2**depth)
                for j in range(1,2**depth,2):
                    check(tuple(native(x) for x in t.data[j*stride])==levels[depth][j])
                t.expand(mode);got=[tuple(native(x) for x in pair) for pair in t.layer()]
                check(got==levels[depth]);layer_count+=1
                for j in range(0,len(got),2):check(mix(got[j],got[j+1])==levels[depth-1][j//2])
                for component in [0,1]:
                    pt=[(j+11,j+5) for j in range(depth)]
                    check(msb_mle([v[component] for v in got],pt)==msb_mle([v[component] for v in levels[depth]],pt));mle_count+=1
                # Independent Fermat inverse catches candidate conjugate formula.
                if depth<=4:
                    x=got[-1][1];check(mul(x,power(x,P*P-2))==O)
                    check(native(E(*x).inv())==power(x,P*P-2))
            m=len(leaves);depth=m.bit_length()-1
            check(t.count['inversions']==(depth if mode=='batch' else m-1))
            batch_mult=sum(3*(2**j-1) for j in range(depth))
            check(t.count['recover_mul']==3*(m-1)+(batch_mult if mode=='batch' else 0))
        fixture_count+=1
    events_total=0;capacity_controls=0
    for row in json.loads((HERE/'capacity-result.json').read_text()):
        peak,events=audit_capacity(row['n'],row['q']);events_total+=len(events)
        check(peak[0]==row['selected_peak_E'])
        check(16*peak[0]==row['selected_peak_bytes'])
        check(2*row['n']==row['tree_E'])
        # These shortcuts undercount a real selected-array phase.
        for false_peak in [row['tree_E'],row['tree_E']+row['n']//2-1]:
            check(false_peak<peak[0]);capacity_controls+=1
    for row in json.loads((HERE/'cases.json').read_text()):
        n=row['n'];d=n.bit_length()-1;c=row['counts']
        check(c['source_reads']==n)
        check(c['build_mul']==6*(n-1) and c['recover_sub']==2*(n-1))
        check(c['inversions']==2*(d if row['mode']=='batch' else n-1))
    forest_count=0
    for f in json.loads((HERE/'forest-result.json').read_text())['profiles']:
        source=next(x for x in json.loads((HERE/'inputs.json').read_text()) if (x['model'],x['T'],x['dd'])==(f['model'],f['T'],f['dd']))
        sizes=source['sizes'];nodes=0;batch_muls=0;inversions=0
        for n in sizes:
            m=1
            while m<n:
                nodes+=m;batch_muls+=3*m+3*(m-1);inversions+=1;m*=2
        check(nodes==f['internal_nodes'])
        check(batch_muls==f['batch_restore_Fp2_muls'])
        check(inversions==f['batch_restore_inversions'])
        check(sum(sizes)==f['source_leaf_reads'])
        for q,plan in enumerate(f['plans']):
            expected=max(audit_capacity(n,q)[0][0] for n in sizes)
            check(expected==plan['selected_peak_E'])
        check(f['prior_leaf_reads_avoided']==f['prior_selected']['leaf_generations']-sum(sizes))
        forest_count+=1
    out=dict(status='PASS',checks=checks,fixtures=fixture_count,layers=layer_count,MSB_MLE_cases=mle_count,source_pins=len(pins),capacity_events=events_total,rejected_capacity_shortcuts=capacity_controls,forest_profiles=forest_count,elapsed_s=time.monotonic()-start,maxrss_KiB=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,scope='Independent tuple immutable trees, MSB folds, inverse exponentiation, source pins and payload event accounting; no native proof')
    (HERE/'validation-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))

if __name__=='__main__':main()

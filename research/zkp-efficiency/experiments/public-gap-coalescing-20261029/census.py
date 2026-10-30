"""Independent public-row decoder, weighted partition reference and source census."""
from pathlib import Path
import json, random, itertools
D=Path(__file__).resolve().parent
result=json.loads((D/'result.json').read_text())
checks=0
def check(v):
    global checks
    assert v
    checks+=1

def decode(words, rows):
    a=[0]*rows
    for word in words:
        r,f=divmod(word,16)
        check(r<rows and a[r]==0 and f>0)
        a[r]=f
    return a

def blocks(a):
    out=[]
    for flag,group in itertools.groupby(enumerate(a),lambda x:x[1]):
        rows=list(group)
        if flag:out.append((rows[0][0],rows[-1][0]+1,flag))
    return out

def plan_reference(a,budget):
    # Decide cuts independently on immutable adjacent required intervals.
    spans=blocks(a);cuts=[]
    for left,right in zip(spans,spans[1:]):
        gap=right[0]-left[1]
        eligible=left[2]==right[2] and not any(a[left[1]:right[0]])
        cuts.append(not (eligible and gap*(8+16*left[2].bit_count())<8+budget))
    joined=[]
    for i,s in enumerate(spans):
        if i and not cuts[i-1]:joined[-1]=(joined[-1][0],s[1],s[2])
        else:joined.append(s)
    return joined

def stats(p):
    v=sum(z-a for a,z,f in p);m=sum((z-a)*f.bit_count() for a,z,f in p);j=len(p)
    return dict(visits=v,macs=m,spans=j,payload_B=8*j,logical_B_per_col=8*v+16*m+8*j)

summaries=[]
for c in result['profiles']:
    for mode in c['modes']:
        arrays=[decode(words,c['rows']) for words in mode['required_words']]
        orig=[blocks(a) for a in arrays]
        base=stats([s for batch in orig for s in batch])
        for s in mode['stats']:
            p=[plan_reference(a,s['budget']) for a in arrays]
            got=stats([x for batch in p for x in batch])
            for k,v in got.items():check(v==s[k])
            check(s['extra_visits']==got['visits']-base['visits'])
            check(s['extra_macs']==got['macs']-base['macs'])
            check(s['removed_spans']==base['spans']-got['spans'])
            check(got['logical_B_per_col']>=base['logical_B_per_col'])
            # Each protected row/group from the original structural fixture
            # must survive the data-only numerical cancellation control.
            if mode['mode']>=2:
                structural=next(m for m in c['modes'] if m['mode']==0)
                for words,aw in zip(structural['required_words'],mode['required_words']):
                    check({w for w in words if w>>4>=c['data_rows']}=={w for w in aw if w>>4>=c['data_rows']})
        if c['source']:
            n=16384
            summaries.append(dict(dd=c['dd'],mode=mode['mode'],rows=c['rows'],groups=c['groups'],
                context=128,n=n,hybrid_B=n*mode['hybrid_logical_B_per_col'],
                policies=[dict(**s,logical_B=n*s['logical_B_per_col'],
                    extra_basefield_multiplications=2*n*s['extra_macs'],
                    extra_limb_additions=2*n*s['extra_macs'],
                    increase_vs_exact_runs=(s['logical_B_per_col']/base['logical_B_per_col']-1),
                    increase_vs_hybrid=(s['logical_B_per_col']/mode['hybrid_logical_B_per_col']-1)) for s in mode['stats']]))

# Exhaustive cut enumeration is independent of the greedy inequality. Each
# candidate span may cover only equal-flag required intervals and zero gaps.
rng=random.Random(202610290153)
partitions=0;synthetic=0
for fixture in range(120):
    flags=rng.randint(1,15);length=rng.randint(1,9)
    a=[]
    for _ in range(length):a.extend([flags]*rng.randint(1,3)+[0]*rng.randint(1,5))
    bs=blocks(a)
    for budget in [0,16,17,64,65,256,1000000]:
        best=None
        for mask in range(1<<max(0,len(bs)-1)):
            joined=[]
            for i,s in enumerate(bs):
                if i and (mask>>(i-1))&1:joined[-1]=(joined[-1][0],s[1],s[2])
                else:joined.append(s)
            st=stats(joined);cost=st['logical_B_per_col']+budget*st['spans']
            best=cost if best is None else min(best,cost);partitions+=1
        got=stats(plan_reference(a,budget))
        check(best==got['logical_B_per_col']+budget*got['spans']);synthetic+=1

# Prove the per-gap source operand rejection over a broad finite sweep;
# algebraically gap>=1 and popcount>=1 implies 24*gap > 8.
for k in range(1,5):
    for gap in range(1,4097):check(gap*(8+16*k)-8>0)

out=dict(status='PASS',assertions=checks,fixtures=len(result['profiles']),
    exact_comparisons=sum(c['comparisons'] for c in result['profiles']),
    source_row_narrow_comparisons=sum(c['comparisons'] for c in result['profiles'] if c['source']),
    controls=sum(c['controls'] for c in result['profiles']),
    exhaustive_partition_candidates=partitions,exhaustive_objectives=synthetic,
    source_profiles=summaries,interpretation='negative for logical operand objective; device time unknown')
(D/'census-result.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps({k:v for k,v in out.items() if k!='source_profiles'},indent=2))

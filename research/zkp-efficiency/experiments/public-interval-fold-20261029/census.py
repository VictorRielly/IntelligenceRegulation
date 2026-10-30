"""Independent Python set model and cost accounting; no production imports."""
from pathlib import Path
from itertools import groupby
import json

D=Path(__file__).resolve().parent
actual=json.loads((D/'result.json').read_text())
reference=json.loads((D/'public-support-reference.json').read_text())
indexed=json.loads((D/'prior-indexed-result.json').read_text())
checks=0
def check(ok,why=''):
    global checks
    assert ok,why
    checks+=1

check(actual['status']=='PASS')
check(len(actual['profiles'])==len(reference['profiles'])==14)
source=[]
for p,ref,old in zip(actual['profiles'],reference['profiles'],indexed['profiles']):
    for k in ('case','source','dd','mode','rows'):check(p[k]==ref[k]==old[k],k)
    sets=[set(s) for s in ref['support_rows']]
    for pi,plan in enumerate(p['plans']):
        order=plan['order'];check(sorted(order)==list(range(len(sets))))
        check(order==old['plans'][pi]['order'])
        totals=dict(dense_B=0,list_B=0,run_B=0,hybrid_B=0,list_payload_B=0,run_payload_B=0,hybrid_payload_B=0,union=0,members=0,runs=0,dense_batches=0,list_batches=0,run_batches=0)
        for bi,start in enumerate(range(0,len(order),4)):
            gs=order[start:start+4];k=len(gs);rows=p['rows']
            union=set().union(*(sets[g] for g in gs))
            pairs=[(r,sum(1<<i for i,g in enumerate(gs) if r in sets[g])) for r in sorted(union)]
            # A different grouping construction: equal flags and (row - position).
            runs=[]
            for _,group in groupby(enumerate(pairs),lambda z:(z[1][1],z[1][0]-z[0])):
                chunk=list(group);r,flags=chunk[0][1];runs.append([16*r+flags,len(chunk)])
            check(runs==plan['spans'][bi],'maximal run encoding')
            check([16*r+f for r,f in pairs]==old['plans'][pi]['words'][bi],'prior list')
            expanded={}
            for word,length in plan['spans'][bi]:
                r,flags=divmod(word,16)
                check(length>0 and r+length<=rows,'span bounds')
                for x in range(r,r+length):
                    check(x not in expanded,'disjoint')
                    expanded[x]=flags
            check(expanded==dict(pairs),'row and flag identity')
            for i,g in enumerate(gs):check({r for r,f in expanded.items() if f&(1<<i)}==sets[g],'complete support')
            for row in (ref['data'],rows-2,rows-1):
                check(expanded.get(row,0)==sum(1<<i for i,g in enumerate(gs) if row in sets[g]),'reserved masks/proximity')
            u=len(union);m=sum(len(sets[g]) for g in gs);nr=len(runs)
            b=plan['batches'][bi]
            check(b==dict(groups=k,union=u,members=m,runs=nr),'census')
            # Per column source operands; not physical/cache/device traffic.
            costs=[rows*(8+16*k),12*u+16*m,8*u+16*m+8*nr]
            mode=min(range(3),key=lambda j:costs[j])
            check(mode==plan['modes'][bi],'public selector')
            lp=4*u;rp=8*nr;hp=[0,lp,rp][mode]
            for key,val in dict(dense_B=costs[0],list_B=costs[1],run_B=costs[2],hybrid_B=costs[mode],list_payload_B=lp,run_payload_B=rp,hybrid_payload_B=hp,union=u,members=m,runs=nr).items():totals[key]+=val
            totals[['dense_batches','list_batches','run_batches'][mode]]+=1
        if p['source']:
            n=ref['n']
            for k in ('dense_B','list_B','run_B','hybrid_B'):totals[k]*=n
            totals.update(dd=p['dd'],order_index=pi,rows=p['rows'],n=n,groups=len(sets),construct_s=plan['construct_s'],validate_s=plan['validate_s'],numeric_stats=plan['numeric_stats'])
            totals['index_reduction']=1-totals['hybrid_payload_B']/totals['list_payload_B']
            totals['source_operand_reduction_vs_list']=1-totals['hybrid_B']/totals['list_B']
            totals['source_operand_reduction_vs_dense']=1-totals['hybrid_B']/totals['dense_B']
            totals['list_metadata_logical_B']=n*totals['list_payload_B']
            totals['hybrid_metadata_logical_B']=n*totals['hybrid_payload_B']
            totals['rho_upload_B_unchanged']=16*p['rows']*len(sets)
            # Cost the already-tested public numerical-zero control independently.
            numeric_cost=0
            for start in range(0,len(order),4):
                gs=order[start:start+4]
                numeric=[(r,sum(1<<i for i,g in enumerate(gs) if r in sets[g])) for r in sorted(set().union(*(sets[g] for g in gs))) if r%3!=0]
                nr=sum(1 for _ in groupby(enumerate(numeric),lambda z:(z[1][1],z[1][0]-z[0])))
                u=len(numeric);m=sum(f.bit_count() for _,f in numeric)
                numeric_cost+=min(p['rows']*(8+16*len(gs)),12*u+16*m,8*u+16*m+8*nr)
            totals['numeric_zero_control_hybrid_B']=numeric_cost*n
            totals['numeric_zero_control_source_reduction_vs_structural']=1-numeric_cost*n/totals['hybrid_B']
            source.append(totals)

out=dict(status='PASS',checks=checks,fixtures=14,stress_fixtures=45,checked_values=sum(p['checked_values'] for p in actual['profiles']),negative_controls=sum(p['controls'] for p in actual['profiles']),source_checked_values=sum(len(p['plans'])*3*5*p['rho_vectors']*p['width'] for p in actual['profiles'] if p['source']),stress_checked_values=2250,source_profiles=source,scope='Synthetic numerical linear algebra, pinned native field/claim/group helpers and frozen R13 public geometry. No native define/FS/PCS pads/CUDA/receipt/privacy acceptance; reference authored independently by this researcher.')
(D/'census-result.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps({k:v for k,v in out.items() if k!='source_profiles'}))
for s in source:print(json.dumps(s))

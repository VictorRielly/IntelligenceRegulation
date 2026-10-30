"""Independent set/coordinate audit using the prior source-derived public census.

No production module, experiment executable or foreign implementation imported.
The current Rust numerical seed differs; public supports must remain identical.
"""
from pathlib import Path
import json

D=Path(__file__).resolve().parent
actual=json.loads((D/'result.json').read_text())
prior=json.loads((D/'startup/prior-result.json').read_text())
checks=0
def check(ok,why=''):
    global checks
    assert ok,why
    checks+=1

check(actual['status']=='PASS')
check(len(actual['profiles'])==len(prior['profiles'])==14)
summaries=[]
for p,ref in zip(actual['profiles'],prior['profiles']):
    for key in ('case','source','dd','mode','rows'):
        check(p[key]==ref[key],key)
    sets=[set(x) for x in ref['support_rows']]
    check(p['rho_vectors']==len(sets))
    for pi,plan in enumerate(p['plans']):
        order=plan['order']; check(sorted(order)==list(range(len(sets))))
        expected=[];rho_union=0;rho_members=0
        for ci in range(0,len(order),4):
            gs=order[ci:ci+4]
            byrow={}
            # Set insertions, unlike the Rust full-row scan.
            for local,g in enumerate(gs):
                for row in sets[g]: byrow[row]=byrow.get(row,0)|(1<<local)
            words=[16*r+mask for r,mask in sorted(byrow.items())]
            check(words==plan['words'][ci//4],'full packed plan')
            expected.append(words)
            rho_union+=len(words)*len(gs)
            rho_members+=sum(len(sets[g]) for g in gs)
            for local,g in enumerate(gs):
                decoded={w>>4 for w in words if w&(1<<local)}
                check(decoded==sets[g],'membership')
            for r in (ref['data'],ref['rows']-2,ref['rows']-1):
                if any(r in sets[g] for g in gs):
                    check(r in byrow,'reserved row')
        visits=sum(map(len,expected))
        check(visits==plan['union_visits'])
        check(rho_union==plan['rho_union_reads_per_column'])
        check(rho_members==plan['rho_membership_reads_per_column'])
        check(plan['index_bytes']==4*visits)
        check(rho_members==sum(map(len,sets)))
        if pi==0: check(visits==ref['structural_visits'])
        if p['source']:
            summaries.append(dict(dd=p['dd'],plan_index=pi,order=order,rows=p['rows'],n=ref['n'],groups=len(sets),union_visits=visits,rho_union_reads_per_column=rho_union,rho_membership_reads_per_column=rho_members,index_bytes=4*visits,construct_s=plan['construct_s'],validate_s=plan['validate_s']))

out=dict(status='PASS',checks=checks,fixtures=len(actual['profiles']),checked_values=sum(p['checked_values'] for p in actual['profiles']),negative_controls=sum(p['controls'] for p in actual['profiles']),source_checked_values=sum(p['checked_values'] for p in actual['profiles'] if p['source']),source_profiles=summaries,scope='Independent set model against prior source-derived support, not native define/FS/CUDA or independent external review')
(D/'census-result.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(out,indent=2))

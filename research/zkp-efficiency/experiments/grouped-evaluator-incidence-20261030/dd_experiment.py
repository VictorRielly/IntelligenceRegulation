"""Dictionary branch grouped round projection versus generic/direct cube."""
from pathlib import Path
from collections import Counter
import json,random,time,itertools
from field_support import F,P,lagrange,fold
from candidate import Rounds
import dd_projection as dd
import oracle as o
E=Path(__file__).resolve().parent;SEED=2026103016801

def generic_round(tables,ir,D,claim,debug):
    m=len(tables[0])//2;result=[F() for _ in range(D+1)]
    for i in range(m):
        low=[t[i] for t in tables];dif=[t[i+m]-t[i] for t in tables]
        for t in range(D+1):
            if t!=1 or claim is None or debug:
                value=o.poly(list(enumerate(ir)),list(map(o.tup,low)))
                result[t]+=F(*value)
            if t!=D:low=[a+b for a,b in zip(low,dif)]
    if claim is not None:
        got=claim-result[0]
        if debug:assert got==result[1]
        result[1]=got
    return result

def main():
    start=time.monotonic();rng=random.Random(SEED);checks=Counter();fixtures=[];controls=[]
    for n,mode in itertools.product(range(4),('full','base','zero','boolean')):
        cfg=dd.config()
        def draw():
            if mode=='zero':return F()
            if mode=='boolean':return F(rng.randrange(2))
            return F(rng.randrange(P),rng.randrange(P) if mode=='full' else 0)
        const={name:draw() for name in ['alpha','beta','gexp','gdd','gu8','lam','nu0','nu1']+['mu'+str(i) for i in range(6)]}
        for name in ['nu0','nu1']:
            if const[name]==0:const[name]=F(1)
        points=[[draw() for _ in range(n)],[draw() for _ in range(max(n-1,0))],[draw() for _ in range(n)]]
        tables=[]
        for p in points:tables.append([F(*o.eq(list(map(o.tup,p)),[(b,0) for b in o.bits(i,n)[:len(p)]])) for i in range(1<<n)])
        tables += [[draw() for _ in range(1<<n)] for _ in range(len(cfg['names'])-3)]
        ir=dd.expanded(cfg,const);original=[list(map(o.tup,t)) for t in tables]
        for _ in range(3):
            v=[draw() for _ in tables]
            for g in range(3):assert o.tup(dd.bracket(g,v,cfg,const)[0])==o.bracket(ir[g],list(map(o.tup,v)));checks['independent_clause_values']+=1
        ev=Rounds(tables,points,cfg,const,bracket_eval=dd.bracket)
        dbg=Rounds(tables,points,cfg,const,debug=True,bracket_eval=dd.bracket)
        generic=[list(t) for t in tables];claim=None;prefix=[];rounds=[];rs=[]
        for j in range(n):
            expected=[o.round_direct(original,list(enumerate(ir)),prefix,t,n) for t in range(5)]
            for got in [generic_round(generic,ir,4,claim,False),generic_round(generic,ir,4,claim,True),ev.round(j),dbg.round(j)]:
                assert list(map(o.tup,got))==expected,(n,mode,j);checks['round_values']+=5
            r=draw();rs.append(o.tup(r));rounds.append([o.tup(x) for x in got])
            claim=lagrange(got,r);generic=[fold(t,r) for t in generic];ev.fold(r);dbg.fold(r);prefix.append(o.tup(r))
            assert generic==ev.tables==dbg.tables;checks['folded_table_values']+=len(tables)*(1<<(n-j-1))
        finals=[o.mle(t,prefix) for t in original]
        assert list(map(o.tup,ev.finals()))==list(map(o.tup,dbg.finals()))==finals;checks['ordered_final_values']+=2*len(finals)
        fixtures.append(dict(n=n,mode=mode,cfg=cfg,constants={k:o.tup(v) for k,v in const.items()},points=[[o.tup(x) for x in p] for p in points],tables=original,challenges=rs,rounds=rounds,finals=finals,counts=dict(ev.counts),records=ev.records))
        checks['fixtures']+=1
    cfg=dd.config();const={k:F(rng.randrange(P),rng.randrange(P)) for k in ['alpha','beta','gexp','gdd','gu8','lam','nu0','nu1']+['mu'+str(i) for i in range(6)]}
    v=[F(rng.randrange(P),rng.randrange(P)) for _ in cfg['names']]
    honest=dd.bracket(0,v,cfg,const)[0]
    for mutation in ['drop_key','drop_mask_in_tuple']:
        assert dd.bracket(0,v,cfg,const,mutation)[0]!=honest;controls.append(mutation)
    per=[dd.bracket(g,v,cfg,const)[1] for g in range(3)]
    costs=[]
    for n in [7,14,23]:
        for recover in [False,True]:
            generic=Counter();grouped=Counter();bcalls=[0]*3;gcalls=[0]*3
            for j in range(n):
                m=1<<(n-j-1);S=5-int(recover and j>0)
                for g,d in enumerate([3,1,1]):
                    G=d+1-int(recover and j>0);bcalls[g]+=m*S;gcalls[g]+=m*G
                    for op,vv in per[g].items():generic[op]+=m*S*vv;grouped[op]+=m*G*vv
                # Generic full polynomial includes 3 Eq*bracket products and
                # 2 result adds; grouped includes suffix weights and outer
                # factor/degree completion separately (not silently free).
                generic['mul']+=m*S*3;generic['add']+=m*S*3
                # Literal grouped row setup always reconstructs 3 suffix
                # weights, including unit products. Each explicit bracket
                # then pays one weighted multiply and accumulator add.
                total_G=sum(d+1-int(recover and j>0) for d in [3,1,1])
                grouped['mul']+=m*(3+total_G);grouped['add']+=m*total_G
                for cc,dmax in [(generic,4),(grouped,3)]:
                    cc['sub']+=m*30;cc['mul']+=m*15;cc['add']+=m*(dmax*15+15)
            costs.append(dict(n=n,not_admitted_geometry=True,recovery=recover,generic_scan_fold=dict(generic),grouped_scan_fold=dict(grouped),generic_bracket_calls=bcalls,grouped_bracket_calls=gcalls,
                removed_scan_fold={op:generic[op]-grouped[op] for op in generic},
                excluded_added_costs=['group Eq prefix/suffix preparation','group inversions/recovery','degree completion','pending group values','unchanged whole-proof work'],
                warning='Row scan plus original-table fold census includes weighting; round setup/recovery/degree completion and whole-proof costs remain unpriced. Not a runtime estimate.'))
    result=dict(status='PASS',seed=SEED,checks=dict(checks),negative_controls=len(controls),wall_s=time.monotonic()-start,
        native_execution=False,proofs=0,proved_positions=0,verdict='Equality factoring is exact for tested dictionary SC_SZC projection; native masked/receipt/refusal gates and complete cost remain untested.')
    (E/'dd-fixtures.json').write_text(json.dumps(fixtures,separators=(',',':'))+'\n')
    (E/'dd-costs.json').write_text(json.dumps(costs,indent=2)+'\n');(E/'dd-controls.json').write_text(json.dumps(controls)+'\n')
    (E/'dd-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
if __name__=='__main__':main()

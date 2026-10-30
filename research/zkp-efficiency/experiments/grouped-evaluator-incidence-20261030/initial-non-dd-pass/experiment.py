"""Bounded arithmetic/operation study, no native proof or speed benchmark."""
from pathlib import Path
from collections import Counter
import json,random,time,hashlib,itertools
from field_support import F,P,bits,lagrange
from source_port import layout,bracket
from polynomial_ir import expanded
from candidate import Rounds,plan,dependencies
import oracle as o
E=Path(__file__).resolve().parent;SEED=20261030168

def tup(x):return (x.a,x.b)
def fixture(n,ls,pad,mode,rng):
    def draw():
        if mode=='zero':return F()
        if mode=='boolean':return F(rng.randrange(2))
        return F(rng.randrange(P),rng.randrange(P) if mode=='full' else 0)
    cfg=layout(ls=ls,padded=pad)
    names=['alpha','beta','gexp','gu8','lam','nu0','nu1','zeta','mupad']+['mu'+str(i) for i in range(6+cfg['helpers'])]
    const={name:draw() for name in names}
    for name in ['nu0','nu1','zeta']:
        if const[name]==0:const[name]=F(1)
    points=[[draw() for _ in range(n)],[draw() for _ in range(max(n-1,0))],[draw() for _ in range(n)]]
    tables=[]
    for p in points:
        tables.append([F(*o.eq(list(map(tup,p)),[(b,0) for b in o.bits(i,n)[:len(p)]])) for i in range(1<<n)])
    for name in cfg['names'][3:]:
        values=[draw() for _ in range(1<<n)]
        if name in ('mx','sum','ght') and n:
            values=[values[i>>1] for i in range(1<<n)]
        if name=='mask':values=[F(int(i%3!=1)) for i in range(1<<n)]
        if name in ('ght','gs'):values=[F(int((i>>1)<max(1,(1<<max(n-1,0))-1) and (name=='ght' or i%2==0))) for i in range(1<<n)]
        tables.append(values)
    challenges=[draw() for _ in range(n)]
    # Force genuine extension challenges in full mode, no reuse across fixtures.
    return cfg,const,points,tables,challenges

def expected_counts(cfg,records,sliced):
    out=Counter();k=len(cfg['names']);a=k-3 if sliced else k
    d=4 if cfg['padded'] else 3
    for r in records:
        m=r['pairs'];out.update(distinct_endpoint_reads=2*a*m,difference_sub=a*m,interpolation_add=d*a*m)
        for g,calls in enumerate(r['calls']):
            cc=bracket(g,[F(5,7)]*k,cfg,{key:F(17,23) for key in ['alpha','beta','gexp','gu8','lam','nu0','nu1','zeta','mupad']+['mu'+str(i) for i in range(6+cfg['helpers'])]})[1]
            out.update({'bracket_'+op:v*calls for op,v in cc.items()})
    return out

def census(n,ls,pad,recovery):
    cfg=layout(ls=ls,padded=pad);k=len(cfg['names']);degrees=[4,2,2] if pad else [3,1,1]
    const={key:F(17,23) for key in ['alpha','beta','gexp','gu8','lam','nu0','nu1','zeta','mupad']+['mu'+str(i) for i in range(6+cfg['helpers'])]}
    per=[bracket(g,[F(5,7)]*k,cfg,const)[1] for g in range(3)]
    before=Counter();after=Counter();calls=[0]*3
    for j in range(n):
        m=1<<(n-j-1)
        for g,d in enumerate(degrees):
            c=m*(d+1-int(recovery and j>0));calls[g]+=c
            for op,v in per[g].items():before[op]+=v*c;after[op]+=v*c
            # One suffix split-weight product per pair + weighted sample mul/add.
            before['mul']+=m+c;after['mul']+=m+c
            before['add']+=c;after['add']+=c
        # Original table folds are retained in both arms.
        for cc,a in [(before,k),(after,k-3)]:
            cc['sub']+=m*(a+k);cc['add']+=m*(a*max(degrees)+k);cc['mul']+=m*k
            cc['distinct_endpoint_reads']+=2*m*(a+k);cc['table_fold_writes']+=m*k
    removed={op:before[op]-after[op] for op in before}
    api_before=sum(before[x] for x in ['mul','mul_base','add','sub'])
    api_after=sum(after[x] for x in ['mul','mul_base','add','sub'])
    return dict(n=n,limbs_sigma_s=ls,limbs_p=2,padded=pad,k=k,degrees=degrees,
        count_only=True,not_admitted_geometry=True,recovery_assumption='nonzero subsequent factors' if recovery else 'explicit/debug/fallback',
        baseline=dict(before),candidate=dict(after),removed=removed,bracket_calls=calls,
        fraction_of_counted_api_calls_removed=(api_before-api_after)/api_before,
        logical_round_plus_fold_distinct_endpoint_read_fraction_removed=removed['distinct_endpoint_reads']/before['distinct_endpoint_reads'],
        extra_scratch_payload='k public last-sample indices; cur/dif dense allocations unchanged',
        excluded=['table building','Eq split/factor setup','inversions','degree completion','group recovery/reduction','masks','extensions','transcript/RNG','witness','PCS/commitments','transfers','serialization','verification'])

def main():
    start=time.monotonic();rng=random.Random(SEED);checks=Counter();fixtures=[];controls=[];digest=hashlib.sha256()
    for n,ls,pad,mode in itertools.product(range(4),(2,3),(False,True),('full','base','zero','boolean')):
        cfg,const,points,tables,rs=fixture(n,ls,pad,mode,rng);ir=expanded(cfg,const)
        original=[list(map(tup,t)) for t in tables];groups=list(enumerate(ir))
        base=Rounds(tables,points,cfg,const);cand=Rounds(tables,points,cfg,const,sliced=True)
        debug=Rounds(tables,points,cfg,const,sliced=True,debug=True)
        prefix=[];saved=[]
        for j,r in enumerate(rs):
            expected=[o.round_direct(original,groups,prefix,t,n) for t in range(base.D+1)]
            for ev in (base,cand,debug):
                got=ev.round(j);assert list(map(tup,got))==expected,(n,ls,pad,mode,j)
                checks['round_values']+=len(got)
            assert cand.pending==base.pending==debug.pending;checks['group_round_vectors']+=3
            for v in cand.pending:
                for x in v:digest.update(x.wire())
            saved.append([[list(tup(x)) for x in v] for v in cand.pending])
            for ev in (base,cand,debug):ev.fold(r)
            assert cand.tables==base.tables==debug.tables;checks['complete_table_fold_values']+=len(tables)*(1<<(n-j-1))
            prefix.append(tup(r))
        finals=[o.mle(t,prefix) for t in original]
        for ev in (base,cand,debug):
            assert list(map(tup,ev.finals()))==finals;checks['ordered_finals']+=len(finals)
        for ev,sliced in [(base,False),(cand,True),(debug,True)]:
            cc=expected_counts(cfg,ev.records,sliced)
            for key,v in cc.items():assert ev.counts[key]==v,(key,v,ev.counts[key])
            checks['closed_form_counts']+=len(cc)
        assert all(cand.counts[k]==base.counts[k] for k in base.counts if k.startswith('bracket_'))
        checks['unchanged_bracket_census']+=1
        fixtures.append(dict(n=n,ls=ls,padded=pad,mode=mode,k=len(tables),points=[[list(tup(x)) for x in p] for p in points],
            challenges=[list(tup(r)) for r in rs],tables=original,constants={k:list(tup(v)) for k,v in const.items()},
            round_group_vectors=saved,finals=finals,base_counts=dict(base.counts),candidate_counts=dict(cand.counts),
            candidate_records=cand.records))
        checks['fixtures']+=1
    # Independently derive table-use sets from expanded equations at generic
    # nonzero constants; never derive a public plan from private zero values.
    for ls,pad in itertools.product((2,3),(False,True)):
        cfg,const,_,_,_=fixture(1,ls,pad,'full',rng)
        ir=expanded(cfg,const);seen=[set(i for coef,mon in terms for i in mon) for terms in ir]
        assert seen==dependencies(cfg),(seen,dependencies(cfg));checks['independent_dependency_sets']+=3
        last=plan(len(cfg['names']),[4,2,2] if pad else [3,1,1],seen)
        assert last[:3]==[-1]*3 and len(set(last[3:]))==1;checks['no_unique_host_columns']+=1
    # Wrong public table-use maps alter values on arbitrary field inputs.
    cfg,const,points,tables,rs=fixture(3,3,True,'full',rng)
    ref=Rounds(tables,points,cfg,const).round(0);last=plan(len(tables),[4,2,2],dependencies(cfg))
    for name,index,value in [('drop_sum',cfg['index']['sum'],-1),('drop_exp_helper',cfg['index']['hx'],-1),('stop_support_at_host_degree',cfg['index']['gs'],2),('stop_s8_at_zero',cfg['index']['s8'],0)]:
        bad=list(last);bad[index]=value
        got=Rounds(tables,points,cfg,const,sliced=True,override=bad).round(0)
        assert got!=ref,name;controls.append(name)
    for deps,d,k,name in [([{0},{0},{99}],[4,2,2],30,'out_of_range_plan'),([{0}],[0],1,'zero_degree_plan'),([{0}],[],1,'group_count_plan')]:
        try:plan(k,d,deps)
        except AssertionError:controls.append(name)
        else:raise AssertionError(name)
    for name,fn in [('round_order',lambda:Rounds(tables,points,cfg,const).round(1)),('fold_without_round',lambda:Rounds(tables,points,cfg,const).fold(F(3))),('premature_finals',lambda:Rounds(tables,points,cfg,const).finals()),('ragged_tables',lambda:Rounds([tables[0],tables[1][:-1]],points,cfg,const))]:
        try:fn()
        except AssertionError:controls.append(name)
        else:raise AssertionError(name)
    # Exact zero factor[1] triggers explicit fallback, never resampling.
    points=[[F(0)]*3,[F(0)]*2,[F(0)]*3]
    for i,p in enumerate(points):tables[i]=[F(*o.eq(list(map(tup,p)),[(b,0) for b in o.bits(x,3)[:len(p)]])) for x in range(8)]
    ev=Rounds(tables,points,cfg,const,sliced=True)
    for j in range(3):ev.round(j);ev.fold(F(0))
    assert ev.counts['zero_factor_fallbacks']>=3;controls.append('explicit_zero_factor_fallback')
    costs=[census(n,ls,pad,recovery) for n,ls,pad,recovery in itertools.product((1,7,14,23),(2,3),(False,True),(False,True))]
    (E/'fixtures.json').write_text(json.dumps(fixtures,separators=(',',':'))+'\n')
    (E/'costs.json').write_text(json.dumps(costs,indent=2)+'\n')
    (E/'negative-controls.json').write_text(json.dumps(controls,indent=2)+'\n')
    result=dict(status='PASS',seed=SEED,checks=dict(checks),negative_controls=len(controls),
        arithmetic_digest=digest.hexdigest(),counts_only_cost_cases=len(costs),wall_s=time.monotonic()-start,
        native_execution=False,gpu_execution=False,full_stack_proofs=0,proved_positions=0,
        result='Current non-DD SC_SZC has no host-only interpolation columns; all savings are the three already-known Eq columns. DD branch does not choose grouped evaluator.')
    (E/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
if __name__=='__main__':main()

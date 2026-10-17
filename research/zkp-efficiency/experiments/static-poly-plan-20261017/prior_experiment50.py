"""Exact prime-field SC_SZC synthetic differential, never a proof benchmark."""
import hashlib,itertools,json,os,random,resource,signal,time
from pathlib import Path
from collections import Counter
import coefficients
from coefficients import Coeff
from field_support import F,P
from fixtures import fixture,constants
from prepared import Plan,generalize
from candidate import CoefficientTerms
from axis_factory import AxisPlan,AxisRounds
from karatsuba_factory import KaratsubaPlan
from polynomial_ir import expanded
from prior_axis_experiment import dependencies,shape_fixture,shape_dependencies,cost_case
import oracle as o

HERE=Path(__file__).resolve().parent;SEED=2026101450

def build(cfg,con,ir,tabs,n,chunk,debug,deps,k=False,algorithm='karatsuba'):
    cls=KaratsubaPlan if k else AxisPlan
    kw=dict(algorithm=algorithm) if k else {}
    rp=cls(cfg,con,Plan(generalize(cfg),con['alpha'],con['gu8']),deps,**kw)
    groups=[(g,CoefficientTerms(ts,g,cfg,con,rp)) for g,ts in enumerate(ir)]
    return AxisRounds(tabs,n,5,groups,rp,chunk,debug),rp

def row_plan(cfg,con,deps,k):
    cls=KaratsubaPlan if k else AxisPlan
    rp=cls(cfg,con,Plan(generalize(cfg),con['alpha'],con['gu8']),deps)
    return rp

def pvalue(cs,t):
    z=o.Z
    for c in reversed(cs):z=o.add(o.mul(z,o.tup(t)),o.tup(c))
    return z

def multiply(a,b,algorithm):
    counts=Counter();coefficients.K_WORK.clear();coefficients.ALGORITHM=algorithm
    try:p=Coeff(a).multiply(Coeff(b),counts)
    finally:coefficients.ALGORITHM='schoolbook'
    return p,counts,coefficients.K_WORK.copy()

def project(shape,ls,rng):
    old=cost_case(shape,ls,rng);from source_port import layout
    cfg=layout(ls=ls,padded=True);con=constants(cfg,lambda:F(rng.randrange(P),rng.randrange(P)))
    deps=shape_dependencies(cfg,*shape);n=old['cube_log']
    b=row_plan(cfg,con,deps,False);a=row_plan(cfg,con,deps,True)
    vals=[F(rng.randrange(P),rng.randrange(P)) for _ in cfg['names']]
    delta=Counter();work=Counter();rows=[]
    for j in range(n):
        d=[F(rng.randrange(P),rng.randrange(P)) for _ in vals]
        for index,axes in deps.items():
            if j not in axes:d[index]=F()
        for rp in (b,a):rp.round_index=j;rp.counts.clear();rp.begin(vals,d)
        assert b.pending[0].c==a.pending[0].c
        q={k:a.counts[k]-b.counts[k] for k in set(a.counts)|set(b.counts)}
        count=1<<(n-j-1)
        for k,v in q.items():delta[k]+=count*v
        for k,v in a.k_work.items():work[k]+=count*v
        rows.append(dict(round=j,rows=count,delta_per_row=q,k_work_per_row=dict(a.k_work)))
        a.k_work.clear();a.end();b.end()
    before=Counter(old['after']);after=before.copy();after.update(delta)
    products=lambda c:5*c['mul']+2*c['mul_base']
    return dict(shape=old['shape'],limbs=ls,cube_log=n,baseline='cycle49 public-axis + weighted coefficient factory',
        before=dict(before),after=dict(after),delta=dict(delta),added_work=dict(work),
        base_products_before=products(before),base_products_after=products(after),
        base_product_fraction_removed=(products(before)-products(after))/products(before),
        api_before=sum(before.values()),api_after=sum(after.values()),api_fraction_change=(sum(after.values())-sum(before.values()))/sum(before.values()),
        break_even='C_Fp2mul > C_Fp2add + 2*C_Fp2sub + marginal width-dispatch/scratch cost per affine product',
        fixed_output_bytes=80,incremental_output_bytes=0,schedule=rows,
        limits='literal field API census; five base products per native Fp2mul, not timing; compiler/spills/peak/critical path unknown')

def main():
    start=time.perf_counter();signal.alarm(59)
    resource.setrlimit(resource.RLIMIT_CPU,(59,59));resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
    rng=random.Random(SEED);cc=Counter();controls=[];digest=hashlib.sha256();delta=Counter();recoveries=fallbacks=0
    draw=lambda:F(rng.randrange(P),rng.randrange(P))
    # Independent tuple-ring multiplication evaluation across all public widths.
    for la,lb,mode in itertools.product(range(1,6),range(1,6),('full','zero','boundary')):
        make=lambda:draw() if mode=='full' else F() if mode=='zero' else F(P-1,P-1)
        av=[make() for _ in range(la)];bv=[make() for _ in range(lb)]
        b,bc,_=multiply(av,bv,'schoolbook');a,ac,kw=multiply(av,bv,'karatsuba')
        assert a.c==b.c
        if la==lb==2:
            assert dict(bc)==dict(mul=4,add=1) and dict(ac)==dict(mul=3,add=2,sub=2)
        else:assert ac==bc
        for t in (F(),F(1),F(P-1,P-1),draw()):
            assert pvalue(a.c,t)==o.mul(pvalue(av,t),pvalue(bv,t));cc['independent_convolution_values']+=1
        cc['convolution_schedules']+=1
    for bad in ('bad_sign','drop_cross'):
        a=[F(2,3),F(4,5)];b=[F(6,7),F(8,9)]
        p,_,_=multiply(a,b,bad)
        assert pvalue(p.c,F(2,3))!=o.mul(pvalue(a,F(2,3)),pvalue(b,F(2,3)))
        controls.append(bad+'-independent-extension-detection')
    allfixtures=[fixture(n,ls,padded,mode,rng,even=even) for n,ls,padded,mode,even in
        itertools.product((0,1,2,3),(2,3),(False,True),('full','zero','boolean'),(False,True))]
    allfixtures += [shape_fixture(s,rng) for s in [(4,1,3,2,1),(4,1,3,2,2),(8,2,6,2,1),(8,2,6,2,2)]]
    for cfg,con,ir,tabs,rs in allfixtures:
        n=len(rs);deps=dependencies(cfg,tabs,n);originals=[o.table(t,n) for t in tabs]
        prefix=[];want=[]
        for j,r in enumerate(rs):
            want.append([o.round_direct(originals,list(enumerate(ir)),prefix,t,n) for t in range(6)]);prefix.append(o.tup(r))
        finals=[o.mle(t,prefix) for t in originals]
        for chunk,debug in itertools.product((1,3,7),(False,True)):
            b,bp=build(cfg,con,ir,tabs,n,chunk,debug,deps);a,ap=build(cfg,con,ir,tabs,n,chunk,debug,deps,True)
            for j,r in enumerate(rs):
                assert list(map(o.tup,a.round(j)))==list(map(o.tup,b.round(j)))==want[j]
                for group in a.pending:
                    for x in group:digest.update(x.wire())
                cc['independent_round_samples']+=6;a.fold(r);b.fold(r)
            assert list(map(o.tup,a.finals()))==list(map(o.tup,b.finals()))==finals
            assert a.work==b.work and ap.eval_counts==bp.eval_counts and ap.axis_work==bp.axis_work
            assert a.data_fold_ops==b.data_fold_ops and a.recoveries==b.recoveries and a.zero_fallbacks==b.zero_fallbacks
            cc['independent_final_values']+=len(finals);cc['full_schedules']+=1
            for k in set(ap.counts)|set(bp.counts):delta[k]+=ap.counts[k]-bp.counts[k]
            count=ap.k_work['affine_products']
            assert ap.counts['mul']-bp.counts['mul']==-count
            assert ap.counts['add']-bp.counts['add']==count
            assert ap.counts['sub']-bp.counts['sub']==2*count
            cc['executed_row_census_checks']+=1
            recoveries+=a.recoveries;fallbacks+=a.zero_fallbacks
        cc['fixtures']+=1
    # Original full clause at arbitrary extension coordinates, and zero values
    # with identical public shapes/metadata give identical operation schedules.
    from source_port import layout
    cfg=layout(ls=3,padded=True)
    for inactive in itertools.product((False,True),repeat=3):
        con=constants(cfg,draw);ir=expanded(cfg,con);vals=[draw() for _ in cfg['names']];ds=[draw() for _ in vals]
        deps={cfg['index'][name]:set() if flag else {0} for name,flag in zip(('mask','gs','ght'),inactive)}
        for k,axes in deps.items():
            if not axes:ds[k]=F()
        a=row_plan(cfg,con,deps,True);a.round_index=0;a.begin(vals,ds)
        for t in (F(),F(1),F(4),F(P-1,P-1),draw()):
            point=[o.add(o.tup(v),o.mul(o.tup(t),o.tup(d))) for v,d in zip(vals,ds)]
            assert pvalue(a.pending[0].c,t)==o.bracket(ir[0],point);cc['independent_clause_extension_values']+=1
        zcon={k:F() for k in con};z=row_plan(cfg,zcon,deps,True);z.round_index=0;z.begin([F() for _ in vals],[F() for _ in vals])
        assert a.counts==z.counts and a.k_work==z.k_work and a.axis_work==z.axis_work
        assert len(a.pending[0].c)==len(z.pending[0].c)==5;cc['value_independent_schedule_checks']+=1
    controls.append('zero-private-values-retain-identical-operation-schedule')
    # Full-round mutation controls: scalar-only pair tests are insufficient.
    cfg,con,ir,tabs,rs=shape_fixture((4,1,3,2,1),rng);deps=dependencies(cfg,tabs,len(rs))
    for bad in ('bad_sign','drop_cross'):
        b,_=build(cfg,con,ir,tabs,len(rs),3,False,deps);a,_=build(cfg,con,ir,tabs,len(rs),3,False,deps,True,bad)
        found=False
        for j,r in enumerate(rs):
            if a.round(j)!=b.round(j):found=True;break
            a.fold(r);b.fold(r)
        assert found;controls.append(bad+'-full-round-detection')
    projections=[project(s,ls,rng) for s,ls in itertools.product([(16,4,12,512,512),(32,8,32,512,512),(32,8,24,1024,769)],(2,3))]
    proof=json.loads((HERE.parent/'public-axis-row-factory-20261013/result.json').read_text())['proof_accounting']
    result=dict(status='passed',run_id='20261014T203626Z-4afb917a',cycle='0050',seed=SEED,counts=dict(cc),controls=controls,
        recoveries=recoveries,zero_factor_fallbacks=fallbacks,executed_row_counter_delta=dict(delta),output_sha256=digest.hexdigest(),
        projections=projections,wall_seconds=time.perf_counter()-start,max_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        hardware=dict(device='CPU only',threads=1,affinity=sorted(os.sched_getaffinity(0)),nice=os.nice(0),
            cpu_model=next(x.split(':',1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name'))),
        limits=dict(wall_seconds=59,cpu_seconds=59,address_space_bytes=512*1024**2,estimated_bytes=64*1024**2),proof_accounting=proof)
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k!='projections'},indent=2))
    for p in projections:print('CENSUS',json.dumps({k:v for k,v in p.items() if k!='schedule'}))

if __name__=='__main__':main()

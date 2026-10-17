"""CPU-light synthetic SC_SZC differential and complete cost census, not a proof."""
import hashlib,itertools,json,os,random,resource,signal,time
from pathlib import Path
from collections import Counter
import coefficients
from field_support import F,P
from fixtures import fixture,constants
from prepared import Plan,generalize
from candidate import CoefficientTerms
from axis_factory import AxisRounds,shape_dependencies
from karatsuba_factory import KaratsubaPlan
from static_plan import StaticRowPlan,compile_mul
from polynomial_ir import expanded
from prior_axis_experiment import dependencies,shape_fixture
from source_port import layout
import oracle as o

HERE=Path(__file__).resolve().parent;SEED=2026101751

def make_plan(cfg,con,deps,candidate,mutation=None):
    cls=StaticRowPlan if candidate else KaratsubaPlan
    kw={'mutation':mutation} if candidate else {}
    return cls(cfg,con,Plan(generalize(cfg),con['alpha'],con['gu8']),deps,**kw)

def build(cfg,con,ir,tabs,n,chunk,debug,deps,candidate=False,mutation=None):
    rp=make_plan(cfg,con,deps,candidate,mutation)
    groups=[(g,CoefficientTerms(ts,g,cfg,con,rp)) for g,ts in enumerate(ir)]
    return AxisRounds(tabs,n,5,groups,rp,chunk,debug),rp

def pvalue(cs,t):
    z=o.Z
    for c in reversed(cs):z=o.add(o.mul(z,o.tup(t)),o.tup(c))
    return z

def baseline_mul(a,b):
    counts=Counter();coefficients.ALGORITHM='karatsuba'
    try:r=coefficients.Coeff(a).multiply(coefficients.Coeff(b),counts)
    finally:coefficients.ALGORITHM='schoolbook'
    return r,counts

def projection(old,rng):
    s=old['shape'];shape=tuple(s[k] for k in ('head_pad','kv_heads','query_heads','token_pad','tokens'))
    cfg=layout(ls=old['limbs'],padded=True);draw=lambda:F(rng.randrange(P),rng.randrange(P))
    con=constants(cfg,draw);deps=shape_dependencies(cfg,*shape);n=old['cube_log']
    b=make_plan(cfg,con,deps,False);a=make_plan(cfg,con,deps,True)
    vals=[draw() for _ in cfg['names']];delta=Counter();work=Counter();baseline_work=Counter();schedule=[]
    for j in range(n):
        ds=[draw() for _ in vals]
        for k,axes in deps.items():
            if j not in axes:ds[k]=F()
        for rp in (a,b):rp.round_index=j;rp.counts.clear();rp.k_work.clear();rp.begin(vals,ds)
        assert a.pending[0].c==b.pending[0].c
        dd={k:a.counts[k]-b.counts[k] for k in set(a.counts)|set(b.counts)};rows=1<<(n-j-1)
        for k,v in dd.items():delta[k]+=v*rows
        for k,v in a.k_work.items():work[k]+=v*rows
        for k,v in b.k_work.items():baseline_work[k]+=v*rows
        schedule.append(dict(round=j,rows=rows,delta_per_row=dd,candidate_work_per_row=dict(a.k_work)))
        a.end();b.end()
    before=Counter(old['after']);after=before.copy();after.update(delta)
    bp=lambda x:5*x['mul']+2*x['mul_base']
    record=a.plan_record();one_time_field={k[6:]:v for k,v in a.setup.items() if k.startswith('trace_') and k[6:] in ('mul','add','sub','mul_base')}
    # Explicitly charge preparation in a cold workload; no timing conversion.
    cold=after.copy();cold.update(one_time_field)
    return dict(shape=s,limbs=old['limbs'],cube_log=n,baseline='cycle50 fixed2x2 Karatsuba public-axis weighted factory',
                before=dict(before),after=dict(after),cold_after_with_trace=dict(cold),delta=dict(delta),
                base_products_before=bp(before),base_products_after=bp(after),
                base_product_fraction_removed=(bp(before)-bp(after))/bp(before),
                api_before=sum(before.values()),api_after=sum(after.values()),api_fraction_change=(sum(after.values())-sum(before.values()))/sum(before.values()),
                baseline_dispatch=dict(baseline_work),candidate_dispatch=dict(work),plan=record,schedule=schedule,
                break_even='saved_Fp2mul_cost > added_Fp2add + 2*added_Fp2sub per blocked32; plus trace/plan/cursor/code/scratch delta',
                limits='Field API census only. Cursor and interpreter opcodes remain; native unrolling is untested. No register/time prediction.')

def main():
    start=time.perf_counter();signal.alarm(59)
    resource.setrlimit(resource.RLIMIT_CPU,(59,59));resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
    rng=random.Random(SEED);draw=lambda:F(rng.randrange(P),rng.randrange(P))
    cc=Counter();controls=[];digest=hashlib.sha256();delta=Counter();recoveries=fallbacks=0
    kernels=[]
    for la,lb in itertools.product(range(1,6),repeat=2):
        plan=compile_mul(la,lb);kernels.append(plan.record())
        for mode in ('full','zero','boundary','sparse'):
            v=lambda i:draw() if mode=='full' else F() if mode=='zero' or mode=='sparse' and i else F(P-1,P-1)
            av=[v(i) for i in range(la)];bv=[v(i) for i in range(lb)];bc=Counter()
            b,baseline=baseline_mul(av,bv);a=plan.execute(av,bv,bc);assert a.c==b.c
            if (la,lb) in ((2,3),(3,2)):
                assert bc==Counter(mul=5,add=3,sub=2) and baseline==Counter(mul=6,add=2)
            else:assert bc==baseline
            for t in (F(),F(1),F(P-1,P-1),draw()):
                assert pvalue(a.c,t)==o.mul(pvalue(av,t),pvalue(bv,t));cc['independent_convolution_values']+=1
            cc['convolution_schedules']+=1
    for mut in ('wrong_sign','dropped_tail'):
        av=[F(2,3),F(4,5),F(10,11)];bv=[F(6,7),F(8,9)]
        a=compile_mul(3,2).execute(av,bv,Counter(),mut)
        assert pvalue(a.c,F(2,3))!=o.mul(pvalue(av,F(2,3)),pvalue(bv,F(2,3)))
        controls.append(mut+'-independent-convolution')
    fixtures=[fixture(n,ls,padded,mode,rng,even=even) for n,ls,padded,mode,even in
              itertools.product((0,1,2,3),(2,3),(False,True),('full','zero','boolean'),(False,True))]
    fixtures += [shape_fixture(s,rng) for s in [(4,1,3,2,1),(4,1,3,2,2),(8,2,6,2,1),(8,2,6,2,2)]]
    setup_total=Counter();plan_sizes=[]
    for cfg,con,ir,tabs,rs in fixtures:
        n=len(rs);deps=dependencies(cfg,tabs,n);originals=[o.table(t,n) for t in tabs];prefix=[];want=[]
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
            count=ap.k_work['blocked32'];dd={k:ap.counts[k]-bp.counts[k] for k in set(ap.counts)|set(bp.counts)}
            assert dd.get('mul',0)==-count and dd.get('add',0)==count and dd.get('sub',0)==2*count
            delta.update(dd);setup_total.update(ap.setup);plan_sizes.append(ap.plan_record()['logical_plan_pointer_bytes'])
            cc['executed_row_census_checks']+=1;cc['independent_final_values']+=len(finals);cc['full_schedules']+=1
            recoveries+=a.recoveries;fallbacks+=a.zero_fallbacks
        cc['fixtures']+=1
    cfg=layout(ls=3,padded=True)
    for inactive in itertools.product((False,True),repeat=3):
        con=constants(cfg,draw);ir=expanded(cfg,con);vals=[draw() for _ in cfg['names']];ds=[draw() for _ in vals]
        deps={cfg['index'][name]:set() if flag else {0} for name,flag in zip(('mask','gs','ght'),inactive)}
        for k,axes in deps.items():
            if not axes:ds[k]=F()
        a=make_plan(cfg,con,deps,True);a.round_index=0;a.begin(vals,ds)
        for t in (F(),F(1),F(4),F(P-1,P-1),draw()):
            point=[o.add(o.tup(v),o.mul(o.tup(t),o.tup(d))) for v,d in zip(vals,ds)]
            assert pvalue(a.pending[0].c,t)==o.bracket(ir[0],point);cc['independent_clause_extension_values']+=1
        z=make_plan(cfg,{k:F() for k in con},deps,True);z.round_index=0;z.begin([F() for _ in vals],[F() for _ in vals])
        assert a.counts==z.counts and a.k_work==z.k_work and a.setup==z.setup
        assert a.plan_record()['schema_sha256']==z.plan_record()['schema_sha256']
        assert len(a.pending[0].c)==len(z.pending[0].c)==5;cc['value_independent_schedule_checks']+=1
    controls.append('zero-random-private-values-and-public-challenges-identical-schema-and-counts')
    cfg,con,ir,tabs,rs=shape_fixture((4,1,3,2,1),rng);deps=dependencies(cfg,tabs,len(rs))
    for mut in ('wrong_sign','dropped_tail','wrong_order'):
        b,_=build(cfg,con,ir,tabs,len(rs),3,False,deps);a,_=build(cfg,con,ir,tabs,len(rs),3,False,deps,True,mut)
        found=False
        try:
            for j,r in enumerate(rs):
                if a.round(j)!=b.round(j):found=True;break
                a.fold(r);b.fold(r)
        except (IndexError,AssertionError,StopIteration):found=True
        assert found;controls.append(mut+'-full-round-rejection')
    old=json.loads((HERE/'prior-affine-karatsuba-20261014.json').read_text())
    projections=[projection(p,rng) for p in old['projections']]
    result=dict(status='passed',run_id='20261017T012624Z-ea61e714',cycle='0051',seed=SEED,counts=dict(cc),controls=controls,
                recoveries=recoveries,zero_factor_fallbacks=fallbacks,executed_row_counter_delta=dict(delta),
                test_preparation_totals=dict(setup_total),max_test_plan_pointer_bytes=max(plan_sizes),kernel_plans=kernels,
                output_sha256=digest.hexdigest(),projections=projections,wall_seconds=time.perf_counter()-start,
                max_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                hardware=dict(device='CPU only',threads=1,affinity=sorted(os.sched_getaffinity(0)),nice=os.nice(0),
                              cpu_model=next(x.split(':',1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name'))),
                limits=dict(wall_seconds=59,cpu_seconds=59,address_space_bytes=512*1024**2,estimated_bytes=64*1024**2),
                proof_accounting=old['proof_accounting'])
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ('projections','kernel_plans')},indent=2))
    for p in projections:print('CENSUS',json.dumps({k:v for k,v in p.items() if k not in ('plan','schedule')}))

if __name__=='__main__':main()

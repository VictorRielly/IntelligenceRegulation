"""Bounded full-row public CSE, structural-square ablation and independent oracle."""
import hashlib,itertools,json,os,random,resource,signal,time
from pathlib import Path
from collections import Counter
from field_support import F,P
from fixtures import fixture,constants
from prepared import Plan,generalize
from candidate import CoefficientTerms
from axis_factory import AxisRounds,shape_dependencies
from static_plan import StaticRowPlan
from row_graph import CSERowPlan
from polynomial_ir import expanded
from prior_axis_experiment import dependencies,shape_fixture
from source_port import layout
import oracle as o

HERE=Path(__file__).resolve().parent;SEED=2026101752

def make(cfg,con,deps,mode,mutation=None):
    args=(cfg,con,Plan(generalize(cfg),con['alpha'],con['gu8']),deps)
    if mode=='prior':return StaticRowPlan(*args)
    return CSERowPlan(*args,cse=mode!='raw',squares=mode=='square',mutation=mutation)

def build(cfg,con,ir,tabs,n,chunk,debug,deps,mode,mutation=None):
    rp=make(cfg,con,deps,mode,mutation)
    gs=[(g,CoefficientTerms(ts,g,cfg,con,rp)) for g,ts in enumerate(ir)]
    return AxisRounds(tabs,n,5,gs,rp,chunk,debug),rp

def ev(cs,t):
    z=o.Z
    for c in reversed(cs):z=o.add(o.mul(z,o.tup(t)),o.tup(c))
    return z

def projection(old,rng):
    s=old['shape'];shape=tuple(s[k] for k in ('head_pad','kv_heads','query_heads','token_pad','tokens'))
    cfg=layout(ls=old['limbs'],padded=True);draw=lambda:F(rng.randrange(P),rng.randrange(P))
    con=constants(cfg,draw);deps=shape_dependencies(cfg,*shape);n=old['cube_log']
    plans={mode:make(cfg,con,deps,mode) for mode in ('prior','raw','cse','square')}
    vals=[draw() for _ in cfg['names']];totals={k:Counter() for k in plans};steps=Counter();schedule=[]
    for j in range(n):
        ds=[draw() for _ in vals]
        for k,axes in deps.items():
            if j not in axes:ds[k]=F()
        per={}
        for mode,rp in plans.items():
            rp.round_index=j;rp.counts.clear();rp.k_work.clear();rp.begin(vals,ds)
            per[mode]=dict(rp.counts)
            assert rp.pending[0].c==plans['prior'].pending[0].c
        assert per['raw']==per['prior'],(per['raw'],per['prior'])
        rows=1<<(n-j-1)
        for mode in plans:
            for k,v in per[mode].items():totals[mode][k]+=v*rows
        steps.update({k:v*rows for k,v in plans['square'].k_work.items()})
        schedule.append(dict(round=j,rows=rows,per_row=per))
        for rp in plans.values():rp.end()
    delta={mode:{k:totals[mode][k]-totals['prior'][k] for k in set(totals[mode])|set(totals['prior'])} for mode in ('raw','cse','square')}
    before=Counter(old['after']);after=before.copy();after.update(delta['square'])
    bp=lambda d:5*d['mul']+2*d['mul_base']
    records={mode:[g.record() for g in rp.graphs.values()] for mode,rp in plans.items() if mode!='prior'}
    return dict(shape=s,limbs=old['limbs'],cube_log=n,before=dict(before),after=dict(after),delta_by_mode=delta,
        base_products_before=bp(before),base_products_after=bp(after),base_fraction_removed=(bp(before)-bp(after))/bp(before),
        api_before=sum(before.values()),api_after=sum(after.values()),api_fraction_removed=(sum(before.values())-sum(after.values()))/sum(before.values()),
        row_factory_totals={k:dict(v) for k,v in totals.items()},graphs=records,schedule=schedule,candidate_dispatch=dict(steps),
        public_pad_setup=dict(plans['square'].setup),
        limits='Counts only; graph includes literal operations and live-word model, not machine instructions. Native compiler may already CSE. Full critical-path clocks unknown.')

def main():
    start=time.perf_counter();signal.alarm(59)
    resource.setrlimit(resource.RLIMIT_CPU,(59,59));resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
    rng=random.Random(SEED);draw=lambda:F(rng.randrange(P),rng.randrange(P))
    cc=Counter();controls=[];digest=hashlib.sha256();delta=Counter();recoveries=fallbacks=0
    fixtures=[fixture(n,ls,padded,mode,rng,even=even) for n,ls,padded,mode,even in
        itertools.product((0,1,2,3),(2,3),(False,True),('full','zero','boolean'),(False,True))]
    fixtures += [shape_fixture(s,rng) for s in [(4,1,3,2,1),(4,1,3,2,2),(8,2,6,2,1),(8,2,6,2,2)]]
    for cfg,con,ir,tabs,rs in fixtures:
        n=len(rs);deps=dependencies(cfg,tabs,n);originals=[o.table(t,n) for t in tabs];prefix=[];want=[]
        for j,r in enumerate(rs):
            want.append([o.round_direct(originals,list(enumerate(ir)),prefix,t,n) for t in range(6)]);prefix.append(o.tup(r))
        finals=[o.mle(t,prefix) for t in originals]
        for chunk,debug in itertools.product((1,3,7),(False,True)):
            b,bp=build(cfg,con,ir,tabs,n,chunk,debug,deps,'prior');a,ap=build(cfg,con,ir,tabs,n,chunk,debug,deps,'square')
            for j,r in enumerate(rs):
                assert list(map(o.tup,a.round(j)))==list(map(o.tup,b.round(j)))==want[j]
                for group in a.pending:
                    for x in group:digest.update(x.wire())
                cc['independent_round_samples']+=6;a.fold(r);b.fold(r)
            assert list(map(o.tup,a.finals()))==list(map(o.tup,b.finals()))==finals
            assert a.work==b.work and ap.eval_counts==bp.eval_counts and ap.axis_work==bp.axis_work
            assert a.data_fold_ops==b.data_fold_ops and a.recoveries==b.recoveries and a.zero_fallbacks==b.zero_fallbacks
            delta.update({k:ap.counts[k]-bp.counts[k] for k in set(ap.counts)|set(bp.counts)})
            cc['full_schedules']+=1;cc['independent_final_values']+=len(finals)
            recoveries+=a.recoveries;fallbacks+=a.zero_fallbacks
        cc['fixtures']+=1
    for ls,lp,count in itertools.product((2,3),(1,2),(1,2,3,4,5,6,7,8)):
        cfg=layout(ls=ls,lp=lp,padded=True,lookup_count=count)
        for inactive in itertools.product((False,True),repeat=3):
            con=constants(cfg,draw);ir=expanded(cfg,con);vals=[draw() for _ in cfg['names']];ds=[draw() for _ in vals]
            deps={cfg['index'][name]:set() if flag else {0} for name,flag in zip(('mask','gs','ght'),inactive)}
            for k,axes in deps.items():
                if not axes:ds[k]=F()
            plans={mode:make(cfg,con,deps,mode) for mode in ('prior','raw','cse','square')}
            for mode,rp in plans.items():rp.round_index=0;rp.begin(vals,ds)
            assert plans['raw'].counts==plans['prior'].counts
            for rp in plans.values():assert rp.pending[0].c==plans['prior'].pending[0].c
            for t in (F(),F(1),F(P-1,P-1),draw()):
                point=[o.add(o.tup(v),o.mul(o.tup(t),o.tup(d))) for v,d in zip(vals,ds)]
                assert ev(plans['square'].pending[0].c,t)==o.bracket(ir[0],point)
                cc['independent_clause_extension_values']+=1
            z=make(cfg,{k:F() for k in con},deps,'square');z.round_index=0;z.begin([F() for _ in vals],[F() for _ in vals])
            a=plans['square'];assert a.counts==z.counts and a.k_work==z.k_work
            assert [g.record()['schema_sha256'] for g in a.graphs.values()]==[g.record()['schema_sha256'] for g in z.graphs.values()]
            cc['value_independent_schema_checks']+=1;cc['baseline_counter_parity_checks']+=1
    controls.append('zero-random-values-and-challenges-identical-symbolic-schema-counts')
    cfg,con,ir,tabs,rs=shape_fixture((4,1,3,2,1),rng);deps=dependencies(cfg,tabs,len(rs))
    for mut in ('sub_sign','drop_tail'):
        a,_=build(cfg,con,ir,tabs,len(rs),3,False,deps,'square',mut)
        found=False
        for j,r in enumerate(rs):
            if list(map(o.tup,a.round(j))) != [o.round_direct([o.table(t,len(rs)) for t in tabs],list(enumerate(ir)),list(map(o.tup,rs[:j])),t,len(rs)) for t in range(6)]:found=True;break
            a.fold(r)
        assert found;controls.append(mut+'-independent-round-detected')
    # Invalid structural-square substitution: two distinct symbolic inputs
    # with equal concrete values must retain different input nodes.
    from row_graph import Graph
    from coefficients import Coeff
    g=Graph(True,True);x=[g.input(('x',i)) for i in range(2)];y=[g.input(('y',i)) for i in range(2)]
    poly=g.multiply(Coeff(x),Coeff(y),Counter());g.outputs=tuple(v.index for v in poly.c)
    assert g.setup['structural_square_sites']==0
    vals={('x',0):F(2,3),('x',1):F(4,5),('y',0):F(2,3),('y',1):F(4,5)}
    assert ev(g.run(vals)[0].c,F(7,8))==o.mul(ev([vals['x',0],vals['x',1]],F(7,8)),ev([vals['y',0],vals['y',1]],F(7,8)))
    vals['y',1]=F(9,10)
    xx=ev([vals['x',0],vals['x',1]],F(7,8));yy=ev([vals['y',0],vals['y',1]],F(7,8))
    assert ev(g.run(vals)[0].c,F(7,8))==o.mul(xx,yy)!=o.mul(xx,xx)
    cc['distinct_input_identity_control']+=1;controls.append('equal-values-distinct-inputs-not-structural-square')
    old=json.loads((HERE/'prior-result.json').read_text());projections=[projection(p,rng) for p in old['projections']]
    result=dict(status='passed',run_id='20261017T022624Z-f3bec81b',cycle='0052',seed=SEED,counts=dict(cc),controls=controls,
        recoveries=recoveries,zero_factor_fallbacks=fallbacks,executed_row_delta=dict(delta),output_sha256=digest.hexdigest(),
        projections=projections,wall_seconds=time.perf_counter()-start,max_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        hardware=dict(device='CPU only',threads=1,affinity=sorted(os.sched_getaffinity(0)),nice=os.nice(0),cpu_model=next(x.split(':',1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name'))),
        limits=dict(wall_seconds=59,cpu_seconds=59,address_space_bytes=512*1024**2,estimated_bytes=64*1024**2),proof_accounting=old['proof_accounting'])
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k!='projections'},indent=2))
    for p in projections:print('CENSUS',json.dumps({k:v for k,v in p.items() if k not in ('graphs','schedule')}))

if __name__=='__main__':main()

#!/usr/bin/env python3
"""Bounded exact public-axis differential checks and literal cost accounting."""
import hashlib,itertools,json,os,random,resource,signal,time
from collections import Counter
from pathlib import Path
from field_support import F,P
from fixtures import fixture,constants
from prepared import Plan,generalize
from candidate import RowPlan,CoefficientTerms
from axis_factory import AxisPlan,AxisRounds,measured_dependencies,shape_dependencies,prefix_bits
from weighted_rounds import WeightedRounds
from polynomial_ir import expanded
from coefficients import Coeff
import oracle as o

HERE=Path(__file__).resolve().parent; SEED=2026101349

def dependencies(cfg,tabs,n):
    return {cfg['index'][name]:measured_dependencies(tabs[cfg['index'][name]]['words'],n)
        for name in ('mask','gs','ght') if name in cfg['index']}

def build(cfg,con,ir,tabs,n,chunk,debug,deps=None,mutation=None):
    p=Plan(generalize(cfg),con['alpha'],con['gu8'])
    rp=RowPlan(cfg,con,p) if deps is None else AxisPlan(cfg,con,p,deps,mutation)
    groups=[(g,CoefficientTerms(ts,g,cfg,con,rp)) for g,ts in enumerate(ir)]
    cls=WeightedRounds if deps is None else AxisRounds
    return cls(tabs,n,5,groups,rp,chunk,debug),rp

def public_tables(hp,kv,qh,tp,tokens):
    # Independently enumerate logical true heads via the native head_slot rule,
    # rather than using candidate BitForm dependencies or gate formulas.
    group=qh//kv; per=hp//kv
    true={(h//group)*per+h%group for h in range(qh)}
    mask=[];gs=[];ght=[]
    for h,t,j in itertools.product(range(hp),range(tp),range(tp)):
        mask.append(F(int(j<=t)))
        gs.append(F(int(h in true and t<tokens and j<tokens)))
        ght.append(F(int(h in true and t<tokens)))
    return dict(mask=mask,gs=gs,ght=ght)

def shape_fixture(shape,rng):
    hp,kv,qh,tp,tokens=shape; n=(hp*tp*tp).bit_length()-1
    cfg,con,ir,tabs,rs=fixture(n,3,True,'full',rng)
    for name,words in public_tables(*shape).items(): tabs[cfg['index'][name]]=dict(kind='Pub',words=words)
    return cfg,con,ir,tabs,rs

def cost_case(shape,ls,rng):
    hp,kv,qh,tp,tokens=shape; n=(hp*tp*tp).bit_length()-1
    from source_port import layout
    from weighted_experiment import projection
    cfg=layout(ls=ls,padded=True);con=constants(cfg,lambda:F(rng.randrange(P),rng.randrange(P)))
    deps=shape_dependencies(cfg,*shape);p=Plan(generalize(cfg),con['alpha'],con['gu8'])
    before=RowPlan(cfg,con,p);after=AxisPlan(cfg,con,p,deps)
    total=Counter();schedule=[]
    vals=[F(rng.randrange(P),rng.randrange(P)) for _ in cfg['names']]
    for j in range(n):
        rows=1<<(n-j-1);dif=[F(rng.randrange(P),rng.randrange(P)) for _ in vals]
        for k,axes in deps.items():
            if j not in axes: dif[k]=F()
        before.counts.clear();after.counts.clear();after.axis_work.clear();after.round_index=j
        before.begin(vals,dif);after.begin(vals,dif)
        assert before.pending[0].c==after.pending[0].c
        delta={k:after.counts[k]-before.counts[k] for k in set(after.counts)|set(before.counts)}
        for k,v in delta.items():total[k]+=rows*v
        schedule.append(dict(round=j,rows=rows,independent_public_roles=[name for name in ('mask','gs','ght') if j not in deps[cfg['index'][name]]],
            before=dict(before.counts),after=dict(after.counts),delta=delta,axis_work_per_row=dict(after.axis_work)))
        before.end();after.end()
    old=projection(n,ls,True,True,False,1024,'public_half')
    b=Counter(old['after']);a=b.copy()
    for k,v in total.items():a[k]+=v
    bb=5*b['mul']+2*b['mul_base'];aa=5*a['mul']+2*a['mul_base']
    return dict(shape=dict(head_pad=hp,kv_heads=kv,query_heads=qh,token_pad=tp,tokens=tokens),cube_log=n,limbs=ls,
        baseline='cycle48 weighted coefficients, release sample1 recovery, part chunk1024',before=dict(b),after=dict(a),delta=dict(total),
        base_products_before=bb,base_products_after=aa,base_product_fraction_removed=(bb-aa)/bb,
        api_before=sum(b.values()),api_after=sum(a.values()),api_fraction_removed=(sum(b.values())-sum(a.values()))/sum(b.values()),
        public_axis_tests=3*((1<<n)-1),zero_output_assignments=sum(s['rows']*s['axis_work_per_row'].get('zero_output_assignments',0) for s in schedule),
        fixed_group0_output_bytes=80,incremental_output_bytes=0,metadata_axis_entries=sum(len(v) for v in deps.values()),
        schedule=schedule,limits='literal field API census; dispatch, assignments and metadata separately charged; native instructions/spills/time/peak unknown')

def main():
    start=time.perf_counter();signal.alarm(59)
    resource.setrlimit(resource.RLIMIT_CPU,(59,59));resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
    rng=random.Random(SEED);cc=Counter();controls=[];digest=hashlib.sha256();differences=Counter();recoveries=fallbacks=0
    allfixtures=[fixture(n,ls,padded,mode,rng) for n,ls,padded,mode in itertools.product((0,1,2,3),(2,3),(False,True),('full','zero','boolean'))]
    shapes=[(4,1,3,2,1),(4,1,3,2,2),(8,2,6,2,1),(8,2,6,2,2)]
    allfixtures += [shape_fixture(s,rng) for s in shapes]
    for number,(cfg,con,ir,tabs,rs) in enumerate(allfixtures):
        n=len(rs);deps=dependencies(cfg,tabs,n)
        if number>=48:
            analytic=shape_dependencies(cfg,*shapes[number-48]);assert analytic==deps;cc['native_shape_dependency_matches']+=1
        originals=[o.table(tab,n) for tab in tabs];groups=list(enumerate(ir));prefix=[];want=[]
        for j,r in enumerate(rs):
            want.append([o.round_direct(originals,groups,prefix,t,n) for t in range(6)]);prefix.append(o.tup(r))
        finals=[o.mle(tab,prefix) for tab in originals]
        for chunk,debug in itertools.product((1,3,7),(False,True)):
            cand,rp=build(cfg,con,ir,tabs,n,chunk,debug,deps);base,bp=build(cfg,con,ir,tabs,n,chunk,debug)
            for j,r in enumerate(rs):
                assert list(map(o.tup,cand.round(j)))==list(map(o.tup,base.round(j)))==want[j]
                for v in cand.pending:
                    for x in v:digest.update(x.wire())
                cc['independent_round_samples']+=6;cand.fold(r);base.fold(r)
            assert list(map(o.tup,cand.finals()))==list(map(o.tup,base.finals()))==finals
            assert cand.work==base.work and rp.eval_counts==bp.eval_counts, 'weighted reduction/evaluation unchanged'
            assert cand.data_fold_ops==base.data_fold_ops and cand.recoveries==base.recoveries and cand.zero_fallbacks==base.zero_fallbacks
            cc['independent_final_values']+=len(finals);cc['schedules']+=1;cc['row_counter_comparisons']+=1
            for k in set(rp.counts)|set(bp.counts):differences[k]+=rp.counts[k]-bp.counts[k]
            recoveries+=cand.recoveries;fallbacks+=cand.zero_fallbacks
        cc['fixtures']+=1
    # Conservative generic prefix fallback and exact MSB mapping, including
    # non-BitForm token counts; no model-sized cube is allocated.
    from source_port import layout
    cfg=layout(ls=3,padded=True)
    for hp,kv,qh,tp,tok in itertools.product((4,8),(1,2),(2,),(1,2,4),range(1,5)):
        if tok>tp:continue
        deps=shape_dependencies(cfg,hp,kv,qh,tp,tok);n=(hp*tp*tp).bit_length()-1
        for name,words in public_tables(hp,kv,qh,tp,tok).items():
            assert measured_dependencies(words,n)<=deps[cfg['index'][name]];cc['conservative_dependency_checks']+=1
    # Direct original expanded polynomial at arbitrary extension coordinates.
    for inactive in itertools.product((False,True),repeat=3):
        con=constants(cfg,lambda:F(rng.randrange(P),rng.randrange(P)));ir=expanded(cfg,con)
        vals=[F(rng.randrange(P),rng.randrange(P)) for _ in cfg['names']];ds=[F(rng.randrange(P),rng.randrange(P)) for _ in vals]
        deps={cfg['index'][name]:set() if flag else {0} for name,flag in zip(('mask','gs','ght'),inactive)}
        for k,axes in deps.items():
            if not axes:ds[k]=F()
        rp=AxisPlan(cfg,con,Plan(generalize(cfg),con['alpha'],con['gu8']),deps);rp.round_index=0;rp.begin(vals,ds)
        for t in (F(),F(1),F(4),F(P-1,P-1),F(rng.randrange(P),rng.randrange(P))):
            point=[o.add(o.tup(v),o.mul(o.tup(t),o.tup(d))) for v,d in zip(vals,ds)]
            z=o.Z
            for c in reversed(rp.pending[0].c):z=o.add(o.mul(z,o.tup(t)),o.tup(c))
            assert z==o.bracket(ir[0],point);cc['arbitrary_extension_polynomial_values']+=1
        assert len(rp.pending[0].c)==5
        # Value-independent operation schedule: same public axes, all private
        # data/coefficients replaced by zeros, identical field counter counts.
        zp=AxisPlan(cfg,{k:F() for k in con},Plan(generalize(cfg),F(),F()),deps);zp.round_index=0
        zp.begin([F() for _ in vals],[F() for _ in vals]);assert zp.counts==rp.counts and zp.axis_work==rp.axis_work
        cc['private_value_independent_counter_checks']+=1
    cfg,con,ir,tabs,rs=shape_fixture((4,1,3,2,1),rng);n=len(rs);deps=shape_dependencies(cfg,4,1,3,2,1)
    def detects(dd,mutation=None):
        cand,rp=build(cfg,con,ir,tabs,n,3,False,dd,mutation);base,bp=build(cfg,con,ir,tabs,n,3,False)
        for j,r in enumerate(rs):
            if cand.round(j)!=base.round(j):return True
            cand.fold(r);base.fold(r)
        return False
    assert detects(deps,'force_mask_constant');controls.append('causal-mask-dependent-axis-falsely-constant')
    swapped={**deps,cfg['index']['gs']:deps[cfg['index']['ght']],cfg['index']['ght']:deps[cfg['index']['gs']]}
    assert detects(swapped);controls.append('Ht-and-S-dependencies-swapped')
    wrong={k:{n-1-j for j in axes} for k,axes in deps.items()}
    assert detects(wrong);controls.append('LSB-versus-MSB-axis-reversal')
    try:AxisPlan(cfg,con,Plan(generalize(cfg),con['alpha'],con['gu8']),{**deps,cfg['index']['s8']:set()})
    except ValueError:controls.append('private-role-metadata-refused')
    else:raise AssertionError('private role')
    # A prefix head layout is a wrong native gate, not a candidate optimization.
    good=public_tables(8,2,6,2,2)['gs'];bad=[F(int(h<6)) for h,t,j in itertools.product(range(8),range(2),range(2))]
    assert good!=bad;controls.append('contiguous-head-prefix-is-wrong')
    projections=[cost_case(s,ls,rng) for s,ls in itertools.product([(16,4,12,512,512),(32,8,32,512,512),(32,8,24,1024,769)],(2,3))]
    result=dict(status='passed',run_id='20261013T073440Z-ac1df939',cycle='0049',seed=SEED,counts=dict(cc),controls=controls,
        recoveries=recoveries,zero_factor_fallbacks=fallbacks,total_executed_row_counter_delta=dict(differences),output_sha256=digest.hexdigest(),
        projections=projections,wall_seconds=time.perf_counter()-start,max_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        hardware=dict(device='CPU only',threads=1,affinity=sorted(os.sched_getaffinity(0)),nice=os.nice(0),
            cpu_model=next(x.split(':',1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name'))),
        limits=dict(wall_seconds=59,cpu_seconds=59,address_space_bytes=512*1024**2,estimated_bytes=64*1024**2),
        proof_accounting=dict(accepted_complete_private_8b_proofs=0,proved_tokens=0,passes=0,context_length=None,
            steady_tokens_per_second=None,total_workload_tokens_per_second=None,startup_seconds=None,startup_fraction=None,
            witness_seconds=None,proof_seconds=None,serialization_seconds=None,independent_verification_seconds=None,
            proof_latency_seconds=None,proof_lag_seconds=None,pipeline_drain_seconds=None,prefill=None,resident_passes=None,decode=None))
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k!='projections'},indent=2))
    for p in projections:print('CENSUS',json.dumps({k:v for k,v in p.items() if k!='schedule'}))

if __name__=='__main__':main()

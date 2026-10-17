"""Bounded differential unpadded SC_SZC factory and complete seam census."""
import datetime,hashlib,itertools,json,os,random,resource,signal,time
from pathlib import Path
from collections import Counter
from field_support import F,P
from source_port import bracket as scalar
from polynomial_ir import expanded
from prepared import Plan,generalize
from fixtures import constants
from prior_optional_experiment import fixture
from support_model import config,construction_check,natural_tables
from axis_factory import measured_dependencies,shape_dependencies
from cubic_factory import CubicPlan,CubicTerms,CubicRounds
from coefficients import Coeff
import oracle as o

HERE=Path(__file__).resolve().parent
SEED=2026101754
MODES=('literal','prepared_scalar','cubic_schoolbook','cubic_karatsuba','cubic_round0')
FIELD=('mul','mul_base','add','sub')

def make(cfg,con,ir,tabs,n,chunk,debug,mode,mutation=None,min_rows=2,native_chunks=False):
    deps={cfg['index']['mask']:measured_dependencies(tabs[cfg['index']['mask']]['words'],n)}
    rp=CubicPlan(cfg,con,Plan(generalize(cfg),con['alpha'],con['gu8']),deps,mode=mode,mutation=mutation)
    groups=[(g,CubicTerms(ts,g,cfg,con,rp)) for g,ts in enumerate(ir)]
    rounds=CubicRounds(tabs,n,4,groups,rp,chunk,debug,min_rows=min_rows)
    rounds.native_model_chunks=native_chunks
    if mutation in ('omit_suffix_weight','drop_part','drop_ragged'):rounds.mutation=mutation
    return rounds,rp

def costs(rounds,rp):
    work=rp.counts+rp.eval_counts+rounds.work
    prep=Counter({k:v for k,v in rp.plan.plan.preparation.items() if k in FIELD}) if rp.mode!='literal' else Counter()
    return dict(construction=dict(rp.counts),scalar=dict(rp.eval_counts),reduction_horner=dict(rounds.work),
        preparation=dict(prep),all_field_ops=dict(work+prep),
        extra=dict(rp.extra),axis=dict(rp.axis_work),denominator_dispatch=dict(rp.plan.plan.dispatch),
        coefficient_words=rp.max_coefficient_words)

def census(shape,ls,rng,return_costs=False):
    cfg=config((False,False),ls=ls);con=constants(cfg,lambda:F(rng.randrange(P),rng.randrange(P)))
    n=(shape[0]*shape[3]**2).bit_length()-1; rows_total=(1<<n)-1
    vals=[F(2,3) for _ in cfg['names']]; dif=[F(5,7) for _ in vals]
    results={};schedules={}
    for mode in MODES:
        rp=CubicPlan(cfg,con,Plan(generalize(cfg),con['alpha'],con['gu8']),shape_dependencies(cfg,*shape),mode=mode)
        total=Counter();rows=[];extras=Counter()
        for j in range(n):
            nr=1<<(n-j-1);selected=mode.startswith('cubic') and nr>=2 and (mode!='cubic_round0' or j==0)
            rp.round_index=j;rp.coefficient_groups={0} if selected else set()
            rp.counts.clear();rp.eval_counts.clear();rp.extra.clear();rp.axis_work.clear();rp.plan.plan.dispatch.clear()
            rp.begin(vals,dif); row=Counter(rp.counts); per=[]
            samples=[4-int(j>0),2-int(j>0),2-int(j>0)]
            for g in range(3):
                if g==0 and selected:
                    # Four weighted coefficients, including sample1 later recovered.
                    row.update(mul=4,add=4);per.append(None)
                else:
                    val,cc=scalar(g,vals,cfg,con,den_eval=rp.plan.plan.evaluate if mode!='literal' else None)
                    for k,v in cc.items():row[k]+=v*samples[g]
                    row.update(mul=samples[g],add=samples[g]);per.append(dict(cc))
            scaled=Counter({k:v*nr for k,v in row.items()})
            # Chunk-independent full sum: per-part global reductions use four
            # words instead of 3 after recovery; expose chunk=1 pessimism too.
            # Native source threshold/chunk policy is modeled with port carrier count.
            # Rayon identity-fold additions are not determined by parts alone.
            chunk=nr if nr*len(cfg['names'])<=1<<16 else min(nr,1024)
            parts=(nr+chunk-1)//chunk
            extra_reduce=Counter(add=(parts-1)*sum((4 if selected and g==0 else samples[g]) for g in range(3)))
            # The implementation retains the recovered h1 scratch slot too.
            # WeightedRounds sums all d+1 slots, including h1 placeholder.
            actual_reduce=Counter(add=(parts-1)*8)
            scaled.update(actual_reduce)
            horner=Counter()
            if selected:
                for t in (0,1,2,3):
                    if t==1 and j>0:continue
                    Coeff([F()]*4).evaluate(t,horner)
                scaled.update(horner)
            total.update(scaled);extras.update({k:v*nr for k,v in rp.extra.items()});extras['public_round_policy_tests']+=1
            extras.update({k:v*nr for k,v in rp.axis_work.items()})
            rows.append(dict(round=j,rows=nr,coefficient_group0=selected,scalar_samples=samples,
                row_field_ops=dict(row),round_field_ops=dict(scaled),horner=dict(horner),
                modeled_part_reduction=dict(actual_reduce),modeled_chunk_rows=chunk,logical_active_part_reduction=dict(extra_reduce),
                denominator_dispatch_per_row=dict(rp.plan.plan.dispatch)))
            rp.end()
        prep=Counter({k:v for k,v in rp.plan.plan.preparation.items() if k in FIELD}) if mode!='literal' else Counter()
        total.update(prep)
        results[mode]=dict(all_field_ops=dict(total),sum_api_ops=sum(total.values()),preparation=dict(prep),
            extra=dict(extras),coefficient_words=rp.max_coefficient_words,coefficient_logical_bytes=16*rp.max_coefficient_words,
            native_array_allocation=False)
        schedules[mode]=rows
    for mode in MODES:
        cc=results[mode]['all_field_ops']
        results[mode]['literal_native_field_api_expansion']=dict(fp_mul=5*cc.get('mul',0)+2*cc.get('mul_base',0),fp_add=2*cc.get('mul',0)+2*cc.get('add',0),fp_sub=2*cc.get('sub',0))
    for mode in MODES[1:]:
        results[mode]['delta_vs_literal']={k:results[mode]['all_field_ops'].get(k,0)-results['literal']['all_field_ops'].get(k,0) for k in FIELD}
        results[mode]['delta_vs_prepared_scalar']={k:results[mode]['all_field_ops'].get(k,0)-results['prepared_scalar']['all_field_ops'].get(k,0) for k in FIELD}
    return dict(shape=dict(head_pad=shape[0],kv_heads=shape[1],query_heads=shape[2],token_pad=shape[3],tokens=shape[4]),
        limbs=ls,n=n,total_rows=rows_total,results=results,schedules=schedules,
        scope='SC_SZC bracket + weighted accumulation + modeled fixed8-word part reduction + final Horner + denominator preparation. Common Eq/interpolation/recovery/fold/PCS/mask/witness/transfer/serialization omitted, no native timing. Counts assume nonzero recovery after round0; coefficient factories only >=2 rows. Native Rayon identity-fold additions uncounted; common reduction widths unchanged. Source literal includes unit/zero API operations; compiler may remove them.')

def main():
    start=time.perf_counter();signal.alarm(59)
    resource.setrlimit(resource.RLIMIT_CPU,(59,59));resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
    rng=random.Random(SEED);counts=Counter();controls=[];digest=hashlib.sha256();recoveries=fallbacks=0;summaries={}
    cases=[fixture(n,ls,(False,False),mode,rng,lookup_count=lc)
        for n,ls,mode,lc in itertools.product((0,1,2,3,4),(2,3),('full','zero','boolean'),(7,8))]
    # Actual public causal mask on complete head domains; no private sparsity.
    for sh in [(1,1,1,4,4),(4,1,4,2,2),(2,1,2,2,2)]:
        n=(sh[0]*sh[3]**2).bit_length()-1
        cfg,con,ir,tabs,rs=fixture(n,3,(False,False),'full',rng)
        tabs[cfg['index']['mask']]['words']=natural_tables(*sh)['mask']
        cases.append((cfg,con,ir,tabs,rs))
    for cfg,con,ir,tabs,rs in cases:
        n=len(rs);original=[o.table(t,n) for t in tabs];prefix=[];want=[]
        for j,r in enumerate(rs):
            want.append([o.round_direct(original,list(enumerate(ir)),prefix,t,n) for t in range(5)])
            prefix.append(o.tup(r))
        finals=[o.mle(t,prefix) for t in original]
        for chunk,debug in itertools.product((1,3,7),(False,True)):
            engines={m:make(cfg,con,ir,tabs,n,chunk,debug,m) for m in MODES}
            for j,r in enumerate(rs):
                ref_pending=None
                for mode,(rr,rp) in engines.items():
                    got=rr.round(j);assert list(map(o.tup,got))==want[j]
                    pending=[list(map(o.tup,x)) for x in rr.pending]
                    if ref_pending is None:ref_pending=pending
                    else:assert pending==ref_pending
                    for group in rr.pending:
                        for x in group:digest.update(x.wire())
                    counts['independent_round_samples']+=5;rr.fold(r)
            ref=engines['literal'][0]
            for mode,(rr,rp) in engines.items():
                assert list(map(o.tup,rr.finals()))==finals
                assert rr.claims==ref.claims and rr.data_fold_ops==ref.data_fold_ops and rr.eq_scalar_ops==ref.eq_scalar_ops
                assert rr.recoveries==ref.recoveries and rr.zero_fallbacks==ref.zero_fallbacks
                assert rp.max_coefficient_words<=4
                counts['independent_final_values']+=len(finals);counts['full_schedules']+=1
                summaries[mode]=costs(rr,rp)
            recoveries+=ref.recoveries;fallbacks+=ref.zero_fallbacks
        counts['fixtures']+=1
    # Arbitrary extension coordinates, independent expanded equation, including
    # zero slope and zero challenge data; cubic construction remains fixed4.
    for ls,mask_active,mode in itertools.product((2,3),(False,True),('full','zero','boolean')):
        cfg,con,ir,tabs,rs=fixture(3,ls,(False,False),mode,rng)
        draw=lambda:F(rng.randrange(P),rng.randrange(P))
        vals=[draw() for _ in cfg['names']];dif=[draw() for _ in vals]
        for alg in MODES[2:]:
            rp=CubicPlan(cfg,con,Plan(generalize(cfg),con['alpha'],con['gu8']),{cfg['index']['mask']:({0} if mask_active else set())},mode=alg)
            rp.round_index=0;rp.begin(vals,dif);poly=rp.pending[0]
            assert len(poly.c)==4
            dd=list(dif)
            if not mask_active:dd[cfg['index']['mask']]=F()
            for t in (F(),F(1),F(P-1,P-1),draw()):
                vv=[a+t*b for a,b in zip(vals,dd)];want=o.bracket(ir[0],list(map(o.tup,vv)))
                acc=o.Z
                for c in reversed(poly.c):acc=o.add(o.mul(acc,o.tup(t)),o.tup(c))
                assert acc==want==o.tup(scalar(0,vv,cfg,con)[0]);counts['independent_extension_checks']+=1
            rp.end()
    # Independently execute the counted scope at small natural layouts.
    # Different counter sources: concrete repeated rounds vs allocation-free
    # multiplication by row count; all four field API categories must match.
    for sh,ls in itertools.product([(2,1,2,4,4),(4,1,4,2,2)],(2,3)):
        ce=census(sh,ls,rng);n=ce['n']
        cfg,con,ir,tabs,rs=fixture(n,ls,(False,False),'full',rng)
        tabs[cfg['index']['mask']]['words']=natural_tables(*sh)['mask']
        for mode in MODES:
            rr,rp=make(cfg,con,ir,tabs,n,3,False,mode,native_chunks=True)
            for j,r in enumerate(rs):rr.round(j);rr.fold(r)
            assert rr.zero_fallbacks==0
            got=costs(rr,rp)['all_field_ops'];want=ce['results'][mode]['all_field_ops']
            assert all(got.get(k,0)==want.get(k,0) for k in FIELD),(mode,ls,got,want)
            counts['executed_vs_allocation_free_censuses']+=1
    cfg,con,ir,tabs,rs=fixture(4,3,(False,False),'full',rng)
    for mut in ('drop_cubic','reverse_coefficients','omit_suffix_weight','drop_part','drop_ragged'):
        rr,rp=make(cfg,con,ir,tabs,4,3,False,'cubic_karatsuba',mutation=mut,min_rows=1)
        original=[o.table(t,4) for t in tabs];want=[o.round_direct(original,list(enumerate(ir)),[],t,4) for t in range(5)]
        assert list(map(o.tup,rr.round(0)))!=want;controls.append(mut+'-detected')
    for supports in ((True,False),(False,True),(True,True)):
        cf=config(supports);co=constants(cf,lambda:F(1))
        try:CubicPlan(cf,co,Plan(generalize(cf),co['alpha'],co['gu8']),{cf['index']['mask']:set()})
        except ValueError:counts['padded_factory_refusals']+=1
        else:raise AssertionError('padded accepted')
    controls+=['padded-factory-refusal','no-private-degree-pruning','four-word-zero-fixture-width','last-row-scalar-fallback']
    projections=[census(sh,ls,rng) for sh,ls in itertools.product([(32,8,32,512,512),(32,8,32,1024,1024),(16,4,16,512,512)],(2,3))]
    prior=json.loads((HERE.parent/'optional-support-port-20261017/result.json').read_text())
    result=dict(status='passed',run_id='20261017T042624Z-0f7bf604',cycle='0054',seed=SEED,counts=dict(counts),controls=controls,
        recoveries=recoveries,zero_factor_fallbacks=fallbacks,output_sha256=digest.hexdigest(),last_fixture_costs=summaries,projections=projections,
        wall_seconds=time.perf_counter()-start,max_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        hardware=dict(device='CPU only',threads=1,affinity=sorted(os.sched_getaffinity(0)),nice=os.nice(0),cpu_model=next(x.split(':',1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name'))),
        limits=dict(wall_seconds=59,cpu_seconds=59,address_space_bytes=512*1024**2,estimated_bytes=64*1024**2),proof_accounting=prior['proof_accounting'])
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ('projections','last_fixture_costs')},indent=2))
    for p in projections:print('CENSUS',json.dumps({k:v for k,v in p.items() if k!='schedules'}))

if __name__=='__main__':main()

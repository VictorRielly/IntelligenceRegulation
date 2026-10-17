#!/usr/bin/env python3
"""One CPU-light differential experiment and literal cost census."""
import hashlib,itertools,json,os,random,resource,signal,time
from pathlib import Path
from collections import Counter
from field_support import F,P
from source_port import layout
from prepared import Plan,generalize
from fixtures import fixture,constants
from candidate import RowPlan,CoefficientTerms
from row_rounds import SteppedRounds
from weighted_rounds import WeightedRounds
from prior_experiment import projection as prior_projection
from coefficients import Coeff
import oracle as o

HERE=Path(__file__).resolve().parent; SEED=2026101348

def build(cfg,const,ir,tabs,n,chunk,debug,policy='public_half',reduction='forward',mutation=None):
    plan=Plan(generalize(cfg),const['alpha'],const['gu8']); rp=RowPlan(cfg,const,plan)
    groups=[(g,CoefficientTerms(ts,g,cfg,const,rp)) for g,ts in enumerate(ir)]
    return WeightedRounds(tabs,n,5,groups,rp,chunk,debug,mutation,policy=policy,reduction=reduction),rp

def old_build(cfg,const,ir,tabs,n,chunk,debug):
    plan=Plan(generalize(cfg),const['alpha'],const['gu8']); rp=RowPlan(cfg,const,plan)
    groups=[(g,CoefficientTerms(ts,g,cfg,const,rp)) for g,ts in enumerate(ir)]
    return SteppedRounds(tabs,n,5,groups,rp,chunk,debug),rp

def projection(n,ls,padded,recover,debug,chunk,policy):
    prev=prior_projection(n,ls,padded,recover,debug)
    before=Counter(prev['loop_after']); after=before.copy(); reduction=0; delta=Counter(); evaluations_before=0; evaluations_after=0
    degree=4; width=5; weighted_rows=0; weighted_rounds=0
    schedule=[]
    for j in range(n):
        rows=1<<(n-j-1); parts=(rows+chunk-1)//chunk
        red=(parts-1)*(11 if padded else 8); reduction+=red
        use=padded and (policy=='always' or (policy=='public_half' and rows>=2))
        c=5 if j==0 or not recover or debug else 4
        eb=degree*(c-1)*rows if padded else 0; ea=degree*(c-1) if use else eb
        evaluations_before+=eb; evaluations_after+=ea
        if use:
            # Suffix weights are full-extension values; no small-value shortcut.
            delta['mul']+=(width-c)*rows
            delta['mul_base']+=ea-eb
            delta['add']+=(width-c)*rows+ea-eb
            weighted_rows+=rows; weighted_rounds+=1
        schedule.append(dict(round=j,rows=rows,parts=parts,samples=c,weighted=use,old_horner_base_mul=eb,new_horner_base_mul=ea))
    before['add']+=reduction; after['add']+=reduction
    for op,v in delta.items(): after[op]+=v
    b=5*before['mul']+2*before['mul_base']; a=5*after['mul']+2*after['mul_base']
    return dict(n=n,ls=ls,padded=padded,recovery=recover,debug=debug,chunk=chunk,policy=policy,
        baseline='cycle47 selective row coefficients plus identical binary part reduction census',
        before=dict(before),after=dict(after),delta=dict(delta),base_mul_before=b,base_mul_after=a,
        base_mul_fraction_removed=(b-a)/b,api_before=sum(before.values()),api_after=sum(after.values()),
        api_fraction_removed=(sum(before.values())-sum(after.values()))/sum(before.values()),
        weighted_rows=weighted_rows,weighted_rounds=weighted_rounds,part_reduction_adds=reduction,
        old_horner_base_mul=evaluations_before,new_horner_base_mul=evaluations_after,schedule=schedule,
        retained_group0_part_output_bytes=80 if padded else 0,incremental_group0_part_output_bytes=0,
        excluded=[x if x!='inverse/recovery/interpolation/reduction' else 'inverse/recovery/high-sample interpolation; part reduction is counted' for x in prev['excluded']],
        reduction_limit='P-1 binary merges counted; rayon identity folds/compiler behavior unmeasured; equal width in both arms')

def main():
    start=time.perf_counter(); signal.alarm(59)
    resource.setrlimit(resource.RLIMIT_CPU,(59,59)); resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))}); os.nice(19)
    rng=random.Random(SEED); counts=Counter(); controls=[]; digest=hashlib.sha256()
    rows=recoveries=fallbacks=weighted_rounds=baseline_rounds=parts=0
    for n,ls,padded,mode,even in itertools.product((0,1,2,3),(2,3),(False,True),('full','base','zero','boolean'),(False,True)):
        cfg,const,ir,tabs,rs=fixture(n,ls,padded,mode,rng,even=even)
        originals=[o.table(t,n) for t in tabs]; groups=list(enumerate(ir)); prefix=[]; wants=[]
        for j,r in enumerate(rs):
            wants.append([o.round_direct(originals,groups,prefix,t,n) for t in range(6)]); prefix.append(o.tup(r))
        finals=[o.mle(t,prefix) for t in originals]
        for chunk,debug,reduction in itertools.product((1,3,7),(False,True),('forward','reverse')):
            cand,rp=build(cfg,const,ir,tabs,n,chunk,debug,reduction=reduction)
            base,bp=old_build(cfg,const,ir,tabs,n,chunk,debug)
            for j,r in enumerate(rs):
                got=list(map(o.tup,cand.round(j))); old=list(map(o.tup,base.round(j)))
                assert got==old==wants[j]
                for value in got: digest.update(F(*value).wire())
                counts['independent_round_samples']+=len(got); cand.fold(r); base.fold(r)
            assert list(map(o.tup,cand.finals()))==list(map(o.tup,base.finals()))==finals
            assert rp.counts==bp.counts, 'row construction identical'
            counts['independent_final_values']+=len(finals); counts['schedules']+=1
            rows+=rp.rows; recoveries+=cand.recoveries; fallbacks+=cand.zero_fallbacks
            weighted_rounds+=cand.weighted_rounds; baseline_rounds+=cand.baseline_rounds; parts+=cand.chunks
        counts['fixtures']+=1
    # Independent arbitrary full-extension coefficients/weights, all five slots,
    # zero/Boolean weights, near-p residues, ragged/reversed reductions.
    for m in (1,2,3,7,16):
        for chunk in (1,3,7):
            cs=[[F(P-1,P-1) if k==0 else F(rng.randrange(P),rng.randrange(P)) for k in range(5)] for _ in range(m)]
            ws=[F() if i==0 else F(1) if i==1 else F(rng.randrange(P),rng.randrange(P)) for i in range(m)]
            acc=[F() for _ in range(5)]
            for lo in reversed(list(range(0,m,chunk))):
                local=[F() for _ in range(5)]
                for i in range(lo,min(lo+chunk,m)):
                    for k in range(5): local[k]+=ws[i]*cs[i][k]
                for k in range(5): acc[k]+=local[k]
            for t in [F(),F(1),F(4),F(rng.randrange(P),rng.randrange(P))]:
                def horn(co):
                    z=o.Z
                    for c in reversed(co): z=o.add(o.mul(z,o.tup(t)),o.tup(c))
                    return z
                wanted=o.Z
                for w,c in zip(ws,cs): wanted=o.add(wanted,o.mul(o.tup(w),horn(c)))
                assert horn(acc)==wanted; counts['independent_weighted_polynomial_values']+=1
    cfg,const,ir,tabs,rs=fixture(3,3,True,'full',rng)
    originals=[o.table(t,3) for t in tabs]
    for mutation in ('omit_suffix_weight','reverse_coefficients','drop_part','drop_ragged'):
        cand,rp=build(cfg,const,ir,tabs,3,3,False,mutation=mutation); prefix=[]; detected=False
        for j,r in enumerate(rs):
            want=[o.round_direct(originals,list(enumerate(ir)),prefix,t,3) for t in range(6)]
            try: detected|=list(map(o.tup,cand.round(j)))!=want
            except (IndexError,AssertionError): detected=True; break
            cand.fold(r); prefix.append(o.tup(r))
        assert detected, mutation; controls.append(mutation)
    for control in ('unfinished_finals','fold_without_round','double_round'):
        cand,rp=build(cfg,const,ir,tabs,3,3,False)
        try:
            if control=='unfinished_finals': cand.finals()
            elif control=='fold_without_round': cand.fold(F(5,7))
            else: cand.round(0); cand.round(0)
        except ValueError: controls.append(control)
        else: raise AssertionError(control)
    projections=[projection(*x) for x in itertools.product((3,20,23,25),(2,3),(False,True),(False,True),(False,True),(1,3,1024),('always','public_half'))]
    # Exact counter delta cross-check on all-zero fixtures: every round uses
    # explicit samples; row setup/host evaluation cancels. No inverse assumption.
    for n,ls,padded,chunk,debug,mode in itertools.product((1,2,3),(2,3),(False,True),(1,3,7),(False,True),('zero','full')):
        cfg,con,ii,tt,rr=fixture(n,ls,padded,mode,rng)
        cand,rp=build(cfg,con,ii,tt,n,chunk,debug)
        base,bp=build(cfg,con,ii,tt,n,chunk,debug,policy='rows')
        for j,r in enumerate(rr): cand.round(j); base.round(j); cand.fold(r); base.fold(r)
        a=rp.counts+rp.eval_counts+cand.work; b=bp.counts+bp.eval_counts+base.work
        got={k:a[k]-b[k] for k in set(a)|set(b)}
        if mode=='full': assert cand.recoveries==3*(n-1) and cand.zero_fallbacks==0
        want=projection(n,ls,padded,mode=='full',debug,chunk,'public_half')['delta']
        assert all(got.get(k,0)==want.get(k,0) for k in set(got)|set(want)),(got,want)
        counts['executed_counter_census_checks']+=1
    # Retain a bounded actual singleton regression: five coefficient weights
    # replace four samples when recovery is available. Public policy avoids it.
    cfg,con,ii,tt,rr=fixture(2,3,True,'full',rng)
    allc,ap=build(cfg,con,ii,tt,2,3,False,policy='always')
    chosen,cp=build(cfg,con,ii,tt,2,3,False)
    for j,r in enumerate(rr):
        assert allc.round(j)==chosen.round(j); allc.fold(r); chosen.fold(r)
    aa=ap.counts+ap.eval_counts+allc.work; cc=cp.counts+cp.eval_counts+chosen.work
    singleton_delta={k:aa[k]-cc[k] for k in set(aa)|set(cc)}
    assert singleton_delta==dict(mul=1,add=1,mul_base=0,sub=0)
    counts['executed_singleton_regressions']+=1
    proof=dict(accepted_complete_private_8b_proofs=0,proved_tokens=0,passes=0,context_length=None,
        steady_tokens_per_second=None,total_workload_tokens_per_second=None,startup_seconds=None,startup_fraction=None,
        witness_seconds=None,proof_seconds=None,serialization_seconds=None,independent_verification_seconds=None,
        prefill=None,resident_passes=None,decode=None)
    result=dict(status='passed',seed=SEED,scope='synthetic source-derived algebra and literal operation accounting; no native proof',
        counts=dict(counts),rows=rows,part_chunks=parts,recoveries=recoveries,zero_factor_fallbacks=fallbacks,
        weighted_rounds=weighted_rounds,baseline_rounds=baseline_rounds,negative_controls=controls,
        retained_negative=dict(singleton_always_policy_delta=singleton_delta,extra_native_base_products=5),
        output_sha256=digest.hexdigest(),projections=projections,wall_seconds=time.perf_counter()-start,
        max_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        hardware=dict(cpu_model=next((x.split(':',1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name')),'unknown'),
            affinity=sorted(os.sched_getaffinity(0)),threads=1,nice=os.nice(0),device='CPU only'),
        limits=dict(wall_seconds=59,cpu_seconds=59,address_space_bytes=512*1024**2,estimated_bytes=64*1024**2),proof_accounting=proof)
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k!='projections'},indent=2))
    p=next(p for p in projections if p['n']==23 and p['ls']==3 and p['padded'] and p['recovery'] and not p['debug'] and p['chunk']==1024 and p['policy']=='public_half')
    print('ILLUSTRATIVE',json.dumps({k:v for k,v in p.items() if k!='schedule'}))

if __name__=='__main__': main()

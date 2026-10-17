#!/usr/bin/env python3
"""Bounded differential full-clause test and separately labelled cost census."""
import copy,hashlib,itertools,json,os,platform,random,resource,signal,time
from pathlib import Path
from collections import Counter
from field_support import F,P
from source_port import V,Terms,layout,bracket
from prepared import Plan,PreparedTerms,generalize
from fixtures import fixture,constants
from baseline import TaggedRounds
from row_rounds import SteppedRounds
from stepping import RowPlan,SteppedTerms
import oracle as o

HERE=Path(__file__).resolve().parent; SEED=2026100434


def model(n,ls,padded,recovery,debug):
    cfg=layout(ls=ls,padded=padded); const=constants(cfg,lambda:F(17,23))
    lk=generalize(cfg); plan=Plan(lk,const['alpha'],const['gu8']); L=len(lk)
    vals=[F(5,7)]*len(cfg['names']); b=[bracket(g,vals,cfg,const,den_eval=plan.evaluate)[1] for g in range(3)]
    # Evaluating a prepared denominator at t=0 and its offset-free delta.
    kinds=Counter('Unit' if c%P==1 else 'Neg' if c%P==P-1 else 'Scale' for ts,k in lk for i,c in ts)
    den=Counter(mul_base=kinds['Scale'],add=kinds['Neg'],sub=kinds['Unit']+kinds['Scale'])
    other=b[0].copy(); other.subtract(den)
    assert all(v>=0 for v in other.values())
    degrees=[4,2,2] if padded else [3,1,1]; d=max(degrees)
    before=Counter(); after=Counter(); rows=0; calls0=0
    for j in range(n):
        half=1<<(n-j-1); rows+=half
        samples=[q+1-int(recovery and j>0 and not debug) for q in degrees]
        calls0+=half*samples[0]
        for g,s in enumerate(samples):
            for op,num in b[g].items(): before[op]+=half*s*num
            core=other if g==0 else b[g]
            for op,num in core.items(): after[op]+=half*s*num
        for op,num in den.items(): after[op]+=2*half*num
        after['add']+=half*d*L
        # Unchanged native ALL-table interpolation, fold, equality weighting.
        common=Counter(mul=half*len(vals)+3*half+half*sum(samples),
                       sub=2*half*len(vals),add=half*len(vals)*(d+1)+half*sum(samples))
        before.update(common); after.update(common)
    # Same compiled plan preparation in both arms; cst+tag already existed.
    before['sub']+=L; after['sub']+=L
    lowered=lambda cc:5*cc['mul']+2*cc['mul_base']
    return dict(n=n,ls=ls,padded=padded,recovery=recovery,debug=debug,
                logical_tables=len(vals),lookups=L,rows=rows,zero_check_calls=calls0,
                before=dict(before),after=dict(after),delta_after_minus_before={k:after[k]-before[k] for k in before},
                counted_base_mul_before=lowered(before),counted_base_mul_after=lowered(after),
                counted_base_mul_fraction_removed=(lowered(before)-lowered(after))/lowered(before) if n else 0,
                api_operation_fraction_removed=(sum(before.values())-sum(after.values()))/sum(before.values()),
                prepared_coefficient_dispatches=calls0*sum(kinds.values()),
                stepped_coefficient_dispatches=2*rows*sum(kinds.values()),
                scratch_reads=L*calls0,scratch_writes=rows*L*(d+2),logical_scratch_bytes_per_part=32*L,
                excluded=['table/Eq construction','part factor setup','inversions','interpolation recovery and reduction',
                          'mask extension','transcript','witness','PCS','transfers','serialization','verification'])


def main():
    started=time.perf_counter(); signal.alarm(59)
    resource.setrlimit(resource.RLIMIT_CPU,(59,59)); resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))}); os.nice(10)
    rng=random.Random(SEED); counts=Counter(); controls=[]; digest=hashlib.sha256(); observations=[]
    for n,ls,padded,mode,even in itertools.product((0,1,2,3),(2,3),(False,True),('full','base','zero','boolean'),(False,True)):
        cfg,const,ir,tabs,rs=fixture(n,ls,padded,mode,rng,even=even)
        original=[o.table(t,n) for t in tabs]; pure=list(enumerate(ir)); prefix=[]; expected=[]
        for r in rs:
            expected.append([o.round_direct(original,pure,prefix,t,n) for t in range(6)])
            prefix.append(o.tup(r)); counts['independent_cube_samples']+=6
        finals=[o.mle(t,prefix) for t in original]
        pl=Plan(generalize(cfg),const['alpha'],const['gu8'])
        reference=TaggedRounds(tabs,n,5,[(g,PreparedTerms(terms,g,cfg,const,pl)) for g,terms in enumerate(ir)])
        for j,r in enumerate(rs):
            assert list(map(o.tup,reference.round(j)))==expected[j]; reference.fold(r)
        assert list(map(o.tup,reference.finals()))==finals; counts['prepared_baseline_fixtures']+=1
        for chunk,debug in itertools.product((1,3,7),(False,True)):
            plan=Plan(generalize(cfg),const['alpha'],const['gu8']); row=RowPlan(plan)
            groups=[(g,SteppedTerms(terms,g,cfg,const,row)) for g,terms in enumerate(ir)]
            candidate=SteppedRounds(tabs,n,5,groups,row,chunk,debug)
            for j,r in enumerate(rs):
                actual=candidate.round(j)
                assert list(map(o.tup,actual))==expected[j]
                for x in actual: digest.update(x.wire())
                candidate.fold(r); counts['stepped_cube_samples']+=6
            assert list(map(o.tup,candidate.finals()))==finals
            counts['direct_mle_final_values']+=len(finals); counts['candidate_schedules']+=1
            L=len(cfg['lookups']); totalrows=(1<<n)-1; d=4 if padded else 3
            den_terms=generalize(cfg); kinds=Counter('Unit' if c%P==1 else 'Neg' if c%P==P-1 else 'Scale' for ts,k in den_terms for i,c in ts)
            expectedcounts={'row_begins':totalrows,'row_ends':totalrows,'steps':totalrows*d,
                            'mul_base':2*totalrows*kinds['Scale'],
                            'add':2*totalrows*kinds['Neg']+totalrows*d*L,
                            'sub':2*totalrows*(kinds['Unit']+kinds['Scale']),
                            'scratch_reads':groups[0][1].calls*L}
            for key,value in expectedcounts.items(): assert row.counts[key]==value
            counts['independent_row_counter_checks']+=len(expectedcounts)
            counts['recoveries']+=candidate.recoveries; counts['zero_factor_fallbacks']+=candidate.zero_fallbacks
            if n and chunk>1: counts['ragged_schedules']+=1
            if row.current is not None: raise AssertionError('row scratch survived')
        counts['complete_clause_fixtures']+=1
    # General lookup contract, independent expanded tuple-field denominators.
    for case in range(160):
        N=case%9; values=[F(rng.randrange(P),rng.randrange(P)) for _ in range(5)]
        dif=[F(rng.randrange(P),rng.randrange(P)) for _ in values]
        lks=[([(rng.randrange(5),rng.choice([0,1,-1,4,64,256,P-2])) for _ in range(j%4)],F(rng.randrange(P),rng.randrange(P))) for j in range(N)]
        alpha=F(rng.randrange(P),rng.randrange(P)); tag=F(rng.randrange(P),rng.randrange(P))
        row=RowPlan(Plan(lks,alpha,tag));row.begin(values,dif)
        for t in range(6):
            vals=[o.add(o.tup(a),o.mul((t,0),o.tup(b))) for a,b in zip(values,dif)]
            for j,(terms,cst) in enumerate(lks):
                den=o.sub(o.sub(o.tup(alpha),o.tup(tag)),o.tup(cst))
                for i,c in terms: den=o.sub(den,o.mul((c%P,0),vals[i]))
                assert o.tup(row.current[j])==den; counts['general_denominator_values']+=1
            if t<5: row.advance()
        row.end();counts['general_lookup_rows']+=1
    # A zero affine denominator is a valid algebraic test; no division/refusal.
    row=RowPlan(Plan([([(0,1)],F())],F(9),F(2)));row.begin([F(7)],[F(3)])
    assert row.current[0]==0;row.advance();assert row.current[0]==-3;row.end();counts['zero_denominator_checks']+=1
    # Intentional faults checked against the independent complete original cube.
    cfg,const,ir,tabs,rs=fixture(3,3,True,'full',rng); original=[o.table(t,3) for t in tabs]
    for fault in ['reverse_delta','skip_step_one','drop_ragged','stale_alpha','stale_tag','wrong_coefficient','tag_in_delta']:
        alpha=const['alpha']+(1 if fault=='stale_alpha' else 0);tag=const['gu8']+(1 if fault=='stale_tag' else 0)
        lk=generalize(cfg)
        if fault=='wrong_coefficient': lk[0]=([(lk[0][0][0][0],4)],lk[0][1])
        plan=Plan(lk,alpha,tag);row=RowPlan(plan,mutation=fault)
        if fault=='tag_in_delta':
            old=row.begin
            def bad_begin(v,d):
                old(v,d); row.delta=[x+const['gu8'] for x in row.delta]
            row.begin=bad_begin
        cand=SteppedRounds(tabs,3,5,[(g,SteppedTerms(ts,g,cfg,const,row)) for g,ts in enumerate(ir)],row,3,False,fault)
        prefix=[]; caught=False
        for j,r in enumerate(rs):
            expected=[o.round_direct(original,list(enumerate(ir)),prefix,t,3) for t in range(6)]
            if list(map(o.tup,cand.round(j)))!=expected: caught=True;break
            cand.fold(r);prefix.append(o.tup(r))
        assert caught,fault;controls.append(dict(name=fault,detected='independent full-clause original-cube mismatch'))
    for fault in ['unfinished row','step outside row','denominator outside row','end outside row']:
        row=RowPlan(Plan([([(0,1)],F())],F(1),F(2)))
        try:
            if fault=='unfinished row':row.begin([F(3)],[F(4)]);row.begin([F(5)],[F(6)])
            elif fault=='step outside row':row.advance()
            elif fault=='denominator outside row':row.evaluate(0,[],Counter())
            else:row.end()
        except ValueError as e: assert str(e)==fault;controls.append(dict(name=fault,detected=str(e)))
        else:raise AssertionError(fault)
    projections=[model(n,ls,padded,recovery,debug) for n,ls,padded,recovery,debug in itertools.product((0,20,23,25),(2,3),(False,True),(False,True),(False,True))]
    previous=json.loads((HERE/'snapshots/research__zkp-efficiency__experiments__compiled-lookup-denominators-20261004__result.json').read_text())
    for prior in previous['projections']:
        match=next(q for q in projections if q['n']==prior['n'] and q['ls']==prior['ls'] and
                   q['padded']==prior['padded'] and q['recovery']==prior['recovery'] and not q['debug'])
        for key,value in prior['loop_after_plus_new_setup'].items():
            assert match['before'][key]==value,(key,match['before'][key],value)
            counts['prior_baseline_census_checks']+=1
    # CPU API-call counts may already be optimized by the native compiler.
    result=dict(run_id='20261004T185034Z-0cf2c35e',cycle='0034',status='pass',seed=SEED,counts=dict(counts),
                controls=controls,control_count=len(controls),round_digest_sha256=digest.hexdigest(),projections=projections,
                elapsed_seconds=time.perf_counter()-started,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                hardware=dict(cpu=next(x.split(':',1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name')),
                              device='CPU only',threads=1,affinity=sorted(os.sched_getaffinity(0)),nice=os.nice(0),python=platform.python_version()),
                resource_limits=dict(wall_seconds=59,cpu_seconds=59,address_space_mib=512,estimated_memory_mib=64),
                code_hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in HERE.glob('*.py')},
                proof_accounting=dict(accepted_complete_private8b_proofs=0,countable_tokens=0,context_length=None,passes=0,device='CPU only',
                                      steady_state_tokens_per_s=None,total_workload_tokens_per_s=None,startup_seconds=None,startup_fraction=None,
                                      witness_seconds=None,proof_seconds=None,serialization_seconds=None,independent_verification_seconds=None,
                                      proof_latency_seconds=None,proof_lag_seconds=None,pipeline_drain_seconds=None,prefill='none',resident_passes='none',decode='none'),
                limits=['source-derived Python only; no Rust/CUDA execution or native speed measurement','synthetic data, not honest witnesses or proofs',
                        'independent tuple-field expanded original-cube oracle; shared copied scheduling driver','native folds counted unchanged in projection; symbolic Eq gains excluded',
                        'all API counts are algebra, not time or compiled instructions','no native mask/RNG/transcript/extension/PCS/refusal/privacy parity'])
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n');signal.alarm(0)
    print(json.dumps({k:v for k,v in result.items() if k not in ['projections','code_hashes']},indent=2))


if __name__=='__main__':main()

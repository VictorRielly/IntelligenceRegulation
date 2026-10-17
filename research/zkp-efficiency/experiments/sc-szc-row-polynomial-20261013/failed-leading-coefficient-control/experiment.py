#!/usr/bin/env python3
"""One bounded synthetic differential/cost experiment, no native proving."""
import copy,hashlib,itertools,json,os,platform,random,resource,signal,time
from collections import Counter
from pathlib import Path
from field_support import F,P
from source_port import layout,bracket,V
from prepared import Plan,PreparedTerms,generalize
from fixtures import fixture,constants
from candidate import RowPlan,CoefficientTerms
from row_rounds import SteppedRounds
from baseline import TaggedRounds
from coefficients import Coeff,LiftedPlan,PolynomialValue
import oracle as o

HERE=Path(__file__).resolve().parent; SEED=2026101347

class NullPlan:
    def begin(self,v,d): pass
    def advance(self): pass
    def end(self): pass

def build(cfg,const,ir,tabs,n,chunk,debug,mutation=None):
    plan=Plan(generalize(cfg),const['alpha'],const['gu8'])
    row=RowPlan(cfg,const,plan,mutation)
    groups=[(g,CoefficientTerms(ts,g,cfg,const,row)) for g,ts in enumerate(ir)]
    return SteppedRounds(tabs,n,5,groups,row,chunk,debug),row

def projection(n,ls,padded,recover,debug,policy='padded_zero'):
    cfg=layout(ls=ls,padded=padded); const=constants(cfg,lambda:F(17,23))
    k=len(cfg['names']); data=k-3; vals=[F(5,7)]*k; dif=[F(11,13)]*k
    plan=Plan(generalize(cfg),const['alpha'],const['gu8']); degrees=[4,2,2] if padded else [3,1,1]
    base=[bracket(g,vals,cfg,const,den_eval=plan.evaluate)[1] for g in range(3)]
    rp=RowPlan(cfg,const,plan,policy=policy); rp.begin(vals,dif)
    setup=rp.counts.copy(); lengths=[len(p.c) if p is not None else 0 for p in rp.pending]
    before=Counter(); after=Counter(); row_count=0; samples=[]
    for j in range(n):
        rows=1<<(n-j-1); row_count+=rows
        points=[list(range(d+1)) if j==0 or not recover or debug else [0]+list(range(2,d+1)) for d in degrees]
        ss=sum(map(len,points)); samples.append(ss*rows)
        for g,ps in enumerate(points):
            for op,v in base[g].items(): before[op]+=v*len(ps)*rows
        ec=Counter()
        for g,ps in enumerate(points):
            if g in rp.coefficient_groups:
                for t in ps: rp.pending[g].evaluate(t,ec)
            else:
                for op,v in base[g].items(): ec[op]+=v*len(ps)
        for op,v in (setup+ec).items(): after[op]+=v*rows
        # Fair literal-current native mixed table driver; retain all k tables
        # and cur interpolation even though coeff path could eliminate it.
        common=Counter(sub=2*rows*k,mul=rows*k+3*rows+ss*rows,add=rows*k*(max(degrees)+1)+ss*rows)
        before.update(common); after.update(common)
    # Charge the same definition-local compilation once per modeled proof.
    before['sub']+=len(plan.entries); after['sub']+=len(plan.entries)
    bm=5*before['mul']+2*before['mul_base']; am=5*after['mul']+2*after['mul_base']
    return dict(n=n,ls=ls,padded=padded,recovery=recover,debug=debug,policy=policy,tables=k,rows=row_count,
        coefficient_lengths=lengths,logical_retained_output_bytes=sum(lengths)*16,
        coefficient_setup_per_row=dict(setup),before_brackets=list(map(dict,base)),loop_before=dict(before),
        loop_after=dict(after),base_mul_before=bm,base_mul_after=am,base_mul_fraction_removed=(bm-am)/bm,
        api_before=sum(before.values()),api_after=sum(after.values()),
        api_fraction_removed=(sum(before.values())-sum(after.values()))/sum(before.values()),
        calls=sum(samples),dispatch_before=plan.preparation['tag_classifications']*sum((1<<(n-j-1))*len(list(range(degrees[0]+1)) if j==0 or not recover or debug else [0]+list(range(2,degrees[0]+1))) for j in range(n)),
        dispatch_after=(2*plan.preparation['tag_classifications']*row_count if 0 in rp.coefficient_groups else plan.preparation['tag_classifications']*sum((1<<(n-j-1))*len(list(range(degrees[0]+1)) if j==0 or not recover or debug else [0]+list(range(2,degrees[0]+1))) for j in range(n))),
        excluded=['Eq construction','group factor setup','inverse/recovery/interpolation/reduction','native allocation/temporaries/register pressure','mask extensions','witness','PCS','transfers','serialization','verification'])

def main():
    start=time.perf_counter(); signal.alarm(59)
    resource.setrlimit(resource.RLIMIT_CPU,(59,59)); resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))}); os.nice(19)
    rng=random.Random(SEED); counts=Counter(); controls=[]; digest=hashlib.sha256(); rows=0; recoveries=fallbacks=0
    # Verify copied clause expression differs solely in the arithmetic carrier.
    a=(HERE/'source_port.py').read_text(); b=(HERE/'polynomial_clause.py').read_text()
    assert a[a.index('def layout'):]==b[b.index('def layout'):]; counts['identical_clause_body_checks']+=1
    for n,ls,padded,mode,even in itertools.product((0,1,2,3),(2,3),(False,True),('full','base','zero','boolean'),(False,True)):
        cfg,const,ir,tabs,rs=fixture(n,ls,padded,mode,rng,even=even)
        original=[o.table(t,n) for t in tabs]; pure=list(enumerate(ir))
        want=[]; prefix=[]
        for j,r in enumerate(rs):
            want.append([o.round_direct(original,pure,prefix,t,n) for t in range(6)]); prefix.append(o.tup(r))
        finals=[o.mle(t,prefix) for t in original]
        for chunk,debug in itertools.product((1,3,7),(False,True)):
            cand,rp=build(cfg,const,ir,tabs,n,chunk,debug)
            bp=Plan(generalize(cfg),const['alpha'],const['gu8'])
            bg=[(g,PreparedTerms(ts,g,cfg,const,bp)) for g,ts in enumerate(ir)]
            base=SteppedRounds(tabs,n,5,bg,NullPlan(),chunk,debug)
            for j,r in enumerate(rs):
                got=list(map(o.tup,cand.round(j))); old=list(map(o.tup,base.round(j)))
                assert got==want[j]==old
                for value in got: digest.update(F(*value).wire())
                counts['round_samples']+=len(got); cand.fold(r); base.fold(r)
            assert list(map(o.tup,cand.finals()))==finals==list(map(o.tup,base.finals()))
            counts['final_values']+=len(finals); counts['schedules']+=1
            rows+=rp.rows; recoveries+=cand.recoveries; fallbacks+=cand.zero_fallbacks
        # Independent arbitrary row values, at integer and full-extension points.
        vv=[F(rng.randrange(P),rng.randrange(P)) for _ in tabs]
        dd=[F(rng.randrange(P),rng.randrange(P)) for _ in tabs]
        bp=Plan(generalize(cfg),const['alpha'],const['gu8']); rp=RowPlan(cfg,const,bp,policy='all'); rp.begin(vv,dd)
        for g,p in enumerate(rp.pending):
            for t in [F(),F(1),F(4),F(rng.randrange(P),rng.randrange(P))]:
                value=F()
                for c in reversed(p.c): value=value*t+c
                at=[o.add(o.tup(a),o.mul(o.tup(t),o.tup(d))) for a,d in zip(vv,dd)]
                assert o.tup(value)==o.bracket(ir[g],at); counts['independent_row_polynomial_values']+=1
        counts['fixtures']+=1
    cfg,const,ir,tabs,rs=fixture(3,3,True,'full',rng)
    expected=[o.round_direct([o.table(t,3) for t in tabs],list(enumerate(ir)),[],t,3) for t in range(6)]
    for mutation in ['drop_high','swap_support','shift_sample']:
        cand,rp=build(cfg,const,ir,tabs,3,3,False,mutation)
        assert list(map(o.tup,cand.round(0)))!=expected; controls.append(mutation)
    cand,rp=build(cfg,const,ir,tabs,3,3,False,'stale_row')
    try: cand.round(0)
    except AssertionError: controls.append('stale_row')
    else: raise AssertionError('stale row not caught')
    for mutation in ['exempt_E','wrong_plane_order','restart_zeta','gate_helpers','drop_odd','drop_c2']:
        cc=copy.deepcopy(cfg)
        if mutation=='exempt_E': cc['splanes'].insert(3,cc['index']['e'])
        elif mutation=='wrong_plane_order': cc['splanes'][0],cc['splanes'][1]=cc['splanes'][1],cc['splanes'][0]
        vv=[F(rng.randrange(P),rng.randrange(P)) for _ in tabs]
        good=o.bracket(ir[0],list(map(o.tup,vv)))
        bad=bracket(0,vv,cc,const,mutation=mutation)[0]
        assert o.tup(bad)!=good; controls.append(mutation)
    # General convolution checked against tuple-field Horner, including zero
    # polynomials and canonical residues near p, without coefficient pruning.
    for da,db in itertools.product(range(5),repeat=2):
        aa=[F(P-1,P-1) if i==0 else F(rng.randrange(P),rng.randrange(P)) for i in range(da+1)]
        bb=[F() if i==0 else F(rng.randrange(P),rng.randrange(P)) for i in range(db+1)]
        cc=Counter(); c=Coeff(aa).multiply(Coeff(bb),cc)
        assert cc==Counter(mul=(da+1)*(db+1),add=(da+1)*(db+1)-(da+db+1))
        assert len(c.c)==da+db+1; counts['convolution_count_checks']+=1
        for t in [F(),F(1),F(P-1,P-1),F(rng.randrange(P),rng.randrange(P))]:
            def horner(cs):
                z=o.Z
                for x in reversed(cs): z=o.add(o.mul(z,o.tup(t)),o.tup(x))
                return z
            assert horner(c.c)==o.mul(horner(aa),horner(bb)); counts['independent_convolution_values']+=1
    # Multi-term and alias plans lifted independently; no inverse is introduced.
    for case in range(80):
        values=[F(rng.randrange(P),rng.randrange(P)) for _ in range(5)]
        dif=[F(rng.randrange(P),rng.randrange(P)) for _ in range(5)]
        alpha,tag=F(rng.randrange(P),rng.randrange(P)),F(rng.randrange(P),rng.randrange(P))
        lk=[([(rng.randrange(5),rng.choice([0,1,-1,4,64,256,P-2])) for _ in range((case+j)%5)],F(rng.randrange(P),rng.randrange(P))) for j in range(case%9)]
        plan=LiftedPlan(Plan(lk,alpha,tag)); cc=Counter()
        for j,(ts,cst) in enumerate(lk):
            got=plan.evaluate(j,[PolynomialValue(Coeff([a,d]),cc) for a,d in zip(values,dif)],cc).value
            for t in [0,1,4]:
                wanted=o.sub(o.sub(o.tup(alpha),o.tup(tag)),o.tup(cst))
                for i,c in ts:
                    at=o.add(o.tup(values[i]),o.mul((t,0),o.tup(dif[i])))
                    wanted=o.sub(wanted,o.mul((c%P,0),at))
                assert o.tup(got.evaluate(t,Counter()))==wanted; counts['general_denominator_samples']+=1
    projections=[projection(n,ls,padded,recover,debug,policy) for n,ls,padded,recover,debug,policy in itertools.product((20,23,25),(2,3),(False,True),(False,True),(False,True),('all','padded_zero'))]
    prior=json.loads((HERE.parent/'compiled-lookup-denominators-20261004/result.json').read_text())
    for p in projections:
        if p['ls']==3:
            old=next(x for x in prior['projections'] if x['n']==p['n'] and x['padded']==p['padded'] and x['recovery']==(p['recovery'] and not p['debug']))
            assert p['loop_before']==old['loop_after_plus_new_setup']
            counts['prior_native_loop_census_checks']+=1
    result=dict(status='passed',seed=SEED,scope='synthetic source-derived algebra and literal operation census; no native proof',counts=dict(counts),rows=rows,recoveries=recoveries,zero_factor_fallbacks=fallbacks,negative_controls=controls,projections=projections,
        output_sha256=digest.hexdigest(),wall_seconds=time.perf_counter()-start,max_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        hardware=dict(cpu_model=next((x.split(':',1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name')),'unknown'),affinity=sorted(os.sched_getaffinity(0)),threads=1,nice=os.nice(0),device='CPU only'),
        limits=dict(wall_seconds=59,cpu_seconds=59,address_space_bytes=512*1024**2,estimated_bytes=64*1024**2),
        proof_accounting=dict(accepted_complete_private_8b_proofs=0,proved_tokens=0,passes=0,context_length=None,steady_tokens_per_second=None,total_workload_tokens_per_second=None,startup_seconds=None,startup_fraction=None,witness_seconds=None,proof_seconds=None,serialization_seconds=None,independent_verification_seconds=None,prefill=None,resident_passes=None,decode=None))
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k!='projections'},indent=2))
    p=next(p for p in projections if p['n']==23 and p['ls']==3 and p['padded'] and p['recovery'] and not p['debug'] and p['policy']=='padded_zero')
    print('ILLUSTRATIVE_PROJECTION',json.dumps(p))

if __name__=='__main__': main()

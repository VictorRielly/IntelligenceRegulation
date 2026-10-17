#!/usr/bin/env python3
"""Bounded source-derived denominator specialization and independent cube oracle."""
import copy,hashlib,itertools,json,os,platform,random,resource,signal,time
from collections import Counter
from pathlib import Path
from field_support import F,P
from source_port import layout,bracket,Terms,V
from prepared import Plan,PreparedTerms,generalize,helper,baseline_den
from fixtures import fixture,constants
from baseline import TaggedRounds
import oracle as o

HERE=Path(__file__).resolve().parent; SEED=2026100433


def independent_helper(lookups,values,h0,alpha,tag,mu):
    # Tuple-field expanded identity, with multiplication order different from
    # both literal helper arms. No Plan, V, baseline_den or field F arithmetic.
    ds=[]; a=o.tup(alpha); t=o.tup(tag); vv=list(map(o.tup,values))
    for terms,cst in lookups:
        d=o.sub(o.sub(a,t),o.tup(cst))
        for i,c in terms: d=o.sub(d,o.mul((c%P,0),vv[i]))
        ds.append(d)
    out=o.Z
    for j in range((len(ds)+1)//2):
        h=vv[h0+j]; a=ds[2*j]
        if 2*j+1<len(ds):
            b=ds[2*j+1]; rel=o.sub(o.sub(o.mul(h,o.mul(a,b)),a),b)
        else: rel=o.sub(o.mul(h,a),o.O)
        out=o.add(out,o.mul(o.tup(mu[j]),rel))
    return out,ds


def formula(lookups):
    L=len(lookups); H=(L+1)//2; paired=L//2; T=sum(len(ts) for ts,c in lookups)
    kinds=Counter('Unit' if c%P==1 else 'Neg' if c%P==P-1 else 'Scale' for ts,k in lookups for i,c in ts)
    # Helper relation arithmetic is unchanged. Literal denominator costs are
    # T mul_base, T add and L sub. Prepared costs: Scale mul_base,
    # Neg add, Unit+Scale sub. Preparation adds L new sub per definition.
    common=Counter(mul=L+H,add=paired+H,sub=H)
    before=common+Counter(mul_base=T,add=T,sub=L)
    after=common+Counter(mul_base=kinds['Scale'],add=kinds['Neg'],sub=kinds['Unit']+kinds['Scale'])
    return before,after,kinds


def projection(n,short,padded,ls,recover):
    cfg=layout(ls=ls,padded=padded); const=constants(cfg,lambda:F(17,23)); lk=generalize(cfg)
    plan=Plan(lk,const['alpha'],const['gu8']); values=[F(5,7)]*len(cfg['names'])
    before=[bracket(g,values,cfg,const)[1] for g in range(3)]
    after=[bracket(g,values,cfg,const,den_eval=plan.evaluate)[1] for g in range(3)]
    k=len(values); degrees=[4,2,2] if padded else [3,1,1]; b=Counter(); a=Counter(); calls=[]
    for j in range(n):
        m=1<<(n-j-1); row=[]
        for g,d in enumerate(degrees):
            s=d+1-int(recover and j>0); c=m*s; row.append(c)
            for op,num in before[g].items(): b[op]+=num*c
            for op,num in after[g].items(): a[op]+=num*c
        # Fair same native table folds/interpolation/Eq weight work in both arms.
        common=Counter(mul=m*k+3*m,sub=2*m*k,add=m*k*(max(degrees)+1)+sum(row))
        b.update(common); a.update(common); calls.append(row)
    prep=plan.preparation; aa=a.copy(); aa['sub']+=prep['sub']
    lb=5*b['mul']+2*b['mul_base']; la=5*aa['mul']+2*aa['mul_base']
    return dict(n=n,short_ht=short,padded=padded,ls=ls,recovery=recover,tables=k,
                lookup_count=len(lk),before_brackets=list(map(dict,before)),after_brackets=list(map(dict,after)),
                loop_before=dict(b),loop_after=dict(a),additional_preparation=dict(prep),
                loop_after_plus_new_setup=dict(aa),lowered_base_mul_before=lb,lowered_base_mul_after=la,
                fraction_counted_base_mul_removed=(lb-la)/lb,
                api_operations_before=sum(b.values()),api_operations_after_plus_new_setup=sum(aa.values()),
                api_operation_fraction_removed=(sum(b.values())-sum(aa.values()))/sum(b.values()),
                denominator_dispatches=sum(row[0] for row in calls)*sum(len(ts) for ts,c in lk),
                zero_check_calls=sum(row[0] for row in calls),
                excluded=['table/eq construction','part factor setup','inversion','interpolation/recovery/reduction',
                          'mask extension','transcript','witness','PCS','transfer','serialization','verification'])


def main():
    started=time.perf_counter(); signal.alarm(59)
    resource.setrlimit(resource.RLIMIT_CPU,(59,59)); resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))}); os.nice(10)
    rng=random.Random(SEED); counts=Counter(); digest=hashlib.sha256(); records=[]; controls=[]
    for n,ls,padded,mode,even in itertools.product((0,1,2,3),(2,3),(False,True),('full','base','zero','boolean'),(False,True)):
        cfg,const,ir,tabs,rs=fixture(n,ls,padded,mode,rng,even=even)
        wanted=['s8','rsl','zsel','p']+[f'pl{i}' for i in range(2)]+[f'sr{i}' for i in range(ls)]+[f'sg{i}' for i in range(ls)]
        assert [cfg['names'][i] for i in cfg['splanes']]==wanted
        assert cfg['helpers']==(len(cfg['lookups'])+1)//2
        counts['native_declaration_checks']+=2
        plan=Plan(generalize(cfg),const['alpha'],const['gu8']); counts['plans_prepared']+=1
        literal=[(g,Terms(terms,g,cfg,const)) for g,terms in enumerate(ir)]
        compiled=[(g,PreparedTerms(terms,g,cfg,const,plan)) for g,terms in enumerate(ir)]
        ref=TaggedRounds(tabs,n,5,literal); cand=TaggedRounds(tabs,n,5,compiled)
        original=[o.table(t,n) for t in tabs]; pure=list(enumerate(ir)); prefix=[]
        values=[F(rng.randrange(P),rng.randrange(P)) for _ in tabs]
        for g in range(3):
            b,bc=bracket(g,values,cfg,const); a,ac=bracket(g,values,cfg,const,den_eval=plan.evaluate)
            assert o.tup(a)==o.bracket(ir[g],list(map(o.tup,values)))==o.tup(b)
            counts['direct_full_clause_values']+=1
            if g==0:
                hb,ha,kinds=formula(generalize(cfg)); delta=Counter()
                for key in set(bc)|set(ac): delta[key]=bc[key]-ac[key]
                assert all(delta[key]==hb[key]-ha[key] for key in set(delta)|set(hb)|set(ha))
                counts['independent_clause_counter_checks']+=1
        for j,r in enumerate(rs):
            expected=[o.round_direct(original,pure,prefix,t,n) for t in range(6)]
            assert list(map(o.tup,ref.round(j)))==expected==list(map(o.tup,cand.round(j)))
            counts['original_cube_samples']+=6; counts['compiled_samples']+=6
            for x in expected: digest.update(F(*x).wire())
            ref.fold(r); cand.fold(r); prefix.append(o.tup(r))
        finals=[o.mle(t,prefix) for t in original]
        assert list(map(o.tup,ref.finals()))==finals==list(map(o.tup,cand.finals()))
        counts['direct_mle_final_values']+=len(finals)
        for g,terms in compiled:
            one=bracket(g,values,cfg,const,den_eval=plan.evaluate)[1]
            assert terms.counts==Counter({key:val*terms.calls for key,val in one.items()})
            counts['per_call_counter_checks']+=1
        records.append(dict(n=n,ls=ls,padded=padded,mode=mode,even=even,lookups=len(cfg['lookups']),
                            recovery=cand.recoveries,zero_fallback=cand.zero_fallbacks))
        counts['complete_clause_fixtures']+=1
    # General native LkT contract: zero/multiple terms, aliases, field-negative
    # and non-unit coefficients, odd/even/empty lists, arbitrary/zero challenges.
    coefs=[0,1,-1,4,64,256,P-1,P-2]
    for case in range(160):
        L=case%10; h0=8; values=[F(rng.randrange(P),rng.randrange(P)) for _ in range(h0+(L+1)//2)]
        alpha=F() if case%5==0 else F(rng.randrange(P),rng.randrange(P))
        tag=F() if case%7==0 else F(rng.randrange(P),rng.randrange(P))
        lk=[([(rng.randrange(h0),rng.choice(coefs)) for _ in range((case+j)%5)],
             F(rng.randrange(P),rng.randrange(P))) for j in range(L)]
        mu=[F(rng.randrange(P),rng.randrange(P)) for _ in range((L+1)//2)]
        plan=Plan(lk,alpha,tag); counts['plans_prepared']+=1
        b,bc=helper(lk,values,h0,alpha,tag,mu); a,ac=helper(lk,values,h0,alpha,tag,mu,plan)
        wanted,ds=independent_helper(lk,values,h0,alpha,tag,mu)
        assert o.tup(b)==wanted==o.tup(a); counts['general_helper_values']+=1
        eb,ea,kinds=formula(lk); assert bc==eb and ac==ea; counts['general_counter_checks']+=2
        assert plan.preparation==Counter(add=L,sub=L,tag_classifications=sum(len(ts) for ts,c in lk))
        counts['preparation_checks']+=1
        assert plan.dispatch==kinds; counts['dispatch_checks']+=1
        for j,d in enumerate(ds):
            cc=Counter(); got=plan.evaluate(j,[V(v,cc) for v in values],cc)
            assert o.tup(got.value)==d; counts['direct_denominator_values']+=1
    # Adversarial plans/challenges produce detectable deviations.
    lk=[([(0,1)],F(127)),([(1,-1)],F(127)),([(2,4),(0,1)],F(9))]
    values=[F(3,5),F(7,11),F(13,17),F(19,23),F(29,31)]; mu=[F(37,41),F(43,47)]
    alpha,tag=F(53,59),F(61,67); expected=independent_helper(lk,values,3,alpha,tag,mu)[0]
    for mut in ['drop_tag','reverse_offset','neg_is_unit']:
        bad=helper(lk,values,3,alpha,tag,mu,Plan(lk,alpha,tag,mut))[0]
        assert o.tup(bad)!=expected; controls.append(mut)
    plan=Plan(lk,alpha,tag)
    assert o.tup(helper(lk,values,3,alpha,tag,mu,plan,'drop_odd')[0])!=expected; controls.append('drop_odd_helper')
    for changed,aa,tt in [('alpha',alpha+1,tag),('tag',alpha,tag+1)]:
        assert o.tup(helper(lk,values,3,aa,tt,mu,plan)[0])!=independent_helper(lk,values,3,aa,tt,mu)[0]
        controls.append('stale_'+changed)
    bad=copy.deepcopy(lk); bad[2]=(list(reversed(lk[2][0]))[:-1],lk[2][1])
    assert o.tup(helper(bad,values,3,alpha,tag,mu,Plan(bad,alpha,tag))[0])!=expected
    controls.append('drop_multiterm')
    # Denominator-zero behavior: do not introduce division or invert the plan.
    zero_lk=[([(0,1)],F())]; zv=[F(5,7),F(9,11)]; za=zv[0]; zm=[F(1)]
    assert helper(zero_lk,zv,1,za,F(),zm)[0]==helper(zero_lk,zv,1,za,F(),zm,Plan(zero_lk,za,F()))[0]==-F(1)
    counts['zero_denominator_relation_checks']+=1
    wrong=copy.deepcopy(plan); off,ops=wrong.entries[2]; wrong.entries[2]=(off,tuple((i,kind,1) for i,kind,c in ops))
    assert o.tup(helper(lk,values,3,alpha,tag,mu,wrong)[0])!=expected; controls.append('wrong_scale_coefficient')
    # Expanded oracle retains earlier pad and A_E negative gates.
    cfg,const,ir,tabs,rs=fixture(3,3,True,'full',rng); vals=[F(rng.randrange(P),rng.randrange(P)) for _ in tabs]
    for mut in ['exempt_E','wrong_plane_order','wrong_support']:
        cc=copy.deepcopy(cfg)
        if mut=='exempt_E': cc['splanes'].insert(3,cc['index']['e'])
        elif mut=='wrong_plane_order': cc['splanes'][0],cc['splanes'][1]=cc['splanes'][1],cc['splanes'][0]
        p=Plan(generalize(cc),const['alpha'],const['gu8'])
        a=bracket(1 if mut=='wrong_support' else 0,vals,cc,const,
                  mutation='ht_uses_s' if mut=='wrong_support' else None,den_eval=p.evaluate)[0]
        assert o.tup(a)!=o.bracket(ir[1 if mut=='wrong_support' else 0],list(map(o.tup,vals)))
        controls.append(mut)
    projections=[projection(n,short,padded,3,recover) for n,short in [(20,12),(23,14),(25,15)]
                 for padded,recover in itertools.product((False,True),(False,True))]
    result=dict(run_id='20261004T150146Z-0acf7ff8',cycle='0033',seed=SEED,status='pass',counts=dict(counts),
                controls=controls,control_count=len(controls),fixtures=records,projections=projections,
                round_digest_sha256=digest.hexdigest(),elapsed_seconds=time.perf_counter()-started,
                peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                hardware=dict(cpu=next(x.split(':',1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name')),
                              device='CPU only',threads=1,affinity=sorted(os.sched_getaffinity(0)),nice=os.getpriority(os.PRIO_PROCESS,0),
                              python=platform.python_version(),platform=platform.platform()),
                resource_limits=dict(wall_seconds=59,cpu_seconds=59,address_space_mib=512,estimated_memory_mib=64),
                hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in HERE.glob('*.py')},
                proof_accounting=dict(accepted_complete_private8b_proofs=0,countable_tokens=0,context_length=None,passes=0,
                    device='CPU only',steady_state_tokens_per_s=None,total_workload_tokens_per_s=None,
                    startup_fraction=None,startup_seconds=None,witness_seconds=None,proof_seconds=None,serialization_seconds=None,
                    independent_verification_seconds=None,proof_latency_seconds=None,proof_lag_seconds=None,pipeline_drain_seconds=None,
                    prefill='none',resident_passes='none',decode='none'),
                limits=['Python algebra/accounting only, no Rust/CUDA execution','no honest witness/proof/privacy acceptance',
                        'no native mask/RNG/transcript/extension/PCS parity','API counts may be optimized by LLVM',
                        'projections are not admitted profiles or runtime/complete-proof ceilings',
                        'tag branches/allocations and compiler/transfer costs unmeasured','zero-denominator refusal policy unchanged only algebraically'])
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ['status','counts','control_count','elapsed_seconds','peak_rss_kib']}))
    print(json.dumps(next(x for x in projections if x['n']==23 and x['padded'] and x['recovery'])))


if __name__=='__main__': main()

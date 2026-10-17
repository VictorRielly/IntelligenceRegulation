#!/usr/bin/env python3
"""Bounded exact actual-clause prototype and arithmetic accounting, no proof."""
import copy,hashlib,itertools,json,os,platform,random,resource,signal,time
from collections import Counter
from pathlib import Path
from field_support import F,P
from source_port import layout,bracket,Terms
from polynomial_ir import expanded
from candidate import SplitRounds,analytic_counts
from baseline import TaggedRounds
import oracle

HERE=Path(__file__).resolve().parent
SEED=2026100432


def constants(cfg,draw):
    names=['alpha','beta','gexp','gu8','lam','nu0','nu1','zeta','mupad']
    names += ['mu'+str(j) for j in range(6+cfg['helpers'])]
    return {name:draw() for name in names}


def fixture(n,ls,padded,mode,rng,even=False):
    draw=lambda: F(rng.randrange(P),rng.randrange(P)) if mode=='full' else (
        F(rng.randrange(P)) if mode=='base' else F(rng.randrange(2)) if mode=='boolean' else F())
    cfg=layout(ls=ls,padded=padded,lookup_count=(7+2+2*ls-1) if even else None)
    const=constants(cfg,draw)
    # Keep batching weights nonzero; ZERO fixtures exercise data/Eq/challenges.
    for name in ['nu0','nu1','zeta']:
        if const[name]==0: const[name]=F(1)
    ir=expanded(cfg,const); tabs=[]
    short=max(0,n-1)
    for i in range(3):
        tabs.append(dict(kind='Eq',start=0,point=[draw() for _ in range(short if i==1 else n)]))
    for name in cfg['names'][3:]:
        if name in ('sum','mx','ght'):
            leading=[draw() for _ in range(1 << short)]
            words=[leading[i>>int(n>0)] for i in range(1 << n)]
        else: words=[draw() for _ in range(1 << n)]
        if padded and name in ('ght','gs'):
            # Ht is lifted; S additionally excludes j padding.
            words=[F(int((i>>int(n>0)) < max(1,(1<<short)-1)
                         and (name=='ght' or n==0 or i%2==0))) for i in range(1<<n)]
        if name=='mask': words=[F(int(i%2==0)) for i in range(1<<n)]
        tabs.append(dict(kind='Pub',words=words))
    return cfg,const,ir,tabs,[draw() for _ in range(n)]


def groups_for(ir,cfg,const,mutation=None):
    return [(i,Terms(terms,i,cfg,const,mutation)) for i,terms in enumerate(ir)]


def census(n,short,padded,ls,recover):
    # Count-only synthetic geometry. No arrays of 2^n words are allocated.
    cfg=layout(ls=ls,padded=padded); const=constants(cfg,lambda:F(17,23))
    per=[dict(bracket(i,[F(5,7)]*len(cfg['names']),cfg,const)[1]) for i in range(3)]
    degrees=[4,2,2] if padded else [3,1,1]
    k=len(cfg['names']); total=Counter(); weight=Counter(); explicit=Counter(); rounds=[]
    for j in range(n):
        m=1 << (n-j-1); chunk=m if m*k<=1<<16 else min(m,1024)
        rr=Counter(); calls=[]
        for g,(length,d) in enumerate(zip([n,short,n],degrees)):
            samples=d+1-int(recover and j>0); calls.append(m*samples)
            for op, count in per[g].items(): rr['bracket_'+op]+=m*samples*count
            ac=analytic_counts(n,j,0,length,samples,chunk,'adaptive')
            for key,val in ac.items():
                if isinstance(val,int): weight[key]+=val
            for op,count in per[g].items(): explicit['bracket_'+op]+=m*(d+1)*count
        # Native retains/folds EVERY table, including Eq: counted baseline.
        rr['table_difference_sub']=m*k
        rr['table_interpolation_add']=m*k*max(degrees)
        rr['table_fold_mul']=m*k; rr['table_fold_add']=m*k; rr['table_fold_sub']=m*k
        total.update(rr); rounds.append(dict(round=j,pairs=m,chunk=chunk,bracket_calls=calls,counts=dict(rr)))
    baseline_mul=total['bracket_mul']+total['table_fold_mul']+weight['literal_mul']
    fair_mul=total['bracket_mul']+total['table_fold_mul']+weight['unit_aware_mul']
    candidate_mul=total['bracket_mul']+total['table_fold_mul']+weight['candidate_mul']
    removed=weight['unit_aware_mul']-weight['candidate_mul']
    base_muls=5*fair_mul+2*total['bracket_mul_base']
    candidate_base_muls=5*candidate_mul+2*total['bracket_mul_base']
    # Source Fp2.mul has 5 base mul/2 base add; Fp2.add/sub has 2 base adds/subs.
    adds=total['bracket_add']+total['table_interpolation_add']+total['table_fold_add']+weight['baseline_add']
    subs=total['bracket_sub']+total['table_difference_sub']+total['table_fold_sub']
    cand_adds=adds+weight['candidate_add']-weight['baseline_add']
    counted_field_api= fair_mul+total['bracket_mul_base']+adds+subs
    return dict(n=n,ht_point_length=short,padded=padded,limbs_sigma_s=ls,tables=k,
                lookup_count=len(cfg['lookups']),helpers=cfg['helpers'],degrees=degrees,
                recovery='nonzero later-round assumption' if recover else 'all explicit, debug or fallback',
                per_bracket=per,table_bracket_counts=dict(total),weight_counts=dict(weight),
                complete_scanned_loop_mul_literal=baseline_mul,
                complete_scanned_loop_mul_unit_aware=fair_mul,
                candidate_scanned_loop_mul=candidate_mul,removed_weight_mul=removed,
                fraction_of_scanned_loop_fp2_mul_removed=removed/fair_mul,
                lowered_base_mul_before=base_muls,lowered_base_mul_after=candidate_base_muls,
                fraction_of_lowered_base_mul_removed=(base_muls-candidate_base_muls)/base_muls,
                scanned_loop_fp2_add_before=adds,scanned_loop_fp2_add_after=cand_adds,
                scanned_loop_fp2_sub=subs,
                literal_api_operation_fraction_removed=(removed-(cand_adds-adds))/counted_field_api,
                symbolic_eq_separate_removed_fold_each=3*((1<<n)-1),
                additional_accumulator_bytes=sum(d+1 for d in degrees)*16,
                excluded=['table construction','split Eq construction','factor setup and inversions',
                          'degree completion/interpolation','group recovery and reduction','mask extension',
                          'transcript','witness','commitments','serialization','verification','transfers'],
                rounds=rounds)


def main():
    started=time.perf_counter(); signal.alarm(59)
    resource.setrlimit(resource.RLIMIT_CPU,(59,59)); resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))}); os.nice(10)
    rng=random.Random(SEED); counts=Counter(); records=[]; digest=hashlib.sha256(); controls=[]
    for n,ls,padded,mode in itertools.product((0,1,2,3),(2,3),(False,True),('full','base','zero','boolean')):
        cfg,const,ir,tabs,challenges=fixture(n,ls,padded,mode,rng)
        # Separate native declaration audit: layout.rs Dom::S numeric order and
        # pad.rs a_rule's A_E exemption. Does not derive from either evaluator.
        wanted=['s8','rsl','zsel','p']+[f'pl{i}' for i in range(2)]+[f'sr{i}' for i in range(ls)]+[f'sg{i}' for i in range(ls)]
        assert [cfg['names'][i] for i in cfg['splanes']]==wanted
        assert cfg['helpers']==(7+2+2*ls+1)//2
        counts['native_declaration_checks']+=2
        pure=[(i,terms) for i,terms in enumerate(ir)]
        original=[oracle.table(tab,n) for tab in tabs]
        # Direct arbitrary extension inputs test independent expanded clauses.
        values=[F(rng.randrange(P),rng.randrange(P)) for _ in tabs]
        for g in range(3):
            got,cc=bracket(g,values,cfg,const)
            assert oracle.tup(got)==oracle.bracket(ir[g],list(map(oracle.tup,values)))
            counts['direct_clause_values']+=1
            # Independently hand-derived clause census: L lookup denominators,
            # ceil(L/2) helpers, two support groups, P zero-rule planes.
            L,H=len(cfg['lookups']),cfg['helpers']; B=2*(ls-1)+1
            pad_planes=len(cfg['splanes'])+2
            expected_cc=([dict(mul=14+L+H+(pad_planes+3 if padded else 1),
                               mul_base=B+1+L,add=B+14+L+L//2+H+(pad_planes+2 if padded else 0),
                               sub=8+L+H+(2 if padded else 0)),
                          dict(mul=2,add=1),dict(mul=2,mul_base=1,add=1,sub=1)])[g]
            assert cc==Counter(expected_cc),(g,cc,expected_cc)
            counts['independent_clause_counter_checks']+=1
        ref=TaggedRounds(tabs,n,5,groups_for(ir,cfg,const))
        candidates=[SplitRounds(tabs,n,5,groups_for(ir,cfg,const),chunk=c,strategy='adaptive') for c in (1,3,1024)]
        prefix=[]
        for j,r in enumerate(challenges):
            expected=[oracle.round_direct(original,pure,prefix,t,n) for t in range(6)]
            counts['original_cube_samples']+=6
            assert list(map(oracle.tup,ref.round(j)))==expected
            for cand in candidates:
                got=cand.round(j); assert list(map(oracle.tup,got))==expected,(n,ls,padded,mode,j)
                counts['candidate_samples']+=6
                for v in got: digest.update(v.wire())
                cc=cand.counts[-1]
                assert cc['candidate_weight_mul']<=cc['baseline_unit_aware_weight_mul']
                counts['weight_guard_checks']+=1
                cand.fold(r)
            ref.fold(r); prefix.append(oracle.tup(r))
        finals=[oracle.mle(t,prefix) for t in original]
        assert list(map(oracle.tup,ref.finals()))==finals
        for cand in candidates:
            assert list(map(oracle.tup,cand.finals()))==finals
            counts['final_values']+=len(finals)
            # Exact evaluator API count equals value-independent per-call census.
            for g,(_,terms) in enumerate(cand.groups):
                one=bracket(g,values,cfg,const)[1]
                assert terms.counts==Counter({key:val*terms.calls for key,val in one.items()})
                counts['literal_counter_checks']+=1
            records.append(dict(n=n,ls=ls,padded=padded,mode=mode,chunk=cand.chunk,
                                recoveries=cand.recoveries,zero_fallbacks=cand.zero_fallbacks))
        counts['fixtures']+=1
    # Even lookup count tests a second paired-helper configuration explicitly.
    cfg,const,ir,tabs,rs=fixture(3,3,True,'full',rng,even=True)
    for _ in range(12):
        values=[F(rng.randrange(P),rng.randrange(P)) for _ in tabs]
        for g in range(3):
            assert oracle.tup(bracket(g,values,cfg,const)[0])==oracle.bracket(ir[g],list(map(oracle.tup,values)))
            counts['even_lookup_direct_values']+=1
    cfg,const,ir,tabs,rs=fixture(3,3,True,'full',rng)
    values=[F(rng.randrange(P),rng.randrange(P)) for _ in tabs]
    for mutation,g in [('ht_uses_s',1),('drop_c2',0),('drop_odd',0),('gate_helpers',0),('restart_zeta',0)]:
        expected=oracle.bracket(ir[g],list(map(oracle.tup,values)))
        assert oracle.tup(bracket(g,values,cfg,const,mutation)[0]) != expected,mutation
        controls.append(dict(name=mutation,detected='expanded original clause mismatch'))
    # Wrong support must fail at a Boolean row too, not only arbitrary inputs.
    ix=cfg['index']; values[ix['ght']]=F(1); values[ix['gs']]=F(0)
    assert bracket(1,values,cfg,const)[0]!=bracket(1,values,cfg,const,'ht_uses_s')[0]
    controls.append(dict(name='Ht true / S padded Boolean row',detected='host term mismatch'))
    for name in ('exempt_E_in_pad','wrong_pad_plane_order'):
        wrong=copy.deepcopy(cfg)
        if name=='exempt_E_in_pad': wrong['splanes'].insert(3,ix['e'])
        else: wrong['splanes'][0],wrong['splanes'][1]=wrong['splanes'][1],wrong['splanes'][0]
        assert oracle.tup(bracket(0,values,wrong,const)[0])!=oracle.bracket(ir[0],list(map(oracle.tup,values)))
        controls.append(dict(name=name,detected='native declaration / expanded clause mismatch'))
    # Higher-degree retained: equating the product MLE to MLE of products fails.
    original=[oracle.table(t,3) for t in tabs]; pure=[(i,terms) for i,terms in enumerate(ir)]
    expected=[oracle.round_direct(original,pure,[],t,3) for t in range(6)]
    for mutation in ('omit_chunk_flush','omit_trailing'):
        bad=SplitRounds(tabs,3,5,groups_for(ir,cfg,const),chunk=1,mutation=mutation)
        assert list(map(oracle.tup,bad.round(0)))!=expected,mutation
        controls.append(dict(name=mutation,detected='expanded original cube mismatch'))
    projections=[census(n,short,padded,3,recover) for n,short in [(20,12),(23,14),(25,15)]
                 for padded,recover in itertools.product((False,True),(False,True))]
    result=dict(run_id='20261004T140146Z-7230b465',cycle='0032',seed=SEED,status='pass',
                counts=dict(counts),control_count=len(controls),controls=controls,fixtures=records,
                projections=projections,round_digest_sha256=digest.hexdigest(),
                elapsed_seconds=time.perf_counter()-started,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                hardware=dict(cpu=next(x.split(':',1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines()
                                       if x.startswith('model name')),device='CPU only',threads=1,
                              affinity=sorted(os.sched_getaffinity(0)),nice=os.getpriority(os.PRIO_PROCESS,0),
                              python=platform.python_version(),platform=platform.platform()),
                resource_limits=dict(wall_seconds=59,cpu_seconds=59,address_space_mib=512,estimated_memory_mib=64),
                hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in HERE.glob('*.py')},
                proof_accounting=dict(accepted_complete_private8b_proofs=0,countable_tokens=0,context_length=None,passes=0,
                                      device='CPU only',steady_state_tokens_per_s=None,total_workload_tokens_per_s=None,
                                      startup_fraction=None,startup_seconds=None,witness_seconds=None,proof_seconds=None,
                                      serialization_seconds=None,independent_verification_seconds=None,
                                      proof_latency_seconds=None,proof_lag_seconds=None,pipeline_drain_seconds=None,
                                      prefill='none',resident_passes='none',decode='none'),
                limits=['source-derived Python closure, not Rust execution','synthetic values, not honest witness/proof',
                        'separate tuple-field expanded-monomial oracle','census omits listed setup/protocol/proof work',
                        'literal Fp2 API counts are not instructions or time','no mask/RNG/transcript/extension/PCS parity',
                        'n20/n23/n25 and short spans are illustrative, not admitted new profiles',
                        'table folds/interpolation baseline includes Eq; symbolic storage is a separate candidate'])
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({key:result[key] for key in ['status','counts','control_count','elapsed_seconds','peak_rss_kib']}))
    for p in projections:
        if p['n']==23 and p['padded'] and 'nonzero' in p['recovery']:
            print(json.dumps({key:p[key] for key in ['tables','per_bracket','complete_scanned_loop_mul_unit_aware',
                           'candidate_scanned_loop_mul','removed_weight_mul','fraction_of_scanned_loop_fp2_mul_removed',
                           'fraction_of_lowered_base_mul_removed','literal_api_operation_fraction_removed']}))


if __name__=='__main__': main()

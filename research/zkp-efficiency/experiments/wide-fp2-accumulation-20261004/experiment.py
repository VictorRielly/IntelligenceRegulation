#!/usr/bin/env python3
"""Independent fixed-width and complete-clause checks under hard light limits."""
import hashlib,itertools,json,os,platform,random,resource,signal,time
from pathlib import Path
from collections import Counter
from field_support import F,P
from accumulator import U192,WideDot,FusedDot,dot,reduce128,SAFE_TERMS,MAX192,B,MASK
from wide_rounds import AccumRounds
from baseline import TaggedRounds
from fixtures import fixture
from prepared import Plan,PreparedTerms,generalize
import oracle as o

HERE=Path(__file__).resolve().parent; SEED=2026100435

def reference(xs,ys):
    # Unbounded integer sums with exactly one modular reduction per coefficient.
    # Independent of the candidate limb reducer, carry code and F arithmetic.
    return (sum(x.a*y.a+7*x.b*y.b for x,y in zip(xs,ys))%P,
            sum(x.a*y.b+x.b*y.a for x,y in zip(xs,ys))%P)

def main():
    t0=time.perf_counter(); signal.alarm(59)
    resource.setrlimit(resource.RLIMIT_CPU,(59,59)); resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))}); os.nice(10)
    rng=random.Random(SEED); counts=Counter(); controls=[]; total=Counter(); digest=hashlib.sha256()
    bounds={'prime':P,'max_product':(P-1)**2,'u128_max':(1<<128)-1,
            'two_max_products_exceed_u128':2*(P-1)**2>(1<<128)-1,
            'safe_wide_terms':SAFE_TERMS,'worst_terms_chunk1024_bits':(2048*(P-1)**2).bit_length(),
            'fused_single_product_plus_residue_fits_u128':(P-1)**2+(P-1)<1<<128,
            'fused_reduced_bd_times7_plus_residue_fits_u128':8*(P-1)<1<<128}
    assert all(bounds[k] for k in ['two_max_products_exceed_u128','fused_single_product_plus_residue_fits_u128','fused_reduced_bd_times7_plus_residue_fits_u128'])
    assert 2*SAFE_TERMS*(P-1)**2<=MAX192<2*(SAFE_TERMS+1)*(P-1)**2
    boundary=[0,1,P-1,P,P+1,B-1,B,B+1,(1<<96)-1,1<<96,(1<<128)-1]
    for x in boundary+[rng.randrange(1<<128) for _ in range(2048)]:
        assert reduce128(x)==x%P; counts['u128_reducer_checks']+=1
    for x in [0,1,B-1,B,B+1,(1<<128)-1,1<<128,MAX192]+[rng.randrange(1<<192) for _ in range(2048)]:
        u=U192();u.limbs=[(x>>(64*j))&MASK for j in range(3)]
        assert u.reduce()==x%P;counts['u192_reducer_checks']+=1
    extrema=[F(0),F(1),F(P-1,P-1),F(P-1,0),F(0,P-1),F(1,P-1),F(P-2,P-3)]
    fixtures=[]
    for x,y in itertools.product(extrema,repeat=2): fixtures.append(([x,y,x],[y,x,y]))
    for n,mode in itertools.product((0,1,2,3,7,8,9,31,32,33,63,64,65,127,128,129,1023,1024,1025),('full','base','zero','max')):
        draw=lambda: F(rng.randrange(P),rng.randrange(P)) if mode=='full' else F(rng.randrange(P)) if mode=='base' else F(P-1,P-1) if mode=='max' else F()
        fixtures.append(([draw() for _ in range(n)],[draw() for _ in range(n)]))
    for xs,ys in fixtures:
        expected=reference(xs,ys);counts['dot_fixtures']+=1
        for kind,ch in [(WideDot,1),(WideDot,7),(WideDot,32),(WideDot,1024),(FusedDot,1024)]:
            actual,c=dot(xs,ys,kind,ch);assert (actual.a,actual.b)==expected
            counts['dot_schedules']+=1
            if kind is WideDot:
                flush=(len(xs)+ch-1)//ch
                assert c['flushes']==flush and c['variable_products']==4*len(xs)
                assert c['reduce128']==7*flush and c['limb_adds']==16*len(xs)
                total.update(c);counts['counter_checks']+=4
            else: assert c['reduce128']==5*len(xs);counts['counter_checks']+=1
            digest.update(actual.wire())
    # Full source-derived clauses, using prior expanded original-cube oracle.
    for n,ls,padded,mode in itertools.product((0,1,2,3),(2,3),(False,True),('full','base','zero','boolean')):
        cfg,const,ir,tabs,rs=fixture(n,ls,padded,mode,rng,even=(ls==2))
        original=[o.table(t,n) for t in tabs]; pure=list(enumerate(ir));prefix=[];expected=[]
        for r in rs:
            expected.append([o.round_direct(original,pure,prefix,t,n) for t in range(6)]);prefix.append(o.tup(r))
            counts['independent_cube_samples']+=6
        finals=[o.mle(t,prefix) for t in original]
        plan=Plan(generalize(cfg),const['alpha'],const['gu8'])
        groups=[(g,PreparedTerms(terms,g,cfg,const,plan)) for g,terms in enumerate(ir)]
        baseline=TaggedRounds(tabs,n,5,groups)
        for j,r in enumerate(rs): assert list(map(o.tup,baseline.round(j)))==expected[j];baseline.fold(r)
        assert list(map(o.tup,baseline.finals()))==finals;counts['complete_clause_fixtures']+=1
        for kind,ch,debug in [(WideDot,1,False),(WideDot,7,False),(WideDot,1024,False),(WideDot,7,True),(FusedDot,1024,False)]:
            candidate=AccumRounds(tabs,n,5,groups,kind,ch,debug)
            for j,r in enumerate(rs):
                got=candidate.round(j);assert list(map(o.tup,got))==expected[j]
                for x in got:digest.update(x.wire())
                candidate.fold(r);counts['candidate_cube_samples']+=6
            assert list(map(o.tup,candidate.finals()))==finals
            counts['direct_mle_final_values']+=len(finals);counts['clause_schedules']+=1
            counts['recoveries']+=candidate.recoveries;counts['zero_factor_fallbacks']+=candidate.zero_fallbacks
    def refusal(name,fn,err):
        try:fn()
        except err:controls.append({'name':name,'detected':True});return
        raise AssertionError(name)
    def mismatch(name,got,want):
        assert got!=want,name;controls.append({'name':name,'detected':True})
    x=F(P-1,P-1);e=reference([x,x],[x,x])
    wrapped=lambda z:(z&((1<<128)-1))%P
    mismatch('blind_u128_real_overflow',(wrapped(16*(P-1)**2),e[1]),e)
    mismatch('blind_u128_cross_overflow',(e[0],wrapped(4*(P-1)**2)),e)
    mismatch('wrong_nonresidue',((2*(P-1)**2+10*(P-1)**2)%P,e[1]),e)
    mismatch('omit_cross_product',(e[0],2*(P-1)**2%P),e)
    u=U192();u.limbs=[1,2,3];z=1+2*B+3*B*B
    mismatch('drop_high_limb',reduce128(1+2*B),z%P)
    mismatch('wrong_high_limb_sign',(reduce128(1+2*((1<<32)-1))+(3<<32))%P,z%P)
    u=U192();u.limbs=[MASK,MASK,0];u.add128(1)
    assert u.limbs==[0,0,1];counts['carry_chain_boundary_checks']+=1
    mismatch('drop_middle_carry',0,u.reduce())
    d=WideDot(7);d.push(F(2,3),F(5,7))
    mismatch('missing_ragged_flush',o.tup(d.total),reference([F(2,3)],[F(5,7)]))
    d.finish();refusal('push_after_finish',lambda:d.push(x,x),ValueError)
    refusal('double_finish',d.finish,ValueError)
    refusal('unsafe_chunk',lambda:WideDot(SAFE_TERMS+1),ValueError)
    refusal('zero_chunk',lambda:WideDot(0),ValueError)
    refusal('mismatched_lengths',lambda:dot([x],[]),ValueError)
    bad=F();bad.a=P;refusal('noncanonical_precondition',lambda:WideDot().push(bad,x),ValueError)
    u=U192();u.limbs=[MASK,MASK,MASK];refusal('u192_carry_overflow',lambda:u.add128(1),OverflowError)
    refusal('u128_product_overflow',lambda:U192().add128(1<<128),OverflowError)
    # Allocation-free scope census uses prior complete scan/fold baseline.
    prior=json.loads((HERE.parent/'affine-denominator-stepping-20261004/result.json').read_text())
    rows=[]
    for m in prior['projections']:
        n=m['n'];weighted=0;flush=0;logical_parts=0
        deg=[4,2,2] if m['padded'] else [3,1,1]
        for j in range(n):
            half=1<<(n-j-1);samples=sum(q+1-int(m['recovery'] and j>0 and not m['debug']) for q in deg)
            weighted+=half*samples;flush+=((half+1023)//1024)*samples;logical_parts+=((half+1023)//1024)
        base=m['counted_base_mul_before'];removed=5*weighted-7*flush
        # Reduction call census uses baseline base-mul count: every current base
        # multiplication uses reduce128; extra wide reducer calls are charged.
        rows.append({'n':n,'ls':m['ls'],'padded':m['padded'],'recovery':m['recovery'],'debug':m['debug'],
          'weighted_terms':weighted,'wide_flushes':flush,'baseline_scan_fold_reduce128_calls':base,
          'weighted_reduce128_before':5*weighted,'weighted_reduce128_after':7*flush,
          'whole_counted_reduce128_fraction_removed':removed/base if base else 0,
          'added_limb_adds':16*weighted,'added_carry_chains':4*weighted,
          'added_reducer_limb_mul':3*flush,'wide_constant_products':flush,
          'logical_wide_bytes_per_sample':72,'logical_retained_total_bytes_per_sample':16,
          'scratch_bytes_per_part':88*sum(q+1 for q in deg),
          'scratch_delta_bytes_per_part':72*sum(q+1 for q in deg),
          'fused_reduce128_calls':5*weighted,'fused_u128_adds':4*weighted,
          'fused_removed_fp_adds':4*weighted,
          'excluded':['bracket internals unchanged','folds unchanged','setup/Eq/inversion/interpolation','mask/transcript/PCS','witness','serialization','verification','native instructions/time/occupancy/spills']})
    hw={'device':'CPU only','cpu':next((l.split(':',1)[1].strip() for l in Path('/proc/cpuinfo').read_text().splitlines() if l.startswith('model name')),'unknown'),
        'threads':1,'affinity':sorted(os.sched_getaffinity(0)),'nice':os.getpriority(os.PRIO_PROCESS,0),'python':platform.python_version()}
    accounting={k:None for k in ['context_length','steady_state_tokens_per_s','total_workload_tokens_per_s','startup_seconds','startup_fraction','witness_seconds','proof_seconds','serialization_seconds','independent_verification_seconds','proof_latency_seconds','proof_lag_seconds','pipeline_drain_seconds']}
    accounting.update(accepted_complete_private8b_proofs=0,countable_tokens=0,passes=0,device='CPU only',prefill='none',resident_passes='none',decode='none')
    result={'run_id':'20261004T195034Z-13077bdd','cycle':'0035','status':'pass','seed':SEED,'counts':dict(counts),'bounds':bounds,'wide_dot_counters':dict(total),
        'controls':controls,'control_count':len(controls),'models':rows,'digest_sha256':digest.hexdigest(),
        'elapsed_seconds':time.perf_counter()-t0,'peak_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,'hardware':hw,
        'resource_limits':{'wall_seconds':59,'cpu_seconds':59,'address_space_mib':512,'estimated_memory_mib':64},
        'proof_accounting':accounting,'code_hashes':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in HERE.glob('*.py')}}
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ['status','counts','control_count','elapsed_seconds','peak_rss_kib','bounds','hardware']}))

if __name__=='__main__':main()

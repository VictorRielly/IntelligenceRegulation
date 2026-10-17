#!/usr/bin/env python3
"""One-thread bounded differential algebra and literal operation accounting."""
import hashlib, itertools, json, os, platform, random, resource, signal, time
from collections import Counter
from pathlib import Path
from field_support import F, P
from accumulator import reduce128, FusedDot, WideDot, dot, addfp
from fused4 import mac, product, native_baseline, Fused4Dot, MAX128, REAL_BOUND, IMAG_BOUND
from baseline import TaggedRounds
from wide_rounds import AccumRounds
from fixtures import fixture
from prepared import Plan, PreparedTerms, generalize
import oracle as o
import cuda_limb_model as cuda

HERE = Path(__file__).resolve().parent
SEED = 2026101236
RUN_ID = '20261012T172555Z-e8207bdf'

def reference(acc, x, y):
    # Independent unbounded polynomial convolution, followed by one modulo per limb.
    coeff = [0, 0, 0]
    for i, a in enumerate((x.a, x.b)):
        for j, b in enumerate((y.a, y.b)): coeff[i+j] += a*b
    return ((acc.a+coeff[0]+7*coeff[2]) % P,
            (acc.b+coeff[1]) % P)

def main():
    start = time.perf_counter(); signal.alarm(59)
    resource.setrlimit(resource.RLIMIT_CPU, (59, 59))
    resource.setrlimit(resource.RLIMIT_AS, (512*1024**2, 512*1024**2))
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))}); os.nice(10)
    rng = random.Random(SEED); counts = Counter(); controls = []; arithmetic = Counter()
    digest = hashlib.sha256()
    edges = [0, 1, P-1, P-2, (1<<32)-1, 1<<32]
    boundary = [0, 1, P-1, P, P+1, (1<<64)-1, 1<<64,
                (1<<96)-1, 1<<96, MAX128, REAL_BOUND, IMAG_BOUND]
    for v in boundary + [rng.randrange(1<<128) for _ in range(2048)]:
        assert reduce128(v) == v % P; counts['reducer_checks'] += 1
    inputs = itertools.chain(itertools.product(edges, repeat=6),
        (tuple(rng.randrange(P) for _ in range(6)) for _ in range(8192)))
    for a,b,c,d,e,f in inputs:
        acc,x,y = F(a,b),F(c,d),F(e,f); expected = reference(acc,x,y)
        got = mac(acc,x,y,arithmetic)
        assert o.tup(got) == expected == o.tup(native_baseline(acc,x,y))
        assert o.tup(cuda.mac(acc,x,y)) == expected
        counts['cuda_limb_mac_fixtures'] += 1
        assert o.tup(product(x,y)) == reference(F(),x,y)
        counts['mac_fixtures'] += 1; counts['product_fixtures'] += 1
        digest.update(got.wire())
    assert arithmetic['reduce128'] == 4*counts['mac_fixtures']
    assert arithmetic['u128_adds'] == 4*counts['mac_fixtures']
    for _ in range(2048):
        x,y,z = [F(rng.randrange(P),rng.randrange(P)) for j in range(3)]
        assert product(product(x,y),z) == product(x,product(y,z))
        assert product(x,y+z) == product(x,y)+product(x,z)
        assert product(x,y) == product(y,x)
        counts['extension_law_fixtures'] += 1
    # Ragged row-part schedules and arbitrary accumulator state.
    for n, mode in itertools.product((0,1,2,3,7,8,9,31,32,33,127,128,129,1023,1024,1025),
                                    ('full','base','zero','max')):
        draw = lambda: F(rng.randrange(P),rng.randrange(P)) if mode=='full' else (
            F(rng.randrange(P)) if mode=='base' else F(P-1,P-1) if mode=='max' else F())
        xs,ys = [draw() for j in range(n)], [draw() for j in range(n)]
        initial = F(rng.randrange(P),rng.randrange(P))
        expected = ((initial.a+sum(x.a*y.a+7*x.b*y.b for x,y in zip(xs,ys)))%P,
                    (initial.b+sum(x.a*y.b+x.b*y.a for x,y in zip(xs,ys)))%P)
        for chunk in (1,3,7,1024):
            acc = initial
            for off in range(0,n,chunk):
                part,counter = dot(xs[off:off+chunk],ys[off:off+chunk],Fused4Dot,chunk)
                assert counter['reduce128']==4*len(xs[off:off+chunk])
                acc = F(addfp(acc.a,part.a),addfp(acc.b,part.b))
            assert o.tup(acc)==expected
            counts['partition_schedules'] += 1; digest.update(acc.wire())
    saved_mul, saved_rmul = F.__mul__, F.__rmul__
    def fused_mul(x,y): return product(x, y if isinstance(y,F) else F(y))
    # Complete source-derived SC_SZC polynomial, independent tuple original-cube oracle.
    # Storage/scheduling is copied locally; no native masks/extension/PCS are executed.
    for n,ls,padded,mode in itertools.product((0,1,2,3),(2,3),(False,True),
                                            ('full','base','zero','boolean')):
        cfg,const,ir,tabs,rs = fixture(n,ls,padded,mode,rng,even=(ls==2))
        tables = [o.table(t,n) for t in tabs]; groups_plain = list(enumerate(ir))
        prefix = []; expected = []
        for r in rs:
            expected.append([o.round_direct(tables,groups_plain,prefix,t,n) for t in range(6)])
            prefix.append(o.tup(r)); counts['independent_cube_samples'] += 6
        final = [o.mle(t,prefix) for t in tables]
        plan = Plan(generalize(cfg),const['alpha'],const['gu8'])
        groups = [(g,PreparedTerms(terms,g,cfg,const,plan)) for g,terms in enumerate(ir)]
        baseline = TaggedRounds(tabs,n,5,groups)
        for j,r in enumerate(rs):
            assert list(map(o.tup,baseline.round(j)))==expected[j]; baseline.fold(r)
        assert list(map(o.tup,baseline.finals()))==final
        counts['complete_clause_fixtures'] += 1
        schedules = [(Fused4Dot,False,False),(Fused4Dot,True,False),
                     (Fused4Dot,False,True),(Fused4Dot,True,True)]
        for kind,debug,global_product in schedules:
            if global_product: F.__mul__,F.__rmul__ = fused_mul,fused_mul
            try:
                candidate = AccumRounds(tabs,n,5,groups,kind,1024,debug)
                for j,r in enumerate(rs):
                    got = candidate.round(j)
                    assert list(map(o.tup,got))==expected[j]
                    for x in got: digest.update(x.wire())
                    candidate.fold(r); counts['candidate_cube_samples'] += 6
                assert list(map(o.tup,candidate.finals()))==final
                assert candidate.counts['reduce128']==4*candidate.counts['terms']
                counts['direct_mle_final_values'] += len(final)
                counts['clause_schedules'] += 1
                counts['recoveries'] += candidate.recoveries
                counts['zero_factor_fallbacks'] += candidate.zero_fallbacks
            finally: F.__mul__,F.__rmul__ = saved_mul,saved_rmul
    def mismatch(name,got,want):
        assert got!=want,name; controls.append({'name':name,'detected':True})
    def refusal(name,fn,error):
        try: fn()
        except error: controls.append({'name':name,'detected':True}); return
        raise AssertionError(name)
    x = F(P-1,P-1); acc = F(P-1,P-1); expected=reference(acc,x,x)
    wrap = lambda v: (v & MAX128) % P
    mismatch('two_raw_products_imag_u128_wrap',(expected[0],wrap(2*(P-1)**2+P-1)),expected)
    mismatch('unreduced_bd_real_u128_wrap',(wrap(8*(P-1)**2+P-1),expected[1]),expected)
    mismatch('drop_accumulator',o.tup(product(x,x)),expected)
    mismatch('wrong_nonresidue',((acc.a+x.a*x.a+5*x.b*x.b)%P,expected[1]),expected)
    mismatch('omit_cross_product',(expected[0],(acc.b+x.a*x.b)%P),expected)
    real_input = x.a*x.a+7*reduce128(x.b*x.b)+acc.a
    mismatch('truncate_product_before_reduction',((real_input & ((1<<64)-1))%P,expected[1]),expected)
    # A noncanonical representation may violate the headroom proof. Never accept it.
    bad = F(); bad.a=(1<<64)-1; bad.b=(1<<64)-1
    assert bad.a*bad.a+8*bad.a>MAX128
    for role in ('acc','x','y'):
        args = [acc,x,x]; args[['acc','x','y'].index(role)] = bad
        refusal('noncanonical_'+role,lambda args=args:mac(*args),ValueError)
    d=Fused4Dot(); d.push(F(2,3),F(5,7)); value=d.finish()
    mismatch('drop_last_row',o.tup(F()),o.tup(value))
    refusal('push_after_finish',lambda:d.push(x,x),ValueError)
    refusal('double_finish',d.finish,ValueError)
    refusal('invalid_chunk',lambda:Fused4Dot(0),ValueError)
    refusal('mismatched_lengths',lambda:dot([x],[],Fused4Dot),ValueError)
    refusal('reducer_overflow',lambda:reduce128(1<<128),OverflowError)
    refusal('reducer_negative',lambda:reduce128(-1),OverflowError)
    for a,b in itertools.chain(itertools.product(edges+[(1<<64)-1],repeat=2),
            ((rng.randrange(1<<64),rng.randrange(1<<64)) for _ in range(2048))):
        lo,hi=cuda.mul128(a,b)
        assert lo+(hi<<64)==a*b
        counts['cuda_schoolbook_mul_checks']+=1
    for a,b in [((cuda.MASK,0),(1,0)),((cuda.MASK,cuda.MASK-1),(1,0)),
                ((3,2),(5,7)),((0,0),(0,0))]:
        lo,hi=cuda.plus128(a,b)
        assert lo+(hi<<64)==a[0]+b[0]+((a[1]+b[1])<<64)
        counts['cuda_add_carry_checks']+=1
    refusal('cuda_top_carry_overflow',lambda:cuda.plus128((cuda.MASK,cuda.MASK),(1,0)),OverflowError)
    xx,yy,aa=F(P-2,P-1),F(P-2,P-1),F(P-1,P-1)
    raw=cuda.mul128(xx.a,yy.a); rhs=cuda.mul128(7,reduce128(xx.b*yy.b))
    wrong=((raw[0]+rhs[0]+aa.a)&cuda.MASK,raw[1]+rhs[1])
    mismatch('cuda_drop_low_carry',cuda.red(wrong),reference(aa,xx,yy)[0])
    xx,yy,aa=F(3,P-1),F(5,1),F(2,0)
    raw=cuda.mul128(xx.a,yy.a); rhs=cuda.mul128(7,P-1)
    wrong=cuda.plus128(cuda.plus128(raw,(rhs[0],0)),(aa.a,0))
    mismatch('cuda_drop_constant_product_high',cuda.red(wrong),reference(aa,xx,yy)[0])
    # Count only source-derived scans/folds, with all unchanged operations retained.
    prior=json.loads((HERE.parent/'affine-denominator-stepping-20261004/result.json').read_text())
    rows=[]
    for m in prior['projections']:
        n=m['n']; degrees=[4,2,2] if m['padded'] else [3,1,1]
        weighted=sum((1<<(n-j-1))*sum(q+1-int(m['recovery'] and j>0 and not m['debug'])
                                  for q in degrees) for j in range(n))
        full=m['before'].get('mul',0); baseline=m['counted_base_mul_before']
        assert baseline==5*full+2*m['before'].get('mul_base',0)
        assert weighted<=full
        rows.append({k:m[k] for k in ('n','ls','padded','recovery','debug')} | {
            'baseline': 'cycle0033 compiled denominators; cycle0034 before stepping',
            'counted_full_fp2_mul':full,'weighted_mac_terms':weighted,
            'baseline_scan_fold_reduce128':baseline,
            'weighted_only_reduce128_removed':weighted,
            'weighted_only_reduction_fraction_removed':weighted/baseline if baseline else 0,
            'global_product_reduce128_removed':full,
            'global_product_reduction_fraction_removed':full/baseline if baseline else 0,
            'weighted_only_modular_base_adds_removed':4*weighted,
            'weighted_only_u128_adds_added':4*weighted,
            'global_plus_mac_modular_base_adds_removed':2*full+2*weighted,
            'global_plus_mac_u128_adds_added':2*full+2*weighted,
            'extra_persistent_scratch_bytes':0,
            'new_costs':['u128 addition carries','changed dependency chains','compiler/instruction/spill behavior unmeasured'],
            'excluded':m['excluded']})
    accounting={k:None for k in ('context_length','steady_state_tokens_per_s','total_workload_tokens_per_s',
        'startup_seconds','startup_fraction','witness_seconds','proof_seconds','serialization_seconds',
        'independent_verification_seconds','proof_latency_seconds','proof_lag_seconds','pipeline_drain_seconds')}
    accounting.update(accepted_complete_private8b_proofs=0,countable_tokens=0,passes=0,
                      device='CPU only',prefill='none',resident_passes='none',decode='none')
    result={'run_id':RUN_ID,'cycle':'0036','status':'pass','seed':SEED,'counts':dict(counts),
        'mac_counters':dict(arithmetic),'controls':controls,'control_count':len(controls),
        'bounds':{'prime':P,'u128_max':MAX128,'real_mac_bound':REAL_BOUND,'imag_mac_bound':IMAG_BOUND,
                  'real_headroom':MAX128-REAL_BOUND,'imag_headroom':MAX128-IMAG_BOUND,
                  'canonical_only':True,'two_raw_products_fit':False},
        'models':rows,'digest_sha256':digest.hexdigest(),'proof_accounting':accounting,
        'elapsed_seconds':time.perf_counter()-start,'peak_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        'hardware':{'device':'CPU only','cpu':next((x.split(':',1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name')),'unknown'),
                    'threads':1,'affinity':sorted(os.sched_getaffinity(0)),'nice':os.getpriority(os.PRIO_PROCESS,0),'python':platform.python_version()},
        'resource_limits':{'wall_seconds':59,'cpu_seconds':59,'address_space_mib':512,'estimated_memory_mib':64},
        'code_hashes':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in HERE.glob('*.py')},
        'limits':['Synthetic fixed-width algebra, not native code or speed',
                  'Generic shared scheduler has an independent original-cube oracle',
                  'Honest native witness/private maps/support/masks/transcript/extensions/refusal/PCS/bytes unexecuted',
                  'No GPU/job/build/dependency installation or downloaded code execution']}
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ('status','counts','control_count','elapsed_seconds','peak_rss_kib','bounds','hardware')}))

if __name__=='__main__': main()

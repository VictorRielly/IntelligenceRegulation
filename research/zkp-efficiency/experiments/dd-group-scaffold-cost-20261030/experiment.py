"""Full scalar-scaffold census and zero-safe three-factor inversion differential."""
from pathlib import Path
from collections import Counter
import hashlib, itertools, json, os, platform, random, time
import scaffold as s

E=Path(__file__).resolve().parent
SEED=20261030170
PRIOR=E.parent/'dd-calibration-boundaries-20261030'

# Separate schoolbook tuple reference; inverse by exponent p^2-2, not norms.
def mul(a,b):
    return ((a[0]*b[0]+7*a[1]*b[1])%s.P,(a[0]*b[1]+a[1]*b[0])%s.P)
def inverse(a):
    assert a!=(0,0)
    e=s.P*s.P-2; out=(1,0)
    while e:
        if e&1:out=mul(out,a)
        a=mul(a,a);e>>=1
    return out

def grouped_counts_without_scan(counter):
    out=Counter()
    for key,v in counter.items():
        phase,op=key.split(':')
        if phase not in ['scan','fold','other']:out[op]+=v
    return out

def scan_counts(n,recover,group_rec,k=15):
    per=[Counter(add=19,mul=20,sub=12,mul_base=4),Counter(mul=2,add=1),
         Counter(mul_base=1,add=1,sub=1,mul=2)]
    gen,grp=Counter(),Counter()
    for j in range(n):
        m=1<<(n-j-1);S=5-int(recover and j>0)
        G=[d+1-int(group_rec[j][g]) for g,d in enumerate([3,1,1])]
        for g in range(3):
            for op,v in per[g].items():gen[op]+=m*S*v;grp[op]+=m*G[g]*v
        gen['mul']+=m*S*3;gen['add']+=m*S*3
        grp['mul']+=m*(3+sum(G));grp['add']+=m*sum(G)
        for cc,dmax in [(gen,4),(grp,3)]:
            cc['sub']+=2*m*k;cc['mul']+=m*k;cc['add']+=m*(dmax*k+k)
    return gen,grp

def census(n,span,label,case):
    recovery=[[False]*3 if j==0 or case=='zero-fallback' else [True]*3 for j in range(n)]
    scalar,_=s.scalar_counts(n,span,recovery)
    generic=Counter()
    for j in range(n):
        generic.update(s.interpolation_counts(5))
        if j>0:generic['sub']+=1
    gs,fs=scan_counts(n,True,recovery)
    old=gs+generic;new=fs+scalar
    # Large-path Rayon reductions: c mapped chunks, 1..c leaf partitions.
    # Its source reduce(identity, combine) performs c..2c-1 vector combines.
    csum_low=csum_high=0
    for j in range(n):
        half=1<<(n-j-1)
        if half*15 > 1<<16:
            c=(half+1023)//1024
            csum_low+=c;csum_high+=2*c-1
    reduced={op:old[op]-new[op] for op in set(old)|set(new)}
    bp_old=s.base_product_count(old);bp_new=s.base_product_count(new)
    max_eq_words=max(sum((1<<(max(l-j-1,0)//2))+(1<<((max(l-j-1,0)+1)//2)) for l in [n,span,n]) for j in range(n))
    return dict(label=label,n=n,row_span=span,case=case,projection_tables=15,
                generic_scan_fold=dict(gs),grouped_scan_fold=dict(fs),
                generic_scalar=dict(generic),grouped_scalar=dict(scalar),
                scalar_base_products_extra=s.base_product_count(scalar)-s.base_product_count(generic),
                total_removed_api=reduced,base_products_before=bp_old,base_products_after=bp_new,
                base_products_removed=bp_old-bp_new,not_time=True,
                extra_reduction_adds_range=[3*csum_low,3*csum_high],
                max_split_eq_payload_bytes=16*max_eq_words,
                batch_norm_inverse_saving=sum(max(sum(x)-1,0) for x in recovery),
                batch_norm_extra_base_mul=sum(3*sum(x) for x in recovery if sum(x)>1),
                limits='15-vector arithmetic projection at public dimensions. Allocation/dispatch/cache/threads/critical time/native CFS/PCS/extension costs unmeasured; no new profile admitted.')

def main():
    start=time.monotonic(); rng=random.Random(SEED);checks=Counter(); evidence=[]; inv_fixtures=[]; controls=[]
    fixtures=json.loads((PRIOR/'fixtures.json').read_text())
    for number,f in enumerate(fixtures):
        saved=[]
        for mode in ['individual','batch-norm']:
            s.COUNTS.clear();ev=s.Grouped(f,mode)
            for j,(expected,r) in enumerate(zip(f['rounds'],f['challenges'])):
                got=ev.round(j)
                assert [v.pair() for v in got]==expected,(number,j,mode)
                checks['saved_round_values']+=5
                ev.fold(j,s.F(*r))
            assert [t[0].pair() for t in ev.tables]==f['finals']
            checks['saved_ordered_finals']+=len(ev.tables)
            actual=grouped_counts_without_scan(s.COUNTS)
            if mode=='individual':
                formula,_=s.scalar_counts(f['n'],f['span'],[x['recover'] for x in ev.round_records])
                assert actual==formula,(number,actual,formula)
                checks['scalar_formula_matches']+=1
            saved.append(dict(mode=mode,scalar=dict(actual),round_records=ev.round_records,
                              rounds=f['rounds'],finals=f['finals']))
        evidence.append(dict(fixture=number,n=f['n'],span=f['span'],shift=f['shift'],modes=saved))
    # All 64 zero/eligibility bit patterns plus 96 random/base/boundary arrays.
    arrays=[]
    for zm,em in itertools.product(range(8),range(8)):
        arrays.append(([s.F() if zm>>i&1 else s.F(i+2,i+3) for i in range(3)],
                       [bool(em>>i&1) for i in range(3)]))
    for j in range(96):
        vals=[s.F(rng.randrange(s.P),rng.randrange(s.P) if j%2 else 0) for _ in range(3)]
        if j%7==0: vals[j%3]=s.F()
        arrays.append((vals,[True]*3))
    for vals,eligible in arrays:
        s.COUNTS.clear()
        with s.phase('inverse'):
            a=s.inverse_factors(vals,eligible,'individual');old=Counter(s.COUNTS)
            s.COUNTS.clear();b=s.inverse_factors(vals,eligible,'batch-norm');new=Counter(s.COUNTS)
        expected=[list(inverse((v.a,v.b))) if ok and not v.zero() else None for v,ok in zip(vals,eligible)]
        got=[v.pair() if v is not None else None for v in b]
        assert got==expected==[v.pair() if v is not None else None for v in a]
        checks['independent_factor_values']+=3
        inv_fixtures.append(dict(values=[v.pair() for v in vals],eligible=eligible,result=got,
                                 before=dict(old),after=dict(new)))
    vals=[s.F(2,3),s.F(),s.F(5,7)]
    expected=s.inverse_factors(vals,[True]*3,'batch-norm')
    # Actual mutation executions, including zero/ineligible handling.
    # Unsafe unfiltered norm product is zero: its inverse must fail, whereas
    # the candidate keeps only the nonzero eligible factors and still works.
    try:
        pow(0,-1,s.P)
        raise AssertionError('unsafe zero batch unexpectedly inverted')
    except ValueError:controls.append('unfiltered zero batch fails')
    for name,got in [
        ('wrong conjugate',[s.F(v.a,-v.b) if v is not None else None for v in expected]),
        ('wrong scatter',list(reversed(expected))),
        ('fill zero with one',[v if v is not None else s.F(1) for v in expected]),
        ('forget inverses',vals)]:
        assert got!=expected;controls.append(name)
    excluded=s.inverse_factors(vals,[False,False,False],'batch-norm')
    assert excluded!=expected;controls.append('recover without prior claim')
    # Nonzero prefix need not stay nonzero: Boolean challenge can kill it.
    assert s.F(1).mul(s.F(0)).zero();checks['zero_prefix_boundary']+=1
    # Costing control: previous 36 mul/pair is not unconditional with fallback.
    allnon=census(7,4,'synthetic','nonzero');allzero=census(7,4,'synthetic','zero-fallback')
    assert allzero['base_products_removed']<allnon['base_products_removed'];controls.append('assume recovery at zero factors')
    assert allnon['scalar_base_products_extra']>0;controls.append('omit scalar scaffold falsely overstates saving')
    rows=[]
    for n,span,label in [(7,4,'synthetic'),(19,12,'T128,32head DD public dimensions'),
                          (21,13,'Shieldstral T256,32head DD public dimensions'),
                          (23,14,'T512,32head arithmetic extrapolation; not admitted8BDD')]:
        for case in ['nonzero','zero-fallback']:rows.append(census(n,span,label,case))
    # Inspect small-cube crossing without allocating large cubes.
    crossing=[census(n,max(0,n-3),'synthetic','nonzero') for n in range(1,13)]
    result=dict(status='PASS',seed=SEED,checks=dict(checks),fixtures=len(fixtures),
                inverse_fixtures=len(inv_fixtures),negative_controls=len(controls),
                wall_s=time.monotonic()-start,native_execution=False,proofs=0,proved_positions=0,
                scope='Literal scalar scaffold at160 saved synthetic DD fixtures, independent exponent inverse reference, allocation-free public-dimension counts; not native proof or speed.')
    for name,obj in [('result',result),('scaffold-evidence',evidence),('inverse-fixtures',inv_fixtures),
                     ('negative-controls',controls),('cost-census',rows),('small-crossing',crossing)]:
        (E/(name+'.json')).write_text(json.dumps(obj,separators=(',',':'))+'\n')
    cpu=next((l.split(':',1)[1].strip() for l in Path('/proc/cpuinfo').read_text().splitlines() if l.startswith('model name')),'unknown')
    (E/'hardware.json').write_text(json.dumps(dict(cpu=cpu,python=platform.python_version(),
               affinity=sorted(os.sched_getaffinity(0)),threads=1,gpu='not used'),indent=2)+'\n')
    print(json.dumps(result))

if __name__=='__main__':main()

"""Standalone saved-evidence audit. Imports neither candidate nor driver.

Direct original-cube equations, schoolbook Fp2, expanded whole-slot cost
formulas and independent per-factor inverses. Not a native proof verifier.
"""
from pathlib import Path
from collections import Counter
import hashlib,itertools,json,time
E=Path(__file__).resolve().parent
P=2**64-2**32+1; Z=(0,0);O=(1,0)
checks=Counter()
def add(a,b):return ((a[0]+b[0])%P,(a[1]+b[1])%P)
def sub(a,b):return ((a[0]-b[0])%P,(a[1]-b[1])%P)
def mul(a,b):return ((a[0]*b[0]+7*a[1]*b[1])%P,(a[0]*b[1]+a[1]*b[0])%P)
def scale(a,k):return (a[0]*k%P,a[1]*k%P)
def prod(xs):
    out=O
    for x in xs:out=mul(out,x)
    return out
def eq(a,b):return prod(add(mul(x,y),mul(sub(O,x),sub(O,y))) for x,y in zip(a,b))
def bits(i,n):return [(i>>(n-1-j)&1,0) for j in range(n)]
def mle(table,x):
    out=Z
    for i,v in enumerate(table):out=add(out,mul(v,eq(x,bits(i,len(x)))))
    return out
def polynomial(v,c,sh):
    _,_,_,m,s,r,z,e,p,mx,total,h0,h1,hx,ht=v
    # Expanded expressions differ from the literal source port's temporaries.
    delta=add(sub(sub(mx,mul(m,s)),scale(m,127)),(127,0))
    exp=sub(sub(sub(sub(mul(hx,c['alpha']),mul(hx,delta)),mul(mul(hx,c['beta']),e)),mul(hx,c['gexp'])),O)
    keyed=add(add(add(c['gdd'],total),mul(c['beta'],mul(m,e))),mul(mul(c['beta'],c['beta']),p))
    dictionary=sub(mul(ht,sub(c['alpha'],keyed)),O)
    a=sub(sub(sub(c['alpha'],c['gu8']),(127,0)),s)
    b=add(sub(sub(c['alpha'],c['gu8']),(127,0)),s)
    d=sub(sub(c['alpha'],c['gu8']),r)
    f=sub(sub(c['alpha'],c['gu8']),scale(r,2**(8-sh)))
    helper=add(mul(c['mu2'],sub(sub(mul(h0,mul(a,b)),a),b)),
               mul(c['mu3'],sub(sub(mul(h1,mul(d,f)),d),f)))
    zero=add(add(add(add(helper,mul(c['mu4'],exp)),mul(c['mu5'],dictionary)),
                 mul(c['mu0'],sub(mul(z,z),z))),mul(c['mu1'],mul(z,delta)))
    row=mul(c['nu0'],add(total,c['lam']))
    score=mul(c['nu1'],sub(add(scale(s,2**sh),r),(2**(sh-1),0)))
    return add(add(mul(v[0],zero),mul(v[1],row)),mul(v[2],score))

def direct_round(f,prefix,t):
    c={k:tuple(v) for k,v in f['constants'].items()};out=Z
    rem=f['n']-len(prefix)-1
    for i in range(1<<rem):
        x=prefix+[(t,0)]+bits(i,rem)
        vals=[mle(tb,x) for tb in f['tables']]
        out=add(out,polynomial(vals,c,f['shift']))
    return out

def ip_counts(m):
    return dict(mul=m*m,sub_base=m*(m-1),base_mul=m*(m-1),base_inv=m,mul_base=m,add=m)
def base(c):
    return 5*c.get('mul',0)+2*c.get('mul_base',0)+c.get('base_mul',0)+127*c.get('base_inv',0)+132*c.get('inv2',0)
def closed_scalar(n,span,nrec):
    active=2*n+span
    suffix_sub=n*(n-1)+span*(span-1)//2
    suffix_mul=0
    for length in [n,span,n]:
        for rem in range(length):suffix_mul+=2*((1<<(rem//2))+(1<<((rem+1)//2))-2)
    return Counter(mul=130*n+13*active+suffix_mul+2*nrec,
                   add=46*n+11*active,sub=12*active+suffix_sub+nrec,
                   mul_base=31*n,sub_base=84*n,base_mul=84*n,base_inv=31*n,inv2=nrec)

def main():
    start=time.monotonic()
    pins=json.loads((E/'source-pins.json').read_text())
    for pin in pins:
        assert hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()==pin['sha256']
        if 'snapshot' in pin:assert hashlib.sha256(Path(pin['snapshot']).read_bytes()).hexdigest()==pin['sha256']
        checks['source_pins']+=1
    # Actual selected profile guard, absent from the earlier branch-only pin.
    arg=(E/'native/8-argument.rs').read_text()
    accuracy=(E/'native/r14-argument_accuracy.rs').read_text()
    precision=(E/'native/r14-accuracy_precision.rs').read_text()
    layout=(E/'native/r14-accuracy_layout.rs').read_text()
    dispatch=arg.split('pub(crate) fn define(')[1]
    assert dispatch.index('accuracy::define_changed') < dispatch.index('SC_SZC if sh.dd_cap > 0')
    assert 'accuracy_stack()!=crate::private_block::accuracy_precision::Stack::Legacy' in dispatch
    assert 'SC_SZC if sh.dd_cap>0=>szc_dd(ctx,pts,tr).map(Some)' in accuracy
    body=accuracy.split('fn szc_dd(')[1].split('\nfn szc(')[0]
    assert 'precision.score' in body and 'limbs(v,&rsl_ix)' in body
    assert 'role(&b,low,L::Rs)' in body and 'b.finish(Box::new(poly), hosted)' in body
    assert 'def.groups' not in body and body.count('b.eq(')==3
    assert 'p.score += 12;' in precision
    assert 'Limbs::Rs,"RSL",3,A_RSL,1' in layout
    tests=(E/'native/r14-split_definition_tests.rs').read_text()
    assert '.filter(|t| matches!(t, Tab::Priv(_)))' in tests
    checks['actual_profile_source_facts']+=10
    # Reachable derived precision for base score6: actual score18, three Rs
    # limbs. This synthetic remainder is within [0,2^18), but legacy single-
    # limb reconstruction and scale give a different host relation.
    score=2;rs=[3,4,1];derived=6+12
    remainder=sum(v*256**j for j,v in enumerate(rs))
    assert 0<=remainder<2**derived
    actual=(2**derived)*score+remainder-2**(derived-1)
    stale=64*score+rs[0]-32
    assert actual!=stale and actual%P!=stale%P
    checks['actual_profile_host_negative']+=3
    source_result=dict(status='PASS',legacy_branch_identity_is_not_dispatch_identity=True,
        selected_relation='argument_accuracy.rs::szc_dd for non-Legacy DD',
        current_accuracy_tables_counted=18,current_private_terminals_counted=14,
        legacy_projection_tables=15,legacy_projection_scope_only=True,
        synthetic_host_control=dict(base_score_shift=6,derived_score_shift=derived,
             score=score,remainder_limbs=rs,remainder=remainder,actual_host=actual,stale_host=stale),
        implication='Legacy160-fixture grouping and scan counts cannot be promoted to LOW/LOW+h24. Actual three-limb/six-lookup/three-helper polynomial differential is next. No admission or native proof.')
    (E/'source-compatibility.json').write_text(json.dumps(source_result,indent=2)+'\n')
    prior=json.loads((E.parent/'dd-calibration-boundaries-20261030/fixtures.json').read_text())
    evidence=json.loads((E/'scaffold-evidence.json').read_text())
    for f,e in zip(prior,evidence):
        assert len(e['modes'])==2
        prefix=[]
        for j,expected in enumerate(f['rounds']):
            expected2=[list(direct_round(f,prefix,t)) for t in range(5)]
            assert expected2==expected
            checks['independent_original_cube_round_values']+=5
            for arm in e['modes']:
                assert arm['rounds'][j]==expected2
                checks['saved_arm_round_values']+=5
            prefix.append(tuple(f['challenges'][j]))
        finals=[list(mle(tb,prefix)) for tb in f['tables']]
        for arm in e['modes']:
            assert arm['finals']==finals
            checks['independent_original_cube_finals']+=len(finals)
        old=e['modes'][0]; nrec=sum(sum(r['recover']) for r in old['round_records'])
        assert Counter(old['scalar'])==closed_scalar(f['n'],f['span'],nrec)
        checks['independent_closed_scalar_census']+=1
        for j,r in enumerate(old['round_records']):
            assert all(flag==(j>0 and factor!=[0,0]) for flag,factor in zip(r['recover'],r['factors']))
            checks['recovery_eligibility']+=3
    for f in json.loads((E/'inverse-fixtures.json').read_text()):
        expected=[]
        m=0
        for value,ok in zip(f['values'],f['eligible']):
            a,b=value
            if not ok or a==b==0:expected.append(None);continue
            # Independent norm formula here, unlike driver's exponent oracle.
            z=pow((a*a-7*b*b)%P,-1,P)
            expected.append([a*z%P,-b*z%P]);m+=1
        assert expected==f['result']
        for v,r in zip(f['values'],expected):
            if r is not None:assert mul(v,r)==O
            checks['inverse_values']+=1
        before=Counter({k.split(':')[1]:v for k,v in f['before'].items()})
        after=Counter({k.split(':')[1]:v for k,v in f['after'].items()})
        assert before==Counter(inv2=m)
        if m>=2:
            assert after==Counter(base_mul=8*m,base_sub=m,base_neg=m,base_inv=1)
            assert base(before)-base(after)==132*m-(8*m+127)
        else:assert after==before
        checks['inverse_api_counts']+=1
    for row in json.loads((E/'cost-census.json').read_text())+json.loads((E/'small-crossing.json').read_text()):
        n,span=row['n'],row['row_span'];rec=3*(n-1) if row['case']=='nonzero' else 0
        assert Counter(row['grouped_scalar'])==closed_scalar(n,span,rec)
        generic=Counter({k:n*v for k,v in ip_counts(5).items()});generic['sub']=n-1
        assert Counter(row['generic_scalar'])==generic
        old=Counter(row['generic_scan_fold'])+generic;new=Counter(row['grouped_scan_fold'])+Counter(row['grouped_scalar'])
        assert row['base_products_before']==base(old) and row['base_products_after']==base(new)
        assert row['scalar_base_products_extra']==base(row['grouped_scalar'])-base(generic)
        checks['public_dimension_census']+=1
    # Saved count-only negative is a real distinction; no CPU speed implied.
    crossing=json.loads((E/'small-crossing.json').read_text())
    assert crossing[6]['base_products_removed']<0<crossing[7]['base_products_removed']
    controls=json.loads((E/'negative-controls.json').read_text());assert len(controls)==8
    checks['saved_control_labels']+=len(controls)
    result=dict(status='PASS',checks=dict(checks),total_checks=sum(checks.values()),wall_s=time.monotonic()-start,
                scope='Locally authored independent equations/count audit, not external/native/privacy verification; control labels not independently reexecuted.')
    (E/'audit-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))

if __name__=='__main__':main()

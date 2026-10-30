"""Standalone saved-evidence replay: imports no candidate/reference modules."""
from pathlib import Path
from collections import Counter
import json,time,hashlib
E=Path(__file__).resolve().parent;P=2**64-2**32+1;Z=(0,0);O=(1,0)
def add(a,b):return ((a[0]+b[0])%P,(a[1]+b[1])%P)
def sub(a,b):return ((a[0]-b[0])%P,(a[1]-b[1])%P)
def mul(a,b):
    q=[0,0,0]
    for i in range(2):
        for j in range(2):q[i+j]+=a[i]*b[j]
    return ((q[0]+7*q[2])%P,q[1]%P)
def k(n):return (n%P,0)
def sumv(xs):
    r=Z
    for x in xs:r=add(r,x)
    return r
def bits(i,n):return [(i>>(n-1-j))&1 for j in range(n)]
def eq(p,x):
    r=O
    for a,b in zip(p,x):r=mul(r,add(mul(a,b),mul(sub(O,a),sub(O,b))))
    return r
def mle(words,x):
    r=Z
    for i,w in enumerate(words):
        f=O
        for bit,q in zip(bits(i,len(x)),x):f=mul(f,q if bit else sub(O,q))
        r=add(r,mul(w,f))
    return r
def native_poly(v,c,shift):
    # Direct ungrouped DD source equation, with separately implemented field.
    q0,q1,q2,m,s,r,z,e,p,mx,total,h0,h1,hx,ht=v
    delta=add(sub(mx,mul(m,add(s,k(127)))),k(127))
    den=[sub(c['alpha'],add(c['gu8'],add(k(127),s))),
         sub(c['alpha'],add(c['gu8'],sub(k(127),s))),
         sub(c['alpha'],add(c['gu8'],r)),
         sub(c['alpha'],add(c['gu8'],mul(k(2**(8-shift)),r)))]
    helper=[]
    for j,h in enumerate([h0,h1]):
        a,b=den[2*j:2*j+2]
        helper.append(mul(c['mu'+str(2+j)],sub(mul(mul(h,a),b),add(a,b))))
    cx=sub(mul(hx,sub(c['alpha'],sumv([delta,mul(c['beta'],e),c['gexp']]))),O)
    ct=sub(mul(ht,sub(c['alpha'],sumv([c['gdd'],total,mul(c['beta'],mul(m,e)),mul(mul(c['beta'],c['beta']),p)]))),O)
    zero=sumv(helper+[mul(c['mu0'],sub(mul(z,z),z)),mul(c['mu1'],mul(z,delta)),mul(c['mu4'],cx),mul(c['mu5'],ct)])
    row=mul(c['nu0'],add(total,c['lam']))
    score=mul(c['nu1'],sub(add(mul(k(2**shift),s),r),k(2**(shift-1))))
    return sumv([mul(q0,zero),mul(q1,row),mul(q2,score)])
def main():
    start=time.monotonic();checks=Counter();fixtures=json.loads((E/'fixtures.json').read_text())
    combos=set()
    for f in fixtures:
        n,span,shift=f['n'],f['span'],f['shift'];tabs=f['tables'];c={a:tuple(v) for a,v in f['constants'].items()};prefix=[]
        assert len(tabs)==15 and len(f['points'][1])==span
        combos.add((shift,n,span,f['mode']))
        for g,point in enumerate(f['points']):
            expected=[eq(point,[(b,0) for b in bits(i,n)[:len(point)]]) for i in range(1<<n)]
            assert expected==list(map(tuple,tabs[g]));checks['original_Eq_values']+=len(expected)
        for ix in [9,10]:
            for i in range(1<<n):
                assert tabs[ix][i]==tabs[ix][(i>>(n-span))<<(n-span)];checks['row_slice_values']+=1
        # The native hosted SC_RS coefficient is nu0*(|S|/|Ht|).
        # Sum the lifted row host independently and check that multiplicity.
        lhs=Z
        for i in range(1<<n):lhs=add(lhs,mul(tabs[1][i],mul(c['nu0'],add(tabs[10][i],c['lam']))))
        row_values=[tabs[10][i<<(n-span)] for i in range(1<<span)]
        rhs=mul(k(1<<(n-span)),sumv(mul(eq(f['points'][1],[k(b) for b in bits(i,span)]),mul(c['nu0'],add(v,c['lam']))) for i,v in enumerate(row_values)))
        assert lhs==rhs;checks['hosted_row_multiplicity']+=1
        for j,round_values in enumerate(f['rounds']):
            for t in range(5):
                total=Z
                for tail in range(1<<(n-j-1)):
                    point=prefix+[k(t)]+[k(b) for b in bits(tail,n-j-1)]
                    total=add(total,native_poly([mle(tab,point) for tab in tabs],c,shift))
                assert total==tuple(round_values[t]),(shift,n,span,j,t);checks['round_values']+=1
            prefix.append(tuple(f['challenges'][j]))
        finals=[mle(t,prefix) for t in tabs]
        assert finals==list(map(tuple,f['finals']));checks['ordered_finals']+=len(finals)
        checks['fixtures']+=1
    assert len(combos)==160 and all((s,n,h,m) in combos for s in range(1,9) for n in range(4) for h in range(n+1) for m in ['full','boolean'])
    # Exhaustive integer membership: both remainder byte checks exactly enforce 0<=r<2^sh.
    for shift in range(1,9):
        coef=2**(8-shift)
        for rem in range(-1,257):
            actual=(0<=rem<=255 and 0<=coef*rem<=255)
            assert actual==(0<=rem<2**shift);checks['remainder_membership_values']+=1
        # Biased signed remainder reconstructs every small host score exactly.
        for raw in range(-1024,1025):
            rounded=(raw+2**(shift-1))//2**shift
            biased=raw-rounded*2**shift+2**(shift-1)
            assert 0<=biased<2**shift and raw==rounded*2**shift+biased-2**(shift-1)
            checks['requantization_host_values']+=1
    for s8 in range(-129,130):
        assert (0<=127+s8<=255 and 0<=127-s8<=255)==(-127<=s8<=127);checks['symmetric_membership_values']+=1
    controls=json.loads((E/'negative-controls.json').read_text())
    assert len(controls)==54 and all(c['expected']!=c['mutated'] for c in controls)
    checks['recorded_negative_controls_distinct']+=len(controls)
    # New older Harvey2012/2013 lazy butterfly Alg3 needs p<2^64/4.
    # Native Goldilocks does not meet that premise. A literal 64-bit add
    # loses a carry even for two canonical inputs; retain as rejection only.
    beta=1<<64
    assert not P<beta//4 and (2**61-1)<beta//4
    x=P-1;y=P-1
    assert ((x+y)%(1<<64))%P!=(x+y)%P
    checks['older_lazy_NTT_premise_controls']+=3
    costs=json.loads((E/'costs.json').read_text())
    assert len(costs)==8 and all(x['per_bracket_api_counts']==costs[0]['per_bracket_api_counts'] for x in costs)
    checks['calibration_invariant_bracket_census']+=8
    for pin in json.loads((E/'native-pins.json').read_text()):
        assert hashlib.sha256((E/'native'/Path(pin['path']).name).read_bytes()).hexdigest()==pin['sha256'];checks['source_pins']+=1
    r=dict(status='PASS',checks=dict(checks),total_checks=sum(checks.values()),wall_s=time.monotonic()-start,
           scope='Independent ungrouped source equations replay every saved round and terminal, original Eq and row slices; exhaustive small integer lookup/host identities. Negative controls only audit saved inequality, not mutation execution. No native cryptographic verifier or privacy theorem.')
    (E/'audit-result.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
if __name__=='__main__':main()

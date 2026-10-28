"""Authored scalar specialization of the prior paired derived-table model.

Only existing BASE && raw && !FOLD round-zero eligibility may select this.
mu, prepared pad coefficients and derived results REMAIN extension-valued.
Counts represent source primitive calls, not compiled instructions/timing.
"""
from affine import Z, pair

def component(o,a,p,difference):
    # A operands are scalars by the existing BASE contract.
    a=[v[0] for v in a]
    f0=o.gs(0,o.gm(a[6],p['kh']))
    if not difference:f0=o.ga(f0,p['kh']//2)
    f0=o.gs(o.gs(f0,a[9]),o.gm(a[10],256))
    f1=a[3] if difference else o.ga(a[3],32768)
    f1=o.gs(o.gs(f1,a[4]),o.gm(a[5],256))
    fh=a[6] if difference else o.ga(a[6],32768)
    fh=o.gs(o.gs(fh,a[7]),o.gm(a[8],256))
    return o.a(o.a(o.base(p['mu'][0],f0),o.base(p['mu'][1],f1)),o.base(p['mu'][2],fh))

def derived(o,lo,delta,p,supp,prepared,base):
    if not base:
        return pair(o,lo,delta,p,supp,'paired',prepared)
    out=[(component(o,lo,p,False),component(o,delta,p,True))]
    # Logical scalar operand reads after dead-code elimination; coefficients
    # and derived/shared/global stores still contain BOTH coordinates.
    reads=8*16
    if supp:
        v=Z;d=Z
        for j,w in enumerate(prepared):
            if w==Z:continue  # public descriptor coefficient only
            v=o.a(v,o.base(w,lo[j][0]))
            d=o.a(d,o.base(w,delta[j][0]))
            reads+=16
        out.append((v,d))
    return out,reads

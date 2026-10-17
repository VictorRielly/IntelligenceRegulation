"""Independent expanded-monomial SC_SZC equations, tuple-field coefficients.

No calls to source_port.bracket. Expansion uses the declared mathematical
clauses and separately constructs paired/single denominator identities.
"""
import full_oracle as o
from field import F


class Poly:
    def __init__(self, terms): self.terms=terms
    @staticmethod
    def scalar(v): return Poly({():v if isinstance(v,tuple) else (v % o.P,0)})
    @staticmethod
    def var(i): return Poly({(i,):o.O})
    def __add__(self, other):
        if not isinstance(other,Poly): other=Poly.scalar(other)
        result=dict(self.terms)
        for mon,coef in other.terms.items(): result[mon]=o.add(result.get(mon,o.Z),coef)
        return Poly({m:c for m,c in result.items() if c != o.Z})
    __radd__=__add__
    def __neg__(self): return Poly({m:o.neg(c) for m,c in self.terms.items()})
    def __sub__(self, other):
        if not isinstance(other,Poly): other=Poly.scalar(other)
        return self+-other
    def __rsub__(self, other): return -self+other
    def __mul__(self, other):
        if not isinstance(other,Poly): other=Poly.scalar(other)
        out={}
        for a,ca in self.terms.items():
            for b,cb in other.terms.items():
                m=tuple(sorted(a+b)); out[m]=o.add(out.get(m,o.Z),o.mul(ca,cb))
        return Poly({m:c for m,c in out.items() if c != o.Z})
    __rmul__=__mul__


def expanded(cfg, const):
    ix=cfg['index']; x=lambda name: Poly.var(ix[name])
    c=lambda name: Poly.scalar(o.tup(const[name]))
    gate_s=x('gs') if cfg['padded'] else Poly.scalar(1)
    gate_ht=x('ght') if cfg['padded'] else Poly.scalar(1)
    limb=lambda name,count: sum((256**j*x(name+str(j)) for j in range(count)),Poly.scalar(0))
    sr,sg,pl=limb('sr',cfg['ls']),limb('sg',cfg['ls']),limb('pl',cfg['lp'])
    # Expand delta/c1/cx rather than using the literal port's intermediate.
    z,mask,s8,e,p,total,mx,hx=(x(n) for n in ('zsel','mask','s8','e','p','sum','mx','hx'))
    clauses=[z*z-z, z*mx-z*mask*s8-127*z*mask+127*z,
             512*mask*e-p*total-sr, sg+sr+1-total, p-pl]
    exp_rel=c('alpha')*hx-hx*mx+hx*mask*s8+127*hx*mask-127*hx-c('beta')*hx*e-c('gexp')*hx-1
    helper=Poly.scalar(0); denominators=[]
    for i,coef,cst in cfg['lookups']:
        denominators.append(c('alpha')-c('gu8')-cst-coef*Poly.var(i))
    for j in range(cfg['helpers']):
        a=denominators[2*j]; h=x('h'+str(j))
        if 2*j+1<len(denominators):
            b=denominators[2*j+1]; rel=h*(a*b)-a-b
        else: rel=h*a-1
        helper += c('mu'+str(5+j))*rel
    padding=Poly.scalar(0)
    if cfg['padded']:
        planes=[(gate_ht,[ix['mx'],ix['sum']]),(gate_s,cfg['splanes'])]
        weight=o.O
        for support, indices in planes:
            inside=Poly.scalar(0)
            for i in indices:
                inside += Poly.scalar(weight)*Poly.var(i)
                weight=o.mul(weight,o.tup(const['zeta']))
            padding += (1-support)*inside
        padding=c('mupad')*padding
    zero=helper+c('mu'+str(5+cfg['helpers']))*exp_rel+padding
    zero += gate_s*sum((c('mu'+str(j))*clause for j,clause in enumerate(clauses)),Poly.scalar(0))
    row=c('nu0')*gate_ht*(total+c('lam'))
    score=c('nu1')*gate_s*(64*s8+x('rsl')-32)
    return [[(F(*coef),mon) for mon,coef in sorted(poly.terms.items())] for poly in (zero,row,score)]

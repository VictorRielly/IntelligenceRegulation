"""Current dictionary SC_SZC equations; no dictionary/check coverage removed."""
from collections import Counter
from field_support import F
from source_port import V
from polynomial_ir import Poly
import oracle as o

NAMES=['eq0','eq1','eq2','mask','s8','rsl','zsel','e','p','mx','sum','h0','h1','hx','ht']
def config():return dict(names=NAMES,index={n:i for i,n in enumerate(NAMES)},padded=False,helpers=2)

def bracket(group,values,cfg,const,mutation=None):
    cc=Counter();v=[V(x,cc) for x in values];ix=cfg['index']
    at=lambda n:v[ix[n]];c=lambda n:V(const[n],cc);k=lambda n:V(F(n),cc)
    if group==1:return c('nu0').mul(k(1)).mul(at('sum').add(c('lam'))).value,cc
    if group==2:
        host=at('s8').mul_base(64).add(at('rsl')).sub(k(32))
        return c('nu1').mul(k(1)).mul(host).value,cc
    assert group==0
    mask,s8,z,e,p,total=(at(n) for n in ['mask','s8','zsel','e','p','sum'])
    delta=at('mx').sub(mask.mul(s8.add(k(127)))).add(k(127))
    c0=z.mul(z).sub(z);c1=z.mul(delta)
    cx=at('hx').mul(c('alpha').sub(delta.add(c('beta').mul(e)).add(c('gexp')))).sub(k(1))
    key=k(0) if mutation=='drop_key' else total
    me=e if mutation=='drop_mask_in_tuple' else mask.mul(e)
    # Native beta2 is prepared at definition; source-level operation counters
    # charge its one setup multiplication separately from per-row evaluation.
    beta2=V(const['beta']*const['beta'],cc)
    ct=at('ht').mul(c('alpha').sub(c('gdd').add(key).add(c('beta').mul(me)).add(beta2.mul(p)))).sub(k(1))
    clauses=c('mu0').mul(c0).add(c('mu1').mul(c1));helper=k(0)
    lookups=[('s8',1,127),('s8',-1,127),('rsl',1,0),('rsl',4,0)]
    def den(item):
        name,coef,offset=item
        return c('alpha').sub(V(F(offset)+const['gu8'],cc).add(at(name).mul_base(coef)))
    for j in range(2):
        a,b=den(lookups[2*j]),den(lookups[2*j+1]);h=at('h'+str(j))
        helper=helper.add(c('mu'+str(j+2)).mul(h.mul(a).mul(b).sub(a.add(b))))
    out=helper.add(c('mu4').mul(cx)).add(c('mu5').mul(ct)).add(k(1).mul(clauses))
    return out.value,cc

def expanded(cfg,const,mutation=None):
    # Independent power-basis equations, schoolbook tuple-field expansion.
    x=lambda n:Poly.var(cfg['index'][n]);c=lambda n:Poly.scalar(o.tup(const[n]))
    m,s,z,e,p,mx,total,hx,ht=(x(n) for n in ['mask','s8','zsel','e','p','mx','sum','hx','ht'])
    delta=mx-m*s-127*m+127
    exp=c('alpha')*hx-hx*mx+hx*m*s+127*hx*m-127*hx-c('beta')*hx*e-c('gexp')*hx-1
    key=Poly.scalar(0) if mutation=='drop_key' else total
    me=e if mutation=='drop_mask_in_tuple' else m*e
    dictionary=ht*c('alpha')-ht*c('gdd')-ht*key-ht*c('beta')*me-ht*c('beta')*c('beta')*p-1
    ds=[c('alpha')-c('gu8')-127-s,c('alpha')-c('gu8')-127+s,c('alpha')-c('gu8')-x('rsl'),c('alpha')-c('gu8')-4*x('rsl')]
    helper=sum((c('mu'+str(j+2))*(x('h'+str(j))*ds[2*j]*ds[2*j+1]-ds[2*j]-ds[2*j+1]) for j in range(2)),Poly.scalar(0))
    zero=helper+c('mu4')*exp+c('mu5')*dictionary+c('mu0')*(z*z-z)+c('mu1')*z*delta
    row=c('nu0')*(total+c('lam'));score=c('nu1')*(64*s+x('rsl')-32)
    return [[(F(*coef),mon) for mon,coef in sorted(poly.terms.items())] for poly in (zero,row,score)]

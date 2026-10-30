"""Independent expanded Fp2 polynomial and original-cube MLE reference.

No import of the candidate field, relation, fold, interpolation or recovery.
"""
P=2**64-2**32+1
Z=(0,0);O=(1,0)
def add(a,b):return ((a[0]+b[0])%P,(a[1]+b[1])%P)
def neg(a):return (-a[0]%P,-a[1]%P)
def sub(a,b):return add(a,neg(b))
def mul(a,b):
    out=[0,0,0]
    for i in range(2):
        for j in range(2):out[i+j]+=a[i]*b[j]
    return ((out[0]+7*out[2])%P,out[1]%P)
def bits(i,n):return [(i>>(n-1-k))&1 for k in range(n)]
def eq(w,x):
    v=O
    for a,b in zip(w,x):v=mul(v,add(mul(a,b),mul(sub(O,a),sub(O,b))))
    return v
def mle(table,x):
    total=Z
    for i,a in enumerate(table):
        weight=O
        for b,q in zip(bits(i,len(x)),x):weight=mul(weight,q if b else sub(O,q))
        total=add(total,mul(tuple(a),weight))
    return total

class Poly:
    def __init__(self,terms):self.terms={k:v for k,v in terms.items() if v!=Z}
    @classmethod
    def coerce(cls,v):
        if isinstance(v,cls):return v
        return cls({():v if isinstance(v,tuple) else (v%P,0)})
    def __add__(self,v):
        terms=dict(self.terms)
        for k,a in self.coerce(v).terms.items():terms[k]=add(terms.get(k,Z),a)
        return Poly(terms)
    __radd__=__add__
    def __neg__(self):return Poly({k:neg(a) for k,a in self.terms.items()})
    def __sub__(self,v):return self+-self.coerce(v)
    def __rsub__(self,v):return self.coerce(v)+-self
    def __mul__(self,v):
        terms={}
        for ka,a in self.terms.items():
            for kb,b in self.coerce(v).terms.items():
                k=tuple(sorted(ka+kb));terms[k]=add(terms.get(k,Z),mul(a,b))
        return Poly(terms)
    __rmul__=__mul__
    def at(self,values):
        total=Z
        for indices,coefficient in self.terms.items():
            term=coefficient
            for i in indices:term=mul(term,values[i])
            total=add(total,term)
        return total

def brackets(constants,shift,mutation=None):
    c={k:Poly.coerce(tuple(v)) for k,v in constants.items()}
    q=[Poly({(i,):O}) for i in range(18)]
    _,_,_,mask,score,r0,r1,r2,z,e,p,mx,total,h0,h1,h2,hx,ht=q
    alpha,beta,gu8=c['alpha'],c['beta'],c['gu8']
    delta=mx-mask*score-127*mask+127
    den=[alpha-gu8-127-score,alpha-gu8-127+score,
         alpha-gu8-r0,alpha-gu8-r1,alpha-gu8-r2,
         alpha-gu8-(2**(24-shift))*r2]
    if mutation=='wrong_top_range':den[5]=alpha-gu8-2*r2
    if mutation=='swap_lookup':den[1],den[2]=den[2],den[1]
    helper=Poly({})
    for j,h in enumerate([h0,h1,h2]):
        if mutation=='drop_helper2' and j==2:continue
        helper+=c['mu'+str(j+2)]*(h*den[2*j]*den[2*j+1]-den[2*j]-den[2*j+1])
    key=0 if mutation=='drop_tuple_key' else total
    tuple_e=e if mutation=='drop_tuple_mask' else mask*e
    cx=hx*(alpha-delta-beta*e-c['gexp'])-1
    ct=ht*(alpha-c['gdd']-key-beta*tuple_e-beta*beta*p)-1
    first=helper+c['mu5']*cx+c['mu6']*ct+c['mu0']*(z*z-z)+c['mu1']*z*delta
    rema=r0+256*r1+65536*r2
    if mutation=='drop_high_limb':rema=r0+256*r1
    if mutation=='drop_middle_limb':rema=r0+65536*r2
    sh=shift-12 if mutation=='legacy_shift' else shift
    host=c['nu1']*((2**sh)*score+rema-2**(sh-1))
    second=c['nu0']*(total+c['lam'])
    return [first,second,host]

def polynomial(constants,shift,mutation=None):
    bs=brackets(constants,shift,mutation)
    order=[0,2,1] if mutation=='swap_eq' else [0,1,2]
    return sum((Poly({(i,):O})*b for i,b in zip(order,bs)),Poly({}))
def direct_round(tables,poly,prefix,t,n):
    out=Z
    for tail in range(1<<(n-len(prefix)-1)):
        x=prefix+[(t,0)]+[(b,0) for b in bits(tail,n-len(prefix)-1)]
        out=add(out,poly.at([mle(a,x) for a in tables]))
    return out

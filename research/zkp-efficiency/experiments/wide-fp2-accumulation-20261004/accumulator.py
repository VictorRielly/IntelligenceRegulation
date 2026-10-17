"""Fixed-width models, not native implementations or performance benchmarks."""
from collections import Counter
from field_support import F, P

B=1<<64; MASK=B-1; EPS=(1<<32)-1; MAX192=(1<<192)-1
# The mixed cross accumulator receives two maximal canonical products per term.
SAFE_TERMS=MAX192//(2*(P-1)**2)

def reduce128(x):
    if not 0<=x<(1<<128): raise OverflowError('u128 input')
    lo=x&MASK; hi=x>>64; upper=hi>>32; lower=hi&EPS
    borrow=lo<upper; t0=(lo-upper)&MASK
    if borrow: t0=(t0-EPS)&MASK
    t1=lower*EPS; carry=t0+t1>=B; r=(t0+t1)&MASK
    if carry: r=(r+EPS)&MASK
    return r-P if r>=P else r

def addfp(a,b):
    carry=a+b>=B; r=(a+b)&MASK
    if carry: r=(r+EPS)&MASK
    return r-P if r>=P else r

def subfp(a,b):
    r=(a-b)&MASK
    return (r-EPS)&MASK if a<b else r

class U192:
    __slots__=('limbs','counts')
    def __init__(self,counts=None):
        self.limbs=[0,0,0]; self.counts=counts if counts is not None else Counter()
    def add128(self,x):
        if not 0<=x<(1<<128): raise OverflowError('product exceeds u128')
        lo,mid,hi=self.limbs
        s=lo+(x&MASK); c=s>>64; lo=s&MASK
        s=mid+(x>>64)+c; c=s>>64; mid=s&MASK
        hi+=c
        if hi>=B: raise OverflowError('u192 accumulation overflow')
        self.counts['carry_chains']+=1
        self.counts['limb_adds']+=4 # lo+x0; mid+x1; mid+carry; hi+carry
        self.counts['carry_events']+=int(lo<(x&MASK))+c
        self.limbs=[lo,mid,hi]
    def reduce(self):
        lo,mid,hi=self.limbs
        if any(not 0<=x<B for x in self.limbs): raise ValueError('limb bounds')
        # B = 2^32-1 and B^2 = -2^32 modulo p. Both arguments fit u128.
        self.counts['reduce128']+=2; self.counts['reducer_limb_mul']+=1
        self.counts['field_subs']+=1
        return subfp(reduce128(lo+mid*EPS),reduce128(hi<<32))

def canonical(v):
    if not isinstance(v,F) or not (0<=v.a<P and 0<=v.b<P):
        raise ValueError('canonical Fp2 precondition')

class WideDot:
    """Three u192 sums: ac, bd, ad+bc; flush before exceeding public limit."""
    def __init__(self,chunk=1024):
        if not isinstance(chunk,int) or not 1<=chunk<=SAFE_TERMS: raise ValueError('unsafe chunk')
        self.chunk=chunk; self.counts=Counter(); self.n=0; self.total=F(); self.done=False
        self.parts=[U192(self.counts) for _ in range(3)]
    def push(self,x,y):
        if self.done: raise ValueError('push after finish')
        canonical(x); canonical(y)
        for dst,product in ((0,x.a*y.a),(1,x.b*y.b),(2,x.a*y.b),(2,x.b*y.a)):
            self.parts[dst].add128(product)
        self.counts['variable_products']+=4; self.counts['terms']+=1; self.n+=1
        if self.n==self.chunk: self.flush()
    def flush(self):
        if not self.n: return
        ac,bd,cross=[a.reduce() for a in self.parts]
        nr=reduce128(bd*7); self.counts['reduce128']+=1
        self.counts['constant_products']+=1; self.counts['field_adds']+=3
        self.total=F(addfp(self.total.a,addfp(ac,nr)),addfp(self.total.b,cross))
        self.parts=[U192(self.counts) for _ in range(3)]; self.n=0; self.counts['flushes']+=1
    def finish(self):
        if self.done: raise ValueError('double finish')
        self.flush(); self.done=True; return self.total

class FusedDot:
    """Same five reductions/term, replacing modular additions with safe u128 adds."""
    def __init__(self,chunk=1024):
        self.total=F(); self.counts=Counter(); self.done=False
    def push(self,x,y):
        if self.done: raise ValueError('push after finish')
        canonical(x); canonical(y)
        a=reduce128(self.total.a+x.a*y.a)
        bd=reduce128(x.b*y.b)
        a=reduce128(a+7*bd)
        b=reduce128(self.total.b+x.a*y.b)
        b=reduce128(b+x.b*y.a)
        self.total=F(a,b)
        self.counts.update(terms=1,variable_products=4,constant_products=1,reduce128=5,u128_adds=4)
    def finish(self):
        if self.done: raise ValueError('double finish')
        self.done=True; return self.total

def dot(xs,ys,kind=WideDot,chunk=1024):
    if len(xs)!=len(ys): raise ValueError('length mismatch')
    d=kind(chunk)
    for x,y in zip(xs,ys): d.push(x,y)
    return d.finish(),d.counts

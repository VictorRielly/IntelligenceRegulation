"""Authored source-level primitive model, NOT compiled CUDA timing.

Goldilocks canonical modular arithmetic. mul follows fz_mulk's actual calls;
generic_mul follows f2_mul. Counts are source calls before compiler lowering.
"""
from collections import Counter
P=2**64-2**32+1
Z=(0,0)

class Ops:
    def __init__(self): self.c=Counter()
    def ga(self,a,b): self.c['base_add']+=1; return (a+b)%P
    def gs(self,a,b): self.c['base_sub']+=1; return (a-b)%P
    def gm(self,a,b): self.c['base_mul']+=1; return (a*b)%P
    def a(self,x,y): return self.ga(x[0],y[0]),self.ga(x[1],y[1])
    def s(self,x,y): return self.gs(x[0],y[0]),self.gs(x[1],y[1])
    def neg(self,x): return self.s(Z,x)
    def base(self,x,b): return self.gm(x[0],b),self.gm(x[1],b)
    def m(self,x,y):
        ac=self.gm(x[0],y[0]);bd=self.gm(x[1],y[1])
        m=self.gm(self.ga(*x),self.ga(*y))
        bd2=self.ga(bd,bd);bd4=self.ga(bd2,bd2);bd8=self.ga(bd4,bd4)
        return self.ga(ac,self.gs(bd8,bd)),self.gs(self.gs(m,ac),bd)
    def generic_mul(self,x,y):
        ac=self.gm(x[0],y[0]);bd=self.gm(x[1],y[1])
        ad=self.gm(x[0],y[1]);bc=self.gm(x[1],y[0])
        return self.ga(ac,self.gm(bd,7)),self.ga(ad,bc)
    def fold(self,x,y,r,generic=False):
        return self.a(x,(self.generic_mul if generic else self.m)(r,self.s(y,x)))

def gl(o,a,p,linear=False):
    f0=o.neg(o.base(a[6],p['kh']))
    if not linear:f0=o.a(f0,(p['kh']//2,0))
    f0=o.s(o.s(f0,a[9]),o.base(a[10],256))
    f1=a[3] if linear else o.a(a[3],(32768,0))
    f1=o.s(o.s(f1,a[4]),o.base(a[5],256))
    fh=a[6] if linear else o.a(a[6],(32768,0))
    fh=o.s(o.s(fh,a[7]),o.base(a[8],256))
    return o.a(o.a(o.m(p['mu'][0],f0),o.m(p['mu'][1],f1)),o.m(p['mu'][2],fh))

def pl(o,a,p,prepared=None):
    out=Z
    for j,w in enumerate(p['pad'] if prepared is None else prepared):
        # Public descriptor support, never a predicate on private a[j].
        if w==Z:continue
        out=o.a(out,o.m(w,a[j]))
    return o.m(p['mupad'],out) if prepared is None else out

def prepare(o,p):
    return [o.m(p['mupad'],w) if w!=Z else Z for w in p['pad']]

def pair(o,lo,delta,p,supp,mode,prepared=None):
    """Return derived (value,difference) pairs and logical shared reads.

    literal is the active raw round0: evaluate at lo and reconstructed hi.
    paired is proposed: affine(lo), homogeneous(delta), preweighted pad.
    Reads assume the compiler eliminates unused sd loads for hi=false;
    physical transactions/cache effects are unmeasured.
    """
    reads=0;results=[]
    for which in range(1+supp):
        indices=[6,9,10,3,4,5,7,8] if which==0 else [j for j,w in enumerate(p['pad']) if w!=Z]
        a=[Z]*11;b=[Z]*11
        for j in indices:
            a[j]=lo[j]
            b[j]=o.a(lo[j],delta[j]) if mode=='literal' else delta[j]
        reads+=len(indices)*(48 if mode=='literal' else 32)
        if which==0:
            v=gl(o,a,p);w=gl(o,b,p,linear=mode!='literal')
        else:
            v=pl(o,a,p,None if mode=='literal' else prepared)
            w=pl(o,b,p,None if mode=='literal' else prepared)
        results.append((v,o.s(w,v) if mode=='literal' else w))
    return results,reads

def primitive_costs(p,supp,mode):
    o=Ops();a=[(j+1,j+2) for j in range(11)];d=[(j+3,j+4) for j in range(11)]
    prep=Ops();q=prepare(prep,p) if mode!='literal' and supp else None
    _,reads=pair(o,a,d,p,supp,mode,q)
    return dict(o.c),reads,dict(prep.c)

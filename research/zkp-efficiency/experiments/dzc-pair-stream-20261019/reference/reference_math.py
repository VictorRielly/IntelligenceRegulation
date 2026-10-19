"""Independent D equations, with arbitrary-precision Fp2 arithmetic."""
P=2**64-2**32+1
Z=(0,0); O=(1,0)
def add(a,b): return ((a[0]+b[0])%P,(a[1]+b[1])%P)
def sub(a,b): return ((a[0]-b[0])%P,(a[1]-b[1])%P)
def mul(a,b): return ((a[0]*b[0]+7*a[1]*b[1])%P,(a[0]*b[1]+a[1]*b[0])%P)
def scale(a,b): return (a[0]*b%P,a[1]*b%P)
def sm(xs):
    a=Z
    for x in xs:a=add(a,x)
    return a
def maps(ln):
    # Synthetic binding: native toy A ids map to identical table indices.
    # Extra limbs are appended, not claimed to be a registered native shape.
    return [list(range(a,a+4))+list(range(46+(i*(ln-4)),46+((i+1)*(ln-4)))) for i,a in enumerate([12,16,28,32])]
def clauses(v,mu,c,ln):
    num,numm,dv,den=c[:4]
    nr,ns,mr,ms=[sm(scale(v[j],pow(256,k,P)) for k,j in enumerate(ix)) for ix in maps(ln)]
    x,y,ao,x1,ym,z,x2,d,dm=[v[i] for i in [8,11,20,24,27,36,37,43,44]]
    limb=lambda i:add(v[i],scale(v[i+1],256))
    cs=[sub(sub(add(scale(mul(v[3],x),num),scale(d,dv)),scale(mul(d,y),den)),nr),
        sub(add(add(ns,nr),O),scale(d,den)),sub(add(x,(32768,0)),limb(9)),
        sub(add(ao,(32768,0)),limb(21)),sub(add(x1,(32768,0)),limb(25)),sub(sub(x1,x),ao),
        sub(sub(add(scale(mul(v[4],x1),numm),scale(dm,dv)),scale(mul(dm,ym),den)),mr),
        sub(add(add(ms,mr),O),scale(dm,den)),sub(add(x2,(32768,0)),limb(38)),sub(sub(x2,x1),z),sub(add(z,(32768,0)),limb(40))]
    return sm(mul(m,q) for m,q in zip(mu,cs))
def fold(tabs,r):
    h=len(tabs[0])//2
    return [[add(t[i],mul(r,sub(t[i+h],t[i]))) for i in range(h)] for t in tabs]
def cube(tab,rs):
    return sm(mul(a,weight(j,rs)) for j,a in enumerate(tab))
def weight(j,rs):
    a=O
    for k,r in enumerate(rs):a=mul(a,r if (j>>(len(rs)-k-1))&1 else sub(O,r))
    return a

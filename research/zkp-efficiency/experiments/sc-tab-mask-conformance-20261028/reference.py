"""Independent tuple/schoolbook Fp2 original-cube oracle. Never folds."""
P=2**64-2**32+1
Z=(0,0); O=(1,0)
def add(a,b): return ((a[0]+b[0])%P,(a[1]+b[1])%P)
def neg(a): return ((-a[0])%P,(-a[1])%P)
def sub(a,b): return add(a,neg(b))
def mul(a,b):
    c=[0,0,0]
    for i in range(2):
        for j in range(2): c[i+j]+=a[i]*b[j]
    return ((c[0]+7*c[2])%P,c[1]%P)
def tup(x): return (x.a,x.b)
def basis(index,point):
    w=O
    for j,r in enumerate(point):
        w=mul(w,r if (index>>(len(point)-1-j))&1 else sub(O,r))
    return w
def restrict(original,n,prefix):
    """Direct sum over original leading Boolean coordinates, not prior state."""
    size=1<<(n-len(prefix)); out=[Z]*size
    for head in range(1<<len(prefix)):
        w=basis(head,prefix)
        if w==Z: continue
        for tail in range(size): out[tail]=add(out[tail],mul(w,original[head*size+tail]))
    return out
def mle(original,point):
    assert len(original)==1<<len(point)
    out=Z
    for i,v in enumerate(original): out=add(out,mul(v,basis(i,point)))
    return out
def encode(kind,raw,beta,gamma):
    # Integer coordinates, separate from candidate field class/conversions.
    return [((i+gamma[0]+(0 if kind=='u8' else beta[0]*raw[i]))%P,
             (gamma[1]+(0 if kind=='u8' else beta[1]*raw[i]))%P) for i in range(256)]
def poly(v,alpha,mu,zeta,padded):
    # Expanded monomials, rather than candidate factored residual expressions.
    out=Z
    for k in range(3):
        eqh=mul(v[0],v[2+3*k]); m=mul(v[0],v[1+3*k])
        term=sub(sub(mul(alpha,eqh),mul(eqh,v[3+3*k])),m)
        out=add(out,mul(mu[k],term))
    if padded:
        power=O
        for idx in (1,4,7,2,5,8):
            eqv=mul(v[0],v[idx])
            out=add(out,mul(mul(mu[3],power),sub(eqv,mul(eqv,v[10]))))
            power=mul(power,zeta)
    return out
def round_samples(original,n,prefix,alpha,mu,zeta,padded):
    tables=[restrict(t,n,prefix) for t in original];half=len(tables[0])//2
    sums=[Z]*4
    for tail in range(half):
        for x in range(4):
            row=[add(mul((1-x,0),t[tail]),mul((x,0),t[tail+half])) for t in tables]
            sums[x]=add(sums[x],poly(row,alpha,mu,zeta,padded))
    return sums

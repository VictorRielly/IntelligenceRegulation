"""Independent arbitrary-integer Fp2 semantic reference; no captured code."""
P=2**64-2**32+1
Z=(0,0)
O=(1,0)
def add(a,b): return ((a[0]+b[0])%P,(a[1]+b[1])%P)
def sub(a,b): return ((a[0]-b[0])%P,(a[1]-b[1])%P)
def mul(a,b): return ((a[0]*b[0]+7*a[1]*b[1])%P,(a[0]*b[1]+a[1]*b[0])%P)
def scale(a,b): return (a[0]*b%P,a[1]*b%P)
def sm(xs):
    z=Z
    for x in xs: z=add(z,x)
    return z
def polynomial(v,s,supp):
    def pair(i): return tuple(s[i:i+2])
    alpha,beta,tag=pair(0),pair(2),pair(4)
    mu=[pair(10+2*i) for i in range(9)]
    gate,rem,act,up,ul,uh,prod,pl,ph,rl,rh=v[3:14]
    den=[sub(alpha,add(pair(30+2*i),scale(v[t],s[48+i])))
         for i,t in enumerate([4,4,7,8,10,11,12,13,13])]
    helper=sm(mul(mu[4+i],sub(mul(v[14+i],mul(den[2*i],den[2*i+1])),add(den[2*i],den[2*i+1]))) for i in range(4))
    helper=add(helper,mul(mu[8],sub(mul(v[18],den[8]),O)))
    activation=sub(mul(v[19],sub(alpha,sm([gate,(128,0),mul(beta,act),tag]))),O)
    clauses=[sub(add(sub(mul(act,up),scale(prod,s[57])),(s[58],0)),add(rl,scale(rh,s[61]))),
             sub(add(up,(32768,0)),add(ul,scale(uh,s[61]))),
             sub(add(prod,(32768,0)),add(pl,scale(ph,s[61])))]
    indicator=v[20] if supp else O
    total=add(helper,mul(mu[3],activation))
    total=add(total,mul(indicator,sm(mul(mu[i],clauses[i]) for i in range(3))))
    if supp:
        weighted=sm(mul(pair(62+2*i),v[3+i]) for i in range(11))
        total=add(total,mul(pair(28),mul(sub(O,indicator),weighted)))
    host=add(mul(mul(pair(6),v[1]),sub(add(scale(gate,s[59]),rem),(s[60],0))),mul(mul(pair(8),v[2]),up))
    return add(mul(v[0],total),mul(indicator,host))
def fold(tables,r):
    h=len(tables[0])//2
    return [[add(t[i],mul(r,sub(t[i+h],t[i]))) for i in range(h)] for t in tables]
def round_values(tables,degree,s,supp):
    h=len(tables[0])//2
    return [sm(polynomial([add(t[i],scale(sub(t[i+h],t[i]),d)) for t in tables],s,supp) for i in range(h)) for d in range(degree+1)]

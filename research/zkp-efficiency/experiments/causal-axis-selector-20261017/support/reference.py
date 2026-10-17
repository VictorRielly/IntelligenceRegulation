"""Independent tuple-field and literal captured-index oracle.

No adapter/generator/source_port imports. Written against pinned argument.rs
and old Szc body in s35_tests.rs. Does not execute native Rust or prove ZK.
"""
P=18446744069414584321
Z=(0,0);O=(1,0)
def cv(x):return (x.a,x.b) if hasattr(x,'a') else (x%P,0)
def add(x,y):return ((x[0]+y[0])%P,(x[1]+y[1])%P)
def neg(x):return ((-x[0])%P,(-x[1])%P)
def sub(x,y):return add(x,neg(y))
def mul(x,y):
    # Four scalar products, independent of the F implementation's dispatch.
    ac=x[0]*y[0];bd=x[1]*y[1];ad=x[0]*y[1];bc=x[1]*y[0]
    return ((ac+7*bd)%P,(ad+bc)%P)
def scalar(n):return (n%P,0)
def sm(xs):
    a=Z
    for x in xs:a=add(a,x)
    return a


def groups(c,values,params,mutation=None):
    v=[cv(x) for x in values];k={n:cv(x) for n,x in params.items() if n!='lk_cst'}
    def at(i):return v[c.idx[i]]
    def limbs(ix):return sm(mul(scalar(256**j),v[i]) for j,i in enumerate(ix))
    gs=O if c.gs is None else v[c.gs];ght=O if c.ght is None else v[c.ght]
    if mutation=='ht_uses_s':ght=gs
    mask,s,z,e,p,total=v[c.im],at(56),at(58),at(59),at(60),v[c.isum]
    sr=limbs(c.i_sr)
    delta=add(sub(v[c.imx],mul(mask,add(s,scalar(127)))),scalar(127))
    clauses=[sub(mul(z,z),z),mul(z,delta),
             sub(sub(mul(scalar(512),mul(mask,e)),mul(p,total)),sr),
             sub(add(add(limbs(c.i_sg),sr),O),total),sub(p,limbs(c.i_pl))]
    mixed=sm(mul(k['mu'+str(j)],mul(gs,x)) for j,x in enumerate(clauses))
    cx=sub(mul(v[c.ihx],sub(k['alpha'],add(add(delta,mul(k['beta'],e)),k['gexp']))),O)
    helper=Z
    def den(j):
        val=cv(params['lk_cst'][j])
        for i,coef in c.lks[j]:val=add(val,mul(scalar(coef),v[i]))
        return sub(k['alpha'],val)
    for j in range(c.n_help):
        d=den(2*j);h=v[c.h0+j]
        if 2*j+1<len(c.lks):
            d2=den(2*j+1);rel=sub(mul(mul(h,d),d2),add(d,d2))
        else:rel=sub(mul(h,d),O)
        helper=add(helper,mul(k['mu'+str(5+j)],rel))
    pad=Z;power=O
    if c.pad_on:
        for support,planes in [(c.ght,(c.imx,c.isum)),(c.gs,c.splanes)]:
            if support is None:continue
            if mutation=='restart_zeta':power=O
            inner=Z
            for i in planes:
                inner=add(inner,mul(power,v[i]));power=mul(power,k['zeta'])
            pad=add(pad,mul(sub(O,v[support]),inner))
        pad=mul(k['mupad'],pad)
    g0=add(add(add(helper,mul(k['mu'+str(5+c.n_help)],cx)),pad),mixed)
    g1=mul(mul(k['nu0'],ght),add(total,k['lam']))
    g2=mul(mul(k['nu1'],gs),sub(add(mul(scalar(64),s),at(57)),scalar(32)))
    return (g0,g1,g2)


def old_full(c,values,params):
    v=[cv(x) for x in values]
    return sm(mul(v[i],x) for i,x in enumerate(groups(c,values,params)))

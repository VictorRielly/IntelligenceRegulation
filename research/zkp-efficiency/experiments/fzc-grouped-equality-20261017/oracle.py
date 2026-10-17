# Independent arbitrary-integer semantic equation, copied from prior cycle.
P = 2**64 - 2**32 + 1
ZERO, ONE = (0, 0), (1, 0)


def add(a, b): return ((a[0] + b[0]) % P, (a[1] + b[1]) % P)
def sub(a, b): return ((a[0] - b[0]) % P, (a[1] - b[1]) % P)
def mul(a, b): return ((a[0]*b[0] + 7*a[1]*b[1]) % P, (a[0]*b[1] + a[1]*b[0]) % P)
def scale(a, b): return (a[0]*b % P, a[1]*b % P)
def summ(xs):
    a = ZERO
    for x in xs: a = add(a, x)
    return a


def reference(v, hh, gg, pad, nlk, mutant=None):
    """Semantic equation, without calling or translating the Rust closure."""
    eq, eg, eu = v[:3]
    gate, rg, act, up, ul, uh, prod, hl, hi, rl, rh = v[3:14]
    alpha, beta, tag_act, tag_u8 = v[21:25]
    mu, nu = v[25:35], v[35:37]
    supp = v[20] if pad else ONE
    kh, kg = 2**hh, 2**gg
    half_h, half_g = (2**(hh-1) if hh else 0), (2**(gg-1) if gg else 0)
    clauses = [sub(add(sub(mul(act, up), scale(prod, kh)), (half_h, 0)), add(rl, scale(rh, 256))),
               sub(add(up, (32768, 0)), add(ul, scale(uh, 256))),
               sub(add(prod, (32768, 0)), add(hl, scale(hi, 256)))]
    fact = v[14] if mutant == 'wrong helper index' else v[19]
    activation = sub(mul(fact, sub(alpha, summ([gate, (128, 0), mul(beta, act), tag_act]))), ONE)
    if mutant == 'activation incorrectly gated': activation = mul(activation, supp)
    columns = [rg, scale(rg, 2**(8-gg)), ul, uh, hl, hi, rl, rh, scale(rh, 2**(16-hh))][:nlk]
    ds = [sub(alpha, add(tag_u8, z)) for z in columns]
    helpers = []
    for i in range(0, nlk, 2):
        if i+1 < nlk:
            rel = sub(mul(v[14+i//2], mul(ds[i], ds[i+1])), add(ds[i], ds[i+1]))
        else: rel = sub(mul(v[14+i//2], ds[i]), ONE)
        helpers.append(mul(mu[4+i//2], rel))
    hs = summ(helpers)
    if mutant == 'helpers incorrectly gated': hs = mul(supp, hs)
    ps = ZERO
    if pad:
        zeta, power = v[37], ONE
        terms = []
        for z in v[3:14]:
            terms.append(mul(power, z)); power = mul(power, zeta)
        ps = mul(mu[4+(nlk+1)//2], mul(sub(ONE, supp), summ(terms)))
    if mutant == 'pad term dropped': ps = ZERO
    zc = summ([hs, mul(mu[3], activation), ps, mul(supp, summ(mul(mu[i], clauses[i]) for i in range(3)))])
    if mutant == 'whole bracket gated': zc = mul(supp, zc)
    hg = sub(add(scale(gate, kg), rg), (half_g, 0))
    if mutant == 'host half omitted': hg = add(scale(gate, kg), rg)
    host_supp = ONE if mutant == 'host gate omitted' else supp
    out = summ([mul(eq, zc), mul(mul(nu[0], eg), mul(host_supp, hg)), mul(mul(nu[1], eu), mul(host_supp, up))])
    return out


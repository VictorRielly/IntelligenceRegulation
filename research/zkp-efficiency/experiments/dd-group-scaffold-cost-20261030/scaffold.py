"""Locally authored literal grouped scaffold and zero-safe norm batching.

Source-level API counts, not instructions or native timing. No transcript/RNG.
"""
from collections import Counter
from contextlib import contextmanager

P = 2**64 - 2**32 + 1
COUNTS = Counter()
PHASE = 'other'

@contextmanager
def phase(name):
    global PHASE
    old = PHASE
    PHASE = name
    try:
        yield
    finally:
        PHASE = old

def charge(op, n=1):
    COUNTS[PHASE + ':' + op] += n

class F:
    __slots__ = ('a', 'b')
    def __init__(self, a=0, b=0): self.a, self.b = a % P, b % P
    def add(self, y):
        charge('add'); return F(self.a+y.a, self.b+y.b)
    def sub(self, y):
        charge('sub'); return F(self.a-y.a, self.b-y.b)
    def sub_base(self, y):
        charge('sub_base'); return F(self.a-y, self.b)
    def mul(self, y):
        charge('mul'); return F(self.a*y.a+7*self.b*y.b, self.a*y.b+self.b*y.a)
    def mul_base(self, y):
        charge('mul_base'); return F(self.a*y, self.b*y)
    def inv(self):
        charge('inv2')
        z = pow((self.a*self.a-7*self.b*self.b) % P, -1, P)
        return F(self.a*z, -self.b*z)
    def zero(self): return self.a == self.b == 0
    def pair(self): return [self.a, self.b]
    def __eq__(self, y): return isinstance(y, F) and self.a == y.a and self.b == y.b

O, Z = F(1), F()

def interpolate(values, x):
    """Literal mle.rs helper: count public denominator arithmetic too."""
    out = Z
    for i, y in enumerate(values):
        num, den = O, 1
        for j in range(len(values)):
            if i != j:
                num = num.mul(x.sub_base(j))
                den = den * (i-j) % P
                charge('base_mul')
        charge('base_inv')
        out = out.add(y.mul(num).mul_base(pow(den, -1, P)))
    return out

def eq_table(point):
    out = [O]
    for w in reversed(point):
        om = O.sub(w)
        out = [e.mul(om) for e in out] + [e.mul(w) for e in out]
    return out

def inverse_factors(factors, eligible, mode='individual'):
    """Zero factors keep None: explicit bracket evaluation, no new refusal.

    Candidate batches base norms, with existing field.rs batch_inverse's
    literal 3*m multiplication schedule. Singleton keeps original inversion.
    """
    out = [None] * len(factors)
    use = [i for i, f in enumerate(factors) if eligible[i] and not f.zero()]
    if mode == 'individual' or len(use) < 2:
        for i in use: out[i] = factors[i].inv()
        return out
    assert mode == 'batch-norm'
    norms = []
    for i in use:
        f = factors[i]
        norms.append((f.a*f.a - 7*f.b*f.b) % P)
        charge('base_mul', 3); charge('base_sub')
    # u^2=7 is irreducible: nonzero Fp2 inputs have nonzero base norms.
    assert all(norms)
    prefix, acc = [], 1
    for n in norms:
        prefix.append(acc); acc = acc*n % P; charge('base_mul')
    acc = pow(acc, -1, P); charge('base_inv')
    inverses = [None]*len(norms)
    for j in reversed(range(len(norms))):
        inverses[j] = acc*prefix[j] % P
        acc = acc*norms[j] % P
        charge('base_mul', 2)
    for i, inv in zip(use, inverses):
        f = factors[i]; out[i] = F(f.a*inv, -f.b*inv)
        charge('base_mul', 2); charge('base_neg')
    return out

def bracket(g, v, c, shift):
    eq0, eq1, eq2, mask, s, rsl, z, e, p, mx, total, h0, h1, hx, ht = v
    if g == 1: return c['nu0'].mul(O).mul(total.add(c['lam']))
    if g == 2:
        return c['nu1'].mul(O).mul(s.mul_base(2**shift).add(rsl).sub(F(2**(shift-1))))
    delta = mx.sub(mask.mul(s.add(F(127)))).add(F(127))
    c0, c1 = z.mul(z).sub(z), z.mul(delta)
    cx = hx.mul(c['alpha'].sub(delta.add(c['beta'].mul(e)).add(c['gexp']))).sub(O)
    # beta2 is definition setup, shared in both arms, excluded from row counts.
    b2 = F(c['beta'].a*c['beta'].a+7*c['beta'].b*c['beta'].b, 2*c['beta'].a*c['beta'].b)
    ct = ht.mul(c['alpha'].sub(c['gdd'].add(total).add(c['beta'].mul(mask.mul(e))).add(b2.mul(p)))).sub(O)
    clauses = c['mu0'].mul(c0).add(c['mu1'].mul(c1))
    ds = []
    for x, coef, off in [(s,1,127),(s,-1,127),(rsl,1,0),(rsl,2**(8-shift),0)]:
        ds.append(c['alpha'].sub(F(off).add(c['gu8']).add(x.mul_base(coef))))
    helper = Z
    for j, h in enumerate([h0,h1]):
        a,b = ds[2*j:2*j+2]
        helper = helper.add(c['mu'+str(j+2)].mul(h.mul(a).mul(b).sub(a.add(b))))
    return helper.add(c['mu4'].mul(cx)).add(c['mu5'].mul(ct)).add(O.mul(clauses))

class Grouped:
    def __init__(self, fixture, mode):
        self.tables = [[F(*v) for v in t] for t in fixture['tables']]
        self.points = [[F(*v) for v in p] for p in fixture['points']]
        self.const = {k:F(*v) for k,v in fixture['constants'].items()}
        self.n = fixture['n']; self.shift = fixture['shift']; self.mode = mode
        self.prefix = [O]*3; self.claims = [None]*3; self.pending = None
        self.round_records = []

    def round(self, j):
        assert self.pending is None
        rg = []
        with phase('factor'):
            for g, point in enumerate(self.points):
                if j < len(point):
                    w = point[j]
                    factors = [self.prefix[g].mul(O.sub(w).add(w.add(w).sub(O).mul(F(t)))) for t in range(5)]
                else: factors = [self.prefix[g]]*5
                rg.append({'factor':factors})
        with phase('inverse'):
            invs = inverse_factors([r['factor'][1] for r in rg], [x is not None for x in self.claims], self.mode)
        with phase('suffix'):
            for g, point in enumerate(self.points):
                rem = point[min(j+1,len(point)):]; split = len(rem)//2
                rg[g].update(left=eq_table(rem[:split]), right=eq_table(rem[split:]),
                             suffix=len(rem), trailing=self.n-len(point) if rem else 0)
        hs = [[Z]*(d+1) for d in [3,1,1]]
        half = len(self.tables[0])//2
        with phase('scan'):
            for i in range(half):
                cur = [t[i] for t in self.tables]
                dif = [t[i+half].sub(t[i]) for t in self.tables]
                weights = []
                for r in rg:
                    pos = (i >> r['trailing']) & ((1<<r['suffix'])-1)
                    weights.append(r['left'][pos//len(r['right'])].mul(r['right'][pos%len(r['right'])]))
                for t in range(4):
                    for g,d in enumerate([3,1,1]):
                        if t <= d and (t != 1 or invs[g] is None):
                            hs[g][t] = hs[g][t].add(weights[g].mul(bracket(g,cur,self.const,self.shift)))
                    if t != 3: cur = [v.add(d) for v,d in zip(cur,dif)]
        values = []
        with phase('completion'):
            for g, r in enumerate(rg):
                if invs[g] is not None:
                    hs[g][1] = self.claims[g].sub(r['factor'][0].mul(hs[g][0])).mul(invs[g])
                values.append([r['factor'][t].mul(hs[g][t] if t<len(hs[g]) else interpolate(hs[g],F(t))) for t in range(5)])
            out = [Z]*5
            for v in values: out = [a.add(b) for a,b in zip(out,v)]
        self.pending = values
        self.round_records.append({'j':j,'recover':[v is not None for v in invs],
                                   'factors':[r['factor'][1].pair() for r in rg]})
        return out

    def fold(self, j, r):
        assert self.pending is not None
        with phase('claim'):
            for g, point in enumerate(self.points):
                self.claims[g] = interpolate(self.pending[g],r)
                if j < len(point):
                    w = point[j]
                    self.prefix[g] = self.prefix[g].mul(O.sub(w).mul(O.sub(r)).add(w.mul(r)))
        with phase('fold'):
            half = len(self.tables[0])//2
            self.tables = [[a.add(r.mul(b.sub(a))) for a,b in zip(t[:half],t[half:])] for t in self.tables]
        self.pending = None

def interpolation_counts(m):
    return Counter(mul=m*m,sub_base=m*(m-1),base_mul=m*(m-1),
                   base_inv=m,mul_base=m,add=m)

def scalar_counts(n, span, recovery):
    """Independent allocation-free structural counts for the literal scaffold."""
    cc = Counter(); per_round=[]
    for j in range(n):
        row=Counter()
        for length in [n,span,n]:
            if j<length:
                row.update(mul=13,add=11,sub=12)  # factors + prefix update
            rem=max(length-j-1,0);a=rem//2;b=rem-a
            row['mul']+=2*((1<<a)+(1<<b)-2)
            row['sub']+=rem
        mrec=sum(recovery[j]);row['inv2']+=mrec
        row['mul']+=2*mrec;row['sub']+=mrec
        for d in [3,1,1]:
            for _ in range(4-d):row.update(interpolation_counts(d+1))
        row.update(mul=15,add=15)
        for _ in range(3):row.update(interpolation_counts(5))
        cc.update(row);per_round.append(dict(row))
    return cc,per_round

def base_product_count(c):
    """Source field.rs expansion; counts products, no CPU/GPU cost weights."""
    inv_work=(P-2).bit_length()+(P-2).bit_count()
    return (5*c['mul']+2*c['mul_base']+c['base_mul']+
            inv_work*c['base_inv']+(inv_work+5)*c['inv2'])

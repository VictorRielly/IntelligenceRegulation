"""Independent schoolbook quotient-field / original-slot polynomial oracle.

Authored locally. No native code, downloaded implementation, or real data runs.
"""
P = 2**64 - 2**32 + 1

class R:
    __slots__ = ('v',)
    def __init__(self, a=0, b=0):
        self.v = (a % P, b % P)
    @staticmethod
    def co(x):
        return x if isinstance(x, R) else R(x)
    def __add__(self, other):
        y = R.co(other)
        return R(self.v[0]+y.v[0], self.v[1]+y.v[1])
    __radd__ = __add__
    def __neg__(self):
        return R(-self.v[0], -self.v[1])
    def __sub__(self, other):
        return self + -R.co(other)
    def __rsub__(self, other):
        return R.co(other) + -self
    def __mul__(self, other):
        y = R.co(other)
        # Polynomial convolution followed by reduction modulo X^2 - 7.
        cs = [0, 0, 0]
        for i in range(2):
            for j in range(2):
                cs[i+j] += self.v[i]*y.v[j]
        cs[0] += 7*cs[2]
        return R(cs[0], cs[1])
    __rmul__ = __mul__

def poly(v, p, supp):
    """Original SC_FZC closure, without split/derived tables."""
    a = v[3:14]
    den = [p['alpha'] - p['cst'][j] - p['coef'][j]*a[t]
           for j,t in enumerate([1,1,4,5,7,8,9,10,10])]
    helper = R()
    for i in range(4):
        d,e = den[2*i:2*i+2]
        helper += p['mu'][4+i]*(v[14+i]*d*e-d-e)
    helper += p['mu'][8]*(v[18]*den[8]-1)
    fact = v[19]*(p['alpha']-a[0]-128-p['beta']*a[2]-p['gact'])-1
    clauses = [a[2]*a[3]-p['kh']*a[6]-a[9]-256*a[10]+p['kh']//2,
               a[3]+32768-a[4]-256*a[5], a[6]+32768-a[7]-256*a[8]]
    gate = v[20] if supp else R(1)
    z = helper+p['mu'][3]*fact
    for i,f in enumerate(clauses):
        z += p['mu'][i]*gate*f
    if supp:
        z += p['mupad']*(1-gate)*sum((p['pad'][j]*a[j] for j in range(11)),R())
    return v[0]*z + p['nu'][0]*v[1]*gate*(p['kg']*a[0]+a[1]-p['kg']//2) + p['nu'][1]*v[2]*gate*a[3]

def direct_prefix(original, challenges):
    """Explicit Boolean-weight MLE of ORIGINAL values; never in-place folds."""
    n = len(original)
    width = n >> len(challenges)
    out = []
    for i in range(width):
        total = R()
        for b in range(1 << len(challenges)):
            weight = R(1)
            for j,r in enumerate(challenges):
                weight *= r if b & (1 << (len(challenges)-1-j)) else 1-r
            total += weight * R(*original[b*width+i])
        out.append(total)
    return out

def round_values(tables, p, supp, degree):
    half = len(tables[0])//2
    sums = [R() for _ in range(degree+1)]
    for i in range(half):
        for d in range(degree+1):
            v = [(1-d)*t[i]+d*t[i+half] for t in tables]
            sums[d] += poly(v,p,supp)
    return [x.v for x in sums]

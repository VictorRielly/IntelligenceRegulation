"""Locally authored scalar transcription; public weights only, one entry per slot.

No private row, evaluation, pad or commitment is retained. This is not native code.
"""
from dataclasses import dataclass

P = 2**64 - 2**32 + 1
ZERO = (0, 0)
ONE = (1, 0)

def add(x, y): return ((x[0] + y[0]) % P, (x[1] + y[1]) % P)
def sub(x, y): return ((x[0] - y[0]) % P, (x[1] - y[1]) % P)
def mul(x, y):
    ac, bd = x[0]*y[0], x[1]*y[1]
    return ((ac + 7*bd) % P, ((x[0]+x[1])*(y[0]+y[1])-ac-bd) % P)
def base(x, y): return (x[0]*y % P, x[1]*y % P)

def weights(point):
    # Native eq_table_msb: reverse point, then low-half/high-half expansion.
    out = [ONE]
    for r in reversed(point):
        out = [mul(v, sub(ONE, r)) for v in out] + [mul(v, r) for v in out]
    return out

def claim_point(coords, rho):
    return tuple(rho[x] if k == 'rho' else sub(ONE, rho[x]) if k == 'flip'
                 else x for k, x in coords)

@dataclass(frozen=True)
class Site:
    cm: str
    row_log: int
    log: int
    coords: tuple
    source_offset: int
    mask_row: int
    ext_round: int = 0

class TailWeights:
    def __init__(self):
        self.point = None
        self.eq = []
        self.builds = self.hits = self.mul_count = self.max_words = 0

    def get(self, point):
        point = tuple(point)
        if self.point == point:
            self.hits += 1
        else:
            # Release previous vector before construction; one-entry ownership.
            self.eq = []
            self.point = None
            self.eq = weights(point)
            self.point = point
            self.builds += 1
            self.mul_count += 2 * (len(self.eq)-1)
            self.max_words = max(self.max_words, len(self.eq))
        return self.eq

def mask_value(site, rho, data, cache):
    point = claim_point(site.coords, rho)
    logm = min(site.log, site.row_log)
    tail = point[site.log-logm:]
    eq = cache.get(tail)
    n = 1 << site.row_log
    c0 = site.source_offset % n if site.log < site.row_log else 0
    a, b = ZERO, ZERO
    for j, e in enumerate(eq):
        a = add(a, base(e, data[site.mask_row*n+c0+j]))
        b = add(b, base(e, data[(site.mask_row+1)*n+c0+j]))
    return add(a, (7*b[1] % P, b[0]))

def extension_terms(sites, rho, data, originals, es, cache=None):
    # Mirrors original iteration order and ext_round branches. Reuses no value.
    cache = TailWeights() if cache is None else cache
    cur = list(originals)
    for m, e in enumerate(es):
        for i, site in enumerate(sites):
            x = mask_value(site, rho, data[site.cm], cache) if site.ext_round == m else ZERO
            cur[i] = add(mul(sub(ONE, e), cur[i]), mul(e, x))
    return cur, cache

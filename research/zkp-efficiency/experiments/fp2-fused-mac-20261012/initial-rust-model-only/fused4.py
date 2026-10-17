"""Canonical Goldilocks Fp2 reduction fusion; fixed-width Python model only.

No masks, transcript, RNG, lookup refusals, private state or native speed here.
One raw product plus bounded canonical residues fits u128. Two raw products do not.
"""
from collections import Counter
from field_support import F, P
from accumulator import canonical, reduce128, addfp

MAX128 = (1 << 128) - 1
MAXPRODUCT = (P - 1) ** 2
REAL_BOUND = MAXPRODUCT + 8 * (P - 1)
IMAG_BOUND = MAXPRODUCT + 2 * (P - 1)
assert REAL_BOUND <= MAX128 and IMAG_BOUND <= MAX128

def mac(acc, x, y, counts=None):
    canonical(acc); canonical(x); canonical(y)
    bd = reduce128(x.b * y.b)
    real = reduce128(x.a * y.a + 7 * bd + acc.a)
    ad = reduce128(x.a * y.b)
    imag = reduce128(x.b * y.a + ad + acc.b)
    assert 0 <= real < P and 0 <= imag < P
    if counts is not None:
        counts.update(terms=1, variable_products=4, constant_products=1,
                      reduce128=4, u128_adds=4)
    return F(real, imag)

def product(x, y):
    canonical(x); canonical(y)
    bd = reduce128(x.b * y.b)
    real = reduce128(x.a * y.a + 7 * bd)
    ad = reduce128(x.a * y.b)
    imag = reduce128(x.b * y.a + ad)
    assert 0 <= real < P and 0 <= imag < P
    return F(real, imag)

def native_baseline(acc, x, y):
    """Literal native five-reduction/four-field-add MAC for a third comparison."""
    canonical(acc); canonical(x); canonical(y)
    ac = reduce128(x.a * y.a); bd = reduce128(x.b * y.b)
    ad = reduce128(x.a * y.b); bc = reduce128(x.b * y.a)
    return F(addfp(acc.a, addfp(ac, reduce128(7 * bd))),
             addfp(acc.b, addfp(ad, bc)))

class Fused4Dot:
    def __init__(self, chunk=1024):
        if not isinstance(chunk, int) or chunk <= 0: raise ValueError('chunk')
        self.total = F(); self.counts = Counter(); self.done = False
    def push(self, x, y):
        if self.done: raise ValueError('push after finish')
        self.total = mac(self.total, x, y, self.counts)
    def finish(self):
        if self.done: raise ValueError('double finish')
        self.done = True
        return self.total

"""Goldilocks Fp and Fp2 = Fp[u]/(u^2 - 7), written for the GS-13 adversarial
check independently of the draft's nl_field.py (not imported, not copied).

The extension is the one zkp-core/src/field.rs:2,131-163 defines:
(a0 + a1 u)(b0 + b1 u) = (a0 b0 + 7 a1 b1) + (a0 b1 + a1 b0) u.
Elements are tuples (c0, c1) of Python ints in [0, P).
"""

import random

P = (1 << 64) - (1 << 32) + 1
NR = 7

ZERO = (0, 0)
ONE = (1, 0)
U = (0, 1)


def e(n):
    return (n % P, 0)


def add(a, b):
    return ((a[0] + b[0]) % P, (a[1] + b[1]) % P)


def sub(a, b):
    return ((a[0] - b[0]) % P, (a[1] - b[1]) % P)


def neg(a):
    return ((-a[0]) % P, (-a[1]) % P)


def mul(a, b):
    return ((a[0] * b[0] + NR * a[1] * b[1]) % P, (a[0] * b[1] + a[1] * b[0]) % P)


def inv(a):
    n = (a[0] * a[0] - NR * a[1] * a[1]) % P
    if n == 0:
        raise ZeroDivisionError("inverse of zero in Fp2")
    ni = pow(n, P - 2, P)
    return ((a[0] * ni) % P, (-a[1] * ni) % P)


def pw(a, k):
    r = ONE
    b = a
    while k:
        if k & 1:
            r = mul(r, b)
        b = mul(b, b)
        k >>= 1
    return r


def iszero(a):
    return a[0] == 0 and a[1] == 0


def parse(s):
    """the IR's 'a+bu' text form of an Fp2 constant"""
    s = s.strip()
    assert s.endswith("u"), s
    a, b = s[:-1].split("+")
    return (int(a) % P, int(b) % P)


class Rng:
    def __init__(self, seed):
        self.r = random.Random(seed)

    def fp(self):
        return self.r.randrange(P)

    def fp2(self):
        return (self.r.randrange(P), self.r.randrange(P))

    def fp2_nz(self):
        while True:
            x = self.fp2()
            if not iszero(x):
                return x

    def fp2_not01(self):
        while True:
            x = self.fp2()
            if x != ZERO and x != ONE:
                return x


def rank(rows):
    """rank over Fp2 of a list of equal-length rows (copied, not modified)"""
    m = [list(r) for r in rows]
    if not m:
        return 0
    ncol = len(m[0])
    rk = 0
    for c in range(ncol):
        piv = None
        for i in range(rk, len(m)):
            if not iszero(m[i][c]):
                piv = i
                break
        if piv is None:
            continue
        m[rk], m[piv] = m[piv], m[rk]
        pinv = inv(m[rk][c])
        m[rk] = [mul(x, pinv) for x in m[rk]]
        for i in range(len(m)):
            if i != rk and not iszero(m[i][c]):
                f = m[i][c]
                m[i] = [sub(x, mul(f, y)) for x, y in zip(m[i], m[rk])]
        rk += 1
        if rk == len(m):
            break
    return rk


def rank_and_span(rows, extras):
    """rows: an L x W matrix; extras: a list of length-L columns. Returns
    (rank of the L x W matrix, [does extra column k lie in its column
    space]). One elimination: pivots only in the first W columns, then an
    extra column lies in the column space iff it is zero on every row left
    without a pivot."""
    m = [list(r) + [ex[i] for ex in extras] for i, r in enumerate(rows)]
    W = len(rows[0])
    rk = 0
    for c in range(W):
        piv = None
        for i in range(rk, len(m)):
            if not iszero(m[i][c]):
                piv = i
                break
        if piv is None:
            continue
        m[rk], m[piv] = m[piv], m[rk]
        pinv = inv(m[rk][c])
        m[rk] = [mul(x, pinv) for x in m[rk]]
        for i in range(rk + 1, len(m)):
            if not iszero(m[i][c]):
                f = m[i][c]
                m[i] = [sub(x, mul(f, y)) for x, y in zip(m[i], m[rk])]
        rk += 1
        if rk == len(m):
            break
    spans = []
    for k in range(len(extras)):
        spans.append(all(iszero(m[i][W + k]) for i in range(rk, len(m))))
    return rk, spans


def solve_combination(rows, target):
    """find coefficients y with sum_i y_i rows[i] = target (over Fp2), or None.
    Gaussian elimination on the transposed system."""
    L = len(rows)
    W = len(target)
    # augmented matrix: W equations, L unknowns
    m = [[rows[i][j] for i in range(L)] + [target[j]] for j in range(W)]
    piv_cols = []
    rk = 0
    for c in range(L):
        piv = None
        for i in range(rk, W):
            if not iszero(m[i][c]):
                piv = i
                break
        if piv is None:
            continue
        m[rk], m[piv] = m[piv], m[rk]
        pinv = inv(m[rk][c])
        m[rk] = [mul(x, pinv) for x in m[rk]]
        for i in range(W):
            if i != rk and not iszero(m[i][c]):
                f = m[i][c]
                m[i] = [sub(x, mul(f, y)) for x, y in zip(m[i], m[rk])]
        piv_cols.append(c)
        rk += 1
    for i in range(rk, W):
        if not iszero(m[i][L]):
            return None
    y = [ZERO] * L
    for r, c in enumerate(piv_cols):
        y[c] = m[r][L]
    return y


def self_test():
    # 7 is a quadratic non-residue mod P (Euler), u^2 = 7, inverses, rank sanity
    ok = pow(NR, (P - 1) // 2, P) == P - 1
    ok = ok and mul(U, U) == e(7)
    rng = Rng(12345)
    for _ in range(100):
        a = rng.fp2_nz()
        ok = ok and mul(a, inv(a)) == ONE
    # a rank-deficient 3x3 (third row = first + second)
    a, b = [rng.fp2() for _ in range(3)], [rng.fp2() for _ in range(3)]
    ok = ok and rank([a, b, [add(x, y) for x, y in zip(a, b)]]) == 2
    return ok

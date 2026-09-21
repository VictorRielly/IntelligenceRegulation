#!/usr/bin/env python3
"""Goldilocks Fp and Fp2 = Fp[u]/(u^2 - 7), and exact linear algebra over Fp2.

Ported from `zkp-core/src/field.rs` at lane commit 8c5922b (`P` at :10,
`Fp2` and its `mul`/`inv` at :130-180, NONRESIDUE 7 at :129) and
`zkp-core/src/mle.rs:252-266` (`interpolate_eval`).

Every computation in this directory is exact: no floating point, no sampling
test. A rank is a rank.
"""
P = (1 << 64) - (1 << 32) + 1
NR = 7

ZERO = (0, 0)
ONE = (1, 0)
U = (0, 1)


def add(a, b):
    return ((a[0] + b[0]) % P, (a[1] + b[1]) % P)


def sub(a, b):
    return ((a[0] - b[0]) % P, (a[1] - b[1]) % P)


def neg(a):
    return ((-a[0]) % P, (-a[1]) % P)


def mul(a, b):
    ac = a[0] * b[0] % P
    bd = a[1] * b[1] % P
    ad = a[0] * b[1] % P
    bc = a[1] * b[0] % P
    return ((ac + bd * NR) % P, (ad + bc) % P)


def inv(a):
    norm = (a[0] * a[0] - a[1] * a[1] * NR) % P
    assert norm != 0, "Fp2 inverse of zero"
    ni = pow(norm, P - 2, P)
    return (a[0] * ni % P, (-a[1]) % P * ni % P)


def is_zero(a):
    return a[0] == 0 and a[1] == 0


def base(v):
    return (v % P, 0)


def scal(a, k):
    """multiply by a base-field integer"""
    return (a[0] * (k % P) % P, a[1] * (k % P) % P)


def interpolate_eval(vals, x):
    """mle.rs:252-266 — Lagrange interpolation through nodes 0..len-1."""
    d = len(vals)
    acc = ZERO
    for i in range(d):
        num = ONE
        den = 1
        for j in range(d):
            if i == j:
                continue
            num = mul(num, sub(x, base(j)))
            den = den * ((i - j) % P) % P
        acc = add(acc, scal(mul(vals[i], num), pow(den, P - 2, P)))
    return acc


class Rng:
    """A deterministic splitmix64 stream; only used to pick GENERIC instances."""

    def __init__(self, seed):
        self.s = seed & ((1 << 64) - 1)

    def u64(self):
        self.s = (self.s + 0x9E3779B97F4A7C15) & ((1 << 64) - 1)
        z = self.s
        z = ((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9) & ((1 << 64) - 1)
        z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & ((1 << 64) - 1)
        return z ^ (z >> 31)

    def fp(self):
        return self.u64() % P

    def fp2(self):
        return (self.fp(), self.fp())

    def fp2_nonzero(self):
        while True:
            v = self.fp2()
            if not is_zero(v):
                return v

    def fp2_vec(self, n):
        return [self.fp2() for _ in range(n)]


def rank(rows):
    """Gaussian elimination over Fp2. `rows` is a list of equal-length lists."""
    if not rows:
        return 0
    m = [list(r) for r in rows]
    n_cols = len(m[0])
    r = 0
    for c in range(n_cols):
        piv = None
        for i in range(r, len(m)):
            if not is_zero(m[i][c]):
                piv = i
                break
        if piv is None:
            continue
        m[r], m[piv] = m[piv], m[r]
        iv = inv(m[r][c])
        m[r] = [mul(x, iv) for x in m[r]]
        for i in range(len(m)):
            if i != r and not is_zero(m[i][c]):
                f = m[i][c]
                m[i] = [sub(x, mul(f, y)) for x, y in zip(m[i], m[r])]
        r += 1
        if r == len(m):
            break
    return r


def rank_of_columns(cols):
    """rank of the matrix whose COLUMNS are `cols` (each a vector)."""
    if not cols:
        return 0
    rows = [[cols[j][i] for j in range(len(cols))] for i in range(len(cols[0]))]
    return rank(rows)


def in_span(cols, v):
    """is v in the span of the given column vectors?"""
    return rank_of_columns(cols + [v]) == rank_of_columns(cols)

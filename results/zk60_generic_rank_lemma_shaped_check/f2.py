"""Independent exact Goldilocks / Fp2 arithmetic for the adversarial check.

Written from scratch (not imported from the memo's `fieldlib.py`) so that a
bug shared with the memo cannot hide.  p = 2^64 - 2^32 + 1, Fp2 = Fp[U]/(U^2-7)
(`zkp-core/src/field.rs`).
"""
P = (1 << 64) - (1 << 32) + 1
NONRES = 7


def fadd(a, b): return (a + b) % P
def fsub(a, b): return (a - b) % P
def fmul(a, b): return (a * b) % P
def fneg(a): return (-a) % P
def finv(a):
    assert a % P != 0, "inverse of zero"
    return pow(a, P - 2, P)


# Fp2 elements are 2-tuples (c0, c1) meaning c0 + c1 * U.
F2ZERO = (0, 0)
F2ONE = (1, 0)
F2U = (0, 1)


def f2add(a, b): return ((a[0] + b[0]) % P, (a[1] + b[1]) % P)
def f2sub(a, b): return ((a[0] - b[0]) % P, (a[1] - b[1]) % P)
def f2neg(a): return ((-a[0]) % P, (-a[1]) % P)


def f2mul(a, b):
    # (a0 + a1 U)(b0 + b1 U) = a0b0 + 7 a1b1 + (a0b1 + a1b0) U
    return ((a[0] * b[0] + NONRES * a[1] * b[1]) % P, (a[0] * b[1] + a[1] * b[0]) % P)


def f2iszero(a): return a[0] % P == 0 and a[1] % P == 0


def norm(a):
    """N(a) = a0^2 - 7 a1^2 -- zero iff a = 0 when U^2-7 is irreducible."""
    return (a[0] * a[0] - NONRES * a[1] * a[1]) % P


def wedge(a, b):
    """`protocol.rs:276-278` determinant(a,b) = a.c0*b.c1 - a.c1*b.c0."""
    return (a[0] * b[1] - a[1] * b[0]) % P


def f2inv(a):
    n = norm(a)
    assert n != 0
    ni = finv(n)
    return ((a[0] * ni) % P, ((-a[1]) % P * ni) % P)


# -- the irreducibility of U^2 - 7 (so Fp2 is a field and only 0 has norm 0)
def u2_minus_7_is_irreducible():
    return pow(NONRES, (P - 1) // 2, P) == P - 1


# ---------------------------------------------------------------- linear algebra
def rank_fp(rows):
    """Exact rank over Fp of a list of row vectors (entries in Fp)."""
    m = [list(r) for r in rows]
    nr, nc = len(m), (len(m[0]) if m else 0)
    r = 0
    for c in range(nc):
        piv = None
        for i in range(r, nr):
            if m[i][c] % P:
                piv = i
                break
        if piv is None:
            continue
        m[r], m[piv] = m[piv], m[r]
        inv = finv(m[r][c])
        m[r] = [(x * inv) % P for x in m[r]]
        for i in range(nr):
            if i != r and m[i][c] % P:
                f = m[i][c]
                m[i] = [(x - f * y) % P for x, y in zip(m[i], m[r])]
        r += 1
        if r == nr:
            break
    return r


def det_fp(m):
    """Exact determinant over Fp of a square matrix."""
    a = [list(r) for r in m]
    n = len(a)
    det = 1
    for c in range(n):
        piv = None
        for i in range(c, n):
            if a[i][c] % P:
                piv = i
                break
        if piv is None:
            return 0
        if piv != c:
            a[c], a[piv] = a[piv], a[c]
            det = (-det) % P
        det = (det * a[c][c]) % P
        inv = finv(a[c][c])
        a[c] = [(x * inv) % P for x in a[c]]
        for i in range(c + 1, n):
            if a[i][c] % P:
                f = a[i][c]
                a[i] = [(x - f * y) % P for x, y in zip(a[i], a[c])]
    return det


def realify(vec_f2):
    """One Fp2 row vector -> two Fp row vectors (the Re and Im functionals).

    A commitment row holds an Fp value x_i.  The published combination is
    sum_i g_i x_i in Fp2; its two Fp coordinates are sum_i Re(g_i) x_i and
    sum_i Im(g_i) x_i.  Realification is Fp-linear (toy correction C-8).
    """
    return ([g[0] % P for g in vec_f2], [g[1] % P for g in vec_f2])


def eq_table_msb(point):
    """`mle.rs` eq_table_msb: the 2^k equality tensor, most significant bit
    first."""
    t = [F2ONE]
    for x in point:
        nt = []
        for e in t:
            nt.append(f2mul(e, f2sub(F2ONE, x)))
            nt.append(f2mul(e, x))
        t = nt
    return t


class Rng:
    """A deterministic, seeded stream of GENERIC field elements (never a
    convenient degenerate one)."""

    def __init__(self, seed):
        import random
        self.r = random.Random(seed)

    def fp(self):
        return self.r.randrange(1, P)

    def f2(self):
        # generic: both coordinates nonzero
        return (self.r.randrange(1, P), self.r.randrange(1, P))

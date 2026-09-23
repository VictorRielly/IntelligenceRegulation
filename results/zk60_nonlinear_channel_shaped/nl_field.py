"""Exact Goldilocks / Fp2 arithmetic and exact linear algebra for the GS-13
check (ZK60_NONLINEAR_CHANNEL_SHAPED.md).

Written for this check; imports nothing from the project's other tools.

  p  = 2^64 - 2^32 + 1
  Fp2 = Fp[u] / (u^2 - 7)          (zkp-core/src/field.rs:131, NONRESIDUE 7)

Fp2 elements are pairs (c0, c1) of ints in [0, p).
"""

P = (1 << 64) - (1 << 32) + 1
NONRES = 7

ZERO = (0, 0)
ONE = (1, 0)
U = (0, 1)


def f(v):
    """an integer (any sign) as an Fp2 element of the base field"""
    return (v % P, 0)


def add(x, y):
    return ((x[0] + y[0]) % P, (x[1] + y[1]) % P)


def sub(x, y):
    return ((x[0] - y[0]) % P, (x[1] - y[1]) % P)


def neg(x):
    return ((-x[0]) % P, (-x[1]) % P)


def mul(x, y):
    a, b = x
    c, d = y
    return ((a * c + NONRES * b * d) % P, (a * d + b * c) % P)


def inv(x):
    a, b = x
    norm = (a * a - NONRES * b * b) % P
    if norm == 0:
        raise ZeroDivisionError("Fp2 inverse of zero")
    ni = pow(norm, P - 2, P)
    return ((a * ni) % P, (-b * ni) % P)


def is_zero(x):
    return x[0] == 0 and x[1] == 0


def pw(x, e):
    r = ONE
    b = x
    while e:
        if e & 1:
            r = mul(r, b)
        b = mul(b, b)
        e >>= 1
    return r


def parse(s):
    """the IR export's value string "c0+c1u" """
    a, b = s.rstrip("u").split("+")
    return (int(a) % P, int(b) % P)


class Rng:
    """a deterministic source of field elements for the check (NOT the
    prover's generator; the check only needs reproducible generic values)"""

    def __init__(self, seed):
        import random

        self.r = random.Random(seed)

    def fp(self):
        return self.r.randrange(P)

    def fp2(self):
        return (self.r.randrange(P), self.r.randrange(P))

    def fp2_nonzero_not_one(self):
        while True:
            v = self.fp2()
            if v != ZERO and v != ONE:
                return v


# ---------------------------------------------------------------- linear algebra over Fp2


def rank(rows, ncols):
    """exact rank over Fp2 of a list of rows (each a list of Fp2 of length ncols)"""
    m = [list(r) for r in rows]
    rk = 0
    col = 0
    nrows = len(m)
    while rk < nrows and col < ncols:
        piv = None
        for i in range(rk, nrows):
            if not is_zero(m[i][col]):
                piv = i
                break
        if piv is None:
            col += 1
            continue
        m[rk], m[piv] = m[piv], m[rk]
        iv = inv(m[rk][col])
        m[rk] = [mul(iv, v) for v in m[rk]]
        for i in range(nrows):
            if i != rk and not is_zero(m[i][col]):
                fct = m[i][col]
                ri = m[i]
                rr = m[rk]
                m[i] = [sub(ri[k], mul(fct, rr[k])) for k in range(ncols)]
        rk += 1
        col += 1
    return rk


def solve(a_cols, b):
    """find x with sum_i x_i * a_cols[i] = b (vectors over Fp2), or None.
    a_cols: list of column vectors (each length n); b: length n."""
    n = len(b)
    k = len(a_cols)
    # augmented matrix rows: n rows, k + 1 columns
    m = [[a_cols[j][i] for j in range(k)] + [b[i]] for i in range(n)]
    pivots = []
    rk = 0
    for col in range(k):
        piv = None
        for i in range(rk, n):
            if not is_zero(m[i][col]):
                piv = i
                break
        if piv is None:
            continue
        m[rk], m[piv] = m[piv], m[rk]
        iv = inv(m[rk][col])
        m[rk] = [mul(iv, v) for v in m[rk]]
        for i in range(n):
            if i != rk and not is_zero(m[i][col]):
                fct = m[i][col]
                m[i] = [sub(m[i][c], mul(fct, m[rk][c])) for c in range(k + 1)]
        pivots.append(col)
        rk += 1
        if rk == n:
            break
    for i in range(rk, n):
        if not is_zero(m[i][k]):
            return None
    x = [ZERO] * k
    for r, col in enumerate(pivots):
        x[col] = m[r][k]
    return x


# ---------------------------------------------------------------- linear algebra over Fp (base field)


def rank_fp(rows, ncols):
    m = [[v % P for v in r] for r in rows]
    rk = 0
    col = 0
    nrows = len(m)
    while rk < nrows and col < ncols:
        piv = None
        for i in range(rk, nrows):
            if m[i][col]:
                piv = i
                break
        if piv is None:
            col += 1
            continue
        m[rk], m[piv] = m[piv], m[rk]
        iv = pow(m[rk][col], P - 2, P)
        m[rk] = [(iv * v) % P for v in m[rk]]
        for i in range(nrows):
            if i != rk and m[i][col]:
                fct = m[i][col]
                rr = m[rk]
                m[i] = [(m[i][c] - fct * rr[c]) % P for c in range(ncols)]
        rk += 1
        col += 1
    return rk


def self_test():
    """returns a dict of facts; raises on a failure"""
    out = {}
    # 7 is a quadratic non-residue mod p (Euler), so u^2 = 7 is irreducible
    assert pow(NONRES, (P - 1) // 2, P) == P - 1
    out["seven_is_nonresidue"] = True
    r = Rng(0x6513)
    for _ in range(200):
        x = r.fp2()
        if is_zero(x):
            continue
        assert mul(x, inv(x)) == ONE
    out["inverse_checks"] = 200
    assert mul(U, U) == f(7)
    out["u_squared_is_7"] = True
    # rank / solve self-consistency on random systems
    agree = 0
    for t in range(30):
        n = 3 + t % 5
        k = 2 + (t * 7) % 6
        cols = [[r.fp2() for _ in range(n)] for _ in range(k)]
        # make some columns dependent
        if k > 2:
            cols[-1] = [add(mul(f(3), cols[0][i]), cols[1][i]) for i in range(n)]
        x_true = [r.fp2() for _ in range(k)]
        b = [ZERO] * n
        for j in range(k):
            for i in range(n):
                b[i] = add(b[i], mul(x_true[j], cols[j][i]))
        x = solve(cols, b)
        assert x is not None
        bb = [ZERO] * n
        for j in range(k):
            for i in range(n):
                bb[i] = add(bb[i], mul(x[j], cols[j][i]))
        assert bb == b
        rows = [[cols[j][i] for j in range(k)] for i in range(n)]
        rk = rank(rows, k)
        rk_aug = rank([rows[i] + [b[i]] for i in range(n)], k + 1)
        assert rk == rk_aug
        agree += 1
    out["solve_rank_selftest_systems"] = agree
    return out

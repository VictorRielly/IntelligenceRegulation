"""Goldilocks / Fp2 arithmetic and an exact sparse Gaussian elimination.

Written from scratch for the independent review of the terminal-surjection
step (ZK60_TERMINAL_SURJECTION_REVIEW.md).  Nothing here is imported from
the project's own joint-view tools: the point of the exercise is that the
numbers are recomputed by code that has not seen them.

p = 2^64 - 2^32 + 1, Fp2 = Fp[U]/(U^2 - 7)  (field_modulus and
extension_nonresidue as the captures themselves declare them).
"""

P = (1 << 64) - (1 << 32) + 1
NONRESIDUE = 7

F2_ZERO = (0, 0)
F2_ONE = (1, 0)
F2_U = (0, 1)


def inv(a):
    a %= P
    assert a != 0, "inverse of zero in Fp"
    return pow(a, P - 2, P)


def f2(x):
    """(c0, c1) from a captured [c0, c1] pair."""
    return (x[0] % P, x[1] % P)


def f2_add(a, b):
    return ((a[0] + b[0]) % P, (a[1] + b[1]) % P)


def f2_sub(a, b):
    return ((a[0] - b[0]) % P, (a[1] - b[1]) % P)


def f2_neg(a):
    return ((-a[0]) % P, (-a[1]) % P)


def f2_mul(a, b):
    return ((a[0] * b[0] + NONRESIDUE * a[1] * b[1]) % P, (a[0] * b[1] + a[1] * b[0]) % P)


def f2_scale(a, k):
    """a * k for k in Fp."""
    return (a[0] * k % P, a[1] * k % P)


def f2_norm(a):
    """a * conj(a) = a0^2 - 7 a1^2; zero iff a == 0 (7 is a non-residue)."""
    return (a[0] * a[0] - NONRESIDUE * a[1] * a[1]) % P


def f2_inv(a):
    n = f2_norm(a)
    assert n != 0, "inverse of zero in Fp2"
    ni = inv(n)
    return (a[0] * ni % P, (-a[1]) % P * ni % P)


def f2_is_zero(a):
    return a[0] % P == 0 and a[1] % P == 0


def f2_det(a, b):
    """The Fp determinant of (a, b) read as two vectors of Fp2 over Fp.

    Zero exactly when a and b are Fp-dependent, i.e. when they are NOT an
    Fp-basis of Fp2 (protocol.rs::determinant).
    """
    return (a[0] * b[1] - a[1] * b[0]) % P


def eq_table_msb(point):
    """zkp-core/src/mle.rs::eq_table_msb, re-derived.

    eq_table splits each existing entry e into (e*(1-r), e*r) as it walks r;
    eq_table_msb walks the point in reverse so point[0] is the most
    significant index bit.  The entries therefore sum to
    prod_i ((1 - r_i) + r_i) = 1, whatever the point is.
    """
    out = [F2_ONE]
    for r in reversed(point):
        one_minus = f2_sub(F2_ONE, r)
        nxt = [F2_ZERO] * (2 * len(out))
        for i, e in enumerate(out):
            nxt[i] = f2_mul(e, one_minus)
            nxt[len(out) + i] = f2_mul(e, r)
        out = nxt
    return out


# --------------------------------------------------------------- linear algebra
class Elim:
    """Exact Gaussian elimination over Fp, rows given as {col: value} dicts.

    Plain textbook echelon maintenance: a new row is reduced against the
    stored pivots in increasing column order; if something is left, its
    leading column becomes a new pivot.  No problem-specific shortcut --
    the same routine is used for the honest instances, the controls and the
    random cross-checks, and it is validated against a dense elimination on
    random instances in ts_review.py (stage 0).
    """

    def __init__(self):
        self.piv = {}  # col -> row dict, normalised so row[col] == 1

    def reduce(self, row):
        row = {c: v % P for c, v in row.items() if v % P}
        while row:
            c = min(row)
            pr = self.piv.get(c)
            if pr is None:
                return c, row
            f = row[c]
            for k, v in pr.items():
                nv = (row.get(k, 0) - f * v) % P
                if nv:
                    row[k] = nv
                elif k in row:
                    del row[k]
        return None, row

    def add(self, row):
        c, red = self.reduce(row)
        if c is None:
            return False
        iv = inv(red[c])
        self.piv[c] = {k: v * iv % P for k, v in red.items()}
        return True

    @property
    def rank(self):
        return len(self.piv)


def dense_rank(rows, ncols):
    """A second, independent implementation: dense elimination over Fp."""
    m = [[x % P for x in r] for r in rows]
    r = 0
    for c in range(ncols):
        piv = None
        for i in range(r, len(m)):
            if m[i][c]:
                piv = i
                break
        if piv is None:
            continue
        m[r], m[piv] = m[piv], m[r]
        iv = inv(m[r][c])
        m[r] = [x * iv % P for x in m[r]]
        for i in range(len(m)):
            if i != r and m[i][c]:
                f = m[i][c]
                m[i] = [(a - f * b) % P for a, b in zip(m[i], m[r])]
        r += 1
        if r == len(m):
            break
    return r

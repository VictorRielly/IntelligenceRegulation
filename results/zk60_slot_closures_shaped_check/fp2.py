"""Fp = 2^64 - 2^32 + 1, Fp2 = Fp[u]/(u^2 - 7).

Written from `zkp-core/src/field.rs:10, :130` at lane commit 8c5922b, NOT from
the memo's own `results/zk60_slot_closures_shaped/fp2.py` (which I have not
read before writing this).  Independent adversarial check.
"""

P = (1 << 64) - (1 << 32) + 1
NR = 7  # u^2 = 7


def inv(a):
    return pow(a % P, P - 2, P)


class F2:
    __slots__ = ("a", "b")

    def __init__(self, a=0, b=0):
        self.a = a % P
        self.b = b % P

    def __add__(self, o):
        return F2(self.a + o.a, self.b + o.b)

    def __sub__(self, o):
        return F2(self.a - o.a, self.b - o.b)

    def __neg__(self):
        return F2(-self.a, -self.b)

    def __mul__(self, o):
        if isinstance(o, int):
            return F2(self.a * o, self.b * o)
        # (a + b u)(c + d u) = (ac + 7 bd) + (ad + bc) u
        return F2(self.a * o.a + NR * self.b * o.b, self.a * o.b + self.b * o.a)

    __rmul__ = __mul__

    def is_zero(self):
        return self.a == 0 and self.b == 0

    def inv(self):
        # norm = a^2 - 7 b^2
        n = (self.a * self.a - NR * self.b * self.b) % P
        assert n != 0, "zero divisor in Fp2 -- 7 would be a square mod p"
        ni = inv(n)
        return F2(self.a * ni, -self.b * ni)

    def __truediv__(self, o):
        return self * o.inv()

    def __eq__(self, o):
        return self.a == o.a and self.b == o.b

    def __hash__(self):
        return hash((self.a, self.b))

    def __repr__(self):
        return f"({self.a},{self.b})"


ZERO = F2(0, 0)
ONE = F2(1, 0)
U = F2(0, 1)


def pw(x, e):
    r = ONE
    for _ in range(e):
        r = r * x
    return r


class Rng:
    """splitmix64-ish; only needs to be reproducible, not cryptographic."""

    def __init__(self, seed):
        self.s = seed & ((1 << 64) - 1)

    def u64(self):
        self.s = (self.s * 6364136223846793005 + 1442695040888963407) & ((1 << 64) - 1)
        return self.s >> 1

    def f2(self):
        return F2(self.u64(), self.u64())

    def vec(self, n):
        return [self.f2() for _ in range(n)]


# ---- exact linear algebra over Fp2 -------------------------------------

def rank(rows):
    """rank of a list of row vectors over Fp2 (exact Gaussian elimination)."""
    m = [list(r) for r in rows]
    if not m:
        return 0
    nc = len(m[0])
    r = 0
    for c in range(nc):
        piv = None
        for i in range(r, len(m)):
            if not m[i][c].is_zero():
                piv = i
                break
        if piv is None:
            continue
        m[r], m[piv] = m[piv], m[r]
        iv = m[r][c].inv()
        m[r] = [x * iv for x in m[r]]
        for i in range(len(m)):
            if i != r and not m[i][c].is_zero():
                f = m[i][c]
                m[i] = [x - f * y for x, y in zip(m[i], m[r])]
        r += 1
        if r == len(m):
            break
    return r


def in_span(rows, v):
    """is v in the row span of rows?"""
    return rank(list(rows) + [list(v)]) == rank(rows)

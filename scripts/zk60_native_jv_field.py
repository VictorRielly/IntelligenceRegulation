"""Goldilocks field, Fp2, NTT and the hashline Fiat-Shamir transcript, in Python.

Ported label-by-label and line-by-line from the pinned Rust sources of the
native private-block / private-attention profiles:

  zkp-core/src/field.rs       P, NONRESIDUE, two_adic_root, to_bytes
  zkp-core/src/ntt.rs         forward/inverse (natural order, omega = two_adic_root)
  zkp-core/src/transcript.rs  Transcript::new/absorb/absorb_u64/absorb_fp2/
                              challenge_fp2/challenge_indices/state
  zkp-core/src/mle.rs         eq_table / eq_table_msb
  zkp-core/src/pcs.rs         encode_row_zk, coset_powers, zpart_weights

This module is READ-ONLY analysis tooling for the joint-view gate: it never
touches a receipt, a prover or any Rust file.  It is deliberately independent
of the older FFN round-2 tools (different profile, geometry and labels).
"""

from __future__ import annotations

P = 0xFFFF_FFFF_0000_0001
NONRESIDUE = 7
GENERATOR = 7
TWO_ADICITY = 32


# --------------------------------------------------------------- base field
def fp(v: int) -> int:
    return v % P


def inv(a: int) -> int:
    if a % P == 0:
        raise ZeroDivisionError("inverse of zero")
    return pow(a, P - 2, P)


def two_adic_root(k: int) -> int:
    """zkp-core/src/field.rs::two_adic_root."""
    assert 0 <= k <= TWO_ADICITY
    r32 = pow(GENERATOR, (P - 1) >> TWO_ADICITY, P)
    return pow(r32, 1 << (TWO_ADICITY - k), P)


def fp_bytes(v: int) -> bytes:
    return (v % P).to_bytes(8, "little")


# ------------------------------------------------------------- extension Fp2
# Fp2 = Fp[u]/(u^2 - 7); an element is the pair (c0, c1).
def f2_add(a, b):
    return ((a[0] + b[0]) % P, (a[1] + b[1]) % P)


def f2_sub(a, b):
    return ((a[0] - b[0]) % P, (a[1] - b[1]) % P)


def f2_neg(a):
    return ((-a[0]) % P, (-a[1]) % P)


def f2_mul(a, b):
    ac = a[0] * b[0] % P
    bd = a[1] * b[1] % P
    ad = a[0] * b[1] % P
    bc = a[1] * b[0] % P
    return ((ac + bd * NONRESIDUE) % P, (ad + bc) % P)


def f2_mul_base(a, s):
    return (a[0] * s % P, a[1] * s % P)


def f2_inv(a):
    norm = (a[0] * a[0] - a[1] * a[1] * NONRESIDUE) % P
    ninv = inv(norm)
    return (a[0] * ninv % P, (-a[1]) % P * ninv % P)


def f2_is_zero(a):
    return a[0] % P == 0 and a[1] % P == 0


F2_ZERO = (0, 0)
F2_ONE = (1, 0)


def f2_bytes(a) -> bytes:
    return fp_bytes(a[0]) + fp_bytes(a[1])


def f2_from_list(x):
    return (x[0] % P, x[1] % P)


# --------------------------------------------------------------------- NTT
class Ntt:
    """Natural-order radix-2 NTT, forward = coefficients -> evaluations at omega^i."""

    def __init__(self, max_log: int = 12):
        self.max_log = max_log
        self._roots = {}

    def root(self, log_n: int) -> int:
        if log_n not in self._roots:
            self._roots[log_n] = two_adic_root(log_n)
        return self._roots[log_n]

    def forward(self, a: list[int]) -> list[int]:
        return _transform(list(a), self.root(len(a).bit_length() - 1), False)

    def inverse(self, a: list[int]) -> list[int]:
        n = len(a)
        out = _transform(list(a), inv(self.root(n.bit_length() - 1)), False)
        ninv = inv(n % P)
        return [x * ninv % P for x in out]


def _transform(a: list[int], w: int, _unused: bool) -> list[int]:
    n = len(a)
    assert n & (n - 1) == 0
    if n == 1:
        return a
    # bit reversal
    j = 0
    for i in range(1, n):
        bit = n >> 1
        while j & bit:
            j ^= bit
            bit >>= 1
        j |= bit
        if i < j:
            a[i], a[j] = a[j], a[i]
    length = 2
    while length <= n:
        step = pow(w, n // length, P)
        half = length // 2
        for start in range(0, n, length):
            tw = 1
            for k in range(half):
                u = a[start + k]
                v = a[start + k + half] * tw % P
                a[start + k] = (u + v) % P
                a[start + k + half] = (u - v) % P
                tw = tw * step % P
        length <<= 1
    return a


def coset_powers(h: int, nn: int) -> list[int]:
    out = [1] * nn
    for i in range(1, nn):
        out[i] = out[i - 1] * h % P
    return out


def eq_table(r: list[tuple]) -> list[tuple]:
    """zkp-core/src/mle.rs::eq_table (first r is the most significant split)."""
    out = [F2_ONE]
    for ri in r:
        one_minus = f2_sub(F2_ONE, ri)
        nxt = [F2_ZERO] * (2 * len(out))
        for i, e in enumerate(out):
            nxt[i] = f2_mul(e, one_minus)
            nxt[i + len(out)] = f2_mul(e, ri)
        out = nxt
    return out


def eq_table_msb(r: list[tuple]) -> list[tuple]:
    return eq_table(list(reversed(r)))


# -------------------------------------------------------------- transcript
class Transcript:
    """zkp-core/src/transcript.rs, without the round masker (verifier side)."""

    def __init__(self, domain: bytes | None = None, state: bytes | None = None, counter: int = 0):
        import blake3

        self._blake3 = blake3
        if state is not None:
            self.state = bytes(state)
            self.counter = counter
        else:
            h = blake3.blake3()
            h.update(b"hashline-v1/")
            h.update(domain)
            self.state = h.digest()
            self.counter = 0

    def clone(self) -> "Transcript":
        return Transcript(state=self.state, counter=self.counter)

    def absorb(self, label: bytes, data: bytes) -> None:
        h = self._blake3.blake3()
        h.update(self.state)
        h.update(len(label).to_bytes(8, "little"))
        h.update(label)
        h.update(len(data).to_bytes(8, "little"))
        h.update(data)
        self.state = h.digest()

    def absorb_u64(self, label: bytes, v: int) -> None:
        self.absorb(label, v.to_bytes(8, "little"))

    def absorb_fp2(self, label: bytes, vals) -> None:
        self.absorb(label, b"".join(f2_bytes(v) for v in vals))

    def _squeeze(self) -> bytes:
        h = self._blake3.blake3()
        h.update(self.state)
        h.update(b"squeeze")
        h.update(self.counter.to_bytes(8, "little"))
        self.counter += 1
        out = h.digest()
        self.state = out
        return out

    def challenge_fp2(self):
        b = self._squeeze()
        c0 = int.from_bytes(b[:16], "little") % P
        c1 = int.from_bytes(b[16:], "little") % P
        return (c0, c1)

    def challenge_fp2_vec(self, n: int):
        return [self.challenge_fp2() for _ in range(n)]

    def challenge_indices(self, n: int, bound: int):
        assert bound & (bound - 1) == 0
        out = []
        while len(out) < n:
            b = self._squeeze()
            for k in range(0, 32, 8):
                if len(out) == n:
                    break
                out.append(int.from_bytes(b[k : k + 8], "little") & (bound - 1))
        return out

    def peek_next(self):
        return self.clone().challenge_fp2()


# ------------------------------------------------------- linear algebra /Fp
def rank(rows: list[list[int]], ncols: int | None = None) -> int:
    """Exact rank over Fp of a list of row vectors (destroys nothing)."""
    mat = [list(r) for r in rows if any(x % P for x in r)]
    if not mat:
        return 0
    ncols = ncols if ncols is not None else len(mat[0])
    r = 0
    for c in range(ncols):
        piv = None
        for i in range(r, len(mat)):
            if mat[i][c] % P:
                piv = i
                break
        if piv is None:
            continue
        mat[r], mat[piv] = mat[piv], mat[r]
        pr = mat[r]
        pinv = inv(pr[c])
        pr[:] = [x * pinv % P for x in pr]
        for i in range(r + 1, len(mat)):
            f = mat[i][c] % P
            if f:
                ri = mat[i]
                mat[i] = [(a - f * b) % P for a, b in zip(ri, pr)]
        r += 1
        if r == len(mat):
            break
    return r


def det_mod_p(mat: list[list[int]]) -> int:
    """Determinant over Fp of a square matrix, by Gaussian elimination.

    Returns 0 exactly when the matrix is singular.  Used to PRINT the
    certifying minor the generic-rank lemma argues about; the gate's tests
    recompute the same determinant by an independent (fraction-free)
    algorithm from the emitted indices.
    """
    n = len(mat)
    if any(len(r) != n for r in mat):
        raise ValueError("det_mod_p: not square")
    a = [[x % P for x in r] for r in mat]
    det = 1
    for c in range(n):
        piv = None
        for i in range(c, n):
            if a[i][c]:
                piv = i
                break
        if piv is None:
            return 0
        if piv != c:
            a[c], a[piv] = a[piv], a[c]
            det = (-det) % P
        det = det * a[c][c] % P
        pinv = inv(a[c][c])
        a[c] = [x * pinv % P for x in a[c]]
        for i in range(c + 1, n):
            f = a[i][c]
            if f:
                a[i] = [(x - f * y) % P for x, y in zip(a[i], a[c])]
    return det % P


def row_reduce(rows: list[list[int]], ncols: int):
    """Reduced row echelon basis of the row space, with the pivot columns."""
    mat = [list(r) for r in rows]
    pivots = []
    r = 0
    for c in range(ncols):
        piv = None
        for i in range(r, len(mat)):
            if mat[i][c] % P:
                piv = i
                break
        if piv is None:
            continue
        mat[r], mat[piv] = mat[piv], mat[r]
        pinv = inv(mat[r][c])
        mat[r] = [x * pinv % P for x in mat[r]]
        for i in range(len(mat)):
            if i != r and mat[i][c] % P:
                f = mat[i][c]
                mat[i] = [(a - f * b) % P for a, b in zip(mat[i], mat[r])]
        pivots.append(c)
        r += 1
        if r == len(mat):
            break
    return [row for row in mat[:r]], pivots


def solve(rows: list[list[int]], rhs: list[int]):
    """One solution x of rows^T? no: of  sum_k x[k] * rows[k] == rhs, or None.

    `rows` is a list of vectors; we look for a coefficient vector x with
    sum_k x[k] rows[k] = rhs.  Returns (x, kernel_basis) or (None, kernel_basis).
    """
    m = len(rows)
    if m == 0:
        return (None if any(v % P for v in rhs) else [], [])
    n = len(rhs)
    # augmented system A x = rhs with A[i][k] = rows[k][i]
    aug = [[rows[k][i] % P for k in range(m)] + [rhs[i] % P] for i in range(n)]
    pivots = []
    r = 0
    for c in range(m):
        piv = None
        for i in range(r, n):
            if aug[i][c]:
                piv = i
                break
        if piv is None:
            continue
        aug[r], aug[piv] = aug[piv], aug[r]
        pinv = inv(aug[r][c])
        aug[r] = [x * pinv % P for x in aug[r]]
        for i in range(n):
            if i != r and aug[i][c]:
                f = aug[i][c]
                aug[i] = [(a - f * b) % P for a, b in zip(aug[i], aug[r])]
        pivots.append(c)
        r += 1
        if r == n:
            break
    for i in range(r, n):
        if aug[i][m] % P and not any(aug[i][:m]):
            return (None, _kernel_from_rref(aug[:r], pivots, m))
    x = [0] * m
    for i, c in enumerate(pivots):
        x[c] = aug[i][m]
    return (x, _kernel_from_rref(aug[:r], pivots, m))


def _kernel_from_rref(rref, pivots, m):
    free = [c for c in range(m) if c not in pivots]
    basis = []
    for fc in free:
        v = [0] * m
        v[fc] = 1
        for i, pc in enumerate(pivots):
            v[pc] = (-rref[i][fc]) % P
        basis.append(v)
    return basis

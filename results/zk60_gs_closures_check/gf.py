"""Exact Goldilocks arithmetic for the GS closures check (independent of the
drafter's code: nothing here is imported from results/zk60_gs_closures/).

p = 2^64 - 2^32 + 1.  Two layers:
  * scalar helpers on Python ints (Fp and Fp2 = Fp[U]/(U^2 - 7));
  * vectorised numpy uint64 arithmetic mod p (Goldilocks reduction with
    2^64 = 2^32 - 1 mod p), used by `rank_split` -- a dense Gaussian
    elimination that returns (rank of the whole matrix, rank of the leading
    `first` columns) in ONE left-to-right pass (the elimination of the leading
    block IS the elimination of the restricted matrix).

`selftest()` checks the numpy multiply against Python ints and the rank
routine against a pure-Python elimination on random low-rank matrices.
"""

from __future__ import annotations

import random

import numpy as np

P = 2**64 - 2**32 + 1
NR = 7  # U^2 = 7 (a non-residue mod p)
EPS = 2**32 - 1  # 2^64 mod p
CHUNK = 1024  # rows per elimination update block
M32 = np.uint64(0xFFFFFFFF)
NP_P = np.uint64(P)
NP_EPS = np.uint64(EPS)
S32 = np.uint64(32)


# ------------------------------------------------------------- scalars
def inv(a):
    a %= P
    assert a, "inverse of zero"
    return pow(a, P - 2, P)


def f2(a, b=0):
    return (a % P, b % P)


def f2_add(x, y):
    return ((x[0] + y[0]) % P, (x[1] + y[1]) % P)


def f2_sub(x, y):
    return ((x[0] - y[0]) % P, (x[1] - y[1]) % P)


def f2_mul(x, y):
    return ((x[0] * y[0] + NR * x[1] * y[1]) % P, (x[0] * y[1] + x[1] * y[0]) % P)


def f2_scale(x, s):
    return (x[0] * s % P, x[1] * s % P)


def f2_inv(x):
    # (a + bU)^-1 = (a - bU) / (a^2 - 7 b^2)
    nrm = (x[0] * x[0] - NR * x[1] * x[1]) % P
    i = inv(nrm)
    return (x[0] * i % P, (-x[1]) * i % P)


def f2_tr(x):
    """Tr_{Fp2/Fp}(a + bU) = 2a."""
    return 2 * x[0] % P


ZERO = (0, 0)
ONE = (1, 0)
U = (0, 1)


def rnd_fp(rng):
    return rng.randrange(1, P)


def rnd_f2(rng):
    return (rng.randrange(0, P), rng.randrange(1, P))  # imaginary part nonzero: not in Fp


def eq_table(point):
    out = [ONE]
    for r in point:
        om = f2_sub(ONE, r)
        nxt = []
        for e in out:
            nxt.append(f2_mul(e, om))
            nxt.append(f2_mul(e, r))
        out = nxt
    return out


# ------------------------------------------------------ numpy mod-p ops
def _red(x):
    return np.where(x >= NP_P, x - NP_P, x)


def np_add(a, b):
    with np.errstate(over="ignore"):
        s = a + b
        over = s < a
        s = np.where(over, s + NP_EPS, s)
    return _red(s)


def np_sub(a, b):
    with np.errstate(over="ignore"):
        d = a - b
        return np.where(a >= b, d, d + NP_P)


def np_mul(a, b):
    with np.errstate(over="ignore"):
        a0 = a & M32
        a1 = a >> S32
        b0 = b & M32
        b1 = b >> S32
        lo = a0 * b0
        m1 = a0 * b1
        m2 = a1 * b0
        hi = a1 * b1
        H = hi + (m1 >> S32) + (m2 >> S32)
        S = (m1 & M32) + (m2 & M32) + (H & M32)
        Sl = S & M32
        Sh = S >> S32
        t = _red(lo)
        t = np_add(t, _red(Sl << S32))
        t = np_add(t, Sh * NP_EPS)
        t = np_sub(t, H & M32)
        t = np_sub(t, H >> S32)
    return t


def rank_split(mat_rows, ncols, first):
    """(rank of the whole matrix, rank of columns [0, first)); exact mod p.

    mat_rows: list of dicts {col: int} or of int lists.  Dense uint64 inside.
    """
    nrows = len(mat_rows)
    if nrows == 0:
        return 0, 0
    A = np.zeros((nrows, ncols), dtype=np.uint64)
    for r, row in enumerate(mat_rows):
        if isinstance(row, dict):
            for c, v in row.items():
                A[r, c] = v % P
        else:
            A[r, :] = [v % P for v in row]
    r = 0
    r_first = 0
    for c in range(ncols):
        if r == nrows:
            break
        col = A[r:, c]
        nz = np.nonzero(col)[0]
        if nz.size == 0:
            continue
        piv = r + int(nz[0])
        if piv != r:
            A[[r, piv], c:] = A[[piv, r], c:]
        iv = np.uint64(inv(int(A[r, c])))
        A[r, c:] = np_mul(A[r, c:], iv)
        below = r + 1 + np.nonzero(A[r + 1:, c])[0]
        # row chunks bound the temporaries (~CHUNK x ncols words per op)
        for s in range(0, below.size, CHUNK):
            blk = below[s:s + CHUNK]
            f = A[blk, c][:, None]
            A[np.ix_(blk, np.arange(c, ncols))] = np_sub(A[np.ix_(blk, np.arange(c, ncols))], np_mul(f, A[r, c:][None, :]))
        r += 1
        if c < first:
            r_first += 1
    return r, r_first


def rank(mat_rows, ncols):
    return rank_split(mat_rows, ncols, ncols)[0]


def rank_py(rows, ncols):
    """Pure-Python reference elimination (small matrices only)."""
    M = [[v % P for v in row] for row in rows]
    r = 0
    for c in range(ncols):
        p = next((i for i in range(r, len(M)) if M[i][c]), None)
        if p is None:
            continue
        M[r], M[p] = M[p], M[r]
        iv = inv(M[r][c])
        M[r] = [x * iv % P for x in M[r]]
        for i in range(len(M)):
            if i != r and M[i][c]:
                f = M[i][c]
                M[i] = [(a - f * b) % P for a, b in zip(M[i], M[r])]
        r += 1
    return r


def solve_left(rows, target):
    """x with sum_k x[k] * rows[k] == target (mod p), or None.  Pure Python."""
    k = len(rows)
    m = len(target)
    aug = [[rows[r][j] % P for r in range(k)] + [target[j] % P] for j in range(m)]
    piv = []
    rr = 0
    for c in range(k):
        p = next((i for i in range(rr, m) if aug[i][c]), None)
        if p is None:
            continue
        aug[rr], aug[p] = aug[p], aug[rr]
        iv = inv(aug[rr][c])
        aug[rr] = [x * iv % P for x in aug[rr]]
        for i in range(m):
            if i != rr and aug[i][c]:
                f = aug[i][c]
                aug[i] = [(a - f * b) % P for a, b in zip(aug[i], aug[rr])]
        piv.append(c)
        rr += 1
    for i in range(rr, m):
        if aug[i][k]:
            return None
    x = [0] * k
    for i, c in enumerate(piv):
        x[c] = aug[i][k]
    return x


def left_kernel(rows, ncols):
    """Basis of {x : sum_k x[k] rows[k] = 0}.  Pure Python."""
    k = len(rows)
    mat = [[rows[r][j] % P for r in range(k)] for j in range(ncols)]
    piv = []
    rr = 0
    for c in range(k):
        p = next((i for i in range(rr, ncols) if mat[i][c]), None)
        if p is None:
            continue
        mat[rr], mat[p] = mat[p], mat[rr]
        iv = inv(mat[rr][c])
        mat[rr] = [x * iv % P for x in mat[rr]]
        for i in range(ncols):
            if i != rr and mat[i][c]:
                f = mat[i][c]
                mat[i] = [(a - f * b) % P for a, b in zip(mat[i], mat[rr])]
        piv.append(c)
        rr += 1
    out = []
    for fc in [c for c in range(k) if c not in piv]:
        v = [0] * k
        v[fc] = 1
        for i, pc in enumerate(piv):
            v[pc] = (-mat[i][fc]) % P
        out.append(v)
    return out


def selftest(seed=11):
    rng = random.Random(seed)
    a = [rng.randrange(P) for _ in range(4000)] + [P - 1, 0, 1, 2**32, 2**63, EPS]
    b = [rng.randrange(P) for _ in range(4000)] + [P - 1, P - 1, 2**32, 2**32, 2**63, EPS]
    na = np.array(a, dtype=np.uint64)
    nb = np.array(b, dtype=np.uint64)
    got_m = [int(x) for x in np_mul(na, nb)]
    got_s = [int(x) for x in np_sub(na, nb)]
    got_a = [int(x) for x in np_add(na, nb)]
    assert got_m == [x * y % P for x, y in zip(a, b)], "np_mul"
    assert got_s == [(x - y) % P for x, y in zip(a, b)], "np_sub"
    assert got_a == [(x + y) % P for x, y in zip(a, b)], "np_add"
    for trial in range(30):
        nr, nc, rk = rng.randrange(2, 14), rng.randrange(2, 14), rng.randrange(1, 8)
        L = [[rng.randrange(P) for _ in range(rk)] for _ in range(nr)]
        R = [[rng.randrange(P) for _ in range(nc)] for _ in range(rk)]
        M = [[sum(L[i][k] * R[k][j] for k in range(rk)) % P for j in range(nc)] for i in range(nr)]
        first = rng.randrange(0, nc + 1)
        r_all, r_first = rank_split(M, nc, first)
        assert r_all == rank_py(M, nc), "rank"
        assert r_first == rank_py([row[:first] for row in M], first) if first else r_first == 0, "rank_first"
    return True


if __name__ == "__main__":
    print("selftest", selftest())

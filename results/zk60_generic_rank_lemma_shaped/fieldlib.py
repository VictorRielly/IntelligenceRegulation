#!/usr/bin/env python3
"""Goldilocks `Fp` and `Fp2 = Fp[U]/(U^2 - 7)`, and exact Fp linear algebra.

Ported from `zkp-core/src/field.rs:15, 133-141, 163, 177` (the modulus, the
extension, `Norm`).  Pure Python integers; nothing approximate anywhere.
"""
from __future__ import annotations
import random

P = (1 << 64) - (1 << 32) + 1
NONRES = 7          # `field.rs:15`: Fp2 = Fp[U]/(U^2 - 7)


def f2mul(a, b):
    (a0, a1), (b0, b1) = a, b
    return ((a0 * b0 + NONRES * a1 * b1) % P, (a0 * b1 + a1 * b0) % P)


def f2add(a, b):
    return ((a[0] + b[0]) % P, (a[1] + b[1]) % P)


def f2sub(a, b):
    return ((a[0] - b[0]) % P, (a[1] - b[1]) % P)


def f2neg(a):
    return ((-a[0]) % P, (-a[1]) % P)


ONE = (1, 0)
ZERO = (0, 0)
U = (0, 1)


def norm(a):
    """`field.rs:177`: Norm(x) = x.c0^2 - 7 x.c1^2."""
    return (a[0] * a[0] - NONRES * a[1] * a[1]) % P


def wedge(a, b):
    """The Fp volume form the code calls `determinant`
    (`private_block/protocol.rs:277-279`)."""
    return (a[0] * b[1] - a[1] * b[0]) % P


def f2inv(a):
    n = norm(a)
    assert n != 0, "Fp2 inverse of zero"
    ni = pow(n, P - 2, P)
    return ((a[0] * ni) % P, ((-a[1]) * ni) % P)


def rand_f2(rng):
    return (rng.randrange(P), rng.randrange(P))


def rand_fp(rng):
    return rng.randrange(P)


# ------------------------------------------------------------------ ranks

def rank_fp(rows, ncols=None):
    """Exact Fp rank of a list of Fp row vectors."""
    if not rows:
        return 0
    n = ncols if ncols is not None else len(rows[0])
    m = [list(r) for r in rows]
    piv_row = 0
    for c in range(n):
        p = None
        for r in range(piv_row, len(m)):
            if m[r][c]:
                p = r
                break
        if p is None:
            continue
        m[piv_row], m[p] = m[p], m[piv_row]
        pr = m[piv_row]
        inv = pow(pr[c], P - 2, P)
        pr = [(x * inv) % P for x in pr]
        m[piv_row] = pr
        for r in range(piv_row + 1, len(m)):
            f = m[r][c]
            if f:
                mr = m[r]
                m[r] = [(x - f * y) % P for x, y in zip(mr, pr)]
        piv_row += 1
        if piv_row == len(m):
            break
    return piv_row


def rank_split(rows, n_first):
    """One elimination in a fixed column order; returns
    `(rank of the first n_first columns, rank of the whole matrix)`.

    Used with the OBSERVED-but-not-hidden coordinates first and the hidden
    data rectangle last, so that
        disclosed = rank(all) - rank(first block)
    is the dimension of the observation span that is supported on the hidden
    rectangle alone.
    """
    if not rows:
        return 0, 0
    n = len(rows[0])
    m = [list(r) for r in rows]
    piv_row = 0
    rank_first = None
    for c in range(n):
        if c == n_first:
            rank_first = piv_row
        p = None
        for r in range(piv_row, len(m)):
            if m[r][c]:
                p = r
                break
        if p is None:
            continue
        m[piv_row], m[p] = m[p], m[piv_row]
        inv = pow(m[piv_row][c], P - 2, P)
        pr = [(x * inv) % P for x in m[piv_row]]
        m[piv_row] = pr
        for r in range(piv_row + 1, len(m)):
            f = m[r][c]
            if f:
                m[r] = [(x - f * y) % P for x, y in zip(m[r], pr)]
        piv_row += 1
        if piv_row == len(m):
            break
    if rank_first is None:
        rank_first = piv_row
    return rank_first, piv_row


def det_fp(square):
    """Exact Fp determinant of a square matrix (list of rows)."""
    m = [list(r) for r in square]
    k = len(m)
    d = 1
    for c in range(k):
        p = None
        for r in range(c, k):
            if m[r][c]:
                p = r
                break
        if p is None:
            return 0
        if p != c:
            m[c], m[p] = m[p], m[c]
            d = (-d) % P
        d = (d * m[c][c]) % P
        inv = pow(m[c][c], P - 2, P)
        pr = [(x * inv) % P for x in m[c]]
        m[c] = pr
        for r in range(c + 1, k):
            f = m[r][c]
            if f:
                m[r] = [(x - f * y) % P for x, y in zip(m[r], pr)]
    return d


def eq_table_msb(point):
    """`zkp-core/src/mle.rs:13-51` — the equality tensor, most-significant
    coordinate first, total 1 at every point."""
    t = [ONE]
    for r in point:
        nt = []
        for e in t:
            nt.append(f2mul(e, f2sub(ONE, r)))
            nt.append(f2mul(e, r))
        t = nt
    return t

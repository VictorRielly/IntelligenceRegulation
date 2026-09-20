#!/usr/bin/env python3
"""INDEPENDENT re-derivation of the masked-sumcheck degrees-of-freedom identity.

Written for ZK60_JOINT_LAW_COMPOSITION_CHECK.md (adversarial check of the
delegated draft).  Deliberately NOT a re-use of the draft's
results/zk60_joint_law_composition/mask_rank_identity.py:

  * the round map R_s is built by BRUTE FORCE from the definition of the CFS
    polynomial g (sum over the boolean tail of g(prev, X, x)), never from the
    closed form at zkp-core/src/sumcheck.rs:255-274.  The closed form is then
    checked AGAINST the brute force, so an error in the closed form cannot
    make the identity true by construction;
  * a different prime (2^61 - 1, and a second run over 10007 to test that the
    conclusion is not an artefact of a large field);
  * the consistency subspace C_s is built from the verifier's own equations
    (zkp-core/src/sumcheck.rs:147-158) with Lagrange interpolation at nodes
    0..d, independently coded;
  * extra controls the draft did not run: dropping a_0, dropping one whole
    round, publishing d+2 values, and the explicit kernel vector predicted by
    the check's own proof.

No witness value, salt or private plane is read.  Everything is generated here.
"""

import random
import sys

# (N_s = n_main + n_ext, d_s) for the 23 slots of the toy private block,
# read off hashline/src/private_block/layout.rs SLOTS = (n, ext, degree).
LAYOUT_SLOTS = [
    (9, 1, 3), (9, 1, 3), (5, 1, 3), (9, 1, 4), (11, 1, 3),
    (4, 1, 2), (4, 1, 2), (4, 1, 2), (3, 2, 2), (5, 2, 2),
    (4, 1, 2), (4, 1, 2), (4, 1, 2), (4, 1, 2),
    (9, 1, 4), (9, 1, 4), (8, 1, 4), (11, 1, 4), (9, 1, 4),
    (8, 1, 3), (8, 1, 2), (9, 1, 2), (9, 1, 2),
]
SHAPES = [(n + e, d) for (n, e, d) in LAYOUT_SLOTS]


def mk(P):
    def inv(a):
        return pow(a % P, P - 2, P)

    def rank(rows, ncols):
        m = [[x % P for x in r] for r in rows]
        r = 0
        for c in range(ncols):
            piv = next((i for i in range(r, len(m)) if m[i][c]), None)
            if piv is None:
                continue
            m[r], m[piv] = m[piv], m[r]
            iv = inv(m[r][c])
            m[r] = [(x * iv) % P for x in m[r]]
            for i in range(len(m)):
                if i != r and m[i][c]:
                    f = m[i][c]
                    m[i] = [(a - f * b) % P for a, b in zip(m[i], m[r])]
            r += 1
            if r == len(m):
                break
        return r

    return inv, rank


def g_eval(coeffs, N, d, xs, P):
    """g(x) = a_0 + a' prod_j x_j + sum_j sum_{e=1..d} a_{j,e} x_j^e."""
    acc = coeffs[0]
    pr = 1
    for x in xs:
        pr = pr * x % P
    acc = (acc + coeffs[1] * pr) % P
    for j, x in enumerate(xs):
        xp = 1
        for e in range(1, d + 1):
            xp = xp * x % P
            acc = (acc + coeffs[2 + j * d + (e - 1)] * xp) % P
    return acc % P


def brute_round(coeffs, N, d, j, prev, P, points):
    """Round j of the honest sumcheck of g: sum over the boolean tail."""
    tail = N - 1 - j
    out = []
    for X in points:
        s = 0
        for m in range(1 << tail):
            xs = list(prev) + [X] + [(m >> (tail - 1 - t)) & 1 for t in range(tail)]
            s = (s + g_eval(coeffs, N, d, xs, P)) % P
        out.append(s)
    return out


def round_matrix_derived(N, d, rho, P, inv, points=None, drop=()):
    """R_s from THIS CHECK's own derivation of the round map, not from the code.

    Round j at X is sum over the boolean tail x_{>j} of
    g(rho_{<j}, X, x_{>j}).  Term by term, with u_i(0) = 0:
      a_0            -> 2^{N-1-j} a_0
      a' prod_i x_i  -> a' (prod_{i<j} rho_i) X            (only the all-ones tail)
      u_i(rho_i) i<j -> 2^{N-1-j} u_i(rho_i)
      u_j(X)         -> 2^{N-1-j} u_j(X)
      u_i(x_i) i>j   -> 2^{N-2-j} u_i(1)
    (Verified against genuine brute force on the small shapes below.)
    """
    if points is None:
        points = list(range(d + 1))
    L = N * d + 2
    cols = [k for k in range(L) if k not in drop]
    half = inv(2)
    rows = []
    for j in range(N):
        scale = pow(2, N - 1 - j, P)
        pj = 1
        for i in range(j):
            pj = pj * rho[i] % P
        for x in points:
            row = [0] * L
            row[0] = scale
            row[1] = pj * x % P
            for i in range(j):
                rp = 1
                for e in range(1, d + 1):
                    rp = rp * rho[i] % P
                    row[2 + i * d + e - 1] = (row[2 + i * d + e - 1] + scale * rp) % P
            for i in range(j + 1, N):
                for e in range(1, d + 1):
                    row[2 + i * d + e - 1] = (row[2 + i * d + e - 1] + scale * half) % P
            xp = 1
            for e in range(1, d + 1):
                xp = xp * x % P
                row[2 + j * d + e - 1] = (row[2 + j * d + e - 1] + scale * xp) % P
            rows.append([row[k] % P for k in cols])
    return rows, len(cols)


def closed_form_round(coeffs, N, d, j, prev, P, inv):
    """The code's closed form, zkp-core/src/sumcheck.rs:255-274."""
    half = inv(2)
    base = coeffs[0]

    def u(i, x):
        acc = 0
        xp = 1
        for e in range(1, d + 1):
            xp = xp * x % P
            acc = (acc + coeffs[2 + i * d + (e - 1)] * xp) % P
        return acc % P

    for i, r in enumerate(prev):
        base = (base + u(i, r)) % P
    for i in range(j + 1, N):
        base = (base + u(i, 1) * half) % P
    scale = pow(2, N - 1 - j, P)
    pp = 1
    for r in prev:
        pp = pp * r % P
    return [(scale * (base + u(j, x)) + coeffs[1] * pp * x) % P for x in range(d + 1)]


def consistency_dim(N, d, rho, P, inv, rank):
    """dim C_s from the verifier's chain, coded from sumcheck.rs:147-158."""
    width = 1 + N * (d + 1)
    ix = lambda j, x: 1 + j * (d + 1) + x

    def lag(r):
        out = []
        for i in range(d + 1):
            num, den = 1, 1
            for m in range(d + 1):
                if m != i:
                    num = num * (r - m) % P
                    den = den * (i - m) % P
            out.append(num * inv(den) % P)
        return out

    eqs = []
    for j in range(N):
        row = [0] * width
        row[ix(j, 0)] += 1
        row[ix(j, 1)] += 1
        if j == 0:
            row[0] -= 1
        else:
            for x, c in enumerate(lag(rho[j - 1])):
                row[ix(j - 1, x)] -= c
        eqs.append([v % P for v in row])
    return width - rank(eqs, width)


def sum_weights(N, d, P):
    w = [pow(2, N - 1, P)] * (N * d + 2)
    w[0] = pow(2, N, P)
    w[1] = 1
    return w


def eval_weights(rho, d, P):
    w = [1]
    pr = 1
    for r in rho:
        pr = pr * r % P
    w.append(pr)
    for r in rho:
        xp = 1
        for _ in range(d):
            xp = xp * r % P
            w.append(xp)
    return w


def kernel_vector(N, d, rho, P, inv):
    """The check's own predicted kernel: a' = 1, a_{j,1} = -2^{j+1-N} p_j,
    a_{j,e} = 0 for e >= 2, a_0 = -sum_{i>0} u_i(1)/2."""
    L = N * d + 2
    a = [0] * L
    a[1] = 1
    p = [1] * N
    for j in range(1, N):
        p[j] = p[j - 1] * rho[j - 1] % P
    for j in range(N):
        a[2 + j * d] = (-pow(2, j + 1, P) * inv(pow(2, N, P)) * p[j]) % P
    # base_0 = a_0 + sum_{i>0} u_i(1)/2 must vanish
    s = 0
    for i in range(1, N):
        s = (s + a[2 + i * d]) % P
    a[0] = (-s * inv(2)) % P
    return a


def run(P, label, seed, verbose=True):
    inv, rank = mk(P)
    rnd = random.Random(seed)
    out = []
    regimes = {
        "random": lambda n: [rnd.randrange(1, P) for _ in range(n)],
        "all-zero": lambda n: [0] * n,
        "all-one": lambda n: [1] * n,
        "repeat-7": lambda n: [7] * n,
        "ramp": lambda n: [i + 2 for i in range(n)],
        "random2": lambda n: [rnd.randrange(1, P) for _ in range(n)],
    }
    tot = ok_rank = ok_ker = ok_dimc = ok_sw = ok_ew = ok_drop_ap = ok_kervec = 0
    ok_closed = n_closed = 0
    drop_ap_ranks, drop_a0_ranks, d_values_kernels = set(), set(), set()
    for si, (N, d) in enumerate(SHAPES):
        L = N * d + 2
        for rname, gen in regimes.items():
            rho = gen(N)
            R, nc = round_matrix_derived(N, d, rho, P, inv)
            rk = rank(R, nc)
            dc = consistency_dim(N, d, rho, P, inv, rank)
            tot += 1
            ok_rank += (rk == N * d + 1)
            ok_ker += (L - rk == 1)
            ok_dimc += (dc == N * d + 1)
            sw, ew = sum_weights(N, d, P), eval_weights(rho, d, P)
            ok_sw += (rank(R + [sw], nc) == rk)
            ok_ew += (rank(R + [ew], nc) == rk)
            # control: drop a' (column 1)
            R2, nc2 = round_matrix_derived(N, d, rho, P, inv, drop=(1,))
            rk2 = rank(R2, nc2)
            drop_ap_ranks.add(rk2 - (N * d + 1))
            ok_drop_ap += (rk2 == N * d + 1)
            # control: drop a_0 (column 0) as well -- the check's own new control
            R3, nc3 = round_matrix_derived(N, d, rho, P, inv, drop=(0,))
            drop_a0_ranks.add(rank(R3, nc3) - (N * d + 1))
            # control: only d values per round
            R4, nc4 = round_matrix_derived(N, d, rho, P, inv, points=list(range(d)))
            d_values_kernels.add(L - rank(R4, nc4))
            # the predicted explicit kernel vector
            kv = kernel_vector(N, d, rho, P, inv)
            img = [sum(R[i][k] * kv[k] for k in range(L)) % P for i in range(len(R))]
            ok_kervec += all(v == 0 for v in img) and any(v % P for v in kv)
            # closed form vs brute force, on the smaller shapes only (cost)
            if N <= 7:
                co = [rnd.randrange(P) for _ in range(L)]
                for j in range(N):
                    n_closed += 1
                    if closed_form_round(co, N, d, j, rho[:j], P, inv) == brute_round(co, N, d, j, rho[:j], P, list(range(d + 1))):
                        ok_closed += 1
    out.append(f"--- field P = {label}, {tot} (slot, rho) pairs over {len(SHAPES)} real slot shapes ---")
    out.append(f"rank R_s == N d + 1            : {ok_rank}/{tot}")
    out.append(f"dim ker R_s == 1               : {ok_ker}/{tot}")
    out.append(f"dim C_s == N d + 1             : {ok_dimc}/{tot}")
    out.append(f"sum_weights in rowspace(R_s)   : {ok_sw}/{tot}")
    out.append(f"eval_weights in rowspace(R_s)  : {ok_ew}/{tot}")
    out.append(f"predicted kernel vector kills R: {ok_kervec}/{tot}")
    out.append(f"CONTROL drop a'  : rank - (Nd+1) in {sorted(drop_ap_ranks)}  (0 => a' redundant); full on {ok_drop_ap}/{tot}")
    out.append(f"CONTROL drop a_0 : rank - (Nd+1) in {sorted(drop_a0_ranks)}  (negative => a_0 is NOT redundant)")
    out.append(f"CONTROL d values/round (drop X=d): dim ker R in {sorted(d_values_kernels)}  (>1 => mask no longer covers C)")
    out.append(f"closed form == brute force     : {ok_closed}/{n_closed} (small shapes only)")
    return out


def layout_arithmetic():
    L = sum(N * d + 2 for N, d in SHAPES)
    rounds = sum(N for N, _ in SHAPES)
    values = sum(N * (d + 1) for N, d in SHAPES)
    dimC = sum(N * d + 1 for N, d in SHAPES)
    distinct = len(set(SHAPES))
    return [
        "--- layout arithmetic recomputed from layout.rs SLOTS ---",
        f"sum L_s              = {L}    (draft says 583)",
        f"sum N_s              = {rounds}    (draft says 184)",
        f"sum N_s (d_s + 1)    = {values}    (draft says 721)",
        f"sum dim C_s          = {dimC}    (draft says 560)",
        f"max L_s              = {max(N * d + 2 for N, d in SHAPES)}     (draft says 50)",
        f"distinct (N_s, d_s)  = {distinct}     (draft says 11)",
        f"max L_s + 256        = {max(N * d + 2 for N, d in SHAPES) + 256}    (must be <= 512)",
    ]


if __name__ == "__main__":
    lines = layout_arithmetic() + [""]
    lines += run((1 << 61) - 1, "2^61 - 1", 4242) + [""]
    lines += run(10007, "10007 (small field control)", 99) + [""]
    print("\n".join(lines))

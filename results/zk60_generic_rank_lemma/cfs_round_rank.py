#!/usr/bin/env python3
"""U-3a evidence 3: the mask channel's two rank facts are identities, not
generic statements.

The tool (scripts/zk60_native_jv_cfs.py) reports, per slot s of geometry
(N_s = main + extension rounds, degree d_s):

    uncovered_s = dim C_s - rank R_s,         dim C_s = N_s d_s + 1
    rank_F mod rounds = 0

R_s is the Fp2 matrix (mask coefficients -> the N_s published round vectors
of the CFS masking polynomial g_s at the replayed challenges), ported from
zkp-core/src/sumcheck.rs::CfsMask::round.  L_s = N_s d_s + 2 coefficients.

CLAIM 1 (uncovered = 0 for EVERY rho).  ker R_s is exactly one-dimensional
for every rho, so rank R_s = L_s - 1 = N_s d_s + 1 = dim C_s, always.
Reason, derived in the memo section 3.5: a kernel direction must make the
degree-<= d polynomial 2^(N-1-j) u_j(X) + a' (prod_{i<j} rho_i) X vanish at
X = 0..d, hence identically, which pins a_{j,e} = 0 for e >= 2 and
a_{j,1} = -a' prod_{i<j} rho_i / 2^(N-1-j); the N constant-term equations
then telescope to ONE, leaving a_0 determined by a'.  One free parameter.

CLAIM 2 (every published functional lies in rowspace(R_s), for every rho).
  CfsMask::sum_weights  gives  sum_x g(x)  = s_0(0) + s_0(1)   (round 0)
  CfsMask::eval_weights gives  g(rho)      = s_{N-1}(rho_{N-1}) (round N-1,
                                             a Lagrange combination)

Both are checked below at the ACTUAL (N_s, d_s) of the two toy profiles, on
locally drawn rho, plus degenerate rho (zeros, ones, repeats) to show the
facts do not depend on the challenge.  No capture is read: only the slot
geometry, which is public layout.
"""

import random

P = (1 << 64) - (1 << 32) + 1
NONRESIDUE = 7
F2_ZERO, F2_ONE = (0, 0), (1, 0)


def f2mul(a, b):
    return ((a[0] * b[0] + NONRESIDUE * a[1] * b[1]) % P, (a[0] * b[1] + a[1] * b[0]) % P)


def f2add(a, b):
    return ((a[0] + b[0]) % P, (a[1] + b[1]) % P)


def f2sub(a, b):
    return ((a[0] - b[0]) % P, (a[1] - b[1]) % P)


def f2inv(a):
    n = (a[0] * a[0] - NONRESIDUE * a[1] * a[1]) % P
    ni = pow(n, P - 2, P)
    return (a[0] * ni % P, (-a[1]) % P * ni % P)


def f2_is_zero(a):
    return a[0] % P == 0 and a[1] % P == 0


def rref2(rows, ncols):
    mat = [list(r) for r in rows]
    piv, r = [], 0
    for c in range(ncols):
        p = None
        for i in range(r, len(mat)):
            if not f2_is_zero(mat[i][c]):
                p = i
                break
        if p is None:
            continue
        mat[r], mat[p] = mat[p], mat[r]
        iv = f2inv(mat[r][c])
        mat[r] = [f2mul(x, iv) for x in mat[r]]
        for i in range(len(mat)):
            if i != r and not f2_is_zero(mat[i][c]):
                f = mat[i][c]
                mat[i] = [f2sub(a, f2mul(f, b)) for a, b in zip(mat[i], mat[r])]
        piv.append(c)
        r += 1
        if r == len(mat):
            break
    return [mat[i] for i in range(r)], piv


def rank2(rows, ncols):
    return len(rref2(rows, ncols)[0])


def reduce2(vec, basis, pivots):
    out = list(vec)
    for row, pc in zip(basis, pivots):
        if not f2_is_zero(out[pc]):
            f = out[pc]
            out = [f2sub(a, f2mul(f, b)) for a, b in zip(out, row)]
    return out


# --------------------------------------- the ported CfsMask round matrix
HALF = pow(2, P - 2, P)


def mask_len(n, d):
    return n * d + 2


def round_matrix(n, d, rho):
    """zkp-core/src/sumcheck.rs::CfsMask::round as a matrix over the coefficients."""
    L = mask_len(n, d)
    rows = []
    for j in range(n):
        prod_prev = F2_ONE
        for r in rho[:j]:
            prod_prev = f2mul(prod_prev, r)
        scale = (pow(2, n - 1 - j, P), 0)
        base = [F2_ZERO] * L
        base[0] = F2_ONE
        for i, r in enumerate(rho[:j]):
            xp = F2_ONE
            for e in range(1, d + 1):
                xp = f2mul(xp, r)
                base[2 + i * d + (e - 1)] = f2add(base[2 + i * d + (e - 1)], xp)
        for i in range(j + 1, n):
            for e in range(1, d + 1):
                base[2 + i * d + (e - 1)] = f2add(base[2 + i * d + (e - 1)], (HALF, 0))
        for x in range(d + 1):
            xv = (x % P, 0)
            row = [f2mul(scale, b) for b in base]
            xp = F2_ONE
            for e in range(1, d + 1):
                xp = f2mul(xp, xv)
                k = 2 + j * d + (e - 1)
                row[k] = f2add(row[k], f2mul(scale, xp))
            row[1] = f2add(row[1], f2mul(prod_prev, xv))
            rows.append(row)
    return rows


def sum_weights(n, d):
    w = [(pow(2, n - 1, P), 0)] * mask_len(n, d)
    w[0] = (pow(2, n, P), 0)
    w[1] = F2_ONE
    return w


def eval_weights(rho, d):
    w = [F2_ONE]
    pr = F2_ONE
    for r in rho:
        pr = f2mul(pr, r)
    w.append(pr)
    for r in rho:
        xp = F2_ONE
        for _ in range(d):
            xp = f2mul(xp, r)
            w.append(xp)
    return w


# ---------------------------------------------------------------- the specs
SPECS = {
    "private-block-t32-poc (23 slots)":
        [(10, 3), (10, 3), (6, 3), (10, 4), (12, 3), (5, 2), (5, 2), (5, 2), (5, 2),
         (7, 2), (5, 2), (5, 2), (5, 2), (5, 2), (10, 4), (10, 4), (9, 4), (12, 4),
         (10, 4), (9, 3), (9, 2), (10, 2), (10, 2)],
    "private-attention-t32-poc (18 slots)":
        [(10, 3), (6, 3), (10, 3), (12, 3), (5, 2), (5, 2), (5, 2), (5, 2), (7, 2),
         (5, 2), (10, 4), (10, 4), (9, 4), (12, 4), (9, 3), (9, 2), (10, 2), (10, 2)],
}

rng = random.Random(902020)


def r2():
    return (rng.randrange(P), rng.randrange(P))


def rho_case(kind, n):
    if kind == "uniform":
        return [r2() for _ in range(n)]
    if kind == "all zero":
        return [F2_ZERO] * n
    if kind == "all one":
        return [F2_ONE] * n
    if kind == "all equal":
        v = r2()
        return [v] * n
    if kind == "in the base field":
        return [(rng.randrange(P), 0) for _ in range(n)]
    raise ValueError(kind)


CASES = ["uniform", "all zero", "all one", "all equal", "in the base field"]

for profile, specs in SPECS.items():
    print(profile)
    for case in CASES:
        bad_rank, bad_sum, bad_eval, tot = 0, 0, 0, 0
        for (n, d) in specs:
            rho = rho_case(case, n)
            R = round_matrix(n, d, rho)
            L = mask_len(n, d)
            basis, piv = rref2(R, L)
            rr = len(basis)
            dimC = n * d + 1
            if rr != dimC:
                bad_rank += 1
            if not all(f2_is_zero(x) for x in reduce2(sum_weights(n, d), basis, piv)):
                bad_sum += 1
            if not all(f2_is_zero(x) for x in reduce2(eval_weights(rho, d), basis, piv)):
                bad_eval += 1
            tot += 1
        print(f"  rho = {case:18s} slots {tot:2d}   "
              f"rank R != dim C: {bad_rank}   "
              f"sum_weights outside rowspace(R): {bad_sum}   "
              f"eval_weights outside rowspace(R): {bad_eval}")
    print()

print("Negative control: perturb the round matrix (drop the last round) and the")
print("two facts must fail.")
n, d = 10, 3
rho = rho_case("uniform", n)
R = round_matrix(n, d, rho)
Rshort = R[: -(d + 1)]
basis, piv = rref2(Rshort, mask_len(n, d))
print(f"  rank of R without its last round = {len(basis)} (dim C = {n * d + 1})")
print(f"  eval_weights still inside rowspace? "
      f"{all(f2_is_zero(x) for x in reduce2(eval_weights(rho, d), basis, piv))}"
      f"   (want False)")
print(f"  sum_weights  still inside rowspace? "
      f"{all(f2_is_zero(x) for x in reduce2(sum_weights(n, d), basis, piv))}"
      f"   (want True: it lives in round 0)")

print()
print("CONCLUSION.  Both mask-channel facts hold at every rho tried, including")
print("degenerate ones the protocol would refuse.  They are identities in the")
print("challenges, so no Schwartz-Zippel term is owed for the M channel's")
print("`uncovered = 0` or for `rank_F mod rounds = 0`.")

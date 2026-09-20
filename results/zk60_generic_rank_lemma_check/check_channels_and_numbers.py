#!/usr/bin/env python3
"""INDEPENDENT CHECK: attacks 3 (mask channel), 4 (opened columns / pads),
5 (the numbers), and the Fp-vs-Fp2 question.

Plain Python, exact integer arithmetic, no third-party packages.  Nothing
here is taken from the draft's scripts; the closed forms are re-derived from
zkp-core/src/pcs.rs::encode_row_zk, hashline/src/zk.rs::mask_commit and
zkp-core/src/sumcheck.rs::CfsMask by reading.
"""

import json
import math
import os
import random
import sys

P = (1 << 64) - (1 << 32) + 1
NR = 7
GEN = 7                      # multiplicative generator of Fp*, also the coset shift
CAPDIR = "/home/victor/IntelligenceRegulation/results/zk60_native_captures_20260919/captures"

rng = random.Random(0xBADC0DE)


def inv(a):
    return pow(a % P, P - 2, P)


def root(logn):
    """primitive 2^logn-th root of unity in Fp (p-1 = 2^32 * (2^32-1))."""
    return pow(GEN, (P - 1) >> logn, P)


def rank_fp(rows, ncols):
    m = [list(r) for r in rows]
    r = 0
    for c in range(ncols):
        piv = None
        for i in range(r, len(m)):
            if m[i][c] % P:
                piv = i
                break
        if piv is None:
            continue
        m[r], m[piv] = m[piv], m[r]
        iv = inv(m[r][c])
        m[r] = [x * iv % P for x in m[r]]
        for i in range(len(m)):
            if i != r and m[i][c] % P:
                f = m[i][c]
                m[i] = [(a - f * b) % P for a, b in zip(m[i], m[r])]
        r += 1
        if r == len(m):
            break
    return r


# ------------------------------------------------------------------ Fp2
def f2mul(a, b):
    return ((a[0] * b[0] + NR * a[1] * b[1]) % P, (a[0] * b[1] + a[1] * b[0]) % P)


def f2add(a, b):
    return ((a[0] + b[0]) % P, (a[1] + b[1]) % P)


def f2sub(a, b):
    return ((a[0] - b[0]) % P, (a[1] - b[1]) % P)


def f2inv(a):
    nm = (a[0] * a[0] - NR * a[1] * a[1]) % P
    ni = inv(nm)
    return (a[0] * ni % P, (-a[1]) * ni % P)


F2Z, F2O = (0, 0), (1, 0)


def rank_f2(rows, ncols):
    m = [list(r) for r in rows]
    r = 0
    for c in range(ncols):
        piv = None
        for i in range(r, len(m)):
            if m[i][c] != F2Z:
                piv = i
                break
        if piv is None:
            continue
        m[r], m[piv] = m[piv], m[r]
        iv = f2inv(m[r][c])
        m[r] = [f2mul(x, iv) for x in m[r]]
        for i in range(len(m)):
            if i != r and m[i][c] != F2Z:
                f = m[i][c]
                m[i] = [f2sub(a, f2mul(f, b)) for a, b in zip(m[i], m[r])]
        r += 1
        if r == len(m):
            break
    return r


def out(title):
    print()
    print("=" * 74)
    print(title)
    print("=" * 74)


# =====================================================================
# 4.  THE OPENED COLUMNS: the A/H/endpoint pad block and M's Cauchy block
# =====================================================================
def pad_block_A_H():
    out("4a. A / H / endpoint pad block  (pcs.rs::encode_row_zk, n=256, nn=2048)")
    n, nn = 256, 2048
    w = root(11)                                    # 2048-th root
    print(f"  order check: 7^(p-1) == 1?  {pow(GEN, P - 1, P) == 1}")
    print(f"  7^2048 == 1?  {pow(GEN, 2048, P) == 1}   (needed: False)")
    print(f"  7^4096 == 1?  {pow(GEN, 4096, P) == 1}   (needed: False)")
    xs = [GEN * pow(w, j, P) % P for j in range(nn)]
    print(f"  distinct coset nodes x_j = 7 w^j over all {nn} positions: "
          f"{len(set(xs))}")
    zn = [(pow(x, n, P) - 1) % P for x in xs]
    print(f"  Z_n(x_j) = x_j^256 - 1 zero anywhere on the encoded domain: "
          f"{sum(1 for z in zn if z == 0)} of {nn}")
    sub = set(pow(root(8), s, P) for s in range(n))
    print(f"  any coset node inside the size-256 subgroup (a systematic "
          f"position): {sum(1 for x in xs if x in sub)} of {nn}")

    # the real captured index sets, repeats included
    for fn in sorted(os.listdir(CAPDIR)):
        if not fn.endswith(".json"):
            continue
        cap = json.load(open(os.path.join(CAPDIR, fn)))
        prof = "block" if "block" in cap["profile"] else "attn "
        for role in cap["roles"]:
            idx = [c["index"] for c in role["columns"]]
            d = len(set(idx))
            rows = [[zn[j] * pow(xs[j], k, P) % P for k in range(256)]
                    for j in sorted(set(idx))]
            r = rank_fp(rows, 256)
            print(f"  {fn[:8]} {prof} {role['role']:6s}: {len(idx)} draws, "
                  f"{d} distinct, pad-block rank {r} (= distinct: {r == d}), "
                  f"q_pad {role['q_pad']}, slack {role['q_pad'] - d}")
        break   # one capture is enough for the column geometry; the rest repeat

    # the boundary and a negative control
    rows = [[zn[j] * pow(xs[j], k, P) % P for k in range(256)] for j in range(256)]
    print(f"  256 DISTINCT positions (the collision-free boundary): rank "
          f"{rank_fp(rows, 256)} of 256")
    rows2 = rows[:255] + [rows[0]]
    print(f"  negative control, one repeated position: rank "
          f"{rank_fp(rows2, 256)} of 256 (must be 255)")
    rows3 = [[zn[j] * pow(xs[j], k, P) % P for k in range(256)]
             for j in range(257)]
    print(f"  negative control, 257 distinct positions vs 256 pads: rank "
          f"{rank_fp(rows3, 256)} of 257 rows (must be 256 -- the budget is "
          f"EXACTLY spent)")


def pad_block_M():
    out("4b. M pad block (zk.rs::mask_commit, m=512 msg, dom=4096, MASK_Q=256)")
    m, dom, q = 512, 4096, 256
    wd, wm = root(12), root(9)
    ys = [GEN * pow(wd, j, P) % P for j in range(dom)]
    print(f"  distinct nodes y_j over all {dom}: {len(set(ys))}")
    zs = [(pow(y, m, P) - 1) % P for y in ys]
    print(f"  z_j = y_j^512 - 1 zero anywhere: {sum(1 for z in zs if z == 0)}")
    msgnodes = set(pow(wm, t, P) for t in range(m))
    print(f"  any y_j equal to a message node w^t: "
          f"{sum(1 for y in ys if y in msgnodes)} of {dom}")
    minv = inv(m)
    # the REAL pad positions of an a-row are [L, L+256) with L = N*d+2 <= 50,
    # not [0,256) as the tool's cross-check uses.  Both are checked.
    for L in (0, 50):
        js = sorted(rng.sample(range(dom), q))
        rows = []
        for j in js:
            y, z = ys[j], zs[j]
            rows.append([z * minv % P * pow(wm, t, P) % P * inv((y - pow(wm, t, P)) % P) % P
                         for t in range(L, L + q)])
        print(f"  pad positions [{L},{L + q}), 256 random opened columns: "
              f"Cauchy rank {rank_fp(rows, q)} of {q}")


# =====================================================================
# 3.  THE MASK CHANNEL: ker R and the published functionals
# =====================================================================
BLOCK_SLOTS = [(9, 1, 3), (9, 1, 3), (5, 1, 3), (9, 1, 4), (11, 1, 3), (4, 1, 2),
               (4, 1, 2), (4, 1, 2), (3, 2, 2), (5, 2, 2), (4, 1, 2), (4, 1, 2),
               (4, 1, 2), (4, 1, 2), (9, 1, 4), (9, 1, 4), (8, 1, 4), (11, 1, 4),
               (9, 1, 4), (8, 1, 3), (8, 1, 2), (9, 1, 2), (9, 1, 2)]


def cfs_round_matrix(N, d, rhos):
    """R: coefficient index -> the N published round vectors (d+1 values each).
    Re-derived from CfsMask::round (sumcheck.rs:255-274) by differentiating in
    each coefficient (the map is linear in the coefficients)."""
    L = N * d + 2
    rowsR = []
    half = inv(2)
    for k in range(L):
        vals = []
        for j in range(N):
            scale = pow(2, N - 1 - j, P)
            prod_prev = 1
            for i in range(j):
                prod_prev = prod_prev * rhos[i] % P
            for x in range(d + 1):
                # base = a_0 + sum_{i<j} u_i(rho_i) + sum_{i>j} u_i(1)/2
                v = 0
                if k == 0:
                    v = scale
                elif k == 1:
                    v = prod_prev * x % P
                else:
                    jj, e = divmod(k - 2, d)
                    e += 1
                    if jj < j:
                        v = scale * pow(rhos[jj], e, P) % P
                    elif jj > j:
                        v = scale * half % P
                    else:
                        v = scale * pow(x, e, P) % P
                vals.append(v % P)
        rowsR.append(vals)
    return rowsR, L


def sum_weights(N, d):
    w = [pow(2, N - 1, P)] * (N * d + 2)
    w[0] = pow(2, N, P)
    w[1] = 1
    return w


def eval_weights(rhos, d):
    w = [1]
    pr = 1
    for r in rhos:
        pr = pr * r % P
    w.append(pr)
    for r in rhos:
        xp = 1
        for _ in range(d):
            xp = xp * r % P
            w.append(xp)
    return w


def cfs_channel():
    out("3. the mask channel: dim ker R and the published functionals")
    regimes = {
        "uniform": lambda N: [rng.randrange(P) for _ in range(N)],
        "all zero": lambda N: [0] * N,
        "all one": lambda N: [1] * N,
        "all equal": lambda N: [rng.randrange(P)] * N,
        "small ints": lambda N: [rng.randrange(2, 9) for _ in range(N)],
    }
    worst = {}
    for label, mk in regimes.items():
        bad_ker = bad_sum = bad_eval = 0
        kers = set()
        for (n, e, d) in BLOCK_SLOTS:
            N = n + e
            rhos = mk(N)
            R, L = cfs_round_matrix(N, d, rhos)
            rk = rank_fp(R, N * (d + 1))
            ker = L - rk
            kers.add(ker)
            if ker != 1:
                bad_ker += 1
            sw = sum_weights(N, d)
            ew = eval_weights(rhos, d)
            # is the functional in the ROW span of R (R's rows are indexed by
            # coefficient, so a functional on coefficients is a COLUMN combination
            # question: is sw in the column space of R^T = row space of R^T?)
            # sw is a vector over coefficients; the published values are the
            # columns of R.  sw in span{columns of R} is the right question.
            cols = [[R[k][c] for k in range(L)] for c in range(N * (d + 1))]
            base = rank_fp(cols, L)
            if rank_fp(cols + [sw], L) != base:
                bad_sum += 1
            if rank_fp(cols + [ew], L) != base:
                bad_eval += 1
        print(f"  rho regime {label:11s}: dim ker R in {sorted(kers)}  "
              f"slots with ker != 1: {bad_ker}/23   "
              f"sum_weights outside span: {bad_sum}   "
              f"eval_weights outside span: {bad_eval}")
        worst[label] = (bad_ker, bad_sum, bad_eval)

    # negative control: drop the last round
    print("  -- negative control: drop the LAST round from R --")
    n, e, d = BLOCK_SLOTS[17]
    N = n + e
    rhos = [rng.randrange(P) for _ in range(N)]
    R, L = cfs_round_matrix(N, d, rhos)
    cols = [[R[k][c] for k in range(L)] for c in range((N - 1) * (d + 1))]
    base = rank_fp(cols, L)
    sw, ew = sum_weights(N, d), eval_weights(rhos, d)
    print(f"    slot 17 (N={N}, d={d}): rank without the last round {base}; "
          f"sum_weights still inside: {rank_fp(cols + [sw], L) == base}; "
          f"eval_weights still inside: {rank_fp(cols + [ew], L) == base}")
    # negative control: publish only d values per round instead of d+1
    print("  -- negative control: only d values per round (X = 0..d-1) --")
    for si in (8, 17):
        n, e, d = BLOCK_SLOTS[si]
        N = n + e
        rhos = [rng.randrange(P) for _ in range(N)]
        R, L = cfs_round_matrix(N, d, rhos)
        keep = [c for c in range(N * (d + 1)) if c % (d + 1) != d]
        sub = [[R[k][c] for c in keep] for k in range(L)]
        print(f"    slot {si} (N={N}, d={d}): dim ker = {L - rank_fp(sub, len(keep))} "
              f"(1 when all d+1 values are published)")


# =====================================================================
#  the Fp-vs-Fp2 question: does full Fp2 row rank imply k0 = 0?
# =====================================================================
def fp_vs_fp2():
    out("2.2/3.7  is the tool's k0 an Fp rank of the realification?  "
        "a two-row counterexample")
    # one Fp2 generator rho = (1, u) with non-data row 0 and data row 1
    rho = [(1, 0), (0, 1)]
    print("  rho = [1, u];  non-data rows = {0}, data rows = {1}")
    print(f"  Fp2 row rank of rho restricted to the non-data rows: "
          f"{rank_f2([[rho[0]]], 1)}  (= G+1 = 1, FULL)")
    gens = [[v[0] for v in rho], [v[1] for v in rho]]
    r1 = rank_fp(gens, 2)
    rnd = rank_fp([[g[0] for g in gens]] if False else [[g[0]] for g in gens], 1)
    print(f"  tool's k0 = rank_Fp(gens) - rank_Fp(gens|non-data) = "
          f"{r1} - {rnd} = {r1 - rnd}")
    print("  => FULL Fp2 row rank on the non-data rows does NOT imply k0 = 0.")
    print("     The event the tool measures is the Fp rank of the REALIFICATION,")
    print("     i.e. the Fp2-independence of {rho_g} TOGETHER WITH their")
    print("     conjugates.  Conjugation is x -> x^p, so Schwartz-Zippel over")
    print("     Fp2 on the (G+1)x(G+1) minor bounds a different event.")


# =====================================================================
# 5.  THE NUMBERS
# =====================================================================
def lg(x):
    return math.log2(x) if x > 0 else float("-inf")


def numbers():
    out("5. the numbers, recomputed")
    p = P
    print("  (B) refusal probability, per proof")
    for prof, (e_draws, lam_draws, c_draws, openings) in {
            "block": (25, 174, 23, 4), "attention": (20, 113, 18, 4)}.items():
        t_e = e_draws * 2 / p ** 2
        t_lam = lam_draws / p ** 2
        t_c = c_draws / p ** 2
        one_prox = (p ** 2 + (p ** 2 - 1) * p) / p ** 4
        t_prox = openings * one_prox
        tot = t_e + t_lam + t_c + t_prox
        print(f"    {prof:10s} e in {{0,1}} 2^{lg(t_e):.2f}   lambda=0 "
              f"2^{lg(t_lam):.2f}   c=0 2^{lg(t_c):.2f}   "
              f"prox wedge 2^{lg(t_prox):.4f}   TOTAL 2^{lg(tot):.4f}")
    print(f"    one proximity opening exactly: 2^{lg((p**2 + (p**2-1)*p)/p**4):.6f}")

    print("  (C) Schwartz-Zippel backstop on the realified minor, over Fp")
    for prof, Gs in {"block": [35, 9, 1, 1], "attention": [30, 8, 1, 1]}.items():
        degs = [6 * G + 2 for G in Gs]
        tot = sum(degs) / p
        print(f"    {prof:10s} degrees {degs}  union 2^{lg(tot):.2f}   "
              f"(x100 slack: 2^{lg(tot * 100):.2f})")
    print("  for comparison, the CHECK's sketch: G_sketch = groups + prox,")
    print("  degree 3 per entry, minor G_sketch x G_sketch, over Fp2:")
    for prof, Gs in {"block": [35, 9, 1, 1], "attention": [30, 8, 1, 1]}.items():
        degs = [3 * (G + 1) for G in Gs]
        tot = sum(degs) / p ** 2
        print(f"    {prof:10s} degrees {degs}  union 2^{lg(tot):.2f}")

    print("  (B') sampler residual on this lemma's own draws, at 2^-96 per draw")
    for prof, n in {"block": 25 + 174 + 23 + 853, "attention": 20 + 113 + 18 + 610}.items():
        print(f"    {prof:10s} {n} draws -> 2^{lg(n * 2 ** -96):.2f}")

    print("  sensitivity: if lambda and e were BASE-field draws")
    for prof, n in {"block": 174 + 50, "attention": 113 + 40}.items():
        print(f"    {prof:10s} {n} such draws -> 2^{lg(n / p):.2f} "
              f"(vs 2^{lg(n / p ** 2):.2f} in Fp2)")


if __name__ == "__main__":
    pad_block_A_H()
    pad_block_M()
    cfs_channel()
    fp_vs_fp2()
    numbers()

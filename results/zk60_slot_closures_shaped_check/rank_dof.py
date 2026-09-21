"""Clause C3 / the CFS covering, recomputed independently — and at DEGENERATE
challenge vectors, which the memo does not test.

R is the map from the L = N*d + 2 mask coefficients to the slot's published
channel (one scalar + N round messages of d+1 values each):

    a  |->  ( <sum_weights(N,d), a> ,  { g_j(0..d) at prev = rho_{<j} }_{j<N} )

ported from `zkp-core/src/sumcheck.rs:205-274` (`CfsMask::a`, `::u`,
`::sum_weights`, `::round`) at lane commit 8c5922b.  The factor c is a nonzero
scalar and is dropped: it does not change a rank.

The memo (ZK60_SLOT_CLOSURES_SHAPED.md §4.1) reports rank R = N*d + 1 and
dim ker R = 1 for 23 slots x 4 shapes at "three independent challenge vectors
each", all random.  `argument.rs:404-406` refuses only the EXTENSION
challenges at 0 and 1; the MAIN round challenges rho_0..rho_{n-1} are refused
at nothing.  So this script asks what happens on the unrefused bad set.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fp2 import F2, ONE, ZERO, Rng, rank, P, inv  # noqa: E402

HALF = F2(inv(2), 0)
LANE = "/home/victor/wt-zk60-block125m/results/zk60_block125m_lane"


def a_idx(j, e, d):
    """CfsMask::a -- coeffs[2 + j*degree + (e-1)]"""
    return 2 + j * d + (e - 1)


def u_col(j, x, d, L):
    """u_j(x) = sum_e a_{j,e} x^e, as a row of coefficients over the L slots."""
    row = [ZERO] * L
    xp = ONE
    for e in range(1, d + 1):
        xp = xp * x
        row[a_idx(j, e, d)] = xp
    return row


def add(r1, r2, s=ONE):
    return [a + s * b for a, b in zip(r1, r2)]


def round_rows(j, prev, N, d, L):
    """CfsMask::round(j, prev) as (d+1) linear functionals of the coefficients."""
    base = [ZERO] * L
    base[0] = ONE
    for i, r in enumerate(prev):
        base = add(base, u_col(i, r, d, L))
    for i in range(j + 1, N):
        base = add(base, u_col(i, ONE, d, L), HALF)
    scale = F2(pow(2, N - 1 - j, P), 0)
    prod_prev = ONE
    for r in prev:
        prod_prev = prod_prev * r
    out = []
    for x in range(d + 1):
        xv = F2(x, 0)
        row = add(base, u_col(j, xv, d, L))
        row = [scale * v for v in row]
        row[1] = row[1] + prod_prev * xv
        out.append(row)
    return out


def sum_weights_row(N, d, L):
    w = [F2(pow(2, N - 1, P), 0)] * L
    w[0] = F2(pow(2, N, P), 0)
    w[1] = ONE
    return w


def R_rows(N, d, rho):
    """The columns of R, as rows of R^T: one row per mask coefficient."""
    L = N * d + 2
    funcs = [sum_weights_row(N, d, L)]
    for j in range(N):
        funcs.extend(round_rows(j, rho[:j], N, d, L))
    # rank of the map a -> (f(a)) is the rank of the matrix whose ROWS are the
    # functionals; that is the same as the rank of R.
    return funcs, L


def chain_ok(N, d, rho, coeffs):
    """Does R(a) satisfy the verifier's chain?  g_0(0)+g_0(1) = total, and
    g_j(0)+g_j(1) = interpolate_eval(g_{j-1}, rho_{j-1})."""
    L = N * d + 2
    ev = lambda row: sum((r * c for r, c in zip(row, coeffs)), ZERO)
    total = ev(sum_weights_row(N, d, L))
    claim = total
    for j in range(N):
        rows = round_rows(j, rho[:j], N, d, L)
        vals = [ev(r) for r in rows]
        if not (vals[0] + vals[1] == claim):
            return False, j
        claim = interp(vals, rho[j])
    return True, None


def chain_ok_wrong_total(N, d, rho, coeffs):
    """Negative control: the same chain with w[1] = 2 instead of 1."""
    L = N * d + 2
    ev = lambda row: sum((r * c for r, c in zip(row, coeffs)), ZERO)
    w = sum_weights_row(N, d, L)
    w[1] = F2(2, 0)
    claim = ev(w)
    for j in range(N):
        rows = round_rows(j, rho[:j], N, d, L)
        vals = [ev(r) for r in rows]
        if not (vals[0] + vals[1] == claim):
            return False, j
        claim = interp(vals, rho[j])
    return True, None


def interp(vals, x):
    """Lagrange evaluation at x over the points 0..len-1 (mle::interpolate_eval)."""
    n = len(vals)
    acc = ZERO
    for i in range(n):
        num, den = ONE, ONE
        for k in range(n):
            if k == i:
                continue
            num = num * (x - F2(k, 0))
            den = den * F2((i - k) % P, 0)
        acc = acc + vals[i] * num * den.inv()
    return acc


def challenge_sets(N, ext, seed):
    """The vectors rho_full = (main challenges, extension challenges) to test.

    The code refuses e in {0, 1} for the EXTENSION coordinates only, so those
    cases are marked 'refused' and reported separately."""
    rng = Rng(seed)
    base = rng.vec(N)
    out = []
    out.append(("random", list(base), False))
    for k in (0, N // 2, N - ext - 1):
        v = list(base)
        v[k] = ZERO
        out.append((f"main rho[{k}] = 0", v, False))
        v = list(base)
        v[k] = ONE
        out.append((f"main rho[{k}] = 1", v, False))
    v = list(base)
    v[1] = v[0]
    out.append(("main rho[1] = rho[0]", v, False))
    v = [base[0]] * N
    out.append(("all main equal", v, False))
    v = [ZERO] * N
    out.append(("all zero", v, False))
    if ext == 2:
        v = list(base)
        v[N - 1] = v[N - 2]
        out.append(("e0 = e1", v, False))
        v = list(base)
        v[N - 2] = ZERO
        out.append(("e0 = 0 (REFUSED by argument.rs:404)", v, True))
        v = list(base)
        v[N - 1] = ONE
        out.append(("e1 = 1 (REFUSED by argument.rs:404)", v, True))
    else:
        v = list(base)
        v[N - 1] = ZERO
        out.append(("e0 = 0 (REFUSED by argument.rs:404)", v, True))
    # all main = 0 but the extension challenges legal
    v = [ZERO] * (N - ext) + list(base[N - ext:])
    out.append(("every main rho = 0, ext legal", v, False))
    return out


def main():
    shapes = {}
    for name in ("toy", "rung_g", "rung_k4", "m125"):
        d = json.load(open(f"{LANE}/model_{name}.json"))
        shapes[name] = [(s["main_rounds"], s["extension_rounds"], s["degree"]) for s in d["slots"]]

    report = {"note": "rank R vs dim C = N*d+1 at shaped (N,d), random and degenerate rho",
              "shapes": {}}
    bad = []
    for sh, slots in shapes.items():
        rows = []
        for s, (m, e, deg) in enumerate(slots):
            N = m + e
            L = N * deg + 2
            want = N * deg + 1
            for label, rho, refused in challenge_sets(N, e, 0x5eed_0000 + 97 * s + 7):
                funcs, _ = R_rows(N, deg, rho)
                r = rank(funcs)
                ok = (r == want)
                rows.append({"slot": s, "N": N, "d": deg, "L": L, "dim_C": want,
                             "rho": label, "rank": r, "ker": L - r, "tight": ok,
                             "refused_by_code": refused})
                if not ok:
                    bad.append((sh, s, N, deg, label, r, want, refused))
        report["shapes"][sh] = rows
    report["failures"] = [{"shape": a, "slot": b, "N": c, "d": d_, "rho": e,
                           "rank": f, "dim_C": g, "refused_by_code": h}
                          for (a, b, c, d_, e, f, g, h) in bad]

    # the chain property on a random coefficient vector, slot 09 at 125M
    N, deg = 13, 3
    rng = Rng(0xC0FFEE)
    rho = rng.vec(N)
    coeffs = rng.vec(N * deg + 2)
    ok, j = chain_ok(N, deg, rho, coeffs)
    report["chain_slot09_m125"] = {"ok": ok, "failed_round": j}

    # ---- controls: does this test have teeth? --------------------------
    ctl = {}
    funcs, L = R_rows(N, deg, rho)
    # (i) the kernel of R: which mask direction is invisible in the channel
    #     (transpose and solve).  rank over the transposed system.
    ctl["slot09_m125_rank"] = rank(funcs)
    ctl["slot09_m125_L"] = L
    # (ii) drop a' (coefficient 1, the prod-of-rho freedom): the CFS mask
    #      without it must NOT cover C.
    cut = [[(ZERO if i == 1 else v) for i, v in enumerate(row)] for row in funcs]
    ctl["rank_without_a_prime"] = rank(cut)
    # (iii) a mask declared at degree d-1 against a slot of degree d: the
    #       covering must fail (this is the under-declaration failure mode).
    f2, L2 = R_rows(N, deg - 1, rho)
    #      embed into the degree-d channel: each round has d+1 entries but the
    #      lower-degree mask only spans a (d)-dim space of them, so compare
    #      rank against the degree-d dim C.
    ctl["rank_mask_degree_minus_1"] = rank(f2)
    ctl["dim_C_degree_d"] = N * deg + 1
    # (iv) the chain with a deliberately wrong sum weight
    bad_ok, bad_j = chain_ok_wrong_total(N, deg, rho, coeffs)
    ctl["chain_with_wrong_total"] = {"ok": bad_ok, "failed_round": bad_j}
    report["controls"] = ctl

    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "rank_dof.json")
    json.dump(report, open(out, "w"), indent=1)

    n = sum(len(v) for v in report["shapes"].values())
    print(f"[COMPUTED] {n} (slot, shape, rho) rank checks; {len(bad)} not tight")
    seen = set()
    for (a, b, c, d_, e, f, g, h) in bad:
        key = (e, h)
        if key not in seen:
            seen.add(key)
        print(f"  NOT TIGHT  shape={a} slot={b:02d} (N,d)=({c},{d_}) rho='{e}' "
              f"rank={f} dim_C={g} refused_by_code={h}")
    print("chain (slot 09 @125M, random a):", report["chain_slot09_m125"])


if __name__ == "__main__":
    main()

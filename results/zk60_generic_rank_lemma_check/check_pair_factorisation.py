#!/usr/bin/env python3
"""INDEPENDENT CHECK of the generic-rank lemma, attack 2 (the factorisation).

Written from scratch by the adversarial checker (2026-09-20).  It does NOT
import the joint-view tool and does not reuse the draft's
`pair_block_identity.py`; `zpart_weights` below is re-implemented from
zkp-core/src/pcs.rs:752-792 by reading, and the ranks/determinants use my
own elimination.

Unlike the draft's evidence, the claim schedule here is the REAL one: the
claims (offset, log_size, coefficient, point) of each of the four captured
role-openings.  What is resampled is the CHALLENGE side: fresh uniform
lambdas per group and a fresh uniform proximity vector per row, so the
factorisation is tested at many challenge vectors, not at the capture's one.

Nothing private is printed: only dimensions, row indices, ranks and
pass/fail counters.
"""

import json
import os
import random
import sys

P = (1 << 64) - (1 << 32) + 1
NR = 7                      # Fp2 = Fp[u]/(u^2 - 7)   (zkp-core/src/field.rs:15)
LOG_COLS = 8
N_COLS = 1 << LOG_COLS

CAPDIR = "/home/victor/IntelligenceRegulation/results/zk60_native_captures_20260919/captures"


# ----------------------------------------------------------------- Fp2
def mul(a, b):
    return ((a[0] * b[0] + NR * a[1] * b[1]) % P, (a[0] * b[1] + a[1] * b[0]) % P)


def add(a, b):
    return ((a[0] + b[0]) % P, (a[1] + b[1]) % P)


ZERO, ONE, U = (0, 0), (1, 0), (0, 1)


def norm(a):
    return (a[0] * a[0] - NR * a[1] * a[1]) % P


def wedge(a, b):
    return (a[0] * b[1] - a[1] * b[0]) % P


def eq_table_msb(point):
    """eq_table_msb: the tensor of (1-x, x) with the FIRST coordinate most
    significant (zkp-core/src/mle.rs).  Length 2^len(point)."""
    t = [ONE]
    for x in point:
        nxt = []
        for v in t:
            nxt.append(mul(v, ((1 - x[0]) % P, (-x[1]) % P)))
            nxt.append(mul(v, x))
        t = nxt
    return t


# ------------------------------------------------- pcs.rs::zpart_weights
def zpart_weights(part, rows):
    rw = [ZERO] * rows
    ls = part["log_size"]
    coef = tuple(part["coefficient"])
    point = [tuple(v) for v in part["point"]]
    off = part["offset"]
    straddle = False
    if not point:
        if ls >= LOG_COLS:
            assert off % N_COLS == 0, "rust assert: offset %% n == 0"
            r0 = off // N_COLS
            for i in range(1 << (ls - LOG_COLS)):
                rw[r0 + i] = add(rw[r0 + i], coef)
            key = ((), 0, N_COLS)
        else:
            r0, c0 = off // N_COLS, off % N_COLS
            straddle = c0 + (1 << ls) > N_COLS       # the rust assert would fire
            rw[r0] = add(rw[r0], coef)
            key = ((), c0, 1 << ls)
    else:
        assert len(point) == ls
        if ls >= LOG_COLS:
            assert off % N_COLS == 0, "rust assert: offset %% n == 0"
            lr = ls - LOG_COLS
            r0 = off // N_COLS
            for i, e in enumerate(eq_table_msb(point[:lr])):
                rw[r0 + i] = add(rw[r0 + i], mul(coef, e))
            key = (tuple(point[lr:]), 0, N_COLS)
        else:
            r0, c0 = off // N_COLS, off % N_COLS
            straddle = c0 + (1 << ls) > N_COLS
            rw[r0] = add(rw[r0], coef)
            key = (tuple(point), c0, 1 << ls)
    return rw, key, straddle


def part_rows(part):
    """protocol.rs::part_rows -- r0 .. r0 + ceil(2^ls / n)."""
    r0 = part["offset"] // N_COLS
    sz = 1 << part["log_size"]
    return list(range(r0, r0 + -(-sz // N_COLS)))


# --------------------------------------------------------- linear algebra
def rank(rows, ncols):
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
        iv = pow(m[r][c], P - 2, P)
        m[r] = [x * iv % P for x in m[r]]
        for i in range(len(m)):
            if i != r and m[i][c] % P:
                f = m[i][c]
                m[i] = [(a - f * b) % P for a, b in zip(m[i], m[r])]
        r += 1
        if r == len(m):
            break
    return r


def det(mat):
    m = [list(r) for r in mat]
    n = len(m)
    d = 1
    for c in range(n):
        piv = None
        for i in range(c, n):
            if m[i][c] % P:
                piv = i
                break
        if piv is None:
            return 0
        if piv != c:
            m[c], m[piv] = m[piv], m[c]
            d = (-d) % P
        d = d * m[c][c] % P
        iv = pow(m[c][c], P - 2, P)
        m[c] = [x * iv % P for x in m[c]]
        for i in range(c + 1, n):
            if m[i][c] % P:
                f = m[i][c]
                m[i] = [(a - f * b) % P for a, b in zip(m[i], m[c])]
    return d


# ------------------------------------------------------------ the roles
def load_roles():
    out = []
    for fn in sorted(os.listdir(CAPDIR)):
        if not fn.endswith(".json"):
            continue
        cap = json.load(open(os.path.join(CAPDIR, fn)))
        prof = "block" if "block" in cap["profile"] else "attention"
        for role in cap["roles"]:
            out.append((fn[:8], prof, role))
    return out


def analyse(role, rng, n_trials, mode="uniform"):
    rows = role["commitment"]["rows"]
    kinds = {r["row"]: r["kind"] for r in role["row_roles"]}
    data_rows = [r for r in range(rows) if kinds[r] == "data"]
    other_rows = [r for r in range(rows) if kinds[r] != "data"]
    prox_rows = [r for r in range(rows) if kinds[r] == "prox"]

    # --- rebuild every claim's row weights and column key, my own grouping
    rws, keys, straddles = [], [], 0
    for cl in role["claims"]:
        rw = [ZERO] * rows
        k0 = None
        for pt in cl["parts"]:
            w, k, st = zpart_weights(pt, rows)
            straddles += int(st)
            if k0 is None:
                k0 = k
            elif k != k0:
                raise SystemExit("parts with different column keys (rust asserts)")
            rw = [add(a, b) for a, b in zip(rw, w)]
        rws.append(rw)
        keys.append(k0)
    groups, order = {}, []
    for ci, k in enumerate(keys):
        if k not in groups:
            groups[k] = []
            order.append(k)
        groups[k].append(ci)
    members = [groups[k] for k in order]

    # --- part_rows vs the true support of the row weights, part by part
    pr_exact = pr_over = pr_under = 0
    for cl in role["claims"]:
        for pt in cl["parts"]:
            w, _, _ = zpart_weights(pt, rows)
            sup = {i for i, v in enumerate(w) if v != ZERO}
            pr = set(part_rows(pt))
            if sup == pr:
                pr_exact += 1
            elif sup < pr:
                pr_over += 1
            else:
                pr_under += 1

    # --- which rows does each claim touch, by kind
    pair_of, touch_bad, on_u, sum_claims = [], 0, 0, 0
    pair_is_cm_cmU = 0
    # the u rows are the layout's declared public linear constraint rows
    u_rows = []
    for plc in role["public_linear_constraints"]:
        u_rows.extend(plc["rows"])
    u_rows = sorted(u_rows)
    mask_rows = sorted(r for r in range(rows) if kinds[r] == "mask")
    site_rows = [r for r in mask_rows if r not in u_rows]

    for ci, rw in enumerate(rws):
        touched = [r for r in other_rows if rw[r] != ZERO]
        if any(r in prox_rows for r in touched):
            touch_bad += 1
        rest = [r for r in touched if r not in u_rows]
        if len(rest) < len(touched):
            on_u += 1
        if not rest and u_rows and set(touched) == set(u_rows):
            sum_claims += 1
            pair = tuple(u_rows)
        elif len(rest) == 2 and rest[1] == rest[0] + 1:
            pair = (rest[0], rest[1])
        else:
            touch_bad += 1
            pair_of.append(None)
            continue
        pair_of.append(pair)
        if rw[pair[1]] == mul(rw[pair[0]], U):
            pair_is_cm_cmU += 1

    shared = len(pair_of) - len({p for p in pair_of if p is not None})

    # --- the factorisation, at fresh challenges
    G = len(members)
    mismatch = det_zero = k0_nonzero = 0
    ranks = set()
    rank_trials = 0
    for trial in range(n_trials):
        def draw():
            if mode == "uniform":
                return (rng.randrange(P), rng.randrange(P))
            if mode == "base":            # lambda in the base field
                return (rng.randrange(P), 0)
            if mode == "imag":            # lambda purely imaginary
                return (0, rng.randrange(P))
            raise ValueError(mode)

        lams = [[draw() for _ in g] for g in members]
        rhos = []
        for gi, g in enumerate(members):
            rho = [ZERO] * rows
            for k, ci in enumerate(g):
                lam = lams[gi][k]
                for i in range(rows):
                    if rws[ci][i] != ZERO:
                        rho[i] = add(rho[i], mul(lam, rws[ci][i]))
            rhos.append(rho)
        prox_rho = [(rng.randrange(P), rng.randrange(P)) for _ in range(rows)]
        gens = []
        for rho in rhos + [prox_rho]:
            gens.append([v[0] for v in rho])
            gens.append([v[1] for v in rho])

        # the chosen square submatrix: one member's pair per group + the prox pair
        cols, want = [], 1
        ok_cols = True
        for gi, g in enumerate(members):
            pr = pair_of[g[0]]
            if pr is None:
                ok_cols = False
                break
            cols += [pr[0], pr[1]]
            want = want * norm(mul(lams[gi][0], rws[g[0]][pr[0]])) % P
        if not ok_cols:
            mismatch += 1
            continue
        p0, p1 = prox_rows[0], prox_rows[1]
        cols += [p0, p1]
        want = want * wedge(prox_rho[p0], prox_rho[p1]) % P
        got = det([[g[c] for c in cols] for g in gens])
        if got != want:
            mismatch += 1
        if got == 0:
            det_zero += 1
        if trial < 2:                      # the full ranks are the expensive part
            rank_trials += 1
            r1 = rank(gens, rows)
            rnd = rank([[g[i] for i in other_rows] for g in gens], len(other_rows))
            ranks.add((r1, rnd))
            if r1 - rnd != 0:
                k0_nonzero += 1

    return {
        "rows": rows, "data": len(data_rows), "nondata": len(other_rows),
        "claims": len(rws), "groups": G, "gens": 2 * (G + 1),
        "u_rows": u_rows, "site_rows": (min(site_rows), max(site_rows)),
        "prox_rows": prox_rows,
        "part_rows_exact": pr_exact, "part_rows_over": pr_over,
        "part_rows_under": pr_under, "straddling_parts": straddles,
        "claims_touching_prox_or_bad": touch_bad,
        "claims_evaluating_u": on_u, "sum_claims": sum_claims,
        "pairs_shared": shared,
        "pair_weights_are_cm_cmU": pair_is_cm_cmU,
        "trials": n_trials, "det_mismatch": mismatch, "det_zero": det_zero,
        "rank_trials": rank_trials,
        "k0_nonzero": k0_nonzero, "(rank,rank|nd)": sorted(ranks),
    }


def main():
    rng = random.Random(0xC4EC)
    trials = int(sys.argv[1]) if len(sys.argv) > 1 else 20
    for tag, prof, role in load_roles():
        for mode in ("uniform",):
            r = analyse(role, rng, trials, mode)
            print(f"=== capture {tag} {prof} role {role['role']} [{mode} lambdas] ===")
            for k, v in r.items():
                print(f"    {k}: {v}")
            sys.stdout.flush()


if __name__ == "__main__":
    main()

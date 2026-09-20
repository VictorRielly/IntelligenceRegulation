#!/usr/bin/env python3
"""INDEPENDENT CHECK, attack 2(b)/(c): adversarial challenge regimes and
negative controls, on the REAL captured claim schedule of the toy block.

The support structure (which rows each claim touches, which pair is whose)
is the capture's.  What is REPLACED is:
  * the lambdas   -- drawn in several regimes (uniform, base field, purely
    imaginary, all equal, lambda = U, one lambda = 0, a whole group zero);
  * the pair weights (cm, cm*U) -- cm redrawn in several regimes (uniform,
    base field, zero real part, cm = U, cm = 0);
  * the proximity vector -- fresh uniform, or with an Fp-dependent pair.
Replacing the pair weights is a MODEL: `build_claim` always writes
(cm, cm*U) there, so only the value of cm is being varied, not the shape.
The data-row weights are left exactly as captured.

Question asked of each regime: does det(chosen 2(G+1) minor) still equal
prod_g Norm(lambda_g cm_g) * wedge(prox pair), and does k0 stay 0?
"""

import json
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from check_pair_factorisation import (  # noqa: E402
    P, U, ZERO, add, mul, norm, wedge, det, rank, zpart_weights, CAPDIR)

rng = random.Random(0x5EED)


def r2():
    return (rng.randrange(P), rng.randrange(P))


def draw(mode):
    if mode == "uniform":
        return r2()
    if mode == "base":
        return (rng.randrange(P), 0)
    if mode == "imag":
        return (0, rng.randrange(P))
    if mode == "isU":
        return U
    if mode == "zero":
        return ZERO
    if mode == "tiny":
        return (rng.randrange(1, 8), rng.randrange(1, 8))
    raise ValueError(mode)


def role_model(role):
    rows = role["commitment"]["rows"]
    kinds = {r["row"]: r["kind"] for r in role["row_roles"]}
    data_rows = [r for r in range(rows) if kinds[r] == "data"]
    other_rows = [r for r in range(rows) if kinds[r] != "data"]
    prox_rows = [r for r in range(rows) if kinds[r] == "prox"]
    u_rows = sorted(x for plc in role["public_linear_constraints"] for x in plc["rows"])
    rws, keys = [], []
    for cl in role["claims"]:
        rw = [ZERO] * rows
        k0 = None
        for pt in cl["parts"]:
            w, k, _ = zpart_weights(pt, rows)
            k0 = k if k0 is None else k0
            rw = [add(a, b) for a, b in zip(rw, w)]
        rws.append(rw)
        keys.append(k0)
    groups, order = {}, []
    for ci, k in enumerate(keys):
        groups.setdefault(k, []) or order.append(k) if k not in groups else None
        groups.setdefault(k, []).append(ci)
    order = []
    seen = set()
    for k in keys:
        if k not in seen:
            seen.add(k)
            order.append(k)
    members = [groups[k] for k in order]
    pair_of = []
    for rw in rws:
        touched = [r for r in other_rows if rw[r] != ZERO]
        rest = [r for r in touched if r not in u_rows]
        if not rest and u_rows and set(touched) == set(u_rows):
            pair_of.append(tuple(u_rows))
        elif len(rest) == 2 and rest[1] == rest[0] + 1:
            pair_of.append((rest[0], rest[1]))
        else:
            pair_of.append(None)
    return rows, data_rows, other_rows, prox_rows, u_rows, rws, members, pair_of


def trial(model, lam_mode="uniform", cm_mode=None, prox_mode="uniform",
          zero_lam=None, zero_cm=None, share_pair=False, equal_lams=False,
          do_rank=True):
    rows, data_rows, other_rows, prox_rows, u_rows, rws0, members, pair_of = model
    rws = [list(r) for r in rws0]
    pair_of = list(pair_of)

    if share_pair:                      # claim 1 is moved onto claim 0's pair
        p0, p1 = pair_of[0], pair_of[1]
        rws[1][p1[0]] = rws[1][p1[1]] = ZERO
        cm = rws[1][p0[0]] if rws[1][p0[0]] != ZERO else r2()
        rws[1][p0[0]] = cm
        rws[1][p0[1]] = mul(cm, U)
        pair_of[1] = p0

    if cm_mode is not None or zero_cm is not None:
        for ci, pr in enumerate(pair_of):
            if pr is None:
                continue
            if zero_cm is not None and ci in zero_cm:
                cm = ZERO
            elif cm_mode is None:
                continue
            else:
                cm = draw(cm_mode)
            rws[ci][pr[0]] = cm
            rws[ci][pr[1]] = mul(cm, U)

    lams = []
    shared_lam = draw(lam_mode)
    for gi, g in enumerate(members):
        ls = []
        for k, ci in enumerate(g):
            if zero_lam is not None and (gi, k) in zero_lam:
                ls.append(ZERO)
            elif zero_lam is not None and ("all", gi) in zero_lam:
                ls.append(ZERO)
            elif equal_lams:
                ls.append(shared_lam)
            else:
                ls.append(draw(lam_mode))
        lams.append(ls)

    rhos = []
    for gi, g in enumerate(members):
        rho = [ZERO] * rows
        for k, ci in enumerate(g):
            lam = lams[gi][k]
            if lam == ZERO:
                continue
            for i in range(rows):
                if rws[ci][i] != ZERO:
                    rho[i] = add(rho[i], mul(lam, rws[ci][i]))
        rhos.append(rho)
    prox_rho = [r2() for _ in range(rows)]
    if prox_mode == "dependent":
        prox_rho[prox_rows[1]] = mul(prox_rho[prox_rows[0]], (rng.randrange(P), 0))
    elif prox_mode == "base":
        prox_rho = [(rng.randrange(P), 0) for _ in range(rows)]

    gens = []
    for rho in rhos + [prox_rho]:
        gens.append([v[0] for v in rho])
        gens.append([v[1] for v in rho])

    cols, want = [], 1
    for gi, g in enumerate(members):
        pr = pair_of[g[0]]
        cols += [pr[0], pr[1]]
        want = want * norm(mul(lams[gi][0], rws[g[0]][pr[0]])) % P
    p0, p1 = prox_rows[0], prox_rows[1]
    cols += [p0, p1]
    want = want * wedge(prox_rho[p0], prox_rho[p1]) % P
    got = det([[g[c] for c in cols] for g in gens])
    out = {"det_matches_product": got == want, "det_zero": got == 0}
    if do_rank:
        r1 = rank(gens, rows)
        rnd = rank([[g[i] for i in other_rows] for g in gens], len(other_rows))
        out["rank_P1"] = r1
        out["rank_on_non_data"] = rnd
        out["k0"] = r1 - rnd
    return out


def main():
    cap = json.load(open(os.path.join(
        CAPDIR,
        "40083e7ac8f3f6c749f12de31ddd9c0e779a016c33fb50180003c60d7cf0716b.json")))
    roles = {r["role"]: r for r in cap["roles"]}
    print(f"profile: {cap['profile']}")
    print()

    for rname in ("H", "A"):
        model = role_model(roles[rname])
        G = len(model[6])
        print(f"### role {rname}: {model[0]} rows, {len(model[5])} claims, "
              f"{G} groups, generators 2(G+1) = {2 * (G + 1)}")
        regimes = [
            ("uniform lambdas, uniform cm", dict()),
            ("lambdas in the BASE field", dict(lam_mode="base")),
            ("lambdas purely IMAGINARY", dict(lam_mode="imag")),
            ("every lambda EQUAL", dict(equal_lams=True)),
            ("every lambda = U", dict(lam_mode="isU")),
            ("cm in the BASE field", dict(cm_mode="base")),
            ("cm with ZERO real part", dict(cm_mode="imag")),
            ("cm = U for every claim", dict(cm_mode="isU")),
            ("cm tiny integers", dict(cm_mode="tiny")),
            ("lambdas base AND cm base", dict(lam_mode="base", cm_mode="base")),
            ("lambdas imag AND cm imag", dict(lam_mode="imag", cm_mode="imag")),
            ("proximity pair Fp-DEPENDENT", dict(prox_mode="dependent")),
            ("proximity vector in the BASE field", dict(prox_mode="base")),
        ]
        for label, kw in regimes:
            reps = 3
            res = [trial(model, do_rank=(i == 0), **kw) for i in range(reps)]
            ok = all(r["det_matches_product"] for r in res)
            dz = sum(r["det_zero"] for r in res)
            print(f"  {label:36s} det==product {str(ok):5s} "
                  f"det_zero {dz}/{reps}  k0 {res[0].get('k0')}")

        print("  -- negative controls (each SHOULD break something) --")
        controls = [
            ("one cm zero (claim 0)", dict(zero_cm={0})),
            ("EVERY cm of group 0 zero", dict(zero_cm=set(model[6][0]))),
            ("one lambda zero (group 0, member 0)", dict(zero_lam={(0, 0)})),
            ("EVERY lambda of group 0 zero", dict(zero_lam={("all", 0)})),
            ("claims 0 and 1 share one reserved pair", dict(share_pair=True)),
        ]
        for label, kw in controls:
            r = trial(model, **kw)
            print(f"  {label:36s} det==product {str(r['det_matches_product']):5s} "
                  f"det_zero {r['det_zero']}  k0 {r['k0']}")
        print()


if __name__ == "__main__":
    main()

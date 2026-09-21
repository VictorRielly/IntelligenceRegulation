#!/usr/bin/env python3
"""Clause C3, COMPUTED at the shaped layouts: for every one of the 23 slots at
every shape, the CFS mask's round map has

    rank R_s = N_s * d_s + 1 = dim C_s      and      dim ker R_s = 1,

and its image lies inside the verifier's consistency subspace C_s.

That is Fact 2.1 of `ZK60_JOINT_LAW_COMPOSITION.md` §2.1 instantiated at the
SHAPED `(main, ext, degree)` of `shape.rs:756-807` — including the two
bilinear slots' new `(N, 3)` and the six or eight slots that gained a degree
from the support indicator. The toy memo proved the identity for every rho;
this recomputes it at the shaped parameters so that no shape constant is
taken on trust.

Ported from `zkp-core/src/sumcheck.rs:189-274` (CfsMask::len, ::sum_weights,
::eval_weights, ::round) at lane commit 8c5922b.

Exact arithmetic over Fp2 = GF(p^2), p = 2^64 - 2^32 + 1. No witness value,
no privacy claim.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fp2 as F
from slot_table import SHAPES, SLOT_NAMES, N_SLOTS

OUT = os.path.dirname(os.path.abspath(__file__))
HALF = pow(2, F.P - 2, F.P)


def mask_len(n_vars, degree):
    """sumcheck.rs:197-199"""
    return n_vars * degree + 2


def sum_weights(n_vars, degree):
    """sumcheck.rs:222-227"""
    w = [F.base(pow(2, n_vars - 1, F.P))] * mask_len(n_vars, degree)
    w = list(w)
    w[0] = F.base(pow(2, n_vars, F.P))
    w[1] = F.ONE
    return w


def eval_weights(rho, degree):
    """sumcheck.rs:230-243"""
    w = [F.ONE]
    p = F.ONE
    for r in rho:
        p = F.mul(p, r)
    w.append(p)
    for r in rho:
        xp = F.ONE
        for _ in range(degree):
            xp = F.mul(xp, r)
            w.append(xp)
    return w


def mask_round(coeffs, n_vars, degree, j, prev):
    """sumcheck.rs:255-274, on an explicit coefficient vector."""
    assert len(prev) == j

    def u(i, x):
        acc = F.ZERO
        xp = F.ONE
        for e in range(1, degree + 1):
            xp = F.mul(xp, x)
            acc = F.add(acc, F.mul(coeffs[2 + i * degree + (e - 1)], xp))
        return acc

    b = coeffs[0]
    for i, r in enumerate(prev):
        b = F.add(b, u(i, r))
    for i in range(j + 1, n_vars):
        b = F.add(b, F.scal(u(i, F.ONE), HALF))
    scale = F.base(pow(2, n_vars - 1 - j, F.P))
    pp = F.ONE
    for r in prev:
        pp = F.mul(pp, r)
    out = []
    for x in range(degree + 1):
        xv = F.base(x)
        out.append(F.add(F.mul(scale, F.add(b, u(j, xv))),
                         F.mul(F.mul(coeffs[1], pp), xv)))
    return out


def round_matrix(n_vars, degree, rho):
    """The columns of R_s: one per mask coefficient, each the concatenation of
    the N round messages of the basis mask."""
    L = mask_len(n_vars, degree)
    cols = []
    for i in range(L):
        c = [F.ZERO] * L
        c[i] = F.ONE
        v = []
        for j in range(n_vars):
            v.extend(mask_round(c, n_vars, degree, j, rho[:j]))
        cols.append(v)
    return cols


def chain_holds(coeffs, n_vars, degree, rho):
    """Im R_s subseteq C_s: r_0(0)+r_0(1) = <sum_weights, a> and
    r_j(0)+r_j(1) = interpolate_eval(r_{j-1}, rho_{j-1})."""
    rounds = [mask_round(coeffs, n_vars, degree, j, rho[:j]) for j in range(n_vars)]
    tot = F.ZERO
    for w, a in zip(sum_weights(n_vars, degree), coeffs):
        tot = F.add(tot, F.mul(w, a))
    if F.add(rounds[0][0], rounds[0][1]) != tot:
        return False, "round 0 does not sum to the mask total"
    for j in range(1, n_vars):
        want = F.interpolate_eval(rounds[j - 1], rho[j - 1])
        if F.add(rounds[j][0], rounds[j][1]) != want:
            return False, "round %d breaks the chain" % j
    # eval_weights is the chain's terminal: g(rho) == interpolate_eval(last, rho[-1])
    gv = F.ZERO
    for w, a in zip(eval_weights(rho, degree), coeffs):
        gv = F.add(gv, F.mul(w, a))
    if gv != F.interpolate_eval(rounds[n_vars - 1], rho[n_vars - 1]):
        return False, "eval_weights is not the chain's terminal"
    return True, ""


def main():
    res = {}
    total_ok = 0
    total_bad = []
    for key, sh in SHAPES.items():
        sl = sh.slots()
        rows = []
        for s in range(N_SLOTS):
            main_r, ext, degree = sl[s]
            n_vars = main_r + ext
            L = mask_len(n_vars, degree)
            per_rho = []
            for seed in (1, 2, 3):
                rng = F.Rng(0x5107 * 1000003 + seed * 7919 + s)
                rho = [rng.fp2_nonzero() for _ in range(n_vars)]
                cols = round_matrix(n_vars, degree, rho)
                r = F.rank_of_columns(cols)
                # a generic mask, and the chain
                a = rng.fp2_vec(L)
                ok, why = chain_holds(a, n_vars, degree, rho)
                per_rho.append({"rank": r, "L": L, "dim_C": n_vars * degree + 1,
                                "kernel": L - r, "chain": ok, "why": why})
            good = all(p["rank"] == n_vars * degree + 1 and p["kernel"] == 1
                       and p["chain"] for p in per_rho)
            total_ok += 1 if good else 0
            if not good:
                total_bad.append((key, s, per_rho))
            rows.append({"slot": s, "name": SLOT_NAMES[s], "N": n_vars,
                         "degree": degree, "L": L, "dim_C": n_vars * degree + 1,
                         "ranks": [p["rank"] for p in per_rho],
                         "kernels": [p["kernel"] for p in per_rho],
                         "chain_all_rho": all(p["chain"] for p in per_rho)})
        res[key] = rows
        print("%-8s: %d slots, rank == N*d+1 and ker == 1 at 3 rho each: %s"
              % (key, N_SLOTS,
                 all(r["ranks"] == [r["dim_C"]] * 3 and r["kernels"] == [1, 1, 1]
                     and r["chain_all_rho"] for r in res[key])))
    print("slots passing at all three rho, over the four shapes: %d of %d"
          % (total_ok, 4 * N_SLOTS))
    for b in total_bad:
        print("  FAIL", b)
    with open(os.path.join(OUT, "mask_dof.json"), "w") as f:
        json.dump({"result": res,
                   "slots_passing": total_ok,
                   "slots_total": 4 * N_SLOTS}, f, indent=1)


if __name__ == "__main__":
    main()

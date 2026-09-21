#!/usr/bin/env python3
"""The non-data block of every commitment KIND of a shaped block and of a
run: `A`, `H` (with its deliberate shared zero-sum pair), the generalised
endpoint (data + 5, one spare row) and the internal boundary
(data + 2*sites + 2).

THE OBJECT.  Per commitment the verifier's blinding generators are the real
and imaginary parts of the `G` group combinations and of the proximity
combination — `2(G+1)` `Fp` row vectors of length `rows`
(`zkp-core/src/pcs.rs:943-966`, realified as
`scripts/zk60_native_jv_pcs.py::_p1_rows` does).  Under `audit_claims`
(`protocol.rs:230-274`) a group's combination is nonzero on the non-data rows
ONLY at its members' own reserved pairs.  The lemma's good event is

    rank_Fp(generators restricted to the non-data rows) = 2(G+1),

which implies `k0 = 0`.  This script computes that rank exactly at every
kind, at the SHAPED counts, and under each perturbation that a refusal
forbids — so that "which refusals are necessary" is a measurement and not an
opinion.

WHAT IS MODELLED AND WHAT IS NOT.  The non-data block is modelled exactly:
one reserved pair per claim with weights `(cm, cm*U)` scaled by that member's
`lambda`, a fresh uniform `Fp2` entry of the proximity combination on every
row, zeros elsewhere.  The DATA-row weights are drawn uniformly, which is
the WORST case for `k0`: `k0 = rank(gens) - rank(gens | non-data)` can only
grow when `rank(gens)` grows, and uniform data weights maximise it.  The
column functionals and the claim values are not in this model; they are in
`bilinear_miniature.py`'s brute force.

**ONE THING THAT IS A RECONSTRUCTION, NOT A COUNT.**  The `A` and `H` cases
distribute each slot's claims over that slot's DECLARED number of opening
groups by an arbitrary rule (the first `ng - 1` alone, the rest together).
The real split is decided by the column keys, which this script does not
derive.  Every RANK verdict below is insensitive to it — each group keeps a
member with its own reserved pair whatever the split — but any COUNT of
singleton groups taken from here is not a fact.  The rigorous lower bound
(15 of 36) is in `shaped_counts.txt`.
"""
from __future__ import annotations
import os, random, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fieldlib import (P, ONE, ZERO, U, f2add, f2mul, norm, wedge, rand_f2,
                      rank_fp, det_fp)

HERE = os.path.dirname(os.path.abspath(__file__))


def build(rows, data_rows, pair_of_claim, group_of_claim, prox_row,
          rng, n_prox_rows=2, zero_cm=None, zero_lambda_group=None,
          dependent_prox=False, extra_group_claims=0):
    """Return the 2(G+1) realified generators as Fp row vectors."""
    ngroups = max(group_of_claim) + 1 if group_of_claim else 0
    rhos = [[ZERO] * rows for _ in range(ngroups)]
    for ci, (g, pr) in enumerate(zip(group_of_claim, pair_of_claim)):
        cm = ZERO if zero_cm == ci else rand_f2(rng)
        lam = ZERO if zero_lambda_group == g else rand_f2(rng)
        lc = f2mul(lam, cm)
        rhos[g][pr] = f2add(rhos[g][pr], lc)
        rhos[g][pr + 1] = f2add(rhos[g][pr + 1], f2mul(lc, U))
        for i in range(data_rows):           # the eq-tensor part, worst case
            rhos[g][i] = f2add(rhos[g][i], f2mul(lam, rand_f2(rng)))
    prox = [rand_f2(rng) for _ in range(rows)]
    if dependent_prox:
        s = (rng.randrange(1, P), 0)
        prox[prox_row + 1] = f2mul(prox[prox_row], s)
    gens = []
    for v in rhos + [prox]:
        gens.append([x[0] for x in v])
        gens.append([x[1] for x in v])
    return gens, prox


def report_case(name, rows, data_rows, pairs, groups, prox_row, n_prox_rows,
                seeds=8, **kw):
    nd = list(range(data_rows, rows))
    res = []
    for s in range(seeds):
        rng = random.Random(90210 + s)
        gens, prox = build(rows, data_rows, pairs, groups, prox_row, rng, **kw)
        full = rank_fp(gens)
        ndr = rank_fp([[r[i] for i in nd] for r in gens])
        res.append((len(gens), len(nd), full, ndr, full - ndr))
    gset = {r[0] for r in res}
    ndset = {r[1] for r in res}
    fullset = sorted({r[2] for r in res})
    ndrset = sorted({r[3] for r in res})
    k0set = sorted({r[4] for r in res})
    return (f"  {name:<56}{list(gset)[0]:>5}{list(ndset)[0]:>6}"
            f"{str(fullset):>10}{str(ndrset):>10}{str(k0set):>8}")


def main():
    L = []
    w = L.append
    w("THE NON-DATA BLOCK, PER COMMITMENT KIND, AT THE SHAPED COUNTS")
    w("field: Goldilocks, Fp2 = Fp[U]/(U^2-7); exact ranks; 8 seeds each")
    w("")
    w(f"  {'case':<56}{'gens':>5}{'nd':>6}{'rank':>10}{'rank|nd':>10}{'k0':>8}")
    w("  " + "-" * 89)

    # ---- the generalised endpoint: data + 5, ONE claim, ONE group --------
    # `endpoint_g.rs:52,140-146`; `protocol.rs:335-348` geometry
    # (rows, data, prox) and `check_endpoint_opening` :355-367.
    for shape, drows in (("rung-G", 4), ("125M", 32)):
        rows = drows + 5
        w(f"  ENDPOINT, {shape}: {drows} data + 5 (pair, prox pair, SPARE)")
        w(report_case("    honest", rows, drows, [drows], [0], drows + 2, 2))
        w(report_case("    proximity pair Fp-DEPENDENT (refused)", rows, drows,
                      [drows], [0], drows + 2, 2, dependent_prox=True))
        w(report_case("    cm = 0 (refused)", rows, drows, [drows], [0],
                      drows + 2, 2, zero_cm=0))
        w(report_case("    lambda = 0 (refused)", rows, drows, [drows], [0],
                      drows + 2, 2, zero_lambda_group=0))
        # the same endpoint WITHOUT its spare row: 4 mask rows, not 5
        w(report_case("    SPARE ROW REMOVED, proximity pair Fp-dependent",
                      drows + 4, drows, [drows], [0], drows + 2, 2,
                      dependent_prox=True))
        w(report_case("    SPARE ROW REMOVED, honest", drows + 4, drows,
                      [drows], [0], drows + 2, 2))
    w("")

    # ---- the internal boundary: data + 2*sites + 2, TWO claims, TWO groups
    # `boundary.rs:178-197`
    for shape, drows in (("rung-G", 4), ("125M", 32)):
        sites = 2
        rows = drows + 2 * sites + 2
        prox = drows + 2 * sites
        pairs = [drows + 2 * s for s in range(sites)]
        w(f"  BOUNDARY, {shape}: {drows} data + 2*{sites} site rows + 2 prox "
          f"= {rows} rows, ZERO slack")
        w(report_case("    honest", rows, drows, pairs, [0, 1], prox, 2))
        w(report_case("    proximity pair Fp-DEPENDENT (refused)", rows, drows,
                      pairs, [0, 1], prox, 2, dependent_prox=True))
        w(report_case("    the two claims in ONE group (refused: group count)",
                      rows, drows, pairs, [0, 0], prox, 2))
        w(report_case("    cm = 0 on one site (refused)", rows, drows, pairs,
                      [0, 1], prox, 2, zero_cm=0))
        w(report_case("    lambda = 0 on one group (refused)", rows, drows,
                      pairs, [0, 1], prox, 2, zero_lambda_group=0))
        w(report_case("    the two claims SHARING one pair (audit refuses)",
                      rows, drows, [drows, drows], [0, 1], prox, 2))
        # ruling M-1's own counterexample: a single proximity ROW
        w(report_case("    ONE proximity ROW instead of a pair (ruling M-1)",
                      drows + 2 * sites + 1, drows, pairs, [0, 1],
                      drows + 2 * sites, 1))
        # a third group where the schedule declares two
        w(report_case("    a THIRD opening group appears (refused: count)",
                      rows, drows, pairs + [drows + 2], [0, 1, 2], prox, 2))
    w("")

    # ---- A at the shaped counts: 36 groups over 122 claims --------------
    # `shape.rs:763-780` a_groups = 36; `layout.rs:1051-1052` rows.
    # The group membership below is the declared per-slot detail of
    # `shaped_counts.txt`; only the SIZES matter to the rank.
    a_members = ([1, 1, 9, 2, 2, 2, 2, 1, 1, 1, 1, 1, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1])
    # 122 claims over 36 groups: the detail sums to 36 groups; distribute the
    # 122 claims over them as the slot table does (sites per slot).
    sites_per_slot = [1, 1, 22, 2, 2, 1, 1, 1, 2, 2, 1, 1, 1, 1, 37, 8, 7, 15,
                      11, 3, 0, 1, 1]
    groups_per_slot = [1, 1, 9, 1, 1, 1, 1, 1, 2, 2, 1, 1, 1, 1, 2, 2, 2, 2, 1,
                       1, 0, 1, 1]
    groups, pairs, gi = [], [], 0
    for ns, ng in zip(sites_per_slot, groups_per_slot):
        if ns == 0:
            continue
        for k in range(ns):
            groups.append(gi + min(k, ng - 1))
            pairs.append(len(pairs))
        gi += ng
    ngroups = max(groups) + 1
    nclaims = len(groups)
    sizes = {}
    for g in groups:
        sizes[g] = sizes.get(g, 0) + 1
    singletons = [c for c in range(nclaims) if sizes[groups[c]] == 1]
    biggest = max(sizes, key=lambda g: sizes[g])
    in_big = [c for c in range(nclaims) if groups[c] == biggest]
    for shape, drows in (("rung-G", 377), ("125M", 5435)):
        rows = drows + 2 * nclaims + 2
        prox = drows + 2 * nclaims
        prs = [drows + 2 * c for c in range(nclaims)]
        w(f"  A, {shape}: {nclaims} claims in {ngroups} groups, {drows} data "
          f"rows, {rows} rows, slack {2*nclaims+2 - 2*(ngroups+1)}")
        w(report_case("    honest", rows, drows, prs, groups, prox, 2, seeds=3))
        w(report_case("    proximity pair Fp-DEPENDENT (refused)", rows, drows,
                      prs, groups, prox, 2, seeds=3, dependent_prox=True))
        w(f"      group sizes: {sorted(sizes.values(), reverse=True)[:6]} … "
          f"({sum(1 for v in sizes.values() if v == 1)} singleton groups of "
          f"{ngroups})")
        w(report_case(f"    cm = 0 on claim {singletons[0]} (a SINGLETON "
                      "group; refused)", rows, drows, prs, groups, prox, 2,
                      seeds=3, zero_cm=singletons[0]))
        w(report_case(f"    cm = 0 on claim {in_big[0]} (a {sizes[biggest]}"
                      "-member group; refused)", rows, drows, prs, groups,
                      prox, 2, seeds=3, zero_cm=in_big[0]))
        break   # the 125M case differs only in data rows; run one
    w("")

    # ---- H: two groups SHARE the zero-sum pair --------------------------
    # `protocol.rs:249-256` lets the sum claim be pairless and cover the
    # zero-sum rows; `argument.rs:1537` has a second claim evaluating the same
    # plane, in a different group.  Modelled with 9 groups, the last two
    # sharing rows (u0, u1).
    for shape, (drows, nsites) in (("rung-G", (468, 52)), ("125M", (7016, 50))):
        ngr = 9
        nd_rows = 2 * nsites + 2 + 2
        rows = drows + nd_rows
        u0 = drows + 2 * nsites
        prox = u0 + 2
        prs = [drows + 2 * c for c in range(nsites)]
        groups = [min(c, ngr - 2) for c in range(nsites)]
        # the sum claim: no pair of its own, covers the u pair, its own group
        prs.append(u0)
        groups.append(ngr - 1)
        w(f"  H, {shape}: {nsites+1} claims in {ngr} groups, the LAST group's "
          f"claim masked by the shared zero-sum pair ({u0},{u0+1})")
        w(report_case("    honest", rows, drows, prs, groups, prox, 2, seeds=3))
        w(report_case("    proximity pair Fp-DEPENDENT (refused)", rows, drows,
                      prs, groups, prox, 2, seeds=3, dependent_prox=True))
        break
    w("")
    w("READING")
    w("  * every honest case reaches rank 2(G+1) on its non-data rows, so "
      "k0 = 0;")
    w("  * where the SLACK (non-data rows minus generators) is zero, a "
      "refusal that")
    w("    the large commitments can absorb becomes load-bearing.  The "
      "BOUNDARY has")
    w("    slack 0 at every shape, and its proximity refusal is therefore "
      "EXACTLY")
    w("    NECESSARY: with an Fp-dependent proximity pair k0 rises.  On `A` "
      "and `H`,")
    w("    with slack in the hundreds, the same perturbation leaves k0 at 0 "
      "— which")
    w("    is what the toy's check found, and it is a fact about the slack, "
      "not")
    w("    about the refusal;")
    w("  * the endpoint's FIFTH (spare) row is what gives it slack 1: remove "
      "it and")
    w("    the dependent proximity pair moves k0 there too.")
    out = "\n".join(L) + "\n"
    sys.stdout.write(out)
    with open(os.path.join(HERE, "boundary_endpoint.txt"), "w") as fh:
        fh.write(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())

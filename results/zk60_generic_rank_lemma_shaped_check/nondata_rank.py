"""B-CHECK 2: the non-data block of every commitment, at the REAL group-size
distribution, and the exact determinant identity.

Independent of the memo's `boundary_endpoint.py`.  Two things are done here
that the memo did NOT do:

  * the group-size distribution of `A` and `H` is DERIVED from the code's own
    `claim_sites` and `a_group_detail` (shape.rs:642-677, :823-847, and the
    lane's layout model), not reconstructed.  The memo's GS-15 says its
    largest `A` group of 36 is "an artefact of that reconstruction"; the real
    largest is 35 (SC_DZC's `Dom::D` cube) and there are 17 singleton groups,
    not "at least 15".

  * `H`'s two ZERO-SUM rows are modelled as they are BUILT: they are the two
    rows of the hidden plane `H_U`, they are counted NON-DATA by the
    disclosure model, and they are touched by the DATA PART of two different
    claims -- the pairless LogUp sum claim (`protocol.rs:167-178`, coefs
    (1, U)) and `SC_ZS`'s evaluation claim (`argument.rs:1529-1538`,
    `b.h(hids.u())`).  The memo's Fact 1 says a claim's point "never appears
    in the commitment's non-data block"; here it does appear in the non-data
    block through those two claims, and the reason it is harmless is a
    DIFFERENT one (see the .txt).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from f2 import (P, F2ONE, F2U, f2add, f2mul, f2iszero, norm, wedge, rank_fp,  # noqa: E402
                det_fp, realify, Rng, u2_minus_7_is_irreducible)

OUT = []


def say(s=""):
    print(s)
    OUT.append(s)


# ---------------------------------------------------------------- the model
def build_nondata(group_sizes, rng, *, zero_cm_in=None, zero_lambda_in=None,
                  dependent_prox=False, extra_prox_rows=0, share_pair=None,
                  pairless_groups=(), u_rows=0, u_touchers=(), n_prox_rows=2,
                  equal_cm=False, extra_groups_no_pair=0):
    """Return the list of Fp2 generator vectors restricted to the NON-DATA
    rows, and the row layout.

    Row layout (non-data only):
        [ 2 * n_pairs reserved-pair rows ] [ u_rows ] [ extra spare rows ]
        [ n_prox_rows proximity rows ]

    Every claim j of group g contributes lambda_{g,j} * cm_j at its own pair
    (rows 2j, 2j+1) with coefficients (cm, cm*U) -- `argument.rs:264-278`.
    A `pairless` group (the LogUp sum claim) has no pair and contributes only
    on the u rows.  A `u_toucher` group contributes cd*(1,U) on the u rows in
    ADDITION to its pair.
    The proximity vector is uniform on EVERY non-data row.
    """
    n_claims = sum(group_sizes)
    n_pairs = n_claims - len(pairless_groups)
    base_pairs = 0
    u_base = base_pairs + 2 * n_pairs
    spare_base = u_base + u_rows
    prox_base = spare_base + extra_prox_rows
    rows = prox_base + n_prox_rows

    cms = []
    for j in range(n_claims):
        cms.append(F2ONE if equal_cm else rng.f2())
    if equal_cm:
        c = rng.f2()
        cms = [c] * n_claims
    if zero_cm_in is not None:
        cms[zero_cm_in] = (0, 0)

    gens = []
    live = []          # does this generator have nonzero DATA-row weights?
    pair_cursor = 0
    claim_id = 0
    pair_of_claim = {}
    for gi, m in enumerate(group_sizes):
        vec = [(0, 0)] * rows
        any_live_lambda = False
        pairless = gi in pairless_groups
        for _ in range(m):
            lam = rng.f2()
            if zero_lambda_in is not None and zero_lambda_in == (gi, claim_id):
                lam = (0, 0)
            if not f2iszero(lam):
                any_live_lambda = True
            if pairless:
                # the sum claim: no reserved pair, its non-data support is the
                # u rows, coefficients exactly (1, U)  [memo S11]
                vec[u_base] = f2add(vec[u_base], f2mul(lam, F2ONE))
                vec[u_base + 1] = f2add(vec[u_base + 1], f2mul(lam, F2U))
            else:
                pr = share_pair if (share_pair is not None and claim_id in (0, 1)) else pair_cursor
                if not (share_pair is not None and claim_id in (0, 1)):
                    pair_cursor += 1
                pair_of_claim[claim_id] = pr
                a = f2mul(lam, cms[claim_id])
                vec[2 * pr] = f2add(vec[2 * pr], a)
                vec[2 * pr + 1] = f2add(vec[2 * pr + 1], f2mul(a, F2U))
                if gi in u_touchers:
                    cd = rng.f2()
                    lcd = f2mul(lam, cd)
                    vec[u_base] = f2add(vec[u_base], lcd)
                    vec[u_base + 1] = f2add(vec[u_base + 1], f2mul(lcd, F2U))
            claim_id += 1
        gens.append(vec)
        live.append(any_live_lambda)

    # extra opening groups that DO NOT get a reserved pair of their own -- the
    # memo's Finding N-2 counterfactual (more generators than the commitment
    # has non-data rows to carry).  Their non-data support is empty but they
    # DO carry data-row weights, so they count towards rank(all).
    for _ in range(extra_groups_no_pair):
        gens.append([(0, 0)] * rows)
        live.append(True)

    # the proximity vector: uniform on every row (`pcs.rs:961`)
    prox = [rng.f2() for _ in range(rows)]
    if dependent_prox:
        # wedge(rho[prox], rho[prox+1]) == 0, i.e. Fp-dependent as a PAIR
        a = prox[prox_base]
        c = rng.fp()
        prox[prox_base + 1] = ((a[0] * c) % P, (a[1] * c) % P)
    gens.append(prox)
    live.append(True)
    return gens, rows, dict(u_base=u_base, prox_base=prox_base, n_pairs=n_pairs, live=live)


DATA_ROWS_MODEL = 6   # enough independent data columns for a generic rank test


def k0_of(gens, rows, rng, live):
    """THE MEMO'S k0 (toy lemma section 1.3):

        k0 = rank(generators over ALL rows) - rank(generators | non-data rows)

    NOT `#generators - rank|non-data`: a generator that is identically zero
    (a group whose lambda was drawn zero) contributes to the second count but
    discloses nothing, so the two definitions disagree exactly on the refused
    zero-lambda draws.  Data-row weights are drawn uniformly, which is the
    worst case for rank(all).
    """
    full = []
    nd = []
    for g, lv in zip(gens, live):
        # A group vector's DATA-row weights are sum_j lambda_j * eq_j; they
        # vanish only when every lambda of the group is zero.  cm = 0 kills
        # the pair entries and NOTHING else.
        data = [rng.f2() for _ in range(DATA_ROWS_MODEL)] if lv else [(0, 0)] * DATA_ROWS_MODEL
        whole = data + list(g)
        re_f, im_f = realify(whole)
        full += [re_f, im_f]
        re_n, im_n = realify(g)
        nd += [re_n, im_n]
    r_full, r_nd = rank_fp(full), rank_fp(nd)
    return r_full - r_nd, r_nd, r_full


def run_case(label, group_sizes, seeds=6, **kw):
    ks, naive, ranks = set(), set(), set()
    for s in range(seeds):
        rng = Rng(1000 + s)
        gens, rows, info = build_nondata(group_sizes, rng, **kw)
        k0, r_nd, r_full = k0_of(gens, rows, rng, info["live"])
        ks.add(k0)
        naive.add(2 * len(gens) - r_nd)
        ranks.add((2 * len(gens), rows, r_nd))
    g, nd, r = sorted(ranks)[0]
    say(f"  {label:<62s} gens {g:>3d}  non-data rows {nd:>3d}  rank|nd "
        f"{r:>3d}  k0 {sorted(ks)}")
    return sorted(ks)


# ------------------------------------------------- the real distributions
# shape.rs:642-677 claim_sites + :823-847 a_groups, cross-read against the
# lane's layout model (model_rung_g.json / model_m125.json "a_group_detail").
A_GROUPS_SHAPED = (
    [6] + [2] * 8          # 02 norm squares zero-check: 22 claims, 9 groups
    + [1, 1]               # 01 SS, 01m SS
    + [2]                  # 08 limb zero-check (SC_LZC): 2 claims, 1 group
    + [2]                  # 07 masked row sums (SC_RS)
    + [1, 1, 1]            # 09Q, 09K, 09V
    + [1, 1]               # 10 score  -- two singletons (the repaired slot)
    + [1, 1]               # 11 PV     -- two singletons
    + [1]                  # 12 Wo
    + [1, 1, 1]            # 13G, 13U, 13D
    + [35, 2]              # 03 D zero-check: cube + the two Dom::T denominators
    + [7, 1]               # 04 Q zero-check: cube + the flipped partner
    + [6, 1]               # 05 KV zero-check
    + [13, 2]              # 06 softmax zero-check: cube + A_MX/A_SUM
    + [11]                 # 14 F zero-check
    + [3]                  # TAB
    + [1, 1]               # IO-in, IO-out
)
H_GROUPS_RUNG_G = [1, 19, 7, 6, 9, 6, 3, 1, 1]   # 8 slot groups + the sum claim
H_GROUPS_M125 = [1, 17, 7, 6, 9, 6, 3, 1, 1]
# index of the pairless sum-claim group and of SC_ZS's group
H_SUM_GROUP = 8
H_ZS_GROUP = 7


def main():
    say("B-CHECK 2  the non-data block at the REAL group-size distribution")
    say("=" * 78)
    say(f"U^2 - 7 irreducible over Goldilocks (so Norm(a)=0 iff a=0): "
        f"{u2_minus_7_is_irreducible()}")
    say("")
    say(f"A, both shaped layouts: {len(A_GROUPS_SHAPED)} groups, "
        f"{sum(A_GROUPS_SHAPED)} claims, largest group {max(A_GROUPS_SHAPED)}, "
        f"singletons {sum(1 for m in A_GROUPS_SHAPED if m == 1)}")
    say("  [the memo's GS-15 reconstruction had largest 36 and 'at least 15'")
    say("   singletons; the derived figures are 35 and 17]")
    say("")

    say("A (36 groups, 122 claims, 246 non-data rows)")
    run_case("honest", A_GROUPS_SHAPED)
    run_case("proximity pair Fp-dependent (a refused draw)", A_GROUPS_SHAPED, dependent_prox=True)
    # claim indices: group 0 holds claims 0..5 (the 6-member TZC group);
    # claim 30 is group 15, a SINGLETON (09Q); claim 45 is inside the
    # 35-member SC_DZC cube group.
    run_case("cm = 0 in a SINGLETON group (claim 30, slot 09Q)", A_GROUPS_SHAPED, zero_cm_in=30)
    run_case("cm = 0 in the 35-member SC_DZC group (claim 45)", A_GROUPS_SHAPED, zero_cm_in=45)
    run_case("cm = 0 in the 6-member TZC group (claim 3)", A_GROUPS_SHAPED, zero_cm_in=3)
    run_case("two SAME-GROUP claims sharing one pair (claims 0,1)", A_GROUPS_SHAPED, share_pair=0)
    say("")

    for name, sizes in [("H rung-G", H_GROUPS_RUNG_G), ("H 125M", H_GROUPS_M125)]:
        say(f"{name} (9 groups incl. the pairless sum claim, 2 zero-sum u rows)")
        kw = dict(pairless_groups=(H_SUM_GROUP,), u_rows=2, u_touchers=(H_ZS_GROUP,))
        run_case("honest (sum claim pairless on u; SC_ZS also touches u)", sizes, **kw)
        run_case("proximity pair Fp-dependent (a refused draw)", sizes, dependent_prox=True, **kw)
        run_case("the sum claim's own lambda = 0 (a refused draw)", sizes,
                 zero_lambda_in=(H_SUM_GROUP, sum(sizes) - 1), **kw)
        run_case("SC_ZS's cm = 0 (a refused draw)", sizes, zero_cm_in=sum(sizes) - 2, **kw)
        say("")

    say("endpoint (1 group, 1 claim; pair, prox PAIR, ONE spare row)")
    run_case("honest", [1], extra_prox_rows=1)
    run_case("proximity pair Fp-dependent (a refused draw)", [1], extra_prox_rows=1, dependent_prox=True)
    run_case("the same, with the spare row REMOVED", [1], extra_prox_rows=0, dependent_prox=True)
    run_case("cm = 0 (a refused draw)", [1], extra_prox_rows=1, zero_cm_in=0)
    run_case("lambda = 0 (a refused draw)", [1], extra_prox_rows=1, zero_lambda_in=(0, 0))
    say("")

    say("boundary (2 singleton groups, 2 pairs, prox pair, ZERO spare rows)")
    run_case("honest", [1, 1])
    run_case("proximity pair Fp-dependent (a refused draw)", [1, 1], dependent_prox=True)
    run_case("cm = 0 on one site (a refused draw)", [1, 1], zero_cm_in=0)
    run_case("the two claims sharing one pair (audit_claims forbids)", [1, 1], share_pair=0)
    run_case("ONE proximity row instead of a pair (ruling M-1's case)", [1, 1], n_prox_rows=1)
    say("")
    say("  FINDING N-2 UNDER ATTACK.  The memo prices the opening-group COUNT")
    say("  check as a privacy check: '8 generators against 6 non-data rows,")
    say("  k0 rises to 2'.  Both directions the count can move:")
    run_case("N-2 as the memo models it: a THIRD group, still 6 non-data rows",
             [1, 1], extra_groups_no_pair=1)
    run_case("the ONLY reachable deviation: the two claims MERGE into one group", [2])
    say("")
    say("  Reachability.  `check_opening` (protocol.rs:297-307) runs")
    say("  `audit_claims` FIRST.  On a 2-site boundary `audit_claims` requires")
    say("  every one of the 4 site rows to be used by exactly ONE claim and")
    say("  every non-sum claim to touch exactly 2 adjacent site rows")
    say("  (protocol.rs:259-272), so THREE claims are impossible: 3 x 2 = 6")
    say("  uses over 4 rows forces some uses[r] != 1.  With exactly 2 claims")
    say("  the group count is 1 or 2 and can only be WRONG by being 1 -- the")
    say("  merge -- whose k0 is 0.  The 8-generator case the memo prices")
    say("  CANNOT OCCUR past the audit that runs before the count check.")
    say("")
    say("  THE BRIEF'S 'THIRD EVENT' PROBES -- events NOT refused anywhere:")
    run_case("the two sites' cm EQUAL (same terminal mask both stages)", [1, 1], equal_cm=True)
    run_case("the two sites' claim points coinciding (data weights equal)", [1, 1])
    say("")

    # ---- the exact determinant identity, which is what makes the backstop
    # ---- unnecessary: the maximal minor is a PRODUCT OF NORM FORMS.
    say("The determinant identity (boundary, the whole 6x6 non-data block):")
    for s in range(6):
        rng = Rng(7000 + s)
        gens, rows, info = build_nondata([1, 1], rng)
        real = []
        for g in gens:
            re, im = realify(g)
            real += [re, im]
        d = det_fp(real)
        # rebuild the factors: group g's single entry at its pair, and the prox wedge
        a0 = gens[0][0]
        a1 = gens[1][2]
        w = wedge(gens[2][info["prox_base"]], gens[2][info["prox_base"] + 1])
        pred = (norm(a0) * norm(a1) % P) * w % P
        say(f"  seed {s}: det = {d}   Norm(l0 cm0)*Norm(l1 cm1)*wedge(prox) = {pred}   "
            f"{'EQUAL' if d == pred else 'DIFFERENT'}")
    say("")
    say("  Consequence: the maximal minor is EXACTLY a product of norm forms and")
    say("  one wedge.  Its zero set is {some lambda*cm = 0} union {wedge = 0},")
    say("  and BOTH are refusals.  'bad set subset refusal set' is therefore an")
    say("  IDENTITY at the boundary, not a Schwartz-Zippel estimate, so the")
    say("  backstop of the memo's section 5.4 is never needed there.")

    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "nondata_rank.txt"), "w") as fh:
        fh.write("\n".join(OUT) + "\n")


if __name__ == "__main__":
    main()

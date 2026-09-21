#!/usr/bin/env python3
"""The refusal inventory of a SHAPED block and of a run, the input-dependent
LogUp term with a DISTINCT-VALUE refinement, and the Schwartz-Zippel backstop
degrees.  Exact rational arithmetic; every figure printed in bits.

SOURCES (lane `zk60-private-block-125m` @ `e6b612f`)
  challenge refusals, by name and line:
    `argument.rs:333`  zero CFS mask challenge            (one `c_s` per slot)
    `argument.rs:405`  degenerate terminal mask challenge (`e in {0,1}`, one
                       per extension round)
    `argument.rs:767`  zero batching challenge            (`nu`, and `zeta`
                       where the pad rule fires)
    `protocol.rs:246`  zero terminal mask coefficient     (`cm != 0`, re-tested
                       from the constructed claim, prover AND verifier)
    `protocol.rs:285`  zero group member coefficient      (`lambda != 0`, one
                       per claim per opening)
    `protocol.rs:290`  dependent proximity mask coefficients (one per opening)
    `protocol.rs:303`  the opening-group COUNT differs from the schedule
    `protocol.rs:403`  zero LogUp denominator             (input-dependent)
  counts: `./model/model_*.json` (the lane's own shape-driven layout model).
"""
from __future__ import annotations
import json, math, os, sys
from fractions import Fraction

HERE = os.path.dirname(os.path.abspath(__file__))
MODEL = os.path.join(HERE, "model")
P = (1 << 64) - (1 << 32) + 1
P2 = P * P
RUST_ENDPOINT_ROWS = {"toy": 7, "rung_g": 9, "m125": 37}
U8_LEN = 256


def bits(fr: Fraction) -> str:
    if fr == 0:
        return "0"
    return f"2^{math.log2(fr.numerator) - math.log2(fr.denominator):.2f}"


def wedge_zero_prob() -> Fraction:
    """a, b uniform in Fp2: wedge(a,b) = 0 iff the two Fp-vectors are
    Fp-dependent.  Count: a = 0 (p^2 b's) or a != 0 (p b's on its line)."""
    return Fraction(P2 + (P2 - 1) * P, P2 * P2)


def load(name):
    return json.load(open(os.path.join(MODEL, f"model_{name}.json")))


def block_inventory(name, zeta_sites):
    m = load(name)
    r, og, ss = m["rows"], m["opening_groups"], m["slot_summary"]
    e_rows = RUST_ENDPOINT_ROWS[name]
    a_claims, h_claims = r["a_sites"], r["h_sites"] + 1
    openings = [("A", a_claims, r["a_rows"]), ("H", h_claims, r["h_rows"]),
                ("Input", 1, e_rows), ("Output", 1, e_rows)]
    ext = ss["extension_round_total"]
    slots = ss["count"]
    terms = {}
    # e in {0, 1}: two bad values per extension round, each uniform in Fp2
    terms["terminal mask e in {0,1}"] = Fraction(2 * ext, P2)
    terms["CFS multiplier c_s = 0"] = Fraction(slots, P2)
    terms["nu = 0 (5 sites x 2)"] = Fraction(10, P2)
    terms[f"zeta = 0 ({zeta_sites} pad-zero hosts)"] = Fraction(zeta_sites, P2)
    lam = sum(c for _, c, _ in openings)
    terms[f"PCS lambda = 0 ({lam} draws)"] = Fraction(lam, P2)
    terms[f"proximity pair Fp-dependent ({len(openings)} openings)"] = \
        len(openings) * wedge_zero_prob()
    pairs = sum(c * (c - 1) // 2 for _, c, _ in openings)
    terms[f"an accidental column-key collision ({pairs} claim pairs)"] = \
        Fraction(pairs, P2)
    prox_draws = sum(rw for _, _, rw in openings)
    draws = dict(lambdas=lam, proximity=prox_draws,
                 sumcheck=ss["sumcheck_challenge_draws"],
                 extension=ext, cfs=slots, nu=10, zeta=zeta_sites, tags=3)
    return m, terms, draws, openings


def logup_terms(name):
    """Raw count, then the DISTINCT-VALUE refinement.

    The prover inverts, per block:
      * one denominator `alpha - (v + gamma*TAG_U8)` per byte-lookup position
        (`protocol.rs:691`).  An honest witness's `v` is a byte, so the ARGUMENT
        ranges over at most 256 values however many positions there are.
      * one `alpha - (d + beta*e + gamma*TAG_EXP)` per `Dom::S` position
        (`:701`).  An honest witness's `(d, e)` is a row of the 256-entry
        exponential table, so again at most 256 values.
      * one `alpha - (i + beta*a + gamma*TAG_ACT)` per `Dom::F` position
        (`:703`), the same with the 256-entry activation table.
      * one per table row of each of the three tables (`:734`), whose values
        are `x % U8_LEN`-indexed (`argument.rs:870-872, 881-883`) and so are
        the SAME at most 256 values per tag, adding nothing new.
    `alpha` is drawn AFTER the `A` and `M` roots (`protocol.rs:682-684`), so
    the arguments are fixed before it; the bad event is `alpha` landing in a
    set of at most 3 * 256 values of Fp2.
    """
    m = load(name)
    lk = m["lookups"]
    # CORRECTED 2026-09-21 (ruling S-4, the check's B-5): the three table
    # helpers are inverted over `table_values_*_at(Dom::Tab.len(), ...)`, and
    # `Dom::Tab.len()` is `1 << domain_log_at(8, true, LOG_N)` with `LOG_N` the
    # toy's 8 (`layout.rs:48`, `:194-199` on the lane at `79f0726`; the prover
    # inverts those 256 values per table at `protocol.rs:905-907` and only then
    # tiles them to the shape's width) -- 256 at EVERY shape, not the shape's
    # padded table width.  The first version of this script used the padded
    # width (3,072 at rung-G, 49,152 at 125M).
    tab = U8_LEN
    raw = lk["u8_total"] + lk["exp_pairs"] + lk["act_pairs"] + 3 * tab
    distinct = 3 * U8_LEN
    return raw, distinct, dict(u8=lk["u8_total"], exp=lk["exp_pairs"],
                               act=lk["act_pairs"], table_rows=3 * tab)


def sz_backstop(name):
    """The realified maximal minor is 2(G+1) square with entries of degree at
    most `1 + ext_of_the_slot <= 3` on the group rows and 1 on the proximity
    rows, over **Fp** (realification is Fp-linear, not Fp2-linear).  Degree
    <= 3*2G + 1*2 = 6G + 2; Schwartz-Zippel gives degree / p.
    """
    m = load(name)
    og = m["opening_groups"]
    out = {}
    for role, G in (("A", og["a_groups"]), ("H", og["h_groups"]),
                    ("endpoint", 1), ("boundary", 2)):
        out[role] = dict(minor=2 * (G + 1), degree=6 * G + 2,
                         prob=Fraction(6 * G + 2, P))
    return out


def main():
    L = []
    w = L.append
    w("REFUSALS, THE INPUT-DEPENDENT TERM, AND THE BACKSTOP, AT THE SHAPED "
      "LAYOUTS")
    w("Goldilocks p = 2^64 - 2^32 + 1; every challenge is drawn from Fp2 "
      "(|Fp2| = p^2).")
    w(f"Pr[wedge(a,b) = 0] for a, b uniform in Fp2 = "
      f"(p^2 + (p^2-1)p)/p^4 = {bits(wedge_zero_prob())}")
    w("")
    # the zeta hosts: one per PADDED domain that has at least one zero-rule
    # `A` plane, collapsed to distinct HOST SLOTS (`pad.rs:347-359`,
    # `argument.rs:934`).  At rung-G all nine domains pad; at 125M six do.
    zeta = {"toy": 0, "rung_g": 8, "m125": 5}
    per_block = {}
    for name in ("toy", "rung_g", "m125"):
        m, terms, draws, openings = block_inventory(name, zeta[name])
        per_block[name] = (terms, draws, openings)
        w("=" * 78)
        w(f"{name}: ONE BLOCK — challenge-only refusals (liveness, not "
          "privacy)")
        w(f"  {'term':<56}{'probability':>18}")
        tot = Fraction(0)
        for k, v in terms.items():
            tot += v
            w(f"  {k:<56}{bits(v):>18}")
        w(f"  {'TOTAL per block':<56}{bits(tot):>18}")
        w(f"  openings: " + ", ".join(f"{n} ({c} claims, {rw} rows)"
                                      for n, c, rw in openings))
        w(f"  challenge draws that enter this lemma: {draws}  "
          f"(total {sum(draws.values())})")
        raw, dist, parts = logup_terms(name)
        w("")
        w(f"  input-dependent refusal INSIDE the argument (zero LogUp "
          f"denominator):")
        w(f"    raw count of inversions {raw:,}  = u8 {parts['u8']:,} + exp "
          f"{parts['exp']:,} + act {parts['act']:,} + table rows "
          f"{parts['table_rows']:,}")
        w(f"      -> {bits(Fraction(raw, P2))} per block   [the figure ruling "
          "R-6 carries]")
        w(f"    DISTINCT denominator ARGUMENTS, honest witness: at most "
          f"{dist} (3 tags x {U8_LEN} table rows)")
        w(f"      -> {bits(Fraction(dist, P2))} per block   [the refinement]")
        w(f"    the refinement is worth "
          f"{math.log2(raw/dist):.1f} bits at this shape")
        w("")
        sz = sz_backstop(name)
        w("  Schwartz-Zippel backstop, if a structural step is rejected "
          "(over Fp):")
        for role, d in sz.items():
            w(f"    {role:<10} minor {d['minor']:>3} x {d['minor']:<3} "
              f"degree {d['degree']:>4}   {bits(d['prob'])}")
        blk = sum(d["prob"] for d in (sz["A"], sz["H"])) + 2 * sz["endpoint"]["prob"]
        w(f"    union over one block's four openings: {bits(blk)}")
        w("")

    # ---------------------------------------------------------------- run
    Ls = 12
    mm = load("m125")
    e_rows = RUST_ENDPOINT_ROWS["m125"]
    a_claims, h_claims = mm["rows"]["a_sites"], mm["rows"]["h_sites"] + 1
    b_rows = (mm["shape"]["t_pad"] * mm["shape"]["d_pad"]) >> mm["shape"]["endpoint_log_n"]
    b_rows = b_rows + 2 * 2 + 2
    run_openings = ([("A", a_claims, mm["rows"]["a_rows"])] * Ls +
                    [("H", h_claims, mm["rows"]["h_rows"])] * Ls +
                    [("boundary", 2, b_rows)] * (Ls - 1) +
                    [("endpoint", 1, e_rows)] * 2)
    w("=" * 78)
    w(f"A RUN OF L = {Ls} BLOCKS AT 125M")
    rt = {}
    ss = mm["slot_summary"]
    rt["terminal mask e in {0,1}"] = Fraction(2 * ss["extension_round_total"] * Ls, P2)
    rt["CFS multiplier c_s = 0"] = Fraction(ss["count"] * Ls, P2)
    rt["nu = 0"] = Fraction(10 * Ls, P2)
    rt["zeta = 0"] = Fraction(zeta["m125"] * Ls, P2)
    lam = sum(c for _, c, _ in run_openings)
    rt[f"PCS lambda = 0 ({lam} draws)"] = Fraction(lam, P2)
    rt[f"proximity pair Fp-dependent ({len(run_openings)} openings = 3L+1)"] = \
        len(run_openings) * wedge_zero_prob()
    pairs = sum(c * (c - 1) // 2 for _, c, _ in run_openings)
    rt[f"an accidental column-key collision ({pairs} claim pairs)"] = \
        Fraction(pairs, P2)
    tot = Fraction(0)
    w(f"  {'term':<56}{'probability':>18}")
    for k, v in rt.items():
        tot += v
        w(f"  {k:<56}{bits(v):>18}")
    w(f"  {'TOTAL per run (liveness)':<56}{bits(tot):>18}"
      "   [ruling R-6: 2^-58.8]")
    raw, dist, parts = logup_terms("m125")
    w("")
    w(f"  input-dependent refusal inside the argument, {Ls} blocks with "
      "independent alpha:")
    w(f"    raw      {Ls*raw:,}  ->  {bits(Fraction(Ls*raw, P2))}"
      "    [ruling R-6: 2^-97.8]")
    w(f"    refined  {Ls*dist:,}  ->  {bits(Fraction(Ls*dist, P2))}"
      f"    [worth {math.log2(raw/dist):.1f} bits]")
    w("")
    sz = sz_backstop("m125")
    run_sz = Ls * (sz["A"]["prob"] + sz["H"]["prob"]) + \
        (Ls - 1) * sz["boundary"]["prob"] + 2 * sz["endpoint"]["prob"]
    w(f"  Schwartz-Zippel backstop over the whole run: {bits(run_sz)}")
    w("")
    w("  the key-collision constraint counts of the two BILINEAR slots "
      "(shared coordinates")
    w("  make part of a collision AUTOMATIC, so they are the closest pair on "
      "`A`):")
    for name in ("rung_g", "m125"):
        mm2 = load(name)
        sh = mm2["shape"]
        lt = (sh["t_pad"] - 1).bit_length()
        lh = (sh["h_pad"] - 1).bit_length()
        ldh = (sh["head_dim"] - 1).bit_length()
        lkv = (sh["kv_heads"] - 1).bit_length()
        lc = sh["log_cols"]
        # SC_SCORE
        cq = [("r_t", i) for i in range(lt)] + [("rg", i) for i in range(lkv)] \
            + [("r_hj", i) for i in range(lh - lkv)] + [("rd", i) for i in range(ldh)]
        ck = [("r_j", i) for i in range(lt)] + [("rg", i) for i in range(lkv)] \
            + [("rd", i) for i in range(ldh)]
        tq, tk = cq[len(cq) - lc:], ck[len(ck) - lc:]
        diff_s = sum(1 for a, b in zip(tq, tk) if a != b)
        # SC_PV
        cp = [("rg", i) for i in range(lkv)] + [("r_hj", i) for i in range(lh - lkv)] \
            + [("r_t", i) for i in range(lt)] + [("rt2", i) for i in range(lt)]
        cv = [("rt2", i) for i in range(lt)] + [("rg", i) for i in range(lkv)] \
            + [("r_i", i) for i in range(ldh)]
        tp, tv = cp[len(cp) - lc:], cv[len(cv) - lc:]
        diff_p = sum(1 for a, b in zip(tp, tv) if a != b)
        w(f"    {name:<8} SC_SCORE: {diff_s} of {lc} tail positions differ -> "
          f"collision {bits(Fraction(1, P**(2*diff_s)))}")
        w(f"    {name:<8} SC_PV   : {diff_p} of {lc} tail positions differ -> "
          f"collision {bits(Fraction(1, P**(2*diff_p)))}")
    out = "\n".join(L) + "\n"
    sys.stdout.write(out)
    with open(os.path.join(HERE, "refusals_and_backstop.txt"), "w") as fh:
        fh.write(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())

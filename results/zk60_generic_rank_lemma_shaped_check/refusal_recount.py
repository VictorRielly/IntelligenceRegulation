"""B-CHECK 3: the refusal inventory recounted, and Finding N-3 re-derived
from the code rather than from the memo.

Everything here is COUNTED from:
  protocol.rs:402-405 (`inverses`, the one checked inversion in the module)
  protocol.rs:682-704  (beta, gamma, alpha; the u8 / exp / act denominators)
  protocol.rs:728-737  (the three TABLE helpers)
  argument.rs:854-883  (`table_values_*_at`, built from `i % U8_LEN`)
  layout.rs:59 U8_LEN = 256, layout.rs:136-165 `Dom::Tab.len()`
  layout.rs:561-571 `byte` / `scaled` / `sym`
  witness.rs:290,374,386,394,534,555,600,640,672,708 (the range refusals)
plus the lane's own layout model for the per-domain position counts.
"""
import math
import os

OUT = []


def say(s=""):
    print(s)
    OUT.append(s)


P = (1 << 64) - (1 << 32) + 1
P2 = P * P


def bits(x):
    """-log2(x) for a probability given as a rational count/modulus."""
    return -math.log2(x)


def pr_count(n, mod=P2):
    return n / mod


MODEL = "/home/victor/IntelligenceRegulation/results/zk60_generic_rank_lemma_shaped/model"


def load(name):
    import json
    with open(os.path.join(MODEL, f"model_{name}.json")) as f:
        return json.load(f)


def main():
    say("B-CHECK 3  the refusal inventory, and Finding N-3 recounted")
    say("=" * 78)
    say("")
    say("A. WHAT IS ACTUALLY INVERTED (the only checked inversion in the module")
    say("   is `inverses` at protocol.rs:402-405; its four live call sites are")
    say("   :691, :702, :704, :734 -- the memo cites ':703', which builds the")
    say("   activation denominators; the inversion is on the next line).")
    say("")
    U8_LEN = 256
    DOM_TAB_LEN = 256        # layout.rs:163-165, 1 << domain_log_at(8, true, LOG_N=8)
    for name, label in [("toy", "toy"), ("rung_g", "rung-G"), ("m125", "125M")]:
        d = load(name)
        u8 = d["lookups"]["u8_total"]
        exp = d["lookups"]["exp_pairs"]
        act = d["lookups"]["act_pairs"]
        log_cols = d["shape"]["log_cols"]
        memo_table_rows = 3 * (1 << log_cols)
        real_table_rows = 3 * DOM_TAB_LEN
        say(f"   {label:<7s} u8 {u8:>12,}  exp {exp:>10,}  act {act:>10,}  "
            f"table rows: memo {memo_table_rows:>7,}  CODE {real_table_rows:>5,}")
        raw_memo = u8 + exp + act + memo_table_rows
        raw_code = u8 + exp + act + real_table_rows
        say(f"           raw total: memo {raw_memo:>12,} (2^-{bits(pr_count(raw_memo)):.2f})   "
            f"code {raw_code:>12,} (2^-{bits(pr_count(raw_code)):.2f})")
    say("")
    say("   >>> B-FINDING. The memo prices the three TABLE helpers at")
    say("   `3 x row width` (3,072 at rung-G, 49,152 at 125M).  The code")
    say("   inverts `table_values_*(...)` which is `table_values_*_at(")
    say("   Dom::Tab.len(), ...)` -- and `Dom::Tab.len()` (layout.rs:163) is")
    say("   the TOY's 256, not `sh.size(Dom::Tab)`.  So the table-helper term")
    say("   is 3 x 256 = 768 at EVERY shape.  The raw figure moves by less")
    say("   than 0.01 bit, so this is an erratum, not a finding of substance;")
    say("   but it also means the lift argument the memo gives for N-3 is not")
    say("   needed for the table families -- they never grow in the first")
    say("   place.")
    say("")
    say("B. FINDING N-3 RE-DERIVED.  alpha is drawn at protocol.rs:684, AFTER")
    say("   beta (:682) and gamma (:683) and after the A and M roots, so")
    say("   conditioned on the transcript so far the whole set of denominator")
    say("   ARGUMENTS is fixed and alpha is uniform on Fp2 (the memo's own")
    say("   wording omits that beta and gamma are also conditioned on -- it")
    say("   matters, because two of the three families' arguments contain")
    say("   beta).  The bad event is exactly `alpha in S`.")
    say("")
    say("   S, family by family, for any witness `Witness::new` admits:")
    say("     u8       alpha - (v + gamma*TAG_U8),   v = cst + sum c_p plane_p")
    say("              `byte(p)`   -> v = p        in [0,256) by witness.rs")
    say("              `scaled(p,k)`-> v = k*p     in [0,256) (byte(p) also present)")
    say("              `sym(p)`    -> v = p+127 and 127-p, in [0,256) for p in [-127,127]")
    say("              at a PADDED position every non-exempt plane is 0 (ruling P-1)")
    say("              so v = cst, which is 0 or 127 -- still a byte.")
    say(f"              => at most {U8_LEN} distinct arguments")
    say("     exp      alpha - (d + beta*e + gamma*TAG_EXP), (d,e) a row of the")
    say("              256-row exponential table; witness.rs:533,639 REFUSE a")
    say(f"              witness with d outside 0..256  => at most {U8_LEN}")
    say(f"     act      alpha - (i + beta*a + gamma*TAG_ACT), i = g8+128  => at most {U8_LEN}")
    say("     u8/exp/act TABLE helpers: `table_values_*_at(256, ...)` enumerates")
    say("              exactly the 256 rows of each table, so each is a SUBSET")
    say("              of its own family above and adds nothing.")
    s_block = 3 * U8_LEN
    say("")
    say(f"   |S| <= 3 x 256 = {s_block} per block, at EVERY shape.")
    say(f"   per block: {s_block}/p^2 = 2^-{bits(pr_count(s_block)):.2f}   "
        f"(memo: 2^-118.42)")
    for L in (12,):
        say(f"   {L}-block run, L independent alphas: {L*s_block}/p^2 = "
            f"2^-{bits(pr_count(L*s_block)):.2f}   (memo: 2^-114.83)")
    say("   VERDICT on N-3: the arithmetic and the bound both reproduce.")
    say("")
    say("   Two corrections to N-3's SCOPE, neither moving the number:")
    say("   (i)  the memo conditions on 'an honest witness'; the right and")
    say("        stronger conditioning is 'any witness `Witness::new` admits',")
    say("        because the byte ranges are REFUSALS in the constructor")
    say("        (witness.rs:290, 374, 386, 394, 534, 555, 600, 640, 672, 708),")
    say("        not a property of honesty.  That is exactly Lemma S's own")
    say("        hypothesis, so the term is in scope after all, and GS-12 can")
    say("        be closed for the u8 and exp families rather than carried.")
    say("   (ii) those same range refusals are R-1's INPUT-DETERMINED refusal")
    say("        sites.  Pricing the LogUp-denominator term over the admitted")
    say("        witnesses is right, but it must be said that the conditioning")
    say("        event itself (admission) is input-dependent and is governed by")
    say("        operating rule M-9, not by this term.")
    say("")

    say("C. THE CHALLENGE-ONLY TERMS, recounted independently.")
    say("")
    # lambda draws per block: A claims + H claims (incl the sum claim) + 2 endpoints
    for name, label in [("toy", "toy"), ("rung_g", "rung-G"), ("m125", "125M")]:
        d = load(name)
        a = d["claim_sites"]["a_total"]
        h = d["claim_sites"]["h_total"] + 1     # + the LogUp sum claim
        lam = a + h + 2
        say(f"   {label:<7s} lambda draws per block = {a} (A) + {h} (H incl sum) + 2 (endpoints) = {lam}"
            f"   -> 2^-{bits(pr_count(lam)):.2f}")
    d = load("m125")
    L = 12
    lam_run = L * (d["claim_sites"]["a_total"] + d["claim_sites"]["h_total"] + 1) + 2 * (L - 1) + 2
    say(f"   12x125M run: {L}*(122+51) + 2*11 + 2 = {lam_run}  -> 2^-{bits(pr_count(lam_run)):.2f}   (memo: 2,100 / 2^-116.96)")
    say("")
    pw = (P**3 + P**2 - P) / P**4      # Pr[wedge(a,b) = 0], a,b uniform in Fp2
    say(f"   Pr[wedge(a,b) = 0] for a,b uniform in Fp2 = (p^3+p^2-p)/p^4 = 2^-{bits(pw):.2f}")
    say(f"   4 openings per block  -> 2^-{bits(4*pw):.2f}      (memo: 2^-62.00)")
    say(f"   3L+1 = 37 per 12-run  -> 2^-{bits(37*pw):.2f}      (memo: 2^-58.79; ruling R-6's 2^-58.8)")
    say("")
    for label, n, mod in [("terminal mask e in {0,1}, 25 extension rounds", 50, P2),
                          ("CFS multiplier c_s = 0, 23 slots", 23, P2),
                          ("nu = 0, 5 sites x 2", 10, P2),
                          ("zeta = 0, 8 pad-zero hosts (rung-G)", 8, P2),
                          ("zeta = 0, 5 pad-zero hosts (125M)", 5, P2)]:
        say(f"   {label:<48s} 2^-{bits(pr_count(n, mod)):.2f}")
    say("")
    say("D. THE BACKSTOP DEGREES (memo section 5.4), recounted: degree 6G+2 over Fp.")
    tot_block = 0.0
    for label, G in [("A", 36), ("H", 9), ("endpoint", 1), ("boundary", 2)]:
        deg = 6 * G + 2
        p_ = deg / P
        say(f"   {label:<9s} minor {2*(G+1)}x{2*(G+1)}  degree {deg:>3d}  bound 2^-{bits(p_):.2f}")
    blk = (6 * 36 + 2) / P + (6 * 9 + 2) / P + 2 * (6 * 1 + 2) / P
    run = 12 * ((6 * 36 + 2) / P + (6 * 9 + 2) / P) + 11 * (6 * 2 + 2) / P + 2 * (6 * 1 + 2) / P
    say(f"   one shaped block union 2^-{bits(blk):.2f}   (memo: 2^-55.82)")
    say(f"   twelve-block run union 2^-{bits(run):.2f}   (memo: 2^-52.24)")
    say("")
    say("   BUT the backstop is never reached.  B-CHECK 2 computes the maximal")
    say("   minor's determinant EXACTLY and it equals")
    say("     prod_g Norm(lambda_{g,j(g)} * cm_{j(g)}) * wedge(rho_prox pair)")
    say("   on every seed.  A product of norm forms vanishes iff one factor")
    say("   does, and each factor vanishing is a NAMED refusal")
    say("   (protocol.rs:246 / :284-286 / :289-290).  So 'bad set subset")
    say("   refusal set' is an IDENTITY, conditional only on `audit_claims`")
    say("   giving each group a member with a pair of its own")
    say("   (protocol.rs:259-272).  Schwartz-Zippel is not the argument and")
    say("   its unusability at run scale costs nothing.")

    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "refusal_recount.txt"), "w") as fh:
        fh.write("\n".join(OUT) + "\n")


if __name__ == "__main__":
    main()

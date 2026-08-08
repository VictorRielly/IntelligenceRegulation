#!/usr/bin/env python3
"""U-AG-B1 Agent BA: BOTH-DIRECTION freeze rows for the aggregation
design-round constants (R-EB1..R-EB4, kappa 11, C-win window constants,
and the R-FC2 per-group digit-headroom rows).

WHAT "BOTH DIRECTIONS" MEANS (the LKP-7/8/9 house pattern, in script
form): every pinned constant is RE-DERIVED here from its recorded
formula/derivation — transcribed from the design docs and spikes, cited
inline — and asserted EQUAL to the pin. If the derivation chain moves
(someone edits a transcribed formula, or an upstream design constant
drifts), the row FAILS; if someone edits a pin without re-deriving, the
row FAILS. [MODEL]-flagged measured constants (the R-EB1 Monte-Carlo
acceptance table) cannot be re-derived arithmetically; their rows pin
the recorded values and assert the recorded consistency gates (the
spike's own bands) instead, so an edit on either side still fails.

Sources (all repo-recorded; cited per row):
  SC  = docs/zkmatrix-poc/AGGREGATION_SOUNDNESS_COMPOSITION.md
  DA  = docs/zkmatrix-poc/AGGREGATION_PARAMS_DESIGN.md
  FD  = docs/zkmatrix-poc/AGGREGATION_FOLDING_DESIGN.md
  FS  = docs/zkmatrix-poc/AGGREGATION_FOLDING_SOUNDNESS.md
  EA  = docs/zkmatrix-poc/AGGREGATION_ENCODING_DESIGN.md
  SR  = docs/zkmatrix-poc/SOUNDNESS_REFERENCE.md
  spike-EB = scripts/slack_composition_spike.py   (36/36, re-run 2026-08-08)
  spike-FA = scripts/aggregation_folding_spike.py (33/33, re-run 2026-08-08)

Doc-vs-spike discrepancies found while transcribing are NOT silently
"fixed" here: each is recorded as a BA-F* finding note on its row, the
SPIKE-derivable value is the pin, and the doc-side note is in the dated
freeze-table sections this lane appended to SC/FD (house rule:
historical doc text is never edited, dated addition notes only).

Runs on stdlib only, < 1 s. Exit 0 iff every row holds.
"""

import math
import sys

FAILURES = []
ROWS = []


def row(row_id, constant, pinned, derived, source, flag="", tol=0.0):
    """One freeze row: pin == derived (within tol for floats) or FAIL."""
    if isinstance(pinned, float) or isinstance(derived, float):
        ok = abs(float(pinned) - float(derived)) <= tol
        shown = round(float(derived), 6)
    else:
        ok = pinned == derived
        shown = derived
    ROWS.append((row_id, constant, ok))
    if not ok:
        FAILURES.append(row_id)
    print("  [%s] %-14s %-44s pin=%-14s derived=%-14s %s%s"
          % ("OK" if ok else "FAIL", row_id, constant, repr(pinned),
             repr(shown), source, (" " + flag) if flag else ""))
    return ok


def gate(row_id, description, ok, source, flag=""):
    """A boolean gate row (an inequality/verdict that must hold)."""
    ROWS.append((row_id, description, ok))
    if not ok:
        FAILURES.append(row_id)
    print("  [%s] %-14s %s  [%s]%s" % ("OK" if ok else "FAIL", row_id,
                                       description, source,
                                       (" " + flag) if flag else ""))
    return ok


# ===========================================================================
# Section 0 — house constants (derivation-side inputs), re-derived
# ===========================================================================
D = 128
Q31_PIN = 2_147_483_249            # mod.rs Q8; DA Section 1
TAIL = 1.3                         # params.rs TAIL; DA Section 1
E_C2 = 2.0                         # E[c_i^2] quinary; params.rs
E_RHO2 = 2.0 / 3.0                 # E[dig^2] convention; spike-EB digit_l2
LOG2_DELTA0 = 0.005326             # params.rs LOG2_DELTA0; DA Section 1
POLY_B = 4 + D * 4                 # 516 B; PROOF_BYTE_LEDGER Section 0
KEL_B = 64                         # PROOF_BYTE_LEDGER Section 0

OP_CONC = TAIL * math.sqrt(E_C2 * D)          # honest conc op norm
OP_DC_CONC = TAIL * math.sqrt(2 * E_C2 * D)   # challenge-DIFFERENCE conc
S_JL = math.sqrt(128.0 / 30.0)     # JL slack sigma; spike-EB S_JL;
#   = sqrt(lambda/C2) at (lambda=128, C2=30) = sqrt(256/60) at 512 rows
#   ([PSS] Lemma 2.2 constants). BA-F1 (finding, recorded in the SC
#   freeze-table addendum): SC 1.4's formula STRING "sqrt(2*lambda/C2)
#   ... sqrt(256/30) ... sqrt(512/60)" evaluates to 2.92 and contradicts
#   the doc's own printed value 2.07; the corpus-wide working constant
#   (DA 3.4's 121.7 base, spike-EB, this file) is sqrt(128/30) = 2.0656.
S_FORK = 2.0                       # extraction fork factor; DA 3.4

GATE_ED_LOG2 = 28.0 - math.log2(S_FORK * OP_DC_CONC)          # exact-digit
GATE_PL_LOG2 = 28.0 - math.log2(S_FORK * S_JL * OP_DC_CONC)   # per-level
# gamma_budget = 2^(31-3)/slack — DA 2.4 item 2 / spike-EB gamma_budget.


def section0():
    print("\n== 0. House constants (derivation-side inputs) ==")
    row("H-q31", "q31 = 2^31 - 399", Q31_PIN, 2 ** 31 - 399,
        "mod.rs Q8; DA S1")
    row("H-opconc", "op_norm(conc) = 1.3*sqrt(2D)", 20.8, OP_CONC,
        "params.rs; DA S1", tol=1e-9,
        flag="[BA-F4: SC 0.2/FD F-IF1.5 print '20.79'; exact 20.80]")
    row("H-opdc", "op_norm(diff conc) = 1.3*sqrt(4D)", 29.42, OP_DC_CONC,
        "DA S1 (prints '29.4' at 1dp; exact 29.4156)", tol=0.005)
    row("H-sjl", "sigma_JL = sqrt(128/30)", 2.07, S_JL,
        "spike-EB S_JL; [PSS] L2.2; SC 1.4 printed value", tol=0.005,
        flag="[BA-F1: SC 1.4 formula string would give 2.92]")
    gate("H-sjl-x", "DA per-level base 2*sigma_JL*29.4 = 121.5 (doc 121.7, "
         "spike tol 0.3); the sqrt(256/30)=2.92 reading would give 171.9",
         abs(S_FORK * S_JL * OP_DC_CONC - 121.7) < 0.3
         and abs(S_FORK * math.sqrt(256.0 / 30.0) * OP_DC_CONC - 121.7) > 40,
         "DA 3.4; spike-EB anchor 1")
    row("H-gate-ed", "gamma_max(exact-digit) log2 = 28 - log2(2*29.4)",
        22.12, GATE_ED_LOG2, "DA 3.4/2.4; spike-EB anchors", tol=0.005)
    row("H-gate-pl", "gamma_max(per-level) log2 = 28 - log2(121.5)",
        21.07, GATE_PL_LOG2, "DA 3.4/2.4; spike-EB anchors", tol=0.005)
    row("H-poly", "poly wire width", 516, POLY_B,
        "PROOF_BYTE_LEDGER S0")


# ===========================================================================
# Section 1 — R-EB1: the T_cap = 33 sampled-cap rule
# ===========================================================================
T_CAP = 33          # SC 1.3 (C-cap) / 5.4; the working point of every
#                     SC 2.4 number; FS F-C2 extends it to fold challenges.
DIFF_CAP = 2 * T_CAP    # challenge-DIFFERENCE cap used in extraction
#                         bounds (FS AFS-L6: a difference is a sum of two).
# [MODEL] Monte-Carlo acceptance table (spike-EB section 2, 20k draws,
# seed 7; quoted in SC 1.3/5.4 as 38%/67%/94%):
MC_ACC_33 = 38.43
MC_ACC_36 = 66.77
MC_ACC_42 = 94.34
MC_P50 = 34.2
MC_P99 = 46.8


def section1():
    print("\n== 1. R-EB1 — operator-norm cap on fold AND batching "
          "challenges (SC 1.3/4.2/5.4; FS F-C2) ==")
    row("EB1-tcap", "T_cap (frozen working point)", 33, T_CAP,
        "SC 1.3 C-cap; SC 5.4; FD standing constraints")
    row("EB1-diffcap", "difference cap = 2*T_cap", 66, DIFF_CAP,
        "FS AFS-L6 statement")
    gate("EB1-band", "OP_CONC 20.8 < T_cap 33 < 2D = 256 (cap sits between "
         "honest conc bound and worst case)",
         OP_CONC < T_CAP < 2 * D, "SC 1.3 MC finding")
    gate("EB1-median", "[MODEL] conc 20.8 < MC op-norm median 34.2 "
         "(why conc is NOT an extraction cap)",
         OP_CONC < MC_P50, "SC 1.3; spike-EB sec 2")
    row("EB1-cost", "cost of no cap log2(256/33) bits", 2.96,
        math.log2(256.0 / 33.0), "FS AFS-L6 ('recovers exactly 2.96 b'); "
        "SC 1.3 says '~2.9 bits'", tol=0.005)
    # [MODEL] MC pins + the spike's own recorded consistency bands:
    row("EB1-mc33", "[MODEL] acceptance at T_cap 33 (%)", 38.43, MC_ACC_33,
        "spike-EB sec 2 (SC quotes 38%)", tol=0.0)
    row("EB1-mc36", "[MODEL] acceptance at 36 (%)", 66.77, MC_ACC_36,
        "spike-EB sec 2 (SC quotes 67%)", tol=0.0)
    row("EB1-mc42", "[MODEL] acceptance at 42 (%)", 94.34, MC_ACC_42,
        "spike-EB sec 2 (SC quotes 94%)", tol=0.0)
    gate("EB1-mcband", "[MODEL] recorded bands hold: 5<=acc33<=50, "
         "acc42>=90, ~3 attempts at 33",
         5.0 <= MC_ACC_33 <= 50.0 and MC_ACC_42 >= 90.0
         and round(100.0 / MC_ACC_33) == 3, "spike-EB checks (sec 2)")
    gate("EB1-scope", "rule scope: cap binds FOLD and BATCHING sampling "
         "(resample-until-under, deterministic FS counter/salt)",
         True, "SC 5.4 R-EB1 text; SC 4.2 note (ii); FS F-C2",
         flag="[rule row — engine wiring exported to BB]")


# ===========================================================================
# Section 2 — R-EB2: no [NS22] garbage-count optimization at recursed
# levels under FS; the byte model keeps the FULL r(r+1) garbage count
# ===========================================================================
NS22_RECURSED_FORBIDDEN = True    # SC 2.2 item 2 / 5.4 R-EB2; the
#                                   (T_op)^r slack of [PSS] I.6.


def garbage_terms(r):
    """Per-level garbage ring count before decomposition: g and h
    families, r(r+1)/2 EACH (DA 3.2, per [LaB]'s protocol) -> r(r+1)
    total. This is the count DA's recurrence and every downstream byte
    model use (spike-EB schedule: '(r * (r + 1), val_bits)')."""
    g_family = r * (r + 1) // 2
    h_family = r * (r + 1) // 2
    return g_family + h_family


def section2():
    print("\n== 2. R-EB2 — [NS22]-style garbage reduction FORBIDDEN at "
          "recursed levels under FS (SC 2.2 item 2 / 5.4) ==")
    row("EB2-rule", "NS22 optimization at recursed levels", "FORBIDDEN",
        "FORBIDDEN" if NS22_RECURSED_FORBIDDEN else "allowed",
        "SC 5.4 R-EB2; [PSS] I.6 (T_op)^r slack")
    ok = all(garbage_terms(r) == r * (r + 1) for r in (4, 8, 16, 33, 64))
    gate("EB2-count", "full garbage count = r(r+1) rings/level "
         "(r(r+1)/2 per family x 2 families) at r in {4,8,16,33,64}",
         ok, "DA 3.2 recurrence; spike-EB schedule term")
    # Context (no pin): at T_cap = 33 the (T_op)^r extraction slack of the
    # optimized form crosses q31 once r >= ceil(31/log2(33)) = 7 — the
    # bare last level is the only place the optimization could ever ride,
    # and only with [PSS] I.6's second amortized opening (not designed).


# ===========================================================================
# Section 3 — R-EB3: ct-aggregation sizing (t-up) / K-draw restructure
# ===========================================================================
Q_FS_LOG2 = 64          # house grinding convention Q = 2^64 (SC 3.3 Q-conv)
L_MAX = 8               # recursion depth bound used by the rule (SC 3.2)
T_LAB = math.ceil(128 / 31)                    # = 5, the [LaB] transfer value
T_MIN = math.ceil((128 + math.log2(2 * (2.0 ** 64 + 1)) + math.log2(L_MAX))
                  / 31)                        # = 7, R-EB3 (t-up)
KDRAW_EXP = 16 * 31     # 496: full-entropy R_q per-slot mass q^-16
T_UP_WIRE = 7 * POLY_B          # 3,612 B/level at t = 7
DA_AGG_LINE = 4 + 16 * KEL_B    # 1,028 B/level (DA's modeled line;
#                                 spike-EB agg_bytes default)
KDRAW_LINE_K11 = 4 + 2 * POLY_B  # 1,036 B/level (FD F-IF1.7 adopted line)


def section3():
    print("\n== 3. R-EB3 — ct-aggregation sizing: t >= 7 OR the K-draw "
          "restructure (SC 3.2/5.4; FD F-IF1.6 'R-EB3-clean') ==")
    row("EB3-tmin", "t_min = ceil((128+log2(2(Q+1))+log2 L)/31), Q=2^64, "
        "L=8", 7, T_MIN, "SC 3.2 (t-up)")
    row("EB3-tlab", "[LaB] transfer t = ceil(128/31) (the FAILING value)",
        5, T_LAB, "SC 3.2 'the missing term'")
    gate("EB3-fail5", "t=5 fails post-FS: 31*5 - 65 = 90 < 128 "
         "(doc headline; spike full-sum 2^-86.5, same verdict)",
         31 * T_LAB - 65 == 90 and 31 * T_LAB - 65 < 128,
         "SC 3.2/3.3 table")
    gate("EB3-pass7", "t=7 passes post-FS: per-level 2^-217, "
         "217 - 65 - 3 = 149 >= 128",
         31 * T_MIN == 217 and 31 * T_MIN - 65 - 3 == 149
         and 31 * T_MIN - 65 - 3 >= 128, "SC 3.2/3.3 table")
    row("EB3-kdraw", "K-draw error class exponent 16*31 (q^-16 per-slot)",
        496, KDRAW_EXP, "SC 3.2 (K-draw); SR 1.3 full-entropy")
    row("EB3-wire7", "t-up wire = 7 polys/level", 3612, T_UP_WIRE,
        "SC 3.2 't*516 B per level'")
    row("EB3-da-line", "DA's modeled aggregation line", 1028, DA_AGG_LINE,
        "DA 5.1 model; spike-EB agg_bytes")
    row("EB3-delta", "t-up delta vs DA line (B/level)", 2584,
        T_UP_WIRE - DA_AGG_LINE, "SC 3.2 '+2,584 B/level'")
    gate("EB3-deltaL", "t-up pass-scope delta: 18,088 B (L=7) / 20,672 B "
         "(L=8) — SC's '~+18-21 KiB' is loose (decimal-ish) rounding",
         (T_UP_WIRE - DA_AGG_LINE) * 7 == 18_088
         and (T_UP_WIRE - DA_AGG_LINE) * 8 == 20_672, "SC 3.2")
    row("EB3-kline", "adopted K-draw wire line at kappa 11 (4 + 2*516)",
        1036, KDRAW_LINE_K11, "FD F-IF1.7; spike-FA AGG_KDRAW",
        flag="[EB 3.2's '516-1,032 B/level' band = object cost sans the "
             "4 B length prefix]")
    row("EB3-adopted", "adopted direction", "K-draw", "K-draw",
        "FD S1 standing constraints; FS 0.3; SC 5.4 recommendation",
        flag="[plumbing owed — BB lane]")


# ===========================================================================
# Section 4 — R-EB4: floor-base cap e <= 7, validity line 2^30.5,
#             kappa = 11, C-win window constants
# ===========================================================================
BT_CAP_LOG2 = 30.5      # SC 2.4(a)/5.4; spike-EB BT_CAP
KAPPA = 11              # SC 2.4(b)/5.1; FD standing constraints
FLOOR_E_MAX = 7         # SC 2.4(a) 'caps e_i <= 7 at the floor'
# Worst-level parameters of the R-EB4-corrected schedules (spike-EB
# section 3b prints; the beta' inputs are schedule outputs, pinned here
# as recorded):
WORST_ED = dict(e=7, beta_next_log2=14.87)   # 2^20 exact-digit L3
WORST_JL = dict(e=7, beta_next_log2=14.30)   # 2^20 JL L7
MAX_BETA_TOP_ED = 29.93     # spike-EB: 'max 2^29.93' (exact-digit)
MAX_BETA_TOP_JL = 30.40     # spike-EB: 'max 2^30.40' (JL)
#   BA-F2 (finding): SC 2.4(b) prints 'max beta_top = 2^30.14 (JL)';
#   its own spike prints 2^30.39-2^30.40. Verdict unchanged (both under
#   the 2^30.5 line; kappa 11 covers both) — the spike value is pinned.
C1_256 = 125            # [LaB] Lemma 4.2 window (tighter than [PSS] 120)
C1_512 = 168            # [PSS] Lemma 2.2 at lambda = 256
JL_ERR_256_LOG2 = -128  # corrected soundness constants (SC 3.2 table)
JL_ERR_512_LOG2 = -256  # (DA modeled -141/-282; corrected by SC)


def digit_l2(n_rings, e):
    """1.3-tail honest l2 bound of an n_rings-ring digit vector at base
    2^e (spike-EB digit_l2; house Q4.1 convention E[d^2] = (2/3)*4^(e-1))."""
    return TAIL * math.sqrt(n_rings * D * E_RHO2 * 4.0 ** (e - 1))


def reb4_bt(n_rings, e, sigma):
    """The R-EB4 inner-binding validity bound at base selection
    (SC 2.4(a); spike-EB schedule): 8*T_cap*(1+2^e)*sigma*beta_i(e)."""
    return 8 * T_CAP * (1 + 2.0 ** e) * sigma * digit_l2(n_rings, e)


def chen_delta(b):
    return (b / (2 * math.pi * math.e) * (math.pi * b) ** (1.0 / b)) ** (
        1.0 / (2 * (b - 1)))


def block_for_delta(delta_target):
    lo, hi = 50.0, 4000.0
    for _ in range(80):
        mid = 0.5 * (lo + hi)
        if chen_delta(mid) > delta_target:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


def msis_bits(k_z, log2_q, log2_beta):
    """Core-SVP bit count on the house C3 line (spike-EB / DA /
    ESTIMATOR_NOTE conventions)."""
    if log2_beta >= log2_q:
        return 0.0
    ld = (log2_beta / 2.0) ** 2 / (k_z * log2_q)
    return 0.292 * block_for_delta(2.0 ** ld)


def c3_kappa(log2_beta):
    """kappa = ceil(k_Z/128), k_Z >= (log2 beta / 2)^2/(31*LOG2_DELTA0)
    (DA Section 1 C3 line)."""
    k_z = math.ceil((log2_beta / 2.0) ** 2 / (31.0 * LOG2_DELTA0))
    return math.ceil(k_z / D), k_z


def kappa_coverage_log2(kappa):
    """Max log2(beta) covered by kappa on the C3 line (inversion)."""
    return 2.0 * math.sqrt(kappa * D * 31.0 * LOG2_DELTA0)


def section4():
    print("\n== 4. R-EB4 — deep-base validity cap, kappa 11, C-win "
          "(SC 2.4/5.4; spike-EB 3b) ==")
    row("EB4-line", "validity line log2 (inner-binding MSIS bounds)",
        30.5, BT_CAP_LOG2, "SC 2.4(a); spike-EB BT_CAP", tol=0.0)
    gate("EB4-line-q", "2^30.5 < q31 (the line sits under q)",
         2.0 ** 30.5 < Q31_PIN, "SC 2.4(a) 'vacuous as bounded' fence")
    gate("EB4-line-cov", "kappa-11 C3 coverage 2*sqrt(11*128*31*d0) = "
         "30.49 — the 30.5 line IS kappa 11's coverage boundary "
         "(consistency)", abs(kappa_coverage_log2(11) - 30.5) < 0.01,
         "DA S1 C3 line; SC 2.4(b)")

    # C3 anchors (ESTIMATOR_NOTE rows, via DA Section 1):
    gate("EB4-c3-anch", "C3 anchors reproduce: beta 2^24.55 -> kappa 8 "
         "(k_Z 913); beta 2^26.13 -> kappa 9 (k_Z 1034)",
         c3_kappa(24.55) == (8, 913) and c3_kappa(26.13) == (9, 1034),
         "DA S1; ESTIMATOR_NOTE 4/6")

    # The floor-base cap e <= 7, re-derived at the recorded floor sizes
    # (EB 2.4(a) floors 620-770 rings; FD 9.1 floors 710/734 rings):
    floors = (620, 640, 710, 734, 770)
    ok7 = all(math.log2(reb4_bt(n, 7, s)) <= BT_CAP_LOG2
              for n in floors for s in (1.0, S_JL))
    ok8 = all(math.log2(reb4_bt(n, 8, s)) > BT_CAP_LOG2
              for n in floors for s in (1.0, S_JL))
    row("EB4-emax", "floor base cap e_max", 7,
        7 if (ok7 and ok8) else -1,
        "SC 2.4(a); derived: e=7 passes / e=8 fails the 2^30.5 rule at "
        "floor sizes 620-770 rings, both sigma branches")
    gate("EB4-window64", "e<=7 puts every digit magnitude 2^(e-1) <= 64 "
         "in the [LF+] monomial window (-64,64); e=8 would not",
         2 ** (FLOOR_E_MAX - 1) <= 64 < 2 ** FLOOR_E_MAX,
         "FS AFS-L5 item 1 convergence")

    # Worst-level beta_top values (recorded schedule outputs re-derived
    # from the [LaB]-form bound at the pinned worst-level parameters):
    bt_ed = math.log2(8 * T_CAP * (1 + 2.0 ** WORST_ED["e"]) * 1.0
                      * 2.0 ** WORST_ED["beta_next_log2"])
    bt_jl = math.log2(8 * T_CAP * (1 + 2.0 ** WORST_JL["e"]) * S_JL
                      * 2.0 ** WORST_JL["beta_next_log2"])
    row("EB4-bted", "max beta_top log2, exact-digit branch",
        MAX_BETA_TOP_ED, bt_ed, "spike-EB 3b (2^20 L3); SC 2.4(b)",
        tol=0.01)
    row("EB4-btjl", "max beta_top log2, JL branch",
        MAX_BETA_TOP_JL, bt_jl, "spike-EB 3b (2^20 L7)", tol=0.01,
        flag="[BA-F2: SC 2.4(b) prints 2^30.14; spike prints 2^30.40]")
    gate("EB4-valid", "both branch maxima clear the 2^30.5 line",
         bt_ed <= BT_CAP_LOG2 and bt_jl <= BT_CAP_LOG2,
         "SC 2.4(b) 'all valid'")

    # kappa = 11:
    row("KAP-11", "kappa (both branches' worst levels)", 11,
        max(c3_kappa(MAX_BETA_TOP_ED)[0], c3_kappa(MAX_BETA_TOP_JL)[0]),
        "SC 2.4(b)/5.1; spike-EB 'max kappa needed = 11'")
    gate("KAP-10-short", "kappa 10 falls short: coverage 29.07 < 29.93 "
         "(exact-digit worst) < 30.40 (JL worst)",
         kappa_coverage_log2(10) < MAX_BETA_TOP_ED < MAX_BETA_TOP_JL,
         "SC 2.4(b) 'kappa = 10 falls short there'")
    gate("KAP-128bit", "core-SVP >= 128 bits at both worst levels on the "
         "C3-line k_Z", all(
             msis_bits(c3_kappa(b)[1], 31.0, b) >= 128.0
             for b in (MAX_BETA_TOP_ED, MAX_BETA_TOP_JL)),
         "house convention (C-msis); DA 3.3 class")

    # C-win window constants:
    w256 = math.log2(Q31_PIN / C1_256)
    w512 = math.log2(Q31_PIN / C1_512)
    row("CWIN-C1-256", "window constant C1 (256-row)", 125, C1_256,
        "[LaB] L4.2 via SC 1.4 (spike uses the TIGHTER 125 vs [PSS] 120)")
    row("CWIN-C1-512", "window constant C1 (512-row)", 168, C1_512,
        "[PSS] L2.2 at lambda 256; SC 1.4")
    row("CWIN-256", "window log2 q/125", 24.03, w256,
        "spike-EB section 3", tol=0.005,
        flag="[BA-F3: SC 1.4 prints 2^24.06 — matches neither C1=120 "
             "(24.09) nor 125 (24.03); margins unaffected]")
    row("CWIN-512", "window log2 q/168", 23.61, w512,
        "SC 1.4 (prints 2^23.60)", tol=0.005)
    gate("CWIN-margin", "recorded witness-bound class <= 2^17.8 leaves "
         ">= +6.2 b (256) / +5.8 b (512) window margin",
         w256 - 17.8 >= 6.2 and w512 - 17.8 >= 5.8,
         "SC 1.4 'minimum margin' at DA schedules; corrected schedules "
         "are wider (spike: +6.98/+6.55 JL, +7.30/+6.87 ed)")
    row("CWIN-jlerr", "corrected JL soundness error exponents (256/512)",
        (-128, -256), (JL_ERR_256_LOG2, JL_ERR_512_LOG2),
        "SC 3.2 correction of DA's -141/~-282")


# ===========================================================================
# Section 5 — R-FC2: per-group digit-headroom freeze rows (pass scope)
# ===========================================================================
# Value-class inventories (recorded; derivations cited):
#   FFN 512x4096x11008 complete pass, DENSE (EA 2.4; FD 5.1/5.2):
#     8-bit  = 32 layers x 3 tensors (X, Y, UP; each 512x11008 dense
#              int8 = 44,032 rings)          = 4,227,072 rings
#     15-bit = 32 x Z (512x11008, |Z|<=127^2) = 1,409,024 rings
#     31-bit aux   = 32 x 200 (EA 2.3)        =     6,400 rings
#     31-bit blind = T_blind 2^12 [MODEL]     =     4,096 rings
#   Weights (stacked, dense int8; FD F-IF1.4): 3 x 32 x 4096x11008/128
#     = 33,816,576 rings; 8B [MODEL] shape 4096x14336 -> 44,040,192.
#   2^20 ledger-unit pass (EA SHAPES; spike-FA pass_classes):
#     8-bit 32x24,576 = 786,432; 15-bit 32x8,192 = 262,144;
#     31-bit aux 32x168 = 5,376; blind 4,096.
RING_11008 = 512 * 11008 // D           # 44,032
ACT_FFN = [(32 * 3 * RING_11008, 8), (32 * RING_11008, 15),
           (32 * 200, 31), (4096, 31)]
W_FFN = [(3 * 32 * 4096 * 11008 // D, 8)]
W_8B = [(3 * 32 * 4096 * 14336 // D, 8)]
ACT_2_20 = [(32 * 24_576, 8), (32 * 8_192, 15), (32 * 168, 31), (4096, 31)]


def nlimb(classes, e):
    """Per-class limb chain (EA schedule2 (a); spike-FA schedule_fold):
    nl(e) = sum_c n_c * max(1, ceil(bits_c / e))."""
    return sum(c * max(1, math.ceil(b / e)) for c, b in classes)


def gamma_log2(classes, e):
    """Level-0 pass fold norm (DA 3.2 / FD F-IF1.5):
    gamma_z = OP_CONC * 2^(e0-1) * sqrt(N_limb * D)."""
    return math.log2(OP_CONC * 2.0 ** (e - 1)
                     * math.sqrt(nlimb(classes, e) * D))


def fc2_row(rid, label, classes, e, gate_log2, pin_nl, pin_gamma,
            pin_head, src, flag=""):
    nl = nlimb(classes, e)
    g = gamma_log2(classes, e)
    ok_nl = row(rid + "-nl", label + " N_limb at e0=%d" % e, pin_nl, nl, src)
    ok_g = row(rid + "-g", label + " gamma_z log2", pin_gamma, g, src,
               tol=0.005)
    ok_h = row(rid + "-h", label + " headroom (b)", pin_head,
               gate_log2 - g, src, tol=0.005, flag=flag)
    return ok_nl and ok_g and ok_h


def section5():
    print("\n== 5. R-FC2 — per-group digit-headroom rows at pass scope "
          "(FD F-IF1.5/5.1-5.3/6.1; FS 8.3 R-FC2; spike-FA) ==")
    # class-count pins (derivation = the recorded per-layer inventory):
    row("FC2-cls-8b", "act 8-bit rings (32 x 3 x 44,032)", 4_227_072,
        ACT_FFN[0][0], "FD 5.1; EA 2.4 (X/Y/UP dense int8)")
    row("FC2-cls-15b", "act 15-bit rings (32 x 44,032)", 1_409_024,
        ACT_FFN[1][0], "FD 5.1; EA 2.4 (Z)")
    row("FC2-cls-aux", "act 31-bit aux rings (32 x 200)", 6_400,
        ACT_FFN[2][0], "FD 5.1; EA 2.3")
    row("FC2-cls-bl", "T_blind rings (2^12) [MODEL]", 4_096,
        ACT_FFN[3][0], "DA 2.5; FD F-IF1.4")
    row("FC2-cls-W", "weight rings (3 x 32 x 4096x11008 dense int8)",
        33_816_576, W_FFN[0][0], "FD 5.2/F-IF1.4")
    row("FC2-cls-W8B", "[MODEL] 8B weight rings (4096x14336)",
        44_040_192, W_8B[0][0], "FD 5.2 F-N4; TARGET_CONTRACT S1 dims")

    # Adopted operating points:
    row("FC2-act-e0", "ADOPTED activation e0 (all modes)", 2, 2,
        "FD F-IF1.5 'ADOPTED e0 = 2 ... ZERO byte premium (F-N3)'")
    row("FC2-w-e0", "ADOPTED weight e0 (W-C, sign-binary)", 1, 1,
        "FD F-IF1.5/5.2")

    # The headroom rows (pins = exact derived values at 2-3 decimals;
    # doc-printed 2dp values are within 0.01 of every pin):
    fc2_row("FC2-act2", "act e0=2 (ADOPTED)", ACT_FFN, 2, GATE_ED_LOG2,
            28_348_416, 21.257, 0.865,
            "FD 5.1 (prints 0.86; FS 8.3 prints 0.87)")
    fc2_row("FC2-act3", "act e0=3 (byte-optimal, razor)", ACT_FFN, 3,
            GATE_ED_LOG2, 19_841_792, 22.000, 0.122, "FD 5.1 (0.12)")
    fc2_row("FC2-act1", "act e0=1 (conservative PL-gate variant)",
            ACT_FFN, 1, GATE_PL_LOG2, 55_277_312, 20.739, 0.336,
            "FD 5.1 (prints 0.33; FS 8.3 prints 0.33; exact 0.336)")
    fc2_row("FC2-act5", "act e0=5 NEGATIVE (layer base at x32)",
            ACT_FFN, 5, GATE_ED_LOG2, 12_754_688, 23.681, -1.559,
            "FD 5.1 spike N5 (prints -1.56)")
    gate("FC2-N5", "negative direction holds: e0=5 headroom < 0 "
         "(the re-derivation is MANDATORY)",
         GATE_ED_LOG2 - gamma_log2(ACT_FFN, 5) < 0, "FD F-IF1.5/5.1")

    fc2_row("FC2-W", "weight group e0=1 (W-C)", W_FFN, 1, GATE_ED_LOG2,
            270_532_608, 21.884, 0.237, "FD 5.2 (prints 0.24; FS 0.23)")
    gate("FC2-FN2", "F-N2: weight group INFEASIBLE at the per-level gate "
         "(headroom -0.81 < 0) — exact-digit branch load-bearing",
         GATE_PL_LOG2 - gamma_log2(W_FFN, 1) < 0,
         "FD 5.2 F-N2; spike-FA check 28")
    fc2_row("FC2-WB", "W-B merged variant (priced, NOT recommended)",
            ACT_FFN + W_FFN, 1, GATE_ED_LOG2, 325_809_920, 22.018, 0.103,
            "FD 5.3 (prints 0.10; 7B-only)")
    fc2_row("FC2-W8B", "[MODEL] 8B weight group e0=1 (F-N4)", W_8B, 1,
            GATE_ED_LOG2, 352_321_536, 22.075, 0.047,
            "FD 5.2 F-N4 (prints 0.05)",
            flag="[F-O4: relaxed-e0 line BEFORE any 8B freeze — BC lane]")
    gate("FC2-FN4", "F-N4 [MODEL] band: 0 < 8B weight headroom < 0.2 b "
         "(the sharpest number in the design)",
         0.0 < GATE_ED_LOG2 - gamma_log2(W_8B, 1) < 0.2,
         "spike-FA check 31 band")

    fc2_row("FC2-led", "2^20 ledger-unit pass act group e0=4", ACT_2_20, 4,
            GATE_ED_LOG2, 2_697_216, 21.560, 0.561,
            "FD 6.1; spike-FA print (0.56)")

    # The one-time pass norm law:
    ratio = (gamma_log2([(32 * c, b) for c, b in ACT_FFN], 2)
             - gamma_log2(ACT_FFN, 2))
    row("FC2-law", "one-time pass cost log2 sqrt(32) (no per-step growth)",
        2.5, ratio, "FD F-IF1.5 norm-growth law; FS V3", tol=1e-9)


# ===========================================================================
# Section 6 — verdict
# ===========================================================================

def main():
    print("aggregation_freeze_rows — U-AG-B1 BA both-direction freeze rows")
    print("(re-derives every pin from its recorded formula; either side "
          "moving FAILS)")
    section0()
    section1()
    section2()
    section3()
    section4()
    section5()
    n_ok = sum(1 for _, _, ok in ROWS if ok)
    print("\nRESULT: %d rows, %d FAIL" % (len(ROWS), len(FAILURES)))
    if FAILURES:
        print("FAILED rows: %s" % ", ".join(FAILURES))
    return 1 if FAILURES else 0


if __name__ == "__main__":
    sys.exit(main())

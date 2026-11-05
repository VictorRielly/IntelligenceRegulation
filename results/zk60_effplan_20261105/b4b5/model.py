#!/usr/bin/env python3
"""B4 / B5 design-study model for one W16R2 8B T128 block (2026-11-05).

Scratch model for docs/zkmatrix-poc/W16R3_DESIGN_B4_B5_20261105.md. Pure Python, no
dependencies, no repository code is imported or changed. Run:  python3 -I model.py

Labels used in the output:
  [CODE]      a count read off the Rust sources (file:line given in the note)
  [MEASURED]  quoted from a measured log (A1 phases, census, H107-H116)
  [MODEL]     derived here from the two above by an explicit scaling rule
  [ESTIMATE]  a judgement range (fixed costs, kernel efficiency)
"""
import json
import math
from fractions import Fraction
from itertools import product

P = 2**64 - 2**32 + 1          # Goldilocks
F2 = P * P                      # |Fp2|, challenges live here
LOG_COLS = 14
N_COLS = 1 << LOG_COLS
Q_OPEN = 280                    # W16R2 opened columns (shape.rs:320)


def lg(x):
    return math.log2(x)


# ---------------------------------------------------------------------------
# 1. The W16R2 8B T128 block, as the code lays it out  [CODE]
# ---------------------------------------------------------------------------
# rows per plane = domain size / 2^14 (shape.rs:2449-2457); census.log
ROWS = {"L": 1, "D": 32, "Q": 32, "Kv": 8, "S": 32, "F": 128}

# Every lookup of lookups_w16 (accuracy_layout.rs:289-344), with the relation it
# serves and its class.  kind: R = remainder (semantic: it defines a floor),
# W = word (no-wrap / class only), S8 = symmetric int8 word, Q = quotient P,
# L = isqrt limb.  width: the range family it queries.
LOOKUPS = {
    "L": [("LIMB", 8, "L", "isqrt limb (TZC D - limbs)"), ("LIMBM", 8, "L", "isqrt limb, norm_m")],
    "D": [("X", 16, "W", "block input; norm_a sum of squares; residual 1"),
          ("Y", 16, "W", "norm_a output; Q/K/V requant input"),
          ("NR.lo", 16, "R", "norm_a division remainder"), ("NR.hi", 8, "R", "norm_a division remainder"),
          ("NS.lo", 16, "R", "norm_a c1 slack"), ("NS.hi", 8, "R", "norm_a c1 slack"),
          ("AO", 16, "W", "Wo requant output; residual 1"),
          ("RAL.lo", 16, "R", "Wo requant remainder (21 b)"), ("RAL.hi", 5, "R", "Wo requant remainder"),
          ("X1", 16, "W", "residual 1; norm_m sum of squares"),
          ("YM", 16, "W", "norm_m output (D12 item 4); gate/up input"),
          ("MR.lo", 16, "R", "norm_m division remainder"), ("MR.hi", 8, "R", "norm_m division remainder"),
          ("MS.lo", 16, "R", "norm_m c1 slack"), ("MS.hi", 8, "R", "norm_m c1 slack"),
          ("Z16", 16, "W", "down requant output; residual 2"),
          ("RDL.lo", 16, "R", "down requant remainder (20 b)"), ("RDL.hi", 4, "R", "down requant remainder"),
          ("X2", 16, "W", "block output (boundary); residual 2")],
    "Q": [("Q", 16, "W", "Q requant output; RoPE input"), ("RQL", 15, "R", "Q requant remainder"),
          ("QR", 16, "W", "RoPE output; score input (bilinear)"), ("RQRL", 7, "R", "RoPE remainder"),
          ("O", 16, "W", "PV requant output; Wo input"), ("RO", 12, "R", "PV requant remainder")],
    "Kv": [("K", 16, "W", "K requant output; RoPE input"), ("RKL", 15, "R", "K requant remainder"),
           ("V", 16, "W", "V requant output; PV input"), ("RVL", 16, "R", "V requant remainder"),
           ("KR", 16, "W", "RoPE output; score input (bilinear)"), ("RKRL", 7, "R", "RoPE remainder")],
    "F": [("RGL.lo", 16, "R", "gate requant remainder (18 b)"), ("RGL.hi", 2, "R", "gate requant remainder"),
          ("U16", 16, "W", "up requant output; product input"), ("RU", 12, "R", "up requant remainder"),
          ("H16.lo", 16, "W", "product word, low expr (word24)"), ("H16.top", 8, "W", "product word, signed top limb"),
          ("RH", 16, "R", "product remainder")],
    "S": [("S8+", 8, "S8", "score int8 class, +"), ("S8-", 8, "S8", "score int8 class, -"),
          ("RSL.lo", 16, "R", "score requant remainder (18 b)"), ("RSL.hi", 2, "R", "score requant remainder"),
          ("P", 13, "Q", "softmax quotient (no-wrap of P*Sum, PV)"),
          ("SR", 16, "R", "softmax division remainder"), ("SG", 16, "R", "softmax c3 slack")],
}
FUNCTIONAL = {"S": 1, "F": 1}   # exp helper on S, ACT helper on F (h_plane_doms, shape.rs:2576-2578)
TAB_H_ROWS = 32                 # 16 Tab Fp2 planes (census.log "H Tab planes 16")
A_DATA_TODAY = 2279             # census.log
A_ROWS_TODAY, H_ROWS_TODAY = 2501, 2602   # census.log (data + mask/proximity rows)
H_MASK_ROWS = H_ROWS_TODAY - 2514          # 88
EXP_ACT_QUERIES = 524_288 + 2_097_152      # REVIEW_W16_20261101.md table
T_D = 127_668                              # ibid.


def h_rows(lk_counts, extra_h=0):
    """H data rows: ceil(lookups/2) Fp2 helpers per domain (+functional), 2 base rows each."""
    rows = 0
    for d, n in lk_counts.items():
        if d.startswith("C"):
            continue
        helpers = math.ceil(n / 2) + FUNCTIONAL.get(d, 0)
        rows += helpers * ROWS[d] * 2
    return rows + TAB_H_ROWS + extra_h


def lookup_rows(lk_counts, extra=0):
    return sum(n * ROWS[d] for d, n in lk_counts.items() if not d.startswith("C")) + extra


today_counts = {d: len(v) for d, v in LOOKUPS.items()}
assert today_counts == {"L": 2, "D": 19, "Q": 6, "Kv": 6, "F": 7, "S": 7}   # census.log line 1
assert h_rows(today_counts) == 2514                                          # census: H data 2514
assert lookup_rows(today_counts) * N_COLS == 32_276_480                      # REVIEW_W16 count


# ---------------------------------------------------------------------------
# 2. B4: which checks move, and the two probabilistic tiers
# ---------------------------------------------------------------------------
# Decision per lookup (see the note, section 3.2):
TIER_B = {"Y", "Q", "O", "K", "V", "U16", "S8+", "S8-", "P"}     # |w| < 2^28 proved
TIER_H = {"H16.lo", "H16.top"}                                  # |h| < 2^36 proved, HT plane dropped
DROPPED = {"AO", "Z16"}                                         # implied by residuals (|.| <= 2^16)
# Rows that enter each tier's combination (one entry per row per position):
#   (plane, domain, honest biased bound B_r)
TIER_B_ROWS = [("Y", "D", 2**16), ("Q", "Q", 2**16), ("O", "Q", 2**16), ("K", "Kv", 2**16),
               ("V", "Kv", 2**16), ("U16", "F", 2**16), ("S8", "S", 255), ("P", "S", 2**13)]
TIER_H_ROWS = [("H16", "F", 2**24)]
K_COMBOS = 128


def tier(rows, G, L_log, limbs_widths):
    R = sum(ROWS[d] for _, d, _ in rows)
    honest_max = sum(ROWS[d] * G * (b - 1) for _, d, b in rows) + 0  # biased values in [0, b)
    positions = K_COMBOS * N_COLS // G
    return {
        "rows_combined": R,
        "G_columns_per_group": G,
        "entries_per_combined_value": R * G,
        "honest_max_combined": honest_max,
        "L": 2**L_log,
        "honest_fits_L": honest_max < 2**L_log,
        "positions": positions,
        "position_rows": positions // N_COLS,
        "limb_widths": limbs_widths,
        "lookups_per_position": len(limbs_widths),
        "lookup_rows": len(limbs_widths) * positions // N_COLS,
        "helpers": math.ceil(len(limbs_widths) / 2),
        "h_rows": math.ceil(len(limbs_widths) / 2) * (positions // N_COLS) * 2,
        "a2_limb_rows": (len(limbs_widths) - 1) * (positions // N_COLS),
    }


tB = tier(TIER_B_ROWS, 16, 28, [16, 12])
tH = tier(TIER_H_ROWS, 32, 36, [16, 16, 4])
assert tB["honest_fits_L"] and tH["honest_fits_L"]

b4_counts = {d: sum(1 for (n, *_ ) in v if n not in TIER_B | TIER_H | DROPPED) for d, v in LOOKUPS.items()}
assert b4_counts == {"L": 2, "D": 16, "Q": 4, "Kv": 4, "F": 4, "S": 4}
A2_HIST_ROWS = 6   # histogram sub-planes for families 16 (4), 12 (1), 4 (1) used by the combined limbs
A2_DATA = tB["a2_limb_rows"] + tH["a2_limb_rows"] + A2_HIST_ROWS
A2_MASK = 8        # D12a: 2*sites + 2 with three sites (C_B, C_H, TAB)  [ESTIMATE]
b4_lookup_rows = lookup_rows(b4_counts, tB["lookup_rows"] + tH["lookup_rows"])
b4_h_data = h_rows(b4_counts, tB["h_rows"] + tH["h_rows"])
b4_a_data = A_DATA_TODAY - ROWS["F"]          # HT plane (128 rows) removed
NEW_A_SITE_MASK = 4                            # two new A claim sites (combination points), 2 rows each


# ---------------------------------------------------------------------------
# 3. No-wrap at the bounds each design PROVES  (|E| < p needed; D56 inventory rows)
# ---------------------------------------------------------------------------
def nowrap(bounds):
    b = bounds
    W, MQ, MK, MV, MO, MG, MU, MD = 127, 2**5, 2**5, 2**6, 2**8, 2**14, 2**4, 2**6
    A_ACT = 32767 * 2**15
    rel = {
        "1 Q requant": 2**15 * b["Q"] + 2**15 + 4096 * MQ * W * b["Y"],
        "2 K requant": 2**15 * b["K"] + 2**15 + 4096 * MK * W * b["Y"],
        "3 V requant": 2**16 * b["V"] + 2**16 + 4096 * MV * W * b["Y"],
        "4 Wo requant": 2**21 * b["AO"] + 2**21 + 4096 * MO * W * b["O"],
        "5 gate requant": 2**18 * 2048 + 2**18 + 4096 * MG * W * b["YM"],
        "6 up requant": 2**12 * b["U16"] + 2**12 + 4096 * MU * W * b["YM"],
        "7 down requant": 2**20 * b["Z16"] + 2**20 + 14336 * MD * W * b["H16"],
        "8 score requant": 2**18 * b["S8"] + 2**18 + 128 * b["QR"] * b["KR"],
        "9 PV requant (naive)": 2**12 * b["O"] + 2**12 + 128 * b["P"] * b["V"],
        "10 product": A_ACT * b["U16"] + 2**16 * b["H16"] + 2**17,
        "12 norm_a division": 127 * b["X"] * 2**21 + 4 * 2**24 + 8 * 2**24 * b["Y"] + 2**24,
        "13 norm_m division": 127 * b["X1"] * 2**21 + 4 * 2**24 + 8 * 2**24 * b["YM"] + 2**24,
        "15 sum of squares (norm_a)": 4096 * b["X"] ** 2 + 2**48 + 2**40,
        "15 sum of squares (norm_m)": 4096 * b["X1"] ** 2 + 2**48 + 2**40,
        "18 residual 1": b["X1"] + b["X"] + b["AO"],
        "18 residual 2": b["X2"] + b["X1"] + b["Z16"],
        "19 RoPE (q)": 2 * 2**7 * b["Q"] + 2**7 * b["QR"] + 2**8,
        "20 softmax c2": 2**9 * 2**12 + b["P"] * 2**17 + 2**16,
    }
    return {k: (lg(v), v < P) for k, v in rel.items()}


int16 = 2**15
today_b = {k: int16 for k in ["X", "Y", "AO", "X1", "YM", "Z16", "X2", "Q", "QR", "O", "K", "V", "KR", "U16"]}
today_b.update({"S8": 127, "P": 2**13, "H16": 2**23})
LB, LH = 2**28 + 2**15, 2**36 + 2**23          # proved |w| < L + bias
b4_b = dict(today_b)
for w in ["Y", "Q", "O", "K", "V", "U16", "S8", "P"]:
    b4_b[w] = LB
b4_b["H16"] = LH
b4_b["AO"] = b4_b["Z16"] = 2**16              # implied by the exact residuals
# negative control: tier B's bound also given to the words B4 keeps exact (X, X1, X2, YM, QR, KR)
all_one_tier = dict(b4_b)
for w in ["X", "X1", "X2", "YM", "QR", "KR"]:
    all_one_tier[w] = LB


# ---------------------------------------------------------------------------
# 4. The combination lemma, checked exhaustively on a small prime field
# ---------------------------------------------------------------------------
def lemma_check(p=61, L=6):
    """For every pair (s, v) in F_p^2 with |v|_centered >= L, at most one c in {0,1} puts
    s + c v in [0, L): pass probability <= 1/2.  For c in {-1,0,1} the worst case is 2/3
    (v = (u + p)/2 with u small odd: s +- v both small).  With a public scale sigma = 2 a
    'small' sigma*v does NOT make v small (v = 1/2)."""
    def cen(x):
        x %= p
        return x if x <= p // 2 else x - p
    I = set(range(L))
    worst_bin = Fraction(0)
    worst_ter = Fraction(0)
    for s, v in product(range(p), range(p)):
        if abs(cen(v)) < L:
            continue
        pb = Fraction(sum(((s + c * v) % p) in I for c in (0, 1)), 2)
        pt = Fraction(sum(((s + c * v) % p) in I for c in (-1, 0, 1)), 3)
        worst_bin = max(worst_bin, pb)
        worst_ter = max(worst_ter, pt)
    half = pow(2, p - 2, p)
    scaled_counterexample = {"v": half, "v_centered": cen(half), "sigma_v": (2 * half) % p}
    return {"p": p, "L": L, "worst_pass_binary": str(worst_bin), "worst_pass_ternary": str(worst_ter),
            "scaled_coefficient_counterexample": scaled_counterexample}


# ---------------------------------------------------------------------------
# 5. Soundness: per-round errors and the block zone (Part 7 V2, Part 9 W2)
# ---------------------------------------------------------------------------
BIAS4 = (1 + P / 2**128) ** 4
U110 = 2.0**-110


def logup(N):
    return {"alpha": (N + 2 * T_D - 1) / F2 * BIAS4, "both": (N + 4 * T_D - 1) / F2 * BIAS4}


def zone(N, openings, extra=0.0):
    lu = logup(N)["both"]
    return lu + openings * 2.0**-111 + 2.0**-106 + 2.0**-111 + extra


N_today = 32_276_480 + EXP_ACT_QUERIES
N_b4 = b4_lookup_rows * N_COLS + EXP_ACT_QUERIES
GKR_ROUND_NUMERATOR = 3 * sum(range(25)) + 7 * 25 + 2 * 25      # layers k=1..25: 3(k-1)+7 rounds, + r_k, lambda_k
soundness = {}
for name, N, openings, extra, kmax_extra in [
        ("today (W16R2)", N_today, 4, 0.0, None),
        ("B4", N_b4, 5, 2.0**-K_COMBOS, 2.0**-K_COMBOS),
        ("B5 (all lookups, H retired)", N_today, 3, GKR_ROUND_NUMERATOR / F2, 7 / F2),
        ("B4 then B5", N_b4, 4, 2.0**-K_COMBOS + GKR_ROUND_NUMERATOR / F2, 2.0**-K_COMBOS)]:
    lu = logup(N)
    # the largest single-round error: LogUp's alpha, or the option's new round if larger
    # (M's opening, <= 2^-106, and every other round are below LogUp's alpha in all options)
    rate = max(lu["alpha"], kmax_extra or 0.0)
    z = zone(N, openings, extra)
    soundness[name] = {"N_lookups": N, "logup_alpha_log2": lg(lu["alpha"]), "rate_log2": lg(rate),
                       "zone_log2": lg(z), "zone_units_2^-110": z / U110,
                       "new_round_log2": (lg(kmax_extra) if kmax_extra else None)}


# ---------------------------------------------------------------------------
# 6. Time model, one serial block, calibrated on A1 (a1_phases.log, wall 0.591 s)  [MEASURED inputs]
# ---------------------------------------------------------------------------
A1 = {  # seconds, first block of results/zk60_h124_witness_20261104/a1_phases.log
    "A rows": 0.026, "A lookups+hist": 0.014, "A exp/act idx": 0.002, "A masks": 0.005, "A commit": 0.078,
    "M commit": 0.006, "H inv range": 0.024, "H inv exp/act": 0.008, "H release": 0.002, "H table helpers": 0.004,
    "H masks+zs": 0.003, "H commit": 0.072,
    "s00-13": 0.061, "s14 D": 0.045, "s15 Q": 0.023, "s16 Kv": 0.006, "s17 S": 0.028, "s18 F": 0.106,
    "s19 TAB": 0.013, "s20 ZS": 0.001, "s21-22 IO": 0.009,
    "open M": 0.003, "open A": 0.023, "open H": 0.018, "B_k commit": 0.008,
}
TABLES = {"s14 D": 36, "s15 Q": 15, "s16 Kv": 15, "s17 S": 19, "s18 F": 19, "s19 TAB": 58}  # elem-terms/(2 cube)
GPU_PER_BLOCK = {"commits": 0.055, "zc rounds": 0.074 + 0.002, "other": 0.165 - 0.055 - 0.076}
ELEM_TODAY = {"s14 D": 37.75e6, "s15 Q": 15.73e6, "s16 Kv": 3.93e6, "s17 S": 19.92e6, "s18 F": 79.69e6,
              "s19 TAB": 1.90e6, "s20 ZS": 0.066e6, "rest": 16.97e6}
CUBE = {"s14 D": 2**19, "s15 Q": 2**19, "s16 Kv": 2**17, "s17 S": 2**19, "s18 F": 2**21}
# GKR on Metal (H107-H116 projection.json), per 2^25 leaves: 52 base products / leaf
GKR_BASE_PER_LEAF = 1_740_971_704 / 2**25
KBENCH = (88e9, 97e9)
GKR_EFF = (0.30, 0.60)


def gkr_gpu_seconds(leaves, eff):
    lo = GKR_BASE_PER_LEAF * leaves / (KBENCH[1] * eff[1])
    hi = GKR_BASE_PER_LEAF * leaves / (KBENCH[0] * eff[0])
    return lo, hi


def forest(n):
    """two power-of-two trees covering n leaves: the largest power of two <= n, plus one
    tree padded to cover the rest (a ragged bottom layer would make the work ~n instead)"""
    big = 1 << (n.bit_length() - 1)
    rest = n - big
    return [big] + ([1 << (rest - 1).bit_length()] if rest > 0 else [])


def leaves_for(range_lookups, with_exp_act):
    return range_lookups + 110_772 + 256 + ((EXP_ACT_QUERIES + 4 * 4096 + 512) if with_exp_act else 0)


def serial_model(option):
    t = dict(A1)
    lo_add = hi_add = 0.0
    notes = []
    tabs = dict(TABLES)            # tables per big zero-check after the change
    if option in ("B4", "B4+B5"):
        a_rows = A_ROWS_TODAY - ROWS["F"] + NEW_A_SITE_MASK
        t["A commit"] *= a_rows / A_ROWS_TODAY
        t["A rows"] *= a_rows / A_ROWS_TODAY
        t["A lookups+hist"] *= b4_lookup_rows / 1970
        t["open A"] *= a_rows / A_ROWS_TODAY
        # A2 commit (proxy: B_k 32 rows 6-8 ms, M 50 rows 6 ms), combination GEMM, limbs + histograms,
        # the two combination sumchecks (partial evaluation of 432 rows + 12-13 rounds), A2 opening and
        # the new claim groups, the new slots' CFS mask rows in M
        lo_add += 0.004 + 0.002 + 0.0005 + 0.002 + 0.002 + 0.0005
        hi_add += 0.008 + 0.006 + 0.001 + 0.004 + 0.0035 + 0.001
        if option == "B4":
            lo_add += 0.0035; hi_add += 0.006                        # the C_B / C_H zero-checks (2^17, 2^16)
        else:
            lo_add += 0.0005; hi_add += 0.001                        # under B5: only their leaf-claim terms
        tabs["s19 TAB"] += A2_HIST_ROWS
        tabs["s18 F"] -= 1                                            # the HT plane
    if option == "B4":
        t["H inv range"] *= b4_lookup_rows / 1970
        h_rows_new = b4_h_data + H_MASK_ROWS + 2
        t["H commit"] *= h_rows_new / H_ROWS_TODAY
        t["open H"] *= h_rows_new / H_ROWS_TODAY
        for s, r in {"s14 D": 2, "s15 Q": 1, "s16 Kv": 1, "s17 S": 2, "s18 F": 2}.items():
            tabs[s] -= r                                              # helpers removed per domain
    if option in ("B5", "B4+B5"):
        # H retired: every helper, its commit, inverses, opening, TAB/ZS helper work
        for k in ["H inv range", "H inv exp/act", "H release", "H table helpers", "H masks+zs", "H commit",
                  "open H", "s20 ZS"]:
            t[k] = 0.0
        tabs["s19 TAB"] = round(0.15 * TABLES["s19 TAB"])
        helpers = {"s14 D": 10, "s15 Q": 3, "s16 Kv": 3, "s17 S": 5, "s18 F": 5}
        if option == "B4+B5":
            helpers = {"s14 D": 8, "s15 Q": 2, "s16 Kv": 2, "s17 S": 3, "s18 F": 3}
        for s, h in helpers.items():
            tabs[s] += 1 - h            # helpers out, one leaf-claim term in (ZK_DESIGN_NOTE section 3)
    for s in TABLES:
        t[s] = A1[s] * tabs[s] / TABLES[s]
    if option in ("B5", "B4+B5"):
        rng = 32_276_480 if option == "B5" else b4_lookup_rows * N_COLS
        leaves = leaves_for(rng, True)
        padded = sum(forest(leaves))
        # serial block: the 1101 projection's full range 0.040-0.105 s at 2^25, scaled by padded leaves
        g_lo, g_hi = 0.040 * padded / 2**25, 0.105 * padded / 2**25
        lo_add += g_lo + 0.0          # M rows precomputed (witness-free) at the low end
        hi_add += g_hi + 0.017        # +144 M rows on the path at the high end
        notes.append(f"GKR leaves {leaves:,} -> forest {forest(leaves)}")
    base = sum(t.values())
    today = sum(A1.values())
    lo, hi = base + lo_add, base + hi_add
    # the same phase-scaling method predicted x1.42 for W16 and x1.30 was measured
    # (results/zk60_limb16_20261031/DESIGN.md): only 78% of the modelled saving appeared
    hair = 0.78
    return {"low_s": lo, "high_s": hi, "speedup": (today / hi, today / lo),
            "speedup_haircut": (today / (today - hair * (today - hi)), today / (today - hair * (today - lo))),
            "notes": notes}


def stream_model(option):
    """GPU-bound fork stream on the Mac: 0.165 s of GPU per block (plan section 1)."""
    rows_today = A_ROWS_TODAY + H_ROWS_TODAY + 32
    elem = dict(ELEM_TODAY)
    commits = GPU_PER_BLOCK["commits"]
    extra_lo = extra_hi = 0.0
    if option == "B4":
        rows = (A_ROWS_TODAY - 128 + NEW_A_SITE_MASK) + (b4_h_data + H_MASK_ROWS + 2) + (A2_DATA + A2_MASK) + 32
        commits *= rows / rows_today
        extra_lo += 0.0005; extra_hi += 0.001     # A2's fixed per-commit cost on the device
        for s, tabs in {"s14 D": 34, "s15 Q": 14, "s16 Kv": 14, "s17 S": 17, "s18 F": 16}.items():
            elem[s] = 2 * tabs * CUBE[s]
        elem["s19 TAB"] *= 64 / 58
        elem["rest"] += 2 * 6 * 2**17 + 2 * 7 * 2**16 + 3.5e6
        extra_lo += 0.001; extra_hi += 0.002      # combination GEMM on the device
    if option in ("B5", "B4+B5"):
        a = A_ROWS_TODAY if option == "B5" else (A_ROWS_TODAY - 128 + NEW_A_SITE_MASK + A2_DATA + A2_MASK)
        commits *= (a + 32) / rows_today
        if option == "B4+B5":
            extra_lo += 0.0015; extra_hi += 0.003
        hel = {"s14 D": 10, "s15 Q": 3, "s16 Kv": 3, "s17 S": 5, "s18 F": 5}
        for s, h in hel.items():
            tabs = TABLES[s] - (1 if (option == "B4+B5" and s == "s18 F") else 0)
            elem[s] = 2 * (tabs - h + 1) * CUBE[s]
        elem["s19 TAB"] = 0.3e6
        elem["s20 ZS"] = 0.0
        if option == "B4+B5":
            elem["rest"] += 3.5e6
        rng = 32_276_480 if option == "B5" else b4_lookup_rows * N_COLS
        leaves = sum(forest(leaves_for(rng, True)))
        g = gkr_gpu_seconds(leaves, GKR_EFF)
        extra_lo += g[0]; extra_hi += g[1]
    zc = GPU_PER_BLOCK["zc rounds"] * sum(elem.values()) / sum(ELEM_TODAY.values())
    base = commits + zc + GPU_PER_BLOCK["other"]
    today = sum(GPU_PER_BLOCK.values())
    res = {"gpu_low_s": base + extra_lo, "gpu_high_s": base + extra_hi,
           "speedup": (today / (base + extra_hi), today / (base + extra_lo))}
    if option in ("B5", "B4+B5"):
        rng = 32_276_480 if option == "B5" else b4_lookup_rows * N_COLS
        leaves = sum(forest(leaves_for(rng, True)))
        g_lo = gkr_gpu_seconds(leaves, GKR_EFF)[0]
        no_gkr = base + extra_lo - g_lo
        mid_rate = sum(KBENCH) / 2
        for ref_name, ref in [("today", today), ("B4", stream_model("B4")["gpu_low_s"] if option == "B4+B5" else None)]:
            if ref is None:
                continue
            budget = ref - no_gkr
            res[f"break_even_gkr_efficiency_vs_{ref_name}"] = GKR_BASE_PER_LEAF * leaves / (budget * mid_rate)
    return res


# ---------------------------------------------------------------------------
# 7. Receipt bytes per block  [ESTIMATE: columns Q*rows*8 + paths + groups*(n+Q)*16]
# ---------------------------------------------------------------------------
GROUP_B = (N_COLS + Q_OPEN) * 16
PATH_B = Q_OPEN * 15 * 32
H_GROUPS = 8


def receipt(option):
    today = 23.3e6
    d = 0.0
    if option == "B4":
        d += (-(128) + NEW_A_SITE_MASK) * Q_OPEN * 8
        d += ((b4_h_data + H_MASK_ROWS + 2) - H_ROWS_TODAY) * Q_OPEN * 8
        d += (A2_DATA + A2_MASK) * Q_OPEN * 8 + PATH_B + 4 * GROUP_B
    if option in ("B5", "B4+B5"):
        d -= H_ROWS_TODAY * Q_OPEN * 8 + PATH_B + H_GROUPS * GROUP_B
        d += 22_000 + 144 * 256 * 8 * 0.5
        if option == "B4+B5":
            d += (-(128) + NEW_A_SITE_MASK) * Q_OPEN * 8 + (A2_DATA + A2_MASK) * Q_OPEN * 8 + PATH_B + 3 * GROUP_B
    return {"per_block_MB": (today + d) / 1e6, "delta_MB": d / 1e6, "per_request_delta_MB_32_blocks": 32 * d / 1e6}


# ---------------------------------------------------------------------------
# 8. Rows committed per option
# ---------------------------------------------------------------------------
def rows(option):
    if option == "today":
        return {"A_data": A_DATA_TODAY, "A2_data": 0, "H_data": 2514, "lookup_rows": 1970}
    if option == "B4":
        return {"A_data": b4_a_data, "A2_data": A2_DATA, "H_data": b4_h_data, "lookup_rows": b4_lookup_rows}
    if option == "B5":
        return {"A_data": A_DATA_TODAY + 1, "A2_data": 0, "H_data": 0, "lookup_rows": 1970}
    if option == "B4+B5":
        return {"A_data": b4_a_data + 1, "A2_data": A2_DATA, "H_data": 0, "lookup_rows": b4_lookup_rows}


def main():
    out = {}
    out["inventory"] = {d: [{"name": n, "width": w, "kind": k, "relation": r,
                             "b4": ("tier B" if n in TIER_B else "tier H" if n in TIER_H else
                                    "dropped (implied)" if n in DROPPED else "exact")}
                            for (n, w, k, r) in v] for d, v in LOOKUPS.items()}
    kinds = {}
    for d, v in LOOKUPS.items():
        for (n, w, k, r) in v:
            kinds.setdefault(k, 0)
            kinds[k] += ROWS[d]
    out["lookup_rows_by_kind_today"] = kinds
    out["tiers"] = {"B": tB, "H": tH}
    out["b4_counts_per_position"] = b4_counts
    out["rows"] = {o: rows(o) for o in ["today", "B4", "B5", "B4+B5"]}
    for o, r in out["rows"].items():
        r["total_data"] = r["A_data"] + r["A2_data"] + r["H_data"]
    out["nowrap"] = {"today": nowrap(today_b), "B4": nowrap(b4_b), "one tier over all words (rejected)": nowrap(all_one_tier)}
    out["lemma"] = lemma_check()
    out["soundness"] = soundness
    out["serial_block"] = {o: serial_model(o) for o in ["B4", "B5", "B4+B5"]}
    out["serial_block"]["today_s"] = sum(A1.values())
    out["gpu_stream"] = {o: stream_model(o) for o in ["B4", "B5", "B4+B5"]}
    out["receipt"] = {o: receipt(o) for o in ["B4", "B5", "B4+B5"]}
    out["gkr_leaves"] = {
        "B5": leaves_for(32_276_480, True), "B5_forest": forest(leaves_for(32_276_480, True)),
        "B4+B5": leaves_for(b4_lookup_rows * N_COLS, True), "B4+B5_forest": forest(leaves_for(b4_lookup_rows * N_COLS, True))}
    print(json.dumps(out, indent=1, default=str))


if __name__ == "__main__":
    main()

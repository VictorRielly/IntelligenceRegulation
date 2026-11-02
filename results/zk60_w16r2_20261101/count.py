#!/usr/bin/env python3
"""W16R2 (D59) soundness recount, exact rational arithmetic. Written for ACCOUNTING.md; every input is a
named constant below or a value the code prints (`W16R2-ACCOUNTING` lines of the test
`private_block::w16r2_tests::w16r2_accounting_inputs_are_printed_from_the_code`).

Usage:  python3 count.py [<log with W16R2-ACCOUNTING lines>]
With a log, its values are parsed and checked equal to the constants below (so a moved input fails here).

Formulas (all |Fp2| = p^2, p = 2^64 - 2^32 + 1; every term an interactive per-attempt bound, D27 A2):
  regular opening (A, H, a boundary, an endpoint), K = n + Q, N = n * inv_rate:
    D15 (delta/3):  column ((2N + K)/(3N))^Q            field (floor(delta N / 3) + 1 + 4096)/p^2, delta = 1 - K/N
    D59 (delta/2):  column (1 - (e + 1)/N)^Q, e = floor((N - K)/2)       field (N + 4096)/p^2
    (4096 = the R14 counter's carried PCS ceiling, REVIEW_R14 A5; the lemma check's section 6 carries it too)
  mask opening M (zk.rs constants, both profiles): column (3/4)^256, field (2*512 + 1 + 4096)/p^2
  LogUp, per block (REVIEW_W16 section 1, the R13/R14 accounting): (N_lk + 4 T_d - 1)/p^2,
    N_lk = range/byte queries + exp queries + ACT queries, T_d = 256 + 256 + 4096 G + sum 2^w, G = 4
  sumcheck rounds, per block: sum over slots (main + ext) * degree / p^2
  zero-check / batching / output-point allowance, per block (REVIEW_R14's): sum (3 (main + ext) + 3) / p^2
  a run of L blocks: 3L + 1 regular openings (2L block, L - 1 boundaries, 2 endpoints), L mask openings,
    L LogUp blocks, L sumcheck blocks; the whole run is the union (sum) of every term (D15's reading, A6)
"""
import json
import math
import re
import sys
from fractions import Fraction as Q_

P = 2**64 - 2**32 + 1
F2 = P * P
CEIL = 4096  # the carried PCS ceiling per opening
G = 4  # activation groups, conservative (REVIEW_W16 section 1)

# ---- the inputs, as the code prints them (2026-11-01, this tree)
PROFILES = {
    # name: (regime, n, inv_rate, Q, a_rows, h_rows, lookup_words, exp, act, range_entries, sc, zc)
    "W16R2_8B_T128_H24": ("delta/2", 2**14, 2, 260, 2501, 2602, 32_276_480, 524_288, 2_097_152, 110_772, 1099, 1179),
    "W16_8B_T128_H24": ("delta/3", 2**14, 4, 256, 2501, 2602, 32_276_480, 524_288, 2_097_152, 110_772, 1099, 1179),
    "W16R2_SHIELD_T128_H24": ("delta/2", 2**14, 2, 260, 2501, 2602, 32_276_480, 524_288, 2_097_152, 110_772, 1159, 1179),
    "W16_SHIELD_T128_H24": ("delta/3", 2**14, 4, 256, 2501, 2602, 32_276_480, 524_288, 2_097_152, 110_772, 1159, 1179),
    "W16R2_RUNG_H24": ("delta/2", 2**14, 2, 260, 317, 198, 1_015_808, 16_384, 32_768, 110_774, 924, 957),
    "W16_RUNG_H24": ("delta/3", 2**14, 4, 256, 317, 198, 1_015_808, 16_384, 32_768, 110_774, 924, 957),
}
# the run lengths counted: Llama-3-8B 32 layers, Shieldstral-1.0-3B 26, the dev rung as one block and as
# the 3-block run the gate chain proves
RUNS = {"W16R2_8B_T128_H24": [32], "W16_8B_T128_H24": [32], "W16R2_SHIELD_T128_H24": [26], "W16_SHIELD_T128_H24": [26], "W16R2_RUNG_H24": [1, 3], "W16_RUNG_H24": [1, 3]}


def lg(x: Q_) -> float:
    return math.log2(x.numerator) - math.log2(x.denominator)


def regular(regime, n, inv_rate, q):
    """(column, field) of one regular opening, exact"""
    nn, k = n * inv_rate, n + q
    if regime == "delta/3":
        col = Q_(2 * nn + k, 3 * nn) ** q
        delta = Q_(nn - k, nn)
        field = Q_(math.floor(delta * nn / 3) + 1 + CEIL, F2)
    else:
        e = (nn - k) // 2
        col = Q_(nn - e - 1, nn) ** q
        field = Q_(nn + CEIL, F2)
    return col, field


MASK_COL = Q_(3, 4) ** 256
MASK_FIELD = Q_(2 * 512 + 1 + CEIL, F2)


def per_block(v):
    _, n, ir, q, a, h, lw, ex, ac, re_, sc, zc = v
    t_d = 256 + 256 + 4096 * G + re_
    n_lk = lw + ex + ac
    return {"logup": Q_(n_lk + 4 * t_d - 1, F2), "sumcheck": Q_(sc, F2), "zerocheck": Q_(zc, F2), "N_lk": n_lk, "T_d": t_d}


def run(name, l):
    v = PROFILES[name]
    col, field = regular(v[0], v[1], v[2], v[3])
    b = per_block(v)
    reg = 3 * l + 1
    terms = {
        "column": reg * col + l * MASK_COL,
        "pcs_field": reg * field + l * MASK_FIELD,
        "logup": l * b["logup"],
        "sumcheck": l * b["sumcheck"],
        "zerocheck": l * b["zerocheck"],
    }
    return terms, sum(terms.values())


def parse_log(path):
    got = {}
    for line in open(path, errors="replace"):
        i = line.find("W16R2-ACCOUNTING ")
        if i < 0:
            continue
        s = line[i + len("W16R2-ACCOUNTING "):].strip()
        s = re.sub(r"\[(\(.*?\))\]", lambda m: '"' + m.group(1) + '"', s)
        d = json.loads(s)
        got[d["name"]] = d
    for name, v in PROFILES.items():
        d = got[name]
        want = (v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8], v[9], v[10], v[11])
        have = ("delta/2" if d["regime"] == "UniqueDecoding" else "delta/3", d["n"], d["inv_rate"], d["Q"], d["a_rows"], d["h_rows"], d["lookup_words"], d["exp_queries"], d["act_queries"], d["range_entries"], d["sumcheck_main_ext_degree"], d["zerocheck_allowance"])
        assert have == want, f"{name}: the code prints {have}, this script carries {want}"
        assert d["q_pad"] == d["Q"] and d["endpoint_inv_rate"] == d["inv_rate"] and d["endpoint_log_n"] == d["log_cols"], name
    print(f"inputs: all {len(PROFILES)} profiles' values equal the code's printed lines in {path}")


def main():
    if len(sys.argv) > 1:
        parse_log(sys.argv[1])
    print("\n== per regular opening (A, H, a boundary, an endpoint)")
    print(f"{'profile':<24} {'rule':<8} {'n':>6} {'N':>6} {'Q':>4} {'K':>6} {'e':>6} {'column':>10} {'field':>10} {'both':>10}")
    for name, v in PROFILES.items():
        col, field = regular(v[0], v[1], v[2], v[3])
        nn, k = v[1] * v[2], v[1] + v[3]
        e = (nn - k) // 2 if v[0] == "delta/2" else math.floor(Q_(nn - k, nn) * nn / 3)
        print(f"{name:<24} {v[0]:<8} {v[1]:>6} {nn:>6} {v[3]:>4} {k:>6} {e:>6} {lg(col):>10.3f} {lg(field):>10.3f} {lg(col + field):>10.3f}")
    print(f"{'M (both)':<24} {'delta/3':<8} {512:>6} {4096:>6} {256:>4} {1024:>6} {1024:>6} {lg(MASK_COL):>10.3f} {lg(MASK_FIELD):>10.3f} {lg(MASK_COL + MASK_FIELD):>10.3f}")
    print("\n== per block: LogUp, sumcheck, zero-check allowance")
    for name, v in PROFILES.items():
        b = per_block(v)
        print(f"{name:<24} N_lk {b['N_lk']:>11,} T_d {b['T_d']:>8,}  LogUp 2^{lg(b['logup']):.3f}  sumcheck 2^{lg(b['sumcheck']):.3f}  zero-check 2^{lg(b['zerocheck']):.3f}")
    print("\n== whole run (union bound), log2 of each term and of the sum")
    print(f"{'profile':<24} {'L':>3} {'openings':>9} {'column':>9} {'pcs fld':>9} {'logup':>9} {'sumchk':>9} {'zerochk':>9} {'WHOLE':>9}")
    out = {}
    for name in PROFILES:
        for l in RUNS[name]:
            terms, total = run(name, l)
            out[(name, l)] = total
            print(f"{name:<24} {l:>3} {f'{3*l+1}+{l}M':>9} " + " ".join(f"{lg(terms[k]):>9.3f}" for k in ["column", "pcs_field", "logup", "sumcheck", "zerocheck"]) + f" {lg(total):>9.3f}")
    print("\n== W16R2 against W16, bits (positive = W16R2 stronger)")
    for r2, w in [("W16R2_8B_T128_H24", "W16_8B_T128_H24"), ("W16R2_SHIELD_T128_H24", "W16_SHIELD_T128_H24"), ("W16R2_RUNG_H24", "W16_RUNG_H24")]:
        cr = lg(sum(regular(*PROFILES[r2][:4])))
        cw = lg(sum(regular(*PROFILES[w][:4])))
        print(f"{r2:<24} per opening {-cr:.3f} vs {-cw:.3f} ({cw - cr:+.3f})" + "".join(f"; L{l} whole run {-lg(out[(r2, l)]):.3f} vs {-lg(out[(w, l)]):.3f} ({lg(out[(w, l)]) - lg(out[(r2, l)]):+.3f})" for l in RUNS[r2]))
    # the lemma check's own figures (section 5 and 6), reproduced
    col_r2, _ = regular("delta/2", 2**14, 2, 260)
    col_w, _ = regular("delta/3", 2**14, 4, 256)
    col_259, _ = regular("delta/2", 2**14, 2, 259)
    print(f"\nlemma-check cross-check: Q 260 2^{lg(col_r2):.3f} (stated 2^-105.946, exact form), Q 259 2^{lg(col_259):.3f} (stated 2^-105.53, the (1 - delta/2)^Q form), W16 2^{lg(col_w):.3f} (stated 2^-105.61)")
    assert abs(lg(col_r2) + 105.946) < 0.001 and abs(lg(col_259) + 105.53) < 0.01 and abs(lg(col_w) + 105.61) < 0.005
    assert lg(col_259) > lg(col_w) > lg(col_r2), "Q = 260 is not the minimum that keeps W16's per-opening figure"
    # the reduction bias of the m uniform row weights (lemma check refinement 3), at the largest m
    m = 2606  # the largest committed row count measured (the A/B's synthetic H; the lemma check's m)
    bias = (2 * m) * P / 2**128
    print(f"row-weight reduction bias (1 + p/2^128)^(2m) at m = {m}: 1 + 2^{math.log2(bias):.2f} (multiplies the column bound; negligible)")
    print(f"powers of one challenge instead (BCIKS20 Thm 1.6), the field term would be (m - 1) N / p^2 = 2^{lg(Q_((m - 1) * 2**15, F2)):.2f} at m = {m}, N = 2^15")


if __name__ == "__main__":
    main()

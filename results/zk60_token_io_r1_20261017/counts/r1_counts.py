"""Rung R1 figures from the design's counter (DESIGN.md v3 section 6.1), written BEFORE the construction.

Imports `token_io_count.py` (v3) read-only from results/zk60_token_io_design_20261017/ and instantiates
its own classes at the R1 rung: the rung_tc block geometry (T32 / d384 / f512, 12 heads of 32 over 4
KV heads, block row width 2^10), L = 2 blocks, a synthetic vocabulary V = 300 (V_pad 512), stage IN
option (b) and stage OUT mode (i) public last row, both stages at row width 2^12, token endpoints at
2^8 rate 1/8 (one claim site each, data + 5 rows). Output: r1_counts.json (the numbers the Rust test
`token_io_tests::the_counted_layout_is_the_counters` asserts). One thread, pure integers, < 1 s.
Labels: every number here is [COUNTED].
"""
import json
import os
import sys

DESIGN = "/home/victor/IntelligenceRegulation/results/zk60_token_io_design_20261017"
sys.path.insert(0, DESIGN)
import token_io_count as tc  # noqa: E402

R1 = tc.Model("R1 rung_tc, V=300", 384, 300, 512, 12, 32, 4, 2, {32: 10})
T = 32
LOG_STAGE = 12


MULT_BITS = 12          # D25 T4 as amended 20:21 UTC: per-row integer multipliers m_j in [1, 2^12]


def per_row_bound(m, wmax=127):
    """the amended head's logit bound over the multiplier class: 2^12 * d * 127 * wmax"""
    return (1 << MULT_BITS) * m.d * 127 * wmax


def main():
    per_tensor = compute()
    orig = tc.logits_bound
    tc.logits_bound = per_row_bound              # the counter's own formulas, amended bound substituted
    try:
        per_row = compute()
    finally:
        tc.logits_bound = orig
    out = {"labels": per_tensor["labels"], "per_row_12bit_D25_T4_amended": per_row, "per_tensor_counter_as_written": per_tensor}
    print(json.dumps({k: per_row[k] for k in ("stage_in", "stage_out", "argmax", "window_keyed_bits", "logits_bound")}, indent=1, default=str))
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "r1_counts.json"), "w") as fh:
        json.dump(out, fh, indent=1, default=str)


def compute():
    ep_in = tc.input_ep(T)                       # public row: one site, tok plane max(256, T_pad)
    st_in = tc.input_b(R1, T, LOG_STAGE, ep_in)
    st_out, info = tc.output_stage(R1, T, T_out=1, log_cols=LOG_STAGE)
    s_in, s_out = st_in.summary(), st_out.summary()
    # receipt-optimal widths at or above the floor, for the record (the rung uses 2^12, DESIGN 6.1)
    bw_in = tc.best_width(lambda lc: tc.input_b(R1, T, lc, ep_in)).log_cols
    bw_out = tc.best_width(lambda lc: tc.output_stage(R1, T, T_out=1, log_cols=lc)[0]).log_cols
    out = {
        "labels": "[COUNTED]; counter = token_io_count.py v3 (read-only import)",
        "model": {"d": R1.d, "d_pad": R1.d_pad, "V": R1.V, "V_pad": R1.V_pad, "v": R1.v, "L": R1.L, "T": T},
        "stage_in": {k: s_in[k] for k in ("log_cols", "A_rows", "H_rows", "M_rows", "A_elems", "H_elems", "elems",
                                           "a_sites", "h_sites", "slots", "inversions", "fold", "largest_zc", "endpoints",
                                           "per_opening_log2")},
        "stage_in_slots": [(nm, m_, e, dg, t, sz, k) for (nm, m_, e, dg, t, sz, k) in st_in.slots],
        "stage_in_planes": {"A": st_in.a, "H": st_in.h},
        "stage_out": {k: s_out[k] for k in ("log_cols", "A_rows", "H_rows", "M_rows", "A_elems", "H_elems", "elems",
                                             "a_sites", "h_sites", "slots", "u8", "inversions", "fold", "largest_zc",
                                             "endpoints", "per_opening_log2")},
        "stage_out_slots": [(nm, m_, e, dg, t, sz, k) for (nm, m_, e, dg, t, sz, k) in st_out.slots],
        "stage_out_planes": {"A": st_out.a, "H": st_out.h},
        "argmax": info,
        "window_keyed_bits": tc.window_bits(R1, True),
        "logits_bound": tc.logits_bound(R1),
        "best_width_log": {"in": bw_in, "out": bw_out},
        "token_endpoint_per_opening_log2": round(tc.per_opening_log2(8, 8), 2),
        "stage_per_opening_log2": round(tc.per_opening_log2(12, 4), 2),
        "block_per_opening_log2": round(tc.per_opening_log2(10, 4), 2),
    }
    return out


if __name__ == "__main__":
    main()

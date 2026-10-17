"""Rung R2 figures from the design's counter (TinyLlama-1.1B, T32, mode (i), public last row), written before
the R2 construction. The counter's own formulas (token_io_count.py v3, read-only import) with the per-row
head of D25 T4 as amended (logit bound times 2^12) and both stages at row width 2^12 (the tier's floor).
Output r2_counts.json. [COUNTED]. One thread, < 1 s."""
import json, os, sys
sys.path.insert(0, "/home/victor/IntelligenceRegulation/results/zk60_token_io_design_20261017")
import token_io_count as tc  # noqa: E402
T, LOG = 32, 12
tc.logits_bound = lambda m, wmax=127: (1 << 12) * m.d * 127 * wmax
m = tc.TINY
ep = tc.input_ep(T)
si = tc.input_b(m, T, LOG, ep)
so, info = tc.output_stage(m, T, T_out=1, log_cols=LOG)
out = {"model": {"d": m.d, "V": m.V, "V_pad": m.V_pad, "L": m.L, "T": T, "stage_log": LOG},
       "stage_in": {k: si.summary()[k] for k in ("A_rows", "H_rows", "M_rows", "elems", "a_sites", "h_sites", "slots", "fold", "endpoints")},
       "stage_out": {k: so.summary()[k] for k in ("A_rows", "H_rows", "M_rows", "elems", "a_sites", "h_sites", "slots", "u8", "fold", "endpoints")},
       "argmax": info, "best_width": {"in": tc.best_width(lambda lc: tc.input_b(m, T, lc, ep)).log_cols,
                                     "out": tc.best_width(lambda lc: tc.output_stage(m, T, T_out=1, log_cols=lc)[0]).log_cols}}
print(json.dumps(out, indent=1, default=str))
json.dump(out, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "r2_counts.json"), "w"), indent=1, default=str)

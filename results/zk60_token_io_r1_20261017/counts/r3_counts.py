"""Rung R3 figures from the design's counter (Llama-3-8B, T32, mode (i), public last row), written before the R3
construction. The counter's own formulas (token_io_count.py v3, read-only import) with the per-row head of D25 T4
as amended (logit bound times 2^12) and both stages at row width 2^12 (the tier's floor), exactly as r2_counts.py.
Also the counter's receipt per stage, the fold sizes and the block-run side (the counter's 8B T32 block geometry).
Output r3_counts.json. [COUNTED]. One thread, < 1 s."""
import json, os, sys
sys.path.insert(0, "/home/victor/IntelligenceRegulation/results/zk60_token_io_design_20261017")
import token_io_count as tc  # noqa: E402
T, LOG = 32, 12
tc.logits_bound = lambda m, wmax=127: (1 << 12) * m.d * 127 * wmax
m = tc.L3_8B
ep = tc.input_ep(T)
si = tc.input_b(m, T, LOG, ep)
so, info = tc.output_stage(m, T, T_out=1, log_cols=LOG)
keys_in = ("A_rows", "H_rows", "M_rows", "elems", "a_sites", "h_sites", "slots", "fold", "receipt", "endpoints")
keys_out = ("A_rows", "H_rows", "M_rows", "elems", "a_sites", "h_sites", "slots", "u8", "fold", "receipt", "endpoints")
out = {"model": {"d": m.d, "V": m.V, "V_pad": m.V_pad, "L": m.L, "T": T, "stage_log": LOG, "block_log_cols_T32": m.logcols[T]},
       "stage_in": {k: si.summary()[k] for k in keys_in},
       "stage_out": {k: so.summary()[k] for k in keys_out},
       "argmax": info,
       "tables": {"embedding_int16_bytes": m.V * m.d * 2, "head_int8_bytes": m.V * m.d, "multipliers_int64_bytes": m.V * 8,
                  "fold_weights_each": m.V * m.d}}
print(json.dumps(out, indent=1, default=str))
json.dump(out, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "r3_counts.json"), "w"), indent=1, default=str)

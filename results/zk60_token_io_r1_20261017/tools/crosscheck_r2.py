"""Independent reference for the R2 run: rung R0's integer semantics on the export's own last-layer output.

For each sequence written by the Rust test `token_io_r2_prove_to_dir` ($OUT/<seq>/crosscheck.json), recompute
the next token from PUBLIC files only, with R0's own functions (results/zk60_token_io_design_20261017/r0/
token_io_ref.py, imported read-only) vectorised in numpy where R0 loops:
  * x = the export's seq_<seq>/x_out_L21.bin row T - 1 (the native parity makes it the run's B_out row);
  * `final_norm` (uniform gain g0, D24 window, refuses instead of clamping), checked against R0 on this row;
  * logits l_j = m_j (y . W'_j) over the per-row int8 head and its 12-bit multipliers (r2_inputs/);
  * `first_argmax` (numpy's rule).
Compares with the id the output owner decommitted from the receipt, and reports (informational) the fidelity
lane's integer-head token at the same position (data/s4_positions.npz, T32 cal_m1.50/pr_m12_tok) when the
sequence is a held-out one it lists. Writes crosscheck_result.json beside the input. One process, a few seconds.
"""
import hashlib
import json
import os
import sys

import numpy as np

R0 = "/home/victor/IntelligenceRegulation/results/zk60_token_io_design_20261017/r0"
sys.path.insert(0, R0)
import token_io_ref as ref  # noqa: E402

EXPORT = "/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/export/pg_rot1_b4_T32_cal128"
INPUTS = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r2_inputs"
FIDELITY = "/home/victor/IntelligenceRegulation/results/zk60_token_io_fidelity_20261017/data/s4_positions.npz"
HEAD_SHA = "b99cbec5f457e47ca2441de517135ba1bd1870e2ae8abe2038dbd84617436280"
MULT_SHA = "7824019e82a62fd6e36c165b9aabfd3711d03b815731e298b356a734a7ea663f"


def sha(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def main(out):
    assert sha(os.path.join(INPUTS, "head_int8_perrow.bin")) == HEAD_SHA
    assert sha(os.path.join(INPUTS, "head_mult12.bin")) == MULT_SHA
    results = {}
    ok_all = True
    for seq in sorted(os.listdir(out)):
        p = os.path.join(out, seq, "crosscheck.json")
        if not os.path.exists(p):
            continue
        c = json.load(open(p))
        V, d, T = c["V"], c["d"], len(c["tokens"])
        W8 = np.fromfile(os.path.join(INPUTS, "head_int8_perrow.bin"), dtype=np.int8).reshape(V, d)
        m = np.fromfile(os.path.join(INPUTS, "head_mult12.bin"), dtype="<i8")
        xs = np.fromfile(os.path.join(EXPORT, f"seq_{seq}", "x_out_L21.bin"), dtype="<i2").reshape(T, d)
        x = [int(v) for v in xs[T - 1]]
        fn = ref.final_norm(x, c["g0"], c["cn"], c["tn"], c["ceps"])
        y = np.array(fn["y"], dtype=np.int64)
        # exact int64 accumulators, 2,048 rows at a time (|acc| < 2^26)
        acc = np.concatenate([W8[r:r + 2048].astype(np.int64) @ y for r in range(0, V, 2048)])
        W = W8
        # R0's head_logits on the first 64 rows, against the vectorised form
        r0_rows = ref.head_logits(fn["y"], [[int(v) for v in W[j]] for j in range(64)])
        assert list(acc[:64]) == r0_rows, "the vectorised head is not R0's"
        logits = m * acc
        tok = ref.first_argmax([int(v) for v in logits])
        assert tok == int(np.argmax(logits))
        top = np.sort(logits)[-2:]
        agree = tok == c["decommitted_next_token"]
        ok_all &= agree
        r = {"r0_next_token": tok, "decommitted_next_token": c["decommitted_next_token"], "agree": agree,
             "top2_margin": int(top[1] - top[0]), "D": fn["D"], "max_abs_y": int(np.abs(y).max()),
             "max_abs_logit": int(np.abs(logits).max()), "prompt_bos": c["tokens"][0] == 1}
        if os.path.exists(FIDELITY) and seq.startswith("ho"):
            z = np.load(FIDELITY)
            idx = int(seq[2:])
            sel = (z["T32/seq"] == idx) & (z["T32/pos"] == T - 1)
            if sel.sum() == 1:
                r["fidelity_lane_pr_m12_tok_same_position"] = int(z["T32/cal_m1.50/pr_m12_tok"][sel][0])
                r["fidelity_lane_float_head_tok_same_position"] = int(z["T32/float_head_tok"][sel][0])
        results[seq] = r
        print(seq, r)
    with open(os.path.join(out, "crosscheck_result.json"), "w") as fh:
        json.dump({"ok": ok_all, "sequences": results, "reference": "R0 token_io_ref.py (final_norm, head_logits x m_j, first_argmax) on the export's x_out_L21 row T-1"}, fh, indent=1)
    print("ALL AGREE" if ok_all else "DISAGREEMENT")
    return 0 if ok_all else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))

"""Integer-only public-file cross-check of a CLI demo's decommitted next token (round 8; any export).

From the export's PUBLIC token tables and its own sequence (prover side), with rung R0's integer semantics
(results/zk60_token_io_design_20261017/r0/token_io_ref.py, imported read-only; vectorised in numpy where R0
loops), on the export's last-layer output row T - 1 (the prove step's parity makes it the run's B_out row):
  * R0's `final_norm` at the head manifest's calibrated constants (refuses rather than clamps);
  * logits C_j = m_j (y . W'_j) over the per-row int8 head and its 12-bit multipliers, R0's `first_argmax`;
  * the top-2 margin in C and in approximate logits (C / (m_j s_y) is not available without the float scales,
    so the margin is reported in C units and relative to the top value).
Used for TinyLlama (whose float head needs the TinyLlama checkpoint path; the fidelity lane's float-model
reference is reported beside it). usage: crosscheck_int_next_token.py EXPORT SEQ DECOMMITTED OUT.json
"""
import json
import sys
from pathlib import Path

import numpy as np

R0 = "/home/victor/IntelligenceRegulation/results/zk60_token_io_design_20261017/r0"
sys.path.insert(0, R0)
import token_io_ref as ref  # noqa: E402


def main(export, seq, dec, out_path):
    root, dec = Path(export), int(dec)
    td = root / "token_io"
    hm = json.loads((td / "head_manifest.json").read_text())
    fnm = hm["final_norm"]
    V, d = hm["V"], hm["d"]
    man = json.loads((root / f"seq_{seq}" / "manifest.json").read_text())
    T = len(man["token_ids"])
    last = max(int(k[len("x_out_L"):]) for k in man["arrays"] if k.startswith("x_out_L"))
    X = np.fromfile(root / f"seq_{seq}" / f"x_out_L{last:02d}.bin", dtype="<i2").reshape(T, d)
    row = [int(v) for v in X[T - 1]]
    fn = ref.final_norm(row, fnm["g0"], fnm["cn_calibrated"], fnm["tn"], fnm["ceps"])
    y = np.array(fn["y"], dtype=np.int64)
    W = np.fromfile(td / "head_int8_perrow.bin", dtype=np.int8).reshape(V, d).astype(np.int64)
    m = np.fromfile(td / "head_mult12.bin", dtype="<i8").astype(np.int64)
    C = (W @ y) * m
    tok = ref.first_argmax([int(v) for v in C])
    order = np.argsort(-C, kind="stable")
    c1, c2 = int(C[order[0]]), int(C[order[1]])
    out = {"export": str(root), "seq": seq, "T": T, "last_layer": last, "decommitted_next_token": dec,
           "r0_integer_token": int(tok), "second_token": int(order[1]), "integer_top2_margin_C": c1 - c2,
           "integer_top2_margin_relative": (c1 - c2) / abs(c1) if c1 else None, "max_abs_y": int(np.abs(y).max()),
           "agree_integer": dec == tok,
           "final_norm": {"g0": fnm["g0"], "cn": fnm["cn_calibrated"], "tn": fnm["tn"], "ceps": fnm["ceps"]}}
    print(json.dumps(out, indent=1))
    with open(out_path, "w") as f:
        json.dump(out, f, indent=1)
        f.write("\n")
    return 0 if out["agree_integer"] else 1


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:5]))

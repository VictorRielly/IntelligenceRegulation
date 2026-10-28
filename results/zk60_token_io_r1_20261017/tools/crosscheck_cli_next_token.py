"""Cross-check a CLI demo's decommitted next token against the calibration lane's heads (round 7).

The same computation as tools/crosscheck_r3_trained.py, for a `zk60_token_io owner` result instead of an
R3 harness run: from PUBLIC files and the export's own sequence (prover side), with the CALIBRATION LANE'S
functions (results/zk60_8b_calibration_20261017/b8_token_io.py, imported read-only):
  * x = the export's seq_<seq>/x_out_L31.bin row T - 1 (the prove step's parity makes it the run's B_out row);
  * the lane's INTEGER head (final_norm at the head manifest's calibrated constants, int_logits over the
    per-row int8 head, C = m_j l_j, first maximum) and R0's reference on the same row;
  * the lane's FLOAT head on the same integer row (TOKEN_IO_SPEC float path: s_out, inverse rotation,
    float32 RMSNorm with the checkpoint's norm weight, the checkpoint's bf16 lm_head), argmax and margin.
This is the float head on the INTEGER stack's output, not the float model; the fidelity lane's own integer
and float-model references are reported beside it when given.

usage: crosscheck_cli_next_token.py EXPORT SEQ DECOMMITTED_TOKEN OUT.json
About 3 GB peak (the 1 GB bf16 lm_head); run it under the guard (light).
"""
import json
import sys
from pathlib import Path

CAL = "/home/victor/IntelligenceRegulation/results/zk60_8b_calibration_20261017"
R0 = "/home/victor/IntelligenceRegulation/results/zk60_token_io_design_20261017/r0"
sys.path.insert(0, CAL)
import b8_token_io as b8  # noqa: E402
import numpy as np  # noqa: E402

sys.path.insert(0, R0)
import token_io_ref as ref  # noqa: E402


def main(export_dir, seq, dec, out_path):
    root, dec = Path(export_dir), int(dec)
    td = root / "token_io"
    hm = json.loads((td / "head_manifest.json").read_text())
    fnm = hm["final_norm"]
    V, d = hm["V"], hm["d"]
    man = json.loads((root / f"seq_{seq}" / "manifest.json").read_text())
    T = len(man["token_ids"])
    ex = b8.export_info(root)
    X = np.fromfile(root / f"seq_{seq}" / "x_out_L31.bin", dtype="<i2").reshape(T, d)
    xi = X[T - 1:T].astype(np.int64)
    Wr = np.fromfile(td / "head_int8_perrow.bin", dtype=np.int8).reshape(V, d)
    mult = np.fromfile(td / "head_mult12.bin", dtype="<i8").astype(np.int64)
    y, refused = b8.final_norm(xi, fnm["g0"], fnm["cn_calibrated"], fnm["tn"], fnm["ceps"], fnm["window_bits"])
    assert not refused.any(), "the lane's final norm refuses this row"
    C = b8.int_logits(y, Wr) * mult[None, :]
    int_tok = int(C.argmax(-1)[0])
    c1, c2 = b8.top2(C)
    fn = ref.final_norm([int(v) for v in X[T - 1]], fnm["g0"], fnm["cn_calibrated"], fnm["tn"], fnm["ceps"])
    assert list(fn["y"]) == [int(v) for v in y[0]], "R0's final norm differs from the lane's"
    r0_tok = ref.first_argmax([int(v) for v in C[0]])
    ck = b8.tc.open_checkpoint()
    nw = b8.tc.tensor_f32(ck.refs["model.norm.weight"]).astype(np.float32)
    lm_raw = b8.raw_u16(ck, "lm_head.weight")
    Lf = b8.float_head(xi, ex["s_out"], ex["R"], nw, lm_raw)
    float_tok = int(Lf.argmax(-1)[0])
    f1, f2 = b8.top2(Lf)
    out = {"export": str(root), "seq": seq, "T": T, "decommitted_next_token": dec,
           "lane_integer_head_token": int_tok, "r0_integer_token": r0_tok, "integer_top2_margin_C": int(c1[0] - c2[0]),
           "lane_float_head_on_integer_row_token": float_tok, "float_head_top2_margin_logits": float(f1[0] - f2[0]),
           "agree_integer": dec == int_tok == r0_tok, "agree_float_head": dec == float_tok,
           "final_norm": {"g0": fnm["g0"], "cn": fnm["cn_calibrated"], "tn": fnm["tn"], "ceps": fnm["ceps"]}}
    print(json.dumps(out, indent=1))
    with open(out_path, "w") as f:
        json.dump(out, f, indent=1)
        f.write("\n")
    return 0 if out["agree_integer"] else 1


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:5]))

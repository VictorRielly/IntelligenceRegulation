"""Cross-check of the TRAINED Llama-3-8B next-token proof (R3) against the calibration lane's own heads.

For the run written by `token_io_r3_prove_to_dir` with the trained tables ($OUT/trained-<seq>/crosscheck.json),
recompute the next token at the last position from public files only, with the CALIBRATION LANE'S functions
(results/zk60_8b_calibration_20261017/b8_token_io.py, imported read-only):
  * x = the export's seq_<seq>/x_out_L31.bin row T - 1 (the native parity makes it the run's B_out row);
  * the lane's INTEGER head: `final_norm` (its vectorised form of tlcalib.i_norm, uniform gain) at the head
    manifest's g0 / Cn (calibrated) / tn / Ceps, `int_logits` over head_int8_perrow.bin, C = m_j l_j with
    head_mult12.bin, first maximum;
  * the lane's FLOAT head: `float_head` (TOKEN_IO_SPEC float path: s_out, inverse rotation, float32 RMSNorm
    with the checkpoint's norm weight, the checkpoint's bf16 lm_head) on the same row, its argmax and top-2
    margin;
  * R0's own `final_norm` / `head_logits` / `first_argmax` on the same row (the design lane's reference).
Compares all with the id the output owner decommitted from the receipt; writes crosscheck_trained_result.json.
Reads the 8B checkpoint's lm_head (1 GB bf16) and norm weight; about 3 GB peak; run it under the guard (light).
"""
import json
import os
import sys
from pathlib import Path

CAL = "/home/victor/IntelligenceRegulation/results/zk60_8b_calibration_20261017"
R0 = "/home/victor/IntelligenceRegulation/results/zk60_token_io_design_20261017/r0"
sys.path.insert(0, CAL)
import b8_token_io as b8  # noqa: E402  (the lane's module; sets ZK60_MODEL=llama3-8b through b5_8b)
import numpy as np  # noqa: E402

sys.path.insert(0, R0)
import token_io_ref as ref  # noqa: E402


def main(run_dir, export_dir):
    run_dir, root = Path(run_dir), Path(export_dir)
    c = json.load(open(run_dir / "crosscheck.json"))
    assert c["tables"] == "trained"
    td = root / "token_io"
    hm = json.loads((td / "head_manifest.json").read_text())
    fnm = hm["final_norm"]
    assert (c["g0"], c["cn"], c["tn"], c["ceps"]) == (fnm["g0"], fnm["cn_calibrated"], fnm["tn"], fnm["ceps"]), "the run's final norm is not the manifest's calibrated one"
    V, d, T = hm["V"], hm["d"], len(c["tokens"])
    ex = b8.export_info(root)
    X = np.fromfile(root / f"seq_{c['seq']}" / "x_out_L31.bin", dtype="<i2").reshape(T, d)
    xi = X[T - 1:T].astype(np.int64)
    # the lane's integer head
    Wr = np.fromfile(td / "head_int8_perrow.bin", dtype=np.int8).reshape(V, d)
    mult = np.fromfile(td / "head_mult12.bin", dtype="<i8").astype(np.int64)
    y, refused = b8.final_norm(xi, fnm["g0"], fnm["cn_calibrated"], fnm["tn"], fnm["ceps"], fnm["window_bits"])
    assert not refused.any(), "the lane's final norm refuses this row"
    Lr = b8.int_logits(y, Wr)
    C = Lr * mult[None, :]
    int_tok = int(C.argmax(-1)[0])
    c1, c2 = b8.top2(C)
    # R0's reference on the same row
    fn = ref.final_norm([int(v) for v in X[T - 1]], fnm["g0"], fnm["cn_calibrated"], fnm["tn"], fnm["ceps"])
    assert list(fn["y"]) == [int(v) for v in y[0]], "R0's final norm differs from the lane's"
    r0_tok = ref.first_argmax([int(v) for v in C[0]])
    # the lane's float head
    ck = b8.tc.open_checkpoint()
    nw = b8.tc.tensor_f32(ck.refs["model.norm.weight"]).astype(np.float32)
    lm_raw = b8.raw_u16(ck, "lm_head.weight")
    Lf = b8.float_head(xi, ex["s_out"], ex["R"], nw, lm_raw)
    float_tok = int(Lf.argmax(-1)[0])
    f1, f2 = b8.top2(Lf)
    dec = c["decommitted_next_token"]
    out = {"seq": c["seq"], "decommitted_next_token": dec, "lane_integer_head_token": int_tok, "r0_integer_token": r0_tok,
           "lane_float_head_token": float_tok, "float_top2_margin_logits": float(f1[0] - f2[0]),
           "integer_top2_margin_C": int(c1[0] - c2[0]), "max_abs_y": int(np.abs(y).max()),
           "agree_integer": dec == int_tok == r0_tok, "agree_float": dec == float_tok,
           "final_norm": {"g0": fnm["g0"], "cn": fnm["cn_calibrated"], "tn": fnm["tn"], "ceps": fnm["ceps"]}}
    print(json.dumps(out, indent=1))
    json.dump(out, open(run_dir.parent / "crosscheck_trained_result.json", "w"), indent=1)
    return 0 if out["agree_integer"] else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))

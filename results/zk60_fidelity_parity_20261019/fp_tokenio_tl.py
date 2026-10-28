#!/usr/bin/env python3
"""Write token_io/ for a TinyLlama export under TOKEN_IO_SPEC and the D25 T4 head rule (as
b8_token_io.py did at 8B): int16 embedding table (the export's own, hard link), per-row int8
head W'' of W' = lm_head diag(norm_w) R^T with s_j = max|W'_j| / 127, 12-bit multipliers
m_j = max(1, floor(2^12 s_j / max s + 0.5)), final norm g0 127 with Cn by tlcalib.norm_site(c = 1)
on the per-channel max |xhat'| of the float model's rotated final residual over the calibration
lane's b4 calibration set (54 licence/docstring + 54 FineWeb row group 0 sequences at T), margin
0.5, tn and Ceps of the export. Checks: table[tokens] == x_in_L00 of every exported sequence.

  python3 fp_tokenio_tl.py EXPORT_DIR      (adds EXPORT_DIR/token_io/; nothing else is touched)
"""
import hashlib
import json
import os
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import fp_lib as fl  # noqa: E402
from fp_lib import tc, GEO  # noqa: E402
import fp_eval  # noqa: E402

assert fl.MODEL == "tinyllama"


def main():
    root = Path(sys.argv[1])
    td = root / "token_io"
    if td.exists():
        raise SystemExit(f"{td} exists")
    ex = fl.Export(root)
    pc = ex.prof["profile_constants"]
    tn, ceps = int(pc["norm_tn"]), int(pc["norm_ceps"])
    s_in, s_out = ex.s_in[0], ex.s_out[-1]
    runs = fl.HERE / "runs" / fl.MODEL
    info = fp_eval.build_final_norm_tinyllama(ex, tn, ceps, s_out, runs)      # cached calibration xhat maxima
    seed = int(ex.prof["metadata_out_of_proof"]["rotation"]["seed"])
    head = fl.IntHead(ex.R, s_out, tn, ceps, int(info["cn"]), cache=runs / f"inthead_words_seed{seed}.npz")
    chp = sorted(runs.glob(f"final_xhat_rot_absmax_T{ex.T}_seed{seed}_*.npy"))
    assert len(chp) == 1, chp
    ch = np.load(chp[0]).astype("<f8")
    td.mkdir()
    os.link(root / "embedding_int16.bin", td / "embedding_int16.bin")
    (td / "head_int8_perrow.bin").write_bytes(np.ascontiguousarray(head.Wr).astype(np.int8).tobytes())
    (td / "head_mult12.bin").write_bytes(head.mult.astype("<i8").tobytes())
    (td / "calib_final_xhat_rot_absmax.bin").write_bytes(ch.tobytes())
    V = head.Wr.shape[0]
    vbits = (V - 1).bit_length()
    sha = fl.sha_file
    tab = np.memmap(td / "embedding_int16.bin", dtype="<i2", mode="r").reshape(-1, GEO.d)
    checked = []
    for sname in ex.prof["sequences"]:
        sm = json.loads((root / sname / "manifest.json").read_text())
        xin = np.frombuffer((root / sname / "x_in_L00.bin").read_bytes(), dtype="<i2").reshape(ex.T, GEO.d)
        assert np.array_equal(np.asarray(tab[np.array(sm["token_ids"])]), xin), f"{sname}: table[tokens] != x_in_L00"
        checked.append(sname)
    hm = {"V": V, "bos": 1, "d": GEO.d, "kind": "token-io head (per-row int8 + 12-bit multipliers, D25 T4 rule) for TinyLlama",
          "final_norm": {"g0": 127, "tn": tn, "ceps": ceps, "cn_calibrated": int(info["cn"]), "cn_refusal_free": 1 << tn,
                         "window_bits": int(tc.norm_window(GEO.d, tn))},
          "final_norm_rule": "tlcalib.norm_site(c = 1) on calib_final_xhat_rot_absmax.bin at margin 0.5, tn / Ceps = the export's",
          "calibration_final_xhat": {k: info[k] for k in ("calib_sequences", "xhat_rot_absmax") if k in info},
          "head_int8_perrow.bin": {"dtype": "int8", "shape": [V, GEO.d], "sha256": sha(td / "head_int8_perrow.bin")},
          "head_mult12.bin": {"dtype": "int64 little-endian", "shape": [V], "sha256": sha(td / "head_mult12.bin"),
                              "min": int(head.mult.min()), "max": int(head.mult.max()), "distinct": int(len(np.unique(head.mult))),
                              "rule": "m_j = max(1, floor(2^12 s_j / max s + 0.5))"},
          "keyed_window_bits": int(((1 << vbits) * 2 * GEO.d * 127 * 127 * 4096 + V - 1).bit_length()),
          "keyed_window_rule": f"bits(2^{vbits} * 2 d 127^2 * 2^12 + V - 1) (V_pad 2^{vbits})",
          "clipped": 0, "minus128": int((head.Wr == -128).sum()),
          "scales_f64_sha256": hashlib.sha256(head.s_r.astype("<f8").tobytes()).hexdigest(),
          "source": "results/zk60_fidelity_parity_20261019/fp_tokenio_tl.py (fp_lib.IntHead = the b8_token_io build_heads rule)"}
    assert hm["minus128"] == 0
    (td / "head_manifest.json").write_text(json.dumps(hm, indent=1, sort_keys=True))
    rt = json.loads((root / "token_io.json").read_text())
    ck = fl.checkpoint()
    tio = {"schema": "zk60-trained-profile-export/1", "kind": "token_io", "mode": "build (fidelity lane fp_tokenio_tl.py)",
           "T": ex.T, "bos": 1, "rms_norm_eps": GEO.eps, "s_x_in_layer0": s_in, "s_x_out_layer21": s_out,
           "embedding_table": {"file": "embedding_int16.bin", "dtype": "int16", "shape": [int(tab.shape[0]), GEO.d],
                               "sha256": sha(td / "embedding_int16.bin"),
                               "rule": "floor(float64(float32(R.fwd(float64(float32(E[t]))))) / s_in + 0.5), refuse outside int16"},
           "checked_against": {"exported_sequences": checked, "check": "table[token_ids] == x_in_L00"},
           "rotation": {"file": "../rotation_sign.bin (see ../rotation.json)", "seed": seed,
                        "sign_sha256": ex.prof["metadata_out_of_proof"]["rotation"]["sign_sha256"]},
           "source_tensors_sha256": rt.get("source_tensors_sha256"),
           "spec": "results/zk60_1b_calibration_20260929/export/TOKEN_IO_SPEC.md (TinyLlama: d 2048, V 32000, BOS 1, 22 layers)",
           "final_norm_note": "Cn by the b8 rule: per-channel max |xhat'| of the FLOAT model's rotated final residual over the calibration "
                              "set (export-independent at a fixed rotation), tn / Ceps = this export's profile; the dg integer stack gave 0 "
                              "final-norm range violations on 96 held-out sequences (fp_eval var_dg)",
           "scope": "public model data + calibration data; not a proof"}
    (td / "token_io.json").write_text(json.dumps(tio, indent=1, sort_keys=True))
    # byte identity with the token lane's R2 inputs (same checkpoint, rotation seed and embedding)
    r2 = Path("/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r2_inputs")
    if r2.is_dir():
        r2m = json.loads((r2 / "head_manifest.json").read_text())
        same = {f: sha(td / f) == sha(r2 / f) for f in ("head_int8_perrow.bin", "head_mult12.bin")}
        same["final_norm"] = r2m["final_norm"] == {k: hm["final_norm"][k] for k in r2m["final_norm"]}
        fl.log(f"byte identity with R2 r2_inputs: {same}")
        tio["r2_inputs_identity"] = {"dir": str(r2), **same}
        (td / "token_io.json").write_text(json.dumps(tio, indent=1, sort_keys=True))
    lines = [f"{sha(f)}  {f.name}" for f in sorted(td.iterdir())]
    (td / "SHA256SUMS").write_text("\n".join(lines) + "\n")
    fl.log(f"token_io written: {td} (cn {info['cn']}, ceps {ceps}, tn {tn}); checked {checked}")


if __name__ == "__main__":
    main()

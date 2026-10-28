#!/usr/bin/env python3
"""Next token at the last position of one exported sequence: integer (export stack + D25 T4
integer head) vs float (original float32 model, HF semantics). For the token lane's demo.

  ZK60_MODEL=llama3-8b python3 fp_nexttoken.py EXPORT_DIR SEQ_NAME OUT_JSON
Integer: x_out of the last layer as exported (chained through tlcalib.i_block when the export
was written), integer final norm (g0 127) + per-row int8 head with 12-bit multipliers; the
integer logits C_j = m_j (y . W''_j); ties go to the lowest token id (D25 T3, numpy first max).
Float: tlcalib.f_block over every layer on the same ids, float32 final RMSNorm + LM head.
"""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import fp_lib as fl  # noqa: E402
from fp_lib import tc, GEO  # noqa: E402
import fp_data  # noqa: E402


def main():
    root, sname, outp = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3])
    ex = fl.Export(root)
    T, L = ex.T, ex.L
    sm = json.loads((root / sname / "manifest.json").read_text())
    ids = np.array(sm["token_ids"], dtype=np.int64)
    assert len(ids) == T
    # ---- integer
    x_out = np.frombuffer((root / sname / f"x_out_L{L - 1:02d}.bin").read_bytes(), dtype="<i2").reshape(T, GEO.d)
    assert fl.sha_file(root / sname / f"x_out_L{L - 1:02d}.bin") == sm["arrays"][f"x_out_L{L - 1:02d}"]["sha256"]
    hm = json.loads((root / "token_io" / "head_manifest.json").read_text())
    fn = hm["final_norm"]
    wr = np.memmap(root / "token_io" / "head_int8_perrow.bin", dtype=np.int8, mode="r").reshape(-1, GEO.d)
    mult = np.frombuffer((root / "token_io" / "head_mult12.bin").read_bytes(), dtype="<i8")
    rec = tc.Rec(1)
    y, _ = tc.i_norm(x_out[-1:][None].astype(np.int64), np.full(GEO.d, int(fn["g0"]), dtype=np.int8), int(fn["cn_calibrated"]),
                     int(fn["tn"]), int(fn["ceps"]), int(fn["window_bits"]), rec, "final_norm", 0, False)
    y = y[0, 0].astype(np.int64)
    C = np.empty(wr.shape[0], dtype=np.int64)
    for v0 in range(0, wr.shape[0], 8192):
        C[v0:v0 + 8192] = (np.asarray(wr[v0:v0 + 8192]).astype(np.int64) @ y) * mult[v0:v0 + 8192]
    a_i = int(np.argmax(C))
    c2 = C.copy(); c2[a_i] = np.iinfo(np.int64).min
    b_i = int(np.argmax(c2))
    K = fl.b3.norm_K(int(fn["cn_calibrated"]), int(fn["tn"]))
    # real-logit scale needs max s_j of the rule (recomputed from the checkpoint head, cached by fp_eval)
    seed = int(ex.prof["metadata_out_of_proof"]["rotation"]["seed"])
    cache = fl.HERE / "runs" / fl.MODEL / ("inthead_llama3_8b_pg_rot1_b7_T128.npz" if fl.IS8B else f"inthead_words_seed{seed}.npz")
    head = fl.IntHead(ex.R, ex.s_out[-1], int(fn["tn"]), int(fn["ceps"]), int(fn["cn_calibrated"]), cache=cache)
    assert np.array_equal(head.Wr, np.asarray(wr)), "head words differ from the rule"
    assert np.array_equal(head.mult.astype(np.int64), mult)
    scale = head.scale
    # ---- float
    ck = fl.checkpoint()
    x = fl.emb_rows(ids[None])
    rope = tc.rope_f32(T)
    for l in range(ck.config["layers"]):
        W = tc.layer_f32(ck, l)
        x = tc.f_block(x, W, *rope)
        del W
    fh = fl.FloatHead()
    lf = np.concatenate([b for _, b in fh.logit_blocks(x[0, -1:].astype(np.float32))], axis=1)[0]
    a_f = int(np.argmax(lf))
    l2 = lf.copy(); l2[a_f] = -np.inf
    b_f = int(np.argmax(l2))
    tok = fp_data.Tok(fl.MODEL)
    dec = (lambda t: tok.tk.id_to_token(t)) if fl.IS8B else (lambda t: tok.tk.decode([t]))  # noqa: E731
    out = {"export": str(root), "export_profile_sha256": fl.sha_file(root / "profile.json"), "sequence": sname,
           "token_ids_sha256": hashlib.sha256(ids.astype("<i8").tobytes()).hexdigest(),
           "token_ids_sha256_rule": "sha256 of the 32 ids as little-endian int64",
           "token_ids_csv_sha256": hashlib.sha256(",".join(map(str, ids.tolist())).encode()).hexdigest(),
           "position": T - 1,
           "integer": {"token": a_i, "text": dec(a_i), "top2": [{"token": a_i, "C": int(C[a_i])}, {"token": b_i, "text": dec(b_i), "C": int(C[b_i])}],
                       "margin_C": int(C[a_i] - C[b_i]), "margin_logits_approx": float((C[a_i] - C[b_i]) * scale),
                       "final_norm_violations": sum(s["violations"] for s in rec.summary()["sites"].values()),
                       "rule": "C_j = m_j (y . W''_j), y = final norm int8 of the last layer's x_out at the last position; argmax, ties to the lowest id"},
           "float": {"token": a_f, "text": dec(a_f), "top2": [{"token": a_f, "logit": float(lf[a_f])}, {"token": b_f, "text": dec(b_f), "logit": float(lf[b_f])}],
                     "margin_logits": float(lf[a_f] - lf[b_f]), "rule": "original float32 model (tlcalib.f_block, unrotated) + float32 final norm + LM head"},
           "agree": a_i == a_f,
           "scope": "fidelity data for the demo, not a proof"}
    outp.write_text(json.dumps(out, indent=1, ensure_ascii=False))
    fl.log(f"integer {a_i} {dec(a_i)!r} (margin C {out['integer']['margin_C']}, ~{out['integer']['margin_logits_approx']:.3f} logits) | "
           f"float {a_f} {dec(a_f)!r} (margin {out['float']['margin_logits']:.3f}) -> {outp}")


if __name__ == "__main__":
    main()

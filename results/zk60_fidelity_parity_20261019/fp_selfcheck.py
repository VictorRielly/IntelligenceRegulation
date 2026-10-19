#!/usr/bin/env python3
"""Self-check of fp_lib against the export and tlcalib.i_block:
1. rx_block with EVERY site exact == tlcalib.i_block == the export's x_out
   (bit for bit) for every layer of every exported sequence;
2. rx_block with EVERY site relaxed vs the float block on the same input
   (rotated float weights): cosine of the block update (expected ~1);
3. the real weights round back to the int8 words (asserted inside real_weights).
Usage: [ZK60_MODEL=llama3-8b] python3 fp_selfcheck.py EXPORT_DIR [--layers N]
"""
import argparse
import json
import time
from pathlib import Path

import numpy as np

import fp_lib as fl
from fp_lib import tc, b3, GEO


def layerint(Lw):
    w, c = Lw["w"], Lw["c"]
    T = None
    P = tc.LayerInt(wq=w["wq"], wk=w["wk"], wv=w["wv"], wo=w["wo"], gamma_a=w["gamma_a"], gamma_m=w["gamma_m"],
                    wg_t=w["wg_t"], wu_t=w["wu_t"], wd_t=w["wd_t"], exp=w["exp"].astype(np.int64), act=w["act"],
                    cn_a=int(c["norm_cn_a"]), cn_m=int(c["norm_cn_m"]), tn=int(c["norm_tn"]), ceps=int(c["norm_ceps"]),
                    norm_wrho=c["wrho"], sh_qkv=c["sh_qkv"], sh_rope=c["sh_rope"], sh_s=c["sh_s"], sh_o=c["sh_o"],
                    sh_ao=c["sh_ao"], sh_g=c["sh_g"], sh_u=c["sh_u"], sh_h=c["sh_h"], sh_z=c["sh_z"], f_e=c["f_e"],
                    f_p=c["f_p"], f_ro=c["f_ro"], sh_r2=int(c.get("sh_r2", 0)))
    return P


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("export")
    ap.add_argument("--layers", type=int, default=None)
    ap.add_argument("--relaxed-layers", type=int, default=2)
    a = ap.parse_args()
    ex = fl.Export(Path(a.export))
    T = ex.T
    seqs = ex.prof["sequences"]
    xs = {}
    for s in seqs:
        sd = ex.root / s
        man = json.loads((sd / "manifest.json").read_text())
        xs[s] = man
    L = a.layers or ex.L
    ck = fl.checkpoint()
    rope_i = (None, None)
    out = {"export": str(ex.root), "layers": [], "relaxed": []}
    t0 = time.time()
    for l in range(L):
        Lw = ex.layer(l)
        P = layerint(Lw)
        rope_i = (Lw["w"]["rope_cos"].reshape(T, -1).astype(np.int64), Lw["w"]["rope_sin"].reshape(T, -1).astype(np.int64))
        M = fl.LayerModel(Lw, T)
        X = np.stack([np.frombuffer((ex.root / s / f"x_in_L{l:02d}.bin").read_bytes(), dtype="<i2").reshape(T, GEO.d) for s in seqs])
        Y = np.stack([np.frombuffer((ex.root / s / f"x_out_L{l:02d}.bin").read_bytes(), dtype="<i2").reshape(T, GEO.d) for s in seqs])
        r1, r2 = tc.Rec(len(seqs)), tc.Rec(len(seqs))
        yi = tc.i_block(X.astype(np.int64), P, rope_i, r1)
        yr = fl.rx_block(X.astype(np.float64), M, frozenset(fl.SITES), r2)
        ok_i = bool(np.array_equal(yi, Y))
        ok_r = bool(np.array_equal(yr.astype(np.int64), Y)) and bool(np.all(yr == np.floor(yr)))
        rec = {"layer": l, "i_block_eq_export": ok_i, "rx_exact_eq_export": ok_r,
               "violations_rx": sum(s["violations"] for s in r2.summary()["sites"].values())}
        if l < a.relaxed_layers:
            W = tc.layer_f32(ck, l)
            Wrot = b3.rotate_layer(W, ex.R)
            Wreal, wrep = fl.real_weights(Wrot, Lw)
            Mr = fl.LayerModel(Lw, T, Wreal)
            s_in, s_out = ex.s_in[l], ex.s_out[l]
            xf = (X.astype(np.float64) * s_in).astype(np.float32)
            yf = tc.f_block(xf, Wrot, *tc.rope_f32(T))
            yrel = fl.rx_block(X.astype(np.float64), Mr, frozenset(), None) * s_out
            upd_f, upd_r = (yf - xf).reshape(-1, GEO.d), (yrel - xf).reshape(-1, GEO.d)
            cos = (upd_f * upd_r).sum(1) / np.linalg.norm(upd_f, axis=1) / np.linalg.norm(upd_r, axis=1)
            rel = float(np.linalg.norm(upd_r - upd_f) / np.linalg.norm(upd_f))
            yex = yr * s_out
            upd_e = (yex - xf).reshape(-1, GEO.d)
            cos_e = (upd_f * upd_e).sum(1) / np.linalg.norm(upd_f, axis=1) / np.linalg.norm(upd_e, axis=1)
            rec["all_relaxed_vs_float_update"] = {"cos_mean": float(cos.mean()), "cos_min": float(cos.min()), "rel_l2": rel}
            rec["all_exact_vs_float_update_cos_mean"] = float(cos_e.mean())
            rec["real_weight_fit"] = wrep
        out["layers"].append(rec)
        fl.log(f"L{l:02d} {rec} ({time.time() - t0:.0f}s)")
    out["all_bit_exact"] = all(r["i_block_eq_export"] and r["rx_exact_eq_export"] for r in out["layers"])
    fl.log(f"ALL BIT-EXACT: {out['all_bit_exact']}")
    name = "selfcheck_" + ex.root.name + ".json"
    (fl.HERE / "runs" / name).write_text(json.dumps(out, indent=1))


if __name__ == "__main__":
    main()

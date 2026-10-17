#!/usr/bin/env python3
"""Lane B3 diagnostic: one layer, one residual scale, several variants; the
isolated per-site error budget (b3calib.site_errors) on held-out sequences.
Usage: b3_layerdiag.py --layer 3 --s-x 0.0089 --variants b,d"""

from __future__ import annotations

import argparse
import pickle
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np  # noqa: E402

import tlcalib as tc  # noqa: E402
import b3calib as b3  # noqa: E402
from corpus import sequences  # noqa: E402
from spm_bpe import SpmBpe  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--layer", type=int, required=True)
    ap.add_argument("--s-x", type=float, required=True)
    ap.add_argument("--variants", default="b,d")
    ap.add_argument("--n", type=int, default=8)
    ap.add_argument("--stats", default="runs/b3_stats4_T32_c6_rNone.pkl")
    args = ap.parse_args()
    stats = pickle.load(open(tc.HERE / args.stats, "rb"))
    ck = tc.open_checkpoint()
    tok = SpmBpe(tc.MODEL_DIR / "tokenizer.model")
    ho, _ = sequences(tok, "heldout", 32, 4)
    ids = np.array(ho[:args.n])
    emb = tc.tensor_f32(ck.refs["model.embed_tokens.weight"])
    x = emb[ids]
    del emb
    rope_f = tc.rope_f32(32)
    rope_i = b3.rope_generate(32)
    for l in range(args.layer):
        x = tc.f_block(x, tc.layer_f32(ck, l), *rope_f)
    W = tc.layer_f32(ck, args.layer)
    xq = tc.quantize_input(x, args.s_x)
    for vn in args.variants.split(","):
        var = b3.variant_by_name(vn)
        glob = b3.Globals(s_in=[args.s_x], s_out=[args.s_x])
        P, rep = b3.solve_layer(W, stats[args.layer], var, args.s_x, args.s_x, glob, {})
        se = b3.site_errors(xq, P, rope_i, W, rope_f)
        print(f"== variant {vn} layer {args.layer} s_x {args.s_x}: shifts {rep['shifts']} e_s {P.e_s} silu {P.silu} "
              f"cn {P.cn_a}/{P.cn_m}")
        print("   site rel err: " + " ".join(f"{k} {v:.3f}" for k, v in se.items()))
        print("   norm_a", {k: rep["norm_a"][k] for k in ("shape", "r_step", "noise", "g_max", "y_fill_calib")},
              "norm_m", {k: rep["norm_m"][k] for k in ("shape", "r_step", "noise", "g_max", "y_fill_calib")})
        print("   score", rep["score"], "\n   ffn", rep["ffn"], "\n   v_o", rep["v_o"], "\n   u_h_d", rep["u_h_d"])
        print("   clip", {k: v for k, v in rep["weights_clipped"].items() if v}, "absmax", rep["weights_absmax_int"])
        print("   scales", rep["metadata_scales"])


if __name__ == "__main__":
    main()

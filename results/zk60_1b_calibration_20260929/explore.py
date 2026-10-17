#!/usr/bin/env python3
"""Exploration: magnitudes of the trained checkpoint that decide the integer
design (norm gains, embedding scale, residual growth / outlier channels,
per-site float maxima). Float32 only; a few calibration sequences."""

from __future__ import annotations

import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np  # noqa: E402

import tlcalib as tc  # noqa: E402
from corpus import sequences  # noqa: E402
from spm_bpe import SpmBpe  # noqa: E402

try:
    from threadpoolctl import threadpool_limits
except ImportError:  # pragma: no cover
    threadpool_limits = None


def main():
    T = int(sys.argv[1]) if len(sys.argv) > 1 else 128
    per = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    t0 = time.time()
    ck = tc.open_checkpoint()
    print(f"checkpoint pinned in {time.time()-t0:.1f}s, {ck.identity['tensor_count']} tensors", flush=True)
    tok = SpmBpe(tc.MODEL_DIR / "tokenizer.model")
    seqs, meta = sequences(tok, "calib", T, per)
    ids = np.array(seqs, dtype=np.int64)
    print(f"{len(seqs)} sequences of {T}", flush=True)
    emb = tc.tensor_f32(ck.refs["model.embed_tokens.weight"])
    print(f"embed: absmax {np.abs(emb).max():.4g} rms {np.sqrt((emb**2).mean()):.4g} p99.9 {np.quantile(np.abs(emb[:2000]), 0.999):.4g}")
    x = emb[ids]
    del emb
    cos, sin = tc.rope_f32(T)
    out = {}
    for layer in range(ck.config["layers"]):
        W = tc.layer_f32(ck, layer)
        ga, gm = W["input_layernorm.weight"], W["post_attention_layernorm.weight"]
        st = {}
        xin = x
        x = tc.f_block(x, W, cos, sin, st)
        ab = np.abs(xin).reshape(-1, xin.shape[-1])
        chmax = ab.max(0)
        top = np.argsort(chmax)[::-1][:4]
        rms_tok = np.sqrt((xin.astype(np.float64) ** 2).mean(-1))
        print(f"L{layer:02d} x_in absmax {ab.max():8.3f} med|x| {np.median(ab):.4f} p99.9 {np.quantile(ab, 0.999):7.3f} "
              f"rms/token [{rms_tok.min():.3f},{rms_tok.max():.3f}] top ch {list(map(int, top))} {[round(float(chmax[i]),1) for i in top]} | "
              f"gam_a [{ga.min():.3g},{ga.max():.3g}] gam_m [{gm.min():.3g},{gm.max():.3g}] | "
              f"xhat_a max {st['xhat_a_ch'].max():.1f} xhat_m max {st['xhat_m_ch'].max():.1f} q {st['q_pair']:.2f} k {st['k_pair']:.2f} v {st['v']:.2f} "
              f"raw_all {st['raw_all']:.1f} raw_causal {st['raw_causal']:.1f} o {st['o']:.2f} ao {st['ao']:.1f} gate {st['gate']:.2f} up {st['up']:.2f} "
              f"h {st['h']:.2f} z {st['z']:.1f} x2 {st['x2']:.1f} ({time.time()-t0:.0f}s)", flush=True)
        # sensitivity inputs for the norm design: xhat*gamma max vs xhat max
        xa = tc.f_xhat(xin, 1e-5).reshape(-1, xin.shape[-1])
        out[layer] = {"xhat_gamma_max": float(np.abs(xa * ga).max()), "xhat_max": float(np.abs(xa).max()),
                      "gamma_a_small": int((np.abs(ga) < np.abs(ga).max() / 64).sum())}
        print(f"     xhat*gamma_a max {out[layer]['xhat_gamma_max']:.2f} xhat max {out[layer]['xhat_max']:.2f} "
              f"gamma_a entries below max/64: {out[layer]['gamma_a_small']}", flush=True)
    print(f"final x absmax {np.abs(x).max():.2f}")


if __name__ == "__main__":
    if threadpool_limits is not None:
        with threadpool_limits(limits=2):
            main()
    else:
        main()

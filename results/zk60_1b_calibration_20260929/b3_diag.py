#!/usr/bin/env python3
"""Lane B3 diagnostic (float only, CPU-light): WHERE the extremes that bind
the native constants live. For calibration and held-out sequences: tokens
carrying massive residual activations, gate values beyond the SiLU registry
ranges (+-16/32/64), and the per-layer counts of positions involved.
Read-only on the checkpoint; prints and writes runs/b3_diag_T<T>.json."""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np  # noqa: E402

import tlcalib as tc  # noqa: E402
from corpus import sequences  # noqa: E402
from spm_bpe import SpmBpe  # noqa: E402


def block_with_gate(x, W, cos, sin, g=tc.GEO):
    """tlcalib.f_block, also returning gate and up (float32)."""
    N, T, d = x.shape
    xa = tc.f_xhat(x, g.eps)
    h = xa * W["input_layernorm.weight"]
    q = (h @ W["self_attn.q_proj.weight"].T).reshape(N, T, g.H, g.dh)
    k = (h @ W["self_attn.k_proj.weight"].T).reshape(N, T, g.KV, g.dh)
    v = (h @ W["self_attn.v_proj.weight"].T).reshape(N, T, g.KV, g.dh)
    qr, kr = tc.f_rope(q, cos, sin), tc.f_rope(k, cos, sin)
    qg = qr.reshape(N, T, g.KV, g.G, g.dh).transpose(0, 2, 3, 1, 4)
    kg = kr.transpose(0, 2, 3, 1)[:, :, None]
    raw = qg @ kg
    tri = np.tril(np.ones((T, T), dtype=bool))
    lg = np.where(tri, raw / np.float32(8.0), -np.inf).astype(np.float32)
    lg -= lg.max(-1, keepdims=True)
    p = np.exp(lg)
    p /= p.sum(-1, keepdims=True)
    o = (p @ v.transpose(0, 2, 1, 3)[:, :, None]).transpose(0, 3, 1, 2, 4).reshape(N, T, d)
    x1 = x + o @ W["self_attn.o_proj.weight"].T
    hm = tc.f_xhat(x1, g.eps) * W["post_attention_layernorm.weight"]
    gt = hm @ W["mlp.gate_proj.weight"].T
    up = hm @ W["mlp.up_proj.weight"].T
    with np.errstate(over="ignore"):
        act = gt / (1.0 + np.exp(-gt))
    x2 = x1 + (act * up) @ W["mlp.down_proj.weight"].T
    return x2, gt, up, act * up


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--T", type=int, default=32)
    ap.add_argument("--per", type=int, default=3)
    args = ap.parse_args()
    ck = tc.open_checkpoint()
    tok = SpmBpe(tc.MODEL_DIR / "tokenizer.model")
    pieces = {}
    out = {}
    for which in ("calib", "heldout"):
        seqs, meta = sequences(tok, which, args.T, args.per)
        ids = np.array(seqs, dtype=np.int64)
        emb = tc.tensor_f32(ck.refs["model.embed_tokens.weight"])
        x = emb[ids]
        del emb
        cos, sin = tc.rope_f32(args.T)
        rows = []
        for l in range(ck.config["layers"]):
            W = tc.layer_f32(ck, l)
            x, gt, up, hh = block_with_gate(x, W, cos, sin)
            res = np.abs(x).max(-1)                                      # (N, T)
            massive = np.argwhere(res > 50)
            gneg = (-gt).max(-1)
            gpos = gt.max(-1)
            ent = {"layer": l, "massive_positions_out": int(len(massive)),
                   "massive_by_pos": sorted({int(t) for _, t in massive}),
                   "massive_tokens": sorted({int(ids[n, t]) for n, t in massive}),
                   "seqs_with_massive_nonbos": int(len({int(n) for n, t in massive if t > 0})),
                   "gate_abs_gt16_pos": int(((np.maximum(gpos, gneg)) > 16).sum()),
                   "gate_abs_gt32_pos": int(((np.maximum(gpos, gneg)) > 32).sum()),
                   "gate_abs_gt64_pos": int(((np.maximum(gpos, gneg)) > 64).sum()),
                   "seqs_gate_gt64": int((np.maximum(gpos, gneg).max(-1) > 64).sum()),
                   "seqs_gate_gt32": int((np.maximum(gpos, gneg).max(-1) > 32).sum()),
                   "seqs_gate_gt16": int((np.maximum(gpos, gneg).max(-1) > 16).sum()),
                   "gate_extreme_pos": [int(t) for t in np.argwhere(np.maximum(gpos, gneg) > 32)[:, 1]],
                   "gate_extreme_tokens": sorted({int(ids[n, t]) for n, t in np.argwhere(np.maximum(gpos, gneg) > 32)}),
                   "up_max": float(np.abs(up).max()), "h_max": float(np.abs(hh).max()),
                   "h_max_pos": [int(v) for v in np.unravel_index(np.abs(hh).argmax(), hh.shape)[:2]],
                   "pos0_gate_absmax": float(np.maximum(gpos, gneg)[:, 0].max()),
                   "nonpos0_gate_absmax": float(np.maximum(gpos, gneg)[:, 1:].max())}
            rows.append(ent)
            print(f"{which} L{l:02d} massive(>50) out {ent['massive_positions_out']} pos {ent['massive_by_pos'][:6]} tok {ent['massive_tokens'][:6]} "
                  f"| gate>16/32/64 seqs {ent['seqs_gate_gt16']}/{ent['seqs_gate_gt32']}/{ent['seqs_gate_gt64']} p0 {ent['pos0_gate_absmax']:.1f} "
                  f"rest {ent['nonpos0_gate_absmax']:.1f} toks {ent['gate_extreme_tokens'][:6]} | up {ent['up_max']:.1f} h {ent['h_max']:.1f} at {ent['h_max_pos']}", flush=True)
            for tkn in ent["massive_tokens"] + ent["gate_extreme_tokens"]:
                pieces[tkn] = tok.pieces[tkn] if hasattr(tok, "pieces") else str(tkn)
        out[which] = {"meta": meta, "layers": rows}
    out["pieces"] = {str(k): v for k, v in pieces.items()}
    print("pieces:", out["pieces"])
    (tc.HERE / "runs" / f"b3_diag_T{args.T}.json").write_text(json.dumps(out, indent=1))


if __name__ == "__main__":
    t0 = time.time()
    main()
    print(f"done {time.time() - t0:.0f}s")

#!/usr/bin/env python3
"""m8b_gemma4_diag.py — U-PERF3 lane Y: forward-pass diagnostics for the
gemma4 walker (the probe FAILED 0/5 at ranks in the thousands — this
localizes where the stream goes wrong). Per-layer hidden-state stats +
a tied-head logit lens at chosen depths, plus cheap semantic ablations
(--attn-scale, --norm-form, --no-embed-scale, --vk POST) to test the
walker's pinned facts one at a time.
"""

import argparse
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import m8b_int8_calibration as m8b                      # noqa: E402
from m8b_gemma4_walker import (                          # noqa: E402
    Gemma4Walker, arch_gemma4, EMBED_SCALE, rmsnorm_noscale, gelu_tanh,
    encode_prompt, DEFAULT_CKPT, p)


class DiagWalker(Gemma4Walker):
    """walk_trace: the exact walk loop with per-layer stats and
    optional ablations."""

    def __init__(self, store, arch, t_max, attn_scale=1.0,
                 norm_form="w", embed_scale=EMBED_SCALE, vk="RAW"):
        super().__init__(store, arch, t_max)
        self.attn_scale = attn_scale
        self.norm_form = norm_form
        self.embed_scale = embed_scale
        self.vk = vk

    def _rms(self, x, w):
        if self.norm_form == "1+w":
            return m8b.rmsnorm(x, 1.0 + w, self.arch.eps)
        return m8b.rmsnorm(x, w, self.arch.eps)

    def _attention(self, xn, lw, layer_type):
        a = self.arch
        B, T, _ = xn.shape
        if layer_type == "full_attention":
            hd, Hk = a.global_head_dim, a.global_kv_heads
            cos, sin = self.cos_g[:T], self.sin_g[:T]
        else:
            hd, Hk = a.head_dim, a.kv_heads
            cos, sin = self.cos_s[:T], self.sin_s[:T]
        H = a.heads
        rep = H // Hk
        flat = xn.reshape(B * T, -1)
        q = (flat @ lw["wq"].T).reshape(B, T, H, hd)
        k = (flat @ lw["wk"].T).reshape(B, T, Hk, hd)
        if "wv" in lw:
            vr = (flat @ lw["wv"].T).reshape(B, T, Hk, hd)
        else:
            vr = k.copy()
        q = self._rms(q, lw["q_norm"])
        k = self._rms(k, lw["k_norm"])
        if self.vk == "POST" and "wv" not in lw:
            v = rmsnorm_noscale(k, a.eps)   # ablation: v from normed k
        else:
            v = rmsnorm_noscale(vr, a.eps)  # facts F4: raw k_proj
        del vr
        mask = np.triu(np.full((T, T), -np.inf, dtype=np.float32), k=1)
        out = np.empty((B, T, H, hd), dtype=np.float32)
        for b in range(B):
            qb = m8b.rope_apply(q[b], cos, sin)
            kb = m8b.rope_apply(k[b], cos, sin)
            for h in range(H):
                s = (qb[:, h] @ kb[:, h // rep].T) * self.attn_scale \
                    + mask
                s -= s.max(axis=-1, keepdims=True)
                e = np.exp(s)
                w = e / e.sum(axis=-1, keepdims=True)
                out[b, :, h] = w @ v[b, :, h // rep]
        return out.reshape(B * T, H * hd) @ lw["wo"].T

    def walk_trace(self, tokens, lens_depths=()):
        a = self.arch
        B, T = tokens.shape
        x = (self.embed.gather(tokens.reshape(-1)).reshape(B, T, a.d)
             * np.float32(self.embed_scale))
        p("emb*scale: rms %.4g absmax %.4g (scale %.4g)"
          % (float(np.sqrt((x ** 2).mean())), float(np.abs(x).max()),
             self.embed_scale))
        lens = {}
        fw = self.store.get(self._n("final_norm"))
        for l in range(a.n_layers):
            lt = a.layer_types[l]
            lw = self.load_layer(l)
            hn = self._rms(x, lw["attn_norm"])
            att = self._attention(hn, lw, lt).reshape(B, T, a.d)
            attn_res = self._rms(att, lw["post_attn_norm"])
            x = x + attn_res
            xin = self._rms(x, lw["pre_ffw_norm"])
            flat = xin.reshape(B * T, a.d)
            gate = flat @ lw["w_gate"].T
            up = flat @ lw["w_up"].T
            h = gelu_tanh(gate) * up
            z = (h @ lw["w_down"].T).reshape(B, T, a.d)
            ffw_res = self._rms(z, lw["post_ffw_norm"])
            x = x + ffw_res
            sc = float(lw["layer_scalar"][0])
            x = x * np.float32(sc)
            p("L%02d %-8s scalar %6.4f | x rms %9.4g absmax %9.4g | "
              "attn_res rms %8.3g | ffw_res rms %8.3g | gate absmax "
              "%8.3g"
              % (l, lt[:8], sc, float(np.sqrt((x ** 2).mean())),
                 float(np.abs(x).max()),
                 float(np.sqrt((attn_res ** 2).mean())),
                 float(np.sqrt((ffw_res ** 2).mean())),
                 float(np.abs(gate).max())))
            if l in lens_depths:
                hidden = self._rms(x, fw)
                lens[l] = self.top5(hidden[0, -1])
                p("    lens@L%02d top-5: %s" % (l, lens[l]))
            del lw, hn, att, attn_res, xin, gate, up, h, z, ffw_res
        hidden = self._rms(x, fw)
        return hidden, lens

    def top5(self, hid_last):
        lg = self.last_logits_stream(hid_last)
        order = np.argsort(-lg)[:5]
        return [(int(i), float(lg[i])) for i in order]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ckpt", default=DEFAULT_CKPT)
    ap.add_argument("--prompt", default="The chemical symbol for gold is")
    ap.add_argument("--max-layers", type=int, default=None)
    ap.add_argument("--attn-scale", default="1.0",
                    help="1.0 (facts F4) or 'rsqrt' for hd**-0.5")
    ap.add_argument("--norm-form", default="w", choices=("w", "1+w"))
    ap.add_argument("--embed-scale", type=float, default=EMBED_SCALE)
    ap.add_argument("--vk", default="RAW", choices=("RAW", "POST"))
    ap.add_argument("--lens", default="0,8,16,24,32,40,46",
                    help="comma depths for the tied-head logit lens")
    args = ap.parse_args()

    arch = arch_gemma4(args.ckpt)
    if args.max_layers:
        arch.n_layers = min(arch.n_layers, args.max_layers)
    store = m8b.TensorStore(args.ckpt)
    scale = (arch.head_dim ** -0.5 if args.attn_scale == "rsqrt"
             else float(args.attn_scale))
    w = DiagWalker(store, arch, 64, attn_scale=scale,
                   norm_form=args.norm_form,
                   embed_scale=args.embed_scale, vk=args.vk)
    tk = m8b.load_tokenizer(args.ckpt)
    ids = encode_prompt(tk, arch, args.prompt)
    p("prompt %r -> %d tokens; ablations: attn_scale=%s norm_form=%s "
      "embed_scale=%.4g vk=%s"
      % (args.prompt, len(ids), args.attn_scale, args.norm_form,
         args.embed_scale, args.vk))
    toks = np.asarray(ids, dtype=np.int64)[None, :]
    depths = set(int(d) for d in args.lens.split(",") if d != "")
    hidden, _ = w.walk_trace(toks, lens_depths=depths)
    final = w.top5(hidden[0, -1])
    words = [(m8b.tok_decode(tk, [i]), round(v, 2)) for i, v in final]
    p("FINAL top-5: %s" % words)
    want = m8b.tok_encode(tk, " Au")
    lg = w.last_logits_stream(hidden[0, -1])
    rank = int((lg > lg[int(want[0])]).sum())
    p("rank of ' Au' (id %d): %d" % (int(want[0]), rank))


if __name__ == "__main__":
    main()

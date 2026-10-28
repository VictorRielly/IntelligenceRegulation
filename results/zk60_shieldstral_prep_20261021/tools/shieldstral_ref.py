"""Float32 numpy reference forward pass of Shieldstral-1.0-3B's TEXT decoder (Ministral-3-3B).

Layer-streamed: one decoder layer's weights (fp32, ~466 MB) are resident at a time; activations
of a whole batch of prompts pass through layer l before layer l+1 is loaded.  Weights are read
with pread (no mmap).  No torch, no transformers: an implementation independent of HF's.

Two weight layouts, selected by --fmt:
  hf           model.safetensors        (HF names; q/k rows permuted for rotate-half RoPE)
  consolidated consolidated.safetensors (Mistral-native names; interleaved-pair RoPE, unpermuted)
Agreement between the two is a check of the RoPE convention and of HF's conversion.

RoPE: YaRN (factor 16, original 16384, beta_fast 32, beta_slow 1, theta 1e6, head_dim 128) with
the reference-implementation index-space ramp (floor/ceil truncation of the correction range),
computed in float64.  Attention factor (mscale ratio) is exactly 1; the Llama-4 query scale
1 + 0.1*log(1 + floor(pos/16384)) is exactly 1 for pos < 16384 (asserted).
Head: tied to the token embedding (logits = RMSNorm(h) @ E^T), computed in row chunks.

Library use:  m = Ref(fmt); out = m.run(list_of_token_id_lists, prefix_ids=None)
"""
import math
import os
import sys
import time

import numpy as np

sys.path.insert(0, "/home/victor/IntelligenceRegulation/results/zk60_shieldstral_prep_20261021/tools")
import shieldstral_common as C  # noqa: E402

D, L, NH, NKV, HD, FF, V = 3072, 26, 32, 8, 128, 9216, 131072
EPS = 1e-5
THETA, YARN_FACTOR, YARN_ORIG, BETA_FAST, BETA_SLOW = 1e6, 16.0, 16384, 32.0, 1.0
LLAMA4_BETA = 0.1

NAMES = {
    "hf": {
        "file": "model.safetensors",
        "embed": "language_model.model.embed_tokens.weight",
        "norm": "language_model.model.norm.weight",
        "layer": "language_model.model.layers.{i}.",
        "attn_norm": "input_layernorm.weight", "ffn_norm": "post_attention_layernorm.weight",
        "wq": "self_attn.q_proj.weight", "wk": "self_attn.k_proj.weight", "wv": "self_attn.v_proj.weight",
        "wo": "self_attn.o_proj.weight",
        "w1": "mlp.gate_proj.weight", "w3": "mlp.up_proj.weight", "w2": "mlp.down_proj.weight",
        "rope": "half",
    },
    "consolidated": {
        "file": "consolidated.safetensors",
        "embed": "tok_embeddings.weight",
        "norm": "norm.weight",
        "layer": "layers.{i}.",
        "attn_norm": "attention_norm.weight", "ffn_norm": "ffn_norm.weight",
        "wq": "attention.wq.weight", "wk": "attention.wk.weight", "wv": "attention.wv.weight",
        "wo": "attention.wo.weight",
        "w1": "feed_forward.w1.weight", "w3": "feed_forward.w3.weight", "w2": "feed_forward.w2.weight",
        "rope": "interleaved",
    },
}


def yarn_inv_freq(variant="yarn"):
    """float64 inverse frequencies [HD/2].  variant: 'yarn' (correct), 'plain' (no scaling, a
    deliberate error), 'yarn_notrunc' (no floor/ceil, a deliberate error), 'yarn_f32' (HF float32)."""
    dim = HD
    if variant == "yarn_f32":
        pos = (np.float32(THETA) ** (np.arange(0, dim, 2, dtype=np.float32) / np.float32(dim))).astype(np.float32)
        ext = (np.float32(1.0) / pos).astype(np.float32)
        inter = (np.float32(1.0) / (np.float32(YARN_FACTOR) * pos)).astype(np.float32)
    else:
        pos = THETA ** (np.arange(0, dim, 2, dtype=np.float64) / dim)
        ext = 1.0 / pos
        inter = 1.0 / (YARN_FACTOR * pos)
    if variant == "plain":
        return ext.astype(np.float64)

    def corr_dim(nrot):
        return dim * math.log(YARN_ORIG / (nrot * 2 * math.pi)) / (2 * math.log(THETA))
    lo, hi = corr_dim(BETA_FAST), corr_dim(BETA_SLOW)
    if variant != "yarn_notrunc":
        lo, hi = math.floor(lo), math.ceil(hi)
    lo, hi = max(lo, 0), min(hi, dim - 1)
    if lo == hi:
        hi += 0.001
    dt = np.float32 if variant == "yarn_f32" else np.float64
    ramp = np.clip((np.arange(dim // 2, dtype=dt) - lo) / (hi - lo), 0, 1).astype(dt)
    extrap_w = (1 - ramp).astype(dt)  # 1 -> keep original frequency (high-frequency dims)
    inv = inter * (1 - extrap_w) + ext * extrap_w
    return inv.astype(np.float64)


def attention_factor():
    def get_mscale(scale, mscale=1.0):
        return 1.0 if scale <= 1 else 0.1 * mscale * math.log(scale) + 1.0
    return get_mscale(YARN_FACTOR, 1.0) / get_mscale(YARN_FACTOR, 1.0)  # mscale = mscale_all_dim = 1


class Ref:
    def __init__(self, fmt="hf", snap=C.SNAP, rope_variant="yarn", threads_note=""):
        self.fmt = fmt
        self.n = NAMES[fmt]
        self.f = C.SafeTensorsFile(os.path.join(snap, self.n["file"]))
        self.inv_freq = yarn_inv_freq("yarn" if rope_variant == "yarn_mscale" else rope_variant)
        self.att_factor = attention_factor()
        assert self.att_factor == 1.0
        if rope_variant == "yarn_mscale":  # deliberate error: YaRN mscale 0.1*ln(16)+1 applied to cos/sin
            self.att_factor = 0.1 * math.log(YARN_FACTOR) + 1.0
        if rope_variant == "hf448":  # what transformers 4.48.1 builds from the shipped config (wrong for this model)
            self.inv_freq = np.load(f"{C.LANE}/crosscheck/inv_freq_transformers448_maxpos262144.npy").astype(np.float64)
            self.att_factor = 0.1 * math.log(YARN_FACTOR) + 1.0
        self.rope_variant = rope_variant
        keys = set(self.f.keys())
        self.has_lm_head = any(k.endswith("lm_head.weight") or k == "output.weight" for k in keys)
        self.tied = not self.has_lm_head

    # ----------------------------------------------------------- weights
    def lw(self, i, key):
        return self.f.get_f32(self.n["layer"].format(i=i) + self.n[key])

    def load_layer(self, i):
        return {k: self.lw(i, k) for k in ("attn_norm", "ffn_norm", "wq", "wk", "wv", "wo", "w1", "w3", "w2")}

    def embed(self, ids):
        out = np.empty((len(ids), D), np.float32)
        for j, t in enumerate(ids):
            out[j] = self.f.get_f32(self.n["embed"], int(t), int(t) + 1)[0]
        return out

    # ----------------------------------------------------------- pieces
    @staticmethod
    def rmsnorm(x, w):
        x64 = x.astype(np.float32)
        var = np.mean(x64 * x64, axis=-1, keepdims=True, dtype=np.float32)
        return (x64 / np.sqrt(var + np.float32(EPS))).astype(np.float32) * w

    def rope(self, x, pos):
        """x [T, H, HD] float32, pos [T] int.  Rotates in place-free fashion."""
        ang = pos.astype(np.float64)[:, None] * self.inv_freq[None, :]  # [T, HD/2]
        cos = (np.cos(ang) * self.att_factor).astype(np.float32)[:, None, :]
        sin = (np.sin(ang) * self.att_factor).astype(np.float32)[:, None, :]
        if self.n["rope"] == "half":
            x1, x2 = x[..., :HD // 2], x[..., HD // 2:]
            return np.concatenate([x1 * cos - x2 * sin, x2 * cos + x1 * sin], axis=-1)
        xe, xo = x[..., 0::2], x[..., 1::2]
        out = np.empty_like(x)
        out[..., 0::2] = xe * cos - xo * sin
        out[..., 1::2] = xe * sin + xo * cos
        return out

    @staticmethod
    def llama4_scale(pos):
        s = 1 + LLAMA4_BETA * np.log(1 + np.floor(pos / YARN_ORIG))
        assert np.all(s == 1.0), "positions >= 16384 would need the Llama-4 query scale"
        return s

    def attend(self, q, k, v):
        """q [T, NH, HD] (queries are the LAST T positions), k/v [S, NKV, HD], S >= T, causal."""
        T, S = q.shape[0], k.shape[0]
        rep = NH // NKV
        out = np.empty((T, NH, HD), np.float32)
        scale = np.float32(1.0 / math.sqrt(HD))
        qb = max(1, min(T, (8 << 20) // max(1, S * rep * 4)))  # score block <= 8 MiB per KV head
        kt = np.ascontiguousarray(k.transpose(1, 2, 0))   # [NKV, HD, S]
        vt = np.ascontiguousarray(v.transpose(1, 0, 2))   # [NKV, S, HD]
        for a in range(0, T, qb):
            b = min(T, a + qb)
            qq = q[a:b].reshape(b - a, NKV, rep, HD).transpose(1, 0, 2, 3).reshape(NKV, (b - a) * rep, HD)
            sc = np.matmul(qq, kt)                             # [NKV, (b-a)*rep, S]
            sc *= scale
            sc = sc.reshape(NKV, b - a, rep, S)
            qpos = (S - T) + np.arange(a, b)
            bias = np.where(np.arange(S)[None, :] > qpos[:, None], np.float32(-np.inf), np.float32(0))
            sc += bias[None, :, None, :].astype(np.float32)
            sc -= sc.max(axis=-1, keepdims=True)
            np.exp(sc, out=sc)
            sc /= sc.sum(axis=-1, keepdims=True)
            o = np.matmul(sc.reshape(NKV, (b - a) * rep, S), vt)  # [NKV, (b-a)*rep, HD]
            out[a:b] = o.reshape(NKV, b - a, rep, HD).transpose(1, 0, 2, 3).reshape(b - a, NH, HD)
        return out

    # ----------------------------------------------------------- forward
    def run(self, seqs, prefix_ids=None, want_layer_last=False, ffn_chunk=2048, log=None,
            topk=20, extra_ids=()):
        """seqs: list of token-id lists (each the FULL prompt).  If prefix_ids is given, every seq must
        start with it; its K/V are computed once and reused (exact under causal attention).

        Returns per sequence: logits at the last position (float32 [V]) summarized, plus optionally
        the last-position residual after every layer."""
        P = len(prefix_ids) if prefix_ids is not None else 0
        tails = []
        for s in seqs:
            if P:
                assert list(s[:P]) == list(prefix_ids), "sequence does not start with the shared prefix"
            tails.append(np.asarray(s[P:], np.int64))
        t0 = time.time()
        pre_kv = None
        if P:
            pre_kv = self._prefix_kv(np.asarray(prefix_ids, np.int64), ffn_chunk)
        lens = [len(t) for t in tails]
        offs = np.concatenate([[0], np.cumsum(lens)]).astype(np.int64)
        allids = np.concatenate(tails)
        pos = np.concatenate([P + np.arange(n) for n in lens]).astype(np.int64)
        self.llama4_scale(pos)
        x = self.embed(allids)
        layer_last = [] if want_layer_last else None
        if want_layer_last:
            layer_last.append(x[offs[1:] - 1].copy())
        for i in range(L):
            x = self._layer(x, i, pos, offs, pre_kv[i] if pre_kv else None, ffn_chunk)
            if want_layer_last:
                layer_last.append(x[offs[1:] - 1].copy())
            if log:
                log(f"layer {i} done {time.time() - t0:.1f}s")
        hl = x[offs[1:] - 1]
        hn = self.rmsnorm(hl, self.f.get_f32(self.n["norm"]))
        logits = self.head(hn)
        return {"logits": logits, "final_hidden": hn, "layer_last": layer_last,
                "tokens_processed": int(allids.size), "prefix_len": P, "seconds": time.time() - t0}

    def _layer(self, x, i, pos, offs, pkv, ffn_chunk):
        """One decoder layer.  Weight matrices are read and widened to fp32 one at a time, at the
        point of use, and dropped right after (peak = one fp32 matrix + activations)."""
        h = self.rmsnorm(x, self.lw(i, "attn_norm"))
        q = (h @ self.lw(i, "wq").T).reshape(-1, NH, HD)
        k = (h @ self.lw(i, "wk").T).reshape(-1, NKV, HD)
        v = (h @ self.lw(i, "wv").T).reshape(-1, NKV, HD)
        del h
        q = self.rope(q, pos)
        k = self.rope(k, pos)
        att = np.empty((x.shape[0], NH, HD), np.float32)
        for j in range(len(offs) - 1):
            a, b = offs[j], offs[j + 1]
            kk, vv = k[a:b], v[a:b]
            if pkv is not None:
                kk = np.concatenate([pkv[0], kk])
                vv = np.concatenate([pkv[1], vv])
            att[a:b] = self.attend(q[a:b], kk, vv)
        del q, k, v
        x = x + att.reshape(-1, NH * HD) @ self.lw(i, "wo").T
        del att
        hh = self.rmsnorm(x, self.lw(i, "ffn_norm"))
        g = np.empty((x.shape[0], FF), np.float32)
        w = self.lw(i, "w1")
        for a in range(0, x.shape[0], ffn_chunk):
            g[a:a + ffn_chunk] = hh[a:a + ffn_chunk] @ w.T
        with np.errstate(over="ignore"):
            for a in range(0, x.shape[0], ffn_chunk):   # silu in place, chunked to bound temporaries
                gg = g[a:a + ffn_chunk]
                gg /= (np.float32(1.0) + np.exp(-gg))
        w = self.lw(i, "w3")
        for a in range(0, x.shape[0], ffn_chunk):
            g[a:a + ffn_chunk] *= hh[a:a + ffn_chunk] @ w.T
        del hh
        w = self.lw(i, "w2")
        for a in range(0, x.shape[0], ffn_chunk):
            x[a:a + ffn_chunk] += g[a:a + ffn_chunk] @ w.T
        del g, w
        return x

    def _prefix_kv(self, ids, ffn_chunk):
        """Per-layer (K, V) of the shared prefix (positions 0..P-1), K after RoPE."""
        pos = np.arange(len(ids), dtype=np.int64)
        x = self.embed(ids)
        kv = []
        for i in range(L):
            h = self.rmsnorm(x, self.lw(i, "attn_norm"))
            k = self.rope((h @ self.lw(i, "wk").T).reshape(-1, NKV, HD), pos)
            v = (h @ self.lw(i, "wv").T).reshape(-1, NKV, HD)
            kv.append((k, v))
            x = self._layer(x, i, pos, np.array([0, len(ids)]), None, ffn_chunk)
        return kv

    def head(self, hn, chunk=8192):
        """Tied head: logits = hn @ E^T, E read in row chunks (exact fp32)."""
        name = self.n["embed"] if self.tied else None
        assert name is not None, "untied head not expected for Shieldstral"
        out = np.empty((hn.shape[0], V), np.float32)
        for a in range(0, V, chunk):
            e = self.f.get_f32(name, a, min(V, a + chunk))
            out[:, a:a + e.shape[0]] = hn @ e.T
        return out


def summarize(logits_row, yes_id, no_id, var_yes, var_no, topk=20):
    """D38 margin and the cookbook reference score from one logits row."""
    z = logits_row.astype(np.float64)
    m = z.max()
    lse = m + math.log(np.exp(z - m).sum())
    lp = z - lse
    top = np.argsort(-z)[:topk]
    zy_ref, zn_ref = -1e9, -1e9
    var_yes, var_no = set(var_yes), set(var_no)
    for t in top:
        if t in var_yes:
            zy_ref = max(zy_ref, lp[t])
        elif t in var_no:
            zn_ref = max(zn_ref, lp[t])
    margin = float(z[yes_id] - z[no_id])
    ref_score = math.exp(zy_ref) / (math.exp(zy_ref) + math.exp(zn_ref)) if max(zy_ref, zn_ref) > -1e8 else float("nan")
    d38_score = 1.0 / (1.0 + math.exp(-margin))
    return {"z_yes": float(z[yes_id]), "z_no": float(z[no_id]), "margin": margin,
            "lp_yes": float(lp[yes_id]), "lp_no": float(lp[no_id]),
            "p_yes_plus_no": float(math.exp(lp[yes_id]) + math.exp(lp[no_id])),
            "d38_score": d38_score, "ref_score": ref_score,
            "argmax": int(top[0]), "top": [[int(t), float(lp[t])] for t in top[:10]]}


# ------------------------------------------------------------------ bf16 emulation (diagnostic)
def bf(x):
    """Round float32 -> bfloat16 (round to nearest even) -> float32."""
    x = np.ascontiguousarray(x, np.float32)
    u = x.view(np.uint32)
    r = (u + np.uint32(0x7FFF) + ((u >> np.uint32(16)) & np.uint32(1))) & np.uint32(0xFFFF0000)
    return r.view(np.float32)


class RefBF16(Ref):
    """Emulates HF bf16 inference (the precision Mistral's published scores use): every tensor HF keeps
    in bf16 is rounded to bf16; matmuls accumulate in fp32 and round their output (as GPU tensor cores
    do); RMSNorm and softmax are computed in fp32 and cast, as in HF's code.  Diagnostic only."""

    def rmsnorm(self, x, w):
        x = x.astype(np.float32)
        var = np.mean(x * x, axis=-1, keepdims=True, dtype=np.float32)
        return bf(w * bf(x / np.sqrt(var + np.float32(EPS))))

    def rope(self, x, pos):
        ang = pos.astype(np.float64)[:, None] * self.inv_freq[None, :]
        cos = bf((np.cos(ang) * self.att_factor).astype(np.float32))[:, None, :]
        sin = bf((np.sin(ang) * self.att_factor).astype(np.float32))[:, None, :]
        assert self.n["rope"] == "half"
        x1, x2 = x[..., :HD // 2], x[..., HD // 2:]
        return np.concatenate([bf(bf(x1 * cos) - bf(x2 * sin)), bf(bf(x2 * cos) + bf(x1 * sin))], axis=-1)

    def attend(self, q, k, v):
        T, S = q.shape[0], k.shape[0]
        rep = NH // NKV
        out = np.empty((T, NH, HD), np.float32)
        scale = np.float32(1.0 / math.sqrt(HD))
        qb = max(1, min(T, (8 << 20) // max(1, S * rep * 4)))
        kt = np.ascontiguousarray(k.transpose(1, 2, 0))
        vt = np.ascontiguousarray(v.transpose(1, 0, 2))
        for a in range(0, T, qb):
            b = min(T, a + qb)
            qq = q[a:b].reshape(b - a, NKV, rep, HD).transpose(1, 0, 2, 3).reshape(NKV, (b - a) * rep, HD)
            sc = bf(bf(np.matmul(qq, kt)) * scale).reshape(NKV, b - a, rep, S)
            qpos = (S - T) + np.arange(a, b)
            bias = np.where(np.arange(S)[None, :] > qpos[:, None], np.float32(-np.inf), np.float32(0))
            sc = sc + bias[None, :, None, :].astype(np.float32)
            sc -= sc.max(axis=-1, keepdims=True)
            np.exp(sc, out=sc)
            sc /= sc.sum(axis=-1, keepdims=True)
            sc = bf(sc)
            o = bf(np.matmul(sc.reshape(NKV, (b - a) * rep, S), vt))
            out[a:b] = o.reshape(NKV, b - a, rep, HD).transpose(1, 0, 2, 3).reshape(b - a, NH, HD)
        return out

    def _layer(self, x, i, pos, offs, pkv, ffn_chunk):
        h = self.rmsnorm(x, self.lw(i, "attn_norm"))
        q = bf(h @ self.lw(i, "wq").T).reshape(-1, NH, HD)
        k = bf(h @ self.lw(i, "wk").T).reshape(-1, NKV, HD)
        v = bf(h @ self.lw(i, "wv").T).reshape(-1, NKV, HD)
        q = self.rope(q, pos)
        k = self.rope(k, pos)
        att = np.empty((x.shape[0], NH, HD), np.float32)
        for j in range(len(offs) - 1):
            a, b = offs[j], offs[j + 1]
            kk, vv = k[a:b], v[a:b]
            if pkv is not None:
                kk = np.concatenate([pkv[0], kk])
                vv = np.concatenate([pkv[1], vv])
            att[a:b] = self.attend(q[a:b], kk, vv)
        x = bf(x + bf(att.reshape(-1, NH * HD) @ self.lw(i, "wo").T))
        hh = self.rmsnorm(x, self.lw(i, "ffn_norm"))
        g = bf(hh @ self.lw(i, "w1").T)
        with np.errstate(over="ignore"):
            g = bf(g / (np.float32(1.0) + np.exp(-g)))
        g = bf(g * bf(hh @ self.lw(i, "w3").T))
        return bf(x + bf(g @ self.lw(i, "w2").T))

    def _prefix_kv(self, ids, ffn_chunk):
        pos = np.arange(len(ids), dtype=np.int64)
        x = self.embed(ids)
        kv = []
        for i in range(L):
            h = self.rmsnorm(x, self.lw(i, "attn_norm"))
            k = self.rope(bf(h @ self.lw(i, "wk").T).reshape(-1, NKV, HD), pos)
            v = bf(h @ self.lw(i, "wv").T).reshape(-1, NKV, HD)
            kv.append((k, v))
            x = self._layer(x, i, pos, np.array([0, len(ids)]), None, ffn_chunk)
        return kv

    def head(self, hn, chunk=8192):
        return bf(super().head(hn, chunk))

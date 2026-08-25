#!/usr/bin/env python3
"""m8b_gemma4_walker.py — U-PERF3 lane Y: numpy streaming reference walker
for the gemma-4-12B-qat text decoder (HF `gemma4_unified`), a drop-in
Walker replacement for scripts/m8b_int8_calibration.py so the SAME
calibrate/verdict machinery runs on Gemma (the C4 qualification gate of
docs/zkmatrix-poc/QUANTIZATION_CONTRACT_DESIGN.md).

================================================================================
GROUND-TRUTH FACTS BLOCK (the audit trail for every semantic below)
================================================================================
Source: huggingface/transformers @ main, commit
  9bb5f6a82b65aa216dfe1b2676194e55a869d51c (2026-08-25T06:46:50Z)
  src/transformers/models/gemma4_unified/modeling_gemma4_unified.py  [MOD]
  src/transformers/models/gemma4_unified/configuration_gemma4_unified.py [CFG]
  src/transformers/modeling_rope_utils.py                            [ROPE]
  src/transformers/activations.py                                    [ACT]
(raw URLs: https://raw.githubusercontent.com/huggingface/transformers/main/
 src/transformers/<path>; line numbers below are from the files fetched at
 the pinned commit, copies read in full on 2026-08-25.)

F1 RMSNorm [MOD L164-182, class Gemma4UnifiedRMSNorm]:
     out = (x * (mean(x^2, -1) + eps)^-0.5) * weight, computed in fp32.
   eps INSIDE the root; the scale is PLAIN `weight` (ones-init), NOT the
   Gemma-2/3 `(1 + weight)` form. A `with_scale=False` variant exists
   (no weight parameter) — used ONLY for v_norm (F4).
F2 Decoder layer wiring [MOD L492-525, Gemma4UnifiedTextDecoderLayer]:
     h = input_layernorm(x); h = self_attn(h);
     h = post_attention_layernorm(h); x = x + h          # attn residual
     h = pre_feedforward_layernorm(x); h = mlp(h);
     h = post_feedforward_layernorm(h); x = x + h        # ffn residual
     x *= layer_scalar                                   # AFTER the ffn
                                                         # residual — the
                                                         # WHOLE stream
   layer_scalar is a [1] buffer (ones-init) [MOD L490, L570].
F3 MLP (GeGLU) [MOD L458-474, Gemma4UnifiedTextMLP]:
     mlp(x) = down_proj(act(gate_proj(x)) * up_proj(x)),
   act = ACT2FN["gelu_pytorch_tanh"] = GELUTanh [ACT ~L965-982]:
     gelu_tanh(x) = 0.5*x*(1 + tanh(sqrt(2/pi)*(x + 0.044715*x^3)))
   (use_double_wide_mlp false, num_kv_shared_layers 0 for this ckpt.)
F4 Attention [MOD L342-455, Gemma4UnifiedTextAttention + L308-339
   eager_attention_forward]:
   - per-layer dims [CFG L177-190]: sliding layers head_dim 256, 8 KV
     heads; full_attention layers head_dim = global_head_dim 512,
     num_key_value_heads = num_global_key_value_heads 1 (because
     attention_k_eq_v true). 16 query heads everywhere; GQA repeat
     16//8 = 2 (sliding), 16//1 = 16 (full).
   - self.scaling = 1.0 [MOD L357], passed explicitly [MOD L448]:
     attn logits = q @ k^T * 1.0 — there is NO head_dim^-0.5 factor
     (the eager default at L319-320 only fires when scaling is None).
   - q path [MOD L408-411]: q_proj -> view(B,T,H,hd) -> q_norm
     (RMSNorm over hd, WITH weight) -> RoPE (unsqueeze_dim=2, i.e. on
     the (B,T,H,hd) layout) -> transpose.
   - k/v path [MOD L422-430]:
       key_states   = k_proj(x).view(...)
       value_states = v_proj(x).view(...) if v_proj is not None
                      else key_states          # BINDS the RAW k_proj
       key_states   = k_norm(key_states)       # output: on k_eq_v
       key_states   = rope(key_states)         # (full) layers v is
       value_states = v_norm(value_states)     # PRE-k_norm, PRE-RoPE
     v_norm is the scale-LESS RMSNorm [MOD L377] and is applied on ALL
     layers (sliding layers too: v = v_norm(v_proj(x))). v is never
     roped. On full layers v_proj is None [MOD L382-388].
   - eager attention [MOD L322-339]: repeat_kv, logits*scaling, +mask,
     softmax fp32, @v, o_proj. NO attention-level softcapping (the
     softcap arg defaults None and is never passed).
   - masks [MOD L642-645]: full_attention = plain causal;
     sliding_attention = causal + window 1024 (config). At T <= 1024
     plain causal is IDENTICAL (this walker asserts T <= window).
F5 RoPE:
   - sliding layers: rope_type "default", theta 10000 [config.json /
     CFG L170-173]; inv_freq = theta^-(arange(0,hd,2)/hd), hd 256
     [MOD L218-243 compute_default_rope_parameters]; emb =
     cat(freqs,freqs); x*cos + rotate_half(x)*sin [MOD L267-293] —
     exactly the m8b module's rope_cache/rope_apply convention.
   - full_attention layers: rope_type "proportional", theta 1e6,
     partial_rotary_factor 0.25 [config.json / CFG L172];
     [ROPE L193-266 _compute_proportional_rope_parameters]:
       rope_angles = int(0.25 * 512 // 2) = 64
       inv_freq = theta^-(arange(0,128,2)/512)   # 64 freqs, note the
                                                 # FULL head_dim in the
                                                 # denominator
       ++ zeros(512//2 - 64 = 192)               # 192 zero freqs
     so pairs (i, i+256) for i in 0..63 rotate, dims 64..255 /
     320..511 pass through (cos 1, sin 0). attention_scaling = 1.0
     [ROPE L244; MOD L261-262 multiplies cos/sin by it].
F6 Embeddings [MOD L528-539, L584-592]: x = embed_tokens(ids) *
   embed_scale, embed_scale = hidden_size**0.5 CAST TO THE WEIGHT DTYPE
   (bf16) at forward [MOD L539]; bf16(sqrt(3840)) = 62.0 exactly (the
   downcast is intended semantics — the PR 29402 comment at [MOD L589]).
F7 Head [MOD L679-746, Gemma4UnifiedForCausalLM]: lm_head TIED to
   embed_tokens [MOD L681]; final softcap [MOD L743-746]:
     logits = softcap * tanh(logits / softcap),  softcap = 30.0.
   Final hidden norm: model.norm RMSNorm before the head [MOD L670].
F8 Positions [MOD L626-629]: position_ids = arange(T) (no offset at
   prefill), BOS id 2 (config.json text_config / generation_config).

Checkpoint facts (scanned from ~/models/gemma-4-12B-qat, single-shard
bf16 safetensors): 48 layers at model.language_model.layers.N.*, 40
sliding + 8 full (layer_types; full at 5,11,17,23,29,35,41,47), d 3840,
f 15360, vocab 262144; sliding: q [4096,3840], k/v [2048,3840],
o [3840,4096], q/k_norm [256]; full: q [8192,3840], k [512,3840], NO
v_proj, o [3840,8192], q/k_norm [512]; four norms + layer_scalar [1]
per layer; rms eps 1e-6.

WHAT THIS WALKER IS: the same streaming discipline as
m8b_int8_calibration.Walker (per-layer load + free; fp32 activations;
< 4 GB RSS by construction — the 262144x3840 embedding is NEVER
materialized: token rows are seek-gathered and the head is streamed in
row chunks for loss/decode). Interface-identical: __init__(store, arch,
t_max), walk(tokens, ffn_override=None, collect=None) -> final-norm
hidden, loss(wins, ffn_override=None), _n/load_layer — so
m8b.weight_study and m8b.calibrate run UNCHANGED on Gemma.

WHAT IS COPIED-WITH-DELTA instead of imported: run_variant /
make_int8_ffn / make_wonly_ffn — m8b's copies hard-code SiLU in the fp
matched-input reference (m8b L674-677) and the weights-only chain (m8b
L701); the versions here are line-identical except the activation is
gelu_tanh and the table lines print the gelu family name. The
ffn_override seam is the GeGLU chain itself: xin is the
pre_feedforward_layernorm output, the override returns the mlp output
BEFORE post_feedforward_layernorm (the norm + residual + layer_scalar
stay fp32 walker code, exactly as mlp_norm/residual do on Mistral).

Typical runs:
  # decode gate (48 layers, one short prompt, minutes):
  python3 scripts/m8b_gemma4_walker.py --decode "The chemical symbol for gold is"
  # factual next-token rank probe (the T12-revised gate, >= 3/5 top-2):
  python3 scripts/m8b_gemma4_walker.py --probe
  # shape/RSS smoke (TRUNCATED — results are not the model's):
  python3 scripts/m8b_gemma4_walker.py --max-layers 6 --text <f> --smoke
  # THE FULL C4 GATE RUN (orchestrator schedules after the box frees):
  python3 scripts/m8b_gemma4_walker.py --text <fineweb_sample.txt>
"""

import argparse
import json
import math
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import m125_int8_calibration as m125    # noqa: E402  (primitives, never edited)
import m8b_int8_calibration as m8b      # noqa: E402  (IMPORTED, never edited)
from m8b_int8_calibration import p, rss_gb  # noqa: E402

DEFAULT_CKPT = str(Path.home() / "models" / "gemma-4-12B-qat")
EMBED_SCALE = 62.0          # bf16(sqrt(3840)) — facts F6
SOFTCAP = 30.0              # facts F7
GELU_C = math.sqrt(2.0 / math.pi)
HEAD_CHUNK = 8192           # vocab rows per streamed head chunk (~126 MB fp32)


def gelu_tanh(x):
    """gelu_pytorch_tanh, facts F3 — valid for fp32/fp64 arrays."""
    return 0.5 * x * (1.0 + np.tanh(GELU_C * (x + 0.044715 * x ** 3)))


def rmsnorm_noscale(x, eps):
    """The with_scale=False RMSNorm (v_norm), facts F1/F4."""
    v = np.mean(np.square(x), axis=-1, keepdims=True)
    return x / np.sqrt(v + eps)


def rope_cache_proportional(t, head_dim, base, partial):
    """Facts F5 full_attention: 'proportional' rope — rope_angles
    rotated frequency pairs at FULL-head_dim-denominator exponents,
    the rest zero-frequency (identity)."""
    rope_angles = int(partial * head_dim // 2)
    inv = base ** (-np.arange(0, 2 * rope_angles, 2, dtype=np.float64)
                   / head_dim)
    inv = np.concatenate([inv, np.zeros(head_dim // 2 - rope_angles)])
    ang = np.outer(np.arange(t, dtype=np.float64), inv)
    emb = np.concatenate([ang, ang], axis=-1)
    return (np.cos(emb).astype(np.float32),
            np.sin(emb).astype(np.float32))


# --------------------------------------------------------------------------
# architecture (config.json text_config) + tensor naming
# --------------------------------------------------------------------------

def arch_gemma4(ckpt_dir):
    cfg = json.loads((Path(ckpt_dir) / "config.json").read_text())
    tc = cfg["text_config"]
    assert tc["model_type"] == "gemma4_unified_text", tc["model_type"]
    names = dict(
        embed="model.language_model.embed_tokens.weight",
        attn_norm="model.language_model.layers.{l}.input_layernorm.weight",
        post_attn_norm=("model.language_model.layers.{l}."
                        "post_attention_layernorm.weight"),
        pre_ffw_norm=("model.language_model.layers.{l}."
                      "pre_feedforward_layernorm.weight"),
        post_ffw_norm=("model.language_model.layers.{l}."
                       "post_feedforward_layernorm.weight"),
        layer_scalar="model.language_model.layers.{l}.layer_scalar",
        wq="model.language_model.layers.{l}.self_attn.q_proj.weight",
        wk="model.language_model.layers.{l}.self_attn.k_proj.weight",
        wv="model.language_model.layers.{l}.self_attn.v_proj.weight",
        wo="model.language_model.layers.{l}.self_attn.o_proj.weight",
        q_norm="model.language_model.layers.{l}.self_attn.q_norm.weight",
        k_norm="model.language_model.layers.{l}.self_attn.k_norm.weight",
        w_gate="model.language_model.layers.{l}.mlp.gate_proj.weight",
        w_up="model.language_model.layers.{l}.mlp.up_proj.weight",
        w_down="model.language_model.layers.{l}.mlp.down_proj.weight",
        final_norm="model.language_model.norm.weight",
        lm_head=None,  # tied (facts F7)
    )
    a = m8b.Arch(tag="gemma-4-12B-qat", layers=tc["num_hidden_layers"],
                 d=tc["hidden_size"], f=tc["intermediate_size"],
                 heads=tc["num_attention_heads"],
                 kv_heads=tc["num_key_value_heads"],
                 vocab=tc["vocab_size"], eps=tc["rms_norm_eps"],
                 rope_base=tc["rope_parameters"]["sliding_attention"]
                 ["rope_theta"], tied=True, names=names)
    a.head_dim = tc["head_dim"]                       # sliding: 256
    a.layer_types = list(tc["layer_types"])
    a.global_head_dim = tc["global_head_dim"]         # full: 512
    a.global_kv_heads = tc["num_global_key_value_heads"]  # full: 1
    a.k_eq_v = bool(tc["attention_k_eq_v"])
    a.softcap = tc["final_logit_softcapping"]
    a.sliding_window = tc["sliding_window"]
    rp = tc["rope_parameters"]["full_attention"]
    assert rp["rope_type"] == "proportional", rp
    a.global_rope_base = rp["rope_theta"]
    a.global_rope_partial = rp["partial_rotary_factor"]
    a.bos_id = tc.get("bos_token_id", 2)
    return a


# --------------------------------------------------------------------------
# streamed embedding access (the 262144 x 3840 tensor is 4 GB in fp32 —
# it must NEVER be materialized; rows are seek-read on demand)
# --------------------------------------------------------------------------

class EmbedRows:
    """Row-gather / row-chunk reader over the bf16 embedding tensor,
    built on the m8b TensorStore/StShard header data."""

    def __init__(self, store, name):
        path = store.where[name]
        if path not in store.files:
            store.files[path] = m8b.StShard(path)
        sh = store.files[path]
        v = sh.hdr[name]
        assert v["dtype"] == "BF16", v["dtype"]
        self.path = sh.path
        self.rows, self.dim = v["shape"]
        self.start = sh.base + v["data_offsets"][0]
        self.rowbytes = self.dim * 2

    @staticmethod
    def _bf16(blob):
        u16 = np.frombuffer(blob, dtype="<u2").astype(np.uint32)
        return (u16 << 16).view(np.float32)

    def gather(self, ids):
        """ids (n,) int -> (n, dim) fp32 (unique rows read once)."""
        uniq, inv = np.unique(np.asarray(ids, dtype=np.int64),
                              return_inverse=True)
        out = np.empty((len(uniq), self.dim), dtype=np.float32)
        with open(self.path, "rb") as f:
            for j, t in enumerate(uniq):
                f.seek(self.start + int(t) * self.rowbytes)
                out[j] = self._bf16(f.read(self.rowbytes))
        return out[inv]

    def chunks(self, rows_per_chunk=HEAD_CHUNK):
        """Yield (row0, (n, dim) fp32) over the full vocab, streamed."""
        with open(self.path, "rb") as f:
            for r0 in range(0, self.rows, rows_per_chunk):
                n = min(rows_per_chunk, self.rows - r0)
                f.seek(self.start + r0 * self.rowbytes)
                yield r0, self._bf16(
                    f.read(n * self.rowbytes)).reshape(n, self.dim)


# --------------------------------------------------------------------------
# the walker (drop-in for m8b_int8_calibration.Walker)
# --------------------------------------------------------------------------

class Gemma4Walker:
    """Block-by-block fp32 reference forward of the gemma4_unified text
    decoder (facts F1-F8). Same interface/streaming contract as
    m8b_int8_calibration.Walker; collect/ffn_override semantics
    identical (x=pre_ffw_norm output; z=mlp output BEFORE
    post_feedforward_layernorm)."""

    def __init__(self, store, arch, t_max):
        self.store = store
        self.arch = arch
        self.t_max = t_max
        assert t_max <= arch.sliding_window, \
            "T exceeds the sliding window — plain causal invalid (F4)"
        # sliding: default rope, theta 10000, hd 256 — the m8b cache
        self.cos_s, self.sin_s = m8b.rope_cache(
            t_max, arch.head_dim, arch.rope_base)
        # full_attention: proportional rope, theta 1e6, partial 0.25
        self.cos_g, self.sin_g = rope_cache_proportional(
            t_max, arch.global_head_dim, arch.global_rope_base,
            arch.global_rope_partial)
        self.embed = EmbedRows(store, arch.names["embed"])

    def _n(self, key, l=None):
        s = self.arch.names[key]
        return s.format(l=l) if l is not None else s

    def load_layer(self, l):
        g = self.store.get
        keys = ["attn_norm", "post_attn_norm", "pre_ffw_norm",
                "post_ffw_norm", "layer_scalar", "wq", "wk", "wo",
                "q_norm", "k_norm", "w_gate", "w_up", "w_down"]
        if self.arch.layer_types[l] == "sliding_attention" or \
                not self.arch.k_eq_v:
            keys.append("wv")
        return {k: g(self._n(k, l)) for k in keys}

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
            vr = k.copy()   # k_eq_v: RAW k_proj output, pre-norm,
            #                 pre-rope (facts F4, MOD L423)
        q = m8b.rmsnorm(q, lw["q_norm"], a.eps)
        k = m8b.rmsnorm(k, lw["k_norm"], a.eps)
        v = rmsnorm_noscale(vr, a.eps)  # scale-less v_norm, ALL layers
        del vr
        mask = np.triu(np.full((T, T), -np.inf, dtype=np.float32), k=1)
        out = np.empty((B, T, H, hd), dtype=np.float32)
        for b in range(B):
            qb = m8b.rope_apply(q[b], cos, sin)
            kb = m8b.rope_apply(k[b], cos, sin)
            for h in range(H):
                # scaling = 1.0 — facts F4: NO hd**-0.5
                s = (qb[:, h] @ kb[:, h // rep].T) + mask
                s -= s.max(axis=-1, keepdims=True)
                e = np.exp(s)
                w = e / e.sum(axis=-1, keepdims=True)
                out[b, :, h] = w @ v[b, :, h // rep]
        return out.reshape(B * T, H * hd) @ lw["wo"].T

    def walk(self, tokens, ffn_override=None, collect=None):
        """tokens (B, T) -> final-norm hidden (B, T, d)."""
        a = self.arch
        B, T = tokens.shape
        x = (self.embed.gather(tokens.reshape(-1)).reshape(B, T, a.d)
             * np.float32(EMBED_SCALE))                    # facts F6
        for l in range(a.n_layers):
            lt = a.layer_types[l]
            lw = self.load_layer(l)
            hn = m8b.rmsnorm(x, lw["attn_norm"], a.eps)
            att = self._attention(hn, lw, lt).reshape(B, T, a.d)
            x = x + m8b.rmsnorm(att, lw["post_attn_norm"], a.eps)
            del hn, att
            xin = m8b.rmsnorm(x, lw["pre_ffw_norm"], a.eps)
            if ffn_override is not None:
                z = ffn_override(l, xin, lw)
            else:
                flat = xin.reshape(B * T, a.d)
                gate = flat @ lw["w_gate"].T
                up = flat @ lw["w_up"].T
                act = gelu_tanh(gate)                      # facts F3
                h = act * up
                z = (h @ lw["w_down"].T).reshape(B, T, a.d)
                if collect is not None:
                    collect(l, dict(x=xin, gate=gate, up=up, a=act,
                                    h=h, z=z))
                del gate, up, act, h
            x = x + m8b.rmsnorm(z, lw["post_ffw_norm"], a.eps)
            x = x * np.float32(lw["layer_scalar"][0])      # facts F2
            del lw, xin, z
        fw = self.store.get(self._n("final_norm"))
        return m8b.rmsnorm(x, fw, a.eps)

    # -- streamed head: logits never materialize at (T, 262144) x fp64 --

    def _lse_and_picked(self, hid_b, targets):
        """One sequence: softcapped logits streamed over vocab chunks;
        returns (lse (T,), picked (T,)) in fp64. Facts F7 softcap."""
        T = hid_b.shape[0]
        m_run = np.full(T, -np.inf)
        s_run = np.zeros(T)
        picked = np.full(T, np.nan)
        tg = np.asarray(targets, dtype=np.int64)
        for r0, blk in self.embed.chunks():
            lg = (hid_b @ blk.T).astype(np.float64)
            lg = SOFTCAP * np.tanh(lg / SOFTCAP)
            inw = (tg >= r0) & (tg < r0 + blk.shape[0])
            if inw.any():
                rows = np.nonzero(inw)[0]
                picked[rows] = lg[rows, tg[rows] - r0]
            m_new = np.maximum(m_run, lg.max(axis=-1))
            s_run = (s_run * np.exp(m_run - m_new)
                     + np.exp(lg - m_new[:, None]).sum(axis=-1))
            m_run = m_new
            del lg, blk
        assert not np.isnan(picked).any()
        return m_run + np.log(s_run), picked

    def loss(self, wins, ffn_override=None):
        """Mean next-token cross-entropy (m8b form), tied softcapped
        head streamed in chunks."""
        hid = self.walk(wins[:, :-1], ffn_override=ffn_override)
        tot, cnt = 0.0, 0
        for b in range(wins.shape[0]):
            lse, picked = self._lse_and_picked(hid[b], wins[b, 1:])
            tot += float((lse - picked).sum())
            cnt += lse.shape[0]
        return tot / cnt

    def last_logits_stream(self, hid_last):
        """(d,) final-norm hidden -> full softcapped logits (vocab,)
        fp32, streamed (one 1 MB row at fp32 — fine to return)."""
        out = np.empty(self.arch.vocab, dtype=np.float32)
        for r0, blk in self.embed.chunks():
            lg = (blk @ hid_last).astype(np.float64)
            out[r0:r0 + blk.shape[0]] = SOFTCAP * np.tanh(lg / SOFTCAP)
        return out


# --------------------------------------------------------------------------
# int8 chain pieces — m8b copies with the activation swapped to
# gelu_tanh (m8b's fp matched-input reference and weights-only chain
# hard-code SiLU; everything else is line-identical, see header)
# --------------------------------------------------------------------------

def make_int8_ffn(scales, members, acc_track, viol_track, err_track,
                  mode="floor"):
    """m8b.make_int8_ffn verbatim EXCEPT the fp32 matched-input
    reference uses gelu_tanh (the model's activation, facts F3)."""

    def ffn(li, x, lw):
        sc = scales[li]
        B, T, C = x.shape
        tab = members[(sc["eGate"], sc["eA"])][0].astype(np.float64)
        Wq = {}
        for name, ekey in (("w_gate", "eWg"), ("w_up", "eWu"),
                           ("w_down", "eWd")):
            q, _ = m125.quantize(lw[name].astype(np.float64), sc[ekey])
            Wq[name] = q
        sh_g = sc["eGate"] - sc["eX"] - sc["eWg"]
        sh_u = sc["eUp"] - sc["eX"] - sc["eWu"]
        sh_h = sc["eH"] - sc["eA"] - sc["eUp"]
        sh_z = sc["eZ"] - sc["eH"] - sc["eWd"]
        z_out = np.empty((B, T, C), dtype=np.float32)
        for b in range(B):
            xf = x[b].astype(np.float64)
            xq, xclip = m125.quantize(xf, sc["eX"])
            viol_track[li]["X_clip"] += xclip
            acc_g = xq @ Wq["w_gate"].T
            acc_u = xq @ Wq["w_up"].T
            acc_track[li]["gateup"] = max(acc_track[li]["gateup"],
                                          float(np.abs(acc_g).max()),
                                          float(np.abs(acc_u).max()))
            yg, vg = m125.narrow_int8(m125.floor_requant(acc_g, sh_g,
                                                         mode))
            yu, vu = m125.narrow_int8(m125.floor_requant(acc_u, sh_u,
                                                         mode))
            viol_track[li]["gate_range"] += vg
            viol_track[li]["up_range"] += vu
            aq = tab[(yg.astype(np.int64) + 128)]
            hq = aq * yu
            acc_track[li]["had"] = max(acc_track[li]["had"],
                                       float(np.abs(hq).max()))
            yh, vh = m125.narrow_int8(m125.floor_requant(hq, sh_h, mode))
            viol_track[li]["h_range"] += vh
            acc_d = yh @ Wq["w_down"].T
            acc_track[li]["down"] = max(acc_track[li]["down"],
                                        float(np.abs(acc_d).max()))
            yz, vz = m125.narrow_int8(m125.floor_requant(acc_d, sh_z,
                                                         mode))
            viol_track[li]["z_range"] += vz
            z_out[b] = (yz * (2.0 ** sc["eZ"])).astype(np.float32)
        # matched-input error: the fp GeGLU FFN on the SAME x
        flat = x.reshape(B * T, C)
        gate = flat @ lw["w_gate"].T
        zf = ((gelu_tanh(gate) * (flat @ lw["w_up"].T))
              @ lw["w_down"].T).astype(np.float64)
        zq = z_out.reshape(B * T, -1).astype(np.float64)
        num = float(np.sqrt(((zf - zq) ** 2).mean()))
        den = float(np.sqrt((zf ** 2).mean()))
        err_track[li].append(num / den if den else 0.0)
        return z_out

    return ffn


def make_wonly_ffn(scales):
    """m8b.make_wonly_ffn with gelu_tanh."""

    def ffn(li, x, lw):
        sc = scales[li]
        B, T, C = x.shape
        flat = x.reshape(B * T, C).astype(np.float64)
        dq = {}
        for name, ekey in (("w_gate", "eWg"), ("w_up", "eWu"),
                           ("w_down", "eWd")):
            q, _ = m125.quantize(lw[name].astype(np.float64), sc[ekey])
            dq[name] = q * (2.0 ** sc[ekey])
        gate = flat @ dq["w_gate"].T
        z = ((gelu_tanh(gate) * (flat @ dq["w_up"].T))
             @ dq["w_down"].T)
        return z.astype(np.float32).reshape(B, T, C)

    return ffn


def run_variant(walker, scales, members, val_wins, mode, label, arch,
                verbose=False):
    """m8b.run_variant verbatim except it calls THIS module's
    make_int8_ffn (gelu matched-input reference)."""
    L = arch.n_layers
    acc_track = [dict(gateup=0.0, had=0.0, down=0.0) for _ in range(L)]
    viol_track = [dict(X_clip=0, gate_range=0, up_range=0, h_range=0,
                       z_range=0) for _ in range(L)]
    err_track = [[] for _ in range(L)]
    ffn = make_int8_ffn(scales, members, acc_track, viol_track,
                        err_track, mode=mode)
    loss = walker.loss(val_wins, ffn_override=ffn)
    m_gu, b_gu = m125.acc_width(arch.d)
    m_dn, b_dn = m125.acc_width(arch.f)
    total_viol = 0
    if verbose:
        p("%-6s %12s %12s %10s %30s %10s" % (
            "layer", "max|acc_d|", "max|acc_f|", "max|h15|",
            "range-fact violations (held-out)", "relFFNerr"))
    for li in range(L):
        v = viol_track[li]
        total_viol += sum(v.values())
        if verbose:
            p("%-6d %12.0f %12.0f %10.0f %30s %10.4f"
              % (li, acc_track[li]["gateup"], acc_track[li]["down"],
                 acc_track[li]["had"],
                 "X:%d g:%d u:%d h:%d z:%d" % (
                     v["X_clip"], v["gate_range"], v["up_range"],
                     v["h_range"], v["z_range"]),
                 float(np.mean(err_track[li]))))
        assert acc_track[li]["gateup"] <= m_gu
        assert acc_track[li]["down"] <= m_dn
    if verbose:
        p("-> accumulator ceilings respected everywhere: gate/up %d-bit "
          "(bound %d), down %d-bit (bound %d); Hadamard products inside "
          "the 15-bit class" % (b_gu, m_gu, b_dn, m_dn))
    return dict(label=label, mode=mode, wgran="tensor", loss=loss,
                total_viol=total_viol,
                acc_bounds=dict(gateup=[m_gu, b_gu], down=[m_dn, b_dn]),
                per_layer=[dict(acc=acc_track[li], viol=viol_track[li],
                                rel_ffn_err=float(np.mean(err_track[li])))
                           for li in range(L)])


# --------------------------------------------------------------------------
# the decode / factual gate (T12-revised: next-token RANKS are the
# evidence; the -it- distribution is chattier, so the gate is >= 3/5
# expected tokens in the top-2)
# --------------------------------------------------------------------------

PROBES = [
    ("The chemical symbol for gold is", " Au"),
    ("The gas that humans need to breathe to survive is called",
     " oxygen"),
    ("The play Romeo and Juliet was written by William", " Shakespeare"),
    ("2 + 2 =", " 4"),
    ("The largest planet in our solar system is", " Jupiter"),
]


# The -it- checkpoint's canonical wrapping (hub chat_template.jinja,
# google/gemma-4-12B-it-qat-q4_0-unquantized @ main, published
# 2026-07-09, lines 188/233/372/382-385): bos_token leads, then
# '<|turn>user\n{msg}<turn|>\n<|turn>model\n' and, with thinking off,
# '<|channel>thought\n<channel|>'. Specials encode as single ids
# (105/106/100/101 — tokenizer.json added_tokens). For the rank probe
# the PARTIAL SENTENCE is prefilled INTO the model turn, keeping the
# gate a next-token-rank test while in the it-model's distribution.
TEMPLATE_PRE = ("<|turn>user\nComplete this sentence.<turn|>\n"
                "<|turn>model\n<|channel>thought\n<channel|>")


def encode_prompt(tk, arch, prompt, template=False):
    if template:
        prompt = TEMPLATE_PRE + prompt
    ids = list(m8b.tok_encode(tk, prompt))
    if ids and ids[0] != arch.bos_id:
        ids = [arch.bos_id] + ids
    return ids


def greedy_decode(walker, arch, ckpt_dir, prompt, n_new=8,
                  template=False):
    tk = m8b.load_tokenizer(ckpt_dir)
    ids = encode_prompt(tk, arch, prompt, template=template)
    p("greedy decode (functional self-check of the forward):")
    p("  prompt: %r  (BOS %d prepended, %d tokens%s)"
      % (prompt, arch.bos_id, len(ids),
         ", it-template wrapped" if template else ""))
    for _ in range(n_new):
        toks = np.asarray(ids, dtype=np.int64)[None, :]
        hid = walker.walk(toks)
        logits = walker.last_logits_stream(hid[0, -1])
        ids.append(int(np.argmax(logits)))
        del hid, logits
    p("  completion: %r" % m8b.tok_decode(tk, ids))


def factual_probe(walker, arch, ckpt_dir, top2_needed=3,
                  template=False):
    """Rank of each expected next token under the softcapped logits;
    gate: >= top2_needed of the probes at rank <= 1."""
    tk = m8b.load_tokenizer(ckpt_dir)
    hits, rows = 0, []
    p("factual next-token rank probe (%d prompts%s):"
      % (len(PROBES), ", it-template wrapped" if template else ""))
    for prompt, expect in PROBES:
        ids = encode_prompt(tk, arch, prompt, template=template)
        want = m8b.tok_encode(tk, expect)
        want_id = int(want[0])
        hid = walker.walk(np.asarray(ids, dtype=np.int64)[None, :])
        logits = walker.last_logits_stream(hid[0, -1])
        order = np.argsort(-logits)
        rank = int(np.nonzero(order == want_id)[0][0])
        top5 = [(int(i), m8b.tok_decode(tk, [int(i)]),
                 float(logits[i])) for i in order[:5]]
        gap = float(logits[order[0]] - logits[want_id])
        ok = rank <= 1
        hits += int(ok)
        rows.append(dict(prompt=prompt, expect=expect, want_id=want_id,
                         rank=rank, top5=top5, gap_to_top=gap,
                         top2=ok))
        p("  %-58r want %r (id %d): rank %d %s gap %.3f"
          % (prompt, expect, want_id, rank,
             "TOP-2" if ok else "MISS ", gap))
        p("    top-5: %s" % ", ".join(
            "%r %.2f" % (t[1], t[2]) for t in top5))
        del hid, logits, order
    verdict = hits >= top2_needed
    p("factual gate: %d/%d expected tokens in the top-2 -> %s "
      "(need >= %d)"
      % (hits, len(PROBES), "PASS" if verdict else "FAIL", top2_needed))
    return dict(hits=hits, needed=top2_needed, passed=verdict,
                template=template, probes=rows)


# --------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ckpt", default=DEFAULT_CKPT)
    ap.add_argument("--tokens", default=None, help="pre-tokenized .npy")
    ap.add_argument("--text", default=None, help="utf-8 text file")
    ap.add_argument("--t", type=int, default=512)
    ap.add_argument("--cal-seqs", type=int, default=8)
    ap.add_argument("--val-seqs", type=int, default=8)
    ap.add_argument("--seed", type=int, default=1337)
    ap.add_argument("--max-layers", type=int, default=None,
                    help="truncate the stack (SMOKE ONLY)")
    ap.add_argument("--out-json",
                    default=str(ROOT / "results" /
                                "m8b_gemma4_calibration.json"))
    ap.add_argument("--variants", action="store_true",
                    help="also run variant B (round-to-nearest requant)")
    ap.add_argument("--decode", default=None,
                    help="greedy-decode this prompt and exit")
    ap.add_argument("--probe", action="store_true",
                    help="run the factual next-token rank gate and exit")
    ap.add_argument("--template", action="store_true",
                    help="wrap --decode/--probe prompts in the it "
                         "chat template (TEMPLATE_PRE)")
    ap.add_argument("--smoke", action="store_true",
                    help="stop after calibration (no held-out chain)")
    args = ap.parse_args()

    arch = arch_gemma4(args.ckpt)
    if args.max_layers:
        arch.n_layers = min(arch.n_layers, args.max_layers)
    store = m8b.TensorStore(args.ckpt)
    walker = Gemma4Walker(store, arch, args.t)
    p("m8b_gemma4_walker — %s (%d layers [%d sliding/%d full in use], "
      "d %d, f %d, heads %d/%d sliding hd %d, global hd %d kv %d, "
      "vocab %d), TARGET_CONTRACT S2 semantics + gemma4 facts F1-F8"
      % (arch.tag, arch.n_layers,
         sum(1 for t in arch.layer_types[:arch.n_layers]
             if t == "sliding_attention"),
         sum(1 for t in arch.layer_types[:arch.n_layers]
             if t == "full_attention"),
         arch.d, arch.f, arch.heads, arch.kv_heads, arch.head_dim,
         arch.global_head_dim, arch.global_kv_heads, arch.vocab))
    p("checkpoint: %s (READ-ONLY, streamed per tensor; embedding "
      "row-gathered, head chunk-streamed)" % args.ckpt)
    if args.max_layers:
        p("** TRUNCATED to %d layers — SMOKE RUN, results are not the "
          "model's **" % arch.n_layers)

    if args.decode:
        greedy_decode(walker, arch, args.ckpt, args.decode,
                      template=args.template)
        p("peak RSS %.2f GB" % rss_gb())
        return
    if args.probe:
        res = factual_probe(walker, arch, args.ckpt,
                            template=args.template)
        out = Path(str(ROOT / "results" / "m8b_gemma4_probe.json"))
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(
            dict(checkpoint=str(args.ckpt), gate=res), indent=1))
        p("JSON -> %s" % out)
        p("peak RSS %.2f GB" % rss_gb())
        return

    from m8b_gemma4_gelu_member import gelu_members, report_gelu_members

    report = {"checkpoint": str(args.ckpt), "arch": "gemma4_unified",
              "model_tag": arch.tag, "seed": args.seed,
              "dims": dict(layers=arch.n_layers, d=arch.d, f=arch.f,
                           t=args.t),
              "truncated": bool(args.max_layers),
              "semantics": "TARGET_CONTRACT.md Section 2 chain on the "
                           "GeGLU FFN (gelu_pytorch_tanh via the v2 "
                           "family formula/digest convention); walker "
                           "facts F1-F8 pinned to transformers "
                           "9bb5f6a8"}

    wrows = m8b.weight_study(store, arch, walker)
    report["weights"] = wrows
    report["accumulators"] = m8b.accumulator_section(arch)

    toks = m8b.load_token_stream(args, args.ckpt)
    cal, val = m8b.token_batches(toks, args.seed, args.cal_seqs,
                                 args.val_seqs, args.t)
    scales = m8b.calibrate(walker, cal, wrows, arch)
    report["calibration"] = scales

    members = gelu_members(scales)
    p()
    fresh = report_gelu_members(members)
    report["gelu_members"] = {
        "%d,%d" % k: dict(digest=dg, frozen=fr)
        for k, (t, dg, fr) in members.items()}

    if args.smoke:
        p()
        p("** --smoke: stopping before the held-out int8 chain **")
        out = Path(args.out_json)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(report, indent=1))
        p("JSON -> %s" % out)
        p("peak RSS %.2f GB" % rss_gb())
        return

    p()
    p("=" * 78)
    p("SECTION 4 — int8 chain on HELD-OUT data (%d seq x %d tokens; "
      "scales frozen from Section 3)" % (val.shape[0], args.t))
    p("=" * 78)
    n_pos = int(val[:, :-1].size)
    loss_ref = walker.loss(val)
    p("bf16 reference val loss: %.4f" % loss_ref)

    p("variant A — the semantics as written (floor requant, per-tensor "
      "scales):")
    A = run_variant(walker, scales, members, val, "floor",
                    "A floor/per-tensor", arch, verbose=True)
    p("-> range-fact violations on held-out data: %d of %d positions x 5 "
      "facts; val loss %.4f (ref %.4f, delta %+.4f nats)"
      % (A["total_viol"], n_pos, A["loss"], loss_ref,
         A["loss"] - loss_ref))
    variants = [A]
    if args.variants:
        B = run_variant(walker, scales, members, val, "round",
                        "B round/per-tensor", arch)
        p("variant B (round-to-nearest attribution): loss %.4f "
          "(%+.4f), %d violations" % (B["loss"], B["loss"] - loss_ref,
                                      B["total_viol"]))
        variants.append(B)
    loss_wonly = walker.loss(val, ffn_override=make_wonly_ffn(scales))
    p("weights-only (per-tensor int8 W, fp acts): loss %.4f (%+.4f)"
      % (loss_wonly, loss_wonly - loss_ref))
    report["int8_chain"] = dict(
        loss_ref=loss_ref, positions=n_pos, variants=variants,
        weights_only=dict(loss=loss_wonly,
                          delta=loss_wonly - loss_ref))

    p()
    p("=" * 78)
    p("VERDICT (C4: (i) 0 violations, (ii) quality budget, "
      "(iii) frozen members)")
    p("=" * 78)
    calibrates = (A["total_viol"] == 0)
    p("range facts on held-out data: %s (%d violations, variant A)"
      % ("HOLD" if calibrates else "FAIL", A["total_viol"]))
    if fresh:
        p("GELU family: %d member(s) NOT in any frozen registry %s — "
          "C5 freeze ruling needed before the rig accepts this "
          "statement" % (len(fresh), [k for k, _ in fresh]))
    else:
        p("GELU family: every calibrated member is already frozen")
    p("verdict: the checkpoint %s in the FORMAL sense at the calibrated "
      "per-tensor power-of-two scales; quality cost of the as-written "
      "chain %+.4f nats (A); weights-only %+.4f"
      % ("CALIBRATES" if calibrates else "DOES NOT CALIBRATE",
         A["loss"] - loss_ref, loss_wonly - loss_ref))
    report["verdict"] = dict(
        calibrates_formally=calibrates,
        range_violations=dict(A=A["total_viol"]),
        gelu_new_members=["%d,%d" % k for k, _ in fresh],
        loss_ref=loss_ref,
        loss_delta_nats=dict(
            A=A["loss"] - loss_ref,
            weights_only=loss_wonly - loss_ref))

    out = Path(args.out_json)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=1))
    p("JSON -> %s" % out)
    p("peak RSS %.2f GB" % rss_gb())


if __name__ == "__main__":
    main()

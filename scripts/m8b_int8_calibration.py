#!/usr/bin/env python3
"""m8b_int8_calibration.py — U-PERF3 lane R: int8 calibration of an 8B-class
FFN (MVP-1, PROGRESS_UPERF3.md) generalized from scripts/m125_int8_calibration.py.

Target: an OPEN checkpoint with the TARGET_CONTRACT 8B FFN dims —
Mistral-7B-v0.1 (d 4096, f 14336, 32 layers, SwiGLU, Apache-2.0) in
HuggingFace safetensors format. Same statement semantics as the m125
study (TARGET_CONTRACT.md Section 2: int8 SYMMETRIC [-127,127],
power-of-two scales, floor requantization x = 2^shift*y + r with
r in [0, 2^shift)); the m125 primitives are IMPORTED, never edited.

What is different from the m125 script (and why):

  1. STREAMING. A 7B bf16 checkpoint is 14.5 GB on disk and does not fit
     the 15 GiB WSL box in RAM. Safetensors tensors are read PER TENSOR
     (seek to the data_offsets window, read exactly those bytes) and the
     model is walked BLOCK BY BLOCK, loading one layer's weights at a
     time and freeing them: peak RSS stays < 4 GB at the 7B shape, so
     EITHER box can run this. Sharded checkpoints
     (model-0000X-of-0000Y.safetensors + model.safetensors.index.json)
     are resolved through the index; single-file checkpoints work too.
  2. NO MLX / NO TORCH. The reference forward is a numpy fp32
     re-implementation of the standard pre-norm decoder (RMSNorm, RoPE
     rotate-half convention, GQA, SwiGLU) driven by config.json. Two
     architecture adapters exist:
       --arch hf      HuggingFace Llama/Mistral naming (the 7B target)
       --arch frugal  frugal-lm 125M naming (blocks.N.*, tied embed) —
                      the TEST adapter: the same walk code runs the 125M
                      checkpoint so the whole path is validated on this
                      box against the committed m125 references
                      (scripts/m8b_verify_125m.py).
     CAVEAT: fp32 activations differ from another framework's fp32 at
     the 1e-6 level (op order), so calibrated EXPONENTS are expected to
     reproduce but activation tensors are not bit-pinned across
     frameworks (the m125 Mac-vs-WSL export README documents the same
     effect under mlx CPU vs Metal).
  3. The int8 simulation carries exact integers in float64 BLAS matmuls
     (every product <= 127^2, every accumulator <= 14336*127^2 = 2.31e8
     << 2^53: sums of integers below 2^53 are exact in float64 in any
     summation order), because numpy int64 matmul does not use BLAS and
     would be ~50x slower at f = 14336.
  4. The SiLU table used in the simulation is the FROZEN v2 family
     formula (round_half_up, ring/lookup.rs via scripts/m125_export_ffn.py)
     — not the m125 study's np.round variant — so the calibration
     verdict is for the exact table the prover uses. If the calibrated
     (eGate, eA) pair is outside the frozen family {(-3,-3), (-4,-4)}
     the script WARNS and records the new member digest (memo Section 2
     W-6: freezing a new member is a Victor ruling because manifest.rs
     moves).

Sections (mirroring the m125 study):
  1. WEIGHTS: per-tensor symmetric int8, power-of-two scale exponents
     eWg/eWu/eWd per layer (NOT asserted uniform like m125's -9),
     saturation counts, quantization error. Streamed.
  2. ACCUMULATORS: the contract's own 27/29-bit rows at inner 4096/11008
     reproduced, then THIS model's rows at inner d / f.
  3. ACTIVATION CALIBRATION: eX, eGate, eUp, eA, eH, eZ per layer from
     absmax on a seeded calibration batch (same window sampler as m125,
     seed 1337, disjoint cal/val windows).
  4. INT8 CHAIN on HELD-OUT windows: variant A (floor requant,
     per-tensor scales — the statement as written): range-fact
     violations (0 required for a provable witness), accumulator
     ceilings, matched-input FFN error, end-to-end val-loss delta; plus
     the weights-only attribution variant. --variants adds B
     (round-to-nearest requant attribution).

Data: --tokens <npy> (a pre-tokenized uint16/uint32 stream — the m125
window sampler draws from it) or --text <utf8 file> (tokenized with the
checkpoint's tokenizer.json via `tokenizers`, else tokenizer.model via
`sentencepiece`). For the 7B run the RUN task extracts a FineWeb-Edu
text sample (memo Section 5).

Outputs: printed tables + a JSON report (--out-json, default
results/m8b_int8_calibration.json) whose "calibration" rows use the
SAME keys as the m125 JSON (eX,eGate,eUp,eA,eH,eZ,eWg,eWu,eWd) so
scripts/m8b_export_ffn.py consumes either. Nothing under the checkpoint
directory is ever written.

Typical runs:
  # the 7B calibration (Mac; ~15-30 min CPU, < 4 GB RSS):
  python3 scripts/m8b_int8_calibration.py \
      --ckpt ~/models/Mistral-7B-v0.1 --text fineweb_edu_sample.txt
  # the 125M validation on the WSL box (see scripts/m8b_verify_125m.py):
  python3 scripts/m8b_int8_calibration.py --arch frugal \
      --ckpt /home/victor/models/125m-best-adamw-val3.0816 \
      --tokens /home/victor/shard-00000.npy
  # functional sanity of the hf forward (greedy continuation):
  python3 scripts/m8b_int8_calibration.py --ckpt ~/models/Mistral-7B-v0.1 \
      --decode "The capital of France is"
"""

import argparse
import json
import math
import resource
import struct
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import m125_int8_calibration as m125  # noqa: E402  (primitives, never edited)
import m125_export_ffn as m125x       # noqa: E402  (frozen SiLU family formula)

QMAX = 127


def p(line=""):
    print(line, flush=True)


def rss_gb():
    """Peak RSS in GB (ru_maxrss: KB on Linux, bytes on macOS)."""
    v = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    return v / 1e9 if sys.platform == "darwin" else v / 1e6


# --------------------------------------------------------------------------
# streaming safetensors (per-tensor seek reads — never a whole shard)
# --------------------------------------------------------------------------

class StShard:
    """One safetensors file: header parsed once, tensors read by seek."""

    def __init__(self, path):
        self.path = Path(path)
        with open(self.path, "rb") as f:
            n = struct.unpack("<Q", f.read(8))[0]
            self.hdr = json.loads(f.read(n))
            self.base = 8 + n
        self.hdr.pop("__metadata__", None)

    def names(self):
        return list(self.hdr)

    def get(self, name):
        """Read ONE tensor: seek + exact-size read; BF16/F16 widened to
        fp32 (BF16 exactly: uint16 << 16 reinterpreted)."""
        v = self.hdr[name]
        s, e = v["data_offsets"]
        with open(self.path, "rb") as f:
            f.seek(self.base + s)
            blob = f.read(e - s)
        dt = v["dtype"]
        if dt == "BF16":
            u16 = np.frombuffer(blob, dtype="<u2").astype(np.uint32)
            arr = (u16 << 16).view(np.float32)
        elif dt == "F32":
            arr = np.frombuffer(blob, dtype="<f4")
        elif dt == "F16":
            arr = np.frombuffer(blob, dtype="<f2").astype(np.float32)
        else:
            raise ValueError("unhandled dtype %s for %s" % (dt, name))
        return np.ascontiguousarray(arr.reshape(v["shape"]).astype(
            np.float32, copy=False))


class TensorStore:
    """Checkpoint directory (or single file): name -> shard resolution via
    model.safetensors.index.json when present, else every *.safetensors
    header is scanned (headers only — data is never bulk-read)."""

    def __init__(self, ckpt):
        ckpt = Path(ckpt)
        self.files = {}     # path -> StShard (lazy)
        self.where = {}     # tensor name -> path
        if ckpt.is_file():
            sh = StShard(ckpt)
            self.files[str(ckpt)] = sh
            for k in sh.names():
                self.where[k] = str(ckpt)
            return
        idx = ckpt / "model.safetensors.index.json"
        if idx.exists():
            wm = json.loads(idx.read_text())["weight_map"]
            for k, fn in wm.items():
                self.where[k] = str(ckpt / fn)
        else:
            cands = sorted(ckpt.glob("*.safetensors"))
            assert cands, "no *.safetensors under %s" % ckpt
            for c in cands:
                sh = StShard(c)
                self.files[str(c)] = sh
                for k in sh.names():
                    self.where[k] = str(c)

    def get(self, name):
        path = self.where[name]
        if path not in self.files:
            self.files[path] = StShard(path)
        return self.files[path].get(name)

    def shard_paths(self):
        return sorted(set(self.where.values()))


# --------------------------------------------------------------------------
# architecture adapters (dims + tensor naming; both are the same standard
# pre-norm decoder: RMSNorm -> attn (RoPE rotate-half, GQA) -> residual ->
# RMSNorm -> SwiGLU FFN -> residual)
# --------------------------------------------------------------------------

class Arch:
    def __init__(self, tag, layers, d, f, heads, kv_heads, vocab, eps,
                 rope_base, tied, names):
        self.tag = tag
        self.n_layers = layers
        self.d = d
        self.f = f
        self.heads = heads
        self.kv_heads = kv_heads
        self.head_dim = d // heads
        self.vocab = vocab
        self.eps = eps
        self.rope_base = rope_base
        self.tied = tied
        self.names = names  # dict of format strings / fixed names


def arch_hf(ckpt_dir):
    cfg = json.loads((Path(ckpt_dir) / "config.json").read_text())
    names = dict(
        embed="model.embed_tokens.weight",
        attn_norm="model.layers.{l}.input_layernorm.weight",
        wq="model.layers.{l}.self_attn.q_proj.weight",
        wk="model.layers.{l}.self_attn.k_proj.weight",
        wv="model.layers.{l}.self_attn.v_proj.weight",
        wo="model.layers.{l}.self_attn.o_proj.weight",
        mlp_norm="model.layers.{l}.post_attention_layernorm.weight",
        w_gate="model.layers.{l}.mlp.gate_proj.weight",
        w_up="model.layers.{l}.mlp.up_proj.weight",
        w_down="model.layers.{l}.mlp.down_proj.weight",
        final_norm="model.norm.weight",
        lm_head="lm_head.weight",
    )
    a = Arch(tag=cfg.get("_name_or_path", "") or "hf-model",
             layers=cfg["num_hidden_layers"], d=cfg["hidden_size"],
             f=cfg["intermediate_size"], heads=cfg["num_attention_heads"],
             kv_heads=cfg.get("num_key_value_heads",
                              cfg["num_attention_heads"]),
             vocab=cfg["vocab_size"], eps=cfg.get("rms_norm_eps", 1e-5),
             rope_base=cfg.get("rope_theta", 10000.0),
             tied=cfg.get("tie_word_embeddings", False), names=names)
    a.sliding_window = cfg.get("sliding_window")
    return a


def arch_frugal():
    """The frugal-lm 125M rung (this box's TEST checkpoint): fixed config
    per configs/125m.yaml; mlx RMSNorm eps 1e-5, RoPE traditional=False
    (= rotate-half), tied embeddings."""
    names = dict(
        embed="embed.weight",
        attn_norm="blocks.{l}.attn_norm.weight",
        wq="blocks.{l}.attn.wq.weight",
        wk="blocks.{l}.attn.wk.weight",
        wv="blocks.{l}.attn.wv.weight",
        wo="blocks.{l}.attn.wo.weight",
        mlp_norm="blocks.{l}.mlp_norm.weight",
        w_gate="blocks.{l}.mlp.w_gate.weight",
        w_up="blocks.{l}.mlp.w_up.weight",
        w_down="blocks.{l}.mlp.w_down.weight",
        final_norm="final_norm.weight",
        lm_head=None,  # tied
    )
    a = Arch(tag="frugal-125m", layers=12, d=768, f=2048, heads=12,
             kv_heads=4, vocab=49152, eps=1e-5, rope_base=10000.0,
             tied=True, names=names)
    a.sliding_window = None
    return a


def make_arch(kind, ckpt):
    return arch_frugal() if kind == "frugal" else arch_hf(ckpt)


# --------------------------------------------------------------------------
# the numpy fp32 walk (streamed: one layer's weights in RAM at a time)
# --------------------------------------------------------------------------

def rmsnorm(x, w, eps):
    v = np.mean(np.square(x), axis=-1, keepdims=True)
    return (x / np.sqrt(v + eps)) * w


def rope_cache(t, head_dim, base):
    """cos/sin (t, head_dim) in the rotate-half convention (HF Llama /
    mlx traditional=False): inv_freq over the first half, duplicated."""
    inv = base ** (-np.arange(0, head_dim, 2, dtype=np.float64) / head_dim)
    ang = np.outer(np.arange(t, dtype=np.float64), inv)
    emb = np.concatenate([ang, ang], axis=-1)
    return (np.cos(emb).astype(np.float32),
            np.sin(emb).astype(np.float32))


def rope_apply(x, cos, sin):
    """x: (T, H, hd) -> rotated, rotate-half convention."""
    hd = x.shape[-1]
    h1, h2 = x[..., : hd // 2], x[..., hd // 2:]
    rot = np.concatenate([-h2, h1], axis=-1)
    return x * cos[:, None, :] + rot * sin[:, None, :]


class Walker:
    """Block-by-block reference forward. Activations fp32; per-layer
    weights loaded on demand and freed (streaming — the RSS contract).

    walk(tokens, ffn_override, collect):
      collect(l, dict(x, gate, up, a, h, z)) is called per layer with
      fp32 arrays the callee must REDUCE, not retain (RSS).
      ffn_override(l, xin(B,T,d) fp32, lw) -> z fp32 replaces the FFN
      (lw holds this layer's fp32 tensors incl. w_gate/w_up/w_down)."""

    def __init__(self, store, arch, t_max):
        self.store = store
        self.arch = arch
        self.cos, self.sin = rope_cache(t_max, arch.head_dim,
                                        arch.rope_base)
        if getattr(arch, "sliding_window", None):
            assert t_max <= arch.sliding_window, \
                "T exceeds the sliding window — plain causal invalid"

    def _n(self, key, l=None):
        s = self.arch.names[key]
        return s.format(l=l) if l is not None else s

    def load_layer(self, l):
        g = self.store.get
        return {k: g(self._n(k, l)) for k in
                ("attn_norm", "wq", "wk", "wv", "wo", "mlp_norm",
                 "w_gate", "w_up", "w_down")}

    def _attention(self, xn, lw):
        a = self.arch
        B, T, _ = xn.shape
        hd, H, Hk = a.head_dim, a.heads, a.kv_heads
        rep = H // Hk
        scale = hd ** -0.5
        flat = xn.reshape(B * T, -1)
        q = (flat @ lw["wq"].T).reshape(B, T, H, hd)
        k = (flat @ lw["wk"].T).reshape(B, T, Hk, hd)
        v = (flat @ lw["wv"].T).reshape(B, T, Hk, hd)
        cos, sin = self.cos[:T], self.sin[:T]
        mask = np.triu(np.full((T, T), -np.inf, dtype=np.float32), k=1)
        out = np.empty((B, T, H, hd), dtype=np.float32)
        for b in range(B):
            qb = rope_apply(q[b], cos, sin)
            kb = rope_apply(k[b], cos, sin)
            for h in range(H):
                s = (qb[:, h] @ kb[:, h // rep].T) * scale + mask
                s -= s.max(axis=-1, keepdims=True)
                e = np.exp(s)
                w = e / e.sum(axis=-1, keepdims=True)
                out[b, :, h] = w @ v[b, :, h // rep]
        return out.reshape(B * T, H * hd) @ lw["wo"].T

    def walk(self, tokens, ffn_override=None, collect=None):
        """tokens (B, T) -> final-norm hidden (B, T, d)."""
        a = self.arch
        B, T = tokens.shape
        emb = self.store.get(self._n("embed"))
        x = emb[tokens.reshape(-1)].reshape(B, T, a.d).astype(np.float32)
        del emb
        for l in range(a.n_layers):
            lw = self.load_layer(l)
            xn = rmsnorm(x, lw["attn_norm"], a.eps)
            x = x + self._attention(xn, lw).reshape(B, T, a.d)
            xin = rmsnorm(x, lw["mlp_norm"], a.eps)
            if ffn_override is not None:
                z = ffn_override(l, xin, lw)
            else:
                flat = xin.reshape(B * T, a.d)
                gate = flat @ lw["w_gate"].T
                up = flat @ lw["w_up"].T
                sa = gate / (1.0 + np.exp(-gate))   # SiLU
                h = sa * up
                z = (h @ lw["w_down"].T).reshape(B, T, a.d)
                if collect is not None:
                    collect(l, dict(x=xin, gate=gate, up=up, a=sa, h=h,
                                    z=z))
                del gate, up, sa, h
            x = x + z
            del lw
        fw = self.store.get(self._n("final_norm"))
        return rmsnorm(x, fw, a.eps)

    def loss(self, wins, ffn_override=None):
        """wins (B, T+1): mean next-token cross-entropy (m125 form:
        lse - picked, mean over positions). Head weights streamed once,
        logits per sequence (caps RAM at T x vocab fp32)."""
        a = self.arch
        hid = self.walk(wins[:, :-1], ffn_override=ffn_override)
        head = self.store.get(
            self._n("embed") if a.tied else self._n("lm_head"))
        tot, cnt = 0.0, 0
        for b in range(wins.shape[0]):
            logits = (hid[b] @ head.T).astype(np.float64)
            m = logits.max(axis=-1)
            lse = m + np.log(np.exp(logits - m[:, None]).sum(axis=-1))
            picked = logits[np.arange(logits.shape[0]), wins[b, 1:]]
            tot += float((lse - picked).sum())
            cnt += logits.shape[0]
        del head
        return tot / cnt


# --------------------------------------------------------------------------
# tokens: .npy stream, or text through the checkpoint's tokenizer
# --------------------------------------------------------------------------

def load_tokenizer(ckpt_dir):
    tj = Path(ckpt_dir) / "tokenizer.json"
    if tj.exists():
        try:
            from tokenizers import Tokenizer
            tok = Tokenizer.from_file(str(tj))
            return ("tokenizers", tok)
        except ImportError:
            pass
    tm = Path(ckpt_dir) / "tokenizer.model"
    if tm.exists():
        try:
            import sentencepiece as spm
            sp = spm.SentencePieceProcessor(model_file=str(tm))
            return ("sentencepiece", sp)
        except ImportError:
            pass
    raise SystemExit(
        "no usable tokenizer: need `tokenizers` (tokenizer.json) or "
        "`sentencepiece` (tokenizer.model) importable — pip install one")


def tok_encode(tk, text):
    kind, tok = tk
    if kind == "tokenizers":
        return np.asarray(tok.encode(text).ids, dtype=np.int64)
    return np.asarray(tok.encode(text), dtype=np.int64)


def tok_decode(tk, ids):
    kind, tok = tk
    if kind == "tokenizers":
        return tok.decode([int(i) for i in ids])
    return tok.decode([int(i) for i in ids])


def load_token_stream(args, ckpt_dir):
    if args.tokens:
        toks = np.load(args.tokens, mmap_mode="r")
        p("token stream: %s (%d tokens, %s)" % (args.tokens, len(toks),
                                                toks.dtype))
        return toks
    assert args.text, "need --tokens <npy> or --text <utf8 file>"
    tk = load_tokenizer(ckpt_dir)
    text = Path(args.text).read_text(encoding="utf-8")
    toks = tok_encode(tk, text)
    p("token stream: %s tokenized with %s -> %d tokens"
      % (args.text, tk[0], len(toks)))
    need = (args.cal_seqs + args.val_seqs) * (args.t + 1) * 2
    assert len(toks) >= need, (
        "text too small: %d tokens < %d needed for %d+%d disjoint "
        "windows of %d — feed a larger sample"
        % (len(toks), need, args.cal_seqs, args.val_seqs, args.t + 1))
    return toks


def token_batches(toks, seed, n_cal, n_val, t):
    """The m125 sampler VERBATIM (seed 1337 default): sorted disjoint
    aligned windows of t+1 tokens; first n_cal are calibration, the rest
    held-out."""
    rng = np.random.default_rng(seed)
    span = t + 1
    offs = np.sort(rng.choice((len(toks) - span) // span,
                              size=n_cal + n_val, replace=False)) * span
    wins = np.stack([np.asarray(toks[o:o + span], dtype=np.int64)
                     for o in offs])
    return wins[:n_cal], wins[n_cal:]


# --------------------------------------------------------------------------
# Section 1 — weights (streamed)
# --------------------------------------------------------------------------

def weight_study(store, arch, walker):
    p("=" * 78)
    p("SECTION 1 — FFN weight quantization (%d layers x w_gate/w_up/"
      "w_down), streamed" % arch.n_layers)
    p("   [semantics: per-tensor symmetric int8, power-of-two scale 2^e, "
      "e = ceil(log2(absmax/127))]")
    p("=" * 78)
    rows = []
    hdr = "%-7s %-7s %10s %10s %5s %9s %10s %10s" % (
        "layer", "tensor", "absmax", "rms", "e", "sat@e", "sat@e-1",
        "relRMS")
    p(hdr)
    for l in range(arch.n_layers):
        for name in ("w_gate", "w_up", "w_down"):
            W = store.get(walker._n(name, l)).astype(np.float64)
            absmax = float(np.abs(W).max())
            rms = float(np.sqrt((W ** 2).mean()))
            e = m125.pow2_exp_for(absmax)
            q, sat = m125.quantize(W, e)
            _, sat_tight = m125.quantize(W, e - 1)
            deq = q * (2.0 ** e)
            rel = float(np.sqrt(((W - deq) ** 2).mean()) / rms)
            rows.append(dict(layer=l, tensor=name, shape=list(W.shape),
                             absmax=absmax, rms=rms, exp=e, sat=sat,
                             sat_tighter=sat_tight, rel_rms_err=rel))
            p("%-7d %-7s %10.5f %10.5f %5d %9d %10d %10.5f"
              % (l, name, absmax, rms, e, sat, sat_tight, rel))
            del W, q, deq
    es = sorted(set(r["exp"] for r in rows))
    p("-> %d tensors quantized; exponent range [%d, %d]%s; worst "
      "per-tensor relative RMS error %.4f"
      % (len(rows), es[0], es[-1],
         " (UNIFORM %d — the m125 situation)" % es[0] if len(es) == 1
         else " (PER-TENSOR eW — unlike m125's uniform -9)",
         max(r["rel_rms_err"] for r in rows)))
    return rows


# --------------------------------------------------------------------------
# Section 2 — honest accumulator widths at this model's inner dims
# --------------------------------------------------------------------------

def accumulator_section(arch):
    p()
    p("=" * 78)
    p("SECTION 2 — honest accumulator widths (contract convention "
      "re-derivation)")
    p("=" * 78)
    p("convention check — the contract's OWN rows reproduce under "
      "symmetric [-127,127]:")
    for inner, want in ((4096, 27), (11008, 29)):
        m, bits = m125.acc_width(inner)
        assert bits == want, "contract convention reproduction failed"
        p("  inner %6d: max|acc| = %11d (2^%.2f) -> %d-bit signed "
          "(contract row %d) OK" % (inner, m, math.log2(m), bits, want))
    p("this model's rows (d = %d, f = %d):" % (arch.d, arch.f))
    out = {}
    for inner, where in ((arch.d, "gate/up matmuls (inner d)"),
                         (arch.f, "down matmul (inner f)")):
        m, bits = m125.acc_width(inner)
        out[str(inner)] = dict(max_abs_acc=m, signed_bits=bits)
        p("  inner %6d: max|acc| = %11d (2^%.2f) -> %d-bit signed  [%s]"
          % (inner, m, math.log2(m), bits, where))
    p("  (these are the statement's Gacc/Uacc/Dacc class widths — memo "
      "Section 2 W-4: the rig's 25/26-bit constants must become these)")
    return out


# --------------------------------------------------------------------------
# Section 3 — activation calibration (one streamed walk, stats reduced
# in place so nothing large is retained)
# --------------------------------------------------------------------------

def calibrate(walker, cal_wins, wrows, arch):
    p()
    p("=" * 78)
    p("SECTION 3 — activation calibration (batch: %d seq x %d tokens, "
      "seeded)" % (cal_wins.shape[0], cal_wins.shape[1] - 1))
    p("=" * 78)
    stats = {}

    def collect(li, d):
        stats[li] = {k: m125.stats_of(v) for k, v in d.items()}

    walker.walk(cal_wins[:, :-1], collect=collect)
    scales = []
    p("%-6s %8s %8s %8s %8s %8s %8s   %s" % (
        "layer", "eX", "eGate", "eUp", "eA", "eH", "eZ",
        "absmax(X/gate/z)"))
    for li in range(arch.n_layers):
        st = stats[li]
        e = {k: m125.pow2_exp_for(st[k]["absmax"]) for k in st}
        wl = {r["tensor"]: r for r in wrows if r["layer"] == li}
        scales.append(dict(layer=li, stats=st,
                           eX=e["x"], eGate=e["gate"], eUp=e["up"],
                           eA=e["a"], eH=e["h"], eZ=e["z"],
                           eWg=wl["w_gate"]["exp"],
                           eWu=wl["w_up"]["exp"],
                           eWd=wl["w_down"]["exp"]))
        p("%-6d %8d %8d %8d %8d %8d %8d   %.3f / %.3f / %.3f"
          % (li, e["x"], e["gate"], e["up"], e["a"], e["h"], e["z"],
             st["x"]["absmax"], st["gate"]["absmax"], st["z"]["absmax"]))
    return scales


# --------------------------------------------------------------------------
# the SiLU tables: the FROZEN v2 family formula (round_half_up)
# --------------------------------------------------------------------------

def silu_members(scales):
    """Distinct (eGate, eA) pairs -> {pair: (table, digest, frozen?)}.
    New members are W-6 (a freeze ruling), not an error here."""
    out = {}
    for sc in scales:
        key = (sc["eGate"], sc["eA"])
        if key in out:
            continue
        t = m125x.silu_v2_generate(*key)
        dg = m125x.silu_v2_digest(key[0], key[1], t)
        frozen = m125x.SILU_V2_PINS.get(key) == dg
        out[key] = (t, dg, frozen)
    return out


def report_members(members):
    fresh = [(k, dg) for k, (t, dg, fr) in members.items() if not fr]
    for k, (t, dg, fr) in members.items():
        p("  silu-int8-table-v2 member (eGate %d, eA %d): digest %s… %s"
          % (k[0], k[1], dg[:16],
             "= frozen pin" if fr else "** NOT IN THE FROZEN FAMILY — "
             "memo W-6: a manifest.rs freeze ruling is needed **"))
    return fresh


# --------------------------------------------------------------------------
# Section 4 — the int8 chain (exact contract semantics) on held-out data
# --------------------------------------------------------------------------

def make_int8_ffn(scales, members, acc_track, viol_track, err_track,
                  mode="floor"):
    """ffn_override(li, x, lw): the contract chain per sequence, exact
    integers in float64 BLAS (all values integers << 2^53 — exact)."""

    def ffn(li, x, lw):
        sc = scales[li]
        B, T, C = x.shape
        tab = members[(sc["eGate"], sc["eA"])][0].astype(np.float64)
        # per-tensor int8 weights at the calibrated exponents
        Wq = {}
        for name, ekey in (("w_gate", "eWg"), ("w_up", "eWu"),
                           ("w_down", "eWd")):
            q, _ = m125.quantize(lw[name].astype(np.float64), sc[ekey])
            Wq[name] = q  # float64-carried exact int8 values
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
        # matched-input error: the fp FFN on the SAME x (fp32 reference)
        flat = x.reshape(B * T, C)
        gate = flat @ lw["w_gate"].T
        zf = ((gate / (1.0 + np.exp(-gate)) * (flat @ lw["w_up"].T))
              @ lw["w_down"].T).astype(np.float64)
        zq = z_out.reshape(B * T, -1).astype(np.float64)
        num = float(np.sqrt(((zf - zq) ** 2).mean()))
        den = float(np.sqrt((zf ** 2).mean()))
        err_track[li].append(num / den if den else 0.0)
        return z_out

    return ffn


def make_wonly_ffn(scales):
    """Weights-only attribution: dequantized per-tensor int8 weights, fp
    activations."""

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
        z = ((gate / (1.0 + np.exp(-gate)) * (flat @ dq["w_up"].T))
             @ dq["w_down"].T)
        return z.astype(np.float32).reshape(B, T, C)

    return ffn


def run_variant(walker, scales, members, val_wins, mode, label, arch,
                verbose=False):
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

def greedy_decode(walker, store, arch, ckpt_dir, prompt, arch_kind,
                  n_new=8):
    tk = load_tokenizer(ckpt_dir)
    ids = list(tok_encode(tk, prompt))
    # Mistral/Llama: prepend BOS (id 1) if the encoder did not
    if arch_kind == "hf" and ids and ids[0] != 1:
        ids = [1] + ids
    p("greedy decode (functional self-check of the forward):")
    p("  prompt: %r" % prompt)
    for _ in range(n_new):
        toks = np.asarray(ids, dtype=np.int64)[None, :]
        hid = walker.walk(toks)
        head = store.get(walker._n("embed") if arch.tied
                         else walker._n("lm_head"))
        logits = hid[0, -1] @ head.T
        del head
        ids.append(int(np.argmax(logits)))
    p("  completion: %r" % tok_decode(tk, ids))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ckpt", default=None,
                    help="checkpoint dir (or single .safetensors file)")
    ap.add_argument("--arch", default="hf", choices=("hf", "frugal"))
    ap.add_argument("--tokens", default=None, help="pre-tokenized .npy")
    ap.add_argument("--text", default=None, help="utf-8 text file")
    ap.add_argument("--t", type=int, default=512)
    ap.add_argument("--cal-seqs", type=int, default=8)
    ap.add_argument("--val-seqs", type=int, default=8)
    ap.add_argument("--seed", type=int, default=1337)
    ap.add_argument("--max-layers", type=int, default=None,
                    help="truncate the stack (SMOKE ONLY — results are "
                         "not the model's)")
    ap.add_argument("--out-json",
                    default=str(ROOT / "results" /
                                "m8b_int8_calibration.json"))
    ap.add_argument("--variants", action="store_true",
                    help="also run variant B (round-to-nearest requant)")
    ap.add_argument("--decode", default=None,
                    help="greedy-decode this prompt and exit (forward "
                         "sanity)")
    args = ap.parse_args()
    assert args.ckpt, "--ckpt is required"

    arch = make_arch(args.arch, args.ckpt)
    if args.max_layers:
        arch.n_layers = min(arch.n_layers, args.max_layers)
    store = TensorStore(args.ckpt)
    walker = Walker(store, arch, args.t)
    p("m8b_int8_calibration — %s (%d layers, d %d, f %d, heads %d/%d, "
      "vocab %d), TARGET_CONTRACT S2 semantics"
      % (arch.tag, arch.n_layers, arch.d, arch.f, arch.heads,
         arch.kv_heads, arch.vocab))
    p("checkpoint: %s (READ-ONLY, streamed per tensor)" % args.ckpt)
    if args.max_layers:
        p("** TRUNCATED to %d layers — SMOKE RUN, results are not the "
          "model's **" % arch.n_layers)

    if args.decode:
        greedy_decode(walker, store, arch, args.ckpt, args.decode,
                      args.arch)
        p("peak RSS %.2f GB" % rss_gb())
        return

    report = {"checkpoint": str(args.ckpt), "arch": args.arch,
              "model_tag": arch.tag, "seed": args.seed,
              "dims": dict(layers=arch.n_layers, d=arch.d, f=arch.f,
                           t=args.t),
              "truncated": bool(args.max_layers),
              "semantics": "TARGET_CONTRACT.md Section 2: int8 symmetric "
                           "[-127,127], power-of-two scales, floor "
                           "requant x = 2^shift*y + r, r in [0, 2^shift);"
                           " SiLU via the FROZEN v2 family formula"}

    wrows = weight_study(store, arch, walker)
    report["weights"] = wrows
    report["accumulators"] = accumulator_section(arch)

    toks = load_token_stream(args, args.ckpt)
    cal, val = token_batches(toks, args.seed, args.cal_seqs,
                             args.val_seqs, args.t)
    scales = calibrate(walker, cal, wrows, arch)
    report["calibration"] = scales

    members = silu_members(scales)
    p()
    fresh = report_members(members)
    report["silu_members"] = {
        "%d,%d" % k: dict(digest=dg, frozen=fr)
        for k, (t, dg, fr) in members.items()}

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
    p("VERDICT")
    p("=" * 78)
    calibrates = (A["total_viol"] == 0)
    p("range facts on held-out data: %s (%d violations, variant A)"
      % ("HOLD" if calibrates else "FAIL", A["total_viol"]))
    if fresh:
        p("SiLU family: %d NEW member(s) %s — memo W-6 ruling needed "
          "before the rig accepts this statement"
          % (len(fresh), [k for k, _ in fresh]))
    else:
        p("SiLU family: every calibrated member is already frozen")
    p("verdict: the checkpoint %s in the FORMAL sense at the calibrated "
      "per-tensor power-of-two scales; quality cost of the as-written "
      "chain %+.4f nats (A); weights-only %+.4f"
      % ("CALIBRATES" if calibrates else "DOES NOT CALIBRATE",
         A["loss"] - loss_ref, loss_wonly - loss_ref))
    report["verdict"] = dict(
        calibrates_formally=calibrates,
        range_violations=dict(A=A["total_viol"]),
        silu_new_members=["%d,%d" % k for k, _ in fresh],
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

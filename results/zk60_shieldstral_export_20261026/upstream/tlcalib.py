#!/usr/bin/env python3
"""Lane B: TinyLlama-1.1B full-block integer calibration + bit-exact reference.

Three parts, all numpy:

1. A float32 reference of the Llama block (HF LlamaForCausalLM semantics:
   RMSNorm, GQA 32q/4kv, half-split RoPE theta 1e4, causal softmax, SiLU FFN).
2. An EXACT integer block with the relations of the native private block
   (`hashline/src/private_block/witness.rs`, shaped form in
   `~/wt-zk60-block125m/.../witness.rs`, reference kernel
   `private-block-kernel-shaped::run_shaped`): round-mode RMSNorm with isqrt,
   round-half-up requantization by arithmetic shift, integer RoPE, int8
   scores, masked max + exp table + integer quotient softmax, PV, O, exact
   residual adds, SiLU table FFN. Every calibration constant is a PARAMETER
   here (the native crates hard-code the toy values; see DESIGN.md).
   Integer matmuls run as float64 BLAS products of integer-valued operands;
   they are exact because every partial sum is an integer below 2^53
   (asserted per call from the operand bounds), and `selfcheck_exact_mm`
   cross-checks against a pure int64 product.
3. A per-layer calibration solver producing int8 weights (native
   orientations), integer shifts / norm constants and exp / SiLU / RoPE
   tables.

Range violations are never clamped silently: every site is checked, counted
and attributed to a sequence (the native kernel would REFUSE that input).
For diagnostics only, the evaluation may continue past a violation with a
clamped value; such results are labelled and never count as native output.
"""

from __future__ import annotations

import os

for _k in ("OPENBLAS_NUM_THREADS", "OMP_NUM_THREADS", "MKL_NUM_THREADS", "NUMEXPR_NUM_THREADS"):
    os.environ.setdefault(_k, "2")

import hashlib
import json
import math
import sys
from dataclasses import dataclass, field, asdict
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
IMPORTER_DIR = REPO / "results" / "zk60_1b_checkpoint_20260927"
# Model selection (lane B5): ZK60_MODEL=llama3-8b before import switches the
# checkpoint, the geometry GEO and the shard pins; default = TinyLlama (B/B2/B3/B4).
MODEL_NAME = os.environ.get("ZK60_MODEL", "tinyllama")
MODEL_DIR = Path("/home/victor/models/tinyllama-1.1b-chat-fe8a4ea1")
MODEL_SHA256 = "6e6001da2106d4757498752a021df6c2bdc332c650aae4bae6b0c004dcf14933"
MODEL_SHARDS = {"model.safetensors": MODEL_SHA256}
if MODEL_NAME == "llama3-8b":
    MODEL_DIR = REPO / "local-models" / "zk60-llama3-8b"
    MODEL_SHARDS = {
        "model-00001-of-00004.safetensors": "f2c144103072514542e327fa8080bd375cb300f2d453fba9ca3aea81d0d4cf33",
        "model-00002-of-00004.safetensors": "d9eee5f23d94405d90b7e9ff88b9443fee42f8528a658f54214c2aba7530d80c",
        "model-00003-of-00004.safetensors": "4b8fbc5e113f69768dd8de84661ea20af8a32b734a9976144b4236c447b40ccc",
        "model-00004-of-00004.safetensors": "5dc34e6bdf2da9e35f0d93b5c333c870f3677dc43dc3a91ea3a8ad28a1fe1acb"}
elif MODEL_NAME != "tinyllama":
    raise ValueError(f"unknown ZK60_MODEL {MODEL_NAME}")
sys.path.insert(0, str(IMPORTER_DIR))
import importer_zk60_1b_checkpoint as importer  # noqa: E402

TWO53 = 1 << 53
I16 = (-32768, 32767)
I8N = (-127, 127)
I8 = (-128, 127)


class Native:
    """The native toy calibration (layout.rs / kernel-shaped `calib`)."""
    NORM_TN = 11
    NORM_CN = 1024
    NORM_CEPS = 1
    SH_QKV = 7
    SH_ROPE = 7
    SH_S = 6
    SH_O = 9
    SH_AO = 7
    SH_G = 7
    SH_U = 0
    SH_H = 14
    SH_Z = 6
    F_E = 9
    F_P = 9
    F_RO = 7
    MASK = -127


# Shift windows that keep the native PLANE LIST unchanged: a remainder of a
# site with one byte limb (plus a `scaled(.., 2^(8-sh))` lookup) holds
# sh <= 8; the two sites with two limbs (O: A_RO0/A_RO1, product: A_RH0/A_RH1)
# hold 9..16 (layout.rs lookup lists, argument.rs host relations).
SHIFT_WINDOW = {"qkv": (1, 8), "rope": (1, 8), "s": (1, 8), "o": (9, 16), "ao": (1, 8),
                "g": (1, 8), "h": (9, 16), "z": (1, 8)}
if os.environ.get("ZK60_MODEL", "tinyllama") == "llama3-8b":
    SHIFT_WINDOW["ao"] = (0, 8)      # D24 accepted windows for the 8B profile: ao 0..8


# ------------------------------------------------------------------ checkpoint

def open_checkpoint():
    return importer.Checkpoint(MODEL_DIR, expected_shards=MODEL_SHARDS)


def tensor_f32(ref, max_bytes: int | None = None) -> np.ndarray:
    raw = ref.read_bytes() if max_bytes is None else ref.read_bytes(max_bytes=max_bytes)
    u = np.frombuffer(raw, dtype="<u2").astype(np.uint32) << 16
    return u.view(np.float32).reshape(ref.shape)


def layer_f32(ck, layer: int) -> dict:
    return {k: tensor_f32(v) for k, v in sorted(ck.layer(layer).items())}


@dataclass(frozen=True)
class Geo:
    d: int = 2048
    f: int = 5632
    H: int = 32
    KV: int = 4
    dh: int = 64
    eps: float = 1e-5
    theta: float = 10000.0

    @property
    def G(self):
        return self.H // self.KV

    @property
    def half(self):
        return self.dh // 2

    @property
    def kvw(self):
        return self.KV * self.dh


GEO = Geo() if MODEL_NAME == "tinyllama" else Geo(d=4096, f=14336, H=32, KV=8, dh=128, eps=1e-5, theta=500000.0)


# ------------------------------------------------------------------ float reference

def rope_f32(T: int, g: Geo = GEO):
    inv = (1.0 / (np.float32(g.theta) ** (np.arange(0, g.dh, 2, dtype=np.int64).astype(np.float32) / np.float32(g.dh)))).astype(np.float32)
    freqs = np.arange(T, dtype=np.float32)[:, None] * inv[None, :]
    return np.cos(freqs).astype(np.float32), np.sin(freqs).astype(np.float32)


def f_xhat(x: np.ndarray, eps: float) -> np.ndarray:
    var = np.mean(x * x, axis=-1, keepdims=True, dtype=np.float32)
    return (x / np.sqrt(var + np.float32(eps))).astype(np.float32)


def f_rope(x: np.ndarray, cos: np.ndarray, sin: np.ndarray) -> np.ndarray:
    half = x.shape[-1] // 2
    a, b = x[..., :half], x[..., half:]
    c, s = cos[None, :, None, :], sin[None, :, None, :]
    return np.concatenate([a * c - b * s, b * c + a * s], axis=-1)


def _upd(st: dict, key: str, val):
    if key in st:
        st[key] = np.maximum(st[key], val)
    else:
        st[key] = val


def f_block(x: np.ndarray, W: dict, cos, sin, st: dict | None = None, g: Geo = GEO) -> np.ndarray:
    """One float32 Llama block on (N, T, d). Optionally accumulates the maxima
    the calibration needs into `st` (running max over batches)."""
    N, T, d = x.shape
    xa = f_xhat(x, g.eps)
    h = xa * W["input_layernorm.weight"]
    q = (h @ W["self_attn.q_proj.weight"].T).reshape(N, T, g.H, g.dh)
    k = (h @ W["self_attn.k_proj.weight"].T).reshape(N, T, g.KV, g.dh)
    v = (h @ W["self_attn.v_proj.weight"].T).reshape(N, T, g.KV, g.dh)
    qr, kr = f_rope(q, cos, sin), f_rope(k, cos, sin)
    qg = qr.reshape(N, T, g.KV, g.G, g.dh).transpose(0, 2, 3, 1, 4)  # (N,KV,G,T,dh)
    kg = kr.transpose(0, 2, 3, 1)[:, :, None]                          # (N,KV,1,dh,T)
    raw = qg @ kg                                                      # (N,KV,G,T,T) = q.k
    tri = np.tril(np.ones((T, T), dtype=bool))
    logits = np.where(tri, raw / np.float32(math.sqrt(g.dh)), -np.inf).astype(np.float32)
    logits -= logits.max(-1, keepdims=True)
    p = np.exp(logits)
    p /= p.sum(-1, keepdims=True)
    vg = v.transpose(0, 2, 1, 3)[:, :, None]                           # (N,KV,1,T,dh)
    o5 = p @ vg                                                        # (N,KV,G,T,dh)
    o = o5.transpose(0, 3, 1, 2, 4).reshape(N, T, d)
    ao = o @ W["self_attn.o_proj.weight"].T
    x1 = x + ao
    xm = f_xhat(x1, g.eps)
    hm = xm * W["post_attention_layernorm.weight"]
    gt = hm @ W["mlp.gate_proj.weight"].T
    up = hm @ W["mlp.up_proj.weight"].T
    act = gt / (1.0 + np.exp(-gt))
    hh = act * up
    z = hh @ W["mlp.down_proj.weight"].T
    x2 = x1 + z
    if st is not None:
        amax = lambda a: float(np.abs(a).max())
        _upd(st, "xhat_a_ch", np.abs(xa).reshape(-1, d).max(0))
        _upd(st, "xhat_m_ch", np.abs(xm).reshape(-1, d).max(0))
        pair = lambda t: float(np.sqrt(t[..., :g.half] ** 2 + t[..., g.half:] ** 2).max())
        for key, val in (("x", amax(x)), ("x1", amax(x1)), ("x2", amax(x2)), ("ao", amax(ao)), ("z", amax(z)),
                         ("q_pair", pair(q)), ("k_pair", pair(k)), ("v", amax(v)), ("q", amax(q)), ("k", amax(k)),
                         ("qr", amax(qr)), ("kr", amax(kr)), ("raw_all", amax(raw)),
                         ("raw_causal", float(np.abs(np.where(tri, raw, 0)).max())),
                         ("o", amax(o)), ("gate", amax(gt)), ("up", amax(up)), ("h", amax(hh))):
            _upd(st, key, val)
    return x2


def f_head(x: np.ndarray, norm_w: np.ndarray, lm_head: np.ndarray, eps: float = GEO.eps) -> np.ndarray:
    return (f_xhat(x, eps) * norm_w) @ lm_head.T


# ------------------------------------------------------------------ exact integer primitives

def requant(acc: np.ndarray, sh: int) -> np.ndarray:
    """round to nearest, ties toward +inf: floor((acc + 2^(sh-1)) / 2^sh); sh = 0 is the identity."""
    if sh == 0:
        return acc.copy()
    if sh < 0:
        raise ValueError("negative shifts are not used by the native witness (u32 shifts)")
    return (acc + (1 << (sh - 1))) >> sh


def isqrt_vec(v: np.ndarray) -> np.ndarray:
    if np.any(v < 0) or np.any(v >= (1 << 62)):
        raise ValueError("isqrt domain")
    r = np.floor(np.sqrt(v.astype(np.float64))).astype(np.int64)
    for _ in range(4):
        r = r - (r * r > v)
        r = r + ((r + 1) * (r + 1) <= v)
    if not (np.all(r * r <= v) and np.all((r + 1) * (r + 1) > v)):
        raise AssertionError("isqrt fix-up did not converge")
    return r


class ExactMat:
    """A public int8 matrix prepared for exact products `x @ M` with x integer
    (float64 BLAS; every partial sum below 2^53, asserted). Large matrices
    (> 16M words, the 8B FFN) stay int8 and are converted in column blocks."""

    BLOCKED_ABOVE = 16 * 1024 * 1024
    BLOCK = 2048

    def __init__(self, m_in_out: np.ndarray):
        self.wmax = int(np.abs(m_in_out.astype(np.int64)).max()) if m_in_out.size else 0
        self.inner = m_in_out.shape[0]
        self.blocked = m_in_out.size > self.BLOCKED_ABOVE
        self.m = np.ascontiguousarray(m_in_out) if self.blocked else m_in_out.astype(np.float64)

    def __call__(self, x: np.ndarray) -> np.ndarray:
        xmax = int(np.abs(x).max()) if x.size else 0
        if xmax * self.wmax * self.inner >= TWO53:
            raise OverflowError("exact float64 product bound exceeded")
        xf = x.astype(np.float64)
        if not self.blocked:
            return (xf @ self.m).astype(np.int64)
        out = np.empty(x.shape[:-1] + (self.m.shape[1],), dtype=np.int64)
        for c0 in range(0, self.m.shape[1], self.BLOCK):
            out[..., c0:c0 + self.BLOCK] = (xf @ self.m[:, c0:c0 + self.BLOCK].astype(np.float64)).astype(np.int64)
        return out


def exact_bmm(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    """Batched exact integer matmul via float64 (operands integer valued)."""
    amax = int(np.abs(a).max()) if a.size else 0
    bmax = int(np.abs(b).max()) if b.size else 0
    if amax * bmax * a.shape[-1] >= TWO53:
        raise OverflowError("exact float64 batched product bound exceeded")
    return (a.astype(np.float64) @ b.astype(np.float64)).astype(np.int64)


def selfcheck_exact_mm(seed: int = 7) -> dict:
    rng = np.random.default_rng(seed)
    out = {}
    for name, (lo, hi, inner) in {"int8xint8 d2048": (-127, 128, 2048), "int16xint8 f5632": (-32768, 32768, 5632)}.items():
        x = rng.integers(lo, hi, size=(8, inner), dtype=np.int64)
        w = rng.integers(-127, 128, size=(inner, 96), dtype=np.int64)
        ref = x @ w  # numpy int64 matmul (no BLAS): exact
        got = ExactMat(w.astype(np.int8))(x)
        out[name] = bool(np.array_equal(ref, got))
    return out


# ------------------------------------------------------------------ range bookkeeping

KERNEL_ORDER = ["norm_a denominator", "norm_a quotient/remainder", "Q", "K", "V", "QR", "KR", "score",
                "exp difference", "softmax denominator", "softmax quotient/remainder", "O", "AO", "residual 1",
                "norm_m denominator", "norm_m quotient/remainder", "FFN gate", "FFN up", "FFN product",
                "FFN down", "residual 2"]


class Rec:
    """Per-site range bookkeeping for one integer run over N sequences."""

    def __init__(self, n_seq: int):
        self.n = n_seq
        self.sites: dict[str, dict] = {}
        self.first: list[str | None] = [None] * n_seq

    def check(self, site: str, val: np.ndarray, lo: int, hi: int, seq0: int, clamp: bool = True,
              extra_bad: np.ndarray | None = None) -> np.ndarray:
        """Count values outside [lo, hi] (plus `extra_bad`, a same-shape mask
        of other violations the kernel names with this site)."""
        bad = (val < lo) | (val > hi)
        if extra_bad is not None:
            bad = bad | extra_bad
        s = self.sites.setdefault(site, {"violations": 0, "elements": 0, "max": -(1 << 62), "min": 1 << 62,
                                         "lo": lo, "hi": hi, "seqs_refused": 0})
        nb = int(bad.sum())
        s["violations"] += nb
        s["elements"] += int(val.size)
        if val.size:
            s["max"] = max(s["max"], int(val.max()))
            s["min"] = min(s["min"], int(val.min()))
        if nb:
            per = bad.reshape(bad.shape[0], -1).any(1)
            for i in np.nonzero(per)[0]:
                s["seqs_refused"] += 1
                if self.first[seq0 + int(i)] is None:
                    self.first[seq0 + int(i)] = site
            if clamp:
                return np.clip(val, lo, hi)
        return val

    def summary(self) -> dict:
        out = {}
        for site in KERNEL_ORDER:
            if site not in self.sites:
                continue
            s = self.sites[site]
            head = max(s["max"] / s["hi"] if s["hi"] > 0 else 0.0, s["min"] / s["lo"] if s["lo"] < 0 else 0.0)
            out[site] = {"violations": s["violations"], "elements": s["elements"], "min": s["min"], "max": s["max"],
                         "lo": s["lo"], "hi": s["hi"], "fill": round(head, 4), "seqs_refused": s["seqs_refused"]}
        n_ref = sum(1 for f in self.first if f is not None)
        return {"sites": out, "sequences": self.n, "sequences_refused": n_ref,
                "first_refusal_sites": sorted({f for f in self.first if f})}


# ------------------------------------------------------------------ the integer block

@dataclass
class LayerInt:
    """Every public integer word of one calibrated block (unpadded native
    orientations: attention (output, input), FFN (input, output))."""
    wq: np.ndarray
    wk: np.ndarray
    wv: np.ndarray
    wo: np.ndarray
    gamma_a: np.ndarray
    gamma_m: np.ndarray
    wg_t: np.ndarray
    wu_t: np.ndarray
    wd_t: np.ndarray
    exp: np.ndarray       # int64[256]
    act: np.ndarray       # int16[256]
    cn_a: int
    cn_m: int
    tn: int
    ceps: int
    norm_wrho: int
    sh_qkv: int
    sh_rope: int
    sh_s: int
    sh_o: int
    sh_ao: int
    sh_g: int
    sh_u: int
    sh_h: int
    sh_z: int
    f_e: int
    f_p: int
    f_ro: int
    # residual-2 rescale k: x2 = requant(x1 + (z16 << k), k) — the general
    # form of private-block-kernel-shaped (SH_X2 = 0, SH_Z2 = SH_R2 = k).
    # The native witness pins k = 0 ("all three shifts are 0").
    sh_r2: int = 0
    _mats: dict = field(default_factory=dict, repr=False)

    def mats(self):
        if not self._mats:
            self._mats = {"q": ExactMat(self.wq.T), "k": ExactMat(self.wk.T), "v": ExactMat(self.wv.T),
                          "o": ExactMat(self.wo.T), "g": ExactMat(self.wg_t), "u": ExactMat(self.wu_t),
                          "d": ExactMat(self.wd_t)}
        return self._mats

    def constants(self) -> dict:
        return {k: int(getattr(self, k)) for k in ("cn_a", "cn_m", "tn", "ceps", "norm_wrho", "sh_qkv", "sh_rope",
                                                   "sh_s", "sh_o", "sh_ao", "sh_g", "sh_u", "sh_h", "sh_z",
                                                   "f_e", "f_p", "f_ro", "sh_r2")}


def norm_window(width: int, tn: int) -> int:
    """tn + 1 + bits(isqrt(1 + width * 32768^2)) — the int16 class includes
    -32768 (contract review 2026-09-30). Equals the 32767 form at width 2048
    (21 bits either way); at width 4096 it is 22 bits (D_max = 2^21)."""
    dmax = math.isqrt(1 + width * 32768 * 32768)
    return tn + 1 + dmax.bit_length()


def i_norm(x, g8, cn, tn, ceps, wrho, rec: Rec, site: str, seq0: int, clamp: bool):
    ss = ceps + (x * x).sum(-1)
    D = isqrt_vec(ss)
    a1 = ss - D * D
    a2 = 2 * D - a1
    abad = (a1 < 0) | (a1 >= (1 << 24)) | (a2 < 0) | (a2 >= (1 << 24))
    rec.check(f"{site} denominator", D, 1, (1 << 24) - 1, seq0, clamp=False, extra_bad=abad)
    D = np.maximum(D, 1)
    dv = D << tn
    den = (2 * dv)[..., None]
    num = 2 * x * g8.astype(np.int64)[None, None, :] * cn + dv[..., None]
    q = num // den            # floor division == div_euclid for den > 0
    rho = num - q * den       # == rem_euclid
    sigma = den - 1 - rho
    win = (rho >= (1 << wrho)) | (sigma >= (1 << wrho))
    q = rec.check(f"{site} quotient/remainder", q, -127, 127, seq0, clamp=clamp, extra_bad=win)
    return q, D


def rope_tables_int(T: int, dh: int, theta: float, f_ro: int):
    """tables_attn::rope_tables_generate: c = round_half_up(cos(t base^(-2i/dh)) 2^f_ro)."""
    half = dh // 2
    scale = float(2 ** f_ro)
    c = np.zeros((T, half), dtype=np.int64)
    s = np.zeros((T, half), dtype=np.int64)
    for i in range(half):
        th = theta ** (-2.0 * i / dh)
        for t in range(T):
            a = t * th
            c[t, i] = math.floor(math.cos(a) * scale + 0.5)
            s[t, i] = math.floor(math.sin(a) * scale + 0.5)
    return c, s


def exp_table(lam: float, f_e: int) -> np.ndarray:
    """E[d] = round_half_up(2^f_e exp(-d lam)), the exp-neg-table-v1 rounding
    with a calibrated decay `lam` (the registry's lam is 2^e_s / sqrt(dh))."""
    e = np.array([math.floor((2 ** f_e) * math.exp(-dd * lam) + 0.5) for dd in range(256)], dtype=np.int64)
    assert e[0] == 1 << f_e and np.all(np.diff(e) <= 0) and e.min() >= 0
    return e


def silu_table(s_in: float, s_out: float) -> np.ndarray:
    """int16out rule: clamp(round_half_up(silu(g s_in) / s_out), -32767, 32767), g = i - 128."""
    out = np.zeros(256, dtype=np.int64)
    for i in range(256):
        x = (i - 128) * s_in
        y = x / (1.0 + math.exp(-x))
        out[i] = min(32767, max(-32767, math.floor(y / s_out + 0.5)))
    return out.astype(np.int16)


def rope_int(x: np.ndarray, c: np.ndarray, s: np.ndarray) -> np.ndarray:
    half = x.shape[-1] // 2
    a, b = x[..., :half], x[..., half:]
    cc, ss = c[None, :, None, :], s[None, :, None, :]
    return np.concatenate([cc * a - ss * b, ss * a + cc * b], axis=-1)


def i_block(x: np.ndarray, P: LayerInt, rope: tuple, rec: Rec, seq0: int = 0, clamp: bool = True,
            trace: dict | None = None, g: Geo = GEO) -> np.ndarray:
    """The native block relations at calibrated constants on int16 input (N, T, d)."""
    N, T, d = x.shape
    M = P.mats()
    c_ro, s_ro = rope
    y, _ = i_norm(x, P.gamma_a, P.cn_a, P.tn, P.ceps, P.norm_wrho, rec, "norm_a", seq0, clamp)
    q = rec.check("Q", requant(M["q"](y), P.sh_qkv), *I8N, seq0, clamp)
    k = rec.check("K", requant(M["k"](y), P.sh_qkv), *I8N, seq0, clamp)
    v = rec.check("V", requant(M["v"](y), P.sh_qkv), *I8N, seq0, clamp)
    qr = rec.check("QR", requant(rope_int(q.reshape(N, T, g.H, g.dh), c_ro, s_ro), P.sh_rope), *I8N, seq0, clamp)
    kr = rec.check("KR", requant(rope_int(k.reshape(N, T, g.KV, g.dh), c_ro, s_ro), P.sh_rope), *I8N, seq0, clamp)
    qg = qr.reshape(N, T, g.KV, g.G, g.dh).transpose(0, 2, 3, 1, 4)
    kg = kr.transpose(0, 2, 3, 1)[:, :, None]
    sacc = exact_bmm(qg, kg)                                       # (N,KV,G,T,T), all (t, j)
    s16 = getattr(P, "s16", False)      # B5 experiment hook (NOT native): int16 score class
    s8 = rec.check("score", requant(sacc, P.sh_s), *((-32767, 32767) if s16 else I8N), seq0, clamp)
    tri = np.tril(np.ones((T, T), dtype=bool))
    masked = np.where(tri, s8, -32767 if s16 else Native.MASK)
    best = masked.max(-1, keepdims=True)
    delta = rec.check("exp difference", best - masked, 0, P.exp.shape[-1] - 1, seq0, clamp)
    if P.exp.ndim == 2:     # B6 experiment hook (NOT native): one exp table per query head
        ex = P.exp.reshape(g.KV, g.G, -1)
        E = ex[np.arange(g.KV)[None, :, None, None, None], np.arange(g.G)[None, None, :, None, None], delta]
    else:
        E = P.exp[delta]
    total = np.where(tri, E, 0).sum(-1, keepdims=True)
    total = rec.check("softmax denominator", total, 1 << P.f_e, T << P.f_e, seq0, clamp)
    num = E << P.f_p
    p = np.where(tri, num // total, 0)
    rho = np.where(tri, num - (num // total) * total, 0)
    sigma = total - 1 - rho
    wrho_s = (T - 1).bit_length() + P.f_e  # clog2(T) + f_e
    p = rec.check("softmax quotient/remainder", p, 0, 1 << P.f_p, seq0, clamp=clamp,
                  extra_bad=(sigma < 0) | (sigma >= (1 << wrho_s)))
    vg = v.reshape(N, T, g.KV, g.dh).transpose(0, 2, 1, 3)[:, :, None]
    oacc = exact_bmm(p, vg)                                        # (N,KV,G,T,dh)
    # B4-3 experiment hook: getattr(P, "o_class16") puts o in the int16 class
    # (NOT a native relation; absent = the native int8 subset)
    o = rec.check("O", requant(oacc, P.sh_o), *(I16 if getattr(P, "o_class16", False) else I8N), seq0, clamp)
    o8 = o.transpose(0, 3, 1, 2, 4).reshape(N, T, d)
    ao = rec.check("AO", requant(M["o"](o8), P.sh_ao), *I16, seq0, clamp)
    x1 = rec.check("residual 1", x + ao, *I16, seq0, clamp)
    nm, _ = i_norm(x1, P.gamma_m, P.cn_m, P.tn, P.ceps, P.norm_wrho, rec, "norm_m", seq0, clamp)
    g8 = rec.check("FFN gate", requant(M["g"](nm), P.sh_g), *I8, seq0, clamp)
    u16 = rec.check("FFN up", requant(M["u"](nm), P.sh_u), *I16, seq0, clamp)
    a16 = P.act.astype(np.int64)[g8 + 128]
    h16 = rec.check("FFN product", requant(a16 * u16, P.sh_h), *I16, seq0, clamp)
    z16 = rec.check("FFN down", requant(M["d"](h16), P.sh_z), *I16, seq0, clamp)
    if P.sh_r2:
        x2 = rec.check("residual 2", requant(x1 + (z16 << P.sh_r2), P.sh_r2), *I16, seq0, clamp)
    else:
        x2 = rec.check("residual 2", x1 + z16, *I16, seq0, clamp)
    if trace is not None:
        trace.update({"y": y, "q": q, "k": k, "v": v, "qr": qr, "kr": kr, "s8": s8, "p": p, "o8": o8, "ao": ao,
                      "x1": x1, "nm": nm, "g8": g8, "u16": u16, "a16": a16, "h16": h16, "z16": z16, "x2": x2})
    return x2


# ------------------------------------------------------------------ calibration solver

@dataclass
class CalibOptions:
    margin: float = 0.25            # headroom factor over the calibration maxima
    smooth_alpha: float | None = None  # None: native gamma in the norm; else SmoothQuant alpha folded into gamma
    norm: str = "calibrated"        # "calibrated": per-site Cn, tn below, Ceps from eps; "native": Cn 1024, tn 11, Ceps 1
    tn: int = 10                    # calibrated tn (10 keeps the 4-limb norm window at width 2048)
    shifts: str = "free"            # "free": per-layer, structure-preserving windows; "native": toy shifts
    f_e: int = 9
    f_p: int = Native.F_P
    f_ro: int = Native.F_RO


def qw(w: np.ndarray, s: float, rep: dict | None = None, name: str = "") -> np.ndarray:
    q = np.floor(w.astype(np.float64) / s + 0.5)
    clipped = int((np.abs(q) > 127).sum())
    if rep is not None:
        rep.setdefault("weights_clipped", {})[name] = clipped
    return np.clip(q, -127, 127).astype(np.int8)


def _log2(v: float) -> float:
    return math.log2(v) if v > 0 else -1e9


def _clip_shift(sh: int, site: str) -> int:
    lo, hi = SHIFT_WINDOW[site]
    return int(min(hi, max(lo, sh)))


def norm_site(gamma, A_ch, consumers, st_key, opt: CalibOptions, s_x: float, rep: dict, name: str, g: Geo = GEO):
    """Choose the int8 gain g, Cn, and the per-channel fold into the consumer
    weights so that y8 = round(x g Cn / (D 2^tn)) ~= xhat * c_eff / s_y fits
    int8. Returns (g8, cn, tn, ceps, s_y, fold)."""
    gamma = gamma.astype(np.float64)
    A = np.maximum(A_ch.astype(np.float64), 1e-12)
    if opt.smooth_alpha is None:
        c = gamma.copy()
    else:
        B = np.max(np.abs(np.concatenate([w.astype(np.float64) * gamma[None, :] for w in consumers], 0)), 0)
        B = np.maximum(B, 1e-12)
        c = B ** (1.0 - opt.smooth_alpha) / A ** opt.smooth_alpha
    sqrt_d = math.sqrt(g.d)
    s_g = float(np.abs(c).max()) / 127.0
    if opt.norm == "native":
        tn, cn, ceps = Native.NORM_TN, Native.NORM_CN, Native.NORM_CEPS
    else:
        tn, ceps = opt.tn, max(1, int(round(g.d * g.eps / (s_x * s_x))))
    for _ in range(8):  # fixed point: forcing |g| >= 1 moves the target, native Cn moves s_g
        g8 = np.floor(c / s_g + 0.5)
        g8 = np.where((g8 == 0) & (c != 0), np.sign(c), g8)
        g8 = np.clip(g8, -127, 127)
        c_eff = g8 * s_g
        target_y = float(np.max(A * np.abs(c_eff))) * (1.0 + opt.margin) / 127.0
        if opt.norm == "native":
            s_y = s_g * (2 ** tn) * sqrt_d / cn
            if s_y >= target_y * (1 - 1e-9):
                break
            s_g = target_y * cn / ((2 ** tn) * sqrt_d)
        else:
            cn = int(math.floor(s_g * (2 ** tn) * sqrt_d / target_y))
            if cn < 1:
                raise ValueError(f"{name}: Cn underflow")
            s_y = s_g * (2 ** tn) * sqrt_d / cn
            break
    fold = np.where(g8 != 0, gamma / np.where(g8 != 0, c_eff, 1.0), 0.0)
    rep[name] = {"cn": int(cn), "tn": int(tn), "ceps": int(ceps), "s_gamma": s_g, "s_y": s_y,
                 "target_y": target_y, "y_fill_at_calib_max": float(np.max(A * np.abs(c_eff)) / s_y / 127.0),
                 "gamma_int_absmax": int(np.abs(g8).max()), "gamma_int_ones": int((np.abs(g8) == 1).sum()),
                 "gamma_rel_err_max": float(np.max(np.abs(c_eff - c) / np.maximum(np.abs(c), 1e-30))),
                 "act_loss_bits": max(0.0, _log2(s_y / target_y))}
    return g8.astype(np.int8), int(cn), int(tn), int(ceps), s_y, fold


def calibrate_layer(W: dict, st: dict, s_x: float, opt: CalibOptions, g: Geo = GEO, s_x_out: float | None = None):
    """Per-layer solver. Returns (LayerInt, report). `st` holds the float
    calibration maxima of this layer (f_block's keys). `s_x` is the input
    (and residual-1) scale; `s_x_out` (default `s_x`) the output scale, a
    power-of-two multiple 2^k of `s_x` (k > 0 needs the residual-2 rescale)."""
    m = 1.0 + opt.margin
    s_x_out = s_x if s_x_out is None else s_x_out
    k_r2 = int(round(math.log2(s_x_out / s_x)))
    if k_r2 < 0 or abs(s_x * 2 ** k_r2 - s_x_out) > 1e-12 * s_x_out:
        raise ValueError("the output scale must be s_x * 2^k with k >= 0")
    rep = {"s_x": s_x, "s_x_out": s_x_out, "sh_r2": k_r2}
    free = opt.shifts == "free"
    Wq, Wk, Wv, Wo = (W[f"self_attn.{n}_proj.weight"].astype(np.float64) for n in "qkvo")
    Wg, Wu, Wd = (W[f"mlp.{n}_proj.weight"].astype(np.float64) for n in ("gate", "up", "down"))

    # ---- norm_a and the QKV fold
    ga, cn_a, tn, ceps, s_y, fold_a = norm_site(W["input_layernorm.weight"], st["xhat_a_ch"], [Wq, Wk, Wv], "a", opt, s_x, rep, "norm_a", g)
    Wq_e, Wk_e, Wv_e = Wq * fold_a[None, :], Wk * fold_a[None, :], Wv * fold_a[None, :]
    tgt = {"q": st["q_pair"] * m / 127.0, "k": st["k_pair"] * m / 127.0, "v": st["v"] * m / 127.0}
    smin = {"q": np.abs(Wq_e).max() / 127.0, "k": np.abs(Wk_e).max() / 127.0, "v": np.abs(Wv_e).max() / 127.0}
    lr = {n: _log2(tgt[n] / (s_y * smin[n])) for n in "qkv"}
    sh_qkv = _clip_shift(int(round(float(np.median(list(lr.values()))))), "qkv") if free else Native.SH_QKV
    s_w = {n: max(smin[n], tgt[n] / (s_y * 2 ** sh_qkv)) for n in "qkv"}
    s_a = {n: s_y * s_w[n] * 2 ** sh_qkv for n in "qkv"}
    sh_rope = opt.f_ro if free else Native.SH_ROPE       # s_qr = s_q 2^(f_ro - sh_rope)
    ro = 2.0 ** (opt.f_ro - sh_rope)
    s_qr, s_kr = s_a["q"] * ro, s_a["k"] * ro
    # ---- scores over all (t, j), incl. causally masked positions
    ts = st["raw_all"] * m / 127.0
    s0 = s_qr * s_kr
    sh_s = _clip_shift(int(math.ceil(_log2(ts / s0))), "s") if free else Native.SH_S
    s_s = s0 * 2 ** sh_s
    if s_s < ts:  # the window (or a fixed shift) cannot reach: coarsen K
        f = ts / s_s
        s_w["k"] *= f
        s_a["k"] *= f
        s_kr *= f
        s_s *= f
        rep["k_coarsened_for_scores"] = f
    lam = s_s / math.sqrt(g.dh)
    exp_t = exp_table(lam, opt.f_e)
    # ---- PV / O
    to = st["o"] * m / 127.0
    sh_o = _clip_shift(int(math.ceil(_log2(to / s_a["v"]))) + opt.f_p, "o") if free else Native.SH_O
    s_o = s_a["v"] * 2.0 ** (sh_o - opt.f_p)
    # ---- AO: the residual add is exact, so s_ao must equal s_x
    s_wo_min = np.abs(Wo).max() / 127.0
    sh_ao = _clip_shift(int(math.floor(_log2(s_x / (s_o * s_wo_min)))), "ao") if free else Native.SH_AO
    s_wo = s_x / (s_o * 2 ** sh_ao)
    # ---- norm_m and the gate/up fold
    gm, cn_m, _, _, s_ym, fold_m = norm_site(W["post_attention_layernorm.weight"], st["xhat_m_ch"], [Wg, Wu], "m", opt, s_x, rep, "norm_m", g)
    Wg_e, Wu_e = Wg * fold_m[None, :], Wu * fold_m[None, :]
    tg = st["gate"] * m / 127.0
    s_wg_min = np.abs(Wg_e).max() / 127.0
    sh_g = _clip_shift(int(round(_log2(tg / (s_ym * s_wg_min)))), "g") if free else Native.SH_G
    s_wg = max(s_wg_min, tg / (s_ym * 2 ** sh_g))
    s_g8 = s_ym * s_wg * 2 ** sh_g
    # ---- up: SH_U = 0 (the native relation has no up remainder plane)
    sh_u = Native.SH_U
    tu = st["up"] * m / 32767.0
    s_wu_min = np.abs(Wu_e).max() / 127.0
    s_wu = max(s_wu_min, tu / (s_ym * 2 ** sh_u))
    s_u = s_ym * s_wu * 2 ** sh_u
    # ---- activation table, product, down (s_z must equal the output scale:
    # s_x, or s_x 2^k when residual 2 rescales)
    s_act_min = max(abs((i - 128) * s_g8 / (1.0 + math.exp(-(i - 128) * s_g8))) for i in range(256)) / 32767.0
    th = st["h"] * m / 32767.0
    s_wd_min = np.abs(Wd).max() / 127.0
    s_zt = s_x_out
    if free:
        sh_z = _clip_shift(int(math.floor(_log2(s_zt / (th * s_wd_min)))), "z")
        s_h = s_zt / (s_wd_min * 2 ** sh_z)
        if s_h < th:  # window clipped the shift: widen h at the cost of Wd
            s_h = th
        sh_h = _clip_shift(int(math.floor(_log2(s_h / (s_u * s_act_min)))), "h")
        s_act = s_h / (s_u * 2 ** sh_h)
        if s_act < s_act_min:  # the product window forced a coarser h: re-derive the down shift
            s_act = s_act_min
            s_h = s_act * s_u * 2 ** sh_h
            sh_z = _clip_shift(int(math.floor(_log2(s_zt / (s_h * s_wd_min)))), "z")
    else:
        sh_z, sh_h = Native.SH_Z, Native.SH_H
        s_h = max(th, s_zt / (s_wd_min * 2 ** sh_z))
        s_act = max(s_act_min, s_h / (s_u * 2 ** sh_h))
        s_h = s_act * s_u * 2 ** sh_h
    s_wd = s_zt / (s_h * 2 ** sh_z)
    act_t = silu_table(s_g8, s_act)
    if opt.f_p != Native.F_P or sh_u != 0:
        raise ValueError("structure-changing option")

    P = LayerInt(
        wq=qw(Wq_e, s_w["q"], rep, "wq"), wk=qw(Wk_e, s_w["k"], rep, "wk"), wv=qw(Wv_e, s_w["v"], rep, "wv"),
        wo=qw(Wo, s_wo, rep, "wo"), gamma_a=ga, gamma_m=gm,
        wg_t=qw(Wg_e, s_wg, rep, "wg").T.copy(), wu_t=qw(Wu_e, s_wu, rep, "wu").T.copy(), wd_t=qw(Wd, s_wd, rep, "wd").T.copy(),
        exp=exp_t, act=act_t, cn_a=cn_a, cn_m=cn_m, tn=tn, ceps=ceps, norm_wrho=norm_window(g.d, tn),
        sh_qkv=sh_qkv, sh_rope=sh_rope, sh_s=sh_s, sh_o=sh_o, sh_ao=sh_ao, sh_g=sh_g, sh_u=sh_u, sh_h=sh_h, sh_z=sh_z,
        f_e=opt.f_e, f_p=opt.f_p, f_ro=opt.f_ro, sh_r2=k_r2)
    # diagnostic only (oracle.py): the per-channel folds, never exported
    P.fold_a, P.fold_m = fold_a, fold_m
    wl = lambda s, smin_: max(0.0, _log2(s / smin_))
    rep.update({
        "scales": {"s_y_a": s_y, "s_q": s_a["q"], "s_k": s_a["k"], "s_v": s_a["v"], "s_s": s_s, "lambda": lam,
                   "s_o": s_o, "s_y_m": s_ym, "s_g8": s_g8, "s_u": s_u, "s_act": s_act, "s_h": s_h,
                   "s_wq": s_w["q"], "s_wk": s_w["k"], "s_wv": s_w["v"], "s_wo": s_wo, "s_wg": s_wg, "s_wu": s_wu, "s_wd": s_wd},
        "weight_loss_bits": {"wq": wl(s_w["q"], smin["q"]), "wk": wl(s_w["k"], smin["k"]), "wv": wl(s_w["v"], smin["v"]),
                             "wo": wl(s_wo, s_wo_min), "wg": wl(s_wg, s_wg_min), "wu": wl(s_wu, s_wu_min), "wd": wl(s_wd, s_wd_min)},
        "weight_overflow_factor": {"wo": s_wo_min / s_wo, "wd": s_wd_min / s_wd},
        "act_loss_bits": {"q": max(0.0, _log2(s_a["q"] / tgt["q"])), "k": max(0.0, _log2(s_a["k"] / tgt["k"])),
                          "v": max(0.0, _log2(s_a["v"] / tgt["v"])), "s": max(0.0, _log2(s_s / ts)),
                          "o": max(0.0, _log2(s_o / to)), "g": max(0.0, _log2(s_g8 / tg)), "u": max(0.0, _log2(s_u / tu)),
                          "h": max(0.0, _log2(s_h / th))},
        "exp_zero_from": int(np.argmax(exp_t == 0)) if np.any(exp_t == 0) else 256,
        "act_table_absmax": int(np.abs(act_t.astype(np.int64)).max()),
    })
    return P, rep


# ------------------------------------------------------------------ native export

def native_words(P: LayerInt, T: int, g: Geo = GEO) -> dict:
    """The words exactly as the shaped `AttentionPublic::new_shaped` /
    `FeedForwardPublic::new_shaped` take them at this geometry: every axis at
    its PADDED extent (d_pad = 2048, h_pad = 32 so the head permutation is the
    identity, f_pad = 8192), zeros off support (ruling P-2), FFN (input,
    output) row-major, attention (output, input) row-major; RoPE tables at
    `tokens x head_dim/2`."""
    d_pad = 1 << (g.d - 1).bit_length()
    f_pad = 1 << (g.f - 1).bit_length()
    h_pad = 1 << (g.H - 1).bit_length()
    assert d_pad == h_pad * g.dh and h_pad == g.H, "this geometry needs no head permutation"
    wg = np.zeros((d_pad, f_pad), dtype=np.int8)
    wu = np.zeros((d_pad, f_pad), dtype=np.int8)
    wd = np.zeros((f_pad, d_pad), dtype=np.int8)
    wg[:g.d, :g.f] = P.wg_t
    wu[:g.d, :g.f] = P.wu_t
    wd[:g.f, :g.d] = P.wd_t
    c, s = rope_tables_int(T, g.dh, g.theta, P.f_ro)
    return {"wq": P.wq, "wk": P.wk, "wv": P.wv, "wo": P.wo, "gamma_a": P.gamma_a, "gamma_m": P.gamma_m,
            "wg_t": wg, "wu_t": wu, "wd_t": wd, "rope_cos": c.reshape(-1), "rope_sin": s.reshape(-1),
            "exp": P.exp, "act": P.act}


def word_digest(a: np.ndarray) -> str:
    """sha256 of (len as u64 LE || little-endian element bytes), the framing
    `absorb_into` uses per vector (native digests use BLAKE3; this is a pin of
    the same bytes, not the native statement digest)."""
    h = hashlib.sha256()
    h.update(int(a.size).to_bytes(8, "little"))
    dt = {np.dtype(np.int8): "<i1", np.dtype(np.int16): "<i2", np.dtype(np.int64): "<i8"}[a.dtype]
    h.update(np.ascontiguousarray(a.reshape(-1)).astype(dt).tobytes())
    return h.hexdigest()


def quantize_input(x: np.ndarray, s_x: float, rec: Rec | None = None, seq0: int = 0) -> np.ndarray:
    q = np.floor(x.astype(np.float64) / s_x + 0.5).astype(np.int64)
    if rec is not None:
        q = rec.check("input int16", q, *I16, seq0, clamp=True)
    return q


def cos_rows(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    a = a.reshape(-1, a.shape[-1]).astype(np.float64)
    b = b.reshape(-1, b.shape[-1]).astype(np.float64)
    na, nb = np.linalg.norm(a, axis=1), np.linalg.norm(b, axis=1)
    return (a * b).sum(1) / np.maximum(na * nb, 1e-30)


def rel_l2(a: np.ndarray, b: np.ndarray) -> float:
    return float(np.linalg.norm((a - b).astype(np.float64)) / max(np.linalg.norm(b.astype(np.float64)), 1e-30))


def jdump(obj) -> str:
    def conv(o):
        if isinstance(o, (np.integer,)):
            return int(o)
        if isinstance(o, (np.floating,)):
            return float(o)
        if isinstance(o, np.ndarray):
            return o.tolist()
        raise TypeError(type(o))
    return json.dumps(obj, default=conv, indent=1, sort_keys=True)

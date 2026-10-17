#!/usr/bin/env python3
"""Lane B3: native-exact calibration of TinyLlama-1.1B blocks.

Builds on `tlcalib.py` (B/B2): the exact integer block `tlcalib.i_block`
(the native witness relations with every constant a parameter) is reused
unchanged. What B3 adds:

1. NATIVE-EXACT PUBLIC TABLES. The exp table is `exp_member(e_s, 64, f_e)`
   of hashline `tables_attn.rs` (score scale exactly 2^e_s), the SiLU table
   one of the 9 frozen `silu-int16out-table-v3` members of zkp-core
   `tables.rs` (gate scale exactly 2^e_in, activation scale exactly 2^e_out)
   and RoPE `rope_tables_generate(T, 64, 10000.0, 7)`. Each generator is
   re-implemented here byte for byte and checked against the frozen digests
   (`verify_tables`).

2. A CONSTRAINED SOLVER with the chain equalities of the native relations.
   Real scales may differ per channel inside one int8 matrix as long as the
   chain holds per channel (no native change; the matrices are public data):
     * norm: y = round(x g Cn / (D 2^tn)) = round(xhat g / K), K = 2^tn sqrt(d)/Cn,
       g int8 per channel, gamma and K/g folded into the consumer columns;
     * Q/K: per (kv head, RoPE pair) s_q,c s_k,c 2^SH_S = 2^e_s (all query
       heads of a group share s_q,c);
     * V/O/Wo: s_v,c (per kv channel) * s_wo,(h,c) * 2^SH_AO = s_x;
     * gate: s_wg 2^SH_G = 2^e_in (uniform), up/product/down per FFN channel j:
       s_h,j = 2^(e_out + SH_H) s_u,j and s_h,j s_wd,j 2^SH_Z = s_x_out.
   Where an interval is empty the solver keeps the activation range (no
   refusal) and CLIPS the public weight, counting the clipped words.

3. VARIANTS of native compatibility (profile-uniform constants, per-layer
   norm constants / tables, per-layer residual rescale, free shifts) and an
   optional orthogonal (randomized Hadamard) rotation of the residual basis,
   which is a change of PUBLIC WEIGHTS only: RMSNorm is rotation invariant
   once gamma is folded into the consumers, so the native relations are
   unchanged.

Calibration data only: not a proof, not a privacy claim.
"""

from __future__ import annotations

import os

for _k in ("OPENBLAS_NUM_THREADS", "OMP_NUM_THREADS", "MKL_NUM_THREADS", "NUMEXPR_NUM_THREADS"):
    os.environ.setdefault(_k, "2")

import hashlib  # noqa: E402
import math  # noqa: E402
import sys  # noqa: E402
from dataclasses import dataclass, field  # noqa: E402
from pathlib import Path  # noqa: E402

import numpy as np  # noqa: E402

sys.path.insert(0, str(Path(__file__).resolve().parent))
import tlcalib as tc  # noqa: E402

GEO = tc.GEO
F_E, F_P, F_RO = 9, 9, 7
MASK = -127


# =============================================================== native tables

SILU_MEMBERS = [(-5, -13), (-4, -13), (-4, -12), (-3, -12), (-3, -11), (-2, -11), (-1, -11), (-1, -10), (-1, -9)]
SILU_DIGESTS = dict(zip(SILU_MEMBERS, [
    "bf3eb04eeeeec844a313be913480606b4b792cdf6f26902bbb7fea4e571b92bc",
    "0c74b0e6fb57dd67a49c61bef5dae093f6ce154d6f331bd65d0d548faf0eca60",
    "afed7dc5c289cbdb18fbf5d794285ba5901ebe43e9e561aad6ec32987fa66d54",
    "859344ba5ed57bd3f831c9082e5991fe7012a0c5696cfa705320ffdb6cb17a25",
    "1001c138ce0d00f09390b36178044d72712fbdca1071467ea274dc980bd9a3f7",
    "eda5f34a1c0dd94ce7398d6762202ed85e3f6f2c4984a5b07aca57b00b30ba56",
    "493202f2d89b0ffe7981decfb818aafaacea4cccb117d758b9e6b416463d9a4b",
    "5323ca1bd1091ec18bf5036ca7ea4e007224ebc3a26ad56759a4b9da0c419a79",
    "d835998909adcd25dcc7eba10239e82ea0323437b5ba419d9fa5c28e6fa6c689",
]))


def silu_generate(e_in: int, e_out: int) -> np.ndarray:
    """zkp-core tables.rs `int16out_generate(Silu, e_in, e_out)`."""
    out = np.zeros(256, dtype=np.int16)
    for i in range(256):
        x = float(i - 128) * (2.0 ** e_in)
        y = x / (1.0 + math.exp(-x))
        v = math.floor(y / (2.0 ** e_out) + 0.5)
        out[i] = int(min(32767.0, max(-32767.0, v)))
    return out


def silu_digest(e_in: int, e_out: int, table: np.ndarray) -> str:
    """`table_spec_digest_int16out(Silu, e_in, e_out, table)`."""
    js = ('{"function":"silu-int16out-table-v3",'
          f'"input":{{"width":8,"scale_exp":{e_in},"signed":true}},'
          f'"output":{{"width":16,"scale_exp":{e_out},"signed":true}},'
          '"rounding":"y = clamp(round_half_up(silu(x*2^in_exp)/2^out_exp), -32767, 32767)",'
          '"table":[' + ",".join(f"[{i - 128},{int(v)}]" for i, v in enumerate(table)) + "]}")
    return hashlib.sha256(js.encode()).hexdigest()


def silu_member(e_in: int, e_out: int):
    """`int16out_member`: None outside the frozen registry; a digest that
    differs from its pin is a hard stop."""
    if (e_in, e_out) not in SILU_DIGESTS:
        return None
    t = silu_generate(e_in, e_out)
    d = silu_digest(e_in, e_out, t)
    if d != SILU_DIGESTS[(e_in, e_out)]:
        raise AssertionError(f"silu ({e_in},{e_out}): regenerated digest {d} != frozen pin")
    return t, d


def exp_generate(e_s: int, head_dim: int = 64, f_e: int = F_E) -> np.ndarray:
    """hashline tables_attn.rs `exp_table_generate`."""
    lam = (2.0 ** e_s) / math.sqrt(head_dim)
    scale = 2.0 ** f_e
    return np.array([math.floor(scale * math.exp(-float(d) * lam) + 0.5) for d in range(256)], dtype=np.int64)


def exp_digest(e_s: int, head_dim: int, f_e: int, table: np.ndarray) -> str:
    js = ('{"function":"exp-neg-table-v1",'
          '"input":{"width":8,"signed":false},'
          f'"output":{{"width":{f_e + 1},"signed":false,"frac_bits":{f_e}}},'
          f'"decay":{{"score_scale_exp":{e_s},"head_dim":{head_dim}}},'
          '"rounding":"E = round_half_up(2^frac_bits * exp(-d * 2^score_scale_exp / sqrt(head_dim)))",'
          '"table":[' + ",".join(f"[{d},{int(e)}]" for d, e in enumerate(table)) + "]}")
    return hashlib.sha256(js.encode()).hexdigest()


def exp_member(e_s: int, head_dim: int = 64, f_e: int = F_E):
    t = exp_generate(e_s, head_dim, f_e)
    assert t[0] == 1 << f_e and np.all((t >= 0) & (t <= 1 << f_e)) and np.all(np.diff(t) <= 0)
    return t, exp_digest(e_s, head_dim, f_e, t)


def rope_generate(t_max: int, head_dim: int = 64, base: float = 10000.0, f_ro: int = F_RO):
    """`rope_tables_generate` (row-major t x head_dim/2)."""
    half = head_dim // 2
    scale = 2.0 ** f_ro
    c = np.zeros((t_max, half), dtype=np.int64)
    s = np.zeros((t_max, half), dtype=np.int64)
    for i in range(half):
        theta = base ** (-2.0 * i / head_dim)
        for t in range(t_max):
            a = float(t) * theta
            c[t, i] = math.floor(math.cos(a) * scale + 0.5)
            s[t, i] = math.floor(math.sin(a) * scale + 0.5)
    return c, s


def _py_float(x: float) -> str:
    return f"{x:.1f}" if x == math.floor(x) and abs(x) < 1e16 else repr(x)


def rope_digest(t_max: int, head_dim: int, base: float, f_ro: int, c: np.ndarray, s: np.ndarray) -> str:
    head = ('{"function":"rope-cs-table-v1",'
            f'"rope_base":{_py_float(base)},"head_dim":{head_dim},"t_max":{t_max},"frac_bits":{f_ro},'
            '"rounding":"c=round_half_up(cos(t*base^(-2i/head_dim))*2^frac_bits); s likewise"}')
    h = hashlib.sha256(head.encode())
    h.update(np.ascontiguousarray(c.reshape(-1)).astype("<i8").tobytes())
    h.update(np.ascontiguousarray(s.reshape(-1)).astype("<i8").tobytes())
    return h.hexdigest()


def verify_tables() -> dict:
    """Every generator against the native pins (tables.rs digests; the
    tables_attn.rs unit-test prefixes)."""
    out = {"silu_members": {}}
    for m in SILU_MEMBERS:
        t, d = silu_member(*m)
        out["silu_members"][f"{m[0]},{m[1]}"] = {"digest": d, "min": int(t.min()), "max": int(t.max()),
                                                "saturated_rows": int((np.abs(t.astype(np.int64)) == 32767).sum())}
    t, _ = silu_member(-3, -11)
    assert int(t.min()) == -570 and int(t.max()) == 32512
    t, _ = silu_member(-4, -13)
    assert int((t == 32767).sum()) == 62
    _, d1 = exp_member(-1, 64, 9)
    _, d2 = exp_member(-2, 64, 9)
    t3, _ = exp_member(1, 64, 9)
    assert d1.startswith("15903694") and d2.startswith("b4f01aca"), (d1, d2)
    assert t3[0] == 512 and t3[4] == math.floor(512.0 * math.exp(-1.0) + 0.5)
    c, s = rope_generate(16)
    d16 = rope_digest(16, 64, 10000.0, 7, c, s)
    c, s = rope_generate(32)
    d32 = rope_digest(32, 64, 10000.0, 7, c, s)
    assert d16.startswith("355be440fcc13985") and d32.startswith("e0de1cf45aa38f10"), (d16, d32)
    ct, st_ = tc.rope_tables_int(32, 64, 10000.0, 7)
    assert np.array_equal(ct, c) and np.array_equal(st_, s), "tlcalib rope tables differ from the native generator"
    out.update({"exp_pin_m1": d1, "exp_pin_m2": d2, "rope_t16": d16, "rope_t32": d32, "all_pins_ok": True})
    return out


# ============================================================ rotation (optional)

def fwht(x: np.ndarray) -> np.ndarray:
    """x H along the last axis (Sylvester H, unnormalized), float64."""
    y = np.array(x, dtype=np.float64, copy=True)
    n = y.shape[-1]
    lead = y.shape[:-1]
    h = 1
    while h < n:
        y = y.reshape(*lead, n // (2 * h), 2, h)
        a, b = y[..., 0, :], y[..., 1, :]
        y = np.stack([a + b, a - b], axis=-2)
        h *= 2
    return y.reshape(*lead, n)


class Rotation:
    """R = H diag(sign) / sqrt(n), orthogonal; the residual basis becomes
    x' = x R^T (row vectors). Public-weight change only."""

    def __init__(self, n: int, seed: int):
        assert n & (n - 1) == 0
        self.n, self.seed = n, seed
        self.sign = np.where(np.random.default_rng(seed).integers(0, 2, n) == 1, 1.0, -1.0)

    def fwd(self, x):       # x R^T
        return fwht(np.asarray(x, dtype=np.float64) * self.sign) / math.sqrt(self.n)

    def inv(self, y):       # y R
        return fwht(y) * self.sign / math.sqrt(self.n)

    def matrix(self):
        return self.fwd(np.eye(self.n)).T      # R (so that x R^T = x @ matrix().T)


def rotate_layer(W: dict, R: Rotation) -> dict:
    """Fold both gammas into their consumers and rotate the residual basis:
    consumers W' = W diag(gamma) R^T, writers W' = R W, gammas 1 (float32
    out; the float model is unchanged up to rounding)."""
    out = dict(W)
    ga = W["input_layernorm.weight"].astype(np.float64)
    gm = W["post_attention_layernorm.weight"].astype(np.float64)
    for n in ("q", "k", "v"):
        k = f"self_attn.{n}_proj.weight"
        out[k] = R.fwd(W[k].astype(np.float64) * ga[None, :]).astype(np.float32)
    for n in ("gate", "up"):
        k = f"mlp.{n}_proj.weight"
        out[k] = R.fwd(W[k].astype(np.float64) * gm[None, :]).astype(np.float32)
    for k in ("self_attn.o_proj.weight", "mlp.down_proj.weight"):
        out[k] = np.ascontiguousarray(R.fwd(W[k].astype(np.float64).T).T).astype(np.float32)
    out["input_layernorm.weight"] = np.ones_like(W["input_layernorm.weight"])
    out["post_attention_layernorm.weight"] = np.ones_like(W["post_attention_layernorm.weight"])
    return out


# ============================================================ float block + per-channel statistics

def _mx(st, key, val):
    st[key] = np.maximum(st[key], val) if key in st else val


def _acc(st, key, val):
    st[key] = st[key] + val if key in st else val


GATE_LIMIT = 127.0 * 2.0 ** -1    # widest frozen SiLU member (e_in = -1): |gate| <= 63.5


def f_block_stats(x: np.ndarray, W: dict, cos, sin, st: dict | None = None, g=GEO, keep: np.ndarray | None = None) -> np.ndarray:
    """The float32 Llama block (== tlcalib.f_block) plus the per-channel
    maxima / sums of squares the solver needs, accumulated into `st`.

    `keep` (bool per sequence, updated IN PLACE): a calibration sequence whose
    gate leaves +-63.5 at this layer cannot be carried by ANY frozen SiLU
    member, so the native block must refuse it here; it is excluded from
    this layer's statistics and from every later layer's (and counted)."""
    x2, parts = _f_block_parts(x, W, cos, sin, g)
    if st is None:
        return x2
    if keep is None:
        keep = np.ones(x.shape[0], dtype=bool)
    gabs = np.abs(parts["gt"]).reshape(x.shape[0], -1).max(1)
    newly = keep & (gabs > GATE_LIMIT)
    keep &= ~newly
    st["excluded_here"] = int(newly.sum())
    st["excluded_total"] = int((~keep).sum())
    st["gate_absmax_all_sequences"] = float(gabs.max())
    sel = {k: v[keep] for k, v in parts.items()}
    _accumulate(st, x[keep], x2[keep], sel, g)
    return x2


def _f_block_parts(x, W, cos, sin, g):
    N, T, d = x.shape
    xa = tc.f_xhat(x, g.eps)
    h = xa * W["input_layernorm.weight"]
    q = (h @ W["self_attn.q_proj.weight"].T).reshape(N, T, g.H, g.dh)
    k = (h @ W["self_attn.k_proj.weight"].T).reshape(N, T, g.KV, g.dh)
    v = (h @ W["self_attn.v_proj.weight"].T).reshape(N, T, g.KV, g.dh)
    qr, kr = tc.f_rope(q, cos, sin), tc.f_rope(k, cos, sin)
    qg = qr.reshape(N, T, g.KV, g.G, g.dh).transpose(0, 2, 3, 1, 4)
    kg = kr.transpose(0, 2, 3, 1)[:, :, None]
    raw = qg @ kg                                                  # (N,KV,G,T,T)
    tri = np.tril(np.ones((T, T), dtype=bool))
    logits = np.where(tri, raw / np.float32(math.sqrt(g.dh)), -np.inf).astype(np.float32)
    logits -= logits.max(-1, keepdims=True)
    p = np.exp(logits)
    p /= p.sum(-1, keepdims=True)
    vg = v.transpose(0, 2, 1, 3)[:, :, None]
    o = (p @ vg).transpose(0, 3, 1, 2, 4).reshape(N, T, d)
    ao = o @ W["self_attn.o_proj.weight"].T
    x1 = x + ao
    xm = tc.f_xhat(x1, g.eps)
    hm = xm * W["post_attention_layernorm.weight"]
    gt = hm @ W["mlp.gate_proj.weight"].T
    up = hm @ W["mlp.up_proj.weight"].T
    with np.errstate(over="ignore"):
        act = gt / (1.0 + np.exp(-gt))   # == tlcalib.f_block (exp overflow -> -0 for gate < -88)
    hh = act * up
    z = hh @ W["mlp.down_proj.weight"].T
    x2 = x1 + z
    return x2, {"xa": xa, "xm": xm, "o": o, "gt": gt, "up": up, "hh": hh, "q": q, "k": k, "v": v, "raw": raw,
                "act": act, "ao": ao, "x1": x1, "z": z}


def _accumulate(st, x, x2, P, g):
    N, T, d = x.shape
    xa, xm, o, gt, up, hh, q, k, v, raw, act, ao, x1, z = (P[n] for n in ("xa", "xm", "o", "gt", "up", "hh", "q", "k", "v",
                                                                          "raw", "act", "ao", "x1", "z"))
    tri = np.tril(np.ones((T, T), dtype=bool))
    if True:
        R = N * T
        a = lambda t: np.abs(t).reshape(R, -1)
        pairn = lambda t: np.sqrt(t[..., :g.half].astype(np.float64) ** 2 + t[..., g.half:].astype(np.float64) ** 2)
        _acc(st, "rows", R)
        for key, t in (("xa", xa), ("xm", xm), ("o", o), ("gate", gt), ("up", up), ("h", hh), ("actc", act), ("ao", ao), ("z", z),
                       ("q", q.reshape(N, T, -1)), ("k", k.reshape(N, T, -1)), ("v", v.reshape(N, T, -1))):
            _mx(st, key + "_max", a(t).max(0))
            _acc(st, key + "_ss", (t.astype(np.float64).reshape(R, -1) ** 2).sum(0))
        _mx(st, "q_pair", pairn(q).reshape(R, g.H, g.half).max(0))       # (H, half)
        _mx(st, "k_pair", pairn(k).reshape(R, g.KV, g.half).max(0))      # (KV, half)
        _mx(st, "raw_kv", np.abs(raw).transpose(1, 0, 2, 3, 4).reshape(g.KV, -1).max(1))
        _mx(st, "raw_causal", float(np.abs(np.where(tri, raw, 0)).max()))
        _acc(st, "raw_cs", float((np.where(tri, raw.astype(np.float64), 0.0) ** 2).sum()))
        _acc(st, "raw_cn", int(N * g.KV * g.G * tri.sum()))
        _mx(st, "gate_pos", float(gt.max()))
        _mx(st, "gate_neg", float(-gt.min()))
        _mx(st, "act_max", float(act.max()))
        for key, t in (("x", x), ("x1", x1), ("x2", x2), ("ao", ao), ("z", z)):
            at = np.abs(t)
            _mx(st, key + "_amax", float(at.max()))
            _mx(st, key + "_amax_p0", float(at[:, 0].max()))
            _mx(st, key + "_amax_rest", float(at[:, 1:].max()) if T > 1 else 0.0)
    return x2


def finalize_stats(st: dict) -> dict:
    """ms = sum of squares / rows for every *_ss; keeps maxima."""
    out = dict(st)
    for k in list(st):
        if k.endswith("_ss"):
            out[k[:-3] + "_ms"] = st[k] / st["rows"]
    out["raw_ms"] = st["raw_cs"] / st["raw_cn"]
    return out


# ============================================================ variants

@dataclass
class Variant:
    name: str
    norm_cn: str = "profile"      # "profile": one Cn_a / Cn_m for all layers; "layer"
    tables: str = "profile"       # "profile": one exp e_s and one SiLU member; "layer"
    residual: str = "global"      # "global": one s_x (k = 0); "layer": per-layer rescale k >= 0
    shifts: str = "native"        # "native": the toy shifts; "free": per layer within the windows;
                                  # "profile": ONE TinyLlama shift set for all layers (within the windows)
    rotate: int | None = None     # seed of a randomized Hadamard residual rotation, or None
    margin: float = 0.5           # global (per-tensor) range margin: bound = (1 + margin) * calibration max
    margin_ch: float = 3.0        # per-channel bounds: min(margin_ch * channel max, (1 + margin) * tensor max)
    margin_pow2: float = 0.25     # for power-of-two table exponents (score e_s, gate e_in, act e_out), which
                                  # already round the range up by up to 2x
    tn: int = 10
    cn_max: int = 65536           # contract-review no-wrap bound (HANDOFF: CN <= 65536)
    shapes: tuple = ("range", "smooth", "gamma")

    @property
    def m(self) -> float:
        return 1.0 + self.margin

    @property
    def m2(self) -> float:
        return 1.0 + self.margin_pow2


NATIVE_SHIFTS = {"qkv": 7, "rope": 7, "s": 6, "o": 9, "ao": 7, "g": 7, "u": 0, "h": 14, "z": 6}
# structure-preserving windows (tlcalib.SHIFT_WINDOW): one-byte remainder
# sites hold 1..8, the two-limb sites (O, product) hold 9..16
WINDOW = tc.SHIFT_WINDOW

LADDER = {
    "a": Variant("a"),
    "a_t": Variant("a_t", tables="layer"),
    "b": Variant("b", norm_cn="layer", tables="layer"),
    "c": Variant("c", norm_cn="layer", tables="layer", residual="layer"),
    "d": Variant("d", norm_cn="layer", tables="layer", residual="layer", shifts="free"),
    # one residual scale, but per-layer free shifts / one profile shift set
    "dg": Variant("dg", norm_cn="layer", tables="layer", residual="global", shifts="free"),
    "pg": Variant("pg", norm_cn="profile", tables="layer", residual="global", shifts="profile"),
}


def variant_by_name(name: str, rotate: int | None = None, margin: float | None = None) -> Variant:
    base = name.split("+")[0]
    v = LADDER[base]
    kw = dict(v.__dict__)
    kw["name"] = name
    if rotate is not None:
        kw["rotate"] = rotate
    if margin is not None:
        kw["margin"] = margin
    return Variant(**kw)




# ============================================================ constants, helpers

NATIVE_SHIFTS = {"qkv": 7, "rope": 7, "s": 6, "o": 9, "ao": 7, "g": 7, "u": 0, "h": 14, "z": 6}
WINDOW = tc.SHIFT_WINDOW   # one-byte remainder sites 1..8; O and product 9..16


def _l2(v: float) -> float:
    return math.log2(v) if v > 0 else -1e9


def _clampw(v, site):
    lo, hi = WINDOW[site]
    return int(min(hi, max(lo, v)))


def rb(arr, m: float, mc: float):
    """Robust per-channel range bound: a channel's calibration maximum is a
    noisy estimate (held-out/calibration up to 2.2x for xhat/q/k/v, 5x for
    up), the tensor maximum is not (<= 1.38x); so min(mc * channel max,
    m * tensor max)."""
    a = np.asarray(arr, dtype=np.float64)
    return np.minimum(mc * a, m * float(a.max()))


def norm_K(cn: int, tn: int, d: int = GEO.d) -> float:
    """y = round(x g Cn / (D 2^tn)) = round(xhat g / K), D ~ sqrt(d) rms_int."""
    return (2 ** tn) * math.sqrt(d) / cn


def _wnoise(Wp, s_rows, eyr, ey2, clip=False):
    """Per-row output noise from y rounding and weight rounding (sum over the
    inner index); `s_rows` the per-row real weight scale."""
    q = np.floor(Wp / s_rows[:, None] + 0.5)
    if clip:
        q = np.clip(q, -127, 127)
    dlt = Wp - s_rows[:, None] * q
    return (Wp * Wp) @ eyr + (dlt * dlt) @ ey2


def _pairmax(rm, heads):
    r = rm.reshape(heads, GEO.dh)
    return np.maximum(r[:, :GEO.half], r[:, GEO.half:])


def qk_scales(rmq, rmk, st, m, sh_qkv, sh_s, e_s_fixed, free, mc=3.0, m2=1.25):
    """The Q/K/score chain at one layer: per (kv head, RoPE pair) lower bounds
    (output range; no weight clipping), the exp-table exponent e_s, the score
    shift, and the scales with s_q,c s_k,c 2^SH_S = 2^e_s. None if a fixed
    e_s cannot hold this layer."""
    g = GEO
    sh = 2.0 ** sh_qkv
    Lq = np.maximum(rb(st["q_pair"], m, mc) / 127.0, sh * _pairmax(rmq, g.H) / 127.0).reshape(g.KV, g.G, g.half).max(1)
    Lk = np.maximum(rb(st["k_pair"], m, mc) / 127.0, sh * _pairmax(rmk, g.KV) / 127.0)
    need_P = float(np.max(Lq * Lk))
    raw = float(st["raw_kv"].max())
    e_range = int(math.ceil(_l2(raw * m2 / 127.0) - 1e-9))
    if e_s_fixed is not None:
        e_s = e_s_fixed
        if free:
            sh_s = _clampw(int(math.floor(e_s - _l2(need_P) + 1e-9)), "s")
        if e_s < e_range:
            return None
    elif free:
        e_s = e_range
        sh_s = _clampw(int(math.floor(e_s - _l2(need_P) + 1e-9)), "s")
        e_s = max(e_s, int(math.ceil(_l2(need_P) + sh_s - 1e-9)))
    else:
        e_s = max(e_range, int(math.ceil(_l2(need_P) + sh_s - 1e-9)))
    P = 2.0 ** (e_s - sh_s)
    if P < need_P * (1 - 1e-9):
        return None
    slack = np.sqrt(P / (Lq * Lk))
    return {"e_s": e_s, "sh_s": sh_s, "s_q": Lq * slack, "s_k": Lk * slack, "need_P": need_P, "e_range": e_range,
            "raw": raw, "slack": slack}


def q_rows(s_q):    # (KV, half) -> per Wq row (head-major, query head h reads kv h // G)
    return np.concatenate([s_q, s_q], 1)[:, None, :].repeat(GEO.G, 1).reshape(-1)


def k_rows(s_k):    # (KV, half) -> per Wk / Wv row
    return np.concatenate([s_k, s_k], 1).reshape(-1)


def gains_for(c_shape, Ab, K, r):
    """Ab: the robust per-channel bound of |xhat| (margin included)."""
    cap = np.clip(np.floor(127.0 * K / Ab), 1, 127)
    g = np.clip(np.floor(c_shape * r * K + 0.5), 1, 127)
    return np.minimum(g, cap)


def norm_shapes(gamma, A, mats):
    absg = np.maximum(np.abs(gamma), 1e-12)
    B = np.zeros_like(A)
    for Wm in mats:
        B = np.maximum(B, np.abs(Wm).max(0).astype(np.float64) * absg)
    B = np.maximum(B, 1e-12)
    return {"range": 1.0 / A, "smooth": np.sqrt(B / A), "gamma": absg}


def choose_norm(gamma, A, ms, mats, objective, var, K_fixed, shapes=None, r_steps=24):
    """Search the per-channel gain SHAPE and the y-range scale r against the
    consumers' objective. With K_fixed None (per-layer Cn) K follows r so the
    largest gain is 127. Returns (g8, cn, K, info)."""
    gamma = gamma.astype(np.float64)
    A = np.maximum(A.astype(np.float64), 1e-6)
    m = var.m
    Ab = rb(A, m, var.margin_ch)
    cn_hi = min(var.cn_max, int(math.floor((2 ** var.tn) * math.sqrt(GEO.d) * 127.0 / float(Ab.max()))))
    if K_fixed is not None and K_fixed < float(Ab.max()) / 127.0:
        raise ValueError(f"profile K {K_fixed:.4f} lets a unit gain overflow (needs >= {float(Ab.max()) / 127.0:.4f})")
    all_shapes = norm_shapes(gamma, A, mats)
    best, per_shape = None, {}
    for sname in (shapes or var.shapes):
        cs = all_shapes[sname]
        r_max = 127.0 / float(np.max(Ab * cs))
        sbest, skk = math.inf, 0
        for kk in range(r_steps):
            r = r_max * 2.0 ** (-kk / 4.0)
            if K_fixed is None:
                K = 127.0 / (r * float(cs.max()))
                cn = min(max(int(round((2 ** var.tn) * math.sqrt(GEO.d) / K)), 1), cn_hi)
                K = norm_K(cn, var.tn)
            else:
                K, cn = K_fixed, None
            g8 = gains_for(cs, Ab, K, r)
            nz, extra = objective(g8, K, ms)
            if nz < sbest:
                sbest, skk = nz, kk
            if best is None or nz < best[0]:
                best = (nz, sname, kk, g8, K, cn, extra)
            if kk > skk + 4 and nz > 1.3 * sbest:
                break
        per_shape[sname] = sbest
    nz, sname, kk, g8, K, cn, extra = best
    if not math.isfinite(nz):
        raise ValueError("no feasible norm gain (every candidate infeasible)")
    if cn is None:
        cn = int(round((2 ** var.tn) * math.sqrt(GEO.d) / K))
    info = {"shape": sname, "r_step": kk, "noise": nz, "K": K, "cn": cn, "extra": extra,
            "y_fill_calib": float(np.max(A * g8 / K)) / 127.0, "y_bound_fill": float(np.max(Ab * g8 / K)) / 127.0,
            "g_max": int(g8.max()), "g_ones": int((g8 == 1).sum()), "g_at_127": int((g8 >= 127).sum()),
            "best_noise_per_shape": per_shape}
    return g8.astype(np.int8), int(cn), float(K), info


# ============================================================ the layer solver

def qw_rows(Wp: np.ndarray, s_rows: np.ndarray, rep: dict, name: str) -> np.ndarray:
    """int8 weights with a per-ROW real scale. Clipping is counted: a public
    weight change, never an activation clamp."""
    q = np.floor(Wp.astype(np.float64) / s_rows[:, None] + 0.5)
    clipped = int((np.abs(q) > 127).sum())
    rep.setdefault("weights_clipped", {})[name] = clipped
    if clipped:
        rep.setdefault("weights_clip_factor", {})[name] = float(np.abs(q).max() / 127.0)
    rep.setdefault("weights_absmax_int", {})[name] = int(min(127, np.abs(q).max()))
    return np.clip(q, -127, 127).astype(np.int8)


def qw_cols(Wp: np.ndarray, s_cols: np.ndarray, rep: dict, name: str) -> np.ndarray:
    return qw_rows(Wp.T, s_cols, rep, name).T.copy()


@dataclass
class Globals:
    """Decisions shared across layers (the profile) and the residual schedule."""
    s_in: list
    s_out: list
    K_a: float | None = None      # profile norm constants (None: per layer)
    K_m: float | None = None
    cn_a: int | None = None
    cn_m: int | None = None
    e_s: int | None = None        # profile tables (None: per layer)
    silu: tuple | None = None
    shifts: dict | None = None    # profile shift set (variant shifts="profile", once decided)


def gate_e_in(gmax: float, m: float) -> int:
    """smallest registry e_in whose int8 range holds the gate with margin
    (-1, the widest, if none does)."""
    for e in (-5, -4, -3, -2, -1):
        if 127.0 * 2.0 ** e >= gmax * m:
            return e
    return -1


def silu_choice(e_in: int, act_max: float, m: float):
    """finest registry e_out for e_in that does not saturate below act_max*m."""
    outs = sorted([eo for (ei, eo) in SILU_MEMBERS if ei == e_in])
    for eo in outs:
        if act_max * m <= 32767 * 2.0 ** eo:
            return (e_in, eo)
    return (e_in, outs[-1])




# ============================================================ the V->O->Wo and up->h->down chains
#
# Shared by the norm-gain objectives and the solver so they cannot disagree.

def v_chain(Lv, wo_colmax, wo_col2, o_ms_g, sy_a, s_x, sh_qkv, sh_ao, free):
    """Per kv channel c: s_v,c in [Lv, Uv] with s_v s_wo 2^SH_AO = s_x. Noise
    growing with s_v (v rounding, Wv rounding through the norm output, o
    rounding at s_o = s_v) against Wo rounding (s_wo shrinking with s_v):
    minimum at s_v^4 = b / a. Empty interval: keep the v range, clip Wo.
    Free shifts: the largest SH_AO with no empty interval."""
    ratio = s_x * 127.0 / (Lv * np.maximum(wo_colmax, 1e-30))       # Uv / Lv at SH_AO = 0
    if free:
        sh_ao = _clampw(int(math.floor(_l2(float(ratio.min())) + 1e-9)), "ao")
    Uv = Lv * ratio / 2.0 ** sh_ao
    a = wo_col2 * (2.0 / 12.0 + sy_a / (12.0 * 4.0 ** sh_qkv))
    b = GEO.d * o_ms_g * (s_x / 2.0 ** sh_ao) ** 2 / 12.0
    bal = (b / np.maximum(a, 1e-300)) ** 0.25
    return np.where(Lv <= Uv, np.clip(bal, Lv, Uv), Lv), sh_ao, Uv


def u_chain(Lu, wd_colmax, wd_col2, act_ms, h_ms, sy_m, hs, s_x_out, sh_z, free):
    """Per FFN channel j: s_u,j is BOTH the up scale and the Wu weight scale
    (SH_U = 0); s_h = hs s_u (hs = 2^(e_out + SH_H)); s_h s_wd 2^SH_Z = s_x_out.
    Noise growing with s_u (Wu rounding through the norm output times act^2,
    product rounding) against Wd rounding: minimum at s_u^4 = b / a. Empty
    interval: keep the up range, clip Wd. Free: the largest feasible SH_Z."""
    ratio = s_x_out * 127.0 / (hs * Lu * np.maximum(wd_colmax, 1e-30))
    if free:
        sh_z = _clampw(int(math.floor(_l2(float(ratio.min())) + 1e-9)), "z")
    Uu = Lu * ratio / 2.0 ** sh_z
    a = wd_col2 * (act_ms * sy_m / 12.0 + hs * hs / 12.0)
    b = GEO.d * h_ms * (s_x_out / ((2.0 ** sh_z) * hs)) ** 2 / 12.0
    bal = (b / np.maximum(a, 1e-300)) ** 0.25
    return np.where(Lu <= Uu, np.clip(bal, Lu, Uu), Lu), sh_z, Uu


def _cols_round_err(Wsub, s_cols):
    """sum over (subsampled) rows of the squared rounding+clipping error of
    each column at its real scale."""
    q = np.clip(np.floor(Wsub / s_cols[None, :] + 0.5), -127, 127)
    dlt = Wsub - q * s_cols[None, :]
    return (dlt * dlt).sum(0)


class AttnObjective:
    """Relative error variance of norm_a's consumers for a gain vector: Q and K
    (y, weight and q/k rounding at the scales the score chain forces), the
    score rounding at 2^e_s, and the attention output ao through
    V -> O -> Wo at the residual scale s_x."""

    def __init__(self, W, st, gamma, var, sh_qkv, sh_s, sh_ao, e_s_fixed, free, s_x, sub=4):
        g = GEO
        self.Wq = W["self_attn.q_proj.weight"].astype(np.float32)
        self.Wk = W["self_attn.k_proj.weight"].astype(np.float32)
        self.Wv = W["self_attn.v_proj.weight"].astype(np.float32)
        Wo = W["self_attn.o_proj.weight"].astype(np.float64)
        self.wo_colmax = np.abs(Wo).max(0).reshape(g.KV, g.G, g.dh).max(1).reshape(-1)
        self.wo_col2_cols = (Wo ** 2).sum(0)                                     # (H*dh,)
        self.wo_col2 = self.wo_col2_cols.reshape(g.KV, g.G, g.dh).sum(1).reshape(-1)
        self.o_ms_g = st["o_ms"].reshape(g.KV, g.G, g.dh).sum(1).reshape(-1)
        self.Wo_sub = Wo[::sub].astype(np.float32)
        self.sub = sub
        self.st, self.gamma, self.var = st, gamma, var
        self.sh_qkv, self.sh_s, self.sh_ao, self.e_s_fixed, self.free, self.s_x = sh_qkv, sh_s, sh_ao, e_s_fixed, free, s_x
        self.vb = rb(st["v_max"], var.m, var.margin_ch) / 127.0

    def __call__(self, g8, K, ms):
        st, var, g = self.st, self.var, GEO
        sh = 2.0 ** self.sh_qkv
        scale = (self.gamma * K / g8).astype(np.float32)
        ey2d = ms * (g8 / K) ** 2
        eyr = np.minimum(1.0 / 12.0, ey2d).astype(np.float32)
        ey2 = ey2d.astype(np.float32)
        Wq, Wk, Wv = self.Wq * scale, self.Wk * scale, self.Wv * scale
        qk = qk_scales(np.abs(Wq).max(1), np.abs(Wk).max(1), st, var.m, self.sh_qkv, self.sh_s, self.e_s_fixed, self.free,
                       var.margin_ch, var.m2)
        if qk is None:
            return math.inf, None
        sq, sk = q_rows(qk["s_q"]), k_rows(qk["s_k"])
        nq = _wnoise(Wq[::4], (sq[::4] / sh).astype(np.float32), eyr, ey2) + 2 * sq[::4] ** 2 / 12.0
        nk = _wnoise(Wk, (sk / sh).astype(np.float32), eyr, ey2) + 2 * sk ** 2 / 12.0
        rel = (float(nq.sum() / st["q_ms"][::4].sum()) + float(nk.sum() / st["k_ms"].sum())
               + (2.0 ** qk["e_s"]) ** 2 / 12.0 / st["raw_ms"])
        # V -> O -> Wo -> ao at s_x
        Lv = np.maximum(self.vb, sh * np.abs(Wv).max(1) / 127.0)
        sy = float(ey2d.sum())
        s_v, sh_ao, _ = v_chain(Lv, self.wo_colmax, self.wo_col2, self.o_ms_g, sy, self.s_x, self.sh_qkv, self.sh_ao, self.free)
        nv = _wnoise(Wv, (s_v / sh).astype(np.float32), eyr, ey2) + s_v ** 2 / 12.0
        no = np.repeat((nv + s_v ** 2 / 12.0).reshape(g.KV, 1, g.dh), g.G, 1).reshape(-1)
        s_v_cols = np.repeat(s_v.reshape(g.KV, 1, g.dh), g.G, 1).reshape(-1)
        s_wo = (self.s_x / (2.0 ** sh_ao * s_v_cols)).astype(np.float32)
        n_ao = (float((self.wo_col2_cols * no).sum()) + self.sub * float((_cols_round_err(self.Wo_sub, s_wo) * st["o_ms"]).sum())
                + g.d * self.s_x ** 2 / 12.0)
        rel += n_ao / float(st["ao_ms"].sum())
        return rel, {"e_s": qk["e_s"], "sh_s": qk["sh_s"], "sh_ao": sh_ao}


class FfnObjective:
    """Relative error variance of the feed-forward OUTPUT z for a gain vector:
    the gate at its pinned 2^e_in (clipped weights where they must be) into
    the activation, up -> product -> down with the up/product/down scales the
    chain forces at s_x_out (FFN channels subsampled by `sub`)."""

    def __init__(self, W, st, gamma, var, sh_g, member, sh_h, sh_z, free, s_x_out, sub=8):
        self.sub, self.st, self.gamma, self.var = sub, st, gamma, var
        self.sh_g, self.e_in, self.e_out, self.sh_h, self.sh_z, self.free, self.s_x_out = sh_g, member[0], member[1], sh_h, sh_z, free, s_x_out
        self.Wg = W["mlp.gate_proj.weight"][::sub].astype(np.float32)
        self.Wu = W["mlp.up_proj.weight"][::sub].astype(np.float32)
        Wd = W["mlp.down_proj.weight"][:, ::sub].astype(np.float32)
        self.Wd = Wd
        self.wd_colmax = np.abs(Wd).max(0).astype(np.float64)
        self.wd_col2 = (Wd.astype(np.float64) ** 2).sum(0)
        self.hs = 2.0 ** (self.e_out + sh_h)
        self.up_b = rb(st["up_max"], var.m, var.margin_ch)[::sub] / 32767.0
        self.h_b = float(st["h_max"].max()) * var.m / (32767.0 * self.hs)
        self.act_ms, self.h_ms, self.up_ms = st["actc_ms"][::sub], st["h_ms"][::sub], st["up_ms"][::sub]
        self.z_sig = float(st["z_ms"].sum())

    def __call__(self, g8, K, ms):
        st, g, sub = self.st, GEO, self.sub
        scale = (self.gamma * K / g8).astype(np.float32)
        ey2d = ms * (g8 / K) ** 2
        eyr = np.minimum(1.0 / 12.0, ey2d).astype(np.float32)
        ey2 = ey2d.astype(np.float32)
        Wg, Wu = self.Wg * scale, self.Wu * scale
        s_wg = np.full(Wg.shape[0], 2.0 ** (self.e_in - self.sh_g), dtype=np.float32)
        n_gate = _wnoise(Wg, s_wg, eyr, ey2, clip=True) + (2.0 ** self.e_in) ** 2 / 12.0
        n_act = 0.5 * n_gate + (2.0 ** self.e_out) ** 2 / 12.0
        Lu = np.maximum.reduce([self.up_b, np.abs(Wu).max(1) / 127.0, np.full(Wu.shape[0], self.h_b)])
        s_u, sh_z, _ = u_chain(Lu, self.wd_colmax, self.wd_col2, self.act_ms, self.h_ms, float(ey2d.sum()), self.hs,
                               self.s_x_out, self.sh_z, self.free)
        n_u = _wnoise(Wu, s_u.astype(np.float32), eyr, ey2)
        n_h = self.act_ms * n_u + self.up_ms * n_act + (self.hs * s_u) ** 2 / 12.0
        s_wd = (self.s_x_out / (2.0 ** sh_z * self.hs * s_u)).astype(np.float32)
        n_z = sub * (float((self.wd_col2 * n_h).sum()) + float((_cols_round_err(self.Wd, s_wd) * self.h_ms).sum())) \
            + g.d * self.s_x_out ** 2 / 12.0
        return n_z / self.z_sig, {"sh_z": sh_z}


# ============================================================ searches and the layer solver

def _shift_mode(var, glob):
    """(free, fixed shift dict). 'profile' shifts are free until the profile
    set is decided, then fixed."""
    if glob.shifts is not None:
        return False, dict(glob.shifts)
    return var.shifts in ("free", "profile"), dict(NATIVE_SHIFTS)


def norm_a_search(W, st, var, glob, s_x, cache):
    free, sh = _shift_mode(var, glob)
    key = ("a", glob.K_a, glob.e_s, round(s_x, 12), tuple(sorted(sh.items())) if glob.shifts else free)
    if key in cache:
        return cache[key]
    ga = W["input_layernorm.weight"].astype(np.float64)
    mats = [W["self_attn.q_proj.weight"], W["self_attn.k_proj.weight"], W["self_attn.v_proj.weight"]]
    best = None
    for i, s_qkv in enumerate((7, 8, 6) if free else (sh["qkv"],)):
        obj = AttnObjective(W, st, ga, var, s_qkv, sh["s"], sh["ao"], glob.e_s, free, s_x)
        try:
            g8, cn, K, info = choose_norm(ga, st["xa_max"], st["xa_ms"], mats, obj, var, glob.K_a,
                                          shapes=None if i == 0 else (best[4]["shape"],))
        except ValueError:
            continue
        if best is None or info["noise"] < best[4]["noise"]:
            best = (s_qkv, g8, cn, K, info)
    cache[key] = best
    return best


def layer_member(st, var, glob):
    if glob.silu is not None:
        return tuple(glob.silu)
    return silu_choice(gate_e_in(max(st["gate_pos"], st["gate_neg"]), var.m2), st["act_max"], var.m2)


def layer_sh_h(st, var, glob, member):
    free, sh = _shift_mode(var, glob)
    if not free:
        return sh["h"]
    # product shift: h's range bound no tighter than up's for 90% of channels
    upb = rb(st["up_max"], var.m, var.margin_ch)
    want = _l2(float(st["h_max"].max()) * var.m / float(np.quantile(upb, 0.1))) - member[1]
    return _clampw(int(math.ceil(want - 1e-9)), "h")


def norm_m_search(W, st, var, glob, member, s_x_out, cache):
    free, sh = _shift_mode(var, glob)
    sh_h = layer_sh_h(st, var, glob, member)
    key = ("m", glob.K_m, member, sh_h, round(s_x_out, 12), tuple(sorted(sh.items())) if glob.shifts else free)
    if key in cache:
        return cache[key]
    gm = W["post_attention_layernorm.weight"].astype(np.float64)
    mats = [W["mlp.gate_proj.weight"], W["mlp.up_proj.weight"]]
    best = None
    for i, s_g in enumerate((7, 8, 6, 5) if free else (sh["g"],)):
        obj = FfnObjective(W, st, gm, var, s_g, member, sh_h, sh["z"], free, s_x_out)
        g8, cn, K, info = choose_norm(gm, st["xm_max"], st["xm_ms"], mats, obj, var, glob.K_m,
                                      shapes=None if i == 0 else (best[5]["shape"],))
        if best is None or info["noise"] < best[5]["noise"]:
            best = (s_g, sh_h, g8, cn, K, info)
    cache[key] = best
    return best


def solve_layer(W, st, var, s_x: float, s_x_out: float, glob: Globals, cache: dict | None = None):
    """Build the integer block of one layer under the variant's constraints.
    `cache` (per layer, mutated) keeps the norm searches. Returns (LayerInt, rep)."""
    g, m, d = GEO, var.m, GEO.d
    cache = {} if cache is None else cache
    free, sh = _shift_mode(var, glob)
    rep = {"s_x": s_x, "s_x_out": s_x_out}
    k_r2 = int(round(math.log2(s_x_out / s_x)))
    if k_r2 < 0 or abs(s_x * 2 ** k_r2 - s_x_out) > 1e-9 * s_x_out:
        raise ValueError("the output scale must be s_x * 2^k, k >= 0")
    rep["sh_r2"] = k_r2
    ga = W["input_layernorm.weight"].astype(np.float64)
    gm = W["post_attention_layernorm.weight"].astype(np.float64)

    # ---------------- norm a (+ SH_QKV when free)
    res = norm_a_search(W, st, var, glob, s_x, cache)
    if res is None:
        raise ValueError("norm_a: no feasible configuration at this e_s")
    sh["qkv"], g_a, cn_a, K_a, info_a = res
    if glob.K_a is not None:
        cn_a = glob.cn_a
    rep["norm_a"] = info_a
    fold_a = ga * K_a / g_a.astype(np.float64)

    # ---------------- Q / K per (kv head, RoPE pair); scores; exp table
    Wq_e = W["self_attn.q_proj.weight"].astype(np.float64) * fold_a[None, :]
    Wk_e = W["self_attn.k_proj.weight"].astype(np.float64) * fold_a[None, :]
    Wv_e = W["self_attn.v_proj.weight"].astype(np.float64) * fold_a[None, :]
    qk = qk_scales(np.abs(Wq_e).max(1), np.abs(Wk_e).max(1), st, m, sh["qkv"], sh["s"], glob.e_s, free, var.margin_ch, var.m2)
    if qk is None:
        raise ValueError("score chain infeasible at the profile e_s")
    e_s, sh["s"], s_q, s_k = qk["e_s"], qk["sh_s"], qk["s_q"], qk["s_k"]
    rep["score"] = {"e_s": e_s, "e_s_range_need": qk["e_range"], "e_s_qk_need": _l2(qk["need_P"]) + sh["s"], "raw_max": qk["raw"],
                    "s_fill_calib": qk["raw"] / (127.0 * 2.0 ** e_s), "qk_slack_bits_mean": 2 * float(np.mean(np.log2(qk["slack"])))}
    wq = qw_rows(Wq_e, q_rows(s_q) / 2.0 ** sh["qkv"], rep, "wq")
    wk = qw_rows(Wk_e, k_rows(s_k) / 2.0 ** sh["qkv"], rep, "wk")
    exp_t, exp_d = exp_member(e_s, g.dh, F_E)

    # ---------------- V / O / Wo per kv channel: s_v,c s_wo,(h,c) 2^SH_AO = s_x
    Lv = np.maximum(rb(st["v_max"], m, var.margin_ch) / 127.0, (2.0 ** sh["qkv"]) * np.abs(Wv_e).max(1) / 127.0)
    Wo = W["self_attn.o_proj.weight"].astype(np.float64)
    wo_colmax = np.abs(Wo).max(0).reshape(g.KV, g.G, g.dh).max(1).reshape(-1)
    wo_col2 = (Wo ** 2).sum(0).reshape(g.KV, g.G, g.dh).sum(1).reshape(-1)
    o_ms_g = st["o_ms"].reshape(g.KV, g.G, g.dh).sum(1).reshape(-1)
    sy_a = float(np.sum(st["xa_ms"] * (g_a.astype(np.float64) / K_a) ** 2))
    s_v, sh["ao"], Uv = v_chain(Lv, wo_colmax, wo_col2, o_ms_g, sy_a, s_x, sh["qkv"], sh["ao"], free)
    rep["v_o"] = {"infeasible_channels": int((Lv > Uv).sum()),
                  "ao_floor": float(np.max((2.0 ** sh["ao"]) * Lv * wo_colmax / 127.0)),
                  "ao_floor_min_shift": float(np.max((2.0 ** WINDOW["ao"][0]) * Lv * wo_colmax / 127.0)),
                  "v_coarsening_bits_mean": float(np.mean(np.log2(s_v / Lv)))}
    wv = qw_rows(Wv_e, s_v / 2.0 ** sh["qkv"], rep, "wv")
    s_o = s_v * 2.0 ** (sh["o"] - F_P)
    wo = qw_cols(Wo, s_x / ((2.0 ** sh["ao"]) * np.repeat(s_o.reshape(g.KV, 1, g.dh), g.G, 1).reshape(-1)), rep, "wo")

    # ---------------- SiLU member, norm m (+ SH_G when free)
    e_in, e_out = layer_member(st, var, glob)
    sh["g"], sh["h"], g_m, cn_m, K_m, info_m = norm_m_search(W, st, var, glob, (e_in, e_out), s_x_out, cache)
    if glob.K_m is not None:
        cn_m = glob.cn_m
    rep["norm_m"] = info_m
    fold_m = gm * K_m / g_m.astype(np.float64)

    # ---------------- gate: scale pinned to 2^e_in
    Wg_e = W["mlp.gate_proj.weight"].astype(np.float64) * fold_m[None, :]
    s_wg = 2.0 ** (e_in - sh["g"])
    wg = qw_rows(Wg_e, np.full(Wg_e.shape[0], s_wg), rep, "wg")
    gmax = max(st["gate_pos"], st["gate_neg"])
    act_t, act_d = silu_member(e_in, e_out)
    rep["ffn"] = {"silu_member": [e_in, e_out], "gate_absmax": gmax, "gate_fill_calib": gmax / (127.0 * 2.0 ** e_in),
                  "wg_fill": float(np.abs(Wg_e).max() / (127.0 * s_wg)), "act_max": st["act_max"],
                  "act_saturates_above": float(32767 * 2.0 ** e_out) if int(act_t.max()) == 32767 else None}

    # ---------------- up / product / down per FFN channel j
    Wu_e = W["mlp.up_proj.weight"].astype(np.float64) * fold_m[None, :]
    hs = 2.0 ** (e_out + sh["h"])
    Lu = np.maximum.reduce([rb(st["up_max"], m, var.margin_ch) / 32767.0, np.abs(Wu_e).max(1) / 127.0,
                            np.full(Wu_e.shape[0], float(st["h_max"].max()) * m / (32767.0 * hs))])
    Wd = W["mlp.down_proj.weight"].astype(np.float64)
    wd_colmax = np.abs(Wd).max(0)
    sy_m = float(np.sum(st["xm_ms"] * (g_m.astype(np.float64) / K_m) ** 2))
    s_u, sh["z"], Uu = u_chain(Lu, wd_colmax, (Wd ** 2).sum(0), st["actc_ms"], st["h_ms"], sy_m, hs, s_x_out, sh["z"], free)
    rep["u_h_d"] = {"infeasible_channels": int((Lu > Uu).sum()),
                    "z_floor": float(np.max((2.0 ** sh["z"]) * hs * Lu * wd_colmax / 127.0)),
                    "z_floor_min_shift": float(np.max((2.0 ** WINDOW["z"][0]) * hs * Lu * wd_colmax / 127.0)),
                    "u_coarsening_bits_mean": float(np.mean(np.log2(s_u / Lu)))}
    wu = qw_rows(Wu_e, s_u, rep, "wu")
    s_h = hs * s_u
    wd = qw_cols(Wd, s_x_out / ((2.0 ** sh["z"]) * s_h), rep, "wd")

    ceps = max(1, int(round(d * g.eps / (s_x * s_x))))
    P_int = tc.LayerInt(
        wq=wq, wk=wk, wv=wv, wo=wo, gamma_a=g_a, gamma_m=g_m,
        wg_t=wg.T.copy(), wu_t=wu.T.copy(), wd_t=wd.T.copy(),
        exp=exp_t, act=act_t, cn_a=int(cn_a), cn_m=int(cn_m), tn=var.tn, ceps=ceps,
        norm_wrho=tc.norm_window(d, var.tn),
        sh_qkv=sh["qkv"], sh_rope=sh["rope"], sh_s=sh["s"], sh_o=sh["o"], sh_ao=sh["ao"],
        sh_g=sh["g"], sh_u=sh["u"], sh_h=sh["h"], sh_z=sh["z"], f_e=F_E, f_p=F_P, f_ro=F_RO, sh_r2=k_r2)
    P_int.e_s, P_int.silu, P_int.exp_digest, P_int.act_digest = e_s, (e_in, e_out), exp_d, act_d
    # diagnostic only (site_errors): per-row real scales of every integer plane
    P_int.diag = {"ya": K_a / g_a.astype(np.float64), "ym": K_m / g_m.astype(np.float64), "q": q_rows(s_q), "k": k_rows(s_k),
                  "v": s_v, "o": np.repeat(s_o.reshape(g.KV, 1, g.dh), g.G, 1).reshape(-1), "s": 2.0 ** e_s,
                  "gate": 2.0 ** e_in, "act": 2.0 ** e_out, "u": s_u, "h": s_h, "s_x": s_x, "s_x_out": s_x_out,
                  "gamma_a": ga, "gamma_m": gm}
    rep["shifts"] = dict(sh)
    rep["norm_consts"] = {"cn_a": int(cn_a), "cn_m": int(cn_m), "K_a": norm_K(int(cn_a), var.tn), "K_m": norm_K(int(cn_m), var.tn),
                          "ceps": ceps, "ceps_exact": d * g.eps / (s_x * s_x)}
    rep["metadata_scales"] = {
        "s_x_in": s_x, "s_x_out": s_x_out, "score_scale": 2.0 ** e_s, "gate_scale": 2.0 ** e_in, "act_scale": 2.0 ** e_out,
        "s_q": [float(s_q.min()), float(s_q.max())], "s_k": [float(s_k.min()), float(s_k.max())],
        "s_v": [float(s_v.min()), float(s_v.max())], "s_u": [float(s_u.min()), float(s_u.max())],
        "s_h": [float(s_h.min()), float(s_h.max())]}
    return P_int, rep

def site_errors(x_int: np.ndarray, P, rope_i, W, rope_f) -> dict:
    """Relative RMS error of every dequantized integer plane of one block
    against the float block run on the SAME dequantized input (so each number
    is this block's own error at that site, accumulated up to it). Diagnostic."""
    g = GEO
    N, T, d = x_int.shape
    tr = {}
    rec = tc.Rec(N)
    tc.i_block(x_int, P, rope_i, rec, trace=tr)
    D = P.diag
    xf = (x_int * D["s_x"]).astype(np.float32)
    _, F = _f_block_parts(xf, W, *rope_f, g)
    tri = np.tril(np.ones((T, T), dtype=bool))
    qr_f = tc.f_rope(F["q"], *rope_f)
    kr_f = tc.f_rope(F["k"], *rope_f)
    with np.errstate(over="ignore"):
        act_f = F["gt"] / (1.0 + np.exp(-F["gt"]))
    pf = None
    lg = np.where(tri, F["raw"] / np.float32(8.0), -np.inf).astype(np.float32)
    lg -= lg.max(-1, keepdims=True)
    pf = np.exp(lg)
    pf /= pf.sum(-1, keepdims=True)

    def rel(a, b, mask=None):
        a = np.asarray(a, dtype=np.float64)
        b = np.asarray(b, dtype=np.float64)
        if mask is not None:
            a, b = a[..., mask], b[..., mask]
        return float(np.linalg.norm(a - b) / max(np.linalg.norm(b), 1e-30))

    out = {
        "norm_a": rel(tr["y"] * D["ya"] * D["gamma_a"], F["xa"] * D["gamma_a"]),
        "q": rel(tr["q"].reshape(N, T, -1) * D["q"], F["q"].reshape(N, T, -1)),
        "k": rel(tr["k"].reshape(N, T, -1) * D["k"], F["k"].reshape(N, T, -1)),
        "v": rel(tr["v"].reshape(N, T, -1) * D["v"], F["v"].reshape(N, T, -1)),
        "qr": rel(tr["qr"].reshape(N, T, -1) * D["q"], qr_f.reshape(N, T, -1)),
        "kr": rel(tr["kr"].reshape(N, T, -1) * D["k"], kr_f.reshape(N, T, -1)),
        "score": rel(tr["s8"] * D["s"], F["raw"], tri),
        "prob": rel(tr["p"] / 2.0 ** F_P, pf, tri),
        "o": rel(tr["o8"] * D["o"], F["o"]),
        "ao": rel(tr["ao"] * D["s_x"], F["ao"]),
        "norm_m": rel(tr["nm"] * D["ym"] * D["gamma_m"], F["xm"] * D["gamma_m"]),
        "gate": rel(tr["g8"] * D["gate"], F["gt"]),
        "act": rel(tr["a16"] * D["act"], act_f),
        "up": rel(tr["u16"] * D["u"], F["up"]),
        "h": rel(tr["h16"] * D["h"], F["hh"]),
        "z": rel(tr["z16"] * D["s_x_out"], F["z"]),
        "x2": rel(tr["x2"] * D["s_x_out"], xf + F["ao"] + F["z"]),
        "update": rel(tr["x2"] * D["s_x_out"] - xf, F["ao"] + F["z"]),
        "refused_sequences": int(sum(f is not None for f in rec.first)),
    }
    return out

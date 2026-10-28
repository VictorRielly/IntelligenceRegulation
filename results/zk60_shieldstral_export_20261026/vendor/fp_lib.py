#!/usr/bin/env python3
"""Fidelity parity lane: the integer model of an export, a RELAXED block for
per-site error attribution, heads, corpora and metrics.

The integer model is read from a `zk60-trained-profile-export/1` directory
(words, constants, tables); nothing is re-solved. `rx_block` mirrors
`tlcalib.i_block` relation by relation. Every value is carried in float64 in
the LSB units of its own integer plane. A site in the EXACT set applies its
quantizer (round half up / floor / table lookup, then the class range check
with diagnostic clamping); a RELAXED site skips that quantizer and passes the
real value on in the same units. With every site exact the block equals
`tlcalib.i_block` bit for bit (checked by `fp_selfcheck.py`); with every site
relaxed it is the float block up to float rounding (the "all relaxed" control).

Relaxing a weight family replaces the int8 words by the real folded weights in
int8-LSB units (W_e / s, s fitted per output or input channel by least squares
against the words; only the scale axis the solver used).

Model selection: set ZK60_MODEL=llama3-8b in the environment before import
(as the calibration tools do); default TinyLlama.
Calibration/fidelity data only: not a proof, not a privacy claim.
"""

from __future__ import annotations

import os

for _k in ("OPENBLAS_NUM_THREADS", "OMP_NUM_THREADS", "MKL_NUM_THREADS", "NUMEXPR_NUM_THREADS"):
    os.environ.setdefault(_k, "4")

import hashlib  # noqa: E402
import json  # noqa: E402
import math  # noqa: E402
import site  # noqa: E402
import sys  # noqa: E402
import time  # noqa: E402
from pathlib import Path  # noqa: E402

import numpy as np  # noqa: E402

REPO = Path("/home/victor/IntelligenceRegulation")
CAL = Path(__file__).resolve().parent
C8 = REPO / "results" / "zk60_8b_calibration_20261017"
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(CAL))
import tlcalib as tc  # noqa: E402
import b3calib as b3  # noqa: E402

GEO = tc.GEO
MODEL = tc.MODEL_NAME
IS8B = MODEL == "llama3-8b"
BOS = 1
MASK = -127


def log(msg: str):
    print(f"[{time.strftime('%H:%M:%S', time.gmtime())}Z] {msg}", flush=True)


def sha_file(p: Path) -> str:
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for blk in iter(lambda: f.read(1 << 24), b""):
            h.update(blk)
    return h.hexdigest()


# ====================================================================== sites

# every quantizer of the integer block, in kernel order
SITES = ("emb", "norm", "y", "w_q", "w_k", "w_v", "q", "k", "v", "rope_tab", "qr", "kr", "s", "exp", "p", "o",
         "w_o", "ao", "nm", "w_g", "w_u", "gate", "up", "act", "h", "w_d", "z", "head")
FAMILIES = {
    "emb": {"emb"},
    "resid": {"emb", "ao", "z"},                                   # residual stream int16 at s_x
    "normq": {"norm", "y", "nm"},                                  # norm arithmetic + int8 norm outputs (QKV / gate-up inputs)
    "w_attn": {"w_q", "w_k", "w_v", "w_o"},
    "w_ffn": {"w_g", "w_u", "w_d"},
    "wts": {"w_q", "w_k", "w_v", "w_o", "w_g", "w_u", "w_d"},
    "qk": {"q", "k"},
    "v": {"v"},
    "rope": {"rope_tab", "qr", "kr"},
    "score": {"s"},
    "exp": {"exp"},
    "pdiv": {"p"},
    "o": {"o"},
    "gate": {"gate"},
    "act": {"act"},
    "uh": {"up", "h"},                                             # FFN int16 planes (up, product)
    "head": {"head"},
    "attn_core": {"q", "k", "v", "rope_tab", "qr", "kr", "s", "exp", "p", "o"},
    "softmax": {"s", "exp", "p"},
    "ffn_core": {"gate", "act", "up", "h"},
    "all": set(SITES),
}


def parse_relax(spec: str) -> frozenset:
    out = set()
    for tok in [t for t in (spec or "").split(",") if t]:
        if tok in FAMILIES:
            out |= FAMILIES[tok]
        elif tok in SITES:
            out.add(tok)
        else:
            raise ValueError(f"unknown site or family {tok}")
    return frozenset(out)


# ====================================================================== export

DT = {"int8": np.int8, "int16": np.int16, "int64": np.int64}


class Export:
    """Read-only view of a profile export (words verified against manifest sha256 on load)."""

    def __init__(self, root: Path, verify: bool = True):
        self.root = Path(root)
        self.prof = json.loads((self.root / "profile.json").read_text())
        meta = self.prof["metadata_out_of_proof"]
        self.T = int(self.prof["T"])
        self.L = len(self.prof["layers"])
        self.s_in = [float(s) for s in meta["residual_scales_in"]]
        self.s_out = [float(s) for s in meta["residual_scales_out"]]
        rot = meta["rotation"]
        self.R = b3.Rotation(GEO.d, int(rot["seed"]))
        raw = (self.root / "rotation_sign.bin").read_bytes()
        assert hashlib.sha256(raw).hexdigest() == rot["sign_sha256"], "rotation sign sha256"
        assert np.array_equal(self.R.sign, np.frombuffer(raw, dtype="<f8")), "rotation sign != Rotation(seed)"
        self.verify = verify

    def layer(self, l: int) -> dict:
        d = self.root / f"layer_{l:02d}"
        man = json.loads((d / "manifest.json").read_text())
        exp_sha = self.prof["layers"][l]["manifest_sha256"]
        assert sha_file(d / "manifest.json") == exp_sha, f"layer {l} manifest sha256"
        words = {}
        for name, a in man["arrays"].items():
            p = d / a["file"]
            raw = p.read_bytes()
            if self.verify:
                assert hashlib.sha256(raw).hexdigest() == a["sha256"], f"layer {l} {name} sha256"
            words[name] = np.frombuffer(raw, dtype=DT[a["dtype"]]).reshape(a["shape"])
        c = dict(man["constants"])
        c["e_s"] = int(man["tables"]["exp"]["e_s"])
        c["silu"] = tuple(man["tables"]["act"]["silu_member"])
        c["wrho"] = tc.norm_window(GEO.d, int(c["norm_tn"]))
        assert int(c.get("sh_r2", 0)) == 0, "residual-2 rescale not supported here"
        return {"w": words, "c": c, "manifest": man}

    def embedding_table(self):
        p = self.root / "embedding_int16.bin"
        if not p.exists():
            p = self.root / "token_io" / "embedding_int16.bin"
        return np.memmap(p, dtype="<i2", mode="r").reshape(-1, GEO.d)


# ====================================================================== checkpoint helpers

_CK = None


def checkpoint():
    global _CK
    if _CK is None:
        _CK = tc.open_checkpoint()
    return _CK


_MM = {}


def bf16_memmap(name: str) -> np.ndarray:
    """Read-only memmap of a pinned bf16 tensor. The tensor's sha256 pin is re-checked once per
    process (TensorRef.read_tile hashes the whole tensor; only 2 bytes are kept), then the
    bytes are mapped instead of copied (the 8B embedding / head are 1 GB each)."""
    if name not in _MM:
        _MM[name] = checkpoint().refs[name].bf16_rows()
    return _MM[name]


def emb_rows(ids: np.ndarray) -> np.ndarray:
    """float32 embedding rows (bf16 widened) for an id array of any shape."""
    raw = bf16_memmap("model.embed_tokens.weight")
    u = np.asarray(raw[ids.reshape(-1)]).astype(np.uint32) << 16
    return u.view(np.float32).reshape(*ids.shape, GEO.d)


def real_weights(W_rot: dict, Lw: dict) -> dict:
    """Real folded weights in int8-LSB units, export orientation: W_e / s with
    s fitted per scale channel by least squares against the words (clipped
    words excluded from the fit)."""
    c, w = Lw["c"], Lw["w"]
    K_a = b3.norm_K(int(c["norm_cn_a"]), int(c["norm_tn"]))
    K_m = b3.norm_K(int(c["norm_cn_m"]), int(c["norm_tn"]))
    fold_a = (K_a / w["gamma_a"].astype(np.float64)).astype(np.float32)
    fold_m = (K_m / w["gamma_m"].astype(np.float64)).astype(np.float32)
    out = {}

    g = GEO
    half = g.dh // 2
    hq = np.arange(g.H * g.dh)
    grp = {   # scale-sharing groups of the solver (b3calib q_rows / k_rows / wo columns / uniform gate)
        "wq": (hq // g.dh // g.G) * half + (hq % g.dh) % half,
        "wk": (np.arange(g.KV * g.dh) // g.dh) * half + (np.arange(g.KV * g.dh) % g.dh) % half,
        "wv": np.arange(g.KV * g.dh),
        "wo": (hq // g.dh // g.G) * g.dh + hq % g.dh,
        "wg_t": np.zeros(g.f, dtype=np.int64),
        "wu_t": np.arange(g.f),
        "wd_t": np.arange(g.f),
    }
    stats = {"ls_fallback_groups": 0}

    def fit(We, W8, axis, gid):
        """scale per index along `axis` (the axis that is NOT summed), shared
        within the solver's groups `gid`. The solver's word is floor(We/s + 0.5),
        so every unclipped entry bounds s: |We|/(|W|+0.5) <= s <= |We|/(|W|-0.5)
        (|W| >= 1), s >= 2|We| (W = 0). s = geometric middle of the group's
        feasible interval (least squares if empty)."""
        sumax = 1 - axis
        n_out = We.shape[axis]
        lo_i = np.zeros(n_out); hi_i = np.full(n_out, np.inf); num_i = np.zeros(n_out); den_i = np.zeros(n_out)
        for r0 in range(0, We.shape[0], 1024):      # row blocks: float64 temporaries stay small at 8B
            Eb = We[r0:r0 + 1024].astype(np.float64)
            Wb = W8[r0:r0 + 1024].astype(np.float64)
            a, w = np.abs(Eb), np.abs(Wb)
            use = w < 127
            lo_b = np.where(use, np.where(w >= 1, a / (w + 0.5), 2.0 * a), 0.0)
            hi_b = np.where(use & (w >= 1), a / np.maximum(w - 0.5, 0.5), np.inf)
            keep = use.astype(np.float64)
            nb, db = Eb * Wb * keep, Wb * Wb * keep
            if axis == 0:
                sl = slice(r0, r0 + Eb.shape[0])
                lo_i[sl] = lo_b.max(1); hi_i[sl] = hi_b.min(1); num_i[sl] = nb.sum(1); den_i[sl] = db.sum(1)
            else:
                lo_i = np.maximum(lo_i, lo_b.max(0)); hi_i = np.minimum(hi_i, hi_b.min(0))
                num_i += nb.sum(0); den_i += db.sum(0)
            del Eb, Wb, a, w, use, lo_b, hi_b, keep, nb, db
        ng = int(gid.max()) + 1
        lo = np.zeros(ng); hi = np.full(ng, np.inf); num = np.zeros(ng); den = np.zeros(ng)
        np.maximum.at(lo, gid, lo_i); np.minimum.at(hi, gid, hi_i)
        np.add.at(num, gid, num_i); np.add.at(den, gid, den_i)
        ok = (lo <= hi * (1 + 1e-6)) & np.isfinite(hi) & (lo > 0)
        ls = np.where(den > 0, num / np.maximum(den, 1e-30), np.where(lo > 0, lo, 1.0))
        s_g = np.where(ok, np.sqrt(np.maximum(lo, 1e-300) * np.where(np.isfinite(hi), hi, 1.0)), ls)
        stats["ls_fallback_groups"] += int((~ok).sum())
        s = s_g[gid]
        shape = (-1, 1) if axis == 0 else (1, -1)
        return (We / s.reshape(shape).astype(np.float32)).astype(np.float32), s

    rep = {}
    for n in ("q", "k", "v"):
        We = (W_rot[f"self_attn.{n}_proj.weight"] * fold_a[None, :]).astype(np.float32)   # (out, in)
        out[f"w{n}"], s = fit(We, w[f"w{n}"], 0, grp[f"w{n}"])
    out["wo"], _ = fit(W_rot["self_attn.o_proj.weight"].astype(np.float32), w["wo"], 1, grp["wo"])  # per input column
    for n, key in (("g", "gate"), ("u", "up")):
        We = (W_rot[f"mlp.{key}_proj.weight"] * fold_m[None, :]).T.astype(np.float32)   # (in d, out f)
        out[f"w{n}_t"], _ = fit(np.ascontiguousarray(We), w[f"w{n}_t"], 1, grp[f"w{n}_t"])
    We = np.ascontiguousarray(W_rot["mlp.down_proj.weight"].T.astype(np.float32))       # (in f, out d)
    out["wd_t"], _ = fit(We, w["wd_t"], 0, grp["wd_t"])
    # sanity: the real weights round back to the words (up to fit noise at .5 boundaries)
    for k, Wr in out.items():
        frac = float(np.mean(np.clip(np.floor(Wr + 0.5), -127, 127) != w[k]))
        rep[f"{k}_reround_mismatch"] = frac
        assert frac < 1e-3, f"{k}: real weights do not round back to the words ({frac})"
    rep.update(stats)
    return out, rep


# ====================================================================== relaxed block

def _rnd(v):
    return np.floor(v + 0.5)


class Mat:
    """x @ M for M (inner, out) given as int8 words or float32 real weights;
    float64 accumulation, blocked over output columns for large matrices."""

    BLOCK = 2048

    def __init__(self, m):
        self.m = m
        self.big = m.size > 16 * 1024 * 1024
        self.m64 = None if self.big else m.astype(np.float64)

    def __call__(self, x):
        sh = x.shape
        x2 = x.reshape(-1, sh[-1])
        if not self.big:
            y = x2 @ self.m64
        else:
            y = np.empty((x2.shape[0], self.m.shape[1]), dtype=np.float64)
            for c0 in range(0, self.m.shape[1], self.BLOCK):
                y[:, c0:c0 + self.BLOCK] = x2 @ self.m[:, c0:c0 + self.BLOCK].astype(np.float64)
        return y.reshape(*sh[:-1], -1)


class LayerModel:
    """One layer: words, constants, prepared matrices (int8 and optionally real)."""

    def __init__(self, Lw: dict, T: int, Wreal: dict | None = None, mods: frozenset = frozenset()):
        self.c, self.w = Lw["c"], Lw["w"]
        # what-if relation changes (NOT native today): "pround" = softmax division rounded half up
        # (2 E 2^F_P + Sum = 2 Sum p + rho, 0 <= rho < 2 Sum) instead of floor
        self.mods = frozenset(mods)
        w = self.w
        self.int = {"q": Mat(np.ascontiguousarray(w["wq"].T)), "k": Mat(np.ascontiguousarray(w["wk"].T)),
                    "v": Mat(np.ascontiguousarray(w["wv"].T)), "o": Mat(np.ascontiguousarray(w["wo"].T)),
                    "g": Mat(w["wg_t"]), "u": Mat(w["wu_t"]), "d": Mat(w["wd_t"])}
        self.real = None
        if Wreal is not None:
            self.real = {"q": Mat(np.ascontiguousarray(Wreal["wq"].T)), "k": Mat(np.ascontiguousarray(Wreal["wk"].T)),
                         "v": Mat(np.ascontiguousarray(Wreal["wv"].T)), "o": Mat(np.ascontiguousarray(Wreal["wo"].T)),
                         "g": Mat(Wreal["wg_t"]), "u": Mat(Wreal["wu_t"]), "d": Mat(Wreal["wd_t"])}
        c = self.c
        half = GEO.dh // 2
        self.rope_int = (w["rope_cos"].reshape(T, half).astype(np.float64), w["rope_sin"].reshape(T, half).astype(np.float64))
        cos, sin = tc.rope_f32(T)   # float32 like the float model
        sc = float(1 << int(c["f_ro"]))
        self.rope_real = (cos.astype(np.float64) * sc, sin.astype(np.float64) * sc)
        self.exp_t = w["exp"].astype(np.float64)
        self.act_t = w["act"].astype(np.float64)
        self.lam = (2.0 ** c["e_s"]) / math.sqrt(GEO.dh)

    def mat(self, name, exact):
        if exact:
            return self.int[name]
        if self.real is None:
            raise ValueError("relaxed weights need the real weights (Wreal)")
        return self.real[name]


class RecPos(tc.Rec):
    """tlcalib.Rec that also records WHERE each violation is: (sequence, token position).
    Position axis by shape: (N, T, ...) -> axis 1; attention planes (N, KV, G, T, *) -> axis 3."""

    def __init__(self, n_seq: int):
        super().__init__(n_seq)
        self.where = {}          # (site, seq, pos) -> count

    def check(self, site, val, lo, hi, seq0, clamp=True, extra_bad=None):
        bad = (val < lo) | (val > hi)
        if extra_bad is not None:
            bad = bad | extra_bad
        if bad.any():
            b = bad.reshape(bad.shape[0], bad.shape[1], -1).any(-1) if bad.ndim in (3, 4) else \
                bad.reshape(bad.shape[:4] + (-1,)).any(-1).any(1).any(1) if bad.ndim == 5 else bad.reshape(bad.shape[0], -1)
            for i, t in zip(*np.nonzero(b)):
                k = (site, seq0 + int(i), int(t))
                self.where[k] = self.where.get(k, 0) + 1
        return super().check(site, val, lo, hi, seq0, clamp=clamp, extra_bad=extra_bad)


def _chk(rec, site, v, lo, hi, seq0, exact, extra_bad=None):
    if not exact or rec is None:
        return v
    return rec.check(site, v, lo, hi, seq0, clamp=True, extra_bad=extra_bad)


def rx_norm(x, g8, cn, tn, ceps, wrho, ex_norm, ex_y, rec, site, seq0, ky=0):
    """y = round(x g Cn / (D 2^tn)), D = isqrt(Ceps + sum x^2). Exact path on
    integer x uses int64 (== tlcalib.i_norm). ky > 0 (WHAT-IF, not native): the
    norm output class is int(8+ky): y = round(x g Cn 2^ky / (D 2^tn)), range +-(2^(7+ky) - 1)."""
    integer_x = ex_norm and bool(np.all(x == np.floor(x)))
    if ky and integer_x and ex_y:
        xi = x.astype(np.int64)
        ss = ceps + (xi * xi).sum(-1)
        D = np.maximum(tc.isqrt_vec(ss), 1)
        dv = (D << tn)[..., None]
        num = 2 * xi * (g8.astype(np.int64) * cn << ky)[None, None, :] + dv
        q = (num // (2 * dv)).astype(np.float64)
        lim = (1 << (7 + ky)) - 1
        return _chk(rec, f"{site} quotient/remainder", q, -lim, lim, seq0, True)
    if integer_x and ex_y:
        xi = x.astype(np.int64)
        q, _ = tc.i_norm(xi, g8, cn, tn, ceps, wrho, rec if rec is not None else tc.Rec(x.shape[0]), site, seq0, True)
        return q.astype(np.float64)
    ss = ceps + (x * x).sum(-1)
    D = np.floor(np.sqrt(ss)) if ex_norm else np.sqrt(ss)
    D = np.maximum(D, 1.0)
    yv = x * (g8.astype(np.float64) * cn * 2.0 ** ky)[None, None, :] / (D[..., None] * float(1 << tn))
    if ex_y:
        yv = _rnd(yv)
        lim = (1 << (7 + ky)) - 1
        yv = _chk(rec, f"{site} quotient/remainder", yv, -lim, lim, seq0, True)
    return yv


def rq(acc, sh, exact):
    if sh < 0:                      # width what-ifs only: a finer output than the accumulator (exact integer scaling)
        return acc * float(1 << -sh)
    v = acc / float(1 << sh) if sh else acc
    return _rnd(v) if exact else v


def mm_rq(M, name, x, wexact, sh, exact):
    """matmul + requant; with a (c2) per-output-channel public multiplier m_j of b bits on this site:
    out_j = round(m_j acc_j / 2^(sh + b)) (WHAT-IF, not native today)."""
    acc = M.mat(name, wexact)(x)
    mult = getattr(M, "mult", None)
    if mult and name in mult:
        m, b = mult[name]
        return rq(acc * m, sh + b, exact)
    return rq(acc, sh, exact)


def rope_apply(x, c, s):
    half = x.shape[-1] // 2
    a, b = x[..., :half], x[..., half:]
    cc, ss = c[None, :, None, :], s[None, :, None, :]
    return np.concatenate([cc * a - ss * b, ss * a + cc * b], axis=-1)


def _modk(M, prefix):
    """integer argument of a width what-if in M.mods (e.g. 'a8' -> 8 for prefix 'a'); 0 if absent."""
    for m in M.mods:
        if m.startswith(prefix) and m[len(prefix):].isdigit() and not (prefix == "s" and m.startswith("sh")):
            return int(m[len(prefix):])
    return 0


def rx_block(x, M: LayerModel, exact: frozenset, rec=None, seq0: int = 0, trace: dict | None = None):
    """The native block relations with per-site quantizers on/off (see module doc).
    WIDTH WHAT-IFS (M.mods, not native today): yK norm outputs int(8+K); fpN F_P = N; aK attention words
    (q, k, v, qr, kr, o) int(8+K) at a 2^K finer scale; gK SiLU input int(8+K) at a 2^K finer step (table of
    2^(8+K) rows); oK SiLU output 2^K finer; hK product h int(16+K) 2^K finer; sK score word int(8+K) 2^K
    finer (exp table over 2^(8+K) differences); ahJ spends J of the aK bits on range instead (attention words
    stay int(8+K) but are only 2^(K-J) finer: J bits of headroom, zero proof cost). Consumer shifts absorb every
    change, so real scales downstream are unchanged. With no mods the block is tlcalib.i_block bit for bit."""
    E = lambda s: s in exact  # noqa: E731
    g = GEO
    c = M.c
    x = np.asarray(x, dtype=np.float64)
    N, T, d = x.shape
    ky = _modk(M, "y")
    f_p = next((int(m[2:]) for m in M.mods if m.startswith("fp") and m[2:].isdigit()), int(c["f_p"]))
    ka, kg, ko, kh, ks = _modk(M, "a"), _modk(M, "g"), _modk(M, "o"), _modk(M, "h"), _modk(M, "s")
    kf = ka - _modk(M, "ah")                              # attention fineness (ka minus headroom bits)
    sh_o = int(c["sh_o"]) + f_p - int(c["f_p"])          # o comes out 2^ka finer on its own (v is 2^ka finer)
    I16 = (-32768, 32767)
    LA = (1 << (7 + ka)) - 1
    LS = (1 << (7 + ks)) - 1
    y = rx_norm(x, M.w["gamma_a"], int(c["norm_cn_a"]), int(c["norm_tn"]), int(c["norm_ceps"]), c["wrho"],
                E("norm"), E("y"), rec, "norm_a", seq0, ky)
    q = _chk(rec, "Q", mm_rq(M, "q", y, E("w_q"), c["sh_qkv"] + ky - kf, E("q")), -LA, LA, seq0, E("q"))
    k = _chk(rec, "K", mm_rq(M, "k", y, E("w_k"), c["sh_qkv"] + ky - kf, E("k")), -LA, LA, seq0, E("k"))
    v = _chk(rec, "V", mm_rq(M, "v", y, E("w_v"), c["sh_qkv"] + ky - kf, E("v")), -LA, LA, seq0, E("v"))
    cr, sr = M.rope_int if E("rope_tab") else M.rope_real
    qr = _chk(rec, "QR", rq(rope_apply(q.reshape(N, T, g.H, g.dh), cr, sr), c["sh_rope"], E("qr")), -LA, LA, seq0, E("qr"))
    kr = _chk(rec, "KR", rq(rope_apply(k.reshape(N, T, g.KV, g.dh), cr, sr), c["sh_rope"], E("kr")), -LA, LA, seq0, E("kr"))
    qg = qr.reshape(N, T, g.KV, g.G, g.dh).transpose(0, 2, 3, 1, 4)
    kg_ = kr.transpose(0, 2, 3, 1)[:, :, None]
    sacc = qg @ kg_                                                    # (N,KV,G,T,T)
    s = _chk(rec, "score", rq(sacc, c["sh_s"] + 2 * kf - ks, E("s")), -LS, LS, seq0, E("s"))
    tri = np.tril(np.ones((T, T), dtype=bool))
    if E("s"):
        masked = np.where(tri, s, -float(LS))
        best = masked.max(-1, keepdims=True)
        delta = best - masked
    else:
        best = np.where(tri, s, -np.inf).max(-1, keepdims=True)
        delta = np.where(tri, best - s, 0.0)
    if E("s") and E("exp") and ks == 0:
        delta = _chk(rec, "exp difference", delta, 0, M.exp_t.shape[0] - 1, seq0, True)
        Ev = M.exp_t[delta.astype(np.int64)]
    else:
        if E("s") and E("exp"):
            delta = _chk(rec, "exp difference", delta, 0, (1 << (8 + ks)) - 1, seq0, True)
        Ev = float(1 << int(c["f_e"])) * np.exp(-delta * M.lam / float(1 << ks))
        if E("exp"):
            Ev = _rnd(Ev)
    Ev = np.where(tri, Ev, 0.0)
    total = Ev.sum(-1, keepdims=True)
    if E("exp"):
        total = _chk(rec, "softmax denominator", total, 1 << int(c["f_e"]), T << int(c["f_e"]), seq0, True)
    p = Ev * float(1 << f_p) / total
    if E("p"):
        p = np.floor(p + 0.5) if "pround" in M.mods else np.floor(p)
        p = _chk(rec, "softmax quotient/remainder", p, 0, 1 << f_p, seq0, True)
    vg = v.reshape(N, T, g.KV, g.dh).transpose(0, 2, 1, 3)[:, :, None]
    oacc = p @ vg                                                       # (N,KV,G,T,dh)
    o = _chk(rec, "O", rq(oacc, sh_o, E("o")), -LA, LA, seq0, E("o"))
    o8 = o.transpose(0, 3, 1, 2, 4).reshape(N, T, g.H * g.dh)
    ao = _chk(rec, "AO", mm_rq(M, "o", o8, E("w_o"), c["sh_ao"] + kf, E("ao")), *I16, seq0, E("ao"))
    x1 = x + ao
    if E("ao") and E("emb"):
        x1 = _chk(rec, "residual 1", x1, *I16, seq0, True)
    nm = rx_norm(x1, M.w["gamma_m"], int(c["norm_cn_m"]), int(c["norm_tn"]), int(c["norm_ceps"]), c["wrho"],
                 E("norm"), E("nm"), rec, "norm_m", seq0, ky)
    u = _chk(rec, "FFN up", mm_rq(M, "u", nm, E("w_u"), c["sh_u"] + ky, E("up")), *I16, seq0, E("up"))
    e_in, e_out = c["silu"]
    GL, GH = -(1 << (7 + kg)), (1 << (7 + kg)) - 1
    AL = 32767 * (1 << ko)
    if getattr(M, "gate_pc", None) is not None:
        # WHAT-IF (not native): per-channel-group SiLU tables. Channel j quantizes the gate at its own
        # 2^(e_j - kg) and looks up silu at its own output step 2^(eo_j - ko); handed on in the layer's act units
        # (a per-column Wd scale would absorb it natively).
        ej, eoj, tabs, sat = M.gate_pc
        gt = mm_rq(M, "g", nm, E("w_g"), c["sh_g"] + ky, False)          # unrounded, units 2^e_in
        xg = gt * (2.0 ** e_in)
        g8 = _rnd(xg / (2.0 ** (ej - kg)))
        if sat:
            g8 = np.maximum(g8, float(GL))
        g8 = _chk(rec, "FFN gate", g8, GL, GH, seq0, True)
        if kg == 0 and ko == 0:
            idx = g8.astype(np.int64) + 128
            a = tabs[np.arange(len(ej))[None, None, :], idx]
        else:
            zin = g8 * (2.0 ** (ej - kg))
            with np.errstate(over="ignore"):
                a = np.clip(_rnd(zin / (1.0 + np.exp(-zin)) / (2.0 ** (eoj - ko))), -AL, AL)
        a = a * (2.0 ** (eoj - e_out))                                     # units 2^(e_out - ko)
    elif kg == 0 and ko == 0:
        gt = _chk(rec, "FFN gate", mm_rq(M, "g", nm, E("w_g"), c["sh_g"] + ky, E("gate")), -128, 127, seq0, E("gate"))
        if E("gate") and E("act"):
            a = M.act_t[gt.astype(np.int64) + 128]
        else:
            z_in = gt * (2.0 ** e_in)
            with np.errstate(over="ignore"):
                a = z_in / (1.0 + np.exp(-z_in)) / (2.0 ** e_out)
            if E("act"):
                a = np.clip(_rnd(a), -32767, 32767)
    else:
        gt = _chk(rec, "FFN gate", mm_rq(M, "g", nm, E("w_g"), c["sh_g"] + ky - kg, E("gate")), GL, GH, seq0, E("gate"))
        z_in = gt * (2.0 ** (e_in - kg))
        with np.errstate(over="ignore"):
            a = z_in / (1.0 + np.exp(-z_in)) / (2.0 ** (e_out - ko))
        if E("act"):
            a = np.clip(_rnd(a), -AL, AL)
    HL, HH = -(1 << (15 + kh)), (1 << (15 + kh)) - 1
    h = _chk(rec, "FFN product", rq(a * u, c["sh_h"] + ko - kh, E("h")), HL, HH, seq0, E("h"))
    z = _chk(rec, "FFN down", mm_rq(M, "d", h, E("w_d"), c["sh_z"] + kh, E("z")), *I16, seq0, E("z"))
    x2 = x1 + z
    if E("z") and E("ao") and E("emb"):
        x2 = _chk(rec, "residual 2", x2, *I16, seq0, True)
    if trace is not None:
        trace.update({"y": y, "q": q, "k": k, "v": v, "s": s, "p": p, "o8": o8, "ao": ao, "x1": x1, "nm": nm, "g8": gt,
                      "u16": u, "a16": a, "h16": h, "z16": z, "x2": x2})
    return x2


def gate_groups(st: dict, e_min: int = -5, mc: float = 2.0, m2: float = 1.25, sat: bool = False, ngroups: int | None = None):
    """WHAT-IF per-channel-group SiLU members from the calibration statistics of one
    layer: e_j = the finest e_in in [e_min, -1] with 127 2^e >= bound_j, bound_j =
    min(mc * channel max, m2 * tensor max) of |gate| (positive side only with
    negative saturation), e_out the registry's finest non-saturating member
    (e_in - 8 below the registry). ngroups caps the distinct tables per layer (native: groups x 4096 rows <= 2^log_cols
    with SiLU input int12, i.e. <= 4 groups at T128, <= 8 at T512; r11 ACTIVATION_COST.md section 4): the finest e_in
    values merge into the ngroups-th coarsest (coarser = more range) and each e_in group takes ONE output member, the
    coarsest any of its channels needs. Returns (e_j, eo_j, tables (f, 256), sat, report)."""
    sys.path.insert(0, str(CAL))
    gm = np.asarray(st["gate_max"], dtype=np.float64)
    tmax = max(st["gate_pos"], 0.0) if sat else max(st["gate_pos"], st["gate_neg"])
    bound = np.minimum(mc * gm, m2 * tmax)
    am = np.asarray(st["actc_max"], dtype=np.float64)
    amb = np.minimum(mc * am, m2 * float(st["act_max"]))
    ej = np.full(gm.shape, -1, dtype=np.int64)
    for e in range(-1, e_min - 1, -1):
        ej = np.where(127.0 * 2.0 ** e >= bound, e, ej)
    if ngroups:
        ue = sorted(np.unique(ej).tolist(), reverse=True)              # coarsest first
        if len(ue) > ngroups:
            ej = np.maximum(ej, ue[ngroups - 1])
    cache, eoj = {}, np.zeros_like(ej)
    for e in np.unique(ej):
        outs = sorted(eo for (ei, eo) in b3.SILU_MEMBERS if ei == e) or [int(e) - 8]
        for j in np.nonzero(ej == e)[0]:
            eo = next((o for o in outs if amb[j] <= 32767 * 2.0 ** o), outs[-1])
            eoj[j] = eo
        if ngroups:
            eoj[ej == e] = eoj[ej == e].max()
    tabs = np.zeros((len(ej), 256))
    for key in set(zip(ej.tolist(), eoj.tolist())):
        if key not in cache:
            cache[key] = b3.silu_generate(*key).astype(np.float64)
        sel = (ej == key[0]) & (eoj == key[1])
        tabs[sel] = cache[key][None, :]
    rep = {"members": {f"{k[0]},{k[1]}": int(((ej == k[0]) & (eoj == k[1])).sum()) for k in cache},
           "outside_registry": int(sum(1 for k in cache if k not in b3.SILU_DIGESTS))}
    return ej, eoj, tabs, sat, rep


MULT_SITES = {"q": ("wq", 0, "sh_qkv", 16), "k": ("wk", 0, "sh_qkv", 16), "v": ("wv", 0, "sh_qkv", 16),
              "o": ("wo", 0, "sh_ao", 16), "g": ("wg_t", 1, "sh_g", 16), "u": ("wu_t", 1, "sh_u", 8),
              "d": ("wd_t", 1, "sh_z", 16)}


def apply_multipliers(Lw: dict, Wreal: dict, bits: dict):
    """(c2) WHAT-IF: narrow per-output-channel public multipliers. For site s with b bits (capped so that
    sh + b fits the site's window: 16 = two bytes, 8 at up): m_j = clip(ceil(2^b rowmax_j / 127), 1, 2^b),
    words W8'_j = round(W_real_j 2^b / m_j) (every channel's largest word near 127 when m_j is large),
    out_j = round(m_j acc'_j / 2^(sh + b)) = the same output scale. Returns (new words, mult dict, report)."""
    w = dict(Lw["w"])
    mult, rep = {}, {}
    for site, b in bits.items():
        key, out_axis, shkey, hi = MULT_SITES[site]
        b_eff = min(int(b), hi - int(Lw["c"][shkey]))
        if b_eff <= 0:
            rep[site] = {"bits": 0}
            continue
        Wr = Wreal[key].astype(np.float64)
        rowmax = np.abs(Wr).max(axis=1 - out_axis)
        m = np.clip(np.ceil((2.0 ** b_eff) * rowmax / 127.0), 1, 2 ** b_eff)
        f = (2.0 ** b_eff) / m
        Wn = Wr * (f[:, None] if out_axis == 0 else f[None, :])
        w[key] = np.clip(np.floor(Wn + 0.5), -127, 127).astype(np.int8)
        mult[site] = (m.astype(np.float64), b_eff)
        med_before = float(np.median(np.abs(Lw["w"][key].astype(np.int16)).max(axis=1 - out_axis)))
        med_after = float(np.median(np.abs(w[key].astype(np.int16)).max(axis=1 - out_axis)))
        rep[site] = {"bits": b_eff, "median_channel_max_word": [med_before, med_after]}
    return w, mult, rep


# ====================================================================== heads

class FloatHead:
    """Final RMSNorm (float32) + LM head (float32, vocab-blocked) on the UNROTATED float residual."""

    def __init__(self, block: int = 8192):
        ck = checkpoint()
        ref = ck.refs["lm_head.weight"]
        self.raw = bf16_memmap("lm_head.weight")
        self.norm = tc.tensor_f32(ck.refs["model.norm.weight"])
        self.V = ref.shape[0]
        self.block = block
        self.small = self.V * GEO.d <= 80 * 1024 * 1024
        self.W = (np.asarray(self.raw).astype(np.uint32) << 16).view(np.float32) if self.small else None

    def hidden(self, x):            # x (P, d) float32 unrotated residual
        return tc.f_xhat(x.astype(np.float32), GEO.eps) * self.norm

    def logit_blocks(self, x):
        h = self.hidden(x)
        for v0 in range(0, self.V, self.block):
            w = self.W[v0:v0 + self.block] if self.small else (np.asarray(self.raw[v0:v0 + self.block]).astype(np.uint32) << 16).view(np.float32)
            yield v0, (h @ w.T).astype(np.float64)


class IntHead:
    """D25 T4 integer head (b8_token_io rule): final norm with uniform gain 127,
    per-row int8 head words W'' of W' = lm_head diag(norm_w) R^T, 12-bit
    multipliers. Real logits = m_j (y . W''_j) K s_max / (127 2^12)."""

    def __init__(self, R, s_out: float, tn: int, ceps: int, cn: int, block: int = 8192, cache: Path | None = None):
        ck = checkpoint()
        raw = bf16_memmap("lm_head.weight")
        nw = tc.tensor_f32(ck.refs["model.norm.weight"]).astype(np.float64)
        self.V = raw.shape[0]
        if cache is not None and cache.exists():
            z = np.load(cache)
            self.Wr, self.s_r = z["Wr"], z["s_r"]
        else:
            self.Wr = np.empty((self.V, GEO.d), dtype=np.int8)
            self.s_r = np.empty(self.V)
            for v0 in range(0, self.V, 8192):
                Wp = R.fwd((np.asarray(raw[v0:v0 + 8192]).astype(np.uint32) << 16).view(np.float32).astype(np.float64) * nw[None, :])
                s = np.abs(Wp).max(1) / 127.0
                self.Wr[v0:v0 + 8192] = np.clip(np.floor(Wp / s[:, None] + 0.5), -127, 127).astype(np.int8)
                self.s_r[v0:v0 + 8192] = s
            if cache is not None:
                tmp = cache.with_name(cache.stem + f".tmp{os.getpid()}.npz")
                np.savez(tmp, Wr=self.Wr, s_r=self.s_r)
                os.replace(tmp, cache)
        self.mult = np.maximum(1, np.floor(4096.0 * self.s_r / self.s_r.max() + 0.5))
        self.tn, self.ceps, self.cn = tn, ceps, cn
        self.wrho = tc.norm_window(GEO.d, tn)
        self.K = b3.norm_K(cn, tn)
        self.scale = self.K * float(self.s_r.max()) / (127.0 * 4096.0)
        self.block = block
        self.s_out = s_out

    def logit_blocks(self, x_lsb, rec=None):
        """x_lsb (P, d) residual in s_out LSB units (rounded to int16 first)."""
        xi = np.clip(np.floor(x_lsb + 0.5), -32768, 32767).astype(np.int64)
        g = np.full(GEO.d, 127, dtype=np.int8)
        r = rec if rec is not None else tc.Rec(1)
        y, _ = tc.i_norm(xi[None], g, self.cn, self.tn, self.ceps, self.wrho, r, "final_norm", 0, True)
        y = y[0].astype(np.float64)
        for v0 in range(0, self.V, self.block):
            C = (y @ self.Wr[v0:v0 + self.block].astype(np.float64).T) * self.mult[None, v0:v0 + self.block]
            yield v0, C * self.scale


def stream_metrics(blocks_f, blocks_i, tgt):
    """One pass over vocab blocks of float and int logits (same positions):
    per position NLL float / int, argmax float / int, KL(float || int)."""
    P = tgt.shape[0]
    mf = np.full(P, -np.inf); mi = np.full(P, -np.inf)
    sf = np.zeros(P); si = np.zeros(P)
    A = np.zeros(P)
    af = np.zeros(P, dtype=np.int64); ai = np.zeros(P, dtype=np.int64)
    tf = np.zeros(P); ti = np.zeros(P)
    for (v0, lf), (v1, li) in zip(blocks_f, blocks_i):
        assert v0 == v1
        nb = lf.shape[1]
        bf, bi = lf.max(1), li.max(1)
        af = np.where(bf > mf, v0 + lf.argmax(1), af)
        ai = np.where(bi > mi, v0 + li.argmax(1), ai)
        nmf, nmi = np.maximum(mf, bf), np.maximum(mi, bi)
        rf = np.exp(mf - nmf)
        ef = np.exp(lf - nmf[:, None])
        sf = sf * rf + ef.sum(1)
        A = A * rf + (ef * (lf - li)).sum(1)
        si = si * np.exp(mi - nmi) + np.exp(li - nmi[:, None]).sum(1)
        mf, mi = nmf, nmi
        inb = (tgt >= v0) & (tgt < v0 + nb)
        tf[inb] = lf[inb, tgt[inb] - v0]
        ti[inb] = li[inb, tgt[inb] - v0]
    lsef, lsei = mf + np.log(sf), mi + np.log(si)
    return {"nll_f": lsef - tf, "nll_i": lsei - ti, "arg_f": af, "arg_i": ai, "kl": A / sf + lsei - lsef}

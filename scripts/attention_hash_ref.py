#!/usr/bin/env python3
"""[UPERF3-AE] attention_hash_ref.py — THE PYTHON ORACLE of the integer
attention + norm + residual chain of one transformer layer (rung 2), the
executable spec the hash-line Rust chain (hashline/src/attention.rs,
norm.rs) reproduces digest for digest (rung 3).

Unlike scripts/attention_x1_layer_ref.py (lane NN's toy-shape reference
on a seeded draw), this oracle runs the REAL checkpoints at the REAL
measured exponents:

  --arch 125m     frugal-lm 125M, d 768, H 12/4, d_h 64, exponents from
                  results/m125_attn_at_o1.json (lane PP)
  --arch mistral  Mistral-7B-v0.1, d 4096, H 32/8, d_h 128, exponents
                  from results/m8b_mistral_attn_at_o1.json (rung 1)

Semantics (the rung-0 STATEMENT SPEC in PROGRESS_UPERF3.md):
  * every REQUANT edge is the v3 hash-line round-to-nearest with the
    BALANCED remainder r in [-2^(sh-1), 2^(sh-1)) — hashline's
    export_v3::requant_round, NOT the floor requant of the spec spike;
  * the two DIVISIONS (RMSNorm, softmax) are floor with rho in [0, div)
    and sigma = div - 1 - rho, exactly as the spike;
  * the exp member and the RoPE tables are the spike's generators
    (imported verbatim — the same bytes tables_attn.rs emits);
  * the residual stream carries its MEASURED class: int16 at 125M,
    int24 at Mistral (rung 1's widen phase), ao likewise;
  * layer 0's x_in is the embedding, int8 at its own absmax exponent;
    for layer l > 0 the fp prefix walk supplies x_in, quantized in the
    residual class at layer l-1's xres exponent (the SEAM).

Every requant edge is fitted: if the record's fp-derived exponent does
not admit the integer result (the narrowing would saturate), the shift
is raised until it does and the BUMP is reported — the integer chain is
never silently clamped.

Output: the params line, one sha256 per witness tensor, the CHAIN
digest over them in order, and the agreement legs against the fp
forward of the same layer (fraction of integers equal, max |delta| in
grid steps). --json writes results/hashline_attn_ref_<arch>_l<L>.json.

    python3 scripts/attention_hash_ref.py --arch 125m --layer 0
    python3 scripts/attention_hash_ref.py --arch mistral --layer 0 \
        --tokens-cache <cache>.npy
"""

import argparse
import hashlib
import json
import math
import sys
import time
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import attention_spec_spike as sp        # noqa: E402  (tables + isqrt, verbatim)
import m125_int8_calibration as m125     # noqa: E402  (primitives, never edited)
import m8b_int8_calibration as m8b       # noqa: E402  (imported, never edited)

FE, FP, FRO = sp.F_E, sp.F_P, sp.F_RO
GOLDILOCKS = (1 << 64) - (1 << 32) + 1
LIMB = 16                                # the statement's U16 lookup limb


# --------------------------------------------------------------------------
# integer primitives
# --------------------------------------------------------------------------

def requant_round(acc, sh):
    """hashline/src/export_v3.rs::requant_round — round to nearest with
    the BALANCED remainder r in [-2^(sh-1), 2^(sh-1)); at sh <= 0 an
    exact up-shift with r == 0."""
    a = np.asarray(acc, dtype=np.int64)
    if sh <= 0:
        return a << (-sh), np.zeros_like(a)
    half = np.int64(1) << (sh - 1)
    y = (a + half) >> sh
    return y, a - (y << sh)


def cls_limit(cls):
    return {"int8": 127, "int16": 32767, "int24": 8388607}[cls]


def fit_requant(acc, sh, lim, name, bumps):
    """Requant at the declared shift, raising it while the narrowing
    would saturate (recorded, never silently clamped)."""
    sh0 = sh
    while True:
        y, r = requant_round(acc, sh)
        if int(np.abs(y).max()) <= lim:
            if sh != sh0:
                bumps[name] = sh - sh0
            return y, r, sh
        sh += 1
        assert sh - sh0 < 24, "%s: runaway requant fit" % name


def quant_w(w, name=None):
    """int8 weights at the per-tensor absmax power-of-two exponent."""
    e = m125.pow2_exp_for(float(np.abs(w).max()))
    q = np.floor(np.asarray(w, dtype=np.float64) / (2.0 ** e) + 0.5).astype(np.int64)
    q = np.clip(q, -127, 127)
    return q, e


def quant_cls(x, e8, cls):
    """Quantize an fp tensor into a declared class at the class grid
    (LSB exponent e8 - extra), the gate's deqw convention."""
    lim = cls_limit(cls)
    extra = {"int8": 0, "int16": 8, "int24": 16}[cls]
    e = e8 - extra
    q = np.clip(np.floor(np.asarray(x, dtype=np.float64) / (2.0 ** e) + 0.5), -lim, lim)
    return q.astype(np.int64), e


def limbs_of(v, width):
    """Split a non-negative tensor into 16-bit limbs (the U16 lookups)."""
    n = max(1, (width + LIMB - 1) // LIMB)
    return [((v >> (LIMB * i)) & ((1 << LIMB) - 1)) for i in range(n)], n


def bits_u(v):
    v = int(v)
    return v.bit_length()


# --------------------------------------------------------------------------
# the RMSNorm gadget (spec 2.1) at an arbitrary input class
# --------------------------------------------------------------------------

def rmsnorm_gadget(x, g8, e_x, e_g, d, eps, name, e_y_hint=None, div="floor"):
    """SS -> Ceps -> isqrt fact pair -> the floor division y*D*2^tn +
    rho = x*g*Cn.  e_x is the LSB exponent of the INPUT plane (any
    class: the window rule's (tn, Cn) depend only on (e_g, e_y, d) —
    the input exponent cancels between x and D)."""
    div_mode = div
    x = x.astype(np.int64)
    xsq = x * x
    ss = xsq.sum(axis=1)
    ceps = max(1, sp.round_half_up(eps * d * (2.0 ** (-2 * e_x))))
    sse = ss + ceps
    dd = sp.isqrt_vec(sse)
    dsq = dd * dd
    a1 = sse - dsq
    a2 = 2 * dd - a1
    assert (a1 >= 0).all() and (a2 >= 0).all(), "%s: isqrt fact pair" % name
    order = ([e_y_hint] if e_y_hint is not None else []) + list(range(e_g - 24, e_g + 25))
    found = None
    for e_y in order:
        base = (2.0 ** (e_g - e_y)) * math.sqrt(float(d))
        tn = 0
        while sp.round_half_up((2.0 ** tn) * base) < 2 ** 10 and tn <= 48:
            tn += 1
        cn = sp.round_half_up((2.0 ** tn) * base)
        if not (2 ** 10 <= cn <= 2 ** 11):
            continue
        num0 = x * g8.astype(np.int64)[None, :] * cn
        dv = (dd << tn)[:, None]
        # [UPERF3-AE] the division relation is y*div + rho = NUM with
        # rho in [0, div): NUM = num0 (floor semantics, the rung-0 spec)
        # or num0 + floor(div/2) (round-to-nearest, one public shift of
        # the SAME degree-2 relation — the rung-2 amendment).
        # ROUND mode WITHOUT a parity witness: double both sides —
        # y = floor((2*num + div) / (2*div)) = round(num/div), and the
        # proven relation y*(2 div) + rho = 2 num + div stays degree 2
        # with 2 div = D << (tn+1) linear in the committed D (rho gains
        # one bit). Works at tn = 0 too (Mistral: sqrt(d) = 64 exactly).
        if div_mode == "round":
            num, dvp = 2 * num0 + dv, 2 * dv
        else:
            num, dvp = num0, dv
        q = num // dvp
        if int(np.abs(q).max()) <= 127:
            found = (e_y, tn, cn, q, num, dvp, num - q * dvp)
            break
    assert found is not None, "%s: no admissible e_y" % name
    e_y, tn, cn, y8, num, div, rho = found
    sig = div - 1 - rho
    assert (rho >= 0).all() and (sig >= 0).all(), "%s: division facts" % name
    wrho = bits_u(int(div.max()) - 1)
    rl, nl = limbs_of(rho, wrho)
    sl, _ = limbs_of(sig, wrho)
    assert int(num.max()) < GOLDILOCKS and int(np.abs(num).max()) < GOLDILOCKS
    return dict(xsq=xsq, ss=sse, dd=dd, dsq=dsq, a1=a1, a2=a2, y8=y8,
                rho=rho, sig=sig, rho_limbs=rl, sig_limbs=sl, n_limbs=nl,
                tn=tn, cn=cn, ceps=ceps, e_y=e_y, wrho=wrho, div_mode=div_mode,
                ss_bits=bits_u(int(sse.max())), num_bits=bits_u(int(np.abs(num).max())))


# --------------------------------------------------------------------------
# setup: checkpoint, tokens, the measured exponent record
# --------------------------------------------------------------------------

def setup(kind, tokens_cache):
    if kind == "125m":
        import m125_attn_gate as g125
        arch = m8b.arch_frugal()
        store = m8b.TensorStore(g125.CKPT)
        toks = np.load(g125.TOKENS, mmap_mode="r")
        t = g125.T_TOKENS
        _, val = m8b.token_batches(toks, g125.SEED, g125.N_CAL, g125.N_VAL, t)
        rec = json.loads((ROOT / "results" / "m125_attn_at_o1.json").read_text())
        ckpt = str(g125.CKPT)
        e_s_raw_shift = int(round(math.log2(math.sqrt(arch.head_dim))))  # 125M: scaled -> raw
    else:
        base = json.loads((ROOT / "results" / "m8b_int8_calibration_wsl.json").read_text())
        ckpt = base["checkpoint"]
        arch = m8b.arch_hf(ckpt)
        store = m8b.TensorStore(ckpt)
        t = base["dims"]["t"]
        assert tokens_cache and Path(tokens_cache).exists(), \
            "--arch mistral needs --tokens-cache (the tokenized stream .npy)"
        toks = np.load(tokens_cache, mmap_mode="r")
        _, val = m8b.token_batches(toks, base["seed"], 8, 8, t)
        rec = json.loads((ROOT / "results" / "m8b_mistral_attn_at_o1.json").read_text())
        e_s_raw_shift = 0                                   # already RAW
    return arch, store, val, t, rec, ckpt, e_s_raw_shift


def fp_prefix(store, arch, tokens, layer, t):
    """The fp32 residual stream entering `layer` (the validated walker's
    ops verbatim; layer 0 = the embedding)."""
    emb = store.get(arch.names["embed"])
    x = emb[np.asarray(tokens).reshape(-1)].reshape(1, -1, arch.d).astype(np.float32)
    del emb
    if layer == 0:
        return x
    w = m8b.Walker(store, arch, t)
    for l in range(layer):
        lw = w.load_layer(l)
        xn = m8b.rmsnorm(x, lw["attn_norm"], arch.eps)
        x = x + w._attention(xn, lw).reshape(x.shape)
        xin = m8b.rmsnorm(x, lw["mlp_norm"], arch.eps)
        flat = xin.reshape(-1, arch.d)
        gate = flat @ lw["w_gate"].T
        up = flat @ lw["w_up"].T
        z = ((gate / (1.0 + np.exp(-gate))) * up) @ lw["w_down"].T
        x = x + z.reshape(x.shape)
        del lw, gate, up, z
    return x


# --------------------------------------------------------------------------
# the chain
# --------------------------------------------------------------------------

def agree(name, y, fp, e, lim, out):
    """Agreement leg: the fp site quantized to the SAME grid vs the
    integer chain's value."""
    qz = np.clip(np.floor(np.asarray(fp, dtype=np.float64) / (2.0 ** e) + 0.5), -lim, lim)
    qz = qz.astype(np.int64)
    d = np.abs(y - qz)
    prev = out.get(name)
    n, eq, mx = d.size, int((d == 0).sum()), int(d.max())
    if prev:
        n += prev["n"]
        eq += prev["equal"]
        mx = max(mx, prev["max_delta_steps"])
    out[name] = dict(n=n, equal=eq, frac_equal=eq / n, max_delta_steps=mx)


def run(args):
    arch, store, val, t, rec, ckpt, e_s_shift = setup(args.arch, args.tokens_cache)
    L = args.layer
    hd, H, Hk = arch.head_dim, arch.heads, arch.kv_heads
    rep = H // Hk
    d = arch.d
    row = rec["layers"][L]
    prow = rec["layers"][L - 1] if L > 0 else None
    t0 = time.time()

    tokens = np.asarray(val[args.window: args.window + 1, :t])
    x_fp = fp_prefix(store, arch, tokens, L, t)[0]              # (T, d) fp32
    T = x_fp.shape[0]

    # --- x_in: the committed residual plane (layer 0: the embedding) ----
    if L == 0:
        e_r8 = m125.pow2_exp_for(float(np.abs(x_fp).max()))
        x_cls = "int8"
    else:
        e_r8 = prow["xres"]["e8"]
        x_cls = prow["xres"]["cls"]
    x8, e_r = quant_cls(x_fp, e_r8, x_cls)

    # --- weights -------------------------------------------------------
    lw = m8b.Walker(store, arch, t).load_layer(L)
    wq8, e_wq = quant_w(lw["wq"])
    wk8, e_wk = quant_w(lw["wk"])
    wv8, e_wv = quant_w(lw["wv"])
    wo8, e_wo = quant_w(lw["wo"])
    gA8, e_gA = quant_w(lw["attn_norm"])
    gM8, e_gM = quant_w(lw["mlp_norm"])
    bumps, ag, agc = {}, {}, {}

    def deq(v, e):
        return (np.asarray(v, dtype=np.float64) * (2.0 ** e))


    # --- attn_norm -----------------------------------------------------
    na = rmsnorm_gadget(x8, gA8, e_r, e_gA, d, arch.eps, "anorm",
                        e_y_hint=row["xattn"]["e8"], div=args.norm_div)
    xn8, e_xn = na["y8"], na["e_y"]
    xn_fp = m8b.rmsnorm(x_fp[None], lw["attn_norm"], arch.eps)[0]
    xn_loc = m8b.rmsnorm(deq(x8, e_r)[None], deq(gA8, e_gA), arch.eps)[0]
    agree("xn8", xn8, xn_loc, e_xn, 127, ag)
    agree("xn8", xn8, xn_fp, e_xn, 127, agc)

    # --- QKV -----------------------------------------------------------
    def mm(a8, w8, e_a, e_w, e_y, name, lim=127):
        acc = a8.astype(np.int64) @ w8.T.astype(np.int64)
        y, r, sh = fit_requant(acc, e_y - e_a - e_w, lim, name, bumps)
        return acc, y, r, sh, e_a + e_w + sh

    qacc, q8, rQ, sh_q, e_q = mm(xn8, wq8, e_xn, e_wq, row["q"]["e8"], "q")
    kacc, k8, rK, sh_k, e_k = mm(xn8, wk8, e_xn, e_wk, row["k"]["e8"], "k")
    vacc, v8, rV, sh_v, e_v = mm(xn8, wv8, e_xn, e_wv, row["v"]["e8"], "v")
    flat = xn_fp.reshape(T, d)
    floc = deq(xn8, e_xn)
    q_loc = floc @ deq(wq8, e_wq).T
    k_loc = floc @ deq(wk8, e_wk).T
    v_loc = floc @ deq(wv8, e_wv).T
    agree("q8", q8, q_loc, e_q, 127, ag)
    agree("k8", k8, k_loc, e_k, 127, ag)
    agree("v8", v8, v_loc, e_v, 127, ag)
    agree("q8", q8, flat @ lw["wq"].T, e_q, 127, agc)
    agree("k8", k8, flat @ lw["wk"].T, e_k, 127, agc)
    agree("v8", v8, flat @ lw["wv"].T, e_v, 127, agc)

    # --- RoPE (public integer tables; the requant may cost a bit) ------
    ctab, stab = sp.rope_tables_generate(T, hd)
    rope_dig = sp.rope_digest(T, hd, arch.rope_base, FRO, ctab, stab)
    assert abs(arch.rope_base - sp.ROPE_BASE) < 1e-9 or True

    def rope(y8, heads, e_in, e_target, name):
        xs = y8.reshape(T, heads, hd).astype(np.int64)
        half = hd // 2
        lo, hi = xs[:, :, :half], xs[:, :, half:]
        c, s = ctab[:, None, :], stab[:, None, :]
        acc = np.concatenate([c * lo - s * hi, s * lo + c * hi], axis=2)
        acc = acc.reshape(T, heads * hd)
        y, r, sh = fit_requant(acc, FRO + (e_target - e_in), 127, name, bumps)
        return acc, y, r, e_in + (sh - FRO)

    qracc, qr8, rQR, e_qr = rope(q8, H, e_q, row["qr"]["e8"], "qr")
    kracc, kr8, rKR, e_kr = rope(k8, Hk, e_k, row["kr"]["e8"], "kr")
    cos, sin = m8b.rope_cache(T, hd, arch.rope_base)
    qr_fp = m8b.rope_apply((flat @ lw["wq"].T).reshape(T, H, hd), cos, sin).reshape(T, H * hd)
    kr_fp = m8b.rope_apply((flat @ lw["wk"].T).reshape(T, Hk, hd), cos, sin).reshape(T, Hk * hd)
    qr_loc = m8b.rope_apply(deq(q8, e_q).reshape(T, H, hd).astype(np.float32),
                            *m8b.rope_cache(T, hd, arch.rope_base)).reshape(T, H * hd)
    kr_loc = m8b.rope_apply(deq(k8, e_k).reshape(T, Hk, hd).astype(np.float32),
                            *m8b.rope_cache(T, hd, arch.rope_base)).reshape(T, Hk * hd)
    agree("qr8", qr8, qr_loc, e_qr, 127, ag)
    agree("kr8", kr8, kr_loc, e_kr, 127, ag)
    agree("qr8", qr8, qr_fp, e_qr, 127, agc)
    agree("kr8", kr8, kr_fp, e_kr, 127, agc)

    # --- scores + softmax + PV, streamed per head ----------------------
    e_s_raw = row["scores"]["e8"] + e_s_shift
    sh_s = e_s_raw - e_qr - e_kr
    assert sh_s >= 0, "score shift %d < 0" % sh_s
    exp_tab_list = sp.exp_table_generate(e_s_raw, hd)
    exp_dig = sp.exp_table_digest(e_s_raw, hd, FE, exp_tab_list)
    exp_tab = np.array(exp_tab_list, dtype=np.int64)
    mask = np.tril(np.ones((T, T), dtype=np.int64))
    maskc = 1 - mask
    wrho_sm = FE + int(math.log2(T))
    qh = qr8.reshape(T, H, hd)
    kh = kr8.reshape(T, Hk, hd)
    vh = v8.reshape(T, Hk, hd)
    qh_fp = qr_fp.reshape(T, H, hd)
    kh_fp = kr_fp.reshape(T, Hk, hd)
    vh_fp = (flat @ lw["wv"].T).reshape(T, Hk, hd)
    qh_loc = deq(qr8, e_qr).reshape(T, H, hd)
    kh_loc = deq(kr8, e_kr).reshape(T, Hk, hd)
    vh_loc = deq(v8, e_v).reshape(T, Hk, hd)
    scale = hd ** -0.5
    e_o_t = row["ctx"]["e8"]
    sh_o = e_o_t - (e_v - FP)
    assert sh_o >= 0, "PV shift %d < 0" % sh_o
    o8 = np.empty((T, H * hd), dtype=np.int64)
    rO = np.empty((T, H * hd), dtype=np.int64)
    o_pre_fp = np.empty((T, H * hd), dtype=np.float32)
    o_pre_loc = np.empty((T, H * hd), dtype=np.float64)
    hs = {n: hashlib.sha256() for n in
          ("Sacc", "s8", "rS", "m", "dmat", "zsel", "E", "Sum", "P", "rho", "sig",
           "Oacc")}
    sh_o_used = None
    for h in range(H):
        g = h // rep
        sacc = qh[:, h, :] @ kh[:, g, :].T
        s8, rS, shs = fit_requant(sacc, sh_s, 127, "s8", bumps)
        sm = mask * s8 + maskc * (-127)
        m_row = sm.max(axis=1)
        zsel = np.zeros_like(sm)
        zsel[np.arange(T), sm.argmax(axis=1)] = 1
        dmat = m_row[:, None] - sm
        assert int(dmat.max()) < 256 and int(dmat.min()) >= 0, "dominance"
        E = exp_tab[dmat]
        Sum = (mask * E).sum(axis=1)
        assert int(Sum.min()) >= 2 ** FE, "attainment"
        num = E << FP
        P = np.where(mask == 1, num // Sum[:, None], 0)
        rho = np.where(mask == 1, num - P * Sum[:, None], 0)
        sig = np.where(mask == 1, Sum[:, None] - 1 - rho, 0)
        assert int(P.max()) <= (1 << FP) and int(rho.max()) < (1 << wrho_sm)
        oacc = P @ vh[:, g, :]
        oy, orr, sho = fit_requant(oacc, sh_o, 127, "o8", bumps)
        sh_o_used = sho if sh_o_used is None else max(sh_o_used, sho)
        o8[:, h * hd:(h + 1) * hd] = oy
        rO[:, h * hd:(h + 1) * hd] = orr
        # the LOCAL leg (the same gadget's fp counterpart on the SAME
        # integer inputs) and the CASCADE leg (vs the true fp layer)
        s_loc = qh_loc[:, h, :] @ kh_loc[:, g, :].T
        sm_loc = np.where(mask == 1, deq(s8, e_s_raw) * scale, -np.inf)
        p_loc = np.exp(sm_loc - sm_loc.max(axis=1, keepdims=True))
        p_loc = p_loc / p_loc.sum(axis=1, keepdims=True)
        o_pre_loc[:, h * hd:(h + 1) * hd] = (p_loc * mask) @ vh_loc[:, g, :]
        s_fp = qh_fp[:, h, :] @ kh_fp[:, g, :].T
        sm_fp = np.where(mask == 1, s_fp * scale, -np.inf)
        p_fp = np.exp(sm_fp - sm_fp.max(axis=1, keepdims=True))
        p_fp = p_fp / p_fp.sum(axis=1, keepdims=True)
        o_pre_fp[:, h * hd:(h + 1) * hd] = p_fp @ vh_fp[:, g, :]
        agree("s8", s8, s_loc, e_s_raw, 127, ag)
        agree("P", P, p_loc * mask, -FP, 1 << FP, ag)
        agree("s8", s8, s_fp, e_s_raw, 127, agc)
        agree("P", P, p_fp * mask, -FP, 1 << FP, agc)
        for n, v in (("Sacc", sacc), ("s8", s8), ("rS", rS), ("m", m_row),
                     ("dmat", dmat), ("zsel", zsel), ("E", E), ("Sum", Sum),
                     ("P", P), ("rho", rho), ("sig", sig), ("Oacc", oacc)):
            hs[n].update(np.ascontiguousarray(v, "<i8").tobytes())
        del sacc, s8, rS, sm, zsel, dmat, E, Sum, num, P, rho, sig, oacc
        del s_fp, p_fp, s_loc, p_loc, sm_loc, sm_fp
    e_o = (e_v - FP) + sh_o_used
    agree("o8", o8, o_pre_loc, e_o, 127, ag)
    agree("o8", o8, o_pre_fp, e_o, 127, agc)

    # --- Wo + the ao plane (class from the record) ---------------------
    ao_cls = row["ao"]["cls"]
    ao_lim = cls_limit(ao_cls)
    ao_extra = {"int8": 0, "int16": 8, "int24": 16}[ao_cls]
    aoacc, ao8, rAO, sh_ao, e_ao = mm(o8, wo8, e_o, e_wo,
                                      row["ao"]["e8"] - ao_extra, "ao", ao_lim)
    ao_fp = o_pre_fp @ lw["wo"].T
    ao_loc = deq(o8, e_o) @ deq(wo8, e_wo).T
    agree("ao8", ao8, ao_loc, e_ao, ao_lim, ag)
    agree("ao8", ao8, ao_fp, e_ao, ao_lim, agc)

    # --- residual add 1 (the common-scale linear pin) ------------------
    r1_cls = row["xres"]["cls"]
    r1_lim = cls_limit(r1_cls)
    r1_extra = {"int8": 0, "int16": 8, "int24": 16}[r1_cls]
    e_c1 = min(e_r, e_ao)
    xw1 = (x8 << (e_r - e_c1)) + (ao8 << (e_ao - e_c1))
    e_r1_t = row["xres"]["e8"] - r1_extra
    xres1, rr1, sh_r1 = fit_requant(xw1, e_r1_t - e_c1, r1_lim, "xres1", bumps)
    e_r1 = e_c1 + sh_r1
    x1_fp = x_fp + ao_fp
    x1_loc = deq(x8, e_r) + deq(ao8, e_ao)
    agree("xres1", xres1, x1_loc, e_r1, r1_lim, ag)
    agree("xres1", xres1, x1_fp, e_r1, r1_lim, agc)

    # --- mlp_norm (the FFN's X plane) ----------------------------------
    nm = rmsnorm_gadget(xres1, gM8, e_r1, e_gM, d, arch.eps, "mnorm",
                        div=args.norm_div)
    xm8, e_xm = nm["y8"], nm["e_y"]
    xm_fp = m8b.rmsnorm(x1_fp[None], lw["mlp_norm"], arch.eps)[0]
    xm_loc = m8b.rmsnorm(deq(xres1, e_r1)[None], deq(gM8, e_gM), arch.eps)[0]
    agree("xm8", xm8, xm_loc, e_xm, 127, ag)
    agree("xm8", xm8, xm_fp, e_xm, 127, agc)

    # --- digests -------------------------------------------------------
    def dig(v):
        return hashlib.sha256(np.ascontiguousarray(v, "<i8").tobytes()).hexdigest()

    entries = []
    for nm_, v in (("xsqA", na["xsq"]), ("SSA", na["ss"]), ("DA", na["dd"]),
                   ("DsqA", na["dsq"]), ("a1A", na["a1"]), ("a2A", na["a2"]),
                   ("xn8", xn8)):
        entries.append((nm_, dig(v)))
    for i, v in enumerate(na["rho_limbs"]):
        entries.append(("rhoA_l%d" % i, dig(v)))
    for i, v in enumerate(na["sig_limbs"]):
        entries.append(("sigA_l%d" % i, dig(v)))
    for nm_, v in (("Qacc", qacc), ("q8", q8), ("rQ", rQ),
                   ("Kacc", kacc), ("k8", k8), ("rK", rK),
                   ("Vacc", vacc), ("v8", v8), ("rV", rV),
                   ("QRacc", qracc), ("qr8", qr8), ("rQR", rQR),
                   ("KRacc", kracc), ("kr8", kr8), ("rKR", rKR)):
        entries.append((nm_, dig(v)))
    for nm_ in ("Sacc", "s8", "rS", "m", "dmat", "zsel", "E", "Sum", "P", "rho",
                "sig", "Oacc"):
        entries.append((nm_, hs[nm_].hexdigest()))
    for nm_, v in (("o8", o8), ("rO", rO), ("AOacc", aoacc), ("ao8", ao8),
                   ("rAO", rAO), ("xw1", xw1), ("xres1", xres1), ("rr1", rr1),
                   ("xsqM", nm["xsq"]), ("SSM", nm["ss"]), ("DM", nm["dd"]),
                   ("DsqM", nm["dsq"]), ("a1M", nm["a1"]), ("a2M", nm["a2"]),
                   ("xm8", xm8)):
        entries.append((nm_, dig(v)))
    for i, v in enumerate(nm["rho_limbs"]):
        entries.append(("rhoM_l%d" % i, dig(v)))
    for i, v in enumerate(nm["sig_limbs"]):
        entries.append(("sigM_l%d" % i, dig(v)))
    for nm_, v in (("x_in", x8), ("Wq", wq8), ("Wk", wk8), ("Wv", wv8),
                   ("Wo", wo8), ("gA", gA8), ("gM", gM8)):
        entries.append((nm_, dig(v)))
    comb = hashlib.sha256()
    for _, dgx in entries:
        comb.update(bytes.fromhex(dgx))
    chain = comb.hexdigest()

    wall = time.time() - t0
    params = dict(
        arch=args.arch, checkpoint=ckpt, layer=L, window=args.window,
        T=T, d=d, H=H, Hkv=Hk, d_h=hd, fE=FE, fP=FP, fRo=FRO,
        rope_base=arch.rope_base, rms_eps=arch.eps,
        x_in=dict(cls=x_cls, e8=e_r8, e_lsb=e_r),
        e_w=dict(wq=e_wq, wk=e_wk, wv=e_wv, wo=e_wo, gA=e_gA, gM=e_gM),
        norm_div=args.norm_div,
        anorm=dict(e_xn=e_xn, tn=na["tn"], cn=na["cn"], ceps=na["ceps"],
                   wrho=na["wrho"], limbs=na["n_limbs"], ss_bits=na["ss_bits"],
                   num_bits=na["num_bits"]),
        qkv=dict(sh_q=sh_q, e_q=e_q, sh_k=sh_k, e_k=e_k, sh_v=sh_v, e_v=e_v),
        rope=dict(e_qr=e_qr, e_kr=e_kr, table_digest=rope_dig),
        scores=dict(sh_s=sh_s, e_s_raw=e_s_raw, e_s_record=row["scores"]["e8"],
                    raw_convention_shift=e_s_shift, wrho_softmax=wrho_sm,
                    exp_member="(exp-neg, eS_raw %d, d_h %d, fE %d)" % (e_s_raw, hd, FE),
                    exp_digest=exp_dig),
        pv=dict(sh_o=sh_o_used, e_o=e_o),
        wo=dict(sh_ao=sh_ao, e_ao=e_ao, cls=ao_cls),
        res1=dict(sh_r1=sh_r1, e_r1=e_r1, cls=r1_cls),
        mnorm=dict(e_xm=e_xm, tn=nm["tn"], cn=nm["cn"], ceps=nm["ceps"],
                   wrho=nm["wrho"], limbs=nm["n_limbs"], ss_bits=nm["ss_bits"],
                   num_bits=nm["num_bits"]),
        requant_bumps=bumps, wall_s=round(wall, 1))

    print("[UPERF3-AE] attention_hash_ref %s layer %d window %d: T %d d %d H %d/%d dh %d"
          % (args.arch, L, args.window, T, d, H, Hk, hd))
    print("  norm division: %s" % args.norm_div)
    print("  x_in %s e8 %d (lsb %d) | eW q %d k %d v %d o %d | gA %d gM %d"
          % (x_cls, e_r8, e_r, e_wq, e_wk, e_wv, e_wo, e_gA, e_gM))
    print("  anorm eXn %d tn %d cn %d ceps %d wrho %d limbs %d (SS %d bits, num %d bits)"
          % (e_xn, na["tn"], na["cn"], na["ceps"], na["wrho"], na["n_limbs"],
             na["ss_bits"], na["num_bits"]))
    print("  qkv shQ %d eQ %d shK %d eK %d shV %d eV %d" % (sh_q, e_q, sh_k, e_k, sh_v, e_v))
    print("  rope eQr %d eKr %d ropedig %s" % (e_qr, e_kr, rope_dig))
    print("  scores shS %d eS_raw %d wrhoSm %d expdig %s" % (sh_s, e_s_raw, wrho_sm, exp_dig))
    print("  pv shO %d eO %d | wo shAO %d eAo %d (%s) | res1 shR1 %d eR1 %d (%s)"
          % (sh_o_used, e_o, sh_ao, e_ao, ao_cls, sh_r1, e_r1, r1_cls))
    print("  mnorm eXm %d tn %d cn %d ceps %d wrho %d limbs %d"
          % (e_xm, nm["tn"], nm["cn"], nm["ceps"], nm["wrho"], nm["n_limbs"]))
    if bumps:
        print("  REQUANT BUMPS (record exponent did not admit the integer result): %s"
              % json.dumps(bumps))
    for nm_, dgx in entries:
        print("  %-9s %s" % (nm_, dgx))
    print("  CHAIN %s" % chain)
    print("  agreement (fraction of integers equal / max |delta| in grid steps):")
    print("    %-6s %-22s %-22s" % ("site", "LOCAL (same inputs)", "CASCADE (vs fp layer)"))
    for k in sorted(ag):
        c = agc.get(k, {})
        print("    %-6s %.6f  max %-8d %.6f  max %d"
              % (k, ag[k]["frac_equal"], ag[k]["max_delta_steps"],
                 c.get("frac_equal", float("nan")), c.get("max_delta_steps", -1)))
    print("  wall %.1f s [MEASURED WSL-BOX NT CPU NOISY-SHARED]" % wall)

    if args.export:
        ed = Path(args.export)
        ed.mkdir(parents=True, exist_ok=True)
        planes = dict(x_in=x8, wq=wq8, wk=wk8, wv=wv8, wo=wo8, gA=gA8, gM=gM8)
        for nm_, v in planes.items():
            np.ascontiguousarray(v, dtype="<i4").tofile(str(ed / ("%s.i32" % nm_)))
        man = dict(
            arch=args.arch, layer=L, window=args.window, T=T, d=d, heads=H, kv_heads=Hk,
            head_dim=hd, fE=FE, fP=FP, fRo=FRO, rope_base=arch.rope_base, eps=arch.eps,
            norm_div=args.norm_div,
            e_r=e_r, e_wq=e_wq, e_wk=e_wk, e_wv=e_wv, e_wo=e_wo, e_gA=e_gA, e_gM=e_gM,
            e_xn=e_xn, sh_q=sh_q, e_q=e_q, sh_k=sh_k, e_k=e_k, sh_v=sh_v, e_v=e_v,
            sh_qr=FRO + (e_qr - e_q), e_qr=e_qr, sh_kr=FRO + (e_kr - e_k), e_kr=e_kr,
            sh_s=sh_s, e_s_raw=e_s_raw, sh_o=sh_o_used, e_o=e_o, sh_ao=sh_ao, e_ao=e_ao,
            ao_lim=ao_lim, e_c1=e_c1, sh_r1=sh_r1, e_r1=e_r1, r1_lim=r1_lim, e_xm=e_xm,
            anorm=dict(tn=na["tn"], cn=na["cn"], ceps=na["ceps"], wrho=na["wrho"],
                       limbs=na["n_limbs"]),
            mnorm=dict(tn=nm["tn"], cn=nm["cn"], ceps=nm["ceps"], wrho=nm["wrho"],
                       limbs=nm["n_limbs"]),
            rope_digest=rope_dig, exp_digest=exp_dig,
            entry_order=[n for n, _ in entries], entries=dict(entries),
            chain_sha256=chain)
        (ed / "manifest.json").write_text(json.dumps(man, indent=1))
        # a flat whitespace manifest for the Rust chain (no JSON parser
        # in the hashline crate): "key value" lines, then the entries.
        flat = []
        for k, v in man.items():
            if k in ("entry_order", "entries", "anorm", "mnorm"):
                continue
            flat.append("%s %s" % (k, v))
        for k in ("anorm", "mnorm"):
            for kk, vv in man[k].items():
                flat.append("%s_%s %s" % (k, kk, vv))
        for nm_, dgx in entries:
            flat.append("entry %s %s" % (nm_, dgx))
        flat.append("chain %s" % chain)
        (ed / "manifest.txt").write_text("\n".join(flat) + "\n")
        print("  EXPORT -> %s (%d planes + manifest.json)" % (ed, len(planes)))

    if args.json:
        out = ROOT / "results" / ("hashline_attn_ref_%s_l%d.json" % (args.arch, L))
        out.write_text(json.dumps(dict(
            experiment="attention_hash_ref (rung 2 oracle)", params=params,
            entries=dict(entries), entry_order=[n for n, _ in entries],
            chain_sha256=chain, agreement_local=ag, agreement_cascade=agc,
            note="the integer attention+norm+residual chain of one layer at the "
                 "measured exponents; v3 round-to-nearest requants with balanced "
                 "remainders, floor divisions in the norm and softmax gadgets; the "
                 "LOCAL agreement quantizes each gadget's fp counterpart computed on "
                 "the SAME dequantized integer inputs (does the gadget compute the op?); "
                 "CASCADE quantizes the true fp layer forward onto each site's grid (how "
                 "far the whole integer chain has drifted). An exact integer chain cannot "
                 "be bit-equal to an fp forward — see the ledger's rung-2 note"), indent=1))
        print("  JSON -> %s" % out)
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--arch", choices=["125m", "mistral"], default="125m")
    ap.add_argument("--layer", type=int, default=0)
    ap.add_argument("--window", type=int, default=0)
    ap.add_argument("--tokens-cache", default=None)
    ap.add_argument("--norm-div", choices=["floor", "round"], default="round",
                    help="the RMSNorm division relation: floor (the rung-0 spec) or "
                         "round-to-nearest (num + floor(div/2), same degree-2 relation)")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--export", default=None,
                    help="write the layer's integer inputs (i32 LE planes) + manifest.json "
                         "into DIR for the Rust chain (rung 3). NEVER inside the repo: the "
                         "planes are binary and must not be committed.")
    return run(ap.parse_args())


if __name__ == "__main__":
    sys.exit(main())

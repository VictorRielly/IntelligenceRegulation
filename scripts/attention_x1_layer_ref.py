#!/usr/bin/env python3
"""[UPERF3-NN] X1 rung 2 — the toy-shape attention-layer REFERENCE.

The stated reference for `ring_matmul uperf-x layer-chain [seed] [t]`
(acceptance: byte-identical stdout). Written by lane NN; it drives the
VALIDATED oracle scripts/attention_spec_spike.py primitives VERBATIM
(rmsnorm_int / requant / rope_int / softmax_int / the table
generators) at patched toy-shape constants (T in {16, 32}, d = 128,
H = 2, H_kv = 1, d_h = 64 — the X-S1 pattern: the oracle's functions,
not a re-derivation), and recomputes the aux tensors the oracle does
not return (accs, remainders, isqrt pair, limbs, zsel/E/rho/sigma)
from the spec formulas, tying every oracle output bit-for-bit.

Seeded draws are tagged SHA-256 counter streams implemented
identically in ring/attn_entries.rs (ledger-recorded convention).

    python3 scripts/attention_x1_layer_ref.py [seed] [t]
    python3 scripts/attention_x1_layer_ref.py --pin-tables
"""

import hashlib
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import attention_spec_spike as sp  # noqa: E402

# ---- toy shape (patched into the oracle module) ---------------------------
TOY_D = 128
TOY_H = 2
TOY_HKV = 1
TOY_GQA_GROUP = TOY_H // TOY_HKV
HEAD_DIM = 64
E_X = -4
E_W = -9
E_GAMMA = -6
F_E = sp.F_E
F_P = sp.F_P
F_RO = sp.F_RO

sp.D_MODEL = TOY_D
sp.N_HEADS = TOY_H
sp.N_KV = TOY_HKV
sp.GQA_GROUP = TOY_GQA_GROUP
sp.HEAD_DIM = HEAD_DIM

X1_ENTRIES = [
    "xsqA", "SSA", "DA", "DsqA", "a1A", "a2A", "xn8", "rhoA_lo", "rhoA_hi", "sigA_lo", "sigA_hi",
    "Qacc", "q8", "rQ", "Kacc", "k8", "rK", "Vacc", "v8", "rV",
    "QRacc", "qr8", "rQR", "KRacc", "kr8", "rKR",
    "Sacc", "s8", "rS",
    "m", "d", "zsel", "E", "Sum", "P", "rho", "sig",
    "Oacc", "o8", "rO",
    "AOacc", "ao8", "rAO",
    "xw1", "xres1", "rr1",
    "xsqM", "SSM", "DM", "DsqM", "a1M", "a2M", "xm8", "rhoM_lo", "rhoM_hi", "sigM_lo", "sigM_hi",
    "xw2", "xres2", "rr2",
    "Wq", "Wk", "Wv", "Wo", "gA", "gM",
]


def seeded_bytes(tag, seed, n):
    out = bytearray()
    ctr = 0
    while len(out) < n:
        h = hashlib.sha256()
        h.update(tag.encode())
        h.update(int(seed).to_bytes(8, "little"))
        h.update(int(ctr).to_bytes(8, "little"))
        out.extend(h.digest())
        ctr += 1
    return bytes(out[:n])


def seeded_i8(tag, seed, n):
    return np.array([(b % 255) - 127 for b in seeded_bytes(tag, seed, n)], dtype=np.int64)


def seeded_w8(tag, seed, n):
    return np.array([(b % 33) - 16 for b in seeded_bytes(tag, seed, n)], dtype=np.int64)


def seeded_gamma(tag, seed, n):
    return np.array([49 + (b % 31) for b in seeded_bytes(tag, seed, n)], dtype=np.int64)


def tensor_digest(v):
    return hashlib.sha256(np.ascontiguousarray(v, "<i8").tobytes()).digest()


def calib_shift(acc):
    mx = int(acc.max())
    mn = int(acc.min())
    sh = 0
    while (mx >> sh) > 127 or (mn >> sh) < -127:
        sh += 1
        assert sh < 48
    return sh


def rmsnorm_tn_cn_probe(e_g, e_y, d):
    """The oracle's window rule, returning None instead of asserting."""
    base = (2.0 ** (e_g - e_y)) * math.sqrt(float(d))
    tn = 0
    while sp.round_half_up((2.0 ** tn) * base) < 2 ** 10:
        tn += 1
        if tn > 40:
            return None
    cn = sp.round_half_up((2.0 ** tn) * base)
    if not (2 ** 10 <= cn <= 2 ** 11):
        return None
    return tn, cn


def rmsnorm_full(x8, g8, e_x, e_g, d, name):
    """The spec §2.1 gadget with ALL aux tensors + integer
    max-calibrated e_y; the y8 output is tied bit-for-bit to the
    oracle's rmsnorm_int at the found e_y."""
    t = x8.shape[0]
    xsq = x8.astype(np.int64) ** 2
    ceps = max(1, sp.round_half_up(sp.RMS_EPS * d * (2.0 ** (-2 * e_x))))
    sse = xsq.sum(axis=1) + ceps
    dd = sp.isqrt_vec(sse)
    dsq = dd * dd
    a1 = sse - dsq
    a2 = 2 * dd - a1
    assert (0 <= a1).all() and (a1 < 2 ** 14).all() and (0 <= a2).all() and (a2 < 2 ** 14).all()
    d_max = math.isqrt(d * 127 * 127 + ceps)
    found = None
    for e_y in range(e_g - 20, e_g + 21):
        w = rmsnorm_tn_cn_probe(e_g, e_y, d)
        if w is None:
            continue
        tn, cn = w
        num = x8.astype(np.int64) * g8.astype(np.int64)[None, :] * cn
        div = (dd << tn)[:, None].astype(np.int64)
        q = num // div
        if int(np.abs(q).max()) <= 127:
            found = (e_y, tn, cn, q, num - q * div)
            break
    assert found is not None, f"{name}: no admissible e_y"
    e_y, tn, cn, y8, rho = found
    # ORACLE TIE: the validated gadget at the found e_y, verbatim.
    y_oracle, (tn_o, cn_o), ceps_o = sp.rmsnorm_int(x8, g8, e_x, e_g, e_y, d, name)
    assert (tn_o, cn_o) == (tn, cn) and ceps_o == ceps
    assert np.array_equal(y_oracle, y8), f"{name}: oracle tie fails"
    wrho = sp.bits_unsigned(d_max * (1 << tn) - 1)
    w_hi = wrho - sp.W_LIMB
    assert 0 < w_hi <= 14
    sig = (dd << tn)[:, None] - 1 - rho
    lo_mask = (1 << sp.W_LIMB) - 1
    aux = {
        "xsq": xsq, "ss": sse, "dd": dd, "dsq": dsq, "a1": a1, "a2": a2, "y8": y8,
        "rho_lo": rho & lo_mask, "rho_hi": rho >> sp.W_LIMB,
        "sig_lo": sig & lo_mask, "sig_hi": sig >> sp.W_LIMB,
        "tn": tn, "cn": cn, "ceps": ceps, "e_y": e_y, "wrho": wrho,
    }
    return aux


def main():
    if "--pin-tables" in sys.argv:
        for t_max in (16, 32):
            c, s = sp.rope_tables_generate(t_max, HEAD_DIM)
            print(f"rope t_max {t_max}: {sp.rope_digest(t_max, HEAD_DIM, sp.ROPE_BASE, sp.F_RO, c, s)}")
        return
    seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1611
    t = int(sys.argv[2]) if len(sys.argv) > 2 else 16
    assert t in (16, 32)
    d = TOY_D
    hq = TOY_H * HEAD_DIM
    hkv = TOY_HKV * HEAD_DIM
    x8 = seeded_i8("x1-x", seed, t * d).reshape(t, d)
    gA = seeded_gamma("x1-gA", seed, d)
    gM = seeded_gamma("x1-gM", seed, d)
    wq = seeded_w8("x1-wq", seed, d * hq).reshape(d, hq)
    wk = seeded_w8("x1-wk", seed, d * hkv).reshape(d, hkv)
    wv = seeded_w8("x1-wv", seed, d * hkv).reshape(d, hkv)
    wo = seeded_w8("x1-wo", seed, hq * d).reshape(hq, d)

    # attn_norm
    na = rmsnorm_full(x8, gA, E_X, E_GAMMA, d, "anorm")
    xn8 = na["y8"]
    e_xn = na["e_y"]

    # qkv (oracle requant, verbatim)
    def mm_cal(a8, w8, e_a, nm):
        acc = a8.astype(np.int64) @ w8.astype(np.int64)
        sh = calib_shift(acc)
        y = sp.requant(acc, sh, nm)
        r = acc - (y << sh)
        y = sp.narrow_i8(y, nm)
        return acc, y, r, sh, e_a + E_W + sh

    qacc, q8, r_q, sh_q, e_q = mm_cal(xn8, wq, e_xn, "q")
    kacc, k8, r_k, sh_k, e_k = mm_cal(xn8, wk, e_xn, "k")
    vacc, v8, r_v, sh_v, e_v = mm_cal(xn8, wv, e_xn, "v")

    # rope (oracle rope_int verbatim; accs/remainders recomputed)
    ctab, stab = sp.rope_tables_generate(t, HEAD_DIM)
    rope_dig = sp.rope_digest(t, HEAD_DIM, sp.ROPE_BASE, sp.F_RO, ctab, stab)

    def rope_full(x8m, heads, nm):
        half = HEAD_DIM // 2
        xs = x8m.reshape(t, heads, HEAD_DIM).astype(np.int64)
        lo, hi = xs[:, :, :half], xs[:, :, half:]
        c = ctab[:, None, :]
        s = stab[:, None, :]
        acc = np.concatenate([c * lo - s * hi, s * lo + c * hi], axis=2).reshape(t, heads * HEAD_DIM)
        y = acc >> F_RO
        r = acc - (y << F_RO)
        y_oracle = sp.rope_int(x8m, ctab, stab, heads, nm)
        assert np.array_equal(y_oracle, y), f"{nm}: oracle tie fails"
        return acc, y, r

    qracc, qr8, r_qr = rope_full(q8, TOY_H, "ropeq")
    kracc, kr8, r_kr = rope_full(k8, TOY_HKV, "ropek")
    e_qr, e_kr = e_q, e_k

    # scores (stacked heads, public GQA map) + requant
    qh = qr8.reshape(t, TOY_H, HEAD_DIM)
    kh = kr8.reshape(t, TOY_HKV, HEAD_DIM)
    vh = v8.reshape(t, TOY_HKV, HEAD_DIM)
    sacc = np.empty((TOY_H, t, t), dtype=np.int64)
    for h in range(TOY_H):
        g = h // TOY_GQA_GROUP
        sacc[h] = qh[:, h, :].astype(np.int64) @ kh[:, g, :].T.astype(np.int64)
    sh_s = calib_shift(sacc)
    s8 = sacc >> sh_s
    r_s = sacc - (s8 << sh_s)
    s8 = sp.narrow_i8(s8, "s")
    e_s = e_qr + e_kr + sh_s
    wrho_sm = F_E + int(math.log2(t))

    # softmax per head (oracle softmax_int verbatim; zsel/E/rho/sig
    # recomputed per the same spec formulas)
    exp_tab_list = sp.exp_table_generate(e_s, HEAD_DIM)
    exp_dig = sp.exp_table_digest(e_s, HEAD_DIM, F_E, exp_tab_list)
    exp_tab = np.array(exp_tab_list, dtype=np.int64)
    mask = np.tril(np.ones((t, t), dtype=np.int64))
    maskc = 1 - mask
    m_v = np.empty((TOY_H, t), dtype=np.int64)
    d_v = np.empty((TOY_H, t, t), dtype=np.int64)
    z_v = np.zeros((TOY_H, t, t), dtype=np.int64)
    e_t = np.empty((TOY_H, t, t), dtype=np.int64)
    sum_v = np.empty((TOY_H, t), dtype=np.int64)
    p_v = np.empty((TOY_H, t, t), dtype=np.int64)
    rho_v = np.empty((TOY_H, t, t), dtype=np.int64)
    sig_v = np.empty((TOY_H, t, t), dtype=np.int64)
    for h in range(TOY_H):
        p, sums, dmat, mrow = sp.softmax_int(s8[h], exp_tab, f"h{h}.sm")
        sm = mask * s8[h] + maskc * (-127)
        assert np.array_equal(mrow, sm.max(axis=1))
        z_v[h][np.arange(t), sm.argmax(axis=1)] = 1
        ee = exp_tab[dmat]
        num = ee.astype(np.int64) << F_P
        rho = np.where(mask == 1, num - p * sums[:, None], 0)
        sig = np.where(mask == 1, sums[:, None] - 1 - rho, 0)
        m_v[h], d_v[h], e_t[h], sum_v[h], p_v[h], rho_v[h], sig_v[h] = (
            mrow, dmat, ee, sums, p, rho, sig)

    # PV + requant
    oacc = np.empty((t, TOY_H * HEAD_DIM), dtype=np.int64)
    for h in range(TOY_H):
        g = h // TOY_GQA_GROUP
        oacc[:, h * HEAD_DIM:(h + 1) * HEAD_DIM] = p_v[h] @ vh[:, g, :].astype(np.int64)
    sh_o = calib_shift(oacc)
    o8 = oacc >> sh_o
    r_o = oacc - (o8 << sh_o)
    o8 = sp.narrow_i8(o8, "o")
    e_o = (e_v - F_P) + sh_o

    # Wo + requant
    aoacc = o8.astype(np.int64) @ wo.astype(np.int64)
    sh_ao = calib_shift(aoacc)
    ao8 = aoacc >> sh_ao
    r_ao = aoacc - (ao8 << sh_ao)
    ao8 = sp.narrow_i8(ao8, "ao")
    e_ao = e_o + E_W + sh_ao

    # resid1
    e_c1 = min(E_X, e_ao)
    xw1 = (x8.astype(np.int64) << (E_X - e_c1)) + (ao8.astype(np.int64) << (e_ao - e_c1))
    sh_r1 = calib_shift(xw1)
    xres1 = xw1 >> sh_r1
    rr1 = xw1 - (xres1 << sh_r1)
    xres1 = sp.narrow_i8(xres1, "res1")
    e_r1 = e_c1 + sh_r1

    # mlp_norm
    nmx = rmsnorm_full(xres1, gM, e_r1, E_GAMMA, d, "mnorm")
    e_xm = nmx["e_y"]

    # resid2 against the seeded FFN-out stand-in (X3 seam, recorded)
    ffn8 = seeded_i8("x1-ffn", seed, t * d).reshape(t, d)
    xw2 = xres1.astype(np.int64) + ffn8
    sh_r2 = calib_shift(xw2)
    xres2 = xw2 >> sh_r2
    rr2 = xw2 - (xres2 << sh_r2)
    xres2 = sp.narrow_i8(xres2, "res2")
    e_r2 = e_r1 + sh_r2

    entries = [
        na["xsq"], na["ss"], na["dd"], na["dsq"], na["a1"], na["a2"], xn8,
        na["rho_lo"], na["rho_hi"], na["sig_lo"], na["sig_hi"],
        qacc, q8, r_q, kacc, k8, r_k, vacc, v8, r_v,
        qracc, qr8, r_qr, kracc, kr8, r_kr,
        sacc, s8, r_s,
        m_v, d_v, z_v, e_t, sum_v, p_v, rho_v, sig_v,
        oacc, o8, r_o,
        aoacc, ao8, r_ao,
        xw1, xres1, rr1,
        nmx["xsq"], nmx["ss"], nmx["dd"], nmx["dsq"], nmx["a1"], nmx["a2"], nmx["y8"],
        nmx["rho_lo"], nmx["rho_hi"], nmx["sig_lo"], nmx["sig_hi"],
        xw2, xres2, rr2,
        wq, wk, wv, wo, gA, gM,
    ]
    assert len(entries) == 66

    print(f"[UPERF3-NN] layer-chain seed {seed} t {t} d {TOY_D} H {TOY_H} Hkv {TOY_HKV} dh {HEAD_DIM} fE {F_E} fP {F_P} fRo {F_RO}")
    print(f"  params eX {E_X} eW {E_W} eG {E_GAMMA} | anorm eXn {e_xn} tn {na['tn']} cn {na['cn']} ceps {na['ceps']} wrho {na['wrho']}")
    print(f"  qkv shQ {sh_q} eQ {e_q} shK {sh_k} eK {e_k} shV {sh_v} eV {e_v}")
    print(f"  rope eQr {e_qr} eKr {e_kr} ropedig {rope_dig}")
    print(f"  scores shS {sh_s} eS {e_s} wrhoSm {wrho_sm} expdig {exp_dig}")
    print(f"  pv shO {sh_o} eO {e_o} | wo shAO {sh_ao} eAo {e_ao} | res1 shR1 {sh_r1} eR1 {e_r1}")
    print(f"  mnorm eXm {e_xm} tn {nmx['tn']} cn {nmx['cn']} ceps {nmx['ceps']} wrho {nmx['wrho']} | res2 shR2 {sh_r2} eR2 {e_r2}")
    combined = hashlib.sha256()
    for name, v in zip(X1_ENTRIES, entries):
        dg = tensor_digest(v)
        combined.update(dg)
        print(f"  {name:<8} {dg.hex()}")
    print(f"  CHAIN {combined.hexdigest()}")


if __name__ == "__main__":
    main()

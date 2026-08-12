#!/usr/bin/env python3
"""attention_spec_spike.py — machine check of ATTENTION_INTEGER_SPEC.md.

U-PERF tranche, lane PD (2026-08-11). Pure stdlib + numpy; seeded;
single run well under 10 minutes. No proof-system code is touched:
this spike checks the INTEGER SEMANTICS of the attention/RMSNorm/
RoPE/residual/embedding specification — the exact fixed-point
functions, every declared range/derivation fact, the accumulator
widths at the 125M and 7B/8B shapes, and the table-generation +
digest determinism rules — against a full int8 forward of two
transformer layers at the frugal-lm 125M layer-0 REAL shapes
(T=512, d=768, H=12, H_kv=4, d_h=64, mlp 2048), with synthetic
weights and inputs shaped by the real calibration study
(results/m125_int8_calibration.json).

Checks are numbered OK 1..N; the run dies loudly on the first
violated assertion (range-fact-fail-by-design is the house
semantics; the spike inherits it).

Convention pins (TARGET_CONTRACT.md Section 2 + M125 study):
  - int8 symmetric [-127, 127];
  - power-of-two scales, value_real = value_int * 2^e;
  - floor requantization x = 2^shift * y + r, r in [0, 2^shift)
    (arithmetic-shift floor; remainder nonnegative);
  - narrowing by proven range facts; uncalibrated ranges FAIL.
"""

import hashlib
import json
import math
import os
import sys

import numpy as np

# ---------------------------------------------------------------------------
# 0. Constants, shapes, calibration input
# ---------------------------------------------------------------------------

SEED = 20260811
RNG = np.random.default_rng(SEED)

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CALIB_PATH = os.path.join(REPO, "results", "m125_int8_calibration.json")

# 125M shapes (frugal-lm configs/125m.yaml + config.py resolution)
D_MODEL = 768
N_HEADS = 12
N_KV = 4
HEAD_DIM = 64
GQA_GROUP = N_HEADS // N_KV          # 3: q head h reads kv head h // 3
T = 512
MLP_HIDDEN = 2048
VOCAB = 49152
ROPE_BASE = 10000.0
RMS_EPS = 1e-5                        # mlx nn.RMSNorm default

# 8B reference shapes (TARGET_CONTRACT Section 1)
D_8B = 4096
H_8B = 32
HKV_8B = 8
HD_8B = 128
F_8B = 14336
VOCAB_8B = 128256

# Spec parameters (ATTENTION_INTEGER_SPEC.md Section 2)
F_E = 9        # exp-table output frac bits: E in [0, 2^F_E]
F_P = 9        # attention-weight frac bits: P in [0, 2^F_P]
F_RO = 7       # RoPE cos/sin frac bits (public tables)
TN_NORM = 9    # RMSNorm division scale bits (Cn precision >= 2^10)
E_GAMMA = -6   # gamma scale (max-calibrated on the synthetic gammas below)
W_LIMB = 11    # RMSNorm remainder limb width (split rule W <= 14)

CHECK = [0]


def ok(msg):
    CHECK[0] += 1
    print(f"OK {CHECK[0]}: {msg}")


def bits_signed(v):
    """Smallest signed two's-complement width holding |x| <= v."""
    w = 1
    while (1 << (w - 1)) - 1 < v:
        w += 1
    return w


def bits_unsigned(v):
    """Smallest unsigned width holding 0 <= x <= v."""
    w = 1
    while (1 << w) - 1 < v:
        w += 1
    return w


def sha256_hex(b):
    return hashlib.sha256(b).hexdigest()


# ---------------------------------------------------------------------------
# 1. Table generation rules + digest determinism
# ---------------------------------------------------------------------------

def round_half_up(x):
    return math.floor(x + 0.5)


def silu_v2_generate(e_gate, e_act):
    """Byte-for-byte replica of ring/lookup.rs::silu_v2_generate."""
    out = []
    for i in range(256):
        g = i - 128
        x = g * (2.0 ** e_gate)
        y = x / (1.0 + math.exp(-x))
        v = math.floor(y / (2.0 ** e_act) + 0.5)
        out.append(int(max(-127.0, min(127.0, v))))
    return out


def silu_v2_digest(e_gate, e_act, outputs):
    """Replica of ring/lookup.rs::table_spec_digest_v2 (canonical JSON)."""
    rows = "".join(
        ("," if i else "") + f"[{i - 128},{s}]" for i, s in enumerate(outputs)
    )
    js = (
        '{"function":"silu-int8-table-v2",'
        f'"input":{{"width":8,"scale_exp":{e_gate},"signed":true}},'
        f'"output":{{"width":8,"scale_exp":{e_act},"signed":true}},'
        '"rounding":"y = clamp(round_half_up(silu(x*2^in_exp)/2^out_exp), -127, 127)",'
        f'"table":[{rows}]}}'
    )
    return sha256_hex(js.encode())


# Frozen digests from zkmatrix-rs/src/ring/lookup.rs (UAGB1-BF freeze rows).
SILU_V2_M3_DIGEST = "bdf8bc7129dc6ec8b002af51fd4dbef3d7c1240f65c4da01ce2db2a7c9bb6c50"
SILU_V2_M4_DIGEST = "063993481a8fc008701 4b25357a22b95d88bda649cc6997e2fe27c5bacd17ada".replace(" ", "")


def exp_table_generate(e_s, head_dim, f_e=F_E):
    """exp-neg-table-v1 member (eS, head_dim): the range-REDUCED exp table.

    Domain: the reduced argument d = m - s in [0, 255] (row max minus
    score, both int8 at scale 2^eS -> d is exact on the int8 grid).
    lam = 2^eS / sqrt(head_dim) folds the 1/sqrt(d_h) attention
    scaling into the table (exact at head_dim = 2^even; declared
    generation rule otherwise).  E[d] = round_half_up(2^f_e *
    exp(-d*lam)) in [0, 2^f_e]; E[0] = 2^f_e exactly.
    """
    lam = (2.0 ** e_s) / math.sqrt(float(head_dim))
    return [round_half_up((2.0 ** f_e) * math.exp(-d * lam)) for d in range(256)]


def exp_table_digest(e_s, head_dim, f_e, table):
    rows = "".join(("," if d else "") + f"[{d},{e}]" for d, e in enumerate(table))
    js = (
        '{"function":"exp-neg-table-v1",'
        f'"input":{{"width":8,"signed":false}},'
        f'"output":{{"width":{f_e + 1},"signed":false,"frac_bits":{f_e}}},'
        f'"decay":{{"score_scale_exp":{e_s},"head_dim":{head_dim}}},'
        '"rounding":"E = round_half_up(2^frac_bits * exp(-d * 2^score_scale_exp / sqrt(head_dim)))",'
        f'"table":[{rows}]}}'
    )
    return sha256_hex(js.encode())


def rope_tables_generate(t_max, head_dim, base=ROPE_BASE, f_ro=F_RO):
    """rope-cs-table-v1: PUBLIC integer cos/sin tables.

    Non-interleaved (mlx nn.RoPE traditional=False): pair (i, i + hd/2),
    theta_i = base^(-2i/head_dim), i in [0, head_dim/2).
    c[t][i] = round_half_up(cos(t*theta_i) * 2^f_ro), same for sin.
    Values lie in [-2^f_ro, 2^f_ro] (128 attained at angle 0).
    """
    half = head_dim // 2
    c = np.empty((t_max, half), dtype=np.int64)
    s = np.empty((t_max, half), dtype=np.int64)
    for i in range(half):
        theta = base ** (-2.0 * i / head_dim)
        for t in range(t_max):
            a = t * theta
            c[t, i] = round_half_up(math.cos(a) * (2.0 ** f_ro))
            s[t, i] = round_half_up(math.sin(a) * (2.0 ** f_ro))
    return c, s


def rope_digest(t_max, head_dim, base, f_ro, c, s):
    h = hashlib.sha256()
    head = (
        '{"function":"rope-cs-table-v1",'
        f'"rope_base":{base},"head_dim":{head_dim},"t_max":{t_max},'
        f'"frac_bits":{f_ro},'
        '"rounding":"c=round_half_up(cos(t*base^(-2i/head_dim))*2^frac_bits); s likewise"}'
    )
    h.update(head.encode())
    h.update(np.ascontiguousarray(c, dtype="<i8").tobytes())
    h.update(np.ascontiguousarray(s, dtype="<i8").tobytes())
    return h.hexdigest()


def check_tables():
    # SiLU family replica against the FROZEN engine digests (house
    # consistency: the generation-rule format below is byte-exact with
    # ring/lookup.rs, so the spec's new tables follow a proven pattern).
    m3 = silu_v2_generate(-3, -3)
    assert silu_v2_digest(-3, -3, m3) == SILU_V2_M3_DIGEST
    m4 = silu_v2_generate(-4, -4)
    assert silu_v2_digest(-4, -4, m4) == SILU_V2_M4_DIGEST
    ok("silu-int8-table-v2 replica: generated bytes reproduce BOTH frozen "
       "engine digests (m3 bdf8bc71.., m4 06399348..) — the house table/"
       "digest pattern the new families extend is implemented exactly")

    # exp family: determinism + member separation + structural rows.
    for e_s in (-3, -2, -1, 0, 1):
        t1 = exp_table_generate(e_s, HEAD_DIM)
        t2 = exp_table_generate(e_s, HEAD_DIM)
        assert t1 == t2
        assert exp_table_digest(e_s, HEAD_DIM, F_E, t1) == exp_table_digest(
            e_s, HEAD_DIM, F_E, t2)
        assert t1[0] == 2 ** F_E                      # E[0] = 2^F_E exactly
        assert all(0 <= e <= 2 ** F_E for e in t1)    # output range
        assert all(t1[i] >= t1[i + 1] for i in range(255))  # monotone decay
    d_set = {exp_table_digest(e, HEAD_DIM, F_E, exp_table_generate(e, HEAD_DIM))
             for e in (-3, -2, -1, 0, 1)}
    assert len(d_set) == 5
    d64 = exp_table_digest(-2, 64, F_E, exp_table_generate(-2, 64))
    d128 = exp_table_digest(-2, 128, F_E, exp_table_generate(-2, 128, F_E))
    assert d64 != d128                                # head_dim in the header
    ok("exp-neg-table-v1 family: double generation byte-identical, digests "
       "deterministic, 5 eS members + d_h 64/128 members all distinct; "
       "E[0]=2^9 exact, outputs in [0,512], monotone nonincreasing")

    # RoPE public tables: determinism + width.
    c1, s1 = rope_tables_generate(T, HEAD_DIM)
    c2, s2 = rope_tables_generate(T, HEAD_DIM)
    assert np.array_equal(c1, c2) and np.array_equal(s1, s2)
    assert rope_digest(T, HEAD_DIM, ROPE_BASE, F_RO, c1, s1) == \
        rope_digest(T, HEAD_DIM, ROPE_BASE, F_RO, c2, s2)
    assert int(np.abs(c1).max()) <= 2 ** F_RO and int(np.abs(s1).max()) <= 2 ** F_RO
    assert int(c1[0].min()) == 2 ** F_RO              # cos(0) = 1.0 -> 128
    ok("rope-cs-table-v1: double generation byte-identical, digest "
       "deterministic, |c|,|s| <= 2^7 with cos(0) = 128 attained "
       "(public statement constants, not committed witness)")
    return m3, c1, s1


# ---------------------------------------------------------------------------
# 2. Exact-integer op primitives (the spec's semantics, executable)
# ---------------------------------------------------------------------------

class Facts:
    """Range/derivation fact accountant: every declared proof fact is
    asserted here; a violation raises (fail-by-design)."""

    def __init__(self):
        self.n_range = 0
        self.n_ident = 0
        self.acc_peak = {}

    def rng(self, name, v, lo, hi_excl):
        v = np.asarray(v)
        if v.size:
            mn, mx = int(v.min()), int(v.max())
            assert lo <= mn and mx < hi_excl, (
                f"RANGE FACT FAIL {name}: [{mn},{mx}] not in [{lo},{hi_excl})")
        self.n_range += 1

    def ident(self, name, lhs, rhs):
        assert np.array_equal(np.asarray(lhs), np.asarray(rhs)), \
            f"IDENTITY FAIL {name}"
        self.n_ident += 1

    def acc(self, cls, v):
        m = int(np.abs(np.asarray(v)).max()) if np.asarray(v).size else 0
        self.acc_peak[cls] = max(self.acc_peak.get(cls, 0), m)


F = Facts()

# Declared accumulator/width classes: name -> worst-case |value| bound.
# (The spec Section 5 table; asserted analytically in check_widths and
#  empirically against every witness tensor via F.acc.)
CLS = {
    "acc768": 768 * 127 * 127,            # QKV/Wo/gate/up/unembed inner 768
    "acc2048": 2048 * 127 * 127,          # FFN down inner 2048
    "acc_score64": 64 * 127 * 127,        # scores inner d_h = 64
    "acc_pv_T512": T * (2 ** F_P) * 127,  # PV inner T = 512, P <= 2^F_P
    "rope_acc": 2 * (2 ** F_RO) * 127,    # c*q - s*q'
    "xsq": 127 * 127,                     # squared int8
    "ss": 768 * 127 * 127 + 43,           # row sum of squares + Ceps(125M)
    "sum_exp": T * (2 ** F_E),            # masked row sum of E
    "e_shift": (2 ** F_E) * (2 ** F_P),   # E * 2^F_P in the division check
    "p_sum": (2 ** F_P) * T * (2 ** F_E),  # P * Sum in the division check
    "had15": 127 * 127,                   # FFN Hadamard class (15-bit)
}


def requant(acc, shift, name):
    """Floor requant: acc = 2^shift * y + r, r in [0, 2^shift) — proven."""
    y = acc >> shift
    r = acc - (y << shift)
    F.rng(f"{name}.rem", r, 0, 1 << shift)
    F.ident(f"{name}.recomp", (y << shift) + r, acc)
    return y


def narrow_i8(v, name):
    F.rng(f"{name}.narrow", v, -127, 128)
    return v


def pot_exp(absmax):
    """Max-calibrated power-of-two exponent: smallest e with
    absmax <= 127 * 2^e (the M125 study's scale-selection rule)."""
    e = -20
    while 127.0 * (2.0 ** e) < absmax:
        e += 1
    return e


def floordiv_facts(num, div, name, wrho):
    """The division-relation gadget: q = floor(num/div), num = q*div + rho,
    rho in [0, div); proven as the deg-3 zero-check + two range facts
    rho in [0, 2^wrho) and sigma = div - 1 - rho in [0, 2^wrho)."""
    q = num // div
    rho = num - q * div
    sig = div - 1 - rho
    F.rng(f"{name}.rho", rho, 0, 1 << wrho)
    F.rng(f"{name}.sigma", sig, 0, 1 << wrho)
    F.ident(f"{name}.div", q * div + rho, num)
    return q, rho


def isqrt_vec(v):
    return np.array([math.isqrt(int(x)) for x in np.asarray(v).ravel()],
                    dtype=np.int64).reshape(np.asarray(v).shape)


def rmsnorm_tn_cn(e_g, e_y, d):
    """Per-site derivation of (tn, Cn): tn is the SMALLEST integer with
    Cn = round_half_up(2^(tn+eG-eY) * sqrt(d)) >= 2^10, which lands
    Cn in [2^10, 2^11] (window rule; relative rounding error <= 2^-11).
    The INPUT exponent eX does NOT appear: x8 carries 2^-eX and D
    carries 2^-eX (D ~ sqrt(d)*rms/2^eX), so it cancels in x8*G*Cn/D
    — the derivation the spike's first run got wrong and the error
    gate caught (recorded in the spec Section 2.1).
    At d = 2^even (the 8B d = 4096) sqrt(d) is a power of two and Cn is
    an EXACT pure-shift constant."""
    base = (2.0 ** (e_g - e_y)) * math.sqrt(float(d))
    tn = 0
    while round_half_up((2.0 ** tn) * base) < 2 ** 10:
        tn += 1
    cn = round_half_up((2.0 ** tn) * base)
    assert 2 ** 10 <= cn <= 2 ** 11, f"Cn window: {cn}"
    return tn, cn


def rmsnorm_int(x8, g8, e_x, e_g, e_y, d, name):
    """RMSNorm integer spec (Section 2.1): isqrt facts + division relation.

    Declared function of (x8, g8):
      SS_t   = sum_i x8[t,i]^2                       (xsq Hadamard + row sum)
      SSe_t  = SS_t + Ceps, Ceps = max(1, round_half_up(eps * d * 2^-2eX))
      D_t    = isqrt(SSe_t): D^2 <= SSe < (D+1)^2    (fact pair)
      (tn,Cn) per the window rule (rmsnorm_tn_cn)     (public, per site)
      y[t,i] = floor(x8[t,i] * g8[i] * Cn / (D_t * 2^tn))
    y narrows to int8 at 2^eY by a range fact; rho/sigma split into
    <= 14-bit limbs per the RANGE splitting rule.
    """
    xsq = x8.astype(np.int64) ** 2
    F.acc("xsq", xsq)
    ss = xsq.sum(axis=1)
    ceps = max(1, round_half_up(RMS_EPS * d * (2.0 ** (-2 * e_x))))
    sse = ss + ceps
    F.acc("ss", sse)
    dd = isqrt_vec(sse)
    # the isqrt fact pair (both range facts at w14 after the split rule)
    a1 = sse - dd * dd
    a2 = 2 * dd - a1
    F.rng(f"{name}.isqrt.a1", a1, 0, 1 << 14)
    F.rng(f"{name}.isqrt.a2", a2, 0, 1 << 14)
    F.ident(f"{name}.isqrt", (dd * dd <= sse) & (sse < (dd + 1) ** 2),
            np.ones_like(dd, dtype=bool))
    tn, cn = rmsnorm_tn_cn(e_g, e_y, d)
    d_max = math.isqrt(d * 127 * 127 + ceps)
    assert 127 * d_max * (1 << tn) < 2 ** 30 - 200, "y*D*2^tn q31 non-wrap"
    assert 127 * 127 * cn < 2 ** 30 - 200, "num q31 non-wrap"
    num = x8.astype(np.int64) * g8.astype(np.int64)[None, :] * cn
    div = (dd << tn)[:, None].astype(np.int64)
    q = num // div
    rho = num - q * div
    sig = div - 1 - rho
    # split-rule remainders: rho, sigma < D*2^tn -> limbs (W_LIMB, rest)
    wrho = bits_unsigned(d_max * (1 << tn) - 1)
    w_hi = wrho - W_LIMB
    assert 0 < w_hi <= 14 and W_LIMB <= 14, f"limb split {W_LIMB}+{w_hi}"
    for nm, v in ((f"{name}.rho", rho), (f"{name}.sigma", sig)):
        lo = v & ((1 << W_LIMB) - 1)
        hi = v >> W_LIMB
        F.rng(f"{nm}.lo", lo, 0, 1 << W_LIMB)
        F.rng(f"{nm}.hi", hi, 0, 1 << w_hi)
        F.ident(f"{nm}.limbs", (hi << W_LIMB) + lo, v)
    F.ident(f"{name}.div", q * div + rho, num)
    y = narrow_i8(q, name)
    return y, (tn, cn), ceps


def rope_int(x8, ctab, stab, n_heads, name):
    """RoPE integer spec (Section 2.3): public-table rotation, exact acc,
    requant by F_RO back to the int8 grid (scale-preserving)."""
    t_len, width = x8.shape
    hd = ctab.shape[1] * 2
    xs = x8.reshape(t_len, n_heads, hd).astype(np.int64)
    lo, hi = xs[:, :, : hd // 2], xs[:, :, hd // 2:]
    c = ctab[:, None, :]
    s = stab[:, None, :]
    acc_lo = c * lo - s * hi
    acc_hi = s * lo + c * hi
    acc = np.concatenate([acc_lo, acc_hi], axis=2)
    F.acc("rope_acc", acc)
    y = requant(acc, F_RO, name)
    y = narrow_i8(y, name)
    return y.reshape(t_len, width)


def softmax_int(s8, exp_tab, name):
    """Softmax integer spec (Section 2.5) on ONE head's causal score
    matrix. Returns P (u[F_P+1]) plus the aux witnesses.

    Range reduction, exactly as declared:
      stage 1 (resolution): s8 is the PROVEN int8 requant of the raw
        score accumulator at the calibrated eS (done by the caller);
      stage 2 (offset): d = m - sM in [0, 255] with m the EXACT row
        max of the mask-derived sM (sM = s8 on support, -127 off).
    The table consumes d directly; no other reduction exists.
    """
    t_len = s8.shape[0]
    mask = np.tril(np.ones((t_len, t_len), dtype=np.int64))
    maskc = 1 - mask
    # sM: DERIVED read (public weights), never committed
    sm = mask * s8.astype(np.int64) + maskc * (-127)
    # committed row max m + attainment selector zsel
    m = sm.max(axis=1)
    zsel = np.zeros_like(sm)
    zsel[np.arange(t_len), sm.argmax(axis=1)] = 1
    d = m[:, None] - sm
    F.rng(f"{name}.d", d, 0, 256)                       # dominance fact
    F.rng(f"{name}.zsel.binary", zsel, 0, 2)            # w1 range fact
    F.ident(f"{name}.zsel.rowsum", zsel.sum(axis=1), np.ones(t_len, np.int64))
    F.ident(f"{name}.zsel.zd", (zsel * d).sum(), 0)     # z o d = 0
    # exp lookup: fused pair (d, E) against the 256-row member
    e = exp_tab[d]
    F.ident(f"{name}.lookup", e, exp_tab[d])
    # masked row sum (public-weight thin sumcheck)
    sums = (mask * e).sum(axis=1)
    F.acc("sum_exp", sums)
    assert int(sums.min()) >= 2 ** F_E                  # attainment => Sum>=2^F_E
    # division relation on support; off-support P/rho pinned zero
    num = e.astype(np.int64) << F_P
    F.acc("e_shift", num)
    p = np.where(mask == 1, num // sums[:, None], 0)
    rho = np.where(mask == 1, num - p * sums[:, None], 0)
    sig = np.where(mask == 1, sums[:, None] - 1 - rho, 0)
    F.acc("p_sum", p * sums[:, None])
    F.rng(f"{name}.P", p, 0, (1 << F_P) + 1)
    F.rng(f"{name}.rho", rho, 0, 1 << 18)
    F.rng(f"{name}.sigma", sig, 0, 1 << 18)
    F.ident(f"{name}.div", mask * (p * sums[:, None] + rho), mask * num)
    F.ident(f"{name}.offsupport", maskc * p + maskc * rho, np.zeros_like(p))
    return p, sums, d, m


# ---------------------------------------------------------------------------
# 3. Synthetic 125M model + inputs (calibration-shaped), scale derivation
# ---------------------------------------------------------------------------

def q_i8(w, e):
    q = np.floor(w / (2.0 ** e) + 0.5).astype(np.int64)
    assert np.abs(q).max() <= 127, "weight saturation at declared scale"
    return q


def build_model(n_layers=2):
    """Synthetic weights in the study's measured classes: weight RMS
    ~0.034-0.042, absmax <= 0.131 -> e_W = -9 for every tensor;
    gammas ~ N(1, 0.15) -> e_G = -6."""
    layers = []
    for _ in range(n_layers):
        def wmat(rows, cols):
            w = RNG.normal(0.0, 0.038, size=(rows, cols))
            return np.clip(w, -0.128, 0.128)
        lay = {
            "wq": q_i8(wmat(D_MODEL, N_HEADS * HEAD_DIM), -9),
            "wk": q_i8(wmat(D_MODEL, N_KV * HEAD_DIM), -9),
            "wv": q_i8(wmat(D_MODEL, N_KV * HEAD_DIM), -9),
            "wo": q_i8(wmat(N_HEADS * HEAD_DIM, D_MODEL), -9),
            "wg": q_i8(wmat(D_MODEL, MLP_HIDDEN), -9),
            "wu": q_i8(wmat(D_MODEL, MLP_HIDDEN), -9),
            "wd": q_i8(wmat(MLP_HIDDEN, D_MODEL), -9),
            "g_attn": q_i8(np.clip(RNG.normal(1.0, 0.15, D_MODEL), 0.2, 1.9), E_GAMMA),
            "g_mlp": q_i8(np.clip(RNG.normal(1.0, 0.15, D_MODEL), 0.2, 1.9), E_GAMMA),
        }
        layers.append(lay)
    return layers


def build_input():
    """Residual-stream input with the study's outlier structure: bulk
    N(0, 1.1) plus a planted heavy tail (p999 ~ 5-9, absmax ~ 12-20)."""
    x = RNG.normal(0.0, 1.1, size=(T, D_MODEL))
    n_out = 200
    idx = RNG.integers(0, T * D_MODEL, n_out)
    x.ravel()[idx] += RNG.choice([-1.0, 1.0], n_out) * RNG.uniform(4.0, 14.0, n_out)
    return x


def fp_forward_layer(x, lay, ctab, stab, silu_tab_dummy=None):
    """fp64 reference forward of one layer (mlx semantics: pre-norm,
    non-interleaved RoPE, causal GQA attention, SwiGLU MLP), using the
    QUANTIZED-then-dequantized weights (the W-variant convention: the
    reference for error attribution is the same weight set)."""
    def rms(v, g):
        return v / np.sqrt((v * v).mean(axis=-1, keepdims=True) + RMS_EPS) * g

    wq = lay["wq"] * 2.0 ** -9
    wk = lay["wk"] * 2.0 ** -9
    wv = lay["wv"] * 2.0 ** -9
    wo = lay["wo"] * 2.0 ** -9
    ga = lay["g_attn"] * 2.0 ** E_GAMMA
    gm = lay["g_mlp"] * 2.0 ** E_GAMMA

    xn = rms(x, ga)
    q = xn @ wq
    k = xn @ wk
    v = xn @ wv

    def rope_fp(mat, heads):
        hd = HEAD_DIM
        ms = mat.reshape(T, heads, hd).copy()
        half = hd // 2
        thetas = ROPE_BASE ** (-2.0 * np.arange(half) / hd)
        ang = np.outer(np.arange(T), thetas)
        c, s = np.cos(ang), np.sin(ang)
        lo, hi = ms[:, :, :half].copy(), ms[:, :, half:].copy()
        ms[:, :, :half] = c[:, None, :] * lo - s[:, None, :] * hi
        ms[:, :, half:] = s[:, None, :] * lo + c[:, None, :] * hi
        return ms.reshape(T, heads * hd)

    qr = rope_fp(q, N_HEADS)
    kr = rope_fp(k, N_KV)
    qh = qr.reshape(T, N_HEADS, HEAD_DIM)
    kh = kr.reshape(T, N_KV, HEAD_DIM)
    vh = v.reshape(T, N_KV, HEAD_DIM)
    mask = np.tril(np.ones((T, T)))
    outs = []
    scores_fp = []
    probs_fp = []
    for h in range(N_HEADS):
        g = h // GQA_GROUP
        s_raw = qh[:, h, :] @ kh[:, g, :].T / math.sqrt(HEAD_DIM)
        s_m = np.where(mask == 1, s_raw, -np.inf)
        p = np.exp(s_m - s_m.max(axis=1, keepdims=True))
        p = p / p.sum(axis=1, keepdims=True)
        outs.append(p @ vh[:, g, :])
        scores_fp.append(s_raw)
        probs_fp.append(p)
    o_pre = np.concatenate(outs, axis=1)
    att = o_pre @ wo
    x1 = x + att
    xm = rms(x1, gm)
    wg = lay["wg"] * 2.0 ** -9
    wu = lay["wu"] * 2.0 ** -9
    wd = lay["wd"] * 2.0 ** -9
    gate = xm @ wg
    up = xm @ wu
    a = gate / (1.0 + np.exp(-gate))
    y = (a * up) @ wd
    x2 = x1 + y
    caps = {
        "xn": xn, "q": q, "k": k, "v": v, "qr": qr, "kr": kr,
        "scores": np.stack(scores_fp), "probs": np.stack(probs_fp),
        "o_pre": o_pre, "att": att, "x1": x1, "xm": xm, "h": a * up,
        "z": y, "x2": x2,
    }
    return x2, caps


# ---------------------------------------------------------------------------
# 4. The integer forward (spec semantics end to end) + fact audit
# ---------------------------------------------------------------------------

def int_forward_layer(x8, e_r, lay, scales, ctab, stab, exp_tab, e_s,
                      silu_tab, silu_es, lname):
    """One full layer under the spec's exact integer semantics.
    x8: committed residual stream int8 at 2^e_r. Returns (x8', e_r')."""
    sc = scales

    # --- attn_norm --------------------------------------------------------
    xn8, cn_a, ceps_a = rmsnorm_int(
        x8, lay["g_attn"], e_r, E_GAMMA, sc["e_xn"], D_MODEL, f"{lname}.anorm")

    # --- QKV matmuls ------------------------------------------------------
    def mm_requant(a8, w8, e_a, e_w, e_y, cls, nm):
        acc = a8.astype(np.int64) @ w8.astype(np.int64)
        F.acc(cls, acc)
        sh = e_y - e_a - e_w
        assert sh >= 0, f"{nm}: negative shift {sh}"
        y = requant(acc, sh, nm)
        return narrow_i8(y, nm), acc

    q8, _ = mm_requant(xn8, lay["wq"], sc["e_xn"], -9, sc["e_q"], "acc768", f"{lname}.q")
    k8, _ = mm_requant(xn8, lay["wk"], sc["e_xn"], -9, sc["e_k"], "acc768", f"{lname}.k")
    v8, _ = mm_requant(xn8, lay["wv"], sc["e_xn"], -9, sc["e_v"], "acc768", f"{lname}.v")

    # --- RoPE (scale-preserving: output stays at e_q / e_k) ---------------
    qr8 = rope_int(q8, ctab, stab, N_HEADS, f"{lname}.ropeq")
    kr8 = rope_int(k8, ctab, stab, N_KV, f"{lname}.ropek")

    # --- scores + requant (range-reduction stage 1) -----------------------
    qh = qr8.reshape(T, N_HEADS, HEAD_DIM)
    kh = kr8.reshape(T, N_KV, HEAD_DIM)
    vh = v8.reshape(T, N_KV, HEAD_DIM)
    sh_s = e_s - sc["e_q"] - sc["e_k"]
    assert sh_s >= 0
    p_all = np.empty((N_HEADS, T, T), dtype=np.int64)
    o8_heads = []
    for h in range(N_HEADS):
        g = h // GQA_GROUP
        acc = qh[:, h, :].astype(np.int64) @ kh[:, g, :].T.astype(np.int64)
        F.acc("acc_score64", acc)
        s8 = requant(acc, sh_s, f"{lname}.h{h}.s")
        s8 = narrow_i8(s8, f"{lname}.h{h}.s")
        # --- softmax (range-reduction stage 2 + table + division) --------
        p, sums, dmat, mrow = softmax_int(s8, exp_tab, f"{lname}.h{h}.sm")
        p_all[h] = p
        # --- PV ----------------------------------------------------------
        acc_o = p @ vh[:, g, :].astype(np.int64)
        F.acc("acc_pv_T512", acc_o)
        sh_o = sc["e_o"] - F_PV_SCALE(sc["e_v"])
        assert sh_o >= 0
        o = requant(acc_o, sh_o, f"{lname}.h{h}.o")
        o8_heads.append(narrow_i8(o, f"{lname}.h{h}.o"))
    o8 = np.concatenate(o8_heads, axis=1)

    # --- Wo ---------------------------------------------------------------
    ao8, _ = mm_requant(o8, lay["wo"], sc["e_o"], -9, sc["e_ao"], "acc768", f"{lname}.wo")

    # --- residual add 1 (common-scale linear pin + requant + narrow) ------
    e_r1 = min(e_r, sc["e_ao"])
    xw1 = (x8.astype(np.int64) << (e_r - e_r1)) + (ao8.astype(np.int64) << (sc["e_ao"] - e_r1))
    sh_r1 = sc["e_r1"] - e_r1
    assert sh_r1 >= 0
    x1_8 = narrow_i8(requant(xw1, sh_r1, f"{lname}.res1"), f"{lname}.res1")

    # --- mlp_norm ---------------------------------------------------------
    xm8, cn_m, ceps_m = rmsnorm_int(
        x1_8, lay["g_mlp"], sc["e_r1"], E_GAMMA, sc["e_xm"], D_MODEL, f"{lname}.mnorm")

    # --- FFN (M125 semantics: gate/up matmuls, SiLU v2 member, Hadamard,
    #     down matmul; all requant edges + narrowings) ---------------------
    g8, _ = mm_requant(xm8, lay["wg"], sc["e_xm"], -9, silu_es, "acc768", f"{lname}.gate")
    u8, _ = mm_requant(xm8, lay["wu"], sc["e_xm"], -9, sc["e_up"], "acc768", f"{lname}.up")
    a8 = silu_tab[g8 + 128]                      # table domain-membership
    h_had = a8.astype(np.int64) * u8.astype(np.int64)
    F.acc("had15", h_had)
    sh_h = sc["e_h"] - silu_es - sc["e_up"]
    assert sh_h >= 0
    h8 = narrow_i8(requant(h_had, sh_h, f"{lname}.h"), f"{lname}.h")
    z8, _ = mm_requant(h8, lay["wd"], sc["e_h"], -9, sc["e_z"], "acc2048", f"{lname}.z")

    # --- residual add 2 ---------------------------------------------------
    e_r2c = min(sc["e_r1"], sc["e_z"])
    xw2 = (x1_8.astype(np.int64) << (sc["e_r1"] - e_r2c)) + (z8.astype(np.int64) << (sc["e_z"] - e_r2c))
    sh_r2 = sc["e_r2"] - e_r2c
    assert sh_r2 >= 0
    x2_8 = narrow_i8(requant(xw2, sh_r2, f"{lname}.res2"), f"{lname}.res2")

    caps = {"xn8": xn8, "q8": q8, "k8": k8, "qr8": qr8, "kr8": kr8,
            "p": p_all, "o8": o8, "ao8": ao8, "x1": x1_8, "xm8": xm8,
            "z8": z8, "x2": x2_8}
    return x2_8, sc["e_r2"], caps


def F_PV_SCALE(e_v):
    """Scale of the PV accumulator: P carries 2^-F_P, V carries 2^e_v."""
    return e_v - F_P


# ---------------------------------------------------------------------------
# 5. Width tables (125M + 8B), asserted analytically
# ---------------------------------------------------------------------------

def check_widths():
    # (name, worst-case bound, declared width, signedness): signed rows
    # carry two's-complement widths (accumulator convention), unsigned
    # rows ("u") carry [0, 2^w) widths (remainder/table-output convention).
    rows_125 = [
        ("qkv/wo/gate/up acc (inner 768)", 768 * 127 * 127, 25, "s"),
        ("down acc (inner 2048)", 2048 * 127 * 127, 26, "s"),
        ("score acc (inner 64)", 64 * 127 * 127, 21, "s"),
        ("PV acc (inner T=512, P<=2^9)", 512 * 512 * 127, 26, "s"),
        ("RoPE acc", 2 * 128 * 127, 16, "s"),
        ("xsq", 127 * 127, 15, "s"),
        ("SS + Ceps", 768 * 127 * 127 + 43, 24, "u"),
        ("D = isqrt(SSe)", math.isqrt(768 * 127 * 127 + 43), 12, "u"),
        ("E (exp out)", 1 << F_E, 10, "u"),
        ("Sum (masked row sum)", 512 * (1 << F_E), 19, "u"),
        ("P", 1 << F_P, 10, "u"),
        ("P*Sum (div check)", (1 << F_P) * 512 * (1 << F_E), 28, "u"),
        ("softmax rho/sigma", 512 * (1 << F_E) - 1, 18, "u"),
        ("rmsnorm num x*G*Cn (Cn<=2^11)", 127 * 127 * 2048, 26, "s"),
        # non-wrap term (never a committed class): centered-residue bound
        ("rmsnorm y*D*2^tn (tn=9 class)", 127 * 3520 * 512, 29, "s"),
        ("unembed acc (inner 768)", 768 * 127 * 127, 25, "s"),
    ]
    for name, bound, w, sg in rows_125:
        need = bits_signed(bound) if sg == "s" else bits_unsigned(bound)
        assert need <= w, f"{name}: needs {need} > {w}"
        assert bound < 2 ** 30 - 200, f"{name}: {bound} outside q31 headroom"
    # tightness of the three headline matmul rows (bound attained by the
    # all-extreme witness, so the width rows are not padded)
    assert bits_signed(768 * 127 * 127) == 25
    assert bits_signed(2048 * 127 * 127) == 26
    assert bits_signed(64 * 127 * 127) == 21
    ok("125M width table: all 16 declared class bounds hold at the stated "
       "widths (signed acc rows, unsigned aux rows), every bound inside "
       "q31 headroom (< 2^30); the three matmul rows are width-tight")

    rows_8b = [
        ("qkv/wo acc (inner 4096)", 4096 * 127 * 127, 27, "s"),
        ("ffn down acc (inner 14336)", 14336 * 127 * 127, 29, "s"),
        ("score acc (inner 128)", 128 * 127 * 127, 22, "s"),
        ("PV acc (T=512)", 512 * 512 * 127, 26, "s"),
        ("PV acc (T=2048, fP=9)", 2048 * 512 * 127, 28, "s"),
        ("SS + Ceps (d=4096)", 4096 * 127 * 127 + 6, 27, "u"),
        ("D = isqrt", math.isqrt(4096 * 127 * 127 + 6), 13, "u"),
        ("Sum (T=512)", 512 * (1 << F_E), 19, "u"),
        ("Sum (T=2048)", 2048 * (1 << F_E), 21, "u"),
        ("P*Sum (T=2048, fE=fP=9)", (1 << F_P) * 2048 * (1 << F_E), 30, "u"),
    ]
    for name, bound, w, sg in rows_8b:
        need = bits_signed(bound) if sg == "s" else bits_unsigned(bound)
        assert need <= w, f"8B {name}: {need} > {w}"
        assert bound <= 2 ** 30, f"8B {name}: {bound} outside q31 headroom"
    # the q31 ceiling at long context: P*Sum <= 2^(fE+fP+log2 T) must stay
    # under q/2 ~ 2^30 - 200, i.e. fE + fP + log2(T) <= 29 at these widths
    assert F_E + F_P + 11 <= 29       # T = 2048 at (9, 9) fits (2^29)
    assert F_E + F_P + 12 >= 30       # T = 4096 at (9, 9) BUSTS: recorded
    ok("8B width table: all 10 declared bounds hold (27-bit @ inner 4096 "
       "reproduces the contract row; 22-bit scores; T=2048 P*Sum = 2^29 "
       "fits, T=4096 at fE=fP=9 hits the q31 wall — the long-context "
       "resolution ceiling fE+fP <= 29 - log2(T) is real and recorded)")

    # contract-row reproduction (the M125 study's convention pin)
    assert 4096 * 127 * 127 < 2 ** 26 and bits_signed(4096 * 127 * 127) == 27
    assert 11008 * 127 * 127 < 2 ** 28 and bits_signed(11008 * 127 * 127) == 29
    ok("contract accumulator rows reproduce under [-127,127]: 27-bit @ "
       "4096, 29-bit @ 11008 (the study's Section 1 pin, re-checked here)")

    # exact power-of-two folds
    assert math.sqrt(64) == 8.0 and math.sqrt(4096) == 64.0
    ok("exact-fold findings: sqrt(d_h)=8 exact at 125M (2^-3 fold), "
       "sqrt(d)=64 exact for the 8B RMSNorm Cn (pure-shift constant); "
       "sqrt(768) and sqrt(128) are irrational -> folded into declared "
       "public constants (Cn) / table generation (lambda), never proven")


def check_worstcase():
    """Adversarial extreme witnesses attain the analytic accumulator
    bounds exactly (the width rows are attainable, not just safe)."""
    a = np.full((4, 768), 127, dtype=np.int64)
    b = np.full((768, 4), 127, dtype=np.int64)
    assert int((a @ b).max()) == 768 * 127 * 127
    q = np.full((4, HEAD_DIM), 127, dtype=np.int64)
    assert int((q @ q.T).max()) == 64 * 127 * 127
    p = np.full((4, T), 1 << F_P, dtype=np.int64)
    v = np.full((T, 4), 127, dtype=np.int64)
    assert int((p @ v).max()) == T * (1 << F_P) * 127
    c = np.int64(1 << F_RO)
    x = np.int64(127)
    assert int(c * x + c * x) == 2 * 128 * 127
    ok("worst-case attainability: all-extreme witnesses hit the exact "
       "analytic bounds for inner-768, score, PV and RoPE accumulators "
       "(the declared widths are tight, not padded)")


# ---------------------------------------------------------------------------
# 6. Embedding / unembedding
# ---------------------------------------------------------------------------

def check_embedding():
    emb = RNG.integers(-127, 128, size=(VOCAB, D_MODEL), dtype=np.int64)
    ids = RNG.integers(0, VOCAB, size=T)
    x0 = emb[ids]
    # public-input form: X0 = Sel @ Emb with public one-hot Sel; the spike
    # checks the exact identity the matmul-class claim certifies
    sel = np.zeros((8, VOCAB), dtype=np.int64)
    sel[np.arange(8), ids[:8]] = 1
    F.ident("embed.sel", sel @ emb, x0[:8])
    F.rng("embed.narrow", x0, -127, 128)     # inherited int8, no requant
    # unembedding (tied): last-position logits, inner 768 -> 25-bit
    xf = RNG.integers(-127, 128, size=(D_MODEL,), dtype=np.int64)
    lacc = emb @ xf
    F.acc("acc768", lacc)
    assert int(np.abs(lacc).max()) <= 768 * 127 * 127
    sh = 10
    l8 = requant(lacc, sh, "unembed")
    F.rng("unembed.width", l8, -(1 << 14), 1 << 14)
    ok("embedding/unembedding: public-selector identity X0 = Sel@Emb exact "
       "on committed int8 rows (no requant edge — rows inherit int8); tied "
       "unembed last-position logits ride the 25-bit inner-768 accumulator "
       "with a standard requant edge")


# ---------------------------------------------------------------------------
# 7. Main: derive scales, run 2 layers int vs fp, error report
# ---------------------------------------------------------------------------

def main():
    t0 = __import__("time").time()

    with open(CALIB_PATH) as f:
        calib = json.load(f)
    l0 = calib["calibration"][0]
    assert l0["eX"] == -3 and l0["eWg"] == -9
    ok(f"calibration study loaded ({os.path.basename(CALIB_PATH)}): layer-0 "
       f"eX={l0['eX']}, eW=-9, absmax X {l0['stats']['x']['absmax']:.2f} — "
       "the synthetic input generator below is shaped to these ranges")

    silu_m3, ctab, stab = check_tables()
    silu_m3 = np.array(silu_m3, dtype=np.int64)
    check_widths()
    check_worstcase()
    check_embedding()

    layers = build_model(2)
    x_fp = build_input()
    ax = float(np.abs(x_fp).max())
    assert 8.0 < ax < 40.0
    ok(f"synthetic residual stream built: absmax {ax:.2f}, p999 "
       f"{np.quantile(np.abs(x_fp), 0.999):.2f} (study-shaped outlier tail)")

    # ---- scale derivation (max-calibration, the study's rule) ------------
    x_cur = x_fp
    scales_all, e_r = [], pot_exp(ax)
    fp_caps_all = []
    for li, lay in enumerate(layers):
        _, caps = fp_forward_layer(x_cur, lay, ctab, stab)
        s_absmax = float(np.abs(caps["scores"]).max()) * math.sqrt(HEAD_DIM)
        sc = {
            "e_xn": pot_exp(float(np.abs(caps["xn"]).max())),
            "e_q": pot_exp(float(np.abs(caps["q"]).max()) * 1.05),
            "e_k": pot_exp(float(np.abs(caps["k"]).max()) * 1.05),
            "e_v": pot_exp(float(np.abs(caps["v"]).max()) * 1.05),
            "e_s": pot_exp(s_absmax),
            "e_o": pot_exp(float(np.abs(caps["o_pre"]).max()) * 1.05),
            "e_ao": pot_exp(float(np.abs(caps["att"]).max())),
            "e_r1": pot_exp(float(np.abs(caps["x1"]).max())),
            "e_xm": pot_exp(float(np.abs(caps["xm"]).max())),
            "e_gate": pot_exp(float(np.abs(caps["xm"] @ (lay["wg"] * 2.0 ** -9)).max())),
            "e_up": pot_exp(float(np.abs(caps["xm"] @ (lay["wu"] * 2.0 ** -9)).max())),
            "e_z": pot_exp(float(np.abs(caps["z"]).max())),
            "e_r2": pot_exp(float(np.abs(caps["x2"]).max())),
        }
        sc["e_h"] = max(pot_exp(float(np.abs(caps["h"]).max())),
                        sc["e_gate"] + sc["e_up"])    # calibrated, shift >= 0
        scales_all.append(sc)
        fp_caps_all.append(caps)
        x_cur = caps["x2"]
    ok("per-layer scale tables max-calibrated from the fp reference "
       f"(layer 0: eXn={scales_all[0]['e_xn']}, eQ={scales_all[0]['e_q']}, "
       f"eS={scales_all[0]['e_s']}, eAo={scales_all[0]['e_ao']}, "
       f"eR1={scales_all[0]['e_r1']})")

    # ---- integer forward, 2 layers ---------------------------------------
    x8 = np.clip(np.floor(x_fp / 2.0 ** e_r + 0.5), -127, 127).astype(np.int64)
    F.rng("input.narrow", x8, -127, 128)
    x8_cur, e_cur = x8, e_r
    int_caps_all = []
    for li, lay in enumerate(layers):
        sc = scales_all[li]
        exp_tab = np.array(exp_table_generate(sc["e_s"], HEAD_DIM), dtype=np.int64)
        # per-layer SiLU member at the calibrated gate scale (family rule:
        # eGate == eA members, the M125 pattern)
        silu_tab = np.array(silu_v2_generate(sc["e_gate"], sc["e_gate"]),
                            dtype=np.int64)
        x8_cur, e_cur, icaps = int_forward_layer(
            x8_cur, e_cur, lay, sc, ctab, stab, exp_tab, sc["e_s"],
            silu_tab, sc["e_gate"], f"L{li}")
        int_caps_all.append(icaps)
        assert e_cur == sc["e_r2"]
    ok(f"two full layers ran under the exact integer semantics: "
       f"{F.n_range} range facts + {F.n_ident} derivation identities all "
       "hold (requant remainders, narrowings, d-dominance, selector "
       "attainment, isqrt pairs, division relations, off-support pins)")

    # ---- accumulator peaks vs declared classes ---------------------------
    for cls, peak in sorted(F.acc_peak.items()):
        bound = CLS[cls]
        assert peak <= bound, f"{cls}: measured {peak} > declared {bound}"
    ok("accumulator audit: measured peak |acc| within the declared class "
       "bound for every class touched: " +
       ", ".join(f"{c}={F.acc_peak[c]:,}<={CLS[c]:,}" for c in sorted(F.acc_peak)))

    # ---- error vs fp32 ----------------------------------------------------
    def rel(a, b):
        den = np.linalg.norm(b.ravel())
        return float(np.linalg.norm((a - b).ravel()) / (den + 1e-30))

    sc0, ic0, fc0 = scales_all[0], int_caps_all[0], fp_caps_all[0]
    err_xn = rel(ic0["xn8"] * 2.0 ** sc0["e_xn"], fc0["xn"])
    err_q = rel(ic0["q8"] * 2.0 ** sc0["e_q"], fc0["q"])
    err_qr = rel(ic0["qr8"] * 2.0 ** sc0["e_q"], fc0["qr"])
    p_int = ic0["p"] * 2.0 ** -F_P
    err_p_max = float(np.abs(p_int - fc0["probs"]).max())
    err_p_mean = float(np.abs(p_int - fc0["probs"]).mean())
    err_att = rel(ic0["ao8"] * 2.0 ** sc0["e_ao"], fc0["att"])
    err_x2 = rel(int_caps_all[0]["x2"] * 2.0 ** sc0["e_r2"], fc0["x2"])
    print(f"    error vs fp reference (layer 0): xn {err_xn:.4f}, q {err_q:.4f}, "
          f"rope(q) {err_qr:.4f}, softmax P max {err_p_max:.4f} / mean "
          f"{err_p_mean:.6f}, attn-out {err_att:.4f}, block-out {err_x2:.4f}")
    assert err_xn < 0.10 and err_q < 0.15 and err_qr < 0.15
    assert err_p_max < 0.25 and err_p_mean < 0.02
    assert err_att < 0.75 and err_x2 < 0.60
    ok("error vs fp32 within sanity gates (wiring-bug detectors, not "
       "quality claims: quality is calibration work per the study's "
       "Section 4 finding, restated for attention in the spec)")

    # ---- softmax row-stochasticity (approximate, deliberately unclaimed) -
    mask = np.tril(np.ones((T, T), dtype=np.int64))
    prow = (int_caps_all[0]["p"][0] * mask).sum(axis=1)
    lo, hi = int(prow.min()), int(prow.max())
    assert hi <= (1 << F_P) and lo >= (1 << F_P) - T
    ok(f"row-mass audit: sum_j P in [{lo}, {hi}] against 2^{F_P} = "
       f"{1 << F_P} — floor semantics lose < T units of mass; the spec "
       "declares the division facts, NOT exact row-stochasticity")

    # ---- determinism ------------------------------------------------------
    x8_rep, e_rep = x8, e_r
    exp_tab0 = np.array(exp_table_generate(scales_all[0]["e_s"], HEAD_DIM),
                        dtype=np.int64)
    silu_tab0 = np.array(
        silu_v2_generate(scales_all[0]["e_gate"], scales_all[0]["e_gate"]),
        dtype=np.int64)
    x8_rep, _, icaps_rep = int_forward_layer(
        x8_rep, e_rep, layers[0], scales_all[0], ctab, stab, exp_tab0,
        scales_all[0]["e_s"], silu_tab0, scales_all[0]["e_gate"], "REP")
    h1 = sha256_hex(np.ascontiguousarray(int_caps_all[0]["x2"], "<i8").tobytes())
    h2 = sha256_hex(np.ascontiguousarray(x8_rep, "<i8").tobytes())
    assert h1 == h2
    ok(f"determinism: layer-0 re-run reproduces the block output digest "
       f"({h1[:16]}..) — the declared function is a function")

    # ---- swept-input width/fact audit (fresh seeded draws, same model) ---
    for sw in range(2):
        rng_sw = np.random.default_rng(SEED + 1000 + sw)
        xs = rng_sw.normal(0.0, 1.1, size=(T, D_MODEL))
        idx = rng_sw.integers(0, T * D_MODEL, 200)
        xs.ravel()[idx] += rng_sw.choice([-1.0, 1.0], 200) * rng_sw.uniform(4.0, 14.0, 200)
        _, capsw = fp_forward_layer(xs, layers[0], ctab, stab)
        e_rw = pot_exp(float(np.abs(xs).max()))
        s_absmax = float(np.abs(capsw["scores"]).max()) * math.sqrt(HEAD_DIM)
        scw = {
            "e_xn": pot_exp(float(np.abs(capsw["xn"]).max())),
            "e_q": pot_exp(float(np.abs(capsw["q"]).max()) * 1.05),
            "e_k": pot_exp(float(np.abs(capsw["k"]).max()) * 1.05),
            "e_v": pot_exp(float(np.abs(capsw["v"]).max()) * 1.05),
            "e_s": pot_exp(s_absmax),
            "e_o": pot_exp(float(np.abs(capsw["o_pre"]).max()) * 1.05),
            "e_ao": pot_exp(float(np.abs(capsw["att"]).max())),
            "e_r1": pot_exp(float(np.abs(capsw["x1"]).max())),
            "e_xm": pot_exp(float(np.abs(capsw["xm"]).max())),
            "e_gate": pot_exp(float(np.abs(capsw["xm"] @ (layers[0]["wg"] * 2.0 ** -9)).max())),
            "e_up": pot_exp(float(np.abs(capsw["xm"] @ (layers[0]["wu"] * 2.0 ** -9)).max())),
            "e_z": pot_exp(float(np.abs(capsw["z"]).max())),
            "e_r2": pot_exp(float(np.abs(capsw["x2"]).max())),
        }
        scw["e_h"] = max(pot_exp(float(np.abs(capsw["h"]).max())),
                         scw["e_gate"] + scw["e_up"])
        x8w = np.clip(np.floor(xs / 2.0 ** e_rw + 0.5), -127, 127).astype(np.int64)
        exp_w = np.array(exp_table_generate(scw["e_s"], HEAD_DIM), dtype=np.int64)
        silu_w = np.array(silu_v2_generate(scw["e_gate"], scw["e_gate"]),
                          dtype=np.int64)
        int_forward_layer(x8w, e_rw, layers[0], scw, ctab, stab, exp_w,
                          scw["e_s"], silu_w, scw["e_gate"], f"SW{sw}")
    for cls, peak in sorted(F.acc_peak.items()):
        assert peak <= CLS[cls], f"sweep {cls}: {peak} > {CLS[cls]}"
    ok("swept-input audit: two fresh seeded input draws (max-calibrated "
       "per draw) ran the full layer-0 integer path — every range fact, "
       "derivation identity and accumulator class bound held across the "
       "sweep (fail-by-design semantics exercised on 3 input draws total)")

    dt = __import__("time").time() - t0
    print(f"\nall attention_spec_spike assertions passed ({CHECK[0]}/{CHECK[0]} OK, "
          f"{F.n_range} range facts, {F.n_ident} identities, {dt:.1f} s, seed {SEED})")


if __name__ == "__main__":
    main()

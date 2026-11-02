#!/usr/bin/env python3
"""[GATE ROUND 7 helper, 2026-10-19] The PER-SLOT TERMINAL IDENTITY of the
token-I/O stages' new slots (stage IN, 4 slots; stage OUT, 11 slots), and an
NL-1 structural check of the same slots on a symbolic expansion.

NOTHING HERE IS A PRIVACY RESULT OR A PRIVACY ACCEPTANCE.

WHAT IS CHECKED (the block analogue is `zk60_native_rg_terminals.py`).

    fin_s == c_s * mask_eval_s + poly_s(vals_s)

is the verifier's own final check of one stage slot: `token_io.rs:992`
(`let g_val = fin.sub((def.poly)(&vals)).mul(c.inv());`), with `fin` from
`sumcheck::verify(claimed, degree, n + ext, ..)` (`token_io.rs:975`) and
`claimed = scalar + sum_hosted coef * scalar[hs]` (`token_io.rs:974`).  The
capture writes `mask_eval = g_val` and `terminal_polynomial = fin -
c*mask_eval` (`run_capture.rs:1199-1209`, called from `token_io.rs:1036`
with `g_val`).  So:

(a) every PUBLIC table of the slot is evaluated at the slot's sumcheck point
    `rho[:main]` (MSB-first MLE, `zkp-core/src/mle.rs:72`, times the
    extension selector `sel = prod(1 - e)`, `token_io.rs:978-985`) from the
    capture's RECORDED values, after the values are checked against the
    capture's own `len` / `sha256`; a table that is a function of the
    geometry or of a re-derived challenge is ALSO rebuilt here, digest
    compared, evaluated, and the two evaluations compared.  The capture
    records no table evaluation of its own: an evaluation enters the record
    only through `terminal_polynomial`, which (b) compares.
(b) the slot polynomial is TRANSCRIBED from `define` (`stage_in.rs:149-221`,
    `stage_out.rs:336-542`) through a builder that mirrors `SB`
    (`token_io.rs:1064-1129`), evaluated on the recorded terminals, the
    public-table evaluations and the RE-DERIVED definition challenges, and
    compared with `terminal_polynomial`.
(c) `fin` is recomputed from the published rounds and `claimed` (the frozen
    `sumcheck_final`, the port of `zkp-core sumcheck::verify`), compared with
    the capture's `sumcheck_final` / `claimed_sum`, and the relation above is
    checked with the recomputed polynomial.

Every challenge comes from `zk60_native_rg_tokengate.TokenRunReplay` (the
transcript re-derived), never from the capture, when a replay is given.

What (c) does NOT establish: that `mask_eval` is the committed mask's value
at `rho_full`.  That is the masking commitment's opening (G-3, the frozen CFS
port `token_mask_cfs`); here `mask_eval` is the verifier's derived value.

What (a) does NOT establish for the two tables it TAKES from the capture
(stage IN's `tau(v) = v + beta E~(v, r_emb) + g_emb`, `stage_in.rs:145-147`;
stage OUT's head fold `Wf = sum_j e_j m_j W'_j`, `stage_out.rs:412-418`,
`token_io.rs:612-631`): that they fold the embedding / head the statement
names.  No bundle carries those weights.  They are checked for length,
digest and the structure their builder gives them (tau's padded rows repeat
row 0; Wf vanishes on padded columns), and no more.  Soundness-side reading.

NL-1 (`nl1_token_slots`).  The same transcription run on a SYMBOLIC ring: every
table is a variable (eq tables and public tables are PUBLIC symbols; A / H /
IO plane terminals are PRIVATE variables), and challenges are either
(i) formal symbols (the result then holds for EVERY challenge value), or
(ii) the run's re-derived values as constants.  The premises checked per slot
are S1's (`results/zk60_nonlinear_channel_shaped/nl_check.py:847-936`,
`docs/zkmatrix-poc/ZK60_NONLINEAR_CHANNEL_SHAPED_DISPOSITION.md` NL-1 / NL-3):
a public TABLE factor in every monomial (an affine `1 - supp` is not a public
factor: the expansion splits it), product degree within the declared degree,
and the private-terminal count equal to the slot's `terminals`.  With one
extension round and every private table in round 0 (checked), S1's per-round
premise is exactly the public-factor condition.

The port was READ at the Rust digests in `PORTED_FROM`; a bundle pinning any
other digest is refused before any slot is evaluated.
"""

from __future__ import annotations

import copy
import json
import os
import resource
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import zk60_native_rg_tokengate as TG  # noqa: E402
import zk60_native_rg_tokenio as TIO  # noqa: E402
from zk60_native_jv_cfs import sumcheck_final  # noqa: E402
from zk60_native_jv_field import (  # noqa: E402
    F2_ONE,
    F2_ZERO,
    P,
    eq_table_msb,
    f2_add,
    f2_from_list,
    f2_inv,
    f2_mul,
    f2_mul_base,
    f2_neg,
    f2_sub,
)
from zk60_native_rg_terminals import eq_point, table_digest  # noqa: E402

add, sub, mul, mulb = f2_add, f2_sub, f2_mul, f2_mul_base
ONE, ZERO = F2_ONE, F2_ZERO

# --------------------------------------------------------------- source pins
# [READ] the digests of the Rust this port was transcribed from (sha256 of the
# files in ops/zkp-mvp/token-io/hashline, 2026-10-19 18:13 UTC), which are the
# digests the four L1/L2 captures pin in their manifests.
PORTED_FROM = {
    "src/private_block/token_io/stage_in.rs": "0387e6b1a9f617eb21bf79e76bf131dff8ba62a8ff6df875e0a78de606717728",
    "src/private_block/token_io/stage_out.rs": "69abed433fd751bf12b30fca40174ca21638230fd9e39af69ea07b987d03e8ca",
    "src/private_block/token_io.rs": "396daba1a49477ba7f2034a31d053f51b41d67704487fc78ab65ce604029092a",
    "src/private_block/run_capture.rs": "aaff4e6e20c4deca7a0342f5b7dd2b9ac53a2837432af72f57c8a852e479db5e",
}

# [READ] token_io.rs:259 TAG_EMB; tables_attn.rs:70 TAG_U8; token_io.rs:261-265
TAG_EMB = 135
TAG_U8 = 133
U8_LEN = 256
LIMBS_ISQRT = 3
NORM_LIMBS = 4
TO_LOG = 1  # stage_out.rs:22

# [READ] stage_in.rs:19-28
IN_A_TOK, IN_A_MULT = 0, 1
IN_H_Q, IN_H_TAB, IN_H_U = 0, 1, 2
SI_IO, SI_QZC, SI_TZC, SI_ZS = 0, 1, 2, 3
# [READ] stage_out.rs:24-65
A_D, A_DSQ, A_TOK, A_M, A_LIMB, A_X, A_XL0, A_XL1, A_Y = 0, 1, 2, 3, 4, 5, 6, 7, 8
A_RHO0, A_SIG0, A_E, A_LAM0 = 9, 13, 17, 18
H_LO, H_D0, H_DO_HELPERS, H_V0 = 0, 1, 6, 7
SO_IO, SO_SS, SO_TZC, SO_LZC, SO_HEAD, SO_DZC, SO_VZC, SO_RSEL, SO_TAB, SO_ZS, SO_IOOUT = range(11)


def a_mult(limbs):  # stage_out.rs:38-40
    return A_LAM0 + limbs


def hv(limbs):  # stage_out.rs:45-47
    return -(-limbs // 2)


def h_gu8(limbs):  # stage_out.rs:48-50
    return H_V0 + hv(limbs)


def h_u(limbs):  # stage_out.rs:51-53
    return H_V0 + hv(limbs) + 1


# [READ] the plane names, in plane order (stage_in.rs:479-480,
# stage_out.rs:874-883)
IN_A_NAMES = ["A_TOK", "A_MULT"]
IN_H_NAMES = ["H_Q", "H_TAB", "H_U"]


def out_a_names(l):
    a = ["A_D", "A_DSQ", "A_TOK", "A_M", "A_LIMB", "A_X", "A_XL0", "A_XL1", "A_Y"]
    a += [f"A_RHO{i}" for i in range(4)] + [f"A_SIG{i}" for i in range(4)]
    return a + ["A_E"] + [f"A_LAM{i}" for i in range(l)] + ["A_MU8"]


def out_h_names(l):
    return ["H_LO"] + [f"H_D{i}" for i in range(H_DO_HELPERS)] + [f"H_V{i}" for i in range(hv(l))] + ["H_GU8", "H_U"]


# [READ] the Rust SlotSpec names (stage_in.rs:44-47, stage_out.rs:88-98)
IN_NAMES = [
    "IN-00 IO-in: token endpoint = supp_T tok (whole padded plane)",
    "IN-01 query zero-check: LogUp + BOS (own mu_bos) + pad, fresh mu each",
    "IN-02 table zero-check: h_tab (alpha - tau) = m + pad, fresh mu each",
    "IN-03 ZS zero-sum row",
]
OUT_NAMES = [
    "OUT-00 IO-in: x = B_out row T-1 (fixed public row bits)",
    "OUT-01 SS final-norm row sum (private, hosted by TZC)",
    "OUT-02 TZC isqrt (D, Dsq, 9 limb slices; hosts SS)",
    "OUT-03 LZC limb lookups (+pad)",
    "OUT-04 HEAD matmul sum_i y(i) W'(r_j, i) (private, hosted by VZC)",
    "OUT-05 DZC final-norm quotient + x limbs + helpers (+pad)",
    "OUT-06 VZC e(1-e) + head host term on keyed l* + helpers (+pad)",
    "OUT-07 RSEL supp e (c1 + c2 iota + c3 delta) - u0 (c1 + c2 tok) (standalone)",
    "OUT-08 TAB byte-table helper (+pad)",
    "OUT-09 ZS zero-sum row",
    "OUT-10 IO-out: output endpoint = u0 tok (whole 256-word plane)",
]
# the slots whose define carries a pad term (the drop-a-pad control's set)
PAD_SLOTS = {("IN", SI_QZC), ("IN", SI_TZC), ("OUT", SO_TZC), ("OUT", SO_LZC),
             ("OUT", SO_DZC), ("OUT", SO_VZC), ("OUT", SO_TAB)}


def k(v: int):
    """`Fp2::from_i64` (`zkp-core/src/field.rs:148`, `token_io.rs:835`)."""
    return (v % P, 0)


def clog2(v: int) -> int:
    return TIO.clog2(v)


# =====================================================================
#  two rings: numeric Fp2 and a symbolic polynomial ring over Fp2
# =====================================================================
class F2:
    """A numeric Fp2 element with operators, so one transcription serves both
    the numeric identity and the symbolic expansion."""

    __slots__ = ("v",)

    def __init__(self, v):
        self.v = (v[0] % P, v[1] % P)

    @staticmethod
    def _co(o):
        if isinstance(o, F2):
            return o.v
        if isinstance(o, int):
            return k(o)
        if isinstance(o, tuple):
            return o
        return None

    def __add__(self, o):
        c = F2._co(o)
        return NotImplemented if c is None else F2(add(self.v, c))

    __radd__ = __add__

    def __sub__(self, o):
        c = F2._co(o)
        return NotImplemented if c is None else F2(sub(self.v, c))

    def __rsub__(self, o):
        c = F2._co(o)
        return NotImplemented if c is None else F2(sub(c, self.v))

    def __mul__(self, o):
        c = F2._co(o)
        return NotImplemented if c is None else F2(mul(self.v, c))

    __rmul__ = __mul__

    def __neg__(self):
        return F2(f2_neg(self.v))

    def __eq__(self, o):
        c = F2._co(o)
        return c is not None and c == self.v

    def __hash__(self):
        return hash(self.v)

    def __repr__(self):
        return f"F2{self.v}"


def K(v: int) -> F2:
    return F2(k(v))


R_ONE, R_ZERO = F2(ONE), F2(ZERO)


def _mono_mul(a, b):
    if not a:
        return b
    if not b:
        return a
    d = dict(a)
    for n, e in b:
        d[n] = d.get(n, 0) + e
    return tuple(sorted(d.items()))


class Poly:
    """A polynomial over Fp2: {monomial: coefficient}, a monomial a sorted
    tuple of (variable name, exponent).  Exact; zero coefficients dropped."""

    __slots__ = ("t",)

    def __init__(self, t=None):
        self.t = {m: c for m, c in (t or {}).items() if c != ZERO}

    @staticmethod
    def var(name):
        return Poly({((name, 1),): ONE})

    @staticmethod
    def const(c):
        return Poly({(): c})

    @staticmethod
    def _co(o):
        if isinstance(o, Poly):
            return o
        if isinstance(o, F2):
            return Poly.const(o.v)
        if isinstance(o, int):
            return Poly.const(k(o))
        if isinstance(o, tuple):
            return Poly.const(o)
        return None

    def __add__(self, o):
        q = Poly._co(o)
        if q is None:
            return NotImplemented
        t = dict(self.t)
        for m, c in q.t.items():
            t[m] = add(t.get(m, ZERO), c)
        return Poly(t)

    __radd__ = __add__

    def __neg__(self):
        return Poly({m: f2_neg(c) for m, c in self.t.items()})

    def __sub__(self, o):
        q = Poly._co(o)
        return NotImplemented if q is None else self + (-q)

    def __rsub__(self, o):
        q = Poly._co(o)
        return NotImplemented if q is None else q + (-self)

    def __mul__(self, o):
        q = Poly._co(o)
        if q is None:
            return NotImplemented
        t = {}
        for m1, c1 in self.t.items():
            for m2, c2 in q.t.items():
                m = _mono_mul(m1, m2)
                t[m] = add(t.get(m, ZERO), mul(c1, c2))
        return Poly(t)

    __rmul__ = __mul__

    def evaluate(self, assign: dict):
        acc = ZERO
        for m, c in self.t.items():
            p = c
            for n, e in m:
                x = assign[n]
                for _ in range(e):
                    p = mul(p, x)
            acc = add(acc, p)
        return acc


def _poly_self_test() -> bool:
    x, y = Poly.var("x"), Poly.var("y")
    a = (x + y) * (x - y)
    b = x * x - y * y
    c = (R_ONE - x) * (x + K(3) * y)
    ok = a.t == b.t and len(c.t) == 4 and (x - x).t == {}
    ok = ok and F2((5, 0)) * 2 == F2((10, 0)) and (1 - F2((3, 0))).v == k(-2)
    return ok


# =====================================================================
#  the port: a builder mirroring SB (token_io.rs:1064-1129) and the two
#  `define`s, line by line
# =====================================================================
class Draws:
    """The slot's definition challenges, consumed in transcript order."""

    def __init__(self, num, mode):
        self.num = list(num)        # re-derived Fp2 values
        self.mode = mode            # "numeric" | "symbolic"
        self.pos = 0
        self.labels = []
        self.zero = []

    def take(self, n, label, nonzero=False):
        if self.pos + n > len(self.num):
            raise ValueError(f"the port draws {self.pos + n} definition challenges, the slot "
                             f"carries {len(self.num)}")
        vals = self.num[self.pos:self.pos + n]
        self.labels.append((label, n))
        self.pos += n
        if nonzero and any(v == ZERO for v in vals):
            self.zero.append(label)   # `nonzero` (token_io.rs:838) would refuse
        ring = [F2(v) for v in vals] if self.mode == "numeric" else [
            Poly.var(f"c:{label}[{i}]") for i in range(n)]
        return vals, ring


class Ctx:
    """What a slot's closure captured: the geometry, the stage's LogUp
    challenges (ring elements), the per-slot definition draws, and the
    control flags."""

    def __init__(self, bundle, kind, logup, r_emb, mode, drop_pad=False, extra=None):
        ti = bundle.run["token_io"]
        g = bundle.geom
        self.kind, self.mode = kind, mode
        self.tokens, self.t_pad, self.d, self.d_pad, self.v = ti["T"], ti["t_pad"], ti["d"], ti["d_pad"], ti["V"]
        self.v_pad = ti["V_pad"]
        self.log_v = clog2(self.v_pad)
        self.limbs = g.limbs
        self.bos = ti["bos"]
        fn = ti["final_norm"]
        self.g0, self.cn, self.tn, self.ceps = fn["g0"], fn["cn"], fn["tn"], fn["ceps"]
        self.geom = g
        self.lay = g.stage_in() if kind == "IN" else g.stage_out()
        self.n = 1 << self.lay.log_n
        # the IO mask rows the RUN schedule gives the stage
        # (stage_in.rs:369/438, stage_out.rs:733/802): B_in site 0, B_out
        # site 1, a token endpoint's pair right after its data rows
        self.b_in_row = ti["b_in"]["site_rows"][0]
        self.b_out_row = ti["b_out"]["site_rows"][2]
        self.b_log = clog2(self.t_pad * self.d_pad)
        self.ep_mask_row = (ti["input_endpoint"] if kind == "IN" else ti["output_endpoint"])["data_rows"]
        self.r_emb = list(r_emb) if r_emb is not None else []
        self.drop_pad = drop_pad
        self.extra = extra
        # LogUp challenges: IN draws beta, gamma, alpha (stage_in.rs:240-244);
        # OUT draws gamma, alpha (stage_out.rs:797-799)
        self.logup_num = list(logup)
        if mode == "numeric":
            ring = [F2(x) for x in logup]
        else:
            ring = [Poly.var(n) for n in (("c:beta", "c:gamma", "c:alpha") if kind == "IN" else ("c:gamma", "c:alpha"))]
        if kind == "IN":
            self.beta, gamma, self.alpha = ring
            self.g_emb = gamma * K(TAG_EMB)              # stage_in.rs:244
            self.g_emb_num = mulb(logup[1], TAG_EMB)
        else:
            gamma, self.alpha = ring
            self.g_u8 = gamma * K(TAG_U8)                # stage_out.rs:799
            self.g_u8_num = mulb(logup[0], TAG_U8)

    def pad(self, x):
        """the pad term, or nothing in the drop-a-pad control copy"""
        return R_ZERO if self.drop_pad else x


def rho_c(r):
    """`rho(range)` (token_io.rs:829)"""
    return [("rho", i) for i in r]


def fixed_c(p):
    """`fixed(&[Fp2])` (token_io.rs:832)"""
    return [("fixed", tuple(x)) for x in p]


def fixed_bits_c(value, bits):
    """`fixed_bits` (token_io.rs:845-847): MSB-first"""
    return [("fixed", ONE if (value >> (bits - 1 - b)) & 1 else ZERO) for b in range(bits)]


class SlotDef:
    def __init__(self, slot, tabs, poly, hosted, parts, draws):
        self.slot, self.tabs, self.poly, self.hosted, self.parts, self.draws = slot, tabs, poly, hosted, parts, draws


class B:
    """`SB` (token_io.rs:1064-1129): counts the claim sites each slot pushes
    against the declared schedule, and records each table's kind."""

    def __init__(self, cx: Ctx, slot: int):
        self.cx, self.slot = cx, slot
        self.lay = cx.lay
        self.tabs = []
        self.ak = self.hk = self.iok = 0
        self.roles = ["A-in", "H-in", "E-token-in", "B-in"] if cx.kind == "IN" else ["A-out", "H-out", "B-out", "E-token-out"]
        self.a_names = IN_A_NAMES if cx.kind == "IN" else out_a_names(cx.limbs)
        self.h_names = IN_H_NAMES if cx.kind == "IN" else out_h_names(cx.limbs)

    def _push(self, t):
        self.tabs.append(t)
        return len(self.tabs) - 1

    def eq(self, point_num, start=0, label="tau"):
        return self._push({"kind": "eq", "point": [tuple(x) for x in point_num], "start": start, "label": label})

    def tabs_len(self):
        return len(self.tabs)

    def public(self, desc):
        return self._push({"kind": "public", "desc": desc})

    def a_slice(self, off, log, coords, plane):
        rows = self.lay.a_site_rows(self.slot)
        if self.ak >= len(rows):
            raise ValueError(f"undeclared A site {self.ak} in slot {self.slot}")
        mask_row = rows[self.ak]
        self.ak += 1
        return self._push({"kind": "private", "role": self.roles[0], "plane": plane,
                           "slices": [(off, ONE)], "log": log, "coords": coords, "mask_row": mask_row})

    def a_at(self, plane, coords):
        off = self.lay.a_off_rows[plane] * self.cx.n
        return self.a_slice(off, self.lay.a_log[plane], coords, self.a_names[plane])

    def a(self, plane):
        return self.a_at(plane, rho_c(range(self.lay.a_log[plane])))

    def h(self, plane):
        rows = self.lay.h_site_rows(self.slot)
        if self.hk >= len(rows):
            raise ValueError(f"undeclared H site {self.hk} in slot {self.slot}")
        mask_row = rows[self.hk]
        self.hk += 1
        re, im = self.lay.h_off_rows[plane]
        log = self.lay.h_log[plane]
        return self._push({"kind": "private", "role": self.roles[1], "plane": self.h_names[plane],
                           "slices": [(re * self.cx.n, ONE), (im * self.cx.n, (0, 1))], "log": log,
                           "coords": rho_c(range(log)), "mask_row": mask_row})

    def io(self, cm, log, coords, mask_row):
        self.iok += 1
        role = self.roles[2] if cm == "In" else self.roles[3]
        return self._push({"kind": "private", "role": role, "plane": role, "slices": [(0, ONE)],
                           "log": log, "coords": coords, "mask_row": mask_row})

    def finish(self, poly, hosted, parts, draws):
        sp = self.lay.slots[self.slot]
        if (self.ak, self.hk, self.iok) != (sp.a_sites, sp.h_sites, sp.io_sites):
            raise ValueError(f"slot {self.slot} uses {self.ak} A / {self.hk} H / {self.iok} IO sites, "
                             f"the schedule declares {sp.a_sites} / {sp.h_sites} / {sp.io_sites}")
        cx = self.cx

        def total(v):
            p = poly(v)
            if cx.extra is not None:
                p = p + cx.extra(v, self)
            return p
        return SlotDef(self.slot, self.tabs, total, hosted, parts, draws)


def helper_sum(v, lks, h0, alpha, mu):
    """`helper_sum` (token_io.rs:1134-1150): helper k covers lookups
    (2k, 2k+1), an odd count leaves the last single."""
    def den(l):
        terms, cst = l
        a = cst
        for (i, c) in terms:
            a = a + v[i] * K(c)
        return alpha - a

    acc = R_ZERO
    for kk in range((len(lks) + 1) // 2):
        h = v[h0 + kk]
        d1 = den(lks[2 * kk])
        if 2 * kk + 1 < len(lks):
            d2 = den(lks[2 * kk + 1])
            rel = h * d1 * d2 - (d1 + d2)
        else:
            rel = h * d1 - R_ONE
        acc = acc + mu[kk] * rel
    return acc


def zeta_fold(v, planes, zeta):
    """`zeta_fold` (token_io.rs:1153-1161): sum_j zeta^j plane_j"""
    p = R_ONE
    acc = R_ZERO
    for t in planes:
        acc = acc + p * v[t]
        p = p * zeta
    return acc


def resolve(lks, idx, g_u8):
    """`resolve` (stage_out.rs:332-334): plane ids -> table indices, the
    constant tagged with g_u8"""
    return [([(idx(p), c) for (p, c) in terms], K(cst) + g_u8) for (terms, cst) in lks]


def lookups_lo():  # stage_out.rs:142-144
    return [([(A_LIMB, 1)], 0)]


def lookups_do():  # stage_out.rs:145-150
    v = [([(A_XL0, 1)], 0), ([(A_XL1, 1)], 0), ([(A_Y, 1)], 127), ([(A_Y, -1)], 127)]
    v += [([(A_RHO0 + kk, 1)], 0) for kk in range(NORM_LIMBS)]
    v += [([(A_SIG0 + kk, 1)], 0) for kk in range(NORM_LIMBS)]
    return v


def lookups_vo(limbs):  # stage_out.rs:151-153
    return [([(A_LAM0 + kk, 1)], 0) for kk in range(limbs)]


# ---------------------------------------------------------------- stage IN
def define_in(slot, cx: Ctx, dr: Draws) -> SlotDef:
    """`stage_in.rs:149-221` `define`, line by line."""
    b = B(cx, slot)
    alpha, beta, g_emb = cx.alpha, cx.beta, cx.g_emb
    tl, sn = cx.geom.ti_log(), 1 << cx.geom.ti_log()          # :154
    lv, vn = cx.geom.voc_log(), 1 << cx.geom.voc_log()        # :155
    t_bits = clog2(cx.t_pad)                                   # :156
    if slot == SI_IO:                                          # :160-171
        words = cx.geom.in_ep_words()
        lw = clog2(words)
        tau, _ = dr.take(lw, "tau")                            # :163
        i_eq = b.eq(tau, 0)
        i_supp = b.public(("supp", cx.tokens, words))          # :165
        ct = fixed_c([ZERO] * (tl - lw)) + rho_c(range(lw))    # :166-167
        i_tok = b.a_at(IN_A_TOK, ct)
        i_end = b.io("In", lw, rho_c(range(lw)), cx.ep_mask_row)

        def poly(v):                                           # :170
            return v[i_eq] * (v[i_end] - v[i_supp] * v[i_tok])
        return b.finish(poly, [], ["eq(tau)", "endpoint - supp_T * tok"], dr)
    if slot == SI_QZC:                                         # :174-197
        tau, _ = dr.take(tl, "tau")                            # :175
        _, mu = dr.take(3, "mu", nonzero=True)                 # :176
        _, zz = dr.take(1, "zeta", nonzero=True)               # :177
        zeta = zz[0]
        i_eq = b.eq(tau, 0)
        i_supp = b.public(("supp", cx.tokens, sn))             # :179
        i_u0 = b.public(("supp", 1, sn))                       # :180
        i_tok = b.a(IN_A_TOK)
        i_hq = b.h(IN_H_Q)
        cb = rho_c(range(tl - t_bits, tl)) + fixed_c(cx.r_emb)  # :185-186
        i_b = b.io("Out", cx.b_log, cb, cx.b_in_row)
        bos = K(cx.bos)                                        # :188

        def poly(v):                                           # :189-195
            q = v[i_tok] + beta * v[i_b] + g_emb
            logup = v[i_hq] * (alpha - q) - v[i_supp]
            bos_c = v[i_u0] * (v[i_tok] - bos)
            pad = cx.pad((R_ONE - v[i_supp]) * (v[i_tok] + zeta * v[i_hq]))
            return v[i_eq] * (mu[0] * logup + mu[1] * bos_c + mu[2] * pad)
        return b.finish(poly, [], ["eq(tau)", "mu0 LogUp h_q (alpha - q) - supp_T", "mu1 BOS u0 (tok - bos)",
                                   "mu2 pad (1 - supp_T)(tok + zeta h_q)"], dr)
    if slot == SI_TZC:                                         # :198-213
        tau, _ = dr.take(lv, "tau")
        _, mu = dr.take(2, "mu", nonzero=True)
        _, zz = dr.take(1, "zeta", nonzero=True)
        zeta = zz[0]
        i_eq = b.eq(tau, 0)
        i_supp = b.public(("supp", cx.v, vn))                  # :203
        i_tau = b.public(("captured", "tau_tab"))              # :204
        i_m = b.a(IN_A_MULT)
        i_h = b.h(IN_H_TAB)

        def poly(v):                                           # :207-211
            rel = v[i_h] * (alpha - v[i_tau]) - v[i_m]
            pad = cx.pad((R_ONE - v[i_supp]) * (v[i_m] + zeta * v[i_h]))
            return v[i_eq] * (mu[0] * rel + mu[1] * pad)
        return b.finish(poly, [], ["eq(tau)", "mu0 h_tab (alpha - tau) - m", "mu1 pad (1 - supp_V)(m + zeta h_tab)"], dr)
    if slot == SI_ZS:                                          # :214-218
        i1 = b.public(("ones", 1 << cx.lay.h_log[IN_H_U]))
        iu = b.h(IN_H_U)
        return b.finish(lambda v: v[i1] * v[iu], [], ["ones * u"], dr)
    raise ValueError("token I/O stage IN: unknown slot")


# ---------------------------------------------------------------- stage OUT
def define_out(slot, cx: Ctx, dr: Draws, pts: dict) -> SlotDef:
    """`stage_out.rs:336-542` `define`, line by line."""
    b = B(cx, slot)
    alpha, g_u8 = cx.alpha, cx.g_u8
    l = cx.limbs
    d_bits = clog2(cx.d_pad)                                   # :341
    t_bits = clog2(cx.t_pad)
    g = cx.geom
    llo, lo_n = g.lo_log(), 1 << g.lo_log()
    ldo, do_n = g.do_log(), 1 << g.do_log()
    lvo, vo_n = g.vo_log(), 1 << g.vo_log()
    ltab, tab_n = g.tab_log(), 1 << g.tab_log()
    lift = ldo - d_bits                                        # :350
    ow, low = g.out_ep_words(), clog2(g.out_ep_words())       # :351

    def f0():                                                  # :352
        return [("fixed", ZERO)] * TO_LOG

    if slot == SO_IO:                                          # :355-365
        tau, _ = dr.take(d_bits, "tau")
        i_eq = b.eq(tau, 0)
        i_x = b.a_at(A_X, fixed_c([ZERO] * lift) + rho_c(range(d_bits)))
        cb = fixed_bits_c(cx.tokens - 1, t_bits) + rho_c(range(d_bits))
        i_b = b.io("In", cx.b_log, cb, cx.b_out_row)
        return b.finish(lambda v: v[i_eq] * (v[i_x] - v[i_b]), [], ["eq(tau)", "x - B_out(T-1, .)"], dr)
    if slot == SO_SS:                                          # :366-370
        i_s = b.public(("supp", cx.d, do_n))
        i_x = b.a(A_X)
        return b.finish(lambda v: v[i_s] * v[i_x] * v[i_x], [], ["supp_d * x * x"], dr)
    if slot == SO_TZC:                                         # :371-394
        tau, _ = dr.take(TO_LOG, "tau")
        _, mu = dr.take(4, "mu", nonzero=True)
        nu_num, nus = dr.take(1, "nu", nonzero=True)
        nu = nus[0]
        _, zz = dr.take(1, "zeta", nonzero=True)
        zeta = zz[0]
        i_eq = b.eq(tau, 0)
        i_u0 = b.public(("supp", 1, 1 << TO_LOG))              # :377
        i_d = b.a(A_D)
        i_dsq = b.a(A_DSQ)
        i_l0 = i_dsq + 1
        for kk in range(3 * LIMBS_ISQRT):                      # :381-383
            b.a_slice(cx.lay.a_off_rows[A_LIMB] * cx.n + 2 * kk, TO_LOG, rho_c(range(TO_LOG)), "A_LIMB")
        k_ceps = K(cx.ceps)
        p1, p2 = K(256), K(65536)

        def poly(v):                                           # :386-392
            def l3(o):
                return v[o] + v[o + 1] * p1 + v[o + 2] * p2
            d, dsq, dl, a1, a2 = v[i_d], v[i_dsq], l3(i_l0), l3(i_l0 + 3), l3(i_l0 + 6)
            pad = cx.pad((R_ONE - v[i_u0]) * (d + zeta * dsq))
            zc = mu[0] * (dsq - d * d) + mu[1] * (d - dl) + mu[2] * ((d + d) - a1 - a2) + mu[3] * pad
            return v[i_eq] * zc + nu * v[i_u0] * (dsq + a1 - k_ceps)
        return b.finish(poly, [(SO_SS, nu_num[0])], ["eq(tau)", "mu0 Dsq - D^2", "mu1 D - limbs(D)",
                                                     "mu2 2D - a1 - a2", "mu3 pad (1 - u0)(D + zeta Dsq)",
                                                     "nu u0 (Dsq + a1 - Ceps) [host term of SS]"], dr)
    if slot == SO_LZC:                                         # :395-410
        tau, _ = dr.take(llo, "tau")
        _, mu = dr.take(2, "mu", nonzero=True)
        i_eq = b.eq(tau, 0)
        i_s = b.public(("live_limbs", lo_n))                   # :400
        i_l = b.a(A_LIMB)
        i_h = b.h(H_LO)
        lks = resolve(lookups_lo(), lambda _p: i_l, g_u8)
        ones = [R_ONE]

        def poly(v):                                           # :405-408
            pad = cx.pad((R_ONE - v[i_s]) * v[i_l])
            return v[i_eq] * (mu[0] * helper_sum(v, lks, i_h, alpha, ones) + mu[1] * pad)
        return b.finish(poly, [], ["eq(tau)", "mu0 helper h(alpha - limb - g_u8) - 1", "mu1 pad (1 - live) limb"], dr)
    if slot == SO_HEAD:                                        # :411-420
        rj, _ = dr.take(lvo, "r_j")
        pts["r_j"] = rj
        i_y = b.a_at(A_Y, fixed_c([ZERO] * lift) + rho_c(range(d_bits)))
        i_w = b.public(("captured", "head_fold"))              # :413-418
        return b.finish(lambda v: v[i_y] * v[i_w], [], ["y * Wf(r_j)"], dr)
    if slot == SO_DZC:                                         # :421-455
        tau, _ = dr.take(ldo, "tau")
        _, mu = dr.take(3 + H_DO_HELPERS + 1, "mu", nonzero=True)
        _, zz = dr.take(1, "zeta", nonzero=True)
        zeta = zz[0]
        i_eq = b.eq(tau, 0)
        i_s = b.public(("supp", cx.d, do_n))
        first = b.tabs_len()
        for p in range(A_X, A_E):
            b.a(p)

        def at(p):
            return first + (p - A_X)
        i_d = b.a_at(A_D, f0())
        h0 = b.h(H_D0)
        for j in range(1, H_DO_HELPERS):
            b.h(H_D0 + j)
        lks = resolve(lookups_do(), at, g_u8)
        planes = [at(p) for p in range(A_X, A_E)]
        k_num, k_dv, k_den = K(2 * cx.g0 * cx.cn), K(1 << cx.tn), K(1 << (cx.tn + 1))

        def poly(v):                                           # :441-453
            def lb(p0):
                a = R_ZERO
                for kk in range(NORM_LIMBS):
                    a = a + v[at(p0 + kk)] * K(1 << (8 * kk))
                return a
            x, y, d = v[at(A_X)], v[at(A_Y)], v[i_d]
            rh, sg = lb(A_RHO0), lb(A_SIG0)
            kd = d * k_den
            c0 = x * k_num + d * k_dv - kd * y - rh
            c1 = sg + rh + R_ONE - kd
            c2 = x + K(32768) - v[at(A_XL0)] - v[at(A_XL1)] * K(256)
            gg = v[i_s]
            clauses = mu[0] * c0 + mu[1] * c1 + mu[2] * c2
            pad = cx.pad((R_ONE - gg) * zeta_fold(v, planes, zeta))
            return v[i_eq] * (gg * clauses + helper_sum(v, lks, h0, alpha, mu[3:3 + H_DO_HELPERS])
                              + mu[3 + H_DO_HELPERS] * pad)
        return b.finish(poly, [], ["eq(tau)", "supp_d (mu0 c0 quotient + mu1 c1 remainder window + mu2 c2 x limbs)",
                                   "6 helpers on 12 byte lookups (mu3..mu8)", "mu9 pad (1 - supp_d) zeta-fold of 12 planes"], dr)
    if slot == SO_VZC:                                         # :456-489
        tau, _ = dr.take(lvo, "tau")
        n_help = hv(l)
        _, mu = dr.take(1 + n_help + 1, "mu", nonzero=True)
        nu_num, nus = dr.take(1, "nu", nonzero=True)
        nu = nus[0]
        _, zz = dr.take(1, "zeta", nonzero=True)
        zeta = zz[0]
        i_eq = b.eq(tau, 0)
        if "r_j" not in pts:
            raise ValueError("VZC reads HEAD's r_j, which no HEAD slot drew")
        i_rj = b.eq(pts["r_j"], 0, label="r_j")
        i_s = b.public(("supp", cx.v, vo_n))
        i_iota = b.public(("iota", vo_n))
        i_e = b.a(A_E)
        for kk in range(l):
            b.a(A_LAM0 + kk)

        def lam(kk):
            return i_e + 1 + kk
        i_tok = b.a_at(A_TOK, f0())
        i_m = b.a_at(A_M, f0())
        h0 = b.h(H_V0)
        for j in range(1, n_help):
            b.h(H_V0 + j)
        lks = resolve(lookups_vo(l), lambda p: lam(p - A_LAM0), g_u8)
        planes = [i_e] + [lam(kk) for kk in range(l)]
        inv2v = F2(f2_inv(k(1 << cx.log_v)))                   # :479

        def poly(v):                                           # :480-487
            delta = R_ZERO
            for kk in range(l):
                delta = delta + v[lam(kk)] * K(1 << (8 * kk))
            e = v[i_e]
            lstar = v[i_s] * (v[i_m] + inv2v * (v[i_iota] - v[i_tok] - delta))
            pad = cx.pad((R_ONE - v[i_s]) * zeta_fold(v, planes, zeta))
            zc = mu[0] * (e * (R_ONE - e)) + helper_sum(v, lks, h0, alpha, mu[1:1 + n_help]) + mu[1 + n_help] * pad
            return v[i_eq] * zc + nu * v[i_rj] * lstar
        return b.finish(poly, [(SO_HEAD, nu_num[0])], ["eq(tau)", "mu0 e(1 - e)", f"{n_help} helpers on {l} limb lookups",
                                                       "pad (1 - supp_V) zeta-fold of e and the limbs",
                                                       "nu eq(r_j) supp_V (M + 2^-v (iota - tok - delta)) [host term of HEAD]"], dr)
    if slot == SO_RSEL:                                        # :493-508
        _, c = dr.take(3, "rsel_c", nonzero=True)
        i_s = b.public(("supp", cx.v, vo_n))
        i_iota = b.public(("iota", vo_n))
        i_u0 = b.public(("supp", 1, vo_n))
        i_e = b.a(A_E)
        for kk in range(l):
            b.a(A_LAM0 + kk)
        i_tok = b.a_at(A_TOK, f0())

        def poly(v):                                           # :503-506
            delta = R_ZERO
            for kk in range(l):
                delta = delta + v[i_e + 1 + kk] * K(1 << (8 * kk))
            return (v[i_s] * v[i_e] * (c[0] + c[1] * v[i_iota] + c[2] * delta)
                    - v[i_u0] * (c[0] + c[1] * v[i_tok]))
        return b.finish(poly, [], ["supp_V e (c1 + c2 iota + c3 delta)", "- u0 (c1 + c2 tok)"], dr)
    if slot == SO_TAB:                                         # :509-526
        tau, _ = dr.take(ltab, "tau")
        _, mu = dr.take(2, "mu", nonzero=True)
        _, zz = dr.take(1, "zeta", nonzero=True)
        zeta = zz[0]
        i_eq = b.eq(tau, 0)
        i_s = b.public(("supp", U8_LEN, tab_n))
        i_tv = b.public(("u8_tagged", tab_n))                  # :517
        i_m = b.a(a_mult(l))
        i_h = b.h(h_gu8(l))

        def poly(v):                                           # :520-524
            rel = v[i_h] * (alpha - v[i_tv]) - v[i_m]
            pad = cx.pad((R_ONE - v[i_s]) * (v[i_m] + zeta * v[i_h]))
            return v[i_eq] * (mu[0] * rel + mu[1] * pad)
        return b.finish(poly, [], ["eq(tau)", "mu0 h (alpha - tv) - m", "mu1 pad (1 - supp_256)(m + zeta h)"], dr)
    if slot == SO_ZS:                                          # :527-531
        i1 = b.public(("ones", 1 << cx.lay.h_log[h_u(l)]))
        iu = b.h(h_u(l))
        return b.finish(lambda v: v[i1] * v[iu], [], ["ones * u"], dr)
    if slot == SO_IOOUT:                                       # :532-539
        tau, _ = dr.take(low, "tau")
        i_eq = b.eq(tau, 0)
        i_u0 = b.public(("supp", 1, ow))
        i_tok = b.a_at(A_TOK, f0())
        i_end = b.io("Out", low, rho_c(range(low)), cx.ep_mask_row)
        return b.finish(lambda v: v[i_eq] * (v[i_end] - v[i_u0] * v[i_tok]), [], ["eq(tau)", "endpoint - u0 * tok"], dr)
    raise ValueError("token I/O stage OUT: unknown slot")


# =====================================================================
#  public tables: rebuilt from the geometry / re-derived challenges, or
#  taken from the capture after len, digest and structure checks
# =====================================================================
def rebuild_public(desc, cx: Ctx):
    """The values of a public table this port can rebuild, or None for one it
    must take from the capture."""
    kind = desc[0]
    if kind == "supp":            # stage_in.rs:139-141, stage_out.rs:327-329
        n, size = desc[1], desc[2]
        return [1 if z < n else 0 for z in range(size)]
    if kind == "ones":            # stage_in.rs:215, stage_out.rs:528
        return [1] * desc[1]
    if kind == "iota":            # stage_out.rs:465, :496
        return list(range(desc[1]))
    if kind == "live_limbs":      # stage_out.rs:400
        return [1 if (z % 2 == 0 and z // 2 < 3 * LIMBS_ISQRT) else 0 for z in range(desc[1])]
    if kind == "u8_tagged":       # stage_out.rs:517: k(z % 256) + g_u8
        return [add(k(z % U8_LEN), cx.g_u8_num) for z in range(desc[1])]
    return None


def describe(desc) -> str:
    kind = desc[0]
    if kind == "supp":
        return f"supp({desc[1]}) over {desc[2]}"
    if kind == "ones":
        return f"ones over {desc[1]}"
    if kind == "iota":
        return f"iota over {desc[1]}"
    if kind == "live_limbs":
        return f"live isqrt limb positions over {desc[1]}"
    if kind == "u8_tagged":
        return f"byte table k(z%256)+g_u8 over {desc[1]}"
    return f"captured {desc[1]}"


def captured_values(tab):
    vals = tab.get("values")
    if vals is None:
        return None
    if hasattr(vals, "numpy"):
        a = vals.numpy()
        return [(int(r[0]) % P, int(r[1]) % P) for r in a]
    return [f2_from_list(x) for x in vals]


def mle(values, eqt):
    """`eval_mle_ext` (zkp-core/src/mle.rs:72-76) over an MSB eq table"""
    acc = ZERO
    for x, e in zip(values, eqt):
        if isinstance(x, int):
            if x:
                acc = add(acc, mulb(e, x % P))
        elif x != ZERO:
            acc = add(acc, mul(e, x))
    return acc


def check_captured_structure(label, vals, cx: Ctx):
    """The structure each taken table's builder gives it.  Returns findings."""
    out = []
    if label == "tau_tab":
        # stage_in.rs:146: padded rows repeat row 0 (`v' = 0`)
        n = 1 << cx.geom.voc_log()
        if len(vals) != n:
            return [f"tau_tab: {len(vals)} entries, not 2^voc_log = {n}"]
        bad = [z for z in range(cx.v, n) if vals[z] != vals[0]]
        if bad:
            out.append(f"tau_tab: {len(bad)} padded rows differ from row 0 (first {bad[0]})")
    elif label == "head_fold":
        # token_io.rs:612-631: d_pad entries, pad columns (i >= d) zero
        if len(vals) != cx.d_pad:
            return [f"head_fold: {len(vals)} entries, not d_pad = {cx.d_pad}"]
        bad = [i for i in range(cx.d, cx.d_pad) if vals[i] != ZERO]
        if bad:
            out.append(f"head_fold: nonzero on {len(bad)} padded columns (first {bad[0]})")
    else:
        out.append(f"{label}: no structure check declared")
    return out


def table_class(desc, values=None):
    """NL classification of a public table: 'indicator' (a 0/1 support or
    position vector), 'constant-MLE' (all entries equal: its MLE is the same
    constant at every point), or 'values' (anything else)."""
    if desc[0] == "ones":
        return "constant-MLE"
    if desc[0] in ("supp", "live_limbs"):
        return "indicator"
    return "values"


# =====================================================================
#  the per-slot checks
# =====================================================================
def check_source_pins(bundle) -> dict:
    """[v13, gate round 10] a pinned digest other than `PORTED_FROM`'s is
    accepted only when the round-9 readings (`zk60_native_rg_tokenio_r9_pins`)
    read it AGAINST that very digest and say no receipt byte moves; anything
    else is refused before any slot is evaluated, as before"""
    import zk60_native_rg_tokenio_r9_pins as R9
    import zk60_native_rg_tokenio_r11_pins as R11
    pins = {p["file"]: p["sha256"] for p in bundle.manifest.get("source_pins", [])}
    moved, also = [], []
    for f, d in PORTED_FROM.items():
        if f not in pins or pins[f] == d:
            continue
        # [v18, gate round 15] walk the readings back to the port's digest:
        # round 11 reads against frozen-r9's digest, round 9 against
        # frozen-r7's (= the port's); every step must move no receipt byte
        chain, cur, ok = [], pins[f], False
        for _ in range(4):
            r, rnd = R11.TOKEN_R11_READINGS.get(f, {}).get(cur), "round-11"
            if r is None:
                r, rnd = R9.TOKEN_R9_READINGS.get(f, {}).get(cur), "round-9"
            if r is None or r.get("moves_a_receipt_byte") is not False:
                break
            chain.append(f"{rnd} reading {cur[:12]} against {r['base'][:12]}")
            cur = r["base"]
            if cur == d:
                ok = True
                break
        if ok:
            also.append(f"{f}: {pins[f][:12]} ({'; '.join(chain)}: no receipt byte moves)")
        else:
            moved.append(f"{f}: bundle {pins[f][:12]}, port read at {d[:12]}")
    missing = [f for f in PORTED_FROM if f not in pins]
    return {"read_at": {f: d[:12] for f, d in PORTED_FROM.items()}, "accepted_by_a_round_9_reading": also,
            "moved": moved, "missing": missing, "ok": not moved and not missing}


def shape_facts(bundle) -> dict:
    """The port is SHAPE-DRIVEN: every size it uses comes from the bundle's
    `token_io` facts (V, V_pad, T, t_pad, d, d_pad, bos, final_norm, the tier,
    the boundary / endpoint site rows) and the geometry re-derived from them
    (`zk60_native_rg_tokenio.TokenGeom`).  The limb count is DERIVED, never
    read (`token_io.rs:417-419`, D24 F-1), and compared with the recorded
    fact here; so are V_pad and the tier's row widths."""
    ti, g = bundle.run["token_io"], bundle.geom
    f = []
    for name, got, want in (("V_pad", ti["V_pad"], g.v_pad), ("limbs", ti["limbs"], g.limbs),
                            ("window_bits", ti["window_bits"], g.window_bits),
                            ("tier.stage_log_n", ti["tier"]["stage_log_n"], g.tier.stage_log_n),
                            ("tier.ep_log_n", ti["tier"]["ep_log_n"], g.tier.ep_log_n)):
        if got != want:
            f.append(f"token_io.{name} = {got}, re-derived {want}")
    return {"V": ti["V"], "V_pad": ti["V_pad"], "T": ti["T"], "t_pad": ti["t_pad"], "d": ti["d"],
            "d_pad": ti["d_pad"], "limbs_derived": g.limbs, "bos": ti["bos"], "final_norm": ti["final_norm"],
            "domain_logs": {"Ti": g.ti_log(), "Voc": g.voc_log(), "Lo": g.lo_log(), "Do": g.do_log(),
                            "Vo": g.vo_log(), "Tab": g.tab_log()},
            "findings": f, "ok": not f}


def _new_stage_challenges(bundle, replay, st, doc):
    """(logup, r_emb, def_challenges(slot), rho(slot), c(slot)) re-derived by
    the replay when one is given, else read from the capture."""
    if replay is not None:
        acc = replay.stages[st.index]
        logup = list(acc["logup"])
        r_emb = list(acc.get("r_emb") or [])

        def dc(s):
            return list(acc["def_challenges"][s])

        def rho(s):
            return list(acc["rho"][s])

        def cc(s):
            return acc["slot_c"][s]
    else:
        logup = [f2_from_list(x) for x in doc["logup_challenges"]]
        r_emb = [f2_from_list(x) for x in (doc.get("r_emb") or [])]

        def dc(s):
            return [f2_from_list(x) for x in doc["arguments"][s]["definition_challenges"]]

        def rho(s):
            return [f2_from_list(x) for x in doc["arguments"][s]["rho"]]

        def cc(s):
            return f2_from_list(doc["arguments"][s]["c"])
    return logup, r_emb, dc, rho, cc


def _structure(sd: SlotDef, arg, kind, slot, cx: Ctx, claim_counter: dict, spi) -> list:
    """The port's declared tables against the capture's, entry for entry:
    kinds, eq points (DERIVED here, compared with the capture's), private
    roles / planes / slices / logs / reserved pairs / coordinates / claim
    indices, and the schedule fields.  Returns findings."""
    f = []
    lay = cx.lay
    sp = lay.slots[slot]
    want_name = (IN_NAMES if kind == "IN" else OUT_NAMES)[slot]
    if arg["name"] != want_name:
        f.append(f"name {arg['name']!r} is not the Rust SlotSpec's {want_name!r}")
    if (arg["kind"], arg["main"], arg["extension"], arg["degree"]) != (sp.kind, sp.main, sp.ext, sp.degree):
        f.append(f"(kind, main, ext, degree) {(arg['kind'], arg['main'], arg['extension'], arg['degree'])} "
                 f"is not the schedule's {(sp.kind, sp.main, sp.ext, sp.degree)}")
    caps = arg["tables"]
    if [t["kind"] for t in caps] != [t["kind"] for t in sd.tabs]:
        f.append(f"table kinds {[t['kind'] for t in caps]} are not the port's {[t['kind'] for t in sd.tabs]}")
        return f
    plane_names = None
    for row in spi.get("slot_planes", []):
        if row["slot"] == slot:
            plane_names = [p["name"] for p in row["planes"]]
    want_planes = [t["plane"] for t in sd.tabs if t["kind"] == "private"]
    if plane_names is not None and plane_names != want_planes:
        f.append(f"the capture's slot plane list {plane_names} is not the port's {want_planes}")
    for i, (t, c) in enumerate(zip(sd.tabs, caps)):
        if t["kind"] == "eq":
            got = [f2_from_list(x) for x in c["point"]]
            if got != t["point"] or c["start"] != t["start"]:
                f.append(f"table {i}: the eq point / start the port DERIVED ({t['label']}) is not the capture's")
        elif t["kind"] == "public":
            if c["len"] != (1 << arg["main"]):
                f.append(f"table {i}: public length {c['len']} is not 2^main")
        else:
            role = t["role"]
            ci = claim_counter.get(role, 0)
            claim_counter[role] = ci + 1
            slices = [(s["offset"], f2_from_list(s["coefficient"])) for s in c["slices"]]
            coords = []
            for co in c["coordinates"]:
                if "rho" in co:
                    coords.append(("rho", co["rho"]))
                elif "fixed" in co:
                    coords.append(("fixed", f2_from_list(co["fixed"])))
                else:
                    coords.append(("flip", co["flip"]))
            want_coords = [(a, tuple(b) if isinstance(b, (list, tuple)) else b) for a, b in t["coords"]]
            checks = {
                "role": c["role"] == role,
                "slices": slices == [(o, tuple(cf)) for o, cf in t["slices"]],
                "log_size": c["log_size"] == t["log"],
                "mask_row": c["mask_row"] == t["mask_row"],
                "extension_round": c["extension_round"] == 0,
                "coordinates": coords == want_coords,
                "claim_index": c["claim"] == ci,
            }
            bad = [n for n, ok in checks.items() if not ok]
            if bad:
                f.append(f"table {i} ({t['plane']}): {', '.join(bad)} differ from the port")
    return f


def _sel(rho_full, main):
    s = ONE
    for e in rho_full[main:]:
        s = mul(s, sub(ONE, e))
    return s


def check_token_terminals(bundle, replay, *, stage_docs=None, terminal_delta=None, table_delta=None,
                          check_digests=True, prefer_captured=False, drop_pad=(), extra=None,
                          expansion_cross_check=True) -> dict:
    """The per-slot terminal identity of every slot of stage IN and stage OUT.

    Controls (in-memory only; no captured byte is touched):
      `stage_docs`      replaces the stage documents (a perturbed copy);
      `terminal_delta`  {(kind, slot): (terminal index, Fp2 delta)};
      `table_delta`     {(kind, slot): (table index, entry, Fp2 delta)} on the
                        capture's recorded public-table values;
      `check_digests`   False skips the digest refusals (one control);
      `prefer_captured` True evaluates rebuildable tables from the capture's
                        values instead of the rebuilt ones (one control);
      `drop_pad`        {(kind, slot)} whose transcription omits its pad term;
      `extra`           {(kind, slot): callable(v, builder) -> ring element}.
    """
    terminal_delta = terminal_delta or {}
    table_delta = table_delta or {}
    extra = extra or {}
    t0 = time.time()
    out = {
        "what": "per new-stage slot: fin == c*mask_eval + poly(vals) (token_io.rs:974-992), the "
        "polynomial transcribed from define (stage_in.rs:149-221, stage_out.rs:336-542) and "
        "evaluated on the recorded terminals, the public tables at rho and the re-derived "
        "definition challenges; compared with terminal_polynomial (= fin - c*mask_eval, "
        "run_capture.rs:1209) and with fin recomputed from the rounds",
        "bundle": bundle.name,
        "challenges_from": "transcript replay (TokenRunReplay)" if replay is not None else "the capture",
        "replay_ok": None if replay is None else replay.summary()["ok"],
        "source_pins": check_source_pins(bundle),
        "shape": shape_facts(bundle),
        "public_tables_included": bool(bundle.public_tables_included),
        "check_digests": check_digests,
        "prefer_captured": prefer_captured,
        "slots": [],
        "findings": [],
        # present from the start: a refusal returns the record as it stands
        "slots_checked": 0, "slots_equal": 0, "public_tables_rebuilt": 0,
        "public_tables_taken_from_capture": 0, "seconds": 0.0,
    }
    if not out["source_pins"]["ok"]:
        out["findings"].append("source pins moved or missing; no slot evaluated")
        out["ok"] = False
        return out
    if not out["shape"]["ok"]:
        out["findings"].append("shape facts differ from the re-derived geometry; no slot evaluated: "
                               + "; ".join(out["shape"]["findings"]))
        out["ok"] = False
        return out
    docs = stage_docs if stage_docs is not None else [st.doc for st in bundle.stages]
    for st in (bundle.stages[0], bundle.stages[-1]):
        kind = st.kind
        doc = docs[st.index]
        logup, r_emb, dcf, rhof, ccf = _new_stage_challenges(bundle, replay, st, doc)
        pts = {}
        claim_counter = {}
        spi = doc.get("stage_plane_index") or {}
        scalars = {a["slot"]: f2_from_list(a["scalar"]) for a in doc["arguments"]}
        n_slots = len((IN_NAMES if kind == "IN" else OUT_NAMES))
        if len(doc["arguments"]) != n_slots:
            out["findings"].append(f"stage {kind}: {len(doc['arguments'])} slots, the port has {n_slots}")
        for s in range(n_slots):
            arg = doc["arguments"][s]
            row = {"stage": kind, "stage_index": st.index, "slot": s, "name": arg.get("name"),
                   "kind": arg.get("kind"), "equal": False}
            try:
                cx = Ctx(bundle, kind, logup, r_emb, "numeric", drop_pad=(kind, s) in drop_pad,
                         extra=extra.get((kind, s)))
                dr = Draws(dcf(s), "numeric")
                sd = define_in(s, cx, dr) if kind == "IN" else define_out(s, cx, dr, pts)
                parts_findings = []
                if dr.pos != len(dr.num):
                    parts_findings.append(f"the port draws {dr.pos} definition challenges, the slot carries {len(dr.num)}")
                if dr.zero:
                    parts_findings.append(f"a zero batching challenge in {dr.zero} (nonzero() would refuse)")
                st_f = _structure(sd, arg, kind, s, cx, claim_counter, spi)
                rho_full = rhof(s)
                main = arg["main"]
                if len(rho_full) != main + arg["extension"]:
                    parts_findings.append(f"{len(rho_full)} sumcheck challenges for main + ext = {main + arg['extension']}")
                es = rho_full[main:]
                if any(e == ZERO or e == ONE for e in es):
                    parts_findings.append("a degenerate terminal mask challenge (token_io.rs:997)")
                sel = _sel(rho_full, main)
                rho_main = rho_full[:main]
                eqt = None
                vals, pub_rows = [], []
                terms = [f2_from_list(x) for x in arg["terminals"]]
                td = terminal_delta.get((kind, s))
                if td is not None:
                    terms[td[0]] = add(terms[td[0]], td[1])
                kk = 0
                for i, t in enumerate(sd.tabs):
                    cap = arg["tables"][i]
                    if t["kind"] == "eq":
                        vals.append(F2(mul(sel, eq_point(t["point"], rho_main[t["start"]:t["start"] + len(t["point"])]))))
                    elif t["kind"] == "public":
                        if eqt is None:
                            eqt = eq_table_msb(rho_main)
                        desc = t["desc"]
                        capv = captured_values(cap)
                        tdl = table_delta.get((kind, s))
                        if capv is not None and tdl is not None and tdl[0] == i:
                            capv = list(capv)
                            capv[tdl[1]] = add(capv[tdl[1]], tdl[2])
                        prow = {"table": i, "what": describe(desc), "len": cap["len"],
                                "class": table_class(desc)}
                        if capv is None:
                            raise ValueError(f"public table {i} ({describe(desc)}): the capture carries no values")
                        if len(capv) != cap["len"]:
                            raise ValueError(f"public table {i}: {len(capv)} values for len {cap['len']}")
                        prow["captured_values_match_own_digest"] = table_digest(capv) == cap["sha256"]
                        ev_cap = mle(capv, eqt)
                        prow["eval_from_captured_values"] = list(ev_cap)
                        rb = rebuild_public(desc, cx)
                        if rb is not None:
                            prow["rebuilt"] = True
                            prow["rebuilt_digest_matches_capture"] = table_digest(rb) == cap["sha256"]
                            ev_rb = mle(rb, eqt)
                            prow["eval_from_rebuilt"] = list(ev_rb)
                            prow["evaluations_agree"] = ev_rb == ev_cap
                            use = ev_cap if prefer_captured else ev_rb
                            if len(set(x if isinstance(x, int) else x for x in rb)) == 1:
                                prow["class"] = "constant-MLE"
                        else:
                            prow["rebuilt"] = False
                            sf = check_captured_structure(desc[1], capv, cx)
                            prow["structure_findings"] = sf
                            prow["evaluations_agree"] = None
                            use = ev_cap
                        ok_dig = prow["captured_values_match_own_digest"] and prow.get("rebuilt_digest_matches_capture", True)
                        if check_digests and not ok_dig:
                            parts_findings.append(f"public table {i} ({describe(desc)}): digest mismatch")
                        if prow["evaluations_agree"] is False:
                            parts_findings.append(f"public table {i} ({describe(desc)}): the evaluation from the "
                                                  "captured values differs from the rebuilt table's")
                        if prow.get("structure_findings"):
                            parts_findings += prow["structure_findings"]
                        vals.append(F2(mul(sel, use)))
                        pub_rows.append(prow)
                    else:
                        if kk >= len(terms):
                            raise ValueError("the port has more private tables than the slot has terminals")
                        vals.append(F2(terms[kk]))
                        kk += 1
                if kk != len(terms):
                    parts_findings.append(f"{kk} private tables for {len(terms)} terminals")
                poly = sd.poly(vals).v
                tp = f2_from_list(arg["terminal_polynomial"])
                # hosted (token_io.rs:974): coefficient re-derived, compared
                claimed = scalars[s]
                cap_h = [(h["slot"], f2_from_list(h["coefficient"])) for h in arg["hosted"]]
                if [(hs, tuple(cf)) for hs, cf in sd.hosted] != cap_h:
                    parts_findings.append(f"hosted {cap_h} is not the port's {sd.hosted}")
                for hs, coef in sd.hosted:
                    claimed = add(claimed, mul(coef, scalars[hs]))
                claimed_ok = claimed == f2_from_list(arg["claimed_sum"])
                fin, consistent = sumcheck_final(arg["rounds"], arg["degree"], rho_full, claimed)
                fin_ok = fin is not None and fin == f2_from_list(arg["sumcheck_final"])
                c = ccf(s)
                me = f2_from_list(arg["mask_eval"])
                identity = fin is not None and fin == add(mul(c, me), poly)
                matches_tp = poly == tp
                exp_ok = None
                if expansion_cross_check:
                    # the SAME transcription on the symbolic ring (challenges at
                    # their run values), evaluated back at the recorded vals
                    cxe = Ctx(bundle, kind, logup, r_emb, "numeric", drop_pad=(kind, s) in drop_pad,
                              extra=extra.get((kind, s)))
                    dre = Draws(dcf(s), "numeric")
                    pts_e = dict(pts)
                    sde = define_in(s, cxe, dre) if kind == "IN" else define_out(s, cxe, dre, pts_e)
                    names = [f"T{i:02d}" for i in range(len(sde.tabs))]
                    pe = sde.poly([Poly.var(n) for n in names])
                    pe = Poly._co(pe)
                    exp_ok = pe.evaluate({n: x.v for n, x in zip(names, vals)}) == poly
                    row["expansion_monomials"] = len(pe.t)
                row.update({
                    "parts": sd.parts,
                    "tables": [t["kind"] if t["kind"] != "private" else f"{t['role']}:{t['plane']}" for t in sd.tabs],
                    "counts": {"tables": len(sd.tabs), "eq": sum(t["kind"] == "eq" for t in sd.tabs),
                               "public": sum(t["kind"] == "public" for t in sd.tabs),
                               "private": sum(t["kind"] == "private" for t in sd.tabs),
                               "definition_draws": len(dr.num), "draw_layout": dr.labels,
                               "rounds": len(arg["rounds"])},
                    "hosted": [{"slot": hs, "coefficient_rederived_and_equal": True} for hs, _ in sd.hosted] if not any("hosted" in x for x in parts_findings) else "MISMATCH",
                    "public_tables": pub_rows,
                    "structure_findings": st_f,
                    "findings": parts_findings,
                    "a_poly_equals_terminal_polynomial": matches_tp,
                    "b_claimed_sum_recomputed": claimed_ok,
                    "c_round_consistency": consistent,
                    "c_fin_recomputed_equals_capture": fin_ok,
                    "c_identity_fin_eq_c_mask_eval_plus_poly": identity,
                    "expansion_reproduces_poly": exp_ok,
                })
                row["equal"] = bool(matches_tp and identity and claimed_ok and consistent and fin_ok
                                    and not st_f and not parts_findings and exp_ok is not False)
                if not row["equal"]:
                    why = []
                    if not matches_tp:
                        why.append("poly != terminal_polynomial")
                    if not identity:
                        why.append("fin != c*mask_eval + poly")
                    if not claimed_ok:
                        why.append("claimed_sum differs")
                    if not consistent:
                        why.append("round consistency fails")
                    if not fin_ok:
                        why.append("fin differs from the capture")
                    if exp_ok is False:
                        why.append("expansion does not reproduce poly")
                    why += st_f + parts_findings
                    out["findings"].append(f"{kind}-{s:02d}: " + "; ".join(why))
            except (ValueError, IndexError, KeyError) as exc:
                row["error"] = str(exc)
                out["findings"].append(f"{kind}-{s:02d}: refused: {exc}")
            out["slots"].append(row)
    n = len(out["slots"])
    out["slots_checked"] = n
    out["slots_equal"] = sum(1 for r in out["slots"] if r["equal"])
    out["public_tables_rebuilt"] = sum(1 for r in out["slots"] for p in r.get("public_tables", []) if p.get("rebuilt"))
    out["public_tables_taken_from_capture"] = sum(1 for r in out["slots"] for p in r.get("public_tables", []) if p.get("rebuilt") is False)
    out["taken_tables_do_not_establish"] = (
        "that stage IN's tau table folds the embedding, and stage OUT's head fold the head, "
        "the statement names (no bundle carries those weights): checked for len, sha256 and "
        "builder structure only")
    out["mask_eval_not_established_here"] = (
        "mask_eval is the verifier's derived g_val; its agreement with the committed mask is "
        "the M opening (G-3, token_mask_cfs)")
    out["seconds"] = round(time.time() - t0, 2)
    out["ok"] = (out["slots_equal"] == n == 15 and not out["findings"]
                 and (replay is None or out["replay_ok"]))
    return out


# =====================================================================
#  NL-1 on a symbolic expansion
# =====================================================================
def _render(mono, classes):
    parts = []
    for n, e in mono:
        lab = classes[n][1]
        parts.append(lab if e == 1 else f"{lab}^{e}")
    return "*".join(parts) if parts else "1"


def _analyze(P: Poly, classes: dict) -> dict:
    """Group the expansion by its TABLE part (challenge symbols stripped):
    a table part exists iff some term with it survives (distinct challenge
    monomials are independent, so its coefficient polynomial is nonzero)."""
    tparts = {}
    for mono in P.t:
        tp = tuple((n, e) for (n, e) in mono if n in classes)
        tparts[tp] = True
    no_pub, pub_only, ind_only, const_only = [], 0, [], []
    maxdeg = 0
    priv_seen = set()
    for tp in tparts:
        cls = [classes[n][0] for n, _ in tp]
        deg = sum(e for _, e in tp)
        maxdeg = max(maxdeg, deg)
        pubs = [(n, classes[n]) for n, _ in tp if classes[n][0] in ("eq", "public")]
        privs = [n for n, _ in tp if classes[n][0] == "private"]
        priv_seen.update(privs)
        if not pubs:
            no_pub.append(_render(tp, classes))
        elif not privs:
            pub_only += 1
        if pubs and all(c[0] == "public" and c[2] == "indicator" for _, c in pubs):
            ind_only.append(_render(tp, classes))
        if pubs and all(c[0] == "public" and c[2] == "constant-MLE" for _, c in pubs):
            const_only.append(_render(tp, classes))
    return {"monomials": len(tparts), "terms_with_challenge_parts": len(P.t),
            "monomials_without_public_factor": no_pub,
            "public_factor_in_every_monomial": not no_pub,
            "public_only_monomials": pub_only,
            "monomials_whose_only_public_factors_are_indicators": ind_only,
            "monomials_whose_only_public_factor_has_a_constant_MLE": const_only,
            "max_table_degree": maxdeg, "private_variables_appearing": len(priv_seen)}


def nl1_token_slots(bundle, replay=None, *, stage_docs=None, extra=None) -> dict:
    """NL-1's structural premises (S1) for every new-stage slot, on a symbolic
    expansion of the transcription: (i) challenges as formal symbols, (ii)
    challenges at the run's values (re-derived when a replay is given)."""
    extra = extra or {}
    t0 = time.time()
    out = {"what": "S1 premises per new-stage slot on the symbolic expansion of the transcribed "
           "polynomial: a public TABLE factor in every monomial (eq or public table; the affine "
           "1 - supp is split by the expansion, NL-3), max product degree <= declared degree, "
           "private-terminal count == the slot's terminals; one extension round with every "
           "private table in round 0, so S1's per-round premise is the public-factor condition",
           "bundle": bundle.name, "slots": [], "findings": [],
           "slots_checked": 0, "slots_with_premises": 0, "observations": {}, "seconds": 0.0}
    sf = shape_facts(bundle)
    if not sf["ok"]:
        out["findings"].append("shape facts differ from the re-derived geometry: " + "; ".join(sf["findings"]))
        out["ok"] = False
        return out
    docs = stage_docs if stage_docs is not None else [st.doc for st in bundle.stages]
    for st in (bundle.stages[0], bundle.stages[-1]):
        kind = st.kind
        doc = docs[st.index]
        logup, r_emb, dcf, _rhof, _ccf = _new_stage_challenges(bundle, replay, st, doc)
        pts_sym, pts_num = {}, {}
        for s in range(len(doc["arguments"])):
            arg = doc["arguments"][s]
            row = {"stage": kind, "slot": s, "name": arg["name"], "declared_degree": arg["degree"]}
            try:
                res = {}
                for mode, pts in (("symbolic", pts_sym), ("numeric", pts_num)):
                    cx = Ctx(bundle, kind, logup, r_emb, mode, extra=extra.get((kind, s)))
                    dr = Draws(dcf(s), mode)
                    sd = define_in(s, cx, dr) if kind == "IN" else define_out(s, cx, dr, pts)
                    classes = {}
                    names = []
                    for i, t in enumerate(sd.tabs):
                        nm = f"T{i:02d}"
                        names.append(nm)
                        if t["kind"] == "eq":
                            classes[nm] = ("eq", f"eq({t['label']})", "eq")
                        elif t["kind"] == "public":
                            rb = rebuild_public(t["desc"], cx) if t["desc"][0] != "u8_tagged" else None
                            cl = table_class(t["desc"])
                            if rb is not None and len(set(rb)) == 1:
                                cl = "constant-MLE"
                            classes[nm] = ("public", describe(t["desc"]), cl)
                        else:
                            classes[nm] = ("private", t["plane"], "private")
                    P = Poly._co(sd.poly([Poly.var(n) for n in names]))
                    res[mode] = _analyze(P, classes)
                    res[mode]["n_private_tables"] = sum(1 for c in classes.values() if c[0] == "private")
                    res[mode]["ext_rounds"] = arg["extension"]
                n_priv = res["symbolic"]["n_private_tables"]
                sp = Ctx(bundle, kind, logup, r_emb, "numeric").lay.slots[s]
                ext_ok = arg["extension"] == 1 and all(
                    t.get("extension_round", 0) == 0 for t in arg["tables"] if t["kind"] == "private")
                row.update({
                    "symbolic_challenges": res["symbolic"],
                    "challenges_at_run_values": res["numeric"],
                    "public_factor_in_every_monomial": (res["symbolic"]["public_factor_in_every_monomial"]
                                                        and res["numeric"]["public_factor_in_every_monomial"]),
                    "max_table_degree": max(res["symbolic"]["max_table_degree"], res["numeric"]["max_table_degree"]),
                    "degree_fits": max(res["symbolic"]["max_table_degree"], res["numeric"]["max_table_degree"]) <= arg["degree"],
                    "private_terminals_port": n_priv,
                    "terminals_recorded": len(arg["terminals"]),
                    "schedule_sites": sp.a_sites + sp.h_sites + sp.io_sites,
                    "terminal_count_ok": n_priv == len(arg["terminals"]) == sp.a_sites + sp.h_sites + sp.io_sites,
                    "every_private_table_appears": res["symbolic"]["private_variables_appearing"] == n_priv,
                    "one_extension_round_all_private_in_round_0": ext_ok,
                })
                row["premises_hold"] = (row["public_factor_in_every_monomial"] and row["degree_fits"]
                                        and row["terminal_count_ok"] and ext_ok)
                if not row["public_factor_in_every_monomial"]:
                    out["findings"].append(f"{kind}-{s:02d}: monomial(s) with NO public factor: "
                                           f"{res['symbolic']['monomials_without_public_factor'][:6]}"
                                           f"{res['numeric']['monomials_without_public_factor'][:6]}")
                if not row["degree_fits"]:
                    out["findings"].append(f"{kind}-{s:02d}: max product degree {row['max_table_degree']} > declared {arg['degree']}")
                if not row["terminal_count_ok"]:
                    out["findings"].append(f"{kind}-{s:02d}: private tables {n_priv}, terminals {len(arg['terminals'])}, "
                                           f"schedule sites {row['schedule_sites']}")
                if not ext_ok:
                    out["findings"].append(f"{kind}-{s:02d}: not one extension round with every private table in round 0")
            except (ValueError, IndexError, KeyError) as exc:
                row["error"] = str(exc)
                row["premises_hold"] = False
                out["findings"].append(f"{kind}-{s:02d}: refused: {exc}")
            out["slots"].append(row)
    out["slots_checked"] = len(out["slots"])
    out["slots_with_premises"] = sum(1 for r in out["slots"] if r.get("premises_hold"))
    out["observations"] = {
        "slots_with_a_monomial_whose_only_public_factors_are_indicator_tables": [
            f"{r['stage']}-{r['slot']:02d}" for r in out["slots"]
            if r.get("symbolic_challenges", {}).get("monomials_whose_only_public_factors_are_indicators")],
        "slots_with_a_monomial_whose_only_public_factor_has_a_constant_MLE": [
            f"{r['stage']}-{r['slot']:02d}" for r in out["slots"]
            if r.get("symbolic_challenges", {}).get("monomials_whose_only_public_factor_has_a_constant_MLE")],
    }
    out["seconds"] = round(time.time() - t0, 2)
    out["ok"] = out["slots_with_premises"] == out["slots_checked"] == 15 and not out["findings"]
    return out


# =====================================================================
#  negative controls (each predicted to fire)
# =====================================================================
def _doc_copy_with(bundle, stage_index, slot, mutate):
    docs = [st.doc for st in bundle.stages]
    d = copy.copy(docs[stage_index])
    d["arguments"] = list(d["arguments"])
    a = copy.deepcopy({k_: v for k_, v in d["arguments"][slot].items() if k_ != "tables"})
    a["tables"] = [copy.copy(t) for t in d["arguments"][slot]["tables"]]
    mutate(a)
    d["arguments"][slot] = a
    docs = list(docs)
    docs[stage_index] = d
    return docs


def _failed_slots(r):
    return [f"{x['stage']}-{x['slot']:02d}" for x in r["slots"] if not x["equal"]]


def token_terminal_controls(bundle, replay) -> dict:
    out = {}
    L1 = len(bundle.stages) - 1
    one = (1, 0)

    # TT-1 / TT-2: one terminal moved, one IN slot and one OUT slot
    for name, key, ti in (("TT-1_terminal_moved_IN-01", ("IN", SI_QZC), 0),
                          ("TT-2_terminal_moved_OUT-05", ("OUT", SO_DZC), 3)):
        r = check_token_terminals(bundle, replay, terminal_delta={key: (ti, one)}, expansion_cross_check=False)
        failed = _failed_slots(r)
        tag = f"{key[0]}-{key[1]:02d}"
        x = next(s for s in r["slots"] if s["stage"] == key[0] and s["slot"] == key[1])
        out[name] = {"fires": failed == [tag] and not x["a_poly_equals_terminal_polynomial"]
                     and not x["c_identity_fin_eq_c_mask_eval_plus_poly"],
                     "failed_slots": failed, "what": f"terminal {ti} of {tag} + 1"}

    # TT-3: one public table value moved (captured values)
    #  (a) a REBUILDABLE table (OUT-07 iota, entry 5): digest and evaluation comparison fire
    key = ("OUT", SO_RSEL)
    r = check_token_terminals(bundle, replay, table_delta={key: (1, 5, one)}, expansion_cross_check=False)
    out["TT-3a_rebuildable_public_value_moved_OUT-07_iota"] = {
        "fires": _failed_slots(r) == ["OUT-07"], "failed_slots": _failed_slots(r),
        "first_finding": (r["findings"] or [None])[0]}
    #  (b) same, digests off and the CAPTURED values evaluated: the arithmetic fires
    r = check_token_terminals(bundle, replay, table_delta={key: (1, 5, one)}, check_digests=False,
                              prefer_captured=True, expansion_cross_check=False)
    x = next(s for s in r["slots"] if s["stage"] == "OUT" and s["slot"] == SO_RSEL)
    out["TT-3b_same_digests_off_captured_values_used"] = {
        "fires": not x["a_poly_equals_terminal_polynomial"] and not x["c_identity_fin_eq_c_mask_eval_plus_poly"],
        "failed_slots": _failed_slots(r)}
    #  (c) a TAKEN table (IN-02 tau_tab, entry 7), digests off: the arithmetic fires
    key = ("IN", SI_TZC)
    r = check_token_terminals(bundle, replay, table_delta={key: (2, 7, one)}, check_digests=False,
                              expansion_cross_check=False)
    x = next(s for s in r["slots"] if s["stage"] == "IN" and s["slot"] == SI_TZC)
    out["TT-3c_taken_table_value_moved_IN-02_tau_digests_off"] = {
        "fires": not x["a_poly_equals_terminal_polynomial"] and not x["c_identity_fin_eq_c_mask_eval_plus_poly"],
        "failed_slots": _failed_slots(r)}
    #  (d) same, digests on: refused by the digest
    r = check_token_terminals(bundle, replay, table_delta={key: (2, 7, one)}, expansion_cross_check=False)
    out["TT-3d_same_digests_on"] = {"fires": _failed_slots(r) == ["IN-02"],
                                    "first_finding": (r["findings"] or [None])[0]}

    # TT-4: a pad term dropped from the transcription, every pad-bearing slot
    per = {}
    for key in sorted(PAD_SLOTS):
        r = check_token_terminals(bundle, replay, drop_pad={key}, expansion_cross_check=False)
        tag = f"{key[0]}-{key[1]:02d}"
        per[tag] = _failed_slots(r) == [tag]
    out["TT-4_pad_term_dropped"] = {"fires": all(per.values()), "per_slot": per}

    # TT-5: the capture's eq point moved (the port DERIVES it)
    def mv_eq(a):
        a["tables"][0] = dict(a["tables"][0])
        pt = [list(x) for x in a["tables"][0]["point"]]
        pt[0] = [(pt[0][0] + 1) % P, pt[0][1]]
        a["tables"][0]["point"] = pt
    docs = _doc_copy_with(bundle, L1, SO_LZC, mv_eq)
    r = check_token_terminals(bundle, replay, stage_docs=docs, expansion_cross_check=False)
    out["TT-5_capture_eq_point_moved_OUT-03"] = {"fires": _failed_slots(r) == ["OUT-03"],
                                                 "first_finding": (r["findings"] or [None])[0]}

    # TT-6: a hosted coefficient moved in the capture (the port re-derives nu)
    def mv_host(a):
        a["hosted"] = [dict(h) for h in a["hosted"]]
        cf = list(a["hosted"][0]["coefficient"])
        a["hosted"][0]["coefficient"] = [(cf[0] + 1) % P, cf[1]]
    docs = _doc_copy_with(bundle, L1, SO_VZC, mv_host)
    r = check_token_terminals(bundle, replay, stage_docs=docs, expansion_cross_check=False)
    out["TT-6_capture_hosted_coefficient_moved_OUT-06"] = {"fires": "OUT-06" in _failed_slots(r),
                                                           "failed_slots": _failed_slots(r)}

    # TT-7: a recorded shape fact moved (the limb count, which the port derives)
    b2 = copy.copy(bundle)
    b2.run = copy.deepcopy(bundle.run)
    b2.run["token_io"]["limbs"] += 1
    r = check_token_terminals(b2, replay, expansion_cross_check=False)
    out["TT-7_token_io_limbs_moved"] = {"fires": not r["ok"] and r["slots_checked"] == 0,
                                        "first_finding": (r["findings"] or [None])[0]}

    # NL-1 controls: synthetic monomials
    def private_only(v, b):         # 3 tok h_q: no public factor
        return K(3) * v[3] * v[4]

    def affine_only(v, b):          # (1 - supp_T) tok: NL-3, the affine term is not a public factor
        return (R_ONE - v[1]) * v[3]

    def constant(v, b):             # a bare constant
        return K(5)

    def over_degree(v, b):          # eq tok h_q B tok: degree 5 > 4, public factor present
        return v[0] * v[3] * v[4] * v[5] * v[3]
    for name, fn, want in (("NL-C1_private_only_monomial_IN-01", private_only, "pub"),
                           ("NL-C2_affine_1_minus_supp_only_IN-01", affine_only, "pub"),
                           ("NL-C3_bare_constant_IN-01", constant, "pub"),
                           ("NL-C4_degree_overflow_IN-01", over_degree, "deg")):
        r = nl1_token_slots(bundle, replay, extra={("IN", SI_QZC): fn})
        x = next(s for s in r["slots"] if s["stage"] == "IN" and s["slot"] == SI_QZC)
        others_ok = all(s["premises_hold"] for s in r["slots"] if not (s["stage"] == "IN" and s["slot"] == SI_QZC))
        hit = (not x["public_factor_in_every_monomial"]) if want == "pub" else (not x["degree_fits"])
        out[name] = {"fires": hit and not x["premises_hold"] and others_ok,
                     "flagged": x["symbolic_challenges"]["monomials_without_public_factor"][:4] if want == "pub"
                     else f"degree {x['max_table_degree']} > {x['declared_degree']}"}

    # NL-C5: a terminal dropped from the capture: the count premise fires
    def drop_term(a):
        a["terminals"] = a["terminals"][:-1]
    docs = _doc_copy_with(bundle, 0, SI_TZC, drop_term)
    r = nl1_token_slots(bundle, replay, stage_docs=docs)
    x = next(s for s in r["slots"] if s["stage"] == "IN" and s["slot"] == SI_TZC)
    out["NL-C5_terminal_dropped_IN-02"] = {"fires": not x["terminal_count_ok"] and not x["premises_hold"],
                                           "counts": [x["private_terminals_port"], x["terminals_recorded"], x["schedule_sites"]]}
    out["all_fire"] = all(v["fires"] for v in out.values() if isinstance(v, dict) and "fires" in v)
    return out


# =====================================================================
#  self-test entry point
# =====================================================================
def _summary_lines(tt, nl):
    lines = []
    lines.append(f"bundle {tt['bundle']}: challenges from {tt['challenges_from']}; replay ok {tt['replay_ok']}; "
                 f"source pins ok {tt['source_pins']['ok']}")
    nl_by = {(r["stage"], r["slot"]): r for r in nl["slots"]}
    for r in tt["slots"]:
        n = nl_by.get((r["stage"], r["slot"]), {})
        c = r.get("counts", {})
        lines.append(
            f"  {r['stage']}-{r['slot']:02d} equal={r['equal']} tp={r.get('a_poly_equals_terminal_polynomial')} "
            f"fin=c*me+poly={r.get('c_identity_fin_eq_c_mask_eval_plus_poly')} rounds={c.get('rounds')} "
            f"tabs eq/pub/priv={c.get('eq')}/{c.get('public')}/{c.get('private')} draws={c.get('definition_draws')} "
            f"| NL-1 pubfactor={n.get('public_factor_in_every_monomial')} deg {n.get('max_table_degree')}<={n.get('declared_degree')} "
            f"terms {n.get('private_terminals_port')}={n.get('terminals_recorded')} monos={n.get('symbolic_challenges', {}).get('monomials')}")
    lines.append(f"  identity: {tt['slots_equal']}/{tt['slots_checked']} equal; public tables rebuilt "
                 f"{tt['public_tables_rebuilt']}, taken {tt['public_tables_taken_from_capture']}; ok {tt['ok']} ({tt['seconds']} s)")
    lines.append(f"  NL-1: {nl['slots_with_premises']}/{nl['slots_checked']} slots hold every premise; ok {nl['ok']} ({nl['seconds']} s)")
    lines.append(f"  NL observations: {nl['observations']}")
    for f in tt["findings"] + nl["findings"]:
        lines.append(f"  FINDING: {f}")
    return lines


def main(argv):
    import argparse
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("bundle_dir")
    ap.add_argument("--json", help="write the full record here")
    ap.add_argument("--no-controls", action="store_true")
    args = ap.parse_args(argv)
    t0 = time.time()
    rec = {"tool": os.path.abspath(__file__), "poly_engine_self_test": _poly_self_test()}
    b = TG.load(args.bundle_dir)
    rp = TG.TokenRunReplay(b).run()
    rec["replay"] = {k_: v for k_, v in rp.summary().items() if k_ != "segment_position_tags"}
    tt = check_token_terminals(b, rp)
    nl = nl1_token_slots(b, rp)
    rec["token_terminals"] = tt
    rec["nl1"] = nl
    for line in _summary_lines(tt, nl):
        print(line)
    if not args.no_controls:
        ct = token_terminal_controls(b, rp)
        rec["controls"] = ct
        for name, v in ct.items():
            if isinstance(v, dict):
                print(f"  control {name}: fires={v['fires']}")
        print(f"  controls all fire: {ct['all_fire']}")
    rec["seconds"] = round(time.time() - t0, 2)
    rec["peak_rss_mib"] = round(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024, 1)
    rec["ok"] = (rec["poly_engine_self_test"] and rec["replay"]["ok"] and tt["ok"] and nl["ok"]
                 and (args.no_controls or rec["controls"]["all_fire"]))
    print(f"  poly engine self-test {rec['poly_engine_self_test']}; total {rec['seconds']} s; "
          f"peak RSS {rec['peak_rss_mib']} MiB; OK {rec['ok']}")
    if args.json:
        with open(args.json, "w") as fh:
            json.dump(rec, fh, indent=1, default=str)
    return 0 if rec["ok"] else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

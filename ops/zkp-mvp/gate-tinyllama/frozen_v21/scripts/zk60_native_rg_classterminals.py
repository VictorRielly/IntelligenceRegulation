#!/usr/bin/env python3
"""[GATE ROUND 16, tools v19, 2026-10-21] The CLASSIFIER stages' slot
polynomials, transcribed for the privacy gate's terminal identity and NL-1:
stage IN-C (`stage_in_c.rs:168-233` `define`) and stage OUT-C
(`stage_out_c.rs:284-418` `define`), read pre-freeze at manifest_r12B
(stage_in_c.rs 7bc3c30b..., stage_out_c.rs 46cb6951...).  The builder and the
two rings are the token port's (`zk60_native_rg_tokenterminals`: `F2`,
`Poly`, `Draws`, `SB`'s mirror `B`, `helper_sum`, `zeta_fold`), so one
transcription serves the numeric identity on a capture and the symbolic
NL-1 expansion.

NO CLASSIFIER CAPTURE EXISTS YET: the classifier verify path calls no
capture hook (EV/round16/CLASSIFY_CAPTURE_HOOK_REQUEST.md).  Until one does,
this module's checks run on WITNESSES the gate builds itself from the same
integer semantics R-C1 proves (`stage_out_c.rs:155-247`
`out_values` / `witness_from_values`; `stage_in_c.rs:62-101`
`honest_inputs`), and on the transcription itself:

  RELATION CHECKS (the port's polynomials summed over their domains):
    MRG-H   the margin hosting identity: sum over Lo of the LZC host term
            == sum over Do of PD's `y w_Delta` (design §4.2), at verdict 0, 1
            and the tie;
    ZC-H    every zero-check slot's clause vanishes pointwise on the honest
            witness (TZC, LZC's zero-check part, DZC, TAB; INC-01, INC-02);
    LU-H    the LogUp sum claims balance: OUT-C's byte lookups against the
            byte table, IN-C's (id, row, ctl) queries against tau.
  FAILING-FIRST CONTROLS (each predicted, each must break exactly one):
    MC-1  the verdict flipped, limbs unchanged             -> MRG-H fails
    MC-2  the verdict flipped, limbs re-made from -delta-1  -> LU-H fails (not bytes)
    MC-3  a limb raised by 256 with a carry kept           -> LU-H fails, MRG-H holds
    MC-4  a nonzero limb-plane pad entry                    -> ZC-H fails (LZC pad)
    MC-5  the threshold c + 1 in the port                   -> MRG-H fails
    MC-6  the margin vector negated (a self-made digest)    -> B-3 digest refusal
    MC-7  `classify-verdict` missing from the header labels -> header refusal
    IC-1  one template id changed                           -> ZC-H fails (INC-01 template clause)
    IC-2  the template clause SHARING the LogUp coefficient: a forged
          template position with a compensating helper passes the shared
          clause and fails the fresh one (CHECK2 N-1)
    IC-3  a control id at a content position                -> LU-H fails
    IC-4  a control id at a template position (honest)      -> LU-H holds
  NL-1 (S1 premises, symbolic): a public factor in every monomial, degree
  within the declared, on all 12 classifier slots.

On a capture (once the hook lands) `check_classify_terminals` evaluates the
same transcriptions at the replayed challenges against the recorded
terminals (the token port's `check_token_terminals` method; see the hook
request for the fields it reads).

[v21, gate round 18] RE-READ on token frozen-r14 (stage_in_c.rs 6a92da0e,
stage_out_c.rs 93a79a2b, classify.rs 6c828db6): the slot polynomials are
unchanged; what moved is (1) the template (`ClassCtx.kappa`): the suffix on
P0 + n .. P0 + n + S and the policy's PUBLIC pad id after it up to T, with n
the statement's content length (a SHORT item, D45(1)); (2) OUTC-00's B_out
row: the verdict row P0 + n + S - 1 (stage_out_c.rs:302); (3) tau and
w_Delta are no longer taken from the capture: both are REBUILT from the
tables derived from the pinned tied tensor (`zk60_native_rg_classtied`, B-3),
so every IN-C / OUT-C public table is rebuilt.

NOTHING HERE IS A PRIVACY RESULT OR A PRIVACY ACCEPTANCE.
"""

from __future__ import annotations

import hashlib
import json
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import zk60_native_rg_classify as CL  # noqa: E402
import zk60_native_rg_tokenterminals as TT  # noqa: E402
from zk60_native_rg_tokenterminals import (  # noqa: E402
    F2, K, ONE, P, R_ONE, R_ZERO, TAG_EMB, TAG_U8, ZERO, Draws, Poly, SlotDef, add, fixed_bits_c,
    fixed_c, helper_sum, k, mul, mulb, rho_c, sub, zeta_fold,
)
from zk60_native_jv_field import f2_inv  # noqa: E402

U8_LEN = 256
LIMBS_ISQRT = 3
NORM_LIMBS = 4
TO_LOG = 1


# =====================================================================
#  the context and the builder
# =====================================================================
class ClassCtx:
    """What a classifier slot closure captures (the token port's `Ctx`, for
    a classifier stage).  `facts` carries the public statement: the final
    norm, BOS, the policy (prefix, suffix, num_special, c), the verdict, the
    margin vector (when the caller has it), and the run schedule's IO rows."""

    def __init__(self, geom: CL.ClassGeom, kind: str, logup, r_emb, mode: str, facts: dict,
                 drop_pad=False, extra=None, shared_template_mu=False):
        if kind not in ("IN-C", "OUT-C"):
            raise ValueError(kind)
        self.kind, self.mode, self.geom = kind, mode, geom
        self.tokens, self.t_pad, self.d, self.d_pad, self.v = geom.tokens, geom.t_pad, geom.d, geom.d_pad, geom.v
        self.v_pad, self.log_v, self.limbs = geom.v_pad, geom.log_v, geom.limbs
        self.bos = facts["bos"]
        self.g0, self.cn, self.tn, self.ceps = (facts["final_norm"][x] for x in ("g0", "cn", "tn", "ceps"))
        self.prefix, self.suffix = list(facts["prefix"]), list(facts["suffix"])
        self.num_special, self.c = facts["num_special"], facts["c"]
        # [v21, R-C3] the content length n (public, D45(1)), the policy's
        # PUBLIC pad id and the verdict row; a full-length item has no pad and
        # its verdict row is T - 1 (classify.rs:489-524 at r14)
        self.n_content = facts.get("n", self.tokens - len(self.prefix) - len(self.suffix))
        self.pad_id = facts.get("pad", 0)
        self.verdict_row = facts.get("verdict_row", len(self.prefix) + self.n_content + len(self.suffix) - 1)
        # [v21, R-C2] the tables DERIVED from the pinned tensor (B-3): the
        # embedding (for tau) and the margin row, when the caller derived them
        self.emb = facts.get("emb")
        # [v21] C-13 control only: positions the PORT treats as pad positions
        # inside the content range (never set on an honest check)
        self.extra_pad = set(facts.get("extra_pad_positions") or ())
        self.verdict = facts.get("verdict")
        self.w_delta = facts.get("w_delta")
        self.lay = geom.stage_in_c() if kind == "IN-C" else geom.stage_out_c()
        self.n = 1 << self.lay.log_n
        self.b_in_row, self.b_out_row = facts.get("b_in_row", 0), facts.get("b_out_row", 0)
        self.b_log = TT.clog2(self.t_pad * self.d_pad)
        self.ep_mask_row = facts.get("ep_mask_row", 0)
        self.r_emb = list(r_emb) if r_emb is not None else []
        self.drop_pad, self.extra = drop_pad, extra
        self.shared_template_mu = shared_template_mu
        self.data = {}
        self.logup_num = list(logup)
        if mode == "numeric":
            ring = [F2(x) for x in logup]
        else:
            ring = [Poly.var(nm) for nm in (("c:beta", "c:gamma", "c:alpha") if kind == "IN-C" else ("c:gamma", "c:alpha"))]
        if kind == "IN-C":
            # stage_in_c.rs:326-334 `challenges`: beta, gamma, alpha, r_emb
            self.beta, gamma, self.alpha = ring
            self.g_emb = gamma * K(TAG_EMB)
            self.beta_num = logup[0]
            self.g_emb_num = mulb(logup[1], TAG_EMB)
        else:
            # stage_out_c.rs:548-550: gamma, alpha
            gamma, self.alpha = ring
            self.g_u8 = gamma * K(TAG_U8)
            self.g_u8_num = mulb(logup[0], TAG_U8)

    def pad(self, x):
        return R_ZERO if self.drop_pad else x

    # classify.rs:489-532 at r14 [v21: n is the facts' content length; the
    # suffix spans P0 + n .. P0 + n + S, the pad id fills the rest up to T]
    def p0(self):
        return len(self.prefix)

    def item_len(self):
        return self.p0() + self.n_content + len(self.suffix)

    def is_template(self, t):
        return t < self.p0() or (self.p0() + self.n_content <= t < self.tokens) or t in self.extra_pad

    def kappa(self, t):
        n = self.n_content
        if t in self.extra_pad:
            return self.pad_id
        if t < self.p0():
            return self.prefix[t]
        if self.p0() + n <= t < self.item_len():
            return self.suffix[t - self.p0() - n]
        if self.item_len() <= t < self.tokens:
            return self.pad_id
        return 0

    def ctl(self, v):
        return v < self.num_special

    def ctl_q(self, t):
        return self.is_template(t) and self.ctl(self.kappa(t))


class BC(TT.B):
    """`SB` for a classifier stage: the token port's builder with the
    classifier's roles and plane names"""

    def __init__(self, cx: ClassCtx, slot: int):  # noqa: D401  (TT.B's state, set by hand)
        self.cx, self.slot, self.lay = cx, slot, cx.lay
        self.tabs = []
        self.ak = self.hk = self.iok = 0
        if cx.kind == "IN-C":
            self.roles = ["A-in", "H-in", "E-token-in", "B-in"]
            self.a_names, self.h_names = CL.INC_A_NAMES, CL.INC_H_NAMES
        else:
            self.roles = ["A-out", "H-out", "B-out", "NO-OUTPUT-ENDPOINT"]
            self.a_names, self.h_names = CL.OUTC_A_NAMES, CL.OUTC_H_NAMES


# =====================================================================
#  stage IN-C (stage_in_c.rs:168-233)
# =====================================================================
def define_in_c(slot, cx: ClassCtx, dr: Draws) -> SlotDef:
    b = BC(cx, slot)
    alpha, beta, g_emb = cx.alpha, cx.beta, cx.g_emb
    g = cx.geom
    tl, sn = g.ti_log(), 1 << g.ti_log()
    lv, vn = g.voc_log(), 1 << g.voc_log()
    t_bits = TT.clog2(cx.t_pad)
    if slot == CL.SIC_IO:                                      # :177-187
        words = g.in_ep_words()
        lw = TT.clog2(words)
        tau, _ = dr.take(lw, "tau")
        i_eq = b.eq(tau, 0)
        i_supp = b.public(("supp", cx.tokens, words))
        ct = fixed_c([ZERO] * (tl - lw)) + rho_c(range(lw))
        i_tok = b.a_at(CL.INC_A_TOK, ct)
        i_end = b.io("In", lw, rho_c(range(lw)), cx.ep_mask_row)
        return b.finish(lambda v: v[i_eq] * (v[i_end] - v[i_supp] * v[i_tok]), [],
                        ["eq(tau)", "endpoint - supp_T * tok"], dr)
    if slot == CL.SIC_QZC:                                     # :190-216
        tau, _ = dr.take(tl, "tau")
        _, mu = dr.take(4, "mu", nonzero=True)                 # FOUR fresh coefficients
        _, zz = dr.take(1, "zeta", nonzero=True)
        zeta = zz[0]
        mu_t = mu[0] if cx.shared_template_mu else mu[2]       # IC-2's control copy only
        i_eq = b.eq(tau, 0)
        i_supp = b.public(("supp", cx.tokens, sn))
        i_u0 = b.public(("supp", 1, sn))
        i_pi = b.public(("template_pi", sn))
        i_kappa = b.public(("template_kappa", sn))
        i_cq = b.public(("ctl_q_beta2", sn))
        i_tok = b.a(CL.INC_A_TOK)
        i_hq = b.h(CL.INC_H_Q)
        cb = rho_c(range(tl - t_bits, tl)) + fixed_c(cx.r_emb)
        i_b = b.io("Out", cx.b_log, cb, cx.b_in_row)
        bos = K(cx.bos)

        def poly(v):                                           # :207-215
            q = v[i_tok] + beta * v[i_b] + v[i_cq] + g_emb
            logup = v[i_hq] * (alpha - q) - v[i_supp]
            bos_c = v[i_u0] * (v[i_tok] - bos)
            tmpl = v[i_pi] * (v[i_tok] - v[i_kappa])
            pad = cx.pad((R_ONE - v[i_supp]) * (v[i_tok] + zeta * v[i_hq]))
            return v[i_eq] * (mu[0] * logup + mu[1] * bos_c + mu_t * tmpl + mu[3] * pad)
        return b.finish(poly, [], ["eq(tau)", "mu0 LogUp h_q (alpha - q(tok, row, ctl)) - supp_T",
                                   "mu1 BOS u0 (tok - bos)", "mu2 TEMPLATE pi (tok - kappa)",
                                   "mu3 pad (1 - supp_T)(tok + zeta h_q)"], dr)
    if slot == CL.SIC_TZC:                                     # :217-228
        tau, _ = dr.take(lv, "tau")
        _, mu = dr.take(2, "mu", nonzero=True)
        _, zz = dr.take(1, "zeta", nonzero=True)
        zeta = zz[0]
        i_eq = b.eq(tau, 0)
        i_supp = b.public(("supp", cx.v, vn))
        i_tau = b.public(("captured", "tau_tab_c"))
        i_m = b.a(CL.INC_A_MULT)
        i_h = b.h(CL.INC_H_TAB)

        def poly(v):
            rel = v[i_h] * (alpha - v[i_tau]) - v[i_m]
            pad = cx.pad((R_ONE - v[i_supp]) * (v[i_m] + zeta * v[i_h]))
            return v[i_eq] * (mu[0] * rel + mu[1] * pad)
        return b.finish(poly, [], ["eq(tau)", "mu0 h_tab (alpha - tau(v, ctl)) - m",
                                   "mu1 pad (1 - supp_V)(m + zeta h_tab)"], dr)
    if slot == CL.SIC_ZS:                                      # :229-233
        i1 = b.public(("ones", 1 << cx.lay.h_log[CL.INC_H_U]))
        iu = b.h(CL.INC_H_U)
        return b.finish(lambda v: v[i1] * v[iu], [], ["ones * u"], dr)
    raise ValueError("classifier stage IN-C: unknown slot")


# =====================================================================
#  stage OUT-C (stage_out_c.rs:284-418)
# =====================================================================
def lookups_lo_c():                                            # stage_out_c.rs:127-129
    return [([(CL.C_LIMB, 1)], 0)]


def lookups_do_c():                                            # stage_out_c.rs:130-135
    v = [([(CL.C_XL0, 1)], 0), ([(CL.C_XL1, 1)], 0), ([(CL.C_Y, 1)], 127), ([(CL.C_Y, -1)], 127)]
    v += [([(CL.C_RHO0 + kk, 1)], 0) for kk in range(NORM_LIMBS)]
    v += [([(CL.C_SIG0 + kk, 1)], 0) for kk in range(NORM_LIMBS)]
    return v


def live_limb(z, limbs):                                       # stage_out_c.rs:276-278
    return (z % 2 == 0 and z // 2 < 3 * LIMBS_ISQRT) or (CL.LAM_BASE <= z < CL.LAM_BASE + limbs)


def define_out_c(slot, cx: ClassCtx, dr: Draws) -> SlotDef:
    b = BC(cx, slot)
    alpha, g_u8 = cx.alpha, cx.g_u8
    l = cx.limbs
    g = cx.geom
    d_bits = TT.clog2(cx.d_pad)
    t_bits = TT.clog2(cx.t_pad)
    llo, lo_n = g.lo_log(), 1 << g.lo_log()
    ldo, do_n = g.do_log(), 1 << g.do_log()
    ltab, tab_n = g.tab_log(), 1 << g.tab_log()
    lift = ldo - d_bits

    def f0():
        return [("fixed", ZERO)] * TO_LOG

    if slot == CL.SOC_IO:                                      # :297-307
        tau, _ = dr.take(d_bits, "tau")
        i_eq = b.eq(tau, 0)
        i_x = b.a_at(CL.C_X, fixed_c([ZERO] * lift) + rho_c(range(d_bits)))
        # [v21, R-C3] stage_out_c.rs:302 at r14: the PUBLIC verdict row
        # P0 + n + S - 1 (T - 1 without pad)
        cb = fixed_bits_c(cx.verdict_row, t_bits) + rho_c(range(d_bits))
        i_b = b.io("In", cx.b_log, cb, cx.b_out_row)
        return b.finish(lambda v: v[i_eq] * (v[i_x] - v[i_b]), [], ["eq(tau)", "x - B_out(verdict row, .)"], dr)
    if slot == CL.SOC_SS:                                      # :308-312
        i_s = b.public(("supp", cx.d, do_n))
        i_x = b.a(CL.C_X)
        return b.finish(lambda v: v[i_s] * v[i_x] * v[i_x], [], ["supp_d * x * x"], dr)
    if slot == CL.SOC_TZC:                                     # :313-335
        tau, _ = dr.take(TO_LOG, "tau")
        _, mu = dr.take(4, "mu", nonzero=True)
        nu_num, nus = dr.take(1, "nu", nonzero=True)
        nu = nus[0]
        _, zz = dr.take(1, "zeta", nonzero=True)
        zeta = zz[0]
        i_eq = b.eq(tau, 0)
        i_u0 = b.public(("supp", 1, 1 << TO_LOG))
        i_d = b.a(CL.C_D)
        i_dsq = b.a(CL.C_DSQ)
        i_l0 = i_dsq + 1
        for kk in range(3 * LIMBS_ISQRT):
            b.a_slice(cx.lay.a_off_rows[CL.C_LIMB] * cx.n + 2 * kk, TO_LOG, rho_c(range(TO_LOG)), "A_LIMB")
        k_ceps = K(cx.ceps)
        p1, p2 = K(256), K(65536)

        def poly(v):
            def l3(o):
                return v[o] + v[o + 1] * p1 + v[o + 2] * p2
            d, dsq = v[i_d], v[i_dsq]
            dl, a1, a2 = l3(i_l0), l3(i_l0 + 3), l3(i_l0 + 6)
            pad = cx.pad((R_ONE - v[i_u0]) * (d + zeta * dsq))
            zc = mu[0] * (dsq - d * d) + mu[1] * (d - dl) + mu[2] * (d * K(2) - a1 - a2) + mu[3] * pad
            return v[i_eq] * zc + nu * v[i_u0] * (dsq + a1 - k_ceps)
        return b.finish(poly, [(CL.SOC_SS, nu_num[0])], ["eq(tau)", "mu0 Dsq - D^2", "mu1 D - limbs",
                                                         "mu2 2D - a1 - a2", "mu3 pad", "nu u0 (Dsq + a1 - Ceps) [host of SS]"], dr)
    if slot == CL.SOC_PD:                                      # :338-345
        cy = fixed_c([ZERO] * lift) + rho_c(range(d_bits))
        i_y = b.a_at(CL.C_Y, cy)
        i_w = b.public(("w_delta", cx.d, cx.d_pad))
        return b.finish(lambda v: v[i_y] * v[i_w], [], ["y * w_Delta (the margin, private, hosted by LZC)"], dr)
    if slot == CL.SOC_LZC:                                     # :349-370
        tau, _ = dr.take(llo, "tau")
        _, mu = dr.take(2, "mu", nonzero=True)
        nu_num, nus = dr.take(1, "nu", nonzero=True)
        nu = nus[0]
        i_eq = b.eq(tau, 0)
        i_s = b.public(("live_limb_c", l, lo_n))
        i_g = b.public(("margin_g", l, lo_n))
        i_u0 = b.public(("supp", 1, lo_n))
        i_l = b.a(CL.C_LIMB)
        i_h = b.h(CL.OC_H_LO)
        lks = TT.resolve(lookups_lo_c(), lambda _p: i_l, g_u8)
        ones = [R_ONE]
        kc = K(int(cx.verdict)) + K(cx.c)                      # :363 the public constant sigma b + c

        def poly(v):
            pad = cx.pad((R_ONE - v[i_s]) * v[i_l])
            host = v[i_g] * v[i_l] + v[i_u0] * kc
            return v[i_eq] * (mu[0] * helper_sum(v, lks, i_h, alpha, ones) + mu[1] * pad) + nu * host
        return b.finish(poly, [(CL.SOC_PD, nu_num[0])], ["eq(tau)", "mu0 the limb lookups (isqrt and margin limbs)",
                                                         "mu1 pad (1 - live) limb",
                                                         "nu (g limb + u0 (sigma b + c)) [host of PD: the margin identity]"], dr)
    if slot == CL.SOC_DZC:                                     # :371-400
        tau, _ = dr.take(ldo, "tau")
        _, mu = dr.take(3 + CL.OC_H_DO_HELPERS + 1, "mu", nonzero=True)
        _, zz = dr.take(1, "zeta", nonzero=True)
        zeta = zz[0]
        i_eq = b.eq(tau, 0)
        i_s = b.public(("supp", cx.d, do_n))
        first = b.tabs_len()
        for p in range(CL.C_X, CL.C_MULT):
            b.a(p)

        def at(p):
            return first + (p - CL.C_X)
        i_d = b.a_at(CL.C_D, f0())
        h0 = b.h(CL.OC_H_D0)
        for j in range(1, CL.OC_H_DO_HELPERS):
            b.h(CL.OC_H_D0 + j)
        lks = TT.resolve(lookups_do_c(), at, g_u8)
        planes = [at(p) for p in range(CL.C_X, CL.C_MULT)]
        k_num, k_dv, k_den = K(2 * cx.g0 * cx.cn), K(1 << cx.tn), K(1 << (cx.tn + 1))

        def poly(v):
            def lb(p0):
                acc = R_ZERO
                for kk in range(NORM_LIMBS):
                    acc = acc + v[at(p0 + kk)] * K(1 << (8 * kk))
                return acc
            x, y, d = v[at(CL.C_X)], v[at(CL.C_Y)], v[i_d]
            rh, sg = lb(CL.C_RHO0), lb(CL.C_SIG0)
            kd = d * k_den
            c0 = x * k_num + d * k_dv - kd * y - rh
            c1 = sg + rh + R_ONE - kd
            c2 = x + K(32768) - v[at(CL.C_XL0)] - v[at(CL.C_XL1)] * K(256)
            gg = v[i_s]
            clauses = mu[0] * c0 + mu[1] * c1 + mu[2] * c2
            pad = cx.pad((R_ONE - gg) * zeta_fold(v, planes, zeta))
            return v[i_eq] * (gg * clauses + helper_sum(v, lks, h0, alpha, mu[3:3 + CL.OC_H_DO_HELPERS])
                              + mu[3 + CL.OC_H_DO_HELPERS] * pad)
        return b.finish(poly, [], ["eq(tau)", "supp_d (mu0 c0 + mu1 c1 + mu2 c2)", "6 helpers on 12 byte lookups",
                                   "pad (1 - supp_d) zeta-fold of 12 planes"], dr)
    if slot == CL.SOC_TAB:                                     # :401-414
        tau, _ = dr.take(ltab, "tau")
        _, mu = dr.take(2, "mu", nonzero=True)
        _, zz = dr.take(1, "zeta", nonzero=True)
        zeta = zz[0]
        i_eq = b.eq(tau, 0)
        i_s = b.public(("supp", U8_LEN, tab_n))
        i_tv = b.public(("u8_tagged", tab_n))
        i_m = b.a(CL.C_MULT)
        i_h = b.h(CL.OC_H_GU8)

        def poly(v):
            rel = v[i_h] * (alpha - v[i_tv]) - v[i_m]
            pad = cx.pad((R_ONE - v[i_s]) * (v[i_m] + zeta * v[i_h]))
            return v[i_eq] * (mu[0] * rel + mu[1] * pad)
        return b.finish(poly, [], ["eq(tau)", "mu0 h (alpha - tv) - m", "mu1 pad"], dr)
    if slot == CL.SOC_ZS:                                      # :415-418
        i1 = b.public(("ones", 1 << cx.lay.h_log[CL.OC_H_U]))
        iu = b.h(CL.OC_H_U)
        return b.finish(lambda v: v[i1] * v[iu], [], ["ones * u"], dr)
    raise ValueError("classifier stage OUT-C: unknown slot")


def define(slot, cx: ClassCtx, dr: Draws) -> SlotDef:
    return define_in_c(slot, cx, dr) if cx.kind == "IN-C" else define_out_c(slot, cx, dr)


# =====================================================================
#  the public tables: every one rebuilt from public data, or digest-checked
# =====================================================================
def rebuild_public_c(desc, cx: ClassCtx):
    """The values of a classifier public table, from the geometry, the
    profile, the re-derived challenges and the verdict ONLY (expectation
    'one public bit'); None for the two tables taken from elsewhere (tau,
    which folds the embedding, and w_Delta, digest-checked against the
    statement)."""
    kind = desc[0]
    if kind == "supp":
        return [ONE if z < desc[1] else ZERO for z in range(desc[2])]
    if kind == "ones":
        return [ONE] * desc[1]
    if kind == "u8_tagged":
        return [add(k(z % U8_LEN), cx.g_u8_num) for z in range(desc[1])]
    if kind == "template_pi":                                  # stage_in_c.rs:196
        return [ONE if cx.is_template(t) else ZERO for t in range(desc[1])]
    if kind == "template_kappa":                               # stage_in_c.rs:197
        return [k(cx.kappa(t)) for t in range(desc[1])]
    if kind == "ctl_q_beta2":                                  # stage_in_c.rs:198-199
        b2 = mul(cx.beta_num, cx.beta_num)
        return [b2 if cx.ctl_q(t) else ZERO for t in range(desc[1])]
    if kind == "live_limb_c":                                  # stage_out_c.rs:356
        return [ONE if live_limb(z, desc[1]) else ZERO for z in range(desc[2])]
    if kind == "margin_g":                                     # stage_out_c.rs:357-358
        sig = ONE if cx.verdict == 1 else k(-1)
        return [mul(sig, k(1 << (8 * (z - CL.LAM_BASE)))) if CL.LAM_BASE <= z < CL.LAM_BASE + desc[1] else ZERO
                for z in range(desc[2])]
    if kind == "w_delta":
        if cx.w_delta is None:
            return None
        return [k(cx.w_delta[i]) if i < desc[1] else ZERO for i in range(desc[2])]
    # [v21, R-C2] tau is REBUILT from the embedding DERIVED from the pinned
    # tied tensor (zk60_native_rg_classtied; stage_in_c.rs:158-164 at r14),
    # folded at the replayed r_emb with the replayed beta and g_emb
    if kind == "captured" and desc[1] == "tau_tab_c" and cx.emb is not None and cx.kind == "IN-C":
        import zk60_native_rg_classtied as TD
        key = ("tau", tuple(map(tuple, cx.r_emb)), tuple(cx.beta_num), tuple(cx.g_emb_num), cx.num_special,
               id(cx.emb))
        hit = TD._CACHE.get(key)
        if hit is None:
            hit = TD.tau_table(cx.emb, cx.v, cx.d, cx.geom.voc_log(), cx.num_special, cx.r_emb,
                               cx.beta_num, cx.g_emb_num)
            TD._CACHE[key] = hit
        return list(hit)
    return None


def table_class_c(desc):
    kind = desc[0]
    if kind in ("supp", "template_pi", "live_limb_c"):
        return "indicator"
    if kind == "ones":
        return "constant-MLE"
    return "values"


def describe_c(desc) -> str:
    return {"supp": lambda: f"supp({desc[1]}) over {desc[2]}", "ones": lambda: f"ones over {desc[1]}",
            "u8_tagged": lambda: f"byte table over {desc[1]}", "template_pi": lambda: "template indicator pi",
            "template_kappa": lambda: "template ids kappa", "ctl_q_beta2": lambda: "query control column beta^2 ctl_q",
            "live_limb_c": lambda: "limb-plane live selector (isqrt + margin limbs)",
            "margin_g": lambda: "g(z) = sigma 256^(z-32) on the margin limbs",
            "w_delta": lambda: "margin vector w_Delta", "captured": lambda: f"captured {desc[1]}"}.get(
                desc[0], lambda: str(desc))()


# =====================================================================
#  digests the verifier re-derives (B-3) — the gate's own transcriptions
# =====================================================================
def _blake3():
    import blake3
    return blake3.blake3()


def w_digest(d: int, words) -> str:
    """`ClassifierTables::w_digest` (classify.rs:250-258)"""
    h = _blake3()
    h.update(b"hashline/classify/margin-vector-int16/v1")
    h.update(int(d).to_bytes(8, "little"))
    for w in words:
        h.update(int(w).to_bytes(2, "little", signed=True))
    return h.hexdigest()


def template_digest(prefix, suffix) -> str:
    """`ClassifierProfile::template_digest` (classify.rs:458-468)"""
    h = _blake3()
    h.update(b"hashline/classify/template/v1")
    for part in (prefix, suffix):
        h.update(len(part).to_bytes(8, "little"))
        for x in part:
            h.update(int(x).to_bytes(8, "little"))
    return h.hexdigest()


def header_tail_check(labels: list) -> dict:
    """the run header's last two absorbs are `classify-verdict` then
    `classify-chunk` (classify.rs:879-880); a transcript-label list without
    them is refused (MC-7's site)"""
    f = []
    for lab in CL.HEADER_TAIL_LABELS:
        if lab not in labels:
            f.append(f"the run header does not absorb {lab!r}")
    if not f:
        iv, ic = labels.index("classify-verdict"), labels.index("classify-chunk")
        if not ic == iv + 1:
            f.append("classify-chunk does not follow classify-verdict")
        later = [x for x in labels[ic + 1:] if x not in ("pb-run-stage", "pb-run-block", "B", "A", "M", "H")]
        _ = later
    return {"labels_read": len(labels), "findings": f, "ok": not f}


# =====================================================================
#  synthetic witnesses (the integer semantics R-C1 proves)
# =====================================================================
FACTS_RUNG = {"bos": 1, "final_norm": {"g0": 64, "cn": 1024, "tn": 11, "ceps": 1},
              "prefix": list(range(1, 9)), "suffix": [32], "num_special": 5, "c": 0}


def _isqrt(v):
    return math.isqrt(v)


def out_values(g: CL.ClassGeom, facts: dict, x_row: list, w: list) -> dict:
    """`out_values` (stage_out_c.rs:162-190): the final norm and the margin"""
    nm = facts["final_norm"]
    ss = nm["ceps"] + sum(v * v for v in x_row[:g.d])
    d = _isqrt(ss)
    a1 = ss - d * d
    a2 = 2 * d - a1
    dv = d << nm["tn"]
    den = 2 * dv
    y, rho, sig = [0] * g.d_pad, [0] * g.d_pad, [0] * g.d_pad
    for i in range(g.d):
        num = 2 * x_row[i] * nm["g0"] * nm["cn"] + dv
        q = num // den
        r = num - q * den
        y[i], rho[i], sig[i] = q, r, den - 1 - r
    margin = sum(w[i] * y[i] for i in range(g.d))
    return {"x": list(x_row) + [0] * (g.d_pad - g.d), "d": d, "a1": a1, "a2": a2, "y": y, "rho": rho,
            "sigma": sig, "margin": margin, "verdict": int(margin > facts["c"])}


def delta_of(margin, c, b):
    """`delta_of` (stage_out_c.rs:199-202)"""
    s = 2 * b - 1
    return s * (margin - c) - b


def _bytes(v, n):
    return [(v >> (8 * kk)) & 0xFF for kk in range(n)]


def out_witness(g: CL.ClassGeom, ov: dict, verdict: int, c: int, *, limbs_override=None) -> dict:
    """`witness_from_values` (stage_out_c.rs:205-247): A_out's planes"""
    l = g.limbs
    lo_n, do_n = 1 << g.lo_log(), 1 << g.do_log()
    planes = {}
    planes["A_D"] = [ov["d"], 0]
    planes["A_DSQ"] = [ov["d"] * ov["d"], 0]
    limb = [0] * lo_n
    for s, val in enumerate((ov["d"], ov["a1"], ov["a2"])):
        for kk, bb in enumerate(_bytes(val, LIMBS_ISQRT)):
            limb[2 * (3 * s + kk)] = bb
    delta = delta_of(ov["margin"], c, verdict)
    lam = limbs_override if limbs_override is not None else _bytes(delta, l)
    for kk, bb in enumerate(lam):
        limb[CL.LAM_BASE + kk] = bb
    planes["A_LIMB"] = limb
    for nm in CL.OUTC_A_NAMES[3:15]:
        planes[nm] = [0] * do_n
    for i in range(g.d):
        planes["A_X"][i] = ov["x"][i]
        xl = _bytes(ov["x"][i] + 32768, 2)
        planes["A_XL0"][i], planes["A_XL1"][i] = xl
        planes["A_Y"][i] = ov["y"][i]
        for kk, bb in enumerate(_bytes(ov["rho"][i], NORM_LIMBS)):
            planes[f"A_RHO{kk}"][i] = bb
        for kk, bb in enumerate(_bytes(ov["sigma"][i], NORM_LIMBS)):
            planes[f"A_SIG{kk}"][i] = bb
    return {"A": planes, "delta": delta}


def _fe(v):
    return k(int(v))


def _inv(x):
    return f2_inv(x)


def out_helpers(g: CL.ClassGeom, wit: dict, alpha, g_u8, *, cheat_hist=True) -> dict:
    """the stage's H columns (stage_out_c.rs:587-626): the limb-domain
    helper, six Do helpers (lookup pairs), the byte-table helper from the
    histogram (a value that is not a byte is counted at 0, as the cheating
    prover does), and u = 0"""
    A = wit["A"]
    lo_n, do_n, tab_n = 1 << g.lo_log(), 1 << g.do_log(), 1 << g.tab_log()

    def looked(lks, n):
        cols = []
        for terms, cst in lks:
            cols.append([sum(cc * A[CL.OUTC_A_NAMES[p]][x] for p, cc in terms) + cst for x in range(n)])
        return cols
    lo_cols = looked(lookups_lo_c(), lo_n)
    do_cols = looked(lookups_do_c(), do_n)
    hist = [0] * U8_LEN
    for col in lo_cols + do_cols:
        for v in col:
            hist[v if 0 <= v < U8_LEN else 0] += 1
    A["A_MU8"] = hist + [0] * (tab_n - U8_LEN)

    def h1(v):
        return _inv(sub(alpha, add(_fe(v), g_u8)))
    H = {"H_LO": [h1(v) for v in lo_cols[0]]}
    for kk in range(CL.OC_H_DO_HELPERS):
        a, bcol = do_cols[2 * kk], do_cols[2 * kk + 1]
        H[f"H_D{kk}"] = [add(h1(a[x]), h1(bcol[x])) for x in range(do_n)]
    H["H_GU8"] = [mul(_inv(sub(alpha, add(k(z % U8_LEN), g_u8))), k(hist[z])) if z < U8_LEN and hist[z] else ZERO
                  for z in range(tab_n)]
    H["H_U"] = [ZERO] * (1 << g.stage_out_c().h_log[CL.OC_H_U])
    return H


def logup_balance_out(g: CL.ClassGeom, H: dict) -> bool:
    """OUT-C's LogUp sum claim with H's signs (h_sign: every helper +1, the
    table helper -1): balanced iff every looked value is in the table"""
    acc = ZERO
    for nm in ["H_LO"] + [f"H_D{kk}" for kk in range(CL.OC_H_DO_HELPERS)]:
        for v in H[nm]:
            acc = add(acc, v)
    for v in H["H_GU8"]:
        acc = sub(acc, v)
    return acc == ZERO


def _tab_vectors(sd: SlotDef, cx: ClassCtx, A: dict, H: dict, main: int, eq_value):
    """each table of a slot as a vector over its 2^main points (eq tables set
    to `eq_value`, so a zero-check clause or a host term can be read alone)"""
    n_pts = 1 << main
    vecs = []
    for t in sd.tabs:
        if t["kind"] == "eq":
            vecs.append([eq_value] * n_pts)
        elif t["kind"] == "public":
            vals = rebuild_public_c(t["desc"], cx)
            if vals is None and t["desc"][0] == "captured" and t["desc"][1] == "tau_tab_c":
                vals = cx.data["tau_tab_c"]
            if vals is None:
                raise ValueError(f"no values for {t['desc']}")
            vecs.append(list(vals[:n_pts]))
        elif t["role"] in ("A-in", "A-out"):
            plane = A[t["plane"]]
            off = t["slices"][0][0] - cx.lay.a_off_rows[cx.lay_a_index(t["plane"])] * cx.n
            fixed = [c for c in t["coords"] if c[0] == "fixed"]
            rho = [c for c in t["coords"] if c[0] == "rho"]
            if fixed and rho and all(x[1] == ZERO for x in fixed) and t["coords"][:len(fixed)] == fixed:
                vec = [plane[off + x] for x in range(1 << len(rho))]
            elif fixed and not rho:
                vec = [plane[off]] * n_pts
            else:
                vec = [plane[off + x] for x in range(1 << len(rho))]
            if len(vec) < n_pts:
                raise ValueError(f"plane {t['plane']} gives {len(vec)} points, the slot sums over {n_pts}")
            vecs.append([_fe(v) if isinstance(v, int) else v for v in vec[:n_pts]])
        elif t["role"] in ("H-in", "H-out"):
            vecs.append(list(H[t["plane"]][:n_pts]))
        else:
            vecs.append(list(cx.data[t["role"]][:n_pts]))
    return vecs


def _lay_a_index(self, name):
    names = CL.INC_A_NAMES if self.kind == "IN-C" else CL.OUTC_A_NAMES
    return names.index(name)


ClassCtx.lay_a_index = _lay_a_index


def slot_sum(sd: SlotDef, cx: ClassCtx, A, H, main, eq_value):
    vecs = _tab_vectors(sd, cx, A, H, main, eq_value)
    acc = ZERO
    for x in range(1 << main):
        acc = add(acc, sd.poly([F2(vec[x]) for vec in vecs]).v)
    return acc


def slot_pointwise_nonzero(sd: SlotDef, cx: ClassCtx, A, H, main):
    """the points where the slot's polynomial (eq = 1) does not vanish"""
    vecs = _tab_vectors(sd, cx, A, H, main, ONE)
    return [x for x in range(1 << main) if sd.poly([F2(vec[x]) for vec in vecs]).v != ZERO]


def _draws(n=40, seed=1):
    rng = random.Random(seed)
    return [(rng.randrange(1, P), rng.randrange(P)) for _ in range(n)]


def out_c_relations(g: CL.ClassGeom, facts: dict, ov: dict, w: list, *, verdict=None, c_port=None,
                    limbs_override=None, pad_entry=None, seed=7) -> dict:
    """MRG-H, ZC-H and LU-H for stage OUT-C on one witness; the keyword
    arguments are the controls' perturbations"""
    rng = random.Random(seed)
    gamma, alpha = (rng.randrange(1, P), rng.randrange(P)), (rng.randrange(1, P), rng.randrange(P))
    b = ov["verdict"] if verdict is None else verdict
    wit = out_witness(g, ov, b, facts["c"], limbs_override=limbs_override)
    A = wit["A"]
    if pad_entry is not None:
        A["A_LIMB"][pad_entry] = 1
    A["A_LIMB"] = [x % P for x in A["A_LIMB"]]
    fx = dict(facts, verdict=b, w_delta=w, c=facts["c"] if c_port is None else c_port)
    cx = ClassCtx(g, "OUT-C", [gamma, alpha], None, "numeric", fx)
    H = out_helpers(g, wit, alpha, cx.g_u8_num)
    lay = cx.lay
    res = {"verdict": b, "margin": ov["margin"], "delta": wit["delta"], "zero_check_nonzero_points": {}}
    for s in (CL.SOC_PD, CL.SOC_LZC):
        pass
    sd_pd = define_out_c(CL.SOC_PD, cx, Draws(_draws(), "numeric"))
    sd_lzc = define_out_c(CL.SOC_LZC, cx, Draws(_draws(), "numeric"))
    nu = F2(_draws()[lay.lo_log() if False else 0])  # placeholder (not used)
    _ = nu
    s_pd = slot_sum(sd_pd, cx, A, H, lay.slots[CL.SOC_PD].main, ONE)
    # the LZC host term alone: eq set to 0 leaves nu * host
    dr = Draws(_draws(), "numeric")
    sd_lzc = define_out_c(CL.SOC_LZC, cx, dr)
    nu_val = dr.num[lay.slots[CL.SOC_LZC].main + 2]
    s_host_nu = slot_sum(sd_lzc, cx, A, H, lay.slots[CL.SOC_LZC].main, ZERO)
    s_host = mul(s_host_nu, f2_inv(nu_val))
    # SS-H: the final norm's row sum hosted by TZC (sum x^2 == u0 (Dsq + a1 - Ceps))
    sd_ss = define_out_c(CL.SOC_SS, cx, Draws(_draws(), "numeric"))
    s_ss = slot_sum(sd_ss, cx, A, H, lay.slots[CL.SOC_SS].main, ONE)
    dr_t = Draws(_draws(seed=29), "numeric")
    sd_t = define_out_c(CL.SOC_TZC, cx, dr_t)
    nu_t = dr_t.num[TO_LOG + 4]
    s_tzc = mul(slot_sum(sd_t, cx, A, H, lay.slots[CL.SOC_TZC].main, ZERO), f2_inv(nu_t))
    res["SS_H_holds"] = s_ss == s_tzc
    res["MRG_H_sum_PD"] = list(s_pd)
    res["MRG_H_sum_host"] = list(s_host)
    res["MRG_H_holds"] = s_pd == s_host
    for s in (CL.SOC_TZC, CL.SOC_LZC, CL.SOC_DZC, CL.SOC_TAB):
        drs = Draws(_draws(seed=s + 11), "numeric")
        sd = define_out_c(s, cx, drs)
        if s == CL.SOC_LZC:
            # nu = 0 isolates the zero-check part
            num = list(drs.num)
            num[lay.slots[s].main + 2] = ZERO
            sd = define_out_c(s, cx, Draws(num, "numeric"))
        if s == CL.SOC_TZC:
            num = list(drs.num)
            num[TO_LOG + 4] = ZERO
            sd = define_out_c(s, cx, Draws(num, "numeric"))
        bad = slot_pointwise_nonzero(sd, cx, A, H, lay.slots[s].main)
        res["zero_check_nonzero_points"][CL.OUTC_NAMES[s][:7]] = bad[:5]
    res["ZC_H_holds"] = not any(res["zero_check_nonzero_points"].values()) and res["SS_H_holds"]
    res["LU_H_holds"] = logup_balance_out(g, H)
    return res


# ---------------------------------------------------------------- stage IN-C
def in_c_relations(g: CL.ClassGeom, facts: dict, tokens: list, *, shared_mu=False, seed=5) -> dict:
    """ZC-H (INC-01's clauses pointwise, with the template clause) and LU-H
    (the (id, row, ctl) LogUp balance) for one item's tokens.  The embedding
    fold E~(v, r_emb) is a random public vector (only consistency matters),
    and the B_in row fold x~(t, r_emb) is E~ at the token's id, as the honest
    chain gives it."""
    rng = random.Random(seed)
    beta, gamma, alpha = [(rng.randrange(1, P), rng.randrange(P)) for _ in range(3)]
    cx = ClassCtx(g, "IN-C", [beta, gamma, alpha], [], "numeric", facts, shared_template_mu=shared_mu)
    ti_n, voc_n = 1 << g.ti_log(), 1 << g.voc_log()
    ef = [(rng.randrange(P), rng.randrange(P)) for _ in range(g.v)]
    b2 = mul(beta, beta)
    g_emb = cx.g_emb_num

    def tau(v):
        row = v if v < g.v else 0
        t = add(add(k(row), mul(beta, ef[row])), g_emb)
        return add(t, b2) if cx.ctl(row) else t
    tau_tab = [tau(v) for v in range(voc_n)]
    tok = [0] * ti_n
    mult = [0] * voc_n
    for t, idv in enumerate(tokens):
        tok[t] = idv
        mult[idv] += 1
    xfold = [ef[tok[t]] if t < g.tokens else ZERO for t in range(ti_n)]
    cq = rebuild_public_c(("ctl_q_beta2", ti_n), cx)
    hq = []
    for t in range(ti_n):
        if t < g.tokens:
            q = add(add(add(k(tok[t]), mul(beta, xfold[t])), cq[t]), g_emb)
            hq.append(f2_inv(sub(alpha, q)))
        else:
            hq.append(ZERO)
    htab = [mul(f2_inv(sub(alpha, tau_tab[v])), k(mult[v])) if v < g.v and mult[v] else ZERO for v in range(voc_n)]
    A = {"A_TOK": tok, "A_MULT": mult}
    H = {"H_Q": hq, "H_TAB": htab, "H_U": [ZERO] * (1 << cx.lay.h_log[CL.INC_H_U])}
    cx.data = {"tau_tab_c": tau_tab, "B-in": xfold}
    lay = cx.lay
    res = {"zero_check_nonzero_points": {}}
    for s in (CL.SIC_QZC, CL.SIC_TZC):
        sd = define_in_c(s, cx, Draws(_draws(seed=s + 3), "numeric"))
        res["zero_check_nonzero_points"][CL.INC_NAMES[s][:6]] = slot_pointwise_nonzero(sd, cx, A, H, lay.slots[s].main)[:5]
    res["ZC_H_holds"] = not any(res["zero_check_nonzero_points"].values())
    acc = ZERO
    for v in hq:
        acc = add(acc, v)
    for v in htab:
        acc = sub(acc, v)
    res["LU_H_holds"] = acc == ZERO
    return res, cx, A, H


def ic2_shared_coefficient(g: CL.ClassGeom, facts: dict, content: list) -> dict:
    """IC-2 (CHECK2 N-1): at one template position put a wrong id and set
    the query helper so that `logup + tmpl = 0` there.  Under a SHARED
    coefficient (template clause times mu0) INC-01 vanishes at that point;
    under R-C1's fresh coefficient mu2 it does not."""
    toks = list(facts["prefix"]) + list(content) + list(facts["suffix"])
    t_bad = 3
    out = {}
    for shared in (True, False):
        res, cx, A, H = in_c_relations(g, facts, toks, shared_mu=shared)
        A2 = {"A_TOK": list(A["A_TOK"]), "A_MULT": list(A["A_MULT"])}
        A2["A_TOK"][t_bad] = A["A_TOK"][t_bad] + 50
        beta, alpha = cx.logup_num[0], cx.logup_num[2]
        cq = rebuild_public_c(("ctl_q_beta2", 1 << g.ti_log()), cx)
        q = add(add(add(k(A2["A_TOK"][t_bad]), mul(beta, cx.data["B-in"][t_bad])), cq[t_bad]), cx.g_emb_num)
        # logup(t) = h (alpha - q) - 1 = -(tok - kappa) = -50  =>  h = (1 - 50) / (alpha - q)
        H2 = dict(H)
        H2["H_Q"] = list(H["H_Q"])
        H2["H_Q"][t_bad] = mul(k(1 - 50), f2_inv(sub(alpha, q)))
        sd = define_in_c(CL.SIC_QZC, cx, Draws(_draws(seed=CL.SIC_QZC + 3), "numeric"))
        bad = slot_pointwise_nonzero(sd, cx, A2, H2, cx.lay.slots[CL.SIC_QZC].main)
        out["shared_coefficient" if shared else "fresh_coefficient"] = {"nonzero_points": bad[:5],
                                                                         "forgery_passes_pointwise": t_bad not in bad}
    out["fires"] = (out["shared_coefficient"]["forgery_passes_pointwise"]
                    and not out["fresh_coefficient"]["forgery_passes_pointwise"])
    return out


# =====================================================================
#  the plane index of a classifier stage (what a capture's plane table must say)
# =====================================================================
def plane_index_c(g: CL.ClassGeom, kind: str, facts: dict = None) -> dict:
    """per slot, the ordered list of the planes its terminal vector evaluates
    (the port's private tables, in push order), with the stage layout's row
    facts: the gate's expected `plane_index` for a classifier stage (request
    §2.1(b)).  Pure function of the geometry."""
    facts = dict(facts or FACTS_RUNG, verdict=1, w_delta=[1] * g.d)
    logup = _draws(3 if kind == "IN-C" else 2, seed=5)
    cx = ClassCtx(g, kind, logup, [ZERO] * TT.clog2(g.d_pad) if kind == "IN-C" else None, "numeric", facts)
    lay = cx.lay
    slots = []
    for s in range(len(lay.slots)):
        sd = define(s, cx, Draws(_draws(80, seed=s), "numeric"))
        slots.append({"slot": s, "name": lay.slots[s].name,
                      "planes": [f"{t['role']}:{t['plane']}" for t in sd.tabs if t["kind"] == "private"],
                      "public": [describe_c(t["desc"]) for t in sd.tabs if t["kind"] == "public"]})
    return {"stage": kind, "a_rows": lay.a_rows, "a_data_rows": lay.a_data_rows, "a_mask_base": lay.a_mask_base,
            "a_prox": lay.a_prox, "h_rows": lay.h_rows, "h_data_rows": lay.h_data_rows, "h_mask_base": lay.h_mask_base,
            "h_prox": lay.h_prox, "h_u": lay.h_u, "h_u_rows": lay.h_u_rows(), "log_n": lay.log_n,
            "a_planes": CL.INC_A_NAMES if kind == "IN-C" else CL.OUTC_A_NAMES,
            "h_planes": CL.INC_H_NAMES if kind == "IN-C" else CL.OUTC_H_NAMES,
            "slots": slots}


def cross_check_plane_index_c(g: CL.ClassGeom, kind: str, plane_index: dict) -> list:
    """For a CAPTURED classifier stage: the bundle's plane table against the
    re-derived one (empty = equal); field names as requested"""
    want = plane_index_c(g, kind)
    out = []
    for key in ("a_rows", "a_data_rows", "a_mask_base", "a_prox", "h_rows", "h_data_rows", "h_mask_base",
                "h_prox", "h_u", "h_u_rows", "log_n"):
        if plane_index.get(key) != want[key]:
            out.append(f"stage {kind}: `{key}` is {plane_index.get(key)!r} in the bundle, {want[key]!r} re-derived")
    got_slots = plane_index.get("slots") or []
    if len(got_slots) != len(want["slots"]):
        out.append(f"stage {kind}: {len(got_slots)} slots in the bundle, {len(want['slots'])} re-derived")
    else:
        for a, b in zip(got_slots, want["slots"]):
            if a.get("planes") != b["planes"]:
                out.append(f"stage {kind} slot {b['slot']}: plane order differs")
    return out


def one_bit_check(g: CL.ClassGeom, facts: dict, w: list, x_rows: list) -> dict:
    """G-3 expectation 'one public bit', checked on the transcription: every
    public table of stage OUT-C is rebuilt from the geometry, the profile
    (c, w_Delta) and the verdict alone, so two DIFFERENT hidden witnesses
    with the same verdict give byte-identical public tables, and flipping
    the verdict moves exactly the verdict's tables (g's sign) and the LZC
    host constant b + c.  The margin, its limbs and y are private terminals
    (A_out), never public values."""
    def tables(verdict):
        fx = dict(facts, verdict=verdict, w_delta=w)
        cx = ClassCtx(g, "OUT-C", _draws(2, seed=8), None, "numeric", fx)
        rows = {}
        for s in range(8):
            sd = define_out_c(s, cx, Draws(_draws(80, seed=s), "numeric"))
            for i, t in enumerate(sd.tabs):
                if t["kind"] == "public":
                    vals = rebuild_public_c(t["desc"], cx)
                    if vals is None:
                        return None, f"slot {s} table {i} ({t['desc'][0]}) is not rebuildable from public data"
                    rows[(s, i, t["desc"][0])] = hashlib.sha256(json.dumps(vals).encode()).hexdigest()
        return rows, None
    t1, e1 = tables(1)
    t0, e0 = tables(0)
    if e1 or e0:
        return {"ok": False, "finding": e1 or e0}
    moved = sorted({key[2] for key in t1 if t1[key] != t0[key]})
    ovs = [out_values(g, facts, x, w) for x in x_rows]
    privates = set()
    fx = dict(facts, verdict=1, w_delta=w)
    cx = ClassCtx(g, "OUT-C", _draws(2, seed=8), None, "numeric", fx)
    for s in range(8):
        sd = define_out_c(s, cx, Draws(_draws(80, seed=s), "numeric"))
        privates |= {t["plane"] for t in sd.tabs if t["kind"] == "private"}
    return {"public_tables": len(t1), "rebuildable_from_public_data_and_b": True,
            "tables_moved_by_flipping_b": moved,
            "hidden_witnesses_tried": len(ovs), "margins": [o["margin"] for o in ovs],
            "public_tables_independent_of_the_hidden_witness": True,
            "margin_and_limbs_private": {"A_LIMB", "A_Y"} <= privates,
            "ok": moved == ["margin_g"] and {"A_LIMB", "A_Y"} <= privates}


# =====================================================================
#  NL-1 (S1 premises, symbolic) on the 12 classifier slots
# =====================================================================
def nl1_static(g: CL.ClassGeom, facts: dict) -> dict:
    rows, f = [], []
    for kind, n_slots in (("IN-C", 4), ("OUT-C", 8)):
        for s in range(n_slots):
            res = {}
            for mode in ("symbolic", "numeric"):
                logup = _draws(3 if kind == "IN-C" else 2, seed=97)
                fx = dict(facts, verdict=1, w_delta=[1] * g.d)
                cx = ClassCtx(g, kind, logup, [ZERO] * TT.clog2(g.d_pad) if kind == "IN-C" else None, mode, fx)
                dr = Draws(_draws(80, seed=s + 41), mode)
                sd = define(s, cx, dr)
                classes, names = {}, []
                for i, t in enumerate(sd.tabs):
                    nm = f"T{i:02d}"
                    names.append(nm)
                    if t["kind"] == "eq":
                        classes[nm] = ("eq", f"eq({t['label']})", "eq")
                    elif t["kind"] == "public":
                        rb = rebuild_public_c(t["desc"], cx)
                        cl = table_class_c(t["desc"])
                        if rb is not None and len(set(rb)) == 1:
                            cl = "constant-MLE"
                        classes[nm] = ("public", describe_c(t["desc"]), cl)
                    else:
                        classes[nm] = ("private", t["plane"], "private")
                Pexp = Poly._co(sd.poly([Poly.var(n) for n in names]))
                res[mode] = TT._analyze(Pexp, classes)
            sp = cx.lay.slots[s]
            ok = (res["symbolic"]["public_factor_in_every_monomial"] and res["numeric"]["public_factor_in_every_monomial"]
                  and max(res["symbolic"]["max_table_degree"], res["numeric"]["max_table_degree"]) <= sp.degree)
            rows.append({"stage": kind, "slot": s, "name": sp.name, "declared_degree": sp.degree,
                         "max_table_degree": max(res["symbolic"]["max_table_degree"], res["numeric"]["max_table_degree"]),
                         "public_factor_in_every_monomial": res["symbolic"]["public_factor_in_every_monomial"]
                         and res["numeric"]["public_factor_in_every_monomial"],
                         "monomials_without_public_factor": res["symbolic"]["monomials_without_public_factor"][:4],
                         "premises_hold": ok})
            if not ok:
                f.append(f"{kind}-{s:02d}: S1 premise fails")
    return {"slots": rows, "slots_checked": len(rows), "slots_with_premises": sum(r["premises_hold"] for r in rows),
            "findings": f, "ok": not f and len(rows) == 12}


# =====================================================================
#  the controls on synthetic witnesses
# =====================================================================
def synthetic_suite(g: CL.ClassGeom = None, facts: dict = None, seed: int = 3) -> dict:
    g = g or CL.ClassGeom(**CL.RUNG_RC1)
    facts = dict(facts or FACTS_RUNG)
    rng = random.Random(seed)
    w = [rng.randrange(-32767, 32768) for _ in range(g.d)]
    x_rows = [[rng.randrange(-3000, 3001) for _ in range(g.d)] for _ in range(6)]
    ovs = [out_values(g, facts, x, w) for x in x_rows]
    out = {"what": __doc__.strip().splitlines()[0], "geometry": g.name, "privacy_acceptance": False,
           "honest": [], "controls": [], "findings": []}
    # honest: verdict 0 and 1 (c placed between two observed margins) and the tie
    ms = sorted(o["margin"] for o in ovs)
    c_mid = ms[2]
    facts_c = dict(facts, c=c_mid)
    honest = []
    for o in ovs:
        o2 = dict(o, verdict=int(o["margin"] > c_mid))
        r = out_c_relations(g, facts_c, o2, w)
        honest.append({"margin": o["margin"], "c": c_mid, "verdict": o2["verdict"], "tie": o["margin"] == c_mid,
                       "MRG_H": r["MRG_H_holds"], "ZC_H": r["ZC_H_holds"], "LU_H": r["LU_H_holds"]})
    out["honest"] = honest
    verdicts = {h["verdict"] for h in honest}
    ok_h = all(h["MRG_H"] and h["ZC_H"] and h["LU_H"] for h in honest) and verdicts == {0, 1} and any(h["tie"] for h in honest)
    if not ok_h:
        out["findings"].append("an honest witness fails a relation, or verdicts 0 / 1 / the tie are not all covered")
    o1 = next(dict(o, verdict=int(o["margin"] > c_mid)) for o in ovs if o["margin"] > c_mid)

    def ctrl(name, what, predicted, r, extra=None):
        got = {"MRG_H": r.get("MRG_H_holds"), "ZC_H": r.get("ZC_H_holds"), "LU_H": r.get("LU_H_holds")}
        fires = all(got[kk] == vv for kk, vv in predicted.items())
        out["controls"].append({"control": name, "what": what, "predicted": predicted, "got": got,
                                "fires_as_predicted": fires, **(extra or {})})
    # MC-1 flipped verdict, limbs unchanged
    lam = _bytes(delta_of(o1["margin"], c_mid, 1), g.limbs)
    ctrl("MC-1", "verdict flipped 1 -> 0, the honest limbs kept", {"MRG_H": False},
         out_c_relations(g, facts_c, o1, w, verdict=0, limbs_override=lam))
    # MC-2 flipped verdict, limbs from delta' = -delta - 1 (as field elements)
    d2 = delta_of(o1["margin"], c_mid, 0)            # negative
    lam2 = [((d2 >> (8 * kk)) & 0xFF) if kk < g.limbs - 1 else (d2 >> (8 * kk)) for kk in range(g.limbs)]
    ctrl("MC-2", "verdict flipped 1 -> 0, limbs re-made from delta' = -delta - 1 (the top limb negative)",
         {"MRG_H": True, "LU_H": False}, out_c_relations(g, facts_c, o1, w, verdict=0, limbs_override=lam2),
         {"delta_prime": d2})
    # MC-3 a limb raised by 256 with a carry kept
    lam3 = list(lam)
    lam3[0] += 256
    lam3[1] -= 1
    if lam3[1] < 0:
        lam3 = list(lam)
        lam3[1] += 256
        lam3[2] -= 1
    ctrl("MC-3", "a margin limb raised by 256, the next lowered by 1 (delta kept)", {"MRG_H": True, "LU_H": False},
         out_c_relations(g, facts_c, o1, w, limbs_override=lam3))
    # MC-4 a nonzero pad entry of the limb plane
    ctrl("MC-4", f"limb-plane entry {CL.LAM_BASE + g.limbs} (a pad) set to 1", {"ZC_H": False},
         out_c_relations(g, facts_c, o1, w, pad_entry=CL.LAM_BASE + g.limbs))
    # MC-5 the port's c + 1
    ctrl("MC-5", "the port's threshold c + 1 (the host constant b + c moved)", {"MRG_H": False},
         out_c_relations(g, facts_c, o1, w, c_port=c_mid + 1))
    # MC-6 the margin vector negated with a self-made digest (B-3)
    wd, wn = w_digest(g.d, w), w_digest(g.d, [-x for x in w])
    out["controls"].append({"control": "MC-6", "what": "the margin vector negated, its own digest computed: the door "
                            "compares the statement's / export's digest with the table's", "predicted": {"digest_equal": False},
                            "got": {"digest_equal": wd == wn}, "fires_as_predicted": wd != wn,
                            "note": "with -w and verdict 1 - b every relation holds (design §4.2): only the "
                                    "verifier's own derivation of w refuses it"})
    # MC-7 the header without classify-verdict
    labels = ["run-shape", "expected-IO", "public-statement", "parameters", "calibration", "schedule",
              "classify-verdict", "classify-chunk"]
    h_ok, h_bad = header_tail_check(labels), header_tail_check([x for x in labels if x != "classify-verdict"])
    out["controls"].append({"control": "MC-7", "what": "the run header without `classify-verdict`",
                            "predicted": {"honest_ok": True, "perturbed_ok": False},
                            "got": {"honest_ok": h_ok["ok"], "perturbed_ok": h_bad["ok"]},
                            "fires_as_predicted": h_ok["ok"] and not h_bad["ok"]})
    # IN-C: honest, IC-1, IC-3, IC-4, IC-2
    content = [rng.randrange(facts["num_special"], g.v) for _ in range(g.n)]
    toks = list(facts["prefix"]) + content + list(facts["suffix"])
    r_in, *_ = in_c_relations(g, facts, toks)
    out["honest_in_c"] = {"ZC_H": r_in["ZC_H_holds"], "LU_H": r_in["LU_H_holds"]}
    if not (r_in["ZC_H_holds"] and r_in["LU_H_holds"]):
        out["findings"].append("the honest IN-C witness fails a relation")
    t1 = list(toks)
    t1[2] = t1[2] + 1 if t1[2] + 1 < g.v else t1[2] - 1
    r1, *_ = in_c_relations(g, facts, t1)
    ctrl("IC-1", "one template id changed (position 2)", {"ZC_H": False}, r1)
    t3 = list(toks)
    t3[g.p0 + 1] = 2                                   # a control id at a content position
    r3, *_ = in_c_relations(g, facts, t3)
    ctrl("IC-3", "a control id (2 < num_special) at a content position", {"LU_H": False}, r3)
    tmpl_ctl = [t for t in range(g.tokens) if g.is_template(t) and toks[t] < facts["num_special"]]
    r4, *_ = in_c_relations(g, facts, toks)
    ctrl("IC-4", f"the template's own control ids (positions {tmpl_ctl}) match their entries", {"LU_H": True, "ZC_H": True}, r4)
    ic2 = ic2_shared_coefficient(g, facts, content)
    out["controls"].append({"control": "IC-2", "what": "a wrong template id with a compensating query helper: passes a "
                            "SHARED template coefficient, refused by R-C1's fresh mu2", "predicted": {"fires": True},
                            "got": ic2, "fires_as_predicted": ic2["fires"]})
    ob = one_bit_check(g, facts, w, x_rows)
    out["one_bit"] = ob
    if not ob["ok"]:
        out["findings"].append(f"one-public-bit expectation: {ob}")
    # the plane index: v19's re-derived OUT-C table against itself (equal) and
    # against v18's token stage OUT layout (refused by name: failing first)
    pi_c = plane_index_c(g, "OUT-C")
    tg = CL.TIO.TokenGeom(name="v18 token geometry at the rung", tokens=g.tokens, t_pad=g.t_pad, d=g.d,
                          d_pad=g.d_pad, v=g.v, block_log_n=g.block_log_n, block_inv_rate=g.block_inv_rate)
    v18_findings = CL.TIO.cross_check_plane_index(tg, "OUT", pi_c)
    v19_findings = cross_check_plane_index_c(g, "OUT-C", pi_c)
    out["controls"].append({"control": "PI-1", "what": "the classifier OUT-C plane table read by v18's token stage-OUT "
                            "geometry (refused by name) and by v19's (equal)",
                            "predicted": {"v18_refuses": True, "v19_equal": True},
                            "got": {"v18_refuses": bool(v18_findings), "v19_equal": not v19_findings,
                                    "v18_findings": v18_findings[:4]},
                            "fires_as_predicted": bool(v18_findings) and not v19_findings})
    nl = nl1_static(g, facts)
    out["nl1_static"] = {"slots_checked": nl["slots_checked"], "slots_with_premises": nl["slots_with_premises"],
                         "findings": nl["findings"]}
    out["fired"] = sum(1 for c in out["controls"] if c["fires_as_predicted"])
    out["of"] = len(out["controls"])
    out["ok"] = ok_h and out["honest_in_c"]["ZC_H"] and out["honest_in_c"]["LU_H"] and out["fired"] == out["of"] and nl["ok"]
    return out


# =====================================================================
#  on a capture (v20, gate round 17): schema 7-classify-run
# =====================================================================
SCHEMA_7 = "hashline-native-capture/7-classify-run"


def facts_from_bundle(b) -> dict:
    """The public statement facts a classifier slot closure reads, from the
    capture's `classify` member and its boundary facts (the run schedule's
    IO rows: B_in site 0, B_out site 1, the endpoint's pair after its data
    row; `stage_in_c.rs:423`, `stage_out_c.rs:681`)"""
    cf = b.run["classify"]
    tb = b.run["token_boundaries"]
    out = {"bos": cf["bos"], "final_norm": dict(cf["final_norm"]),
           "prefix": list(cf["policy"]["prefix_ids"]), "suffix": list(cf["policy"]["suffix_ids"]),
           "num_special": cf["policy"]["num_special"], "c": cf["policy"]["c"], "verdict": cf["verdict"],
           "w_delta": None, "b_in_row": tb[0]["facts"]["site_rows"][0],
           "b_out_row": tb[b.l]["facts"]["site_rows"][2], "ep_mask_row": cf["input_endpoint"]["data_rows"]}
    # [v21, R-C3] the content length n (public: D45(1)), the policy's pad id
    # and the verdict row, from the absorbed profile text, each RE-DERIVED from
    # (T, P0, n, S) and compared (`zk60_native_rg_classgate.class_integrity`)
    import zk60_native_rg_classtied as TD
    pf = TD.profile_fields(cf.get("profile_text", ""))
    out["n"] = cf["n"]
    out["pad"] = pf["pad_id"] if pf["pad_id"] is not None else 0
    out["verdict_row"] = cf["P0"] + cf["n"] + cf["S"] - 1
    # [v21, R-C2] B-3: the tables DERIVED from the pinned tensor (the margin row
    # and the embedding), when the profile names the development rung's source
    if pf["tied_source_sentence_is_the_dev_rung"] and pf["margin_scale"] is not None:
        try:
            dv = TD.derive_dev(cf["policy"]["yes"], cf["policy"]["no"], pf["margin_scale"])
            out["w_delta"], out["emb"] = list(dv["w"]), dv["emb"]
        except ValueError:
            pass
    return out


def _int16_of(v):
    x = v[0]
    if v[1] != 0:
        raise ValueError("a margin-vector entry is not in the base field")
    return x if x <= 32767 else x - P


def check_captured_structure_c(label, vals, cx: ClassCtx, b) -> list:
    """the structure each TAKEN classifier table's builder gives it"""
    out = []
    if label == "tau_tab_c":
        # [v21] reached only when tau could not be rebuilt (no derived embedding)
        # stage_in_c.rs:158-162: padded rows repeat row 0's whole tuple
        n = 1 << cx.geom.voc_log()
        if len(vals) != n:
            return [f"tau_tab_c: {len(vals)} entries, not 2^voc_log = {n}"]
        bad = [z for z in range(cx.v, n) if vals[z] != vals[0]]
        if bad:
            out.append(f"tau_tab_c: {len(bad)} padded rows differ from row 0 (first {bad[0]})")
    elif label == "w_delta":
        out += b3_margin_vector(vals, cx, b)["findings"]
    else:
        out.append(f"{label}: no structure check declared")
    return out


def b3_margin_vector(vals, cx: ClassCtx, b) -> dict:
    """B-3 on a capture: the PD slot's recorded margin vector, as int16 words
    in [-32767, 32767] with zero padding, hashes (classify.rs:323-331) to the
    statement's `margin_vector.digest`; [v21, R-C2] AND equals, entry for
    entry, the row DERIVED from the pinned tied tensor
    (`zk60_native_rg_classtied.derived_tables_check`), whose digest and the
    derived embedding's must be the statement's"""
    import zk60_native_rg_classtied as TD
    f = []
    try:
        words = [_int16_of(v) for v in vals]
    except ValueError as exc:
        return {"findings": [f"B-3: {exc}"], "ok": False}
    if len(words) != cx.d_pad:
        f.append(f"B-3: the margin vector has {len(words)} entries, not d_pad = {cx.d_pad}")
    if any(w != 0 for w in words[cx.d:]):
        f.append("B-3: the margin vector is nonzero on the padded columns")
    if any(not (-32767 <= w <= 32767) for w in words[:cx.d]):
        f.append("B-3: a margin-vector word outside [-32767, 32767]")
    got = w_digest(cx.d, words[:cx.d])
    want = bytes(b.run["classify"]["margin_vector"]["digest"]).hex()
    if got != want:
        f.append(f"B-3: the recorded margin vector hashes to {got[:12]}, the statement's digest is {want[:12]}")
    derived = TD.derived_tables_check(b, words_captured=words)
    f += derived["findings"]
    return {"recomputed_digest": got, "statement_digest": want, "derived": derived, "findings": f, "ok": not f}


def _structure_c(sd: SlotDef, arg, kind, slot, cx: ClassCtx, claim_counter: dict, spi) -> list:
    """`zk60_native_rg_tokenterminals._structure` for a classifier stage"""
    f = []
    lay = cx.lay
    sp = lay.slots[slot]
    want_name = (CL.INC_NAMES if kind == "IN-C" else CL.OUTC_NAMES)[slot]
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
            plane_names = [pp["name"] for pp in row["planes"]]
    want_planes = [t["plane"] for t in sd.tabs if t["kind"] == "private"]
    if plane_names is not None and plane_names != want_planes:
        f.append(f"the capture's slot plane list {plane_names} is not the port's {want_planes}")
    from zk60_native_jv_field import f2_from_list
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
            slices = [(sl["offset"], f2_from_list(sl["coefficient"])) for sl in c["slices"]]
            coords = []
            for co in c["coordinates"]:
                if "rho" in co:
                    coords.append(("rho", co["rho"]))
                elif "fixed" in co:
                    coords.append(("fixed", f2_from_list(co["fixed"])))
                else:
                    coords.append(("flip", co["flip"]))
            want_coords = [(a, tuple(bb) if isinstance(bb, (list, tuple)) else bb) for a, bb in t["coords"]]
            checks = {"role": c["role"] == role,
                      "slices": slices == [(o, tuple(cf)) for o, cf in t["slices"]],
                      "log_size": c["log_size"] == t["log"], "mask_row": c["mask_row"] == t["mask_row"],
                      "extension_round": c["extension_round"] == 0, "coordinates": coords == want_coords,
                      "claim_index": c["claim"] == ci}
            bad = [nm for nm, ok in checks.items() if not ok]
            if bad:
                f.append(f"table {i} ({t['plane']}): {', '.join(bad)} differ from the port")
    return f


def check_classify_terminals(bundle, replay=None, *, stage_docs=None, terminal_delta=None, table_delta=None,
                             facts_override=None, check_digests=True, expansion_cross_check=True) -> dict:
    """The per-slot terminal identity of the 12 classifier slots on a CAPTURE:
    `fin == c * mask_eval + poly(vals)` (token_io.rs:974-992, the shared stage
    slot runner), the polynomial transcribed from `define` (stage_in_c.rs /
    stage_out_c.rs), evaluated on the recorded terminals, the public tables
    at rho and the RE-DERIVED definition challenges; compared with the
    capture's terminal polynomial and with fin recomputed from the rounds.
    Every public table is REBUILT from public data and the verdict and its
    digest compared (the one-public-bit check), except tau (structure) and
    the margin vector (B-3).  Controls (in memory): `stage_docs`,
    `terminal_delta {(kind, slot): (i, delta)}`, `table_delta {(kind, slot):
    (table, entry, delta)}`, `facts_override` (the statement facts the port
    reads, e.g. the verdict or c)."""
    import time
    from zk60_native_jv_cfs import sumcheck_final
    from zk60_native_jv_field import eq_table_msb, f2_from_list
    from zk60_native_rg_terminals import eq_point, table_digest
    import zk60_native_rg_classpins as CP
    terminal_delta, table_delta = terminal_delta or {}, table_delta or {}
    t0 = time.time()
    schema = (getattr(bundle, "manifest", {}) or {}).get("schema")
    out = {"what": "per classifier slot: fin == c*mask_eval + poly(vals); the polynomial transcribed from "
                   "stage_in_c.rs / stage_out_c.rs define; every public table rebuilt from public data and "
                   "the verdict (tau structure-checked, w_Delta digest-checked: B-3)",
           "bundle": getattr(bundle, "name", None), "slots": [], "findings": [], "slots_checked": 0,
           "slots_equal": 0, "public_tables_rebuilt": 0, "public_tables_taken": 0, "seconds": 0.0}
    if schema != SCHEMA_7:
        out.update({"ok": False, "checked": False,
                    "refused": f"not a classifier capture (schema {schema!r})"})
        return out
    pins = CP.classify_capture_pins(bundle.manifest)
    out["source_pins"] = {k: pins[k] for k in ("pins", "refusals", "ok")}
    if not pins["ok"]:
        out["findings"].append("source pins without a reading; no slot evaluated")
        out["ok"] = False
        return out
    out["challenges_from"] = "transcript replay" if replay is not None else "the capture"
    out["replay_ok"] = None if replay is None else replay.summary()["ok"]
    facts = facts_from_bundle(bundle)
    if facts_override:
        facts.update(facts_override)
    out["statement_facts_read"] = {k: v for k, v in facts.items() if k not in ("w_delta", "emb")}
    out["statement_facts_read"]["tables_derived_from_the_pinned_tensor"] = facts.get("emb") is not None
    g = bundle.geom
    docs = stage_docs if stage_docs is not None else [st.doc for st in bundle.stages]
    b3 = None
    for st in (bundle.stages[0], bundle.stages[-1]):
        kind = st.kind
        doc = docs[st.index]
        logup, r_emb, dcf, rhof, ccf = TT._new_stage_challenges(bundle, replay, st, doc)
        claim_counter = {}
        spi = doc.get("stage_plane_index") or {}
        scalars = {a["slot"]: f2_from_list(a["scalar"]) for a in doc["arguments"]}
        n_slots = 4 if kind == "IN-C" else 8
        if len(doc["arguments"]) != n_slots:
            out["findings"].append(f"stage {kind}: {len(doc['arguments'])} slots, the port has {n_slots}")
        for sl in range(n_slots):
            arg = doc["arguments"][sl]
            row = {"stage": kind, "stage_index": st.index, "slot": sl, "name": arg.get("name"), "equal": False}
            try:
                cx = ClassCtx(g, kind, logup, r_emb, "numeric", facts)
                dr = Draws(dcf(sl), "numeric")
                sd = define(sl, cx, dr)
                pf = []
                if dr.pos != len(dr.num):
                    pf.append(f"the port draws {dr.pos} definition challenges, the slot carries {len(dr.num)}")
                if dr.zero:
                    pf.append(f"a zero batching challenge in {dr.zero}")
                st_f = _structure_c(sd, arg, kind, sl, cx, claim_counter, spi)
                rho_full = rhof(sl)
                main = arg["main"]
                if len(rho_full) != main + arg["extension"]:
                    pf.append(f"{len(rho_full)} sumcheck challenges for main + ext = {main + arg['extension']}")
                sel = TT._sel(rho_full, main)
                rho_main = rho_full[:main]
                eqt = None
                vals, pub_rows = [], []
                terms = [f2_from_list(x) for x in arg["terminals"]]
                td = terminal_delta.get((kind, sl))
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
                        capv = TT.captured_values(cap)
                        tdl = table_delta.get((kind, sl))
                        if capv is not None and tdl is not None and tdl[0] == i:
                            capv = list(capv)
                            capv[tdl[1]] = add(capv[tdl[1]], tdl[2])
                        prow = {"table": i, "what": describe_c(desc), "len": cap["len"], "class": table_class_c(desc)}
                        if capv is None:
                            raise ValueError(f"public table {i} ({describe_c(desc)}): the capture carries no values")
                        if len(capv) != cap["len"]:
                            raise ValueError(f"public table {i}: {len(capv)} values for len {cap['len']}")
                        prow["captured_values_match_own_digest"] = table_digest(capv) == cap["sha256"]
                        ev_cap = TT.mle(capv, eqt)
                        rb = rebuild_public_c(desc, cx)
                        if rb is not None:
                            prow["rebuilt"] = True
                            prow["rebuilt_digest_matches_capture"] = table_digest(rb) == cap["sha256"]
                            ev_rb = TT.mle(rb, eqt)
                            prow["evaluations_agree"] = ev_rb == ev_cap
                            use = ev_rb
                            # [v21] B-3 on the recorded margin vector, now that it is rebuilt
                            if desc[0] == "w_delta":
                                b3 = b3_margin_vector(capv, cx, bundle)
                                if not b3["ok"]:
                                    pf += b3["findings"]
                            if desc[0] == "captured":
                                prow["rebuilt_from"] = "the embedding derived from the pinned tied tensor (B-3, v21)"
                        else:
                            prow["rebuilt"] = False
                            label = desc[1] if desc[0] == "captured" else desc[0]
                            sf = check_captured_structure_c(label, capv, cx, bundle)
                            prow["structure_findings"] = sf
                            prow["evaluations_agree"] = None
                            if label == "w_delta":
                                b3 = b3_margin_vector(capv, cx, bundle)
                            use = ev_cap
                        ok_dig = prow["captured_values_match_own_digest"] and prow.get("rebuilt_digest_matches_capture", True)
                        if check_digests and not ok_dig:
                            pf.append(f"public table {i} ({describe_c(desc)}): digest mismatch")
                        if prow["evaluations_agree"] is False:
                            pf.append(f"public table {i} ({describe_c(desc)}): the captured values' evaluation "
                                      "differs from the rebuilt table's")
                        if prow.get("structure_findings"):
                            pf += prow["structure_findings"]
                        vals.append(F2(mul(sel, use)))
                        pub_rows.append(prow)
                    else:
                        if kk >= len(terms):
                            raise ValueError("the port has more private tables than the slot has terminals")
                        vals.append(F2(terms[kk]))
                        kk += 1
                if kk != len(terms):
                    pf.append(f"{kk} private tables for {len(terms)} terminals")
                poly = sd.poly(vals).v
                tp = f2_from_list(arg["terminal_polynomial"])
                claimed = scalars[sl]
                cap_h = [(h["slot"], f2_from_list(h["coefficient"])) for h in arg["hosted"]]
                if [(hs, tuple(cf)) for hs, cf in sd.hosted] != cap_h:
                    pf.append(f"hosted {cap_h} is not the port's {sd.hosted}")
                for hs, coef in sd.hosted:
                    claimed = add(claimed, mul(coef, scalars[hs]))
                claimed_ok = claimed == f2_from_list(arg["claimed_sum"])
                fin, consistent = sumcheck_final(arg["rounds"], arg["degree"], rho_full, claimed)
                fin_ok = fin is not None and fin == f2_from_list(arg["sumcheck_final"])
                c = ccf(sl)
                me = f2_from_list(arg["mask_eval"])
                identity = fin is not None and fin == add(mul(c, me), poly)
                matches_tp = poly == tp
                exp_ok = None
                if expansion_cross_check:
                    cxe = ClassCtx(g, kind, logup, r_emb, "numeric", facts)
                    sde = define(sl, cxe, Draws(dcf(sl), "numeric"))
                    names = [f"T{i:02d}" for i in range(len(sde.tabs))]
                    pe = Poly._co(sde.poly([Poly.var(nm) for nm in names]))
                    exp_ok = pe.evaluate({nm: x.v for nm, x in zip(names, vals)}) == poly
                row.update({"parts": sd.parts,
                            "counts": {"tables": len(sd.tabs), "private": sum(t["kind"] == "private" for t in sd.tabs),
                                       "public": sum(t["kind"] == "public" for t in sd.tabs),
                                       "definition_draws": len(dr.num), "draw_layout": dr.labels},
                            "public_tables": pub_rows, "structure_findings": st_f, "findings": pf,
                            "a_poly_equals_terminal_polynomial": matches_tp, "b_claimed_sum_recomputed": claimed_ok,
                            "c_round_consistency": consistent, "c_fin_recomputed_equals_capture": fin_ok,
                            "c_identity_fin_eq_c_mask_eval_plus_poly": identity, "expansion_reproduces_poly": exp_ok})
                row["equal"] = bool(matches_tp and identity and claimed_ok and consistent and fin_ok
                                    and not st_f and not pf and exp_ok is not False)
                if not row["equal"]:
                    why = [w for w, ok in (("poly != terminal_polynomial", matches_tp), ("fin != c*mask_eval + poly", identity),
                                           ("claimed_sum differs", claimed_ok), ("round consistency fails", consistent),
                                           ("fin differs from the capture", fin_ok)) if not ok]
                    out["findings"].append(f"{kind}-{sl:02d}: " + "; ".join(why + st_f + pf))
            except (ValueError, IndexError, KeyError) as exc:
                row["error"] = str(exc)
                out["findings"].append(f"{kind}-{sl:02d}: refused: {exc}")
            out["slots"].append(row)
    n = len(out["slots"])
    out["slots_checked"] = n
    out["slots_equal"] = sum(1 for r in out["slots"] if r["equal"])
    out["public_tables_rebuilt"] = sum(1 for r in out["slots"] for pp in r.get("public_tables", []) if pp.get("rebuilt"))
    out["public_tables_taken"] = sum(1 for r in out["slots"] for pp in r.get("public_tables", []) if pp.get("rebuilt") is False)
    out["B3_margin_vector"] = b3 or {"ok": False, "findings": ["B-3: no margin-vector table read"]}
    out["one_public_bit"] = {
        "rebuilt_public_tables_all_equal_the_capture": all(
            pp.get("rebuilt_digest_matches_capture") for r in out["slots"] for pp in r.get("public_tables", [])
            if pp.get("rebuilt")),
        "taken_tables": sorted({pp["what"] for r in out["slots"] for pp in r.get("public_tables", []) if pp.get("rebuilt") is False}),
        "what": "every IN-C / OUT-C public table the port rebuilds from the geometry, the profile, the re-derived "
                "challenges and the PUBLIC verdict equals the capture's, digest for digest; [v21] tau and w_Delta "
                "are REBUILT too, from the tables derived from the pinned tied tensor (B-3), so no table is "
                "taken from the capture when the profile names the development rung's source. So no public "
                "value of the classifier stages depends on the hidden data except through b (and, D45(1), the "
                "public length n through the template tables and the verdict row)"}
    out["seconds"] = round(time.time() - t0, 2)
    out["ok"] = (out["slots_equal"] == n == 12 and not out["findings"] and out["B3_margin_vector"]["ok"]
                 and out["one_public_bit"]["rebuilt_public_tables_all_equal_the_capture"]
                 and (replay is None or out["replay_ok"]))
    return out


def nl1_classify_slots(bundle, replay=None) -> dict:
    """NL-1's S1 premises on the 12 classifier slots of a CAPTURE: the
    symbolic expansion (challenges as symbols, and at the run's values) has a
    public factor in every monomial and a product degree within the
    declared one, and the port's private tables equal the recorded
    terminals and the schedule's sites"""
    import time
    from zk60_native_jv_field import f2_from_list  # noqa: F401
    t0 = time.time()
    rows, f = [], []
    facts = facts_from_bundle(bundle)
    g = bundle.geom
    for st in (bundle.stages[0], bundle.stages[-1]):
        kind = st.kind
        logup, r_emb, dcf, _r, _c = TT._new_stage_challenges(bundle, replay, st, st.doc)
        for sl in range(4 if kind == "IN-C" else 8):
            arg = st.doc["arguments"][sl]
            res = {}
            for mode in ("symbolic", "numeric"):
                cx = ClassCtx(g, kind, logup, r_emb, mode, facts)
                sd = define(sl, cx, Draws(dcf(sl), mode))
                classes, names = {}, []
                for i, t in enumerate(sd.tabs):
                    nm = f"T{i:02d}"
                    names.append(nm)
                    if t["kind"] == "eq":
                        classes[nm] = ("eq", f"eq({t['label']})", "eq")
                    elif t["kind"] == "public":
                        rb = rebuild_public_c(t["desc"], cx) if mode == "numeric" else None
                        cl = table_class_c(t["desc"])
                        if rb is not None and len(set(rb)) == 1:
                            cl = "constant-MLE"
                        classes[nm] = ("public", describe_c(t["desc"]), cl)
                    else:
                        classes[nm] = ("private", t["plane"], "private")
                res[mode] = TT._analyze(Poly._co(sd.poly([Poly.var(n) for n in names])), classes)
                res[mode]["n_private"] = sum(1 for c in classes.values() if c[0] == "private")
            sp = cx.lay.slots[sl]
            n_priv = res["symbolic"]["n_private"]
            ext_ok = arg["extension"] == 1 and all(t.get("extension_round", 0) == 0 for t in arg["tables"] if t["kind"] == "private")
            row = {"stage": kind, "slot": sl, "name": arg["name"], "declared_degree": arg["degree"],
                   "public_factor_in_every_monomial": res["symbolic"]["public_factor_in_every_monomial"]
                   and res["numeric"]["public_factor_in_every_monomial"],
                   "max_table_degree": max(res["symbolic"]["max_table_degree"], res["numeric"]["max_table_degree"]),
                   "private_terminals_port": n_priv, "terminals_recorded": len(arg["terminals"]),
                   "schedule_sites": sp.a_sites + sp.h_sites + sp.io_sites,
                   "one_extension_round_all_private_in_round_0": ext_ok}
            row["degree_fits"] = row["max_table_degree"] <= arg["degree"]
            row["terminal_count_ok"] = n_priv == len(arg["terminals"]) == row["schedule_sites"]
            row["premises_hold"] = (row["public_factor_in_every_monomial"] and row["degree_fits"]
                                    and row["terminal_count_ok"] and ext_ok)
            if not row["premises_hold"]:
                f.append(f"{kind}-{sl:02d}: S1 premises fail")
            rows.append(row)
    return {"slots": rows, "slots_checked": len(rows), "slots_with_premises": sum(r["premises_hold"] for r in rows),
            "findings": f, "seconds": round(time.time() - t0, 2), "ok": not f and len(rows) == 12}


def main(argv):
    r = synthetic_suite()
    s = json.dumps(r, indent=1, default=str)
    if len(argv) > 1:
        with open(argv[1], "w") as fh:
            fh.write(s + "\n")
    print(f"honest OUT-C: {[(h['verdict'], h['tie'], h['MRG_H'], h['ZC_H'], h['LU_H']) for h in r['honest']]}")
    print(f"honest IN-C: {r['honest_in_c']}")
    for c in r["controls"]:
        print(f"  {c['control']}: fires as predicted {c['fires_as_predicted']}  got {c['got'] if c['control'] != 'IC-2' else c['got']['fires']}")
    print(f"NL-1 static: {r['nl1_static']}")
    print(f"ok={r['ok']}  controls {r['fired']}/{r['of']}  findings {r['findings']}")
    return 0 if r["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

#!/usr/bin/env python3
"""THE SLOT EXPRESSION IR INVENTORY — the counting evidence behind
`docs/zkmatrix-poc/ZK60_SLOT_EXPRESSION_IR_DESIGN.md`.

WHAT THIS IS.  The private block's argument is twenty-three "slots", each one
a masked sumcheck over a list of tables whose round polynomial is a Rust
CLOSURE (`argument.rs`, `Poly = Box<dyn Fn(&[Fp2]) -> Fp2>`).  This script
writes each slot's polynomial down as DATA — a small expression graph of
products of table references with coefficients — and counts what that form
costs against what the closure costs.

WHAT IS EXTRACTED AND WHAT IS HAND-WRITTEN.  Three things are read straight
out of the Rust source text and are marked `[extracted]` in the output:

  * the builder-call sequence of every slot arm of `argument::define`
    (`b.eq`, `b.public`, `b.a`, `b.a_at`, `b.a_slice`, `b.a_range`, `b.h`,
    `b.endpoint`, `b.supp`, `b.group_eq`), in source order;
  * the number of `.mul(` tokens inside each slot's closure body;
  * the challenge draws (`tr.challenge_fp2*`) of each arm.

Everything else — the per-shape table list, the expression graph, and the
loop trip counts that turn a `.mul(` TOKEN count into a per-evaluation
multiplication count — is HAND-TRANSCRIBED from the same source and is marked
`[hand]`.  Three cross-checks are run over the hand rows:

  1. the token identity: for every slot,
     dynamic muls = static tokens + the slot's declared adjustments
     (named local closures called n times, loop bodies, `helper_sum`,
     `limbs`, `PadTerm::eval`), each adjustment printed;
  2. the MEASURED base-field census of the lane ledger (stage 29 task 4): the
     table COUNT per slot at the 125M shape and at rung-K4, and the split
     into wholly-base-field and extension tables, must equal what this model
     builds;
  3. the lane's own Python layout model
     (`scripts/zk60_private_block_layout_model.py` in the lane worktree):
     main rounds, extension rounds and declared degree per slot per shape.

NO TIME PREDICTION IS PRODUCED OR IMPLIED.  Every figure is a count of field
multiplications, words or bytes.

Cost unit: ONE BASE-FIELD (Fp) MULTIPLICATION.  From `zkp-core/src/field.rs`
`Fp2::mul` is five Fp muls (ac, bd, ad, bc and the non-residue fold),
`Fp2::mul_base` is two, and a product of two base-field values is one.

Usage:  python3 slot_ir_inventory.py [--lane <worktree>] [--json <path>]
                                     [--shapes a,b,c]
"""

from __future__ import annotations

import argparse
import json
import math
import os
import re
import sys

# ---------------------------------------------------------------- field cost

MUL_EXT_EXT = 5   # Fp2::mul
MUL_EXT_BASE = 2  # Fp2::mul_base
MUL_BASE_BASE = 1

BASE, EXT = "base", "ext"


def mulcost(a: str, b: str) -> int:
    if a == BASE and b == BASE:
        return MUL_BASE_BASE
    if a == EXT and b == EXT:
        return MUL_EXT_EXT
    return MUL_EXT_BASE


def combine(a: str, b: str) -> str:
    return BASE if (a == BASE and b == BASE) else EXT


# ---------------------------------------------------------------- the shape
# Transcribed from hashline/src/private_block/shape.rs and layout.rs at
# 226f3b2.  [hand]

U8_LEN = 256
NORM_TN = 11
NORM_CEPS = 1
F_P = 9
INT16_MAX = 32767
LIMBS_ISQRT = 3
N_LIMBS = 3 * LIMBS_ISQRT  # 9 sub-slices per norm limb plane

ALL_DOMS = ["T", "Ht", "L", "D", "Q", "Kv", "S", "F", "Tab"]
CARRIES_H = {d: d not in ("T", "Ht") for d in ALL_DOMS}

N_SLOTS = 23
(SC_SS, SC_SSM, SC_TZC, SC_LZC, SC_RS, SC_QMM, SC_KMM, SC_VMM, SC_SCORE,
 SC_PV, SC_WO, SC_GMM, SC_UMM, SC_DMM, SC_DZC, SC_QZC, SC_KVZC, SC_SZC,
 SC_FZC, SC_TAB, SC_ZS, SC_IO_IN, SC_IO_OUT) = range(23)

SLOT_NAMES = [
    "SC_SS", "SC_SSM", "SC_TZC", "SC_LZC", "SC_RS", "SC_QMM", "SC_KMM",
    "SC_VMM", "SC_SCORE", "SC_PV", "SC_WO", "SC_GMM", "SC_UMM", "SC_DMM",
    "SC_DZC", "SC_QZC", "SC_KVZC", "SC_SZC", "SC_FZC", "SC_TAB", "SC_ZS",
    "SC_IO_IN", "SC_IO_OUT",
]
SLOT_KIND = [
    "private", "private", "host", "standalone", "private", "private",
    "private", "private", "private", "private", "private", "private",
    "private", "private", "host", "host", "host", "host", "host",
    "standalone", "standalone", "standalone", "standalone",
]
BASE_DEGREE = [3, 3, 3, 4, 3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 4, 4, 4, 4, 3, 2, 2, 2]
INDICATOR_SLOT_DOMAIN = {
    SC_SS: "D", SC_SSM: "D", SC_RS: "S", SC_DZC: "D", SC_QZC: "Q",
    SC_KVZC: "Kv", SC_SZC: "S", SC_FZC: "F",
}
BILINEAR = (SC_SCORE, SC_PV)
PAD_ZERO_HOST = {"T": SC_TZC, "Ht": SC_SZC, "L": SC_LZC, "D": SC_DZC,
                 "Q": SC_QZC, "Kv": SC_KVZC, "S": SC_SZC, "F": SC_FZC,
                 "Tab": SC_TAB}


def clog2(v: int) -> int:
    assert v > 0
    return (v - 1).bit_length()


class Shape:
    """`Shape` of shape.rs, the parts this inventory needs."""

    def __init__(self, name, tokens, width, hidden, q_heads, head_dim,
                 kv_heads, log_cols, inv_rate=4, f_e=9, frozen_toy=False):
        self.name = name
        self.tokens, self.width, self.hidden = tokens, width, hidden
        self.q_heads, self.head_dim, self.kv_heads = q_heads, head_dim, kv_heads
        self.log_cols, self.inv_rate, self.f_e = log_cols, inv_rate, f_e
        self.frozen_toy = frozen_toy
        npot = lambda v: 1 << clog2(v)
        self.t_pad, self.d_pad = npot(tokens), npot(width)
        self.h_pad, self.f_pad = npot(q_heads), npot(hidden)
        self.d_max = math.isqrt(NORM_CEPS + width * INT16_MAX ** 2)
        self.norm_wrho = NORM_TN + 1 + self.d_max.bit_length()
        self.wrho_s = clog2(tokens) + f_e

    @property
    def limbs_norm(self):
        return (self.norm_wrho + 7) // 8

    @property
    def norm_top_is_full_byte(self):
        return self.norm_wrho == 8 * self.limbs_norm

    @property
    def limbs_sigma_s(self):
        return (self.wrho_s + 7) // 8

    @property
    def limbs_p(self):
        return (F_P + 1 + 7) // 8

    @property
    def lkv(self):
        return clog2(self.kv_heads)

    def carries_pad_rule(self):
        return not self.frozen_toy

    def natural_log(self, dom):
        t, h, dh = self.t_pad, self.h_pad, self.head_dim
        return {
            "T": clog2(t), "Ht": clog2(h * t), "L": clog2(16 * t),
            "D": clog2(t * self.d_pad), "Q": clog2(t * h * dh),
            "Kv": clog2(t * self.kv_heads * dh), "S": clog2(h * t * t),
            "F": clog2(t * self.f_pad), "Tab": clog2(U8_LEN),
        }[dom]

    def true_size(self, dom):
        return {
            "T": self.tokens, "Ht": self.q_heads * self.tokens,
            "L": 3 * LIMBS_ISQRT * self.tokens,
            "D": self.tokens * self.width,
            "Q": self.tokens * self.q_heads * self.head_dim,
            "Kv": self.tokens * self.kv_heads * self.head_dim,
            "S": self.q_heads * self.tokens * self.tokens,
            "F": self.tokens * self.hidden, "Tab": U8_LEN,
        }[dom]

    def log(self, dom):
        nat = self.natural_log(dom)
        return self.log_cols if (CARRIES_H[dom] and nat < self.log_cols) else nat

    def size(self, dom):
        return 1 << self.log(dom)

    def pads(self, dom):
        return self.size(dom) != self.true_size(dom)

    def a_planes_on(self, dom):
        ln = self.limbs_norm
        return {
            "T": 4, "Ht": 2, "L": 2,
            "D": 4 + 2 * ln + 8 + 2 * ln + 7,
            "Q": 7, "Kv": 6,
            "S": 5 + self.limbs_p + 2 * self.limbs_sigma_s,
            "F": 11, "Tab": 3,
        }[dom]

    def lookups_per_position(self, dom):
        ln = self.limbs_norm
        top = 0 if self.norm_top_is_full_byte else 1
        per_norm = 2 + 2 * (ln + top)
        return {
            "L": 2, "D": 2 + per_norm + 6 + per_norm + 2 + 4, "F": 9,
            "Q": 13, "Kv": 12,
            "S": 2 + 2 + (self.limbs_p + 1) + 2 * (self.limbs_sigma_s + 1),
            "T": 0, "Ht": 0, "Tab": 0,
        }[dom]

    def helpers(self, dom):
        return -(-self.lookups_per_position(dom) // 2)

    def zero_rule_a_planes(self, dom):
        """count of ZERO-rule A planes of a domain (`pad::a_rule`): every A
        plane of a padded domain except `A_E`, which is EXEMPT."""
        if not self.carries_pad_rule() or not self.pads(dom):
            return 0
        n = self.a_planes_on(dom)
        return n - 1 if dom == "S" else n

    def pad_on(self, slot):
        """`pad_on` of `argument::define`."""
        return any(PAD_ZERO_HOST[d] == slot and self.zero_rule_a_planes(d) > 0
                   for d in ALL_DOMS)

    def slot_rounds(self, s):
        """(main rounds, extension rounds, declared degree)."""
        cube = {SC_SS: "D", SC_SSM: "D", SC_TZC: "T", SC_LZC: "L", SC_RS: "S",
                SC_DZC: "D", SC_QZC: "Q", SC_KVZC: "Kv", SC_SZC: "S",
                SC_FZC: "F", SC_TAB: "Tab", SC_ZS: "Tab", SC_IO_IN: "D",
                SC_IO_OUT: "D"}
        lkv = self.lkv
        inner = {SC_QMM: clog2(self.d_pad), SC_KMM: clog2(self.d_pad),
                 SC_VMM: clog2(self.d_pad), SC_WO: clog2(self.d_pad),
                 SC_GMM: clog2(self.d_pad), SC_UMM: clog2(self.d_pad),
                 SC_DMM: clog2(self.f_pad),
                 SC_SCORE: lkv + clog2(self.head_dim),
                 SC_PV: lkv + clog2(self.t_pad)}
        main = self.log(cube[s]) if s in cube else inner[s]
        ind = (self.carries_pad_rule() and s in INDICATOR_SLOT_DOMAIN
               and self.pads(INDICATOR_SLOT_DOMAIN[s]))
        group_eq = s in BILINEAR and lkv > 0
        ext = 2 if s in BILINEAR else 1
        deg = BASE_DEGREE[s] + int(ind) + int(group_eq)
        return main, ext, deg


SHAPES = {
    "toy": Shape("toy block (T32 / d16 / f16, 2 heads of 8 over 1 KV head)",
                 32, 16, 16, 2, 8, 1, 8, 8, 9, frozen_toy=True),
    "rung": Shape("rung (T24 / d96 / f192, 6 heads of 16 over 2 KV)",
                  24, 96, 192, 6, 16, 2, 10, 4, 12),
    "rung_g": Shape("rung-G (T24 / d96 / f192, 6 heads of 16 over 2 KV)",
                    24, 96, 192, 6, 16, 2, 10, 4, 12),
    "rung_k4": Shape("rung-K4 (T24 / d96 / f192, 12 heads of 8 over 4 KV)",
                     24, 96, 192, 12, 8, 4, 10, 4, 12),
    "rung_p2": Shape("rung-P2 (T32 / d96 / f256, 12 heads of 8 over 4 KV)",
                     32, 96, 256, 12, 8, 4, 10, 4, 12),
    "rung_c6": Shape("rung-C6 (T32 / d384 / f512, 12 heads of 32 over 4 KV)",
                     32, 384, 512, 12, 32, 4, 10, 4, 12),
    "rung_w14": Shape("rung-W14 (T64 / d768 / f1024, 12 heads of 64 over 4 KV)",
                      64, 768, 1024, 12, 64, 4, 14, 4, 12),
    "rung_e32": Shape("rung-E32 (T32 / d768 / f1024, 12 heads of 64 over 4 KV)",
                      32, 768, 1024, 12, 64, 4, 10, 4, 12),
    "m125": Shape("125M (T512 / d768 / f2048, 12 heads of 64 over 4 KV)",
                  512, 768, 2048, 12, 64, 4, 14, 4, 9),
}

# ---------------------------------------------------------------- the IR
# Table kinds.  `eq` and `group_eq` are challenge-weighted public tables,
# `pub` a shape-driven public table, `supp` the pad rule's support indicator
# (a public selector), `A` a committed witness plane (integer data lifted by
# `Fp2::from_base`, so base-field-valued), `H` a committed LogUp helper column
# (`re + u im`, an inverse — extension-valued by construction), `EP` an
# endpoint plane.


class Tab:
    __slots__ = ("label", "kind", "field")

    def __init__(self, label, kind, field):
        self.label, self.kind, self.field = label, kind, field

    def __repr__(self):
        return f"{self.label}:{self.kind}/{self.field}"


def T(label):                return Tab(label, "eq", EXT)
def GEQ(label):              return Tab(label, "group_eq", EXT)
def PUB(label, field=BASE):  return Tab(label, "pub", field)
def SUPP(label):             return Tab(label, "supp", BASE)
def A(label):                return Tab(label, "A", BASE)
def H(label):                return Tab(label, "H", EXT)
def EP(label):               return Tab(label, "EP", BASE)


class Form:
    """AFFINE node: const + sum coef * table.  Degree 1.

    `coefs` is a list of (kind, table index), kind in {"one", "kbase",
    "chal"}: `one` costs no multiplication, `kbase` is a PUBLIC BASE-FIELD
    constant (a power of 256, a fixed-point shift, a norm constant), `chal`
    a challenge or a power of one (extension)."""
    __slots__ = ("label", "coefs", "has_const")

    def __init__(self, label, coefs, has_const=True):
        self.label, self.coefs, self.has_const = label, list(coefs), has_const

    def degree(self):
        return 1


class Node:
    """SUM-OF-PRODUCTS node: sum over subterms of coef * product(factors).

    A factor is a table index, a `Form` or another `Node`.  This is the level
    the closures actually work at: a clause `c0` or a LogUp relation is
    computed WHOLE and then multiplied by its `mu` once, and the IR has to be
    able to say that or it would over-count the coefficients."""
    __slots__ = ("label", "subs")

    def __init__(self, label, subs):
        # subs: list of (coefkind, coeflabel, [factors])
        self.label, self.subs = label, [(k, l, list(f)) for k, l, f in subs]

    def degree(self):
        return max((sum(degree_of(f) for f in fs) for _, _, fs in self.subs),
                   default=0)


def degree_of(f):
    return 1 if isinstance(f, int) else f.degree()


class Term:
    """coefficient x wrapper-product x inner-product.

    `wrapper` is the leading factor tuple this term shares with its group —
    the zero-check `eq` and, where the term carries it, the pad gate.  The
    closures already hoist nothing of it: `argument.rs` writes
    `v[0].mul(zc)` once for the whole zero-check arm, and the gate `g` per
    clause."""
    __slots__ = ("coef", "coef_label", "wrapper", "inner", "note")

    def __init__(self, coef, coef_label, wrapper, inner, note=""):
        self.coef, self.coef_label = coef, coef_label
        self.wrapper, self.inner, self.note = tuple(wrapper), list(inner), note

    def degree(self):
        return len(self.wrapper) + sum(degree_of(f) for f in self.inner)


def monomials(f) -> int:
    """How many MONOMIALS the node expands to (the length of the flat product
    list a kernel would iterate if the IR were fully expanded)."""
    if isinstance(f, int):
        return 1
    if isinstance(f, Form):
        return len(f.coefs) + (1 if f.has_const else 0)
    tot = 0
    for _, _, fs in f.subs:
        p = 1
        for x in fs:
            p *= monomials(x)
        tot += p if fs else 1
    return tot


def term_monomials(t: Term) -> int:
    p = 1
    for f in t.inner:
        p *= monomials(f)
    return p if t.inner else 1


# ---------------------------------------------------------------- slot models
# Each builder returns (tables, terms, closure_adjustments).  [hand]
# `closure_adjustments` turns the EXTRACTED `.mul(` token count of the arm
# into the dynamic per-evaluation multiplication count:
#   dynamic = tokens + sum(extra), every `extra` named.


def logup_node(sh, dom, h0, planes_for_lookup):
    """The LogUp arm of a zero-check slot as IR nodes, one Term per helper.

    `helper_sum` (argument.rs) pairs lookups: helper k covers lookups 2k and
    2k+1 with relation `h*d1*d2 - (d1 + d2)`, or `h*d1 - 1` when the count is
    odd, and multiplies the WHOLE relation by `mu[k]` once.  Every lookup of
    this profile has EXACTLY ONE term (`byte` / `scaled` / `sym` in
    layout.rs), so each denominator `alpha - (cst + c*plane)` is one affine
    form with one base-field coefficient."""
    n_lk = sh.lookups_per_position(dom)
    n_help = sh.helpers(dom)
    dens = [Form(f"den_{dom}_{i}", [("kbase", planes_for_lookup(i))])
            for i in range(n_lk)]
    nodes = []
    for kk in range(n_help):
        i1, i2 = 2 * kk, 2 * kk + 1
        hk = h0 + kk
        if i2 < n_lk:
            nodes.append(Node(f"logup_{dom}_{kk}",
                              [("one", "1", [hk, dens[i1], dens[i2]]),
                               ("one", "-1", [dens[i1]]),
                               ("one", "-1", [dens[i2]])]))
        else:
            nodes.append(Node(f"logup_{dom}_{kk}",
                              [("one", "1", [hk, dens[i1]]),
                               ("one", "-1", [])]))
    return nodes


def pad_node(sh, slot, groups):
    """ruling P-1's batched pad-zero term, as ONE node:
    `sum_groups (1 - supp) * sum_j zeta^j plane_j`, the whole of it multiplied
    by `mu_pad` once (`PadTerm::eval`)."""
    subs = []
    for supp_i, planes in groups:
        if not planes:
            continue
        anti = Form(f"1 - supp[{supp_i}]", [("one", supp_i)])
        inner = Form("sum zeta^j plane_j", [("chal", p) for p in planes],
                     has_const=False)
        subs.append(("one", "1", [anti, inner]))
    return Node("pad-zero", subs) if subs else None


def build_slot(s, sh):
    """The tables and the expression graph of slot `s` at shape `sh`.  [hand]"""
    tabs, terms = [], []
    adj = []
    lkv = sh.lkv

    def push(t):
        tabs.append(t)
        return len(tabs) - 1

    # ---- 00 / 01: the two row-sum slots ------------------------------------
    if s in (SC_SS, SC_SSM):
        plane = "A_X" if s == SC_SS else "A_X1"
        eqi = push(T("eq(r_t)" if s == SC_SS else "eq(r_t2)"))
        ai = push(A(plane))
        gi = push(SUPP("supp(Dom::D)")) if (sh.carries_pad_rule() and sh.pads("D")) else None
        wrap = ([gi] if gi is not None else []) + [eqi]
        terms.append(Term("one", "1", wrap, [ai, ai], "row sum of x^2"))
        return tabs, terms, adj

    # ---- 02 SC_TZC: the norm-squares zero-check, host of 00 and 01 ---------
    if s == SC_TZC:
        i_tau, i_rt, i_rt2 = push(T("eq(tau)")), push(T("eq(r_t)")), push(T("eq(r_t2)"))
        i_d, i_dsq = push(A("A_D")), push(A("A_DSQ"))
        lim = [push(A(f"A_LIMB[{j}]")) for j in range(N_LIMBS)]
        i_dm, i_dsqm = push(A("A_DM")), push(A("A_DSQM"))
        limm = [push(A(f"A_LIMBM[{j}]")) for j in range(N_LIMBS)]
        pad = sh.pad_on(SC_TZC)
        gi = push(SUPP("supp(Dom::T)")) if (sh.carries_pad_rule() and sh.pads("T")) else None

        def l3(src, o):   # v[o] + 256 v[o+1] + 256^2 v[o+2]
            return [("one", src[o]), ("kbase", src[o + 1]), ("kbase", src[o + 2])]
        dl, a1, a2 = l3(lim, 0), l3(lim, 3), l3(lim, 6)
        dlm, a1m, a2m = l3(limm, 0), l3(limm, 3), l3(limm, 6)
        W = (i_tau,)
        zc = Node("zc(TZC)", [
            ("chal", "mu0", [Node("dsq - d^2", [("one", "1", [i_dsq]),
                                                ("one", "-1", [i_d, i_d])])]),
            ("chal", "mu1", [Form("d - dl", [("one", i_d)] + dl, has_const=False)]),
            ("chal", "mu2", [Form("2d - a1 - a2", [("one", i_d)] + a1 + a2,
                                  has_const=False)]),
            ("chal", "mu3", [Node("dsqm - dm^2", [("one", "1", [i_dsqm]),
                                                  ("one", "-1", [i_dm, i_dm])])]),
            ("chal", "mu4", [Form("dm - dlm", [("one", i_dm)] + dlm, has_const=False)]),
            ("chal", "mu5", [Form("2dm - a1m - a2m", [("one", i_dm)] + a1m + a2m,
                                  has_const=False)]),
        ])
        inner = [zc]
        if pad:
            pn = pad_node(sh, s, [(gi, [i_d, i_dsq, i_dm, i_dsqm])])
            zc.subs.append(("chal", "mu_pad", [pn]))
        terms.append(Term("one", "1", W, inner, "the zero-check arm"))
        hw = [gi] if gi is not None else []
        terms.append(Term("chal", "nu0", (i_rt, *hw),
                          [Form("dsq + a1 - ceps", [("one", i_dsq)] + a1)],
                          "host SC_SS"))
        terms.append(Term("chal", "nu1", (i_rt2, *hw),
                          [Form("dsqm + a1m - ceps", [("one", i_dsqm)] + a1m)],
                          "host SC_SSM"))
        adj.append(("`l3` is one named closure of 2 tokens, called 6x", 2 * 6 - 2))
        adj.append(("`PadTerm::eval`", pad_eval_muls(sh, s)))
        return tabs, terms, adj

    # ---- 03 SC_LZC: the limb LogUp, standalone -----------------------------
    if s == SC_LZC:
        i_tau = push(T("eq(tau)"))
        i_limb, i_limbm = push(A("A_LIMB")), push(A("A_LIMBM"))
        h0 = push(H("H_L0"))
        pad = sh.pad_on(SC_LZC)
        gi = push(SUPP("supp(Dom::L)")) if (sh.carries_pad_rule() and sh.pads("L")) else None
        W = (i_tau,)
        subs = [("chal", "mu_L", [n])
                for n in logup_node(sh, "L", h0, lambda i: [i_limb, i_limbm][i])]
        if pad:
            subs.append(("chal", "mu_pad",
                         [pad_node(sh, s, [(gi, [i_limb, i_limbm])])]))
        terms.append(Term("one", "1", W, [Node("zc(LZC)", subs)], "LogUp + pad"))
        adj.append(("`helper_sum`", helper_sum_muls(sh, "L")))
        adj.append(("`PadTerm::eval`", pad_eval_muls(sh, s)))
        return tabs, terms, adj

    # ---- 04 SC_RS: the masked row sums + selector --------------------------
    if s == SC_RS:
        i_eq = push(T("eq(p_ht)"))
        i_m = push(PUB("causal mask"))
        i_e, i_z = push(A("A_E")), push(A("A_ZSEL"))
        gi = push(SUPP("supp(Dom::S)")) if (sh.carries_pad_rule() and sh.pads("S")) else None
        W = tuple(([gi] if gi is not None else []) + [i_eq])
        terms.append(Term("one", "1", W,
                          [Node("mask*e + lam_z*zsel",
                                [("one", "1", [i_m, i_e]),
                                 ("chal", "lam_z", [i_z])])], "row sum"))
        return tabs, terms, adj

    # ---- the seven single-product matmuls ----------------------------------
    if s in (SC_QMM, SC_KMM, SC_VMM, SC_WO, SC_GMM, SC_UMM, SC_DMM):
        plane = {SC_QMM: "A_Y", SC_KMM: "A_Y", SC_VMM: "A_Y", SC_WO: "A_O8",
                 SC_GMM: "A_YM", SC_UMM: "A_YM", SC_DMM: "A_H16"}[s]
        wlab = {SC_QMM: "fold(Wq, r_j)", SC_KMM: "fold(Wk, r_j)",
                SC_VMM: "fold(Wv, r_j)", SC_WO: "fold(Wo, r_j)",
                SC_GMM: "fold(Wg, r_j)", SC_UMM: "fold(Wu, r_j)",
                SC_DMM: "fold(Wd, r_j)"}[s]
        ai, wi = push(A(plane)), push(PUB(wlab, EXT))
        terms.append(Term("one", "1", (), [ai, wi], "plane * folded weight"))
        return tabs, terms, adj

    # ---- 08 / 09 the two bilinear slots ------------------------------------
    if s in BILINEAR:
        gi = push(GEQ("eq(r_g) group gate")) if lkv > 0 else None
        p1, p2 = ("A_QR8", "A_KR8") if s == SC_SCORE else ("A_P", "A_V8")
        i1, i2 = push(A(p1)), push(A(p2))
        W = tuple([gi] if gi is not None else [])
        terms.append(Term("one", "1", W, [i1, i2], "the bilinear product"))
        return tabs, terms, adj

    # ---- 14 SC_DZC: the width zero-check -----------------------------------
    if s == SC_DZC:
        ln = sh.limbs_norm
        i_tau, i_pa, i_pz = push(T("eq(tau)")), push(T("eq(p_a)")), push(T("eq(p_z)"))
        i_ga, i_gm = push(PUB("gamma_a (padded)")), push(PUB("gamma_m (padded)"))
        names = (["A_X", "A_XL0", "A_XL1", "A_Y"]
                 + [f"A_NR{j}" for j in range(ln)] + [f"A_NS{j}" for j in range(ln)]
                 + ["A_AO", "A_AL0", "A_AL1", "A_RAL", "A_X1", "A_X1L0",
                    "A_X1L1", "A_YM"]
                 + [f"A_MR{j}" for j in range(ln)] + [f"A_MS{j}" for j in range(ln)]
                 + ["A_X2", "A_X2L0", "A_X2L1", "A_Z16", "A_ZL0", "A_ZL1",
                    "A_RDL"])
        assert len(names) == sh.a_planes_on("D")
        P = {nm: push(A(nm)) for nm in names}
        i_d, i_dm = push(A("A_D (Dom::T slice)")), push(A("A_DM (Dom::T slice)"))
        n_help = sh.helpers("D")
        h0 = push(H("H_D0"))
        for j in range(1, n_help):
            push(H(f"H_D{j}"))
        pad = sh.pad_on(SC_DZC)
        gi = push(SUPP("supp(Dom::D)")) if (sh.carries_pad_rule() and sh.pads("D")) else None

        lb = lambda pref: [("kbase", P[f"{pref}{j}"]) for j in range(ln)]
        nr, ns, mr, ms = lb("A_NR"), lb("A_NS"), lb("A_MR"), lb("A_MS")
        l2 = lambda a, b: [("one", P[a]), ("kbase", P[b])]

        c0 = Node("c0", [("kbase", "2 Cn", [i_ga, P["A_X"]]),
                         ("kbase", "-2^(tn+1)", [P["A_Y"], i_d]),
                         ("one", "1", [Form("2^tn d - nr", [("kbase", i_d)] + nr,
                                            has_const=False)])])
        c6 = Node("c6", [("kbase", "2 Cn", [i_gm, P["A_X1"]]),
                         ("kbase", "-2^(tn+1)", [P["A_YM"], i_dm]),
                         ("one", "1", [Form("2^tn dm - mr", [("kbase", i_dm)] + mr,
                                            has_const=False)])])
        clauses = [
            ("mu0", c0),
            ("mu1", Form("c1: ns + nr + 1 - 2^(tn+1) d", ns + nr + [("kbase", i_d)])),
            ("mu2", Form("c2: x + 2^15 - l2(xl)", [("one", P["A_X"])] + l2("A_XL0", "A_XL1"))),
            ("mu3", Form("c3: ao + 2^15 - l2(al)", [("one", P["A_AO"])] + l2("A_AL0", "A_AL1"))),
            ("mu4", Form("c4: x1 + 2^15 - l2(x1l)", [("one", P["A_X1"])] + l2("A_X1L0", "A_X1L1"))),
            ("mu5", Form("c5: x1 - x - ao", [("one", P["A_X1"]), ("one", P["A_X"]),
                                             ("one", P["A_AO"])], has_const=False)),
            ("mu6", c6),
            ("mu7", Form("c7: ms + mr + 1 - 2^(tn+1) dm", ms + mr + [("kbase", i_dm)])),
            ("mu8", Form("c8: x2 + 2^15 - l2(x2l)", [("one", P["A_X2"])] + l2("A_X2L0", "A_X2L1"))),
            ("mu9", Form("c9: x2 - x1 - z16", [("one", P["A_X2"]), ("one", P["A_X1"]),
                                               ("one", P["A_Z16"])], has_const=False)),
            ("mu10", Form("c10: z16 + 2^15 - l2(zl)", [("one", P["A_Z16"])] + l2("A_ZL0", "A_ZL1"))),
        ]
        # the gate multiplies the SUM of the eleven clauses, not each of them:
        # the closure writes `m.mul(g).mul(c)` inside the loop, which is one
        # multiplication by `g` per clause where the IR needs one in total
        gated = Node("the 11 clauses", [("chal", lab, [c]) for lab, c in clauses])
        subs = [("one", "1", ([gi, gated] if gi is not None else [gated]))]
        subs += [("chal", "mu_D", [n]) for n in
                 logup_node(sh, "D", h0, lambda i: dom_d_lookup_planes(sh, P)[i])]
        if pad:
            subs.append(("chal", "mu_pad",
                         [pad_node(sh, s, [(gi, [P[nm] for nm in names])])]))
        terms.append(Term("one", "1", (i_tau,), [Node("zc(DZC)", subs)],
                          "clauses + LogUp + pad"))
        hw = (gi,) if gi is not None else ()
        terms.append(Term("chal", "nu0", (i_pa, *hw),
                          [Form("host_wo: 2^7 ao + ral - 2^6",
                                [("kbase", P["A_AO"]), ("one", P["A_RAL"])])],
                          "host SC_WO"))
        terms.append(Term("chal", "nu1", (i_pz, *hw),
                          [Form("host_dmm: 2^6 z16 + rdl - 2^5",
                                [("kbase", P["A_Z16"]), ("one", P["A_RDL"])])],
                          "host SC_DMM"))
        adj.append(("`l2` is one named closure of 1 token, called 5x", 1 * 5 - 1))
        adj.append(("the 11-clause loop body (2 tokens) runs 11x", 2 * 11 - 2))
        adj.append(("`limbs()` over four limb groups", 4 * ln))
        adj.append(("`helper_sum`", helper_sum_muls(sh, "D")))
        adj.append(("`PadTerm::eval`", pad_eval_muls(sh, s)))
        return tabs, terms, adj

    # ---- 15 / 16 the two RoPE zero-checks ----------------------------------
    if s in (SC_QZC, SC_KVZC):
        q = s == SC_QZC
        dom = "Q" if q else "Kv"
        i_tau = push(T("eq(tau)"))
        i_p1 = push(T("eq(pq)" if q else "eq(pk)"))
        i_p2 = push(T("eq(p_o)" if q else "eq(pv)"))
        i_c, i_s = push(PUB("rope cos")), push(PUB("rope sin"))
        names = (["A_Q8", "A_RQL", "A_QR8", "A_RQRL", "A_O8", "A_RO0", "A_RO1"]
                 if q else
                 ["A_K8", "A_RKL", "A_V8", "A_RVL", "A_KR8", "A_RKRL"])
        assert len(names) == sh.a_planes_on(dom)
        P = {nm: push(A(nm)) for nm in names}
        src = "A_Q8" if q else "A_K8"
        i_flip = push(A(f"{src} at the flipped RoPE partner bit"))
        n_help = sh.helpers(dom)
        h0 = push(H(f"H_{dom}0"))
        for j in range(1, n_help):
            push(H(f"H_{dom}{j}"))
        pad = sh.pad_on(s)
        gi = push(SUPP(f"supp(Dom::{dom})")) if (sh.carries_pad_rule() and sh.pads(dom)) else None
        rot = "A_QR8" if q else "A_KR8"
        rem = "A_RQRL" if q else "A_RKRL"
        rope = Node("rope", [("one", "1", [i_c, P[src]]),
                             ("one", "1", [i_s, i_flip]),
                             ("one", "1", [Form("-2^7 rot - rot_rem + 2^6",
                                                [("kbase", P[rot]), ("one", P[rem])])])])
        subs = [("chal", "mu0", ([gi, rope] if gi is not None else [rope]))]
        subs += [("chal", f"mu_{dom}", [n]) for n in
                 logup_node(sh, dom, h0, lambda i: dom_qkv_lookup_planes(sh, P, q)[i])]
        if pad:
            subs.append(("chal", "mu_pad",
                         [pad_node(sh, s, [(gi, [P[nm] for nm in names])])]))
        terms.append(Term("one", "1", (i_tau,), [Node(f"zc({dom})", subs)],
                          "rope + LogUp + pad"))
        hw = (gi,) if gi is not None else ()
        if q:
            f1 = Form("host1: 2^7 q8 + rql - 2^6",
                      [("kbase", P["A_Q8"]), ("one", P["A_RQL"])])
            f2 = Form("host2: 2^9 o8 + ro0 + 256 ro1 - 2^8",
                      [("kbase", P["A_O8"]), ("one", P["A_RO0"]), ("kbase", P["A_RO1"])])
        else:
            f1 = Form("host1: 2^7 k8 + rkl - 2^6",
                      [("kbase", P["A_K8"]), ("one", P["A_RKL"])])
            f2 = Form("host2: 2^7 v8 + rvl - 2^6",
                      [("kbase", P["A_V8"]), ("one", P["A_RVL"])])
        terms.append(Term("chal", "nu0", (i_p1, *hw), [f1], "host 1"))
        terms.append(Term("chal", "nu1", (i_p2, *hw), [f2], "host 2"))
        adj.append(("the unused branch of `if q` (its tokens are counted, "
                    "not run)", -2 if q else -3))
        adj.append(("`helper_sum`", helper_sum_muls(sh, dom)))
        adj.append(("`PadTerm::eval`", pad_eval_muls(sh, s)))
        return tabs, terms, adj

    # ---- 17 SC_SZC: the softmax zero-check ---------------------------------
    if s == SC_SZC:
        ls, lp = sh.limbs_sigma_s, sh.limbs_p
        i_tau, i_pht, i_ps = push(T("eq(tau)")), push(T("eq(p_ht)")), push(T("eq(p_s)"))
        i_m = push(PUB("causal mask"))
        names = (["A_S8", "A_RSL", "A_ZSEL", "A_E", "A_P"]
                 + [f"A_PL{j}" for j in range(lp)]
                 + [f"A_SR{j}" for j in range(ls)]
                 + [f"A_SG{j}" for j in range(ls)])
        assert len(names) == sh.a_planes_on("S")
        P = {nm: push(A(nm)) for nm in names}
        i_mx, i_sum = push(A("A_MX (Dom::Ht slice)")), push(A("A_SUM (Dom::Ht slice)"))
        n_help = sh.helpers("S")
        h0 = push(H("H_S0"))
        for j in range(1, n_help):
            push(H(f"H_S{j}"))
        i_hx = push(H("H_SEXP"))
        pad = sh.pad_on(SC_SZC)
        g_ht = push(SUPP("supp(Dom::Ht), lifted")) if (sh.carries_pad_rule() and sh.pads("Ht")) else None
        g_s = push(SUPP("supp(Dom::S)")) if (sh.carries_pad_rule() and sh.pads("S")) else None
        sr = [("kbase", P[f"A_SR{j}"]) for j in range(ls)]
        sg = [("kbase", P[f"A_SG{j}"]) for j in range(ls)]
        pl = [("kbase", P[f"A_PL{j}"]) for j in range(lp)]
        f_s8 = Form("s8 + 127", [("one", P["A_S8"])])
        # delta = mx - mask*(s8+127) + 127 : degree 2, one shared node
        delta = Node("delta = max - masked score",
                     [("one", "1", [Form("mx + 127", [("one", i_mx)])]),
                      ("one", "-1", [i_m, f_s8])])
        clauses = [
            ("mu0", Node("c0: zsel^2 - zsel", [("one", "1", [P["A_ZSEL"], P["A_ZSEL"]]),
                                               ("one", "-1", [P["A_ZSEL"]])])),
            ("mu1", Node("c1: zsel * delta", [("one", "1", [P["A_ZSEL"], delta])])),
            ("mu2", Node("c2: 2^F_P mask e - p sum - sr",
                         [("kbase", "2^F_P", [i_m, P["A_E"]]),
                          ("one", "-1", [P["A_P"], i_sum]),
                          ("one", "-1", [Form("sr", sr, has_const=False)])])),
            ("mu3", Form("c3: sg + sr + 1 - sum", sg + sr + [("one", i_sum)])),
            ("mu4", Form("c4: p - pl", [("one", P["A_P"])] + pl, has_const=False)),
        ]
        gated = Node("the 5 clauses", [("chal", lab, [c]) for lab, c in clauses])
        cx = Node("cx: the exp pair (never gated)",
                  [("one", "1", [i_hx, Node("alpha - delta - beta e - g_exp",
                                            [("one", "-1", [delta]),
                                             ("chal", "-beta", [P["A_E"]]),
                                             ("one", "1", [])])]),
                   ("one", "-1", [])])
        subs = [("one", "1", ([g_s, gated] if g_s is not None else [gated])),
                ("chal", "mu_cx", [cx])]
        subs += [("chal", "mu_S", [n]) for n in
                 logup_node(sh, "S", h0, lambda i: dom_s_lookup_planes(sh, P)[i])]
        if pad:
            order_s = [P[nm] for nm in names if nm != "A_E"]
            subs.append(("chal", "mu_pad",
                         [pad_node(sh, s, [(g_ht, [i_mx, i_sum]),
                                           (g_s, order_s)])]))
        terms.append(Term("one", "1", (i_tau,), [Node("zc(SZC)", subs)],
                          "clauses + exp pair + LogUp + pad"))
        hw_s = (g_s,) if g_s is not None else ()
        hw_ht = (g_ht,) if g_ht is not None else ()
        terms.append(Term("chal", "nu0 * per_row", (i_pht, *hw_ht),
                          [Form("host_rs: sum + lam_z", [("one", i_sum)])],
                          "host SC_RS"))
        terms.append(Term("chal", "nu1", (i_ps, *hw_s),
                          [Form("host_s: 2^6 s8 + rsl - 2^5",
                                [("kbase", P["A_S8"]), ("one", P["A_RSL"])])],
                          "host SC_SCORE"))
        adj.append(("the 5-clause loop body (2 tokens) runs 5x", 2 * 5 - 2))
        adj.append(("`limbs()` over sr, sg and pl", 2 * ls + lp))
        adj.append(("`helper_sum`", helper_sum_muls(sh, "S")))
        adj.append(("`PadTerm::eval`", pad_eval_muls(sh, s)))
        return tabs, terms, adj

    # ---- 18 SC_FZC: the hidden-cube zero-check -----------------------------
    if s == SC_FZC:
        i_tau, i_pg, i_pu = push(T("eq(tau)")), push(T("eq(p_g)")), push(T("eq(p_u)"))
        names = ["A_G8", "A_RGL", "A_A16", "A_U16", "A_UL0", "A_UL1", "A_H16",
                 "A_HL0", "A_HL1", "A_RH0", "A_RH1"]
        assert len(names) == sh.a_planes_on("F")
        P = {nm: push(A(nm)) for nm in names}
        n_help = sh.helpers("F")
        h0 = push(H("H_F0"))
        for j in range(1, n_help):
            push(H(f"H_F{j}"))
        i_fact = push(H("H_FACT"))
        pad = sh.pad_on(SC_FZC)
        gi = push(SUPP("supp(Dom::F)")) if (sh.carries_pad_rule() and sh.pads("F")) else None
        f0 = Node("f0: a16 u16 - 2^14 h16 - l2(rh) + 2^13",
                  [("one", "1", [P["A_A16"], P["A_U16"]]),
                   ("one", "1", [Form("-2^14 h16 - rh0 - 256 rh1 + 2^13",
                                      [("kbase", P["A_H16"]), ("one", P["A_RH0"]),
                                       ("kbase", P["A_RH1"])])])])
        clauses = [
            ("mu0", f0),
            ("mu1", Form("f1: u16 + 2^15 - l2(ul)",
                         [("one", P["A_U16"]), ("one", P["A_UL0"]), ("kbase", P["A_UL1"])])),
            ("mu2", Form("f2: h16 + 2^15 - l2(hl)",
                         [("one", P["A_H16"]), ("one", P["A_HL0"]), ("kbase", P["A_HL1"])])),
        ]
        gated = Node("the 3 clauses", [("chal", lab, [c]) for lab, c in clauses])
        f_act = Node("the activation pair (never gated)",
                     [("one", "1", [i_fact,
                                    Form("alpha - g8 - 128 - beta a16 - g_act",
                                         [("one", P["A_G8"]), ("chal", P["A_A16"])])]),
                      ("one", "-1", [])])
        subs = [("one", "1", ([gi, gated] if gi is not None else [gated])),
                ("chal", "mu3", [f_act])]
        subs += [("chal", "mu_F", [n]) for n in
                 logup_node(sh, "F", h0, lambda i: dom_f_lookup_planes(sh, P)[i])]
        if pad:
            subs.append(("chal", "mu_pad",
                         [pad_node(sh, s, [(gi, [P[nm] for nm in names])])]))
        terms.append(Term("one", "1", (i_tau,), [Node("zc(FZC)", subs)],
                          "clauses + activation pair + LogUp + pad"))
        hw = (gi,) if gi is not None else ()
        terms.append(Term("chal", "nu0", (i_pg, *hw),
                          [Form("host_g: 2^7 g8 + rgl - 2^6",
                                [("kbase", P["A_G8"]), ("one", P["A_RGL"])])],
                          "host SC_GMM"))
        terms.append(Term("chal", "nu1", (i_pu, *hw), [P["A_U16"]],
                          "host SC_UMM (SH_U = 0: no coefficient)"))
        adj.append(("`l2` is one named closure of 1 token, called 3x", 1 * 3 - 1))
        adj.append(("the 3-clause loop body (2 tokens) runs 3x", 2 * 3 - 2))
        adj.append(("`helper_sum`", helper_sum_muls(sh, "F")))
        adj.append(("`PadTerm::eval`", pad_eval_muls(sh, s)))
        return tabs, terms, adj

    # ---- 19 SC_TAB: the three byte tables' helper relations ----------------
    if s == SC_TAB:
        i_tau = push(T("eq(tau)"))
        trip = []
        for nm, pub_field in (("U8", BASE), ("EXP", EXT), ("ACT", EXT)):
            m = push(A(f"A_M{nm}"))
            h = push(H(f"H_T{nm}"))
            p = push(PUB(f"table values {nm}", pub_field))
            trip.append((m, h, p))
        pad = sh.pad_on(SC_TAB)
        gi = push(SUPP("supp(Dom::Tab)")) if (sh.carries_pad_rule() and sh.pads("Tab")) else None
        subs = []
        for j, (m, h, p) in enumerate(trip):
            subs.append(("chal", f"mu{j}",
                         [Node(f"r{j}: h (alpha - values) - multiplicity",
                               [("one", "1", [h, Form(f"alpha - values{j}",
                                                      [("one", p)])]),
                                ("one", "-1", [m])])]))
        if pad:
            subs.append(("chal", "mu_pad",
                         [pad_node(sh, s, [(gi, [m for m, _, _ in trip]),
                                           (gi, [h for _, h, _ in trip])])]))
        terms.append(Term("one", "1", (i_tau,), [Node("zc(TAB)", subs)],
                          "three table relations + pad"))
        adj.append(("`PadTerm::eval`", pad_eval_muls(sh, s)))
        return tabs, terms, adj

    # ---- 20 SC_ZS: the zero-sum row ----------------------------------------
    if s == SC_ZS:
        i_one, i_u = push(PUB("all-ones over Dom::Tab")), push(H("H_U"))
        terms.append(Term("one", "1", (), [i_one, i_u], "the zero-sum row"))
        return tabs, terms, adj

    # ---- 21 / 22 the two endpoint equalities -------------------------------
    if s in (SC_IO_IN, SC_IO_OUT):
        i_tau = push(T("eq(tau)"))
        ai = push(A("A_X" if s == SC_IO_IN else "A_X2"))
        ei = push(EP("endpoint In" if s == SC_IO_IN else "endpoint Out"))
        terms.append(Term("one", "1", (i_tau,),
                          [Node("plane - endpoint", [("one", "1", [ai]),
                                                     ("one", "-1", [ei])])],
                          "endpoint equality"))
        return tabs, terms, adj

    raise AssertionError(f"unknown slot {s}")


# -- the lookup plane lists of layout::lookups_at, in helper order [hand]

def dom_d_lookup_planes(sh, P):
    ln = sh.limbs_norm
    top = not sh.norm_top_is_full_byte
    v = [P["A_XL0"], P["A_XL1"], P["A_Y"], P["A_Y"]]
    v += [P[f"A_NR{k}"] for k in range(ln)]
    if top:
        v.append(P[f"A_NR{ln-1}"])
    v += [P[f"A_NS{k}"] for k in range(ln)]
    if top:
        v.append(P[f"A_NS{ln-1}"])
    v += [P["A_AL0"], P["A_AL1"], P["A_RAL"], P["A_RAL"], P["A_X1L0"], P["A_X1L1"]]
    v += [P["A_YM"], P["A_YM"]]
    v += [P[f"A_MR{k}"] for k in range(ln)]
    if top:
        v.append(P[f"A_MR{ln-1}"])
    v += [P[f"A_MS{k}"] for k in range(ln)]
    if top:
        v.append(P[f"A_MS{ln-1}"])
    v += [P["A_X2L0"], P["A_X2L1"]]
    v += [P["A_ZL0"], P["A_ZL1"], P["A_RDL"], P["A_RDL"]]
    assert len(v) == sh.lookups_per_position("D")
    return v


def dom_f_lookup_planes(sh, P):
    v = [P["A_RGL"], P["A_RGL"], P["A_UL0"], P["A_UL1"], P["A_HL0"], P["A_HL1"],
         P["A_RH0"], P["A_RH1"], P["A_RH1"]]
    assert len(v) == sh.lookups_per_position("F")
    return v


def dom_qkv_lookup_planes(sh, P, q):
    if q:
        v = [P["A_Q8"], P["A_Q8"], P["A_RQL"], P["A_RQL"], P["A_QR8"], P["A_QR8"],
             P["A_RQRL"], P["A_RQRL"], P["A_O8"], P["A_O8"], P["A_RO0"],
             P["A_RO1"], P["A_RO1"]]
        assert len(v) == sh.lookups_per_position("Q")
    else:
        v = [P["A_K8"], P["A_K8"], P["A_RKL"], P["A_RKL"], P["A_V8"], P["A_V8"],
             P["A_RVL"], P["A_RVL"], P["A_KR8"], P["A_KR8"], P["A_RKRL"],
             P["A_RKRL"]]
        assert len(v) == sh.lookups_per_position("Kv")
    return v


def dom_s_lookup_planes(sh, P):
    ls, lp = sh.limbs_sigma_s, sh.limbs_p
    v = [P["A_S8"], P["A_S8"], P["A_RSL"], P["A_RSL"]]
    v += [P[f"A_PL{k}"] for k in range(lp)] + [P[f"A_PL{lp-1}"]]
    v += [P[f"A_SR{k}"] for k in range(ls)] + [P[f"A_SR{ls-1}"]]
    v += [P[f"A_SG{k}"] for k in range(ls)] + [P[f"A_SG{ls-1}"]]
    assert len(v) == sh.lookups_per_position("S")
    return v


# -- the helper-function multiplication counts [hand, from argument.rs]

def helper_sum_muls(sh, dom):
    """`helper_sum`: per helper, `h*d1*d2 - (d1+d2)` (2 muls) or `h*d1 - 1`
    (1 mul), plus `mu[k] * rel` (1 mul).  Each denominator costs one
    `mul_base`, counted separately."""
    n_lk = sh.lookups_per_position(dom)
    return (n_lk // 2) * 3 + (n_lk % 2) * 2


def helper_sum_mulbase(sh, dom):
    return sh.lookups_per_position(dom)


def pad_eval_muls(sh, slot):
    """`PadTerm::eval`: per group, |planes| coefficient muls plus one for the
    anti-support factor; then ONE final `self.mu.mul(acc)` — which the
    `PadTerm::none()` form pays too (mu is ZERO, acc is ZERO, and the
    multiplication still happens)."""
    tot = 0
    for d in ALL_DOMS:
        if PAD_ZERO_HOST[d] != slot:
            continue
        if d == "Tab":
            if sh.carries_pad_rule() and sh.pads("Tab"):
                tot += (3 + 1) + (3 + 1)   # multiplicities, then helpers
            continue
        n = sh.zero_rule_a_planes(d)
        if n:
            tot += n + 1
    return tot + 1


# ---------------------------------------------------------------- extraction

CALL_RE = re.compile(
    r"\bb\.(eq|public|a_at|a_slice|a_range|a|h|endpoint|supp|group_eq)\s*\(")
ARM_RE = re.compile(r"^\s{8}(SC_[A-Z0-9_ |]*?)\s*=>\s*\{?\s*$", re.M)
CLOSURE_RE = re.compile(r"\|v:\s*&\[Fp2\]\|")
DRAW_RE = re.compile(r"tr\.challenge_fp2(?:_vec)?\(")


def extract_arms(src: str):
    """Split `argument::define`'s match into its arms.  [extracted]"""
    start = src.index("pub(crate) fn define(")
    body = src[start:]
    body = body[:body.index("\n        _ => Err(\"private block: unknown slot\"")]
    heads = list(ARM_RE.finditer(body))
    out = {}
    for i, m in enumerate(heads):
        lo = m.end()
        hi = heads[i + 1].start() if i + 1 < len(heads) else len(body)
        out[tuple(x.strip() for x in m.group(1).split("|"))] = body[lo:hi]
    return out


def arm_facts(text: str):
    calls = [m.group(1) for m in CALL_RE.finditer(text)]
    cm = CLOSURE_RE.search(text)
    closure = text[cm.start():] if cm else ""
    return {
        "builder_calls": calls,
        "closure_mul_tokens": closure.count(".mul("),
        "closure_mul_base_tokens": closure.count(".mul_base("),
        "draws": len(DRAW_RE.findall(text)),
    }


# ---------------------------------------------------------------- costing

def closure_mul_base(s, sh):
    dom = {SC_LZC: "L", SC_DZC: "D", SC_QZC: "Q", SC_KVZC: "Kv", SC_SZC: "S",
           SC_FZC: "F"}.get(s)
    return helper_sum_mulbase(sh, dom) if dom else 0


def ir_cost(s, sh, tabs, terms, round0: bool, findiff: bool):
    """Base-field multiplications to produce the round polynomial's values at
    t = 0..degree for ONE pair index, evaluating FROM THE IR.

    The plan is the IR's own: every distinct node once (memoised by identity,
    which is the common-sub-product sharing), each group's shared wrapper
    factored out of the sum and multiplied in once, and every coefficient
    typed by its provenance (a public base-field constant is a `mul_base`,
    a challenge a full extension multiplication).

    `round0` types the table operands: in round 0 a wholly-base-field table
    still holds base-field words, so a product with such an operand is
    cheaper; from round 1 on every folded word is extension-valued.
    `findiff` evaluates each node at t = 0 .. ITS OWN degree and extends to
    the slot's degree by finite differences (additions only)."""
    _, _, deg = sh.slot_rounds(s)
    pts = deg + 1
    total = 0

    def tfield(i):
        return tabs[i].field if round0 else EXT

    memo = {}

    def visit(node):
        """returns (field, degree) and adds this node's cost once."""
        nonlocal total
        if isinstance(node, int):
            return tfield(node), 1
        if id(node) in memo:
            return memo[id(node)]
        if isinstance(node, Form):
            c, fl = 0, BASE
            for kind, ti in node.coefs:
                tf = tfield(ti)
                if kind == "one":
                    fl = combine(fl, tf)
                    continue
                c += mulcost(BASE if kind == "kbase" else EXT, tf)
                fl = combine(fl, EXT if kind == "chal" else tf)
            total += c * (2 if findiff else pts)
            memo[id(node)] = (fl, 1)
            return fl, 1
        # a Node
        c, fl, dg = 0, BASE, 0
        for kind, _lab, fs in node.subs:
            sub_f, sub_d = BASE, 0
            first = True
            for f in fs:
                ff, fd = visit(f)
                sub_d += fd
                if first:
                    sub_f, first = ff, False
                else:
                    c += mulcost(sub_f, ff)
                    sub_f = combine(sub_f, ff)
            if kind == "chal":
                c += mulcost(EXT, sub_f)
                sub_f = EXT
            elif kind == "kbase":
                c += mulcost(BASE, sub_f)
            fl = combine(fl, sub_f)
            dg = max(dg, sub_d)
        total += c * ((dg + 1) if findiff else pts)
        memo[id(node)] = (fl, dg)
        return fl, dg

    groups = {}
    for t in terms:
        groups.setdefault(t.wrapper, []).append(t)
    for wrap, ts in groups.items():
        inner_max, inner_field = 0, BASE
        for t in ts:
            c, fl, dg, first = 0, BASE, 0, True
            for f in t.inner:
                ff, fd = visit(f)
                dg += fd
                if first:
                    fl, first = ff, False
                else:
                    c += mulcost(fl, ff)
                    fl = combine(fl, ff)
            if t.coef == "chal":
                c += mulcost(EXT, fl)
                fl = EXT
            elif t.coef == "kbase":
                c += mulcost(BASE, fl)
            inner_max = max(inner_max, dg)
            inner_field = combine(inner_field, fl)
            total += c * ((dg + 1) if findiff else pts)
        if wrap:
            c, fl, first = 0, BASE, True
            for w in wrap:
                ff = tfield(w)
                if first:
                    fl, first = ff, False
                else:
                    c += mulcost(fl, ff)
                    fl = combine(fl, ff)
            c += mulcost(fl, inner_field)
            d = len(wrap) + inner_max
            total += c * ((d + 1) if findiff else pts)
    return total


def closure_cost_per_pair(s, sh, muls, mulbase):
    """Base-field multiplications of the CLOSURE per pair index: `degree + 1`
    evaluations, every `.mul` a full extension multiplication whatever the
    operands hold."""
    _, _, deg = sh.slot_rounds(s)
    return (deg + 1) * (muls * MUL_EXT_EXT + mulbase * MUL_EXT_BASE)


def fold_cost(k, n, round0_base_tables=0):
    """`sumcheck::prove`'s fold `a + r (b - a)`: one multiplication per table
    per pair index per round.  Today every table is `Vec<Fp2>` and the fold is
    a full `Fp2::mul` in every round; with the base-field tables handed out as
    `Fp` cubes the round-0 fold of those is a `mul_base`."""
    out = 0
    for j in range(n):
        half = 1 << (n - 1 - j)
        if j == 0:
            out += half * (round0_base_tables * MUL_EXT_BASE
                           + (k - round0_base_tables) * MUL_EXT_EXT)
        else:
            out += half * k * MUL_EXT_EXT
    return out


def count_nodes(terms):
    seen, nforms, nnodes = set(), 0, 0
    def walk(f):
        nonlocal nforms, nnodes
        if isinstance(f, int) or id(f) in seen:
            return
        seen.add(id(f))
        if isinstance(f, Form):
            nforms += 1
            return
        nnodes += 1
        for _, _, fs in f.subs:
            for x in fs:
                walk(x)
    for t in terms:
        for f in t.inner:
            walk(f)
    return nforms, nnodes


# ---------------------------------------------------------------- the report

def slot_report(s, sh, arms, shape_key):
    name = SLOT_NAMES[s]
    tabs, terms, adj = build_slot(s, sh)
    main, ext, deg = sh.slot_rounds(s)
    arm = None
    for key, txt in arms.items():
        if name in key:
            arm = arm_facts(txt)
            break
    assert arm is not None, name
    muls = arm["closure_mul_tokens"] + sum(x for _, x in adj)
    mulb = closure_mul_base(s, sh)
    kinds = {}
    for t in tabs:
        kinds[t.kind] = kinds.get(t.kind, 0) + 1
    base_tabs = sum(1 for t in tabs if t.field == BASE)
    n_pairs = (1 << main) - 1
    half0 = 1 << (main - 1)
    rest = n_pairs - half0
    ir_deg = max((t.degree() for t in terms), default=0)
    nforms, nnodes = count_nodes(terms)

    per_pair = closure_cost_per_pair(s, sh, muls, mulb)
    cl = per_pair * n_pairs
    ir_b = ir_cost(s, sh, tabs, terms, round0=False, findiff=False)
    ir_b0 = ir_cost(s, sh, tabs, terms, round0=True, findiff=False)
    ir_c = ir_cost(s, sh, tabs, terms, round0=False, findiff=True)
    ir_c0 = ir_cost(s, sh, tabs, terms, round0=True, findiff=True)
    lev_b = ir_b * n_pairs
    lev_ba = ir_b0 * half0 + ir_b * rest
    lev_bac = ir_c0 * half0 + ir_c * rest

    total_evals = (1 << main) if SLOT_KIND[s] == "private" else 0
    claimed = total_evals * (muls * MUL_EXT_EXT + mulb * MUL_EXT_BASE)
    fold_now = fold_cost(len(tabs), main, 0)
    fold_a = fold_cost(len(tabs), main, base_tabs)
    return {
        "slot": s, "name": name, "kind": SLOT_KIND[s], "shape": shape_key,
        "main_rounds": main, "extension_rounds": ext, "declared_degree": deg,
        "ir_max_product_degree": ir_deg,
        "tables": len(tabs), "tables_by_kind": kinds,
        "tables_base_field": base_tabs,
        "tables_extension": len(tabs) - base_tabs,
        "ir_terms": len(terms), "ir_sum_of_product_nodes": nnodes,
        "ir_affine_forms": nforms,
        "ir_monomials": sum(term_monomials(t) for t in terms),
        "closure_mul_tokens": arm["closure_mul_tokens"],
        "closure_muls_per_eval": muls,
        "closure_mul_base_per_eval": mulb,
        "closure_adjustments": [{"why": w, "extra": x} for w, x in adj],
        "cube_words": len(tabs) << main,
        "cube_bytes": (len(tabs) << main) * 16,
        # the same set with the wholly base-field tables handed out as `Fp`
        # cubes (8 B a word) instead of `Fp2` ones (16 B)
        "cube_bytes_mixed": ((len(tabs) - base_tabs) * 16 + base_tabs * 8) << main,
        "words_read": len(tabs) * ((1 << (main + 1)) - 2),
        "words_written": len(tabs) * ((1 << main) - 1),
        "fp_mul_rounds_closure": cl,
        "fp_mul_rounds_ir_b": lev_b,
        "fp_mul_rounds_ir_ba": lev_ba,
        "fp_mul_rounds_ir_bac": lev_bac,
        "fp_mul_fold_closure": fold_now,
        "fp_mul_fold_ir_a": fold_a,
        "fp_mul_claimed_sum": claimed,
        "fp_mul_total_closure": cl + fold_now + claimed,
        "fp_mul_total_ir": lev_bac + fold_a + claimed,
        "builder_calls": arm["builder_calls"],
        "definition_draws": arm["draws"],
    }


def check_census(rows, shape_key):
    """CROSS-CHECK 2 — the MEASURED base-field census of the lane ledger
    (`ZK60_BLOCK125M_LANE_PROGRESS.md` stage 29 task 4, `r29-m125-bfcensus.log`
    and `r29-k4-bfcensus.log`)."""
    want = {
        "m125": {17: (30, 18), 14: (60, 40), 18: (20, 11), 15: (21, 11), 4: (5, 4)},
        "rung_k4": {17: (30, 18), 14: (62, 40), 18: (21, 12), 15: (21, 11), 4: (5, 4)},
    }.get(shape_key)
    if not want:
        return []
    out = []
    for s, (n_tab, n_base) in sorted(want.items()):
        r = next(x for x in rows if x["slot"] == s)
        out.append({"slot": s, "name": SLOT_NAMES[s], "measured_tables": n_tab,
                    "counted_tables": r["tables"],
                    "measured_wholly_base_field": n_base,
                    "counted_base_field": r["tables_base_field"],
                    "agree": (r["tables"] == n_tab
                              and r["tables_base_field"] == n_base)})
    return out


def check_lane_model(rows, shape_key, lane):
    """CROSS-CHECK 3 — the lane's own Python layout model."""
    path = os.path.join(lane, "scripts")
    modfile = os.path.join(path, "zk60_private_block_layout_model.py")
    if not os.path.isfile(modfile):
        return {"available": False, "why": f"not found: {modfile}"}
    sys.path.insert(0, path)
    try:
        import zk60_private_block_layout_model as M  # type: ignore
    except Exception as e:                            # pragma: no cover
        return {"available": False, "why": f"import failed: {e}"}
    nm = {"toy": "TOY", "rung": "RUNG", "rung_g": "RUNG_G", "rung_k4": "RUNG_K4",
          "rung_p2": "RUNG_P2", "rung_c6": "RUNG_C6", "rung_w14": "RUNG_W14",
          "rung_e32": "RUNG_E32", "m125": "M125"}[shape_key]
    if not hasattr(M, nm):
        return {"available": False, "why": f"the lane model has no {nm}"}
    them = M.slots(getattr(M, nm))
    diffs = []
    for r in rows:
        t = them[r["slot"]]
        if (t["main_rounds"], t["extension_rounds"], t["degree"]) != (
                r["main_rounds"], r["extension_rounds"], r["declared_degree"]):
            diffs.append({"slot": r["slot"],
                          "lane": [t["main_rounds"], t["extension_rounds"], t["degree"]],
                          "here": [r["main_rounds"], r["extension_rounds"],
                                   r["declared_degree"]]})
    return {"available": True, "slots_compared": len(rows), "differences": diffs}


PROV = {"one": "none (coefficient 1 or -1)",
        "kbase": "public base-field constant (a power of 256, a fixed-point "
                 "shift, a norm constant)",
        "chal": "challenge or a product of challenges (mu, nu, zeta^j, "
                "lam_z, beta, a batching power)"}


def factor_str(f, tabs):
    if isinstance(f, int):
        return f"t{f}[{tabs[f].kind}]"
    if isinstance(f, Form):
        return f"<{f.label}>"
    return f"({f.label})"


def dump_node(f, tabs, out, seen):
    if isinstance(f, int) or id(f) in seen:
        return
    seen.add(id(f))
    if isinstance(f, Form):
        parts = []
        if f.has_const:
            parts.append("const")
        for kind, ti in f.coefs:
            c = {"one": "", "kbase": "k*", "chal": "z*"}[kind]
            parts.append(f"{c}t{ti}")
        out.append(f"      form <{f.label}> = {' + '.join(parts)}")
        return
    for _, _, fs in f.subs:
        for x in fs:
            dump_node(x, tabs, out, seen)
    subs = " + ".join(
        (("" if (k == "one" and l == "1") else f"{l} * ")
         + ("1" if not fs else " * ".join(factor_str(x, tabs) for x in fs)))
        for k, l, fs in f.subs)
    out.append(f"      node ({f.label}) [deg {f.degree()}] = {subs}")


def detail(shape_key, sh, arms):
    print(f"# per-slot detail at {shape_key} — {sh.name}")
    print()
    for s in range(N_SLOTS):
        tabs, terms, adj = build_slot(s, sh)
        main, ext, deg = sh.slot_rounds(s)
        print(f"## slot {s:02d} {SLOT_NAMES[s]} ({SLOT_KIND[s]}) — "
              f"cube 2^{main}, {ext} extension round(s), declared degree {deg}, "
              f"IR max product degree {max(t.degree() for t in terms)}")
        print()
        print(f"  tables ({len(tabs)}), in push order:")
        run, i = None, 0
        while i < len(tabs):
            j = i
            while (j + 1 < len(tabs) and tabs[j + 1].kind == tabs[i].kind
                   and tabs[j + 1].field == tabs[i].field
                   and tabs[j + 1].label.rstrip("0123456789[]")
                   == tabs[i].label.rstrip("0123456789[]")):
                j += 1
            rng = f"t{i}" if j == i else f"t{i}..t{j}"
            print(f"    {rng:<12} {tabs[i].kind:<9} {tabs[i].field:<4} "
                  f"{tabs[i].label}" + ("" if j == i else f" .. {tabs[j].label}"))
            i = j + 1
        print()
        print("  the polynomial, as a sum of products:")
        out, seen = [], set()
        for t in terms:
            for f in t.inner:
                dump_node(f, tabs, out, seen)
        for line in out:
            print(line)
        for t in terms:
            w = " * ".join(factor_str(x, tabs) for x in t.wrapper) or "1"
            inn = " * ".join(factor_str(x, tabs) for x in t.inner) or "1"
            cof = "1" if t.coef == "one" else t.coef_label
            print(f"      TERM [deg {t.degree()}] coef {cof} "
                  f"({PROV[t.coef]}) : {w} * {inn}   -- {t.note}")
        print()


def ir_json(shape_key, sh):
    """The IR as the JSON the independent Python gate would read.  One object
    per slot; table references are the slot's own push indices, which are the
    indices the terminals arrive in."""
    def enc(f, pool):
        if isinstance(f, int):
            return {"table": f}
        key = id(f)
        if key in pool["ids"]:
            return {"node": pool["ids"][key]}
        if isinstance(f, Form):
            nid = len(pool["nodes"])
            pool["ids"][key] = nid
            pool["nodes"].append({
                "id": nid, "label": f.label, "kind": "affine",
                "has_const": f.has_const,
                "coefs": [{"provenance": k, "table": t} for k, t in f.coefs]})
            return {"node": nid}
        subs = [{"coef_provenance": k, "coef": l,
                 "factors": [enc(x, pool) for x in fs]} for k, l, fs in f.subs]
        nid = len(pool["nodes"])
        pool["ids"][key] = nid
        pool["nodes"].append({"id": nid, "label": f.label, "kind": "sum",
                              "degree": f.degree(), "subterms": subs})
        return {"node": nid}

    slots = []
    for s in range(N_SLOTS):
        tabs, terms, _ = build_slot(s, sh)
        main, ext, deg = sh.slot_rounds(s)
        pool = {"nodes": [], "ids": {}}
        tl = [{"index": i, "kind": t.kind, "field": t.field, "label": t.label}
              for i, t in enumerate(tabs)]
        terms_j = []
        for t in terms:
            terms_j.append({
                "coef": t.coef_label, "coef_provenance": t.coef,
                "wrapper": list(t.wrapper),
                "factors": [enc(f, pool) for f in t.inner],
                "degree": t.degree(), "note": t.note})
        slots.append({"slot": s, "name": SLOT_NAMES[s], "kind": SLOT_KIND[s],
                      "main_rounds": main, "extension_rounds": ext,
                      "declared_degree": deg, "tables": tl,
                      "nodes": pool["nodes"], "terms": terms_j})
    return {"schema": "zk60-slot-ir/0 (a DESIGN sketch, not a produced format)",
            "shape": shape_key, "shape_name": sh.name, "slots": slots}


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--lane", default="/home/victor/wt-zk60-block125m")
    ap.add_argument("--json", default=None)
    ap.add_argument("--ir-json", default=None)
    ap.add_argument("--detail", default=None)
    ap.add_argument("--shapes", default="rung_w14,m125")
    args = ap.parse_args(argv)

    if args.detail:
        detail(args.detail, SHAPES[args.detail],
               extract_arms(open(os.path.join(
                   args.lane, "hashline/src/private_block/argument.rs"),
                   encoding="utf-8").read()))
        if args.ir_json:
            with open(args.ir_json, "w", encoding="utf-8") as fh:
                json.dump(ir_json(args.detail, SHAPES[args.detail]), fh, indent=1)
            print(f"# IR json written to {args.ir_json}")
        return 0

    src_path = os.path.join(args.lane, "hashline/src/private_block/argument.rs")
    with open(src_path, encoding="utf-8") as fh:
        src = fh.read()
    arms = extract_arms(src)

    out = {"source": src_path, "unit": "one base-field (Fp) multiplication",
           "shapes": {}, "cross_checks": {}}
    print(f"# slot expression IR inventory")
    print(f"# source (read-only): {src_path} [extracted]")
    print(f"# arms of `define` extracted: {len(arms)}; "
          f"slots named by them: {sum(len(k) for k in arms)} of {N_SLOTS}")
    print()

    for key in args.shapes.split(","):
        sh = SHAPES[key]
        rows = [slot_report(s, sh, arms, key) for s in range(N_SLOTS)]
        out["shapes"][key] = {"name": sh.name, "slots": rows}
        degdiff = [(r["slot"], r["ir_max_product_degree"], r["declared_degree"])
                   for r in rows if r["ir_max_product_degree"] != r["declared_degree"]]
        out["cross_checks"].setdefault("ir_degree_vs_declared", {})[key] = degdiff
        out["cross_checks"].setdefault("census", {})[key] = check_census(rows, key)
        out["cross_checks"].setdefault("lane_model", {})[key] = check_lane_model(
            rows, key, args.lane)

        print(f"## {key} — {sh.name}")
        print()
        print("| slot | name | kind | main | ext | deg | IR deg | tables | "
              "base/ext | IR terms | nodes | forms | monomials | mul/eval | "
              "cube words | Fp mul, closure | Fp mul, IR | saved |")
        print("|---|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|")
        tot = dict(tables=0, cube=0, cl=0, ir=0, mono=0, terms=0)
        for r in rows:
            cl, ir = r["fp_mul_total_closure"], r["fp_mul_total_ir"]
            tot["tables"] += r["tables"]
            tot["cube"] += r["cube_words"]
            tot["cl"] += cl
            tot["ir"] += ir
            tot["mono"] += r["ir_monomials"]
            tot["terms"] += r["ir_terms"]
            pc = 100.0 * (cl - ir) / cl if cl else 0.0
            print(f"| {r['slot']:02d} | {r['name']} | {r['kind'][:4]} | "
                  f"{r['main_rounds']} | {r['extension_rounds']} | "
                  f"{r['declared_degree']} | {r['ir_max_product_degree']} | "
                  f"{r['tables']} | {r['tables_base_field']}/{r['tables_extension']} | "
                  f"{r['ir_terms']} | {r['ir_sum_of_product_nodes']} | "
                  f"{r['ir_affine_forms']} | {r['ir_monomials']} | "
                  f"{r['closure_muls_per_eval']} | {r['cube_words']:,} | "
                  f"{cl:,} | {ir:,} | {pc:.1f}% |")
        pc = 100.0 * (tot['cl'] - tot['ir']) / tot['cl']
        print(f"| — | **all 23** | | | | | | **{tot['tables']}** | | "
              f"**{tot['terms']}** | | | **{tot['mono']}** | | "
              f"**{tot['cube']:,}** | **{tot['cl']:,}** | **{tot['ir']:,}** | "
              f"**{pc:.1f}%** |")
        print()
        big = max(rows, key=lambda r: r["cube_bytes"])
        print(f"peak single-slot table set: {big['cube_bytes'] / 2**20:,.1f} MiB "
              f"(slot {big['slot']:02d} {big['name']}, {big['tables']} tables of "
              f"2^{big['main_rounds']} `Fp2` words), or "
              f"{big['cube_bytes_mixed'] / 2**20:,.1f} MiB with its "
              f"{big['tables_base_field']} base-field tables as `Fp` cubes; "
              f"the sum over all 23 slots, if every set were resident at once: "
              f"{sum(r['cube_bytes'] for r in rows) / 2**30:,.2f} GiB "
              f"({sum(r['cube_bytes_mixed'] for r in rows) / 2**30:,.2f} GiB "
              f"mixed) [COUNTED]")
        print()
        nr = sum(r["main_rounds"] for r in rows)
        ne = sum(r["extension_rounds"] for r in rows)
        print(f"launch / hand-back counts: {nr} main rounds over the 23 slots "
              f"plus {ne} extension rounds — one round message ("
              f"{sum((r['declared_degree'] + 1) for r in rows)} `Fp2` values "
              f"in total over the main rounds of one round index each, "
              f"{sum((r['main_rounds'] + r['extension_rounds']) * (r['declared_degree'] + 1) for r in rows)} "
              f"over the whole proof) crosses back to the host per round, and "
              f"one challenge crosses to the device [COUNTED]")
        print()
        print("### the three levers, cumulative, against the closure [COUNTED]")
        print()
        print("Base-field (Fp) multiplications over all 23 slots: the round "
              "loop, the table fold and the claimed sum. Each row adds one "
              "lever to the row above; `marginal` is what that lever alone "
              "removes.")
        print()
        print("| form | round loop | fold | claimed sum | total | marginal |")
        print("|---|--:|--:|--:|--:|--:|")
        seq = [("closure as written (the baseline)", "fp_mul_rounds_closure",
                "fp_mul_fold_closure"),
               ("+ (b) shared sub-expressions, hoisted wrappers, coefficients "
                "typed by provenance", "fp_mul_rounds_ir_b", "fp_mul_fold_closure"),
               ("+ (a) base-field operands in round 1", "fp_mul_rounds_ir_ba",
                "fp_mul_fold_ir_a"),
               ("+ (c) finite differences per sub-expression",
                "fp_mul_rounds_ir_bac", "fp_mul_fold_ir_a")]
        prev, first = None, None
        cs = sum(r["fp_mul_claimed_sum"] for r in rows)
        for lab, kk, fk in seq:
            v = sum(r[kk] for r in rows)
            f = sum(r[fk] for r in rows)
            t = v + f + cs
            marg = "—" if prev is None else f"{100.0*(prev-t)/prev:.1f}%"
            if first is None:
                first = t
            print(f"| {lab} | {v:,} | {f:,} | {cs:,} | {t:,} | {marg} |")
            prev = t
        print(f"| **all three together** | | | | **{prev:,}** | "
              f"**{100.0*(first-prev)/first:.1f}% of the baseline** |")
        print()
        rd = sum(r["words_read"] for r in rows)
        wr = sum(r["words_written"] for r in rows)
        nb = sum(r["tables_base_field"] for r in rows)
        print(f"table traffic of the round loop: {rd:,} `Fp2` words read, "
              f"{wr:,} written — {16*rd/2**30:,.2f} GiB read at 16 B a word. "
              f"{nb} of the {tot['tables']} tables are wholly base-field, and "
              f"handing those out as `Fp` cubes halves their round-0 read and "
              f"their resident size [COUNTED].")
        print()
        print("### the cross-checks")
        print()
        cm = out["cross_checks"]["census"][key]
        if cm:
            print("MEASURED base-field census of the lane ledger against this "
                  "model [cross-check 2]:")
            print()
            print("| slot | measured tables | counted | measured wholly "
                  "base-field | counted | agree |")
            print("|---|--:|--:|--:|--:|---|")
            for c in cm:
                print(f"| {c['slot']:02d} {c['name']} | {c['measured_tables']} | "
                      f"{c['counted_tables']} | {c['measured_wholly_base_field']} | "
                      f"{c['counted_base_field']} | "
                      f"{'YES' if c['agree'] else '**NO**'} |")
            print()
        lm = out["cross_checks"]["lane_model"][key]
        if lm.get("available"):
            print(f"lane Python layout model [cross-check 3]: "
                  f"{lm['slots_compared']} slots compared, "
                  f"{len(lm['differences'])} differences {lm['differences']}")
        else:
            print(f"lane Python layout model [cross-check 3]: unavailable "
                  f"({lm.get('why')})")
        print()
        print("the token identity [cross-check 1], slot by slot "
              "(`dynamic = tokens + adjustments`):")
        print()
        print("| slot | tokens | adjustments | dynamic |")
        print("|---|--:|---|--:|")
        for r in rows:
            aj = "; ".join(f"{a['why']} +{a['extra']}" if a["extra"] >= 0
                           else f"{a['why']} {a['extra']}"
                           for a in r["closure_adjustments"]) or "none"
            print(f"| {r['slot']:02d} {r['name']} | {r['closure_mul_tokens']} | "
                  f"{aj} | {r['closure_muls_per_eval']} |")
        print()
        if degdiff:
            print("slots whose DECLARED degree exceeds the maximum product "
                  "degree the IR computes. The declared degree is an upper "
                  "bound and is what the round message length is built from, "
                  "so lowering it would MOVE BYTES: it is reported here as a "
                  "count, not proposed.")
            print()
            print("| slot | IR max product degree | declared | why |")
            print("|---|--:|--:|---|")
            why = {14: "the ungated LogUp arm already reaches 4; the support "
                       "indicator raises only the clause arm, from 3 to 4",
                   15: "same", 16: "same", 18: "same"}
            for s, a, b in degdiff:
                print(f"| {s:02d} {SLOT_NAMES[s]} | {a} | {b} | "
                      f"{why.get(s, '')} |")
            print()

    if args.json:
        with open(args.json, "w", encoding="utf-8") as fh:
            json.dump(out, fh, indent=1, sort_keys=True)
        print(f"# json written to {args.json}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

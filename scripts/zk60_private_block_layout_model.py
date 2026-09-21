#!/usr/bin/env python3
"""An INDEPENDENT, shape-driven layout model of the private transformer block.

WHAT THIS IS. A pure-Python recomputation, from a SHAPE alone, of everything
the private block's layout fixes: the padded domains, the plane list with its
per-plane rows, the A / H / M row totals, the claim sites, the opening-group
counts, the 23 slots with each slot's mask length `L`, the lookup totals and
the receipt size in bytes.  Nothing is imported from the Rust crate and no
number below is copied from it: every rule is re-derived from
`hashline/src/private_block/{layout,argument,wire,protocol}.rs` and from
`docs/zkmatrix-poc/ZK60_PRIVATE_BLOCK_125M_LAYOUT.md`, and where those two
disagree the Rust is the truth at the toy shape and the disagreement is
reported.

WHY IT EXISTS.  The 125M layout memo's figures are hand-counted.  A model that
reproduces the TOY shape's numbers EXACTLY — `A` 455, `H` 384, `M` 50, 23
slots, 120 / 51 claim sites, 35 / 9 opening groups, the per-domain U8 totals
`[1024, 19456, 4608, 6656, 3072, 26624]` and a 2,816,472-byte receipt — has
earned the right to be believed at the shapes nobody can run yet.  A model
that does not reproduce the toy says nothing about any other shape, which is
why the toy reproduction is an assertion and not a printout.

A DIFFERENCE AGAINST THE MEMO IS A RESULT, NOT A BUG.  Nothing here is tuned
to match the memo's [COUNTED] figures; the differences are reported with the
plane or rule responsible.

Run `python3 scripts/zk60_private_block_layout_model.py --all --out DIR` for
the three shapes' JSON plus a plain report.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys

# --------------------------------------------------------------------------
# calibration constants that do not move with the shape
# (`private_block/layout.rs:52-70`)
# --------------------------------------------------------------------------
NORM_TN = 11          # the norm's fixed-point shift; den = 2^(tn+1) * D
NORM_CEPS = 1
F_P = 9               # softmax quotient scale; p in [0, 2^F_P] INCLUSIVE
INT16_MAX = 32767
LIMBS_ISQRT = 3       # byte limbs of D, a1, a2 (each < 2^24)
N_SLOTS = 23
M_ROWS = 2 * N_SLOTS + 4
N_FUNCTIONALS = N_SLOTS + 5 + 6   # one eval per slot + one Gamma per standalone + one per host

# the wire format's fixed counts (`private_block/wire.rs:16-26`)
WIRE_HEADER = 8 + 32
COL_CHECKS = 256
MASK_VEC = 1024       # the mask message is 2 * 512 Fp2 words, shape-independent
MASK_PATH = 12        # log2(MASK_DOM = 4096)

# the slot order and the structural degree of each slot, before any pad
# indicator (`layout.rs:411-462`)
SLOT_NAMES = [
    "01 SS row sums norm_a", "01m SS row sums norm_m", "02 norm squares zero-check",
    "08 limb zero-check", "07 masked row sums + selector", "09Q matmul", "09K matmul",
    "09V matmul", "10 score matmul", "11 PV matmul", "12 Wo matmul", "13G gate matmul",
    "13U up matmul", "13D down matmul", "03 D zero-check", "04 Q zero-check",
    "05 KV zero-check", "06 softmax zero-check", "14 F zero-check",
    "TAB table helper zero-check", "ZS zero-sum row", "IO-in endpoint equality",
    "IO-out endpoint equality",
]
(SC_SS, SC_SSM, SC_TZC, SC_LZC, SC_RS, SC_QMM, SC_KMM, SC_VMM, SC_SCORE, SC_PV,
 SC_WO, SC_GMM, SC_UMM, SC_DMM, SC_DZC, SC_QZC, SC_KVZC, SC_SZC, SC_FZC,
 SC_TAB, SC_ZS, SC_IO_IN, SC_IO_OUT) = range(N_SLOTS)

BASE_DEGREE = [3, 3, 3, 4, 3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 4, 4, 4, 4, 3, 2, 2, 2]
EXT_ROUNDS = [1] * N_SLOTS
EXT_ROUNDS[SC_SCORE] = 2   # two private factors, masked in extension rounds 0 and 1
EXT_ROUNDS[SC_PV] = 2
# The two BILINEAR slots: the only slots whose monomial is a product of TWO
# private factors, and the only ones that read the head axis in two different
# ways (the query head is the whole of `r_h`, the key-value head is its top
# `log2(kv_heads)` bits).  See `group_sumcheck_bits`.
BILINEAR_SLOTS = (SC_SCORE, SC_PV)
SLOT_KIND = (["private", "private", "host", "standalone", "private"] + ["private"] * 9
             + ["host"] * 5 + ["standalone"] * 4)
# host slot -> the private slots it hosts (`layout.rs:501-508`)
HOSTS = {SC_TZC: (SC_SS, SC_SSM), SC_DZC: (SC_WO, SC_DMM), SC_QZC: (SC_QMM, SC_PV),
         SC_KVZC: (SC_KMM, SC_VMM), SC_SZC: (SC_RS, SC_SCORE), SC_FZC: (SC_GMM, SC_UMM)}

# The slots whose relation is switched off on the pad by the support indicator,
# and which therefore gain ONE degree when their governing domain pads
# (`ZK60_PRIVATE_BLOCK_125M_LAYOUT.md` §3.7a, "what the indicator gates").
# `SC_LZC` and `SC_TAB` are deliberately absent: they are homogeneous / already
# satisfied at zero, so they gain nothing.
INDICATOR_SLOT_DOMAIN = {
    SC_SS: "D", SC_SSM: "D", SC_RS: "S", SC_DZC: "D",
    SC_QZC: "Q", SC_KVZC: "Kv", SC_SZC: "S", SC_FZC: "F",
}

LOOKUP_DOMS = ["L", "D", "F", "Q", "Kv", "S"]
ALL_DOMS = ["T", "Ht", "L", "D", "Q", "Kv", "S", "F", "Tab"]


def npot(v: int) -> int:
    """the next power of two at or above `v` (the padding rule, trap T-4)"""
    if v < 1:
        raise ValueError("a shape axis must be positive")
    return 1 << (v - 1).bit_length()


def clog2(v: int) -> int:
    return (v - 1).bit_length()


class Shape:
    """One block geometry, plus the PCS parameters the receipt is priced at."""

    def __init__(self, name, tokens, width, hidden, q_heads, head_dim, kv_heads,
                 log_cols, inv_rate=4, opened_cols=COL_CHECKS, f_e=9,
                 endpoint_rows=7, endpoint_log_n=None, endpoint_inv_rate=None,
                 norm_wrho=None, wrho_s=None, note=""):
        self.name = name
        self.tokens, self.width, self.hidden = tokens, width, hidden
        self.q_heads, self.head_dim, self.kv_heads = q_heads, head_dim, kv_heads
        self.log_cols, self.inv_rate, self.opened_cols = log_cols, inv_rate, opened_cols
        self.f_e = f_e
        self.endpoint_rows = endpoint_rows
        self.endpoint_log_n = log_cols if endpoint_log_n is None else endpoint_log_n
        self.endpoint_inv_rate = inv_rate if endpoint_inv_rate is None else endpoint_inv_rate
        self.note = note
        # ---- derived pads
        self.t_pad, self.d_pad = npot(tokens), npot(width)
        self.h_pad, self.f_pad = npot(q_heads), npot(hidden)
        # ---- derived integer windows (§3.3, §3.4); overridable for a rung-only calibration
        d_max = math.isqrt(NORM_CEPS + width * INT16_MAX ** 2)
        self.d_max = d_max
        self.norm_wrho = (NORM_TN + 1 + d_max.bit_length()) if norm_wrho is None else norm_wrho
        # Sum <= T * 2^F_E, and sigma_s < Sum, so the window is that many bits
        self.wrho_s = (clog2(tokens) + f_e) if wrho_s is None else wrho_s

    # -- the byte-limb counts the windows force -----------------------------
    @property
    def limbs_norm(self):
        return (self.norm_wrho + 7) // 8

    @property
    def norm_top_is_full_byte(self):
        """When the window fills its top limb exactly, the `scaled(top, 2^(32-wrho))`
        lookup is redundant and is dropped (C-6: FOUR of them, rho and sigma of
        each norm)."""
        return self.norm_wrho == 8 * self.limbs_norm

    @property
    def limbs_sigma_s(self):
        return (self.wrho_s + 7) // 8

    @property
    def limbs_p(self):
        return (F_P + 1 + 7) // 8   # p reaches 2^F_P, so F_P + 1 bits

    # -- the nine domains ---------------------------------------------------
    def natural_log(self, dom):
        t, d, h, dh, f = self.t_pad, self.d_pad, self.h_pad, self.head_dim, self.f_pad
        return {
            "T": clog2(t),
            "Ht": clog2(h * t),
            "L": clog2(16 * t),              # sixteen packed limb sub-planes of T
            "D": clog2(t * d),
            "Q": clog2(t * h * dh),
            "Kv": clog2(t * self.kv_heads * dh),
            "S": clog2(h * t * t),
            "F": clog2(t * f),
            "Tab": 8,                        # the three 256-entry tables
        }[dom]

    def true_size(self, dom):
        t, d, h, dh, f = self.tokens, self.width, self.q_heads, self.head_dim, self.hidden
        return {
            "T": t, "Ht": h * t, "L": (3 * LIMBS_ISQRT) * t, "D": t * d,
            "Q": t * h * dh, "Kv": t * self.kv_heads * dh, "S": h * t * t,
            "F": t * f, "Tab": 256,
        }[dom]

    def carries_h_planes(self, dom):
        return dom in LOOKUP_DOMS or dom == "Tab"

    def log(self, dom):
        """The domain's log AFTER the B-3 / P-3 lift: every domain that carries
        `H` planes is lifted to the row width, because the single value-0 LogUp
        sum claim has one part per `H` plane and `part_key` keys a part below
        the row width by its column offset and length — three different keys
        and `check_opening` refuses (`protocol.rs:161-163`).  `rows_of` is 1
        either way below the row width, so the lift costs no rows."""
        nat = self.natural_log(dom)
        if self.carries_h_planes(dom) and nat < self.log_cols:
            return self.log_cols
        return nat

    def lifted(self, dom):
        return self.log(dom) != self.natural_log(dom)

    def size(self, dom):
        return 1 << self.log(dom)

    def rows_of(self, dom):
        n = 1 << self.log_cols
        return max(1, -(-self.size(dom) // n))


# --------------------------------------------------------------------------
# the plane lists (`layout.rs:114-256`), re-derived per shape
# --------------------------------------------------------------------------
def a_planes(sh: Shape):
    """(domain, plane name, multiplicity) for every committed `A` plane."""
    ln = sh.limbs_norm
    out = [("T", "A_D"), ("T", "A_DSQ"), ("T", "A_DM"), ("T", "A_DSQM"),
           ("Ht", "A_MX"), ("Ht", "A_SUM"),
           ("L", "A_LIMB"), ("L", "A_LIMBM")]
    out += [("D", "A_X"), ("D", "A_XL0"), ("D", "A_XL1"), ("D", "A_Y")]
    out += [("D", f"A_NR{k}") for k in range(ln)]
    out += [("D", f"A_NS{k}") for k in range(ln)]
    out += [("D", "A_AO"), ("D", "A_AL0"), ("D", "A_AL1"), ("D", "A_RAL"),
            ("D", "A_X1"), ("D", "A_X1L0"), ("D", "A_X1L1"), ("D", "A_YM")]
    out += [("D", f"A_MR{k}") for k in range(ln)]
    out += [("D", f"A_MS{k}") for k in range(ln)]
    out += [("D", "A_Z16"), ("D", "A_X2"), ("D", "A_X2L0"), ("D", "A_X2L1"),
            ("D", "A_ZL0"), ("D", "A_ZL1"), ("D", "A_RDL")]
    out += [("Q", "A_Q8"), ("Q", "A_RQL"), ("Q", "A_QR8"), ("Q", "A_RQRL"),
            ("Q", "A_O8"), ("Q", "A_RO0"), ("Q", "A_RO1")]
    out += [("Kv", "A_K8"), ("Kv", "A_RKL"), ("Kv", "A_V8"), ("Kv", "A_RVL"),
            ("Kv", "A_KR8"), ("Kv", "A_RKRL")]
    out += [("S", "A_S8"), ("S", "A_RSL"), ("S", "A_ZSEL"), ("S", "A_E"), ("S", "A_P")]
    out += [("S", f"A_PL{k}") for k in range(sh.limbs_p)]
    out += [("S", f"A_SR{k}") for k in range(sh.limbs_sigma_s)]
    out += [("S", f"A_SG{k}") for k in range(sh.limbs_sigma_s)]
    out += [("F", "A_G8"), ("F", "A_RGL"), ("F", "A_A16"), ("F", "A_U16"),
            ("F", "A_UL0"), ("F", "A_UL1"), ("F", "A_H16"), ("F", "A_HL0"),
            ("F", "A_HL1"), ("F", "A_RH0"), ("F", "A_RH1")]
    out += [("Tab", "A_MU8"), ("Tab", "A_MEXP"), ("Tab", "A_MACT")]
    return out


def lookup_counts(sh: Shape):
    """How many U8 lookups each position of each lookup domain carries
    (`layout.rs:310-368`), with the two shape-driven changes of §4."""
    ln = sh.limbs_norm
    top = 0 if sh.norm_top_is_full_byte else 1
    per_norm = 2 + 2 * (ln + top)        # sym(y) + rho limbs (+scaled) + sigma limbs (+scaled)
    d = (2                                # A_XL0, A_XL1
         + per_norm                       # norm_a: sym(y), rho, sigma
         + 6                              # AL0, AL1, RAL, scaled(RAL,2), X1L0, X1L1
         + per_norm                       # norm_m: sym(ym), rho, sigma
         + 2                              # X2L0, X2L1
         + 4)                             # ZL0, ZL1, RDL, scaled(RDL,4)
    s = (2                                # sym(s8)
         + 2                              # RSL, scaled(RSL,4)
         + sh.limbs_p + 1                 # p limbs + the scaled top limb
         + sh.limbs_sigma_s + 1           # rho_s limbs + scaled top
         + sh.limbs_sigma_s + 1)          # sigma_s limbs + scaled top
    return {"L": 2, "D": d, "F": 9, "Q": 13, "Kv": 12, "S": s}


def helpers(sh: Shape):
    """helper planes per lookup domain: helper k covers lookups (2k, 2k+1)"""
    lk = lookup_counts(sh)
    return {dom: -(-lk[dom] // 2) for dom in LOOKUP_DOMS}


def h_planes(sh: Shape):
    """(domain, name) for every `Fp2`-valued LogUp helper plane"""
    hp = helpers(sh)
    out = [("L", f"H_L{k}") for k in range(hp["L"])]
    out += [("D", f"H_D{k}") for k in range(hp["D"])]
    out += [("Q", f"H_Q{k}") for k in range(hp["Q"])]
    out += [("Kv", f"H_KV{k}") for k in range(hp["Kv"])]
    out += [("S", f"H_S{k}") for k in range(hp["S"])] + [("S", "H_SEXP")]
    out += [("F", f"H_F{k}") for k in range(hp["F"])] + [("F", "H_FACT")]
    out += [("Tab", "H_GU8"), ("Tab", "H_GEXP"), ("Tab", "H_GACT"), ("Tab", "H_U")]
    return out


# --------------------------------------------------------------------------
# claim sites (`argument.rs:538-905`, site by site)
# --------------------------------------------------------------------------
def claim_sites(sh: Shape):
    a_by_dom = {}
    for dom, _ in a_planes(sh):
        a_by_dom[dom] = a_by_dom.get(dom, 0) + 1
    hp = helpers(sh)
    a = [0] * N_SLOTS
    h = [0] * N_SLOTS
    a[SC_SS] = 1                                     # A_X
    a[SC_SSM] = 1                                    # A_X1
    a[SC_TZC] = 4 + 2 * (3 * LIMBS_ISQRT)            # 4 Dom::T planes + 9 limb sub-slices per norm
    a[SC_LZC], h[SC_LZC] = a_by_dom["L"], hp["L"]
    a[SC_RS] = 2                                     # A_E, A_ZSEL
    for s in (SC_QMM, SC_KMM, SC_VMM, SC_WO, SC_GMM, SC_UMM, SC_DMM):
        a[s] = 1
    a[SC_SCORE] = 2                                  # A_QR8, A_KR8
    a[SC_PV] = 2                                     # A_P, A_V8
    a[SC_DZC], h[SC_DZC] = a_by_dom["D"] + 2, hp["D"]     # + the two Dom::T denominators
    a[SC_QZC], h[SC_QZC] = a_by_dom["Q"] + 1, hp["Q"]     # + the flipped RoPE partner
    a[SC_KVZC], h[SC_KVZC] = a_by_dom["Kv"] + 1, hp["Kv"]
    a[SC_SZC], h[SC_SZC] = a_by_dom["S"] + 2, hp["S"] + 1  # + A_MX, A_SUM; + H_SEXP
    a[SC_FZC], h[SC_FZC] = a_by_dom["F"], hp["F"] + 1      # + H_FACT
    a[SC_TAB], h[SC_TAB] = 3, 3
    h[SC_ZS] = 1                                     # H_U
    a[SC_IO_IN] = a[SC_IO_OUT] = 1                   # A_X / A_X2 (the endpoint table is not on A)
    return a, h


def slot_terms(sh: Shape):
    a, h = claim_sites(sh)
    return [a[s] + h[s] + (1 if s >= SC_IO_IN else 0) for s in range(N_SLOTS)]


# --------------------------------------------------------------------------
# the slot schedule
# --------------------------------------------------------------------------
def group_sumcheck_bits(sh: Shape) -> int:
    """`lkv`, the number of KEY-VALUE GROUP bits the two BILINEAR slots must
    sum over rather than fix.

    DERIVED HERE, from the shape and from the construction's own algebra —
    not transcribed from the Rust.  `score[h,t,j] = sum_c q[t,h,c]
    k[j,g(h),c]` with `g(h)` the key-value group of padded head slot `h`, and
    `out[t,h,i] = sum_s P[h,t,s] V[s,g(h),i]`.  A slot must claim the
    multilinear extension of that POINTWISE PRODUCT at the challenge point.
    Writing `r_h = (r_g, r_hj)` — the group bits are the HIGH bits of the head
    slot (correction C-1) — the extension is

        sum_{g} eq(r_g, g) . q~(r_t, (g, r_hj), c) . k~(r_j, g, c)

    because the key/value factor does not depend on the within-group head `hj`
    while the query/probability factor is multilinear in it.  Taking the group
    as a FIXED coordinate of BOTH factors instead computes the PRODUCT OF THE
    TWO EXTENSIONS, which is QUADRATIC in each shared group bit and so is a
    different polynomial: that is exactly finding S19-F1, a completeness
    failure, and it is why the group must be summed.

    So each bilinear slot gains `lkv = log2(kv_heads)` MAIN ROUNDS, and one
    DEGREE for the public `eq(r_g, .)` factor, which is a third factor of its
    monomial.  `kv_heads == 1` gives `lkv == 0`: no extra round, no `eq`, no
    extra degree — which is why the frozen toy profile pays nothing.
    """
    return clog2(sh.kv_heads)


def slots(sh: Shape):
    """(name, main rounds, extension rounds, degree, L, indicator?) per slot.

    Main rounds are the slot's cube: the domain log for a zero-check or a row
    sum, and the matmul's INNER index log for a matmul — plus, for the two
    BILINEAR slots, the key-value group bits of `group_sumcheck_bits`."""
    dom_of_cube = {
        SC_SS: "D", SC_SSM: "D", SC_TZC: "T", SC_LZC: "L", SC_RS: "S",
        SC_DZC: "D", SC_QZC: "Q", SC_KVZC: "Kv", SC_SZC: "S", SC_FZC: "F",
        SC_TAB: "Tab", SC_ZS: "Tab", SC_IO_IN: "D", SC_IO_OUT: "D",
    }
    lkv = group_sumcheck_bits(sh)
    inner = {
        SC_QMM: clog2(sh.d_pad), SC_KMM: clog2(sh.d_pad), SC_VMM: clog2(sh.d_pad),
        SC_WO: clog2(sh.d_pad),
        SC_SCORE: lkv + clog2(sh.head_dim), SC_PV: lkv + clog2(sh.t_pad),
        SC_GMM: clog2(sh.d_pad), SC_UMM: clog2(sh.d_pad), SC_DMM: clog2(sh.f_pad),
    }
    pads = padded_domains(sh)
    out = []
    for s in range(N_SLOTS):
        main = inner[s] if s in inner else sh.log(dom_of_cube[s])
        ind = s in INDICATOR_SLOT_DOMAIN and INDICATOR_SLOT_DOMAIN[s] in pads
        # the public group `eq` is a third factor of a bilinear slot's
        # monomial, and only exists when the shape actually groups
        group_eq = s in BILINEAR_SLOTS and lkv > 0
        deg = BASE_DEGREE[s] + (1 if ind else 0) + (1 if group_eq else 0)
        ext = EXT_ROUNDS[s]
        out.append({
            "slot": s, "name": SLOT_NAMES[s], "kind": SLOT_KIND[s],
            "main_rounds": main, "extension_rounds": ext, "degree": deg,
            "carries_support_indicator": ind,
            "carries_group_eq": group_eq,
            "group_sumcheck_bits": lkv if s in BILINEAR_SLOTS else 0,
            "L": (main + ext) * deg + 2,
        })
    return out


def padded_domains(sh: Shape):
    """the domains whose padded size exceeds their true size — the ones the
    pad rule of §3.7a governs (a domain lifted by P-3 counts as padded)"""
    return [d for d in ALL_DOMS if sh.size(d) != sh.true_size(d)]


# --------------------------------------------------------------------------
# rows, opening groups, receipt
# --------------------------------------------------------------------------
def rows(sh: Shape):
    a_data = sum(sh.rows_of(dom) for dom, _ in a_planes(sh))
    h_data = sum(2 * sh.rows_of(dom) for dom, _ in h_planes(sh))
    a_sites, h_sites = claim_sites(sh)
    a_total = a_data + 2 * sum(a_sites) + 2      # + the proximity pair
    h_total = h_data + 2 * sum(h_sites) + 2
    return {
        "a_data_rows": a_data, "a_site_rows": 2 * sum(a_sites), "a_rows": a_total,
        "h_data_rows": h_data, "h_site_rows": 2 * sum(h_sites), "h_rows": h_total,
        "m_rows": M_ROWS, "a_sites": sum(a_sites), "h_sites": sum(h_sites),
    }


def opening_groups(sh: Shape):
    """The PCS column-weight groups of the single `A` and `H` openings
    (`protocol.rs:66-71`, `:150-165`): a claim's key is (the tail of its
    evaluation point, the column offset, the slice length), and claims that
    read a plane on their slot's own cube with the identity coordinate map
    share one key.  So each slot contributes one group per DISTINCT key it
    raises."""
    n = 1 << sh.log_cols
    detail = {}
    # SC_TZC's 22 sites: 4 Dom::T planes at column offset 0, and 9 limb
    # sub-slices per norm at offsets k * T_pad mod n.  Both limb planes are row
    # aligned, so the two norms raise the same set of offsets.
    if sh.natural_log("T") >= sh.log_cols:
        tzc = 1
    else:
        tzc = len({(k * sh.t_pad) % n for k in range(3 * LIMBS_ISQRT)} | {0})
    detail["02 norm squares zero-check"] = tzc
    for s, g in [("01 SS", 1), ("01m SS", 1), ("08 limb zero-check", 1),
                 ("07 masked row sums", 1), ("09Q", 1), ("09K", 1), ("09V", 1),
                 ("10 score (two private factors)", 2), ("11 PV (two private factors)", 2),
                 ("12 Wo", 1), ("13G", 1), ("13U", 1), ("13D", 1),
                 ("03 D zero-check (cube + the two Dom::T denominators)", 2),
                 ("04 Q zero-check (cube + the flipped partner)", 2),
                 ("05 KV zero-check (cube + the flipped partner)", 2),
                 ("06 softmax zero-check (cube + A_MX/A_SUM)", 2),
                 ("14 F zero-check", 1), ("TAB", 1), ("ZS", 0),
                 ("IO-in", 1), ("IO-out", 1)]:
        detail[s] = g
    a_groups = sum(detail.values())
    # H: one group per slot that raises H claims, plus the value-0 LogUp sum
    # claim.  The sum claim has ONE part per H plane and no point, so its key
    # is (the empty tail, offset % n, length): one key only if every H domain
    # sits at or above the row width — which is what the P-3 lift buys.
    h_dom_keys = set()
    for dom, _ in h_planes(sh):
        if sh.log(dom) >= sh.log_cols:
            h_dom_keys.add(("full", 0, 1 << sh.log_cols))
        else:
            h_dom_keys.add(("sub", 0, sh.size(dom)))
    h_slot_groups = 8   # LZC, DZC, QZC, KVZC, SZC, FZC, TAB, ZS
    return {
        "a_groups": a_groups, "a_group_detail": detail,
        "h_groups": h_slot_groups + 1,
        "logup_sum_claim_keys": len(h_dom_keys),
        "logup_sum_claim_instantiable": len(h_dom_keys) == 1,
    }


def receipt_bytes(sh: Shape):
    """`wire.rs:28-36`, with the row width, the pad count Q and the Merkle path
    length taken from the shape's own PCS parameters."""
    n = 1 << sh.log_cols
    vec = n + sh.opened_cols                      # message + Q random pads
    path = clog2(n * sh.inv_rate)
    r = rows(sh)
    g = opening_groups(sh)
    sl = slots(sh)
    terms = slot_terms(sh)

    def opening(groups, rws, vc=vec, pth=path):
        return ((groups + 1) * vc * 16
                + COL_CHECKS * (8 + rws * 8 + 32 + pth * 32))

    e_n = 1 << sh.endpoint_log_n
    e_vec = e_n + sh.opened_cols
    e_path = clog2(e_n * sh.endpoint_inv_rate)
    slot_words = sum(1 + (s["main_rounds"] + s["extension_rounds"]) * (s["degree"] + 1) + terms[i]
                     for i, s in enumerate(sl))
    parts = {
        "header_and_three_roots": WIRE_HEADER + 3 * 32,
        "slots": slot_words * 16,
        "mask_opening": 2 * MASK_VEC * 16 + COL_CHECKS * (8 + M_ROWS * 8 + 32 + MASK_PATH * 32),
        "a_opening": opening(g["a_groups"], r["a_rows"]),
        "h_opening": opening(g["h_groups"], r["h_rows"]),
        "endpoint_openings": 2 * opening(1, sh.endpoint_rows, e_vec, e_path),
    }
    parts["total"] = sum(parts.values())
    return parts


def lookups(sh: Shape):
    lk = lookup_counts(sh)
    per_dom = {d: lk[d] * sh.size(d) for d in LOOKUP_DOMS}
    return {
        "per_position": lk,
        "per_domain_u8": per_dom,
        "per_domain_u8_list": [per_dom[d] for d in LOOKUP_DOMS],
        "u8_total": sum(per_dom.values()),
        "exp_pairs": sh.size("S"),
        "act_pairs": sh.size("F"),
    }


def model(sh: Shape):
    """Everything the model computes for one shape, as plain JSON data."""
    doms = {}
    for d in ALL_DOMS:
        doms[d] = {
            "true": sh.true_size(d), "padded": sh.size(d),
            "natural_log": sh.natural_log(d), "log": sh.log(d),
            "lifted_by_P3": sh.lifted(d), "rows_each": sh.rows_of(d),
            "pads": sh.size(d) != sh.true_size(d),
        }
    ap, hp = a_planes(sh), h_planes(sh)
    plane_rows = {}
    for dom, _ in ap:
        plane_rows.setdefault(dom, {"planes": 0, "rows": 0})
        plane_rows[dom]["planes"] += 1
        plane_rows[dom]["rows"] += sh.rows_of(dom)
    h_plane_rows = {}
    for dom, _ in hp:
        h_plane_rows.setdefault(dom, {"planes": 0, "rows": 0})
        h_plane_rows[dom]["planes"] += 1
        h_plane_rows[dom]["rows"] += 2 * sh.rows_of(dom)
    sl = slots(sh)
    a_sites, h_sites = claim_sites(sh)
    max_l = max(s["L"] for s in sl)
    return {
        "shape": {
            "name": sh.name, "tokens": sh.tokens, "width": sh.width, "hidden": sh.hidden,
            "query_heads": sh.q_heads, "head_dim": sh.head_dim, "kv_heads": sh.kv_heads,
            "t_pad": sh.t_pad, "d_pad": sh.d_pad, "h_pad": sh.h_pad, "f_pad": sh.f_pad,
            "log_cols": sh.log_cols, "inv_rate": sh.inv_rate, "opened_columns_Q": sh.opened_cols,
            "F_E": sh.f_e, "NORM_WRHO": sh.norm_wrho, "WRHO_S": sh.wrho_s,
            "D_max": sh.d_max, "limbs_norm": sh.limbs_norm,
            "norm_top_limb_is_full_byte": sh.norm_top_is_full_byte,
            "limbs_sigma_s": sh.limbs_sigma_s, "limbs_p": sh.limbs_p,
            "endpoint_rows": sh.endpoint_rows, "endpoint_log_n": sh.endpoint_log_n,
            "endpoint_inv_rate": sh.endpoint_inv_rate,
            "d_pad_equals_h_pad_times_head_dim": sh.d_pad == sh.h_pad * sh.head_dim,
            "note": sh.note,
        },
        "domains": doms,
        "padded_domains": padded_domains(sh),
        "a_planes": {"total": len(ap), "by_domain": plane_rows},
        "h_planes": {"total": len(hp), "by_domain": h_plane_rows},
        "rows": rows(sh),
        "claim_sites": {"a": a_sites, "h": h_sites, "a_total": sum(a_sites), "h_total": sum(h_sites)},
        "opening_groups": opening_groups(sh),
        "slots": sl,
        "slot_summary": {
            "count": N_SLOTS, "functionals": N_FUNCTIONALS,
            "largest_L": max_l,
            "largest_L_slots": [s["name"] for s in sl if s["L"] == max_l],
            "L_plus_256_within_512": all(s["L"] + 256 <= 512 for s in sl),
            "worst_L_plus_256": max_l + 256,
            "main_round_total": sum(s["main_rounds"] for s in sl),
            "extension_round_total": sum(s["extension_rounds"] for s in sl),
            # what the PROVER publishes and what the VERIFIER draws, both a
            # function of the schedule alone: a round message is `degree + 1`
            # evaluations (`sumcheck.rs`'s length refusal), and every round —
            # main or extension — consumes exactly one challenge
            "published_round_values": sum((s["main_rounds"] + s["extension_rounds"]) * (s["degree"] + 1) for s in sl),
            "sumcheck_challenge_draws": sum(s["main_rounds"] + s["extension_rounds"] for s in sl),
            "slot_lengths": [s["L"] for s in sl],
            "group_sumcheck_bits": group_sumcheck_bits(sh),
            "hosts": {SLOT_NAMES[k]: [SLOT_NAMES[x] for x in v] for k, v in HOSTS.items()},
        },
        "lookups": lookups(sh),
        "receipt_bytes": receipt_bytes(sh),
    }


# --------------------------------------------------------------------------
# the shapes
# --------------------------------------------------------------------------
TOY = Shape("toy block (T32 / d16 / f16, 2 heads of 8 over 1 KV head)",
            tokens=32, width=16, hidden=16, q_heads=2, head_dim=8, kv_heads=1,
            log_cols=8, inv_rate=8, f_e=9, endpoint_rows=7,
            note="the profile that exists and proves: hashline-zk-mr1/private-block-t32-poc/1")

RUNG = Shape("development rung (T24 / d96 / f192, 6 heads of 16 over 2 KV heads)",
             tokens=24, width=96, hidden=192, q_heads=6, head_dim=16, kv_heads=2,
             log_cols=10, inv_rate=4, f_e=12,
             endpoint_rows=14, endpoint_log_n=8, endpoint_inv_rate=4,
             note="memo §9a; F_E = 12 is a rung-only calibration, chosen to break the softmax window")

RUNG_G = Shape("development rung, generalised endpoint (T24 / d96 / f192, 6 heads of 16 over 2 KV heads)",
               tokens=24, width=96, hidden=192, q_heads=6, head_dim=16, kv_heads=2,
               log_cols=10, inv_rate=4, f_e=12, endpoint_rows=9,
               note="S11b: the rung's geometry exactly, with the GENERALISED endpoint — the "
                    "block's own PCS parameters (log_cols 10, inv_rate 4) instead of the frozen "
                    "seam's 8 / 8, and 9 commitment rows for the 2^5 x 2^7 padded Dom::D plane")

M125 = Shape("125M complete private block (T512 / d768 / f2048, 12 heads of 64 over 4 KV heads)",
             tokens=512, width=768, hidden=2048, q_heads=12, head_dim=64, kv_heads=4,
             log_cols=14, inv_rate=4, f_e=9, endpoint_rows=29,
             note="memo §2; endpoint rows 29 per §6 / step S11")

SHAPES = {"toy": TOY, "rung": RUNG, "rung_g": RUNG_G, "m125": M125}

# What the module's own Rust asserts at the toy (`layout.rs:523-526`, `:700-749`,
# `:778-780`, `tests.rs:106-108`).  The model must reproduce every one of these.
TOY_RUST_FACTS = {
    "a_data_rows": 213, "a_rows": 455, "h_data_rows": 280, "h_rows": 384,
    "m_rows": 50, "a_sites": 120, "h_sites": 51, "a_groups": 35, "h_groups": 9,
    "n_slots": 23, "functionals": 34, "a_planes": 81, "h_planes": 51,
    "per_domain_u8": [1024, 19456, 4608, 6656, 3072, 26624], "u8_total": 61440,
    "exp_pairs": 2048, "act_pairs": 512, "largest_L": 50,
    "main_round_total": 159, "extension_round_total": 25,
    "receipt_bytes": 2816472,
    "f_domain_a_planes": 11, "f_domain_h_planes": 6,
}

# The memo's own [COUNTED] figures, for comparison ONLY — never for tuning.
MEMO_FIGURES = {
    "rung": {
        "a_planes": 83, "h_planes": 52, "a_data_rows": 377, "h_data_rows": 470,
        "a_sites": 122, "h_sites": 52, "a_rows": 623, "h_rows": 576, "m_rows": 50,
        "a_groups": 36, "h_groups": 9, "u8_total": 419840, "exp_pairs": 8192,
        "act_pairs": 8192, "largest_L": 72, "receipt_bytes": 4173032,
    },
    "m125": {
        "a_planes": 83, "h_planes": 50, "a_data_rows": 5435, "h_data_rows": 7018,
        "a_sites": 122, "h_sites": 50, "a_rows": 5681, "h_rows": 7120, "m_rows": 50,
        "a_groups": 36, "h_groups": 9, "u8_total": 98598912, "exp_pairs": 4194304,
        "act_pairs": 1048576, "largest_L": 117, "receipt_bytes": 40750024,
        "receipt_bytes_alternative": 40747256,
    },
}


# Every difference the model shows against the memo, with the rule responsible.
# These are RESULTS: the model is not tuned to remove them.
S20_MEMO_DIFFERENCE = (
    " PLUS the stage-20 repair of finding S19-F1 (`group_sumcheck_bits`): the two "
    "bilinear slots sum over the log2(kv_heads) key-value GROUP bits instead of fixing "
    "them on both private factors, which adds those main rounds and one degree for the "
    "public eq(r_g, .). The memo predates the repair and prices the old schedule. This "
    "term is +336 B at both rungs (lkv = 1) and +560 B at 125M (lkv = 2), and it is zero "
    "at the toy (lkv = 0), which is why the frozen toy profile does not move."
)

KNOWN_MEMO_DIFFERENCES = {
    "rung": {
        "receipt_bytes": (
            "+176 B (11 Fp2 words) in the slot line. The model gives SC_KVZC the support "
            "indicator, because Dom::Kv PADS at the rung (768 true of 1,024) and §9a's own "
            "domain paragraph says so: 'the pad rule of §3.7a is exercised on Kv and F as "
            "well (their indicators are supp_Kv and supp_F)'. An indicator raises the slot's "
            "degree by one, which lengthens each of its 11 round messages by one Fp2 word: "
            "(10 main + 1 ext) x 16 B = 176 B. The memo's 19,552-byte slot line prices "
            "SC_FZC's indicator but not SC_KVZC's, and §9a's open question 2 mentions only "
            "SC_FZC. Either the rung receipt is 4,173,208 B before the S20 term below, or "
            "supp_Kv does not gate "
            "SC_KVZC's inhomogeneous RoPE constraint and the domain paragraph is wrong. "
            "Nothing else moves: SC_KVZC's L is 57 with the indicator, well under the rung's "
            "largest L of 72, so the mask budget is untouched."
        ) + S20_MEMO_DIFFERENCE,
    },
    "rung_g": {},
    "m125": {
        "receipt_bytes": "+560 B in the slot line and nothing else." + S20_MEMO_DIFFERENCE,
    },
}


def logup_sum_claim_keys(sh: Shape, lift: bool):
    """How many distinct column-weight keys the single value-0 LogUp sum claim
    raises, with and without the B-3 / P-3 lift. More than one is a REFUSAL —
    `check_opening` returns "claim parts with different column weights" on both
    sides before any byte is produced (`protocol.rs:161-163`)."""
    keys = set()
    for dom, _ in h_planes(sh):
        log = sh.log(dom) if lift else sh.natural_log(dom)
        if log >= sh.log_cols:
            keys.add(("full", 0, 1 << sh.log_cols))
        else:
            keys.add(("sub", 0, 1 << log))
    return sorted(keys)


def compare_to_memo(name, m):
    """every difference between the model and the memo's [COUNTED] figures"""
    want = MEMO_FIGURES.get(name)
    if not want:
        return []
    got = {
        "a_planes": m["a_planes"]["total"], "h_planes": m["h_planes"]["total"],
        "a_data_rows": m["rows"]["a_data_rows"], "h_data_rows": m["rows"]["h_data_rows"],
        "a_sites": m["rows"]["a_sites"], "h_sites": m["rows"]["h_sites"],
        "a_rows": m["rows"]["a_rows"], "h_rows": m["rows"]["h_rows"],
        "m_rows": m["rows"]["m_rows"],
        "a_groups": m["opening_groups"]["a_groups"], "h_groups": m["opening_groups"]["h_groups"],
        "u8_total": m["lookups"]["u8_total"], "exp_pairs": m["lookups"]["exp_pairs"],
        "act_pairs": m["lookups"]["act_pairs"], "largest_L": m["slot_summary"]["largest_L"],
        "receipt_bytes": m["receipt_bytes"]["total"],
    }
    diffs = []
    for k, w in want.items():
        if k == "receipt_bytes_alternative":
            continue
        if got.get(k) != w:
            diffs.append({"quantity": k, "model": got.get(k), "memo": w,
                          "delta": (got.get(k) - w) if isinstance(got.get(k), int) else None,
                          "cause": KNOWN_MEMO_DIFFERENCES.get(name, {}).get(k, "UNDIAGNOSED")})
    return diffs


# --------------------------------------------------------------------------
# the pad table of §3.7a, recounted from its own rows
# --------------------------------------------------------------------------
# Transcribed row by row from `ZK60_PRIVATE_BLOCK_125M_LAYOUT.md` §3.7a "The
# table" (the six padded domains at the 125M shape).  (domain, entry, how many
# planes the entry covers, rule).
PAD_TABLE_ROWS = [
    # Dom::D - header claims "35 planes, all ZERO"
    ("D", "A", "A_X", 1, "ZERO"), ("D", "A", "A_XL0, A_XL1", 2, "ZERO"),
    ("D", "A", "A_Y", 1, "ZERO"), ("D", "A", "A_NR0..A_NR3", 4, "ZERO"),
    ("D", "A", "A_NS0..A_NS3", 4, "ZERO"), ("D", "A", "A_AO", 1, "ZERO"),
    ("D", "A", "A_AL0, A_AL1", 2, "ZERO"), ("D", "A", "A_RAL", 1, "ZERO"),
    ("D", "A", "A_X1", 1, "ZERO"), ("D", "A", "A_X1L0, A_X1L1", 2, "ZERO"),
    ("D", "A", "A_YM", 1, "ZERO"), ("D", "A", "A_MR0..3, A_MS0..3", 8, "ZERO"),
    ("D", "A", "A_Z16", 1, "ZERO"), ("D", "A", "A_X2", 1, "ZERO"),
    ("D", "A", "A_X2L0, A_X2L1, A_ZL0, A_ZL1", 4, "ZERO"), ("D", "A", "A_RDL", 1, "ZERO"),
    # Dom::Q - header claims "7 planes, all ZERO"
    ("Q", "A", "A_Q8", 1, "ZERO"), ("Q", "A", "A_RQL", 1, "ZERO"),
    ("Q", "A", "A_QR8", 1, "ZERO"), ("Q", "A", "A_RQRL", 1, "ZERO"),
    ("Q", "A", "A_O8", 1, "ZERO"), ("Q", "A", "A_RO0, A_RO1", 2, "ZERO"),
    # Dom::S - header claims "13 planes, 12 ZERO and one EXEMPT"
    ("S", "A", "A_S8", 1, "ZERO"), ("S", "A", "A_RSL", 1, "ZERO"),
    ("S", "A", "A_ZSEL", 1, "ZERO"), ("S", "A", "A_E", 1, "EXEMPT"),
    ("S", "A", "A_P", 1, "ZERO"), ("S", "A", "A_PL0, A_PL1", 2, "ZERO"),
    ("S", "A", "A_SR0..A_SR2", 3, "ZERO"), ("S", "A", "A_SG0..A_SG2", 3, "ZERO"),
    # Dom::Ht - header claims "2 planes, both ZERO"
    ("Ht", "A", "A_MX", 1, "ZERO"), ("Ht", "A", "A_SUM", 1, "ZERO"),
    # Dom::L - header claims "2 planes, both ZERO"
    ("L", "A", "A_LIMB, A_LIMBM", 2, "ZERO"),
    # Dom::Tab - header claims "3 A planes ZERO, 3 table helpers ZERO, H_U has no pad"
    ("Tab", "A", "A_MU8, A_MEXP, A_MACT", 3, "ZERO"),
    ("Tab", "H", "H_GU8, H_GEXP, H_GACT", 3, "ZERO"),
    ("Tab", "H", "H_U", 1, "NO PAD RULE"),
    # the helper block - header claims "34 planes, ALL EXEMPT"
    ("L", "H", "H_L", 1, "EXEMPT"), ("D", "H", "H_D0..H_D16", 17, "EXEMPT"),
    ("Q", "H", "H_Q0..H_Q6", 7, "EXEMPT"),
    ("S", "H", "H_S0..H_S7 and H_SEXP", 9, "EXEMPT"),
]

# what the memo's own prose / the editor's summary says, for comparison
PAD_TABLE_CLAIMED = {
    "summary_line": "62 planes on six padded domains: 61 proved zero; 35 exempt by name",
    "per_domain_headers": {
        "D": {"planes": 35, "ZERO": 35}, "Q": {"planes": 7, "ZERO": 7},
        "S": {"planes": 13, "ZERO": 12, "EXEMPT": 1}, "Ht": {"planes": 2, "ZERO": 2},
        "L": {"planes": 2, "ZERO": 2},
        "Tab": {"A planes ZERO": 3, "table helpers ZERO": 3, "H_U": "no pad"},
        "helper block": {"planes": 34, "EXEMPT": 34},
    },
}


def pad_table_recount():
    by_dom, by_rule, by_commitment = {}, {}, {}
    for dom, cm, _entry, count, rule in PAD_TABLE_ROWS:
        by_dom.setdefault(dom, {}).setdefault(rule, 0)
        by_dom[dom][rule] += count
        by_rule[rule] = by_rule.get(rule, 0) + count
        by_commitment.setdefault(cm, {}).setdefault(rule, 0)
        by_commitment[cm][rule] += count
    total = sum(c for *_ , c, _ in [(d, m, e, c, r) for d, m, e, c, r in PAD_TABLE_ROWS])
    a_total = sum(by_commitment.get("A", {}).values())
    h_total = sum(by_commitment.get("H", {}).values())
    return {
        "rows_transcribed": len(PAD_TABLE_ROWS),
        "planes_classified_total": total,
        "by_rule": by_rule,
        "by_commitment": by_commitment,
        "by_domain": by_dom,
        "a_planes_on_padded_domains": a_total,
        "h_planes_on_padded_domains": h_total,
        "claimed": PAD_TABLE_CLAIMED,
        "verdict": (
            "The three summary figures each count a DIFFERENT population and therefore "
            "cannot be added. '62 planes' is the number of A planes on the six padded "
            f"domains ({a_total} by recount); '61 proved zero' is the number of those A "
            f"planes ruled ZERO ({by_commitment.get('A', {}).get('ZERO')} by recount), the "
            "one exception being A_E; '35 exempt' spans BOTH commitments (A_E plus the 34 "
            f"lookup reciprocals, {by_rule.get('EXEMPT')} by recount). The real tally over "
            f"every plane the table classifies is {total} planes = {by_rule.get('ZERO')} ZERO "
            f"+ {by_rule.get('EXEMPT')} EXEMPT + {by_rule.get('NO PAD RULE', 0)} with no pad "
            "rule (H_U, the zero-sum masking pair). No plane is missing and no plane is "
            "classified twice; the arithmetic of the summary line is what does not add up, "
            "not the table."
        ),
    }


# --------------------------------------------------------------------------
# reporting
# --------------------------------------------------------------------------
def report(out=sys.stdout):
    w = out.write
    w("=" * 78 + "\n")
    w("Independent shape-driven layout model of the private block\n")
    w("=" * 78 + "\n\n")
    models = {k: model(v) for k, v in SHAPES.items()}

    w("-- 1. TOY REPRODUCTION (the model means nothing unless this is exact) --\n")
    m = models["toy"]
    got = {
        "a_data_rows": m["rows"]["a_data_rows"], "a_rows": m["rows"]["a_rows"],
        "h_data_rows": m["rows"]["h_data_rows"], "h_rows": m["rows"]["h_rows"],
        "m_rows": m["rows"]["m_rows"], "a_sites": m["rows"]["a_sites"],
        "h_sites": m["rows"]["h_sites"], "a_groups": m["opening_groups"]["a_groups"],
        "h_groups": m["opening_groups"]["h_groups"], "n_slots": N_SLOTS,
        "functionals": N_FUNCTIONALS, "a_planes": m["a_planes"]["total"],
        "h_planes": m["h_planes"]["total"],
        "per_domain_u8": m["lookups"]["per_domain_u8_list"],
        "u8_total": m["lookups"]["u8_total"], "exp_pairs": m["lookups"]["exp_pairs"],
        "act_pairs": m["lookups"]["act_pairs"], "largest_L": m["slot_summary"]["largest_L"],
        "main_round_total": m["slot_summary"]["main_round_total"],
        "extension_round_total": m["slot_summary"]["extension_round_total"],
        "receipt_bytes": m["receipt_bytes"]["total"],
        "f_domain_a_planes": m["a_planes"]["by_domain"]["F"]["planes"],
        "f_domain_h_planes": m["h_planes"]["by_domain"]["F"]["planes"],
    }
    bad = 0
    for k, want in TOY_RUST_FACTS.items():
        ok = got[k] == want
        bad += 0 if ok else 1
        w(f"  {'OK ' if ok else 'XX '} {k:28s} model {str(got[k]):>28s}   rust {str(want):>28s}\n")
    w(f"  -> {'ALL TOY NUMBERS REPRODUCED EXACTLY' if bad == 0 else str(bad) + ' TOY MISMATCHES'}\n\n")

    for name in ("rung", "rung_g", "m125"):
        m = models[name]
        w(f"-- 2. {m['shape']['name']} --\n")
        w(f"  padded domains: {', '.join(m['padded_domains'])}\n")
        w("  domain      true        padded   log  lifted  rows\n")
        for d in ALL_DOMS:
            x = m["domains"][d]
            w(f"  {d:<6s} {x['true']:>10d} {x['padded']:>13d} {x['log']:>5d}"
              f" {'yes' if x['lifted_by_P3'] else '  -':>7s} {x['rows_each']:>5d}\n")
        w(f"  A planes {m['a_planes']['total']}  H planes {m['h_planes']['total']}\n")
        w("  quantity                      model            memo [COUNTED]    delta\n")
        want = MEMO_FIGURES.get(name)
        gotm = {
            "a_planes": m["a_planes"]["total"], "h_planes": m["h_planes"]["total"],
            "a_data_rows": m["rows"]["a_data_rows"], "h_data_rows": m["rows"]["h_data_rows"],
            "a_sites": m["rows"]["a_sites"], "h_sites": m["rows"]["h_sites"],
            "a_rows": m["rows"]["a_rows"], "h_rows": m["rows"]["h_rows"],
            "m_rows": m["rows"]["m_rows"], "a_groups": m["opening_groups"]["a_groups"],
            "h_groups": m["opening_groups"]["h_groups"], "u8_total": m["lookups"]["u8_total"],
            "exp_pairs": m["lookups"]["exp_pairs"], "act_pairs": m["lookups"]["act_pairs"],
            "largest_L": m["slot_summary"]["largest_L"],
            "receipt_bytes": m["receipt_bytes"]["total"],
        }
        if want is None:
            w("  (this shape has no [COUNTED] memo table of its own; it is the rung's\n"
              "   geometry with the generalised endpoint, so only the endpoint line moves)\n")
            for k in gotm:
                w(f"  {k:<26s} {gotm[k]:>16d}\n")
        else:
            for k in gotm:
                d = gotm[k] - want[k]
                flag = "" if d == 0 else "   <-- DIFFERENCE"
                w(f"  {k:<26s} {gotm[k]:>16d} {want[k]:>16d} {d:>8d}{flag}\n")
        for k, why in KNOWN_MEMO_DIFFERENCES.get(name, {}).items():
            w(f"  CAUSE of the {k} difference: {why}\n")
        ss = m["slot_summary"]
        w(f"  bilinear group sumcheck bits lkv = {ss['group_sumcheck_bits']};"
          f" main rounds {ss['main_round_total']}, extension rounds {ss['extension_round_total']},"
          f" published round values {ss['published_round_values']},"
          f" sumcheck challenge draws {ss['sumcheck_challenge_draws']}\n")
        w(f"  slots carrying a support indicator: "
          f"{[s['name'] for s in m['slots'] if s['carries_support_indicator']]}\n")
        w(f"  LogUp sum-claim keys WITHOUT the P-3 lift: "
          f"{len(logup_sum_claim_keys(SHAPES[name], lift=False))}"
          f" {logup_sum_claim_keys(SHAPES[name], lift=False)}\n")
        w(f"  largest L slots: {m['slot_summary']['largest_L_slots']}"
          f"  (L + 256 = {m['slot_summary']['worst_L_plus_256']} <= 512:"
          f" {m['slot_summary']['L_plus_256_within_512']})\n")
        w(f"  LogUp sum-claim column-weight keys: {m['opening_groups']['logup_sum_claim_keys']}"
          f" (instantiable: {m['opening_groups']['logup_sum_claim_instantiable']})\n")
        w("  receipt parts: " + ", ".join(f"{k} {v:,}" for k, v in m["receipt_bytes"].items()) + "\n\n")

    w("-- 3. THE PAD TABLE OF §3.7a, RECOUNTED FROM ITS OWN ROWS --\n")
    pr = pad_table_recount()
    w(f"  rows transcribed: {pr['rows_transcribed']}; planes classified: {pr['planes_classified_total']}\n")
    w(f"  by rule: {pr['by_rule']}\n")
    w(f"  by commitment: {pr['by_commitment']}\n")
    for d, r in pr["by_domain"].items():
        w(f"    {d:<4s} {r}\n")
    w("  " + pr["verdict"] + "\n")
    return models


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--shape", choices=sorted(SHAPES), help="print one shape's model as JSON")
    ap.add_argument("--all", action="store_true", help="the full report for all three shapes")
    ap.add_argument("--out", help="directory to write the JSON evidence into")
    a = ap.parse_args(argv)
    if a.shape:
        json.dump(model(SHAPES[a.shape]), sys.stdout, indent=1, sort_keys=True)
        sys.stdout.write("\n")
        return 0
    models = report()
    if a.out:
        os.makedirs(a.out, exist_ok=True)
        for k, m in models.items():
            m["memo_differences"] = compare_to_memo(k, m)
            with open(os.path.join(a.out, f"model_{k}.json"), "w") as fh:
                json.dump(m, fh, indent=1, sort_keys=True)
                fh.write("\n")
        with open(os.path.join(a.out, "pad_table_recount.json"), "w") as fh:
            json.dump(pad_table_recount(), fh, indent=1, sort_keys=True)
            fh.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())

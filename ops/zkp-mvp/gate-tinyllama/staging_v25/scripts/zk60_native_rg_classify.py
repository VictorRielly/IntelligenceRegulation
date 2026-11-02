#!/usr/bin/env python3
"""[GATE ROUND 16, tools v19, 2026-10-21] The CLASSIFIER profile family
(D38 / D40 / D41; `results/zk60_token_io_r1_20261017/classifier/
DESIGN_CLASSIFIER.md` v2) for the privacy gate: its geometry, re-derived
from public parameters; what the gate EXPECTS a classifier receipt to
disclose; D40's recount of D34's input-dependent refusal term; and D41's
chunk split and label rule, re-derived.

READ (pre-freeze) on the token lane's working copy at manifest_r12B (list
sha256 edbffc75...), the rung R-C1 tree:

    token_io/classify.rs     dd31955296cb...   (profile, door, statement, chunks)
    token_io/stage_in_c.rs   7bc3c30b5f20...   (stage IN-C)
    token_io/stage_out_c.rs  46cb695192cf...   (stage OUT-C)
    token_io/classify_run.rs 56fcccef9738...   (the run)

Line numbers below refer to those digests.  When R-C1 freezes, every digest
is checked again (`zk60_native_rg_classpins.py`); a moved digest has no
reading and is refused.

WHAT R-C1 BUILDS, IN THE GATE'S TERMS [READ]

* **Stage IN-C** = stage IN (4 slots, A {tok, mult}, H {h_q, h_tab, u}, A 3 /
  H 4 opening groups) plus two PUBLIC columns and one clause:
  - INC-01's query zero-check draws FOUR fresh coefficients (LogUp, BOS,
    TEMPLATE, pad; stage IN drew three) and adds
    `mu2 * pi(t) * (tok(t) - kappa(t))`, with `pi` the public template
    indicator and `kappa` the public template ids (stage_in_c.rs:188-209);
  - the lookup tuple gains a third, public column: the query adds
    `beta^2 * ctl_q(t)` (public: `ctl(kappa(t))` at template positions, 0 at
    content), the table adds `beta^2 * ctl(v)` (stage_in_c.rs:166-170).
  No new commitment, plane or opening group.
* **Stage OUT-C** = stage OUT's final norm, then the MARGIN, with no head,
  no argmax and no output endpoint (stage_out_c.rs:1-24, 74-111):
  - 8 slots: IO-in, SS (private, hosted by TZC), TZC, **PD** (the margin
    `sum_i y(i) w_Delta(i)`, private, hosted by LZC), **LZC** (the limb
    lookups over the WHOLE limb plane, its pad clause, and the HOST TERM
    `nu (g(z) limb(z) + u0(z) (sigma b + c))`), DZC, TAB, ZS;
  - A planes: D, Dsq (To), limb (Lo), x, xl0, xl1, y, rho0-3, sigma0-3 (Do),
    the byte histogram (Tab): 16 planes, **16 opening groups**;
  - H planes: H_LO, six Do helpers, the byte-table helper, u: **5 opening
    groups** (LZC, DZC, TAB, ZS, the LogUp sum claim);
  - the margin limbs `lambda_k` are entries `32 + k` (k < L) of the limb
    plane (LAM_BASE = 32), bytes by LZC's lookup on every entry, zero
    elsewhere by LZC's pad clause; `g(z) = sigma 256^(z - 32)` there;
  - the hosting rule makes `sum_z host(z) = sum_i y(i) w(i)`, i.e. the margin
    identity `Delta = sigma (delta + b) + c`, `delta = sum_k 256^k
    lambda_k` (design §4.2).
* **The run header** absorbs, last before any commitment, `classify-verdict`
  (the public bit) and `classify-chunk` (D41's ChunkRef: index, count,
  a, b, total, size, overlap; u64 LE each) (classify.rs:866-881).
* **One external endpoint** (the input token endpoint); no output endpoint
  (D40); B_in / B_out are the run's boundaries.

[v21, gate round 18, 2026-10-29] RE-READ on token frozen-r14 (manifest
`manifest_final_r14.sha256`, list 0b4c429b..., 258 files; rungs R-C2 + R-C3):

    token_io/classify.rs     6c828db6673e...   (R-C2 margin scale + tied
                                                source in the profile text;
                                                R-C3 short items, pad id,
                                                verdict row)
    token_io/stage_in_c.rs   6a92da0ecfe7...   (INC-01's name; the template
                                                clause covers the pad)
    token_io/stage_out_c.rs  93a79a2b39ab...   (OUTC-00 reads the verdict row)
    token_io/classify_run.rs 5d1d077f5102...   (BoundClassifierTables; the
                                                verdict row in the pipeline)
    token_io/classify_tied.rs 401d38d444b6...  (the tables derived from the
                                                pinned tensor; NEW)

What moved for this module [READ, classify.rs at 6c828db6]:
* a SHORT item (DESIGN v2.4 §15): `1 <= n < T - P0 - S` content ids are ONE
  chunk `[0, n)`; the item is `prefix || content || suffix || pad^(T - P0 -
  n - S)`, the pad a PUBLIC policy id (rung: 2), every pad position a
  template position (`is_template` unchanged: `t >= P0 + n`), `kappa` the
  suffix id on `P0 + n .. P0 + n + S` and the pad id after it
  (classify.rs:512-524); the door admits `P0 + n + S <= T` (:431-433);
* the verdict row is `P0 + n + S - 1` (classify.rs:503-505; `T - 1` without
  pad), read by OUTC-00 (stage_out_c.rs:302);
* the chunk plan's size is `T - P0 - S` (never n; classify.rs:798) and
  `chunk_ranges` returns `[(0, total)]` for `1 <= total < size`, refusing an
  empty content (classify.rs:220-228);
* the profile text adds `item-length= pad-id= pad-positions= verdict-row=`,
  `chunk-size=` is the plan's size, `short-content=one-chunk-of-its-length-
  pad-pinned`, `margin-scale= margin-scale-bits=`, the tied source and the
  D45 rulings sentence (classify.rs:578-622).

NOTHING HERE IS A PRIVACY STATEMENT.
"""

from __future__ import annotations

import json
import math
import os
import sys
from dataclasses import dataclass

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import zk60_native_rg_tokenio as TIO  # noqa: E402
from zk60_native_rg_tokenio import (  # noqa: E402
    LIMBS_ISQRT, NORM_LIMBS, R1_MVP, TO_LOG, U8_LEN, Slot, StageLayout, Tier, clog2,
)

P = (1 << 64) - (1 << 32) + 1

# [READ] classify.rs:281-284
C_MAX = 1 << 33
LAM_BASE = 32
# [READ] classify.rs:524-525
STAGE_IN_C_MAGIC = b"HLPCLIN1"
STAGE_OUT_C_MAGIC = b"HLPCLOT1"
# [READ] classify.rs:879-880 (the last two run-header absorbs, in order)
HEADER_TAIL_LABELS = ("classify-verdict", "classify-chunk")
# [READ] run.rs (manifest_r12B 10cfc2b1) RUN_PROFILE_CLASSIFY_RUNG_TC
RUN_PROFILE_CLASSIFY_RUNG_TC = "hashline-zk-mr1/private-classify-run-rung-tc-t32-public-row-dev/1"
# [READ] classify.rs:166
CHUNK_OVERLAPS = {RUN_PROFILE_CLASSIFY_RUNG_TC: 4}
# [v21, READ classify.rs:137 at r14] the registered policy's PUBLIC pad id per
# classifier run profile (the rung's synthetic policy and every test policy
# cloned from it: 2)
PAD_IDS = {RUN_PROFILE_CLASSIFY_RUNG_TC: 2}

# [v22, gate round 19, READ token frozen-r16b] run.rs:153-154 / :173 (the R13
# classifier run profiles: Shieldstral T128 / T256, and the TEST-ONLY R13 h24
# development rung), classify.rs:280-292 (CHUNK_OVERLAPS 8 at Shieldstral; 4 at
# the test rung, `#[cfg(test)]`), classify.rs:136-235 (the pad ids: the dev
# policy's 2, every Shieldstral category policy's 11)
RUN_PROFILE_CLASSIFY_R13_SHIELD_T128 = "hashline-zk-mr1/private-classify-run-shieldstral-3b-t128-r13-public-row/1"
RUN_PROFILE_CLASSIFY_R13_SHIELD_T256 = "hashline-zk-mr1/private-classify-run-shieldstral-3b-t256-r13-public-row/1"
RUN_PROFILE_CLASSIFY_R13_RUNG_H24_TEST = "hashline-zk-mr1/private-classify-run-rung-lh-t32-public-row-tst/1"
CHUNK_OVERLAPS.update({RUN_PROFILE_CLASSIFY_R13_SHIELD_T128: 8, RUN_PROFILE_CLASSIFY_R13_SHIELD_T256: 8,
                       RUN_PROFILE_CLASSIFY_R13_RUNG_H24_TEST: 4})
PAD_IDS.update({RUN_PROFILE_CLASSIFY_R13_SHIELD_T128: 11, RUN_PROFILE_CLASSIFY_R13_SHIELD_T256: 11,
                RUN_PROFILE_CLASSIFY_R13_RUNG_H24_TEST: 2})
# the R13 block profile each R13 classifier run profile names (run.rs:157-160,
# shape.rs:188-193), and the R13 classifier run profiles (the stage lines
# carry each block stage's gate denominator, classify.rs `stage_lines`)
R13_BLOCK_PROFILE_OF = {RUN_PROFILE_CLASSIFY_R13_SHIELD_T128: "hashline-zk-mr1/private-block-shieldstral-3b-t128-lowh24-blocks/1",
                        RUN_PROFILE_CLASSIFY_R13_SHIELD_T256: "hashline-zk-mr1/private-block-shieldstral-3b-t256-lowh24-blocks/1",
                        RUN_PROFILE_CLASSIFY_R13_RUNG_H24_TEST: "hashline-zk-mr1/private-block-rung-lh-t32-dev/1"}
R13_CLASSIFY_RUN_PROFILES = tuple(R13_BLOCK_PROFILE_OF)
# **THE PRE-REGISTERED SHIELDSTRAL POLICY LIST (D45(2))** at r16b
# (classify.rs:145-235, `registered_policies()` = [dev] + these three; the card
# policy is `#[cfg(test)]` since round 16b, REVIEW_R16 F-1). The prefix ids'
# SHA-256 (u64 LE each) are the round-16 test's pins of Astra's moderate
# templates (classify_r16_tests.rs:70-74); every other field is common.
SHIELDSTRAL_POLICIES = {
    "shieldstral-1.0-3b-moderate-sexual/1": {"p0": 72, "prefix_sha256": "eed4d4c58661672ee6ee9b2f30fe2bbc99282f875f8246dec0d9d2d26d8ab3fd"},
    "shieldstral-1.0-3b-moderate-violence/1": {"p0": 72, "prefix_sha256": "96225c387d6c3d6ccf29827d5ea6889e0be13e68fa0788c9cc7a5edd3aedfba1"},
    "shieldstral-1.0-3b-moderate-hate/1": {"p0": 78, "prefix_sha256": "83ac93e6a103a270205398d4c9bc341ac64b5f48021a963504ac270277329fee"},
}
SHIELDSTRAL_POLICY_COMMON = {"suffix": [4], "yes": 13059, "no": 2649, "c": 0, "pad": 11, "num_special": 1000,
                             "v": 131072, "margin_scale_bits": "0x3ed11ff597db2fb6"}
SHIELDSTRAL_CARD_POLICY = "shieldstral-1.0-3b-card-unsafe/1"   # test-only at r16b; refused here by name


def shieldstral_policy_check(policy: dict) -> list:
    """[v22] a Shieldstral capture's policy against the registered list:
    the id one of the three, its P0 and prefix digest, every common field"""
    import hashlib
    import struct as _st
    f = []
    pid = policy.get("id")
    if pid == SHIELDSTRAL_CARD_POLICY:
        return [f"policy {pid} is round 12's card policy, test-only since r16b (REVIEW_R16 F-1): not registered"]
    want = SHIELDSTRAL_POLICIES.get(pid)
    if want is None:
        return [f"policy {pid!r} is not one of the three registered Shieldstral category policies (D45(2))"]
    pre = list(policy.get("prefix_ids") or [])
    if len(pre) != want["p0"]:
        f.append(f"policy {pid}: P0 {len(pre)}, registered {want['p0']}")
    if hashlib.sha256(b"".join(_st.pack("<Q", int(x)) for x in pre)).hexdigest() != want["prefix_sha256"]:
        f.append(f"policy {pid}: the prefix ids are not the registered template's")
    c = SHIELDSTRAL_POLICY_COMMON
    got = {"suffix": list(policy.get("suffix_ids") or []), "yes": policy.get("yes"), "no": policy.get("no"),
           "c": policy.get("c"), "num_special": policy.get("num_special")}
    for k_, v_ in got.items():
        if v_ != c[k_]:
            f.append(f"policy {pid}: {k_} {v_!r}, registered {c[k_]!r}")
    return f

# [READ] stage_in_c.rs:24-37
INC_A_TOK, INC_A_MULT = 0, 1
INC_H_Q, INC_H_TAB, INC_H_U = 0, 1, 2
SIC_IO, SIC_QZC, SIC_TZC, SIC_ZS = 0, 1, 2, 3
INC_A_GROUPS, INC_H_GROUPS = 3, 4
INC_A_NAMES = ["A_TOK", "A_MULT"]
INC_H_NAMES = ["H_Q", "H_TAB", "H_U"]
INC_NAMES = [
    "INC-00 IO-in: token endpoint = supp_T tok (whole padded plane: template and content)",
    # [v21] r14's name (stage_in_c.rs:49): the template now names the trailing pad ids
    "INC-01 query zero-check: LogUp over (id, row, ctl) + BOS + TEMPLATE (prefix, suffix, trailing pad ids) + pad, fresh mu each",
    "INC-02 table zero-check: h_tab (alpha - tau(v, ctl)) = m + pad, fresh mu each",
    "INC-03 ZS zero-sum row",
]
# [READ] stage_out_c.rs:36-63
C_D, C_DSQ, C_LIMB, C_X, C_XL0, C_XL1, C_Y, C_RHO0, C_SIG0, C_MULT = 0, 1, 2, 3, 4, 5, 6, 7, 11, 15
OC_H_LO, OC_H_D0, OC_H_DO_HELPERS, OC_H_GU8, OC_H_U = 0, 1, 6, 7, 8
SOC_IO, SOC_SS, SOC_TZC, SOC_PD, SOC_LZC, SOC_DZC, SOC_TAB, SOC_ZS = range(8)
OUTC_A_GROUPS, OUTC_H_GROUPS = 16, 5
OUTC_A_NAMES = (["A_D", "A_DSQ", "A_LIMB", "A_X", "A_XL0", "A_XL1", "A_Y"]
                + [f"A_RHO{i}" for i in range(NORM_LIMBS)] + [f"A_SIG{i}" for i in range(NORM_LIMBS)]
                + ["A_MU8"])
OUTC_H_NAMES = ["H_LO"] + [f"H_D{i}" for i in range(OC_H_DO_HELPERS)] + ["H_GU8", "H_U"]
OUTC_NAMES = [
    # [v21] r14's name (stage_out_c.rs:78): the public verdict row
    "OUTC-00 IO-in: x = B_out at the public verdict row P0+n+S-1 (fixed public row bits; T-1 without pad)",
    "OUTC-01 SS final-norm row sum (private, hosted by TZC)",
    "OUTC-02 TZC isqrt (D, Dsq, 9 limb slices; hosts SS)",
    "OUTC-03 PD margin sum_i y(i) w_Delta(i) (private, hosted by LZC)",
    "OUTC-04 LZC limb lookups (+pad; isqrt and margin limbs) + host term sigma g limb + u0 (sigma b + c)",
    "OUTC-05 DZC final-norm quotient + x limbs + helpers (+pad)",
    "OUTC-06 TAB byte-table helper (+pad)",
    "OUTC-07 ZS zero-sum row",
]


def bit_length(v: int) -> int:
    return int(v).bit_length()


@dataclass
class ClassGeom:
    """`ClassifierProfile::new` (classify.rs:316-409), the parts the layout and
    the margin read, at one classifier shape (public-row variant, mode
    verdict-public-bit)."""
    name: str
    tokens: int
    t_pad: int
    d: int
    d_pad: int
    v: int
    p0: int
    n: int
    s: int
    c: int
    num_special: int
    block_log_n: int
    block_inv_rate: int
    tier: Tier = R1_MVP
    # [v21, R-C3] the policy's PUBLIC pad id (classify.rs:119; the rung's 2)
    pad: int = 2

    def __post_init__(self):
        f = []
        if not (2 <= self.v <= TIO.V_MAX):
            f.append(f"V = {self.v} outside 2..=2^17")
        # [v21, R-C3] classify.rs:431-433: P0 + n + S <= T (a short item's
        # trailing positions hold the public pad id)
        if self.n < 1 or self.p0 + self.n + self.s > self.tokens:
            f.append(f"P0 + n + S = {self.p0} + {self.n} + {self.s} is more than T = {self.tokens} (n >= 1)")
        if not (0 <= self.pad < self.v):
            f.append(f"the public pad id {self.pad} is outside the vocabulary")
        if self.s < 1:
            f.append("the template has no suffix")
        if not (-C_MAX <= self.c <= C_MAX):
            f.append(f"c = {self.c} outside [-2^33, 2^33]")
        if not (0 < self.num_special < self.v):
            f.append("the control-id class [0, num_special) must be nonempty and below V")
        self.v_pad = 1 << clog2(self.v)
        self.log_v = clog2(self.v_pad)
        # classify.rs:372-379: the margin window over the WHOLE classes
        top = self.d * 127 * 32767 + C_MAX + 1
        self.window_bits = bit_length(top)
        self.limbs = -(-self.window_bits // 8)
        if (1 << (8 * self.limbs)) + (1 << self.window_bits) + C_MAX >= P // 2:
            f.append("the margin limbs and window wrap the field")
        lt = self.tier.stage_log_n
        if clog2(max(self.t_pad, 1 << self.tier.ep_log_n)) > self.ti_log():
            f.append("the input token endpoint is wider than the position domain")
        if LAM_BASE + self.limbs > (1 << self.lo_log()):
            f.append("the margin limbs do not fit the isqrt-limb domain")
        if max(self.do_log(), self.voc_log()) > TIO.MAX_DOM_LOG:
            f.append("a stage domain exceeds 2^17 words")
        self.door_findings = f
        _ = lt

    # the stage domains (classify.rs:439-456)
    def ti_log(self): return max(clog2(self.t_pad), self.tier.stage_log_n)
    def voc_log(self): return max(self.log_v, self.tier.stage_log_n)
    def lo_log(self): return max(clog2(2 * 3 * LIMBS_ISQRT), self.tier.stage_log_n)
    def do_log(self): return max(clog2(self.d_pad), self.tier.stage_log_n)
    def tab_log(self): return max(clog2(U8_LEN), self.tier.stage_log_n)
    def in_ep_words(self): return max(self.t_pad, 1 << self.tier.ep_log_n)

    # the template (classify.rs:489-524 at r14)
    def is_template(self, t): return t < self.p0 or (self.p0 + self.n <= t < self.tokens)

    # [v21, R-C3] the item's own length, the pad count, the verdict row, the
    # chunk plan's size (classify.rs:493-505, 798)
    def item_len(self): return self.p0 + self.n + self.s
    def pad_positions(self): return self.tokens - self.item_len()
    def verdict_row(self): return self.item_len() - 1
    def plan_size(self): return self.tokens - self.p0 - self.s
    def is_short(self): return self.n < self.plan_size()

    def kappa(self, t, prefix, suffix):
        """`ClassifierProfile::kappa` (classify.rs:512-524 at r14): the
        prefix's id, the suffix's, then the PUBLIC pad id up to T; 0 at
        content positions and beyond T"""
        if t < self.p0:
            return prefix[t]
        if self.p0 + self.n <= t < self.item_len():
            return suffix[t - self.p0 - self.n]
        if self.item_len() <= t < self.tokens:
            return self.pad
        return 0

    def stage_in_c(self) -> StageLayout:
        """`stage_in_c.rs:39-55`: stage IN's layout under new slot names"""
        lt = self.tier.stage_log_n
        lti, lvoc = self.ti_log(), self.voc_log()
        slots = [
            Slot(INC_NAMES[0], clog2(self.in_ep_words()), 1, 3, "Standalone", 1, 0, 1),
            Slot(INC_NAMES[1], lti, 1, 4, "Standalone", 1, 1, 1),
            Slot(INC_NAMES[2], lvoc, 1, 4, "Standalone", 1, 1, 0),
            Slot(INC_NAMES[3], lt, 1, 2, "Standalone", 0, 1, 0),
        ]
        return StageLayout("stage IN-C", lt, [lti, lvoc], [lti, lvoc, lt], [1, -1, 1], INC_H_U,
                           slots, [], [lt, lt, self.tier.ep_log_n, self.block_log_n])

    def stage_out_c(self) -> StageLayout:
        """`stage_out_c.rs:74-111`"""
        lt = self.tier.stage_log_n
        llo, ldo, ltab = self.lo_log(), self.do_log(), self.tab_log()
        d_bits = clog2(self.d_pad)
        slots = [
            Slot(OUTC_NAMES[0], d_bits, 1, 2, "Standalone", 1, 0, 1),
            Slot(OUTC_NAMES[1], ldo, 1, 4, "Private", 1, 0, 0),
            Slot(OUTC_NAMES[2], TO_LOG, 1, 3, "Host", 11, 0, 0),
            Slot(OUTC_NAMES[3], d_bits, 1, 2, "Private", 1, 0, 0),
            Slot(OUTC_NAMES[4], llo, 1, 4, "Host", 1, 1, 0),
            Slot(OUTC_NAMES[5], ldo, 1, 5, "Standalone", 13, OC_H_DO_HELPERS, 0),
            Slot(OUTC_NAMES[6], ltab, 1, 3, "Standalone", 1, 1, 0),
            Slot(OUTC_NAMES[7], lt, 1, 2, "Standalone", 0, 1, 0),
        ]
        a_log = [TO_LOG] * 2 + [llo] + [ldo] * 12 + [ltab]
        h_sign = [1] * (OC_H_U + 1)
        h_sign[OC_H_GU8] = -1
        h_log = [llo] + [ldo] * OC_H_DO_HELPERS + [ltab] + [lt]
        # [A, H, In = B_out, Out = unused]
        return StageLayout("stage OUT-C", lt, a_log, h_log, h_sign, OC_H_U, slots,
                           [[SOC_TZC, [SOC_SS]], [SOC_LZC, [SOC_PD]]],
                           [lt, lt, self.block_log_n, lt])

    def endpoint(self) -> dict:
        n = 1 << self.tier.ep_log_n
        words = self.in_ep_words()
        data = -(-words // n)
        return {"words": words, "row_width_log": self.tier.ep_log_n, "inv_rate": self.tier.ep_inv_rate,
                "data_rows": data, "commitment_rows": data + TIO.EP_MASK_ROWS,
                "true_words": self.tokens, "pad_words": words - self.tokens,
                # [v21, R-C3] a short item's trailing pad ids are template words
                "template_words": self.tokens - self.n, "content_words": self.n,
                "pad_id_words": self.pad_positions()}

    def boundary(self) -> dict:
        words = self.t_pad * self.d_pad
        data = -(-words // (1 << self.block_log_n))
        return {"plane": [self.t_pad, self.d_pad], "row_width_log": self.block_log_n,
                "inv_rate": self.block_inv_rate, "data_rows": data, "rows": data + 2 * 2 + 2, "sites": 2}

    def margin_bounds(self) -> dict:
        """design §4.1-4.2 / classify.rs:372-379 [COUNTED]: every term of the
        margin identity is an integer below p / 2, so it holds over Z"""
        b_delta = self.d * 127 * 32767
        return {"B_Delta": b_delta, "B_Delta_log2": round(math.log2(b_delta), 3),
                "window_bits": self.window_bits, "limbs": self.limbs,
                "delta_max_any_limbs_log2": 8 * self.limbs,
                "honest_delta_max": b_delta + C_MAX, "honest_delta_fits": b_delta + C_MAX < (1 << (8 * self.limbs)),
                "identity_total_below_p_half": b_delta + (1 << (8 * self.limbs)) + C_MAX + 1 < P // 2,
                "limb_entries": [LAM_BASE, LAM_BASE + self.limbs - 1],
                "limb_plane_entries": 1 << self.lo_log(),
                "isqrt_live_entries": [2 * k for k in range(3 * LIMBS_ISQRT)]}

    def g2(self) -> dict:
        """G-2, static half (the token geometry's rule; the B_out plane and
        the public row T - 1 are the same in a classifier run)"""
        return TIO.TokenGeom.g2(self)

    def report(self) -> dict:
        si, so = self.stage_in_c(), self.stage_out_c()
        return {
            "geometry": self.name, "tokens": self.tokens, "t_pad": self.t_pad, "d": self.d,
            "d_pad": self.d_pad, "V": self.v, "V_pad": self.v_pad, "P0": self.p0, "n": self.n, "S": self.s,
            "c": self.c, "num_special": self.num_special, "door_findings": self.door_findings,
            "margin": self.margin_bounds(), "tier": self.tier.__dict__,
            "stage_in_c": si.summary(), "stage_out_c": so.summary(),
            "input_endpoint": self.endpoint(), "output_endpoint": None,
            "b_in_b_out": self.boundary(),
            "opening_groups": {"IN-C": [INC_A_GROUPS, INC_H_GROUPS], "OUT-C": [OUTC_A_GROUPS, OUTC_H_GROUPS]},
            "expectations": expectations(self),
            "privacy_acceptance": False,
        }


# ---------------------------------------------------------------- shapes
# the R-C1 development rung (shape.rs TRAINED_CALIB_RUNG_PROFILE: T32 / d384;
# classify.rs:109-111 policy_rung_dev: P0 8, suffix [32], num_special 5,
# V 300, c 0); block endpoint row width 10 [v20: corrected from 12; the
# rung's shape in every classifier capture says endpoint_log_n 10]
RUNG_RC1 = dict(name="R-C1 classifier rung (T32 / d384, V 300, P0 8 + n 23 + S 1)", tokens=32, t_pad=32,
                d=384, d_pad=512, v=300, p0=8, n=23, s=1, c=0, num_special=5,
                block_log_n=10, block_inv_rate=4)


def shieldstral(t: int) -> dict:
    """Shieldstral-1.0-3B at T (classify.rs:118-139 policy_shieldstral_card:
    P0 84, S 1, num_special 1000, V 131,072, c 0; d 3072 -> d_pad 4096). The
    block shape is native R12's (in progress): the block endpoint row width
    is taken as the 8B class's 13 until R12 freezes [ASSUMED, re-read then]."""
    return dict(name=f"Shieldstral-1.0-3B T{t} (card template, P0 84 + n {t - 85} + S 1)", tokens=t,
                t_pad=1 << clog2(t), d=3072, d_pad=4096, v=131072, p0=84, n=t - 85, s=1, c=0,
                num_special=1000, block_log_n=13, block_inv_rate=4)


# ---------------------------------------------------------------- D40 / D34
def d34_residual_log2(blocks: int, tokens: int, out_bytes: int = U8_LEN) -> float:
    """D34's two-world distance for the input-dependent token-stage refusal,
    `2 (768 L + T + 256) / p^2` (D34 / D40 [READ]); at a classifier stage
    IN-C inverts at most T distinct tau rows and stage OUT-C at most 256 byte
    values, the blocks 768 each.  log2 of the figure."""
    return math.log2(2 * (768 * blocks + tokens + out_bytes)) - 2 * math.log2(P)


def d34_table() -> dict:
    rows = []
    for t in (128, 256, 512):
        rows.append({"L": 26, "T": t, "log2": round(d34_residual_log2(26, t), 3)})
    return {"formula": "2 (768 L + T + 256) / p^2 (D34; D40 recount for the classifier family)",
            "next_token_L1_T32_check": round(d34_residual_log2(1, 32), 3),
            "classifier_L26": rows,
            "D40_figure_T512": round(d34_residual_log2(26, 512), 1)}


# ---------------------------------------------------------------- D41 chunks
def chunk_ranges(total: int, size: int, overlap: int) -> list:
    """`chunk_ranges` (classify.rs:219-235 at r14), transcribed: chunks of
    exactly `size` ids at stride `size - overlap`, the last END-ALIGNED;
    [v21, R-C3] a SHORT content (`1 <= total < size`) is ONE chunk
    `[0, total)`; an empty content is refused"""
    if size <= 0 or overlap >= size or overlap < 0:
        raise ValueError(f"the plan (size {size}, overlap {overlap}) needs 0 <= overlap < size")
    if total <= 0:
        raise ValueError("an empty content has no chunk (n >= 1)")
    if total < size:
        return [(0, total)]
    stride = size - overlap
    k = 1 + -(-(total - size) // stride)
    return [(j * stride, j * stride + size) if j + 1 < k else (total - size, total) for j in range(k)]


def chunk_ref_bytes(index, count, a, b, total, size, overlap) -> bytes:
    """`ChunkRef::bytes` (classify.rs:215-217): seven u64 LE"""
    return b"".join(int(x).to_bytes(8, "little") for x in (index, count, a, b, total, size, overlap))


def check_item_chunks(chunks: list, *, total: int, size: int, overlap: int) -> dict:
    """D41's label rule for ONE category of one item, fail-closed (design
    §13.4): `chunks` = the accepted chunk statements, each a dict with
    `index, count, a, b, total, size, overlap, verdict, policy, model`.  The
    label is 1 (flagged) if ANY chunk says 1, or a chunk index 0..K-1 has no
    accepted proof, or a chunk appears twice, or a range / count / total /
    plan is not the split's, or the chunks name different policies or
    models.  Returns the label and every reason."""
    reasons = []
    try:
        want = chunk_ranges(total, size, overlap)
    except ValueError as exc:
        return {"label": 1, "reasons": [f"no split: {exc}"], "K": None}
    k = len(want)
    seen = {}
    for c in chunks:
        j = c.get("index")
        if not isinstance(j, int) or not (0 <= j < k):
            reasons.append(f"a chunk index {j!r} outside 0..{k - 1}")
            continue
        if j in seen:
            reasons.append(f"chunk {j} appears twice")
            continue
        seen[j] = c
        if (c.get("a"), c.get("b")) != want[j]:
            reasons.append(f"chunk {j}'s range {(c.get('a'), c.get('b'))} is not the split's {want[j]}")
        for key, val in (("count", k), ("total", total), ("size", size), ("overlap", overlap)):
            if c.get(key) != val:
                reasons.append(f"chunk {j}'s {key} is {c.get(key)!r}, the split's {val}")
    missing = [j for j in range(k) if j not in seen]
    if missing:
        reasons.append(f"chunks {missing} have no accepted proof")
    for key in ("policy", "model"):
        vals = {c.get(key) for c in seen.values()}
        if len(vals) > 1:
            reasons.append(f"the chunks name different {key}s")
    verdict_or = int(any(c.get("verdict") == 1 for c in seen.values()))
    bad_verdicts = [j for j, c in seen.items() if c.get("verdict") not in (0, 1)]
    if bad_verdicts:
        reasons.append(f"chunks {bad_verdicts} carry no one-bit verdict")
    label = 1 if (reasons or verdict_or) else 0
    return {"label": label, "verdict_or": verdict_or, "K": k, "ranges": want,
            "fail_closed_reasons": reasons, "covers": bool(want) and want[0][0] == 0 and want[-1][1] == total
            and all(want[i][1] > want[i + 1][0] for i in range(k - 1)) if k > 1 else bool(want)}


# ---------------------------------------------------------------- expectations
def expectations(g: ClassGeom) -> dict:
    """What the gate EXPECTS of a classifier receipt (G-1 / G-3), stated
    before any capture exists (predictions; each is compared by the capture
    tools once the hook lands)."""
    so = g.stage_out_c()
    return {
        "per_commitment_disclosed_Fp": {
            "A-in": 0, "H-in": 2, "E-token-in": 0, "B-in / internal boundaries / B-out": 0,
            "block A": 0, "block H": 2, "A-out (OUT-C)": 0, "H-out (OUT-C)": 2,
            "E-token-out": "ABSENT (D40: no output endpoint)"},
        "why_H_2": "each H commitment's two zero-sum rows (the value-0 sum claim's u pair), as in every built stage",
        "opening_groups": {"IN-C": [INC_A_GROUPS, INC_H_GROUPS], "OUT-C": [OUTC_A_GROUPS, OUTC_H_GROUPS]},
        "OUT-C claims": {"A_site_pairs": (so.a_prox - so.a_mask_base) // 2, "H_site_pairs": (so.h_prox - so.h_mask_base) // 2},
        "public_outputs_depending_on_hidden_data": ["the verdict bit b (statement; header label classify-verdict)"],
        "one_public_bit": ("stage OUT-C's public tables are functions of the geometry, the profile "
                           "constants (c, the margin vector w_Delta by digest), the re-derived "
                           "challenges and b ONLY: supp_d, the limb-plane live selector, "
                           "g(z) = sigma 256^(z-32) on the limb entries, u0, w_Delta, the byte "
                           "table and its support; the LZC host constant is b + c. The margin "
                           "Delta, the limbs lambda and y are committed in A_out and opened only "
                           "through reserved pairs, so (rank lemma) A_out discloses 0 and no "
                           "magnitude of Delta is a public value"),
        "template_and_ctl_columns": ("stage IN-C's template indicator pi, template ids kappa and the "
                                     "query control column ctl_q are public functions of the "
                                     "policy; the content positions' ids stay in A_in (disclosed 0)"),
    }


def main(argv):
    geoms = [ClassGeom(**RUNG_RC1)] + [ClassGeom(**shieldstral(t)) for t in (128, 256, 512)]
    out = {"what": "classifier profile family, re-derived (gate round 16); NOT a privacy result",
           "privacy_acceptance": False, "geometries": [g.report() for g in geoms], "D34_D40": d34_table(),
           "D41_rung_example": {"total": 27, "size": 23, "overlap": 4, "ranges": chunk_ranges(27, 23, 4)}}
    s = json.dumps(out, indent=1, sort_keys=True, default=str)
    if len(argv) > 1:
        with open(argv[1], "w") as fh:
            fh.write(s + "\n")
    for g in out["geometries"]:
        si, so = g["stage_in_c"], g["stage_out_c"]
        print(f"{g['geometry']}: margin window {g['margin']['window_bits']} bits, {g['margin']['limbs']} limbs; "
              f"IN-C A {si['A']['rows']} / H {si['H']['rows']}; OUT-C A {so['A']['rows']} / H {so['H']['rows']} "
              f"({so['committed_elements']:,} elements); door {g['door_findings'] or 'ok'}")
    print("D34 / D40:", out["D34_D40"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

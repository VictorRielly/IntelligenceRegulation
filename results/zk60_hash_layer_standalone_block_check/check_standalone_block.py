#!/usr/bin/env python3
"""Independent adversarial re-derivation for
`docs/zkmatrix-poc/ZK60_HASH_LAYER_STANDALONE_TAGGED_BLOCK_CHECK.md`.

It does NOT import, read or reuse the draft's script
(`results/zk60_hash_layer_standalone_block/standalone_block_hash_counts.py`)
or its pinned models.  Every geometry number is re-derived here from the
Rust source of the lane `/home/victor/wt-zk60-block125m` at `544fbaf`
(read-only), function by function:

  shape.rs    Shape::build (:280-...), natural_log (:1256-1269), true_size,
              log / size / rows_of (:1286-1295), pads, a_plane_doms (:1303),
              lookups_per_position, helpers, h_plane_doms (:1348),
              claim_sites (:1368), slots (:1420), a_groups (:1561),
              h_groups (:1585), constants BASE_DEGREE (:77),
              INDICATOR_SLOT_DOMAIN (:84), LIMBS_ISQRT (:29), F_P (:47)
  layout.rs   Layout::for_shape (:1063-1135), domain_log_at (:170)
  argument.rs define (:1102-1855): every tr.challenge_* call per slot;
              run_slot (:444-628): pb-slot / c / pb-scalar / rounds / pb-term
  protocol.rs transcript (:113-123), prove_core (:899-1173),
              prove_inner_at (:787-852), check_opening(_challenges)
  zk.rs       mask_commit_tagged (:481-517), mask_open (:563-600)
  zkp-core    pcs.rs commit_zk_owned_with_tag (:769-808), open_zk
              (:1023-1052), zk_rhos (:943-964); transcript.rs; rng.rs;
              sumcheck.rs (one absorb + one squeeze per round)
  endpoint_g.rs prepare (:259-284)

MEASURED figures used only as CONTROLS (never as inputs to a figure):
  * lane stage 36 (`ZK60_BLOCK125M_LANE_PROGRESS.md` lines 11769-11787):
    six shapes' block-stream fp() draws, salts, stream bytes, live
    squeezes, replay points, frame bytes, and the endpoint replica draws;
  * gate round 9j (joint-view branch ledger §R9j.7 / §R9j.8): final
    counter and challenges at rung-G and 125M, per-commitment blinding
    unknowns (R9j.8 B11 for A at 125M);
  * the four real receipts (`receipt.bin`) and their `block.json` /
    `expected.bin`: the frame length, and a PARSE of the frame's public
    structure (indices, salts, opened columns, paths, roots) with every
    opened column re-hashed and authenticated here under the profile's own
    keys (Python `blake3`, keyed mode), and the 40-byte envelope binding
    recomputed from the public header words.

Exact integer / Fraction arithmetic; floating point only for printed log2
and for the expected-occupancy formula.  Nothing is built, proved or
benchmarked.  Not a privacy acceptance.
"""

import json
import math
import os
import sys
from fractions import Fraction

try:
    import blake3  # the Python binding of the same BLAKE3
except ImportError:  # pragma: no cover
    blake3 = None

P = 0xFFFF_FFFF_0000_0001
Q_OPEN = 256          # COL_CHECKS (shape.rs:64) = opened columns = pads per row
IDX_PER_SQUEEZE = 4   # transcript.rs:136-148
MASK_LOG_MSG, MASK_LOG_DOM, MASK_Q = 9, 12, 256   # zk.rs:373-375
N_SLOTS = 23
M_ROWS = 2 * N_SLOTS + 4                            # layout.rs:931
EP_MASK_ROWS = 5                                    # endpoint_g.rs:92
LIMBS_ISQRT, F_P, NORM_TN, INT16_MAX = 3, 9, 11, 32767
SH_G, SH_H_PROD, SH_Z = 7, 14, 6                    # layout.rs:78-80
(SS, SSM, TZC, LZC, RS, QMM, KMM, VMM, SCORE, PV, WO, GMM, UMM, DMM, DZC, QZC,
 KVZC, SZC, FZC, TAB, ZS, IO_IN, IO_OUT) = range(23)  # layout.rs:799-821
BASE_DEGREE = [3, 3, 3, 4, 3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 4, 4, 4, 4, 3, 2, 2, 2]
DOMS = ["T", "Ht", "L", "D", "Q", "Kv", "S", "F", "Tab"]
INDICATOR = {SS: "D", SSM: "D", RS: "S", DZC: "D", QZC: "Q", KVZC: "Kv", SZC: "S", FZC: "F"}
PAD_HOST = {"T": TZC, "Ht": SZC, "L": LZC, "D": DZC, "Q": QZC, "Kv": KVZC, "S": SZC, "F": FZC, "Tab": TAB}
TOY_PROFILE = "hashline-zk-mr1/private-block-t32-poc/1"
FROZEN_SEAM_RUNG = "hashline-zk-mr1/private-block-rung-t24-dev/1"


def clog2(v):
    return (v - 1).bit_length() if v > 1 else 0


def npow2(v):
    return 1 << clog2(v)


def isqrt(v):
    return math.isqrt(v)


class Shape:
    """shape.rs Shape::build with the registered constructors' arguments"""

    def __init__(self, key, profile, tokens, width, hidden, qh, dh, kv, log_cols, inv_rate, f_e, e_rows, e_log=None, e_rate=None):
        self.key, self.profile = key, profile
        self.tokens, self.width, self.hidden, self.qh, self.dh, self.kv = tokens, width, hidden, qh, dh, kv
        self.log_cols, self.inv_rate, self.f_e, self.e_rows = log_cols, inv_rate, f_e, e_rows
        self.t_pad, self.d_pad, self.h_pad, self.f_pad = npow2(tokens), npow2(width), npow2(qh), npow2(hidden)
        self.e_log = log_cols if e_log is None else e_log
        self.e_rate = inv_rate if e_rate is None else e_rate
        d_max = isqrt(1 + width * INT16_MAX * INT16_MAX)
        self.norm_wrho = NORM_TN + 1 + d_max.bit_length()
        self.wrho_s = clog2(tokens) + f_e
        self.toy = profile == TOY_PROFILE
        self.legacy = self.toy or profile == FROZEN_SEAM_RUNG
        self.general = not (self.t_pad * self.d_pad <= 4096 and self.e_log == 8 and self.e_rate == 8)
        self.n = 1 << log_cols

    # ---- limbs (shape.rs:1236-1250)
    def ln(self):
        return -(-self.norm_wrho // 8)

    def top_full(self):
        return self.norm_wrho == 8 * self.ln()

    def ls(self):
        return -(-self.wrho_s // 8)

    def lp(self):
        return -(-(F_P + 1) // 8)

    # ---- domains
    def natural(self, d):
        t, h, dh = self.t_pad, self.h_pad, self.dh
        return {"T": clog2(t), "Ht": clog2(h * t), "L": clog2(16 * t), "D": clog2(t * self.d_pad),
                "Q": clog2(t * h * dh), "Kv": clog2(t * self.kv * dh), "S": clog2(h * t * t),
                "F": clog2(t * self.f_pad), "Tab": clog2(256)}[d]

    def log(self, d):
        nat = self.natural(d)
        return self.log_cols if (d not in ("T", "Ht") and nat < self.log_cols) else nat

    def size(self, d):
        return 1 << self.log(d)

    def true_size(self, d):
        return {"T": self.tokens, "Ht": self.qh * self.tokens, "L": 3 * LIMBS_ISQRT * self.tokens,
                "D": self.tokens * self.width, "Q": self.tokens * self.qh * self.dh,
                "Kv": self.tokens * self.kv * self.dh, "S": self.qh * self.tokens * self.tokens,
                "F": self.tokens * self.hidden, "Tab": 256}[d]

    def pads(self, d):
        return self.size(d) != self.true_size(d)

    def rows_of(self, d):
        return max(1, self.size(d) >> self.log_cols)

    def carries_pad_rule(self):
        return not self.toy

    # ---- planes
    def a_plane_doms(self):
        ln = self.ln()
        v = ["T"] * 4 + ["Ht"] * 2 + ["L"] * 2 + ["D"] * (4 + 2 * ln + 8 + 2 * ln + 7)
        v += ["Q"] * 7 + ["Kv"] * 6 + ["S"] * (5 + self.lp() + 2 * self.ls()) + ["F"] * 11 + ["Tab"] * 3
        return v

    def lpp(self, d):
        top = 0 if self.top_full() else 1
        per_norm = 2 + 2 * (self.ln() + top)
        return {"L": 2, "D": 2 + per_norm + 6 + per_norm + 2 + 4, "F": 9, "Q": 13, "Kv": 12,
                "S": 2 + 2 + (self.lp() + 1) + 2 * (self.ls() + 1), "T": 0, "Ht": 0, "Tab": 0}[d]

    def helpers(self, d):
        return -(-self.lpp(d) // 2)

    def h_plane_doms(self):
        return (["L"] * self.helpers("L") + ["D"] * self.helpers("D") + ["Q"] * self.helpers("Q")
                + ["Kv"] * self.helpers("Kv") + ["S"] * (self.helpers("S") + 1)
                + ["F"] * (self.helpers("F") + 1) + ["Tab"] * 4)

    def a_on(self, d):
        return self.a_plane_doms().count(d)

    def claim_sites(self):
        a, h = [0] * N_SLOTS, [0] * N_SLOTS
        a[SS] = a[SSM] = 1
        a[TZC] = 4 + 2 * 3 * LIMBS_ISQRT
        a[LZC], h[LZC] = self.a_on("L"), self.helpers("L")
        a[RS] = 2
        for s in (QMM, KMM, VMM, WO, GMM, UMM, DMM):
            a[s] = 1
        a[SCORE] = a[PV] = 2
        a[DZC], h[DZC] = self.a_on("D") + 2, self.helpers("D")
        a[QZC], h[QZC] = self.a_on("Q") + 1, self.helpers("Q")
        a[KVZC], h[KVZC] = self.a_on("Kv") + 1, self.helpers("Kv")
        a[SZC], h[SZC] = self.a_on("S") + 2, self.helpers("S") + 1
        a[FZC], h[FZC] = self.a_on("F"), self.helpers("F") + 1
        a[TAB], h[TAB] = 3, 3
        h[ZS] = 1
        a[IO_IN] = a[IO_OUT] = 1
        return a, h

    def lkv(self):
        return clog2(self.kv)

    def slots(self):
        cube = {SS: "D", SSM: "D", DZC: "D", IO_IN: "D", IO_OUT: "D", TZC: "T", LZC: "L", RS: "S",
                SZC: "S", QZC: "Q", KVZC: "Kv", FZC: "F", TAB: "Tab", ZS: "Tab"}
        lkv = self.lkv()
        inner = {QMM: clog2(self.d_pad), KMM: clog2(self.d_pad), VMM: clog2(self.d_pad), WO: clog2(self.d_pad),
                 GMM: clog2(self.d_pad), UMM: clog2(self.d_pad), SCORE: lkv + clog2(self.dh),
                 PV: lkv + clog2(self.t_pad), DMM: clog2(self.f_pad)}
        out = []
        for s in range(N_SLOTS):
            main = self.log(cube[s]) if s in cube else inner[s]
            ind = self.carries_pad_rule() and s in INDICATOR and self.pads(INDICATOR[s])
            ext = 2 if s in (SCORE, PV) else 1
            geq = s in (SCORE, PV) and lkv > 0
            out.append((main, ext, BASE_DEGREE[s] + int(ind) + int(geq)))
        return out

    def a_groups(self):
        offs = {(k * self.t_pad) % self.n for k in range(3 * LIMBS_ISQRT)} | {0}
        return len(offs) + 15 + 2 * 2 + 4 * 2

    def h_groups(self):
        return 9

    # ---- the layout (layout.rs:1063-1135)
    def layout(self):
        a, h = self.claim_sites()
        a_data = sum(self.rows_of(d) for d in self.a_plane_doms())
        h_data = sum(2 * self.rows_of(d) for d in self.h_plane_doms())
        return dict(a_data=a_data, h_data=h_data, a_rows=a_data + 2 * sum(a) + 2, h_rows=h_data + 2 * sum(h) + 2,
                    a_claims=sum(a), h_claims=sum(h) + 1, a_sites=a, h_sites=h)

    def e_data_rows(self):
        return (self.t_pad * self.d_pad) >> self.e_log

    # ---- the transcript `parameters` word (protocol.rs:128-148)
    def parameter_line(self):
        base = (f"T{self.tokens}/d{self.width}/f{self.hidden}/H{self.qh}/KV{self.kv}/dh{self.dh}/log_cols{self.log_cols}"
                f"/inv_rate{self.inv_rate}/Q{Q_OPEN}/P1/sh-g{SH_G}-u0-h{SH_H_PROD}-z{SH_Z}/two-private-endpoints/one-proof-one-transcript")
        if self.toy:
            return base
        return base + f"/endpoint-log_n{self.e_log}-rate{self.e_rate}-pad{Q_OPEN}-rows{self.e_rows}"


SHAPES = {
    # shape.rs:713, :767-784, :827-844, :890-907, :965-982, :1044-1061, :1106-1123, :1142
    "toy": Shape("toy", TOY_PROFILE, 32, 16, 16, 2, 8, 1, 8, 8, 9, 7),
    "rung_g": Shape("rung_g", "hashline-zk-mr1/private-block-rung-g-t24-dev/1", 24, 96, 192, 6, 16, 2, 10, 4, 12, 9),
    "rung_k4": Shape("rung_k4", "hashline-zk-mr1/private-block-rung-k4-t24-dev/1", 24, 96, 192, 12, 8, 4, 10, 4, 12, 9),
    "rung_p2": Shape("rung_p2", "hashline-zk-mr1/private-block-rung-p2-t32-dev/1", 32, 96, 256, 12, 8, 4, 10, 4, 12, 9),
    "rung_c6": Shape("rung_c6", "hashline-zk-mr1/private-block-rung-c6-t32-dev/1", 32, 384, 512, 12, 32, 4, 10, 4, 12, 21),
    "rung_w14": Shape("rung_w14", "hashline-zk-mr1/private-block-rung-w14-t64-dev/1", 64, 768, 1024, 12, 64, 4, 14, 4, 12, 9),
    "rung_e32": Shape("rung_e32", "hashline-zk-mr1/private-block-rung-e32-t32-dev/1", 32, 768, 1024, 12, 64, 4, 10, 4, 12, 37),
    "m125": Shape("m125", "hashline-zk-mr1/private-block-m125/1", 512, 768, 2048, 12, 64, 4, 14, 4, 9, 37),
}
TAGGED_REGISTERED = ["rung_g", "rung_k4", "rung_p2", "rung_c6", "rung_w14", "rung_e32", "m125"]
K8_PROFILE = "hashline-zk-mr1/private-block-rung-k8-t24-dev/1"   # k8_tests.rs:74 (test-only)
RUN_PROFILES = ["hashline-zk-mr1/private-run-rung-g-t24-dev/1", "hashline-zk-mr1/private-run-rung-k4-t24-dev/1",
                "hashline-zk-mr1/private-run-rung-p2-t32-dev/1", "hashline-zk-mr1/private-run-rung-c6-t32-dev/1",
                "hashline-zk-mr1/private-run-rung-w14-t64-dev/1", "hashline-zk-mr1/private-run-rung-e32-t32-dev/1",
                "hashline-zk-mr1/private-run-m125/1"]   # run.rs:52-70


# =========================================================== the counts
def draws(sh):
    """fp() draws and salts per generator, from the draw sites themselves"""
    lay, n = sh.layout(), sh.n
    A = (lay["a_rows"] - lay["a_data"]) * n + lay["a_rows"] * Q_OPEN          # protocol.rs:1002-1004 + pcs.rs:777
    H = (lay["h_rows"] - lay["h_data"]) * n + 2 * (n - 1) + lay["h_rows"] * Q_OPEN  # :1115-1126 + pcs.rs:777
    sl = sh.slots()
    sum_L = sum((m + e) * d + 2 for m, e, d in sl)                             # CfsMask::len, sumcheck.rs:197
    M = 2 * sum_L + 2 * N_SLOTS * MASK_Q + 4 * 2 * (1 << MASK_LOG_MSG)        # zk.rs:485, :496, :503-508
    block_salts = 2 * n * sh.inv_rate + (1 << MASK_LOG_DOM)                    # pcs.rs:778 x2, zk.rs:513
    e_n = 1 << sh.e_log
    E = EP_MASK_ROWS * e_n + sh.e_rows * Q_OPEN                                # endpoint_g.rs:276-278 + pcs.rs:777
    e_salts = e_n * sh.e_rate
    block_fp = A + H + M
    return dict(A=A, H=H, M=M, sum_L=sum_L, block_fp=block_fp, block_salts=block_salts,
                block_bytes=16 * block_fp + 32 * block_salts, E_each=E, E_salts_each=e_salts,
                E_both_bytes=2 * (16 * E + 32 * e_salts), proof_fp=block_fp + 2 * E,
                proof_salts=block_salts + 2 * e_salts)


def slot_definition_draws(sh):
    """every tr.challenge_* in argument.rs::define, per slot"""
    lt, lh, ldh = clog2(sh.t_pad), clog2(sh.h_pad), clog2(sh.dh)
    ld, lf = clog2(sh.d_pad), clog2(sh.f_pad)
    kvw = clog2(sh.kv * sh.dh)

    def npad(slot):
        if not sh.carries_pad_rule():
            return 0
        return int(any(PAD_HOST[d] == slot and sh.pads(d) for d in DOMS))

    hp = sh.helpers
    L = sh.log
    out = [0] * N_SLOTS
    out[SS] = lt                                               # :1128
    out[SSM] = lt                                              # :1137
    out[TZC] = lt + (6 + npad(TZC)) + 2 + npad(TZC)            # :1144-1147
    out[LZC] = L("L") + npad(LZC) + npad(LZC)                  # :1209-1214
    out[RS] = L("Ht") + 1                                      # :1230-1231
    out[QMM] = lt + ld                                         # :1246, :1258
    out[KMM] = kvw
    out[VMM] = kvw
    out[SCORE] = lh + lt + lt                                  # :1313-1315
    out[PV] = lh + lt + ldh                                    # :1349-1351
    out[WO] = lt + ld
    out[GMM] = lt + lf                                         # :1382, :1386
    out[UMM] = lf
    out[DMM] = lt + ld                                         # :1385-1386
    out[DZC] = L("D") + (11 + hp("D") + npad(DZC)) + 2 + npad(DZC)             # :1406-1410
    out[QZC] = L("Q") + (1 + hp("Q") + npad(QZC)) + 2 + npad(QZC)              # :1606-1610
    out[KVZC] = L("Kv") + (1 + hp("Kv") + npad(KVZC)) + 2 + npad(KVZC)
    out[SZC] = L("S") + (5 + hp("S") + 1 + npad(SZC)) + 2 + npad(SZC)          # :1664-1668
    out[FZC] = L("F") + (4 + hp("F") + npad(FZC)) + 2 + npad(FZC)              # :1553-1557
    out[TAB] = L("Tab") + (3 + npad(TAB)) + npad(TAB)                          # :1788-1790
    out[ZS] = 0                                                                # :1833-1843
    out[IO_IN] = out[IO_OUT] = L("D")                                          # :1846
    return out


def transcript_counts(sh):
    lay, sl = sh.layout(), sh.slots()
    rounds = sum(m + e for m, e, _ in sl)
    defs = slot_definition_draws(sh)
    idx = Q_OPEN // IDX_PER_SQUEEZE
    open_A = lay["a_claims"] + lay["a_rows"] + idx          # zk_rhos: lambdas, prox rho; indices
    open_H = lay["h_claims"] + lay["h_rows"] + idx
    open_E = 1 + sh.e_rows + idx
    open_M = 1 + (2 * N_SLOTS + 2) + MASK_Q // IDX_PER_SQUEEZE   # zk.rs:566, :584-594
    squeezes = 3 + sum(defs) + N_SLOTS + rounds + open_M + open_A + open_H + 2 * open_E
    challenges = squeezes - 5 * idx
    replay = (lay["a_claims"] + lay["a_rows"]) + (lay["h_claims"] + lay["h_rows"]) + 2 * (1 + sh.e_rows)
    ga, gh = sh.a_groups(), sh.h_groups()
    absorbs = 5 + 3 + 1 + 3 + 3 * N_SLOTS + rounds + 2 + (ga + 1) + (gh + 1) + 2 + 2
    return dict(rounds=rounds, slot_definition_draws=sum(defs), per_slot_definition_draws=defs,
                squeezes=squeezes, challenges=challenges, replay_points=replay, absorbs=absorbs,
                F_T_queries_A=1 + absorbs + squeezes, a_groups=ga, h_groups=gh)


def frame_bytes(sh):
    """wire.rs encode/decode, from this geometry"""
    lay, sl = sh.layout(), sh.slots()
    a, h = sh.claim_sites()
    terms = [a[s] + h[s] + int(s >= IO_IN) for s in range(N_SLOTS)]
    slots = sum(16 * (1 + (m + e) * (d + 1) + terms[s]) for s, (m, e, d) in enumerate(sl))
    mask = 2 * 1024 * 16 + Q_OPEN * (8 + M_ROWS * 8 + 32 + 12 * 32)
    depth = clog2(sh.n * sh.inv_rate)
    vec = (sh.n + Q_OPEN) * 16

    def op(groups, rows, v, dep):
        return (groups + 1) * v + Q_OPEN * (8 + rows * 8 + 32 + dep * 32)
    e_n = 1 << sh.e_log
    e_depth = clog2(e_n * sh.e_rate)
    total = (40 + 96 + slots + mask + op(sh.a_groups(), lay["a_rows"], vec, depth)
             + op(sh.h_groups(), lay["h_rows"], vec, depth) + 2 * op(1, sh.e_rows, (e_n + Q_OPEN) * 16, e_depth))
    parts = dict(header=136, slots=slots, mask=mask, A=op(sh.a_groups(), lay["a_rows"], vec, depth),
                 H=op(sh.h_groups(), lay["h_rows"], vec, depth), E_each=op(1, sh.e_rows, (e_n + Q_OPEN) * 16, e_depth))
    return total, parts, terms


# ======================================================= the receipts (parse)
BUNDLES = {
    "rung-g-dense": ("rung_g", "/home/victor/wt-zk60-block125m/results/zk60_block_captures_20260923/rung-g/rung-g-dense"),
    "rung-g-zero": ("rung_g", "/home/victor/wt-zk60-block125m/results/zk60_block_captures_20260923/rung-g/rung-g-zero"),
    "m125-dense": ("m125", "/home/victor/zk60-artifacts/block-captures-20260923/m125-dense"),
    "m125-zero": ("m125", "/home/victor/zk60-artifacts/block-captures-20260923/m125-zero"),
}
CTX = {"transcript": "hashline-zk-mr1 2026-09-20 fiat-shamir transcript",
       "column": "hashline-zk-mr1 2026-09-20 pcs column digest",
       "leaf": "hashline-zk-mr1 2026-09-20 pcs salted merkle leaf",
       "node": "hashline-zk-mr1 2026-09-20 pcs merkle inner node"}   # hashtag.rs:48-54


def tag_keys(profile):
    return {r: blake3.blake3(profile.encode(), derive_key_context=c).digest() for r, c in CTX.items()}


def kh(key, data):
    return blake3.blake3(data, key=key).digest()


def le64(v):
    return int(v).to_bytes(8, "little")


def header_state(profile, keys, words):
    """protocol.rs:113-123 under Transcript::new_tagged / absorb (transcript.rs:40-68)"""
    st = kh(keys["transcript"], b"hashline-v1/" + profile.encode())
    for label, data in words:
        st = kh(keys["transcript"], st + le64(len(label)) + label + le64(len(data)) + data)
    return st


def parse_receipt(sh, raw):
    lay, sl = sh.layout(), sh.slots()
    a, h = sh.claim_sites()
    terms = [a[s] + h[s] + int(s >= IO_IN) for s in range(N_SLOTS)]
    pos = [0]

    def take(k):
        b = raw[pos[0]:pos[0] + k]
        assert len(b) == k, "truncated"
        pos[0] += k
        return b
    magic, binding = take(8), take(32)
    roots = dict(A=take(32), H=take(32), M=take(32))
    for s, (m, e, d) in enumerate(sl):
        take(16 * (1 + (m + e) * (d + 1) + terms[s]))

    def columns(rows, depth):
        out = []
        for _ in range(Q_OPEN):
            j = int.from_bytes(take(8), "little")
            col = take(8 * rows)
            salt = take(32)
            path = [take(32) for _ in range(depth)]
            out.append((j, col, salt, path))
        return out
    take(2 * 1024 * 16)
    opens = {"M": columns(M_ROWS, 12)}
    depth, vec = clog2(sh.n * sh.inv_rate), (sh.n + Q_OPEN) * 16
    take((sh.a_groups() + 1) * vec)
    opens["A"] = columns(lay["a_rows"], depth)
    take((sh.h_groups() + 1) * vec)
    opens["H"] = columns(lay["h_rows"], depth)
    e_n = 1 << sh.e_log
    e_depth = clog2(e_n * sh.e_rate)
    for name in ("Input", "Output"):
        take(2 * (e_n + Q_OPEN) * 16)
        opens[name] = columns(sh.e_rows, e_depth)
    assert pos[0] == len(raw), "trailing bytes"
    return magic, binding, roots, opens


def authenticate(opens, roots, keys):
    """pcs.rs:1248-1249 (verify_zk_tagged), zk.rs:671-672, merkle.rs:102-109"""
    ok, bad = 0, 0
    for name, cols in opens.items():
        for j, col, salt, path in cols:
            leaf = kh(keys["leaf"], kh(keys["column"], col) + salt)
            cur, idx = leaf, j
            for sib in path:
                cur = kh(keys["node"], cur + sib) if idx & 1 == 0 else kh(keys["node"], sib + cur)
                idx >>= 1
            if cur == roots[name]:
                ok += 1
            else:
                bad += 1
    return ok, bad


def bundle_checks(name):
    shkey, path = BUNDLES[name]
    sh = SHAPES[shkey]
    out = dict(path=path)
    if not os.path.exists(os.path.join(path, "receipt.bin")):
        out["available"] = False
        return out
    raw = open(os.path.join(path, "receipt.bin"), "rb").read()
    blk = json.load(open(os.path.join(path, "block.json")))
    exp = open(os.path.join(path, "expected.bin"), "rb").read()
    out["frame_bytes_measured"] = len(raw)
    out["frame_bytes_counted_here"] = frame_bytes(sh)[0]
    out["frame_length_agrees"] = len(raw) == frame_bytes(sh)[0]
    out["parameter_line_here_equals_capture"] = sh.parameter_line() == blk["parameter_line"]
    # the policy frame (private_block.rs:998-1007)
    assert len(exp) == 112 and exp[:8] == b"HBLKEXP1"
    in_root, out_root = exp[48:80], exp[80:112]
    out["policy"] = dict(magic_ok=True, context_nonzero=exp[8:40] != bytes(32),
                         scales=(int.from_bytes(exp[40:44], "little", signed=True), int.from_bytes(exp[44:48], "little", signed=True)),
                         input_root_ne_output_root=in_root != out_root,
                         equals_capture_expected_policy=list(exp) == blk["expected_policy"])
    if blake3 is None:
        out["blake3"] = "unavailable: hash checks skipped"
        return out
    keys = tag_keys(sh.profile)
    out["tag_keys_equal_capture"] = all(keys[r].hex() == blk["hash_tag"]["keys_hex"][r] for r in CTX)
    calib = blake3.blake3(b"B3 public fixed calibration v1").digest()   # private_block.rs:365-367
    out["calibration_identity_equals_capture"] = list(calib) == blk["calibration"]
    sched = blake3.blake3()
    sched.update(b"hashline/private-block-schedule/1")                  # layout.rs:1333-1341
    for line in blk["layout_description"]:
        sched.update(le64(len(line.encode())) + line.encode())
    out["schedule_digest_from_layout_description_equals_capture"] = list(sched.digest()) == blk["schedule_digest"]
    words = [(b"expected-IO", exp), (b"public-statement", bytes(blk["public_statement_digest"])),
             (b"parameters", sh.parameter_line().encode()), (b"calibration", calib), (b"schedule", sched.digest())]
    st = header_state(sh.profile, keys, words)
    magic, binding, roots, opens = parse_receipt(sh, raw)
    out["envelope"] = dict(magic=magic.decode(), binding_recomputed_equals_frame=st == binding,
                           frame_binding_equals_capture=list(binding) == blk["block_binding"])
    roots["Input"], roots["Output"] = in_root, out_root
    ok, bad = authenticate(opens, roots, keys)
    out["opened_columns_authenticated_under_the_block_keys"] = dict(ok=ok, failed=bad)
    # the adversarial endpoint checks on the REAL receipts
    distinct = {k: len({j for j, *_ in v}) for k, v in opens.items()}
    out["distinct_opened_columns"] = dict(distinct, total=sum(distinct.values()))
    salt_owner = {}
    cross = 0
    within_same_index_same_salt = True
    for k, v in opens.items():
        seen = {}
        for j, col, salt, _ in v:
            if j in seen and seen[j] != salt:
                within_same_index_same_salt = False
            seen[j] = salt
            if salt in salt_owner and salt_owner[salt] != (k, j):
                cross += 1
            salt_owner[salt] = (k, j)
    out["salts"] = dict(distinct_published=len(salt_owner), pairs_shared_between_two_leaf_positions=cross,
                        a_repeated_index_repeats_its_salt=within_same_index_same_salt)
    ins = {j: col for j, col, _, _ in opens["Input"]}
    outs = {j: col for j, col, _, _ in opens["Output"]}
    shared = sorted(set(ins) & set(outs))
    data = sh.e_data_rows()
    zero_words_in_data_rows = sum(1 for col in list(ins.values()) + list(outs.values())
                                  for r in range(data) if col[8 * r:8 * r + 8] == bytes(8))
    out["endpoints"] = dict(indices_opened_in_both=len(shared),
                            identical_column_at_a_shared_index=sum(1 for j in shared if ins[j] == outs[j]),
                            identical_mask_rows_at_a_shared_index=sum(1 for j in shared if ins[j][8 * data:] == outs[j][8 * data:]),
                            zero_field_words_in_opened_data_rows=zero_words_in_data_rows,
                            opened_data_row_words=data * (len(ins) + len(outs)),
                            input_root_ne_output_root=in_root != out_root)
    return out


# ============================================================ residuals
def lg(x):
    x = Fraction(x)
    return math.log2(x.numerator) - math.log2(x.denominator)


def residuals(fp_draws, n_leaf, a_q, m_keys, q_log2=128, n_unpublished=None):
    q, t256 = Fraction(1 << q_log2), Fraction(1, 1 << 256)
    r = 1 << 128
    rr = r % P
    per_draw_sd = Fraction(rr * (P - rr), P * r)              # exact, rng.rs:73-77
    t = {"sampler (D9), draws x 2^-96": Fraction(fp_draws, 1 << 96),
         "sampler, exact per-draw SD x draws": per_draw_sd * fp_draws,
         "salt guessing q N_leaf 2^-256": q * n_leaf * t256,
         "leaf-input collision C(N_leaf,2) 2^-256": Fraction(n_leaf * (n_leaf - 1) // 2) * t256,
         "challenge pre-query q A 2^-256": q * a_q * t256,
         "absorb collision C(A,2) 2^-256": Fraction(a_q * (a_q - 1) // 2) * t256,
         "constructor-vs-absorb (A+q) 2^-256": (a_q + q) * t256,
         "tag-key collision C(m,2) 2^-256": Fraction(m_keys * (m_keys - 1) // 2) * t256,
         "tag key = generator key 12 x 2^-256": 12 * t256,
         "generator in-model 6q 2^-256": 6 * q * t256}
    if n_unpublished is not None:
        t["salt guessing over UNPUBLISHED salts only"] = q * n_unpublished * t256
    hashes = {k: v for k, v in t.items() if not k.startswith("sampler") and "UNPUBLISHED" not in k}
    big = max(hashes, key=hashes.get)
    total = t["sampler (D9), draws x 2^-96"] + sum(hashes.values())
    return dict(log2={k: round(lg(v), 4) for k, v in t.items()}, largest_hash_term=big,
                gap_bits=round(lg(t["sampler (D9), draws x 2^-96"]) - lg(hashes[big]), 3),
                total_log2=round(lg(total), 4), per_draw_sd_log2=round(lg(per_draw_sd), 10),
                per_draw_sd_below_2_96=per_draw_sd < Fraction(1, 1 << 96))


# ================================================================ main
STAGE36 = {  # lane ledger lines 11771-11787, MEASURED
    "toy": dict(block_bytes=5396672, block_fp=320908, salts=8192, squeezes=1863, replay=1027, frame=2816472, E_each=3072),
    "rung_k4": dict(block_bytes=12401856, block_fp=750540, salts=12288, squeezes=2610, replay=1642, frame=4743128, E_each=7424),
    "rung_p2": dict(block_bytes=12401056, block_fp=750490, salts=12288, squeezes=2604, replay=1642, frame=4742728, E_each=7424),
    "rung_c6": dict(block_bytes=17654944, block_fp=1078858, salts=12288, squeezes=3977, replay=2962, frame=7452040, E_each=10496),
    "rung_w14": dict(block_bytes=100308416, block_fp=5998940, salts=135168, squeezes=2254, replay=1156, frame=16421048, E_each=84224),
    "rung_e32": dict(block_bytes=25356928, block_fp=1560232, salts=12288, squeezes=5919, replay=4874, frame=11368824, E_each=14592),
}
GATE_9J = {  # joint-view ledger §R9j.7 (rung-G) / §R9j.8 (125M), MEASURED
    "rung_g": dict(challenges=2036, counter=2356, A_unknowns=None, a_rows=623, h_rows=576, a_claims=122, h_claims=53, groups=(36, 9)),
    "m125": dict(challenges=13932, counter=14252, A_unknowns=5484800, a_rows=5681, h_rows=7120, a_claims=122, h_claims=51, groups=(36, 9)),
}
TOY_ABSORBS_T3 = 317   # ZK60_TOY_ROUTE_A_REEXAMINATION.md row T3 (as quoted by lane stage 36, S36-F1)


def main():
    res = {"controls_stage36_measured": {}, "targets": {}, "bundles": {}, "keys": {}}
    all_ok = True
    for k, want in STAGE36.items():
        sh = SHAPES[k]
        d, t = draws(sh), transcript_counts(sh)
        got = dict(block_bytes=d["block_bytes"], block_fp=d["block_fp"], salts=d["block_salts"],
                   squeezes=t["squeezes"], replay=t["replay_points"], frame=frame_bytes(sh)[0], E_each=d["E_each"])
        ok = got == want
        all_ok &= ok
        res["controls_stage36_measured"][k] = dict(got=got, want=want, ok=ok)
    toy_abs = transcript_counts(SHAPES["toy"])["absorbs"]
    res["controls_stage36_measured"]["toy absorbs (row T3)"] = dict(got=toy_abs, want=TOY_ABSORBS_T3, ok=toy_abs == TOY_ABSORBS_T3)
    toy_proof = draws(SHAPES["toy"])["proof_fp"]
    res["controls_stage36_measured"]["toy per-proof draws (D9 / D22)"] = dict(got=toy_proof, want=327052, ok=toy_proof == 327052)
    all_ok &= toy_abs == TOY_ABSORBS_T3 and toy_proof == 327052

    for k in ("rung_g", "m125"):
        sh = SHAPES[k]
        lay, d, t = sh.layout(), draws(sh), transcript_counts(sh)
        fb, parts, terms = frame_bytes(sh)
        g = GATE_9J[k]
        n_leaf = 2 * sh.n * sh.inv_rate + (1 << MASK_LOG_DOM) + 2 * (1 << sh.e_log) * sh.e_rate
        gate_cmp = dict(challenges=(t["challenges"], g["challenges"]), counter=(t["squeezes"], g["counter"]),
                        a_rows=(lay["a_rows"], g["a_rows"]), h_rows=(lay["h_rows"], g["h_rows"]),
                        a_claims=(lay["a_claims"], g["a_claims"]), h_claims=(lay["h_claims"], g["h_claims"]),
                        groups=((t["a_groups"], t["h_groups"]), g["groups"]))
        if g["A_unknowns"]:
            gate_cmp["A blinding unknowns (R9j.8 B11)"] = (d["A"], g["A_unknowns"])
        gate_ok = all(a == b for a, b in gate_cmp.values())
        all_ok &= gate_ok
        res["targets"][k] = dict(
            profile=sh.profile, layout={x: lay[x] for x in ("a_data", "h_data", "a_rows", "h_rows", "a_claims", "h_claims")},
            slots=sh.slots(), sum_L=d["sum_L"], rounds=t["rounds"],
            draws={x: d[x] for x in ("A", "H", "M", "block_fp", "block_salts", "E_each", "E_salts_each", "proof_fp", "proof_salts")},
            sampler_log2=round(lg(Fraction(d["proof_fp"], 1 << 96)), 4),
            transcript={x: t[x] for x in ("slot_definition_draws", "squeezes", "challenges", "replay_points", "absorbs", "F_T_queries_A")},
            per_slot_definition_draws=t["per_slot_definition_draws"],
            frame_bytes=fb, frame_parts=parts, N_leaf=n_leaf,
            against_the_gate=dict(pairs={x: list(v) if not isinstance(v[0], tuple) else [list(v[0]), list(v[1])] for x, v in gate_cmp.items()}, ok=gate_ok),
            parameter_line=sh.parameter_line(),
            constructor_input_bytes=12 + len(sh.profile),
            residuals_m28=residuals(d["proof_fp"], n_leaf, t["F_T_queries_A"], 28),
            residuals_m32=residuals(d["proof_fp"], n_leaf, t["F_T_queries_A"], 32),
            a_million_proofs=dict(sampler=round(lg(Fraction(10**6 * d["proof_fp"], 1 << 96)), 3),
                                  salt_guessing=round(lg(Fraction(1 << 128) * 10**6 * n_leaf * Fraction(1, 1 << 256)), 3)),
            logup_two_world_log2=round(lg(Fraction(2 * 768, P * P)), 3),
            liveness_4_over_p_log2=round(lg(Fraction(4, P)), 3))

    if blake3 is not None:
        keys = []
        for k in TAGGED_REGISTERED:
            for r, v in tag_keys(SHAPES[k].profile).items():
                keys.append((SHAPES[k].profile, r, v))
        k8 = [(K8_PROFILE, r, v) for r, v in tag_keys(K8_PROFILE).items()]
        runs = [(p, r, v) for p in RUN_PROFILES for r, v in tag_keys(p).items()]
        vals = [v for *_, v in keys]
        res["keys"] = dict(registered_tagged_profiles=len(TAGGED_REGISTERED), keys=len(keys),
                           pairwise_distinct=len(set(vals)) == len(vals),
                           with_k8_distinct=len({v for *_, v in keys + k8}) == len(keys) + 4,
                           with_run_would_be_sets_distinct=len({v for *_, v in keys + k8 + runs}) == len(keys) + 4 + 4 * len(RUN_PROFILES))
        all_ok &= res["keys"]["pairwise_distinct"]
        for name in BUNDLES:
            b = bundle_checks(name)
            res["bundles"][name] = b
            if b.get("frame_bytes_measured") is not None:
                all_ok &= b["frame_length_agrees"] and b["parameter_line_here_equals_capture"]
            if "envelope" in b:
                all_ok &= b["envelope"]["binding_recomputed_equals_frame"] and b["opened_columns_authenticated_under_the_block_keys"]["failed"] == 0
    # ---- extras the findings cite
    ex = {}
    k4 = draws(SHAPES["rung_k4"])
    ex["rung_k4: block stream (stage 36 in situ) + both endpoints (replica) = per proof"] = dict(
        block=k4["block_fp"], endpoints=2 * k4["E_each"], per_proof=k4["proof_fp"],
        per_proof_log2=round(lg(Fraction(k4["proof_fp"], 1 << 96)), 4),
        block_only_log2=round(lg(Fraction(k4["block_fp"], 1 << 96)), 4))
    # every constructor input length vs the squeeze's 47 and the shortest ACTUAL absorb on a block
    ctor = {p: 12 + len(p) for p in [s.profile for s in SHAPES.values()] + [K8_PROFILE, FROZEN_SEAM_RUNG] + RUN_PROFILES}
    labels_data = [(b"expected-IO", 112), (b"public-statement", 32), (b"parameters", min(len(SHAPES[k].parameter_line()) for k in ("rung_g", "m125"))), (b"calibration", 32),
                   (b"schedule", 32), (b"A", 32), (b"H", 32), (b"M", 32), (b"rows", 8), (b"log-cols", 8),
                   (b"pb-slot", 8), (b"pb-scalar", 16), (b"pb-term", 16), (b"sc-round", 16 * 3),
                   (b"mask-q", 16 * 1024), (b"mask-prox", 16 * 1024), (b"pcs-vec", 16 * 264), (b"pcs-prox", 16 * 264)]
    shortest_absorb = min(48 + len(l) + d for l, d in labels_data)
    ex["constructor lengths"] = dict(any_equals_47=any(v == 47 for v in ctor.values()), lengths=ctor,
                                     shortest_actual_absorb_input_on_a_block=shortest_absorb,
                                     block_constructors_below_every_actual_absorb=all(ctor[SHAPES[k].profile] < shortest_absorb for k in ("rung_g", "m125")))
    for k in ("rung_g", "m125"):
        d = draws(SHAPES[k])
        ex[f"{k}: one-sided vs two-world sampler"] = dict(one_sided=round(lg(Fraction(d["proof_fp"], 1 << 96)), 4),
                                                          two_world=round(lg(Fraction(2 * d["proof_fp"], 1 << 96)), 4))
    # the draft's own JSON, read AFTER everything above is computed, for a figure-by-figure comparison
    draft_json = "/home/victor/IntelligenceRegulation/results/zk60_hash_layer_standalone_block/standalone_block_hash_counts.json"
    if os.path.exists(draft_json):
        dj = json.load(open(draft_json))
        cmp = {}
        for k, dk in (("rung_g", "rung_g_standalone_block"), ("m125", "m125_standalone_block")):
            mine, theirs = res["targets"][k], dj["configurations"][dk]
            pairs = {
                "proof fp draws": (mine["draws"]["proof_fp"], theirs["draws"]["fp_total"]),
                "A/H/M draws": ([mine["draws"][x] for x in "AHM"], [theirs["draws"]["parts"][x] for x in "AHM"]),
                "endpoint draws each": (mine["draws"]["E_each"], theirs["draws"]["endpoint_stream_each"]["fp"]),
                "salts per proof": (mine["draws"]["proof_salts"], theirs["draws"]["salts_total"]),
                "F_T absorbs": (mine["transcript"]["absorbs"], theirs["prover_queries"]["F_T_absorbs"]),
                "F_T squeezes": (mine["transcript"]["squeezes"], theirs["prover_queries"]["F_T_live_squeezes_MEASURED"]),
                "slot definition draws": (mine["transcript"]["slot_definition_draws"], theirs["prover_queries"]["implied_slot_definition_draws"]),
                "A (F_T queries)": (mine["transcript"]["F_T_queries_A"], theirs["prover_queries"]["F_T_total_A"]),
                "sampler log2": (mine["sampler_log2"], theirs["sampler_log2"]),
                "salt guessing log2": (mine["residuals_m28"]["log2"]["salt guessing q N_leaf 2^-256"],
                                       theirs["residuals q=2^128, m=28 (production registry at 544fbaf)"]["terms"]["salt guessing: q N_leaf 2^-256"]),
                "gap bits": (round(mine["residuals_m28"]["gap_bits"], 2), theirs["residuals q=2^128, m=28 (production registry at 544fbaf)"]["gap_sampler_to_largest_hash_term_bits"]),
            }
            cmp[k] = {x: dict(mine=a, draft=b, equal=a == b) for x, (a, b) in pairs.items()}
        ex["draft figures, compared after the fact"] = cmp
    res["extras"] = ex
    res["ALL_CONTROLS_AND_CROSS_CHECKS_PASS"] = all_ok
    json.dump(res, sys.stdout, indent=1, default=lambda o: o.hex() if isinstance(o, bytes) else str(o))
    print()
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())

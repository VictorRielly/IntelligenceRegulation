#!/usr/bin/env python3
"""O4 -- the attention argument's source inventory (FA8 blockers A1-A4).

Reviewer: Opus 5, independent reviewer, 2026-09-08 session (continuation of
Fable's FA6 A1-A4 handoff; Fable's completed analyses stay credited to Fable).

Source pin: b41d036 (`hashline/src/attention.rs` sha256 c5ae80dd...), worktree
`/home/victor/wt-zk60-fa` at a8a1bc7.

WHAT THIS TOOL IS
-----------------
An *inventory*, not a repair.  It rebuilds, from the pinned Rust source, the
exact public/P0 attention schedule of the fixed A00 profile (T32 / d16 / f16,
H=2, KV=1, head_dim=8, INT16 classes, 2 norm limbs, log_cols 8) and reports:

  A1  every sumcheck slot in transcript order with (n_vars, degree), its
      claimed-sum form, its terminal descriptors, and every claim it raises
      (commitment, slice offset, log size, point, data rows, group key);
      then the four `collapse_range` proofs, the LogUp helper/zero-sum rows
      and the pads/columns budget.
  A2  the (n_vars, degree) list a CFS mask commitment for a PRIVATE attention
      would need, derived from those slots; FA6's surjectivity criterion is
      applied per slot by importing `scripts/zk60_fable_cfs_channel.py`
      read-only (no algebra is re-derived here), plus the mask-commitment
      layout constraint L_s + 256 <= 512 (`zk.rs::mask_commit`).
  A3  the attention-side seam endpoints (`SeamXm8[c]`, `SeamZ16c[c]`) and the
      residual seam, with the rows they open and the aliasing they create.
  A4  what the public residual seam / chain expose per block and across two
      linked blocks.

Every number the tool derives is cross-checked against constants that are
*independently* fixed in the source (public_block_wire.rs ATTN_SC, the
collapse round list, the 4/108/106 commitment rows, the 133|135 claim count,
and A01's executed event counts).  A disagreement is a hard failure: the
model is wrong, not the source.

NOTHING HERE IS A REPAIR, A PRIVACY VERDICT, OR A CLOSED BLOCKER.  Attention
is a public/P0 argument at this pin; the private mask kinds quoted from FA3
are that document's specification applied as a *classification* of attention
sites, so that Codex can see which sites would be scalar-masked.

    python3 scripts/zk60_opus_attention_inventory.py \
        --out results/zk60_opus_attention_inventory.json
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent

REVIEWER = "Opus 5, independent reviewer, 2026-09-08 session"
SOURCE_COMMIT = "b41d036"
WORKTREE_HEAD = "a8a1bc7"

# ---------------------------------------------------------------------------
# 0. the fixed A00 / B3 profile (causal_oracle.rs:20-24, :94-147)
# ---------------------------------------------------------------------------

PROFILE = {
    "t": 32,            # causal_oracle.rs:20
    "d": 16,            # causal_oracle.rs:21
    "f": 16,            # causal_oracle.rs:22
    "heads": 2,         # causal_oracle.rs:23
    "kv_heads": 1,      # causal_oracle.rs:106
    "head_dim": 8,      # causal_oracle.rs:24
    "x_cls": "Int16",   # causal_oracle.rs:115
    "ao_cls": "Int16",  # causal_oracle.rs:130
    "r1_cls": "Int16",  # causal_oracle.rs:134
    "r2_cls": "Int16",  # causal_oracle.rs:145
    "n_limb_a": 2,      # causal_oracle.rs:94 (NormConsts.n_limbs)
    "n_limb_m": 2,
    "log_cols": 8,      # A00 params
    "inv_rate": 8,
    "num_col_checks": 256,
    "sh_ao": 7, "sh_r1": 0, "sh_r2": 0, "sh_q": 7, "sh_k": 7, "sh_v": 7,
    "sh_qr": 7, "sh_kr": 7, "sh_s": 6, "sh_o": 9, "f_p": 9, "wrho_s": 14,
}

# independently fixed in the source -- the model must reproduce these
SOURCE_CONSTANTS = {
    # public_block_wire.rs:21-35 (rounds, width = degree + 1)
    "attn_sc": [(9, 4), (5, 4), (9, 5), (9, 5), (8, 5), (11, 6),
                (11, 4), (8, 5), (4, 3), (3, 4), (5, 4), (4, 3)],
    # public_block_wire.rs:114 -- collapse sumcheck round counts, width 3
    "collapse_rounds": [14, 13, 11, 10],
    # public_block_wire.rs:117-121 -- (W, A, H) commitment rows
    "rows": {"w": 4, "a": 108, "h": 106},
    # public_block_wire.rs:106 -- 133 (B3 block) or 135 (B4 receipt)
    "vals": [133, 135],
    # ZK60_ATTENTION_SCHEDULE.md (A01) executed event counts
    "a01": {"a_claims": 89, "w_claims": 6, "h_eval_claims": 19, "h_sum_claims": 19,
            "vals": 133, "terminal_descriptors": 99, "lookup_descriptors": 30,
            "histogram_tags": 10, "sumchecks": 12, "collapses": 4,
            "prover_checks": 12, "replay_checks": 24},
    # public_block_oracle.rs:196-205 -- short-W adapter preconditions
    "short_w": {"cols_log": 8, "log_wkv": 7, "wk": 256, "wv": 384, "w_len": 1024},
    # zk.rs:374-375, :442
    "mask_log_dom": 12, "mask_q": 256, "mask_msg": 512,
}


def ceil_log2(n: int) -> int:
    l = 0
    while (1 << l) < n:
        l += 1
    return l


class Alloc:
    """attention.rs:944-956 -- align-up bump allocator."""

    def __init__(self) -> None:
        self.off = 0

    def take(self, log: int) -> int:
        sz = 1 << log
        o = -(-self.off // sz) * sz
        self.off = o + sz
        return o


class Layout:
    """Exact port of `AttnLayout::new` (attention.rs:1026-1105)."""

    def __init__(self, p: Dict) -> None:
        t, d = p["t"], p["d"]
        dp = 1 << ceil_log2(d)
        hp = 1 << ceil_log2(p["heads"])
        kp = p["kv_heads"]
        hd = p["head_dim"]
        qp, vp = hp * hd, kp * hd
        rep, rep_p = p["heads"] // kp, hp // kp
        self.t, self.dp, self.hp, self.kp, self.hd, self.qp, self.vp = t, dp, hp, kp, hd, qp, vp
        self.rep, self.rep_p = rep, rep_p
        self.log_t = t.bit_length() - 1
        self.log_dp = dp.bit_length() - 1
        self.log_hp = hp.bit_length() - 1
        self.log_qp = qp.bit_length() - 1
        self.log_vp = vp.bit_length() - 1
        self.log_hd = hd.bit_length() - 1
        self.log_kp = kp.bit_length() - 1
        self.log_d = self.log_t + self.log_dp
        self.log_q = self.log_t + self.log_qp
        self.log_kv = self.log_t + self.log_vp
        self.log_s = self.log_hp + 2 * self.log_t
        min_dom = min(self.log_d, self.log_q, self.log_kv, self.log_s)
        self.cols_log = min(p["log_cols"], min_dom)
        self.log_sm = max(ceil_log2(2 * hp * t + 8 * t), self.cols_log)
        self.log_lm = max(ceil_log2(8 * t), self.cols_log + 1)
        n_cls = {"Int24": 2}.get  # Cls::Int24 -> 2 limbs, else 1 (attention.rs:1035-1038)
        al = Alloc()

        def cls_plane(cls: str) -> List[int]:
            n = n_cls(cls) or 1
            return [al.take(self.log_d) for _ in range(n)]

        self.x_in = cls_plane(p["x_cls"])
        self.xn8 = al.take(self.log_d)
        self.rho_a = [al.take(self.log_d) for _ in range(p["n_limb_a"])]
        self.sig_a = [al.take(self.log_d) for _ in range(p["n_limb_a"])]
        self.q8, self.rq, self.qr8, self.rqr, self.o8, self.ro = (
            al.take(self.log_q) for _ in range(6))
        self.k8, self.rk, self.v8, self.rv, self.kr8, self.rkr = (
            al.take(self.log_kv) for _ in range(6))
        self.s8, self.rs, self.zsel, self.et, self.pp, self.rho_s = (
            al.take(self.log_s) for _ in range(6))
        self.ao = cls_plane(p["ao_cls"])
        self.rao = al.take(self.log_d)
        self.xres1 = cls_plane(p["r1_cls"])
        self.rr1 = al.take(self.log_d)
        self.xm8 = al.take(self.log_d)
        self.rho_m = [al.take(self.log_d) for _ in range(p["n_limb_m"])]
        self.sig_m = [al.take(self.log_d) for _ in range(p["n_limb_m"])]
        self.xres2 = cls_plane(p["r2_cls"])
        self.rr2 = al.take(self.log_d)
        self.z16c = al.take(self.log_d)
        self.sm = al.take(self.log_sm)
        self.lm = al.take(self.log_lm)
        cols = 1 << self.cols_log
        self.a_len = -(-al.off // cols) * cols
        # ---- W ----
        self.log_wq = self.log_dp + self.log_qp
        self.log_wkv = self.log_dp + self.log_vp
        self.log_gp = max(ceil_log2(2 * dp), self.cols_log)
        wl = Alloc()
        self.wq = wl.take(self.log_wq)
        self.wk = wl.take(self.log_wkv)
        self.wv = wl.take(self.log_wkv)
        self.wo = wl.take(self.log_wq)
        self.gpack = wl.take(self.log_gp)
        self.w_len = -(-wl.off // cols) * cols
        # ---- H ----
        hl = Alloc()

        def pair(n: int, log: int) -> List[Tuple[int, int]]:
            return [(hl.take(log), hl.take(log)) for _ in range(n)]

        self.n_d = -(-(1 + len(self.x_in) + 2 * p["n_limb_a"] + 2 * p["n_limb_m"]
                       + len(self.ao) + 1 + len(self.xres1) + 1 + len(self.xres2)
                       + 1 + 1 + 1) // 2)
        self.h_d = pair(self.n_d, self.log_d)
        self.h_q = pair(3, self.log_q)
        self.h_kv = pair(3, self.log_kv)
        self.h_s = pair(3, self.log_s)
        self.h_lm = (hl.take(self.log_lm - 1), hl.take(self.log_lm - 1))
        self.h_len = -(-hl.off // cols) * cols

    # attention.rs:1112-1121
    def sm_m(self) -> int:
        return self.sm

    def sm_sum(self) -> int:
        return self.sm + self.hp * self.t

    def sm_row(self, site: int, k: int) -> int:
        return self.sm + 2 * self.hp * self.t + (4 * site + k) * self.t

    def lm_row(self, site: int, k: int) -> int:
        return self.lm + (4 * site + k) * self.t

    def rows(self, length: int) -> int:
        return length >> self.cols_log


# ---------------------------------------------------------------------------
# 1. symbolic points (challenge coordinates as names; constants as "0" / "1")
# ---------------------------------------------------------------------------

Point = Tuple[str, ...]


def vec(name: str, n: int) -> List[str]:
    return [f"{name}[{i}]" for i in range(n)]


def sub_point(base: int, base_log: int, off: int, sub_log: int, r: Sequence[str]) -> List[str]:
    """attention.rs:1126-1137."""
    assert len(r) == sub_log, (len(r), sub_log)
    idx = (off - base) >> sub_log
    hi = base_log - sub_log
    return [("1" if (idx >> b) & 1 else "0") for b in reversed(range(hi))] + list(r)


def flip(pt: Sequence[str], k: int) -> List[str]:
    """attention.rs:2413-2414 / :2453-2454 -- one coordinate replaced by 1 - x."""
    out = list(pt)
    out[k] = f"1-{out[k]}"
    return out


# ---------------------------------------------------------------------------
# 2. the executed schedule (attention.rs::attn_argument, sections 1-13)
# ---------------------------------------------------------------------------

class Claim:
    __slots__ = ("index", "com", "site", "offset", "log_size", "point", "is_sum",
                 "section", "role", "parts", "src", "raw_offset", "raw_log_size",
                 "raw_point", "lifted")

    def __init__(self, index: int, com: str, site: str, offset: int, log_size: int,
                 point: Sequence[str], section: str, role: str, src: str,
                 is_sum: bool = False, parts: int = 1) -> None:
        self.index, self.com, self.site = index, com, site
        self.offset, self.log_size = offset, log_size
        self.point = tuple(point)
        self.is_sum, self.parts = is_sum, parts
        self.section, self.role, self.src = section, role, src
        self.raw_offset, self.raw_log_size, self.raw_point = offset, log_size, tuple(point)
        self.lifted = False

    def lift(self, cols_log: int, w_len: int) -> None:
        """public_block_oracle.rs:181-224 -- the tiny short-W adapter.

        A W claim on a 2^7 half-row is lifted to its enclosing 2^8 committed
        row by fixing the leading point bit; the vector and the claimed value
        are unchanged.  Applied on both sides after argument collection and
        before opening, so GROUPING sees the lifted claim.
        """
        if self.is_sum or self.log_size >= cols_log:
            return
        base = self.offset // (1 << cols_log) * (1 << cols_log)
        assert base + (1 << cols_log) <= w_len
        self.point = tuple(sub_point(base, cols_log, self.offset, self.log_size,
                                     self.point))
        self.offset, self.log_size, self.lifted = base, cols_log, True

    def data_rows(self, cols_log: int) -> int:
        return 1 << (self.log_size - cols_log)

    def group_key(self, cols_log: int) -> Optional[Point]:
        """zkp-core/src/pcs.rs:232-238 -- None for sum claims, else the point tail."""
        if self.is_sum:
            return None
        lr = self.log_size - cols_log
        return tuple(self.point[lr:])

    def to_json(self, cols_log: int) -> Dict:
        key = self.group_key(cols_log)
        out = {
            "index": self.index, "commitment": self.com, "site": self.site,
            "section": self.section, "role": self.role, "source": self.src,
            "offset": self.offset, "log_size": self.log_size,
            "data_rows": self.data_rows(cols_log), "parts": self.parts,
            "sum_claim": self.is_sum, "point": list(self.point),
            "group_key": None if key is None else list(key),
        }
        if self.lifted:
            out["short_w_lifted_from"] = {
                "offset": self.raw_offset, "log_size": self.raw_log_size,
                "point": list(self.raw_point),
                "adapter": "public_block_oracle.rs:181-224 lift_public_weight_claims",
            }
        return out


class Slot:
    __slots__ = ("index", "section", "name", "main_rounds", "degree", "claimed_sum",
                 "claimed_sum_kind", "terminals", "src", "poly", "public_factor",
                 "private_factors")

    def __init__(self, index: int, section: str, name: str, main_rounds: int, degree: int,
                 claimed_sum: str, claimed_sum_kind: str, src: str, poly: str,
                 public_factor: Optional[str], private_factors: int) -> None:
        self.index, self.section, self.name = index, section, name
        self.main_rounds, self.degree = main_rounds, degree
        self.claimed_sum, self.claimed_sum_kind = claimed_sum, claimed_sum_kind
        self.src, self.poly = src, poly
        self.public_factor, self.private_factors = public_factor, private_factors
        self.terminals: List[Dict] = []


def build_schedule(lay: Layout) -> Tuple[List[Slot], List[Claim], Dict]:
    """Walk `attn_argument` in transcript order, recording every claim and slot."""
    claims: List[Claim] = []
    slots: List[Slot] = []
    sec_of: Dict[int, str] = {}

    def claim(com: str, site: str, off: int, log: int, pt: Sequence[str], section: str,
              role: str, src: str, is_sum: bool = False, parts: int = 1) -> None:
        claims.append(Claim(len(claims), com, site, off, log, pt, section, role, src,
                            is_sum, parts))

    def terms(slot: Slot, descs: List[Dict], section: str, src: str) -> None:
        """attention.rs:1846-1882 -- one TabDesc per terminal table, in order."""
        for i, d in enumerate(descs):
            slot.terminals.append(dict(d, index=i))
            if d["kind"] == "Pub":
                continue
            if d["kind"] == "ACls":
                for off in d["offsets"]:
                    claim("A", d["site"], off, d["log"], d["point"], section,
                          "terminal (class limb)", src)
            elif d["kind"] == "H":
                claim("H", d["site"], d["re"], d["log"], d["point"], section,
                      "terminal (helper pair)", src, parts=2)
            else:
                claim(d["kind"], d["site"], d["offset"], d["log"], d["point"], section,
                      "terminal", src)

    lt, ld, lq, lkv, ls = lay.log_t, lay.log_d, lay.log_q, lay.log_kv, lay.log_s
    lsm, llm = lay.log_sm, lay.log_lm

    # ---------------- section 1: isqrt row facts + SS row sums ---------------
    sec = "1 norm row facts and SS sums"
    r_t = vec("r_t", lt)
    for site in range(2):
        for k, nm in enumerate(["D", "Dsq", "a1", "a2"]):
            off = lay.sm_row(site, k)
            claim("A", f"sm[{nm} site {site}]", lay.sm, lsm,
                  sub_point(lay.sm, lsm, off, lt, r_t), sec, "pre-sumcheck claim_sub",
                  "attention.rs:2241-2244")
        for k in range(4):
            off = lay.lm_row(site, k)
            claim("A", f"lm[limb {k} site {site}]", lay.lm, llm,
                  sub_point(lay.lm, llm, off, lt, r_t), sec, "pre-sumcheck claim_sub",
                  "attention.rs:2245-2247")
    s = Slot(0, sec, "SS row sums", ld, 3,
             "ss[0] + lam_ss*ss[1], each a linear form in the 16 claim_sub values above",
             "derived-from-claims (PRIVATE under a hiding profile)",
             "attention.rs:2257", "eq * (X^2 + lam*xres1^2)", "eq(r_t) rows", 2)
    u1 = vec("rho_SS", ld)
    terms(s, [
        {"kind": "Pub", "site": "eq(r_t, rho[..log_t])", "note": "attention.rs:2266"},
        {"kind": "ACls", "site": "x_in (class recon)", "offsets": list(lay.x_in),
         "log": ld, "point": u1},
        {"kind": "ACls", "site": "xres1 (class recon)", "offsets": list(lay.xres1),
         "log": ld, "point": u1},
    ], sec, "attention.rs:2265-2273")
    slots.append(s)

    # ---------------- section 2: Dsq = D*D -----------------------------------
    sec = "2 norm squares"
    s = Slot(1, sec, "D^2", lt, 3, "public ZERO", "public-zero",
             "attention.rs:2281", "eq * mu-batched (Dsq - D*D)", "eq(tau1)", 2)
    u2 = vec("rho_Dsq", lt)
    d2 = [{"kind": "Pub", "site": "eq(tau1, rho)", "note": "attention.rs:2288"}]
    for site in range(2):
        for k in range(2):
            d2.append({"kind": "A", "site": f"sm[{'D' if k == 0 else 'Dsq'} site {site}]",
                       "offset": lay.sm, "log": lsm,
                       "point": sub_point(lay.sm, lsm, lay.sm_row(site, k), lt, u2)})
    terms(s, d2, sec, "attention.rs:2288-2296")
    slots.append(s)

    # ---------------- section 3: D-domain zero-check -------------------------
    sec = "3 D ranges norm and residuals"
    d_offs = ([lay.x_in[0]] + [lay.xn8] + lay.rho_a + lay.sig_a + [lay.xm8]
              + lay.rho_m + lay.sig_m + list(lay.ao) + [lay.rao] + list(lay.xres1)
              + [lay.rr1] + list(lay.xres2) + [lay.rr2] + [lay.z16c])
    d_names = (["x_in"] + ["xn8"] + [f"rho_a[{i}]" for i in range(len(lay.rho_a))]
               + [f"sig_a[{i}]" for i in range(len(lay.sig_a))] + ["xm8"]
               + [f"rho_m[{i}]" for i in range(len(lay.rho_m))]
               + [f"sig_m[{i}]" for i in range(len(lay.sig_m))] + ["ao"] + ["rao"]
               + ["xres1"] + ["rr1"] + ["xres2"] + ["rr2"] + ["z16c"])
    assert len(d_offs) == len(d_names)
    s = Slot(2, sec, "zero-check D", ld, 4, "public ZERO", "public-zero",
             "attention.rs:2334", "eq * (hcon lookup pairs + 2 NormDiv)", "eq(tau_d)", 2)
    u3 = vec("rho_D", ld)
    d3 = [{"kind": "Pub", "site": "eq(tau_d, rho)", "note": "attention.rs:2347"}]
    for off, nm in zip(d_offs, d_names):
        d3.append({"kind": "A", "site": nm, "offset": off, "log": ld, "point": u3})
    ri = u3[lt:]
    d3.append({"kind": "W", "site": "gpack[gamma_A]", "offset": lay.gpack, "log": lay.log_gp,
               "point": sub_point(lay.gpack, lay.log_gp, lay.gpack, lay.log_dp, ri)})
    d3.append({"kind": "W", "site": "gpack[gamma_M]", "offset": lay.gpack, "log": lay.log_gp,
               "point": sub_point(lay.gpack, lay.log_gp, lay.gpack + lay.dp, lay.log_dp, ri)})
    for site in range(2):
        d3.append({"kind": "A", "site": f"sm[D site {site}] (bcast row)", "offset": lay.sm,
                   "log": lsm,
                   "point": sub_point(lay.sm, lsm, lay.sm_row(site, 0), lt, u3[:lt])})
    for i, (re, im) in enumerate(lay.h_d):
        d3.append({"kind": "H", "site": f"h_d[{i}]", "re": re, "im": im, "log": ld,
                   "point": u3})
    terms(s, d3, sec, "attention.rs:2347-2364")
    slots.append(s)

    # ---------------- section 4: Q-domain zero-check -------------------------
    sec = "4 Q ranges and RoPE"
    q_offs = [lay.q8, lay.rq, lay.qr8, lay.rqr, lay.o8, lay.ro]
    q_names = ["q8", "rq", "qr8", "rqr", "o8", "ro"]
    s = Slot(3, sec, "zero-check Q", lq, 4, "public ZERO", "public-zero",
             "attention.rs:2398", "eq * (3 hcon pairs + Rope)", "eq(tau_q)", 2)
    u4 = vec("rho_Q", lq)
    flip_q = lay.log_t + lay.log_hp
    d4 = [{"kind": "Pub", "site": "eq(tau_q, rho)", "note": "attention.rs:2415"}]
    for off, nm in zip(q_offs, q_names):
        d4.append({"kind": "A", "site": nm, "offset": off, "log": lq, "point": u4})
    d4.append({"kind": "A", "site": "q8 @ FLIPPED point (rotate-half)", "offset": lay.q8,
               "log": lq, "point": flip(u4, flip_q)})
    d4.append({"kind": "Pub", "site": "RoPE C(rt, ri)", "note": "attention.rs:2417"})
    d4.append({"kind": "Pub", "site": "RoPE S'(rt, ri)", "note": "attention.rs:2418"})
    for i, (re, im) in enumerate(lay.h_q):
        d4.append({"kind": "H", "site": f"h_q[{i}]", "re": re, "im": im, "log": lq,
                   "point": u4})
    terms(s, d4, sec, "attention.rs:2415-2420")
    slots.append(s)

    # ---------------- section 5: KV-domain zero-check ------------------------
    sec = "5 KV ranges and RoPE"
    kv_offs = [lay.k8, lay.rk, lay.v8, lay.rv, lay.kr8, lay.rkr]
    kv_names = ["k8", "rk", "v8", "rv", "kr8", "rkr"]
    s = Slot(4, sec, "zero-check KV", lkv, 4, "public ZERO", "public-zero",
             "attention.rs:2438", "eq * (3 hcon pairs + Rope)", "eq(tau_kv)", 2)
    u5 = vec("rho_KV", lkv)
    flip_kv = lay.log_t + lay.log_kp   # attention.rs:2437
    d5 = [{"kind": "Pub", "site": "eq(tau_kv, rho)", "note": "attention.rs:2455"}]
    for off, nm in zip(kv_offs, kv_names):
        d5.append({"kind": "A", "site": nm, "offset": off, "log": lkv, "point": u5})
    d5.append({"kind": "A", "site": "k8 @ FLIPPED point (rotate-half)", "offset": lay.k8,
               "log": lkv, "point": flip(u5, flip_kv)})
    d5.append({"kind": "Pub", "site": "RoPE C(rt, ri)", "note": "attention.rs:2457"})
    d5.append({"kind": "Pub", "site": "RoPE S'(rt, ri)", "note": "attention.rs:2458"})
    for i, (re, im) in enumerate(lay.h_kv):
        d5.append({"kind": "H", "site": f"h_kv[{i}]", "re": re, "im": im, "log": lkv,
                   "point": u5})
    terms(s, d5, sec, "attention.rs:2455-2460")
    slots.append(s)

    # ---------------- section 6: softmax zero-check --------------------------
    sec = "6 softmax identities and ranges"
    s = Slot(5, sec, "zero-check S", ls, 5, "public ZERO", "public-zero",
             "attention.rs:2471", "eq * (c0..c5) -- SPlan", "eq(tau_s)", 2)
    u6 = vec("rho_S", ls)
    n_ht = lay.log_hp + lay.log_t
    d6 = [{"kind": "Pub", "site": "eq(tau_s, rho)", "note": "attention.rs:2487"}]
    for off, nm in [(lay.s8, "s8"), (lay.rs, "rs"), (lay.zsel, "zsel"),
                    (lay.et, "et"), (lay.pp, "pp"), (lay.rho_s, "rho_s")]:
        d6.append({"kind": "A", "site": nm, "offset": off, "log": ls, "point": u6})
    d6.append({"kind": "A", "site": "sm[m] (row max, bcast)", "offset": lay.sm, "log": lsm,
               "point": sub_point(lay.sm, lsm, lay.sm_m(), n_ht, u6[:n_ht])})
    d6.append({"kind": "A", "site": "sm[Sum] (row sum, bcast)", "offset": lay.sm, "log": lsm,
               "point": sub_point(lay.sm, lsm, lay.sm_sum(), n_ht, u6[:n_ht])})
    d6.append({"kind": "Pub", "site": "causal mask MLE", "note": "attention.rs:2497"})
    for i, (re, im) in enumerate(lay.h_s):
        d6.append({"kind": "H", "site": f"h_s[{i}]", "re": re, "im": im, "log": ls,
                   "point": u6})
    terms(s, d6, sec, "attention.rs:2485-2501")
    slots.append(s)

    # ---------------- section 7: masked row sums -----------------------------
    sec = "7 masked row sums and selector"
    p_ht = vec("p_ht", n_ht)
    claim("A", "sm[Sum]", lay.sm, lsm, sub_point(lay.sm, lsm, lay.sm_sum(), n_ht, p_ht),
          sec, "pre-sumcheck claim_sub", "attention.rs:2509-2510")
    s = Slot(6, sec, "row sums", ls, 3,
             "sum_cl + lam_z (sum_cl is the claim_sub value above)",
             "derived-from-claims (PRIVATE under a hiding profile)",
             "attention.rs:2513", "eq * (mask*E + lam*zsel)", "eq(p_ht) x causal mask", 2)
    u7 = vec("rho_rowsum", ls)
    terms(s, [
        {"kind": "Pub", "site": "eq(p_ht, rho[..n_ht])", "note": "attention.rs:2522"},
        {"kind": "Pub", "site": "causal mask MLE", "note": "attention.rs:2523"},
        {"kind": "A", "site": "et", "offset": lay.et, "log": ls, "point": u7},
        {"kind": "A", "site": "zsel", "offset": lay.zsel, "log": ls, "point": u7},
    ], sec, "attention.rs:2521-2526")
    slots.append(s)

    # ---------------- section 8: packed limb zero-check ----------------------
    sec = "8 packed norm limb ranges"
    s = Slot(7, sec, "zero-check LM", llm - 1, 4, "public ZERO", "public-zero",
             "attention.rs:2540", "eq * hcon", "eq(tau_l)", 2)
    u8 = vec("rho_LM", llm - 1)
    half_lm = 1 << (llm - 1)
    terms(s, [
        {"kind": "Pub", "site": "eq(tau_l, rho)", "note": "attention.rs:2547"},
        {"kind": "A", "site": "lm[lower half]", "offset": lay.lm, "log": llm,
         "point": sub_point(lay.lm, llm, lay.lm, llm - 1, u8)},
        {"kind": "A", "site": "lm[upper half]", "offset": lay.lm, "log": llm,
         "point": sub_point(lay.lm, llm, lay.lm + half_lm, llm - 1, u8)},
        {"kind": "H", "site": "h_lm", "re": lay.h_lm[0], "im": lay.h_lm[1],
         "log": llm - 1, "point": u8},
    ], sec, "attention.rs:2547-2554")
    slots.append(s)

    # ---------------- section 9: QKV matmul ----------------------------------
    sec = "9 QKV projections"
    rq_t = vec("rq_t", lt)
    r_jq = vec("r_jq", lay.log_qp)
    r_jk = vec("r_jk", lay.log_vp)
    r_jv = vec("r_jv", lay.log_vp)
    pq, pk, pv2 = rq_t + r_jq, rq_t + r_jk, rq_t + r_jv
    for off, nm, pt in [(lay.q8, "q8", pq), (lay.rq, "rq", pq), (lay.k8, "k8", pk),
                        (lay.rk, "rk", pk), (lay.v8, "v8", pv2), (lay.rv, "rv", pv2)]:
        log = lq if off in (lay.q8, lay.rq) else lkv
        claim("A", nm, off, log, pt, sec, "pre-sumcheck claim_at",
              "attention.rs:2569-2574")
    s = Slot(8, sec, "QKV matmul", lay.log_dp, 2,
             "acc_q + lam_k*acc_k + lam_v*acc_v (six claim_at values above)",
             "derived-from-claims (PRIVATE under a hiding profile)",
             "attention.rs:2578", "xn8 * (Wq + lam_k Wk + lam_v Wv)", None, 1)
    u9 = vec("rho_QKV", lay.log_dp)
    terms(s, [
        {"kind": "A", "site": "xn8", "offset": lay.xn8, "log": ld, "point": rq_t + u9},
        {"kind": "W", "site": "Wq", "offset": lay.wq, "log": lay.log_wq, "point": u9 + r_jq},
        {"kind": "W", "site": "Wk", "offset": lay.wk, "log": lay.log_wkv, "point": u9 + r_jk},
        {"kind": "W", "site": "Wv", "offset": lay.wv, "log": lay.log_wkv, "point": u9 + r_jv},
    ], sec, "attention.rs:2589-2594")
    slots.append(s)

    # ---------------- section 10: score matmul -------------------------------
    sec = "10 GQA score product"
    p_s = vec("p_s", ls)
    claim("A", "s8", lay.s8, ls, p_s, sec, "pre-sumcheck claim_at", "attention.rs:2601")
    claim("A", "rs", lay.rs, ls, p_s, sec, "pre-sumcheck claim_at", "attention.rs:2602")
    r_sh = p_s[:lay.log_hp]
    r_st = p_s[lay.log_hp:lay.log_hp + lt]
    r_sj = p_s[lay.log_hp + lt:]
    r_hi, r_lo = r_sh[:lay.log_kp], r_sh[lay.log_kp:]
    s = Slot(9, sec, "score matmul", lay.log_kp + lay.log_hd, 3,
             "cs8*2^sh_s + crs (two claim_at values above)",
             "derived-from-claims (PRIVATE under a hiding profile)",
             "attention.rs:2608", "eq_g * QR * KR", "eq(r_hi) -- CONSTANT 1 at kp=1", 2)
    u10 = vec("rho_score", lay.log_kp + lay.log_hd)
    rg, ri10 = u10[:lay.log_kp], u10[lay.log_kp:]
    terms(s, [
        {"kind": "Pub", "site": "eq(r_hi, rg)", "note": "attention.rs:2641; == 1 at kp=1"},
        {"kind": "A", "site": "qr8", "offset": lay.qr8, "log": lq,
         "point": r_st + rg + r_lo + ri10},
        {"kind": "A", "site": "kr8", "offset": lay.kr8, "log": lkv,
         "point": r_sj + rg + ri10},
    ], sec, "attention.rs:2640-2647")
    slots.append(s)

    # ---------------- section 11: PV matmul ----------------------------------
    sec = "11 probability value product"
    p_o = vec("p_o", lq)
    claim("A", "o8", lay.o8, lq, p_o, sec, "pre-sumcheck claim_at", "attention.rs:2654")
    claim("A", "ro", lay.ro, lq, p_o, sec, "pre-sumcheck claim_at", "attention.rs:2655")
    r_ot = p_o[:lt]
    r_oh = p_o[lt:lt + lay.log_hp]
    r_oi = p_o[lt + lay.log_hp:]
    r_ohi, r_olo = r_oh[:lay.log_kp], r_oh[lay.log_kp:]
    s = Slot(10, sec, "PV matmul", lay.log_kp + lt, 3,
             "co8*2^sh_o + cro (two claim_at values above)",
             "derived-from-claims (PRIVATE under a hiding profile)",
             "attention.rs:2660", "eq_g * P * V", "eq(r_ohi) -- CONSTANT 1 at kp=1", 2)
    u11 = vec("rho_pv", lay.log_kp + lt)
    rg11, rj11 = u11[:lay.log_kp], u11[lay.log_kp:]
    terms(s, [
        {"kind": "Pub", "site": "eq(r_ohi, rg)", "note": "attention.rs:2693; == 1 at kp=1"},
        {"kind": "A", "site": "pp", "offset": lay.pp, "log": ls,
         "point": rg11 + r_olo + r_ot + rj11},
        {"kind": "A", "site": "v8", "offset": lay.v8, "log": lkv,
         "point": rj11 + rg11 + r_oi},
    ], sec, "attention.rs:2692-2699")
    slots.append(s)

    # ---------------- section 12: Wo matmul ----------------------------------
    sec = "12 output projection"
    p_a = vec("p_a", ld)
    for k, off in enumerate(lay.ao):
        claim("A", f"ao (class limb {k})", off, ld, p_a, sec, "pre-sumcheck claim_at",
              "attention.rs:2707")
    claim("A", "rao", lay.rao, ld, p_a, sec, "pre-sumcheck claim_at", "attention.rs:2710")
    r_at, r_an = p_a[:lt], p_a[lt:]
    s = Slot(11, sec, "Wo matmul", lay.log_qp, 2,
             "ao_v*2^sh_ao + crao (the ao class limbs + rao claim_at values above)",
             "derived-from-claims (PRIVATE under a hiding profile)",
             "attention.rs:2714", "o8 * Wo", None, 1)
    u12 = vec("rho_Wo", lay.log_qp)
    terms(s, [
        {"kind": "A", "site": "o8", "offset": lay.o8, "log": lq, "point": r_at + u12},
        {"kind": "W", "site": "Wo", "offset": lay.wo, "log": lay.log_wq, "point": u12 + r_an},
    ], sec, "attention.rs:2722-2725")
    slots.append(s)

    # ---------------- section 13: LogUp helper sums --------------------------
    sec = "13 LogUp helper histogram identity"
    all_h = ([(x, ld, f"h_d[{i}]") for i, x in enumerate(lay.h_d)]
             + [(x, lq, f"h_q[{i}]") for i, x in enumerate(lay.h_q)]
             + [(x, lkv, f"h_kv[{i}]") for i, x in enumerate(lay.h_kv)]
             + [(x, ls, f"h_s[{i}]") for i, x in enumerate(lay.h_s)]
             + [(lay.h_lm, llm - 1, "h_lm")])
    for (re, im), log, nm in all_h:
        claim("H", f"{nm} SUM", re, log, [], sec, "helper sum (Cc::hsum, empty point)",
              "attention.rs:2745-2747", is_sum=True, parts=2)

    # ---------------- the internal FFN seam (nb_d = 1) -----------------------
    sec = "S internal FFN seam (attn_seam)"
    seam_pt = vec("rho_zcd_seam", ld)
    claim("A", "xm8 (SeamXm8[0])", lay.xm8, ld, seam_pt, sec,
          "seam claim_at (FFN X endpoint)", "attention.rs:2905")
    claim("A", "z16c (SeamZ16c[0])", lay.z16c, ld, seam_pt, sec,
          "seam claim_at (FFN z16 endpoint)", "attention.rs:2906")

    n_block = len(claims)

    # ---------------- B4 receipt only: the external I/O binding --------------
    sec = "E external I/O binding (bind_endpoints, B4 receipt only)"
    for role, plane, nm in [("external-input", lay.x_in, "x_in"),
                            ("external-output", lay.xres2, "xres2")]:
        pt = vec(f"p_{role.replace('-', '_')}", ld)
        for k, off in enumerate(plane):
            claim("A", f"{nm} (class limb {k})", off, ld, pt, sec,
                  f"cls_claim, role {role}", "public_block_receipt.rs:270-273")
    n_receipt = len(claims)

    # the short-W adapter, applied exactly where the source applies it: after
    # argument collection and the seam, before the openings
    n_lifted = 0
    for c in claims:
        if c.com == "W" and not c.is_sum and c.log_size < lay.cols_log:
            c.lift(lay.cols_log, lay.w_len)
            n_lifted += 1

    meta = {"n_block_claims": n_block, "n_receipt_claims": n_receipt,
            "short_w_claims_lifted": n_lifted}
    return slots, claims, meta


# ---------------------------------------------------------------------------
# 3. the collapse plan (attention.rs:3089-3126)
# ---------------------------------------------------------------------------

def blocks(lo: int, hi: int) -> List[Tuple[int, int]]:
    out: List[Tuple[int, int]] = []
    off = lo
    while off < hi:
        log = (hi - off).bit_length() - 1
        while off % (1 << log) != 0:
            log -= 1
        out.append((off, log))
        off += 1 << log
    return out


def collapse_plan(lay: Layout) -> List[Tuple[int, int]]:
    """DEFAULT mode (HL_FOLD unset): the binary decomposition of [0, a_len)."""
    return blocks(0, lay.a_len)


# ---------------------------------------------------------------------------
# 4. the LogUp tables (attention.rs:2022-2071, tables_attn.rs)
# ---------------------------------------------------------------------------

def rem_rows(sh: int) -> int:
    """layer.rs::rem_rows -- balanced round-requant window of a signed shift."""
    return 1 if sh <= 0 else (1 << sh)


def lookup_tables(lay: Layout, p: Dict) -> List[Dict]:
    """The distinct LogUp tables and their required totals (`lookup_totals`)."""
    ld, lq, lkv, ls = lay.log_d, lay.log_q, lay.log_kv, lay.log_s
    d_tbls = (["Int16"] + ["Int8"] + ["U16"] * (2 * p["n_limb_a"]) + ["Int8"]
              + ["U16"] * (2 * p["n_limb_m"]) + ["Int16", f"Win({p['sh_ao']})",
                                                 "Int16", f"Win({p['sh_r1']})",
                                                 "Int16", f"Win({p['sh_r2']})", "Int16"])
    q_tbls = ["Int8", f"Win({p['sh_q']})", "Int8", f"Win({p['sh_qr']})",
              "Int8", f"Win({p['sh_o']})"]
    kv_tbls = ["Int8", f"Win({p['sh_k']})", "Int8", f"Win({p['sh_v']})",
               "Int8", f"Win({p['sh_kr']})"]
    totals: Dict[str, int] = {}

    def add(t: str, n: int) -> None:
        totals[t] = totals.get(t, 0) + n

    for t in d_tbls:
        add(t, 1 << ld)
    for t in q_tbls:
        add(t, 1 << lq)
    for t in kv_tbls:
        add(t, 1 << lkv)
    add("Int8", 1 << ls)
    add(f"Win({p['sh_s']})", 1 << ls)
    add("Exp", 1 << ls)
    add("Prob", 1 << ls)
    add(f"Srem({p['wrho_s']})", 2 * (1 << ls))
    add("U16", 1 << lay.log_lm)

    def size(t: str) -> int:
        if t in ("Int8", "Exp"):
            return 256
        if t in ("Int16", "U16"):
            return 1 << 16
        if t == "Prob":
            return (1 << p["f_p"]) + 1
        if t.startswith("Srem("):
            return 1 << int(t[5:-1])
        if t.startswith("Win("):
            return rem_rows(int(t[4:-1]))
        raise AssertionError(t)

    n = 1 << lay.cols_log
    out = []
    for t in sorted(totals):
        rows = max(size(t), n) // n
        out.append({
            "table": t, "table_rows": size(t), "required_total": totals[t],
            "mask_block_rows_if_hidden": rows,
            "mask_kind_under_FA3_rule": "block" if rows >= 2 else "pair (single-row slot)",
        })
    return out


# ---------------------------------------------------------------------------
# 5. the derived CFS slot table (A2) and FA6's criterion
# ---------------------------------------------------------------------------

def load_fa6():
    """Import FA6's tool read-only (its algebra is reused, never re-derived)."""
    spec = importlib.util.spec_from_file_location(
        "zk60_fable_cfs_channel", HERE / "zk60_fable_cfs_channel.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def cfs_slot_table(lay: Layout, slots: List[Slot], p3: bool = False) -> List[Dict]:
    """The (n_vars, degree) a private-attention mask commitment would need.

    n_vars = main rounds + extension rounds (FA6 section 1.1).  The extension
    count is DERIVED from the slot's polynomial, using `mask_specs_v3`'s rule
    (zk.rs:2138-2147): the extension round is an identity only when
    poly(exts) = 0, so a round with ONE private factor family (the others
    public, extending to 0) needs one extension round, and a round that
    multiplies TWO private factors needs two (one per side).  This is a
    DERIVATION, not an implemented specification -- no attention CFS slot
    exists in source at this pin.
    """
    out = []
    for s in slots:
        if s.public_factor is not None and "CONSTANT 1" not in s.public_factor:
            ext, why = 1, "one public factor (eq) extends to 0"
        elif s.private_factors >= 2:
            ext, why = 2, ("two private factors in one round; no public factor vanishes "
                           "(mask_specs_v3's P3 rationale, zk.rs:2140-2145)")
        else:
            ext, why = 1, "activation private, weights public under P1 (weight ext 0)"
        if p3 and s.name in ("QKV matmul", "Wo matmul"):
            ext, why = 2, "P3: private weights need the second extension round"
        n_vars = s.main_rounds + ext
        out.append({
            "slot": f"SC_ATTN_{s.index:02d}", "name": s.name, "section": s.section,
            "main_rounds": s.main_rounds, "ext_rounds": ext, "ext_rationale": why,
            "n_vars": n_vars, "degree": s.degree,
            "cfs_len": n_vars * s.degree + 2,
            "claimed_sum_form": s.claimed_sum_kind,
            "claimed_sum": s.claimed_sum,
            "source": s.src,
        })
    return out


def collapse_cfs_slots(plan: List[Tuple[int, int]]) -> List[Dict]:
    out = []
    for i, (base, log) in enumerate(plan):
        n_vars = log + 1
        out.append({
            "slot": f"SC_ATTN_COLLAPSE_{i}", "name": f"collapse block {i}",
            "section": "L5 claim collapse", "main_rounds": log, "ext_rounds": 1,
            "ext_rationale": "G(x) (the nu-weighted eq table) is public and extends to 0",
            "n_vars": n_vars, "degree": 2, "cfs_len": n_vars * 2 + 2,
            "claimed_sum_form": "derived-from-claims (sum_c nu_c * claim value)",
            "claimed_sum": "sum_c nu_c * claims[c].value (attention.rs:3014-3017)",
            "source": "attention.rs:3004",
            "note": ("A1/A03 (ZK60_PRIVATE_BLOCK.md item 5) requires the first private "
                     "profile to be NO-COLLAPSE; this row exists only if collapse is kept."),
        })
    return out


def run_fa6_criterion(fa6, table: List[Dict]) -> List[Dict]:
    """FA6 section 2.2's criterion per slot: rank(map) == dim S, image inside S."""
    rng = fa6.Rng(6)
    out = []
    for row in table:
        slots = {row["slot"]: {"n_vars": row["n_vars"], "degree": row["degree"],
                               "claim": row["claimed_sum_form"],
                               "ext_rounds": row["ext_rounds"]}}
        fa6._finish(slots)           # asserts cfs_len + 256 <= 512 (mask_commit)
        ch, meta = fa6.system_single(slots, row["slot"], rng)
        res = fa6.analyze_system(ch, meta)
        out.append({
            "slot": row["slot"], "name": row["name"],
            "n_vars": row["n_vars"], "degree": row["degree"], "cfs_len": row["cfs_len"],
            "n_unknowns_fp2": res["n_unknowns_fp2"], "n_view_fp2": res["n_view_fp2"],
            "rank_map": res["rank_map"],
            "dim_consistency_subspace": res["dim_consistency_subspace"],
            "image_inside_subspace": res["image_inside_subspace"],
            "leaked_dim_fp2": res["leaked_dim_fp2"],
            "kernel_dim_fp2": res["kernel_dim_fp2"],
            "verdict": res["verdict"],
            "m_functionals_in_view_span": res["m_functionals_in_view_span"],
            "theta_combination_in_view_span": res["theta_combination_in_view_span"],
            "row_budget_L_plus_256_le_512": row["cfs_len"] + 256 <= 512,
        })
    return out


# ---------------------------------------------------------------------------
# 6. report assembly and the self-checks
# ---------------------------------------------------------------------------

def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


SOURCE_FILES = [
    "hashline/src/attention.rs", "hashline/src/attention_schedule.rs",
    "hashline/src/public_block_wire.rs", "hashline/src/public_block_receipt.rs",
    "hashline/src/public_block_oracle.rs", "hashline/src/public_chain_receipt.rs",
    "hashline/src/private_seam.rs", "hashline/src/chain.rs", "hashline/src/norm.rs",
    "hashline/src/tables_attn.rs", "hashline/src/causal_oracle.rs",
    "hashline/src/zk.rs", "hashline/src/pcs.rs", "zkp-core/src/pcs.rs",
    "zkp-core/src/sumcheck.rs",
    "scripts/zk60_fable_cfs_channel.py", "scripts/zk60_fable_joint_rank.py",
]


def build_report(run_ranks: bool = True) -> Dict:
    lay = Layout(PROFILE)
    slots, claims, meta = build_schedule(lay)
    plan = collapse_plan(lay)
    cols_log = lay.cols_log

    block_claims = claims[:meta["n_block_claims"]]
    receipt_claims = claims

    def counts(cs: List[Claim]) -> Dict[str, int]:
        return {
            "total": len(cs),
            "A": sum(1 for c in cs if c.com == "A"),
            "W": sum(1 for c in cs if c.com == "W"),
            "H_eval": sum(1 for c in cs if c.com == "H" and not c.is_sum),
            "H_sum": sum(1 for c in cs if c.com == "H" and c.is_sum),
        }

    def groups(cs: List[Claim], com: str) -> List[Dict]:
        keys: List[Optional[Point]] = []
        members: List[List[int]] = []
        for c in cs:
            if c.com != com:
                continue
            k = c.group_key(cols_log)
            if k in keys:
                members[keys.index(k)].append(c.index)
            else:
                keys.append(k)
                members.append([c.index])
        return [{"group": i, "key": None if k is None else list(k),
                 "sum_group": k is None, "members": m,
                 "sites": sorted({cs[j].site for j in m})}
                for i, (k, m) in enumerate(zip(keys, members))]

    idx = {c.index: c for c in claims}
    block_groups = {com: groups(block_claims, com) for com in ("A", "W", "H")}
    receipt_groups = {com: groups(receipt_claims, com) for com in ("A", "W", "H")}

    # aliasing: the same committed slice opened at several distinct points
    alias: Dict[Tuple[int, int], List[str]] = {}
    for c in claims:
        if c.is_sum:
            continue
        alias.setdefault((c.offset, c.log_size), []).append("/".join(c.point))
    aliased = [{"offset": o, "log_size": l, "distinct_points": len(set(v)),
                "claims": len(v)}
               for (o, l), v in sorted(alias.items()) if len(set(v)) > 1]

    terminals = sum(len(s.terminals) for s in slots)

    checks: List[Dict] = []

    def check(name: str, got, want) -> None:
        checks.append({"check": name, "got": got, "want": want, "pass": got == want})

    check("commitment rows (W, A, H) vs public_block_wire.rs:117-121",
          {"w": lay.rows(lay.w_len), "a": lay.rows(lay.a_len), "h": lay.rows(lay.h_len)},
          SOURCE_CONSTANTS["rows"])
    check("ATTN_SC (rounds, degree+1) vs public_block_wire.rs:21-35",
          [(s.main_rounds, s.degree + 1) for s in slots], SOURCE_CONSTANTS["attn_sc"])
    check("collapse block rounds vs public_block_wire.rs:114",
          [log for _, log in plan], SOURCE_CONSTANTS["collapse_rounds"])
    check("block claim-value count vs public_block_wire.rs:106",
          counts(block_claims)["total"], 133)
    check("receipt claim-value count vs public_block_receipt.rs:300",
          counts(receipt_claims)["total"], 135)
    a01 = SOURCE_CONSTANTS["a01"]
    check("A evaluations vs A01", counts(block_claims)["A"], a01["a_claims"])
    check("W evaluations vs A01", counts(block_claims)["W"], a01["w_claims"])
    check("H extension evaluations vs A01", counts(block_claims)["H_eval"],
          a01["h_eval_claims"])
    check("H extension sums vs A01", counts(block_claims)["H_sum"], a01["h_sum_claims"])
    check("terminal descriptors vs A01", terminals, a01["terminal_descriptors"])
    check("sumcheck count vs A01", len(slots), a01["sumchecks"])
    check("collapse count vs A01", len(plan), a01["collapses"])
    tables = lookup_tables(lay, PROFILE)
    check("distinct LogUp table tags vs A01", len(tables), a01["histogram_tags"])
    check("total attention lookups vs FA5 section 4.3 (N = 26624)",
          sum(t["required_total"] for t in tables), 26624)
    check("short-W claims lifted by the adapter", meta["short_w_claims_lifted"], 2)
    check("short-W adapter preconditions vs public_block_oracle.rs:196-205",
          {"cols_log": lay.cols_log, "log_wkv": lay.log_wkv, "wk": lay.wk,
           "wv": lay.wv, "w_len": lay.w_len}, SOURCE_CONSTANTS["short_w"])

    cfs_p1 = cfs_slot_table(lay, slots, p3=False)
    cfs_p3 = cfs_slot_table(lay, slots, p3=True)
    cfs_collapse = collapse_cfs_slots(plan)
    seam_slots = [{
        "slot": "SC_SEAM_X", "name": "FFN X seam (FA3 section 12; FA6 section 6)",
        "n_vars": lay.log_t + 4 + 1, "degree": 2,
        "cfs_len": (lay.log_t + 4 + 1) * 2 + 2,
        "owner": "the FFN M (FA6 section 6 (i)); the attention M carries NO seam slot",
        "status": "design-note (FA3-specified, not implemented at this pin)",
    }, {
        "slot": "SC_SEAM_Z", "name": "FFN z16 seam (FA3 section 12; FA6 section 6)",
        "n_vars": lay.log_t + 4 + 1, "degree": 2,
        "cfs_len": (lay.log_t + 4 + 1) * 2 + 2,
        "owner": "the FFN M (FA6 section 6 (i)); the attention M carries NO seam slot",
        "status": "design-note (FA3-specified, not implemented at this pin)",
    }]

    # ---- where a scalar base-field mask would remain (FA1/FA2's leak shape) --
    def scalar_analysis(gs: Dict[str, List[Dict]], cs: List[Claim]) -> Dict:
        by_index = {c.index: c for c in cs}
        out: Dict[str, Dict] = {}
        for com, rows in gs.items():
            singles, multi, sums = [], [], []
            for g in rows:
                m = len(g["members"])
                entry = {"group": g["group"], "members": m, "sites": g["sites"],
                         "sum_group": g["sum_group"],
                         "sections": sorted({by_index[i].section for i in g["members"]}),
                         "data_rows_per_member": sorted(
                             {by_index[i].data_rows(cols_log) for i in g["members"]}),
                         "legacy_port_mask": "ONE base row per member (scalar)",
                         "FA2_leak_if_scalar": ("n functionals per column (FA2 14.1: "
                                                "whole plane) -- singleton group"
                                                if m == 1 and not g["sum_group"] else
                                                "2 base functionals per group (FA2 14.2)"),
                         "FA3_kind_required": ("prox_pair" if g["sum_group"] is None
                                               else "pair")}
                if g["sum_group"]:
                    entry["FA3_kind_required"] = "zero_sum_pair + fresh pair (FA3 2.1)"
                    sums.append(entry)
                elif m == 1:
                    singles.append(entry)
                else:
                    multi.append(entry)
            out[com] = {
                "groups": len(rows), "singleton_groups": len(singles),
                "multi_member_groups": len(multi), "sum_groups": len(sums),
                "singletons": singles, "multi": multi, "sum": sums,
            }
        return out

    scalar = {
        "block_profile": scalar_analysis(block_groups, block_claims),
        "receipt_profile": scalar_analysis(receipt_groups, receipt_claims),
        "today": ("NO mask exists: attention commits with pcs::commit and opens with "
                  "pcs::open (attention.rs:2866-2885, :3213-3238); there is no mask row, "
                  "no pad, no salt, no CFS mask and no hiding commitment anywhere on the "
                  "attention path. Every row of this table is what a mask WOULD have to "
                  "cover, not what one covers."),
        "extra_scalar_sites": [
            {"site": "proximity mask row (per commitment)",
             "source": "zkp-core/src/pcs.rs:563 prox_mask_row: Option<usize>, :889",
             "note": ("A single reserved row; assert_mask_sites checks only that ONE row. "
                      "FA3 2.4 requires a prox PAIR and an extended assertion. The FFN's "
                      "mr1 path fills a 2-row range (zk.rs:2469 with mask_range) but still "
                      "names one row to the assertion.")},
            {"site": "the 19 LogUp helper SUM claims (Cc::hsum, empty point)",
             "source": "attention.rs:1823-1829, :2735-2753",
             "note": ("All 19 share one opening group (col_key None, all-ones column "
                      "weights). The FFN has exactly ONE such claim and masks it with a "
                      "zero_sum_pair plus a fresh pair h_up (FA2 14.5). Nineteen "
                      "independent sums over five different domains have no analogue in "
                      "FA2/FA3 and no inventory row anywhere.")},
            {"site": "collapse terminal `aval` (4 of them)",
             "source": "attention.rs:3040, :3054, :3063-3065",
             "note": ("A raw A evaluation absorbed in the clear and stored in "
                      "proof.collapse. ZK60_PRIVATE_BLOCK.md exposure item 5 requires the "
                      "first private profile to be NO-COLLAPSE.")},
            {"site": "class-reconstruction (ACls / cls_claim) limbs",
             "source": "attention.rs:1868-1878, :2920-2932",
             "note": ("Each limb is its own claim, so each needs its own mask row: a "
                      "single shared mask would leave limb DIFFERENCES in the clear "
                      "(zk.rs:1974-1977's rationale). Latent at this profile "
                      "(Cls::Int16 -> 1 limb); it bites under Cls::Int24 (2 limbs).")},
            {"site": "flipped-point RoPE claims (q8, k8)",
             "source": "attention.rs:2413-2416, :2453-2456",
             "note": ("FA3 2.3 item 6: a flipped-point claim is a separate group with its "
                      "own reserved pair. Each is a SINGLETON group here.")},
            {"site": "the public multiplicity histograms",
             "source": "attention.rs:1770-1776 (AttnProof.mults), :2831-2843 "
                       "(absorb_mults_a), :2735-2753 (the table side of the identity)",
             "note": ("Not a mask site: the histograms are published in full. A private "
                      "profile needs the FFN's committed-table construction; the "
                      "single-row table slots below are FA2 U10's pair-needed case.")},
        ],
    }

    ranks = None
    if run_ranks:
        fa6 = load_fa6()
        ranks = {
            "P1": run_fa6_criterion(fa6, cfs_p1),
            "P3": run_fa6_criterion(fa6, cfs_p3),
            "collapse": run_fa6_criterion(fa6, cfs_collapse),
        }
        for mode, rows in ranks.items():
            check(f"FA6 criterion: every derived attention slot surjective ({mode})",
                  all(r["leaked_dim_fp2"] == 0 and r["image_inside_subspace"]
                      for r in rows), True)
            check(f"mask row budget L+256<=512 ({mode})",
                  all(r["row_budget_L_plus_256_le_512"] for r in rows), True)

    largest = max(cfs_p1 + cfs_p3 + cfs_collapse, key=lambda r: r["cfs_len"])

    report = {
        "task": "O4 -- attention inventory (FA8 blockers A1-A4)",
        "reviewer": REVIEWER,
        "source_commit": SOURCE_COMMIT,
        "worktree_head": WORKTREE_HEAD,
        "worktree": "/home/victor/wt-zk60-fa",
        "limits": [
            "Design input only. Attention is a PUBLIC/P0 argument at this pin: "
            "pcs::commit / pcs::open, no hiding commitment, no CFS mask, no mask row.",
            "No repair is designed and no privacy blocker is closed by this document.",
            "The CFS slot table of section A2 is DERIVED from the executed schedule; "
            "no attention CFS slot exists in source. The FA6 rank verdicts therefore "
            "certify the derived (n_vars, degree) systems, not an implementation.",
            "Mask kinds quoted from FA3 are that document's specification applied as a "
            "classification; FA3's rank evidence is Fable's and is not re-run here.",
            "Stand-in challenge values (FA2's Rng), exact modular arithmetic; "
            "numerical rank is not a simulation proof (FA2 section 13, FA6 section 9).",
        ],
        "profile": PROFILE,
        "layout": {
            "log_t": lay.log_t, "log_dp": lay.log_dp, "log_hp": lay.log_hp,
            "log_qp": lay.log_qp, "log_vp": lay.log_vp, "log_hd": lay.log_hd,
            "log_kp": lay.log_kp, "log_d": lay.log_d, "log_q": lay.log_q,
            "log_kv": lay.log_kv, "log_s": lay.log_s, "log_sm": lay.log_sm,
            "log_lm": lay.log_lm, "cols_log": lay.cols_log,
            "a_len": lay.a_len, "w_len": lay.w_len, "h_len": lay.h_len,
            "a_rows": lay.rows(lay.a_len), "w_rows": lay.rows(lay.w_len),
            "h_rows": lay.rows(lay.h_len),
            "helper_pairs": {"h_d": lay.n_d, "h_q": 3, "h_kv": 3, "h_s": 3, "h_lm": 1},
            "planes": {
                "x_in": lay.x_in, "xn8": lay.xn8, "rho_a": lay.rho_a, "sig_a": lay.sig_a,
                "q8": lay.q8, "rq": lay.rq, "qr8": lay.qr8, "rqr": lay.rqr,
                "o8": lay.o8, "ro": lay.ro, "k8": lay.k8, "rk": lay.rk, "v8": lay.v8,
                "rv": lay.rv, "kr8": lay.kr8, "rkr": lay.rkr, "s8": lay.s8, "rs": lay.rs,
                "zsel": lay.zsel, "et": lay.et, "pp": lay.pp, "rho_s": lay.rho_s,
                "ao": lay.ao, "rao": lay.rao, "xres1": lay.xres1, "rr1": lay.rr1,
                "xm8": lay.xm8, "rho_m": lay.rho_m, "sig_m": lay.sig_m,
                "xres2": lay.xres2, "rr2": lay.rr2, "z16c": lay.z16c,
                "sm": lay.sm, "lm": lay.lm,
                "wq": lay.wq, "wk": lay.wk, "wv": lay.wv, "wo": lay.wo,
                "gpack": lay.gpack,
            },
        },
        "A1_schedule": {
            "sumchecks": [{
                "index": s.index, "section": s.section, "name": s.name,
                "main_rounds": s.main_rounds, "degree": s.degree,
                "n_vars_public_P0": s.main_rounds,
                "claimed_sum": s.claimed_sum, "claimed_sum_kind": s.claimed_sum_kind,
                "polynomial": s.poly, "public_vanishing_factor": s.public_factor,
                "private_factor_families": s.private_factors,
                "source": s.src, "terminals": s.terminals,
            } for s in slots],
            "collapse_proofs": [{
                "index": i, "base": base, "base_log": log, "rounds": log, "degree": 2,
                "claimed_sum": "sum_c nu_c * claims[c].value",
                "exposes": "one A evaluation `aval` at rho, absorbed in the clear "
                           "(attention.rs:3040, :3054) and stored in proof.collapse",
                "source": "attention.rs:3004 (sumcheck), :3097-3126 (plan)",
            } for i, (base, log) in enumerate(plan)],
            "claim_counts_block_profile": counts(block_claims),
            "claim_counts_receipt_profile": counts(receipt_claims),
            "terminal_descriptor_count": terminals,
            "claims": [c.to_json(cols_log) for c in claims],
            "opening_groups_block_profile": block_groups,
            "opening_groups_receipt_profile": receipt_groups,
            "group_counts_block_profile": {k: len(v) for k, v in block_groups.items()},
            "group_counts_receipt_profile": {k: len(v) for k, v in receipt_groups.items()},
            "aliased_slices": aliased,
            "logup_tables": tables,
            "pads_and_columns": {
                "log_cols": lay.cols_log, "cols": 1 << lay.cols_log,
                "inv_rate": PROFILE["inv_rate"],
                "num_col_checks": PROFILE["num_col_checks"],
                "encoded_cols": (1 << lay.cols_log) * PROFILE["inv_rate"],
                "merkle_path": 11,
                "q_pad_today": 0,
                "note": ("P0 today: pcs::commit / pcs::open have NO pads and NO salts "
                         "(zkp-core/src/pcs.rs:42). A hiding attention commitment would "
                         "need q_pad >= Q = 256 per row (pcs.rs:625, :947), turning each "
                         "row into RS(n + Q = 512, 2048) as FA5 section 4.3 records."),
            },
        },
        "A2_cfs_slots": {
            "derivation_note": (
                "n_vars = main rounds + extension rounds; the extension count follows "
                "mask_specs_v3's rule (zk.rs:2138-2147). NOT implemented at this pin."),
            "P1": cfs_p1, "P3": cfs_p3, "collapse_if_kept": cfs_collapse,
            "seam_slots_owned_by_the_FFN_M": seam_slots,
            "largest_slot": largest,
            "mask_commit_budget": {
                "message_positions": SOURCE_CONSTANTS["mask_msg"],
                "pads_per_row": SOURCE_CONSTANTS["mask_q"],
                "constraint": "L_s + 256 <= 512 (zk.rs:442)",
                "largest_L": largest["cfs_len"],
                "fits": largest["cfs_len"] + 256 <= SOURCE_CONSTANTS["mask_msg"],
                "headroom_coefficients": SOURCE_CONSTANTS["mask_msg"]
                - SOURCE_CONSTANTS["mask_q"] - largest["cfs_len"],
            },
            "rank_verdicts": ranks,
        },
        "A3_seam_endpoints": {
            "internal_FFN_seam": {
                "implemented": True,
                "source": "attention.rs:2899-2917 attn_seam; "
                          "public_block_oracle.rs:104-118, :235-251 seam_points; "
                          "public_block_receipt.rs:226-238",
                "blocks_nb_d": 1,
                "point": "the FFN zero-check-D challenge rho_d, replayed by "
                         "layer.rs::v3_zcd_point on a cloned transcript state "
                         "(absorbs nothing); drawn after BOTH A commitments",
                "endpoints": [
                    {"name": "SeamXm8[0]", "attention_row_set": "xm8",
                     "offset": lay.xm8, "log_size": lay.log_d,
                     "data_rows": 1 << (lay.log_d - cols_log),
                     "ffn_side": "zcd_term[..nb_d] (the FFN's X plane at rho_d)",
                     "check": "attention.rs:2905, :2909-2914 (clear equality today)",
                     "FA3_kind_required": "pair (a_sx-mirror on the attention A)",
                     "status_today": "PUBLIC value in AttnProof.vals"},
                    {"name": "SeamZ16c[0]", "attention_row_set": "z16c",
                     "offset": lay.z16c, "log_size": lay.log_d,
                     "data_rows": 1 << (lay.log_d - cols_log),
                     "ffn_side": "zcd_term[nb_d..2nb_d] (the FFN's z16 plane at rho_d)",
                     "check": "attention.rs:2906, :2909-2915",
                     "FA3_kind_required": "pair (a_sz-mirror on the attention A)",
                     "status_today": "PUBLIC value in AttnProof.vals"},
                ],
                "aliasing_created": [
                    {"row_set": "xm8", "opened_at": ["rho_D (zero-check D terminal)",
                                                     "rho_d (the seam)"],
                     "distinct_points": 2},
                    {"row_set": "z16c", "opened_at": ["rho_D (zero-check D terminal)",
                                                      "rho_d (the seam)"],
                     "distinct_points": 2},
                ],
                "one_shot_rule": ("attn_open_a is called once and consumes AttnPending by "
                                  "value (attention.rs:3223-3238), dropping a_cm and "
                                  "a_data; the seam claims must therefore be appended "
                                  "BEFORE it. Nothing in the type system marks a seam role "
                                  "as consumed exactly once -- FA3 4.1's role set does not "
                                  "exist on the attention side."),
                "row_cost_if_paired": {
                    "per_block": 2, "seam_roles": 2,
                    "extra_A_rows_at_this_profile": 4,
                    "basis": "FA3 section 8: +4 A rows for a_sx/a_sz at nb_d = 1",
                },
            },
            "experimental_standalone_seam_gadget": {
                "implemented": True,
                "used_on_the_attention_path": False,
                "source": "hashline/src/private_seam.rs (module doc :1-13); the only "
                          "consumer is hashline/tests/zk60_private_seam.rs",
                "mask_rows": 5,
                "mask_row_breakdown": ("2 terminal mask rows (re, im -- an Fp2 PAIR: "
                                       "private_seam.rs:33-35, :211-212) + 1 declared "
                                       "prox_mask_row + 2 further reserved rows"),
                "cfs_slot": {"n_vars": "log_len + 1", "degree": 2,
                             "source": "private_seam.rs:112-114 mask_spec"},
                "terminal_claim_form": ("3 parts: (data, 1-e, rho), (R_re, e, tail rho), "
                                        "(R_im, e*u, tail rho) -- private_seam.rs:257-283, "
                                        "exactly FA3's pair form"),
                "refusals": "c = 0 (private_seam.rs:358-360, :443-445); "
                            "e = 0 (:394-396, :452-454)",
                "note": ("This is A02/S2's gadget on TWO independently hiding commitments. "
                         "It is NOT what attn_seam does; attn_seam compares clear values "
                         "on non-hiding commitments."),
            },
        },
        "A4_residual_seam_and_chain": {
            "cross_layer_seam_in_source": {
                "implemented": True,
                "used_on_the_receipt_path": False,
                "source": "attention.rs:2935-2952 layer_seam, :2920-2932 cls_claim",
                "what_it_proves": "layer l's xres2 MLE == layer l+1's x_in MLE at one "
                                  "point drawn after BOTH layers' A commitments",
                "exposes": ("one cls_claim per side = one claim per class limb per side "
                            "(2 claims at this profile, 4 under Cls::Int24), each a raw "
                            "evaluation in AttnProof.vals; plus one clear equality check "
                            "(attention.rs:2941-2951)"),
                "row_sets": {"previous": "xres2", "current": "x_in"},
                "note": "FA5 R26 records that this gadget is NOT on the B5 chain path.",
            },
            "public_residual_seam_as_shipped": {
                "implemented": True,
                "source": "public_chain_receipt.rs:127-148 block_expectations; "
                          "public_block_receipt.rs:255-284 bind_endpoints; FA5 R26/R27",
                "mechanism": ("block 0's expected OUTPUT tensor and block 1's expected "
                              "INPUT tensor are the SAME 512 public INT16 words; each "
                              "block binds its own end of it with bind_endpoints, so the "
                              "residual is carried by a PUBLIC tensor, not by an MLE "
                              "equality between two commitments"),
                "exposes_per_block": [
                    "the full 512-word public input tensor and 512-word output tensor "
                    "(ExpectedPublicBlock, public_block_receipt.rs:17-19, :28-34)",
                    "2 extra A claims (x_in, xres2 class reconstruction) at 2 fresh "
                    "points -> 135 vals instead of 133 (public_block_receipt.rs:266-278)",
                    "2 extra A opening groups",
                ],
                "exposes_across_two_blocks": [
                    "the intermediate 512-word tensor in the clear "
                    "(PublicChainReceipt.intermediate, public_chain_receipt.rs:153-158)",
                    "both blocks' complete P0 proofs, each with its own 135 claim values, "
                    "12 sumchecks, 4 collapses and 3 non-hiding openings",
                    "the per-block context digest chain (public_chain_receipt.rs:118-125)",
                ],
                "what_a_private_profile_must_change": [
                    "the intermediate tensor cannot be published: the residual becomes an "
                    "MLE equality between block k's attention A and block k+1's attention "
                    "A, i.e. layer_seam's relation under a masked-equality gadget "
                    "(private_seam.rs's form) with its own CFS slot and reserved pair rows",
                    "block k's attention A may not finalize before block k+1 has bound the "
                    "residual seam (FA3 section 4.5), so a chain holds two AttnPending "
                    "objects; nothing in attention.rs enforces that ordering today",
                    "bind_endpoints' external I/O binding stays public only for the "
                    "declared boundary; every intermediate binding must move inside",
                ],
            },
            "chain_rs": {
                "role": "the exact-integer FFN witness derivation (chain.rs:1-15), NOT a "
                        "cross-block proof object; it produces the planes the FFN proof "
                        "consumes and the z digest the export gate compares",
                "attention_analogue": "attention.rs:661-732 witness_digests, :734-737 "
                                      "chain_from_export, :740-786 verify_export",
                "exposes": ("64 per-tensor SHA-256 digests plus one CHAIN digest of the "
                            "whole witness -- a diagnostic oracle comparison. "
                            "ZK60_PRIVATE_BLOCK.md exposure item 9: witness digests permit "
                            "dictionary testing and must stay out of public artifacts."),
            },
        },
        "scalar_mask_analysis": scalar,
        "checks": checks,
        "all_checks_pass": all(c["pass"] for c in checks),
        "source_sha256": {f: sha256_file(ROOT / f) for f in SOURCE_FILES},
        "tool_sha256": sha256_file(Path(__file__).resolve()),
    }
    return report


def main(argv: Optional[Sequence[str]] = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", default=None, help="write the JSON record here")
    ap.add_argument("--no-ranks", action="store_true",
                    help="skip the FA6 rank runs (structure only)")
    a = ap.parse_args(argv)
    rep = build_report(run_ranks=not a.no_ranks)
    text = json.dumps(rep, indent=2, sort_keys=True) + "\n"
    if a.out:
        p = Path(a.out)
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)
    for c in rep["checks"]:
        print(f"{'PASS' if c['pass'] else 'FAIL'}  {c['check']}")
        if not c["pass"]:
            print(f"      got  {c['got']}\n      want {c['want']}")
    print(f"\nall checks pass: {rep['all_checks_pass']}")
    return 0 if rep["all_checks_pass"] else 1


if __name__ == "__main__":
    sys.exit(main())

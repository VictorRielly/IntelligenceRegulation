#!/usr/bin/env python3
"""Soundness recount of the native private RUN at the trained profiles (2026-10-17).

[COUNTED] exact arithmetic, one thread, well under a second. No import from any
other lane: the few layout formulas needed for the lookup and sumcheck counts are
copied from `results/zk60_token_io_design_20261017/layout.py` (itself a replica of
`ops/zkp-mvp/trained-1b/hashline/src/private_block/shape.rs`) and re-checked here
against the Rust-counted rows and lookups (`results/zk60_1b_native_20261017/
r3-ladder-count.log`, R4 counted layouts in the same lane's logs).

What it computes, per profile (TinyLlama T32/T64/T128 x 22 blocks, Llama-3-8B
T32 x 32 blocks, plus the 125M twelve-block run as a reconciliation row):

  * every PCS-type opening of one run (A, H, M per block; B_k per internal
    boundary; the two run endpoints), its geometry and its column-test term
      (a) D15's convention: (3/4)^256 = 2^-106.25 for every opening;
      (b) the real code distance of the ZK encoding,
          delta = 1 - (msg)/(nn), msg = n + Q for A/H/B/E (pcs.rs:565),
          msg = 1024 for M (zk.rs: prox vector of 1024 coefficients on 4096);
  * the other terms of the project's union bound (obligations doc §4.2-4.6):
    PCS field terms, sumcheck rounds, LogUp (derived N/|F| and the R14 4N/|F|
    convention);
  * the whole-run union (a) and (b), and the token-I/O check's
    "6 openings per layer" convention for reconciliation.
"""
import json
import math
import os
from fractions import Fraction

P = 0xFFFF_FFFF_0000_0001            # zkp-core/src/field.rs:10
LOG2_F = 2 * math.log2(P)            # |F_{p^2}|, Fp2 = Fp[u]/(u^2 - 7)
Q = 256                              # shape.rs:279 COL_CHECKS; ZkOpts::standard q_pad = Q (pcs.rs:583)
INV_RATE = 4                         # every trained profile (shape.rs:347-371)
MASK_ROWS = 5                        # endpoint_g.rs:92
M_MSG, M_DOM, M_Q = 1024, 4096, 256  # zk.rs:373-375 (prox / product vectors: 2*512 coefficients)
N_TAB_DISTINCT = 3 * 256             # U8, EXP, ACT tables, 256 distinct rows each (argument.rs:1086-1104)


def lg(x):
    return math.log2(x)


def lsum(terms_log2):
    """log2 of a sum of 2^t (union bound)."""
    m = max(terms_log2)
    return m + lg(sum(2.0 ** (t - m) for t in terms_log2))


def column_term(msg, nn, checks=Q, regime=3):
    """(1 - delta/regime)^checks with delta = 1 - msg/nn (the convention of the
    125M check and the token-I/O check; it drops the RS '+1', which is
    conservative by < 2^-9 bit here)."""
    delta = 1 - Fraction(msg, nn)
    return float(delta), checks * lg(float(1 - delta / regime))


def prox_field_term(msg, nn):
    """AHIV/Ligero lemma (e < d/3): the random combination is e-close by chance
    with probability <= (e + 1)/|F|, e the absolute radius."""
    d_abs = nn - msg + 1
    e = (d_abs - 1) // 3
    return lg(e + 1) - LOG2_F


# ---------------------------------------------------------------------------
# layout formulas (copied, see docstring)
# ---------------------------------------------------------------------------
U8_LEN, LIMBS_ISQRT, N_SLOTS, F_P = 256, 3, 23, 9
(SC_SS, SC_SSM, SC_TZC, SC_LZC, SC_RS, SC_QMM, SC_KMM, SC_VMM, SC_SCORE, SC_PV, SC_WO, SC_GMM,
 SC_UMM, SC_DMM, SC_DZC, SC_QZC, SC_KVZC, SC_SZC, SC_FZC, SC_TAB, SC_ZS, SC_IO_IN, SC_IO_OUT) = range(23)
BASE_DEGREE = [3, 3, 3, 4, 3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 4, 4, 4, 4, 3, 2, 2, 2]   # shape.rs:292
LOOKUP_DOMS = ["L", "D", "Q", "Kv", "S", "F"]
INDICATOR = [(SC_SS, "D"), (SC_SSM, "D"), (SC_RS, "S"), (SC_DZC, "D"), (SC_QZC, "Q"),
             (SC_KVZC, "Kv"), (SC_SZC, "S"), (SC_FZC, "F")]


def clog2(v):
    return (v - 1).bit_length()


def npow2(v):
    return 1 << clog2(v)


class Shape:
    def __init__(self, T, d, f, h, hd, kv, log_cols, norm_wrho=32):
        self.T, self.d, self.f, self.h, self.hd, self.kv = T, d, f, h, hd, kv
        self.t_pad, self.d_pad, self.h_pad, self.f_pad = npow2(T), npow2(d), npow2(h), npow2(f)
        self.log_cols, self.n = log_cols, 1 << log_cols
        self.wrho_s = clog2(T) + 9
        self.ln = (norm_wrho + 7) // 8
        self.top = 0 if norm_wrho == 8 * self.ln else 1
        self.ls = (self.wrho_s + 7) // 8
        self.lp = (F_P + 1 + 7) // 8
        self.endpoint_rows = ((self.t_pad * d) >> log_cols) + MASK_ROWS

    def natural_log(self, dom):
        t, h, hd, kv = self.t_pad, self.h_pad, self.hd, self.kv
        return {"T": clog2(t), "Ht": clog2(h * t), "L": clog2(16 * t), "D": clog2(t * self.d_pad),
                "Q": clog2(t * h * hd), "Kv": clog2(t * kv * hd), "S": clog2(h * t * t),
                "F": clog2(t * self.f_pad), "Tab": clog2(U8_LEN)}[dom]

    def true_size(self, dom):
        T = self.T
        return {"T": T, "Ht": self.h * T, "L": 3 * LIMBS_ISQRT * T, "D": T * self.d, "Q": T * self.h * self.hd,
                "Kv": T * self.kv * self.hd, "S": self.h * T * T, "F": T * self.f, "Tab": U8_LEN}[dom]

    def log(self, dom):
        nat = self.natural_log(dom)
        return self.log_cols if (dom not in ("T", "Ht") and nat < self.log_cols) else nat

    def size(self, dom):
        return 1 << self.log(dom)

    def rows_of(self, dom):
        return max(1, self.size(dom) >> self.log_cols)

    def pads(self, dom):
        return self.size(dom) != self.true_size(dom)

    def a_plane_doms(self):
        ln = self.ln
        v = ["T"] * 4 + ["Ht"] * 2 + ["L"] * 2 + ["D"] * (4 + 2 * ln + 8 + 2 * ln + 7) + ["Q"] * 7 + ["Kv"] * 6
        return v + ["S"] * (5 + self.lp + 2 * self.ls) + ["F"] * 11 + ["Tab"] * 3

    def lookups_per_position(self, dom):
        per_norm = 2 + 2 * (self.ln + self.top)
        return {"L": 2, "D": 2 + per_norm + 6 + per_norm + 2 + 4, "F": 9, "Q": 13, "Kv": 12,
                "S": 2 + 2 + (self.lp + 1) + 2 * (self.ls + 1)}.get(dom, 0)

    def helpers(self, dom):
        return (self.lookups_per_position(dom) + 1) // 2

    def h_plane_doms(self):
        v = ["L"] * self.helpers("L") + ["D"] * self.helpers("D") + ["Q"] * self.helpers("Q") + ["Kv"] * self.helpers("Kv")
        return v + ["S"] * (self.helpers("S") + 1) + ["F"] * (self.helpers("F") + 1) + ["Tab"] * 4

    def claim_sites(self):
        on = lambda dm: self.a_plane_doms().count(dm)  # noqa: E731
        a, h = [0] * N_SLOTS, [0] * N_SLOTS
        a[SC_SS] = a[SC_SSM] = 1
        a[SC_TZC] = 4 + 2 * (3 * LIMBS_ISQRT)
        a[SC_LZC], h[SC_LZC] = on("L"), self.helpers("L")
        a[SC_RS] = 2
        for s in (SC_QMM, SC_KMM, SC_VMM, SC_WO, SC_GMM, SC_UMM, SC_DMM):
            a[s] = 1
        a[SC_SCORE] = a[SC_PV] = 2
        a[SC_DZC], h[SC_DZC] = on("D") + 2, self.helpers("D")
        a[SC_QZC], h[SC_QZC] = on("Q") + 1, self.helpers("Q")
        a[SC_KVZC], h[SC_KVZC] = on("Kv") + 1, self.helpers("Kv")
        a[SC_SZC], h[SC_SZC] = on("S") + 2, self.helpers("S") + 1
        a[SC_FZC], h[SC_FZC] = on("F"), self.helpers("F") + 1
        a[SC_TAB], h[SC_TAB] = 3, 3
        h[SC_ZS] = 1
        a[SC_IO_IN] = a[SC_IO_OUT] = 1
        return a, h

    def slots(self):
        cube = {SC_SS: "D", SC_SSM: "D", SC_DZC: "D", SC_IO_IN: "D", SC_IO_OUT: "D", SC_TZC: "T", SC_LZC: "L",
                SC_RS: "S", SC_SZC: "S", SC_QZC: "Q", SC_KVZC: "Kv", SC_FZC: "F", SC_TAB: "Tab", SC_ZS: "Tab"}
        lkv = clog2(self.kv) if self.kv > 1 else 0
        inner = {SC_QMM: clog2(self.d_pad), SC_KMM: clog2(self.d_pad), SC_VMM: clog2(self.d_pad), SC_WO: clog2(self.d_pad),
                 SC_GMM: clog2(self.d_pad), SC_UMM: clog2(self.d_pad), SC_SCORE: lkv + clog2(self.hd),
                 SC_PV: lkv + clog2(self.t_pad), SC_DMM: clog2(self.f_pad)}
        out = []
        for s in range(N_SLOTS):
            main = self.log(cube[s]) if s in cube else inner[s]
            ind = any(sl == s and self.pads(dm) for sl, dm in INDICATOR)
            ext = 2 if s in (SC_SCORE, SC_PV) else 1
            geq = (s in (SC_SCORE, SC_PV)) and lkv > 0
            out.append((main, ext, BASE_DEGREE[s] + int(ind) + int(geq)))
        return out

    def a_rows(self):
        return sum(self.rows_of(d) for d in self.a_plane_doms()) + 2 * sum(self.claim_sites()[0]) + 2

    def h_rows(self):
        return sum(2 * self.rows_of(d) for d in self.h_plane_doms()) + 2 * sum(self.claim_sites()[1]) + 2

    def u8_lookups(self):
        return sum(self.lookups_per_position(d) * self.size(d) for d in LOOKUP_DOMS)

    def a_groups(self):
        offs = sorted(set([(k * self.t_pad) % self.n for k in range(3 * LIMBS_ISQRT)] + [0]))
        return len(offs) + 15 + 4 + 8


def tinyllama(T, lc):
    return Shape(T, 2048, 5632, 32, 64, 4, lc)


def llama3_8b(T, lc):
    return Shape(T, 4096, 14336, 32, 128, 8, lc)


# whole-run receipt bytes of the measured stacks (results/zk60_1b_native_20261017/PROGRESS.md R3-3, R4-3)
RECEIPT_BYTES = {"TinyLlama T32": 250855088, "TinyLlama T64": 333316880, "TinyLlama T128": 497665904,
                 "Llama-3-8B T32": 465815776}

# Rust-counted (A rows, H rows, U8 lookups) at the registered widths
RUST_COUNTED = {
    "TinyLlama T32": (1729, 1798, 5971968),    # r3-ladder-count.log:5
    "TinyLlama T64": (1817, 1926, 12795904),   # r3-ladder-count.log:13
    "TinyLlama T128": (1993, 2182, 28999680),  # r3-ladder-count.log:21
    "Llama-3-8B T32": (1697, 1758, 11714560),  # R4 counted layouts, log_cols 13
    "TinyLlama T512 (projection)": (3309, 3976, 214564864),  # r3-ladder-count.log:37 (not registered)
    "Llama-3-8B T512 (projection)": None,      # no Rust count exists for this geometry
}

PROFILES = [
    ("TinyLlama T32", tinyllama(32, 12), 22),
    ("TinyLlama T64", tinyllama(64, 13), 22),
    ("TinyLlama T128", tinyllama(128, 14), 22),
    ("Llama-3-8B T32", llama3_8b(32, 13), 32),
]

# NOT registered profiles (no export, above the laptop's memory gate): the T512
# geometry the speed plan targets, at row width 2^16, for perspective only.
PROJECTIONS = [
    ("TinyLlama T512 (projection)", tinyllama(512, 16), 22),
    ("Llama-3-8B T512 (projection)", llama3_8b(512, 16), 32),
]

CONV = 256 * lg(0.75)   # D15: (3/4)^256


def recount(name, sh, L):
    n, nn = sh.n, sh.n * INV_RATE
    a_sites, h_sites = (sum(x) for x in sh.claim_sites())
    slots = sh.slots()
    d_blk, t_blk = column_term(n + Q, nn)
    d_m, t_m = column_term(M_MSG, M_DOM)
    _, t_blk_half = column_term(n + Q, nn, regime=2)
    _, t_m_half = column_term(M_MSG, M_DOM, regime=2)
    f_blk = prox_field_term(n + Q, nn)
    f_m = prox_field_term(M_MSG, M_DOM)
    # one row per commitment kind: (kind, times opened, n or msg, nn, rows, claims for lambda batching)
    openings = [
        dict(kind="A (block witness)", times=L, n=n, inv_rate=INV_RATE, msg=n + Q, nn=nn, pads=Q, checks=Q,
             rows=sh.a_rows(), claims=2 * a_sites + 2, delta=d_blk, b=t_blk, half=t_blk_half, field=f_blk),
        dict(kind="H (block LogUp helpers)", times=L, n=n, inv_rate=INV_RATE, msg=n + Q, nn=nn, pads=Q, checks=Q,
             rows=sh.h_rows(), claims=2 * h_sites + 2, delta=d_blk, b=t_blk, half=t_blk_half, field=f_blk),
        dict(kind="M (block CFS masks)", times=L, n=512, inv_rate=8, msg=M_MSG, nn=M_DOM, pads=M_Q, checks=M_Q,
             rows=2 * N_SLOTS + 4, claims=sum(m + e + 2 for m, e, _ in slots), delta=d_m, b=t_m, half=t_m_half, field=f_m),
        dict(kind="B_k (internal boundary)", times=L - 1, n=n, inv_rate=INV_RATE, msg=n + Q, nn=nn, pads=Q, checks=Q,
             rows=sh.endpoint_rows + 1, claims=6, delta=d_blk, b=t_blk, half=t_blk_half, field=f_blk),
        dict(kind="E_in (run input endpoint)", times=1, n=n, inv_rate=INV_RATE, msg=n + Q, nn=nn, pads=Q, checks=Q,
             rows=sh.endpoint_rows, claims=4, delta=d_blk, b=t_blk, half=t_blk_half, field=f_blk),
        dict(kind="E_out (run output endpoint)", times=1, n=n, inv_rate=INV_RATE, msg=n + Q, nn=nn, pads=Q, checks=Q,
             rows=sh.endpoint_rows, claims=4, delta=d_blk, b=t_blk, half=t_blk_half, field=f_blk),
    ]
    n_open = sum(o["times"] for o in openings)
    col_a = lsum([CONV + lg(o["times"]) for o in openings])
    col_b = lsum([o["b"] + lg(o["times"]) for o in openings])
    col_half = lsum([o["half"] + lg(o["times"]) for o in openings])
    col_6L = CONV + lg(6 * L)
    pcs_field = lsum([lsum([o["field"], lg(o["claims"]) - LOG2_F]) + lg(o["times"]) for o in openings])
    # sumchecks, per block: rounds x degree (Schwartz-Zippel per round) + main (zero-check eq point)
    # + terms (batching of relations / terminals) + 2 (CFS mask combination, final check)
    a, h = sh.claim_sites()
    sc_units = sum((m + e) * dg + m + (a[s] + h[s] + int(s >= SC_IO_IN)) + 2 for s, (m, e, dg) in enumerate(slots))
    sc_block = lg(sc_units) - LOG2_F
    sc_run = sc_block + lg(L)
    # LogUp, per block (own alpha, beta, gamma per block: protocol.rs:1201-1203)
    exp_q, act_q = sh.size("S"), sh.size("F")
    nq = sh.u8_lookups() + exp_q + act_q
    logup_der_block = lg(nq + 2 * N_TAB_DISTINCT) - LOG2_F    # alpha identity (Nq + 768) + compression (768)
    logup_4n_block = lg(4 * nq) - LOG2_F                     # obligations doc R14 / §4.3 convention
    logup_der_run = logup_der_block + lg(L)
    logup_4n_run = logup_4n_block + lg(L)
    rest = [pcs_field, sc_run]
    whole = {
        "a_4N": lsum([col_a, logup_4n_run] + rest),
        "b_4N": lsum([col_b, logup_4n_run] + rest),
        "a_N": lsum([col_a, logup_der_run] + rest),
        "b_N": lsum([col_b, logup_der_run] + rest),
        "6L_4N": lsum([col_6L, logup_4n_run] + rest),
        "half_4N": lsum([col_half, logup_4n_run] + rest),
    }
    worst_round = {
        "D15 per opening": CONV,
        "real per opening (A/H/B/E)": t_blk,
        "LogUp per block (N)": logup_der_block,
        "LogUp per block (4N)": logup_4n_block,
        "largest sumcheck per block": sc_block,
    }
    # the smallest column-check count (pads = checks, ZkOpts::standard) that restores
    # D15's 2^-106.25 per opening at this width and rate
    q_restore = Q
    while column_term(n + q_restore, nn, checks=q_restore)[1] > CONV:
        q_restore += 1
    # bytes the extra checks add to one run (wire.rs opening layout: per column
    # 8 index + rows*8 + 32 salt + path*32; every clear vector grows by one Fp2 per extra pad)
    dq = q_restore - Q
    path = sh.log_cols + 2
    per_col = lambda rows: 8 + rows * 8 + 32 + path * 32  # noqa: E731
    extra = L * dq * (per_col(sh.a_rows()) + (sh.a_groups() + 1) * 16 + per_col(sh.h_rows()) + (9 + 1) * 16)
    extra += (L - 1) * dq * (per_col(sh.endpoint_rows + 1) + 2 * 16) + 2 * dq * (per_col(sh.endpoint_rows) + 2 * 16)
    rb = RECEIPT_BYTES.get(name)
    rc = RUST_COUNTED[name]
    mine = (sh.a_rows(), sh.h_rows(), sh.u8_lookups())
    rust_check = dict(a_rows=mine[0], h_rows=mine[1], u8=mine[2], rust=rc, ok=(None if rc is None else mine == rc))
    return dict(
        profile=name, blocks=L, log_cols=sh.log_cols, row_width=n, inv_rate=INV_RATE, Q=Q,
        rust_check=rust_check,
        openings=openings, openings_total=n_open,
        column=dict(a=col_a, b=col_b, six_per_layer=col_6L, delta_half_regime=col_half, weaker_bits=col_b - col_a),
        pcs_field=pcs_field, sumcheck_units_per_block=sc_units, sumcheck_block=sc_block, sumcheck_run=sc_run,
        lookups=dict(u8=sh.u8_lookups(), exp=exp_q, act=act_q, total=nq),
        logup=dict(derived_block=logup_der_block, r14_block=logup_4n_block, derived_run=logup_der_run, r14_run=logup_4n_run),
        whole=whole, whole_weaker_bits=dict(R14_4N=whole["b_4N"] - whole["a_4N"], derived_N=whole["b_N"] - whole["a_N"]),
        worst_single_round=worst_round,
        q_restore=dict(checks=q_restore, per_opening=column_term(n + q_restore, nn, checks=q_restore)[1],
                       extra_run_bytes=extra, receipt_bytes=rb, extra_share=(None if rb is None else extra / rb)),
    )


def reconcile_125m():
    """The 125M twelve-block figure (D12a, MVP_STATUS) from recompute.out lines 173-180,
    and the same run with this lane's opening set."""
    L, n = 12, 1 << 14
    _, t = column_term(n + Q, 4 * n)
    _, tm = column_term(M_MSG, M_DOM)
    lk = 103825408                                      # recompute.out:179
    lu = lg(lk) - LOG2_F
    theirs = lsum([lsum([t + lg(4), lu]) + lg(L), t + lg(L - 1)])
    ours = lsum([t + lg(3 * L + 1), tm + lg(L), lu + lg(L)])   # 12 A + 12 H + 11 B + 2 E = 37; 12 M
    ours_conv = lsum([CONV + lg(4 * L + 1), lu + lg(L)])
    return dict(per_opening_real=t, per_opening_M=tm, logup_block=lu, recompute_py=theirs,
                this_lane_real=ours, this_lane_D15_convention=ours_conv)


def main():
    out = {"log2_F": LOG2_F, "D15_per_opening": CONV, "profiles": [], "projections": [],
           "125M_reconciliation": reconcile_125m()}
    print("log2|F_p^2| = %.10f ; D15 per opening (3/4)^256 = 2^%.2f" % (LOG2_F, CONV))
    for name, sh, L in PROFILES + PROJECTIONS:
        r = recount(name, sh, L)
        out["projections" if "projection" in name else "profiles"].append(r)
        print("\n==== %s : %d blocks, row width 2^%d, inv_rate %d, Q %d ====" % (name, L, sh.log_cols, INV_RATE, Q))
        rc = r["rust_check"]
        if rc["rust"] is None:
            print("  layout (no Rust count to compare): A %d  H %d  U8 %d" % (rc["a_rows"], rc["h_rows"], rc["u8"]))
        else:
            print("  layout check vs Rust counts: A %d/%d  H %d/%d  U8 %d/%d  -> %s" % (
                rc["a_rows"], rc["rust"][0], rc["h_rows"], rc["rust"][1], rc["u8"], rc["rust"][2],
                "OK" if rc["ok"] else "MISMATCH"))
        print("  %-28s %5s %7s %6s %6s %5s %5s %5s %8s %9s %9s" % (
            "commitment", "times", "n/msg", "nn", "rows", "pads", "Q", "delta", "(a)", "(b)", "(d/2)"))
        for o in r["openings"]:
            print("  %-28s %5d %7d %6d %6d %5d %5d %.4f %8.2f %9.2f %9.2f" % (
                o["kind"], o["times"], o["msg"], o["nn"], o["rows"], o["pads"], o["checks"], o["delta"], CONV, o["b"], o["half"]))
        c = r["column"]
        print("  openings per run: %d (= 4L + 1)" % r["openings_total"])
        print("  column term  (a) D15 convention, real count : 2^%.2f" % c["a"])
        print("  column term  (b) real ZK distance           : 2^%.2f   (%.2f bits weaker than (a))" % (c["b"], c["weaker_bits"]))
        print("  column term  token-I/O check, 6 per layer   : 2^%.2f" % c["six_per_layer"])
        print("  column term  delta/2 regime (not adopted)   : 2^%.2f" % c["delta_half_regime"])
        lk = r["lookups"]
        print("  lookups per block: U8 %d + exp %d + act %d = %d" % (lk["u8"], lk["exp"], lk["act"], lk["total"]))
        lu = r["logup"]
        print("  LogUp per block: derived (N+1536)/|F| 2^%.2f ; R14 4N/|F| 2^%.2f ; run: 2^%.2f / 2^%.2f" % (
            lu["derived_block"], lu["r14_block"], lu["derived_run"], lu["r14_run"]))
        print("  sumchecks: %d units per block -> 2^%.2f per block, 2^%.2f per run" % (
            r["sumcheck_units_per_block"], r["sumcheck_block"], r["sumcheck_run"]))
        print("  PCS field terms (prox (e+1)/|F| + lambda batching), whole run: 2^%.2f" % r["pcs_field"])
        w = r["whole"]
        print("  WHOLE RUN  (a) D15 per-opening : 2^%.2f with R14 LogUp (4N) ; 2^%.2f with derived LogUp (N)" % (w["a_4N"], w["a_N"]))
        print("  WHOLE RUN  (b) real distance   : 2^%.2f with R14 LogUp (4N) ; 2^%.2f with derived LogUp (N)" % (w["b_4N"], w["b_N"]))
        print("  whole run weaker by %.2f bits (4N) / %.2f bits (N)" % (
            r["whole_weaker_bits"]["R14_4N"], r["whole_weaker_bits"]["derived_N"]))
        print("  whole run, 6-per-layer convention (4N): 2^%.2f ; delta/2 regime (4N): 2^%.2f" % (w["6L_4N"], w["half_4N"]))
        print("  worst single round: " + ", ".join("%s 2^%.2f" % kv for kv in r["worst_single_round"].items()))
        qr = r["q_restore"]
        print("  column checks (= pads) restoring 2^-106.25 per A/H/B/E opening at this width: %d (2^%.2f); +%d B per run%s" % (
            qr["checks"], qr["per_opening"], qr["extra_run_bytes"],
            "" if qr["receipt_bytes"] is None else " = +%.2f%% of the %d B receipt" % (100 * qr["extra_share"], qr["receipt_bytes"])))
    # M's product check (zk.rs mask_verify): q (degree < 1024) against sum_s a_s W_s + b with
    # a_s only proven close to degree < 1024 and W_s of degree < 512: a wrong q differs from the
    # decoded product as a polynomial of degree <= 1534, and at most e < 1024 columns are corrupted
    m_prod = M_Q * lg(Fraction(1534, M_DOM) + Fraction(1, 4))
    out["M_product_check_log2"] = m_prod
    print("\nM product check (consistency half, any profile): (1534/4096 + 1/4)^256 = 2^%.2f" % m_prod)
    # consistency half of an A/H/B/E opening at the narrowest width (2^12): (1 - 2 delta/3)^256
    d12 = 1 - Fraction(4096 + Q, 4 * 4096)
    out["consistency_2_12_log2"] = Q * lg(1 - 2 * d12 / 3)
    print("A/H/B/E consistency half per group at 2^12: (1 - 2 delta/3)^256 = 2^%.2f" % out["consistency_2_12_log2"])
    rm = out["125M_reconciliation"]
    print("\n==== 125M twelve-block run (reconciliation; D12a / MVP_STATUS quote 2^-97.5) ====")
    print("  per opening at log_cols 14 / rate 4 (real ZK distance, as recompute.py §11 used): 2^%.2f ; M 2^%.2f" % (
        rm["per_opening_real"], rm["per_opening_M"]))
    print("  recompute.py's assembly (12 x (4 openings + LogUp) + 11 boundaries): 2^%.2f" % rm["recompute_py"])
    print("  this lane's opening set (37 at 2^%.2f, 12 M, LogUp N): 2^%.2f ; same at D15's 2^-106.25: 2^%.2f" % (
        rm["per_opening_real"], rm["this_lane_real"], rm["this_lane_D15_convention"]))
    here = os.path.dirname(os.path.abspath(__file__))
    with open(os.path.join(here, "recount.json"), "w") as fh:
        json.dump(out, fh, indent=1, default=float)


if __name__ == "__main__":
    main()

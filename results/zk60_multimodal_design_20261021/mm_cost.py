#!/usr/bin/env python3
"""MULTIMODAL DESIGN lane (paper and counting only, 2026-10-21): what Shieldstral's
image path (Pixtral ViT + projector), its text decoder at image-sized contexts, and
sampled video would cost the native private-block prover.

NOTHING HERE PROVES OR BUILDS ANYTHING. Pure Python, one thread, about a second.

WHAT IS REUSED, AND CHECKED BEFORE USE
  * the native lane's R10 replica of the frozen R9 layout
    (results/zk60_1b_native_20261017/r10/r10_weight_range_cost.py). Its anchor()
    asserts that the replica equals every size the R9-tree prover printed in
    HL_PB_TIMING for four T128 runs; it is re-run here and stops on a difference;
  * the speed plan's layout replica and calibrated per-phase cost law
    (results/zk60_speed_plan_20261017/{layout,cost_model,projection}.py): receipts
    checked against the Rust counted ladder; the law fitted on the R4-4 TinyLlama
    T128 phase run and validated within -3..+8% on TinyLlama T32/64/128 and 8B T32.

WHAT IS NEW
  `Lay` below restates both replicas in one class with four generalisations:
  (1) any block geometry (Pixtral: d 1024, FFN 4096, 16 heads x 64, 16 KV heads;
      Shieldstral decoder: d 3072 -> padded 4096, FFN 9216 -> padded 16384,
      32 x 128 heads, 8 KV heads);
  (2) DD (the per-row division dictionary, D30) with its receipt;
  (3) a public-prefix variant (survey feature F6): Tq proved query positions
      against Tk = prefix + Tq keys, so the score domain is h x Tq x Tk [MODEL:
      no such relation exists];
  (4) a batch axis (B independent sequences or frames per block; block-diagonal
      attention laid out as an extra batch axis, NOT as a masked square) [MODEL].
  At the existing geometries with (2)-(4) off, `Lay` must equal both replicas
  exactly (asserted below), and with DD on it must equal the R10 replica's DD
  counts and DD's measured counted receipt delta (+235,008 B per block).

LABELS
  [COUNTED] exact on the replicated R9 layout at a geometry the code admits or
            would admit with F2 (decoupled head_dim) and a registered profile;
  [MODEL]   everything else: new relations' plane lists, the cost law applied at
            new sizes, platform factors (taken unchanged from the speed plan).
Writes mm_cost.json beside itself and prints the tables (copied into DESIGN.md).
usage: python3 mm_cost.py
"""
import json
import math
import os
import sys

sys.dont_write_bytecode = True  # import other lanes' scripts without leaving __pycache__ in their directories
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
NATIVE = os.path.join(REPO, "results", "zk60_1b_native_20261017")
SPDIR = os.path.join(REPO, "results", "zk60_speed_plan_20261017")
sys.path.insert(0, os.path.join(NATIVE, "r10"))
sys.path.insert(0, SPDIR)
import r10_weight_range_cost as r10  # noqa: E402
import layout as sp_layout  # noqa: E402
import cost_model as sp_cm  # noqa: E402
import projection as sp_proj  # noqa: E402

clog2, npow2 = r10.clog2, r10.npow2
F_P = 9
LIMBS_ISQRT = 3
U8_LEN = 256
COL_CHECKS = 256
MASK_VEC = 1024
MASK_PATH = 12
WIRE_HEADER = 40
INV_RATE = 4
MASK_ROWS = 5
DD_CAP = 32
SLOTS = ["SS", "SSM", "TZC", "LZC", "RS", "QMM", "KMM", "VMM", "SCORE", "PV", "WO", "GMM", "UMM", "DMM",
         "DZC", "QZC", "KVZC", "SZC", "FZC", "TAB", "ZS", "IO_IN", "IO_OUT"]
BASE_DEGREE = dict(zip(SLOTS, sp_layout.BASE_DEGREE))
BASE_DEGREE["DD"] = 4  # ledger R9: BASE_DEGREE[SC_DD] = 4
INDICATOR = {"SS": "D", "SSM": "D", "RS": "S", "DZC": "D", "QZC": "Q", "KVZC": "Kv", "SZC": "S", "FZC": "F"}
CUBE = {"SS": "D", "SSM": "D", "DZC": "D", "IO_IN": "D", "IO_OUT": "D", "TZC": "T", "LZC": "L", "RS": "S", "SZC": "S",
        "QZC": "Q", "KVZC": "Kv", "FZC": "F", "TAB": "Tab", "ZS": "Tab", "DD": "Dd"}
LOOKUP_DOMS = ["L", "D", "Q", "Kv", "S", "F"]


class Lay:
    """One block of the native private-block layout (R9 counting) at any geometry."""

    def __init__(self, T, d, f, h, hd, kv, log_cols, dd=False, f_e=9, tk=None, batch=1, norm_wrho=32, f_p=F_P):
        self.T, self.d, self.f, self.h, self.hd, self.kv, self.batch = T, d, f, h, hd, kv, batch
        self.Tk = T if tk is None else tk          # keys per query (F6: public prefix + proved)
        self.dd = dd
        self.tq_pad, self.tk_pad = npow2(T), npow2(self.Tk)
        self.b_pad = npow2(batch)
        self.d_pad, self.h_pad, self.f_pad = npow2(d), npow2(h), npow2(f)
        assert self.d_pad == self.h_pad * hd, "the layout's width = heads x head_dim (true for both models after padding)"
        self.log_cols, self.n = log_cols, 1 << log_cols
        self.wrho_s = clog2(self.Tk) + f_e
        assert self.wrho_s <= 24, "softmax window rule clog2(T)+f_e <= 24"
        self.ln = (norm_wrho + 7) // 8
        self.top = 0 if norm_wrho == 8 * self.ln else 1
        self.ls = (self.wrho_s + 7) // 8
        self.lp = (f_p + 1 + 7) // 8
        self.cap = DD_CAP if dd else 0
        tq, tk, b = self.tq_pad, self.tk_pad, self.b_pad
        self.nat = {"T": clog2(b * tq), "Ht": clog2(self.h_pad * b * tq), "L": clog2(16 * b * tq), "D": clog2(b * tq * self.d_pad),
                    "Q": clog2(b * tq * self.h_pad * hd), "Kv": clog2(b * tq * kv * hd), "S": clog2(self.h_pad * b * tq * tk),
                    "F": clog2(b * tq * self.f_pad), "Tab": clog2(U8_LEN), "Dd": clog2(self.h_pad * b * tq * max(1, self.cap))}
        B, Tq, Tk = batch, T, self.Tk
        self.true = {"T": B * Tq, "Ht": h * B * Tq, "L": 3 * LIMBS_ISQRT * B * Tq, "D": B * Tq * d, "Q": B * Tq * h * hd,
                     "Kv": B * Tq * kv * hd, "S": h * B * Tq * Tk, "F": B * Tq * f, "Tab": U8_LEN, "Dd": h * B * Tq * max(1, self.cap)}
        assert self.nat["T"] < log_cols, "S-6: padded token count below the row width"
        assert self.nat["Kv"] >= log_cols, "bilinear slots refuse a Kv domain lifted by P-3"
        assert log_cols >= 8
        if dd:
            assert not self.pads("S") and not self.pads("Dd"), "DD (D30, B-3 by restriction) is admitted only on unpadded score/dictionary domains"

    # ---- domains --------------------------------------------------------------
    def log(self, dom):
        nat = self.nat[dom]
        return self.log_cols if (dom not in ("T", "Ht") and nat < self.log_cols) else nat

    def size(self, dom):
        return 1 << self.log(dom)

    def rows_of(self, dom):
        return max(1, self.size(dom) >> self.log_cols)

    def pads(self, dom):
        return self.size(dom) != self.true[dom]

    def doms(self):
        return ["T", "Ht", "L", "D", "Q", "Kv", "S", "F", "Tab"] + (["Dd"] if self.dd else [])

    # ---- planes, lookups, helpers (shape.rs) -----------------------------------
    def a_planes(self):
        ln = self.ln
        a = {"T": 4, "Ht": 2, "L": 2, "D": 4 + 2 * ln + 8 + 2 * ln + 7, "Q": 7, "Kv": 6, "F": 11, "Tab": 3,
             "S": 5 if self.dd else 5 + self.lp + 2 * self.ls}
        if self.dd:
            a["Dd"] = 2 + self.lp + 2 * self.ls
        return a

    def lookups(self):
        pn = 2 + 2 * (self.ln + self.top)
        u = {"L": 2, "D": 2 + pn + 6 + pn + 2 + 4, "F": 9, "Q": 13, "Kv": 12,
             "S": 4 if self.dd else 2 + 2 + (self.lp + 1) + 2 * (self.ls + 1)}
        if self.dd:
            u["Dd"] = (self.lp + 1) + 2 * (self.ls + 1)
        return u

    def helpers(self):
        return {k: (v + 1) // 2 for k, v in self.lookups().items()}

    def h_planes(self):
        hp = self.helpers()
        out = {"L": hp["L"], "D": hp["D"], "Q": hp["Q"], "Kv": hp["Kv"], "S": hp["S"] + 1 + int(self.dd), "F": hp["F"] + 1, "Tab": 4}
        if self.dd:
            out["Dd"] = hp["Dd"] + 1
        return out

    def claim_sites(self):
        a, hp = self.a_planes(), self.helpers()
        A = {s: 0 for s in SLOTS}
        H = {s: 0 for s in SLOTS}
        A.update({"SS": 1, "SSM": 1, "TZC": 4 + 2 * (3 * LIMBS_ISQRT), "LZC": a["L"], "RS": 2, "QMM": 1, "KMM": 1, "VMM": 1,
                  "SCORE": 2, "PV": 2, "WO": 1, "GMM": 1, "UMM": 1, "DMM": 1, "DZC": a["D"] + 2, "QZC": a["Q"] + 1,
                  "KVZC": a["Kv"] + 1, "SZC": a["S"] + 2, "FZC": a["F"], "TAB": 3, "IO_IN": 1, "IO_OUT": 1})
        H.update({"LZC": hp["L"], "DZC": hp["D"], "QZC": hp["Q"], "KVZC": hp["Kv"], "SZC": hp["S"] + 1 + int(self.dd),
                  "FZC": hp["F"] + 1, "TAB": 3, "ZS": 1})
        if self.dd:
            A["DD"] = a["Dd"] + 1
            H["DD"] = hp["Dd"] + 1
        return A, H

    def slot_names(self):
        return SLOTS + (["DD"] if self.dd else [])

    def slots(self):
        lkv = clog2(self.kv) if self.kv > 1 else 0
        lb = clog2(self.b_pad)   # [MODEL] batch bits are shared by both private factors of the bilinear slots
        inner = {"QMM": clog2(self.d_pad), "KMM": clog2(self.d_pad), "VMM": clog2(self.d_pad), "WO": clog2(self.d_pad),
                 "GMM": clog2(self.d_pad), "UMM": clog2(self.d_pad), "SCORE": lkv + lb + clog2(self.hd),
                 "PV": lkv + lb + clog2(self.tk_pad), "DMM": clog2(self.f_pad)}
        out = []
        for s in self.slot_names():
            main = self.log(CUBE[s]) if s in CUBE else inner[s]
            ind = s in INDICATOR and self.pads(INDICATOR[s])
            ext = 2 if s in ("SCORE", "PV") else 1
            geq = s in ("SCORE", "PV") and (lkv + lb) > 0
            out.append((s, main, ext, BASE_DEGREE[s] + int(ind) + int(geq)))
        return out

    def a_rows(self):
        A, _ = self.claim_sites()
        return sum(v * self.rows_of(k) for k, v in self.a_planes().items()) + 2 * sum(A.values()) + 2

    def h_rows(self):
        _, H = self.claim_sites()
        return sum(2 * v * self.rows_of(k) for k, v in self.h_planes().items()) + 2 * sum(H.values()) + 2

    def u8(self):
        return sum(v * self.size(k) for k, v in self.lookups().items())

    def a_groups(self):
        offs = sorted(set([(k * self.tq_pad * self.b_pad) % self.n for k in range(3 * LIMBS_ISQRT)] + [0]))
        return len(offs) + 15 + 4 + 8 + (2 if self.dd else 0)

    def h_groups(self):
        return 9 + int(self.dd)

    def endpoint_rows(self):
        return ((self.b_pad * self.tq_pad * self.d_pad) >> self.log_cols) + MASK_ROWS

    def receipt(self):
        n = self.n
        vec_len = n + COL_CHECKS
        path = clog2(n * INV_RATE)

        def opening(groups, rows):
            return (groups + 1) * vec_len * 16 + COL_CHECKS * (8 + rows * 8 + 32 + path * 32)
        A, H = self.claim_sites()
        words = 0
        for (s, main, ext, deg) in self.slots():
            words += 1 + (main + ext) * (deg + 1) + A[s] + H[s] + int(s in ("IO_IN", "IO_OUT"))
        n_slots = len(self.slot_names())
        mask = 2 * MASK_VEC * 16 + COL_CHECKS * (8 + (2 * n_slots + 4) * 8 + 32 + MASK_PATH * 32)
        return (WIRE_HEADER + 96 + words * 16 + mask + opening(self.a_groups(), self.a_rows()) + opening(self.h_groups(), self.h_rows())
                + 2 * opening(1, self.endpoint_rows()))

    def zc_terms(self):
        A, H = self.claim_sites()
        t = {"D": A["DZC"] + H["DZC"], "Q": A["QZC"] + H["QZC"], "Kv": A["KVZC"] + H["KVZC"], "S": A["SZC"] + H["SZC"], "F": A["FZC"] + H["FZC"]}
        if self.dd:
            t["Dd"] = A["DD"] + H["DD"]
        return t

    def summary(self):
        a, h = self.a_rows() * self.n, self.h_rows() * self.n
        by_dom = {}
        for k, v in self.a_planes().items():
            by_dom[k] = by_dom.get(k, 0) + v * self.rows_of(k) * self.n
        for k, v in self.h_planes().items():
            by_dom[k] = by_dom.get(k, 0) + 2 * v * self.rows_of(k) * self.n
        return {"A_elems": a, "H_elems": h, "elems": a + h, "u8": self.u8(), "sizes": {k: self.size(k) for k in self.doms()},
                "terms": self.zc_terms(), "receipt": self.receipt(), "n": self.n, "elems_by_domain": by_dom}

    # ---- the true work a block does (for the witness law) ----------------------
    def weights_true(self):
        return self.d * self.h * self.hd * 2 + self.d * self.kv * self.hd * 2 + 3 * self.d * self.f

    def padded_weights(self):
        return self.d_pad * self.d_pad * 2 + self.d_pad * self.kv * self.hd * 2 + 3 * self.d_pad * self.f_pad

    def macs(self):
        return self.batch * (self.T * self.weights_true() + 2 * self.h * self.hd * self.T * self.Tk)


def best(make, lo=8, hi=24):
    """the receipt-minimising admissible row width (the speed plan's rule)"""
    bestl = None
    for lc in range(lo, hi + 1):
        try:
            sh = make(lc)
        except AssertionError:
            continue
        rb = sh.receipt()
        if bestl is None or rb < bestl.receipt():
            bestl = sh
    return bestl


# ---- geometries -------------------------------------------------------------------
def tinyllama(T, lc, **kw):
    return Lay(T, 2048, 5632, 32, 64, 4, lc, **kw)


def llama8b(T, lc, **kw):
    return Lay(T, 4096, 14336, 32, 128, 8, lc, **kw)


def pixtral(T, lc, **kw):        # VERIFIED config.json vision_config: d 1024, FFN 4096, 16 heads x 64, MHA
    return Lay(T, 1024, 4096, 16, 64, 16, lc, **kw)


def shieldstral(T, lc, **kw):    # VERIFIED config.json text_config: d 3072, FFN 9216, 32 x 128, 8 KV heads
    return Lay(T, 3072, 9216, 32, 128, 8, lc, **kw)


# ---- the checks ------------------------------------------------------------------------
def checks():
    r10.anchor()  # the replica == the R9 prover's printed sizes (asserts)
    out = []
    # (1) Lay == the speed plan's replica (A/H rows, receipt, U8) at its counted-ladder shapes
    for T, lc in ((32, 12), (64, 13), (128, 14), (256, 14), (512, 16), (512, 13)):
        a, b = tinyllama(T, lc), sp_layout.tinyllama(T, lc)
        sb = b.summary()
        assert (a.a_rows(), a.h_rows(), a.receipt(), a.u8()) == (sb["A_rows"], sb["H_rows"], sb["receipt"], sb["u8"]), ("TinyLlama", T, lc)
    for lc in (11, 12, 13, 14, 15):
        assert llama8b(32, lc).receipt() == sp_layout.llama3_8b(32, lc).receipt_bytes(), ("8B T32", lc)
    for T, lc in ((128, 14), (512, 15), (1024, 16)):
        a, b = llama8b(T, lc), sp_layout.llama3_8b(T, lc)
        assert (a.a_rows(), a.h_rows(), a.receipt(), a.u8()) == (b.a_rows(), b.h_rows(), b.receipt_bytes(), b.u8_lookups()), ("8B", T)
    out.append("Lay == speed-plan replica at the counted ladder (TinyLlama T32..T512, 8B T32 lc 11..15, 8B T128/512/1024)")
    # (2) Lay == the R10 replica, DD off and on (A rows, H rows, U8, committed)
    for geo, mk in (("TinyLlama-1.1B T128", lambda dd: tinyllama(128, 14, dd=dd)), ("Llama-3-8B T128", lambda dd: llama8b(128, 14, dd=dd)),
                    ("Llama-3-8B T512", lambda dd: llama8b(512, 15, dd=dd))):
        for dd in (False, True):
            t = r10.Layout(r10.GEOMS[geo], dd=dd).totals()
            a = mk(dd)
            assert (a.a_rows(), a.h_rows(), a.u8(), a.summary()["elems"]) == (t["a_rows"], t["h_rows"], t["u8"], t["committed"]), (geo, dd)
    out.append("Lay == R10 replica (which == the R9 prover's printed sizes at T128) with DD off and on; 8B T512 DD 525,172,736")
    # (3) DD's counted receipt delta: +235,008 B per block at both T128 shapes (ledger R9)
    for mk in (lambda dd: tinyllama(128, 14, dd=dd), lambda dd: llama8b(128, 14, dd=dd)):
        assert mk(True).receipt() - mk(False).receipt() == 235_008
    assert tinyllama(128, 14).receipt() == 23_049_192 and llama8b(128, 14).receipt() == 29_300_856
    out.append("DD receipt delta +235,008 B per block reproduced; R9 counted receipts 23,049,192 / 29,300,856 B reproduced")
    # (4) the cost law applied through Lay == the speed plan's block_phases at its shapes
    c = sp_cm.coefficients("cpu")
    for T, lc in ((32, 12), (64, 13), (128, 14)):
        mine, theirs = phases(tinyllama(T, lc), c)["total"], sp_cm.block_phases(sp_layout.tinyllama(T, lc), c)["total"]
        assert abs(mine - theirs) < 1e-9, (T, mine, theirs)
    assert abs(phases(llama8b(32, 13), c)["total"] - sp_cm.block_phases(sp_layout.llama3_8b(32, 13), c)["total"]) < 1e-9
    assert abs(witness(llama8b(32, 13)) - sp_proj.witness_cpu(32)) < 1e-9
    out.append("cost law through Lay == speed plan's block_phases and witness law at its validation shapes")
    return out


# ---- the speed plan's cost law (laptop, 16 threads) [MODEL] -------------------------------
C_CPU = sp_cm.coefficients("cpu")


def phases(sh, c=C_CPU):
    s = sh.summary()
    ah = s["elems"]
    out = {"conversion": c["conv"] * s["A_elems"], "commit": c["commit"] * ah}
    pairs = s["sizes"]["S"] + s["sizes"]["F"] + (s["sizes"]["S"] if sh.dd else 0)   # DD: one tuple inverse per score entry [MODEL]
    out["inverses"] = c["inv_u8"] * s["u8"] + c["inv_pair"] * pairs
    for k in s["terms"]:
        coef = c["zc"]["S"] if k == "Dd" else c["zc"][k]
        out["zc_" + k] = coef * s["sizes"][k] * s["terms"][k] + c["ext"] * s["terms"][k] * s["n"] + c["f0"]
    out["openings"] = c["open"] * ah
    r = c["rest"]
    A, H = sh.claim_sites()
    site_rows = 2 * (sum(A.values()) + sum(H.values()))
    out["rest"] = (r["Dlin"] * s["sizes"]["D"] + r["Slin"] * s["sizes"]["S"] + r["wfold"] * sh.padded_weights()
                   + r["ncol"] * s["n"] + r["siterows"] * site_rows * s["n"] + r["u8"] * s["u8"] + r["const"])
    out["total"] = sum(out.values())
    return out


def witness(sh):
    """the speed plan's CPU witness law (TinyLlama fit; linear term x true weights, quadratic x h*hd)"""
    a_tiny, b_tiny = 3.566e-3, 7.73e-6
    return sh.batch * (a_tiny * (sh.weights_true() / 44_040_192) * sh.T + b_tiny * (sh.h * sh.hd / 2048) * sh.T * sh.Tk)


def verify_block(sh, descriptors=False):
    """speed plan's fresh-verify cryptography law; the 0.737 us term is the dense public tables over the
    score domain (mask, ...), which public-table descriptors (lever L9) would remove"""
    s = sh.summary()
    return 1.46e-9 * sh.padded_weights() + (0 if descriptors else 0.737e-6 * s["sizes"]["S"]) + 0.0315


def memory_gib(sh):
    e = sh.summary()["elems"]
    g = 1024 ** 3
    return dict(host_cpu=(0.5 * g + 53 * e) / g, host_gpu_commit=(0.5 * g + 40 * e) / g, vram_commit_only=(0.2 * g + 8 * e) / g)


BOARD, HOST, GPU_PORT, GPU_WIT = sp_proj.BOARD, sp_proj.HOST, sp_proj.GPU_PORT, sp_proj.GPU_WITNESS_S
CPU_KEYS_BASE = ["conversion", "inverses", "openings", "rest"]
MAC_8B_T512 = llama8b(512, 15).macs()


def block_time(sh, mode, band=1):
    """seconds per block (proof, witness): laptop_cpu | 5090_today (GPU commits only, host CPU 2x laptop,
    the speed plan's step 0) | 5090_port (whole prover + witness on the GPU, step 4 bands) [MODEL]"""
    ph = phases(sh)
    w = witness(sh)
    elems = sh.summary()["elems"]
    if mode == "laptop_cpu":
        return ph["total"], w
    commit = sp_proj.C_GPU_COMMIT_4070 * elems / BOARD[band] + sp_proj.G0_4070 / 2
    rest = sum(v for k, v in ph.items() if k not in ("total", "commit"))
    if mode == "5090_today":
        return commit + rest / HOST[band], w / HOST[band]
    if mode == "5090_port":
        return commit + rest / GPU_PORT[band], GPU_WIT[band] * sh.macs() / MAC_8B_T512
    raise ValueError(mode)


def load_s(weights):
    """digest pass + proving-pass reload, 2.5 s each per 8B layer, scaled by weight bytes [MODEL]"""
    return 2 * sp_proj.LOAD_PER_LAYER * weights / sp_proj.W_UNPADDED


# ---- the new stages around the vision blocks [MODEL plane lists, replica conventions] ------
def stage_counts(T_enc, b=1, lc=15, tq_dec=None):
    """front end (patch embedding + ln_pre) and projector (norm, 2x2 merge, merging layer, linear_1,
    GELU, linear_2), counted with the replica's conventions: an int8 'sym' word = 1 plane and 2 byte
    lookups; int16 = 3 planes and 2 lookups; an L-limb remainder = L planes and L+1 lookups; a norm =
    8 limb planes (rho, sigma at four limbs) + its output, 2 + 2*4 lookups; H = 2 x ceil(lookups/2) per
    position; every domain lifted to the row width. A sketch, not a specification."""
    t = npow2(T_enc) * b
    n = 1 << lc
    lift = lambda size: max(size, n)
    pix = lift(t * 1024)           # 3 x 14 x 14 = 588 bytes per patch, committed in patch-major layout, padded to 1024
    denc = lift(t * 1024)          # encoder width 1024
    m = lift(t // 4 * 1024)        # merged tokens x 1024 (merging-layer output)
    p = lift(t // 4 * 4096)        # merged tokens x 3072 padded to 4096 (projector width)

    def dom(size, a_planes, lookups, act_pairs=0):
        hel = (lookups + 1) // 2 + act_pairs
        return dict(size=size, a=a_planes, lookups=lookups, h=hel, elems=size * (a_planes + 2 * hel), u8=size * lookups)
    front = {
        "pixel plane (u8 range = 1 byte lookup)": dom(pix, 1, 1),
        "conv output int16 + two-byte remainder + ln_pre norm (int16 output, N16 form) + binding plane": dom(denc, 3 + 2 + 6 + 3 + 1, 2 + 3 + (2 + 2 * 3) + 2),
    }
    proj = {
        "projector RMSNorm (int8 output) on the encoder width": dom(denc, 8 + 1, 2 + 2 * 4),
        "merging layer output int8 + two-byte remainder (input = the 2x2 unfold, a bit permutation)": dom(m, 1 + 2, 2 + 3),
        "linear_1 output int8 + two-byte remainder; GELU a16 (activation lookup); linear_2 output int16 + three-byte remainder": dom(p, 1 + 2 + 1 + 3 + 3, (2 + 3) + (2 + 4), act_pairs=1),
    }
    tot = lambda st: dict(elems=sum(v["elems"] for v in st.values()), u8=sum(v["u8"] for v in st.values()))
    return dict(front=front, projector=proj, front_total=tot(front), projector_total=tot(proj))


# ---- scenarios --------------------------------------------------------------------------
TEMPLATE_BEFORE, TEMPLATE_AFTER = 91, 1          # survey T1: 91 public tokens before the content, 1 after (7-category instruction)
IMG_TRAIL = 4                                    # MODEL: " \n\n" + "[/INST]" after the image (empty caption)
ENC_L, DEC_L = 24, 26
W_ENC_BLOCK = pixtral(1024, 15).weights_true()
W_DEC_BLOCK = shieldstral(512, 15).weights_true()


def enc_layout(T_enc, dd, batch=1):
    return best(lambda lc: pixtral(T_enc, lc, dd=dd, batch=batch, f_p=F_P))


def dec_layout(Tq, Tk=None, dd=False, batch=1):
    return best(lambda lc: shieldstral(Tq, lc, tk=Tk, dd=dd, batch=batch))


def run_cost(parts, mode, band=1):
    """parts: list of (layout or None, count, extra_elems_for_stage) -> (seconds, receipt bytes)"""
    secs = 0.0
    for (sh, cnt) in parts:
        b, w = block_time(sh, mode, band)
        secs += cnt * (b + w)
    return secs


def describe(sh):
    s = sh.summary()
    return dict(T=sh.T, Tk=sh.Tk, batch=sh.batch, dd=sh.dd, log_cols=sh.log_cols, elems=s["elems"], u8=s["u8"], receipt=s["receipt"],
                sizes=s["sizes"], elems_by_domain=s["elems_by_domain"], s_share=round(s["elems_by_domain"].get("S", 0) / s["elems"], 3),
                mem=memory_gib(sh), phases_laptop=phases(sh), witness_laptop=witness(sh), verify=verify_block(sh),
                verify_descriptors=verify_block(sh, True), macs=sh.macs())


def image_case(g, enc_dd, f6, label):
    """g = merged grid side (canvas = 28 g px); encoder T = (2g)^2; decoder image tokens g(g+1)"""
    T_enc = (2 * g) ** 2
    img_tok = g * (g + 1)
    enc = enc_layout(T_enc, enc_dd and npow2(T_enc) == T_enc)
    if f6:
        Tq = img_tok + IMG_TRAIL
        dec = dec_layout(Tq, TEMPLATE_BEFORE + Tq)
    else:
        dec = dec_layout(TEMPLATE_BEFORE + img_tok + IMG_TRAIL)
    st = stage_counts(T_enc, lc=enc.log_cols)
    stage_elems = st["front_total"]["elems"] + st["projector_total"]["elems"]
    enc_e = enc.summary()["elems"]
    res = dict(label=label, canvas_px=28 * g, enc_T=T_enc, enc_T_pad=npow2(T_enc), img_tokens=img_tok, dec_Tq=dec.T, dec_Tk=dec.Tk,
               dec_T_pad=dec.tq_pad, enc=describe(enc), dec=describe(dec), stages=st, stage_elems=stage_elems,
               stage_frac_of_enc_block=stage_elems / enc_e)
    # stages: time and receipt scaled from one encoder block by committed elements [MODEL]
    for mode in ("laptop_cpu", "5090_today", "5090_port"):
        be, we = block_time(enc, mode)
        bd, wd = block_time(dec, mode)
        stage_s = (be + we) * stage_elems / enc_e
        res[mode] = dict(enc=ENC_L * (be + we), dec=DEC_L * (bd + wd), stages=stage_s,
                         total=ENC_L * (be + we) + DEC_L * (bd + wd) + stage_s)
    res["loads_s"] = load_s(ENC_L * W_ENC_BLOCK + DEC_L * W_DEC_BLOCK + 2 * W_ENC_BLOCK)
    # whole cold pass: laptop + loads; 5090 today + loads / 1.5 (the speed plan's rule); 5090 port: resident model, no loads
    res["laptop_cpu"]["with_loads"] = res["laptop_cpu"]["total"] + res["loads_s"]
    res["5090_today"]["with_loads"] = res["5090_today"]["total"] + res["loads_s"] / 1.5
    res["5090_port"]["with_loads"] = res["5090_port"]["total"]
    # receipts: the two stages are segments of their own; each is charged one encoder-block receipt [MODEL, conservative]
    res["receipt"] = ENC_L * enc.summary()["receipt"] + DEC_L * dec.summary()["receipt"] + 2 * enc.summary()["receipt"]
    res["peak_host_cpu_GiB"] = max(memory_gib(enc)["host_cpu"], memory_gib(dec)["host_cpu"])
    res["peak_vram_commit_GiB"] = max(memory_gib(enc)["vram_commit_only"], memory_gib(dec)["vram_commit_only"])
    res["verify_s"] = ENC_L * verify_block(enc) + DEC_L * verify_block(dec)
    res["verify_descriptors_s"] = ENC_L * verify_block(enc, True) + DEC_L * verify_block(dec, True)
    return res


def text_case(c, f6, dd=False):
    if f6:
        dec = dec_layout(c + TEMPLATE_AFTER, TEMPLATE_BEFORE + c + TEMPLATE_AFTER, dd=dd)
    else:
        dec = dec_layout(TEMPLATE_BEFORE + c + TEMPLATE_AFTER, dd=dd)
    res = dict(content_tokens=c, f6=f6, dec=describe(dec), dec_T_pad=dec.tq_pad, dec_Tk_pad=dec.tk_pad)
    for mode in ("laptop_cpu", "5090_today", "5090_port"):
        b, w = block_time(dec, mode)
        res[mode] = DEC_L * (b + w)
    res["loads_s"] = load_s(DEC_L * W_DEC_BLOCK)
    res["receipt"] = DEC_L * dec.summary()["receipt"]
    res["peak_host_cpu_GiB"] = memory_gib(dec)["host_cpu"]
    res["peak_vram_commit_GiB"] = memory_gib(dec)["vram_commit_only"]
    res["verify_s"] = DEC_L * verify_block(dec)
    return res


def anchors():
    """the brief's measured anchors and the R8 quiet run, against this model (whole cold pass)"""
    out = {}
    for name, sh, L, meas in (("TinyLlama T32 (brief: 85 s)", tinyllama(32, 12), 22, 85.0), ("8B T32 (brief: 296 s)", llama8b(32, 13), 32, 296.0),
                              ("8B T128 (brief: 569 s, receipt 928 MB, peak 8 GiB)", llama8b(128, 14), 32, 569.0),
                              ("8B T128 R8 quiet (prove 478.7 s + load 27.2 s)", llama8b(128, 14), 32, 478.7 + 27.2)):
        b, w = block_time(sh, "laptop_cpu")
        tot = L * (b + w) + load_s(L * sh.weights_true())
        out[name] = dict(model_s=round(tot, 1), measured_s=meas, err_pct=round(100 * (tot / meas - 1), 1),
                         receipt_MB_model=round(L * sh.receipt() / 1e6, 1), mem_GiB_model=round(memory_gib(sh)["host_cpu"], 2))
    return out


def main():
    notes = checks()
    out = {"schema": "zk60-multimodal-design-cost/1", "checks": notes, "anchors": anchors()}
    # 1. one block of each model at the shapes that matter
    blocks = {}
    for name, sh in (("8B T128 (reference)", llama8b(128, 14)), ("8B T512 (reference)", llama8b(512, 15)),
                     ("Shieldstral decoder T128", dec_layout(128)), ("Shieldstral decoder T256", dec_layout(256)),
                     ("Shieldstral decoder T512", dec_layout(512)), ("Shieldstral decoder T1024", dec_layout(1024)),
                     ("Shieldstral decoder T2048", dec_layout(2048)),
                     ("Pixtral T256 (224 px) non-DD", enc_layout(256, False)), ("Pixtral T256 (224 px) DD", enc_layout(256, True)),
                     ("Pixtral T576->1024 (336 px) non-DD (padded)", enc_layout(576, False)),
                     ("Pixtral T1024 (448 px) non-DD", enc_layout(1024, False)), ("Pixtral T1024 (448 px) DD", enc_layout(1024, True)),
                     ("Pixtral T4096 (896 px) non-DD", enc_layout(4096, False)), ("Pixtral T4096 (896 px) DD", enc_layout(4096, True))):
        blocks[name] = describe(sh)
    out["blocks"] = blocks
    # 2. text posts
    out["text"] = {f"{c} tokens, {'F6' if f6 else 'no F6'}": text_case(c, f6) for c in (64, 256) for f6 in (False, True)}
    # 3. images
    imgs = {}
    for g, lab in ((8, "224 px"), (10, "280 px"), (12, "336 px"), (16, "448 px"), (32, "896 px")):
        for f6 in (False, True):
            imgs[f"{lab}, encoder DD, decoder {'F6' if f6 else 'no F6'}"] = image_case(g, True, f6, lab)
        imgs[f"{lab}, encoder non-DD, decoder no F6"] = image_case(g, False, False, lab)
    out["images"] = imgs
    # 4. video: per-frame image proofs, frames in one run (one load), 30 s at 1 and 0.2 frames/s
    vids = {}
    for key in ("224 px, encoder DD, decoder F6", "224 px, encoder DD, decoder no F6", "448 px, encoder DD, decoder F6"):
        im = imgs[key]
        for fps, frames in ((1.0, 30), (0.2, 6)):
            vids[f"30 s at {fps} fps ({frames} frames), {key}"] = dict(
                frames=frames, laptop_cpu=frames * im["laptop_cpu"]["total"] + im["loads_s"], s5090_today=frames * im["5090_today"]["total"] + im["loads_s"] / 1.5,
                s5090_port=frames * im["5090_port"]["total"], receipt=frames * im["receipt"], peak_host_cpu_GiB=im["peak_host_cpu_GiB"],
                per_minute_frames=frames * 2, per_minute_laptop_s=2 * frames * im["laptop_cpu"]["total"])
    out["video"] = vids
    # 5. batching frames into one block proof (batch axis) vs one block per frame [MODEL]
    bat = {}
    for B in (1, 2, 4, 8):
        e = best(lambda lc: pixtral(256, lc, dd=True, batch=B))
        d = best(lambda lc: shieldstral(80, lc, tk=171, batch=B))
        be, we = block_time(e, "laptop_cpu")
        bd, wd = block_time(d, "laptop_cpu")
        bat[B] = dict(enc_receipt_per_frame=e.receipt() / B, dec_receipt_per_frame=d.receipt() / B, enc_s_per_frame=(be + we) / B,
                      dec_s_per_frame=(bd + wd) / B, enc_mem=memory_gib(e)["host_cpu"], dec_mem=memory_gib(d)["host_cpu"],
                      enc_lc=e.log_cols, dec_lc=d.log_cols)
    out["batch_axis_224px_F6"] = bat
    # 6. split-width decoder layout (3072 = 2048 + 1024, 9216 = 8192 + 1024) as an UPPER BOUND on the saving [MODEL]:
    #    D-domain elements x 3072/4096, F-domain elements x 9216/16384, before any extra claim site / slot / group
    sw = {}
    for T in (128, 256, 512):
        b = describe(dec_layout(T))
        e, D, F = b["elems"], b["elems_by_domain"]["D"], b["elems_by_domain"]["F"]
        new_e = e - D * (1 - 3072 / 4096) - F * (1 - 9216 / 16384)
        sw[T] = dict(elems=e, bound_elems=new_e, d_pct=round(100 * (new_e / e - 1), 1), mem_GiB=(0.5 * 1024 ** 3 + 53 * new_e) / 1024 ** 3)
    out["split_width_bound"] = sw
    json.dump(out, open(os.path.join(HERE, "mm_cost.json"), "w"), indent=1, default=float)

    # ---- print ----
    print("checks:")
    for n_ in notes:
        print("  OK", n_)
    print("\nanchors (whole cold pass, laptop CPU law):")
    for k, v in out["anchors"].items():
        print(f"  {k}: model {v['model_s']} s vs {v['measured_s']} s ({v['err_pct']:+}%), receipt {v['receipt_MB_model']} MB, mem {v['mem_GiB_model']} GiB")
    print("\none block (committed elements, score-domain share, receipt, memory CPU path, laptop proof+witness, verify):")
    for k, v in blocks.items():
        ph = v["phases_laptop"]
        print(f"  {k:46s} lc {v['log_cols']:2d}  elems {v['elems']/1e6:8.1f} M  S {100*v['s_share']:4.1f}%  receipt {v['receipt']/1e6:6.1f} MB"
              f"  mem {v['mem']['host_cpu']:6.1f} GiB  VRAM(commit) {v['mem']['vram_commit_only']:5.1f}  laptop {ph['total']:7.1f}+{v['witness_laptop']:5.1f} s"
              f"  verify {v['verify']:5.2f} s ({v['verify_descriptors']:.2f} w/ descriptors)")
    print("\ntext posts (Shieldstral decoder, 26 blocks):")
    for k, v in out["text"].items():
        print(f"  {k:22s} T_pad {v['dec_T_pad']:4d} (keys {v['dec_Tk_pad']:4d})  laptop {v['laptop_cpu']:7.0f} s (+loads {v['loads_s']:.0f})  5090 today {v['5090_today']:6.0f} s  5090 port {v['5090_port']:5.1f} s"
              f"  receipt {v['receipt']/1e9:5.2f} GB  mem {v['peak_host_cpu_GiB']:5.1f} GiB  verify {v['verify_s']:5.0f} s")
    print("\nimages (24 Pixtral blocks + stages + 26 decoder blocks):")
    for k, v in out["images"].items():
        print(f"  {k:42s} enc T {v['enc_T']:5d}->{v['enc_T_pad']:5d} dec Tq {v['dec_Tq']:4d}->{v['dec_T_pad']:4d}  cold pass laptop {v['laptop_cpu']['with_loads']:6.0f} / 5090 today {v['5090_today']['with_loads']:5.0f} s;  laptop {v['laptop_cpu']['total']:7.0f} s"
              f" (enc {v['laptop_cpu']['enc']:6.0f}, dec {v['laptop_cpu']['dec']:6.0f}, stages {v['laptop_cpu']['stages']:4.0f})"
              f"  5090 today {v['5090_today']['total']:6.0f} s  port {v['5090_port']['total']:5.1f} s  receipt {v['receipt']/1e9:5.2f} GB"
              f"  mem {v['peak_host_cpu_GiB']:6.1f} GiB  VRAM {v['peak_vram_commit_GiB']:5.1f}  verify {v['verify_s']:6.0f} s ({v['verify_descriptors_s']:.0f})  stages/enc-block {v['stage_frac_of_enc_block']:.3f}")
    print("\nvideo (frames proved as images, one run, one load):")
    for k, v in out["video"].items():
        print(f"  {k:60s} laptop {v['laptop_cpu']/3600:6.2f} h  5090 today {v['s5090_today']/3600:5.2f} h  5090 port {v['s5090_port']/60:5.1f} min"
              f"  receipts {v['receipt']/1e9:6.1f} GB  mem {v['peak_host_cpu_GiB']:5.1f} GiB")
    print("\nbatch axis at 224 px with F6 (per frame):")
    for B, v in bat.items():
        print(f"  B={B}: enc {v['enc_s_per_frame']:6.2f} s/frame/block, receipt {v['enc_receipt_per_frame']/1e6:5.1f} MB/frame/block (mem {v['enc_mem']:.1f} GiB, lc {v['enc_lc']});"
              f"  dec {v['dec_s_per_frame']:6.2f} s, {v['dec_receipt_per_frame']/1e6:5.1f} MB (mem {v['dec_mem']:.1f} GiB, lc {v['dec_lc']})")
    print("\nsplit-width decoder, upper bound on the saving [MODEL]:")
    for T, v in sw.items():
        print(f"  T{T}: {v['elems']/1e6:.1f} M -> {v['bound_elems']/1e6:.1f} M ({v['d_pct']:+}%), memory {v['mem_GiB']:.1f} GiB")
    for T, lc in ((256, 14), (1024, 15)):
        stx = stage_counts(T, lc=lc)
        print(f"stages at encoder T{T} (lc {lc}): front {stx['front_total']['elems']/1e6:.1f} M, projector {stx['projector_total']['elems']/1e6:.1f} M")
    st = stage_counts(1024)
    print("\nstages at 448 px (encoder T1024, lc 15) [MODEL]:")
    for part in ("front", "projector"):
        for k, v in st[part].items():
            print(f"  {part:9s} {k}: size 2^{clog2(v['size'])}, A {v['a']}, lookups {v['lookups']}, helpers {v['h']} -> {v['elems']/1e6:.1f} M elements")
    print(f"  front total {st['front_total']['elems']/1e6:.1f} M, projector total {st['projector_total']['elems']/1e6:.1f} M elements")


if __name__ == "__main__":
    main()

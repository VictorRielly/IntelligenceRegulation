"""Counted layouts, per-opening soundness and [MODEL] seconds for the token I/O stages (paper design).

Version 3 (2026-10-17, after the second check `check/CHECK2.md` and the D15 correction): the stack's
own commitment term is counted as the soundness recount does (`results/zk60_soundness_recount_20261017/
RECOUNT.md`: 4L + 1 openings, A / H / boundaries / endpoints at the real ZK-code distance, M at
2^-106.25), whole-run figures add the token-I/O deltas to the recount's R14 whole-run figures where
they exist; N-7: the hidden-length SEL slot claims `s` and `x` (three private tables with `B_out`),
so a selector variant has SEL 2 + SBOOL 1 + IO-s (or the IO-out `s` read) 1 = 4 A sites in place of
IO-in's 1. Version 2 (after the adversarial check `check/CHECK.md`). Changes from v1
(`token_io_count_v1.py`, output `token_io_count_v1.json`):
  * B-1: token endpoints at row width 2^8, rate 1/8 (the frozen toy endpoint geometry); every new
    stage commitment (A_in, H_in, A_out, H_out) at row width >= 2^12, rate 1/4; per-opening proximity
    term (1 - delta/3)^256 with delta = 1 - (n + 256)/(n * inv_rate) (zkp-core/src/pcs.rs ZK code);
    whole-proof commitment term reported per configuration.
  * B-2: the hidden selector s is sealed under an endpoint root: preferred = second half of the input
    token endpoint (two claim sites, boundary geometry data + 2*2 + 2, opened once at the run's end);
    fallback = in the output endpoint's plane beside the token (one site).
  * B-3: tok lives on the same lifted domain as its LogUp helper; every IO slot runs over its token
    endpoint's whole padded plane (>= 256 words); RSEL / IO terms carry public factors (no count change).
  * F-4: the top-limb pin of the argmax difference is dropped (six byte limbs bound delta to
    [0, 2^48); 2^48 + max|RHS| < p): one lookup and (for U8) one Vo helper fewer per entry.

What it counts (DESIGN.md sections 2, 3, 4.4, 5): the INPUT stage, options (a) one-hot matmul,
(b) compressed-row indexed LogUp [chosen], (c) two-chunk one-hot (dense engine); the OUTPUT stage
(final norm + head + keyed argmax) in mode (i) (one output row: public last row, hidden selector
sealed in the input endpoint, hidden selector sealed in the output endpoint) and mode (ii) (every
position), U8 / U16 limbs, keyed / step tie rule.
Conventions as layout.py (exact replica of hashline private_block::shape). Labels: rows / elements /
lookups / terms / bytes / per-opening bits are [COUNTED]; seconds are [MODEL] (cost_model.py).
One thread, pure integers and floats, well under a second.
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cost_model as cm  # noqa: E402  (copied unchanged from results/zk60_speed_plan_20261017)
from layout import Shape, clog2, npow2, COL_CHECKS, MASK_VEC, MASK_PATH, INV_RATE  # noqa: E402

U8 = 256
U16 = 1 << 16
Q = COL_CHECKS                   # opened columns = ZK pad symbols per row (ZkOpts::standard)
ENDPOINT_MASK_ROWS = 5           # endpoint_g::MASK_ROWS (one claim site)
TOKEN_EP_LOG_N, TOKEN_EP_RATE = 8, 8   # B-1: the frozen toy endpoint geometry
STAGE_MIN_LOG = 12               # B-1: width floor of every new stage commitment
VERIFY_PER_WEIGHT = 1.46e-9      # projection.py verify_block fit, per padded weight [MODEL]
VERIFY_PER_STAGE = 0.0315        # same fit, fixed term per block-sized stage [MODEL]
VERIFY_PUBTAB_PER_ENTRY = 5e-9   # ASSUMED Fp2 MLE evaluation of a materialised public table [MODEL]
G0_4070 = 0.305                  # projection.py
BOARD_CENTRAL, HOST_CENTRAL, GPU_PORT_CENTRAL = 5.0, 2.0, 25.0  # projection.py bands, central [MODEL]
D15_CONV = Q * math.log2(0.75)   # the stack's per-opening convention (pads ignored): 2^-106.25


def per_opening_log2(log_n, inv_rate, q=Q):
    """log2 of the column test's miss probability on a far matrix, ZK code RS(n + q, n * inv_rate)."""
    n = 1 << log_n
    delta = 1 - (n + q) / (n * inv_rate)
    return q * math.log2(1 - delta / 3)


def total_log2(terms):
    return math.log2(sum(2.0 ** t for t in terms))


class Model:
    def __init__(self, name, d, V, f, h, hd, kv, L, logcols):
        self.name, self.d, self.V, self.f, self.h, self.hd, self.kv, self.L = name, d, V, f, h, hd, kv, L
        self.d_pad, self.V_pad = npow2(d), npow2(V)
        self.v = clog2(self.V_pad)
        self.logcols = logcols

    def block(self, T):
        return Shape(T, self.d, self.f, self.h, self.hd, self.kv, self.logcols[T])


TINY = Model("TinyLlama-1.1B", 2048, 32000, 5632, 32, 64, 4, 22, {32: 12, 128: 14, 512: 16})
L3_8B = Model("Llama-3-8B", 4096, 128256, 14336, 32, 128, 8, 32, {32: 13, 128: 14, 512: 15})
MODELS = [TINY, L3_8B]
TS = [32, 128, 512]


def logits_bound(m, wmax=127):
    return m.d * 127 * wmax


def window_bits(m, keyed=True):
    """bits needed by the honest difference: keyed 2^v (M - l_i) + (i - tok) <= 2^v * 2B + (V - 1);
    step M - l_i - [i < tok] <= 2B."""
    B2 = 2 * logits_bound(m)
    top = (B2 << m.v) + (m.V - 1) if keyed else B2
    return top.bit_length()


def limbs(bits, limb_bits):
    return -(-bits // limb_bits)


class Endpoint:
    """A token endpoint: `plane` padded words at row width 2^8, rate 1/8; one site = endpoint_g's
    data + 5 rows (M-7); two sites = boundary geometry data + 2 * sites + 2 (M-1, R9)."""

    def __init__(self, name, plane, sites):
        self.name, self.plane, self.sites = name, max(plane, 1 << TOKEN_EP_LOG_N), sites
        self.data = -(-self.plane // (1 << TOKEN_EP_LOG_N))
        self.rows = self.data + (ENDPOINT_MASK_ROWS if sites == 1 else 2 * sites + 2)

    def receipt(self):
        n = 1 << TOKEN_EP_LOG_N
        vl, pth = n + Q, clog2(n * TOKEN_EP_RATE)
        return (self.sites + 1) * vl * 16 + Q * (8 + self.rows * 8 + 32 + pth * 32)

    def per_opening(self):
        return per_opening_log2(TOKEN_EP_LOG_N, TOKEN_EP_RATE)


class Stage:
    """A run stage with its own A / H / M commitments under the run's transcript."""

    def __init__(self, name, log_cols):
        self.name, self.log_cols, self.n = name, log_cols, 1 << log_cols
        self.a, self.h = [], []          # (domain, size) per plane
        self.a_sites, self.h_sites = 0, 0
        self.slots = []                  # (name, main_rounds, ext, degree, terms, zc_size_or_None, n_priv)
        self.u8 = 0
        self.inversions = 0
        self.fold = 0
        self.pubtab = 0
        self.pubtab_factored = 0
        self.endpoints = []              # Endpoint objects this stage introduces (receipt + soundness)
        self.groups_a, self.groups_h = 8, 4

    def lift(self, size, carries_h):
        return max(size, self.n) if carries_h else size

    def rows(self, size):
        return max(1, size >> self.log_cols)

    def a_rows(self):
        return sum(self.rows(s) for _, s in self.a) + 2 * self.a_sites + 2

    def h_rows(self):
        if not self.h:
            return 0
        return sum(2 * self.rows(s) for _, s in self.h) + 2 * self.h_sites + 2

    def openings(self):
        """per-opening log2 of every commitment this stage opens: A, H (rate 1/4 at the stage width),
        M (kept at the stack's D15 convention, like every block's M), token endpoints (2^8, rate 1/8)"""
        t = [per_opening_log2(self.log_cols, INV_RATE)]
        if self.h:
            t.append(per_opening_log2(self.log_cols, INV_RATE))
        t.append(D15_CONV)
        t += [e.per_opening() for e in self.endpoints]
        return t

    def summary(self):
        n = self.n
        ar, hr = self.a_rows(), self.h_rows()
        zc = [(nm, sz, t) for nm, m_, e, dg, t, sz, k in self.slots if sz is not None]
        m_rows = 2 * len(self.slots) + 4
        vec_len, path = n + Q, clog2(n * INV_RATE)

        def opening(groups, rows, vl, pth):
            return (groups + 1) * vl * 16 + Q * (8 + rows * 8 + 32 + pth * 32)
        slot_words = sum(1 + (m_ + e) * (dg + 1) + t for nm, m_, e, dg, t, sz, k in self.slots)
        mask_open = 2 * MASK_VEC * 16 + Q * (8 + m_rows * 8 + 32 + MASK_PATH * 32)
        rb = 96 + slot_words * 16 + mask_open + opening(self.groups_a, ar, vec_len, path)
        if hr:
            rb += opening(self.groups_h, hr, vec_len, path)
        rb += sum(e.receipt() for e in self.endpoints)
        return dict(log_cols=self.log_cols, A_rows=ar, H_rows=hr, M_rows=m_rows, A_elems=ar * n, H_elems=hr * n,
                    elems=(ar + hr) * n, u8=self.u8, inversions=self.inversions, fold=self.fold,
                    zc=zc, zc_elem_terms=sum(sz * t for _, sz, t in zc), largest_zc=max([sz for _, sz, _ in zc] or [0]),
                    slots=len(self.slots), a_sites=self.a_sites, h_sites=self.h_sites, receipt=rb,
                    pubtab=self.pubtab, pubtab_factored=self.pubtab_factored,
                    endpoints={e.name: dict(plane=e.plane, sites=e.sites, rows=e.rows) for e in self.endpoints},
                    per_opening_log2=[round(x, 2) for x in self.openings()])

    def cost(self, c):
        s = self.summary()
        n = self.n
        out = dict(conversion=c["conv"] * s["A_elems"], commit=c["commit"] * s["elems"],
                   inverses=c["inv_u8"] * (s["u8"] + s["inversions"]), openings=c["open"] * s["elems"])
        zc = 0.0
        for nm, sz, t in s["zc"]:
            zc += c["zc"]["D"] * sz * t + c["ext"] * t * n + c["f0"]
        out["zero_checks"] = zc
        r = c["rest"]
        out["fold"] = r["wfold"] * s["fold"]
        out["rest_other"] = r["const"] + r["ncol"] * n + r["siterows"] * 2 * (s["a_sites"] + s["h_sites"]) * n + r["u8"] * s["u8"]
        out["total"] = sum(out.values())
        gpu_commit = cm.coefficients("gpu")["commit"] * s["elems"] / BOARD_CENTRAL + G0_4070 / 2
        cpu_rest = out["total"] - out["commit"]
        out["s0_5090"] = gpu_commit + cpu_rest / HOST_CENTRAL
        out["s3_5090"] = gpu_commit + cpu_rest / GPU_PORT_CENTRAL
        out["verify"] = VERIFY_PER_WEIGHT * s["fold"] + VERIFY_PER_STAGE
        out["verify_pubtab_unfactored"] = VERIFY_PUBTAB_PER_ENTRY * s["pubtab"]
        return out


# ------------------------------------------------------------------------- input stage options
def input_ep(T, sealed_selector=False, shift=False):
    """the input token endpoint: tok (T_pad words, >= 256); with the B-2 selector a second half of
    max(128, T_pad) words; two sites when stage OUT also claims it (selector or SHIFT)"""
    Tp = npow2(T)
    if sealed_selector:
        return Endpoint("input token endpoint (tok | s)", 2 * max(128, Tp), 2)
    return Endpoint("input token endpoint", Tp, 2 if shift else 1)


def input_b(m, T, log_cols, ep):
    """(b) compressed-row indexed LogUp. A: tok [T lifted], mult [Voc]. H: h_q [T lifted], h_tab [Voc], u [Tab]."""
    st = Stage("IN (b) indexed LogUp", log_cols)
    Tp = npow2(T)
    Tl, Vl, Tab = st.lift(Tp, True), st.lift(m.V_pad, True), st.lift(U8, True)
    st.a = [("T", Tl), ("Voc", m.V_pad)]           # B-3: tok on h_q's lifted domain
    st.h = [("T", Tl), ("Voc", m.V_pad), ("Tab", U8)]
    half = ep.plane // 2 if ep.sites == 2 and "s)" in ep.name else ep.plane
    st.slots = [("IO-in tok = endpoint (whole tok plane, public support factor)", clog2(half), 1, 3, 2, half, 2),
                ("query zero-check h_q (alpha - tok - beta x~(t, r_emb) - g) = supp_T (+pad)", clog2(Tl), 1, 4, 3, Tl, 3),
                ("table zero-check h_tab (alpha - tau) = mult (+pad)", clog2(Vl), 1, 4, 2, Vl, 2),
                ("ZS zero-sum row", clog2(Tab), 1, 2, 1, None, 1)]
    st.a_sites, st.h_sites = 3, 3
    st.inversions = m.V_pad + Tp
    st.fold = m.V_pad * m.d_pad
    st.pubtab = Vl + 2 * Tl + Vl
    st.pubtab_factored = st.pubtab
    st.endpoints = [ep]
    st.groups_a, st.groups_h = 3, 4
    return st


def input_a(m, T, log_cols, ep):
    st = Stage("IN (a) one-hot matmul", log_cols)
    Tp = npow2(T)
    OV = Tp * m.V_pad
    st.a = [("OV", OV), ("T", Tp)]
    st.h = []
    st.slots = [("booleanity + row sum 1 + tok = sum_v v O (batched, +pad)", clog2(OV), 1, 4, 2, OV, 2),
                ("gather: sum_v O~(r_t, v) E~(v, r_i) = x~(r_t, r_i)", m.v, 1, 2, 2, None, 2),
                ("IO-in tok = endpoint", clog2(ep.plane), 1, 3, 2, ep.plane, 2)]
    st.a_sites = 4
    st.fold = m.V_pad * m.d_pad
    st.pubtab = 2 * OV + m.V_pad + Tp
    st.pubtab_factored = 3 * m.V_pad + 2 * Tp
    st.endpoints = [ep]
    st.groups_a, st.groups_h = 4, 0
    return st


def input_c(m, T, log_cols, ep):
    st = Stage("IN (c) two-chunk one-hot (dense engine)", log_cols)
    Tp = npow2(T)
    hi, lo = (m.v + 1) // 2, m.v // 2
    Ch, Cl = Tp << hi, Tp << lo
    st.a = [("Ch", Ch), ("Cl", Cl), ("T", Tp)]
    st.h = []
    st.slots = [("chunk hi: booleanity + row sum + index sum", clog2(Ch), 1, 4, 1, Ch, 1),
                ("chunk lo: booleanity + row sum + index sum", clog2(Cl), 1, 4, 1, Cl, 1),
                ("tok = 2^lo hi_idx + lo_idx (T zero-check, hosts both index sums)", clog2(Tp), 1, 2, 1, Tp, 1),
                ("gather over (t, v): eq ra_hi ra_lo E(v, r_i) (two private factors)", clog2(Tp) + m.v, 2, 4, 3, Tp * m.V_pad, 2),
                ("IO-in tok = endpoint", clog2(ep.plane), 1, 3, 2, ep.plane, 2)]
    st.a_sites = 6
    st.fold = m.V_pad * m.d_pad
    st.pubtab = Tp * m.V_pad + Ch + Cl + 2 * Tp
    st.pubtab_factored = m.V_pad + Ch + Cl + 2 * Tp
    st.endpoints = [ep]
    st.groups_a, st.groups_h = 5, 0
    return st


# ------------------------------------------------------------------------- output stage
def output_stage(m, T, T_out, log_cols, limb_bits=8, keyed=True, selector=None, shift=False, pin=False):
    """Final norm + head + greedy argmax for T_out output rows.

    selector: None (public last row), "input" (B-2 preferred: s sealed in the input endpoint's second
    half, claimed by stage OUT's IO-s slot), "output" (B-2 fallback: s in the output endpoint's plane,
    the IO-out slot reads tok and s).
    A planes: To: D, Dsq, tok_out, M; Lo: isqrt limbs; Do: x, xl0, xl1, y, rho x4, sigma x4;
    Vo: e, delta limbs (step: + s_lt); Tab: U8 multiplicities (+ U16); Ts: s (selector variants).
    """
    lc = max(log_cols, 16) if limb_bits == 16 else log_cols
    st = Stage("OUT", lc)
    Top, Tp = npow2(T_out), npow2(T)
    Do, Lo, Vo = Top * m.d_pad, 16 * Top, Top * m.V_pad
    Do_l, Lo_l, Vo_l, Tab_l = st.lift(Do, True), st.lift(Lo, True), st.lift(Vo, True), st.lift(U8, True)
    w = window_bits(m, keyed)
    nl = limbs(w, limb_bits)
    pin_n = 1 if (pin and nl * limb_bits != w) else 0
    v_planes = 1 + nl + (0 if keyed else 1)
    lk_v = nl + pin_n
    hv = (lk_v + 1) // 2
    lk_do = 12
    st.a = [("To", Top)] * 4 + [("Lo", Lo)] + [("Do", Do)] * 12 + [("Vo", Vo)] * v_planes + [("Tab", U8)]
    st.h = [("Lo", Lo)] + [("Do", Do)] * (lk_do // 2) + [("Vo", Vo)] * hv + [("Tab", U8)] * 2
    if limb_bits == 16:
        st.a.append(("Tab16", U16))
        st.h.append(("Tab16", U16))
    if selector:
        st.a.append(("Ts", Tp))
    # output endpoint (B-1 geometry): mode (i) one id (+ s in the fallback), mode (ii) the answer
    if selector == "output":
        out_ep = Endpoint("output token endpoint (tok | s)", 2 * max(128, Tp), 1)
    else:
        out_ep = Endpoint("output token endpoint", Top, 1)
    st.endpoints = [out_ep]
    io_in = ("IO-in x_row = B_out row T-1 (public row bits)", clog2(Do_l), 1, 2, 2, Do_l, 2)
    sel = [("SEL x_sel = sum_t s(t) B_out(t, .) (two private factors, public u0 on x_sel)", clog2(Tp) + clog2(Do_l), 2, 3, 3, None, 3),
           ("SBOOL s(1 - s) = 0 and sum s = 1 (batched, public factors)", clog2(Tp), 1, 3, 1, Tp, 1)]
    if selector == "input":
        sel.append(("IO-s s = input endpoint half 1 (whole half, public support factor)", clog2(max(128, Tp)), 1, 3, 2, max(128, Tp), 2))
    st.slots = ([io_in] if not selector else sel) + [
        ("SS row sums (private, hosted by TZC)", clog2(Do_l), 1, 4, 1, None, 1),
        ("TZC isqrt (D, Dsq, 9 limb slices; hosts SS)", clog2(Top), 1, 3, 11, Top, 11),
        ("LZC limb lookups", clog2(Lo_l), 1, 4, 2, Lo_l, 2),
        ("HEAD matmul sum_i y(r_t, i) W'(r_j, i) (private, hosted by VZC)", clog2(m.d_pad), 1, 2, 1, None, 1),
        ("DZC norm quotient + x limbs + helpers (+pad)", clog2(Do_l), 1, 5, 13 + lk_do // 2, Do_l, 13 + lk_do // 2),
        ("VZC e(1-e) + head host term on keyed l* + helpers (+pad)", clog2(Vo_l), 1, 5, v_planes + 2 + hv, Vo_l, v_planes + 2 + hv),
        ("RSEL supp e (c1 + c2 iota + c3 delta) - u0 (c1 + c2 tok) (standalone)", clog2(Vo_l), 1, 4, v_planes + 1, Vo_l, v_planes + 1),
        ("TAB table helper(s)", clog2(Tab_l), 1, 3, 2 * (2 if limb_bits == 16 else 1), Tab_l, 2),
        ("ZS zero-sum row", clog2(Tab_l), 1, 2, 1, None, 1),
        ("IO-out output endpoint = u0 tok" + (" + S s" if selector == "output" else "") + " (whole plane)",
         clog2(out_ep.plane), 1, 3, 3 if selector == "output" else 2, out_ep.plane, 3 if selector == "output" else 2),
    ]
    if not keyed:
        st.slots.append(("STEP s_lt = LT e (private, hosted by VZC)", clog2(Vo_l), 1, 3, 1, None, 1))
    if shift:
        st.slots.append(("SHIFT tok_out[k] = tok_in[k+1] on the generated range", clog2(Tp), 1, 3, 2, Tp, 2))
    a_sites = (1 + 11 + 1 + 1 + 13 + (v_planes + 2) + (v_planes + 1) + 1 + 1)   # SS..IO-out
    a_sites += 4 if selector else 1          # N-7: SEL (s, x) + SBOOL (s) + IO-s / IO-out s read; or IO-in
    a_sites += (0 if keyed else 2) + (1 if shift else 0)
    st.a_sites = a_sites
    st.h_sites = 1 + lk_do // 2 + hv + (2 if limb_bits == 16 else 1) + 1
    st.u8 = lk_do * Do_l + 1 * Lo_l + lk_v * Vo_l
    st.inversions = U8 + (U16 if limb_bits == 16 else 0)
    st.fold = m.V_pad * m.d_pad
    st.pubtab = 2 * Vo_l + 3 * Do_l + Lo_l + Tab_l
    st.pubtab_factored = 2 * m.V_pad + 2 * Top + 3 * m.d_pad + Lo_l + Tab_l
    st.groups_a, st.groups_h = 10, 6
    return st, dict(window_bits=w, limbs=nl, pin=pin_n, lookups_per_vocab_entry=lk_v, vocab_planes=v_planes)


def best_width(build, lo=STAGE_MIN_LOG, hi=18):
    """the stage's own row width: receipt-optimal at or above the B-1 floor"""
    best = None
    for lc in range(lo, hi + 1):
        st = build(lc)
        rb = st.summary()["receipt"]
        if best is None or rb < best[0]:
            best = (rb, lc, st)
    return best[2]


def boundary_delta(m, T):
    sh = m.block(T)
    data = (npow2(T) * m.d_pad) >> sh.log_cols
    return dict(old_endpoint_rows=data + 5, boundary_rows=data + 6, delta_rows_each=1, row_width_log=sh.log_cols,
                per_opening_log2=round(per_opening_log2(sh.log_cols, INV_RATE), 2))


def stack(m, T, c):
    sh = m.block(T)
    s = sh.summary()
    ph = cm.block_phases(sh, c)
    blk = ph["total"]
    gpu_commit = cm.coefficients("gpu")["commit"] * (s["A_elems"] + s["H_elems"]) / BOARD_CENTRAL + G0_4070 / 2
    rest = blk - ph["commit"]
    return dict(blocks=m.L, elems=m.L * (s["A_elems"] + s["H_elems"]), receipt=m.L * s["receipt"],
                cpu_s=m.L * blk, s0_5090=m.L * (gpu_commit + rest / HOST_CENTRAL), s3_5090=m.L * (gpu_commit + rest / GPU_PORT_CENTRAL),
                verify_s=m.L * (VERIFY_PER_WEIGHT * cm.padded_weights(sh) + 0.737e-6 * s["sizes"]["S"] + VERIFY_PER_STAGE),
                fold=m.L * cm.padded_weights(sh), u8=m.L * s["u8"], largest_zc=max(s["sizes"][k] for k in ("D", "F", "S", "Q", "Kv")),
                openings_d15=6 * m.L, lookups_per_block=s["u8"] + s["sizes"]["S"] + s["sizes"]["F"],
                stack_openings_real=stack_openings(m, T))


def stack_openings(m, T):
    """RECOUNT.md (D15 correction 19:40 UTC): a run opens 4L + 1 commitments -- A, H per block and the
    L - 1 boundaries and two endpoints at the block row width, rate 1/4, real ZK-code distance; one M
    per block at 2^-106.25 (RS(1024, 4096)). With token I/O the two endpoints become B_in / B_out at
    the same geometry, so this list is unchanged and the new openings are added on top."""
    lc = m.logcols[T]
    return [per_opening_log2(lc, INV_RATE)] * (3 * m.L + 1) + [D15_CONV] * m.L


# RECOUNT.md section 4, whole run (b) real distance, R14 LogUp convention (no T512 figures exist)
RECOUNT_WHOLE_RUN_R14 = {("TinyLlama-1.1B", 32): -97.09, ("TinyLlama-1.1B", 128): -96.45, ("Llama-3-8B", 32): -96.77}
F_ORDER_LOG2 = 128.0   # |F_p^2| ~ 2^128 (R14 convention: lookup term 4N/|F|)


def fmt_stage(st, c):
    s, k = st.summary(), st.cost(c)
    line = ("%-50s n=2^%-2d A %6d H %6d elems %9.3fM u8 %9.3fM zcET %9.3fM maxzc 2^%-2d | cpu %6.2f S0 %5.2f S3 %5.2f | ver %5.2f"
            " | receipt %5.2f MB | worst opening 2^%.2f" % (
                st.name, st.log_cols, s["A_rows"], s["H_rows"], s["elems"] / 1e6, s["u8"] / 1e6, s["zc_elem_terms"] / 1e6,
                max(1, s["largest_zc"]).bit_length() - 1, k["total"], k["s0_5090"], k["s3_5090"], k["verify"], s["receipt"] / 1e6,
                max(s["per_opening_log2"])))
    return line, s, k


def main():
    c = cm.coefficients("cpu")
    res = {"version": 2, "labels": "rows/elements/lookups/terms/bytes/bits [COUNTED]; seconds [MODEL]",
           "per_opening_log2": {"log_n %d rate 1/4" % ln: round(per_opening_log2(ln, 4), 2) for ln in range(8, 17)},
           "models": {}}
    res["per_opening_log2"]["token endpoint log_n 8 rate 1/8"] = round(per_opening_log2(8, 8), 2)
    res["per_opening_log2"]["D15 convention"] = round(D15_CONV, 2)
    print("per-opening log2: " + ", ".join("%s %.2f" % kv for kv in res["per_opening_log2"].items()))
    for m in MODELS:
        mres = {"V": m.V, "V_pad": m.V_pad, "d": m.d, "logits_bound": logits_bound(m),
                "window_keyed_bits": window_bits(m, True), "window_step_bits": window_bits(m, False), "T": {}}
        print("\n==== %s  V=%d (pad 2^%d)  d=%d  |logit| <= %d  keyed window %d bits (%d byte limbs, no pin), step %d bits ====" % (
            m.name, m.V, m.v, m.d, logits_bound(m), window_bits(m, True), limbs(window_bits(m, True), 8), window_bits(m, False)))
        for T in TS:
            tr = {}
            stk = stack(m, T, c)
            tr["stack"] = stk
            tr["boundary"] = boundary_delta(m, T)
            stk["commitment_term_real_log2"] = round(total_log2(stk["stack_openings_real"]), 2)
            print("-- T%d: %d-block stack: elems %.3fG, cpu %.1f s, 5090 S0 %.1f s, S3 %.1f s, verify %.1f s, commitment term (RECOUNT, real) 2^%.2f%s" % (
                T, m.L, stk["elems"] / 1e9, stk["cpu_s"], stk["s0_5090"], stk["s3_5090"], stk["verify_s"], stk["commitment_term_real_log2"],
                (", whole run (R14) 2^%.2f" % RECOUNT_WHOLE_RUN_R14[(m.name, T)]) if (m.name, T) in RECOUNT_WHOLE_RUN_R14 else ""))
            ep1 = input_ep(T)
            for fn in (input_a, input_b, input_c):
                st = best_width(lambda lc: fn(m, T, lc, ep1))
                line, s, k = fmt_stage(st, c)
                print("   " + line)
                tr[st.name] = dict(summary={kk: vv for kk, vv in s.items() if kk != "zc"}, zc=s["zc"], cost=k)
            variants = [("OUT mode(i) public last row", dict(T_out=1), None, False),
                        ("OUT mode(i) hidden selector, sealed in input endpoint (B-2 preferred)", dict(T_out=1, selector="input"), "input", False),
                        ("OUT mode(i) hidden selector, sealed in output endpoint (B-2 fallback)", dict(T_out=1, selector="output"), None, False),
                        ("OUT mode(i) public last row, WITH pin (v1 form)", dict(T_out=1, pin=True), None, False),
                        ("OUT mode(ii) U8 keyed", dict(T_out=T, shift=True), "shift", True),
                        ("OUT mode(ii) U8 step", dict(T_out=T, keyed=False, shift=True), "shift", True),
                        ("OUT mode(ii) U16 keyed", dict(T_out=T, limb_bits=16, shift=True), "shift", True)]
            for nm, kw, in_kind, is_ii in variants:
                lo = 16 if kw.get("limb_bits") == 16 else STAGE_MIN_LOG
                st = best_width(lambda lc: output_stage(m, T, log_cols=lc, **kw)[0], lo, 18)
                info = output_stage(m, T, log_cols=st.log_cols, **kw)[1]
                st.name = nm
                line, s, k = fmt_stage(st, c)
                print("   " + line + "  [w %d b, %d limbs, pin %d]" % (info["window_bits"], info["limbs"], info["pin"]))
                # the matching input stage (its endpoint geometry depends on the variant)
                ep = input_ep(T, sealed_selector=(in_kind == "input"), shift=(in_kind == "shift"))
                st_in = best_width(lambda lc: input_b(m, T, lc, ep))
                s_in, k_in = st_in.summary(), st_in.cost(c)
                el = s_in["elems"] + s["elems"]
                tot = {k2: k_in[k2] + k[k2] for k2 in ("total", "s0_5090", "s3_5090", "verify")}
                rb = s_in["receipt"] + s["receipt"]
                new_open = st_in.openings() + st.openings()
                term = total_log2(stk["stack_openings_real"] + new_open)
                n_tok = T + s["u8"]
                whole = None
                if (m.name, T) in RECOUNT_WHOLE_RUN_R14:
                    whole = round(math.log2(2.0 ** RECOUNT_WHOLE_RUN_R14[(m.name, T)] + sum(2.0 ** x for x in new_open)
                                            + 4 * n_tok / 2.0 ** F_ORDER_LOG2), 2)
                tr[nm] = dict(summary={kk: vv for kk, vv in s.items() if kk != "zc"}, zc=s["zc"], cost=k, argmax=info,
                              input_stage=dict(log_cols=st_in.log_cols, elems=s_in["elems"], receipt=s_in["receipt"],
                                               endpoints=s_in["endpoints"], cost=k_in),
                              total=dict(elems=el, receipt=rb, commitment_term_log2=round(term, 2), whole_run_r14_log2=whole, **tot))
                print("      + IN(b) n=2^%d %.3fM -> TOTAL elems %8.3fM (+%5.2f%%) cpu %6.2f s (+%5.2f%%) S0 %5.2f (+%5.2f%%) S3 %5.2f (+%5.2f%%)"
                      " verify +%5.2f s (+%4.1f%%) receipt +%5.2f MB | commitment term 2^%.2f%s" % (
                          st_in.log_cols, s_in["elems"] / 1e6, el / 1e6, 100 * el / stk["elems"], tot["total"], 100 * tot["total"] / stk["cpu_s"],
                          tot["s0_5090"], 100 * tot["s0_5090"] / stk["s0_5090"], tot["s3_5090"], 100 * tot["s3_5090"] / stk["s3_5090"],
                          tot["verify"], 100 * tot["verify"] / stk["verify_s"], rb / 1e6, term,
                          (" whole run (R14) 2^%.2f" % whole) if whole is not None else ""))
            mres["T"][T] = tr
        res["models"][m.name] = mres
    # the v1 geometry, for the record (token endpoints 2^8 at rate 1/4, receipt-optimal stage widths)
    v1 = {}
    for m, lin, lout in ((L3_8B, 11, 12), (TINY, 10, 11)):
        terms = [D15_CONV] * (6 * m.L) + [per_opening_log2(lin, 4)] * 2 + [per_opening_log2(lout, 4)] * 2 \
            + [D15_CONV] * 2 + [per_opening_log2(8, 4)] * 2
        v1[m.name] = round(total_log2(terms), 2)
    res["v1_geometry_commitment_term_log2"] = v1
    print("\nv1 geometry whole-proof commitment term (T32): " + ", ".join("%s 2^%.2f" % kv for kv in v1.items()))
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "token_io_count.json"), "w") as fh:
        json.dump(res, fh, indent=1, default=float)


if __name__ == "__main__":
    main()

"""Counted layouts and [MODEL] seconds for the token I/O stages (paper design, read-only arithmetic).

What it counts (DESIGN.md sections 2, 3, 5):
  * the INPUT stage, three options: (a) hidden one-hot rows x public embedding (matmul slot),
    (b) compressed-row indexed LogUp  (tok_t, x~(t, r_emb)) in {(v, E~(v, r_emb))}  [chosen],
    (c) two-chunk one-hot addresses (Shout-style, Setty-Thaler ePrint 2025/105) with the dense
        sum-check engine this codebase has;
  * the OUTPUT stage: final RMSNorm (one norm of the block's kind, uniform gain) + head matmul +
    keyed greedy argmax (one-hot selector e, keyed differences delta in byte limbs), in
    mode (i) one output position and mode (ii) every position (T_out = T);
    variants: U8 limbs (baseline, today's single byte table) and U16 limbs (needs row width 2^16).

Every count is a function of public geometry only, written from the plane / site / slot lists in
DESIGN.md section 2.3 and 3.3 with the same conventions as layout.py (the exact replica of
hashline private_block::shape): rows_of = max(1, size >> log_cols); A rows = data + 2*sites + 2;
H planes are Fp2 (two slices); a domain that carries H planes and sits below the row width is
lifted to it (P-3); every padded position is a pad-zero position (P-1) and is counted in the
lookup and zero-check sizes exactly as layout.py counts them.
Labels: rows / elements / lookups / terms / bytes are [COUNTED] (exact arithmetic on the design);
seconds are [MODEL] (cost_model.py coefficients, fitted on the R4-4 laptop phase run).
One thread, pure integers and floats, well under a second.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cost_model as cm  # noqa: E402  (copied unchanged from results/zk60_speed_plan_20261017)
from layout import Shape, clog2, npow2, COL_CHECKS, MASK_VEC, MASK_PATH, INV_RATE, WIRE_HEADER  # noqa: E402

U8 = 256
U16 = 1 << 16
ENDPOINT_MASK_ROWS = 5          # endpoint_g::MASK_ROWS
VERIFY_PER_WEIGHT = 1.46e-9     # projection.py verify_block fit (fresh-process verifier, per padded weight) [MODEL]
VERIFY_PER_STAGE = 0.0315       # same fit, fixed term per block-sized stage [MODEL]
VERIFY_PUBTAB_PER_ENTRY = 5e-9  # ASSUMED Fp2 MLE evaluation of a materialised public table, per entry [MODEL]
G0_4070 = 0.305                 # projection.py
BOARD_CENTRAL, HOST_CENTRAL, GPU_PORT_CENTRAL = 5.0, 2.0, 25.0  # projection.py bands, central [MODEL]


class Model:
    def __init__(self, name, d, V, f, h, hd, kv, L, logcols):
        self.name, self.d, self.V, self.f, self.h, self.hd, self.kv, self.L = name, d, V, f, h, hd, kv, L
        self.d_pad, self.V_pad = npow2(d), npow2(V)
        self.v = clog2(self.V_pad)
        self.logcols = logcols  # block row width per T (the speed plan's choice)

    def block(self, T):
        return Shape(T, self.d, self.f, self.h, self.hd, self.kv, self.logcols[T])


TINY = Model("TinyLlama-1.1B", 2048, 32000, 5632, 32, 64, 4, 22, {32: 12, 128: 14, 512: 16})
L3_8B = Model("Llama-3-8B", 4096, 128256, 14336, 32, 128, 8, 32, {32: 13, 128: 14, 512: 15})
MODELS = [TINY, L3_8B]
TS = [32, 128, 512]


def logits_bound(m):
    """|logit| <= d * 127 * 127: int8 norm output in [-127, 127] (sym lookups), int8 head weights
    clipped to [-127, 127] by the calibration's qw()."""
    return m.d * 127 * 127


def window_bits(m, keyed=True):
    """bits of the argmax difference. keyed: delta = 2^v (M - l_i) + (i - tok) in [0, 2^v * 2B + 2^v);
    step: delta' = M - l_i - [i < tok] in [0, 2B]."""
    B2 = 2 * logits_bound(m)
    top = (B2 << m.v) + (1 << m.v) if keyed else B2
    return top.bit_length()


def limbs(bits, limb_bits):
    n = -(-bits // limb_bits)
    pin = 0 if bits == n * limb_bits else 1
    return n, pin


class Stage:
    """A run stage with its own A / H / M commitments under the run's transcript."""

    def __init__(self, name, log_cols):
        self.name, self.log_cols, self.n = name, log_cols, 1 << log_cols
        self.a, self.h = [], []          # (domain, size) per plane
        self.a_sites, self.h_sites = 0, 0
        self.slots = []                  # (name, main_rounds, ext, degree, terms, zc_size_or_None, n_priv_tables)
        self.u8 = 0                      # byte(-table) lookups
        self.inversions = 0              # LogUp table-side inversions (+ query side)
        self.fold = 0                    # public matrix entries folded per proof (both sides)
        self.pubtab = 0                  # public-table entries the verifier materialises (unfactored)
        self.pubtab_factored = 0         # the same if supp / eq are evaluated as tensor products
        self.extra_rows = {}             # endpoint / boundary rows this stage adds (name -> (rows, log_n))
        self.groups_a, self.groups_h = 8, 4  # column-weight groups estimate for the opening bytes

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

    def summary(self):
        n = self.n
        ar, hr = self.a_rows(), self.h_rows()
        zc = [(nm, sz, t) for nm, m_, e, dg, t, sz, k in self.slots if sz is not None]
        m_rows = 2 * len(self.slots) + 4
        vec_len, path = n + COL_CHECKS, clog2(n * INV_RATE)

        def opening(groups, rows, vl, pth):
            return (groups + 1) * vl * 16 + COL_CHECKS * (8 + rows * 8 + 32 + pth * 32)
        slot_words = sum(1 + (m_ + e) * (dg + 1) + t for nm, m_, e, dg, t, sz, k in self.slots)
        mask_open = 2 * MASK_VEC * 16 + COL_CHECKS * (8 + m_rows * 8 + 32 + MASK_PATH * 32)
        rb = 96 + slot_words * 16 + mask_open + opening(self.groups_a, ar, vec_len, path)
        if hr:
            rb += opening(self.groups_h, hr, vec_len, path)
        for nm, (rows, ln) in self.extra_rows.items():
            rb += opening(1, rows, (1 << ln) + COL_CHECKS, clog2((1 << ln) * INV_RATE))
        return dict(A_rows=ar, H_rows=hr, M_rows=m_rows, A_elems=ar * n, H_elems=hr * n,
                    elems=(ar + hr) * n, u8=self.u8, inversions=self.inversions, fold=self.fold,
                    zc=zc, zc_elem_terms=sum(sz * t for _, sz, t in zc), largest_zc=max([sz for _, sz, _ in zc] or [0]),
                    slots=len(self.slots), a_sites=self.a_sites, h_sites=self.h_sites, receipt=rb,
                    pubtab=self.pubtab, pubtab_factored=self.pubtab_factored,
                    extra_rows={k: v[0] for k, v in self.extra_rows.items()})

    def cost(self, c):
        """laptop-CPU phases [MODEL], the block cost model's coefficient per unit of work."""
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
        # 5090 S0 central: commit on the keyed GPU kernel (4070 coefficient / board factor), the rest
        # on a desktop host CPU; S3 central: every other phase ported to the GPU.
        gpu_commit = cm.coefficients("gpu")["commit"] * s["elems"] / BOARD_CENTRAL + G0_4070 / 2
        cpu_rest = out["total"] - out["commit"]
        out["s0_5090"] = gpu_commit + cpu_rest / HOST_CENTRAL
        out["s3_5090"] = gpu_commit + cpu_rest / GPU_PORT_CENTRAL
        out["verify"] = VERIFY_PER_WEIGHT * s["fold"] + VERIFY_PER_STAGE
        out["verify_pubtab_unfactored"] = VERIFY_PUBTAB_PER_ENTRY * s["pubtab"]
        return out


# ------------------------------------------------------------------------- input stage options
def endpoint_tok(T_pad):
    """the new external token endpoint: one data row of max(256, T_pad) words + 5 mask rows"""
    ln = max(8, clog2(T_pad))
    return (-(-T_pad // (1 << ln))) + ENDPOINT_MASK_ROWS, ln


def input_b(m, T, log_cols=None):
    """(b) compressed-row indexed LogUp. A: tok [T], mult [Voc]. H: h_q [T], h_tab [Voc], u [Tab]."""
    sh = m.block(T)
    st = Stage("IN (b) indexed LogUp", log_cols or sh.log_cols)
    Tp = npow2(T)
    Tl, Vl, Tab = st.lift(Tp, True), st.lift(m.V_pad, True), st.lift(U8, True)
    st.a = [("T", Tp), ("Voc", m.V_pad)]
    st.h = [("T", Tp), ("Voc", m.V_pad), ("Tab", U8)]
    # slots: (name, main, ext, degree, terms, zc size, private tables)
    st.slots = [("IO-in tok = endpoint", clog2(Tl), 1, 2, 2, Tl, 2),
                ("query zero-check h_q (alpha - tok - beta x~(t, r_emb)) = 1 (+pad)", clog2(Tl), 1, 4, 3, Tl, 3),
                ("table zero-check h_tab (alpha - tau) = mult (+pad)", clog2(Vl), 1, 4, 2, Vl, 2),
                ("ZS zero-sum row", clog2(Tab), 1, 2, 1, None, 1)]
    st.a_sites, st.h_sites = 3, 3      # tok x2, mult; h_q, h_tab, u
    st.inversions = m.V_pad + Tp
    st.fold = m.V_pad * m.d_pad        # E~(v, r_emb) for every v (int16 table)
    st.pubtab = Vl + 2 * Tl + Vl       # tau, supp_T, iota-tag part of tau, supp_V
    st.pubtab_factored = st.pubtab
    st.extra_rows["token endpoint"] = endpoint_tok(Tp)
    st.groups_a, st.groups_h = 3, 4
    return st


def input_a(m, T, log_cols=None):
    """(a) hidden one-hot rows O [T x V] times the public table, as a matmul slot."""
    sh = m.block(T)
    st = Stage("IN (a) one-hot matmul", log_cols or sh.log_cols)
    Tp = npow2(T)
    OV = Tp * m.V_pad
    st.a = [("OV", OV), ("T", Tp)]
    st.h = []
    st.slots = [("booleanity + row sum 1 + tok = sum_v v O (batched, +pad)", clog2(OV), 1, 4, 2, OV, 2),
                ("gather: sum_v O~(r_t, v) E~(v, r_i) = x~(r_t, r_i)", m.v, 1, 2, 2, None, 2),
                ("IO-in tok = endpoint", clog2(Tp), 1, 2, 2, Tp, 2)]
    st.a_sites = 4
    st.fold = m.V_pad * m.d_pad
    st.pubtab = 2 * OV + m.V_pad + Tp    # supp over the OV cube, iota tiled over OV, E~(., r_i), supp_T
    st.pubtab_factored = 3 * m.V_pad + 2 * Tp
    st.extra_rows["token endpoint"] = endpoint_tok(Tp)
    st.groups_a, st.groups_h = 4, 0
    return st


def input_c(m, T, log_cols=None):
    """(c) two-chunk one-hot addresses (Shout-style) with this codebase's DENSE sum-check engine."""
    sh = m.block(T)
    st = Stage("IN (c) two-chunk one-hot (dense engine)", log_cols or sh.log_cols)
    Tp = npow2(T)
    hi, lo = (m.v + 1) // 2, m.v // 2
    Ch, Cl = Tp << hi, Tp << lo
    st.a = [("Ch", Ch), ("Cl", Cl), ("T", Tp)]
    st.h = []
    st.slots = [("chunk hi: booleanity + row sum + index sum", clog2(Ch), 1, 4, 1, Ch, 1),
                ("chunk lo: booleanity + row sum + index sum", clog2(Cl), 1, 4, 1, Cl, 1),
                ("tok = 2^lo hi_idx + lo_idx (T zero-check, hosts both index sums)", clog2(Tp), 1, 2, 1, Tp, 1),
                ("gather over (t, v): eq ra_hi ra_lo E(v, r_i) (two private factors)", clog2(Tp) + m.v, 2, 4, 3, Tp * m.V_pad, 2),
                ("IO-in tok = endpoint", clog2(Tp), 1, 2, 2, Tp, 2)]
    st.a_sites = 6
    st.fold = m.V_pad * m.d_pad
    st.pubtab = Tp * m.V_pad + Ch + Cl + 2 * Tp
    st.pubtab_factored = m.V_pad + Ch + Cl + 2 * Tp
    st.extra_rows["token endpoint"] = endpoint_tok(Tp)
    st.groups_a, st.groups_h = 5, 0
    return st


# ------------------------------------------------------------------------- output stage
def output_stage(m, T, T_out, limb_bits=8, keyed=True, selector=False, shift=False, log_cols=None):
    """Final norm + head + greedy argmax for T_out output positions.

    A planes: To: D, Dsq, tok_out, M (+ s on the T axis if the output row is a HIDDEN selection);
    Lo: the isqrt limb plane; Do: x, xl0, xl1, y, rho x4, sigma x4 (the block's norm_a set, int16
    x re-range-proved as every block does); Vo: e, delta limbs (step variant: + s_lt); Tab: mult(s).
    """
    sh = m.block(T)
    lc = log_cols if log_cols is not None else sh.log_cols
    if limb_bits == 16:
        lc = max(lc, 16)   # P-3 / stage 23 invariant: log(Tab) == row width, so a U16 table needs 2^16
    st = Stage("OUT", lc)
    Top = npow2(T_out)
    Tp = npow2(T)
    Do, Lo, Vo = Top * m.d_pad, 16 * Top, Top * m.V_pad
    Do_l, Lo_l, Vo_l = st.lift(Do, True), st.lift(Lo, True), st.lift(Vo, True)
    w = window_bits(m, keyed)
    nl, pin = limbs(w, limb_bits)
    v_planes = 1 + nl + (0 if keyed else 1)
    lk_v = nl + pin
    st.a = [("To", Top)] * 4 + [("Lo", Lo)] + [("Do", Do)] * 12 + [("Vo", Vo)] * v_planes + [("Tab", U8)]
    if limb_bits == 16:
        st.a.append(("Tab16", U16))
    if selector:
        st.a.append(("Ts", Tp))
    lk_do = 2 + 2 + 8   # x limbs, y sym, rho/sigma 4+4 (C-6: window 32, top pins dropped)
    st.h = [("Lo", Lo)] + [("Do", Do)] * ((lk_do + 1) // 2) + [("Vo", Vo)] * ((lk_v + 1) // 2) + [("Tab", U8)] * 2
    if limb_bits == 16:
        st.h.append(("Tab16", U16))
    Tab_l = st.lift(U8, True)
    hv = (lk_v + 1) // 2
    st.slots = [
        ("IO-in x_row = B_out row" + (" (hidden selector, bilinear)" if selector else " (public row)"),
         clog2(Do_l) + (clog2(Tp) if selector else 0), 2 if selector else 1, 2, 2, None if selector else Do_l, 2),
        ("SS row sums (private, hosted by TZC)", clog2(Do_l), 1, 4, 1, None, 1),
        ("TZC isqrt (D, Dsq, 9 limb slices; hosts SS)", clog2(Top), 1, 3, 11, Top, 11),
        ("LZC limb lookups", clog2(Lo_l), 1, 4, 2, Lo_l, 2),
        ("HEAD matmul sum_i y(r_t, i) W'(r_j, i) (private, hosted by VZC)", clog2(m.d_pad), 1, 2, 1, None, 1),
        ("DZC norm quotient + x limbs + helpers (+pad)", clog2(Do_l), 1, 5, 13 + (lk_do + 1) // 2, Do_l, 13 + (lk_do + 1) // 2),
        ("VZC e(1-e) + head host term on keyed l + helpers (+pad)", clog2(Vo_l), 1, 5, v_planes + 2 + hv, Vo_l, v_planes + 2 + hv),
        ("RSEL sum e = 1, sum e*iota = tok, sum e*delta = 0 (batched, standalone)", clog2(Vo_l), 1, 4, v_planes + 1, Vo_l, v_planes + 1),
        ("TAB table helper(s)", clog2(Tab_l), 1, 3, 2 * (2 if limb_bits == 16 else 1), Tab_l, 2),
        ("ZS zero-sum row", clog2(Tab_l), 1, 2, 1, None, 1),
        ("IO-out tok_out = output endpoint", clog2(Top), 1, 2, 2, Top, 2),
    ]
    if not keyed:
        st.slots.append(("STEP s = LT e (private, hosted by VZC)", clog2(Vo_l), 1, 3, 1, None, 1))
    if shift:
        st.slots.append(("SHIFT tok_out[k] = tok_in[k+1] on the generated range", clog2(Tp), 1, 3, 2, Tp, 2))
    st.a_sites = (1 + 1 + 11 + 1 + 1 + 13 + (v_planes + 2) + (v_planes + 1) + 1 + 1
                  + (1 if selector else 0) + (0 if keyed else 2) + (1 if shift else 0))
    st.h_sites = 1 + (lk_do + 1) // 2 + hv + (2 if limb_bits == 16 else 1) + 1
    st.u8 = lk_do * Do_l + 1 * Lo_l + lk_v * Vo_l
    st.inversions = U8 + (U16 if limb_bits == 16 else 0)
    st.fold = m.V_pad * m.d_pad        # W_head' (int8), folded with eq(r_j) on both sides
    st.pubtab = 2 * Vo_l + 3 * Do_l + Lo_l + Tab_l     # supp_Vo + iota tiled, gamma / supp over Do, ...
    st.pubtab_factored = 2 * m.V_pad + 2 * Top + 3 * m.d_pad + Lo_l + Tab_l
    st.extra_rows["output token endpoint"] = endpoint_tok(Top)
    st.groups_a, st.groups_h = 10, 6
    return st, dict(window_bits=w, limbs=nl, pin=pin, lookups_per_vocab_entry=lk_v, vocab_planes=v_planes)


def best_width(build, lo=8, hi=17):
    """the stage's own row width, receipt-optimal (the speed plan's convention for blocks)"""
    best = None
    for lc in range(lo, hi + 1):
        st = build(lc)
        rb = st.summary()["receipt"]
        if best is None or rb < best[0]:
            best = (rb, lc, st)
    return best[2]


def boundary_delta(m, T):
    """B_in / B_out replace today's two external x endpoints: data + 2*2 + 2 rows instead of data + 5."""
    sh = m.block(T)
    data = (npow2(T) * m.d_pad) >> sh.log_cols
    return dict(old_endpoint_rows=data + 5, boundary_rows=data + 6, delta_rows_each=1, row_width_log=sh.log_cols)


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
                fold=m.L * cm.padded_weights(sh), u8=m.L * s["u8"], largest_zc=max(s["sizes"][k] for k in ("D", "F", "S", "Q", "Kv")))


def fmt_stage(st, c, extra=None):
    s, k = st.summary(), st.cost(c)
    line = ("%-46s n=2^%-2d A %6d H %6d elems %9.3fM u8 %9.3fM inv %7d zcET %9.3fM maxzc 2^%-4.1f fold %6.1fM | cpu %6.2f s "
            "S0 %5.2f S3 %5.2f | ver %5.2f s (+%5.2f unfactored) | receipt %5.2f MB" % (
                st.name, st.log_cols, s["A_rows"], s["H_rows"], s["elems"] / 1e6, s["u8"] / 1e6, s["inversions"],
                s["zc_elem_terms"] / 1e6, (max(1, s["largest_zc"])).bit_length() - 1, s["fold"] / 1e6, k["total"], k["s0_5090"], k["s3_5090"],
                k["verify"], k["verify_pubtab_unfactored"], s["receipt"] / 1e6))
    return line, s, k


def main():
    c = cm.coefficients("cpu")
    res = {"labels": "rows/elements/lookups/terms/bytes [COUNTED]; seconds [MODEL]", "models": {}}
    for m in MODELS:
        mres = {"V": m.V, "V_pad": m.V_pad, "d": m.d, "logits_bound": logits_bound(m),
                "window_keyed_bits": window_bits(m, True), "window_step_bits": window_bits(m, False), "T": {}}
        print("\n==== %s  V=%d (pad 2^%d)  d=%d  |logit| <= %d (2^%.2f)  keyed window %d bits, step window %d bits ====" % (
            m.name, m.V, m.v, m.d, logits_bound(m), logits_bound(m).bit_length() - 1 + (logits_bound(m) / (1 << (logits_bound(m).bit_length() - 1)) - 1),
            window_bits(m, True), window_bits(m, False)))
        for T in TS:
            tr = {}
            stk = stack(m, T, c)
            tr["stack"] = stk
            tr["boundary"] = boundary_delta(m, T)
            print("-- T%d: today's %d-block stack: elems %.3fG, cpu %.1f s, 5090 S0 %.1f s, S3 %.1f s, verify %.1f s, fold %.2fG, largest block zc domain 2^%d, receipt %.1f MB" % (
                T, m.L, stk["elems"] / 1e9, stk["cpu_s"], stk["s0_5090"], stk["s3_5090"], stk["verify_s"], stk["fold"] / 1e9,
                stk["largest_zc"].bit_length() - 1, stk["receipt"] / 1e6))
            for fn in (input_a, input_b, input_c):
                st = best_width(lambda lc: fn(m, T, lc), 8, 17)
                line, s, k = fmt_stage(st, c)
                print("   " + line)
                tr[st.name] = dict(log_cols=st.log_cols, summary={kk: vv for kk, vv in s.items() if kk != "zc"}, zc=s["zc"], cost=k)
            variants = [("OUT mode(i) U8 keyed, public last row", dict(T_out=1)),
                        ("OUT mode(i) U8 keyed, hidden selector", dict(T_out=1, selector=True)),
                        ("OUT mode(ii) U8 keyed, T_out=T", dict(T_out=T, shift=True)),
                        ("OUT mode(ii) U8 step, T_out=T", dict(T_out=T, keyed=False, shift=True)),
                        ("OUT mode(ii) U16 keyed, T_out=T", dict(T_out=T, limb_bits=16, shift=True)),
                        ("OUT mode(ii) U16 step, T_out=T", dict(T_out=T, limb_bits=16, keyed=False, shift=True))]
            for nm, kw in variants:
                lo = 16 if kw.get("limb_bits") == 16 else 8
                st = best_width(lambda lc: output_stage(m, T, log_cols=lc, **kw)[0], lo, 18)
                info = output_stage(m, T, log_cols=st.log_cols, **kw)[1]
                st.name = nm
                line, s, k = fmt_stage(st, c)
                print("   " + line + "  [window %d b, %d limbs + %d pin]" % (info["window_bits"], info["limbs"], info["pin"]))
                tr[nm] = dict(log_cols=st.log_cols, summary={kk: vv for kk, vv in s.items() if kk != "zc"}, zc=s["zc"], cost=k, argmax=info)
            # run totals: chosen input (b) + output mode (i) / mode (ii) U8 keyed, against the stack
            for mode, key in (("mode (i)", "OUT mode(i) U8 keyed, public last row"), ("mode (ii)", "OUT mode(ii) U8 keyed, T_out=T"),
                              ("mode (ii) U16", "OUT mode(ii) U16 keyed, T_out=T")):
                a, b = tr["IN (b) indexed LogUp"], tr[key]
                el = a["summary"]["elems"] + b["summary"]["elems"]
                tot = {k2: a["cost"][k2] + b["cost"][k2] for k2 in ("total", "s0_5090", "s3_5090", "verify")}
                rb = a["summary"]["receipt"] + b["summary"]["receipt"]
                tr["total " + mode] = dict(elems=el, receipt=rb, **tot)
                print("   TOTAL token I/O %-13s elems %8.3fM (+%5.2f%% of stack) | cpu %6.2f s (+%5.2f%%) S0 %5.2f s (+%5.2f%%) S3 %5.2f s (+%5.2f%%) | verify +%5.2f s (+%5.1f%%) | receipt +%5.2f MB (+%4.1f%%)" % (
                    mode, el / 1e6, 100 * el / stk["elems"], tot["total"], 100 * tot["total"] / stk["cpu_s"], tot["s0_5090"], 100 * tot["s0_5090"] / stk["s0_5090"],
                    tot["s3_5090"], 100 * tot["s3_5090"] / stk["s3_5090"], tot["verify"], 100 * tot["verify"] / stk["verify_s"], rb / 1e6, 100 * rb / stk["receipt"]))
            mres["T"][T] = tr
        res["models"][m.name] = mres
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "token_io_count.json"), "w") as fh:
        json.dump(res, fh, indent=1, default=float)


if __name__ == "__main__":
    main()

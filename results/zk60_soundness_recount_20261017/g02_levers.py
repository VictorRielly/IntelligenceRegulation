#!/usr/bin/env python3
"""G.0-2 costed options: whole-run soundness targets for the private Llama-3-8B stack at T512.

[COUNTED] soundness arithmetic and committed-element / receipt counts; [MODEL] prover time from
the speed plan's cost model. Run with `python3 -B` (no bytecode next to the copies). One thread,
well under a second.

Inputs (read only, imported from verbatim copies in g02_speedplan_copy/, sha256 equal to
results/zk60_speed_plan_20261017/{layout,cost_model,projection}.py):
  * layout.py      exact counted-layout replica (checked against the Rust ladder by its author);
  * cost_model.py  per-block phase law, laptop CPU, fitted on the R4-4 TinyLlama T128 run;
  * projection.py  the 8B geometry class, the receipt-optimal row width, the 5090 platform bands.
The roofline model of the speed plan (projection.py main block, counted bytes per unit at a
fraction of 1.792 TB/s) is re-implemented below with the same constants.

Soundness terms follow results/zk60_soundness_recount_20261017/recount.py (the D15 correction):
column test (1 - delta/3)^Q with the ZK distance delta = 1 - (n + Q)/(n inv_rate); M at
RS(1024, 4096); PCS field terms; sumcheck terms; LogUp in two conventions (R14 4N/|F| and the
derived (N + 3*768)/|F|).
"""
import json
import math
import os
import sys
from fractions import Fraction

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "g02_speedplan_copy"))
import cost_model as cm  # noqa: E402
import projection as pj  # noqa: E402
from layout import (clog2, N_SLOTS, SC_IO_IN, SC_LZC, SC_DZC, SC_QZC, SC_KVZC, SC_SZC, SC_FZC,  # noqa: E402
                    SC_TAB, SC_ZS, MASK_VEC, MASK_PATH, WIRE_HEADER, INV_RATE)

P = 0xFFFF_FFFF_0000_0001
LOG2_P = math.log2(P)
L = 32
T = 512
TAB_DISTINCT = 3 * 256
SLOT_OF = {"L": SC_LZC, "D": SC_DZC, "Q": SC_QZC, "Kv": SC_KVZC, "S": SC_SZC, "F": SC_FZC, "Tab": SC_TAB}
LOOKUP_DOMS = ["L", "D", "Q", "Kv", "S", "F"]


def lg(x):
    return math.log2(x)


def lsum(ts):
    m = max(ts)
    return m + lg(sum(2.0 ** (t - m) for t in ts))


class Var(pj.Llama8B):
    """The 8B block at T, row width 2^lc, with soundness levers:
    Q      column checks = pads of A/H/B/E (ZkOpts::standard ties them);
    MQ     M's opened columns = pads per M a-row (zk.rs MASK_Q);
    rep    domains whose lookups get a second, independent (alpha, beta, gamma) in Fp2
           (second helper set in H, its own table helpers and zero-sum row);
    f4lk   LogUp challenges and helpers in Fp4 (= Fp2[v], helpers 4 limbs, terminal masks 4 rows);
    f4all  every challenge in Fp4 (sumchecks, PCS combinations, CFS masks), plus f4lk;
    prox   proximity vectors per opening (2 = repeated proximity test, one more mask row each);
    rate   inverse rate of A/H/B/E (4 today)."""

    def __init__(self, T_, lc, Q=256, MQ=256, rep=(), f4lk=False, f4all=False, prox=1, rate=4):
        self.Q, self.MQ, self.rep, self.prox, self.rate = Q, MQ, frozenset(rep), prox, rate
        self.f4lk, self.f4all = (f4lk or f4all), f4all
        pj.Llama8B.__init__(self, T_, lc)

    def hmul(self, dom):
        if dom in self.rep:
            return 2
        if dom in ("Tab",) and self.rep:
            return 2
        return 1

    def h_plane_doms(self):
        out = []
        for d in pj.Llama8B.h_plane_doms(self):
            out += [d] * self.hmul(d)
        return out

    def claim_sites(self):
        a, h = pj.Llama8B.claim_sites(self)
        for d, s in SLOT_OF.items():
            h[s] *= self.hmul(d)
        if self.rep:
            h[SC_ZS] *= 2
        return a, h

    def a_rows(self):
        a, _ = self.claim_sites()
        site = 4 if self.f4all else 2
        return sum(self.rows_of(d) for d in self.a_plane_doms()) + site * sum(a) + 2 + (self.prox - 1)

    def h_rows(self):
        _, h = self.claim_sites()
        limbs = 4 if self.f4lk else 2
        site = 4 if self.f4lk else 2
        return sum(limbs * self.rows_of(d) for d in self.h_plane_doms()) + site * sum(h) + 2 + (self.prox - 1)

    def zc_terms(self):
        """cost-equivalent zero-check terms: an Fp4 term is priced as two Fp2 terms (bandwidth)."""
        a, h = self.claim_sites()
        fa = 2 if self.f4all else 1
        fh = 2 if self.f4lk else 1
        return {dm: fa * a[s] + fh * h[s] for dm, s in (("D", SC_DZC), ("Q", SC_QZC), ("Kv", SC_KVZC), ("S", SC_SZC), ("F", SC_FZC))}

    def receipt_bytes(self):
        n, Q = self.n, self.Q
        vb = 32 if self.f4all else 16
        vec_len, path = n + Q, clog2(n * self.rate)

        def opening(groups, rows):
            return (groups + self.prox) * vec_len * vb + Q * (8 + rows * 8 + 32 + path * 32)
        sl = self.slots()
        a, h = self.claim_sites()
        terms = [a[s] + h[s] + int(s >= SC_IO_IN) for s in range(N_SLOTS)]
        slot_words = sum(1 + (sl[s][0] + sl[s][1]) * (sl[s][2] + 1) + terms[s] for s in range(N_SLOTS))
        m_rows = (2 * N_SLOTS + 4) * (2 if self.f4all else 1)
        mask = 2 * MASK_VEC * vb + self.MQ * (8 + m_rows * 8 + 32 + MASK_PATH * 32)
        return (WIRE_HEADER + 96 + slot_words * vb + mask + opening(self.a_groups(), self.a_rows())
                + opening(9, self.h_rows()) + 2 * opening(1, self.endpoint_rows + (self.prox - 1)))

    def lookups_by_dom(self):
        return {d: self.lookups_per_position(d) * self.size(d) for d in LOOKUP_DOMS}

    def max_mask_len(self):
        return max((m + e) * dg + 2 for m, e, dg in self.slots())


# ----------------------------------------------------------------------------- soundness
def soundness(v):
    n, nn, Q = v.n, v.n * v.rate, v.Q
    lf = 4 * LOG2_P if v.f4all else 2 * LOG2_P           # challenge field for sumchecks / PCS
    llk = 4 * LOG2_P if v.f4lk else 2 * LOG2_P           # LogUp field
    delta = 1 - Fraction(n + Q, nn)
    blk = Q * lg(float(1 - delta / 3))
    mterm = v.MQ * lg(0.75)
    n_ahbe = 3 * L + 1                                    # L A + L H + (L-1) B + 2 E
    col = lsum([blk + lg(n_ahbe), mterm + lg(L)])
    # PCS field terms: proximity combination (e+1)/|F| (squared with two proximity vectors),
    # lambda batching of the group claims (claims/|F|)
    e = (nn - (n + Q)) // 3
    e_m = (4096 - 1024) // 3
    a, h = v.claim_sites()
    claims = {"A": 2 * sum(a) + 2, "H": 2 * sum(h) + 2, "B": 6, "E": 4}
    prox_t = lambda ee: v.prox * (lg(ee + 1) - lf)  # noqa: E731
    per = {k: lsum([prox_t(e), lg(c) - lf]) for k, c in claims.items()}
    m_func = sum(mm + ee + 2 for mm, ee, _ in v.slots())
    per_m = lsum([prox_t(e_m), lg(m_func) - lf])
    pcs_field = lsum([per["A"] + lg(L), per["H"] + lg(L), per["B"] + lg(L - 1), per["E"] + 1, per_m + lg(L)])
    # sumchecks per block
    sl = v.slots()
    sc_units = sum((mm + ee) * dg + mm + (a[s] + h[s] + int(s >= SC_IO_IN)) + 2 for s, (mm, ee, dg) in enumerate(sl))
    sc_run = lg(sc_units) - lf + lg(L)
    # LogUp per block: single-alpha part and repeated part
    lk = v.lookups_by_dom()
    pairs = {"S": v.size("S"), "F": v.size("F")}       # exp pairs on S, act pairs on F
    n_single = sum(lk[d] for d in LOOKUP_DOMS if d not in v.rep) + sum(p for d, p in pairs.items() if d not in v.rep)
    n_rep = sum(lk[d] for d in v.rep if d in lk) + sum(p for d, p in pairs.items() if d in v.rep)
    terms_der, terms_r14 = [], []
    if n_single:
        terms_der.append(lg(n_single + 3 * TAB_DISTINCT) - llk)
        terms_r14.append(lg(4 * n_single) - llk)
    if n_rep:  # two independent (alpha, beta, gamma): both identities must fail
        terms_der.append(2 * (lg(n_rep + 3 * TAB_DISTINCT) - llk))
        terms_r14.append(2 * (lg(4 * n_rep) - llk))
    lu_der = lsum(terms_der) + lg(L)
    lu_r14 = lsum(terms_r14) + lg(L)
    rest = [col, pcs_field, sc_run]
    return dict(per_opening=blk, per_opening_M=mterm, column=col, pcs_field=pcs_field, sumcheck=sc_run,
                logup_derived=lu_der, logup_r14=lu_r14, n_single=n_single, n_rep=n_rep,
                whole_derived=lsum(rest + [lu_der]), whole_r14=lsum(rest + [lu_r14]))


# ----------------------------------------------------------------------------- cost
C_CPU = cm.coefficients("cpu")
BW = 1.792e12
BYTES = dict(commit=170.0, zc=72.0, inv=56.0, open=16.0, witness=8.0)
SEQ_S = 0.025


def cost(v, base=None):
    s = v.summary()
    elems = s["A_elems"] + s["H_elems"]
    ph = cm.block_phases(v, C_CPU)
    lk = v.lookups_by_dom()
    inv_mult_u8 = (sum(lk.values()) + sum(lk[d] for d in v.rep)) / sum(lk.values())
    pairs = v.size("S") + v.size("F")
    inv_mult_pair = (pairs + sum(v.size(d) for d in ("S", "F") if d in v.rep)) / pairs
    fi = 2.0 if v.f4lk else 1.0
    inv = fi * (C_CPU["inv_u8"] * s["u8"] * inv_mult_u8 + C_CPU["inv_pair"] * pairs * inv_mult_pair)
    ph["total"] += inv - ph["inverses"]
    ph["inverses"] = inv
    rate_f = v.rate / 4.0                                # encode/hash volume scales with the codeword
    ph["total"] += ph["commit"] * (rate_f - 1.0)
    ph["commit"] *= rate_f
    if v.prox == 2:                                      # one more row combination per opening
        extra = ph["openings"] / (v.a_groups() + 1)
        ph["openings"] += extra
        ph["total"] += extra
    # roofline whole-GPU prover on one 5090 (speed plan §5 constants)
    et = sum(s["sizes"][k] * s["terms"][k] for k in s["terms"])

    def roof(frac):
        bw = BW * frac
        t = dict(commit=BYTES["commit"] * rate_f * elems / bw, zc=BYTES["zc"] * et / bw,
                 inv=BYTES["inv"] * fi * s["u8"] * inv_mult_u8 / bw, open=BYTES["open"] * elems / bw,
                 witness=BYTES["witness"] * s["A_elems"] / bw, seq=SEQ_S)
        t["rest"] = 0.10 * t["zc"]
        t["total"] = sum(t.values())
        return t
    r25, r40 = roof(0.25), roof(0.40)
    # anchored central (speed plan step 4: whole prover on the GPU at the measured-ratio band)
    commit_a = pj.C_GPU_COMMIT_4070 * elems * rate_f / pj.BOARD[1] + pj.G0_4070 / 2
    ported = sum(ph[k] for k in pj.CPU_KEYS) / pj.GPU_PORT[1]
    anch = commit_a + ported + pj.GPU_WITNESS_S[1] * v.T / 512
    out = dict(elems=elems, a_rows=v.a_rows(), h_rows=v.h_rows(), receipt_block=v.receipt_bytes(),
               receipt_pass=L * v.receipt_bytes(), cpu_block_s=ph["total"], phases=ph,
               roof25_pps=v.T / (L * r25["total"]), roof40_pps=v.T / (L * r40["total"]), roof40=r40,
               anchored_pps=v.T / (L * anch),
               # achieved-bandwidth fraction every kernel needs for 50 positions/s (roofline, SEQ fixed)
               frac_for_50=(r40["total"] - SEQ_S) * 0.40 / (v.T / (L * 50.0) - SEQ_S))
    if base is not None:
        out["d_elems"] = elems / base["elems"] - 1
        out["d_receipt"] = out["receipt_pass"] / base["receipt_pass"] - 1
        out["d_cpu"] = out["cpu_block_s"] / base["cpu_block_s"] - 1
        out["d_roof40"] = out["roof40_pps"] / base["roof40_pps"] - 1
    return out


def min_q(make, target, key="whole_derived", qmax=600):
    """smallest Q (= MQ) at which the variant reaches the target whole-run bits."""
    for q in range(256, qmax):
        v = make(q)
        if -soundness(v)[key] >= target:
            return q, v
    return None, None


LC = pj.best_layout(T).log_cols


def V(**kw):
    return Var(T, LC, **kw)


ALL = ("L", "D", "Q", "Kv", "S", "F")


def main():
    out = {"row_width_log2": LC, "bundles": []}
    base_v = V()
    assert base_v.receipt_bytes() == pj.best_layout(T).receipt_bytes(), "the variant class must reproduce the counted receipt"
    assert base_v.a_rows() == pj.best_layout(T).a_rows() and base_v.h_rows() == pj.best_layout(T).h_rows()
    base = cost(base_v)
    sb = soundness(base_v)
    print("Llama-3-8B T%d, row width 2^%d, inv_rate 4, Q 256 (speed plan's receipt-optimal layout)" % (T, LC))
    print("  per opening A/H/B/E 2^%.2f, M 2^%.2f; lookups per block %d; max CFS mask length %d (M_Q ceiling %d)" % (
        sb["per_opening"], sb["per_opening_M"], sb["n_single"], base_v.max_mask_len(), 512 - base_v.max_mask_len()))
    print("  committed elements per block %.4f G (A %d rows, H %d rows; H share %.1f%%); receipt per pass %.3f GB" % (
        base["elems"] / 1e9, base["a_rows"], base["h_rows"], 100 * base["h_rows"] / (base["a_rows"] + base["h_rows"]), base["receipt_pass"] / 1e9))
    print("  laptop-CPU law %.2f s/block; 5090 roofline %.1f / %.1f pos/s at 25%% / 40%%; anchored central %.2f pos/s" % (
        base["cpu_block_s"], base["roof25_pps"], base["roof40_pps"], base["anchored_pps"]))
    print("  lookups by domain:", {d: n for d, n in base_v.lookups_by_dom().items()}, "exp pairs", base_v.size("S"), "act pairs", base_v.size("F"))

    nb = sb["n_single"]
    wr = dict(column=sb["per_opening"], M=sb["per_opening_M"], logup_derived=lg(nb + 3 * TAB_DISTINCT) - 2 * LOG2_P,
              logup_r14=lg(4 * nb) - 2 * LOG2_P)
    out["B0_worst_single_round"] = wr
    print("  worst single round (per-round / work-factor reading): column 2^%.2f, M 2^%.2f, one block's LogUp 2^%.2f (derived) / 2^%.2f (R14)" % (
        wr["column"], wr["M"], wr["logup_derived"], wr["logup_r14"]))

    bundles = [
        ("B0  today's design", dict()),
        ("L1  partial LogUp repetition on S, F", dict(rep=("S", "F"))),
        ("L2  partial LogUp repetition on S, F, D", dict(rep=("S", "F", "D"))),
        ("L3  full LogUp repetition (two independent alpha/beta/gamma in Fp2)", dict(rep=ALL)),
        ("L4  LogUp challenges and helpers in Fp4", dict(f4lk=True)),
        ("O1  Q = 262 (checks = pads), MQ 262", dict(Q=262, MQ=262)),
        ("O2  rate 1/8 at Q 256", dict(rate=8)),
        ("O3  two proximity vectors per opening", dict(prox=2)),
        ("A1  every challenge in Fp4", dict(f4all=True)),
    ]
    print("\n== single levers (each alone against B0) ==")
    hdr = "%-66s %8s %8s | %9s %9s %9s %9s | %7s %8s %8s %7s"
    print(hdr % ("lever", "R14", "derived", "column", "LogUp-der", "sumcheck", "PCS-fld", "d_elem", "d_rcpt", "d_cpu", "roof40"))
    for name, kw in bundles:
        v = V(**kw)
        s = soundness(v)
        c = cost(v, base)
        out["bundles"].append(dict(name=name, kw={k: (list(x) if isinstance(x, (tuple, frozenset)) else x) for k, x in kw.items()},
                                   soundness=s, cost={k: x for k, x in c.items() if k not in ("phases", "roof40")}))
        print("%-66s %8.2f %8.2f | %9.2f %9.2f %9.2f %9.2f | %+6.1f%% %+7.1f%% %+7.1f%% %7.1f" % (
            name, -s["whole_r14"], -s["whole_derived"], -s["column"], -s["logup_derived"], -s["sumcheck"], -s["pcs_field"],
            100 * c["d_elems"], 100 * c["d_receipt"], 100 * c["d_cpu"], c["roof40_pps"]))

    # ---- target bundles: the cheapest combination found for each target (derived LogUp bound
    # unless stated), searching the column-check count
    print("\n== target bundles (derived LogUp bound; R14 figure shown alongside) ==")
    targets = []
    # 96: partial repetition on S, F (no Q change) -- check; else S, F, D
    for rep in (("S", "F"), ("S", "F", "D")):
        v = V(rep=rep)
        if -soundness(v)["whole_derived"] >= 96:
            targets.append(("~96: derived bound + LogUp repetition on %s" % "+".join(rep), v))
            break
    targets.append(("~97: derived bound + LogUp repetition on S+F+D", V(rep=("S", "F", "D"))))
    targets.append(("~96 (R14 convention): full LogUp repetition", V(rep=ALL)))
    q100, v100 = min_q(lambda q: V(rep=ALL, Q=q, MQ=q), 100)
    targets.append(("~100: full LogUp repetition + Q = MQ = %d" % q100, v100))
    q100b, v100b = min_q(lambda q: V(f4lk=True, Q=q, MQ=q), 100)
    targets.append(("~100 alt: LogUp in Fp4 + Q = MQ = %d" % q100b, v100b))
    q110, v110 = min_q(lambda q: V(rep=ALL, prox=2, Q=q, MQ=q), 110)
    targets.append(("~110: full LogUp repetition + two proximity vectors + Q = MQ = %d" % (q110 or -1), v110))
    q110c, v110c = min_q(lambda q: V(rep=ALL, prox=2, rate=8, Q=q, MQ=max(q, 256)), 110)
    q128, v128 = min_q(lambda q: V(f4all=True, Q=q, MQ=q), 128)
    targets.append(("~128: every challenge in Fp4 + Q = MQ = %d" % (q128 or -1), v128))
    print(hdr % ("bundle", "R14", "derived", "column", "LogUp-der", "sumcheck", "PCS-fld", "d_elem", "d_rcpt", "d_cpu", "roof40"))
    out["targets"] = []
    for name, v in targets:
        if v is None:
            print("%-66s unreachable in the searched range" % name)
            continue
        s = soundness(v)
        c = cost(v, base)
        print("%-66s %8.2f %8.2f | %9.2f %9.2f %9.2f %9.2f | %+6.1f%% %+7.1f%% %+7.1f%% %7.1f" % (
            name, -s["whole_r14"], -s["whole_derived"], -s["column"], -s["logup_derived"], -s["sumcheck"], -s["pcs_field"],
            100 * c["d_elems"], 100 * c["d_receipt"], 100 * c["d_cpu"], c["roof40_pps"]))
        print("%-66s roof25 %.1f pos/s (B0 %.1f); anchored central %.2f (B0 %.2f); receipt/pass %.3f GB; M_Q ceiling %d; bandwidth for 50/s %.1f%% (B0 %.1f%%)" % (
            "", c["roof25_pps"], base["roof25_pps"], c["anchored_pps"], base["anchored_pps"], c["receipt_pass"] / 1e9, 512 - v.max_mask_len(),
            100 * c["frac_for_50"], 100 * base["frac_for_50"]))
        out["targets"].append(dict(name=name, Q=v.Q, MQ=v.MQ, rep=sorted(v.rep), f4lk=v.f4lk, f4all=v.f4all, prox=v.prox, rate=v.rate,
                                   soundness=s, cost={k: x for k, x in c.items() if k not in ("phases", "roof40")}))

    # ---- the opening-term levers compared at equal bits: what the column term gains per unit cost
    print("\n== opening term: three ways to gain the same bits ==")
    v_q = V(Q=273, MQ=273)
    gain_q = soundness(base_v)["column"] - soundness(v_q)["column"]
    print("  Q 256 -> 273 (checks = pads): column term +%.2f bits; receipt %+.2f%%; roofline unchanged (%.1f pos/s)" % (
        gain_q, 100 * (cost(v_q, base)["d_receipt"]), cost(v_q, base)["roof40_pps"]))
    batched = lsum([soundness(base_v)["per_opening"] + lg(4), soundness(base_v)["per_opening_M"]])
    print("  D14 cross-layer batching (A, H, B, E each one batched test; M one): column term 2^%.2f (+%.2f bits);"
          " needs every block's encoded matrix until the end (%.0f GB at 32 B per element) or a second encode pass" % (
              batched, soundness(base_v)["column"] - batched, L * base["elems"] * 32 / 1e9))
    c8 = cost(V(rate=8), base)
    print("  rate 1/8 at Q 256: column term +%.2f bits; commit volume x2: roofline %.1f pos/s at 40%% (B0 %.1f)" % (
        soundness(base_v)["column"] - soundness(V(rate=8))["column"], c8["roof40_pps"], base["roof40_pps"]))
    if q110c:
        print("  (110 via rate 1/8 instead of Q: Q = %d; roofline %.1f pos/s)" % (q110c, cost(v110c, base)["roof40_pps"]))

    # ---- sketch: D1 (LogUp-GKR in place of the committed H) with the fraction tree in Fp2 or Fp4.
    # ASSUMPTIONS [MODEL, not the cost model's]: H is not committed (A only), the zero-check slots
    # lose their helper terms, the helper inverses vanish, and the fraction tree costs K
    # element-terms per lookup leaf (num/den pairs over log N layers, ~2N entries x 2): K = 4 in
    # Fp2, priced as 8 in Fp4 (bandwidth). Privacy design open (speed plan D1).
    print("\n== sketch: D1 LogUp-GKR, fraction tree in Fp2 / Fp4 (roofline at 40%) ==")
    sd = base_v.summary()
    a_sites, _ = base_v.claim_sites()
    et_a = sum(sd["sizes"][k] * a_sites[sl] for k, sl in (("D", SC_DZC), ("Q", SC_QZC), ("Kv", SC_KVZC), ("S", SC_SZC), ("F", SC_FZC)))
    n_all = sum(base_v.lookups_by_dom().values()) + base_v.size("S") + base_v.size("F")
    out["d1_sketch"] = {}
    for kname, kk in (("Fp2 fraction tree, K = 2", 2), ("Fp2 fraction tree, K = 4", 4), ("Fp4 fraction tree, K = 2 (x2)", 4.0001), ("Fp4 fraction tree, K = 4 (x2)", 8)):
        bw = BW * 0.40
        t = dict(commit=BYTES["commit"] * sd["A_elems"] / bw, zc=BYTES["zc"] * (et_a + kk * n_all) / bw,
                 open=BYTES["open"] * sd["A_elems"] / bw, witness=BYTES["witness"] * sd["A_elems"] / bw, seq=SEQ_S)
        t["rest"] = 0.10 * t["zc"]
        tot = sum(t.values())
        lu = (lg(n_all + 3 * TAB_DISTINCT) - (2 if kname.startswith("Fp2") else 4) * LOG2_P) + lg(L)
        frac = (tot - SEQ_S) * 0.40 / (T / (L * 50.0) - SEQ_S)
        out["d1_sketch"][kname] = dict(pps40=T / (L * tot), logup_derived=lu, frac_for_50=frac, elems=sd["A_elems"])
        print("  %s: committed %.3f G (%.1f%%), roofline %.1f pos/s, bandwidth for 50/s %.1f%%, LogUp term 2^%.2f (derived)" % (
            kname, sd["A_elems"] / 1e9, 100 * (sd["A_elems"] / base["elems"] - 1), T / (L * tot), 100 * frac, lu))

    with open(os.path.join(HERE, "g02_levers.json"), "w") as fh:
        json.dump(out, fh, indent=1, default=float)


if __name__ == "__main__":
    main()

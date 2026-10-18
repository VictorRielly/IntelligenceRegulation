"""GPT nonlinear-ZKP conversation review: exactness checks and counted layout variants.

Read-only arithmetic, one thread, pure Python, a few seconds. Run as
    python3 -I -B results/zk60_gpt_nonlinear_review_20261018/variants.py
(-B: the speed plan's modules are imported read-only and must not get a __pycache__).

Part A  [COUNTED] exactness of the "shared row reciprocal" rewrite of our softmax quotient.
Part B  [MODEL, synthetic] how often "normalise after PV" changes o8, and its error vs float.
Part C  [COUNTED layouts / MODEL rates] the candidate layouts at Llama-3-8B T512, using the
        speed plan's exact layout replica and cost law (results/zk60_speed_plan_20261017/).

Our current relation (argument.rs:1834-1836, SC_SZC):
    c2: mask*E*2^F_P - p*Sum - sr = 0      c3: sg + sr + 1 - Sum = 0      sr, sg < 2^wrho_s (limbs)
i.e. p = floor(E * 2^F_P / Sum), with two wrho_s-bit range checks per score entry.
Candidate (per row h,t): Z committed, Z*Sum = 2^(B+F_P) + zr with zr in [0, 2^wrho_s) (ONE check);
per entry: mask*E*Z = p*2^B + r with r in [0, 2^B) (ONE check, byte-aligned B -> no top pin).
"""
import json
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SP = os.path.join(os.path.dirname(HERE), "zk60_speed_plan_20261017")
sys.path.insert(0, SP)
import projection as P  # noqa: E402  (read-only import; run with -B)
import cost_model as cm  # noqa: E402

Q_GOLDILOCKS = (1 << 64) - (1 << 32) + 1
OUT = {}


def clog2(v):
    return (v - 1).bit_length()


# ------------------------------------------------------------------------------------------
# Part A: exactness of the shared reciprocal
# ------------------------------------------------------------------------------------------
def lhs_quotient(E, S, zr, B, fp):
    """the ONLY p the integer relation E*(X+zr) = S*(p*2^B + r), 0 <= r < 2^B admits
    (when S divides E*(X+zr)); taking the floor is a superset check (covers every zr)."""
    X = 1 << (B + fp)
    return (E * (X + zr)) // (S * (1 << B))


def exhaustive_small():
    rows = []
    for fe in (3, 4, 5):
        for T in (4, 8, 16):
            for fp in (3, 9):
                w = clog2(T) + fe
                bmin = fe + w
                for B in (bmin - 2, bmin - 1, bmin, ((bmin + 7) // 8) * 8):
                    bad = 0
                    checked = 0
                    zmax = (1 << w) - 1  # one-sided window; LHS is non-decreasing in zr, so zr_max is the worst case
                    for S in range(1 << fe, T * (1 << fe) + 1):
                        for E in range(0, (1 << fe) + 1):
                            honest = (E << fp) // S
                            checked += 1
                            if lhs_quotient(E, S, zmax, B, fp) != honest:
                                bad += 1
                            # completeness: honest ceil reciprocal sits inside the window
                            if B >= bmin and E == (1 << fe):
                                X = 1 << (B + fp)
                                Z = -(-X // S)
                                zr = Z * S - X
                                assert 0 <= zr < S <= (1 << w), (fe, T, fp, B, S)
                                assert (E * Z) >> B == honest
                    rows.append(dict(fE=fe, T=T, F_P=fp, wrho_s=w, B=B, B_min=bmin, checked=checked, mismatches=bad))
    return rows


def sampled_8b(seed=2026101803, n_random=200_000):
    fe, T, fp = 9, 512, 9
    w = clog2(T) + fe  # 18
    res = {}
    rng = random.Random(seed)
    for B in (26, 27, 32):
        zmax = (1 << w) - 1
        bad = 0
        n = 0
        # adversarial: every Sum for the largest E, and a sweep of E on Sums near powers of two
        for S in range(1 << fe, (T << fe) + 1, 1 if B != 32 else 1):
            E = 1 << fe
            n += 1
            if lhs_quotient(E, S, zmax, B, fp) != (E << fp) // S:
                bad += 1
        for S in [(1 << k) + d for k in range(fe, w + 1) for d in (-3, -1, 0, 1, 3)] + [T << fe]:
            if S < (1 << fe) or S > (T << fe):
                continue
            for E in range(0, (1 << fe) + 1):
                n += 1
                if lhs_quotient(E, S, zmax, B, fp) != (E << fp) // S:
                    bad += 1
        for _ in range(n_random):
            S = rng.randint(1 << fe, T << fe)
            E = rng.randint(0, 1 << fe)
            n += 1
            if lhs_quotient(E, S, zmax, B, fp) != (E << fp) // S:
                bad += 1
        res[B] = dict(checked=n, mismatches=bad)
    # no-wrap margins at B = 32 (all bounds over the integers, before reduction mod q)
    B = 32
    lhs_max = (1 << fe) * ((1 << (B + fp)) + (1 << w))
    rhs_max = (T << fe) * (((1 << (fp + 1)) - 1) * (1 << B) + (1 << B) - 1)
    res["no_wrap_B32"] = dict(lhs_bits=math.log2(lhs_max), rhs_bits=math.log2(rhs_max), q_bits=math.log2(Q_GOLDILOCKS),
                              ok=max(lhs_max, rhs_max) < Q_GOLDILOCKS)
    return res


# ------------------------------------------------------------------------------------------
# Part B: "normalise after PV" vs today's two roundings (synthetic, indicative only)
# ------------------------------------------------------------------------------------------
def fused_normalisation_sim(seed=7, rows=24, T=512, dv=48, fe=9, fp=9, sh_o=9, scale=1 / 8):
    """Today: p_j = floor(E_j 2^fp / Sum); o = round(sum_j p_j v_j / 2^sh_o).
    Fused: o' = round(sum_j E_j v_j * 2^(fp - sh_o) / Sum). Reference: float softmax(scores) @ v.
    Exp table is a SYNTHETIC stand-in E[d] = round(2^fe exp(-d*scale)); real tables are calibrated."""
    rng = random.Random(seed)
    table = [round((1 << fe) * math.exp(-d * scale)) for d in range(256)]
    diff = 0
    tot = 0
    err_today = 0.0
    err_fused = 0.0
    maxdiff = 0
    for _ in range(rows):
        s = [rng.randint(-127, 127) for _ in range(T)]
        m = max(s)
        E = [table[min(255, m - x)] for x in s]
        Sum = sum(E)
        p = [(e << fp) // Sum for e in E]
        wf = [math.exp(-(m - x) * scale) for x in s]
        wsum = sum(wf)
        for _c in range(dv):
            v = [rng.randint(-127, 127) for _ in range(T)]
            acc = sum(pi * vi for pi, vi in zip(p, v))
            o_today = (acc + (1 << (sh_o - 1))) >> sh_o
            num = sum(e * vi for e, vi in zip(E, v)) << (fp - sh_o) if fp >= sh_o else sum(e * vi for e, vi in zip(E, v))
            o_fused = (2 * num + Sum) // (2 * Sum)
            ref = sum(wi * vi for wi, vi in zip(wf, v)) / wsum * (1 << (fp - sh_o))
            tot += 1
            if o_today != o_fused:
                diff += 1
                maxdiff = max(maxdiff, abs(o_today - o_fused))
            err_today += abs(o_today - ref)
            err_fused += abs(o_fused - ref)
    return dict(outputs=tot, differ=diff, differ_pct=100.0 * diff / tot, max_abs_diff=maxdiff,
                mean_abs_err_vs_float_today=err_today / tot, mean_abs_err_vs_float_fused=err_fused / tot,
                note="synthetic scores/values/exp table; indicative only, not a calibration result")


# ------------------------------------------------------------------------------------------
# Part C: counted layout variants at Llama-3-8B
# ------------------------------------------------------------------------------------------
EXTERNAL_VPE_SITES = dict(SC_SS=1, SC_SSM=1, SC_IO_IN=1, SC_IO_OUT=1, SC_DMM=1)  # + SC_PV when P is dropped


class Variant(P.Llama8B):
    """flags: vpe (value planes with full byte limbs not committed), exr (exact shared reciprocal, B=32),
    fn (normalise after PV), plus the plan's triangle (L7) and zkattn (L8) sketches."""

    def __init__(self, T, log_cols, vpe=False, exr=False, fn=False, em_plane=True, **kw):
        self.vpe, self.exr, self.fn, self.em_plane = vpe, exr, fn, em_plane
        assert not (fn and kw.get("zkattn")) and not (exr and (fn or kw.get("zkattn")))
        P.Llama8B.__init__(self, T, log_cols, **kw)

    # --- A planes ---------------------------------------------------------------------------
    def s_planes(self):
        if self.zkattn:
            return 3
        if self.fn:
            return 4 + int(self.em_plane)  # s8, its remainder limb, zsel, E (+ masked E for PV)
        p_plane = 0 if self.vpe else 1
        if self.exr:
            return 4 + p_plane + self.lp + 4  # s8, rsl, zsel, E, (p), p limbs, r limbs (B = 32)
        return 4 + p_plane + self.lp + 2 * self.ls

    def q_planes(self):
        if self.fn:
            lr = (self.wrho_s + 1 + 7) // 8
            return 7 - 2 + 2 * lr  # RO0/RO1 -> two-sided remainder of the division by 2*Sum
        return 7

    def a_plane_doms(self):
        ln = self.ln
        d_planes = 4 + 2 * ln + 8 + 2 * ln + 7 - (5 if self.vpe else 0)
        f_planes = 11 - (2 if self.vpe else 0)
        v = ["T"] * 4 + ["Ht"] * (2 + (4 if self.exr else 0)) + ["L"] * 2 + ["D"] * d_planes + ["Q"] * self.q_planes()
        v += ["Kv"] * 6 + ["S"] * self.s_planes() + ["F"] * f_planes + ["Tab"] * 3
        return v

    # --- lookups ----------------------------------------------------------------------------
    def lookups_per_position(self, dom):
        if dom == "S":
            if self.zkattn or self.fn:
                return 4
            if self.exr:
                return 2 + 2 + (self.lp + 1) + 4
        if dom == "Q" and self.fn:
            bits = self.wrho_s + 1
            lr = (bits + 7) // 8
            per = lr + (0 if bits == 8 * lr else 1)
            return 13 - 3 + 2 * per
        if dom == "Ht" and self.exr:
            lz = (self.wrho_s + 7) // 8
            return lz + (0 if self.wrho_s == 8 * lz else 1)
        return P.Llama8B.lookups_per_position(self, dom)

    def log(self, dom):
        if dom == "Ht" and self.exr:  # Ht now carries H planes -> P-3 lift to the row width
            nat = self.natural_log("Ht")
            return self.log_cols if nat < self.log_cols else nat
        return P.Llama8B.log(self, dom)

    def h_plane_doms(self):
        v = P.Llama8B.h_plane_doms(self)
        if self.exr:
            v = v + ["Ht"] * self.helpers("Ht")
        return v

    def u8_lookups(self):
        doms = ["L", "D", "Q", "Kv", "S", "F"] + (["Ht"] if self.exr else [])
        return sum(self.lookups_per_position(d) * self.size(d) for d in doms)

    # --- claim sites (the plan's zero-check "terms") ----------------------------------------
    def claim_sites(self):
        a, h = P.Llama8B.claim_sites(self)
        (SC_SS, SC_SSM, _TZC, _LZC, _RS, _QMM, _KMM, _VMM, _SCORE, SC_PV, _WO, _GMM, _UMM, SC_DMM,
         _DZC, SC_QZC, _KVZC, SC_SZC, _FZC, _TAB, _ZS, SC_IO_IN, SC_IO_OUT) = range(23)
        if self.vpe:
            for s in (SC_SS, SC_SSM, SC_IO_IN, SC_IO_OUT, SC_DMM):
                a[s] += 1
            if not (self.zkattn or self.fn):
                a[SC_PV] += 1
        if self.exr:
            a[SC_SZC] += 1  # Z read on the leading (h, t) coordinates, like A_SUM
        if self.fn:
            a[SC_QZC] += 1  # Sum read on the (t, h) coordinates of the Q cube
        return a, h

    def zc_terms(self):
        t = P.Llama8B.zc_terms(self)
        if self.exr:
            t["Ht"] = 4 + self.helpers("Ht")  # a small new Ht zero-check: Z, zr limbs, helpers
        return t

    def summary(self):
        s = P.Llama8B.summary(self)
        s["sizes"]["Ht"] = self.size("Ht")
        return s


BW = 1.792e12
BYTES = dict(commit=170.0, zc=72.0, inv=56.0, open=16.0, witness=8.0)  # copied from projection.py:246-250
SEQ_S = 0.025


def roofline_block(sh, frac):
    s = sh.summary()
    bw = BW * frac
    elems = s["A_elems"] + s["H_elems"]
    et = sum(s["sizes"][k] * s["terms"][k] for k in s["terms"])
    t = dict(commit=BYTES["commit"] * elems / bw, zc=BYTES["zc"] * et / bw, inv=BYTES["inv"] * s["u8"] / bw,
             open=BYTES["open"] * elems / bw, witness=BYTES["witness"] * s["A_elems"] / bw, seq=SEQ_S)
    t["rest"] = 0.10 * t["zc"]
    t["total"] = sum(t.values())
    return t


def best(T, **kw):
    bestv = None
    for lc in range(clog2(T) + 1, clog2(T) + 11):
        try:
            sh = Variant(T, lc, **kw)
        except AssertionError:
            continue
        rb = sh.receipt_bytes()
        if bestv is None or rb < bestv[0]:
            bestv = (rb, sh)
    return bestv[1]


VARIANTS = [
    ("today", {}),
    ("VPE value planes from limbs", dict(vpe=True)),
    ("EXR exact shared reciprocal", dict(exr=True)),
    ("FN normalise after PV [ruling]", dict(fn=True)),
    ("EXR + VPE", dict(exr=True, vpe=True)),
    ("FN + VPE [ruling]", dict(fn=True, vpe=True)),
    ("L7 triangle (plan)", dict(triangle=True)),
    ("L7 + EXR", dict(triangle=True, exr=True)),
    ("L7 + EXR + VPE", dict(triangle=True, exr=True, vpe=True)),
    ("L7 + FN [ruling]", dict(triangle=True, fn=True)),
    ("L7 + FN + VPE [ruling]", dict(triangle=True, fn=True, vpe=True)),
    ("L7 + L8 zkAttn (plan) [ruling]", dict(triangle=True, zkattn=True)),
    ("L7 + L8 + VPE [ruling]", dict(triangle=True, zkattn=True, vpe=True)),
]


def variant_table(T=512):
    rows = []
    base = None
    for name, kw in VARIANTS:
        sh = best(T, **kw)
        s = sh.summary()
        elems = s["A_elems"] + s["H_elems"]
        et = sum(s["sizes"][k] * s["terms"][k] for k in s["terms"])
        lookups_all = s["u8"] + s["exp_pairs"] + s["act_pairs"]
        ph = cm.block_phases(sh, P.C_CPU)
        cpu = ph["total"] + (P.C_CPU["zc"]["S"] * s["sizes"]["Ht"] * s["terms"].get("Ht", 0) if "Ht" in s["terms"] else 0.0)
        anch = []
        for band in (0, 1, 2):
            blk, wit, _ = P.block_time(sh, "5090", band, ported=tuple(P.CPU_KEYS), witness_gpu=True)
            anch.append(T / (P.L * (blk + wit)))
        roof = [T / (P.L * roofline_block(sh, f)["total"]) for f in (0.25, 0.40)]
        r = dict(name=name, frac_for_50=frac_for_rate(sh, 50.0, T), log_cols=sh.log_cols, A_rows=s["A_rows"], H_rows=s["H_rows"], elems=elems,
                 elems_per_token=elems / T, H_share=s["H_rows"] / (s["A_rows"] + s["H_rows"]),
                 u8=s["u8"], lookups_all=lookups_all, elem_terms=et, terms=dict(s["terms"]),
                 s_planes=sh.a_planes_on("S"), s_lookups=sh.lookups_per_position("S"),
                 cpu_proof_s=cpu, anchored_5090_whole_gpu=anch, roofline_25_40=roof, receipt_MB=s["receipt"] / 1e6)
        if base is None:
            base = r
        r["d_elems_pct"] = 100.0 * (elems / base["elems"] - 1)
        r["d_u8_pct"] = 100.0 * (s["u8"] / base["u8"] - 1)
        r["d_terms_pct"] = 100.0 * (et / base["elem_terms"] - 1)
        r["d_cpu_pct"] = 100.0 * (cpu / base["cpu_proof_s"] - 1)
        r["lookup_bits_gain"] = math.log2(base["lookups_all"] / lookups_all)
        rows.append(r)
    return rows


def exr_admissible():
    """B must satisfy 2^B >= max(E) * max(Sum) (exactness) and both sides of the integer identity
    E*(X+zr) = Sum*(p*2^B + r) must stay below q (no wrap): fE+B+F_P+1 and wrho_s+F_P+1+B < 64."""
    out = []
    for T in (32, 128, 512, 1024, 4096):
        for fe in (9, 10, 12, 16):
            for fp in (9, 12):
                w = clog2(T) + fe
                if w > 24:
                    continue
                bmin = fe + w
                ok = [B for B in range(bmin, 64) if (fe + B + fp + 1) < 64 and (w + fp + 1 + B) < 64]
                out.append(dict(T=T, fE=fe, F_P=fp, wrho_s=w, B_min=bmin, B_max=max(ok) if ok else None,
                                byte_aligned_B=next((B for B in ok if B % 8 == 0), None)))
    return out


def frac_for_rate(sh, target=50.0, T=512):
    """achieved-bandwidth fraction at which the roofline block time gives `target` positions/s"""
    t1 = roofline_block(sh, 1.0)
    a = t1["total"] - SEQ_S  # everything but the fixed host term scales as 1/frac
    budget = T / (P.L * target) - SEQ_S
    return a / budget


def per_entry_census():
    """the per-score-entry and per-Q-entry counts the review quotes (8B T512)"""
    out = {}
    for name, kw in (("today", {}), ("EXR", dict(exr=True)), ("FN", dict(fn=True)), ("FN_trilinear_PV", dict(fn=True, em_plane=False)),
                     ("L8_sketch", dict(zkattn=True)), ("VPE", dict(vpe=True))):
        sh = Variant(512, 15, **kw)
        per = {}
        for d in ("D", "Q", "S", "F"):
            a = sh.a_planes_on(d)
            lk = sh.lookups_per_position(d)
            hp = sh.helpers(d) + (1 if d in ("S", "F") else 0)
            per[d] = dict(A=a, lookups=lk, H_fp2=hp, committed_base=a + 2 * hp, terms=sh.zc_terms()[d])
        out[name] = per
    return out


if __name__ == "__main__":
    small = exhaustive_small()
    agg = {}
    for r in small:
        key = "B<B_min" if r["B"] < r["B_min"] else "B>=B_min"
        agg.setdefault(key, [0, 0, 0])
        agg[key][0] += r["checked"]
        agg[key][1] += r["mismatches"]
        agg[key][2] += int(r["mismatches"] > 0)
    print("== A. shared reciprocal exactness, exhaustive small geometries (fE 3..5, T 4..16, F_P 3/9) ==")
    print("   B >= fE + wrho_s : %d (E, Sum) cases, %d mismatches" % (agg["B>=B_min"][0], agg["B>=B_min"][1]))
    print("   B <  fE + wrho_s : %d cases, %d mismatches, in %d of %d configs" % (
        agg["B<B_min"][0], agg["B<B_min"][1], agg["B<B_min"][2], sum(1 for r in small if r["B"] < r["B_min"])))
    s8 = sampled_8b()
    print("== A. 8B T512 geometry (fE 9, wrho_s 18, F_P 9), zr at the window top ==")
    for B in (26, 27, 32):
        print("   B=%d: %d cases, %d mismatches" % (B, s8[B]["checked"], s8[B]["mismatches"]))
    nw = s8["no_wrap_B32"]
    print("   no wrap at B=32: max LHS 2^%.2f, max RHS 2^%.2f < q 2^%.2f: %s" % (nw["lhs_bits"], nw["rhs_bits"], nw["q_bits"], nw["ok"]))
    OUT["A_exhaustive_small"] = small
    OUT["A_sampled_8b"] = {str(k): v for k, v in s8.items()}

    fnres = fused_normalisation_sim()
    print("== B. normalise-after-PV vs today, synthetic (%d outputs) ==" % fnres["outputs"])
    print("   o8 differs in %.2f%% (max |diff| %d); mean |err| vs float: today %.4f, fused %.4f" % (
        fnres["differ_pct"], fnres["max_abs_diff"], fnres["mean_abs_err_vs_float_today"], fnres["mean_abs_err_vs_float_fused"]))
    OUT["B_fused_sim"] = fnres

    census = per_entry_census()
    OUT["C_per_entry"] = census
    print("== C. per-entry census, 8B T512 (A planes, U8 lookups, Fp2 helpers, committed base elements, zero-check terms) ==")
    for name, per in census.items():
        print("   %-16s " % name + "  ".join("%s: A%d lk%d H%d c%d t%d" % (d, v["A"], v["lookups"], v["H_fp2"], v["committed_base"], v["terms"]) for d, v in per.items()))

    rows = variant_table(512)
    OUT["C_variants_T512"] = rows
    print("== C. layout variants, Llama-3-8B T512, per block (receipt-optimal row width) ==")
    print("%-32s %4s %9s %7s %6s %8s %7s %8s %7s %6s %18s %12s" % (
        "variant", "n", "elems(M)", "d%", "H%", "u8(M)", "d%", "eterm(M)", "d%", "+bits", "anchored l/c/h", "roof 25/40"))
    for r in rows:
        print("%-32s 2^%-2d %9.1f %+7.1f %6.1f %8.1f %+7.1f %8.1f %+7.1f %6.2f %5.2f/%5.2f/%5.2f %5.1f/%5.1f" % (
            r["name"], r["log_cols"], r["elems"] / 1e6, r["d_elems_pct"], 100 * r["H_share"], r["u8"] / 1e6, r["d_u8_pct"],
            r["elem_terms"] / 1e6, r["d_terms_pct"], r["lookup_bits_gain"], *r["anchored_5090_whole_gpu"], *r["roofline_25_40"]))
    print("   bandwidth fraction of a 5090 needed for 50 positions/s (roofline): " + ", ".join(
        "%s %.0f%%" % (r["name"].split(" [")[0], 100 * r["frac_for_50"]) for r in rows))
    adm = exr_admissible()
    OUT["A_exr_admissible"] = adm
    print("== A. EXR admissible B (exact and wrap-free) ==")
    for a in adm:
        if a["B_max"] is None:
            print("   T%-5d fE %-2d F_P %-2d wrho_s %-2d: NOT admissible (exactness needs B >= %d, which wraps mod q)" % (
                a["T"], a["fE"], a["F_P"], a["wrho_s"], a["B_min"]))
        else:
            print("   T%-5d fE %-2d F_P %-2d wrho_s %-2d: B in [%d, %d], byte-aligned %s" % (
                a["T"], a["fE"], a["F_P"], a["wrho_s"], a["B_min"], a["B_max"], a["byte_aligned_B"]))
    print("   laptop-CPU-law proof per block (s): " + ", ".join("%s %.1f (%+.1f%%)" % (r["name"].split(" [")[0], r["cpu_proof_s"], r["d_cpu_pct"]) for r in rows))
    with open(os.path.join(HERE, "variants.json"), "w") as fh:
        json.dump(OUT, fh, indent=1, default=float)
    print("wrote variants.json")

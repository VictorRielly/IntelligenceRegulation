"""ROUND 2 (shares 2-4): the per-row division dictionary (DD) and an implied-range item, counted.

Read-only arithmetic, one thread, pure Python, ~1-2 s. Run as
    python3 -I -B results/zk60_gpt_nonlinear_review_20261018/variants_r2.py
Reuses round 1's variants.py (unchanged) and, through it, the speed plan's layout replica.

DD (share3's "observed-pair dictionary", made privacy-safe by a PUBLIC capacity):
  p = floor(mask*E*2^F_P / Sum) depends on the score entry only through E, and E takes at most
  n_E values = the number of distinct outputs of the PUBLIC exp table (19 at the 8B calibration).
  So per attention row (h, t) a dictionary of `cap` slots (one per distinct table value e, padded)
  holds (row, e, p_row(e)), each slot proved ONCE with today's exact division relation; every score
  entry then proves (row, mask*E, P) in that dictionary with ONE tuple lookup, instead of carrying
  P's limbs and the sigma/rho limbs. Bit-exact: the per-entry p is unchanged.
IOR: at 8B sh_o = F_P = 9, and sum_j p_j <= 2^F_P with |v| <= 127, so |o8| <= 127 is implied and
  o8's two `sym` lookups can be dropped (needs the security owner's agreement).
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import variants as V  # noqa: E402  (round 1, unchanged)

P = V.P
cm = V.cm
clog2 = V.clog2


def exp_table(e_s, head_dim, f_e):
    """tables_attn.rs:96-104 (exp_table_generate), round_half_up as floor(x + 0.5) for x >= 0"""
    lam = (2.0 ** e_s) / math.sqrt(head_dim)
    s = 2.0 ** f_e
    return [math.floor(s * math.exp(-d * lam) + 0.5) for d in range(256)]


def n_e_census():
    rows = []
    for hd in (64, 128):
        for fe in (9, 12):
            for es in range(-1, 5):
                t = exp_table(es, hd, fe)
                rows.append(dict(head_dim=hd, f_e=fe, e_s=es, distinct=len(set(t)), nonzero=sum(1 for e in t if e > 0)))
    return rows


class V2(V.Variant):
    def __init__(self, T, log_cols, dd=False, dd_form="today", cap=32, ior=False, **kw):
        self.dd, self.dd_form, self.cap, self.ior = dd, dd_form, cap, ior
        assert not (dd and (kw.get("fn") or kw.get("exr") or kw.get("zkattn")))
        V.Variant.__init__(self, T, log_cols, **kw)

    # --- domains -------------------------------------------------------------------------------
    def natural_log(self, dom):
        if dom == "DD":
            return clog2(self.h_pad * self.t_pad * self.cap)
        return V.Variant.natural_log(self, dom)

    def true_size(self, dom):
        if dom == "DD":
            return self.h * self.T * self.cap
        return V.Variant.true_size(self, dom)

    def log(self, dom):
        if dom == "DD":
            nat = self.natural_log("DD")
            return self.log_cols if nat < self.log_cols else nat
        return V.Variant.log(self, dom)

    def dd_a_planes(self):
        if self.dd_form == "today":  # P_dict, p limbs, sigma limbs, rho limbs, multiplicity
            return 1 + self.lp + 2 * self.ls + 1
        return 1 + self.lp + 4 + 1  # EXR form on the dictionary (B = 32): P_dict, p limbs, r limbs, multiplicity

    def s_planes(self):
        if self.dd:
            return 5  # s8, its remainder limb, zsel, E, P (P stays: PV reads it)
        return V.Variant.s_planes(self)

    def a_plane_doms(self):
        v = V.Variant.a_plane_doms(self)
        if self.dd:
            v = v + ["DD"] * self.dd_a_planes()
            if self.dd_form == "exr":
                v = v + ["Ht"] * 4
        return v

    def lookups_per_position(self, dom):
        if dom == "S" and self.dd:
            return 4  # sym(s8) 2 + remainder limb 2; the tuple lookup has its own helper (below)
        if dom == "DD":
            if self.dd_form == "today":
                return (self.lp + 1) + 2 * (self.ls + 1)
            return (self.lp + 1) + 4
        if dom == "Ht" and self.dd and self.dd_form == "exr":
            lz = (self.wrho_s + 7) // 8
            return lz + (0 if self.wrho_s == 8 * lz else 1)
        if dom == "Q" and self.ior:
            return V.Variant.lookups_per_position(self, "Q") - 2
        return V.Variant.lookups_per_position(self, dom)

    def h_plane_doms(self):
        v = V.Variant.h_plane_doms(self)
        if self.dd:
            v = v + ["S"]  # the tuple-lookup helper
            v = v + ["DD"] * (self.helpers("DD") + 1)  # U8 helpers + the dictionary (table) helper
            if self.dd_form == "exr":
                v = v + ["Ht"] * self.helpers("Ht")
        return v

    def u8_lookups(self):
        doms = ["L", "D", "Q", "Kv", "S", "F"] + (["Ht"] if (self.exr or (self.dd and self.dd_form == "exr")) else []) + (["DD"] if self.dd else [])
        return sum(self.lookups_per_position(d) * self.size(d) for d in doms)

    def claim_sites(self):
        a, h = V.Variant.claim_sites(self)
        SC_PV, SC_SZC = 9, 17
        if self.dd:
            h[SC_SZC] += 1  # tuple helper read in slot 17
            if self.vpe:
                a[SC_PV] -= 1  # round 1 added a PV site for dropping P; under DD P is kept
        return a, h

    def zc_terms(self):
        t = V.Variant.zc_terms(self)
        if self.dd:
            t["DD"] = self.a_planes_on("DD") + 1 + self.helpers("DD") + 1  # + Sum (or Z) read; + table helper
            if self.dd_form == "exr":
                t["Ht"] = 4 + self.helpers("Ht")
        return t

    def summary(self):
        s = V.Variant.summary(self)
        if self.dd:
            s["sizes"]["DD"] = self.size("DD")
            s["dd_tuple_queries"] = self.size("S")
        return s


def best2(T, **kw):
    bestv = None
    for lc in range(clog2(T) + 1, clog2(T) + 11):
        try:
            sh = V2(T, lc, **kw)
        except AssertionError:
            continue
        rb = sh.receipt_bytes()
        if bestv is None or rb < bestv[0]:
            bestv = (rb, sh)
    return bestv[1]


VARIANTS2 = [
    ("today", {}),
    ("EXR (round 1)", dict(exr=True)),
    ("FN (round 1) [ruling]", dict(fn=True)),
    ("DD, today's division on the dictionary", dict(dd=True)),
    ("DD, EXR form on the dictionary", dict(dd=True, dd_form="exr")),
    ("IOR implied o8 range", dict(ior=True)),
    ("VPE (round 1)", dict(vpe=True)),
    ("DD + VPE + IOR", dict(dd=True, vpe=True, ior=True)),
    ("FN + VPE [ruling]", dict(fn=True, vpe=True)),
    ("L7 (plan)", dict(triangle=True)),
    ("L7 + DD", dict(triangle=True, dd=True)),
    ("L7 + DD + VPE + IOR", dict(triangle=True, dd=True, vpe=True, ior=True)),
    ("L7 + FN + VPE [ruling]", dict(triangle=True, fn=True, vpe=True)),
    ("L7 + L8 (plan) [ruling]", dict(triangle=True, zkattn=True)),
    ("L7 + L8 + VPE [ruling]", dict(triangle=True, zkattn=True, vpe=True)),
]


def table(T):
    rows = []
    base = None
    for name, kw in VARIANTS2:
        sh = best2(T, **kw)
        s = sh.summary()
        elems = s["A_elems"] + s["H_elems"]
        et = sum(s["sizes"][k] * s["terms"][k] for k in s["terms"])
        lookups_all = s["u8"] + s["exp_pairs"] + s["act_pairs"] + s.get("dd_tuple_queries", 0)
        ph = cm.block_phases(sh, P.C_CPU)
        extra = sum(P.C_CPU["zc"]["S"] * s["sizes"][k] * s["terms"][k] for k in ("Ht", "DD") if k in s["terms"] and k in s["sizes"])
        cpu = ph["total"] + extra
        roof = [T / (P.L * V.roofline_block(sh, f)["total"]) for f in (0.25, 0.40)]
        r = dict(name=name, log_cols=sh.log_cols, elems=elems, H_share=s["H_rows"] / (s["A_rows"] + s["H_rows"]), u8=s["u8"],
                 lookups_all=lookups_all, elem_terms=et, cpu=cpu, roof=roof, frac50=V.frac_for_rate(sh, 50.0, T),
                 s_entry=None)
        if base is None:
            base = r
        r["d_elems"] = 100.0 * (elems / base["elems"] - 1)
        r["d_u8"] = 100.0 * (s["u8"] / base["u8"] - 1)
        r["d_terms"] = 100.0 * (et / base["elem_terms"] - 1)
        r["d_cpu"] = 100.0 * (cpu / base["cpu"] - 1)
        r["bits"] = math.log2(base["lookups_all"] / lookups_all)
        rows.append(r)
    return rows


def census_dd():
    sh = V2(512, 15, dd=True)
    out = {}
    for d in ("S", "DD", "Q"):
        a = sh.a_planes_on(d)
        hp = sh.h_plane_doms().count(d)
        out[d] = dict(A=a, U8=sh.lookups_per_position(d), H_fp2=hp, committed_per_entry=a + 2 * hp, size=sh.size(d), terms=sh.zc_terms().get(d))
    out["DD_over_S"] = sh.size("DD") / sh.size("S")
    return out


if __name__ == "__main__":
    out = {}
    ne = n_e_census()
    out["n_e"] = ne
    print("== distinct exp-table outputs n_E (tables_attn.rs:96-104), by head_dim / f_e / e_s ==")
    for r in ne:
        print("   hd %-3d fE %-2d e_s %-2d: n_E %-3d (nonzero entries %d)" % (r["head_dim"], r["f_e"], r["e_s"], r["distinct"], r["nonzero"]))
    c = census_dd()
    out["dd_census_T512"] = c
    print("== DD census at 8B T512, n=2^15, cap 32 slots per row ==")
    for d in ("S", "DD", "Q"):
        v = c[d]
        print("   %-3s A %-2d U8 %-2d Fp2 helpers %-2d committed/entry %-2d size 2^%d terms %s" % (d, v["A"], v["U8"], v["H_fp2"], v["committed_per_entry"], clog2(v["size"]), v["terms"]))
    print("   dictionary size / score-domain size = %.4f" % c["DD_over_S"])
    for T in (128, 512, 1024):
        rows = table(T)
        out["T%d" % T] = rows
        print("== Llama-3-8B T%d, per block ==" % T)
        print("%-40s %4s %9s %7s %6s %7s %7s %6s %11s %5s %7s" % ("variant", "n", "elems(M)", "d%", "H%", "U8 d%", "eterm%", "+bits", "roof 25/40", "bw50", "cpu d%"))
        for r in rows:
            print("%-40s 2^%-2d %9.1f %+7.1f %6.1f %+7.1f %+7.1f %6.2f %5.1f/%5.1f %4.0f%% %+7.1f" % (
                r["name"], r["log_cols"], r["elems"] / 1e6, r["d_elems"], 100 * r["H_share"], r["d_u8"], r["d_terms"], r["bits"],
                r["roof"][0], r["roof"][1], 100 * r["frac50"], r["d_cpu"]))
    with open(os.path.join(HERE, "variants_r2.json"), "w") as fh:
        json.dump(out, fh, indent=1, default=float)
    print("wrote variants_r2.json")

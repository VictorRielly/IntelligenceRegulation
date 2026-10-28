#!/usr/bin/env python3
"""NATIVE R11 (paper and counting only): what the ACTIVATION-side levers cost
the proof, counted on native R9's layout, alone and stacked on R10's (c2).

Method = R10's: the replica of the R9 counting functions in
../r10/r10_weight_range_cost.py (its anchor is re-run here: the replica must
reproduce every size the R9 prover printed in HL_PB_TIMING, or this script
stops). This script adds, as a subclass (no change to the R10 file):
  * extra planes / lookups on Dom::S (R10 had them on D / Q / Kv / F only);
  * the isqrt limb count (SC_TZC sites 4 + 2*3*L and tables 25 + 6*(L-3));
  * extra PUBLIC tables per slot (runtime element-terms only);
and a WINDOW CALCULATOR: every requantisation remainder's byte limbs follow
from the interval of shifts it must admit, `L = ceil(max / 8)`, one top pin if
`min >= 8 (L - 1)`, else a second (union) pin. Shift intervals: the three
current exports (r10/r10_word_use.json and the export constants), plus each
lever's change of input / output scale in bits:
  weight sites q k v ao g u z   base sh_R9, or sh_a + the (c2) multiplier
                                bits (q/k 5, v 7, ao 8, g 6, z 6, u 4)
  score   RSL   sh_s 5..8      + dq + dk - ds
  PV      RO    sh_o 9         + dF + dv - do
  product RH    sh_h 13..16    + da - dh
  RoPE          SH_ROPE 7 fixed (the output keeps the input's scale)
Word classes: an int8 `sym` word (1 plane, 2 lookups) becomes int12 = 2 limb
planes + byte, byte, top pin (+2 planes, +1 lookup) or int16 = 2 limb planes
+ 2 bytes (+2 planes, +0 lookups), as x / ao / x1 / x2 / z16 / u16 / h16 are
today. Writes r11_activation_cost.json beside itself."""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "r10"))
import r10_weight_range_cost as r10  # noqa: E402

GEOMS = r10.GEOMS
SITES = r10.SITES

# shift intervals, union over llama3_8b_dg_rot1_voc0_T128, tinyllama_dg_rot1_T128, llama3_8b_pg_rot1_b7voc0_T128
SH_R9 = {"q": (8, 8), "k": (8, 8), "v": (8, 8), "ao": (3, 8), "g": (8, 8), "u": (0, 0), "z": (4, 8)}
SH_FULL = {"q": (9, 11), "k": (9, 11), "v": (8, 9), "ao": (3, 8), "g": (8, 10), "u": (0, 4), "z": (4, 10)}  # sh_a, r10_word_use.json
C2_BITS = {"q": 5, "k": 5, "v": 7, "ao": 8, "g": 6, "u": 4, "z": 6}
SH_S, SH_O, SH_H = (5, 8), (9, 9), (13, 16)
R9_NONW = {"s": (1, 1), "o": (2, 1), "h": (2, 1)}  # RSL one limb, RO and RH two limbs, one pin each


def window(lo, hi):
    """(limbs, pins) of the remainder of a shift that must admit [lo, hi]"""
    if hi <= 0:
        return (0, 0)
    L = (hi + 7) // 8
    return (L, 1 if (L == 1 or lo >= 8 * (L - 1)) else 2)


def word(delta):
    """an int8 sym word widened by `delta` bits: (planes, lookups) added"""
    return {0: (0, 0), 4: (2, 1), 8: (2, 0)}[delta]


class L2(r10.Layout):
    def __init__(self, g, dd=False, sites=None, extra=None, ln=4, norm_top=0, s_extra=(0, 0), isqrt=3, extra_tables=None):
        super().__init__(g, dd=dd, sites=sites, ln=ln, norm_top=norm_top, extra=extra)
        self.s_extra, self.isqrt, self.extra_tables = s_extra, isqrt, dict(extra_tables or {})

    def a_planes(self):
        a = super().a_planes()
        a["S"] += self.s_extra[0]
        return a

    def lookups(self):
        u = super().lookups()
        u["S"] += self.s_extra[1]
        return u

    def claim_sites(self):
        A, H = super().claim_sites()
        A["TZC"] = 4 + 2 * (3 * self.isqrt)
        return A, H

    def slot_work(self):
        out = []
        for (name, m, e, t) in super().slot_work():
            if name == "TZC":
                t = 25 + 6 * (self.isqrt - 3)
            out.append((name, m, e, t + self.extra_tables.get(name, 0)))
        return out


def build(geo, dd, cfg):
    """a configuration -> (L2 layout, the windows it chose, notes)"""
    c = dict(c2=False, dy=0, dnm=0, dq=0, dk=0, dv=0, do=0, ds=0, dF=0, dg=0, da=0, dh=0, norm="int8", sg=False, residual=False)
    c.update(cfg)
    base = SH_FULL if c["c2"] else SH_R9
    bits = C2_BITS if c["c2"] else {s: 0 for s in SITES}
    din = {"q": c["dy"] - c["dq"], "k": c["dy"] - c["dk"], "v": c["dy"] - c["dv"], "ao": c["do"], "g": c["dnm"] - c["dg"], "u": c["dnm"], "z": c["dh"]}
    sites, wins = {}, {}
    for s in SITES:
        # every layer keeps the full (c2) multiplier width, so the interval is shifted by it at both ends
        lo, hi = base[s][0] + din[s] + bits[s], base[s][1] + din[s] + bits[s]
        lo = max(0, lo)
        w = window(lo, hi)
        if s != "u" and w[0] == 0:
            # a site that has a remainder in R9 keeps at least one byte (window [0, 8]): the
            # honest accumulator is not promised to fit the output class unshifted
            w = (1, 1)
        wins[s] = (lo, hi, w)
        sites[s] = w
    nonw = {"s": (SH_S[0] + c["dq"] + c["dk"] - c["ds"], SH_S[1] + c["dq"] + c["dk"] - c["ds"]),
            "o": (SH_O[0] + c["dF"] + c["dv"] - c["do"], SH_O[1] + c["dF"] + c["dv"] - c["do"]),
            "h": (SH_H[0] + c["da"] - c["dh"], SH_H[1] + c["da"] - c["dh"])}
    extra = {"D": [0, 0], "Q": [0, 0], "Kv": [0, 0], "F": [0, 0]}
    s_extra = [0, 0]
    for k, (lo, hi) in nonw.items():
        L, p = window(max(lo, 0), hi)
        if L == 0:
            L, p = 1, 1
        L0, p0 = R9_NONW[k]
        dpl, dlk = L - L0, (L + p) - (L0 + p0)
        wins[k] = (lo, hi, (L, p))
        tgt = {"s": s_extra, "o": extra["Q"], "h": extra["F"]}[k]
        tgt[0] += dpl
        tgt[1] += dlk
    # word classes
    for dom, ws in (("D", ()), ("Q", (c["dq"], c["dq"], c["do"])), ("Kv", (c["dk"], c["dv"], c["dk"]))):  # Q: q8, qr8, o8; Kv: k8, v8, kr8
        for w in ws:
            extra[dom][0] += word(w)[0]
            extra[dom][1] += word(w)[1]
    s_extra[0] += word(c["ds"])[0]
    s_extra[1] += word(c["ds"])[1]
    if c["dh"]:
        extra["F"][0] += 1   # h16 -> int24: a third limb (full byte, no pin)
        extra["F"][1] += 1
    # the norms: output class and the remainder window wrho = tn + 1 + bits(D_max)
    wrho = 32
    if c["norm"] == "n12cn":      # cn x 16, window unchanged; y and nm int12
        extra["D"][0] += 4
        extra["D"][1] += 2
    elif c["norm"] in ("n16cn", "n16tn"):  # y and nm int16 (offset limbs)
        extra["D"][0] += 4
        if c["norm"] == "n16tn":  # tn - 8: the window shrinks by 8 bits
            wrho -= 8
    isqrt = 3
    if c["residual"]:
        # x, x1, x2 int24 (a third limb each; ao and z16 stay int16 with a public 2^8 in the residual adds),
        # D_max 8 bits larger (window + 8), isqrt D / a1 / a2 four limbs
        extra["D"][0] += 3
        extra["D"][1] += 3
        wrho += 8
        isqrt = 4
    ln = (wrho + 7) // 8
    top = int(wrho != 8 * ln)
    ext_tab = {"FZC": 1, "TAB": 1} if c["sg"] else {}
    lay = L2(GEOMS[geo], dd=dd, sites=sites, extra={k: tuple(v) for k, v in extra.items()}, ln=ln, norm_top=top, s_extra=tuple(s_extra), isqrt=isqrt, extra_tables=ext_tab)
    return lay, dict(windows={k: dict(lo=v[0], hi=v[1], limbs=v[2][0], pins=v[2][1]) for k, v in wins.items()}, norm_window=wrho, norm_limbs=ln, isqrt_limbs=isqrt)


LEVERS = {
    "N12": ("(1) norm outputs y, nm int12 (cn x 16; norm window unchanged)", dict(dy=4, dnm=4, norm="n12cn")),
    "N16": ("(1) norm outputs y, nm int16 via tn - 8 (window 32 -> 24: one remainder limb fewer per norm)", dict(dy=8, dnm=8, norm="n16tn")),
    "N16cn": ("(1) norm outputs int16 via cn x 256 (window unchanged; cn up to 917,248 < 2^20)", dict(dy=8, dnm=8, norm="n16cn")),
    "FP12": ("(2) softmax F_P 9 -> 12 (p stays two limbs to F_P 15; sh_o 9 -> 12 inside 9..=16)", dict(dF=3)),
    "A12": ("(2) attention words q, k, v, qr, kr, o int12 (score window, PV, ao follow)", dict(dq=4, dk=4, dv=4, do=4)),
    "A16": ("(2) attention words q, k, v, qr, kr, o int16", dict(dq=8, dk=8, dv=8, do=8)),
    "S12": ("(2) score word s int12 + a 4096-row exp table (fits Dom::Tab; DD infeasible)", dict(ds=4)),
    "SG": ("(3) per-channel-group SiLU, registry members: 0 planes; one public group column in SC_FZC and SC_TAB", dict(sg=True)),
    "SI12": ("(3) SiLU input int12 (4096-row act table inside Dom::Tab; gate shift - 4)", dict(dg=4)),
    "RH3": ("(3) SiLU output 4 bits finer (table values) -> product remainder three bytes", dict(da=4)),
    "H24": ("(3) product output h int24 (third limb) -> down input + 8 bits", dict(dh=8)),
    "RES": ("(4) residual x, x1, x2 int24 (+ norm window + 8, isqrt four limbs)", dict(residual=True)),
}
STACKS = {
    "C2": ("(c2) alone (R10 a3_1)", dict(c2=True)),
    "LOW12": ("(c2) + norm int16 (tn route) + F_P 12 + attention words int12 + per-group SiLU + SiLU input int12 (product remainder unchanged)",
              dict(c2=True, dy=8, dnm=8, norm="n16tn", dF=3, dq=4, dk=4, dv=4, do=4, sg=True, dg=4)),
    "LOW16": ("LOW12 with the attention words int16", dict(c2=True, dy=8, dnm=8, norm="n16tn", dF=3, dq=8, dk=8, dv=8, do=8, sg=True, dg=4)),
    "MIN12": ("(c2) + norm int16 (tn route) + F_P 12 + attention words int12 + per-group SiLU + SiLU input int12 + SiLU output 4 bits finer (product three bytes)",
              dict(c2=True, dy=8, dnm=8, norm="n16tn", dF=3, dq=4, dk=4, dv=4, do=4, sg=True, dg=4, da=4)),
    "MIN16": ("MIN12 with the attention words int16 (cheaper at T128, dearer at T512)",
              dict(c2=True, dy=8, dnm=8, norm="n16tn", dF=3, dq=8, dk=8, dv=8, do=8, sg=True, dg=4, da=4)),
    "WIDE": ("MIN16 + h int24 + score word int12 (non-DD only)", dict(c2=True, dy=8, dnm=8, norm="n16tn", dF=3, dq=8, dk=8, dv=8, do=8, ds=4, sg=True, dg=4, da=4, dh=8)),
    "WIDE_DD": ("MIN16 + h int24 (the widest that keeps DD)", dict(c2=True, dy=8, dnm=8, norm="n16tn", dF=3, dq=8, dk=8, dv=8, do=8, sg=True, dg=4, da=4, dh=8)),
    "WIDE_RES": ("WIDE_DD + residual int24 (tn - 8 serves both: norm window back to 32)", dict(c2=True, dy=8, dnm=8, norm="n16tn", dF=3, dq=8, dk=8, dv=8, do=8, sg=True, dg=4, da=4, dh=8, residual=True)),
}


def row(t, base, geo, dd, meas, receipts):
    r = dict(committed=t["committed"], u8=t["u8"], element_terms=t["element_terms"],
             d_committed_pct=r10.pct(base["committed"], t["committed"]), d_u8_pct=r10.pct(base["u8"], t["u8"]),
             d_element_terms_pct=r10.pct(base["element_terms"], t["element_terms"]), d_receipt_bytes_per_block=r10.receipt_delta(base, t),
             d_a_planes=t["a_planes"] - base["a_planes"], d_h_planes=t["h_planes"] - base["h_planes"])
    if geo in receipts:
        off, on, nb = receipts[geo]
        r["d_run_receipt_pct"] = round(100.0 * nb * r["d_receipt_bytes_per_block"] / (on if dd else off), 2)
    mk = (geo, dd) if (geo, dd) in meas else ("Llama-3-8B T128", dd)
    if geo == "Llama-3-8B T512":
        _, _, ab, an = r10.time_model(meas[mk], base, t, per_unit_from=True)
    else:
        tb, tn, ab, an = r10.time_model(meas[mk], base, t)
        r["model_prove_time_pct"] = r10.pct(tb, tn)
    r["model_argument_time_pct"] = r10.pct(ab, an)
    return r


def main():
    meas = r10.anchor()  # asserts the replica == the prover's printed sizes
    receipts = {"TinyLlama-1.1B T128": (497_665_904, 502_836_080, 22), "Llama-3-8B T128": (922_711_264, 930_231_520, 32)}
    # self-checks: the empty configuration is R9; c2 is R10's a3_1
    for geo in GEOMS:
        for dd in (False, True):
            assert build(geo, dd, {})[0].totals() == r10.Layout(GEOMS[geo], dd=dd).totals()
            a31 = {**{s: (2, 1) for s in SITES}, "u": (1, 1)}
            assert build(geo, dd, dict(c2=True))[0].totals()["committed"] == r10.Layout(GEOMS[geo], dd=dd, sites=a31).totals()["committed"]
    out = {"schema": "zk60-native-r11-activation-cost/1", "levers": {k: v[0] for k, v in LEVERS.items()}, "stacks": {k: v[0] for k, v in STACKS.items()},
           "alone": {}, "on_c2": {}, "stacks_result": {}, "windows": {}}
    for geo in GEOMS:
        for dd in (False, True):
            key = f"{geo} | R9 {'DD' if dd else 'non-DD'}"
            base = r10.Layout(GEOMS[geo], dd=dd).totals()
            c2t = build(geo, dd, dict(c2=True))[0].totals()
            out["alone"][key], out["on_c2"][key], out["stacks_result"][key] = {}, {}, {}
            for k, (desc, cfg) in LEVERS.items():
                if dd and cfg.get("ds"):
                    out["alone"][key][k] = out["on_c2"][key][k] = "n/a: a 4096-row exp table has up to 2^f_e + 1 = 513 distinct outputs, far above any cap below T"
                    continue
                lay, w = build(geo, dd, cfg)
                out["alone"][key][k] = row(lay.totals(), base, geo, dd, meas, receipts)
                lay2, w2 = build(geo, dd, {**cfg, "c2": True})
                r = row(lay2.totals(), base, geo, dd, meas, receipts)
                r["marginal_over_c2_committed_pct"] = r10.pct(c2t["committed"], lay2.totals()["committed"])
                r["marginal_over_c2_u8_pct"] = r10.pct(c2t["u8"], lay2.totals()["u8"])
                r["marginal_over_c2_element_terms_pct"] = r10.pct(c2t["element_terms"], lay2.totals()["element_terms"])
                out["on_c2"][key][k] = r
                if geo == "Llama-3-8B T128" and not dd:
                    out["windows"][f"{k} alone"] = w
                    out["windows"][f"{k} on c2"] = w2
            for k, (desc, cfg) in STACKS.items():
                if dd and cfg.get("ds"):
                    out["stacks_result"][key][k] = "n/a (DD infeasible with a 4096-row exp table)"
                    continue
                lay, w = build(geo, dd, cfg)
                out["stacks_result"][key][k] = row(lay.totals(), base, geo, dd, meas, receipts)
                if geo == "Llama-3-8B T128" and not dd:
                    out["windows"][f"stack {k}"] = w
    json.dump(out, open(os.path.join(HERE, "r11_activation_cost.json"), "w"), indent=1)
    f = lambda r: "n/a" if isinstance(r, str) else f"{r['d_committed_pct']:+6.2f} / {r['d_u8_pct']:+6.2f} / {r['d_element_terms_pct']:+6.2f}"
    for key in out["alone"]:
        print(f"\n== {key}   (committed / U8 / element-terms, % vs R9)")
        for k in LEVERS:
            a, b = out["alone"][key][k], out["on_c2"][key][k]
            m = "" if isinstance(b, str) else f"   marginal over c2 {b['marginal_over_c2_committed_pct']:+6.2f} / {b['marginal_over_c2_u8_pct']:+6.2f} / {b['marginal_over_c2_element_terms_pct']:+6.2f}"
            print(f"  {k:6s} alone {f(a)}   on c2 {f(b)}{m}")
        for k in STACKS:
            r = out["stacks_result"][key][k]
            extra = "" if isinstance(r, str) else "".join(f"  {lab} {r[fl]:+.1f}%" for fl, lab in (("model_prove_time_pct", "time[M]"), ("model_argument_time_pct", "arg-time[M]"), ("d_run_receipt_pct", "receipt")) if fl in r)
            print(f"  STACK {k:9s} {f(r)}{extra}")
    print("\nwindows at 8B T128 (lo..hi -> limbs, pins):")
    for k, w in out["windows"].items():
        print(f"  {k:12s}", " ".join(f"{s}:{v['lo']}..{v['hi']}->{v['limbs']}/{v['pins']}" for s, v in w["windows"].items()), f"norm {w['norm_window']}b/{w['norm_limbs']}L isqrt {w['isqrt_limbs']}")


if __name__ == "__main__":
    main()

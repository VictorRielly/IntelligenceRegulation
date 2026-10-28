#!/usr/bin/env python3
"""NATIVE R9: DD's counts, the review's model against the built layout.

`model()` is dd_check.py part B's `counts()` (results/zk60_gpt_nonlinear_
review_20261018/dd_check/dd_check.py, lines 95-141), copied and parameterised
by the geometry (T, heads, head_dim, kv, width, f_pad, log_n) instead of the
fixed Llama-3-8B T512 / 2^15 it was written for; nothing else is changed. It
is run at the review's own anchor (8B T512: today 663,257,088 committed,
DD -20.82%) and at the two built profiles (TinyLlama and 8B T128), where it
is compared with the layout the Rust tree builds (`Shape::totals`, printed by
r9_tests::the_t128_dd_shapes_build_and_lay_out, values pasted below).
Writes r9_counts.json beside this script."""
import json
import os


def clog2(v):
    return (v - 1).bit_length()


def model(T, h, hd, kv, d, f_pad, log_n, dd=False, cap=32, dd_slot_sites=True, ln=4, top=0):
    n = 1 << log_n
    fe, fp = 9, 9
    wrho_s = clog2(T) + fe
    ls, lp = (wrho_s + 7) // 8, (fp + 1 + 7) // 8
    size = {"T": T, "Ht": h * T, "L": 1 << max(log_n, clog2(16 * T)), "D": T * d, "Q": T * h * hd,
            "Kv": T * kv * hd, "S": h * T * T, "F": T * f_pad, "Tab": 1 << log_n, "DD": h * T * cap}
    rows_of = {k: max(1, v >> log_n) for k, v in size.items()}
    a = {"T": 4, "Ht": 2, "L": 2, "D": 4 + 2 * ln + 8 + 2 * ln + 7, "Q": 7, "Kv": 6, "S": 5 + lp + 2 * ls, "F": 11, "Tab": 3}
    per_norm = 2 + 2 * (ln + top)
    u8 = {"L": 2, "D": 2 + per_norm + 6 + per_norm + 2 + 4, "Q": 13, "Kv": 12, "F": 9, "S": 2 + 2 + (lp + 1) + 2 * (ls + 1)}
    if dd:
        a["S"] = 5
        u8["S"] = 4
        a["DD"] = 1 + lp + 2 * ls + 1
        u8["DD"] = (lp + 1) + 2 * (ls + 1)
    helpers = {k: (v + 1) // 2 for k, v in u8.items()}
    extra_h = {"S": 1, "F": 1, "Tab": 4}
    if dd:
        extra_h["S"] = 2
        extra_h["DD"] = 1
    hplanes = {k: helpers.get(k, 0) + extra_h.get(k, 0) for k in size}
    a_sites = 1 + 1 + (4 + 2 * 9) + 2 + 2 + 7 + 2 + 2 + (a["D"] + 2) + (a["Q"] + 1) + (a["Kv"] + 1) + (a["S"] + 2) + a["F"] + 3 + 2
    h_sites = helpers["L"] + helpers["D"] + helpers["Q"] + helpers["Kv"] + hplanes["S"] + hplanes["F"] + 3 + 1
    if dd and dd_slot_sites:
        a_sites += a["DD"] + 1
        h_sites += hplanes["DD"]
    a_rows = sum(a[k] * rows_of[k] for k in a) + 2 * a_sites + 2
    h_rows = sum(2 * hplanes[k] * rows_of[k] for k in hplanes) + 2 * h_sites + 2
    u8_total = sum(u8[k] * size[k] for k in u8)
    terms = {"D": (a["D"] + 2) + helpers["D"], "Q": (a["Q"] + 1) + helpers["Q"], "Kv": (a["Kv"] + 1) + helpers["Kv"],
             "S": (a["S"] + 2) + hplanes["S"], "F": a["F"] + hplanes["F"]}
    if dd:
        terms["DD"] = a["DD"] + 1 + hplanes["DD"]
    eterms = sum(size[k] * terms[k] for k in terms)
    return dict(a_rows=a_rows, h_rows=h_rows, elems=(a_rows + h_rows) * n, u8=u8_total, eterms=eterms)


GEOMS = {
    "Llama-3-8B T512 (the review's anchor, row 2^15)": dict(T=512, h=32, hd=128, kv=8, d=4096, f_pad=16384, log_n=15),
    "Llama-3-8B T128 (row 2^14)": dict(T=128, h=32, hd=128, kv=8, d=4096, f_pad=16384, log_n=14),
    "TinyLlama-1.1B T128 (row 2^14)": dict(T=128, h=32, hd=64, kv=4, d=2048, f_pad=8192, log_n=14),
}
# the built layout (Shape::totals via r9_tests), [COUNTED]
BUILT = {
    "Llama-3-8B T128 (row 2^14)": dict(a=(3405, 3283), h=(3790, 3634), u8=(51937280, 48398336)),
    "TinyLlama-1.1B T128 (row 2^14)": dict(a=(1993, 1871), h=(2182, 2026), u8=(28999680, 25460736)),
}
out = {}
for name, g in GEOMS.items():
    t, d = model(**g), model(**g, dd=True)
    row = dict(today=t, dd=d, d_elems_pct=round(100 * (d["elems"] / t["elems"] - 1), 2), d_u8_pct=round(100 * (d["u8"] / t["u8"] - 1), 2), d_eterms_pct=round(100 * (d["eterms"] / t["eterms"] - 1), 2))
    if name in BUILT:
        b = BUILT[name]
        row["built_matches_model"] = (b["a"] == (t["a_rows"], d["a_rows"]) and b["h"] == (t["h_rows"], d["h_rows"]) and b["u8"] == (t["u8"], d["u8"]))
        row["built"] = b
    out[name] = row
    print(f"{name}: committed {t['elems']:,} -> {d['elems']:,} ({row['d_elems_pct']:+.2f}%), U8 {row['d_u8_pct']:+.2f}%, element-terms {t['eterms']:,} -> {d['eterms']:,} ({row['d_eterms_pct']:+.2f}%)"
          + (f"; built layout == model: {row['built_matches_model']}" if 'built_matches_model' in row else ""))
assert out["Llama-3-8B T512 (the review's anchor, row 2^15)"]["today"]["elems"] == 663_257_088
json.dump(out, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "r9_counts.json"), "w"), indent=1)

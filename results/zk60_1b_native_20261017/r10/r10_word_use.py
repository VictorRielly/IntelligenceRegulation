#!/usr/bin/env python3
"""NATIVE R10: how many bits the public int8 weight words leave unused, per
weight-matmul site and layer, read from an export's own arrays (read-only).

For each layer and each of the seven block matmuls (q, k, v, ao=wo, g, u, z=wd):
  tmax      the tensor's largest |W8|
  k_t       floor(log2(127 / tmax)): the whole bits a per-tensor power-of-two
            rescale can add while every word stays in int8 (what option (a)
            buys; the shift at that site grows by exactly k_t)
  cmed      the median over output channels of the channel's largest |W8|
            (how much a per-output-channel scale could add on top: option (b))
  sh_r9     the site's shift in the export (sh_qkv, sh_ao, sh_g, sh_u = 0, sh_z)
  sh_a      sh_r9 + k_t: the shift option (a) needs at that site and layer
  s_b       sh_a + 12: the shift option (b) needs with a 12-bit multiplier
            normalised to the tensor's largest channel
The byte limbs a window needs are ceil(shift / 8) (a shift of 0 needs none).
usage: python3 r10_word_use.py <export dir> [<export dir> ...]
Writes r10_word_use.json beside itself (one entry per export)."""
import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
# site -> (array, axis of the OUTPUT channel in the stored orientation, shift key)
SITES = {"q": ("wq", 0, "sh_qkv"), "k": ("wk", 0, "sh_qkv"), "v": ("wv", 0, "sh_qkv"), "ao": ("wo", 0, "sh_ao"),
         "g": ("wg_t", 1, "sh_g"), "u": ("wu_t", 1, "sh_u"), "z": ("wd_t", 1, "sh_z")}


def limbs(sh):
    return 0 if sh <= 0 else (sh + 7) // 8


def scan(export):
    prof = json.load(open(os.path.join(export, "profile.json")))
    rows = []
    for L in prof["layers"]:
        d = os.path.join(export, L["dir"])
        man = json.load(open(os.path.join(d, "manifest.json")))
        c = man["constants"]
        row = {"layer": L["layer"]}
        for s, (name, axis, key) in SITES.items():
            a = man["arrays"][name]
            w = np.fromfile(os.path.join(d, a["file"]), dtype=np.int8).reshape(a["shape"])
            ab = np.abs(w.astype(np.int16))
            ch = ab.max(axis=1 - axis)
            tmax = int(ch.max())
            k_t = int(math.floor(math.log2(127 / tmax))) if tmax > 0 else 0
            sh = int(c.get(key, 0))
            row[s] = dict(tmax=tmax, cmed=float(np.median(ch)), cmin=int(ch.min()), k_t=k_t, sh_r9=sh, sh_a=sh + k_t, s_b=sh + k_t + 12)
        rows.append(row)
    summ = {}
    for s in SITES:
        sa = [r[s]["sh_a"] for r in rows]
        sb = [r[s]["s_b"] for r in rows]
        summ[s] = dict(tmax=[min(r[s]["tmax"] for r in rows), max(r[s]["tmax"] for r in rows)], k_t=[min(r[s]["k_t"] for r in rows), max(r[s]["k_t"] for r in rows)],
                       sh_r9=[min(r[s]["sh_r9"] for r in rows), max(r[s]["sh_r9"] for r in rows)], sh_a=[min(sa), max(sa)], s_b=[min(sb), max(sb)],
                       limbs_a=[limbs(min(sa)), limbs(max(sa))], limbs_b=[limbs(min(sb)), limbs(max(sb))],
                       cmed_median=float(np.median([r[s]["cmed"] for r in rows])))
    return dict(export=export, layers=len(rows), summary=summ, per_layer=rows)


def main():
    out = {}
    for e in sys.argv[1:]:
        r = scan(e)
        out[os.path.basename(e.rstrip("/"))] = r
        print(f"== {os.path.basename(e.rstrip('/'))} ({r['layers']} layers)")
        for s, v in r["summary"].items():
            print(f"  {s:2s} tmax {v['tmax']}  k_t {v['k_t']}  sh_r9 {v['sh_r9']}  sh_a {v['sh_a']} -> limbs {v['limbs_a']}  s_b {v['s_b']} -> limbs {v['limbs_b']}  median channel max {v['cmed_median']:.1f}")
    json.dump(out, open(os.path.join(HERE, "r10_word_use.json"), "w"), indent=1)


if __name__ == "__main__":
    main()

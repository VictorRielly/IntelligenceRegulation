#!/usr/bin/env python3
"""Proof-cost deltas of candidate profile changes, on the speed plan's counted
layout replica and phase cost law (copies of results/zk60_speed_plan_20261017/
layout.py and cost_model.py, sha256 abc5f58f... / 2460be8d..., unmodified).

A candidate is a set of per-domain deltas: extra committed A planes and extra
U8 lookups per element on a domain (each pair of lookups adds one LogUp helper
H plane, as in layout.py), or a change of the softmax remainder window
(wrho_s, through f_e or a rounding bit) / probability width (F_P, through lp).
Plane deltas of the gadgets are [MODEL] estimates from the layout's plane
lists (named per candidate); window-driven limb counts are [COUNTED] by the
replica's own formulas.
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import layout as lay  # noqa: E402
import cost_model as cm  # noqa: E402


class Variant(lay.Shape):
    def __init__(self, T, d, f, h, hd, kv, log_cols, f_e=9, wrho_extra=0, f_p=9, dA=None, dL=None):
        self._dA, self._dL = dict(dA or {}), dict(dL or {})
        self._fp = f_p
        lay.Shape.__init__(self, T, d, f, h, hd, kv, log_cols, f_e=f_e)
        self.wrho_s = lay.clog2(T) + f_e + wrho_extra
        assert self.wrho_s <= 32
        self.ls = (self.wrho_s + 7) // 8
        self.lp = (f_p + 1 + 7) // 8

    def a_plane_doms(self):
        v = lay.Shape.a_plane_doms(self)
        for dom, k in self._dA.items():
            v += [dom] * k
        return v

    def lookups_per_position(self, dom):
        return lay.Shape.lookups_per_position(self, dom) + self._dL.get(dom, 0)


GEOS = {"tinyllama": (2048, 5632, 32, 64, 4), "llama3-8b": (4096, 14336, 32, 128, 8)}
LOGCOLS = {("tinyllama", 128): 14, ("llama3-8b", 128): 14, ("llama3-8b", 512): 15}

CANDIDATES = {
    "baseline": {},
    "per_layer_shifts (all requant shifts per block, like R6 sh_s)": {},
    "softmax round-half-up (2E 2^F_P + Sum = 2 Sum p + rho)": {"wrho_extra": 1},
    "f_e 12": {"f_e": 12},
    "f_e 15": {"f_e": 15},
    "F_P 12 (p limbs unchanged: lp = 2)": {"f_p": 12},
    "F_P 15 (lp = 2)": {"f_p": 15},
    "sh_qkv two-byte remainder (window 1..16)": {"dA": {"Q": 1, "Kv": 2}, "dL": {"Q": 1, "Kv": 2}},
    "int16 score + clamped exp input [MODEL: +2 limbs, +1 selector, +1 clamp limb]": {"dA": {"S": 4}, "dL": {"S": 4}},
    "o int16 (two limbs instead of sym-U8) [MODEL]": {"dA": {"Q": 2}, "dL": {"Q": 2}},
}


def evaluate(model, T, spec):
    d, f, h, hd, kv = GEOS[model]
    sh = Variant(T, d, f, h, hd, kv, LOGCOLS[(model, T)], **spec)
    s = sh.summary()
    c = cm.coefficients("cpu")
    ph = cm.block_phases(sh, c)
    return {"committed_elems": s["A_elems"] + s["H_elems"], "u8": s["u8"], "receipt": s["receipt"],
            "block_proof_s_cpu_law": ph["total"], "S_A_planes": sh.a_planes_on("S"), "ls": sh.ls, "lp": sh.lp,
            "wrho_s": sh.wrho_s}


def main():
    out = {}
    for (model, T) in LOGCOLS:
        base = evaluate(model, T, {})
        rows = {}
        for name, spec in CANDIDATES.items():
            try:
                r = evaluate(model, T, spec)
            except AssertionError as e:
                rows[name] = {"error": str(e)}
                continue
            r["committed_delta_pct"] = 100 * (r["committed_elems"] / base["committed_elems"] - 1)
            r["proof_delta_pct"] = 100 * (r["block_proof_s_cpu_law"] / base["block_proof_s_cpu_law"] - 1)
            r["receipt_delta_pct"] = 100 * (r["receipt"] / base["receipt"] - 1)
            rows[name] = r
            print(f"{model:10s} T{T:<4d} {name[:70]:70s} committed {r['committed_delta_pct']:+6.2f}%  proof {r['proof_delta_pct']:+6.2f}%"
                  f"  receipt {r['receipt_delta_pct']:+6.2f}%  (ls {r['ls']} lp {r['lp']} S planes {r['S_A_planes']})")
        out[f"{model}_T{T}"] = rows
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "fp_cost.json"), "w") as fh:
        json.dump(out, fh, indent=1)


if __name__ == "__main__":
    main()

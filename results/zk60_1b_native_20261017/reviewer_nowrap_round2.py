#!/usr/bin/env python3
"""NATIVE LANE, round 2 (2026-10-17): the D24 reviewer's INDEPENDENT checker,
re-run on the classes declared after the review. It IMPORTS the reviewer's
results/zk60_d24_review_20261017/reviewer_nowrap.py by path (read-only; its
main() is not called, so nothing is written into the reviewer's directory)
and evaluates the reviewer's own functions:

  * softmax_bounds / softmax_forgery over the new f_e class 9..=16 at every
    T with clog2(T) + f_e <= 24 (review finding F-1);
  * clause_bounds at the norm class corner (unchanged class; re-checked).

Writes reviewer_nowrap_round2.json next to this file.
"""
import importlib.util
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "zk60_d24_review_20261017", "reviewer_nowrap.py")
spec = importlib.util.spec_from_file_location("reviewer_nowrap", SRC)
rv = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rv)


def main():
    P = rv.P
    out = {"source": os.path.normpath(SRC), "f_e_class": "9..=16", "wrho_s_max": 24, "softmax": []}
    worst = 0
    for f_e in range(9, 17):
        for lt in range(0, 16):
            T = 1 << lt
            if lt + f_e > 24:
                continue
            b, wrho_s = rv.softmax_bounds(T, f_e)
            fz = rv.softmax_forgery(T, f_e)
            assert b < P, (f_e, T)
            assert fz is None, (f_e, T, fz)
            worst = max(worst, b)
            out["softmax"].append({"f_e": f_e, "T": T, "wrho_s": wrho_s, "bound_log2": round(math.log2(b), 3), "forgery": fz})
    out["softmax_worst_log2"] = round(math.log2(worst), 3)
    out["softmax_margin_bits"] = round(math.log2(P) - math.log2(worst), 3)
    # the reviewer's own threshold, reproduced
    out["T32_first_f_e_forgery"] = next(f for f in range(0, 63) if rv.softmax_forgery(32, f))
    corner = rv.clause_bounds(16, 2**20, 2**40, 8, 4096)
    out["norm_class_corner_log2"] = {k: round(math.log2(max(abs(v[0]), abs(v[1]), 1)), 3) if isinstance(v, (tuple, list)) else round(math.log2(max(abs(v), 1)), 3) for k, v in corner.items()} if isinstance(corner, dict) else str(corner)
    path = os.path.join(HERE, "reviewer_nowrap_round2.json")
    with open(path, "w") as f:
        json.dump(out, f, indent=1, default=str)
    print("PASS (reviewer's functions): f_e 9..=16, %d (f_e, T) points, worst softmax bound 2^%.3f (margin %.3f bits), no forgery; reviewer's T32 forgery threshold f_e %d; written %s"
          % (len(out["softmax"]), out["softmax_worst_log2"], out["softmax_margin_bits"], out["T32_first_f_e_forgery"], path))
    print("norm class corner (reviewer's clause_bounds):", out["norm_class_corner_log2"])
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Round-6 checker (reviewer, 2026-10-18): the per-layer softmax score shift.

sh_s enters exactly one relation (argument.rs SC_SZC group 2, the score host:
s8 * 2^sh_s + rsl - 2^(sh_s - 1) = acc, acc = sum over head_dim of q8 * k8)
and one lookup (layout.rs: byte(rsl), scaled(rsl, 2^(8 - sh_s)), so rsl in
[0, 2^sh_s)). Every other clause is independent of sh_s. This script sweeps
sh_s over the whole one-limb class 1..=8 at every trained profile (TinyLlama
T32/T64/T128: head_dim 64; Llama-3-8B T32/T64/T128: head_dim 128) and also
re-runs round 5's full clause set (reviewer_nowrap_r5.geometry) at the
TinyLlama geometries, which round 5 ran at 8B only. Writes
reviewer_nowrap_r6.json."""
import importlib.util
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("nowrap_r5", os.path.join(HERE, "reviewer_nowrap_r5.py"))
r5 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r5)

P = r5.P
HALF = P // 2


def score_host(hd, sh):
    acc = (-hd * 127 * 127, hd * 127 * 127)
    return r5.mag(r5.sc((-127, 127), 2**sh), (0, 2**sh - 1), (-(2 ** (sh - 1)), 0), r5.sc(acc, -1))


def main():
    out = {"score_host_by_sh_s": {}, "full_clause_sets": {}}
    for name, hd in (("TinyLlama (head_dim 64)", 64), ("Llama-3-8B (head_dim 128)", 128)):
        row = {}
        for sh in range(1, 9):
            v = score_host(hd, sh)
            assert v < HALF, (name, sh)
            # uniqueness: rsl in [0, 2^sh) and s8 in [-127, 127] make (s8, rsl)
            # the floor quotient / remainder of acc + 2^(sh-1) when no wrap
            row[sh] = round(math.log2(v), 3)
        out["score_host_by_sh_s"][name] = row
    geoms = {
        "TinyLlama T32": dict(T=32, d=2048, f=5632, q=32, kv=4, hd=64),
        "TinyLlama T64": dict(T=64, d=2048, f=5632, q=32, kv=4, hd=64),
        "TinyLlama T128": dict(T=128, d=2048, f=5632, q=32, kv=4, hd=64),
        "Llama-3-8B T32": dict(T=32),
        "Llama-3-8B T64": dict(T=64),
        "Llama-3-8B T128": dict(T=128),
    }
    for name, g in geoms.items():
        res = r5.geometry(**g)
        out["full_clause_sets"][name] = {"worst_geometry_clause_log2": res["worst_geometry_clause_log2"], "softmax_f_e_16": res["softmax"][16], "hosts": res["hosts"]}
    with open(os.path.join(HERE, "reviewer_nowrap_r6.json"), "w") as fh:
        json.dump(out, fh, indent=1)
    print("score host log2 by sh_s:", json.dumps(out["score_host_by_sh_s"]))
    for k, v in out["full_clause_sets"].items():
        print(k, "worst 2^%s" % v["worst_geometry_clause_log2"], "softmax f_e 16:", {kk: v["softmax_f_e_16"][kk] for kk in ("wrho_s", "c2_log2", "c3_log2", "pv_host_log2")})
    return 0


if __name__ == "__main__":
    sys.exit(main())

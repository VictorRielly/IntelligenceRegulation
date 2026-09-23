"""GS-11 adversarial check: M's declared geometry on every capture stage, read
with my own code (read-only), against the zk.rs constants (lane 2ea7221:
N_SLOTS 23, M_ROWS 50, MASK_LOG_MSG 9 -> 512, MASK_Q 256, b/u of 2*512 = 1024,
48 proximity coefficients = 2*23 + 2, 34 functionals), and the mask lengths
L_s = N_s * d_s + 2 (zkp-core/src/sumcheck.rs:197-199) with the fit
L_s + 256 <= 512 (ruling C-4, shape.rs:610-647; zk.rs:442 backstop).
"""

from __future__ import annotations

import json
import os

ART = "/home/victor/zk60-artifacts"
LANE = "/home/victor/wt-zk60-block125m/results/zk60_block_captures_20260923/rung-g"
FILES = [
    ("125M run dense s0", f"{ART}/m125-capture-dense-l2/stage-00.json"),
    ("125M run dense s1", f"{ART}/m125-capture-dense-l2/stage-01.json"),
    ("125M run zero s0", f"{ART}/m125-capture-zero-l2/stage-00.json"),
    ("125M run zero s1", f"{ART}/m125-capture-zero-l2/stage-01.json"),
    ("125M block dense", f"{ART}/block-captures-20260923/m125-dense/observations.json"),
    ("125M block zero", f"{ART}/block-captures-20260923/m125-zero/observations.json"),
    ("rung-G block dense", f"{LANE}/rung-g-dense/observations.json"),
    ("rung-G block zero", f"{LANE}/rung-g-zero/observations.json"),
]
WANT = {"rows": 50, "slots": 23, "q_len": 1024, "prox_len": 1024, "prox_rhos": 48, "columns": 256,
        "column_height": [50], "functionals": 34}


def main():
    out = []
    for label, f in FILES:
        m = json.load(open(f))["mask"]
        Ls = [n * d + 2 for n, d in m["specs"]]
        got = {"rows": m["rows"], "slots": len(m["specs"]), "q_len": m["q"]["len"], "prox_len": m["prox"]["len"],
               "prox_rhos": len(m["proximity_rhos"]), "columns": len(m["columns"]),
               "column_height": sorted({len(c["values"]) for c in m["columns"]}), "functionals": len(m["functionals"])}
        rec = {"capture": label, **got, "constants_match": got == WANT, "sum_L": sum(Ls), "max_L": max(Ls),
               "argmax_slot": Ls.index(max(Ls)), "headroom": 256 - max(Ls), "fit_ok": all(L + 256 <= 512 for L in Ls)}
        out.append(rec)
        print(json.dumps(rec))
    json.dump(out, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "gs11_check.json"), "w"), indent=1)


if __name__ == "__main__":
    main()

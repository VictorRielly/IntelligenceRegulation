"""Summarise gs5_check*.json by case family: instances, brute = exact formula,
brute = the gate's formula, the set of (brute - exact formula) and of the
values' own contribution.  Read-only over this directory."""

from __future__ import annotations

import glob
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))


def family(label):
    return label.split(" n=")[0].split(" rows=")[0]


def main():
    fams = {}
    grids = {}
    total = agree_exact = agree_tool = 0
    for f in sorted(glob.glob(os.path.join(HERE, "gs5_check*.json"))):
        for r in json.load(open(f)):
            k = family(r["case"])
            s = fams.setdefault(k, {"inst": 0, "exact": 0, "tool": 0, "diff": set(), "vals": set(), "nq": set()})
            s["inst"] += 1
            s["exact"] += r["agree_exact"]
            s["tool"] += r["agree_tool"]
            s["diff"].add(r["brute"] - r["formula_exact"])
            s["vals"].add(r["values_contribution"])
            s["nq"].add((r["n"], r["Q"], r["rows"]))
            total += 1
            agree_exact += r["agree_exact"]
            agree_tool += r["agree_tool"]
    for k, s in fams.items():
        print(f"{k:52s} inst {s['inst']:4d}  brute=exact {s['exact']:4d}  brute=gate {s['tool']:4d}  "
              f"brute-exact {sorted(s['diff'])}  values' contribution {sorted(s['vals'])}  (n,Q,rows) x{len(s['nq'])}")
    print(json.dumps({"instances": total, "brute_equals_exact_formula": agree_exact, "brute_equals_gate_formula": agree_tool}))


if __name__ == "__main__":
    main()

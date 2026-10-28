#!/usr/bin/env python3
"""[gate round 14] Failing-first controls for the export check's two NEW
per-layer arms (tools v17: E1 against the run calibration, E5 against each
stage's export layer), run with the FROZEN v17 code on the T128 DD L = 2
dense capture, in memory only:

  EXP-1  run.json's sh_s (a per-layer field) moved by one: E1 must refuse it
         against the run calibration of export layers [0, 1];
  EXP-2  run.json's norm_cn_a (per-layer) moved by one: E1 must refuse;
  EXP-3  stage 1's own `score shift` clause changed 8 -> 7 and the schedule
         digest RE-BOUND to the edited lines (so the stage-line reader
         accepts it): E5 must refuse stage 1 against export layer 1;
  EXP-4  the README's declared layer list changed to [0, 2]: E3b must refuse
         the disagreement with the gains' identification [0, 1].

The honest bundle must pass.  Nothing on disk is touched.

    python3 ex_perlayer_controls.py <out.json>
"""
import copy
import json
import os
import sys

V17 = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/frozen_v17/scripts"
sys.path.insert(0, V17)
sys.dont_write_bytecode = True

import zk60_native_rg_exportcheck as X  # noqa: E402
import zk60_native_rg_stagecal as SC  # noqa: E402
from zk60_native_rg_block import load_bundle  # noqa: E402

B = "/home/victor/zk60-artifacts/dd-gate-r9/tl128dd-l2-dense"
EXPORT = "/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/exports/tinyllama_dg_rot1_T128"


def main(out):
    b = load_bundle(B)
    honest = X.export_check(b, EXPORT)
    rows = []

    def run(name, what, want, mutate=None, readme=None):
        saved = copy.deepcopy(b.run)
        orig_readme = X._readme_layers
        try:
            if mutate:
                mutate(b.run)
            if readme is not None:
                X._readme_layers = lambda _b: readme
            r = X.export_check(b, EXPORT)
        finally:
            b.run.clear()
            b.run.update(saved)
            X._readme_layers = orig_readme
        named = [f for f in r["findings"] if f.startswith(want)]
        rows.append({"control": name, "what": what, "ok_under_perturbation": r["ok"],
                     "findings_naming_it": named[:3], "fires": (not r["ok"]) and bool(named)})

    run("EXP-1", "run.json sh_s 6 -> 7 (per-layer field)", "E1",
        mutate=lambda r: r["shape"].__setitem__("sh_s", r["shape"]["sh_s"] + 1))
    run("EXP-2", "run.json norm_cn_a +1 (per-layer field)", "E1",
        mutate=lambda r: r["shape"].__setitem__("norm_cn_a", r["shape"]["norm_cn_a"] + 1))

    def edit_clause(r):
        ln = r["stage_lines"][1]
        new = ln.replace("score shift 8 (the layer's own", "score shift 7 (the layer's own", 1)
        assert new != ln
        r["stage_lines"] = [r["stage_lines"][0], new] + list(r["stage_lines"][2:])
        r["schedule_digest"] = list(bytes.fromhex(SC.schedule_digest(r)["recomputed"]))
    run("EXP-3", "stage 1's own score shift 8 -> 7, schedule digest re-bound", "E5", mutate=edit_clause)
    run("EXP-4", "README layers [0, 2] instead of [0, 1]", "E3b", readme=[0, 2])
    doc = {"what": __doc__.strip().splitlines()[0], "bundle": B, "export": EXPORT, "tools": V17,
           "honest_ok": honest["ok"], "honest_findings": honest["findings"], "controls": rows,
           "all_fire": all(r["fires"] for r in rows),
           "ok": honest["ok"] and all(r["fires"] for r in rows), "privacy_acceptance": False}
    with open(out, "w") as fh:
        json.dump(doc, fh, indent=1)
    print("honest", honest["ok"], [(r["control"], r["fires"], r["findings_naming_it"][:1]) for r in rows])
    return 0 if doc["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1]))

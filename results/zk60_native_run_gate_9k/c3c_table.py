#!/usr/bin/env python3
"""ROUND 9k: control C3c on the four standalone block bundles, against the
prediction written before it first ran (`prediction_by_hand.json`).

    python3 results/zk60_native_run_gate_9k/c3c_table.py

Reads the two rung-G block records (re-taken in place,
`results/zk60_native_run_gate_block/`) and the two 125M C3c records (this
directory) and writes `c3c_table.json`: every predicted figure beside the
measured one, per bundle, per system (the pair, the whole block), honest and
perturbed, plus whether the rest of stage 6 still fires and whether the
honest whole block is the record's own stage-4 figure.
"""

from __future__ import annotations

import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
W = os.path.dirname(os.path.dirname(HERE))
C3C = "C3c_a_blinding_row_shared_between_the_two_external_endpoints"
KEYS = ("identified_rows", "rank_all", "rank_on_non_data", "k0",
        "u_row_term_fp", "joint_fp", "sum_of_parts_fp", "block_diagonal")
BUNDLES = (
    ("rung-g-dense", "rung-g", "zk60_native_run_gate_block/block-rung-g-dense", False),
    ("rung-g-zero", "rung-g", "zk60_native_run_gate_block/block-rung-g-zero", False),
    ("m125-dense", "m125", "zk60_native_run_gate_9k/block-m125-dense-c3c", True),
    ("m125-zero", "m125", "zk60_native_run_gate_9k/block-m125-zero-c3c", True),
)


def main():
    with open(os.path.join(HERE, "prediction_by_hand.json")) as fh:
        pred = json.load(fh)
    out = {"what": __doc__.split("\n\n")[0], "bundles": [], "mismatches": []}
    for name, shape, rec, staged in BUNDLES:
        path = os.path.join(W, "results", rec + ".json")
        if not os.path.exists(path):
            out["bundles"].append({"bundle": name, "record": rec, "missing": True})
            out["mismatches"].append(f"{name}: record missing")
            continue
        with open(path) as fh:
            r = json.load(fh)
        s6 = r["stage6_negative_controls"]
        fam = s6["run_controls"] if staged else s6
        c = fam[C3C]
        row = {"bundle": name, "record": rec, "fires": c["fires"],
               "marginals_unchanged": c["marginals_unchanged"],
               "what": c["what"], "systems": {}}
        for system in ("pair", "whole_block"):
            for side in ("honest", "perturbed"):
                want = pred[system][shape][side]
                got = c[system][side]
                want_matrix = f"{want['generators']} x {want['coordinate_classes']}"
                cells = {"matrix": {"predicted": want_matrix, "measured": got["matrix"]}}
                for k in KEYS:
                    if k in want:
                        cells[k] = {"predicted": want[k], "measured": got[k]}
                for k, v in cells.items():
                    if v["predicted"] != v["measured"]:
                        out["mismatches"].append(f"{name} {system} {side} {k}: "
                                                 f"{v['predicted']} vs {v['measured']}")
                row["systems"][f"{system}/{side}"] = cells
            row["systems"][f"{system}/rise_fp"] = c[system]["rise_fp"]
        row["parts_fp_perturbed_whole"] = c["whole_block"]["perturbed"]["parts_fp"]
        if row["parts_fp_perturbed_whole"] != pred["parts_fp"]:
            out["mismatches"].append(f"{name}: parts moved")
        w = r["stage4_the_boundary"]["whole_run"]
        h = c["whole_block"]["honest"]
        row["honest_whole_block_is_stage_4"] = (
            (h["matrix"], h["joint_fp"], h["sum_of_parts_fp"])
            == (w["matrix"], w["joint_fp"], w["sum_of_parts_fp"]))
        row["block_controls"] = {"controls": fam["controls"],
                                 "fire": sum(1 for n in fam["controls"]
                                             if fam[n]["fires"]),
                                 "all_fire": fam["all_fire"]}
        row["record_ok"] = r.get("ok")
        if staged:
            # the staged driver's stage 6 also fires the hash-rule family and
            # round 9's M9 controls; say which part is not `ok` and why
            hc = s6["hash_rule_controls"]
            row["stage6_parts_ok"] = {k: v.get("ok") for k, v in s6.items()
                                      if isinstance(v, dict)}
            row["hash_rule_controls_that_did_not_fire"] = hc.get(
                "controls_that_did_not_fire")
            row["hash_rule_controls_skipped"] = [
                x["control"] for x in hc.get("controls_skipped", [])]
        row["stages_not_ok"] = sorted(k for k in r if k.startswith("stage")
                                      and isinstance(r[k], dict)
                                      and r[k].get("ok") is False)
        if not (c["fires"] and c["marginals_unchanged"]
                and row["honest_whole_block_is_stage_4"] and fam["all_fire"]):
            out["mismatches"].append(f"{name}: fires / marginals / stage 4 / all_fire")
        out["bundles"].append(row)
    out["prediction_held"] = not out["mismatches"]
    with open(os.path.join(HERE, "c3c_table.json"), "w") as fh:
        json.dump(out, fh, indent=1, sort_keys=True)
        fh.write("\n")
    for b in out["bundles"]:
        if b.get("missing"):
            print(b["bundle"], "MISSING")
            continue
        p, q = b["systems"]["pair/perturbed"], b["systems"]["whole_block/perturbed"]
        print(f"{b['bundle']}: fires {b['fires']}, pair joint "
              f"{b['systems']['pair/honest']['joint_fp']['measured']} -> "
              f"{p['joint_fp']['measured']} (sum {p['sum_of_parts_fp']['measured']}), "
              f"whole {b['systems']['whole_block/honest']['joint_fp']['measured']} -> "
              f"{q['joint_fp']['measured']} (sum {q['sum_of_parts_fp']['measured']}), "
              f"non-data rank {q['rank_on_non_data']['measured']}, "
              f"controls {b['block_controls']['fire']} of "
              f"{len(b['block_controls']['controls'])}, record ok {b['record_ok']}, "
              f"stages not ok {b['stages_not_ok']}")
    print("prediction held:", out["prediction_held"], out["mismatches"])
    return 0 if out["prediction_held"] else 1


if __name__ == "__main__":
    raise SystemExit(main())

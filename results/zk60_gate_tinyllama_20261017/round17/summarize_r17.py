#!/usr/bin/env python3
"""[gate round 17] One summary of the round's records (frozen tools v20 on
the seven R-C1 classifier rung captures), and the cross-verdict comparison:
at one L, the randomness-free figures of the v0 / v1 / vtie captures must be
equal (the verdict moves no committed shape, no claim count, no disclosure).
Reads JSON only.

    python3 summarize_r17.py <out.json>
"""
import glob
import json
import os
import sys

E = "/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017"
P = E + "/round17"
MAN = {l.split()[1].split("/")[-1]: l.split()[0] for l in open(E + "/gate-tinyllama.tools.frozen.v20.sha256")}


def L(p):
    with open(p) as fh:
        return json.load(fh)


def row(p):
    d = L(p)
    t = d["terminals_classifier_slots"]
    tb = d["terminals_block_stages"]
    s3 = d["G1_per_commitment"]
    fp = d.get("full_preimage") or {}
    return {
        "record": os.path.relpath(p, E), "bundle": d["bundle"], "status": d["status"], "false_parts": d["false_parts"],
        "tools_equal_v20": all(MAN.get(os.path.basename(k)) == v for k, v in (d.get("tool_sha256") or {}).items()),
        "blocks": d["blocks"], "verdict": d["public_outputs"]["verdict"], "c": d["public_outputs"]["c"],
        "chunk": d["public_outputs"]["chunk"],
        "replay": [d["replay"]["challenges_checked"], d["replay"]["positions_checked"], d["replay"]["run_binding_reproduced"]],
        "classifier_slots": [t["slots_equal"], t["slots_checked"]],
        "block_stage_slots": [[x["slot_checks_equal"], x["slot_checks_expected"]] for x in tb.get("per_stage", [])],
        "per_commitment": [[r["role"], r["rows"], r["claims"], r["groups"], r["disclosed_dimension"], r["expected_disclosed_dimension"]]
                           for r in s3["per_commitment"]],
        "cfs": [[x["stage_kind"], x["entries_recomputed"], x["entries_differing"], x.get("functional_values")] for x in d["G3_mask_cfs"]["per_stage"]],
        "joint": [d["G1_joint"]["identified_word_pairs"], d["G1_joint"]["joint_disclosed_fp"], d["G1_joint"]["joint_equals_sum_of_parts"]],
        "full_preimage": [fp.get("commitments") if not isinstance(fp.get("commitments"), list) else len(fp["commitments"]),
                          fp.get("view_entries_compared"), fp.get("view_entries_differing")],
        "joint_preimage": (d.get("joint_preimage") or {}).get("all_four_couplings_respected"),
        "B3": d["B3_margin_vector"]["ok"], "one_public_bit": d["one_public_bit"]["ok"], "D41": d["D41"]["ok"],
        "NL1": [d["NL1_classifier_slots"]["slots_with_premises"], d["NL1_classifier_slots"]["slots_checked"]],
        "controls_fired": sorted(k for k, v in d["controls"].items() if isinstance(v, dict) and v.get("fires")),
        "controls_not_fired": d["controls"].get("not_fired"),
        "seconds": d["total_seconds"], "peak_rss_mb": d.get("peak_rss_mb"),
    }


def main(out):
    rows = [row(p) for p in sorted(glob.glob(P + "/v20/v20-*.json")) if not p.endswith(".guard.json")]
    cross = {}
    for L_ in (1, 2):
        grp = [r for r in rows if r["blocks"] == L_ and r["chunk"]["count"] == 1]
        keys = ("replay", "classifier_slots", "block_stage_slots", "per_commitment", "joint", "NL1")
        ref = grp[0] if grp else None
        cross[f"L{L_}"] = {"captures": [r["bundle"] for r in grp], "verdicts": [r["verdict"] for r in grp],
                           "randomness_free_figures_equal": bool(grp) and all(
                               all(r[k] == ref[k] for k in keys)
                               and [x[:3] for x in r["cfs"]] == [x[:3] for x in ref["cfs"]] for r in grp),
                           "compared": list(keys) + ["cfs (stage, entries, differing)"]}
    doc = {"what": __doc__.strip().splitlines()[0], "privacy_acceptance": False, "records": rows,
           "cross_verdict": cross, "all_pass": bool(rows) and all(r["status"] == "PASS" for r in rows)}
    for nm in ("ff/ff-v19-reader.json", "d41/d41-item-chunk1o27.json"):
        p = os.path.join(P, nm)
        if os.path.exists(p):
            doc[nm] = L(p)
    with open(out, "w") as fh:
        json.dump(doc, fh, indent=1, default=str)
    for r in rows:
        print(r["bundle"], r["status"], r["false_parts"], "v", r["verdict"], "slots", r["classifier_slots"], r["block_stage_slots"],
              "disc", [(x[0], x[4]) for x in r["per_commitment"]], "fp", r["full_preimage"], "ctl", len(r["controls_fired"]),
              r["controls_not_fired"], r["seconds"], "s")
    print("cross:", cross)
    print("all pass:", doc["all_pass"])


if __name__ == "__main__":
    main(sys.argv[1])

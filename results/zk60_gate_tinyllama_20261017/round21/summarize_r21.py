#!/usr/bin/env python3
"""[gate round 21] Collect the round's records into R21_SUMMARY.json (digests and the figures the summary and
the draft statement quote).  Reads JSON only.  NOT a privacy result.

    python3 summarize_r21.py <out.json>
"""
import hashlib
import json
import os
import sys

R = "/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round21"
DRAFT = "/home/victor/IntelligenceRegulation/docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_CLASSIFIER_SHIELDSTRAL_T128_DRAFT.md"


def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as fh:
        for b in iter(lambda: fh.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def main(out):
    rec = {"what": "gate round 21 summary [MEASURED / COUNTED / READ]; NOT a privacy acceptance",
           "privacy_acceptance": False, "files": {}}
    for rel in ("derive_block_tables.py", "classify_run_counts.py", "owner_record.py", "astra_wait.py", "r21_chain.sh",
                "dev/dev_b1.json", "derive/DERIVE_ALL.json", "CLASSIFY_RUN_COUNTS.json", "owner/OWNER_RECORD.json"):
        p = os.path.join(R, rel)
        if os.path.exists(p):
            rec["files"][rel] = sha(p)
    rec["files"]["docs/.../ZK60_PRIVACY_STATEMENT_CLASSIFIER_SHIELDSTRAL_T128_DRAFT.md"] = sha(DRAFT)
    d = os.path.join(R, "derive/DERIVE_ALL.json")
    if os.path.exists(d):
        a = json.load(open(d))
        rec["derivation"] = {
            "summary": a["summary"], "export_profile_is_the_runs": a["export_profile_is_the_runs"],
            "arrays_bin_sha256_ok": a.get("arrays_bin_sha256_ok"), "run_json_sha256_ok": a["run_json_sha256_ok"],
            "per_stage": [{"stage": s["stage"], "layer": s["layer"], "equal": s["equal"], "of": s["of"],
                           "G": s["G_derived"], "G_line": s["G_stage_line"], "groups": s["groups"],
                           "base_member": s["base_member"], "sh_h": s["sh_h_layer"],
                           "silu_ok": all(x["export_equals_float64_definition"] and x["export_equals_exact_decimal"]
                                          and x["export_equals_native_reference_vectors"] for x in s["silu"]),
                           "min_tie_margin": min(x["closest_approach_to_a_rounding_tie"] for x in s["silu"]),
                           "ok": s["ok"], "seconds": s["seconds"]} for s in a["stages"]],
            "controls": {k: v["fired"] for k, v in a.get("controls", {}).items()},
            "exp_generators": a["exp_generators"],
            "distinct_silu_members": a["summary"]["silu_members_checked"],
            "min_tie_margin_all": min(x["closest_approach_to_a_rounding_tie"] for s in a["stages"] for x in s["silu"]),
        }
        g = json.load(open(os.path.join(R, "derive/derive_all.guard.json")))
        rec["derivation"]["guard"] = {k: g.get(k) for k in ("label", "class", "need_gib", "cap_gib", "exit",
                                                             "child_wall_seconds", "peak_rss_gib", "ts_end")}
    c = json.load(open(os.path.join(R, "CLASSIFY_RUN_COUNTS.json")))
    rec["distance"] = {"counts": c["counts"], "residuals": c["residuals"], "controls": c["controls"]}
    o = json.load(open(os.path.join(R, "owner/OWNER_RECORD.json")))
    rec["owner"] = o["summary"]
    with open(out, "w") as fh:
        json.dump(rec, fh, indent=1, sort_keys=True)
        fh.write("\n")
    print(json.dumps({"files": rec["files"], "derivation": rec.get("derivation", {}).get("summary"),
                      "controls": rec.get("derivation", {}).get("controls"), "owner": rec["owner"]}, indent=1))


if __name__ == "__main__":
    main(sys.argv[1])

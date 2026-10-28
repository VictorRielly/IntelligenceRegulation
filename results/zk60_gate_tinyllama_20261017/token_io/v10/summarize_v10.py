#!/usr/bin/env python3
"""Gate round 7 step 2: one row per tools-v10 token record, for the report.
Reads JSON only; checks every record's tool hashes against the v10 manifest.
    python3 summarize_v10.py <out.json>
"""
import collections
import glob
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
EV = os.path.dirname(os.path.dirname(HERE))
MAN = os.path.join(EV, "gate-tinyllama.tools.frozen.v10.sha256")


def manifest():
    out = {}
    for line in open(MAN):
        d, p = line.split(None, 1)
        out[os.path.basename(p.strip())] = d
    return out


def one(path, man):
    r = json.load(open(path))
    gp = path[:-5] + ".guard.json"
    gu = json.load(open(gp)) if os.path.exists(gp) else {}
    pc = r["G1_per_commitment"]["per_commitment"]
    by_role = collections.defaultdict(set)
    for c in pc:
        role = c["site_role"] if c.get("stage_kind") in ("IN", "OUT") or c.get("site_role", "").startswith("E-") \
            else c.get("class") or c.get("site_role")
        by_role[f"{c.get('stage_kind') or 'BOUNDARY'}:{role}"].add(c["disclosed_dimension"])
    unmet = [c["role"] for c in pc if not c.get("meets_expectation")]
    g3 = r["G3_mask_cfs"]["per_stage"]
    g3k = collections.defaultdict(lambda: {"stages": 0, "functionals": set(), "entries": 0, "differing": 0})
    for s in g3:
        k = g3k[s["stage_kind"]]
        k["stages"] += 1
        k["functionals"].add(s.get("functionals_re_derived", s.get("functional_values")))
        k["entries"] += s["entries_recomputed"]
        k["differing"] += s["entries_differing"]
    g6 = r["G6_endpoints"]["endpoints"]
    ctl = r["controls"]
    live = {k: v for k, v in ctl["controls"].items() if k not in ctl["not_applicable"]}
    tb = r["terminals_block_stages"]
    ti = tb["terminal_identity"]
    tools = r.get("tool_sha256", {})
    tool_moved = sorted(k for k, v in tools.items() if man.get(k) != v)
    j = r["G1_joint"]
    fp = r["full_preimage"]
    return {
        "record": os.path.basename(path), "bundle": r["bundle"], "blocks": r["blocks"],
        "status": r["status"], "ok": r["ok"], "false_parts": r["false_parts"],
        "seconds": r["total_seconds"], "peak_rss_mb": r.get("peak_rss_mb"),
        "guard": {"exit": gu.get("exit"), "peak_rss_gib": gu.get("peak_rss_gib"),
                  "wall_s": round(gu.get("child_wall_seconds") or 0), "need": gu.get("need_gib")},
        "tools_equal_v10_manifest": not tool_moved, "tools_not_in_v10": tool_moved,
        "tools_hashed": len(tools),
        "replay": {k: r["replay"][k] for k in ("challenges_checked", "positions_checked",
                                               "run_binding_reproduced", "stages")},
        "replay_failures": len(r["replay"]["failures"]),
        "hash_columns": [r["hash_layer"]["columns_checked"], r["hash_layer"]["columns_authenticated"]],
        "G1": {"commitments_ranked": len(pc), "unmet": unmet,
               "disclosed_by_role": {k: sorted(v) for k, v in sorted(by_role.items())},
               "masking_commitments": len(r["G1_per_commitment"]["masking_commitments"])},
        "G1_joint": {"joint_disclosed_fp": j["joint_disclosed_fp"], "sum_of_parts_fp": j["sum_of_parts_fp"],
                     "identified_word_pairs": j["identified_word_pairs"], "components": len(j["components"]),
                     "findings": len(j["findings"]), "ok": j["ok"]},
        "G2_ok": r["G2_claim_points"]["ok"],
        "G2_r_emb_columns": [c["r_emb_column_coordinates"] for c in r["G2_claim_points"]["claims"]["B_in"]["claims"]],
        "G2_B_out_public_bits": [c.get("public_bits") for c in r["G2_claim_points"]["claims"]["B_out"]["claims"]],
        "G3": {k: {"stages": v["stages"], "functionals": sorted(v["functionals"]),
                   "entries": v["entries"], "differing": v["differing"]} for k, v in sorted(g3k.items())},
        "G3_ok": r["G3_mask_cfs"]["ok"],
        "G4_ok": r["G4_support_tables"]["ok"],
        "G4_required_found": sum(1 for v in r["G4_support_tables"]["required_support_tables"].values()
                                 if v.get("present") is True),
        "G4_required": len(r["G4_support_tables"]["required_support_tables"]),
        "G5_ok": r["G5_tab_width"]["ok"],
        "G6": {k: {"disclosed": v["disclosed_dimension"], "pad_rank": v["pad_block_rank"],
                   "distinct_columns": v["distinct_opened_columns"], "ok": v["ok"]} for k, v in g6.items()},
        "terminals_new_slots": [r["terminals_new_slots"]["slots_equal"], r["terminals_new_slots"]["slots_checked"]],
        "NL1": [r["NL1_new_slots"]["slots_with_premises"], r["NL1_new_slots"]["slots_checked"],
                r["NL1_new_slots"]["ok"]],
        "terminals_block_stages": {"equal": ti["slot_checks_equal"], "expected": ti["slot_checks_expected"],
                                   "status": tb["status"], "controls_ok": tb["controls"]["ok"],
                                   "controls": sorted(tb["controls"]["controls"]),
                                   "not_applicable": tb["controls"]["not_applicable"]},
        "full_preimage": {"commitments": len(fp["commitments"]), "entries": fp["view_entries_compared"],
                          "differing": fp["view_entries_differing"],
                          "leaves": fp["salted_leaves_authenticated"], "ok": fp["ok"]},
        "joint_preimage": {"all_four_couplings_respected": r["joint_preimage"]["all_four_couplings_respected"],
                           "C1_identified_word_pairs": r["joint_preimage"]["couplings"]["C1_shared_planes"]["identified_word_pairs"]},
        "controls": {"live": len(live), "fired": sum(1 for v in live.values() if v.get("fires", v.get("ok")) is True),
                     "not_fired": ctl["not_fired"], "not_applicable": ctl["not_applicable"],
                     "all_fire": ctl["all_fire"]},
        "timings": r["timings"],
    }


def main(out):
    man = manifest()
    rows = [one(p, man) for p in sorted(glob.glob(os.path.join(HERE, "token-v10-*.json")))
            if not p.endswith((".guard.json", "-summary.json"))]
    rec = {"what": "tools-v10 token gate records, one row each (gate round 7 step 2); NOT a privacy result",
           "manifest": os.path.basename(MAN), "records": len(rows),
           "all_pass": all(x["status"] == "PASS" for x in rows),
           "all_tools_equal_v10": all(x["tools_equal_v10_manifest"] for x in rows), "rows": rows}
    with open(out, "w") as fh:
        json.dump(rec, fh, indent=1, sort_keys=True, default=list)
        fh.write("\n")
    for x in rows:
        print(x["record"], x["status"], x["seconds"], x["peak_rss_mb"], "tools-v10", x["tools_equal_v10_manifest"])


if __name__ == "__main__":
    main(sys.argv[1])

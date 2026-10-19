#!/usr/bin/env python3
"""Round 6 part (B): the figures of the R7 gate records, one row each, for
the draft's step tables.  Reads JSON only.
    python3 summarize_r7.py <out.json> <record.json> ...
"""
import json
import os
import sys


def g(o, *path):
    for k in path:
        if o is None:
            return None
        o = o[k] if isinstance(k, int) and isinstance(o, list) and len(o) > k else (
            o.get(k) if isinstance(o, dict) else None)
    return o


def ctrl(c):
    if not isinstance(c, dict):
        return None
    return {"ok": c.get("ok"), "not_fired": c.get("controls_that_did_not_fire")}


def one(path):
    r = json.load(open(path))
    st = path[:-5] + ".status.json"
    gd = path[:-5] + ".guard.json"
    s = json.load(open(st)) if os.path.exists(st) else {}
    gu = json.load(open(gd)) if os.path.exists(gd) else {}
    ti = g(r, "stage8_plane_index_and_terminals", "terminal_identity") or {}
    m93 = None
    for c in g(r, "stage6_negative_controls", "round_9_controls", "controls") or []:
        if c.get("control") == "M9-3":
            m93 = {"ok": c.get("ok"), "domains": [(p["domain"], p["arms"]["draw-count"]["port_and_capture_numbers"])
                                                  for p in c.get("per_domain", [])]}
    return {
        "record": os.path.basename(path), "bundle": r.get("bundle"),
        "status": s.get("status"), "unexplained": len(s.get("unexplained", [])) if s else None,
        "ok": r.get("ok"), "pins_ok": g(r, "run_layer_source_pins", "ok"),
        "pins_moved": g(r, "run_layer_source_pins", "pins_that_moved"),
        "replay": {"challenges": g(r, "stage2_transcript_replay", "challenges_checked"),
                   "positions": g(r, "stage2_transcript_replay", "positions_checked"),
                   "binding": g(r, "stage2_transcript_replay", "run_binding_reproduced"),
                   "failures": len(g(r, "stage2_transcript_replay", "failures") or [])},
        "hash": {"columns": g(r, "stage9_hash_layer", "columns_checked"),
                 "authenticated": g(r, "stage9_hash_layer", "columns_authenticated"),
                 "bytes": g(r, "stage9_hash_layer", "bytes_hashed"),
                 "wrong_rules_reaching_root": g(r, "stage9_hash_layer", "cross_rule_probe", "wrong_rules_that_reached_the_root")},
        "terminal": {"equal": ti.get("slot_checks_equal"), "expected": ti.get("slot_checks_expected"),
                     "controls": ctrl(g(r, "stage8_plane_index_and_terminals", "controls"))},
        "stage10_controls": ctrl(g(r, "stage10_bilinear_group_factor", "controls")),
        "stage3_ok": g(r, "stage3_per_commitment", "ok"), "stage4_ok": g(r, "stage4_the_boundary", "ok"),
        "stage5_ok": g(r, "stage5_zero_data_preimage", "ok"),
        "full_preimage": {"commitments": g(r, "stage11_full_preimage", "commitments"),
                          "compared": g(r, "stage11_full_preimage", "view_entries_compared"),
                          "differing": g(r, "stage11_full_preimage", "view_entries_differing"),
                          "leaves": g(r, "stage11_full_preimage", "salted_leaves_authenticated"),
                          "controls": ctrl(g(r, "stage11_full_preimage", "controls"))},
        "mask": {"recomputed": g(r, "stage12_mask_and_cfs", "entries_recomputed"),
                 "differing": g(r, "stage12_mask_and_cfs", "entries_differing"),
                 "controls": ctrl(g(r, "stage12_mask_and_cfs", "controls"))},
        "joint": {"compared": g(r, "stage13_joint_run_preimage", "entries_compared"),
                  "differing": g(r, "stage13_joint_run_preimage", "entries_differing"),
                  "couplings": g(r, "stage13_joint_run_preimage", "all_four_couplings_respected")},
        "stage6": {"ok": g(r, "stage6_negative_controls", "ok"),
                   "run_controls_ok": g(r, "stage6_negative_controls", "run_controls", "ok"),
                   "hash_rule_controls_ok": g(r, "stage6_negative_controls", "hash_rule_controls", "ok"),
                   "round9_ok": g(r, "stage6_negative_controls", "round_9_controls", "ok"),
                   "m9_3": m93},
        "export_ok": g(r, "stage14_export_crosscheck", "ok"),
        "export_findings": len(g(r, "stage14_export_crosscheck", "findings") or []),
        "channels": g(r, "stage7_channels", "counts"),
        "seconds": r.get("total_seconds"), "peak_rss_mb": r.get("peak_rss_mb"),
        "guard": {"exit": gu.get("exit"), "wall": gu.get("child_wall_seconds"), "peak_rss_gib": gu.get("peak_rss_gib")},
    }


rows = [one(p) for p in sys.argv[2:]]
json.dump({"what": __doc__.strip().splitlines()[0], "privacy_acceptance": False, "rows": rows},
          open(sys.argv[1], "w"), indent=1, sort_keys=True)
for x in rows:
    print(json.dumps(x, sort_keys=True)[:3000])
    print()

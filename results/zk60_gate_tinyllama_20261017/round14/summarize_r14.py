#!/usr/bin/env python3
"""[gate round 14] One summary of the round's records (frozen tools v17 on
the eight DD captures): status, unexplained leaves, replay counts, terminal
slots, per-commitment disclosure, full preimage / mask / joint figures,
controls, and whether each record's `tool_sha256` equals the v17 manifest.
Reads JSON only.

    python3 summarize_r14.py <out.json>
"""
import glob
import json
import os
import sys

E = "/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017"
P = E + "/round14"
MAN = {l.split()[1].split("/")[-1]: l.split()[0]
       for l in open(E + "/gate-tinyllama.tools.frozen.v17.sha256")}


def L(p):
    with open(p) as fh:
        return json.load(fh)


def tools_ok(d):
    ts = d.get("tool_sha256")
    if not isinstance(ts, dict):
        return None
    return all(MAN.get(os.path.basename(k)) == v for k, v in ts.items())


def staged(p):
    d = L(p)
    st = p.replace(".json", ".status.json")
    s = L(st) if os.path.exists(st) else {}
    r = d.get("stage2_transcript_replay") or {}
    t = (d.get("stage8_plane_index_and_terminals") or {}).get("terminal_identity") or {}
    pcs = (d.get("stage3_per_commitment") or {}).get("per_commitment") or []
    out = {
        "record": os.path.relpath(p, E), "bundle": d.get("bundle"), "ok": d.get("ok"),
        "status": s.get("status"), "unexplained_false_leaves": (len(s["unexplained"]) if "unexplained" in s else None),
        "false_leaves_explained": len(s.get("explained") or {}),
        "tools_equal_v17": tools_ok(d), "seconds": d.get("total_seconds"), "peak_rss_mb": d.get("peak_rss_mb"),
        "replay": [r.get("challenges_checked"), r.get("positions_checked"), r.get("run_binding_reproduced")],
        "terminals": [t.get("slot_checks_equal"), t.get("slot_checks_expected")],
        "stages_at_own_calibration": (t.get("stage_calibration") or {}).get("stages_at_their_own_calibration"),
        "dd_e_column_attribution_ok": (all(a.get("ok") for a in t["dd_e_column_attribution"])
                                       if t.get("dd_e_column_attribution") else None),
        "per_commitment": [[c.get("role"), c.get("rows"), c.get("disclosed_dimension"),
                            c.get("expected_disclosed_dimension"), c.get("claims"), c.get("groups")]
                           for c in pcs],
    }
    fp = d.get("stage11_full_preimage") or {}
    if fp.get("requested"):
        pcs_fp = fp.get("per_commitment") or []
        out["full_preimage"] = {"commitments": len(pcs_fp),
                                "salted_leaves_authenticated": fp.get("salted_leaves_authenticated"),
                                "entries_compared": fp.get("view_entries_compared"),
                                "entries_differing": fp.get("view_entries_differing"),
                                "all_solved_and_exhibited": all(c.get("solved") and c.get("preimage_exhibited")
                                                                for c in pcs_fp if isinstance(c, dict)),
                                "ok": fp.get("ok")}
    mk = d.get("stage12_mask_and_cfs") or {}
    if mk.get("requested"):
        out["mask_cfs"] = {"entries_recomputed": mk.get("entries_recomputed"),
                           "entries_differing": mk.get("entries_differing"), "ok": mk.get("ok")}
    jt = d.get("stage13_joint_run_preimage") or {}
    if jt.get("requested"):
        out["joint"] = {"entries_compared": jt.get("entries_compared"),
                        "entries_differing": jt.get("entries_differing"),
                        "couplings_respected": jt.get("all_four_couplings_respected"), "ok": jt.get("ok")}
    x = d.get("stage14_export_crosscheck")
    if isinstance(x, dict) and "E1_constants" in x:
        out["export"] = {"ok": x.get("ok"), "findings": x.get("findings"),
                         "layers": (x.get("E3b_layers_by_gamma") or {}).get("layer_of_stage"),
                         "map_source": (x.get("E3b_layers_by_gamma") or {}).get("map_source"),
                         "run_calibration": (x.get("E1_run_calibration") or {}).get("run_values"),
                         "E5": [[r["stage"], r["layer"], r["at_its_own_calibration"], r["ok"]]
                                for r in (x.get("E5_stage_calibration") or {}).get("per_stage", [])],
                         "E4_checked": (x.get("E4_tables") or {}).get("checked")}
    neg = d.get("stage6_negative_controls")
    if isinstance(neg, dict):
        out["negative_controls_ok"] = neg.get("ok")
    return out


def main(out):
    doc = {"what": __doc__.strip().splitlines()[0], "privacy_acceptance": False,
           "v17_manifest_sha256": None, "staged": [], "dd": [], "controls": {}, "failing_first": []}
    import hashlib
    doc["v17_manifest_sha256"] = hashlib.sha256(open(E + "/gate-tinyllama.tools.frozen.v17.sha256", "rb").read()).hexdigest()
    for p in sorted(glob.glob(P + "/v17/*-a.json") + glob.glob(P + "/v17/*-everything.json")):
        doc["staged"].append(staged(p))
    for p in sorted(glob.glob(P + "/v17/prediction-*-validated.json")):
        d = L(p)
        doc.setdefault("predictions", []).append({"record": os.path.relpath(p, E), "ok": d.get("ok"),
                                                  "validation": d.get("validation", d.get("validated"))})
    for p in sorted(glob.glob(P + "/dd/*.json")):
        if p.endswith((".guard.json", ".status.json")):
            continue
        d = L(p)
        row = {"record": os.path.relpath(p, E), "ok": d.get("ok"), "tools_equal_v17": tools_ok(d)}
        if "summary" in d:
            row["summary"] = d["summary"]
        if isinstance(d.get("controls"), list):
            row["controls"] = [[c.get("control"), c.get("fires"), c.get("ok")] for c in d["controls"]]
        elif isinstance(d.get("controls"), dict):
            row["controls_ok"] = d["controls"].get("ok")
        doc["dd"].append(row)
    for p in sorted(glob.glob(P + "/controls/*.json") + glob.glob(P + "/controls/pincontrols/*.json")):
        if p.endswith((".guard.json", ".status.json")):
            continue
        d = L(p)
        doc["controls"][os.path.relpath(p, E)] = {
            "ok": d.get("ok"), "fired": d.get("fired"), "of": d.get("of"),
            "not_ok": [c.get("control") for c in d.get("controls", [])
                       if isinstance(c, dict) and not c.get("ok") and not c.get("skipped")]
            if isinstance(d.get("controls"), list) else None}
    for p in sorted(glob.glob(P + "/ff/*.json")):
        if p.endswith((".guard.json", ".status.json")):
            continue
        d = L(p)
        t = ((d.get("stage8_plane_index_and_terminals") or {}).get("terminal_identity") or {})
        doc["failing_first"].append({"record": os.path.relpath(p, E), "ok": d.get("ok"),
                                     "pins_that_moved": (t.get("source_pins") or {}).get("pins_that_moved"),
                                     "refused": t.get("refused_before_any_slot_was_evaluated")})
    with open(out, "w") as fh:
        json.dump(doc, fh, indent=1)
    for s in doc["staged"]:
        print(s["bundle"], os.path.basename(s["record"]), s["status"], s["unexplained_false_leaves"],
              "tools", s["tools_equal_v17"], "replay", s["replay"], "term", s["terminals"],
              "disc", [(c[0], c[2]) for c in s["per_commitment"]],
              {k: s[k] for k in ("full_preimage", "mask_cfs", "joint") if k in s})
    for r in doc["dd"]:
        print(os.path.basename(r["record"]), r["ok"], r["tools_equal_v17"])
    for k, v in doc["controls"].items():
        print(os.path.basename(k), v)
    for f in doc["failing_first"]:
        print("FF", os.path.basename(f["record"]), f["ok"], len(f["pins_that_moved"] or []))


if __name__ == "__main__":
    main(sys.argv[1])

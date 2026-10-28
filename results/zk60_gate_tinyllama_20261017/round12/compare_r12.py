#!/usr/bin/env python3
"""[gate round 12] The DETERMINISTIC figures of the gate records on the ten
frozen-r9 re-captures, against the records of the same capture name on the
frozen-r7 captures (token gate: gate round 7, tools v10; NL-1, surjection,
calibration: gate round 10, tools v12 / v16).  Reads JSON only.

Compared: every figure that does not depend on the run's randomness --
statuses and verdicts, replay counts, hashed columns and bytes, every
commitment's (role, class, stage kind, rows, data rows, disclosed and
expected dimension, claims, groups, k0, rank of P1, reserved pairs used,
reserved mask rows), the G-3 functionals and recomputed mask entries per
stage, the computed joint and its word pairs, the full preimage's
commitments, salted leaves and differing entries, the terminal slot counts,
the block-stage terminal parts, the controls fired / not applicable, NL-1's
summary, the surjection summary and TS-1's disclosed figures, and the
absorbed calibration word.  NOT compared (they depend on the opened
columns or are wall clock): view entries compared, distinct opened columns,
pad margins, timings.
    python3 compare_r12.py <out.json>
"""
import json
import os
import sys

E = "/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017"
CAPS = ["tinyllama-t32-L1-dense-pt1", "tinyllama-t32-L1-fixed-pt1", "tinyllama-t32-L2-dense-pt1",
        "tinyllama-t32-L2-fixed-pt1", "tinyllama-t32-L22-dense-pt1", "tinyllama-t32-L22-fixed-pt1",
        "llama3-8b-t32-L1-dense-pt1", "llama3-8b-t32-L1-fixed-pt1", "llama3-8b-t32-L2-dense-pt1",
        "llama3-8b-t32-L2-fixed-pt1"]


def L(p):
    with open(p) as fh:
        return json.load(fh)


def gate_figures(r):
    pcs = r["G1_per_commitment"]["per_commitment"]
    keys = ("role", "class", "stage_kind", "rows", "data_rows", "disclosed_dimension",
            "expected_disclosed_dimension", "claims", "groups", "k0", "rank_P1",
            "reserved_pairs_used", "reserved_mask_rows")
    g3 = r["G3_mask_cfs"]["per_stage"]
    tb = r["terminals_block_stages"]
    ti = tb.get("terminal_identity") or {}
    ctl = r["controls"]
    return {
        "status": r["status"], "false_parts": r["false_parts"], "blocks": r["blocks"], "stages": r["stages"],
        "replay": {k: r["replay"][k] for k in ("challenges_checked", "positions_checked", "final_counter",
                                                 "run_binding_reproduced", "stages")},
        "hash_layer": {k: r["hash_layer"][k] for k in ("bytes_hashed", "columns_checked", "columns_authenticated")},
        "per_commitment": [[p.get(k) for k in keys] for p in pcs],
        "G3": [[s.get("stage"), s.get("stage_kind"), s.get("functional_values"), s.get("functionals_re_derived"),
                s.get("entries_recomputed"), s.get("entries_differing"), s.get("ok")] for s in g3],
        "G1_joint": {k: r["G1_joint"][k] for k in ("identified_word_pairs", "joint_disclosed_fp", "sum_of_parts_fp",
                                                     "joint_equals_sum_of_parts")},
        "full_preimage": {"commitments": len(r["full_preimage"].get("commitments") or []),
                          "salted_leaves_authenticated": r["full_preimage"]["salted_leaves_authenticated"],
                          "view_entries_differing": r["full_preimage"]["view_entries_differing"]},
        "joint_preimage": r["joint_preimage"].get("all_four_couplings_respected"),
        "terminals_new_slots": [r["terminals_new_slots"].get("slots_checked"), r["terminals_new_slots"].get("slots_equal")],
        "NL1_new_slots": [r["NL1_new_slots"].get("slots_checked"), r["NL1_new_slots"].get("slots_with_premises")],
        "terminals_block_stages": {"every_block_slot_equal": tb.get("every_block_slot_equal"), "parts": tb.get("parts"),
                                   "terminal_identity": {k: v for k, v in ti.items() if not isinstance(v, (dict, list))},
                                   "controls_fire": {k: (v.get("ok") if isinstance(v, dict) else v)
                                                     for k, v in (tb.get("controls") or {}).get("controls", {}).items()}},
        "G_items_ok": {k: (r[k].get("ok") if isinstance(r[k], dict) else r[k])
                       for k in ("G2_claim_points", "G4_support_tables", "G5_tab_width", "G6_endpoints")},
        "controls": {"entries": len(ctl["controls"]), "not_applicable": sorted(ctl["not_applicable"]),
                     "not_fired": sorted(ctl["not_fired"]), "all_fire": ctl.get("all_fire")},
    }


def nl_figures(r):
    return {"status": r["status"], "summary": r["summary"]}


def ts_figures(r):
    rows = r["controls"]["TS_1_pair_removed_on_token_roles"]["rows"]
    out = {"summary": r["summary"], "controls_ok": r["controls"]["ok"],
           "TS_1": [[x["role"], x["stage"], x["group"], x["honest_disclosed_Fp"], x["pair_removed_disclosed_Fp"],
                     x["fires"]] for x in rows]}
    rv = r["controls"].get("review_controls_on_block_A")
    if rv:
        out["review_controls"] = {"ok": rv["ok"], "fires": rv["fires"],
                                  "rows": [[x["control"], x["expected_rank"], x["rank_blinding_plus_data"],
                                            x["disclosed_Fp"], x["fires"]] for x in rv["rows"]]}
    return out


def diff(a, b):
    return {k: {"r9": a[k], "r7": b[k]} for k in a if a.get(k) != b.get(k)}


def main(out):
    res, every = [], True
    for c in CAPS:
        row = {"capture": c}
        pairs = [
            ("token_gate", f"{E}/round12/gate/r9-tokengate-{c}.json", f"{E}/token_io/v10/token-v10-{c}.json", gate_figures),
            ("nl1", f"{E}/round12/nl/r9-nl-{c}.json", f"{E}/round10/nl/nl-{c}.json", nl_figures),
            ("surjection", f"{E}/round12/ts/r9-ts-{c}.json", f"{E}/round10/ts/ts-{c}.json", ts_figures),
        ]
        if c.startswith("tinyllama-t32-L1-"):
            pairs.append(("surjection_block", f"{E}/round12/ts/r9-ts-block-{c}.json",
                          f"{E}/round10/ts/ts-block-{c}.json", ts_figures))
        for kind, new, old, f in pairs:
            if not (os.path.exists(new) and os.path.exists(old)):
                row[kind] = {"missing": [p for p in (new, old) if not os.path.exists(p)]}
                every = False
                continue
            a, b = f(L(new)), f(L(old))
            d = diff(a, b)
            row[kind] = {"equal": not d, "differing": d, "r9": a if kind == "token_gate" else None}
            every &= not d
        res.append(row)
    # the absorbed calibration words
    cal_new = {x["bundle"]: x for x in L(f"{E}/round12/cal/r9-cal-all.json")["captures"]}
    cal_old = {x["bundle"]: x for x in L(f"{E}/round10/cal/v16-cal-all.json")["captures"]}
    cal = []
    for c in CAPS:
        a, b = cal_new.get(c), cal_old.get(c)
        eq = bool(a and b and a["ok"] and b["ok"] and a["absorbed_calibration"] == b["absorbed_calibration"]
                  and a["controls_ok"] and b["controls_ok"])
        every &= eq
        cal.append({"capture": c, "r9_ok": a and a["ok"], "word_r9": a and a["absorbed_calibration"],
                    "word_r7": b and b["absorbed_calibration"], "equal": eq})
    doc = {"what": __doc__.strip().splitlines()[0], "privacy_acceptance": False,
           "every_deterministic_figure_equal": every, "per_capture": res, "calibration": cal}
    with open(out, "w") as fh:
        json.dump(doc, fh, indent=1)
    for row in res:
        print(row["capture"], {k: (v.get("equal") if "equal" in v else v) for k, v in row.items() if k != "capture"})
        for k, v in row.items():
            if isinstance(v, dict) and v.get("differing"):
                print("   ", k, json.dumps(v["differing"])[:600])
    for x in cal:
        print("cal", x["capture"], x["equal"], (x["word_r9"] or "")[:16])
    print("every deterministic figure equal:", every)


if __name__ == "__main__":
    main(sys.argv[1])

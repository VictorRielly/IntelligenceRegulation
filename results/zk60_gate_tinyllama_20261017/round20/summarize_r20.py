#!/usr/bin/env python3
"""[gate round 20] One summary of the round's records (frozen tools v23 on token frozen-r17's
captures WITH public-table values: the REAL Shieldstral moderate-hate capture and the r17 R13 rung
capture), and the comparisons the brief asks for:

* LIMIT 1 on the real capture: all 23 block slots in every one of the 26 block stages (none open,
  the captured statement tables taken, their structure details), every other part round 19 checked;
* LIMIT 2 on the real capture: the full zero-data preimage over ALL commitments (none sampled);
* the real record against round 19's real record (moderate-sexual, no table values, sampled
  preimage): the same disclosure per commitment kind, the block slots 11 -> 23;
* the published /3 statement of the hate run: keys, the length fields re-derived, and its input
  root = the capture's;
* the failing-first records and the suites.

Reads JSON / logs only (the guard's own `*.guard.json` records are skipped).

    python3 summarize_r20.py <out.json>
"""
import glob
import json
import os
import re
import sys

E = "/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017"
P = E + "/round20"
CAP = "/home/victor/zk60-artifacts/token-io/captures"
MAN = {l.split()[1].split("/")[-1]: l.split()[0] for l in open(E + "/gate-tinyllama.tools.frozen.v23.sha256")}
REAL = "classify-r13-shield-t128-cli-hate-r17-values"
R19_REAL = E + "/round19/v22/v22-classify-r13-shield-t128-cli-sexual-r16b.json"
HATE_STATEMENT = "/home/victor/zk60-artifacts/token-io/r16-runs/hate-run/statement/statement.json"
sys.path.insert(0, E + "/round19")
import summarize_r19 as S19  # noqa: E402  (its /3 key classes, READ in round 19)


def L(p):
    with open(p) as fh:
        return json.load(fh)


def row(p):
    d = L(p)
    if d.get("status") == "REFUSED":
        return {"record": os.path.relpath(p, E), "bundle": d["bundle"], "status": "REFUSED",
                "refusal": d.get("refusal"), "seconds": d.get("total_seconds")}
    t = d["terminals_classifier_slots"]
    tb = d["terminals_block_stages"]
    s3 = d["G1_per_commitment"]
    fp = d.get("full_preimage") or {}
    po = d["public_outputs"]
    per_stage = tb.get("per_stage", [])
    return {
        "record": os.path.relpath(p, E), "bundle": d["bundle"], "status": d["status"], "false_parts": d["false_parts"],
        "declared_limits": d.get("declared_limits"),
        "tools_equal_v23": all(MAN.get(os.path.basename(k)) == v for k, v in (d.get("tool_sha256") or {}).items()),
        "blocks": d["blocks"], "policy": po["policy"], "verdict": po["verdict"], "c": po["c"], "chunk": po["chunk"],
        "n": po.get("n"), "item_length": po.get("item_length"), "pad_positions": po.get("pad_positions"),
        "verdict_row": po.get("verdict_row"), "pad_id": po.get("pad_id"), "short_item": po.get("short_item"),
        "source_pins": d["integrity"]["source_pins"], "source_pin_status": d["integrity"].get("source_pin_status"),
        "replay": [d["replay"]["challenges_checked"], d["replay"]["positions_checked"], d["replay"]["run_binding_reproduced"]],
        "hash_layer": d.get("hash_layer"),
        "classifier_slots": [t["slots_equal"], t["slots_checked"]],
        "public_tables_rebuilt_taken": [t.get("public_tables_rebuilt"), t.get("public_tables_taken")],
        "block_stage_gates": d["integrity"].get("r13_stage_gates"),
        "block_tables_absent_by_capture_option": tb.get("tables_absent_by_capture_option"),
        "block_stage_slots": [[x.get("slot_checks_equal"), x.get("slot_checks_expected")] for x in per_stage],
        "block_stages_all_23": bool(per_stage) and all(x.get("slot_checks_equal") == 23 == x.get("slot_checks_expected")
                                                       and not x.get("open_by_capture_option") and x.get("ok")
                                                       for x in per_stage),
        "block_stages_evaluated": len(per_stage), "blocks_not_evaluated": tb.get("blocks_not_evaluated"),
        "captured_tables_per_stage": sorted({len(x.get("captured_tables") or []) for x in per_stage}),
        "structure_failures": sorted({f for x in per_stage for f in (x.get("structure_failures") or [])}),
        "group_factor_ok_all": all(x.get("group_factor_ok") for x in per_stage) if per_stage else None,
        "group_column_groups_per_stage": [[(g or {}).get("groups_used") for g in ((x.get("structure_detail_r13") or {}).get("group_column") or [])]
                                          for x in per_stage],
        "act3_groups_per_stage": [[(g or {}).get("groups") for g in ((x.get("structure_detail_r13") or {}).get("act3_values") or [])]
                                  for x in per_stage],
        "block_controls": {k: v.get("fires") for k, v in (tb.get("controls") or {}).items() if isinstance(v, dict)},
        "per_commitment": [[r["role"], r["rows"], r["claims"], r["groups"], r["disclosed_dimension"], r["expected_disclosed_dimension"]]
                           for r in s3["per_commitment"]],
        "commitments": len(s3["per_commitment"]),
        "cfs": [[x["stage_kind"], x["entries_recomputed"], x["entries_differing"]] for x in d["G3_mask_cfs"]["per_stage"]],
        "joint": [d["G1_joint"]["identified_word_pairs"], d["G1_joint"]["joint_disclosed_fp"], d["G1_joint"]["joint_equals_sum_of_parts"]],
        "full_preimage": {"commitments": fp.get("commitments") if not isinstance(fp.get("commitments"), list) else len(fp["commitments"]),
                          "entries_compared": fp.get("view_entries_compared"), "entries_differing": fp.get("view_entries_differing"),
                          "salted_leaves_authenticated": fp.get("salted_leaves_authenticated"),
                          "sampled": fp.get("sampled_commitments"), "not_evaluated": fp.get("not_evaluated"), "ok": fp.get("ok")},
        "joint_preimage": (d.get("joint_preimage") or {}).get("all_four_couplings_respected"),
        "joint_preimage_c4": ((d.get("joint_preimage") or {}).get("couplings") or {}).get("C4_the_terminal_identity"),
        "B3": d["B3_margin_vector"]["ok"],
        "B3_derived": {k: (d["B3_margin_vector"].get("derived") or {}).get(k) for k in
                       ("recorded_vs_derived", "checkpoint_sha256", "emb_digest", "w_sha256", "seconds")},
        "one_public_bit": d["one_public_bit"]["ok"], "D41": d["D41"]["ok"],
        "NL1": [d["NL1_classifier_slots"]["slots_with_premises"], d["NL1_classifier_slots"]["slots_checked"]],
        "bout_claim_row": d["integrity"].get("bout_claim_row", {}).get("row"),
        "controls_fired": sorted(k for k, v in d["controls"].items() if isinstance(v, dict) and v.get("fires")),
        "controls_not_applicable": sorted(k for k, v in d["controls"].items() if isinstance(v, dict) and v.get("fires") is None),
        "controls_not_fired": d["controls"].get("not_fired"),
        "timings": d.get("timings"), "seconds": d["total_seconds"], "peak_rss_mb": d.get("peak_rss_mb"),
    }


def kinds(per_commitment):
    """disclosed dimension per commitment KIND (A@k / H@k / B k / stage roles), as sets"""
    out = {}
    for role, _r, _c, _g, disc, exp in per_commitment:
        k = re.sub(r"@\d+$", "@k", role)
        k = re.sub(r"^B\d+$", "Bk", k)
        out.setdefault(k, set()).add((disc, exp))
    return {k: sorted(v) for k, v in sorted(out.items())}


def statement_check(path, cap_name):
    st = L(path)
    classified = {k.split(" ")[0] for v in S19.STATEMENT_V3_KEYS.values() for k in v}
    p0_, s_, n_, t_ = len(st["template_prefix_ids"]), len(st["template_suffix_ids"]), st["content_length_n"], st["T"]
    run = L(os.path.join(CAP, cap_name, "run.json"))["classify"]
    root = bytes(run["input_root"]).hex()
    out = {"statement": path, "schema": st["schema"], "keys": len(st), "keys_not_classified": sorted(set(st) - classified),
           "policy": st["policy"], "P0": p0_, "n": n_, "S": s_, "T": t_,
           "item_length_is_P0_n_S": st["item_length"] == p0_ + n_ + s_,
           "pad_positions_is_T_minus_item": st["pad_positions"] == t_ - st["item_length"],
           "verdict_row_is_item_minus_1": st["verdict_row"] == st["item_length"] - 1,
           "pad_id_is_the_registered_policy_s": st["pad_id"] == 11,
           "input_root_equals_the_capture_s": st["input_token_endpoint_root"] == root,
           "identity": st["trained_statement_identity"], "verdict": st["verdict"]}
    out["ok"] = (not out["keys_not_classified"] and out["item_length_is_P0_n_S"] and out["pad_positions_is_T_minus_item"]
                 and out["verdict_row_is_item_minus_1"] and out["pad_id_is_the_registered_policy_s"]
                 and out["input_root_equals_the_capture_s"])
    return out


def suite(log):
    if not os.path.exists(log):
        return None
    txt = open(log).read()
    m = re.findall(r"Ran (\d+) tests? in ([\d.]+)s", txt)
    return {"log": os.path.relpath(log, E), "ran": int(m[-1][0]) if m else None, "seconds": float(m[-1][1]) if m else None,
            "ok": bool(re.search(r"^OK", txt, re.M)) and "FAILED" not in txt}


def main(out):
    rows = [row(p) for p in sorted(glob.glob(P + "/v23/v23-*.json")) if not p.endswith(".guard.json")]
    by = {r["bundle"]: r for r in rows}
    doc = {"what": __doc__.strip().splitlines()[0], "privacy_acceptance": False, "records": rows,
           "tools_v23_manifest_sha256": "64f4b7572674caef31d21da014869b119a58b186418174ad97d21400f7440230"}
    real = by.get(REAL)
    if real and real["status"] != "REFUSED":
        doc["limit_1_closed"] = (real["block_stages_all_23"] and real["block_stages_evaluated"] == 26
                                 and real["block_tables_absent_by_capture_option"] is False
                                 and not real["structure_failures"])
        doc["limit_2_closed"] = (real["full_preimage"]["ok"] is True and real["full_preimage"]["sampled"] is None
                                 and real["full_preimage"]["commitments"] == real["commitments"]
                                 and real["full_preimage"]["entries_differing"] == 0)
        doc["real_status_without_declared_limits"] = real["status"] == "PASS" and not real["declared_limits"]
        if os.path.exists(R19_REAL):
            r19 = S19.row(R19_REAL)
            doc["real_vs_round19_real"] = {
                "round19": {"bundle": r19["bundle"], "status": r19["status"], "block_stage_slots": sorted({tuple(x) for x in r19["block_stage_slots"]}),
                            "full_preimage": r19["full_preimage"]},
                "round20": {"bundle": real["bundle"], "status": real["status"], "block_stage_slots": sorted({tuple(x) for x in real["block_stage_slots"]}),
                            "full_preimage": real["full_preimage"]},
                "disclosed_per_kind_round19": kinds(r19["per_commitment"]),
                "disclosed_per_kind_round20": kinds(real["per_commitment"]),
                "disclosed_per_kind_equal": kinds(r19["per_commitment"]) == kinds(real["per_commitment"]),
                "commitments": [len(r19["per_commitment"]), real["commitments"]],
                "rows_claims_groups_equal_per_block_commitment": [x[:4] for x in r19["per_commitment"] if x[0].startswith(("A@", "H@", "B"))]
                == [x[:4] for x in real["per_commitment"] if x[0].startswith(("A@", "H@", "B"))],
                "why_stage_commitments_may_differ": "the policies' templates differ (P0 72 sexual / 78 hate), so stage IN-C's "
                                                    "and OUT-C's row positions differ; the block stages are the same shape"}
        if os.path.exists(HATE_STATEMENT):
            doc["statement_v3_check_real_hate"] = statement_check(HATE_STATEMENT, REAL)
    for nm in sorted(glob.glob(P + "/ff/*.json")):
        if not nm.endswith(".guard.json"):
            doc[os.path.relpath(nm, P)] = L(nm)
    ffg = P + "/ff/ff-v22-gate-r17-rung.log"
    if os.path.exists(ffg):
        txt = open(ffg).read()
        doc["ff_v22_whole_gate_on_r17_log"] = {"keyerror": "KeyError" in txt, "traceback": "Traceback" in txt,
                                               "tail": txt.strip().splitlines()[-4:]}
    doc["suites"] = {"frozen": suite(P + "/suite/unittests-v23-frozen.log"),
                     "working_copy": suite(P + "/suite/unittests-v23-working-copy.log")}
    doc["all_pass"] = bool(rows) and all(r["status"] in ("PASS", "PASS-WITH-DECLARED-LIMITS") for r in rows)
    with open(out, "w") as fh:
        json.dump(doc, fh, indent=1, default=str)
    for r in rows:
        if r["status"] == "REFUSED":
            print(r["bundle"], "REFUSED", r["refusal"])
            continue
        print(r["bundle"], r["status"], r["false_parts"], r["declared_limits"], "v", r["verdict"], "n", r["n"],
              "slots", r["classifier_slots"], "blocks", sorted({tuple(x) for x in r["block_stage_slots"]}), r["block_stages_evaluated"],
              "taken", r["public_tables_rebuilt_taken"], "cap/stage", r["captured_tables_per_stage"],
              "disc", sorted({(x[0][:2], x[4]) for x in r["per_commitment"]}), "fp", r["full_preimage"]["commitments"],
              r["full_preimage"]["entries_compared"], r["full_preimage"]["entries_differing"],
              "ctl", len(r["controls_fired"]), r["controls_not_applicable"], r["controls_not_fired"], r["seconds"], "s",
              r["peak_rss_mb"], "MB")
    for k in ("limit_1_closed", "limit_2_closed", "real_status_without_declared_limits", "all_pass"):
        print(k, doc.get(k))
    if "real_vs_round19_real" in doc:
        print("disclosed per kind equal to round 19:", doc["real_vs_round19_real"]["disclosed_per_kind_equal"])
    if "statement_v3_check_real_hate" in doc:
        print("statement /3:", doc["statement_v3_check_real_hate"]["ok"])
    print("suites:", doc["suites"])


if __name__ == "__main__":
    main(sys.argv[1])

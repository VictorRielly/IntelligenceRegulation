#!/usr/bin/env python3
"""[gate round 19] One summary of the round's records (frozen tools v22 on
the R13-stack classifier captures of token frozen-r16b: the R13 h24 rung and the real Shieldstral T128 capture), and the
comparisons the brief asks for:

* cross-verdict: at one L, the randomness-free figures of the v0 / v1 / vtie
  captures must be equal (the verdict moves nothing but its public bit);
* short vs full: a short item (20 ids, 3 pad positions) against the
  full-length item at the same L and verdict: the same randomness-free
  figures, per-commitment disclosure equal, and the run.json `classify`
  facts differing only in public length fields (D45(1)) and run-random
  values;
* D41 over the two chunks of the 27-id item;
* the failing-first records; the /3 statement's keys classified [READ].

Reads JSON only.  The guard's own records (`*.guard.json`) are skipped
(round 17's KeyError, fixed up front).

    python3 summarize_r19.py <out.json>
"""
import glob
import json
import os
import sys

E = "/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017"
P = E + "/round19"
CAP = "/home/victor/zk60-artifacts/token-io/captures"
MAN = {l.split()[1].split("/")[-1]: l.split()[0] for l in open(E + "/gate-tinyllama.tools.frozen.v22.sha256")}

# [READ] classify_cli.rs:323-385 at frozen-r14 (render): every key of a
# `zk60-classify-run/3` statement and where its value comes from
STATEMENT_V3_KEYS = {
    "data-dependent, public by design": ["verdict", "verdict_bit"],
    "the content length and its pad layout (public: D45(1)); functions of (T, P0, S, n) and the policy's pad id":
        ["content_length_n", "chunk (index, count, range, content_total, chunk_size, overlap)", "item_length",
         "pad_id", "pad_positions", "verdict_row"],
    "binding to the post (D45(3)) and the run context": ["input_token_endpoint_root", "context", "context_label"],
    "public constants of the registered policy / profile / model": [
        "schema", "scope", "statement_written_by", "run_profile", "block_profile", "blocks", "export_variant",
        "trained_statement_identity", "policy", "threshold_c", "yes_id", "no_id", "template_prefix_ids",
        "template_suffix_ids", "T", "control_ids_below", "tokenizer", "margin_vector_digest", "margin_scale",
        "tied_source", "embedding_digest", "bos", "final_norm", "classifier_profile_digest", "rulings",
        "whole_run_floor_bits", "parameter_line"],
}


def L(p):
    with open(p) as fh:
        return json.load(fh)


def row(p):
    d = L(p)
    t = d["terminals_classifier_slots"]
    tb = d["terminals_block_stages"]
    s3 = d["G1_per_commitment"]
    fp = d.get("full_preimage") or {}
    po = d["public_outputs"]
    return {
        "record": os.path.relpath(p, E), "bundle": d["bundle"], "status": d["status"], "false_parts": d["false_parts"],
        "tools_equal_v22": all(MAN.get(os.path.basename(k)) == v for k, v in (d.get("tool_sha256") or {}).items()),
        "blocks": d["blocks"], "verdict": po["verdict"], "c": po["c"], "chunk": po["chunk"],
        "n": po.get("n"), "item_length": po.get("item_length"), "pad_positions": po.get("pad_positions"),
        "verdict_row": po.get("verdict_row"), "short_item": po.get("short_item"),
        "replay": [d["replay"]["challenges_checked"], d["replay"]["positions_checked"], d["replay"]["run_binding_reproduced"]],
        "classifier_slots": [t["slots_equal"], t["slots_checked"]],
        "public_tables_rebuilt_taken": [t.get("public_tables_rebuilt"), t.get("public_tables_taken")],
        "block_stage_slots": [[x.get("slot_checks_equal"), x.get("slot_checks_expected")] for x in tb.get("per_stage", [])],
        "block_stage_gates": d["integrity"].get("r13_stage_gates"),
        "block_tables_absent_by_capture_option": tb.get("tables_absent_by_capture_option"),
        "per_commitment": [[r["role"], r["rows"], r["claims"], r["groups"], r["disclosed_dimension"], r["expected_disclosed_dimension"]]
                           for r in s3["per_commitment"]],
        "cfs": [[x["stage_kind"], x["entries_recomputed"], x["entries_differing"], x.get("functional_values")] for x in d["G3_mask_cfs"]["per_stage"]],
        "joint": [d["G1_joint"]["identified_word_pairs"], d["G1_joint"]["joint_disclosed_fp"], d["G1_joint"]["joint_equals_sum_of_parts"]],
        "full_preimage": [fp.get("commitments") if not isinstance(fp.get("commitments"), list) else len(fp["commitments"]),
                          fp.get("view_entries_compared"), fp.get("view_entries_differing")],
        "joint_preimage": (d.get("joint_preimage") or {}).get("all_four_couplings_respected"),
        "B3": d["B3_margin_vector"]["ok"],
        "B3_derived": ((d["B3_margin_vector"].get("derived") or {}).get("recorded_vs_derived")),
        "one_public_bit": d["one_public_bit"]["ok"], "taken_tables": d["one_public_bit"].get("taken_tables"),
        "D41": d["D41"]["ok"],
        "NL1": [d["NL1_classifier_slots"]["slots_with_premises"], d["NL1_classifier_slots"]["slots_checked"]],
        "bout_claim_row": d["integrity"].get("bout_claim_row", {}).get("row"),
        "capture_format_notes": d.get("capture_format_notes"),
        "controls_fired": sorted(k for k, v in d["controls"].items() if isinstance(v, dict) and v.get("fires")),
        "controls_not_applicable": sorted(k for k, v in d["controls"].items() if isinstance(v, dict) and v.get("fires") is None),
        "controls_not_fired": d["controls"].get("not_fired"),
        "seconds": d["total_seconds"], "peak_rss_mb": d.get("peak_rss_mb"),
    }


RF_KEYS = ("replay", "classifier_slots", "public_tables_rebuilt_taken", "block_stage_slots", "per_commitment", "joint", "NL1")


def rf_equal(a, b):
    return all(a[k] == b[k] for k in RF_KEYS) and [x[:3] for x in a["cfs"]] == [x[:3] for x in b["cfs"]]


def classify_fact_diff(a_name, b_name):
    """the run.json `classify` facts of two captures: which keys differ"""
    a = L(os.path.join(CAP, a_name, "run.json"))["classify"]
    b = L(os.path.join(CAP, b_name, "run.json"))["classify"]
    diff = sorted(k for k in set(a) | set(b) if a.get(k) != b.get(k))
    sub = {}
    for k in diff:
        if isinstance(a.get(k), dict) and isinstance(b.get(k), dict):
            sub[k] = sorted(kk for kk in set(a[k]) | set(b[k]) if a[k].get(kk) != b[k].get(kk))
    pt_a, pt_b = a.get("profile_text", "").split(), b.get("profile_text", "").split()
    words = sorted({w for w in pt_a if w not in pt_b} | {w for w in pt_b if w not in pt_a})
    return {"keys_differing": diff, "subkeys_differing": sub, "profile_text_words_differing": words}


PUBLIC_LENGTH_WORDS = ("n=", "item-length=", "pad-positions=", "verdict-row=")
RUN_RANDOM_KEYS = {"input_root", "input_endpoint", "b_in", "b_out"}   # roots and statement digests over them


def main(out):
    rows = [row(p) for p in sorted(glob.glob(P + "/v22/v22-*.json")) if not p.endswith(".guard.json")]
    by = {r["bundle"]: r for r in rows}
    cross = {}
    for L_ in (1, 2):
        grp = [r for r in rows if r["blocks"] == L_ and r["chunk"]["count"] == 1 and not r["short_item"]
               and r["bundle"].startswith("classify-r13-rung-")]
        ref = grp[0] if grp else None
        cross[f"L{L_}"] = {"captures": [r["bundle"] for r in grp], "verdicts": [r["verdict"] for r in grp],
                           "randomness_free_figures_equal": bool(grp) and all(rf_equal(r, ref) for r in grp),
                           "compared": list(RF_KEYS) + ["cfs (stage, entries, differing)"]}
    # [coordinator ~03:05] the n sweep: at each n, v0 / v1 / vtie randomness-free figures equal
    cross_n = {}
    for n_ in (1, 11, 22):
        grp = [r for r in rows if r["blocks"] == 2 and r["n"] == n_ and r["bundle"].startswith("classify-r13-rung-")
               and r["short_item"]]
        if grp:
            cross_n[f"L2 n={n_}"] = {"captures": [r["bundle"] for r in grp], "verdicts": [r["verdict"] for r in grp],
                                     "randomness_free_figures_equal": all(rf_equal(r, grp[0]) for r in grp)}
    sf = {}
    for short, full in (("classify-r13-rung-L2-v1-short1", "classify-r13-rung-L2-v1"),
                        ("classify-r13-rung-L2-v1-short11", "classify-r13-rung-L2-v1"),
                        ("classify-r13-rung-L2-v1-short22", "classify-r13-rung-L2-v1"),
                        ("classify-r13-rung-L2-v0-short11", "classify-r13-rung-L2-v0"),
                        ("classify-r13-rung-L2-vtie-short11", "classify-r13-rung-L2-vtie"),
                        ("classify-r13-rung-L2-v0-short1", "classify-r13-rung-L2-v0")):
        if short in by and full in by:
            a, b = by[short], by[full]
            fd = classify_fact_diff(short, full)
            pub_words = all(any(w.startswith(x) for x in PUBLIC_LENGTH_WORDS) for w in fd["profile_text_words_differing"])
            other = [k for k in fd["keys_differing"] if k not in ("n", "chunk", "profile_text", "profile_digest",
                                                                   "stage_out_c_layout") and k not in RUN_RANDOM_KEYS]
            sf[f"{short} vs {full}"] = {
                "randomness_free_figures_equal": rf_equal(a, b),
                "per_commitment_disclosure_equal": [x[4] for x in a["per_commitment"]] == [x[4] for x in b["per_commitment"]],
                "per_commitment_rows_claims_groups_equal": [x[:4] for x in a["per_commitment"]] == [x[:4] for x in b["per_commitment"]],
                "disclosed_dimensions": sorted({(x[0], x[4]) for x in a["per_commitment"]}),
                "public_lengths": {"short": [a["n"], a["item_length"], a["pad_positions"], a["verdict_row"]],
                                   "full": [b["n"], b["item_length"], b["pad_positions"], b["verdict_row"]]},
                "classify_facts_diff": fd,
                "profile_text_differs_only_in_public_length_words": pub_words,
                "classify_keys_differing_beyond_length_and_run_random": other,
                "nothing_beyond_the_public_length_differs": pub_words and not other and rf_equal(a, b),
            }
    # the published /3 statement of the CLI short item: keys and the length fields re-derived
    st_chk = None
    stp = os.path.join(P, "cap", "real", "classify-r13-shield-t128-cli-sexual-r16b.statement.json")
    if os.path.exists(stp):
        st = L(stp)
        classified = {k.split(" ")[0] for v in STATEMENT_V3_KEYS.values() for k in v}
        p0_, s_, n_, t_ = len(st["template_prefix_ids"]), len(st["template_suffix_ids"]), st["content_length_n"], st["T"]
        st_chk = {"schema": st["schema"], "keys": sorted(st), "keys_not_classified": sorted(set(st) - classified),
                  "item_length_is_P0_n_S": st["item_length"] == p0_ + n_ + s_,
                  "pad_positions_is_T_minus_item": st["pad_positions"] == t_ - st["item_length"],
                  "verdict_row_is_item_minus_1": st["verdict_row"] == st["item_length"] - 1,
                  "pad_id_is_the_registered_policy_s": st["pad_id"] == 11,
                  "chunk": st["chunk"]}
        st_chk["ok"] = (not st_chk["keys_not_classified"] and st_chk["item_length_is_P0_n_S"]
                        and st_chk["pad_positions_is_T_minus_item"] and st_chk["verdict_row_is_item_minus_1"]
                        and st_chk["pad_id_is_the_registered_policy_s"])
    doc = {"what": __doc__.strip().splitlines()[0], "privacy_acceptance": False, "records": rows,
           "cross_verdict": cross, "cross_verdict_per_n": cross_n, "short_vs_full": sf,
           "statement_v3_check_real_shieldstral": st_chk,
           "statement_v3_key_classes_READ": STATEMENT_V3_KEYS,
           "all_pass": bool(rows) and all(r["status"] in ("PASS", "PASS-WITH-DECLARED-LIMITS") for r in rows),
           "statuses": sorted({(r["bundle"], r["status"]) for r in rows})}
    for nm in sorted(glob.glob(P + "/ff/*.json") + glob.glob(P + "/d41/*.json")):
        if not nm.endswith(".guard.json"):
            doc[os.path.relpath(nm, P)] = L(nm)
    with open(out, "w") as fh:
        json.dump(doc, fh, indent=1, default=str)
    for r in rows:
        print(r["bundle"], r["status"], r["false_parts"], "v", r["verdict"], "n", r["n"], "slots", r["classifier_slots"],
              r["block_stage_slots"], "taken", r["public_tables_rebuilt_taken"],
              "disc", sorted({(x[0], x[4]) for x in r["per_commitment"]}), "fp", r["full_preimage"],
              "ctl", len(r["controls_fired"]), r["controls_not_applicable"], r["controls_not_fired"], r["seconds"], "s")
    print("cross:", json.dumps(cross))
    print("cross per n:", json.dumps({k: v["randomness_free_figures_equal"] for k, v in cross_n.items()}))
    print("statement /3:", None if st_chk is None else (st_chk["ok"], st_chk["keys_not_classified"]))
    print("short vs full:", json.dumps({k: {kk: v[kk] for kk in ("randomness_free_figures_equal", "per_commitment_disclosure_equal",
                                                                  "nothing_beyond_the_public_length_differs")} for k, v in sf.items()}))
    print("all pass:", doc["all_pass"])


if __name__ == "__main__":
    main(sys.argv[1])

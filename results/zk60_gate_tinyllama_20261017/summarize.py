#!/usr/bin/env python3
"""Read the gate's records for the trained TinyLlama bundles and print the
figures of the five-step table, each beside the prediction written before
the run.  Reads JSON only; computes nothing about the bundles.

    python3 summarize.py <record.json> [<record.json> ...]
"""

import json
import sys


def g(o, *path, default=None):
    for k in path:
        if o is None:
            return default
        if isinstance(k, int):
            o = o[k] if isinstance(o, list) and len(o) > k else None
        else:
            o = o.get(k) if isinstance(o, dict) else None
    return o if o is not None else default


def summarize(path):
    r = json.load(open(path))
    out = {"record": path.split("/")[-1], "bundle": r.get("bundle"),
           "ok": r.get("ok"), "total_seconds": r.get("total_seconds"),
           "peak_rss_mb": r.get("peak_rss_mb")}
    out["timings"] = {t["stage"]: (t["seconds"], t["peak_rss_mb_after"],
                                   t["raised"]) for t in r.get("timings", [])}
    s1 = r.get("stage1_integrity")
    if s1:
        out["P1"] = dict(ok=s1.get("ok"), findings=len(s1.get("findings", [])),
                         blocks=s1.get("blocks"), boundaries=s1.get("boundaries"),
                         roots=s1.get("distinct_roots_opened"),
                         twice=s1.get("any_root_opened_twice"),
                         manifest_files=s1.get("manifest_files_checked"))
        out["pins_ok"] = g(r, "run_layer_source_pins", "ok")
        out["shared_pins_ok"] = g(r, "run_layer_source_pins", "shared_files", "ok")
    s2 = r.get("stage2_transcript_replay")
    if s2:
        out["P2"] = dict(ok=s2.get("ok"), positions=s2.get("positions_checked"),
                         challenges=s2.get("challenges_checked"),
                         final_counter=s2.get("final_counter"),
                         binding=s2.get("run_binding_reproduced"),
                         tags_ok=all(t["start_tag_ok"] and t["end_tag_ok"]
                                     for t in s2.get("segment_position_tags", [])),
                         failures=len(s2.get("failures", [])))
    s9 = r.get("stage9_hash_layer")
    if s9:
        out["P3"] = dict(ok=s9.get("ok"), openings=s9.get("openings"),
                         columns=s9.get("columns_checked"),
                         authenticated=s9.get("columns_authenticated"),
                         bytes=s9.get("bytes_hashed"),
                         distinct_salted_leaves=s9.get("distinct_salted_leaves"),
                         wrong_rules_reaching_root=g(s9, "cross_rule_probe",
                                                     "wrong_rules_that_reached_the_root"))
    s8 = r.get("stage8_plane_index_and_terminals")
    if s8 and "terminal_identity" in s8:
        ti = s8["terminal_identity"]
        out["P4"] = dict(ok=ti.get("ok"), equal=ti.get("slot_checks_equal"),
                         expected=ti.get("slot_checks_expected"),
                         matching_stored=ti.get(
                             "slot_checks_matching_the_stored_terminal_polynomial"),
                         open=len(ti.get("open_slots", [])),
                         group=g(ti, "bilinear_group_factor", "definition_in_force"),
                         tables_digest_checked=g(s8, "carried_public_tables",
                                                 "digest_checked"),
                         structure_checks=ti.get("public_table_structure_checks"),
                         structure_failures=len(ti.get(
                             "public_table_structure_failures", [])),
                         channel=s8.get("channel_status"),
                         controls_ok=g(s8, "controls", "ok"),
                         controls_not_fired=g(s8, "controls",
                                              "controls_that_did_not_fire"))
    s3 = r.get("stage3_per_commitment")
    if s3 and "per_commitment" in s3:
        pcs = {}
        for c in s3["per_commitment"]:
            pcs[c["role"]] = dict(rows=c["rows"], data=c["data_rows"],
                                  claims=c["claims"], groups=c["groups"],
                                  disclosed=c["disclosed_dimension"],
                                  rank_P1=c.get("rank_P1"), k0=c.get("k0"),
                                  non_data=c.get("non_data_rows"),
                                  excl=g(c, "exclusivity", "clauses_passed"),
                                  distinct_cols=c.get("distinct_opened_columns"),
                                  meets=c.get("meets_expectation"))
        out["P5"] = pcs
        out["P5_M"] = [(m["commitment"], m["disclosed_dimension"])
                       for m in s3.get("masking_commitments", [])]
        out["P5_exclusivity_controls"] = g(s3, "exclusivity_controls", "all_fire")
        out["P5_hpad"] = g(s3, "pad_block_exact_rank_cross_check")
        if out["P5_hpad"]:
            out["P5_hpad"] = {k: out["P5_hpad"][k] for k in
                              ("commitment", "distinct_columns",
                               "exact_rank_of_the_pad_block", "full_rank")}
    s4 = r.get("stage4_the_boundary")
    if s4 and "whole_run" in s4:
        w = s4["whole_run"]
        out["P6"] = dict(ok=s4.get("ok"), matrix=w.get("matrix"),
                         generators=w.get("generators"),
                         identified=w.get("identified_rows"),
                         joint=w.get("joint_fp"), parts=w.get("sum_of_parts_fp"),
                         equal=w.get("joint_equals_sum_of_parts"),
                         k0=g(w, "joint_detail", "k0"),
                         u_star=g(w, "joint_detail", "u_row_detail",
                                  "extra_dimension_beyond_k0"))
        pb = []
        for b in s4.get("per_boundary", []):
            rr = b.get("restricted_to_the_reserved_rows", {})
            tr = b.get("three_roles_of_the_plane", {})
            pb.append(dict(rank=rr.get("rank_on_the_reserved_block"),
                           generators=rr.get("generators"),
                           disclosed=rr.get("disclosed_on_the_reserved_block_fp"),
                           three_role=(tr.get("matrix"), tr.get("joint_fp"),
                                       tr.get("sum_of_parts_fp"))))
        out["P6_boundaries"] = pb
    s5 = r.get("stage5_zero_data_preimage")
    if s5 and "per_commitment" in s5:
        out["P7"] = [(c["commitment"], c["preimage_exhibited"],
                      c.get("free_fp_per_position"),
                      g(c, "verification", "message_entries_differing"))
                     for c in s5["per_commitment"]]
    s11 = r.get("stage11_full_preimage")
    if s11 and s11.get("requested"):
        out["P9"] = {k: s11.get(k) for k in s11 if k in (
            "ok", "entries_checked", "entries_differing", "commitments_exhibited",
            "salted_leaves_checked", "salted_leaves_differing",
            "commitments_requested")}
        out["P9_controls"] = g(s11, "controls", "ok")
        out["P9_keys"] = sorted(s11.keys())
    s12 = r.get("stage12_mask_and_cfs")
    if s12 and s12.get("requested"):
        out["P8_keys"] = sorted(s12.keys())
        out["P8_ok"] = s12.get("ok")
    s13 = r.get("stage13_joint_run_preimage")
    if s13 and s13.get("requested"):
        out["P10_keys"] = sorted(s13.keys())
        out["P10_ok"] = s13.get("ok")
    s6 = r.get("stage6_negative_controls")
    if s6:
        out["P11"] = {k: (v.get("ok") if isinstance(v, dict) else v)
                      for k, v in s6.items()}
    s7 = r.get("stage7_channels")
    if s7:
        out["P12"] = dict(total=s7.get("total"), counts=s7.get("counts"),
                          grading_failures=s7.get("grading_failures"))
    return out


if __name__ == "__main__":
    for p in sys.argv[1:]:
        print(json.dumps(summarize(p), indent=1, default=str))

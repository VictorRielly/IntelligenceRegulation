#!/usr/bin/env python3
"""D60 privacy gate (2026-11-02): one block of lines per Python D55 gate record in
results/zk60_d60_20261102/privacy_gate/records/ (the figures README.md quotes)."""
import glob
import json
import os
import sys

E = os.path.join(os.path.dirname(os.path.abspath(__file__)), "records")
paths = sys.argv[1:] or sorted(glob.glob(os.path.join(E, "*.json")))
for path in paths:
    r = json.load(open(path))
    print(f"== {os.path.basename(path)}: {r.get('status')} ({r.get('seconds')} s, peak {r.get('peak_rss_mb')} MB) family {r.get('family')}")
    print("   parts", {k: v for k, v in r.get("parts", {}).items()})
    f = r.get("D55-1/2 facts") or {}
    print("   profile", f.get("run_profile"), "| base", f.get("d55_base_run_profile"), "| registered", f.get("run_profile_is_registered"))
    print("   geometry", f.get("pcs_geometry"), "| schedule digest equal", (f.get("d55_schedule_digest") or {}).get("equal"))
    rp = r.get("D55-3 replay") or {}
    print("   replay positions", rp.get("positions_checked"), "challenges", rp.get("challenges_checked"), "failures", len(rp.get("failures", [])),
          "binding", rp.get("run_binding_reproduced", rp.get("run_binding_ok")), "s0", rp.get("s0_tag_reproduced"), "s1", rp.get("s1_reproduced"),
          "tail end", rp.get("tail_end_tag_reproduced"), "tail openings", rp.get("tail_openings_replayed"))
    h = r.get("R13-H registered header")
    if h:
        print("   header: parameter line recomputed", h.get("parameter_line_recomputed"), "| schedule", h["schedule_digest"]["equal"],
              "| binding by replay", h.get("run_binding_reproduced_by_the_replay"), "| findings", h.get("findings"))
        print("   header controls", {k: v.get("fires") for k, v in (h.get("controls") or {}).items() if isinstance(v, dict)})
    t = r.get("R13-3 terminals")
    if t:
        for p in t["per_fork"]:
            print(f"   fork {p['fork']}: G {p['gate_shift_recovered']} (closing {p['gate_values_closing_sc_fzc']}), slots {p['slot_checks_equal']}/{p['slot_checks_expected']},"
                  f" captured tables {len(p.get('captured_tables') or [])}, rebuilt {p.get('rebuilt_tables')}, struct fail {len(p.get('structure_failures') or [])},"
                  f" digest fail {len(p.get('digest_failures') or [])}, group {p.get('group_factor_ok')}, {p['seconds']} s")
        print("   R13 controls", {k: v.get("fires") for k, v in t["controls"].items() if isinstance(v, dict)}, "on fork", t["controls"].get("on_fork"))
        print("   terminal-port pins ok", t["source_pins"]["ok"], "moved", [m.split(":")[0] for m in t["source_pins"]["pins_that_moved"]],
              "| argument.rs reading added / removed", t["argument_rs_reading"]["added_in_memory"] != [], t["argument_rs_reading"]["removed_after"])
    s3 = r.get("R13-6 per commitment") or r.get("W16-6 per commitment") or {}
    for row in s3.get("per_commitment", []):
        print(f"   {row['role']:9s} {row['commitment_kind']:18s} rows {row['rows']:5d} data {row['data_rows']:5d} disclosed {row['disclosed_dimension']} (want {row['expected_disclosed_dimension']})"
              f" distinct {row['distinct_columns']}/{row['sampled_columns']} pads {row['q_pad']} margin {row['pad_margin']}"
              f" minor {row['certifying_minor'].get('full_row_rank')}/{row['certifying_minor'].get('determinant_nonzero')} hyp {all(row['reduction_hypotheses'].values())}")
    for m in s3.get("masking_commitments", []):
        print(f"   {m['commitment']:9s} M rows {m['rows']} disclosed {m['disclosed_dimension']}")
    print("   pad block", {k: v for k, v in (s3.get("pad_block_exact_rank_cross_check") or {}).items() if k != "what"},
          "| exclusivity controls", (s3.get("exclusivity_controls") or {}).get("ok"))
    mc = r.get("R13-7 mask and CFS") or r.get("W16-7 mask and CFS") or {}
    print("   mask/CFS", mc.get("ok"), "entries", mc.get("entries_recomputed"), "differing", mc.get("entries_differing"), "leaves",
          mc.get("salted_leaves_authenticated"), "controls", (mc.get("controls") or {}).get("ok"))
    io = r.get("D55-IO joined claims from the forks") or {}
    print("   D55-IO", io.get("ok"), "claims derived", io.get("claims_derived"), "control fires", (io.get("control") or {}).get("fires"))
    j = r.get("D55-J joint rank")
    if j:
        for p in j["per_boundary"]:
            a, t3 = p["restricted_to_the_reserved_rows"], p["three_roles_of_the_plane"]
            print(f"   J B{p['boundary']}: reserved rank {a['rank_on_the_reserved_block']}/{a['generators']} disclosed {a['disclosed_on_the_reserved_block_fp']}"
                  f" det!=0 {a['determinant_nonzero']} | three roles {t3['roles']} parts {t3['parts_fp']} joint {t3['joint_fp']} ({t3['joint_detail']['generators']} x"
                  f" {t3['coordinate_classes']}, {t3['identified_rows']} identified rows) block-diagonal {t3['non_data_block_is_block_diagonal_by_role']} ok {p['ok']}")
        w = j.get("whole_run") or {}
        print(f"   J whole run {w.get('matrix')} joint {w.get('joint_fp')} sum {w.get('sum_of_parts_fp')} identified {w.get('identified_rows')} ok {w.get('ok')}")
        for p in j.get("adjacent_fork_pairs", []):
            print(f"   J {p['label']}: {p['matrix']} joint {p['joint_fp']} sum {p['sum_of_parts_fp']} ok {p['ok']}")
        print("   J controls", {k: (v.get("fires"), (v.get("perturbed") or {}).get("joint_fp", (v.get("perturbed") or {}).get("disclosed_fp"))) for k, v in j["controls"].items() if isinstance(v, dict)})
    c = r.get("D55-C replay controls") or {}
    print("   D55-C", {k: (v.get("fires"), v.get("replay_failures")) for k, v in c.items() if isinstance(v, dict)})
    p = r.get("PINS", {})
    print("   pins", p.get("pins"), "at r19b", p.get("at_r19b"), "read", len(p.get("read_here", [])), "unread", len(p.get("unread", [])))

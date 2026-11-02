#!/usr/bin/env python3
"""D59 condition (5) privacy re-check (2026-11-02): one line per fact of each Python gate record in
results/zk60_w16r2_20261101/privacy_recheck_gate/ (the figures PRIVACY_RECHECK_20261102.md quotes)."""
import glob
import json
import os
import sys

E = "/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-acdb40abef543db2f/results/zk60_w16r2_20261101/privacy_recheck_gate"
for path in sorted(glob.glob(os.path.join(E, "*.json"))):
    r = json.load(open(path))
    print(f"== {os.path.basename(path)}: {r.get('status')} ({r.get('seconds')} s) parts {r.get('parts')}")
    facts = r.get("W16-1/2 facts") or r.get("D55-1/2 facts") or {}
    print("   geometry", facts.get("pcs_geometry"))
    rp = r.get("W16-3 replay") or r.get("D55-3 replay") or {}
    print("   replay positions", rp.get("positions_checked"), "challenges", rp.get("challenges_checked"), "failures", len(rp.get("failures", [])),
          "s0", rp.get("s0_tag_reproduced"), "s1", rp.get("s1_reproduced"), "tail end", rp.get("tail_end_tag_reproduced"), "tail openings", rp.get("tail_openings_replayed"))
    s3 = r.get("W16-6 per commitment") or {}
    for row in s3.get("per_commitment", []):
        print(f"   {row['role']:9s} {row['commitment_kind']:18s} rows {row['rows']:4d} data {row['data_rows']:4d} disclosed {row['disclosed_dimension']} (want {row['expected_disclosed_dimension']})"
              f" distinct {row['distinct_columns']}/{row['sampled_columns']} pads {row['q_pad']} margin {row['pad_margin']} Zn0 {row['vanishing_Zn_nodes']}"
              f" minor {row['certifying_minor'].get('full_row_rank')}/{row['certifying_minor'].get('determinant_nonzero')} hyp {all(row['reduction_hypotheses'].values())}"
              f" col-id {row['column_identity_checked'] - row['column_identity_failures']}/{row['column_identity_checked']} findings {len(row['findings'])}")
    for m in s3.get("masking_commitments", []):
        print(f"   {m['commitment']:9s} M rows {m['rows']} disclosed {m['disclosed_dimension']} opened {m['opened_columns']}")
    print("   pad block", {k: v for k, v in (s3.get("pad_block_exact_rank_cross_check") or {}).items() if k != "what"})
    xc = s3.get("exclusivity_controls") or {}
    print("   exclusivity controls ok", xc.get("ok"), "count", len([k for k in xc if k != "ok"]))
    mc = r.get("W16-7 mask and CFS") or {}
    print("   mask/CFS ok", mc.get("ok"), "entries", mc.get("entries_recomputed"), "differing", mc.get("entries_differing"), "leaves", mc.get("salted_leaves_authenticated"),
          "controls", (mc.get("controls") or {}).get("ok"))
    if "D55-C replay controls" in r:
        print("   D55-C", {k: (v.get("fires"), v.get("replay_failures")) for k, v in r["D55-C replay controls"].items() if isinstance(v, dict)})
    if "D55-0 integrity" in r:
        i = r["D55-0 integrity"]
        print("   D55-0 files", i.get("manifest_files_checked"), "tail", i.get("tail_openings"), "roots", i.get("distinct_roots_opened"), "twice", i.get("any_root_opened_twice"))
    p = r.get("PINS", {})
    print("   pins", p.get("pins"), "at r19b", p.get("at_r19b"), "read", len(p.get("read_here", [])), "unread", [u["file"] for u in p.get("unread", [])])
sys.exit(0)

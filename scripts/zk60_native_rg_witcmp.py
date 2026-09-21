#!/usr/bin/env python3
"""The WITNESS comparison: every measured figure of one gate record beside
another's, so that a DENSE witness can be read against a DEGENERATE one.

    python3 scripts/zk60_native_rg_witcmp.py \
        --record <a.json> --label "run-g (dense)" \
        --record <b.json> --label "run-h (zero)" \
        --out results/.../witness_comparison.json

WHY.  Every capture this gate has read before round 4 was made on a witness
whose normalised hidden state is IDENTICAL in every attention head, or on
the all-zero input.  Finding S19-F1 turned on exactly that degeneracy.  So
the honest question for round 4 is not "does the gate pass" but "does any
figure MOVE when the witness stops being degenerate".  This tool answers it
by pulling the same named figures out of each record and saying, per figure,
whether they agree.

WHAT IT DOES NOT DO.  It does not decide whether a difference is expected.
It reports the difference; a human writes the reading.  It also cannot see
the witness: no capture carries one, so the label is supplied on the
command line and is a claim about the Rust lane's test, not a measurement.

RULING R-3 travels with the joint figures it reports.
"""

from __future__ import annotations

import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

from zk60_native_rg_joint import RULING_R3  # noqa: E402


def _get(d, path, default="(absent)"):
    cur = d
    for k in path:
        if isinstance(k, int):
            if not isinstance(cur, list) or len(cur) <= k:
                return default
            cur = cur[k]
        else:
            if not isinstance(cur, dict) or k not in cur:
                return default
            cur = cur[k]
    return cur


def figures(rec: dict) -> dict:
    """Every figure this comparison covers, flat, in the report's order."""
    out = {}
    r2 = rec["stage2_transcript_replay"]
    out["replay/run binding reproduced"] = r2["run_binding_reproduced"]
    out["replay/transcript positions"] = r2["positions_checked"]
    out["replay/challenges re-derived"] = r2["challenges_checked"]
    out["replay/final transcript counter"] = r2["final_counter"]
    out["replay/segment position tags ok"] = sum(
        1 for t in r2["segment_position_tags"]
        if t["start_tag_ok"] and t["end_tag_ok"])
    out["replay/challenges NOT re-derived"] = len(r2["not_rederived"])
    out["replay/hash rule"] = r2.get("hash_rule")

    s1 = rec["stage1_integrity"]
    out["integrity/findings"] = len(s1.get("findings", []))
    segs = _get(rec, ["stage7_channels", "channels"], [])
    for c in segs:
        if c.get("segments"):
            out["integrity/segment byte lengths"] = [
                s.get("bytes") for s in c["segments"]]

    s3 = rec["stage3_per_commitment"]
    for row in s3["per_commitment"]:
        key = f"{row['stage']}:{row['site_role']}"
        out[f"disclosed/{key}"] = row["disclosed_dimension"]
        out[f"rank_P1/{key}"] = row["rank_P1"]
        out[f"rows/{key}"] = row["rows"]
        out[f"distinct opened columns/{key}"] = row["distinct_opened_columns"]
        out[f"pad count/{key}"] = row["pad_count"]
        out[f"pad margin/{key}"] = row["pad_margin"]
        out[f"k0/{key}"] = row["k0"]
    for m in s3["masking_commitments"]:
        out[f"disclosed/{m['commitment']}"] = m["disclosed_dimension"]
        out[f"rows/{m['commitment']}"] = m["rows"]
        out[f"opened columns/{m['commitment']}"] = m["opened_columns"]
    x = s3.get("pad_block_exact_rank_cross_check")
    if isinstance(x, dict):
        out["pad block/distinct columns"] = x.get("distinct_columns")
        out["pad block/exact rank"] = x.get("exact_rank_of_the_pad_block")
        out["pad block/full rank"] = x.get("full_rank")

    s4 = rec["stage4_the_boundary"]
    for b in s4["per_boundary"]:
        k = b["boundary"]
        res = b["restricted_to_the_reserved_rows"]
        out[f"boundary {k}/reserved rows ranked"] = res.get("reserved_rows")
        out[f"boundary {k}/rank on the reserved block"] = res.get(
            "rank_of_the_reserved_block")
        out[f"boundary {k}/disclosed on the reserved block"] = res[
            "disclosed_on_the_reserved_block_fp"]
        th = b["three_roles_of_the_plane"]
        out[f"boundary {k}/three-role parts"] = th["parts_fp"]
        out[f"boundary {k}/three-role sum"] = th["sum_of_parts_fp"]
        out[f"boundary {k}/three-role joint"] = th["joint_fp"]
        out[f"boundary {k}/three-role generators"] = th.get("generators")
        out[f"boundary {k}/aliasing lost to the identification"] = th.get(
            "aliasing_lost_to_the_identification_fp")
    w = s4.get("whole_run") or {}
    out["whole run/generators x classes"] = w.get("matrix")
    out["whole run/sum of parts"] = w.get("sum_of_parts_fp")
    out["whole run/joint"] = w.get("joint_fp")
    out["whole run/identified rows"] = w.get("identified_rows")
    for p in s4.get("adjacent_stage_pairs", []):
        out[f"pair/{p.get('label')}/joint"] = p.get("joint_fp")
        out[f"pair/{p.get('label')}/sum"] = p.get("sum_of_parts_fp")

    s5 = rec["stage5_zero_data_preimage"]
    out["preimage/attempted"] = s5.get("attempted")
    out["preimage/half"] = s5.get("half")
    out["preimage/commitments reproduced"] = sum(
        1 for c in s5.get("per_commitment", []) if c.get("reproduced"))

    s8 = rec["stage8_plane_index_and_terminals"]
    t = s8.get("terminal_identity", {})
    out["terminals/slots covered"] = len(t.get("covered_slots", []))
    out["terminals/checks equal"] = t.get("slot_checks_equal")
    out["terminals/checks expected"] = t.get("slot_checks_expected")
    out["terminals/matching the stored terminal_polynomial"] = t.get(
        "slot_checks_matching_the_stored_terminal_polynomial")
    out["terminals/public tables rebuilt"] = t.get(
        "public_tables_rebuilt_and_digest_matched")
    out["terminals/public tables taken from the capture"] = t.get(
        "public_tables_taken_from_the_capture")
    out["terminals/public table structure checks"] = t.get(
        "public_table_structure_checks")
    out["terminals/derived group points used"] = t.get(
        "derived_group_points_used_and_compared")
    ct = s8.get("controls", {})
    out["terminals/controls that fire"] = sum(
        1 for c in ct.get("controls", []) if c.get("fires"))
    out["terminals/controls total"] = len(ct.get("controls", []))
    pt = s8.get("carried_public_tables", {})
    out["public tables/checked against len and sha256"] = pt.get(
        "tables_checked", pt.get("checked"))

    s9 = rec.get("stage9_hash_layer", {})
    out["hash layer/openings"] = s9.get("openings")
    out["hash layer/columns checked"] = s9.get("columns_checked")
    out["hash layer/columns authenticated"] = s9.get("columns_authenticated")
    out["hash layer/bytes hashed"] = s9.get("bytes_hashed")
    hc = s9.get("controls", {})
    out["hash layer/controls that fire"] = sum(
        1 for c in hc.get("controls", []) if c.get("fires"))

    s10 = rec.get("stage10_bilinear_group_factor", {})
    gf = s10.get("group_factor", {})
    out["group factor/definition in force"] = gf.get("definition_in_force")
    out["group factor/lkv"] = _get(gf, ["geometry", "lkv = clog2(kv_heads)"], None)
    for k, v in (gf.get("counts") or {}).items():
        out[f"group factor/{k}"] = v
    out["group factor/slots with a derived point"] = gf.get(
        "slots_with_a_derived_group_point")
    gc = s10.get("controls", {})
    out["group factor/controls that fire"] = gc.get("controls_that_fire")
    out["group factor/controls total"] = gc.get("controls_total")
    m = gc.get("pre_repair_polynomial_measured", {})
    out["group factor/the repaired polynomial holds"] = m.get(
        "the_repaired_definition_holds")
    out["group factor/the pre-repair polynomial holds"] = m.get(
        "the_pre_repair_definition_holds")
    out["group factor/group factors equal to one"] = m.get(
        "group_factors_equal_to_one")
    out["group factor/terminal products that are zero"] = m.get(
        "terminal_products_that_are_zero")

    ch = rec["stage7_channels"]
    out["channels/total"] = ch["total"]
    for k, v in sorted(ch["counts"].items()):
        out[f"channels/{k}"] = v

    s6 = rec.get("stage6_negative_controls", {})
    named = s6.get("controls")
    if isinstance(named, list):
        out["run controls/named"] = named
        out["run controls/all fire"] = s6.get("all_fire")
        for c in named:
            out[f"run controls/{c}"] = bool(_get(s6, [c, "fires"], False))
    return out


def compare(records) -> dict:
    """`records` is a list of `(label, witness, path, record)`."""
    tables = [(lab, wit, figures(rec)) for lab, wit, _p, rec in records]
    keys = []
    for _lab, _w, t in tables:
        for k in t:
            if k not in keys:
                keys.append(k)
    rows, differing = [], []
    for k in keys:
        vals = [t.get(k, "(absent)") for _l, _w, t in tables]
        same = all(v == vals[0] for v in vals)
        rows.append({"figure": k, "values": vals, "identical": same})
        if not same:
            differing.append({"figure": k, "values": vals})
    return {
        "what": "every measured figure of each record, side by side, so a "
        "DENSE witness can be read against a DEGENERATE one",
        "labels": [lab for lab, _w, _t in tables],
        "witnesses": [wit for _l, wit, _t in tables],
        "sources": [os.path.relpath(p) for _l, _w, p, _r in records],
        "the_witness_is_not_in_the_bundle": (
            "no capture carries a witness, so the witness column is a claim "
            "about the Rust lane's test that made the bundle (its README), "
            "not something this tool measured"
        ),
        "figures_compared": len(keys),
        "figures_identical": len(keys) - len(differing),
        "figures_that_differ": differing,
        "all_identical": not differing,
        "per_figure": rows,
        "ruling_R3": RULING_R3,
        "this_is_not_a_privacy_result": True,
    }


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--record", action="append", required=True)
    ap.add_argument("--label", action="append", required=True)
    ap.add_argument("--witness", action="append", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args(argv)
    if not (len(a.record) == len(a.label) == len(a.witness)):
        raise SystemExit("--record, --label and --witness must come in threes")
    recs = []
    for p, lab, wit in zip(a.record, a.label, a.witness):
        with open(p) as fh:
            recs.append((lab, wit, p, json.load(fh)))
    out = compare(recs)
    with open(a.out, "w") as fh:
        json.dump(out, fh, indent=2, sort_keys=False)
        fh.write("\n")
    print(f"{out['figures_compared']} figures, "
          f"{out['figures_identical']} identical, "
          f"{len(out['figures_that_differ'])} differ -> {a.out}")
    for d in out["figures_that_differ"]:
        print("  DIFFERS:", d["figure"], d["values"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

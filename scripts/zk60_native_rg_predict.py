#!/usr/bin/env python3
"""ROUND 9: what the gate MUST report at a shape, computed from the shape
before the gate is run there.

    python3 scripts/zk60_native_rg_predict.py \
      --bundle /home/victor/zk60-artifacts/m125-capture-dense-l2 \
      --validate-against results/zk60_native_run_gate_s20/run-g-dense-s20.json \
      --validate-against results/zk60_native_run_gate_k4/run-i-dense-k4.json \
      --evidence results/zk60_native_run_gate_m125 --name prediction_m125

WHY A PREDICTION IS A DIFFERENT OBJECT FROM A CHECK.

Round 5 established the method and this module is it, written down: every
figure the gate reports at a new shape is either SHAPE-INDEPENDENT -- it must
come out identical, or something the ports assumed is wrong -- or it SCALES,
and then the scaling law is an arithmetic statement that can be written
before the number is seen.  A figure read first and explained afterwards is
worth much less, because any number can be explained.

So this module takes a bundle's `run.json["shape"]` and the per-opening
geometry the capture declares (row counts, group counts, claim counts --
INPUTS, not the gate's output), and computes what the gate's record must
say.  It is VALIDATED by being run against the two development shapes whose
records are committed: if it does not reproduce those to the unit, it
predicts nothing at 125M either.  `--validate-against` is not optional in
practice and the record says whether it passed.

NOTHING HERE IS A PRIVACY STATEMENT.  A prediction about a rank is a
prediction about a rank.
"""

from __future__ import annotations

import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

from zk60_native_rg_bundle import RunBundle  # noqa: E402
from zk60_native_rg_gqa import Geometry  # noqa: E402


# ---------------------------------------------------------------- the laws
SHAPE_INDEPENDENT = {
    "a_disclosed": (0, "A commits witness data under 36 opening groups whose "
                    "blinding block is 246 rows at every shape so far; the "
                    "disclosed dimension is a rank of the BLINDING structure, "
                    "not of the data"),
    "h_disclosed": (2, "the public LogUp identity, and the gate checks that "
                    "it IS that identity rather than assuming it"),
    "endpoint_disclosed": (0, "one singleton group, 2(G+1) = 4 generators"),
    "boundary_disclosed": (0, "ruling M-8's figure on the reserved rows"),
    "m_disclosed": (0, "M commits no witness data, so its part over the "
                    "commitments' coordinates is 0"),
    "boundary_reserved_rank": (6, "2*sites + 2 = 6 reserved columns over "
                               "2(G+1) = 6 generators, full rank"),
    "m_rows": (50, "layout.rs: M_ROWS = 2 * N_SLOTS + 4, a constant of the "
               "slot table and not of the shape"),
    "m_functionals": (34, "layout.rs: N_FUNCTIONALS = 34, likewise"),
    "n_slots": (23, "the block's slot table"),
    "a_groups": (36, "read from the shape, not assumed -- but equal at all "
                 "three shapes so far"),
    "h_groups": (9, "likewise"),
    "channels": (28, "the channel array is a property of the gate, not of "
                 "the shape"),
    "three_role_generators": (154, "74 + 6 + 74: A's 2(36+1), the boundary's "
                              "2(2+1) and A's again"),
}


def geometry_of(bundle) -> dict:
    """Per-opening geometry as the CAPTURE declares it (an input)."""
    out = {"per_stage": [], "roles": []}
    for st in bundle.stages:
        rs = []
        for r in st.roles:
            rs.append({
                "key": st.key(r["role"]),
                "kind": r["commitment_kind"],
                "rows": r["commitment"]["rows"],
                "data_rows_declared": r["data_rows"],
                "groups": len(r["groups"]),
                "claims": sum(len(g["members"]) for g in r["groups"]),
                "non_data_rows_by_row_roles": sum(
                    1 for x in r["row_roles"] if x["kind"] != "data"
                ),
            })
        out["per_stage"].append(rs)
        out["roles"].extend(rs)
    return out


def predict(bundle) -> dict:
    """Every figure the gate must report, from the shape and the geometry."""
    sh = bundle.shape
    L = bundle.blocks
    geo = geometry_of(bundle)
    g = Geometry(sh.raw)
    # The number of DEFINITION draws a slot makes is a property of that
    # slot's composition, not of the shape: `Geometry.n_definition_challenges`
    # is the port for the two BILINEAR slots (08, 09) and returns the generic
    # count elsewhere.  So this term is read from the capture -- a declared
    # count, an INPUT -- and the two slots the port really covers are
    # compared with the derivation instead.  Said here rather than hidden in
    # a number that happened to come out right.
    n_defs = sum(len(a["definition_challenges"]) for a in bundle.stages[0].slots)
    bilinear = [
        {"slot": s,
         "captured": len(bundle.stages[0].slots[s]["definition_challenges"]),
         "derived": g.n_definition_challenges(s)}
        for s in (8, 9)
    ]
    sc_rounds = sum(m + e for m, e, _d in sh.slots)

    # ---- the transcript replay, exactly as `RunReplay` counts it
    # positions: 1 (the run binding) + per stage 1 header + 5 per slot
    # (the site's before, before_definition, before, after, the site's after)
    # + 2 for the M opening + 2 per PCS opening.
    positions = 1 + L * (1 + 5 * sh.n_slots + 2) + 2 * len(geo["roles"])
    # challenges COMPARED: 3 LogUp + per slot (its definition draws, its
    # mask challenge c, one per sumcheck round) + M's theta and its
    # proximity rhos + per opening (one lambda per claim, one rho per row).
    m_prox = [len(st.mask["proximity_rhos"]) for st in bundle.stages]
    challenges = (
        L * (3 + n_defs + sh.n_slots + sc_rounds + 1)
        + sum(m_prox)
        + sum(r["claims"] + r["rows"] for r in geo["roles"])
    )

    # ---- the hash layer: every opened column of every commitment
    pcs_cols = sum(sh.opened_cols for _r in geo["roles"])
    pcs_bytes = sum(sh.opened_cols * r["rows"] * 8 for r in geo["roles"])
    m_cols = L * sh.mask_columns
    m_bytes = L * sh.mask_columns * (2 * sh.n_slots + 4) * 8
    tree_depth = sh.log_cols + (sh.inv_rate.bit_length() - 1)

    # ---- the masking layer: L_s = (main + ext) * degree + 2
    lens = [(m + e) * d + 2 for m, e, d in sh.slots]
    mask_msg = 1 << 9  # zk.rs::MASK_LOG_MSG, and the shape now refuses above it
    mask_q = sh.mask_columns

    # ---- the joint systems
    pairs = 2 * L * (bundle.boundary(0)["data_rows"] if bundle.boundaries
                     else geo["roles"][0]["data_rows_declared"])
    sum_of_parts = L * SHAPE_INDEPENDENT["h_disclosed"][0]

    per_role = []
    for r in geo["roles"]:
        if r["key"].startswith("A@"):
            disc, gen = SHAPE_INDEPENDENT["a_disclosed"][0], 2 * (sh.a_groups + 1)
        elif r["key"].startswith("H@"):
            disc, gen = SHAPE_INDEPENDENT["h_disclosed"][0], 2 * (sh.h_groups + 1)
        else:
            disc, gen = 0, 2 * (r["groups"] + 1)
        per_role.append({
            **r,
            "predicted_disclosed_dimension": disc,
            "predicted_generators": gen,
            "predicted_non_data_rows": 2 * r["claims"] + 2,
            "non_data_rows_match": r["non_data_rows_by_row_roles"]
            == 2 * r["claims"] + 2,
        })

    return {
        "shape": sh.name,
        "blocks": L,
        "tokens": sh.tokens, "width": sh.width, "hidden": sh.hidden,
        "q_heads": sh.q_heads, "kv_heads": sh.kv_heads, "head_dim": sh.head_dim,
        "lkv": (sh.kv_heads - 1).bit_length(),
        "cols": sh.cols, "encoded_cols": sh.enc_cols,
        "opened_cols": sh.opened_cols,
        "a_groups": sh.a_groups, "h_groups": sh.h_groups,
        "n_slots": sh.n_slots,
        "shape_independent": {k: v[0] for k, v in SHAPE_INDEPENDENT.items()},
        "shape_independent_why": {k: v[1] for k, v in SHAPE_INDEPENDENT.items()},
        "replay": {
            "positions_checked": positions,
            "challenges_checked": challenges,
            "definition_draws_per_stage": n_defs,
            "definition_draws_are_read_from_the_capture": True,
            "bilinear_definition_draws_derived_and_compared": bilinear,
            "sumcheck_rounds_per_stage": sc_rounds,
            "m_proximity_rhos_per_stage": m_prox,
            "segment_position_tags": 2 * L,
        },
        "hash_layer": {
            "openings": len(geo["roles"]) + L,
            "columns": pcs_cols + m_cols,
            "column_bytes": pcs_bytes + m_bytes,
            "largest_column_bytes": max(r["rows"] for r in geo["roles"]) * 8,
            "tree_depth": tree_depth,
        },
        "masking": {
            "rows": 2 * sh.n_slots + 4,
            "functionals": 34,
            "slot_lengths": lens,
            "largest_L": max(lens),
            "largest_L_slot": lens.index(max(lens)),
            "mask_msg": mask_msg,
            "mask_q": mask_q,
            "ruling_C4_headroom": mask_msg - max(lens) - mask_q,
            "coefficient_unknowns_fp": 2 * sum(lens),
            "q_entries_per_stage": 1 << (sh.mask_log_dom - 2),
        },
        "terminals": {
            "slot_checks_expected": sh.n_slots * L,
            "why": "public_tables_included is "
            f"{bundle.public_tables_included}, so "
            + ("every slot's tables are carried and all 23 can be evaluated"
               if bundle.public_tables_included
               else "the eleven table-bearing slots stay open"),
        },
        "joint": {
            "identified_row_pairs": pairs,
            "sum_of_the_parts": sum_of_parts,
            "whole_run_joint": sum_of_parts,
            "whole_run_generators": sum(
                p["predicted_generators"] for p in per_role
            ) + L * 2,
        },
        "per_commitment": per_role,
        "what_this_is": "a PREDICTION, computed from run.json[\"shape\"] and "
        "the capture's declared per-opening geometry, before the gate was "
        "run at this shape.  Every figure the gate reports that this does "
        "not name, or names wrongly, is the round's headline",
        "what_this_is_not": "a privacy statement, and not a check: nothing "
        "here reads a published value",
    }


# ------------------------------------------------------- validation
VALIDATE = [
    ("replay.positions_checked", ["stage2_transcript_replay", "positions_checked"]),
    ("replay.challenges_checked", ["stage2_transcript_replay", "challenges_checked"]),
    ("hash_layer.openings", ["stage9_hash_layer", "openings"]),
    ("hash_layer.columns", ["stage9_hash_layer", "columns_checked"]),
    ("hash_layer.column_bytes", ["stage9_hash_layer", "bytes_hashed"]),
    ("terminals.slot_checks_expected",
     ["stage8_plane_index_and_terminals", "terminal_identity",
      "slot_checks_expected"]),
    ("masking.rows", ["stage3_per_commitment", "masking_commitments", 0, "rows"]),
    ("joint.whole_run_joint",
     ["stage4_the_boundary", "whole_run", "joint_fp"]),
    ("joint.sum_of_the_parts",
     ["stage4_the_boundary", "whole_run", "sum_of_parts_fp"]),
    ("joint.whole_run_generators",
     ["stage4_the_boundary", "whole_run", "generators"]),
    ("joint.identified_row_pairs",
     ["stage4_the_boundary", "whole_run", "identified_rows"]),
]


def _dig(o, path):
    for k in path:
        if o is None:
            return None
        o = o[k] if not isinstance(k, int) else o[k]
    return o


def _pget(pred, dotted):
    o = pred
    for k in dotted.split("."):
        o = o[k]
    return o


def validate(pred_fn, bundle_dir, record_path) -> dict:
    b = RunBundle(bundle_dir)
    p = pred_fn(b)
    with open(record_path) as fh:
        rec = json.load(fh)
    rows, bad = [], []
    for name, path in VALIDATE:
        want = _pget(p, name)
        try:
            got = _dig(rec, path)
        except (KeyError, IndexError, TypeError):
            got = "<absent>"
        rows.append({"figure": name, "predicted": want, "recorded": got,
                     "equal": want == got})
        if want != got:
            bad.append(f"{name}: predicted {want}, the record says {got}")
    for r in p["per_commitment"]:
        recorded = next(
            (x for x in rec["stage3_per_commitment"]["per_commitment"]
             if x["role"] == r["key"]), None)
        if recorded is None:
            bad.append(f"{r['key']}: no such commitment in the record")
            continue
        for field, want in (("disclosed_dimension", r["predicted_disclosed_dimension"]),
                            ("rows", r["rows"]),
                            ("claims", r["claims"]),
                            ("groups", r["groups"])):
            if recorded[field] != want:
                bad.append(f"{r['key']}.{field}: predicted {want}, "
                           f"the record says {recorded[field]}")
    return {
        "bundle": b.name,
        "record": os.path.basename(record_path),
        "figures": rows,
        "mismatches": bad,
        "ok": not bad,
    }


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--bundle", required=True)
    ap.add_argument("--validate", action="append", default=[],
                    metavar="BUNDLE_DIR:RECORD.json")
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--name", default="prediction")
    args = ap.parse_args(argv)

    b = RunBundle(args.bundle)
    out = {"prediction": predict(b), "validation": []}
    for spec in args.validate:
        d, r = spec.rsplit(":", 1)
        out["validation"].append(validate(predict, d, r))
    out["validated_on"] = [v["bundle"] for v in out["validation"]]
    out["validation_ok"] = all(v["ok"] for v in out["validation"])
    out["ok"] = out["validation_ok"] and bool(out["validation"])
    os.makedirs(args.evidence, exist_ok=True)
    path = os.path.join(args.evidence, f"{args.name}.json")
    with open(path, "w") as fh:
        json.dump(out, fh, indent=1, sort_keys=True)
        fh.write("\n")
    for v in out["validation"]:
        print(f"validated on {v['bundle']}: {'OK' if v['ok'] else 'MISMATCH'}")
        for m in v["mismatches"]:
            print("   ", m)
    print(json.dumps({k: v for k, v in out["prediction"].items()
                      if k in ("replay", "hash_layer", "masking", "terminals",
                               "joint", "shape_independent")}, indent=1))
    print(f"record: {path}")
    return 0 if out["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())

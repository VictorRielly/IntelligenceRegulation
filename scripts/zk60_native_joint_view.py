#!/usr/bin/env python3
"""The native joint-view gate: one command, eight stages, each able to FAIL.

    python3 scripts/zk60_native_joint_view.py \
      --captures results/zk60_native_captures_20260919 \
      --evidence results/zk60_native_joint_view

Runs the joint-view analysis on the REAL captured verifier views of the
source-pinned native receipts of 2026-09-19 (two complete-block, two
attention).  Read `docs/zkmatrix-poc/ZK60_NATIVE_JOINT_VIEW.md` for what
each number means and, above all, for what it does NOT establish.

  1 TRANSCRIPT REPLAY     every checkpoint and challenge re-derived with
                          BLAKE3 from the capture's public data
  2 COMMITMENT-SIDE VIEW  A and H (and both endpoints) jointly, with the
                          claim values, the group combinations and the 256
                          sampled columns with their pads
  3 MASKING-COMMITMENT    the CFS masks, the slots' masked rounds, the one M
                          opening, and the per-slot identity by which the
                          verifier DERIVES each mask evaluation
  4 STACKED               A, H, the endpoints and M as ONE generator system
                          over the union of their coordinates, with the
                          coordinates the protocol shares identified: the
                          joint disclosed dimension by rank, against the sum
                          of the parts (both COMPUTED; see the note below)
  5 ZERO-WITNESS GATE     a zero-data preimage of the same view, per channel
  6 NEGATIVE CONTROLS     each must fire, plus the pad-budget boundary
                          (q_pad == the number of distinct opened positions)
  7 TERMINAL POLYNOMIALS  the STRONG form of each slot's final check,
                          fin = c * mask_eval + poly(terminals), every poly
                          recomputed by the Python port of the Rust closures
                          (scripts/zk60_native_terminal_polys.py)
  8 RECORD                results, hashes and a marker under --evidence

NO STAGE ESTABLISHES A PRIVACY PROPERTY.  Every rank below is a rank of an
explicitly stated linear model at two receipts' real challenges.  The
caller-fixed endpoint-root obligation (decisions D8/D11) is untouched and
remains OPEN.

CORRECTION, 2026-09-20 (the security owner's ruling G-1).  Until this date
stage 4 set `joint_equals_sum_of_parts` to the literal `True` and its own
verdict to the literal `True` with it: the stage could not fail, and every
statement that quoted "joint disclosed dimension 4, equal to the sum of the
parts" was quoting four MARGINALS and an assumption.  Stage 4 now builds one
generator system over the union of the commitments' coordinates, identifies
the coordinates the protocol shares, and computes the joint disclosed
dimension by rank; four negative controls, each of which makes it FAIL at an
honest capture, are in stage 6.  `scripts/zk60_native_jv_joint.py` states
the model and what is shared.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

from zk60_native_jv_capture import load_all, manifest_check  # noqa: E402
from zk60_native_jv_cfs import (  # noqa: E402
    CfsView,
    m_pad_block_rank,
    terminal_identity,
    terminal_identity_controls as cfs_terminal_controls,
)
from zk60_native_jv_field import F2_ZERO, f2_from_list  # noqa: E402
from zk60_native_jv_joint import joint_controls, joint_view  # noqa: E402
from zk60_native_jv_pcs import RoleView  # noqa: E402
from zk60_native_jv_replay import Replay  # noqa: E402
import zk60_native_jv_smallmodel as smallmodel  # noqa: E402
import zk60_native_terminal_polys as terminal_polys  # noqa: E402

TOOLS = [
    "zk60_native_joint_view.py",
    "zk60_native_jv_field.py",
    "zk60_native_jv_capture.py",
    "zk60_native_jv_replay.py",
    "zk60_native_jv_pcs.py",
    "zk60_native_jv_cfs.py",
    "zk60_native_jv_joint.py",
    "zk60_native_jv_smallmodel.py",
    "zk60_native_terminal_polys.py",
    "zk60_native_mask_commit.py",
]


def tool_hashes():
    out = {}
    for t in TOOLS:
        with open(os.path.join(HERE, t), "rb") as fh:
            out[t] = hashlib.sha256(fh.read()).hexdigest()
    return out


# --------------------------------------------------------------- stage 1
def stage1(caps):
    out, replays = [], {}
    for cap in caps:
        rp = Replay(cap).run()
        replays[cap.proof_sha256] = rp
        out.append(rp.summary())
    return {"per_capture": out, "ok": all(o["ok"] for o in out)}, replays


def stage1_tamper(caps, replays):
    """A capture whose bytes were altered must FAIL the replay."""
    fired = []
    for cap in caps:
        doc = cap.doc
        saved = doc["arguments"][0]["rounds"][0][0][0]
        doc["arguments"][0]["rounds"][0][0][0] = (saved + 1) % (2**64 - 2**32 + 1)
        rp = Replay(cap).run()
        doc["arguments"][0]["rounds"][0][0][0] = saved
        fired.append(
            {
                "capture": cap.proof_sha256[:16],
                "fired": not rp.summary()["ok"],
                "first_failure": (rp.failures or ["<none>"])[0],
            }
        )
    return {"per_capture": fired, "ok": all(f["fired"] for f in fired)}


# --------------------------------------------------------------- stage 2
def stage2(caps, replays, pad_rank_check=True):
    out = []
    pad_rank = None
    boundary = None
    views = {}  # capture -> the RoleView objects, for stage 4
    for cap in caps:
        rp = replays[cap.proof_sha256]
        roles, total = [], 0
        views[cap.proof_sha256] = []
        for role in cap.roles:
            rv = RoleView(cap, role, rp.role_prox_rhos[role["role"]])
            f = rv.run(rp.role_lambdas[role["role"]])
            views[cap.proof_sha256].append(rv)
            f = dict(f)
            f.pop("xi_vectors", None)
            f.pop("data_rows_index", None)
            roles.append(f)
            total += f["disclosed_dimension"]
            if pad_rank_check and pad_rank is None and role["role"] == "Input":
                t0 = time.time()
                r, d = rv.pad_block_rank()
                pad_rank = {
                    "role": "Input",
                    "capture": cap.proof_sha256[:16],
                    "distinct_columns": d,
                    "exact_rank_of_pad_block": r,
                    "full_rank": r == d,
                    "seconds": round(time.time() - t0, 1),
                }
                # The boundary the source allows: q_pad = num_col_checks pads
                # against that many DISTINCT opened positions (report §9b).
                t0 = time.time()
                rb, db = rv.pad_block_rank_at_full_budget()
                boundary = {
                    "role": "Input",
                    "capture": cap.proof_sha256[:16],
                    "distinct_positions": db,
                    "q_pad": db,
                    "pad_margin": 0,
                    "exact_rank_of_pad_block": rb,
                    "full_rank": rb == db,
                    "seconds": round(time.time() - t0, 1),
                }
        out.append(
            {
                "capture": cap.proof_sha256,
                "profile": cap.profile,
                "roles": roles,
                "sum_of_parts": total,
            }
        )
    ok = all(
        r["findings"] == []
        and all(r["reduction_hypotheses"].values())
        and r["column_identity_failures"] == 0
        and r["group_claim_identity_failures"] == 0
        and r["disclosed_dimension"] == (2 if r["role"] == "H" else 0)
        for c in out
        for r in c["roles"]
    )
    # k0 = 0 on every role is also the statement that the opening-group
    # vectors consume no pad freedom: their pad entries are already reached
    # through the mask rows, so they constrain no data row's pads (§9b).
    k0s = {r["role"]: r["k0"] for c in out for r in c["roles"]}
    # JOB 3: the certifying minor of the generic-rank lemma's good event,
    # per role per capture, and the pad budget it has to live inside.
    minors_ok = all(
        r["certifying_minor"]["full_row_rank"]
        and r["certifying_minor"]["determinant_nonzero"]
        and r["distinct_opened_columns_within_pad_count"]
        for c in out
        for r in c["roles"]
    )
    return {
        "per_capture": out,
        "expected": {"A": 0, "H": 2, "Input": 0, "Output": 0},
        "pad_block_exact_rank_cross_check": pad_rank,
        "pad_block_at_the_full_budget": boundary,
        "k0_by_role": k0s,
        "group_vectors_consume_pad_freedom": any(v for v in k0s.values()),
        "certifying_minors_all_nonsingular_within_the_pad_budget": minors_ok,
        "ok": ok
        and minors_ok
        and (pad_rank is None or pad_rank["full_rank"])
        and (boundary is None or boundary["full_rank"]),
    }, views


# --------------------------------------------------------------- stage 3
def stage3(caps, replays, pad_rank_check=True):
    out = []
    mpad = None
    for cap in caps:
        rp = replays[cap.proof_sha256]
        f = CfsView(cap, rp).run()
        f.pop("per_slot_detail", None)
        slots = f.pop("per_slot")
        f["slots_with_uncovered_directions"] = [p["slot"] for p in slots if p["uncovered"]]
        # The derived mask evaluation is COMPUTED by the verifier, not observed
        # (report §3.1): assert the identity it is computed by, per slot.
        f["derived_mask_evaluation"] = terminal_identity(cap, rp)
        out.append({"capture": cap.proof_sha256, "profile": cap.profile, **f})
        if pad_rank_check and mpad is None:
            t0 = time.time()
            r, d = m_pad_block_rank(cap)
            mpad = {
                "capture": cap.proof_sha256[:16],
                "distinct_columns": d,
                "exact_rank_of_a_row_pad_block": r,
                "full_rank": r == d,
                "seconds": round(time.time() - t0, 1),
            }
    ok = all(
        c["findings"] == []
        and c["uncovered_consistency_directions"] == 0
        and c["q_public_sum_identity"]
        and c["m_pad_margin"] > 0
        and c["derived_mask_evaluation"]["ok"]
        for c in out
    )
    return {
        "per_capture": out,
        "m_pad_block_exact_rank_cross_check": mpad,
        "ok": ok and (mpad is None or mpad["full_rank"]),
    }


# --------------------------------------------------------------- stage 4
def stage4(caps, replays, views, s2, s3):
    """A, H, the two endpoints and M as ONE system, not four marginals.

    CORRECTED 2026-09-20 (ruling G-1).  What this stage used to do: add the
    per-commitment figures and write `joint_equals_sum_of_parts = True` as a
    literal, with `ok = True` beside it.  What it does now: build one
    generator system over the union of the commitments' coordinates, with
    the coordinates the protocol makes the same unknown IDENTIFIED (the two
    endpoint planes are A's planes -- the last two slots of either profile
    prove exactly that), and compute the joint disclosed dimension by rank.

    The stage FAILS when the joint differs from the sum, when a part exceeds
    its expected public value, when the parts recomputed through the joint
    code path disagree with stage 2's, or when a commitment's reduction
    hypothesis does not hold.  `zk60_native_jv_joint` states the model, and
    stage 6 carries four controls that each make this stage fail.
    """
    rows = []
    for cap, c2, c3 in zip(caps, s2["per_capture"], s3["per_capture"]):
        pcs = {r["role"]: r["disclosed_dimension"] for r in c2["roles"]}
        jv = joint_view(
            cap,
            replays[cap.proof_sha256],
            views[cap.proof_sha256],
            c3["disclosed_opening_only_fp"],
        )
        joint_pcs = jv["joint_detail"]["disclosed_fp"] + jv["parts_fp"]["M"]
        rows.append(
            {
                "capture": c2["capture"],
                "profile": c2["profile"],
                "pcs_parts_fp": pcs,
                "pcs_sum_fp": sum(pcs.values()),
                "cfs_opening_only_fp": c3["disclosed_opening_only_fp"],
                "cfs_all_derived_values_fp": c3["disclosed_all_values_fp"],
                # kept keys, now COMPUTED: the joint over the commitments'
                # coordinates, plus the CFS channel's own figure (a disjoint
                # unknown space: the honest sumcheck round messages)
                "joint_opening_only_fp": jv["joint_fp"],
                "joint_all_derived_values_fp": joint_pcs + c3["disclosed_all_values_fp"],
                "joint_equals_sum_of_parts": jv["joint_equals_sum_of_parts"],
                # new, all computed
                "sum_of_parts_fp": jv["sum_of_parts_fp"],
                "joint_fp": jv["joint_fp"],
                "joint_disclosed_over_the_commitments_fp": joint_pcs,
                # M's own contribution, and where each half of it comes from.
                # Since 2026-09-20 both halves are COMPUTED: M is in the union
                # of commitments as a block with 2S+4 rows, no data row and
                # one published row combination (its proximity vector), which
                # is why its part over the commitments' coordinates is 0; and
                # its figure over its OWN unknown space -- the mask
                # coefficients -- is the rank of the theta-batched functional,
                # taken from the ported row layout rather than asserted.
                "M_in_the_union_of_commitments": {
                    "rows": jv["parts_detail"]["M"]["non_data_rows"]
                    + jv["parts_detail"]["M"]["data_rows"],
                    "commits_witness_data": jv["parts_detail"]["M"][
                        "commits_witness_data"
                    ],
                    "part_fp_over_the_commitment_coordinates": jv["parts_fp"]["M"],
                    "own_disclosed_fp_over_the_coefficients": c3[
                        "disclosed_opening_only_fp"
                    ],
                    "own_disclosed_fp_computed_from_the_ported_layout": c3.get(
                        "m_disclosed_fp_computed"
                    ),
                    "row_layout_ported": True,
                },
                "joint_detail": jv["joint_detail"],
                "parts_detail": jv["parts_detail"],
                "parts_recomputed_through_the_joint_path_match_stage2": jv[
                    "parts_recomputed_through_the_joint_path_match_stage2"
                ],
                "reduction_hypotheses_hold": jv["reduction_hypotheses_hold"],
                "shared_coordinates": jv["shared_coordinates"],
                "joint_without_the_endpoint_identification_fp": jv[
                    "joint_without_the_endpoint_identification_fp"
                ],
                "aliasing_lost_to_the_endpoint_identification_fp": jv[
                    "aliasing_lost_to_the_endpoint_identification_fp"
                ],
                "expected_parts_fp": jv["expected_parts_fp"],
                "parts_exceeding_their_expected_value": jv[
                    "parts_exceeding_their_expected_value"
                ],
                "findings": jv["findings"],
                "what_is_NOT_covered": jv["what_is_NOT_covered"],
                "ok": jv["ok"],
            }
        )
    return {
        "per_capture": rows,
        "joint_is_computed_not_assumed": True,
        "corrected": "2026-09-20, ruling G-1: this stage used to hard-code "
        "joint_equals_sum_of_parts and its own verdict",
        "ok": all(r["ok"] for r in rows),
    }


# --------------------------------------------------------------- stage 5
def stage5(caps, s2):
    """The zero-witness gate, channel by channel, IN THE LINEAR MODEL.

    For a fixed view, the set of (data, randomness) consistent with it is an
    affine coset of ker(randomness map): every fibre therefore has the SAME
    free dimension, whichever data value it sits over.  A zero-data preimage
    exists exactly when every disclosed functional takes the value it takes
    at zero, i.e. when the public identities the disclosed space consists of
    evaluate to zero.  On the commitment side the only disclosed functional
    is H's LogUp identity, whose published claim value is checked to be zero
    here; A, Input and Output disclose nothing, so a zero-data preimage
    exists unconditionally.  CHANNELS NOT COVERED: the roots, the leaf salts
    and the Merkle authentication paths are hash objects; no linear algebra
    covers them.  What covers them is assumed, not shown: salted-leaf hiding
    of the unopened columns, and, for the two caller-fixed endpoint roots,
    the programmable random-oracle argument of D8/D11, WHICH IS OPEN.
    """
    rows = []
    for cap, c2 in zip(caps, s2["per_capture"]):
        h = cap.role("H")
        sums = [
            cl
            for cl in h["claims"]
            if all(not p["point"] for p in cl["parts"])
        ]
        zero_valued = all(f2_from_list(cl["value"]) == F2_ZERO for cl in sums) and sums
        per_role = {}
        for r in c2["roles"]:
            per_role[r["role"]] = {
                "disclosed_dimension": r["disclosed_dimension"],
                "zero_data_preimage_exists_in_model": (
                    r["disclosed_dimension"] == 0
                    or (r["role"] == "H" and bool(zero_valued))
                ),
                "fibre_is_a_coset_of_the_same_kernel": True,
            }
        rows.append(
            {
                "capture": cap.proof_sha256,
                "h_sum_claims": len(sums),
                "h_sum_claim_value_is_zero": bool(zero_valued),
                "roles": per_role,
                "channels_covered": [
                    "claim values",
                    "group vectors",
                    "proximity vector",
                    "sampled column values",
                    "M: q, proximity vector, sampled column values",
                    "the slots' masked round messages",
                ],
                "channels_not_covered": [
                    "the three Merkle roots",
                    "the 256 leaf salts served per opening",
                    "the 11- and 12-level authentication paths",
                    "the receipt's byte encoding and its length",
                    "anything nonlinear in the view",
                ],
            }
        )
    ok = all(
        v["zero_data_preimage_exists_in_model"] for r in rows for v in r["roles"].values()
    )
    return {"per_capture": rows, "ok": ok}


# --------------------------------------------------------------- stage 6
def stage6(caps, replays, views=None, s3=None):
    ctl = smallmodel.controls()
    honest_ok = (
        ctl["honest"]["bruteforce"] == ctl["honest"]["reduction"] == 0
        and ctl["honest_with_zero_sum_pair"]["bruteforce"]
        == ctl["honest_with_zero_sum_pair"]["reduction"]
    )
    names = [
        "masks_removed",
        "two_claims_share_one_pair",
        "commitment_opened_twice",
        "extra_published_helper_sum",
        "one_pad_fewer_than_opened_columns",
    ]
    fired = {n: ctl[n]["bruteforce"] > 0 for n in names}
    tamper = stage1_tamper(caps, replays)
    # the derived-mask-evaluation identity of stage 3 (report §3.1): one
    # published field perturbed by one, per capture; the transcript replay is
    # re-run on the first capture only (it is the expensive arm)
    mask_ctl = [
        {
            "capture": cap.proof_sha256[:16],
            **cfs_terminal_controls(cap, replays[cap.proof_sha256], replay_check=(i == 0)),
        }
        for i, cap in enumerate(caps)
    ]
    boundary = smallmodel.pad_boundary()
    # stage 4's own controls (ruling G-1): the joint reduction validated
    # against a DENSE joint rank on two toy commitments, and four
    # perturbations of the real capture, each of which must make stage 4
    # fail.  Run on the FIRST capture; the joint figures of the others are
    # in stage 4 itself.
    small_joint = smallmodel.joint_controls()
    stage4_ctl = None
    if views is not None and s3 is not None:
        cap = caps[0]
        stage4_ctl = joint_controls(
            cap,
            replays[cap.proof_sha256],
            views[cap.proof_sha256],
            s3["per_capture"][0]["disclosed_opening_only_fp"],
        )
    return {
        "small_model": ctl,
        "reduction_agrees_with_bruteforce": honest_ok,
        "controls_fired": fired,
        "altered_capture_bytes_break_the_replay": tamper,
        "derived_mask_evaluation_controls": mask_ctl,
        "pad_budget_boundary": boundary,
        "joint_reduction_against_a_dense_joint_rank": small_joint,
        "stage4_joint_controls": stage4_ctl,
        "ok": honest_ok
        and all(fired.values())
        and tamper["ok"]
        and all(m["ok"] for m in mask_ctl)
        and boundary["ok"]
        and small_joint["ok"]
        and (stage4_ctl is None or stage4_ctl["ok"]),
    }


# --------------------------------------------------------------- stage 7
def stage7(caps, replays, controls=True):
    """The STRONG form of every slot's final check.

    Stage 3 can only assert `mask_eval = (fin - terminal_polynomial) / c` with
    the ALREADY EVALUATED terminal polynomial the capture stores, which is
    blind to a perturbed terminal (report section 3.1).  Here every slot's
    composition polynomial is RECOMPUTED from the published terminals by the
    Python port of the Rust closures, and the verifier's own equation

        fin_s == c_s * mask_eval_s + poly_s(vals_s)

    is checked, per slot, on every capture.  The port refuses to run if a
    pinned Rust source changed, and each slot is called checkable only after
    its name, its number of definition challenges and its table push order
    match the port's declared ones.

    The equality of the port with the Rust closures remains a REVIEWED
    obligation: it was established by reading, not by machine.  No privacy
    property is established here either.
    """
    pins = terminal_polys.check_source_pins()
    rows = []
    for cap in caps:
        row = terminal_polys.summary(cap, replays[cap.proof_sha256])
        if controls:
            row["negative_controls"] = terminal_polys.terminal_poly_controls(
                cap, replays[cap.proof_sha256]
            )
        rows.append(row)
    ok = all(
        r["ok"] and (not controls or r["negative_controls"]["ok"]) for r in rows
    )
    return {
        "per_capture": rows,
        "source_pins": pins,
        "port": "scripts/zk60_native_terminal_polys.py",
        "equality_of_the_port_with_the_rust_closures": "reviewed obligation, by reading",
        "privacy_property_established": False,
        "ok": ok,
    }


# ------------------------------------------------------------------- main
def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--captures", required=True)
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--skip-exact-pad-rank", action="store_true")
    args = ap.parse_args(argv)

    t0 = time.time()
    caps = load_all(args.captures)
    if not caps:
        print("no captures found", file=sys.stderr)
        return 2
    record = {
        "gate": "zk60-native-joint-view",
        "version": 1,
        "privacy_review_complete": False,
        "privacy_property_established": False,
        "d8_d11_endpoint_root_obligation": "open, untouched by this gate",
        "captures_dir": os.path.abspath(args.captures),
        "manifest": manifest_check(args.captures, caps),
        "tool_sha256": tool_hashes(),
        "captures": [
            {
                "proof_sha256": c.proof_sha256,
                "profile": c.profile,
                "json_sha256": c.sha256,
                "json_bytes": c.bytes,
                "slots": len(c.slots),
                "source_commit": c.doc["source_commit"],
            }
            for c in caps
        ],
    }
    s1, replays = stage1(caps)
    record["stage1_transcript_replay"] = s1
    s2, views = stage2(caps, replays, not args.skip_exact_pad_rank)
    record["stage2_commitment_side_joint_view"] = s2
    record["stage3_masking_commitment_view"] = stage3(
        caps, replays, not args.skip_exact_pad_rank
    )
    record["stage4_stacked"] = stage4(
        caps, replays, views, s2, record["stage3_masking_commitment_view"]
    )
    record["stage5_zero_witness_gate"] = stage5(caps, record["stage2_commitment_side_joint_view"])
    record["stage6_negative_controls"] = stage6(
        caps, replays, views, record["stage3_masking_commitment_view"]
    )
    record["stage7_terminal_polynomial_port"] = stage7(caps, replays)
    record["seconds"] = round(time.time() - t0, 1)
    stages = [k for k in record if k.startswith("stage")]
    record["ok"] = all(record[k]["ok"] for k in stages)

    os.makedirs(args.evidence, exist_ok=True)
    out = os.path.join(args.evidence, "joint_view.json")
    with open(out, "w") as fh:
        json.dump(record, fh, indent=1, sort_keys=True)
        fh.write("\n")
    with open(os.path.join(args.evidence, "joint_view.done"), "w") as fh:
        fh.write("0\n" if record["ok"] else "1\n")
    for k in stages:
        print(f"{k}: {'ok' if record[k]['ok'] else 'FAIL'}")
    print(f"record: {out} ({record['seconds']} s)")
    return 0 if record["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())

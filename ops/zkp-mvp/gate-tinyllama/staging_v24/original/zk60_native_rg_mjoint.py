#!/usr/bin/env python3
"""**A JOINT run-wide preimage** — one assignment for the whole run, not ten
per-commitment ones and three per-stage ones.

WHY IT IS NOT A FORMALITY.  Round 7's control P-5 exhibits two commitments
of one stage that each have a preimage and, once ONE blinding row is
identified between them, have no joint one: each row is forced by its own
commitment and the two forced values differ at every position.  Round 8's
control M-5 is the same thing one layer down, between two SLOTS of the
masking layer.  So "each part has a preimage" does not give "the run has
one", and the difference is exactly the COUPLINGS.

WHAT COUPLES THE PARTS OF AN HONEST RUN.  Four things, and this module
enumerates all four and checks each:

  C1  the L-1 internal boundary planes and the two external endpoint
      planes.  Each is a set of rows that TWO commitments hold and a third
      claims about (`A@k` output rows ~ `B_k` rows ~ `A@k+1` input rows),
      identified by the two endpoint-equality slots' zero-checks.  The
      identification is between DATA rows -- that is checked here, row by
      row, and it is the load-bearing fact: an identification that reached
      a BLINDING row would be P-5 exactly.
  C2  the published CLAIM VALUES.  A value that two commitments both
      publish is one number, and each preimage is built to meet the number
      the capture carries, so a shared value is respected by construction.
      How many are shared is counted here rather than assumed to be zero.
  C3  the masking layer against the slots.  M's 34 functional values ARE
      the slots' own published scalars and mask evaluations -- the
      declared-order check asserts that three ways, 34 of 34 -- and round
      8's construction reproduces all 34 from the solved coefficients.
  C4  the terminal identity, `fin_s = c_s * mask_eval_s + poly_s(terminals)`,
      which ties the masking layer to the PCS claims with degree up to 4.
      It is NONLINEAR and no linear model sees it.  What this construction
      can say about it is narrow and is said narrowly below.

WHAT THE JOINT ASSIGNMENT IS.  Exactly the product of what rounds 7 and 8
exhibit: the data block of EVERY commitment set to zero, the per-commitment
PCS blinding round 7 solves, and the per-stage mask coefficients and M
blinding round 8 solves.  It is a joint object because no coordinate is
claimed twice -- C1 identifies only data rows, and the data is zero on both
sides of every identification -- and because every published number each
part meets is the same number wherever it appears.

NOTHING HERE ESTABLISHES A PRIVACY PROPERTY.  It is a statement about the
LINEAR view map of one captured run at that run's real challenges.
"""

from __future__ import annotations

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

__all__ = ["joint_run_preimage", "JOINT_OFF"]

JOINT_OFF = {
    "requested": False,
    "what": "one assignment reproducing the WHOLE run's linear view at once",
    "why_off": "it is the union of round 7's arm and round 8's arm, so it is "
    "computed only when BOTH are on (`--full-preimage --mask-cfs`)",
    "consequence": "the channel 'the preimage construction for a RUN' stays "
    "OPEN, with the reason the two arms leave it",
    "ok": True,
}


def _claim_values(views):
    """Every published claim value of the run, by commitment."""
    out = {}
    for key, v in views.items():
        vals = []
        for c in v.role["claims"]:
            vals.append(tuple(c["value"]))
        out[key] = vals
    return out


def joint_run_preimage(bundle, views, shared, s11, s12) -> dict:
    """The four couplings, checked, and the union of the two constructions."""
    out = {
        "what": "ONE assignment -- zero data in every commitment, round 7's "
        "per-commitment PCS blinding, round 8's per-stage mask coefficients "
        "and M blinding -- checked to reproduce the whole run's published "
        "linear view at once",
        "requested": True,
        "privacy_property_established": False,
        "privacy_acceptance": False,
        "bundle": bundle.name,
        "couplings": {},
        "findings": [],
    }

    # --------------------------------------------- C1 the shared planes
    pairs = shared["pairs"]
    data_only = 0
    blinding_touched = []
    for (k1, r1), (k2, r2) in pairs:
        v1, v2 = views.get(k1), views.get(k2)
        if v1 is None or v2 is None:
            blinding_touched.append(f"{k1}/{k2}: a commitment the gate has no view of")
            continue
        if r1 in set(v1.data_rows) and r2 in set(v2.data_rows):
            data_only += 1
        else:
            blinding_touched.append(
                f"{k1} row {r1} ~ {k2} row {r2}: not a data row on both sides"
            )
    roles_per_plane = {}
    for s in shared["slots"]:
        roles_per_plane.setdefault(s["commitment"], set()).add(f"A@{s['stage']}")
    out["couplings"]["C1_shared_planes"] = {
        "identified_row_pairs": len(pairs),
        "both_sides_are_data_rows": data_only,
        "pairs_touching_a_blinding_row": blinding_touched,
        "commitments_per_plane": {
            k: sorted(v) + [k] for k, v in sorted(roles_per_plane.items())
        },
        "respected": len(pairs) > 0 and not blinding_touched,
        "why": "an identification between DATA rows is satisfied by the "
        "assignment because the data block is zero on BOTH sides.  An "
        "identification that reached a blinding row would be round 7's "
        "control P-5, where two per-commitment preimages exist and no joint "
        "one does -- so this count is the whole difference between 'each has "
        "one' and 'the run has one'",
    }

    # ---------------------------------------- C2 shared published values
    by_key = _claim_values(views)
    seen = {}
    shared_values = 0
    for key, vals in by_key.items():
        for v in vals:
            seen.setdefault(v, set()).add(key)
    for v, keys in seen.items():
        if len(keys) > 1:
            shared_values += 1
    out["couplings"]["C2_shared_claim_values"] = {
        "claim_values_in_the_run": sum(len(v) for v in by_key.values()),
        "distinct_values": len(seen),
        "values_published_by_more_than_one_commitment": shared_values,
        "respected": True,
        "why": "each part's preimage is solved to meet the value the CAPTURE "
        "carries, so a value two commitments both publish is met as the same "
        "number by both.  A shared value is a coupling that costs nothing; "
        "a shared UNKNOWN is the one that costs everything (C1)",
    }

    # ------------------------------- C3 the masking layer and the slots
    stages = s12.get("per_stage") or []
    order_ok = all(
        st["declared_order"]["value_matches"]
        == st["declared_order"]["captured_functionals"]
        for st in stages
    )
    fvals_ok = all(
        st["cfs"]["functional_values"]["mismatches"] == 0 for st in stages
    )
    out["couplings"]["C3_masking_layer_against_the_slots"] = {
        "stages": len(stages),
        "functionals_per_stage": [
            st["declared_order"]["captured_functionals"] for st in stages
        ],
        "every_functional_value_is_a_slot_s_own_published_number": order_ok,
        "every_functional_value_recomputed_from_the_coefficients": fvals_ok,
        "respected": bool(order_ok and fvals_ok),
        "why": "M's 34 functionals are the slots' Gammas and mask "
        "evaluations in the declared order; the declared-order check "
        "asserts that by position, value and weights, and round 8's "
        "coefficients reproduce all 34 values.  So the masking commitment "
        "and the 23 sumchecks are met by ONE coefficient vector per stage, "
        "not by two independent solves",
    }

    # ------------------------------------------ C4 the terminal identity
    out["couplings"]["C4_the_terminal_identity"] = {
        "degree": "up to 4 in the published terminals",
        "linear_models_see_it": False,
        "what_can_be_said": "every quantity the identity relates -- fin_s, "
        "c_s, mask_eval_s and the terminals -- is a PUBLISHED number, and "
        "this assignment reproduces every published number of the run "
        "exactly.  So the identity holds at the reproduced view for the "
        "trivial reason that the reproduced view IS the captured view, entry "
        "by entry.  That is NOT the same as saying the assignment is a "
        "witness of the identity's arithmetic: the terminals are met as "
        "claim VALUES by blinding, and whether a model input exists whose "
        "activations make them is a question about the block's arithmetic "
        "that no preimage argument answers (round 7 §11.8, second bullet)",
        "respected": True,
        "respected_only_in_that_narrow_sense": True,
    }

    # -------------------------------------------------- the two unions
    pcs_ok = bool(
        s11.get("requested") and s11.get("ok")
        and s11.get("view_entries_differing") == 0
    )
    mask_ok = bool(
        s12.get("requested") and s12.get("ok")
        and s12.get("entries_differing") == 0
    )
    out["parts"] = {
        "pcs_commitments": len(s11.get("exhibited") or []),
        "pcs_entries_compared": s11.get("view_entries_compared", 0),
        "pcs_entries_differing": s11.get("view_entries_differing", None),
        "pcs_salted_leaves": s11.get("salted_leaves_authenticated", 0),
        "masking_stages": s12.get("stages_checked", 0),
        "masking_entries_compared": s12.get("entries_recomputed", 0),
        "masking_entries_differing": s12.get("entries_differing", None),
        "masking_salted_leaves": s12.get("salted_leaves_authenticated", 0),
    }
    out["entries_compared"] = (
        out["parts"]["pcs_entries_compared"]
        + out["parts"]["masking_entries_compared"]
    )
    out["entries_differing"] = (
        (out["parts"]["pcs_entries_differing"] or 0)
        + (out["parts"]["masking_entries_differing"] or 0)
    )
    out["salted_leaves_authenticated"] = (
        out["parts"]["pcs_salted_leaves"] + out["parts"]["masking_salted_leaves"]
    )
    if not pcs_ok:
        out["findings"].append(
            "round 7's arm is off or did not close, so there is nothing to "
            "join on the commitment side"
        )
    if not mask_ok:
        out["findings"].append(
            "round 8's arm is off or did not close, so there is nothing to "
            "join on the masking side"
        )
    every = all(
        c.get("respected") for c in out["couplings"].values()
    )
    out["all_four_couplings_respected"] = bool(every)
    out["ok"] = bool(pcs_ok and mask_ok and every and out["entries_differing"] == 0)
    out["what_it_does_not_show"] = [
        "the LAW of the blinding.  A joint preimage EXISTS; whether the "
        "honest prover's randomness is uniform on the joint fibre is "
        "obligation O-R2 / gap G-R4 and nothing here bears on it",
        "that the zero data block is a reachable WITNESS.  What is fixed is "
        "the data rectangle of every commitment, set to zero; whether a model "
        "input exists whose activations are exactly those blocks is a "
        "question about arithmetic, not about the linear view",
        "anything about an UNOPENED Merkle leaf, which no preimage can "
        "reproduce (M-2, M-3, still ARGUED)",
        "the FIXED transcript of the masking layer is a named public element "
        "of the channel's data space, not the zero witness's own honest "
        "rounds, which no capture carries",
        "anything nonlinear beyond the narrow sense of C4",
        "anything at the 125M shape, and nothing about any other run",
        "it is NOT a privacy acceptance and NOT a privacy property",
    ]
    return out

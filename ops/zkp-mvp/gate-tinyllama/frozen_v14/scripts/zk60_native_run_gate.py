#!/usr/bin/env python3
"""The RUN gate: the privacy-consistency checks of a multi-block run capture.

    python3 scripts/zk60_native_run_gate.py \
      --bundle /path/to/run-a-tame \
      --evidence results/zk60_native_run_gate

Input: a RUN CAPTURE bundle, schema `hashline-native-capture/4-run`, written
by `hashline/src/private_block/run_capture.rs` on lane
`zk60-private-block-125m`; format `docs/zkmatrix-poc/ZK60_RUN_CAPTURE_FORMAT.md`.
Report: `docs/zkmatrix-poc/ZK60_NATIVE_RUN_GATE.md`.

  1 LOAD AND INTEGRITY    the manifest's hashes and byte lengths, the schema
                          strings, every size against `run.json["shape"]`,
                          the boundary table against the two stages that use
                          it, and "no commitment opened twice"
  2 TRANSCRIPT REPLAY     every challenge of every stage re-derived with
                          BLAKE3 from the bundle's public data, in run order,
                          plus the segment position tags (outside the chain)
  3 PER COMMITMENT        A, H, the masking commitment M, the external
                          endpoints and each internal boundary: the disclosed
                          dimension by exact rank, the certifying minor, the
                          distinct opened columns against the pad count;
                          **round 9l**: the exact u-row term, H-pair with
                          the sixteen clauses of exclusivity, and one
                          negative control per clause
  4 THE BOUNDARY          ruling M-8: (a) each boundary's figure RESTRICTED
                          to its reserved rows; (b) the three roles of one
                          boundary plane as one system; (c) the whole run as
                          one system
  5 ZERO-DATA PREIMAGE    the message half of every singleton-group
                          commitment reproduced under the all-zero input
  6 NEGATIVE CONTROLS     six, each shown to pass honest and fail perturbed
  7 CHANNELS              every channel of a run's view labelled CONSTRUCTED
                          / DERIVED / ARGUED / OPEN with its reason
  8 PLANE INDEX AND       `run.json["plane_index"]` (stage 15 of the Rust
    THE TERMINAL          lane) read and integrity-checked, and the per-slot
    IDENTITY              terminal identity it unlocks, recomputed at the
                          run's shape for the slots whose public tables the
                          bundle carries, with five controls.  A bundle
                          written before stage 15 has no table: the stage
                          says so and the channel stays OPEN
 11 THE FULL PREIMAGE     **round 7, opt-in (`--full-preimage`)**: the same
                          construction at MSG != PAD, so `A` and `H` are in
                          it, and both halves plus every opened column plus
                          the salted leaves of the opened columns.  Off by
                          default because it is minutes, not seconds; when
                          it is off the stage says so and three channels
                          stay OPEN with round 1's reason
 12 THE MASKING LAYER     **round 8, opt-in (`--mask-cfs`)**: the masking
                          commitment `M` and the CFS channel at the SHAPED
                          layout -- one coefficient vector per stage meeting
                          every slot's masked rounds and its mask-bearing
                          scalar AND `M`'s whole published opening, `M`'s
                          rebuilt columns re-hashed and re-authenticated,
                          the pad budget, and six controls.  Off by default;
                          when it is off four channels stay OPEN
  9 RECORD                the machine-readable result under --evidence

NO STAGE ESTABLISHES A PRIVACY PROPERTY, AND THIS IS NOT A PRIVACY
ACCEPTANCE.  Every rank below is a rank of an explicitly stated linear model
at one captured run's real challenges, at ONE development shape.  The hash
layer is argued, not computed.  The joint-law composition for a run is
unwritten.  `run.json` itself carries `privacy_review_complete: false`.
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

from zk60_native_rg_bundle import RunBundle, integrity  # noqa: E402
# [ROUND 9j] a STANDALONE shaped block bundle is read as a run of one stage
# with no boundary; everything a block does not share with a run stage
# lives in this one module
from zk60_native_rg_block import (  # noqa: E402
    R3_STATUS_20260923,
    BlockReplay,
    block_channel_table,
    block_controls,
    block_integrity,
    check_block_layer_pins,
    load_bundle,
)
from zk60_native_rg_controls import controls  # noqa: E402
from zk60_native_rg_joint import (  # noqa: E402
    RULING_R3,
    RunJointSystem,
    boundary_reserved_figure,
    discover_shared_planes,
    mask_block,
    run_wide_figure,
    three_role_figure,
)
from zk60_native_rg_pcs import RunRoleView  # noqa: E402
from zk60_native_rg_planes import NO_TABLE, plane_index_of  # noqa: E402
from zk60_native_rg_ahcontrols import ah_controls  # noqa: E402
from zk60_native_rg_ahpreimage import full_preimages  # noqa: E402
from zk60_native_rg_preimage import preimages  # noqa: E402
from zk60_native_rg_replay import RunReplay  # noqa: E402
from zk60_native_rg_runpins import (  # noqa: E402
    check_run_layer_pins,
    not_checked,
)
from zk60_native_rg_hashlayer import check_hash_layer  # noqa: E402
from zk60_native_rg_hcontrols import hash_rule_controls  # noqa: E402
from zk60_native_rg_mask import mask_cfs_run  # noqa: E402
from zk60_native_rg_mcontrols import mask_controls_at_shape  # noqa: E402
from zk60_native_rg_mjoint import JOINT_OFF, joint_run_preimage  # noqa: E402
from zk60_native_rg_tcontrols import terminal_controls  # noqa: E402
from zk60_native_rg_gqa import GroupFactors  # noqa: E402
from zk60_native_rg_gcontrols import group_controls  # noqa: E402
from zk60_native_rg_terminals import (  # noqa: E402
    PORTS,
    check_terminals,
    covered_at,
    verify_captured_public_tables,
)
from zk60_native_rg_exclusivity import exclusivity_controls  # noqa: E402

TOOLS = [
    "zk60_native_run_gate.py",
    "zk60_native_rg_bundle.py",
    # [ROUND 9] the /5-run binary array store.  `rg_bundle` delegates every
    # array resolution to it, so a record that pinned `rg_bundle` and not
    # this file would name the loader's front door and not the room the
    # bundle's bytes are actually read in -- the shape of finding K4-F2.
    "zk60_native_rg_arrays.py",
    # [ROUND 9j] the standalone-block adapter: `load_bundle` is on EVERY
    # record's path, run or block, so every record pins it
    "zk60_native_rg_block.py",
    "zk60_native_rg_replay.py",
    "zk60_native_rg_runpins.py",
    "zk60_native_rg_pcs.py",
    # [ROUND 9l] the exclusivity audit (H-pair) and its per-clause controls,
    # called from `RunRoleView` on every record's path
    "zk60_native_rg_exclusivity.py",
    "zk60_native_rg_joint.py",
    "zk60_native_rg_preimage.py",
    "zk60_native_rg_ahpreimage.py",
    "zk60_native_rg_ahcontrols.py",
    "zk60_native_rg_controls.py",
    "zk60_native_rg_planes.py",
    "zk60_native_rg_terminals.py",
    "zk60_native_rg_tcontrols.py",
    "zk60_native_rg_gqa.py",
    "zk60_native_rg_gcontrols.py",
    "zk60_native_rg_hashrule.py",
    "zk60_native_rg_hashlayer.py",
    "zk60_native_rg_hcontrols.py",
    "zk60_native_rg_mask.py",
    "zk60_native_rg_mcontrols.py",
    "zk60_native_rg_mjoint.py",
    "zk60_native_jv_field.py",
    "zk60_native_jv_pcs.py",
    "zk60_native_jv_joint.py",
    # the toy gate's own solves, imported by rounds 7 and 8 and never edited
    "zk60_native_pg_pcs.py",
    "zk60_native_pg_cfs.py",
    "zk60_native_mask_commit.py",
    # [TINYLLAMA PORT 2026-10-17] the port's readings, its prediction, its
    # staged driver and its own controls are tools of every record too
    "zk60_native_rg_tinyllama_pins.py",
    "zk60_native_rg_tlcontrols.py",
    "zk60_native_rg_predict.py",
    "zk60_native_rg_m125.py",
    # [TINYLLAMA PORT, tools v4] the record status (the driver writes it
    # beside every record) and finding G-10's own negative controls
    "zk60_native_rg_status.py",
    "zk60_native_rg_g10controls.py",
    # [TINYLLAMA PORT v5, round 4] the readings of the R5 tree's digests
    "zk60_native_rg_tinyllama_r5_pins.py",
    # [v5, independent review P-2 / P-9 / P-10] the pin-enforcement controls,
    # the export cross-check and the closed capture schema
    "zk60_native_rg_pincontrols.py",
    "zk60_native_rg_exportcheck.py",
    "zk60_native_rg_schema.py",
    # [v6, round 5] the readings of the R5b tree's digests
    "zk60_native_rg_tinyllama_r5b_pins.py",
    # [v8, round 6, finding G-11] every module the driver and its control
    # families import, so a record's `tool_sha256` names all the code that
    # made it (M9-1..M9-3 live in m125controls, which v7 changed), and the
    # readings of the R7 tree's digests
    "zk60_native_rg_m125controls.py",
    "zk60_native_jv_capture.py",
    "zk60_native_jv_cfs.py",
    "zk60_native_jv_replay.py",
    "zk60_native_manifest_pins.py",
    "zk60_native_privacy_gate.py",
    "zk60_native_profile_pins.py",
    "zk60_native_rg_tinyllama_r7_pins.py",
    "zk60_native_rg_tinyllama_tk7_pins.py",  # [v11, round 8]
    # [v9, gate round 7] the token-I/O stages: geometry, gate, token pins
    "zk60_native_rg_tokenio.py",
    "zk60_native_rg_tokengate.py",
    "zk60_native_rg_tokenio_r7c_pins.py",
    # [v10, gate round 7 step 2] the new slots' terminal identity and NL-1,
    # and the block-stage terminal identity inside a token run
    "zk60_native_rg_tokenterminals.py",
    "zk60_native_rg_tokenblocks.py",
    # [v12, gate round 10] NL-1 S1-S5 on the new slots, the terminal
    # surjection on the token stages' commitments, the calibration attribution
    "zk60_native_rg_tokennl.py",
    "zk60_native_rg_tokents.py",
    "zk60_native_rg_tokencal.py",
    # [v13, gate round 10] the readings of the token lane's round-9 files
    "zk60_native_rg_tokenio_r9_pins.py",
]

EXPECTED_DISCLOSED = {
    "A": 0,
    "H": 2,
    "external-endpoint": 0,
    "internal-boundary": 0,
    "M": 0,
}


def tool_hashes():
    out = {}
    for t in TOOLS:
        with open(os.path.join(HERE, t), "rb") as fh:
            out[t] = hashlib.sha256(fh.read()).hexdigest()
    return out


def expected_for(view):
    if view.name.startswith("H@"):
        return EXPECTED_DISCLOSED["H"]
    if view.name.startswith("A@"):
        return EXPECTED_DISCLOSED["A"]
    return EXPECTED_DISCLOSED[view.role["commitment_kind"]]


# --------------------------------------------------------------- stage 3
def stage3(bundle, replay, pad_rank=True, terminal_note=None, do_controls=True):
    """Every commitment of every stage, at the run's own shape.

    **[ROUND 9l, ruling GC-2]** each commitment's H-pair now includes the
    sixteen clauses of `zk60_native_rg_exclusivity` (its `exclusivity`
    facts), and the stage carries that module's per-clause negative
    controls (`exclusivity_controls`), which the stage's verdict requires."""
    views, rows = {}, []
    for st in bundle.stages:
        for role in st.roles:
            key = st.key(role["role"])
            v = RunRoleView(
                st, role, replay.stages[st.index]["role_prox_rhos"][key],
                bundle.shape, name=key,
            )
            f = dict(v.run(replay.stages[st.index]["role_lambdas"][key]))
            views[key] = v
            f.pop("xi_vectors", None)
            f.pop("data_rows_index", None)
            f["site_role"] = role["role"]
            f["expected_disclosed_dimension"] = expected_for(v)
            f["meets_expectation"] = f["disclosed_dimension"] == f["expected_disclosed_dimension"]
            rows.append(f)
    # the masking commitment of each stage, as a block with no data row
    masks = []
    for st in bundle.stages:
        blk = mask_block(st)
        d = RunJointSystem([blk]).disclosed(msg_width=bundle.shape.cols)
        masks.append(
            {
                "commitment": blk.name,
                "rows": blk.rows,
                "data_rows": 0,
                "commits_witness_data": False,
                "disclosed_dimension": d["disclosed_fp"],
                "expected_disclosed_dimension": EXPECTED_DISCLOSED["M"],
                "opened_columns": len(st.mask["columns"]),
                "specs": len(st.mask["specs"]),
                "batched_value": "the theta-batched functional of the slots' mask "
                "evaluations; M commits no witness data, so its part over the "
                "commitments' coordinates is 0 and that is computed here, not argued",
                "meets_expectation": d["disclosed_fp"] == EXPECTED_DISCLOSED["M"],
            }
        )
    pad = None
    if pad_rank:
        key = f"B{0}" if bundle.boundaries else bundle.stages[0].key("Input")
        t0 = time.time()
        r, d = views[key].pad_block_rank()
        pad = {
            "commitment": key,
            "distinct_columns": d,
            "pad_positions": views[key].pad_len,
            "exact_rank_of_the_pad_block": r,
            "full_rank": r == d,
            "seconds": round(time.time() - t0, 1),
            "what": "H-pad, computed rather than assumed: the pad block of the {E_j} "
            "over the distinct sampled columns has rank equal to their number, so no "
            "functional of the opened columns is supported on the message positions",
        }
    ok = all(
        r["findings"] == []
        and all(r["reduction_hypotheses"].values())
        and r["column_identity_failures"] == 0
        and r["group_claim_identity_failures"] == 0
        and r["meets_expectation"]
        and r["certifying_minor"]["full_row_rank"]
        and r["certifying_minor"]["determinant_nonzero"]
        and r["distinct_opened_columns_within_pad_count"]
        for r in rows
    ) and all(m["meets_expectation"] for m in masks)
    # [ROUND 9l] one negative control per clause of exclusivity
    xc = (exclusivity_controls(bundle, views) if do_controls
          else {"skipped": "controls not requested", "ok": True})
    return (
        {
            "per_commitment": rows,
            "masking_commitments": masks,
            "expected": EXPECTED_DISCLOSED,
            "pad_block_exact_rank_cross_check": pad,
            "per_slot_terminal_check": terminal_note or PER_SLOT_TERMINAL_OPEN,
            "exclusivity_controls": xc,
            "ok": ok and (pad is None or pad["full_rank"]) and xc["ok"],
        },
        views,
    )


PER_SLOT_TERMINAL_OPEN = {
    "status": "open",
    "what": "the STRONG form of each slot's final check, fin = c*mask_eval + "
    "poly(terminals), with every composition polynomial recomputed from the "
    "published terminals",
    "why_open": "the port `scripts/zk60_native_terminal_polys.py` is a hand-port of "
    "the TOY layout: its `_Layout` namespace carries that shape's plane index table "
    "(A_D .. N_A = 81, H_L .. H_U) and its `SOURCE_PINS` pin argument.rs, layout.rs "
    "and protocol.rs by sha256 at commit 5ca721f, while this bundle's "
    "manifest.json[source_pins] names different digests of the same files at commit "
    "cb27845.  The shape's geometry axes (norm_wrho 31, wrho_s 17, f_e 12, the pads) "
    "ARE in run.json[shape], but the PLANE INDEX TABLE is not, and it is what the 23 "
    "closures read",
    "missing_field": "run.json[shape] carries no plane index table; the A-plane and "
    "H-plane index assignment of layout.rs at the run's shape (A_* / H_* and N_A), "
    "plus the per-slot table push order",
    "is_it_public": "yes -- it is a function of the public layout, not of any hidden "
    "value, so the lane can add it to the bundle without publishing anything new",
    "consequence": "the per-slot terminal identity is NOT checked for a run; the "
    "toy gate checks it for the four single-block captures",
}

# The ONE reason the eleven remaining slots stay open, stated once so that
# the channel table, the stage-8 block and the report cannot drift apart.
PUBLIC_TABLES_OPEN = (
    "`run.json[public_tables_included]` is false, so a bundle carries a public "
    "table's length and SHA-256 but not its values, and the tables these slots "
    "need are folds of the public WEIGHTS (05, 06, 07, 10, 11, 12, 13), the two "
    "norm GAINS gamma_a / gamma_m (14), the RoPE (cos, sin) pair (15, 16) or the "
    "exp and activation table values (19) -- none of which a bundle carries.  "
    "Nothing HIDDEN is missing: all of it is public.  Re-capturing with "
    "HL_RUN_CAPTURE_PUBLIC_TABLES=1 would close them"
)


# --------------------------------------------------------------- stage 8
def stage10(bundle, index, replay, do_controls=True):
    """**ROUND 4, finding S19-F1.**  The two BILINEAR attention slots'
    group factor, derived and compared, and round 4's own controls.

    A bundle with no plane index table cannot be terminal-checked at all,
    so the stage says so and is not a failure -- the same rule stage 8
    keeps.  A bundle written before the repair is replayed under the
    definition that made its bytes and reported SUPERSEDED for those two
    slots; that too is not a failure.
    """
    group = GroupFactors(bundle, replay=replay)
    out = {"group_factor": group.summary()}
    if index is None:
        out["controls"] = {"skipped": "the bundle carries no plane index table, "
                           "so no slot polynomial can be evaluated", "ok": True}
        out["ok"] = out["group_factor"]["ok"]
        return out
    out["controls"] = (group_controls(bundle, index, replay=replay)
                       if do_controls else {"skipped": "controls not requested",
                                            "ok": False})
    out["ok"] = out["group_factor"]["ok"] and (
        out["controls"].get("ok") if do_controls else True)
    return out


def stage8(bundle, replay, old=None, do_controls=True):
    """The PLANE INDEX TABLE, and the per-slot terminal identity it unlocks.

    An OLD bundle (written before stage 15 of the Rust lane) has no table:
    the stage reports that, leaves the channel OPEN with the reason the gate
    had before, and is NOT a failure -- a missing input is not a broken gate.
    """
    index, reason = plane_index_of(bundle)
    if index is None:
        return {
            "plane_index": {"present": False, "reason": reason},
            "terminal_identity": {
                "checked": False,
                "reason": reason,
                "slots_checked": 0,
            },
            "controls": {"skipped": reason},
            "channel_status": "open",
            "ok": True,
            "note": "the bundle predates the plane index table; nothing about it "
            "changed and nothing is claimed for it",
        }, None
    pi = index.summary()
    tables = verify_captured_public_tables(bundle)
    terms = check_terminals(bundle, index, replay=replay)
    ctl = (terminal_controls(bundle, index, replay=replay, old_bundle=old)
           if do_controls else {"skipped": "controls not requested", "ok": False})
    covered = covered_at(bundle)
    covered_ok = (
        terms["ok"]
        and terms["slot_checks_equal"] == terms["slot_checks_expected"]
    )
    return {
        "plane_index": pi,
        "carried_public_tables": tables,
        "terminal_identity": {
            "checked": True,
            "covered_slots": list(covered),
            "covered_slot_names": [n for s, n, fn, _r in PORTS if s in covered],
            "open_slots": terms["open_slots"],
            "slot_checks_attempted": terms["slot_checks_attempted"],
            "slot_checks_equal": terms["slot_checks_equal"],
            "slot_checks_expected": terms["slot_checks_expected"],
            "slot_checks_matching_the_stored_terminal_polynomial":
                terms["slot_checks_matching_the_stored_terminal_polynomial"],
            "derived_group_points_used_and_compared":
                terms["derived_group_points_used_and_compared"],
            "bilinear_group_factor": terms["bilinear_group_factor"],
            "public_tables_rebuilt_and_digest_matched":
                terms["public_tables_rebuilt_and_digest_matched"],
            "rebuilt_public_tables": terms["rebuilt_public_tables"],
            "public_tables_taken_from_the_capture":
                terms["public_tables_taken_from_the_capture"],
            "captured_public_tables": terms["captured_public_tables"],
            "public_table_structure_checks": terms["public_table_structure_checks"],
            "public_table_structure_failures":
                terms["public_table_structure_failures"],
            "public_table_structure_detail": terms["public_table_structure_detail"],
            "what_a_captured_table_does_not_establish":
                terms["what_a_captured_table_does_not_establish"],
            "public_table_digest_failures": terms["public_table_digest_failures"],
            "source_pins": terms["source_pins"],
            "per_stage": terms["per_stage"],
            "findings": terms["findings"],
            "what": terms["what"],
            "ok": terms["ok"],
            # [ROUND 6, finding R6-F1] K4-F1 made the moved-pin arm return
            # every key a caller reads, and one of them -- the sentence
            # saying the zeros are the ABSENCE of a check and not a passing
            # one -- was not copied into the record here, so a reader of the
            # JSON saw zeros with no explanation.  Present only on a
            # refusal, so no healthy record gains a leaf.
            **({"refused_before_any_slot_was_evaluated":
                terms["refused_before_any_slot_was_evaluated"]}
               if "refused_before_any_slot_was_evaluated" in terms else {}),
        },
        "controls": ctl,
        "channel_status": "derived" if covered_ok else "open",
        "ok": pi["ok"] and covered_ok and tables["ok"]
        and (ctl.get("ok") if do_controls else True),
    }, index


# -------------------------------------------------------------- stage 11
FULL_PREIMAGE_OFF = {
    "requested": False,
    "what": "the FULL zero-data preimage -- A and H included, both halves, "
    "every opened column and the salted leaves of the opened columns",
    "why_off": "it is minutes of exact Fp arithmetic per bundle, not seconds, "
    "so it is opt-in (`--full-preimage`); the default gate stays a ~10 s tool "
    "and every figure of rounds 1-6 is taken at the same cost as before",
    "consequence": "the three channels round 1 left OPEN for A and H -- their "
    "vectors, the pad half and the opened column values -- stay OPEN with "
    "round 1's reason, and stage 5's message-half construction for the "
    "singleton-group commitments is unaffected",
    "ok": True,
}


def stage11(bundle, views, do_controls=True):
    """**ROUND 7.**  The preimage construction for every PCS commitment.

    Round 1 skipped `A` and `H` -- "skipped, not faked" -- because the toy
    gate's solve is written at `MSG == PAD == 256`.  `zk60_native_rg_ahpreimage`
    is that solve with the two widths apart; this stage runs it on every PCS
    commitment of every stage and fires round 7's controls.
    """
    order = [k for k in views]
    out = full_preimages(bundle, views, names=order)
    out["requested"] = True
    if do_controls:
        a = next((k for k in order if k.startswith("A@")), None)
        h = next((k for k in order if k.startswith("H@")), None)
        out["controls"] = (
            ah_controls(bundle, views, a_name=a, h_name=h)
            if a and h
            else {"skipped": "this bundle has no A and H pair", "ok": False}
        )
    else:
        out["controls"] = {"skipped": "controls not requested", "ok": False}
    out["ok"] = out["ok"] and out["controls"].get("ok", False)
    return out


MASK_CFS_OFF = {
    "requested": False,
    "what": "the masking commitment M and the masked-sumcheck (CFS) channel "
    "at this run's shape: M's linear view, ONE coefficient vector that meets "
    "every slot's masked rounds and scalar AND M's whole opening, M's opened "
    "columns re-hashed and re-authenticated, and the pad budget",
    "why_off": "it is seconds per stage of exact Fp arithmetic and the "
    "controls are twenty more, so it is opt-in (`--mask-cfs`) exactly as "
    "round 7's arm is; the default gate keeps its cost and every figure of "
    "rounds 1-7 is taken as before",
    "consequence": "the masked round messages and the three channels of M's "
    "own opening -- its q, its proximity vector and its 256 opened columns -- "
    "stay OPEN, with round 1's reason plus a sentence saying round 8 removed "
    "the assumption behind it",
    "ok": True,
}


def stage12(bundle, replay, do_controls=True):
    """**ROUND 8.**  The masking commitment `M` and the CFS channel.

    Channel 7 of the table has said since round 1 that
    `zk60_native_mask_commit` and `zk60_native_jv_cfs` "are written at the
    toy's row layout and slot specs".  `zk60_native_rg_mask` is the
    shape-driven port; this stage runs it on every stage of the run and
    fires round 8's six controls on the first one.
    """
    out = mask_cfs_run(bundle, replay)
    out["requested"] = True
    if do_controls and out.get("stages_checked"):
        out["controls"] = mask_controls_at_shape(bundle, replay, k=0)
    else:
        out["controls"] = {
            "skipped": "controls not requested" if out.get("stages_checked")
            else "the mask layer's pins refused, so nothing was perturbed",
            "ok": False,
        }
    out["ok"] = bool(out["ok"] and out["controls"].get("ok", False))
    return out


# --------------------------------------------------------------- stage 4
def stage4(bundle, views, shared, run_wide=True):
    if getattr(bundle, "standalone", False):
        return _stage4_block(bundle, views, shared, run_wide=run_wide)
    per_boundary = []
    for k in range(bundle.boundaries):
        res = boundary_reserved_figure(bundle, views[f"B{k}"], k)
        three = three_role_figure(bundle, views, shared, k)
        per_boundary.append(
            {
                "boundary": k,
                "restricted_to_the_reserved_rows": res,
                "three_roles_of_the_plane": three,
                "ok": (
                    res["disclosed_on_the_reserved_block_fp"] == 0
                    and res["full_row_rank"]
                    and res["determinant_nonzero"]
                    and three["ok"]
                ),
            }
        )
    whole = None
    pairs = []
    if run_wide:
        t0 = time.time()
        whole = run_wide_figure(bundle, views, shared)
        whole["seconds"] = round(time.time() - t0, 1)
        for k in range(bundle.boundaries):
            sub = [f"A@{k}", f"H@{k}", f"A@{k+1}", f"H@{k+1}", f"B{k}",
                   f"M@{k}", f"M@{k+1}"]
            if k == 0:
                sub.append("E-Input")
            if k == bundle.boundaries - 1:
                sub.append("E-Output")
            pairs.append(
                run_wide_figure(bundle, views, shared, subset=sub,
                                label=f"stages {k} and {k+1} with boundary {k}")
            )
    return {
        "per_boundary": per_boundary,
        "adjacent_stage_pairs": pairs,
        "whole_run": whole,
        "shared_planes": {
            "identified_row_pairs": len(shared["pairs"]),
            "equality_slots": shared["slots"],
            "source_facts": shared["source_facts"],
            "findings": shared["findings"],
        },
        "ruling": "M-8: three blocks at the development rung, all three roles of each "
        "boundary plane ranked jointly, the shared-pair and single-proximity-row "
        "controls included",
        "ruling_R3": RULING_R3,
        "ok": all(b["ok"] for b in per_boundary)
        and not shared["findings"]
        and (whole is None or whole["ok"])
        and all(p["ok"] for p in pairs),
    }


def _stage4_block(bundle, views, shared, run_wide=True):
    """[ROUND 9j] Stage 4 for a STANDALONE block: there is no boundary, so
    ruling M-8's (a) and (b) have no object; (c) is the whole block as one
    system -- `A@0`, `H@0`, `M@0` and both external endpoints, each
    endpoint's data plane identified with `A@0`'s IO plane.  The key
    `whole_run` is kept so that every reader of a record finds the figure
    where it always has."""
    whole = None
    if run_wide:
        t0 = time.time()
        whole = run_wide_figure(bundle, views, shared, label="whole block")
        whole["seconds"] = round(time.time() - t0, 1)
    return {
        "per_boundary": [],
        "adjacent_stage_pairs": [],
        "whole_run": whole,
        "shared_planes": {
            "identified_row_pairs": len(shared["pairs"]),
            "equality_slots": shared["slots"],
            "source_facts": shared["source_facts"],
            "findings": shared["findings"],
        },
        "ruling": "a standalone block has no internal boundary: ruling M-8's "
        "(a) (a boundary restricted to its reserved rows) and (b) (the three "
        "roles of a boundary plane) have no object here.  (c) is computed: "
        "the whole block as one system, both external endpoints' data planes "
        "identified with A@0's IO planes (slots 21 and 22)",
        "ruling_R3": RULING_R3,
        "ok": not shared["findings"] and (whole is None or whole["ok"]),
    }


# --------------------------------------------------------------- stage 7
def channels(bundle, record):
    """Every channel of a RUN's view, with a status and a reason."""
    s3 = record["stage3_per_commitment"]
    s5 = record["stage5_zero_data_preimage"]
    s11 = record.get("stage11_full_preimage") or FULL_PREIMAGE_OFF
    s12 = record.get("stage12_mask_and_cfs") or MASK_CFS_OFF
    s13 = record.get("stage13_joint_run_preimage") or JOINT_OFF
    s8 = record["stage8_plane_index_and_terminals"]
    s9 = record.get("stage9_hash_layer")
    hash_rule_derived = bool(
        s9 is not None
        and s9.get("columns_checked")
        and s9["columns_authenticated"] == s9["columns_checked"]
        and not s9["findings"]
        and not record["hash_rule"]["refusals"]
    )
    _ti = s8["terminal_identity"]
    open_slots = ([e["slot"] for e in _ti["open_slots"]] if _ti.get("checked")
                  else [s for s, _n, _fn, r in PORTS if r is not None])
    pre = {p["commitment"]: p for p in s5["per_commitment"]}
    constructed = [c for c, p in pre.items() if p.get("preimage_exhibited")]
    ver_ok = all(
        p["verification"]["all_entries_equal"]
        for p in pre.values()
        if "verification" in p
    )
    disclosed = {r["role"]: r["disclosed_dimension"] for r in s3["per_commitment"]}
    # [ROUND 7] the FULL construction, when it was asked for: every PCS
    # commitment of every stage, both halves, the opened columns and their
    # salted leaves.  `full_ok` is what moves three channels off OPEN, and it
    # is true only when every commitment the run has was exhibited AND
    # verified AND every control fired.
    full_names = list(s11.get("commitments") or [])
    full_done = list(s11.get("exhibited") or [])
    pcs_names = [r["role"] for r in s3["per_commitment"]]
    full_ok = bool(
        s11.get("requested")
        and s11.get("ok")
        and s11.get("view_entries_differing") == 0
        and sorted(full_done) == sorted(pcs_names)
    )
    full_entries = s11.get("view_entries_compared", 0)
    full_leaves = s11.get("salted_leaves_authenticated", 0)
    # [ROUND 8] the masking layer.  `mask_ok` is what moves four channels off
    # OPEN, and it is true only when every stage was exhibited AND verified
    # with nothing differing AND every control fired.
    mask_ok = bool(
        s12.get("requested")
        and s12.get("ok")
        and s12.get("entries_differing") == 0
        and s12.get("stages_checked")
    )
    mask_entries = s12.get("entries_recomputed", 0)
    mask_leaves = s12.get("salted_leaves_authenticated", 0)
    mask_stages = s12.get("per_stage") or []
    mask_why_open = s12.get("why_off") or s12.get("why_not_checked") or (
        "the construction ran and did not close on every stage"
        if s12.get("requested") else None
    )
    joint_ok = bool(
        s13.get("requested") and s13.get("ok")
        and s13.get("entries_differing") == 0
    )
    # `.get` throughout: a stage that REFUSED carries zeroed counts rather
    # than no counts, and this summary must not crash on one (K4-F1).
    def _mask_sum(field):
        return sum(
            (st.get("entries_recomputed") or {}).get(field, 0)
            for st in mask_stages
        )

    mask_round_entries = _mask_sum("masked_round_entries")
    mask_scalars = _mask_sum("masked_scalars")
    mask_columns = _mask_sum("column_entries")
    MASK_PORT_OPEN = (
        "the CFS analysis (zk60_native_jv_cfs) and the mask-row port "
        "(zk60_native_mask_commit) are written at the toy's capture and "
        "replay TYPES, at the toy's three mask-domain constants and with no "
        "shape to check the slot specs against, and they do not hash.  Round "
        "8 supplied all five (zk60_native_rg_mask.LAYOUT_SPECIFIC) and the "
        "arm is simply not switched on in this record"
    )
    full_why_open = s11.get("why_off") or (
        "the construction ran and did not close: "
        + ", ".join(sorted(set(full_names) - set(full_done)))
        if s11.get("requested")
        else None
    )
    # [ROUND 9j] a standalone block has no segment; its channel is replaced
    # by `block_channel_table` below, so the run's list is never read there
    seg = [
        {"stage": st.index, "bytes": st.doc["segment_bytes"],
         "sha256": st.doc["segment_sha256"][:16]}
        for st in bundle.stages
    ] if not getattr(bundle, "standalone", False) else []
    ch = [
        # ------------------------------------------------ the commitment side
        {
            "channel": "opening-group and proximity vectors, message half "
            "(the internal boundaries and the two external endpoints)",
            "section": "run 2.1",
            "status": "constructed" if constructed and ver_ok else "open",
            "assumption": None,
            "preimage_exhibited": bool(constructed and ver_ok),
            "how": "every group of these commitments is a singleton, so at each of the "
            "1,024 message positions the view is one 2(G+1) x (non-data rows) system "
            "over Fp; with the hidden data fixed to zero it is solved exactly and the "
            "view recomputed entry by entry",
            "commitments": constructed,
        },
        {
            "channel": "claim values (the internal boundaries and the two external "
            "endpoints)",
            "section": "run 2.1",
            "status": "constructed" if constructed and ver_ok else "open",
            "assumption": None,
            "preimage_exhibited": bool(constructed and ver_ok),
            "how": "recomputed from the exhibited zero-data randomness and compared "
            "with the capture",
        },
        {
            "channel": "opening-group and proximity vectors of A and H",
            "section": "run 2.1",
            "status": "constructed" if full_ok else "open",
            "assumption": None,
            "preimage_exhibited": bool(full_ok),
            # [ROUND 7] round 1's reason, kept verbatim as the reason the
            # channel is open WHEN THE ARM DID NOT RUN -- and replaced by the
            # construction when it did.
            "reason": None if full_ok else (
                "their opening groups have several members, so each claim's own "
                "published value is an extra constraint; the correction step that "
                "handles it is in zk60_native_pg_pcs, whose MSG == PAD == 256 does not "
                "hold at this shape (1,024 message positions against 256 pads).  "
                "ROUND 7 removed that assumption; " + str(full_why_open)
            ),
            "how": (
                "zk60_native_rg_ahpreimage: the same solve with the two widths apart. "
                "Per group, the whole per-position residual on one anchor pair, then a "
                "correction inside the kernel of that constraint meeting every claim's "
                "own published value and the public zero-sum rows; the proximity pair "
                "last; then each row's pad polynomial by Lagrange interpolation through "
                "the d distinct sampled nodes.  The view is then RECOMPUTED from the "
                "solved blinding and compared entry by entry"
                if full_ok else None
            ),
            "commitments": full_done if full_ok else [],
            "what_is_computed_instead": {
                "disclosed_dimension_by_exact_rank": {
                    k: v for k, v in disclosed.items() if k.startswith(("A@", "H@"))
                },
                "note": "A discloses 0 and H discloses 2, the public LogUp identity, "
                "with a certifying minor; that is a rank, not a preimage",
            },
        },
        {
            "channel": "the pad half of every published vector",
            "section": "run 2.1",
            "status": "constructed" if full_ok else "open",
            "assumption": None,
            "preimage_exhibited": bool(full_ok),
            "reason": None if full_ok else (
                "constructing it needs the Lagrange interpolation through the "
                "distinct sampled nodes and the Z_S divisibility test of "
                "zk60_native_pg_pcs, which assumes MSG == PAD; what IS computed is "
                "H-pad, the exact rank of the pad block over the distinct opened "
                "columns.  ROUND 7 removed that assumption; " + str(full_why_open)
            ),
            "how": (
                "the fibre of each row's pad is I(p_i) + Z_S q_i with deg q_i < Q - d; "
                "the pad half of each combination then fixes sum_i rho[i] q_i, which is "
                "a polynomial only when the residual is divisible by Z_S -- exactly "
                "when the verifier's own sampled-column identity holds"
                if full_ok else None
            ),
            "excluded": "the masking commitment M's own opening, which is the "
            "separate CFS channel below",
        },
        {
            "channel": "opened column values",
            "section": "run 2.1",
            "status": "constructed" if full_ok else "open",
            "assumption": None,
            "preimage_exhibited": bool(full_ok),
            "reason": None if full_ok else (
                "they are a function of the pads, which are not constructed here; the "
                "verifier's own column identity IS reproduced from the model on a "
                "sample of columns of every commitment, with no failures.  ROUND 7 "
                "constructs them; " + str(full_why_open)
            ),
            "how": (
                "every row of every PCS commitment is re-encoded from the solved "
                "(zero data + blinding) and read at every distinct sampled position, "
                "and compared with the capture; the rebuilt columns are then re-hashed "
                "under the bundle's own rule and their salted leaves re-authenticated "
                "against the PUBLISHED salts and paths"
                if full_ok else None
            ),
            "entries_recomputed_and_compared": full_entries if full_ok else None,
            "salted_leaves_authenticated": full_leaves if full_ok else None,
            "unopened_leaves": "NOT reproducible from any preimage and not claimed: "
            "an unopened leaf is a salted digest, its hiding is M-2 / M-3, and that "
            "channel stays ARGUED",
            "identities_reproduced": sum(
                r["column_identity_checked"] for r in s3["per_commitment"]
            ),
            "identity_failures": sum(
                r["column_identity_failures"] for r in s3["per_commitment"]
            ),
        },
        {
            "channel": "column indices (PCS and M)",
            "section": "run 2.1",
            "status": "derived",
            "assumption": None,
            "preimage_exhibited": None,
            "function": "Transcript::challenge_indices over the public prefix; the "
            "gate's stage 2 re-derives every index of every opening of every stage",
            "recomputed": True,
        },
        {
            "channel": "every Fiat-Shamir challenge of the run (definition draws, the "
            "slot challenges c, the sumcheck rhos, theta, the M proximity rhos, the "
            "opening lambdas and proximity coefficients)",
            "section": "run 2.1",
            "status": "derived",
            "assumption": None,
            "preimage_exhibited": None,
            "function": "re-derived with BLAKE3 from the bundle's public data",
            "challenges_rederived": record["stage2_transcript_replay"][
                "challenges_checked"
            ],
            "positions_compared": record["stage2_transcript_replay"]["positions_checked"],
        },
        {
            "channel": "the masked sumcheck round messages and the published scalars",
            "section": "run 2.1",
            "status": "constructed" if mask_ok else "open",
            "assumption": None,
            "preimage_exhibited": bool(mask_ok),
            "reason": None if mask_ok else mask_why_open or MASK_PORT_OPEN,
            "entries_recomputed_and_compared": (
                mask_round_entries + mask_scalars if mask_ok else None
            ),
            "how": (
                "zk60_native_rg_mask: per slot, the system "
                "c_s R_s coef_s = masked_s - honest_s and "
                "c_s <w_s, coef_s> = scalar_s - sigma_s is solved exactly over "
                "Fp at a FIXED, named, public transcript (the flat honest one "
                "whose claimed sum the hosted slots' published scalars force), "
                "projected onto the functional identities M's opening pins; "
                "every published round value and scalar is then RECOMPUTED "
                "from (fixed transcript + solved coefficients) and compared"
                if mask_ok else None
            ),
            "the_fixed_data_is_not_the_zero_witness_s_transcript": (
                "the honest unmasked rounds are in no capture and are not "
                "recoverable from one; what is fixed is a named public "
                "element of the channel's data space, and the statement is "
                "about the view map"
                if mask_ok else None
            ),
            "joint_note": "the masking commitment IS carried in the joint system "
            "as a block with 2S+4 rows and no data row, and its part over the "
            "commitments' coordinates is computed as 0",
        },
        {
            "channel": "the masking commitment M's opening: the product "
            "polynomial q and the one batched functional value it pins",
            "section": "run 2.1 (NEW)",
            "status": "constructed" if mask_ok else "open",
            "assumption": None,
            "preimage_exhibited": bool(mask_ok),
            "reason": None if mask_ok else mask_why_open or MASK_PORT_OPEN,
            "disclosed_fp_computed": (
                [st["disclosed"]["disclosed_fp_computed"] for st in mask_stages]
                if mask_ok else None
            ),
            "how": (
                "b is DEFINED as the residue q - sum_s a_s W_s, so q is "
                "reproduced by construction and what the channel really pins "
                "is b's zero-sum admissibility, 512 (q[0] + q[512]) = V(a).  "
                "The disclosed dimension is COMPUTED as the exact Fp rank of "
                "V over the coefficient unknowns, and the refusal one off the "
                "V plane is exhibited beside it"
                if mask_ok else None
            ),
        },
        {
            "channel": "the masking commitment M's proximity vector",
            "section": "run 2.1 (NEW)",
            "status": "constructed" if mask_ok else "open",
            "assumption": None,
            "preimage_exhibited": bool(mask_ok),
            "reason": None if mask_ok else mask_why_open or MASK_PORT_OPEN,
            "how": (
                "u is DEFINED as the residue prox - sum_row rho_row * row, so "
                "the proximity vector is reproduced by construction; its "
                "entry count records that two arithmetic paths agree"
                if mask_ok else None
            ),
        },
        {
            "channel": "the masking commitment M's own opened columns (and "
            "their salted leaves)",
            "section": "run 2.1 (NEW)",
            "status": "constructed" if mask_ok else "open",
            "assumption": None,
            "preimage_exhibited": bool(mask_ok),
            "reason": None if mask_ok else mask_why_open or MASK_PORT_OPEN,
            "entries_recomputed_and_compared": mask_columns if mask_ok else None,
            "salted_leaves_authenticated": mask_leaves if mask_ok else None,
            "how": (
                "genuinely independent data: the pads were solved by a "
                "rational interpolation through the distinct sampled nodes "
                "and every one of M's 50 rows is re-encoded here through the "
                "NTT path mask_commit itself uses, then read at every sampled "
                "node; the rebuilt columns are re-hashed under the bundle's "
                "own derived rule and their salted leaves re-authenticated "
                "against the PUBLISHED salts and 12-level paths"
                if mask_ok else None
            ),
            "unopened_leaves": "NOT reproducible from any preimage and not "
            "claimed: M-2 / M-3, and that channel stays ARGUED",
        },
        {
            "channel": "the derived mask evaluation per slot (the terminal identity) "
            "-- the slots whose composition polynomial this gate recomputes",
            "section": "run 2.1",
            "status": s8["channel_status"],
            "assumption": None,
            "preimage_exhibited": False,
            "slots": (s8["terminal_identity"].get("covered_slots") or []),
            "slot_checks": s8["terminal_identity"].get("slot_checks_equal", 0),
            "of": s8["terminal_identity"].get("slot_checks_expected", 0),
            "reason": (
                None
                if s8["channel_status"] == "derived"
                else s8["terminal_identity"].get("reason")
                or PER_SLOT_TERMINAL_OPEN["why_open"]
            ),
            "derivation": (
                "fin_s == c_s*mask_eval_s + poly_s(vals_s), recomputed from the "
                "PUBLISHED terminals at the run's real challenges and compared with "
                "the capture's own terminal_polynomial, in every stage.  The plane "
                "index table (run.json[plane_index], stage 15) says which plane each "
                "terminal is an evaluation of; the public tables that are a function "
                "of the shape are rebuilt and checked against the capture's SHA-256"
                if s8["channel_status"] == "derived"
                else None
            ),
        },
        {
            "channel": "the derived mask evaluation per slot (the terminal identity) "
            "-- the slots whose public tables the bundle does not carry",
            "section": "run 2.1 (NEW)",
            "status": "derived" if open_slots == [] and s8["plane_index"].get("present")
            else "open",
            "assumption": None,
            "preimage_exhibited": False,
            "slots": open_slots,
            "reason": (
                None
                if open_slots == [] and s8["plane_index"].get("present")
                else PUBLIC_TABLES_OPEN
                if s8["plane_index"].get("present")
                else s8["terminal_identity"].get("reason", NO_TABLE)
            ),
            "derivation": (
                "this bundle carries `public_tables_included: true`, so the eleven "
                "slots that read a fold of the public weights, the norm gains, the "
                "RoPE pair or a lookup table's values ARE evaluated: each table is "
                "checked against the capture's own length and SHA-256 and against "
                "the structure its builder gives it, and the identity holds at the "
                "run's real challenges in every stage"
                if open_slots == [] and s8["plane_index"].get("present")
                else None
            ),
            "is_it_public": "yes -- every such table is a function of the PUBLIC "
            "statement (the weights, the norm gains, the RoPE constants, the exp and "
            "activation tables), so carrying it publishes nothing new",
        },
        # ------------------------------------------ NEW FOR A TAGGED RUN (D19)
        {
            "channel": "the hash RULE of the run: which BLAKE3 made every byte, "
            "and the four keys of a tagged profile",
            "section": "run 2.3 (NEW)",
            "status": "derived" if hash_rule_derived else "open",
            "assumption": None,
            "preimage_exhibited": False,
            "reason": None if hash_rule_derived else (
                (s9 or {}).get("findings") or ["no hash layer was computed"]
            )[0],
            "caveat": (
                "this bundle predates the tag (no `hash_tag` member), so the rule "
                "was DERIVED as the legacy one from the schema era and not compared "
                "against a declared one; the profile itself is tagged, so the bundle "
                "is SUPERSEDED and nothing measured on it is a statement about what "
                "the profile produces now"
                if record["hash_rule"]["superseded"] else None
            ),
            "rule": None if s9 is None else s9.get("hash_rule"),
            "derivation": "the four context strings and the list of legacy profiles "
            "are pinned in the gate's own source, the key set is DERIVED from the "
            "profile the bundle's shape names (the port of Shape::hash_tag) and "
            "compared with the bundle's declared hash_tag member by member -- "
            "re-derive, never consume (ruling T-7).  The bytes are then shown to be "
            "under that rule: the whole transcript replays, and every opened column "
            "re-hashes and re-authenticates, only under it",
            "columns_authenticated": None if s9 is None else s9.get(
                "columns_authenticated"
            ),
            "of": None if s9 is None else s9.get("columns_checked"),
            "keys_are_public": "yes -- each key is blake3.derive_key(<public "
            "context>, <public profile>), so publishing them discloses nothing; "
            "they are never an INPUT",
        },
        {
            "channel": "the Merkle roots (A, H, M per stage, the L-1 boundary roots, "
            "the two endpoint roots)",
            "section": "run 2.1",
            "status": "argued",
            "assumption": "M-2",
            "preimage_exhibited": None,
            "model_assumption": "the roots are generated by the prover itself (ruling "
            "D18) and indistinguishability rests on M-2, the hiding of unopened salted "
            "leaves in the random-oracle model.  A boundary root is an observed "
            "commitment and NOT part of the run statement",
            "what_stage_9_adds_and_what_it_does_not": "stage 9 re-hashes every OPENED "
            "column and folds its path to the root under the rule, so the root is "
            "COMPUTED from the opened data rather than read -- a soundness-side "
            "check.  The channel stays ARGUED because what it is about is HIDING: "
            "what an unopened leaf reveals is M-2's assumption either way",
            "roots_this_run": record["stage1_integrity"]["distinct_roots_opened"] + len(
                bundle.stages
            ),
        },
        {
            "channel": "leaf salts",
            "section": "run 2.1",
            "status": "argued",
            "assumption": "M-3",
            "preimage_exhibited": None,
            "model_assumption": "fresh uniform bytes in both worlds; equality of the "
            "two laws rests on M-3, the assumption that the whole output stream of "
            "ZkRng is indistinguishable from uniform",
            "counts": {
                "per_opening": bundle.shape.opened_cols,
                "openings": sum(len(st.roles) + 1 for st in bundle.stages),
            },
        },
        {
            "channel": "authentication paths",
            "section": "run 2.1",
            "status": "argued",
            "assumption": "M-2",
            "preimage_exhibited": None,
            "model_assumption": "the paths are genuine hashes of the same world's own "
            "columns; hiding of the unopened leaf digests rests on M-2.  That they "
            "ARE genuine hashes of this run's own columns is now computed, not "
            "assumed (stage 9), including each path's LENGTH against the tree depth "
            "-- the check that stops an inner node being presented as a salted leaf",
            "levels": {
                "pcs": bundle.shape.log_cols + bundle.shape.inv_rate.bit_length() - 1,
                "mask": bundle.shape.mask_log_dom,
            },
        },
        # ---------------------------------------------- NEW FOR A RUN
        {
            "channel": "the sequencing surface: the number of segments, their byte "
            "lengths and their position tags",
            "section": "run 2.2 (NEW)",
            "status": "argued",
            "assumption": "shape facts + ruling M-6",
            "preimage_exhibited": None,
            "model_assumption": "L is a public word of the run statement (absorbed "
            "under run-shape) and a segment's length is a function of the shape and of "
            "the stage's position, not of the witness; the position tags are squeezed "
            "from a DISCARDED transcript clone, compared by the verifier and never "
            "absorbed (ruling M-6), so they are a public function of public transcript "
            "data.  EVIDENCE, not proof: the two bundles are independent runs on "
            "different hidden inputs and their three segment lengths agree exactly",
            "segments": seg,
            "position_tags_rederived": record["stage2_transcript_replay"][
                "segment_position_tags"
            ],
        },
        {
            "channel": "the cross-block joint law beyond the linear rank",
            "section": "run 2.2 (NEW)",
            "status": "open",
            "assumption": None,
            "preimage_exhibited": None,
            # [ROUND 9j, CORRECTED 2026-09-23, status page row 28] the reason
            # used to say the composition argument for a run "is unwritten"
            # and ended with ruling R-3's quote, whose "to be machine-asserted
            # elsewhere" was an instruction since carried out for single
            # blocks.  The grade does not move: a reduction is not a
            # computation of this gate.
            "reason": "obligation O-R3: what is computed here is a RANK of a linear "
            "model over the run's commitments.  The joint LAW of a run is Theorem B "
            "-- the toy theorem per stage plus one factorisation over stages, whose "
            "key hypothesis (no run-wide masking commitment; every slot of block k "
            "masked by block k's own M) is a fact of the code -- WRITTEN and "
            "ACCEPTED AS A REDUCTION (ZK60_JOINT_LAW_COMPOSITION_RUN_DISPOSITION.md, "
            "2026-09-20 17:58, section 1), conditional on G-R1, G-R2 and G-R4.  The "
            "draw accounting ruling R-3 asked for is machine-asserted on "
            "single-block proofs (lane stage 36), not at run scope and not at 125M.  "
            "The check's OMITTED CONDITION 7 -- that the gate must rank the two A "
            "commitments that hold the same plane, not the boundary alone -- IS met "
            "by stage 4(b)",
            "ruling_R3": RULING_R3,
            "ruling_R3_as_of_2026_09_23": R3_STATUS_20260923,
            "corrected": "2026-09-23 (round 9j, ZK60_SHAPED_PRIVACY_PATH_STATUS.md "
            "section 4 row 28): until this date the reason read 'a composition "
            "argument for a run, which is unwritten' and ended with ruling R-3's "
            "'is to be machine-asserted elsewhere'; Theorem B was written and "
            "accepted as a reduction on 2026-09-20 and the draw accounting is "
            "asserted on single blocks since lane stage 36.  Grade unchanged: OPEN",
        },
        {
            "channel": "the preimage construction for a RUN (one randomness "
            "reproducing the whole run's view under a fixed input)",
            "section": "run 2.2 (NEW)",
            "status": "constructed" if joint_ok else "open",
            "assumption": None,
            "preimage_exhibited": bool(joint_ok),
            "joint": (
                {
                    "entries_compared": s13.get("entries_compared"),
                    "entries_differing": s13.get("entries_differing"),
                    "salted_leaves_authenticated": s13.get(
                        "salted_leaves_authenticated"),
                    "couplings_respected": s13.get("all_four_couplings_respected"),
                    "identified_row_pairs_all_data": s13["couplings"][
                        "C1_shared_planes"]["both_sides_are_data_rows"],
                    "pairs_touching_a_blinding_row": s13["couplings"][
                        "C1_shared_planes"]["pairs_touching_a_blinding_row"],
                }
                if joint_ok else None
            ),
            "how": (
                "the product of round 7's per-commitment blinding and round "
                "8's per-stage mask coefficients and M blinding, over a data "
                "block that is zero in EVERY commitment.  It is joint because "
                "the only coordinates two commitments share are the boundary "
                "and endpoint DATA planes, checked row by row to be data rows "
                "on both sides and zero on both sides; a shared BLINDING row "
                "would be round 7's control P-5.  Every published number each "
                "part meets is the same number wherever it appears"
                if joint_ok else None
            ),
            "still_not_shown": (
                s13.get("what_it_does_not_show") if joint_ok else None
            ),
            "reason": None if joint_ok else (
                "exhibited PER COMMITMENT for all "
                f"{len(full_done)} PCS commitments of the run, both halves, every "
                "opened column and their salted leaves (round 7).  It is still not a "
                "RUN preimage: a run preimage is a JOINT object -- one randomness "
                "reproducing every stage's view at once with each boundary plane "
                "shared between three commitments -- and round 7's control P-5 is "
                "exactly the case where per-commitment preimages exist and no joint "
                "one does.  " + (
                    "The masking layer is now constructed too (round 8), per "
                    "STAGE, and round 8's control M-5 is the same gap one "
                    "layer down: two slots whose rounds each FORCE the same "
                    "coefficient index have no joint assignment when the "
                    "forced values differ"
                    if mask_ok else "The CFS channel is unconstructed as well"
                )
                if full_ok else
                "exhibited here per commitment, message half only, for the "
                f"{len(constructed)} singleton-group commitments of the run.  A RUN "
                "preimage is a joint object: it must reproduce every stage's view at "
                "once with the boundary planes shared between three commitments, and "
                "it needs the pad half and the CFS channel first"
            ),
            "constructed_so_far": full_done if full_ok else constructed,
            "per_commitment_not_joint": True,
        },
        # [ROUND 9j, CORRECTED 2026-09-23, status page row 26] OPEN -> ARGUED.
        {
            "channel": "the boundary scale tags and the one calibration identity",
            "section": "run 2.2 (NEW)",
            "status": "argued",
            "assumption": "D12b(3) as built (ruling R-5) + ruling M-4",
            "preimage_exhibited": None,
            "model_assumption": "a boundary's scale pair is a CONSTANT of the "
            "approved calibration and so carries nothing about the hidden input: "
            "RunStatement::new refuses any interior scale pair but ENDPOINT_SCALES "
            "(ruling R-5, register D12b item 3; built at lane stage 21 item 3, "
            "71c6509, 2026-09-20; run.rs at every capture commit since 0426ad2 -- "
            "zk60_native_rg_runpins READINGS on 65d55d25 -- and at f4697f9 "
            "run.rs:143-169), and the scales are then bound through the ONE "
            "calibration identity the run header absorbs (ruling M-4).  The gate "
            "reads the declared scales as public constants and checks that the run "
            "declares one calibration identity; it does NOT re-run R-5's refusal, "
            "which is a code fact the run.rs pin covers",
            "corrected": "2026-09-23 (round 9j, ZK60_SHAPED_PRIVACY_PATH_STATUS.md "
            "section 4 row 26): until this date this channel was graded OPEN on "
            "check A7.5 -- 'nothing in the run's privacy section covers the "
            "boundary's scale/calibration binding, and D12 item 5 records that a "
            "tag equality check would pass on a factor-of-8 mismatch'.  D12b(3) "
            "closed that BY CONSTRUCTION at lane stage 21 (2026-09-20), so the "
            "grade was stale",
            "boundary_scales": bundle.run.get("boundary_scales"),
            "one_calibration_identity": True,
        },
        # ---------------------------------------------- out of band
        {
            "channel": "whether a proof attempt produced a receipt (refusal events)",
            "section": "run 2.2",
            "status": "open",
            "assumption": None,
            "preimage_exhibited": None,
            # [ROUND 9j, CORRECTED 2026-09-23, status page row 27] the entropy
            # side of it; grade unchanged
            "reason": "the refusal channel is inside the game (ruling C-2); a capture "
            "exists only when the run was accepted.  Its ENTROPY side is one "
            "fail-closed read per generator and THREE generators per run, accepted "
            "as built (ruling R-2 of ZK60_JOINT_LAW_COMPOSITION_RUN_DISPOSITION.md; "
            "J-2; run memo section 6.3): prove_run makes ONE "
            "ZkRng::from_os(run_seed_domain(profile)) before the run header is "
            "absorbed and before stage 0 (run.rs:523 at f4697f9), every boundary "
            "is drawn from that stream, and the two external endpoints read once "
            "each (endpoint_g.rs:269); boundary.rs's own from_os is in its test "
            "module.  A run's other refusals (a witness the builder refuses, a "
            "lookup miss under CS-3) can still fire inside stage k and name the "
            "stage: rule M-9 / D12b(1) governs who may see that reason",
            "corrected": "2026-09-23 (round 9j, ZK60_SHAPED_PRIVACY_PATH_STATUS.md "
            "section 4 row 27): until this date the reason read 'with 49 "
            "commitments a run makes 23 more ZkRng::from_os calls, and from_os "
            "fails closed -- now possibly in stage 12, minutes in (A7.2)', the "
            "design's one-generator-per-commitment recommendation, which ruling "
            "R-2 withdrew on 2026-09-20.  Grade unchanged: OPEN",
        },
        {
            "channel": "rejected-but-emitted receipts",
            "section": "run 2.2",
            "status": "open",
            "assumption": None,
            "preimage_exhibited": None,
            "reason": "history item H8, a procedural condition on the deployment",
        },
        {
            "channel": "retained captures",
            "section": "run 2.2",
            "status": "open",
            "assumption": None,
            "preimage_exhibited": None,
            # [TINYLLAMA PORT, tools v3, finding G-3] a TRAINED bundle's
            # hidden input is not a synthetic fixture: it is held-out
            # calibration data (or the all-zero plane).  Frozen-profile
            # records keep their sentence byte for byte.
            "reason": ("history item H9: a retained capture is a published "
                       "opening.  This bundle's hidden input is REAL held-out "
                       "calibration data of the trained export (or the all-zero "
                       "plane), which the export itself stores in the repository "
                       "(seq_*/x_in_L*.bin), so retaining it publishes nothing "
                       "new; a capture of a NON-public input would be a published "
                       "opening of a real input and falls under D21.  The writer "
                       "is behind #[cfg(test)]"
                       if bundle.run["shape"].get("trained_calibration") is True
                       else
                       "history item H9: a retained capture is a published opening.  "
                       "This bundle is of a deliberately public synthetic fixture and its writer "
                       "is behind #[cfg(test)]"),
        },
        {
            "channel": "timing, memory, power",
            "section": "run 2.2",
            "status": "open",
            "assumption": None,
            "preimage_exhibited": None,
            "reason": "declared out of scope for the first MVP (M-5, ruling C-2).  A "
            "run adds per-stage wall-clock and a per-stage high-water mark to what an "
            "observer could time; no field of the capture bears on it",
        },
        {
            "channel": "prior proofs by the same prover",
            "section": "run 2.2",
            "status": "open",
            "assumption": None,
            "preimage_exhibited": None,
            "reason": "open item U-3b; this gate analyses one run at a time",
        },
        {
            "channel": "the integer-range facts the statement implies",
            "section": "run 2.2",
            "status": "open",
            "assumption": None,
            "preimage_exhibited": None,
            "reason": "chain item 20: the statement implies the hidden values are in "
            "range, which is information about them that no preimage argument removes",
        },
        {
            "channel": "any nonlinear functional of the joint view",
            "section": "run 2.2",
            "status": "open",
            "assumption": None,
            "preimage_exhibited": None,
            "reason": "chain item 21: the terminal identity links the commitment and "
            "masking channels with degree up to 4 in the terminals, and stage 8 now "
            "EVALUATES that identity for the covered slots -- but the DISCLOSURE "
            "model of stages 3 and 4 is still a rank over a linear model, so a "
            "nonlinear functional of the joint view is outside it",
        },
    ]
    # [ROUND 9j] a standalone block: the boundary words dropped and each of
    # the four run-only channels replaced IN ITS POSITION by its block
    # counterpart (zk60_native_rg_block.block_channel_table)
    if getattr(bundle, "standalone", False):
        ch = block_channel_table(ch, bundle, record)
    counts = {}
    for c in ch:
        counts[c["status"]] = counts.get(c["status"], 0) + 1
    bad = []
    for c in ch:
        st = c.get("status")
        if st not in ("constructed", "derived", "argued", "open"):
            bad.append(f"{c['channel']}: status {st!r} is not one of the four labels")
        if st == "constructed" and not c.get("preimage_exhibited"):
            bad.append(f"{c['channel']}: constructed but no preimage exhibited")
        if st == "argued" and not c.get("assumption"):
            bad.append(f"{c['channel']}: argued but no assumption named")
        if st == "open" and not c.get("reason"):
            bad.append(f"{c['channel']}: open with no reason")
    return {
        "channels": ch,
        "counts": counts,
        "total": len(ch),
        "new_for_a_run": [c["channel"] for c in ch if "(NEW)" in c["section"]],
        **({"block_counterparts_of_the_run_only_channels":
            [c["channel"] for c in ch if c["section"].startswith("block")]}
           if getattr(bundle, "standalone", False) else {}),
        "grading_failures": bad,
        "ok": not bad,
    }


# ------------------------------------------------------------------- main
def run_gate(bundle_dir, other_dir=None, pad_rank=True, run_wide=True,
             do_controls=True, old_dir=None, cross_profile_dir=None,
             full_preimage=False, mask_cfs=False):
    t0 = time.time()
    # [ROUND 9j] a run bundle or a standalone block bundle, by what the
    # directory holds; a block takes the block layer's pins, integrity,
    # replay header, run-control analogues and channel wording
    bundle = load_bundle(bundle_dir)
    standalone = getattr(bundle, "standalone", False)
    record = {
        "gate": "zk60-native-run-gate",
        "version": 1,
        "privacy_property_established": False,
        "privacy_acceptance": False,
        "privacy_review_complete": bundle.run["privacy_review_complete"],
        "what_this_is": (
            "the linear channels of ONE captured STANDALONE private block "
            f"({bundle.profile}), at that proof's real challenges"
            if standalone else
            "the linear channels of ONE captured private run of "
            f"{bundle.blocks} blocks at the development rung shape, at that "
            "run's real challenges"),
        "bundle": bundle.name,
        "bundle_dir": bundle.dir,
        "tool_sha256": tool_hashes(),
    }
    # [ROUND 6, finding K4-F2] the RUN LAYER's own pins, before any stage.
    # Until 2026-09-21 `run_capture.rs`, `run.rs` and `boundary.rs` were
    # pinned by no run-gate tool at all, and a comment said otherwise.  A
    # digest this gate has not read leaves the AFFECTED STAGES not checked by
    # name -- never a crash, which is finding K4-F1's lesson one layer up.
    if standalone:
        rlp = check_block_layer_pins(bundle)
        record["block_layer_source_pins"] = rlp
    else:
        rlp = check_run_layer_pins(bundle)
        record["run_layer_source_pins"] = rlp
    suspended = rlp["stages_not_checked"]

    def _skipped(stage):
        return stage in suspended

    if _skipped("stage1_integrity"):
        record["stage1_integrity"] = not_checked(
            "stage1_integrity", suspended["stage1_integrity"])
    else:
        record["stage1_integrity"] = (block_integrity(bundle) if standalone
                                      else integrity(bundle))
    record["hash_rule"] = bundle.hash_rule_record.copy()
    record["hash_rule"].pop("rule", None)
    other = load_bundle(other_dir) if other_dir else None
    old = load_bundle(old_dir) if old_dir else None
    if _skipped("stage2_transcript_replay"):
        replay = None
        record["stage2_transcript_replay"] = not_checked(
            "stage2_transcript_replay", suspended["stage2_transcript_replay"])
    else:
        replay = (BlockReplay(bundle) if standalone else RunReplay(bundle)).run()
        record["stage2_transcript_replay"] = replay.summary()
    if _skipped("stage8_plane_index_and_terminals"):
        s8, _index = None, None
        record["stage8_plane_index_and_terminals"] = not_checked(
            "stage8_plane_index_and_terminals",
            suspended["stage8_plane_index_and_terminals"])
    else:
        s8, _index = stage8(bundle, replay, old=old, do_controls=do_controls)
        record["stage8_plane_index_and_terminals"] = s8
    if _skipped("stage10_bilinear_group_factor"):
        record["stage10_bilinear_group_factor"] = not_checked(
            "stage10_bilinear_group_factor",
            suspended["stage10_bilinear_group_factor"])
    else:
        record["stage10_bilinear_group_factor"] = stage10(
            bundle, _index, replay, do_controls=do_controls)
    if _skipped("stage3_per_commitment"):
        views = {}
        record["stage3_per_commitment"] = not_checked(
            "stage3_per_commitment", suspended["stage3_per_commitment"])
    else:
        note = dict(s8["terminal_identity"])
        note["status"] = s8["channel_status"]
        s3, views = stage3(bundle, replay, pad_rank=pad_rank,
                           terminal_note=note, do_controls=do_controls)
        record["stage3_per_commitment"] = s3
    if _skipped("stage4_the_boundary"):
        shared = None
        record["stage4_the_boundary"] = not_checked(
            "stage4_the_boundary", suspended["stage4_the_boundary"])
    else:
        shared = discover_shared_planes(bundle)
        record["stage4_the_boundary"] = stage4(bundle, views, shared,
                                               run_wide=run_wide)
    if _skipped("stage5_zero_data_preimage"):
        record["stage5_zero_data_preimage"] = not_checked(
            "stage5_zero_data_preimage", suspended["stage5_zero_data_preimage"])
    else:
        singles = [k for k, v in views.items()
                   if all(len(m) == 1 for m in v.groups)]
        record["stage5_zero_data_preimage"] = preimages(
            bundle, views, sorted(singles))
    # [ROUND 7] the same construction at MSG != PAD, so A and H are in it.
    # It is suspended with stage 5 (it needs the same views) and off unless
    # asked for.
    if _skipped("stage5_zero_data_preimage"):
        record["stage11_full_preimage"] = not_checked(
            "stage11_full_preimage", suspended["stage5_zero_data_preimage"])
    elif full_preimage:
        record["stage11_full_preimage"] = stage11(
            bundle, views, do_controls=do_controls)
    else:
        record["stage11_full_preimage"] = dict(FULL_PREIMAGE_OFF)
    # [ROUND 8] the masking commitment M and the CFS channel at the shape.
    # It needs the replayed challenges, so it is suspended with stage 2, and
    # it is off unless asked for.
    if _skipped("stage2_transcript_replay"):
        record["stage12_mask_and_cfs"] = not_checked(
            "stage12_mask_and_cfs", suspended["stage2_transcript_replay"])
    elif mask_cfs:
        record["stage12_mask_and_cfs"] = stage12(
            bundle, replay, do_controls=do_controls)
    else:
        record["stage12_mask_and_cfs"] = dict(MASK_CFS_OFF)
    # [ROUND 8, the stretch] the two arms JOINED: one assignment for the
    # whole run, with the four couplings enumerated and each checked.  It
    # needs both arms, so it is computed only when both ran.
    if _skipped("stage5_zero_data_preimage") or _skipped("stage2_transcript_replay"):
        record["stage13_joint_run_preimage"] = not_checked(
            "stage13_joint_run_preimage",
            suspended.get("stage5_zero_data_preimage")
            or suspended["stage2_transcript_replay"])
    elif full_preimage and mask_cfs:
        record["stage13_joint_run_preimage"] = joint_run_preimage(
            bundle, views, shared, record["stage11_full_preimage"],
            record["stage12_mask_and_cfs"])
    else:
        record["stage13_joint_run_preimage"] = dict(JOINT_OFF)
    if _skipped("stage6_negative_controls"):
        record["stage6_negative_controls"] = not_checked(
            "stage6_negative_controls", suspended["stage6_negative_controls"])
    elif do_controls and standalone:
        record["stage6_negative_controls"] = block_controls(
            bundle, other, views, replay, shared
        )
    elif do_controls and other is not None:
        record["stage6_negative_controls"] = controls(
            bundle, other, views, replay, shared
        )
    else:
        record["stage6_negative_controls"] = {
            "ok": False,
            "skipped": "the controls need a second bundle (--other) for the "
            "swapped-stage control",
        }
    # stage 9 (round 3): the hash layer under the rule the loader derived,
    # and the controls of the rule itself
    if _skipped("stage9_hash_layer"):
        record["stage9_hash_layer"] = not_checked(
            "stage9_hash_layer", suspended["stage9_hash_layer"])
    else:
        hl = check_hash_layer(bundle)
        # CH-6 needs a LEGACY-rule bundle; when none is supplied and the
        # bundle under test is itself a legacy-rule one, it stands for itself.
        legacy_for_ch6 = old
        if legacy_for_ch6 is None and bundle.hash_rule is not None \
                and bundle.hash_rule.is_legacy:
            legacy_for_ch6 = bundle
        # CH-7 (round 5) needs a bundle of a SECOND tagged profile.
        # `--other` is normally the same profile's sibling run, so it is used
        # only when its profile really differs; otherwise `--cross-profile`
        # names one.
        cross = load_bundle(cross_profile_dir) if cross_profile_dir else None
        if cross is None and other is not None and \
                other.run["shape"]["profile"] != bundle.run["shape"]["profile"]:
            cross = other
        hl["controls"] = (hash_rule_controls(bundle,
                                             legacy_bundle=legacy_for_ch6,
                                             cross_profile_bundle=cross)
                          if do_controls
                          else {"skipped": "controls not requested",
                                "ok": False})
        hl["ok"] = hl["ok"] and (hl["controls"].get("ok")
                                 if do_controls else True)
        record["stage9_hash_layer"] = hl
    # The channel table is a summary of the stages above, so it is suspended
    # whenever ANY of them is -- `channels()` is never handed a partial
    # record.  That is finding K4-F1's lesson kept rather than repeated.
    if _skipped("stage7_channels"):
        record["stage7_channels"] = not_checked(
            "stage7_channels", suspended["stage7_channels"])
    else:
        record["stage7_channels"] = channels(bundle, record)
    record["seconds"] = round(time.time() - t0, 1)
    stages = [k for k in record if k.startswith("stage")]
    record["ok"] = all(record[k]["ok"] for k in stages)
    if suspended:
        record["what_it_does_not_show"] = [
            "NOTHING WAS COMPUTED ABOUT THIS BUNDLE beyond its "
            + ("block" if standalone else "run") + "-layer "
            "source pins: " + "; ".join(sorted(
                set(rlp["pins_that_moved"] + rlp["pins_missing_from_the_bundle"]))),
            "the stages left unchecked, by name: "
            + ", ".join(sorted(suspended)),
            "the absence of a figure is not a figure, and nothing here says "
            "the bundle is bad -- it says this gate has not read the Rust "
            "that made it",
            "NOT a privacy acceptance and NOT a privacy property",
        ]
        return record
    n_cov = len(covered_at(bundle))
    record["what_it_does_not_show"] = ([
        "linear channels of ONE captured STANDALONE block proof at its real "
        "challenges.  One proof is not a distribution, and a block is not a "
        "run: nothing here is about a boundary, a segment or twelve blocks",
    ] if standalone else [
        "linear channels of ONE captured three-block run at ONE development shape",
        "nothing about the 125M shape, where exact rank over thousands of rows per "
        "commitment is a different computation",
    ]) + [
        "the hash layer's HIDING is still ARGUED, not computed: stage 9 "
        "authenticates every OPENED column under the rule, which says nothing "
        "about what an unopened leaf hides (M-2, M-3)",
        # [ROUND 9j, CORRECTED 2026-09-23] was "the joint-law composition for
        # a run is unwritten" -- Theorem B was written and accepted as a
        # reduction on 2026-09-20 (status page row 28)
        "the joint LAW (Theorem B) is a reduction accepted on paper, not a "
        "computation of this gate: what is computed is a rank",
        (
            "the per-slot terminal identity is checked for "
            f"{n_cov} of {bundle.shape.n_slots} slots and OPEN for the other "
            f"{bundle.shape.n_slots - n_cov}, whose public tables this bundle "
            "does not carry"
            if record["stage8_plane_index_and_terminals"]["plane_index"].get("present")
            else "the per-slot terminal identity is not checked at this shape: this "
            "bundle carries no plane index table"
        ),
        "a captured public table is checked against the capture's own length, "
        "SHA-256 and the structure its builder gives it -- NOT against the "
        "weight matrix the statement names, which no bundle carries",
        "the bilinear slots' group factor is DERIVED and compared, which says "
        "the claim point and the schedule are the repaired construction's -- "
        "it says nothing about the witness the run was proved on.  A capture "
        "carries no witness, so THIS GATE CANNOT TELL A DENSE WITNESS FROM A "
        "DEGENERATE ONE, and cannot reproduce finding S19-F1, which is a "
        "disagreement between the prover's claim and the true sum over "
        "key-value groups.  Which witness made a bundle is a fact of the Rust "
        "lane's test, read from the capture's README, not from the bundle",
        RULING_R3,
        "NOT a privacy acceptance and NOT a privacy property",
    ]
    return record


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--bundle", required=True)
    ap.add_argument("--other", help="a second bundle, for the swapped-stage control")
    ap.add_argument(
        "--old",
        help="a bundle written BEFORE stage 15 (no plane index table), for the "
        "stage-8 control that a missing table leaves the channel OPEN rather "
        "than quietly passed",
    )
    ap.add_argument(
        "--cross-profile",
        help="a bundle of a DIFFERENT tagged profile, for control CH-7: each "
        "bundle's real columns re-hashed under the other profile's derived "
        "key set (round 5)",
    )
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--name")
    ap.add_argument("--skip-exact-pad-rank", action="store_true")
    ap.add_argument("--skip-run-wide", action="store_true")
    ap.add_argument(
        "--full-preimage",
        action="store_true",
        help="round 7: also CONSTRUCT the zero-data preimage of every PCS "
        "commitment -- A and H included, both halves, every opened column and "
        "the salted leaves of the opened columns -- and fire round 7's "
        "controls.  Minutes, not seconds; off by default",
    )
    ap.add_argument(
        "--mask-cfs",
        action="store_true",
        help="round 8: also CONSTRUCT the masking layer -- one coefficient "
        "vector per stage meeting every slot's masked rounds and scalar AND "
        "M's whole published opening, with M's opened columns re-hashed and "
        "re-authenticated -- and fire round 8's six controls.  Off by default",
    )
    args = ap.parse_args(argv)

    record = run_gate(
        args.bundle,
        other_dir=args.other,
        old_dir=args.old,
        cross_profile_dir=args.cross_profile,
        pad_rank=not args.skip_exact_pad_rank,
        run_wide=not args.skip_run_wide,
        full_preimage=args.full_preimage,
        mask_cfs=args.mask_cfs,
    )
    os.makedirs(args.evidence, exist_ok=True)
    name = args.name or record["bundle"]
    out = os.path.join(args.evidence, f"{name}.json")
    with open(out, "w") as fh:
        json.dump(record, fh, indent=1, sort_keys=True)
        fh.write("\n")
    with open(os.path.join(args.evidence, f"{name}.done"), "w") as fh:
        fh.write("0\n" if record["ok"] else "1\n")
    for k in [k for k in record if k.startswith("stage")]:
        print(f"{k}: {'ok' if record[k]['ok'] else 'FAIL'}")
    print(f"record: {out} ({record['seconds']} s)")
    return 0 if record["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())

"""The run gate's negative controls: each must FAIL, honest must PASS.

"A control that cannot fire is not a control."  Every entry below records
the honest verdict beside the perturbed one and the numbers of both, so a
reader can see that the perturbation is the thing that moved.

The five the brief names, in order:

C1  the two boundary claims share ONE reserved pair -- the per-claim figures
    do not move, the joint figure on the reserved block does: rank 4 of 6,
    **disclosed 2** (the checker's exact small model, A1.4 of
    `ZK60_PRIVATE_RUN_MULTI_BLOCK_CHECK.md`);
C2  a single proximity row (`data + 2*sites + 1`): rank 5 of 6, **disclosed
    1** -- ruling M-1's reason for deriving the row count;
C3  one blinding row shared between the boundary and an adjacent activation
    commitment: the marginals do not move, the three-role joint rises above
    the sum of the parts;
C4  a claim whose source stage is wrong (`claim_sources` swapped): the
    integrity pass refuses it and the shared-plane discovery refuses to
    identify the planes;
C5  a stage file swapped between the two bundles: the transcript replay
    refuses at the first position of that stage.

and one more that guards the pad step of the reduction (H-pad):

C6  a commitment with one pad fewer than its distinct opened columns.

C1 and C2 are perturbations of the MODEL (which rows are ranked, and which
coordinates are the same unknown); C3 is an identification; C4 and C5 alter
a JSON field or swap a file and are restored afterwards.  No captured file
on disk is ever written.
"""

from __future__ import annotations

import copy

from zk60_native_jv_field import row_reduce
from zk60_native_rg_bundle import Stage, integrity
from zk60_native_rg_joint import (
    boundary_reserved_figure,
    discover_shared_planes,
    three_role_figure,
)
from zk60_native_rg_pcs import RunRoleView
from zk60_native_rg_replay import RunReplay


def per_claim_reserved_ranks(bundle, view, k):
    """Each claim's own figure on its own reserved pair, honest and merged.

    The point of C1: these do NOT move.  A per-claim (per-group) reading of
    a boundary cannot see a shared pair; only the joint reading can.
    """
    b = bundle.boundary(k)
    sites = [tuple(b["site_rows"][2 * i : 2 * i + 2]) for i in range(b["sites"])]
    out = []
    for gi, members in enumerate(view.groups):
        rho = view.rhos[gi]
        gens = [[v[0] for v in rho], [v[1] for v in rho]]
        own = sites[gi] if gi < len(sites) else sites[-1]
        block = [[g[c] for c in own] for g in gens]
        _, piv = row_reduce(block, 2)
        merged = [[(g[sites[0][j]] + sum(g[p[j]] for p in sites[1:])) % (2**64 - 2**32 + 1)
                   for j in range(2)] for g in gens]
        _, piv_m = row_reduce(merged, 2)
        out.append(
            {
                "group": gi,
                "claims": list(members),
                "own_pair": list(own),
                "rank_on_its_own_pair": len(piv),
                "rank_when_the_two_pairs_are_one": len(piv_m),
                "disclosed_fp": 2 - len(piv),
            }
        )
    return out


def controls(bundle, other_bundle, views, replay, shared):
    """Every control, with the honest figure beside the perturbed one."""
    out = {}
    k = 0  # the first internal boundary; both are identical in geometry
    bview = views[f"B{k}"]

    # ------------------------------------------------------------- C1, C2
    honest = boundary_reserved_figure(bundle, bview, k)
    per_claim = per_claim_reserved_ranks(bundle, bview, k)
    merged = boundary_reserved_figure(bundle, bview, k, merge_pairs=True)
    single = boundary_reserved_figure(bundle, bview, k, drop_prox_row=True)
    out["C1_two_claims_share_one_reserved_pair"] = {
        "what": f"boundary {k}'s two claim sites, rows {bundle.boundary(k)['site_rows'][:2]} "
        f"and {bundle.boundary(k)['site_rows'][2:]}, made the SAME coordinates",
        "honest": {
            "rank": honest["rank_on_the_reserved_block"],
            "of": honest["generators"],
            "disclosed_fp": honest["disclosed_on_the_reserved_block_fp"],
        },
        "perturbed": {
            "rank": merged["rank_on_the_reserved_block"],
            "of": merged["generators"],
            "disclosed_fp": merged["disclosed_on_the_reserved_block_fp"],
        },
        "per_claim_figures_honest": per_claim,
        "per_claim_figures_unchanged": all(
            p["rank_on_its_own_pair"] == p["rank_when_the_two_pairs_are_one"]
            for p in per_claim
        ),
        "reproduces_the_checkers_disclosed_2": (
            merged["disclosed_on_the_reserved_block_fp"] == 2
            and merged["rank_on_the_reserved_block"] == 4
        ),
        "rank_over_all_rows_honest": honest["rank_over_all_rows"],
        "why_the_restriction_matters": "over ALL rows every case looks like full rank; "
        "only the restriction to the reserved rows separates them (check A1.4)",
        "fires": merged["disclosed_on_the_reserved_block_fp"] > 0,
    }
    out["C2_a_single_proximity_row"] = {
        "what": f"boundary {k} modelled with data + 2*sites + 1 rows: the proximity "
        "PAIR replaced by one row",
        "honest": {
            "rank": honest["rank_on_the_reserved_block"],
            "of": honest["generators"],
            "disclosed_fp": honest["disclosed_on_the_reserved_block_fp"],
        },
        "perturbed": {
            "rank": single["rank_on_the_reserved_block"],
            "of": single["generators"],
            "disclosed_fp": single["disclosed_on_the_reserved_block_fp"],
        },
        "reproduces_the_checkers_disclosed_1": (
            single["disclosed_on_the_reserved_block_fp"] == 1
            and single["rank_on_the_reserved_block"] == 5
        ),
        "ruling": "M-1: the boundary's row count is DERIVED, never accepted, because "
        "audit_claims accepts the 37-row geometry",
        "fires": single["disclosed_on_the_reserved_block_fp"] > 0,
    }

    # ----------------------------------------------------------------- C3
    honest3 = three_role_figure(bundle, views, shared, k)
    a_row = bundle.stages[k].role("A")["site_rows"][0]
    b_row = bundle.boundary(k)["site_rows"][0]
    shared3 = three_role_figure(
        bundle, views, shared, k,
        extra_identifications=[((f"A@{k}", a_row), (f"B{k}", b_row))],
    )
    out["C3_a_blinding_row_shared_with_an_adjacent_activation_commitment"] = {
        "what": f"A@{k}[{a_row}] and B{k}[{b_row}] -- one reserved mask row of each -- "
        "made the SAME unknown",
        "honest": {
            "parts_fp": honest3["parts_fp"],
            "sum_of_parts_fp": honest3["sum_of_parts_fp"],
            "joint_fp": honest3["joint_fp"],
            "block_diagonal": honest3["non_data_block_is_block_diagonal_by_role"],
        },
        "perturbed": {
            "parts_fp": shared3["parts_fp"],
            "sum_of_parts_fp": shared3["sum_of_parts_fp"],
            "joint_fp": shared3["joint_fp"],
            "block_diagonal": shared3["non_data_block_is_block_diagonal_by_role"],
            "joint_k0": shared3["joint_detail"]["k0"],
        },
        "marginals_unchanged": shared3["parts_fp"] == honest3["parts_fp"],
        "joint_greater_than_sum": shared3["joint_fp"] > shared3["sum_of_parts_fp"],
        "direction": "UP.  Neither commitment discloses anything on its own and the "
        "marginals do not move; once the two blinding rows are one unknown a "
        "combination of the two commitments' group vectors cancels on every non-data "
        "coordinate and survives on the data rows, so the joint rises by one message "
        "width per such direction while the sum stands still",
        "fires": not shared3["ok"],
    }

    # ----------------------------------------------------------------- C4
    op = bundle.stages[k + 1].boundary_opening()
    saved = copy.deepcopy(op["claim_sources"])
    op["claim_sources"] = [saved[1], saved[0]]
    try:
        swapped_integrity = integrity(bundle)
        swapped_shared = discover_shared_planes(bundle)
    finally:
        op["claim_sources"] = saved
    honest_integrity = integrity(bundle)
    out["C4_a_claim_whose_source_stage_is_wrong"] = {
        "what": f"boundary {k}'s claim_sources swapped, so claim 0 is attributed to "
        f"stage {k+1}'s slot 21 and claim 1 to stage {k}'s slot 22",
        "honest": {
            "integrity_ok": honest_integrity["ok"],
            "discovery_findings": len(shared["findings"]),
            "identified_row_pairs": len(shared["pairs"]),
        },
        "perturbed": {
            "integrity_ok": swapped_integrity["ok"],
            "integrity_findings": swapped_integrity["findings"][:4],
            "discovery_findings": swapped_shared["findings"],
            "identified_row_pairs": len(swapped_shared["pairs"]),
        },
        "why_it_fires": "the reserved pair a site uses is fixed by its position in the "
        "claim order, so a swapped source puts stage k's equality on the other site's "
        "pair; the integrity pass refuses the claim_sources shape and the discovery "
        "refuses to identify the planes",
        "fires": (not swapped_integrity["ok"]) and bool(swapped_shared["findings"]),
    }

    # ----------------------------------------------------------------- C5
    victim = 1
    saved_stage = bundle.stages[victim]
    bundle.stages[victim] = Stage(
        other_bundle.stages[victim].path, victim, bundle.blocks
    )
    try:
        swapped_replay = RunReplay(bundle).run().summary()
        swapped_int = integrity(bundle)
    finally:
        bundle.stages[victim] = saved_stage
    out["C5_a_stage_file_swapped_between_the_two_bundles"] = {
        "what": f"stage {victim} of {bundle.name} replaced by stage {victim} of "
        f"{other_bundle.name} (same schema, same shape, another run)",
        "honest": {
            "replay_ok": replay.summary()["ok"],
            "challenges_checked": replay.summary()["challenges_checked"],
        },
        "perturbed": {
            "replay_ok": swapped_replay["ok"],
            "first_failure": (swapped_replay["failures"] or ["<none>"])[0],
            "failures": len(swapped_replay["failures"]),
            "integrity_ok": swapped_int["ok"],
            "integrity_first_finding": (swapped_int["findings"] or ["<none>"])[0],
        },
        "fires": (not swapped_replay["ok"]) and (not swapped_int["ok"]),
    }

    # ----------------------------------------------------------------- C6
    hview = views[f"H@{k}"]
    d = hview.facts["distinct_columns"]
    role = bundle.stages[k].role("H")
    tight = RunRoleView(
        bundle.stages[k], role, replay.stages[k]["role_prox_rhos"][f"H@{k}"],
        bundle.shape, q_pad=d - 1, name=f"H@{k}",
    )
    tf = tight.run(replay.stages[k]["role_lambdas"][f"H@{k}"])
    out["C6_one_pad_fewer_than_the_distinct_opened_columns"] = {
        "what": f"H@{k}'s pad budget set to {d - 1} against {d} distinct opened columns",
        "honest": {
            "H-pad": hview.facts["reduction_hypotheses"]["H-pad"],
            "distinct_columns": d,
            "pad_count": hview.facts["pad_count"],
        },
        "perturbed": {
            "H-pad": tf["reduction_hypotheses"]["H-pad"],
            "findings": tf["findings"][:2],
        },
        "direction": "the pad step of the reduction fails, so the ranks below are no "
        "longer a disclosed dimension at all and the gate refuses rather than "
        "reporting a number",
        "fires": not tf["reduction_hypotheses"]["H-pad"],
    }

    names = list(out)
    out["all_fire"] = all(out[n]["fires"] for n in names)
    out["controls"] = names
    out["ok"] = out["all_fire"]
    return out

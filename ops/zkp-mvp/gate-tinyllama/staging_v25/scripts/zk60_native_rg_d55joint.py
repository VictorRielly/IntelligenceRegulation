#!/usr/bin/env python3
"""[v25 STAGING, 2026-11-02] D60: THE RUN-LEVEL JOINT RANK OF A D55 FORK RUN
(ruling M-8, D12a's run gate stage 4, ported to "commit, fork, join").

    d55_joint(b, views, do_controls=True, other=None, rp=None) -> dict

`b` is a `zk60_native_rg_d55.D55Bundle`, `views` the per-commitment
`RunRoleView`s `d55_stage3` built (keys `A@k`, `H@k` for fork k; `B{k}`,
`E-Input`, `E-Output` for the tail's openings).

WHAT IT IS.  The privacy re-check of 2026-11-02
(`results/zk60_w16r2_20261101/PRIVACY_RECHECK_20261102.md` section 5) names
the one run-level privacy obligation the per-commitment rank does not
discharge (`boundary.rs:32-38`): the SAME hidden interior plane sits under
three commitments -- block k's activation commitment `A_k` (its output
plane, read by slot 22), the internal boundary `B_k`, and block k+1's
activation commitment `A_{k+1}` (its input plane, read by slot 21) -- and
their openings must not disclose more JOINTLY than separately.  D12a's run
gate computes it in stage 4 (`zk60_native_run_gate.stage4`, the module
`zk60_native_rg_joint`):

  (a) each boundary's figure RESTRICTED to its reserved rows (the two claim
      pairs and the proximity pair): rank 6 of 6, disclosed 0;
  (b) the three roles of each boundary plane as ONE generator system, the
      shared data coordinates identified (from `claim_sources`, never from
      role names: finding U-8), against the sum of the three parts;
  (c) the whole run as one system, and each adjacent pair of stages with its
      boundary.

At D12a, `B_k` is opened inside stage k+1's file; at D55 it is opened ONCE in
the TAIL (both claims, after S1) and each fork stage file holds only its A /
H / M openings.  The identification therefore resolves each fork's IO claim
against the TAIL's openings (`resolve_claim_site`); the rank functions
(`boundary_reserved_figure`, `three_role_figure`, `RunJointSystem`) are
v24's, unchanged.  The model is the same: a joint system over the forks' A,
H, M and the tail's boundaries and endpoints; D55 adds no shared blinding
source (each fork draws from its own generator, the boundaries from the
commit-phase one; `run_fork.rs:719, 776`), and that is what (b) / (c)
COMPUTE (the non-data block is block diagonal by role) rather than assume.

CONTROLS (each must FAIL; v24's `zk60_native_rg_controls` C1-C3 and C6 at D55,
C4 rewritten for the tail, C5 as a fork-file swap):

  J-C1  boundary 0's two claim sites made the SAME coordinates (a shared
        reserved pair): the restricted rank drops, disclosed > 0;
  J-C2  boundary 0 modelled with ONE proximity row (`data + 2 sites + 1`):
        disclosed > 0;
  J-C3  one reserved blinding row of A_0 and one of B_0 made the SAME unknown:
        the marginals do not move and the three-role joint rises ABOVE the sum
        of the parts -- the run-level joint rank FAILS (the control the
        privacy re-check asked for);
  J-C4  the tail's boundary 0 `claim_sources` swapped: D55 integrity refuses
        and the shared-plane discovery refuses to identify the planes;
  J-C5  (with `other`) fork 1's stage file replaced by the same fork of
        another run: the D55 replay refuses;
  J-C6  H@0's pad budget one below its distinct opened columns: H-pad fails.

NOTHING HERE IS A PRIVACY STATEMENT.  Ruling R-3 applies to every
`joint == sum` figure: it is a consistency check of the model's coordinate
classes, not evidence that the blinding is independent.
"""

from __future__ import annotations

import copy
import time

from zk60_native_rg_joint import (
    IO_SITE_ROLES,
    RULING_R3,
    RunJointSystem,
    block_from_view,
    boundary_reserved_figure,
    mask_block,
    three_role_figure,
)

ADJACENT_EXTRA = ("E-Input", "E-Output")


# ------------------------------------------------ the shared coordinates
def resolve_claim_site(b, stage_index, slot_index):
    """Which opening discharges the IO claim raised by fork `stage_index`'s
    slot `slot_index`: at D55 it is one of the TAIL's openings (every
    boundary once, then the two endpoints), found by its `claim_sources`
    (finding U-8), never by a role name.  A fork's own A / H openings carry
    no claim source."""
    for st in b.stages:
        for r in st.roles:
            if any(src["stage"] == stage_index and src["slot"] == slot_index for src in r["claim_sources"]):
                return {"refused": f"fork {st.index}'s {r['role']} opening declares the source (fork {stage_index}, slot "
                                   f"{slot_index}); a D55 fork opens no IO commitment"}
    for i, r in enumerate(b.tail.roles):
        base = 0
        for src in r["claim_sources"]:
            if src["stage"] == stage_index and src["slot"] == slot_index:
                return {"stage": b.tail, "opening": r, "key": b.tail.key_at(i), "first_claim": base,
                        "claims": src["claims"], "tail_position": i}
            base += src["claims"]
    return None


def discover_shared_planes(b):
    """`zk60_native_rg_joint.discover_shared_planes` at D55: every (A_k row)
    ~ (IO commitment row) identification of the run, the IO commitment
    resolved against the tail.  The same four conditions: the slot's private
    tables are one A table and one IO-site table, the two claims' first parts
    have the same log_size and point, the IO table's reserved pair is the one
    `claim_sources` puts the claim at, and the slot is a Standalone zero-check."""
    n = b.shape.cols
    out = {"pairs": [], "slots": [], "findings": [], "source_facts": [
        "private_block/argument.rs: the two endpoint-equality slots run eq(tau) * (A_plane - IO_plane) over "
        "log_size variables; layout.rs marks them Standalone (the capture carries the kind as data)",
        "run_fork.rs: at D55 every internal boundary and both endpoints are opened ONCE in the tail after S1; "
        "the commitment behind an IO site is named by the tail opening's claim_sources (finding U-8)",
    ]}
    for st in b.stages:
        k = st.index
        a_key = st.key("A")
        for arg in st.slots:
            privates = [t for t in arg["tables"] if t["kind"] == "private"]
            roles = [t["role"] for t in privates]
            if len(privates) != 2 or "A" not in roles:
                continue
            ends = [r for r in roles if r in IO_SITE_ROLES]
            if len(ends) != 1:
                continue
            a_tab = privates[roles.index("A")]
            o_tab = privates[1 - roles.index("A")]
            site = resolve_claim_site(b, k, arg["slot"])
            if site is None or "refused" in site:
                out["findings"].append(f"fork {k} slot {arg['slot']}: " + (site["refused"] if site else
                                       "no tail opening declares it as the source of a claim (claim_sources)"))
                continue
            ci = site["first_claim"]
            if site["claims"] != 1:
                out["findings"].append(f"fork {k} slot {arg['slot']}: claim_sources gives it {site['claims']} claims on {site['key']}, not one")
                continue
            want_pair = site["opening"]["site_rows"][2 * ci]
            if o_tab["mask_row"] != want_pair:
                out["findings"].append(f"fork {k} slot {arg['slot']}: its {o_tab['role']} table uses mask row {o_tab['mask_row']}, but "
                                       f"claim_sources puts this slot at claim {ci} of {site['key']}, whose reserved pair starts at {want_pair}")
                continue
            a_cl = st.role("A")["claims"][a_tab["claim"]]
            o_cl = site["opening"]["claims"][ci]
            ap, ep = a_cl["parts"][0], o_cl["parts"][0]
            if ap["log_size"] != ep["log_size"] or ap["point"] != ep["point"]:
                out["findings"].append(f"fork {k} slot {arg['slot']}: the A claim and the {o_tab['role']} claim of {site['key']} are not "
                                       "the same evaluation (different log_size or point) -- the planes are not shown equal")
                continue
            if arg["kind"] != "Standalone":
                out["findings"].append(f"fork {k} slot {arg['slot']}: kind {arg['kind']!r} is not Standalone")
                continue
            nrows = 1 << max(0, ap["log_size"] - b.shape.log_cols)
            a0, e0 = ap["offset"] // n, ep["offset"] // n
            out["pairs"].extend([((a_key, a0 + i), (site["key"], e0 + i)) for i in range(nrows)])
            out["slots"].append({"stage": k, "slot": arg["slot"], "name": arg["name"], "site_role": o_tab["role"],
                                 "commitment": site["key"], "commitment_kind": site["opening"]["commitment_kind"],
                                 "boundary": site["opening"]["boundary"], "opened_in": "tail",
                                 "tail_position": site["tail_position"], "log_size": ap["log_size"], "rows": nrows,
                                 "a_rows": [a0 + i for i in range(nrows)], "commitment_rows": [e0 + i for i in range(nrows)],
                                 "same_evaluation_point": True, "claim_index_in_the_opening": ci,
                                 "reserved_pair_first_row": want_pair, "table_claim_field": o_tab["claim"]})
    # every fork raises exactly its two IO claims, each resolved
    per = {}
    for s in out["slots"]:
        per.setdefault(s["stage"], []).append(s["slot"])
    for st in b.stages:
        if sorted(per.get(st.index, [])) != [21, 22]:
            out["findings"].append(f"fork {st.index}: identified IO slots {sorted(per.get(st.index, []))}, not [21, 22]")
    return out


# --------------------------------------------------- (c) the whole run
def run_wide_figure(b, views, shared, include_mask=True, subset=None, extra_identifications=(), label="whole run"):
    """`zk60_native_rg_joint.run_wide_figure` at D55: one system over every
    commitment named by `subset` (None: every fork's A, H, M and every tail
    opening)."""
    msg_width = b.shape.cols
    blocks = []
    for st in b.stages:
        for r in st.roles:
            key = st.key(r["role"])
            if subset is None or key in subset:
                blocks.append(block_from_view(views[key]))
        if include_mask and (subset is None or f"M@{st.index}" in subset):
            blocks.append(mask_block(st))
    for i in range(len(b.tail.roles)):
        key = b.tail.key_at(i)
        if subset is None or key in subset:
            blocks.append(block_from_view(views[key]))
    have = {blk.name for blk in blocks}
    ids = [(tuple(x), tuple(y)) for x, y in shared["pairs"] if x[0] in have and y[0] in have] + [tuple(p) for p in extra_identifications]
    parts = {blk.name: RunJointSystem([blk]).disclosed(msg_width=msg_width)["disclosed_fp"] for blk in blocks}
    js = RunJointSystem(blocks, identifications=ids)
    jf = js.disclosed(msg_width=msg_width)
    total = sum(parts.values())
    block_diagonal = not js.shared_non_data_classes and not js.mixed_classes
    findings = list(js.findings)
    if jf["disclosed_fp"] != total:
        findings.append(f"{label}: the joint {jf['disclosed_fp']} differs from the sum of the parts {total}")
    return {"label": label, "commitments": [blk.name for blk in blocks], "rows_total": sum(blk.rows for blk in blocks),
            "generators": jf["generators"], "coordinate_classes": jf["coordinate_classes"],
            "matrix": f"{jf['generators']} x {jf['coordinate_classes']}", "identified_rows": len(ids),
            "classes_shared_between_roles_data": len(js.shared_data_classes),
            "classes_shared_between_roles_non_data": len(js.shared_non_data_classes),
            "non_data_block_is_block_diagonal_by_role": block_diagonal, "parts_fp": parts, "sum_of_parts_fp": total,
            "joint_fp": jf["disclosed_fp"], "joint_detail": jf, "joint_equals_sum_of_parts": jf["disclosed_fp"] == total,
            "ruling_R3": RULING_R3, "findings": findings, "ok": not findings and jf["disclosed_fp"] == total}


# --------------------------------------------------- the stage
def d55_joint(b, views, do_controls=True, other=None, run_wide=True, rp=None) -> dict:
    t0 = time.time()
    shared = discover_shared_planes(b)
    per_boundary = []
    for k in range(b.boundaries):
        res = boundary_reserved_figure(b, views[f"B{k}"], k)
        three = three_role_figure(b, views, shared, k)
        per_boundary.append({
            "boundary": k, "roles": [f"A@{k}", f"B{k}", f"A@{k + 1}"],
            "restricted_to_the_reserved_rows": res, "three_roles_of_the_plane": three,
            "ok": (res["disclosed_on_the_reserved_block_fp"] == 0 and res["full_row_rank"] and res["determinant_nonzero"]
                   and three["ok"] and three["identified_rows"] > 0
                   and three["non_data_block_is_block_diagonal_by_role"])})
    whole, pairs = None, []
    if run_wide:
        tw = time.time()
        whole = run_wide_figure(b, views, shared)
        whole["seconds"] = round(time.time() - tw, 1)
        for k in range(b.boundaries):
            sub = [f"A@{k}", f"H@{k}", f"A@{k + 1}", f"H@{k + 1}", f"B{k}", f"M@{k}", f"M@{k + 1}"]
            if k == 0:
                sub.append("E-Input")
            if k == b.boundaries - 1:
                sub.append("E-Output")
            pairs.append(run_wide_figure(b, views, shared, subset=sub, label=f"forks {k} and {k + 1} with boundary {k}"))
    rec = {
        "what": "ruling M-8 at a D55 fork run: (a) each internal boundary restricted to its reserved rows; (b) the three "
                "commitments holding each interior plane (A_k's output rows, B_k, A_{k+1}'s input rows) as ONE system; "
                "(c) the whole run and each adjacent pair of forks with its boundary -- the IO commitments resolved against "
                "the TAIL's openings",
        "per_boundary": per_boundary, "adjacent_fork_pairs": pairs, "whole_run": whole,
        "shared_planes": {"identified_row_pairs": len(shared["pairs"]), "equality_slots": shared["slots"],
                          "source_facts": shared["source_facts"], "findings": shared["findings"]},
        "ruling_R3": RULING_R3,
        "ok": (bool(per_boundary) or b.boundaries == 0) and all(p["ok"] for p in per_boundary) and not shared["findings"]
              and (whole is None or whole["ok"]) and all(p["ok"] for p in pairs),
    }
    if do_controls:
        rec["controls"] = joint_controls(b, views, shared, other=other, rp=rp)
        rec["ok"] = rec["ok"] and rec["controls"]["ok"]
    rec["seconds"] = round(time.time() - t0, 1)
    return rec


# --------------------------------------------------- the controls
def joint_controls(b, views, shared, other=None, rp=None) -> dict:
    from zk60_native_rg_controls import per_claim_reserved_ranks
    from zk60_native_rg_pcs import RunRoleView
    import zk60_native_rg_d55 as D
    out = {}
    if not b.boundaries:
        out["not_applicable"] = "a one-fork run has no internal boundary; J-C1 .. J-C4 perturb one"
        out["ok"] = False
        return out
    k = 0
    bview = views[f"B{k}"]
    honest = boundary_reserved_figure(b, bview, k)
    merged = boundary_reserved_figure(b, bview, k, merge_pairs=True)
    single = boundary_reserved_figure(b, bview, k, drop_prox_row=True)
    per_claim = per_claim_reserved_ranks(b, bview, k)
    out["J-C1 two claims share one reserved pair"] = {
        "what": f"boundary {k}'s two claim sites, rows {b.boundary(k)['site_rows'][:2]} and {b.boundary(k)['site_rows'][2:]}, made the SAME coordinates",
        "honest": {"rank": honest["rank_on_the_reserved_block"], "of": honest["generators"], "disclosed_fp": honest["disclosed_on_the_reserved_block_fp"]},
        "perturbed": {"rank": merged["rank_on_the_reserved_block"], "of": merged["generators"], "disclosed_fp": merged["disclosed_on_the_reserved_block_fp"]},
        "per_claim_figures_unchanged": all(p["rank_on_its_own_pair"] == p["rank_when_the_two_pairs_are_one"] for p in per_claim),
        "fires": merged["disclosed_on_the_reserved_block_fp"] > 0 and honest["disclosed_on_the_reserved_block_fp"] == 0}
    out["J-C2 a single proximity row"] = {
        "what": f"boundary {k} modelled with data + 2*sites + 1 rows (the proximity PAIR replaced by one row)",
        "honest": {"disclosed_fp": honest["disclosed_on_the_reserved_block_fp"]},
        "perturbed": {"rank": single["rank_on_the_reserved_block"], "of": single["generators"], "disclosed_fp": single["disclosed_on_the_reserved_block_fp"]},
        "fires": single["disclosed_on_the_reserved_block_fp"] > 0}
    # J-C3: the run-level joint rank made to FAIL
    honest3 = three_role_figure(b, views, shared, k)
    a_row = b.stages[k].role("A")["site_rows"][0]
    b_row = b.boundary(k)["site_rows"][0]
    shared3 = three_role_figure(b, views, shared, k, extra_identifications=[((f"A@{k}", a_row), (f"B{k}", b_row))])
    out["J-C3 a blinding row shared between A_0 and B_0"] = {
        "what": f"A@{k}[{a_row}] and B{k}[{b_row}] -- one reserved mask row of each -- made the SAME unknown",
        "honest": {"parts_fp": honest3["parts_fp"], "sum_of_parts_fp": honest3["sum_of_parts_fp"], "joint_fp": honest3["joint_fp"],
                   "block_diagonal": honest3["non_data_block_is_block_diagonal_by_role"]},
        "perturbed": {"parts_fp": shared3["parts_fp"], "sum_of_parts_fp": shared3["sum_of_parts_fp"], "joint_fp": shared3["joint_fp"],
                      "block_diagonal": shared3["non_data_block_is_block_diagonal_by_role"], "joint_k0": shared3["joint_detail"]["k0"]},
        "marginals_unchanged": shared3["parts_fp"] == honest3["parts_fp"],
        "joint_greater_than_sum": shared3["joint_fp"] > shared3["sum_of_parts_fp"],
        "fires": (not shared3["ok"]) and honest3["ok"] and shared3["joint_fp"] > shared3["sum_of_parts_fp"]}
    # J-C4: the tail's boundary-0 claim sources swapped
    op = b.tail.roles[k]
    saved = copy.deepcopy(op["claim_sources"])
    op["claim_sources"] = [saved[1], saved[0]]
    try:
        bad_int = D.d55_integrity(b)
        bad_shared = discover_shared_planes(b)
    finally:
        op["claim_sources"] = saved
    out["J-C4 a boundary claim whose source fork is wrong"] = {
        "what": f"the tail's boundary {k} opening with its claim_sources swapped (claim 0 attributed to fork {k + 1}'s slot 21, "
                f"claim 1 to fork {k}'s slot 22)",
        "honest": {"discovery_findings": len(shared["findings"]), "identified_row_pairs": len(shared["pairs"])},
        "perturbed": {"integrity_ok": bad_int["ok"], "integrity_findings": bad_int["findings"][:3],
                      "discovery_findings": bad_shared["findings"][:3], "identified_row_pairs": len(bad_shared["pairs"])},
        "fires": (not bad_int["ok"]) and bool(bad_shared["findings"])}
    # J-C5: a fork file of another run
    if other is not None and len(other.stages) == len(b.stages) and len(b.stages) > 1:
        from zk60_native_rg_bundle import Stage
        victim = 1
        saved_st = b.stages[victim]
        b.stages[victim] = Stage(other.stages[victim].path, victim, b.blocks, schema=D.SCHEMA_D55, store=other.store, refusals=[])
        try:
            sw = D.D55Replay(b).run()
        finally:
            b.stages[victim] = saved_st
        out["J-C5 a fork file of another run"] = {
            "what": f"fork {victim} of {b.name} replaced by fork {victim} of {other.name} (same profile and shape, another run)",
            "perturbed": {"replay_failures": len(sw.failures), "first": sw.failures[:2]},
            "fires": bool(sw.failures)}
    else:
        out["J-C5 a fork file of another run"] = {"not_run": "no second bundle of the same profile was given", "fires": None}
    # J-C6: the pad step of the reduction
    if rp is not None:
        key = f"H@{k}"
        hview = views[key]
        dcols = hview.facts["distinct_columns"]
        tight = RunRoleView(b.stages[k], b.stages[k].role("H"), rp.stages[k]["role_prox_rhos"][key], b.shape, q_pad=dcols - 1, name=key)
        tf = tight.run(rp.stages[k]["role_lambdas"][key])
        out["J-C6 one pad fewer than the distinct opened columns"] = {
            "what": f"{key}'s pad budget set to {dcols - 1} against {dcols} distinct opened columns",
            "honest": {"H-pad": hview.facts["reduction_hypotheses"]["H-pad"], "pad_count": hview.facts["pad_count"]},
            "perturbed": {"H-pad": tf["reduction_hypotheses"]["H-pad"], "findings": tf["findings"][:2]},
            "fires": hview.facts["reduction_hypotheses"]["H-pad"] and not tf["reduction_hypotheses"]["H-pad"]}
    else:
        out["J-C6 one pad fewer than the distinct opened columns"] = {"not_run": "no replay was given", "fires": None}
    applicable = [n for n, v in out.items() if isinstance(v, dict) and v.get("fires") is not None]
    out["applicable"] = applicable
    out["ok"] = bool(applicable) and all(out[n]["fires"] for n in applicable)
    return out

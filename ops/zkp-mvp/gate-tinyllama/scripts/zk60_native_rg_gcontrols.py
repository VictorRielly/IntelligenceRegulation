#!/usr/bin/env python3
"""Round 4's negative controls: the two REPAIRED bilinear attention slots.

Each is shown to pass HONEST first, and each record says WHICH check fired.
Five controls, and one measurement that is not a control but the reason the
round exists:

    GQ-1        a terminal of slot 08 `SC_SCORE` changed by +1
    GQ-2        a terminal of slot 09 `SC_PV` changed by +1
    GQ-3.SS.c   the bundle's DECLARED group point changed (in memory)
    GQ-4.SS.c   the point this tool DERIVED perturbed (in memory)
    GQ-5        the other definition of the two slots FORCED on these bytes
    GQ-6        the PRE-REPAIR polynomial evaluated on a repaired bundle's own
                terminals -- the measurement, run on both witnesses, that says
                from the gate's side what the defect looks like and what it
                does not look like
    GQ-7        the DECLARED point's group coordinates SWAPPED (round 5;
                skipped by name at `lkv = 1`, where it does not exist)
    GQ-7.j.j+1  [round 9i] the same reorder on each further ADJACENT pair
                (j, j+1), j >= 1 -- present only at `lkv >= 3`, where GQ-7's
                (0, 1) no longer reaches every coordinate

GQ-3 and GQ-4 are the two halves of one rule.  The group factor is
VERIFIER-COMPUTED: this tool derives it and only compares.  GQ-3 shows that
a bundle cannot name a different point and be believed; GQ-4 shows that
this tool cannot derive a different point and get away with it either --
the comparison is two-sided, and neither side is the authority.

**ROUND 5.**  `GQ-3` and `GQ-4` became FAMILIES, one member per bilinear
slot per GROUP COORDINATE -- `GQ-3.08.0`, `GQ-3.09.0` at `lkv = 1`, and
`GQ-3.08.0`, `GQ-3.08.1`, `GQ-3.09.0`, `GQ-3.09.1` at `lkv = 2`.  Round 4
ran one of each, on slot 08's single group coordinate, which was the only
one any bundle had.  Two reasons for the widening: the second coordinate is
the bit that separates the third and fourth key-value groups from the first
two, and the two slots put their group variables at DIFFERENT positions of
their factors' coordinate lists (`A_QR8` after `r_t`, `A_P` first), so one
slot passing was never evidence for the other.

NOTHING HERE IS A PRIVACY STATEMENT.
"""

from __future__ import annotations

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

from zk60_native_jv_cfs import sumcheck_final  # noqa: E402
from zk60_native_jv_field import (  # noqa: E402
    F2_ONE,
    F2_ZERO,
    f2_add,
    f2_from_list,
    f2_mul,
)
from zk60_native_rg_gqa import (  # noqa: E402
    BILINEAR_SLOTS,
    PRE_REPAIR,
    REPAIRED,
    SLOT_NAMES,
    GroupFactors,
)
from zk60_native_rg_terminals import (  # noqa: E402
    SlotCtx,
    TerminalGate,
    lam_z_of,
)
from zk60_native_rg_terminals import check_terminals  # noqa: E402


def _docs_with_terminal_perturbed(bundle, stage: int, slot: int, term: int):
    """The bundle's stage documents with ONE terminal changed by +1, sharing
    all the JSON that is not on the path."""
    docs = [st.doc for st in bundle.stages]
    doc = dict(docs[stage])
    args = list(doc["arguments"])
    arg = dict(args[slot])
    terms = list(arg["terminals"])
    old = f2_from_list(terms[term])
    new = f2_add(old, F2_ONE)
    terms[term] = [new[0], new[1]]
    arg["terminals"] = terms
    args[slot] = arg
    doc["arguments"] = args
    docs = list(docs)
    docs[stage] = doc
    return docs, old, new


def _docs_with_group_point_perturbed(bundle, stage: int, slot: int,
                                     entry: int = 0, swap: bool = False):
    """The same, for the DECLARED `Tab::Eq` point of a bilinear slot.

    `entry` picks WHICH group coordinate moves.  At `lkv = 1` only entry 0
    exists; at `lkv = 2` entry 1 is the bit that tells the third and fourth
    key-value groups from the first two, and no control before round 5 could
    reach it.  `swap` instead exchanges the two coordinates, which is a
    perturbation a one-entry point cannot have at all: it leaves the
    multiset of the point untouched and only reorders the group axis, so a
    tool that compared points as a SET rather than a sequence would pass it.
    """
    docs = [st.doc for st in bundle.stages]
    doc = dict(docs[stage])
    args = list(doc["arguments"])
    arg = dict(args[slot])
    tabs = list(arg["tables"])
    tab = dict(tabs[0])
    if tab["kind"] != "eq":
        raise ValueError(f"slot {slot}: table 0 is not the group eq table")
    pt = list(tab["point"])
    if swap:
        # [round 9i] `swap` may name the PAIR to exchange; `True` is round
        # 5's (0, 1), which is the only pair a two-entry point has.
        if len(pt) < 2:
            raise ValueError("a point of one entry cannot be reordered")
        a, b = (0, 1) if swap is True else swap
        if not (0 <= a < len(pt) and 0 <= b < len(pt) and a != b):
            raise ValueError(f"cannot exchange group coordinates {a} and {b} "
                             f"of a point of {len(pt)}")
        pt[a], pt[b] = pt[b], pt[a]
    else:
        if not 0 <= entry < len(pt):
            raise ValueError(f"group coordinate {entry} of a point of {len(pt)}")
        new = f2_add(f2_from_list(pt[entry]), F2_ONE)
        pt[entry] = [new[0], new[1]]
    tab["point"] = pt
    tabs[0] = tab
    arg["tables"] = tabs
    args[slot] = arg
    doc["arguments"] = args
    docs = list(docs)
    docs[stage] = doc
    return docs


def _failed_slots(got) -> list:
    return sorted({(r["stage"], s) for r in got["per_stage"]
                   for s in r["checked"] if s not in r["equal"]})


def _not_checked(got, slot: int) -> list:
    return [(r["stage"], e["why"]) for r in got["per_stage"]
            for e in r["not_checked"] if e["slot"] == slot]


# =====================================================================
#  GQ-6: the pre-repair polynomial on a repaired bundle's own bytes
# =====================================================================
def pre_repair_polynomial_on_this_bundle(bundle, index, replay, group) -> dict:
    """Evaluate, for every bilinear slot of every stage, BOTH

        poly_repaired   = eq(r_g, rho[..lkv]) * X * Y     (the definition in
                                                           force)
        poly_pre_repair = X * Y                           (the definition
                                                           finding S19-F1
                                                           names as wrong)

    on the SAME captured terminals, and say which of them satisfies the
    verifier's final identity `fin == c*mask_eval + poly`.

    This is the round's headline measurement, not a control, and its value
    is in what it does NOT show.  It cannot reproduce the defect, because
    the defect was an inequality between the prover's CLAIM and the true
    sum over heads, and no bundle carries a witness to compute either side
    from.  What it does show is the arithmetic weight of the group factor
    in the verifier's own final check, on a dense witness and on a
    degenerate one, and whether that weight is the same.
    """
    gate = TerminalGate(bundle, index)
    planes = [[p.name for p in row] for row in index.slot_planes]
    rows, repaired_ok, pre_ok = [], 0, 0
    for st in bundle.stages:
        doc = st.doc
        gate.set_stage(st.index)       # [v17] the stage's own calibration
        gate.set_logup(doc["logup_challenges"])
        lam_z = lam_z_of(doc)
        for slot in BILINEAR_SLOTS:
            arg = doc["arguments"][slot]
            dc = [f2_from_list(x) for x in arg["definition_challenges"]]
            cx = SlotCtx(gate, arg, planes[slot], dc, lam_z)
            cx.bilinear_definition = group.definition
            cx.group_table_required = group.group_table_required()
            pt = group.point(st.index, slot)
            if pt is not None and cx.eq_idx:
                cx.derived_eq_points = {cx.eq_idx[0]: pt}
            cx.rho_full = replay.stages[st.index]["rho"][slot]
            c = replay.stages[st.index]["slot_c"][slot]
            gate.build_public(cx)
            v = gate.vals(cx)
            a, b = [v[cx.t(n)] for n in
                    (("A_QR8", "A_KR8") if slot == 8 else ("A_P", "A_V8"))]
            product = f2_mul(a, b)
            eq_val = cx.group_gate(v)
            poly_new = f2_mul(eq_val, product)
            poly_old = product
            claimed = f2_from_list(arg["scalar"])
            fin, _ = sumcheck_final(arg["rounds"], arg["degree"],
                                    cx.rho_full, claimed)
            target = f2_add(f2_mul(c, f2_from_list(arg["mask_eval"])), F2_ZERO)
            want = None if fin is None else f2_add(target, F2_ZERO)
            new_holds = fin is not None and fin == f2_add(
                f2_mul(c, f2_from_list(arg["mask_eval"])), poly_new)
            old_holds = fin is not None and fin == f2_add(
                f2_mul(c, f2_from_list(arg["mask_eval"])), poly_old)
            repaired_ok += int(new_holds)
            pre_ok += int(old_holds)
            rows.append({
                "stage": st.index,
                "slot": slot,
                "name": SLOT_NAMES[slot],
                "group_factor_is_one": eq_val == F2_ONE,
                "first_terminal_is_zero": a == F2_ZERO,
                "second_terminal_is_zero": b == F2_ZERO,
                "product_of_the_two_terminals_is_zero": product == F2_ZERO,
                "the_repaired_polynomial_satisfies_the_identity": new_holds,
                "the_pre_repair_polynomial_satisfies_the_identity": old_holds,
            })
            del want
    return {
        "what": "both definitions' polynomials evaluated on the SAME captured "
        "terminals and rho, and which of them satisfies fin == c*mask_eval + poly",
        "slot_instances": len(rows),
        "the_repaired_definition_holds": repaired_ok,
        "the_pre_repair_definition_holds": pre_ok,
        "group_factors_equal_to_one": sum(r["group_factor_is_one"] for r in rows),
        "terminal_products_that_are_zero": sum(
            r["product_of_the_two_terminals_is_zero"] for r in rows),
        "per_slot": rows,
        "what_this_does_not_show": (
            "the defect itself.  Finding S19-F1 is a disagreement between the "
            "prover's CLAIM and the true sum over key-value groups, and both "
            "sides of that need a witness, which no capture carries.  A gate "
            "reading a capture can only say which POLYNOMIAL the published "
            "numbers satisfy -- and both bundles here were produced under the "
            "repaired one, so the pre-repair polynomial failing is a "
            "statement about the group factor's arithmetic weight, not about "
            "the witness"
        ),
        "ok": repaired_ok == len(rows),
    }


# =====================================================================
#  the controls
# =====================================================================
def group_controls(bundle, index, replay=None, other_definition=None) -> dict:
    """The five controls plus GQ-6, each honest-then-perturbed."""
    group = GroupFactors(bundle, replay=replay)
    honest = check_terminals(bundle, index, replay=replay, group=group)
    out = {
        "what": "round 4's controls: the two bilinear attention slots under the "
        "definition the bundle's own source pin selects",
        "definition_in_force": group.definition,
        "honest": {
            "ok": honest["ok"],
            "slot_checks_equal": honest["slot_checks_equal"],
            "slot_checks_expected": honest["slot_checks_expected"],
            "derived_group_points_used_and_compared":
                honest["derived_group_points_used_and_compared"],
            "findings": honest["findings"],
        },
        "controls": [],
    }
    if not honest["ok"]:
        out["ok"] = False
        out["skipped"] = "the honest case does not pass; a control would prove nothing"
        return out

    # ------------------------------ GQ-1 / GQ-2: a perturbed bilinear terminal
    # **[ROUND 9, finding M-F3, second pass.]**  GQ-2 named stage 2 as a
    # LITERAL here too -- the first repair reached only the GQ-3/GQ-4 aim
    # list, and this one raised `IndexError` at L = 2 through the whole
    # stage-10 arm.  A control that crashes is not a control, and a partial
    # repair of that failure is not a repair: both sites derive the stage
    # from `blocks` now, and GQ-1 stays at the FIRST stage while GQ-2 takes
    # the LAST, which is what the pair was for.
    _last = bundle.blocks - 1
    for name, stage, slot, term in (("GQ-1", 0, 8, 0), ("GQ-2", _last, 9, 1)):
        docs, old, new = _docs_with_terminal_perturbed(bundle, stage, slot, term)
        g2 = GroupFactors(bundle, replay=replay, stage_docs=docs)
        got = check_terminals(bundle, index, replay=replay, stage_docs=docs, group=g2)
        failed = _failed_slots(got)
        out["controls"].append({
            "control": name,
            "what": f"stage {stage}, slot {slot} [{SLOT_NAMES[slot]}], terminal "
                    f"{term} changed by +1",
            "mechanism": "the repaired identity's own arithmetic",
            "slots_that_failed": [list(x) for x in failed],
            "fails_at_exactly_the_perturbed_slot": failed == [(stage, slot)],
            "slot_checks_equal": got["slot_checks_equal"],
            "of": got["slot_checks_expected"],
            "fires": failed == [(stage, slot)],
        })
        del old, new

    # ------------------------- GQ-3: the bundle names a different group point
    #
    # [round 5] GQ-3 and GQ-4 are now run ONCE PER GROUP COORDINATE.  At
    # `lkv = 1` that is one pass each and the figures are round 4's exactly.
    # At `lkv = 2` (rung-K4) the second pass perturbs the bit that separates
    # the third and fourth key-value groups from the first two -- a
    # coordinate that did not exist in any bundle before round 5.  A slot 09
    # pass is added beside the slot 08 one for the same reason: the two
    # bilinear slots put the group variables at DIFFERENT positions of their
    # factors' coordinate lists (`A_QR8` after `r_t`, `A_P` first), so one
    # slot passing is no evidence for the other.
    if group.geom.lkv > 0 and group.definition == REPAIRED:
        lkv = group.geom.lkv
        # **[ROUND 9, finding M-F3.]**  `(2, 9, j)` named stage 2 as a
        # literal -- the last stage of a three-block run.  A two-block run
        # has none.  The two aims are now "a middle-ish stage" and "the
        # last stage", derived from `L`, which is what the pair was for:
        # the two bilinear slots put the group variables at different
        # positions, so one passing is no evidence for the other.
        last = bundle.blocks - 1
        first = min(1, last)
        aims = ([(first, 8, j) for j in range(lkv)]
                + [(last, 9, j) for j in range(lkv)])
        for stage, slot, entry in aims:
            sfx = f".{slot:02d}.{entry}"
            where = (f"stage {stage}, slot {slot} [{SLOT_NAMES[slot]}], group "
                     f"coordinate {entry} of {lkv}")
            docs = _docs_with_group_point_perturbed(bundle, stage, slot,
                                                    entry=entry)
            g3 = GroupFactors(bundle, replay=replay, stage_docs=docs)
            s3 = g3.summary()
            got = check_terminals(bundle, index, replay=replay,
                                  stage_docs=docs, group=g3)
            why = _not_checked(got, slot)
            out["controls"].append({
                "control": f"GQ-3{sfx}",
                "what": f"{where}: the DECLARED eq point's entry {entry} "
                        "changed by +1",
                "mechanism": "the derive-and-compare, refused by name",
                "group_coordinate": entry,
                "of_group_coordinates": lkv,
                "slot": slot,
                "group_factor_ok": s3["ok"],
                "refusal": (s3["failures"] or [""])[0][:220],
                "slots_with_a_derived_group_point":
                    s3["slots_with_a_derived_group_point"],
                "of": s3["slot_instances"],
                "the_slot_is_not_evaluated": bool(why),
                "why_the_slot_is_not_evaluated": (why[0][1] if why else "")[:220],
                "slot_checks_equal": got["slot_checks_equal"],
                "of_expected": got["slot_checks_expected"],
                "fires": (not s3["ok"]) and bool(why)
                and any("not r_g" in f for f in s3["failures"]),
            })

            # --------------- GQ-4: THIS TOOL derives a different group point
            g4 = GroupFactors(bundle, replay=replay,
                              perturb_derived_point=(stage, slot),
                              perturb_derived_entry=entry)
            s4 = g4.summary()
            got4 = check_terminals(bundle, index, replay=replay, group=g4)
            why4 = _not_checked(got4, slot)
            out["controls"].append({
                "control": f"GQ-4{sfx}",
                "what": f"{where}: the point this tool DERIVED perturbed by +1, "
                        "the bundle untouched",
                "mechanism": "the same comparison, from the other side",
                "group_coordinate": entry,
                "of_group_coordinates": lkv,
                "slot": slot,
                "group_factor_ok": s4["ok"],
                "refusal": (s4["failures"] or [""])[0][:220],
                "the_slot_is_not_evaluated": bool(why4),
                "why_the_slot_is_not_evaluated": (why4[0][1] if why4 else "")[:220],
                "slot_checks_equal": got4["slot_checks_equal"],
                "of_expected": got4["slot_checks_expected"],
                "fires": (not s4["ok"]) and bool(why4),
            })

        # ------------------------------- GQ-7 [round 5]: the point REORDERED
        #
        # The one perturbation that needs more than one group bit to exist.
        # Swapping the two coordinates of the declared point keeps every
        # value it names and only changes which group each bit selects --
        # group 1 and group 2 exchange places.  A comparison that treated
        # the point as a SET, or that only checked its length and its first
        # entry, would pass this.  At lkv = 1 it is NAMED AND SKIPPED, which
        # is the honest record: a one-entry point cannot be reordered, so
        # round 4 could not have run this control at all.
        gq7 = {"control": "GQ-7",
               "what": "the DECLARED eq point's two group coordinates SWAPPED, "
                       "every value kept",
               "mechanism": "the entry-by-entry comparison, which is ordered",
               "slot": 8}
        if lkv < 2:
            gq7.update({
                "skipped": f"this shape has lkv = {lkv}: a point of one entry "
                           "cannot be reordered, so the control does not exist "
                           "here",
                # [v17, gate round 14] a NAMED not-applicable null, which the
                # status module reads as such (it was False, an unexplained
                # false leaf at every lkv < 2 shape: the DD rung's first
                # everything-pass showed it)
                "fires": None})
        else:
            docs7 = _docs_with_group_point_perturbed(bundle, 0, 8, swap=True)
            g7 = GroupFactors(bundle, replay=replay, stage_docs=docs7)
            s7 = g7.summary()
            got7 = check_terminals(bundle, index, replay=replay,
                                   stage_docs=docs7, group=g7)
            why7 = _not_checked(got7, 8)
            # a swap that changes nothing is not a control: if the prover's
            # two group challenges happened to be equal the bytes are
            # identical, and the record must say so rather than claim a pass
            pt = bundle.stages[0].doc["arguments"][8]["tables"][0]["point"]
            distinct = f2_from_list(pt[0]) != f2_from_list(pt[1])
            gq7.update({
                "the_two_group_challenges_differ": distinct,
                "group_factor_ok": s7["ok"],
                "refusal": (s7["failures"] or [""])[0][:220],
                "the_slot_is_not_evaluated": bool(why7),
                "slot_checks_equal": got7["slot_checks_equal"],
                "of_expected": got7["slot_checks_expected"],
                "fires": distinct and (not s7["ok"]) and bool(why7)
                and any("not r_g" in f for f in s7["failures"]),
            })
        out["controls"].append(gq7)

        # ------------- GQ-7.j.j+1 [round 9i]: the reorder reaching bit 2 on
        #
        # GQ-7 exchanges coordinates 0 and 1 -- written at lkv = 2, where
        # that is the only pair there is.  At lkv = 3 (rung-K8) the third
        # group bit, the one that separates groups 4-7 from 0-3, is reached
        # by GQ-3 / GQ-4 (a VALUE moved) but by no REORDERING: a comparison
        # that checked only the first two entries in order, and the rest as
        # a set, would pass GQ-7 and still accept a point whose last two
        # coordinates are exchanged.  One member per further ADJACENT pair
        # (j, j+1), j >= 1, so every coordinate is in at least one reorder.
        # At lkv <= 2 the range is empty and nothing is added, so every
        # record at rung-G, rung-K4, rung-P2 and 125M is unchanged.
        for j in range(1, lkv - 1):
            name = f"GQ-7.{j}.{j + 1}"
            docsj = _docs_with_group_point_perturbed(bundle, 0, 8,
                                                     swap=(j, j + 1))
            gj = GroupFactors(bundle, replay=replay, stage_docs=docsj)
            sj = gj.summary()
            gotj = check_terminals(bundle, index, replay=replay,
                                   stage_docs=docsj, group=gj)
            whyj = _not_checked(gotj, 8)
            ptj = bundle.stages[0].doc["arguments"][8]["tables"][0]["point"]
            distinct_j = f2_from_list(ptj[j]) != f2_from_list(ptj[j + 1])
            out["controls"].append({
                "control": name,
                "what": f"the DECLARED eq point's group coordinates {j} and "
                        f"{j + 1} (of {lkv}) SWAPPED, every value kept",
                "mechanism": "the entry-by-entry comparison, which is ordered",
                "slot": 8,
                "swapped_coordinates": [j, j + 1],
                "the_two_group_challenges_differ": distinct_j,
                "group_factor_ok": sj["ok"],
                "refusal": (sj["failures"] or [""])[0][:220],
                "the_slot_is_not_evaluated": bool(whyj),
                "slot_checks_equal": gotj["slot_checks_equal"],
                "of_expected": gotj["slot_checks_expected"],
                "fires": distinct_j and (not sj["ok"]) and bool(whyj)
                and any("not r_g" in f for f in sj["failures"]),
            })

    # ------------------------------- GQ-5: the other definition, forced whole
    other = other_definition or (PRE_REPAIR if group.definition == REPAIRED
                                 else REPAIRED)
    g5 = GroupFactors(bundle, replay=replay, definition=other)
    s5 = g5.summary()
    got5 = check_terminals(bundle, index, replay=replay, group=g5)
    why5 = {s: _not_checked(got5, s) for s in BILINEAR_SLOTS}
    out["controls"].append({
        "control": "GQ-5",
        "what": f"the {other} definition of slots 08 and 09 FORCED on bytes made "
                f"under the {group.definition} one",
        "mechanism": "the derived dimensions and the presence of the group table, "
                     "both refused by name before any arithmetic runs",
        "group_factor_ok": s5["ok"],
        "refusals": s5["failures"][:4],
        "refusal_count": len(s5["failures"]),
        "both_slots_refused_in_every_stage": all(
            len(why5[s]) == bundle.blocks for s in BILINEAR_SLOTS),
        "slot_checks_equal": got5["slot_checks_equal"],
        "of_expected": got5["slot_checks_expected"],
        "the_other_21_slots_are_unaffected":
            got5["slot_checks_equal"] == got5["slot_checks_expected"]
            - 2 * bundle.blocks,
        "fires": (not s5["ok"]) and all(
            len(why5[s]) == bundle.blocks for s in BILINEAR_SLOTS),
    })

    # ------------------------- GQ-6: the pre-repair polynomial, measured
    measured = pre_repair_polynomial_on_this_bundle(bundle, index, replay, group)
    out["pre_repair_polynomial_measured"] = measured
    n = measured["slot_instances"]
    grouped = group.group_table_required()
    if grouped:
        # a bundle made under the repair at a grouped shape: the group factor
        # is a real field element, so dropping it must break the identity
        expect = (measured["the_repaired_definition_holds"] == n
                  and measured["the_pre_repair_definition_holds"] == 0)
        reading = ("the group factor is never 1 and no terminal product is 0, so "
                   "dropping it breaks the verifier's final check in every slot "
                   "of every stage")
    else:
        # a bundle made BEFORE the repair: there is no group table, so the two
        # definitions are literally the same expression and this gate cannot
        # tell them apart -- which is the configuration in which the defect
        # was invisible
        expect = (measured["the_repaired_definition_holds"] == n
                  and measured["the_pre_repair_definition_holds"] == n
                  and measured["group_factors_equal_to_one"] == n)
        reading = ("this bundle carries no group table, so the two definitions "
                   "are the SAME expression here and no gate reading this "
                   "capture can separate them")
    out["controls"].append({
        "control": "GQ-6",
        "what": "the PRE-REPAIR polynomial X*Y evaluated on this bundle's own "
                "terminals, beside the repaired eq(r_g,.)*X*Y",
        "mechanism": "a measurement, not a perturbation",
        "the_bundle_carries_a_group_table": grouped,
        "the_repaired_definition_holds": measured["the_repaired_definition_holds"],
        "the_pre_repair_definition_holds": measured["the_pre_repair_definition_holds"],
        "of": n,
        "group_factors_equal_to_one": measured["group_factors_equal_to_one"],
        "terminal_products_that_are_zero":
            measured["terminal_products_that_are_zero"],
        "reading": reading,
        "fires": expect,
    })

    # [round 5] A SKIPPED control is not a failure -- it is a control this
    # SHAPE cannot have, and it is named so a reader can see which ones did
    # not run.  GQ-7 is skipped at lkv = 1, where a one-entry point cannot
    # be reordered; every control of round 4 still runs on every bundle.
    live = [c for c in out["controls"] if "skipped" not in c]
    out["controls_that_fire"] = sum(1 for c in live if c["fires"])
    out["controls_total"] = len(out["controls"])
    out["controls_live"] = len(live)
    out["controls_skipped"] = [c["control"] for c in out["controls"]
                               if "skipped" in c]
    out["ok"] = bool(live) and all(c["fires"] for c in live)
    return out

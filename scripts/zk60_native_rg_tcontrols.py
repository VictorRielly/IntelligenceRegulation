#!/usr/bin/env python3
"""The negative controls of the PER-SLOT TERMINAL IDENTITY channel.

Each control is shown to PASS on the honest bundle first and then made to
FAIL, and the record says WHICH check fired -- the port's declared push
order, the plane index loader's geometry cross-check, or the identity's own
arithmetic.  A control whose only firing mechanism is a label is reported as
such and never dressed up as an arithmetic catch.

  CT-1  one captured terminal evaluation is perturbed        -> the identity
        fails at EXACTLY that slot and that stage, and nowhere else.  The
        transcript replay catches the same perturbation independently,
        because `pb-term` absorbs the terminals (argument.rs:390).
  CT-2  two entries of one slot's plane list are swapped     -> the port
        refuses by push order; with the push-order check DROPPED the
        identity itself fails, at that slot, in every stage; and the plane
        index loader refuses, because the private tables' slice offsets no
        longer lie in the planes the list names.
  CT-3  one slot's entry is re-pointed at a DIFFERENT plane of the same
        size and domain                                      -> the loader
        refuses on the slice offset, and the port refuses because the plane
        the polynomial reads is no longer pushed.  A second form, where only
        the `id` moves and the name stays, is caught by the loader's
        name-against-id cross-check.
  CT-4  an OLD bundle (no plane index table)                 -> the channel
        stays OPEN with the reason it had before, and no slot is reported
        checked.  This is the control against a gate that quietly counts a
        missing check as a passed one.
  CT-5  one entry of a rebuilt PUBLIC table is flipped       -> the SHA-256
        the capture carries refuses it, so the port never evaluates a
        polynomial the verifier did not evaluate.

NOTHING HERE IS A PRIVACY STATEMENT.
"""

from __future__ import annotations

import copy
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

from zk60_native_jv_field import f2_add, f2_from_list, F2_ONE  # noqa: E402
from zk60_native_rg_planes import NO_TABLE, PlaneIndex, plane_index_of  # noqa: E402
from zk60_native_rg_replay import RunReplay  # noqa: E402
from zk60_native_rg_terminals import (  # noqa: E402
    PadGeometry,
    check_terminals,
    table_digest,
)


def _docs_with_terminal_perturbed(bundle, stage: int, slot: int, term: int):
    """The bundle's stage documents with ONE terminal changed by +1.  Only
    the three dictionaries on the path are copied; the 12 MB of JSON around
    them is shared."""
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


def _names(index):
    return [[p.name for p in row] for row in index.slot_planes]


def _index_with_table(bundle, table):
    """A `PlaneIndex` over a REPLACED plane index table, without writing any
    file: the bundle's own `run` dict is restored before returning."""
    keep = bundle.run["plane_index"]
    bundle.run["plane_index"] = table
    try:
        try:
            return PlaneIndex(bundle), None
        except Exception as exc:                       # a table that cannot load
            return None, str(exc)
    finally:
        bundle.run["plane_index"] = keep


def _swapped_table(bundle, slot: int, i: int, j: int):
    table = copy.deepcopy(bundle.run["plane_index"])
    planes = table["slot_planes"][slot]["planes"]
    planes[i], planes[j] = planes[j], planes[i]
    return table


def _repointed_table(bundle, slot: int, i: int, donor: int, id_only: bool):
    """Slot `slot`'s entry `i` re-pointed at the plane entry `donor` of the
    same slot -- a plane of the same domain and the same row count."""
    table = copy.deepcopy(bundle.run["plane_index"])
    planes = table["slot_planes"][slot]["planes"]
    if id_only:
        planes[i]["id"] = planes[donor]["id"]
    else:
        planes[i] = copy.deepcopy(planes[donor])
    return table


def _flip_one_public_entry(geom_cls, gate_geom, dom, cube):
    vals = list(gate_geom.supp(dom, cube))
    at = next(i for i, x in enumerate(vals) if x == 1)
    vals[at] = 0
    return vals, at


def terminal_controls(bundle, index, replay=None, old_bundle=None) -> dict:
    """The five controls, each shown honest-then-perturbed."""
    honest = check_terminals(bundle, index, replay=replay)
    out = {
        "honest": {
            "ok": honest["ok"],
            "slot_checks_equal": honest["slot_checks_equal"],
            "slot_checks_expected": honest["slot_checks_expected"],
            "findings": honest["findings"],
        },
        "controls": [],
    }
    if not honest["ok"]:
        out["ok"] = False
        out["skipped"] = "the honest case does not pass; a control would prove nothing"
        return out

    # ------------------------------------------------ CT-1: a perturbed terminal
    stage, slot, term = 1, 17, 3
    docs, old, new = _docs_with_terminal_perturbed(bundle, stage, slot, term)
    got = check_terminals(bundle, index, replay=replay, stage_docs=docs)
    failed = sorted(
        {(r["stage"], s) for r in got["per_stage"]
         for s in r["checked"] if s not in r["equal"]}
    )
    # the same perturbation, caught independently by the transcript replay:
    # `pb-term` absorbs the terminals, so a changed one moves every later state
    keep = bundle.stages[stage].doc
    bundle.stages[stage].doc = docs[stage]
    try:
        try:
            rp = RunReplay(bundle).run()
            replay_failures = list(rp.failures)
        except Exception as exc:                      # a refusal that raises
            replay_failures = [str(exc)]
    finally:
        bundle.stages[stage].doc = keep
    out["controls"].append({
        "control": "CT-1",
        "what": f"stage {stage}, slot {slot} [SC_SZC], terminal {term} changed by +1",
        "mechanism": "the identity's own arithmetic",
        "slots_that_failed": [list(x) for x in failed],
        "fails_at_exactly_the_perturbed_slot": failed == [(stage, slot)],
        "slot_checks_equal": got["slot_checks_equal"],
        "of": got["slot_checks_expected"],
        "the_transcript_replay_refuses_the_same_bundle": bool(replay_failures),
        "replay_refusals": len(replay_failures),
        "first_replay_refusal": (replay_failures[0] if replay_failures else "")[:200],
        "restored": bundle.stages[stage].doc is keep,
        "fires": failed == [(stage, slot)] and bool(replay_failures),
    })

    # ---------------------------------------- CT-2: two plane entries swapped
    # slot 17's `A_SR0` and `A_SR1`: the same domain, the same row count, and
    # both read by the same polynomial, so the swap is invisible to any check
    # that only counts planes.
    swap_slot = 17
    names17 = _names(index)[swap_slot]
    i, j = names17.index("A_SR0"), names17.index("A_SR1")
    table = _swapped_table(bundle, swap_slot, i, j)
    bad_index, load_error = _index_with_table(bundle, table)
    load_findings = bad_index.findings if bad_index is not None else [load_error]
    planes = _names(index)
    planes[swap_slot] = list(names17)
    planes[swap_slot][i], planes[swap_slot][j] = planes[swap_slot][j], planes[swap_slot][i]
    strict = check_terminals(bundle, index, replay=replay, slot_planes=planes)
    loose = check_terminals(bundle, index, replay=replay, slot_planes=planes,
                            structural=False)
    loose_failed = sorted(
        {(r["stage"], s) for r in loose["per_stage"]
         for s in r["checked"] if s not in r["equal"]}
    )
    out["controls"].append({
        "control": "CT-2",
        "what": f"slot {swap_slot}'s plane list: entries {i} (A_SR0) and {j} "
                "(A_SR1) swapped -- the same domain, the same row count",
        "mechanism": "three independent refusals",
        "the_port_refuses_the_push_order": not strict["ok"],
        "port_refusal": next((f for f in strict["findings"] if "push order" in f), "")[:200],
        "with_the_push_order_check_dropped_the_identity_fails":
            [list(x) for x in loose_failed],
        "the_identity_fails_at_the_swapped_slot_in_every_stage":
            loose_failed == [(k, swap_slot) for k in range(bundle.blocks)],
        "the_plane_index_loader_refuses": bool(load_findings),
        "loader_refusal": (load_findings[0] if load_findings else "")[:200],
        "bundle_table_restored": bundle.run["plane_index"] is not table,
        "fires": (not strict["ok"]
                  and loose_failed == [(k, swap_slot) for k in range(bundle.blocks)]
                  and bool(load_findings)),
    })

    # ------------------- CT-3: one entry re-pointed at another plane, same size
    donor = names17.index("A_SG0")
    same_size = (
        index.slot_planes[swap_slot][i].rows == index.slot_planes[swap_slot][donor].rows
        and index.slot_planes[swap_slot][i].domain
        == index.slot_planes[swap_slot][donor].domain
    )
    table = _repointed_table(bundle, swap_slot, i, donor, id_only=False)
    bad_index, load_error = _index_with_table(bundle, table)
    full_findings = bad_index.findings if bad_index is not None else [load_error]
    planes = _names(index)
    planes[swap_slot] = list(names17)
    planes[swap_slot][i] = "A_SG0"
    repointed = check_terminals(bundle, index, replay=replay, slot_planes=planes,
                                structural=False)
    not_checked = sorted(
        {(r["stage"], e["slot"]) for r in repointed["per_stage"]
         for e in r["not_checked"] if e["why"] != "OPEN"}
    )
    table2 = _repointed_table(bundle, swap_slot, i, donor, id_only=True)
    bad2, load_error2 = _index_with_table(bundle, table2)
    id_only_findings = bad2.findings if bad2 is not None else [load_error2]
    out["controls"].append({
        "control": "CT-3",
        "what": f"slot {swap_slot}'s entry {i} (A_SR0) re-pointed at entry "
                f"{donor} (A_SG0): the same domain, the same row count",
        "the_two_planes_really_are_the_same_size": same_size,
        "mechanism": "the loader's slice-offset check, then the port's missing plane",
        "the_plane_index_loader_refuses": bool(full_findings),
        "loader_refusals": len(full_findings),
        "loader_refusal": (full_findings[0] if full_findings else "")[:220],
        "loader_slice_offset_refusal": next(
            (f for f in full_findings if "slice offset" in f), "")[:220],
        "the_port_cannot_evaluate_the_slot": [list(x) for x in not_checked],
        "port_refusal": next((f for f in repointed["findings"]
                              if "does not push plane" in f), "")[:200],
        "id_only_form_is_caught_by_the_name_against_id_cross_check":
            any("the entry says" in f for f in id_only_findings),
        "id_only_refusal": next((f for f in id_only_findings
                                 if "the entry says" in f), "")[:200],
        "fires": (bool(full_findings)
                  and not_checked == [(k, swap_slot) for k in range(bundle.blocks)]
                  and any("the entry says" in f for f in id_only_findings)),
    })

    # ------------------------------------------------- CT-4: an OLD bundle
    old = {"control": "CT-4", "what": "an OLD bundle, written before stage 15, "
           "carries no plane index table"}
    if old_bundle is None:
        old.update({"skipped": "no old bundle was supplied (--old)", "fires": False})
    else:
        idx, reason = plane_index_of(old_bundle)
        old.update({
            "bundle": old_bundle.name,
            "mechanism": "the loader reports the table absent and the gate leaves "
                         "the channel OPEN",
            "table_present": idx is not None,
            "reason_is_the_one_the_gate_had_before": reason == NO_TABLE,
            "reason": (reason or "")[:200],
            "no_slot_is_reported_checked": idx is None,
            "fires": idx is None and reason == NO_TABLE,
        })
    out["controls"].append(old)

    # ---------------------------------- CT-5: a flipped public-table entry
    geom = PadGeometry(bundle.run["shape"], index.domain_log)
    cube = 1 << bundle.stages[0].doc["arguments"][17]["main"]
    real = geom.supp("S", cube)
    flipped = list(real)
    at = next(i2 for i2, x in enumerate(flipped) if x == 1)
    flipped[at] = 0
    captured = next(t["sha256"] for t in bundle.stages[0].doc["arguments"][17]["tables"]
                    if t["kind"] == "public" and t["sha256"] == table_digest(real))
    out["controls"].append({
        "control": "CT-5",
        "what": f"one entry (index {at}) of the rebuilt supp(Dom::S) table flipped "
                "from 1 to 0",
        "mechanism": "the SHA-256 the capture carries for that public table",
        "the_honest_table_matches_the_capture": table_digest(real) == captured,
        "the_flipped_table_does_not": table_digest(flipped) != captured,
        "fires": table_digest(real) == captured and table_digest(flipped) != captured,
    })

    out["ok"] = all(c.get("fires") for c in out["controls"])
    out["controls_that_did_not_fire"] = [
        c["control"] for c in out["controls"] if not c.get("fires")
    ]
    return out

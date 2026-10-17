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

ROUND 3, on a bundle that carries its public tables' VALUES:

  CT-6  one value of a CAPTURED public table is changed by +1 -> the
        capture's own SHA-256 for that table refuses it, and the slot is not
        reported checked.
  CT-7  the same perturbation with the digest check DROPPED   -> the
        identity itself fails, at exactly the slot that reads that table and
        in exactly the stage that was perturbed.  A captured table is read
        by ONE slot of ONE stage, so "the slots that read it" is that one.
  CT-8  one terminal of a NEWLY checked slot (14, SC_DZC) is perturbed ->
        the identity fails at exactly that slot and stage, which is the
        statement that the eleven new ports are load-bearing and not
        decoration.

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
from zk60_native_rg_replay import replay_for  # noqa: E402
from zk60_native_rg_terminals import (  # noqa: E402
    PadGeometry,
    SlotCtx,
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
    # **[ROUND 9j, finding R9j-F1.]**  This read `stage = 1` -- a literal that
    # assumes a second stage exists, the shape of finding M-F3 one `L` lower.
    # A STANDALONE block has one stage, so the literal raised `IndexError`
    # and took the whole stage-8 arm with it, CT-2..CT-9 included.  A run
    # keeps stage 1, so no run record moves; a block perturbs its one stage.
    stage, slot, term = min(1, bundle.blocks - 1), 17, 3
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
            # [ROUND 9j] a standalone block is replayed under its OWN header
            rp = replay_for(bundle).run()
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
    elif old_bundle.run.get("plane_index") is not None:
        old.update({
            "skipped": f"{old_bundle.name} CARRIES a plane index table, so it cannot "
            "stand for a pre-stage-15 bundle; pass one with --old",
            "fires": False,
        })
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
    # [TINYLLAMA PORT 2026-10-17] CT-5 flipped an entry of supp(Dom::S),
    # which exists only where Dom::S PADS -- every shape before TinyLlama.
    # At the trained TinyLlama shape S, D, Q, Kv, Ht and T are exact and
    # only F, L and Tab pad, so `supp("S")` is None.  The control's meaning
    # is "a rebuilt public support table, one entry flipped, is caught by the
    # capture's own digest"; it now takes the FIRST padded domain of this
    # list, in its host slot, so at every earlier shape it is still Dom::S in
    # slot 17 and no earlier record moves.
    for dom5, slot5 in (("S", 17), ("F", 18), ("D", 14), ("Q", 15),
                        ("Kv", 16), ("L", 3), ("T", 2), ("Tab", 19)):
        cube = 1 << bundle.stages[0].doc["arguments"][slot5]["main"]
        real = geom.supp(dom5, cube)
        if real is not None:
            break
    flipped = list(real)
    at = next(i2 for i2, x in enumerate(flipped) if x == 1)
    flipped[at] = 0
    captured = next(t["sha256"] for t in bundle.stages[0].doc["arguments"][slot5]["tables"]
                    if t["kind"] == "public" and t["sha256"] == table_digest(real))
    out["controls"].append({
        "control": "CT-5",
        "what": f"one entry (index {at}) of the rebuilt supp(Dom::{dom5}) table "
                f"(slot {slot5:02d}) flipped from 1 to 0",
        "mechanism": "the SHA-256 the capture carries for that public table",
        "the_honest_table_matches_the_capture": table_digest(real) == captured,
        "the_flipped_table_does_not": table_digest(flipped) != captured,
        "fires": table_digest(real) == captured and table_digest(flipped) != captured,
    })

    # ============== round 3: the CAPTURED public tables and a new slot
    if getattr(bundle, "public_tables_included", False):
        out["controls"] += _captured_table_controls(bundle, index, replay)

    # ====== [ROUND 9b] CT-9: the pad rule, in whichever directions exist
    out["controls"] += _pad_rule_controls(bundle, index, replay, honest)

    out["ok"] = all(c.get("fires") for c in out["controls"])
    out["controls_that_did_not_fire"] = [
        c["control"] for c in out["controls"] if not c.get("fires")
    ]
    return out


# --------------------------------------------------------------------------
# [ROUND 9b] CT-9: the pad rule, and M9-3's development-shape twin
# --------------------------------------------------------------------------
# Finding M-F1 was a hardcoded `n_pad = 1` in every zero-check port, and its
# control M9-3 (`zk60_native_rg_m125controls`) is fired only by the 125M
# driver -- so the regression for a repair that took a 281 MB bundle and
# three minutes to find lived at the 125M shape alone.  This is the same
# control in the ORDINARY gate, at whatever shape it is handed, and in BOTH
# directions:
#
#   * a domain that does NOT pad, made to LOOK PADDED -- M9-3 exactly.  It
#     exists only at a shape with an unpadded domain: 125M, and now `rung-P2`,
#     where T, Kv and F sit exactly on their pads;
#   * a domain that DOES pad, made to look UNPADDED -- the mirror, which
#     exists at every shape this gate has ever read, including the toy and
#     both development rungs.
#
# Either way the host slot must REFUSE BY NAME, with the draws it consumes
# and the draws the capture declares in the message, and no other slot may
# stop being checked.  A refusal that raises instead of reporting is finding
# K4-F1 and is what this control is against.
PAD_HOSTS = {"T": (2, "SC_TZC"), "L": (3, "SC_LZC"), "D": (14, "SC_DZC"),
             "Q": (15, "SC_QZC"), "Kv": (16, "SC_KVZC"), "S": (17, "SC_SZC"),
             "Ht": (17, "SC_SZC"), "F": (18, "SC_FZC"),
             "Tab": (19, "SC_TAB")}


def _pad_rule_controls(bundle, index, replay, honest) -> list:
    """CT-9: one entry per domain whose pad state is flipped, one at a
    time, on the port's own `PadGeometry.pads` -- the method
    `zk60_native_rg_terminals.Geometry` really calls, patched on the class
    for the length of one `check_terminals` and restored in a `finally`.

    **The object matters, and finding P-F2 is why.**  Round 9's M9-3 read
    `index.geom`, which a `PlaneIndex` does not have, so every domain's pad
    state came back `None`, the control found no unpadded domain and
    excused itself as inapplicable -- at the one shape where it applied."""
    geom = PadGeometry(bundle.run["shape"], index.domain_log)
    pads = {}
    for dom in PAD_HOSTS:
        if dom not in index.domain_log:
            pads[dom] = None
            continue
        try:
            pads[dom] = bool(geom.pads(dom))
        except Exception:  # noqa: BLE001 -- a domain this shape has no size for
            pads[dom] = None
    # `Dom::Ht` is hosted by slot 17 beside `Dom::S`, so it is reported and
    # not perturbed separately: the rule is about the HOSTED SET.
    unpadded = sorted(d for d, v in pads.items() if v is False and d != "Ht")
    # The mirror runs once, not nine times: at the 125M shape one
    # `check_terminals` is a hundred seconds, and a control that doubles the
    # cost of the stage it lives in gets turned off.  `Dom::L` is the
    # cheapest host slot and pads at every shape this gate has read; if some
    # shape ever unpads it, the first padded domain is taken instead.
    mirror = ("L" if pads.get("L") else
              next((d for d in sorted(PAD_HOSTS) if pads.get(d) and d != "Ht"),
                   None))
    targets = [(d, False) for d in unpadded]
    if mirror is not None:
        targets.append((mirror, True))
    per = []
    for dom, padded in targets:
        slot, name = PAD_HOSTS[dom]
        real = SlotCtx.pad_on

        def flipped(self, *doms, _dom=dom, _r=real):
            return (not _r(self, *doms)) if _dom in doms else _r(self, *doms)

        SlotCtx.pad_on = flipped
        try:
            bad = check_terminals(bundle, index, replay=replay)
            said = [f["why"] for s in bad["per_stage"]
                    for f in s["not_checked"] if f["slot"] == slot]
            equal = bad["slot_checks_equal"]
        finally:
            SlotCtx.pad_on = real
        names_both = bool(said) and ("definition draws" in said[0]
                                     and "the capture declares" in said[0])
        per.append({
            "domain": dom,
            "slot": slot,
            "name": name,
            "direction": ("a PADDED domain's slot made to consume the "
                          "UNPADDED arithmetic (the mirror, which exists at "
                          "every shape)" if padded else
                          "an UNPADDED domain's slot made to consume the "
                          "PADDED arithmetic (M9-3's own direction, which "
                          "needs a domain sitting exactly on its pad)"),
            "honest_pad_state": pads[dom],
            "refusal": (said[0] if said else None),
            "the_refusal_names_the_two_numbers": names_both,
            "only_this_slot_stopped_being_checked":
                equal == honest["slot_checks_equal"] - bundle.blocks,
            "fires": bool(said) and names_both,
        })
    return [{
        "control": "CT-9",
        "what": "the pad rule's DRAW ARITHMETIC flipped for one hosted "
        "domain at a time -- `SlotCtx.pad_on`, the method finding M-F1 was "
        "a hardcoded `True` in -- with the public-table geometry left "
        "alone, so what is tested is exactly the draw count: the slot must "
        "refuse BY NAME with the draws it consumes and the draws the "
        "capture declares, and no other slot may stop being checked",
        "pads_by_domain": pads,
        "domains_that_do_not_pad_at_this_shape": unpadded,
        "the_M9_3_direction_exists_here": bool(unpadded),
        "mirror_domain": mirror,
        "why_it_matters_that_it_does_or_does_not":
            "a shape where every domain pads can only run the mirror "
            "direction; the direction finding M-F1 is about needs a domain "
            "sitting exactly on its pad, which before `rung-P2` only the "
            "125M shape had -- which is why M-F1 waited for a 281 MB "
            "bundle and why this shape exists",
        "per_domain": per,
        "fires": bool(per) and all(p["fires"] for p in per),
    }]


def _docs_with_public_value_perturbed(bundle, stage: int, slot: int, tab: int,
                                      at: int):
    """The stage documents with ONE value of ONE captured public table
    changed by +1.  Only the dictionaries on the path are copied."""
    docs = [st.doc for st in bundle.stages]
    doc = dict(docs[stage])
    args = list(doc["arguments"])
    arg = dict(args[slot])
    tabs = list(arg["tables"])
    t = dict(tabs[tab])
    vals = list(t["values"])
    old = f2_from_list(vals[at])
    new = f2_add(old, F2_ONE)
    vals[at] = [new[0], new[1]]
    t["values"] = vals
    tabs[tab] = t
    arg["tables"] = tabs
    args[slot] = arg
    doc["arguments"] = args
    docs = list(docs)
    docs[stage] = doc
    return docs, old, new


def _captured_table_controls(bundle, index, replay) -> list:
    """CT-6, CT-7 and CT-8 -- the three that only a bundle carrying its
    public tables' values can have."""
    out = []
    # slot 5's single public table is the fold of the public query weight
    # matrix, and position 0 is inside the width's live support, so the
    # perturbation is a value the verifier really reads.
    stage, slot, at = 0, 5, 0
    tab = next(i for i, t in enumerate(bundle.stages[stage].doc["arguments"][slot]
                                       ["tables"]) if t["kind"] == "public")
    docs, old, new = _docs_with_public_value_perturbed(bundle, stage, slot, tab, at)
    caught = check_terminals(bundle, index, replay=replay, stage_docs=docs)
    why = [e["why"] for r in caught["per_stage"] for e in r["not_checked"]
           if e["slot"] == slot and e["why"] != "OPEN"]
    out.append({
        "control": "CT-6",
        "what": f"stage {stage}, slot {slot} [SC_QMM]: value {at} of the captured "
                "public weight fold changed by +1",
        "mechanism": "the capture's own SHA-256 for that public table",
        "the_slot_is_not_reported_checked": all(
            slot not in r["checked"] for r in caught["per_stage"]
            if r["stage"] == stage),
        "refusal": (why or [""])[0][:200],
        "digest_failures": len(caught["public_table_digest_failures"]),
        "slot_checks_equal": caught["slot_checks_equal"],
        "of": caught["slot_checks_expected"],
        "the_other_stages_are_untouched": caught["slot_checks_equal"]
        == caught["slot_checks_expected"] - 1,
        "fires": bool(why) and bool(caught["public_table_digest_failures"]),
    })

    # the same perturbation with the digest check DROPPED: the arithmetic,
    # not the label, must catch it -- and at exactly one slot of one stage.
    loose = check_terminals(bundle, index, replay=replay, stage_docs=docs,
                            check_digests=False)
    failed = sorted({(r["stage"], s) for r in loose["per_stage"]
                     for s in r["checked"] if s not in r["equal"]})
    out.append({
        "control": "CT-7",
        "what": "the same perturbed value, with the public-table digest check "
                "dropped (in this control only)",
        "mechanism": "the identity's own arithmetic",
        "slots_that_failed": [list(x) for x in failed],
        "fails_at_exactly_the_slot_that_reads_that_table": failed == [(stage, slot)],
        "slot_checks_equal": loose["slot_checks_equal"],
        "of": loose["slot_checks_expected"],
        "fires": failed == [(stage, slot)],
    })

    # CT-8: a terminal of one of the ELEVEN newly covered slots.
    #
    # **[ROUND 9, finding M-F3.]**  This read `stage2 = 2` -- the LAST stage
    # of a three-block run, written when every run in scope had three.  A
    # two-block run has no stage 2 and the control raised `IndexError`
    # through the whole terminal stage, taking CT-1..CT-7 with it: a control
    # that crashes is not a control, which is finding K4-F1 again, this time
    # about `L` rather than about a pin.  The stage is now DERIVED as the
    # run's last, which is what "a slot that was open until this round" was
    # ever about.
    stage2, slot2, term2 = bundle.blocks - 1, 14, 5
    docs2, _o, _n = _docs_with_terminal_perturbed(bundle, stage2, slot2, term2)
    got = check_terminals(bundle, index, replay=replay, stage_docs=docs2)
    failed2 = sorted({(r["stage"], s) for r in got["per_stage"]
                      for s in r["checked"] if s not in r["equal"]})
    out.append({
        "control": "CT-8",
        "what": f"stage {stage2}, slot {slot2} [SC_DZC], terminal {term2} changed "
                "by +1 -- a slot that was OPEN until this round",
        "mechanism": "the identity's own arithmetic",
        "slots_that_failed": [list(x) for x in failed2],
        "fails_at_exactly_the_perturbed_slot": failed2 == [(stage2, slot2)],
        "slot_checks_equal": got["slot_checks_equal"],
        "of": got["slot_checks_expected"],
        "fires": failed2 == [(stage2, slot2)],
    })
    return out

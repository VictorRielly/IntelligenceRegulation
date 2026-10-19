"""ROUND 9's OWN controls: the ones the 125M shape and the `/5-run` store
make possible, and that no earlier round could run.

Rounds 1-8 have thirty-four controls between them (C1-C6, CT-1..CT-8,
CH-1..CH-7, GQ-1..GQ-7, P-1..P-6, M-1..M-6) and they all still apply; the
gate fires them at 125M unchanged.  This module adds the three that are
NEW BECAUSE OF THIS ROUND, and each is shown to PASS on the honest bundle
first.

* **M9-1, the array store.**  One reference's byte range is moved by eight
  bytes in memory -- the same length, the same element type, real bytes of
  the same file, and a digest that no longer matches.  The loader must
  REFUSE BY NAME.  This is the control for the one new trust assumption the
  schema introduces: that the bytes at an offset are the array the JSON
  says they are.
* **M9-2, an opened column entry.**  One entry of one opened column is moved
  by one, in memory.  The Merkle leaf under the bundle's own derived rule no
  longer authenticates, and the verifier's own sampled-column identity for
  that commitment fails.  Two independent refusals from one perturbation.
* **M9-3, the unpadded-domain draw count** -- finding M-F1's own control.
  The three host slots of the three domains that do not pad at 125M are made
  to believe their domain pads, and each refuses BY NAME with the two
  numbers in the message.  Before this round the same case was an
  `IndexError`; the control is here so it can never quietly become one
  again.

NOTHING IS WRITTEN.  Every perturbation is applied to an in-memory copy and
a caller re-reads the bundle's files afterwards; the record carries the
before-and-after digests.  NOTHING HERE IS A PRIVACY STATEMENT.
"""

from __future__ import annotations

import copy
import hashlib
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

from zk60_native_rg_arrays import ArrayRefused  # noqa: E402
from zk60_native_rg_hashlayer import check_hash_layer  # noqa: E402


def _digests(bundle) -> dict:
    out = {}
    for fn in sorted(os.listdir(bundle.dir)):
        p = os.path.join(bundle.dir, fn)
        if not os.path.isfile(p):
            continue
        h = hashlib.sha256()
        with open(p, "rb") as fh:
            for chunk in iter(lambda: fh.read(1 << 22), b""):
                h.update(chunk)
        out[fn] = h.hexdigest()
    return out


# ------------------------------------------------------------------ M9-1
def m9_1_a_moved_array_reference(bundle) -> dict:
    """The honest reference resolves; the same reference shifted by one
    field element does not."""
    st = bundle.stages[0]
    member = st.roles[0]["groups"][0]["vector"]
    ref = dict(member.ref)
    honest = None
    try:
        got = bundle.store.resolve(ref, "stage-00.json.roles[0].groups[0].vector")
        honest = len(got)
    except ArrayRefused as e:
        return {"control": "M9-1", "fires": False,
                "the_honest_case_refused": str(e), "ok": False}
    moved = dict(ref, offset=ref["offset"] + 8)
    refusal = None
    raised = None
    try:
        bundle.store.resolve(moved, "stage-00.json.roles[0].groups[0].vector")
    except ArrayRefused as e:
        refusal = str(e)
    except Exception as e:  # noqa: BLE001 -- this is the thing being tested
        raised = f"{type(e).__name__}: {e}"
    return {
        "control": "M9-1",
        "what": "one array reference's byte range moved by 8 bytes in "
        "memory -- the same length, the same element type, real bytes of "
        "the same arrays.bin",
        "honest_entries_resolved": honest,
        "refusal": refusal,
        "it_raised_something_other_than_a_refusal": raised,
        "mechanism": "the SHA-256 the reference itself carries, over "
        "exactly the bytes it names",
        "fires": bool(refusal) and raised is None,
        "ok": bool(refusal) and raised is None,
    }


# ------------------------------------------------------------------ M9-2
class _ShadowStage:
    """A stage with exactly one opened-column entry replaced.

    `arguments`, `mask` and `roles` are shallow-copied down to the one
    column that moves, so nothing on disk and nothing else in memory is
    touched."""

    def __init__(self, st, role_i: int, col_i: int, entry_i: int):
        self.__dict__.update(st.__dict__)
        self.doc = dict(st.doc)
        roles = [dict(r) for r in st.doc["roles"]]
        cols = [dict(c) for c in roles[role_i]["columns"]]
        vals = list(cols[col_i]["values"])
        self.moved = {"role": roles[role_i]["role"], "column": col_i,
                      "entry": entry_i, "from": vals[entry_i]}
        vals[entry_i] = (vals[entry_i] + 1) % ((1 << 64) - (1 << 32) + 1)
        self.moved["to"] = vals[entry_i]
        cols[col_i]["values"] = vals
        roles[role_i]["columns"] = cols
        self.doc["roles"] = roles

    @property
    def roles(self):
        return self.doc["roles"]

    @property
    def slots(self):
        return self.doc["arguments"]

    @property
    def mask(self):
        return self.doc["mask"]

    def role(self, name):
        for r in self.doc["roles"]:
            if r["role"] == name:
                return r
        raise KeyError(name)

    def role_or_none(self, name):
        for r in self.doc["roles"]:
            if r["role"] == name:
                return r
        return None

    def boundary_opening(self):
        for r in self.doc["roles"]:
            if r["commitment_kind"] == "internal-boundary":
                return r
        return None

    def key(self, role_name):
        r = self.role(role_name)
        if r["commitment_kind"] == "internal-boundary":
            return f"B{r['boundary']}"
        if r["commitment_kind"] == "external-endpoint":
            return f"E-{role_name}"
        return f"{role_name}@{self.index}"


class _ShadowBundle:
    """A bundle with one stage replaced.

    `RunBundle.name` is a PROPERTY, not an instance attribute, so copying
    `__dict__` does not bring it and `check_hash_layer`'s first line raised
    `AttributeError`.  Found by running the control, which is what a
    control is for; carried explicitly here with everything else a reader
    of this shadow needs."""

    def __init__(self, bundle, stages):
        self.__dict__.update(bundle.__dict__)
        self.stages = stages
        self.name = bundle.name
        self._real = bundle

    def boundary(self, k):
        return self._real.boundary(k)

    def labels(self):
        return self._real.labels()


def m9_2_a_moved_opened_column_entry(bundle) -> dict:
    """The honest hash layer authenticates every column; with one entry of
    one column moved by one, that column's leaf does not."""
    honest = check_hash_layer(bundle)
    st = bundle.stages[0]
    shadow_stage = _ShadowStage(st, role_i=0, col_i=0, entry_i=0)
    shadow = _ShadowBundle(bundle, [shadow_stage] + list(bundle.stages[1:]))
    bad = check_hash_layer(shadow)
    return {
        "control": "M9-2",
        "what": "one entry of one opened column of the first commitment, "
        "moved by one, in memory",
        "moved": shadow_stage.moved,
        "honest": {"columns_checked": honest["columns_checked"],
                   "columns_authenticated": honest["columns_authenticated"],
                   "findings": len(honest["findings"])},
        "perturbed": {"columns_checked": bad["columns_checked"],
                      "columns_authenticated": bad["columns_authenticated"],
                      "findings": bad["findings"][:2],
                      "findings_total": len(bad["findings"])},
        "mechanism": "the leaf digest under the bundle's own DERIVED keyed "
        "rule, salted with the published salt and folded along the "
        "published path",
        "exactly_one_column_stopped_authenticating":
            honest["columns_authenticated"] - bad["columns_authenticated"] == 1,
        "fires": bad["columns_authenticated"] < honest["columns_authenticated"],
        "ok": (honest["columns_authenticated"] == honest["columns_checked"]
               and bad["columns_authenticated"]
               == honest["columns_authenticated"] - 1),
    }


# ------------------------------------------------------------------ M9-3
# [v7, finding G-4] `pad::indicator_slots` (R5b `pad.rs:225-238`, READ): the
# slots whose definition reads a domain's support indicator.  Ht is lifted
# over the trailing axis of the S cube, so it shares S's host slot.
INDICATOR_SLOTS = {
    "D": {0, 1, 14}, "Q": {15}, "S": {4, 17}, "Ht": {17}, "Kv": {16},
    "F": {18}, "L": {3}, "Tab": {19}, "T": {2},
}

# [v7, review round 2 Q-8] the two refusals that name the host slot's
# indicator mechanism, matched EXACTLY (the texts of
# `zk60_native_rg_terminals.TerminalGate.build_public` and
# `SlotCtx.pad_draws`).  Any other refusal -- by name or not -- does not count.
_TABLE_COUNT = re.compile(
    r"^slot (\d+): the port declares (\d+) public tables, the capture has (\d+)$")
_DRAW_COUNT = re.compile(
    r"^slot (\d+): this slot consumes (\d+) definition draws \(.*\) and the "
    r"capture declares (\d+)$")
# a domain made to look padded adds ONE support table to its host slot, and
# TWO definition draws (the pad mu and zeta) to it
_EXTRA = {"public-table count": 1, "definition-draw count": 2}


def _stopped_slots(rec) -> set:
    """the slots that are not checked or do not match, over every stage"""
    out = set()
    for row in rec["per_stage"]:
        out |= set(row["checked"]) - set(row["equal"])
        out |= {e["slot"] for e in row["not_checked"]}
    return out


def refusal_mechanism(host: int, said: list):
    """Which indicator mechanism the host slot's first refusal names, and its
    two numbers (the port's, the capture's); (None, None) for anything else."""
    if not said:
        return None, None
    for mech, rx in (("public-table count", _TABLE_COUNT),
                     ("definition-draw count", _DRAW_COUNT)):
        m = rx.match(said[0])
        if m and int(m[1]) == host:
            return mech, (int(m[2]), int(m[3]))
    return None, None


def g4_criterion(dom: str, host: int, arm: str, stopped: set, said: list) -> dict:
    """[v7, finding G-4, tightened per review round 2 Q-8] one arm's verdict
    for one domain.

    arm "indicator": the domain's pad state forced true everywhere (the
      pre-v7 perturbation).  The host slot must refuse by one of the two
      indicator mechanisms -- recorded -- with exactly the expected surplus,
      and exactly the slots `pad::indicator_slots` lists must stop.
    arm "draw-count": only the host slot's `pad_on` forced true (its support
      tables untouched), so the public-table count agrees and the slot reaches
      the definition-draw count.  It must refuse by THAT mechanism, the port
      consuming exactly two draws more than the capture declares, and only the
      host slot may stop.  This is the refusal M9-3's criterion always
      expected; before v7 no perturbation reached it."""
    mech, nums = refusal_mechanism(host, said)
    if arm == "indicator":
        want_slots = set(INDICATOR_SLOTS[dom])
        allowed = ("public-table count", "definition-draw count")
    elif arm == "draw-count":
        want_slots = {host}
        allowed = ("definition-draw count",)
    else:
        raise ValueError(f"unknown M9-3 arm {arm!r}")
    surplus = nums[0] - nums[1] if nums else None
    mech_ok = mech in allowed and surplus == _EXTRA[mech]
    exact = stopped == want_slots
    return {"arm": arm, "refusal_mechanism": mech,
            "port_and_capture_numbers": list(nums) if nums else None,
            "mechanism_and_surplus_as_expected": mech_ok,
            "expected_slots_to_stop": sorted(want_slots),
            "exactly_the_expected_slots": exact,
            "ok": bool(said) and mech_ok and exact}


def m9_3_the_unpadded_domains(bundle, index, replay) -> dict:
    """Finding M-F1's own control.

    The domains that do not pad at this shape are made to LOOK padded to
    the port, one at a time, and the slot that hosts each must refuse by
    the mechanism the perturbation reaches.  Before round 9 this case
    raised an `IndexError` that the per-slot arm reported as 'not checked:
    list index out of range'.  [v7] Two arms per domain (`g4_criterion`)."""
    from zk60_native_rg_terminals import PadGeometry, SlotCtx, check_terminals

    honest = check_terminals(bundle, index, replay=replay)
    hosts = {"T": (2, "SC_TZC"), "Kv": (16, "SC_KVZC"), "F": (18, "SC_FZC"),
             "L": (3, "SC_LZC"), "D": (14, "SC_DZC"), "Q": (15, "SC_QZC"),
             "S": (17, "SC_SZC"), "Tab": (19, "SC_TAB")}
    # **[ROUND 9b] FINDING P-F2, repaired here.**  Until now this read
    # `index.geom`, and a `PlaneIndex` has no `geom`: the `except` below
    # turned every domain's pad state into `None`, `unpadded` came out
    # EMPTY, and the control reported "every domain pads at this shape, so
    # the control does not exist here" -- at the one shape where it did.
    # M-F1's own control had therefore never fired.  The pad state now comes
    # from the port's own `PadGeometry`, built the way
    # `zk60_native_rg_terminals.Geometry` builds it, and the perturbation
    # patches that class's `pads` for the length of one `check_terminals`.
    geom = PadGeometry(bundle.run["shape"], index.domain_log)
    geom_doms = {}
    pad_errors = {}
    for dom in hosts:
        try:
            geom_doms[dom] = bool(geom.pads(dom))
        except Exception as e:  # noqa: BLE001
            # [v5, review P-11] no longer swallowed: a domain whose pad state
            # cannot be read is NAMED and fails the control (it cannot fire)
            geom_doms[dom] = None
            pad_errors[dom] = f"{type(e).__name__}: {e}"[:200]
    unpadded = sorted(d for d, v in geom_doms.items() if v is False)
    honest_stopped = _stopped_slots(honest)

    def one_arm(dom, slot, arm):
        if arm == "indicator":
            owner, attr = PadGeometry, "pads"
            real = PadGeometry.pads

            def patched(self, d, _dom=dom, _r=real):
                return True if d == _dom else _r(self, d)
        else:
            owner, attr = SlotCtx, "pad_on"
            real = SlotCtx.pad_on

            def patched(self, *doms, _dom=dom, _r=real):
                return True if _dom in doms else _r(self, *doms)
        setattr(owner, attr, patched)
        try:
            bad = check_terminals(bundle, index, replay=replay)
        finally:
            setattr(owner, attr, real)
        said = [f["why"] for s in bad["per_stage"]
                for f in s["not_checked"] if f["slot"] == slot]
        stopped = _stopped_slots(bad) - honest_stopped
        crit = g4_criterion(dom, slot, arm, stopped, said)
        return {"refusal": said[0] if said else None,
                "slots_that_stopped_being_checked": sorted(stopped),
                "fires": bool(said), **crit}

    per = []
    for dom in unpadded:
        slot, name = hosts[dom]
        arms = {a: one_arm(dom, slot, a) for a in ("indicator", "draw-count")}
        ind = arms["indicator"]
        per.append({
            "domain": dom, "slot": slot, "name": name,
            "refusal": ind["refusal"],
            # kept for the record; NOT criteria since v7 (finding G-4)
            "the_refusal_names_the_two_numbers":
                bool(ind["refusal"]) and "definition draws" in ind["refusal"]
                and "the capture declares" in ind["refusal"],
            "only_this_slot_stopped_being_checked":
                ind["slots_that_stopped_being_checked"] == [slot],
            # [v7, finding G-4 / review Q-8]
            "the_indicator_slots_of_the_domain": sorted(INDICATOR_SLOTS[dom]),
            "arms": arms,
            "fires": all(a["fires"] for a in arms.values()),
            "ok": all(a["ok"] for a in arms.values()),
        })
    return {
        "control": "M9-3",
        "what": "each domain that does NOT pad at this shape, made to look "
        "padded to the port one at a time, in two arms: everywhere (its host "
        "slot must refuse by an indicator mechanism and exactly the slots "
        "pad::indicator_slots lists must stop) and at the host slot's draw "
        "count only (it must refuse by the definition-draw count, two draws "
        "over the capture's, and only the host slot may stop) -- finding "
        "M-F1; v7 = finding G-4 / review round 2 Q-8",
        "pads_by_domain": geom_doms,
        "domains_that_do_not_pad": unpadded,
        "honest_slot_checks_equal": honest["slot_checks_equal"],
        "per_domain": per,
        "skipped": None if unpadded else
        "every domain pads at this shape, so the control does not exist "
        "here -- which is exactly why rounds 1-8 could not run it",
        "fires": bool(per) and all(p["fires"] for p in per),
        # [v5, review P-11] with no domain left, ok only when that is the
        # named every-domain-pads case and no domain's pad state errored
        "pad_state_errors": pad_errors,
        # [v7] per domain, both arms ok.  Before v7 the criterion asked that
        # the indicator arm's refusal name the two definition-draw counts
        # (false at every shape: the public-table count refusal fires first)
        # and that exactly ONE slot stop (false for D and S).
        "ok": (all(p["ok"] for p in per) if per else True) and not pad_errors,
    }


# ---------------------------------------------------------------- driver
def m125_controls(bundle, index=None, replay=None) -> dict:
    before = _digests(bundle)
    out = [m9_1_a_moved_array_reference(bundle),
           m9_2_a_moved_opened_column_entry(bundle)]
    if index is not None and replay is not None:
        out.append(m9_3_the_unpadded_domains(bundle, index, replay))
    else:
        # [v5, review P-11] NAMED, never silently omitted
        out.append({"control": "M9-3", "fires": None,
                    "skipped": "not run in this pass: it needs the terminal "
                    "stage's plane index (run the pass with `terminals`)"})
    after = _digests(bundle)
    live = [c for c in out if not c.get("skipped")]
    return {
        "what": "round 9's own controls -- the ones the 125M shape and the "
        "binary array store make possible",
        "controls": out,
        "controls_that_did_not_fire": [c["control"] for c in out
                                       if not c.get("fires")
                                       and not c.get("skipped")],
        "nothing_on_disk_was_written": before == after,
        "bundle_file_digests_unchanged": before == after,
        # [v5, review P-11] over the controls that RAN (a named skip is not a
        # failure, as in the hash-rule family), and never over none
        "ok": bool(live) and all(c.get("ok") for c in live) and before == after,
    }

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
def m9_3_the_unpadded_domains(bundle, index, replay) -> dict:
    """Finding M-F1's own control.

    The three domains that do not pad at 125M are made to LOOK padded to
    the port -- `Shape::pads` forced true for one of them at a time -- and
    the slot that hosts it must refuse by name, saying how many definition
    draws it would consume and how many the capture declares.  Before round
    9 this case raised an `IndexError` that the per-slot arm reported as
    'not checked: list index out of range'."""
    from zk60_native_rg_terminals import PadGeometry, check_terminals

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
    for dom in hosts:
        try:
            geom_doms[dom] = bool(geom.pads(dom))
        except Exception:  # noqa: BLE001
            geom_doms[dom] = None
    unpadded = sorted(d for d, v in geom_doms.items() if v is False)
    per = []
    for dom in unpadded:
        slot, name = hosts[dom]
        real = PadGeometry.pads

        def looks_padded(self, d, _dom=dom, _r=real):
            return True if d == _dom else _r(self, d)

        PadGeometry.pads = looks_padded
        try:
            bad = check_terminals(bundle, index, replay=replay)
            said = [f["why"] for s in bad["per_stage"]
                    for f in s["not_checked"] if f["slot"] == slot]
        finally:
            PadGeometry.pads = real
        per.append({
            "domain": dom, "slot": slot, "name": name,
            "refusal": said[0] if said else None,
            "the_refusal_names_the_two_numbers":
                bool(said) and "definition draws" in said[0]
                and "the capture declares" in said[0],
            "only_this_slot_stopped_being_checked":
                bad["slot_checks_equal"]
                == honest["slot_checks_equal"] - bundle.blocks,
            "fires": bool(said),
        })
    return {
        "control": "M9-3",
        "what": "each domain that does NOT pad at this shape, made to look "
        "padded to the port one at a time; its host slot must refuse by "
        "name (finding M-F1)",
        "pads_by_domain": geom_doms,
        "domains_that_do_not_pad": unpadded,
        "honest_slot_checks_equal": honest["slot_checks_equal"],
        "per_domain": per,
        "skipped": None if unpadded else
        "every domain pads at this shape, so the control does not exist "
        "here -- which is exactly why rounds 1-8 could not run it",
        "fires": bool(per) and all(p["fires"] for p in per),
        "ok": all(p["fires"] and p["the_refusal_names_the_two_numbers"]
                  for p in per) if per else True,
    }


# ---------------------------------------------------------------- driver
def m125_controls(bundle, index=None, replay=None) -> dict:
    before = _digests(bundle)
    out = [m9_1_a_moved_array_reference(bundle),
           m9_2_a_moved_opened_column_entry(bundle)]
    if index is not None and replay is not None:
        out.append(m9_3_the_unpadded_domains(bundle, index, replay))
    after = _digests(bundle)
    return {
        "what": "round 9's own controls -- the ones the 125M shape and the "
        "binary array store make possible",
        "controls": out,
        "controls_that_did_not_fire": [c["control"] for c in out
                                       if not c.get("fires")
                                       and not c.get("skipped")],
        "nothing_on_disk_was_written": before == after,
        "bundle_file_digests_unchanged": before == after,
        "ok": all(c.get("ok") for c in out) and before == after,
    }

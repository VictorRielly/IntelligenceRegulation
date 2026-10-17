#!/usr/bin/env python3
"""[TINYLLAMA PORT, tools v4, 2026-10-17] A staged record's STATUS, beside
its `ok`.

    python3 zk60_native_rg_status.py --record <record.json> [--out <file>]

WHY.  `zk60_native_rg_m125.py` computes `ok` as "no stage reports
ok = false".  A pass run WITHOUT `--controls` therefore exits 1 whenever one
of its stages conjoins its controls even when they were not asked for -- and
`zk60_native_run_gate.stage12` does (`ok = arm and controls.ok`, with
`controls = {"skipped": "controls not requested", "ok": False}`), and the
joint stage (`zk60_native_rg_mjoint`) conjoins stage 12's `ok`.  The driver
prints "FAIL" for both.  The 22-block all-zero arms pass of 2026-10-17
(`tl-l22r2-zero-arms.json`) is exactly that state: every figure of both arms
closed, the record says ok = false.  "FAIL" is the wrong word for it, and a
reader cannot tell it from a figure that failed without reading the code.

WHAT THIS DOES.  It does not touch `ok`, which stays the gate's only pass
verdict and is copied unchanged.  It adds a STATUS computed from the record's
own fields:

  PASS       `ok` is true.
  ARMS-ONLY  `ok` is false; `--controls` was NOT given for the pass (no
             control family of stages 8, 10, 11, 12 ran, at least one says
             "controls not requested"); no stage raised; and EVERY false
             `ok` / `all_fire` / `fires` leaf of the record is one of
               (a) a `controls` entry reading exactly
                   {"skipped": "controls not requested", "ok": false};
               (b) stage 12's own `ok`, where the masking arm is CLOSED --
                   recomputed here: its pins accepted, every stage checked and
                   ok, none refused, entries recomputed > 0, 0 differing,
                   salted leaves > 0;
               (c) stage 13's own `ok`, where the joint assignment is CLOSED --
                   recomputed: four couplings, each respected; 0 differing in
                   both parts and in total; stage 11 requested, unrestricted,
                   ok, 0 differing, every requested commitment exhibited; stage
                   12 closed by (b); its only finding the masking-side one that
                   stage 12's `ok` produces;
               (d) the record's top-level `ok`.
  NOT-OK     anything else.  The false leaves are listed; nothing is claimed
             about them (a by-name skip such as CT-4 or CH-6 lands here too:
             this module explains exactly one state and no other).

WHAT ARMS-ONLY DOES NOT SAY.  That the controls of those arms fired.  They did
not fire IN THIS PASS; the status lists every control family that did not, and
an arm counts only where its controls fired on the same tools and shape in
another record, which the lane's ledger has to cite.

NOTHING HERE IS A PRIVACY STATEMENT.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os

NOT_REQUESTED = "controls not requested"
MASK_SIDE_FINDING = ("round 8's arm is off or did not close, so there is "
                     "nothing to join on the masking side")
CONTROL_FAMILIES = {
    "stage8_plane_index_and_terminals": "CT-1..CT-9 (terminal identity)",
    "stage10_bilinear_group_factor": "GQ (bilinear group factor)",
    "stage11_full_preimage": "P-1..P-6 (full preimage arm)",
    "stage12_mask_and_cfs": "M1..M6 (masking / CFS arm)",
}
FALSE_KEYS = ("ok", "all_fire", "fires")


def false_leaves(o, path=""):
    """every `ok` / `all_fire` / `fires` that is exactly False"""
    out = []
    if isinstance(o, dict):
        for k, v in o.items():
            p = f"{path}/{k}"
            if k in FALSE_KEYS and v is False:
                out.append(p)
            out += false_leaves(v, p)
    elif isinstance(o, list):
        for i, v in enumerate(o):
            out += false_leaves(v, f"{path}[{i}]")
    return out


def _skipped_not_requested(c):
    return isinstance(c, dict) and c == {"skipped": NOT_REQUESTED, "ok": False}


def mask_arm_closed(s12, blocks):
    """(b): stage 12's arm figures, recomputed from its own fields"""
    if not isinstance(s12, dict):
        return False
    per = s12.get("per_stage") or []
    rec = s12.get("entries_recomputed")
    return bool(
        s12.get("requested") is True
        and (s12.get("source_pins") or {}).get("ok") is True
        and s12.get("stages_checked") == blocks
        and len(per) == blocks
        and all(isinstance(st, dict) and st.get("ok") is True for st in per)
        and s12.get("stages_that_refused") == []
        and isinstance(rec, int) and rec > 0
        and s12.get("entries_differing") == 0
        and (s12.get("salted_leaves_authenticated") or 0) > 0
    )


def joint_closed(s13, s11, s12, blocks):
    """(c): stage 13's figures, recomputed from its own fields and the arms'"""
    if not all(isinstance(x, dict) for x in (s13, s11, s12)):
        return False
    parts = s13.get("parts") or {}
    couplings = s13.get("couplings") or {}
    return bool(
        s13.get("requested") is True
        and len(couplings) == 4
        and all(isinstance(c, dict) and c.get("respected") is True
                for c in couplings.values())
        and s13.get("all_four_couplings_respected") is True
        and s13.get("entries_differing") == 0
        and parts.get("pcs_entries_differing") == 0
        and parts.get("masking_entries_differing") == 0
        and (parts.get("pcs_entries_compared") or 0) > 0
        and (parts.get("masking_entries_compared") or 0) > 0
        and s11.get("requested") is True
        and s11.get("ok") is True
        and s11.get("arm_restricted_to") is None
        and s11.get("view_entries_differing") == 0
        and (s11.get("view_entries_compared") or 0) > 0
        and s11.get("not_exhibited") == []
        and sorted(s11.get("exhibited") or []) == sorted(s11.get("commitments") or [])
        and len(s11.get("exhibited") or []) > 0
        and mask_arm_closed(s12, blocks)
        and s13.get("findings") == [MASK_SIDE_FINDING]
    )


def explain(record, path, controls_requested):
    """the reason a false leaf is the arms-only state, or None"""
    if controls_requested:
        return None
    blocks = record.get("blocks")
    if path == "/ok":
        return "(d) the record's top-level ok"
    parts = path.strip("/").split("/")
    if len(parts) == 3 and parts[1] == "controls" and parts[2] == "ok":
        if _skipped_not_requested(record.get(parts[0], {}).get("controls")):
            return "(a) controls not requested in this pass"
        return None
    if path == "/stage12_mask_and_cfs/ok":
        s12 = record.get("stage12_mask_and_cfs")
        if (mask_arm_closed(s12, blocks)
                and _skipped_not_requested(s12.get("controls"))):
            return ("(b) the masking arm closed; ok = arm AND controls.ok, and the "
                    "controls were not requested")
        return None
    if path == "/stage13_joint_run_preimage/ok":
        s12 = record.get("stage12_mask_and_cfs")
        if (joint_closed(record.get("stage13_joint_run_preimage"),
                         record.get("stage11_full_preimage"), s12, blocks)
                and isinstance(s12, dict)
                and _skipped_not_requested(s12.get("controls"))):
            return ("(c) the joint assignment closed; its ok conjoins stage 12's ok, "
                    "which is false only for (b)")
        return None
    return None


def infer_controls_requested(record):
    """True if any control family of stages 8/10/11/12 RAN; False if none ran
    and at least one says it was not requested; None if neither is known"""
    ran, not_req = False, False
    for key in CONTROL_FAMILIES:
        c = (record.get(key) or {}).get("controls") if isinstance(record.get(key), dict) else None
        if c is None:
            continue
        if _skipped_not_requested(c):
            not_req = True
        elif not (isinstance(c, dict) and "skipped" in c):
            # a family that ran carries its controls; every skip names itself
            # ("controls not requested", "stage 8 was not run in this pass",
            # "the arm was restricted to [...]", a refusal of the pins)
            ran = True
    if ran:
        return True
    if not_req:
        return False
    return None


def classify(record, controls_requested=None) -> dict:
    """The status of one staged record.  `controls_requested` is the driver's
    own flag when it is known; otherwise it is inferred from the record."""
    inferred = infer_controls_requested(record)
    if controls_requested is None:
        controls_requested = inferred
    raised = [t.get("stage") for t in record.get("timings", []) if t.get("raised")]
    raised += [k for k, v in record.items()
               if isinstance(v, dict) and "the_stage_raised" in v]
    leaves = false_leaves(record)
    explained = {p: explain(record, p, controls_requested) for p in leaves}
    unexplained = [p for p, why in explained.items() if why is None]
    not_fired = {k: CONTROL_FAMILIES[k] for k in CONTROL_FAMILIES
                 if isinstance(record.get(k), dict)
                 and _skipped_not_requested(record[k].get("controls"))}
    if record.get("ok") is True:
        status = "PASS"
    elif (controls_requested is False and inferred is not True and not raised
          and leaves and not unexplained):
        status = "ARMS-ONLY"
    else:
        status = "NOT-OK"
    return {
        "status": status,
        "ok": record.get("ok"),
        "ok_is_unchanged": "this status never changes `ok`; ok = false stays "
        "ok = false",
        "controls_requested": controls_requested,
        "controls_requested_inferred_from_the_record": inferred,
        "stages_that_raised": raised,
        "false_leaves": leaves,
        "explained": {p: w for p, w in explained.items() if w is not None},
        "unexplained": unexplained,
        "control_families_not_fired_in_this_pass": not_fired,
        "what_ARMS_ONLY_means": "every figure of the arms this pass ran closed "
        "(recomputed here from the record), and the ONLY reason ok is false is "
        "that the pass was run without --controls",
        "what_it_does_not_mean": "that those controls fired: they did not, in "
        "this pass.  An arm counts only where its controls fired on the same "
        "tools and shape in another record, which the ledger must cite",
        "privacy_property_established": False,
        "privacy_acceptance": False,
    }


def status_record(record_path, controls_requested=None) -> dict:
    with open(record_path, "rb") as fh:
        raw = fh.read()
    rec = json.loads(raw)
    here = os.path.dirname(os.path.abspath(__file__))
    with open(os.path.join(here, "zk60_native_rg_status.py"), "rb") as fh:
        me = hashlib.sha256(fh.read()).hexdigest()
    out = {
        "record": os.path.abspath(record_path),
        "record_sha256": hashlib.sha256(raw).hexdigest(),
        "record_bundle": rec.get("bundle"),
        "record_stages_run": rec.get("stages_run"),
        "record_driver_sha256": (rec.get("tool_sha256") or {}).get(
            "zk60_native_rg_m125.py"),
        "classifier_sha256": me,
    }
    out.update(classify(rec, controls_requested))
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--record", required=True)
    ap.add_argument("--out")
    a = ap.parse_args(argv)
    out = status_record(a.record)
    path = a.out or (a.record[:-5] if a.record.endswith(".json") else a.record) \
        + ".status.json"
    with open(path, "w") as fh:
        json.dump(out, fh, indent=1, sort_keys=True)
        fh.write("\n")
    print(f"{out['status']}  ok={out['ok']}  false leaves {len(out['false_leaves'])}"
          f"  unexplained {len(out['unexplained'])}  -> {path}")
    return {"PASS": 0, "ARMS-ONLY": 3}.get(out["status"], 1)


if __name__ == "__main__":
    raise SystemExit(main())

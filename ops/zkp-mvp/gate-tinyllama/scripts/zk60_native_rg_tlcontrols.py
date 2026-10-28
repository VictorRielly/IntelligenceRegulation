#!/usr/bin/env python3
"""[TINYLLAMA PORT, 2026-10-17] Controls on the port's OWN adaptation: the
per-bundle calibration the terminal identity now reads from
`run.json["shape"]`.

    python3 zk60_native_rg_tlcontrols.py --bundle <trained bundle> \
        --evidence <dir> --name tl-controls

A port that READS constants from the bundle could be vacuous -- an identity
that holds whatever the constants are says nothing about them.  These
controls show it is not, on the real trained bytes and at the run's real
challenges:

* **TL-1** the FROZEN calibration on a trained bundle (the trained keys
  removed from a copy of the shape): exactly the slots whose relations read
  a constant that DIFFERS between the frozen and the trained calibration must
  fail -- predicted from the two calibrations alone, never read off the
  result -- and every other slot must still hold.
* **TL-2** each of the eleven trained constants moved by one step inside its
  declared class: exactly the slots that read THAT constant fail.
* **TL-3** a shape that names trained keys without `trained_calibration:
  true`, one with the flag but a key missing, and one with the flag false
  and keys present are each REFUSED by `Calibration` (no silent mixture of a
  frozen and a trained reading).

[v17, gate round 14] A run whose layers carry their OWN constants (native
R8 / R9 `stage_shape`) is evaluated stage by stage at each stage's
calibration (`zk60_native_rg_stagecal`).  TL-1 and TL-2 then perturb EVERY
stage's shape (passed to `check_terminals` as `stage_shapes`), and their
prediction is per (stage, slot): stage k fails in the slots that read a
constant that differs at stage k.  Two families are added:

* **TL-5** (the failing-first control of the per-stage calibration) each
  stage with own constants evaluated at the RUN shape instead, as tools v16
  would: predicted, exactly that stage's slots that read one of its own
  constants, and nothing else.  Named not applicable at a run without own
  constants.
* **TL-6** the stage-line reader's refusals on edited copies of run.json:
  an own value changed in a line (SC-5, the schedule digest), a clause's run
  value that is not the shape's (SC-1), a clause equal to the run's (SC-2),
  two clauses swapped (SC-3), and a mistyped label (SC-4).  Each must be
  refused with its code.

Nothing is written to the bundle: each perturbation is a shallow copy of the
loaded bundle with a modified `run["shape"]`.  NOTHING HERE IS A PRIVACY
STATEMENT.
"""

from __future__ import annotations

import argparse
import copy
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

from zk60_native_rg_block import load_bundle  # noqa: E402
from zk60_native_rg_planes import plane_index_of  # noqa: E402
from zk60_native_rg_replay import RunReplay  # noqa: E402
from zk60_native_rg_terminals import (  # noqa: E402
    FROZEN_CALIBRATION,
    TRAINED_KEYS,
    Calibration,
    check_terminals,
)
import zk60_native_rg_stagecal as SCAL  # noqa: E402  [v17]

# Which slot's relation (or lookup list) reads which calibration constant,
# from `argument.rs` / `layout.rs` at the trained digests (the readings in
# `zk60_native_rg_tinyllama_pins`).  The lookups of a domain enter its host
# zero-check's helper sum, so a top-limb coefficient is that slot's too.
READS = {
    "norm_ceps": {2},            # SC_TZC: dsq + a1 - Ceps (both norms)
    "norm_tn": {14},             # SC_DZC: 2^tn, 2^(tn+1)
    "norm_cn_a": {14},           # SC_DZC c0
    "norm_cn_m": {14},           # SC_DZC c6
    "sh_ao": {14},               # SC_DZC host_wo; Dom::D lookup RAL 2^(8-sh_ao)
    "sh_z": {14},                # SC_DZC host_dmm; Dom::D lookup RDL
    "sh_qkv": {15, 16},          # SC_QZC host1, SC_KVZC host1/2; RQL, RKL, RVL
    "sh_o": {15},                # SC_QZC host2; Dom::Q lookup RO1 2^(16-sh_o)
    "sh_s": {17},                # SC_SZC host_s; Dom::S lookup RSL
    "sh_g": {18},                # SC_FZC host_g; Dom::F lookup RGL
    "sh_h": {18},                # SC_FZC f0; Dom::F lookup RH1 2^(16-sh_h)
}
# a step inside each constant's declared class (`shape.rs`)
WINDOWS = {
    "norm_tn": (1, 16), "norm_cn_a": (1, 1 << 20), "norm_cn_m": (1, 1 << 20),
    "norm_ceps": (1, 1 << 40), "sh_ao": (0, 8), "sh_qkv": (1, 8),
    "sh_s": (1, 8), "sh_o": (9, 16), "sh_g": (1, 8), "sh_h": (9, 16),
    "sh_z": (1, 8),
}


def _step(name: str, v: int) -> int:
    lo, hi = WINDOWS[name]
    return v + 1 if v + 1 <= hi else v - 1


def _with_shape(bundle, shape):
    b = copy.copy(bundle)
    b.run = dict(bundle.run)
    b.run["shape"] = shape
    return b


def _failing_slots(rec) -> set:
    bad = set()
    for row in rec["per_stage"]:
        bad |= set(row["checked"]) - set(row["equal"])
        bad |= {e["slot"] for e in row["not_checked"]}
    return bad


def _failing_pairs(rec) -> set:
    """(stage, slot) of every slot that stopped matching"""
    bad = set()
    for k, row in enumerate(rec["per_stage"]):
        bad |= {(k, s) for s in set(row["checked"]) - set(row["equal"])}
        bad |= {(k, e["slot"]) for e in row["not_checked"]}
    return bad


TAB_SLOT = 19   # SC_TAB: the slot whose arguments carry the captured lookup rows


def tl4_table_swaps(bundle, index, replay) -> list:
    """[v5, review P-20] **TL-4: one layer reads ANOTHER layer's table.**  For
    the first adjacent stage pair (j, k = j + 1) whose captured lookup tables
    differ (pg_rot1: layers 7 | 8, where both the exp key and the SiLU member
    change), stage k's carried table entry (values AND its digest, so the
    capture's own digest check passes) is replaced by stage j's, one table at
    a time.  Predicted: stage k's SC_TAB slot, and no slot of any other stage,
    stops matching.  The entry is restored before the next run."""
    def caps(st):
        return {i: t for i, t in enumerate(st.doc["arguments"][TAB_SLOT]["tables"])
                if "values" in t}
    pair = None
    for j in range(bundle.blocks - 1):
        a, b = caps(bundle.stages[j]), caps(bundle.stages[j + 1])
        diff = [i for i in a if i in b and a[i].get("sha256") != b[i].get("sha256")]
        if diff:
            pair = (j, j + 1, diff)
            break
    if pair is None:
        return [{"control": "TL-4", "skipped": "no adjacent stage pair carries "
                 "different lookup tables (a one-block run, or equal tables)",
                 "ok": True, "fires": None}]
    j, k, diff = pair
    out = []
    for i in diff:
        tabs = bundle.stages[k].doc["arguments"][TAB_SLOT]["tables"]
        saved = tabs[i]
        tabs[i] = bundle.stages[j].doc["arguments"][TAB_SLOT]["tables"][i]
        try:
            rec = check_terminals(bundle, index, replay=replay)
        finally:
            tabs[i] = saved
        got = _failing_pairs(rec)
        want = {(k, TAB_SLOT)}
        c = {"control": f"TL-4/table-{i}", "perturbation": f"stage {k}'s SC_TAB "
             f"table {i} replaced by stage {j}'s (values and digest)",
             "predicted_failing": sorted(list(x) for x in want),
             "failing": sorted(list(x) for x in got), "fires": not rec["ok"],
             "exactly_as_predicted": got == want}
        c["ok"] = c["fires"] and c["exactly_as_predicted"]
        out.append(c)
    return out


def tl5_run_shape_at_own_stages(bundle, index, replay, shapes_of) -> list:
    """[v17] **TL-5: a stage with its own constants evaluated at the RUN
    shape** (what tools v16 did for every stage).  Predicted: exactly that
    stage's slots that read one of its own constants fail, and no slot of
    any other stage."""
    run_shape = bundle.run["shape"]
    own = [k for k, sh in enumerate(shapes_of) if sh is not run_shape]
    if not own:
        return [{"control": "TL-5", "skipped": "no stage carries its own "
                 "calibration constants (every stage is at the run shape)",
                 "ok": True, "fires": None}]
    out = []
    for k in own:
        keys = [key for key in TRAINED_KEYS if int(shapes_of[k][key]) != int(run_shape[key])]
        stages = list(shapes_of)
        stages[k] = run_shape
        rec = check_terminals(bundle, index, replay=replay, stage_shapes=stages)
        got = _failing_pairs(rec)
        want = {(k, sl) for key in keys for sl in READS[key]}
        c = {"control": f"TL-5/stage-{k}", "perturbation": f"stage {k} evaluated "
             f"at the run shape, not at its own {keys}",
             "predicted_failing": sorted(list(x) for x in want),
             "failing": sorted(list(x) for x in got), "fires": not rec["ok"],
             "exactly_as_predicted": got == want}
        c["ok"] = c["fires"] and c["exactly_as_predicted"]
        out.append(c)
    return out


def tl6_stage_line_refusals(bundle) -> list:
    """[v17] **TL-6: the stage-line reader refuses edited lines**, each by
    its code (`zk60_native_rg_stagecal` SC-1..SC-5), on copies of run.json.
    At a run whose lines carry no own clause, one is ADDED for SC-5 (an
    unbound clause) and the others are named not applicable."""
    run = bundle.run
    if "token_io" in run:
        return [{"control": "TL-6", "skipped": "a token-I/O run: the stage-line "
                 "reader does not apply (tokenblocks' per-block shim)", "ok": True,
                 "fires": None}]
    lines = list(run.get("stage_lines") or [])
    k = next((i for i, ln in enumerate(lines) if SCAL.OWN_CLAUSE.search(ln)), None)
    cases = []
    if k is None:
        if not lines or run["shape"].get("trained_calibration") is not True:
            return [{"control": "TL-6", "skipped": "no stage lines or no trained "
                     "calibration", "ok": True, "fires": None}]
        b = int(run["shape"]["sh_s"])
        v = b + 1 if b + 1 <= WINDOWS["sh_s"][1] else b - 1
        added = lines[-1] + f"; score shift {v} (the layer's own; the run's is {b})"
        cases.append(("TL-6/added-clause", "SC-5", len(lines) - 1, added))
    else:
        ln = lines[k]
        m = SCAL.OWN_CLAUSE.search(ln)
        lab, v, b = m.group(1), int(m.group(2)), int(m.group(3))
        clause = m.group(0)
        cases.append(("TL-6/own-value-edited", "SC-5", k, ln.replace(
            clause, f"; {lab} {v + 1} (the layer's own; the run's is {b})", 1)))
        cases.append(("TL-6/run-value-not-the-shape's", "SC-1", k, ln.replace(
            clause, f"; {lab} {v} (the layer's own; the run's is {b + 1})", 1)))
        cases.append(("TL-6/own-equal-to-run", "SC-2", k, ln.replace(
            clause, f"; {lab} {b} (the layer's own; the run's is {b})", 1)))
        clauses = SCAL.OWN_CLAUSE.findall(ln[SCAL.DATA_ROWS.search(ln).end():])
        if len(clauses) >= 2:
            head = ln[:SCAL.DATA_ROWS.search(ln).end()]
            sw = [clauses[1], clauses[0]] + clauses[2:]
            cases.append(("TL-6/clauses-swapped", "SC-3", k, head + "".join(
                f"; {a} {x} (the layer's own; the run's is {y})" for a, x, y in sw)))
        cases.append(("TL-6/label-mistyped", "SC-4", k, ln.replace(
            clause, clause.replace(lab, lab.upper(), 1), 1)))
    out = []
    for name, code, at, edited in cases:
        r2 = dict(run)
        l2 = list(lines)
        l2[at] = edited
        r2["stage_lines"] = l2
        if code in ("SC-1", "SC-2", "SC-3", "SC-4"):
            # bind the edited lines, so the refusal is the reader's and not the digest's
            dig = SCAL.schedule_digest(r2)
            r2["schedule_digest"] = list(bytes.fromhex(dig["recomputed"]))
        try:
            SCAL.stage_shapes(r2)
            refused, why = False, None
        except ValueError as exc:
            refused, why = True, str(exc)
        ok = refused and why.startswith(code)
        out.append({"control": name, "stage": at, "expected_code": code,
                    "refused": refused, "why": why, "fires": refused, "ok": ok})
    return out


def tl_controls(bundle, index=None, replay=None, only=None) -> dict:
    """`only`: a set of families to run ({"TL-1", "TL-2", "TL-3", "TL-4"}); all
    by default"""
    fam = set(only) if only else {"TL-1", "TL-2", "TL-3", "TL-4", "TL-5", "TL-6"}
    shape = bundle.run["shape"]
    cal = Calibration(shape)
    if not cal.trained:
        return {"skipped": "not a trained-calibration bundle", "ok": False}
    if index is None:
        index, why = plane_index_of(bundle)
        if index is None:
            return {"skipped": f"no plane index: {why}", "ok": False}
    if replay is None:
        replay = RunReplay(bundle).run()
    out = {"what": __doc__.strip().splitlines()[0], "controls": [], "ok": True}

    honest = check_terminals(bundle, index, replay=replay)
    out["honest"] = {"ok": honest["ok"], "slot_checks_equal":
                     honest["slot_checks_equal"],
                     "slot_checks_expected": honest["slot_checks_expected"]}
    if not honest["ok"]:
        out["ok"] = False
        out["why"] = "the honest identity does not hold; no control is meaningful"
        return out

    # [v17] each stage's calibration (the run shape where a stage carries no
    # own constant); TL-1 / TL-2 perturb every stage's shape
    stage_shapes, stage_rec = SCAL.stage_shapes(bundle.run)
    out["stage_calibration"] = stage_rec
    n_st = len(bundle.stages)
    shapes_of = [stage_shapes[k] if k < len(stage_shapes) else shape for k in range(n_st)]

    def _pairs_reading(keys_per_stage):
        return {(k, sl) for k, keys in enumerate(keys_per_stage) for key in keys
                for sl in READS[key]}

    # TL-1: the frozen calibration
    if "TL-1" in fam:
        frozen_shape = {k: v for k, v in shape.items()
                        if k not in TRAINED_KEYS + ("trained_calibration", "d_max")}
        frozen_stages = [{k: v for k, v in sh.items()
                          if k not in TRAINED_KEYS + ("trained_calibration", "d_max")}
                         for sh in shapes_of]
        differs = [k for k in TRAINED_KEYS if FROZEN_CALIBRATION[k] != cal.values[k]]
        differs_at = [[k for k in TRAINED_KEYS if FROZEN_CALIBRATION[k] != int(sh[k])]
                      for sh in shapes_of]
        want = set().union(*(READS[k] for kk in differs_at for k in kk)) if any(differs_at) else set()
        want_pairs = _pairs_reading(differs_at)
        rec = check_terminals(_with_shape(bundle, frozen_shape), index, replay=replay,
                              stage_shapes=frozen_stages)
        got, got_pairs = _failing_slots(rec), _failing_pairs(rec)
        c = {"control": "TL-1", "perturbation": "the frozen calibration "
             "(trained keys removed) at every stage", "constants_that_differ": differs,
             "constants_that_differ_per_stage": differs_at,
             "predicted_failing_slots": sorted(want), "failing_slots": sorted(got),
             "predicted_failing_pairs": sorted(list(x) for x in want_pairs),
             "failing_pairs": sorted(list(x) for x in got_pairs),
             "fires": not rec["ok"],
             "exactly_as_predicted": got == want and got_pairs == want_pairs}
        c["ok"] = c["fires"] and c["exactly_as_predicted"]
        out["controls"].append(c)

    # TL-2: each constant moved by one step inside its class, at every stage
    if "TL-2" in fam:
        for name in TRAINED_KEYS:
            moved = dict(shape)
            moved[name] = _step(name, int(shape[name]))
            moved_stages = [dict(sh, **{name: _step(name, int(sh[name]))}) for sh in shapes_of]
            want_pairs = _pairs_reading([[name]] * n_st)
            rec = check_terminals(_with_shape(bundle, moved), index, replay=replay,
                                  stage_shapes=moved_stages)
            got, got_pairs = _failing_slots(rec), _failing_pairs(rec)
            per_stage = sorted({(sh[name], ms[name]) for sh, ms in zip(shapes_of, moved_stages)})
            c = {"control": f"TL-2/{name}", "perturbation":
                 f"{name} {shape[name]} -> {moved[name]}" + (
                     "" if len(per_stage) == 1 else
                     f" (per stage {', '.join(f'{a} -> {b}' for a, b in per_stage)})"),
                 "predicted_failing_slots": sorted(READS[name]),
                 "failing_slots": sorted(got),
                 "predicted_failing_pairs": sorted(list(x) for x in want_pairs),
                 "failing_pairs": sorted(list(x) for x in got_pairs),
                 "fires": not rec["ok"],
                 "exactly_as_predicted": got == READS[name] and got_pairs == want_pairs}
            c["ok"] = c["fires"] and c["exactly_as_predicted"]
            out["controls"].append(c)

    # TL-3: the loader's refusals
    if "TL-3" in fam:
        bad_shapes = {
            "TL-3/keys-without-flag": {k: v for k, v in shape.items()
                                       if k != "trained_calibration"},
            "TL-3/flag-without-a-key": {k: v for k, v in shape.items()
                                        if k != "norm_ceps"},
            "TL-3/flag-false-with-keys": {**shape, "trained_calibration": False},
        }
        for name, sh in bad_shapes.items():
            try:
                Calibration(sh)
                refused, why = False, None
            except ValueError as exc:
                refused, why = True, str(exc)
            out["controls"].append({"control": name, "refused": refused,
                                    "why": why, "ok": refused})
    # TL-4 (v5, review P-20): one layer reads another layer's table
    if "TL-4" in fam:
        out["controls"] += tl4_table_swaps(bundle, index, replay)
    # TL-5 / TL-6 (v17): the per-stage calibration
    if "TL-5" in fam:
        out["controls"] += tl5_run_shape_at_own_stages(bundle, index, replay, shapes_of)
    if "TL-6" in fam:
        out["controls"] += tl6_stage_line_refusals(bundle)
    live = [c for c in out["controls"] if not c.get("skipped")]
    out["fired"] = sum(1 for c in live if c["ok"])
    out["of"] = len(live)
    out["skipped_by_name"] = [c["control"] for c in out["controls"] if c.get("skipped")]
    # [v5] over the controls that ran, never over none
    out["ok"] = bool(live) and all(c["ok"] for c in live)
    out["privacy_property_established"] = False
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--bundle", required=True)
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--name", default="tl-controls")
    ap.add_argument("--only", default="", help="[v5] comma list of families "
                    "(TL-1,TL-2,TL-3,TL-4); all by default")
    a = ap.parse_args(argv)
    b = load_bundle(a.bundle)
    only = {x.strip() for x in a.only.split(",") if x.strip()} or None
    rec = tl_controls(b, only=only)
    rec["families_run"] = sorted(only) if only else ["TL-1", "TL-2", "TL-3", "TL-4"]
    rec["bundle"] = b.name
    os.makedirs(a.evidence, exist_ok=True)
    path = os.path.join(a.evidence, a.name + ".json")
    with open(path, "w") as fh:
        json.dump(rec, fh, indent=1, sort_keys=True)
        fh.write("\n")
    for c in rec["controls"]:
        print(f"{c['control']:28s} ok={c['ok']}  "
              + (f"failing={c.get('failing_slots')} predicted="
                 f"{c.get('predicted_failing_slots')}" if 'failing_slots' in c
                 else f"failing={c.get('failing')} predicted={c.get('predicted_failing')}"
                 if 'failing' in c else f"refused={c.get('refused')} {c.get('skipped') or ''}"))
    print(f"record: {path}  {rec.get('fired')} of {rec.get('of')} fire  ok={rec['ok']}")
    return 0 if rec["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())

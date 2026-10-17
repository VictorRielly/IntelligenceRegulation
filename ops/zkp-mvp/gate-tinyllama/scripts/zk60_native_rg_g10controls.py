#!/usr/bin/env python3
"""[TINYLLAMA PORT, tools v4, finding G-10] The negative controls of the run
integrity pass's EXTERNAL-ENDPOINT check.

    python3 zk60_native_rg_g10controls.py --bundle <run bundle> \
        [--other <a second run bundle of the same profile>] \
        [--legacy <scripts dir of the v3 tools>] --evidence <dir> --name <name>

G-10 (found 2026-10-17 by control C5 on a one-block trained run): the run
integrity pass compared every internal boundary's committed root with the root
opened one stage later, and never compared the two external-endpoint openings
with `run.json["external_endpoints"]`; the standalone-block reader does.  Tools
v4 add that comparison (`zk60_native_rg_bundle.integrity`).  A check that
cannot fire is not a check, so each control below perturbs ONE thing in memory
and requires the v4 pass to refuse it WITH a finding that names G-10:

  G10-1  stage 0's Input (external-endpoint) opening root, one byte flipped;
  G10-2  the last stage's Output opening root, one byte flipped;
  G10-3  run.json's declared `external_endpoints.input_root`, one byte flipped
         (the declared side, not the opened side);
  G10-4  (with --other) stage 0 replaced by the OTHER run's stage 0 -- control
         C5's swap, on the stage that carries the Input endpoint.  At L = 1
         this is exactly the case G-10 was found in.

Every control is also run through the v3 integrity pass (`--legacy`, loaded
from the frozen copy under another module name, every module it imports being
byte-identical in v3 and v4) to show the failing-first state: where v3 accepts
the perturbation, the record says so.  Nothing on disk is written except the
record; every perturbation is undone (and checked undone) before the next.

NOTHING HERE IS A PRIVACY STATEMENT.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

from zk60_native_rg_block import load_bundle  # noqa: E402
from zk60_native_rg_bundle import Stage, integrity  # noqa: E402

MARK = "(finding G-10)"


def _legacy_integrity(legacy_dir):
    """`integrity` of the v3 bundle module, loaded under another name.  Its
    imports (`zk60_native_rg_arrays`, `zk60_native_rg_hashrule`) resolve to
    the modules already loaded, which v4 did not change (checked by digest)."""
    if not legacy_dir:
        return None, None
    for name in ("zk60_native_rg_arrays.py", "zk60_native_rg_hashrule.py"):
        with open(os.path.join(legacy_dir, name), "rb") as a, \
                open(os.path.join(HERE, name), "rb") as b:
            if a.read() != b.read():
                raise SystemExit(f"{name} differs between {legacy_dir} and {HERE}: "
                                 "the legacy integrity cannot share it")
    path = os.path.join(legacy_dir, "zk60_native_rg_bundle.py")
    spec = importlib.util.spec_from_file_location("legacy_zk60_native_rg_bundle", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    with open(path, "rb") as fh:
        digest = hashlib.sha256(fh.read()).hexdigest()
    return mod.integrity, digest


def _flip(root):
    out = list(root)
    out[0] ^= 0x01
    return out


def _verdicts(bundle, legacy):
    new = integrity(bundle)
    g10 = [x for x in new["findings"] if MARK in x]
    out = {
        "v4_integrity_ok": new["ok"],
        "v4_findings_naming_G10": g10,
        "v4_findings_total": len(new["findings"]),
        "v4_first_finding": (new["findings"] or ["<none>"])[0],
    }
    if legacy is not None:
        try:
            old = legacy(bundle)
            out["v3_integrity_ok"] = old["ok"]
            out["v3_first_finding"] = (old["findings"] or ["<none>"])[0]
        except Exception as e:  # noqa: BLE001 -- the old pass may crash
            out["v3_integrity_ok"] = None
            out["v3_raised"] = f"{type(e).__name__}: {e}"[:200]
    return out


def _snapshot(bundle):
    """the fields any control touches, to check they are restored"""
    return json.dumps({
        "in": list(bundle.stages[0].role("Input")["commitment"]["root"]),
        "out": list(bundle.stages[-1].role("Output")["commitment"]["root"]),
        "ee": bundle.run["external_endpoints"],
        "stage0": bundle.stages[0].sha256,
    }, sort_keys=True)


def g10_controls(bundle, other=None, legacy=None) -> dict:
    before = _snapshot(bundle)
    out = {"bundle": bundle.name, "blocks": bundle.blocks}
    honest = _verdicts(bundle, legacy)
    out["honest"] = honest
    honest_ok = honest["v4_integrity_ok"] and not honest["v4_findings_naming_G10"]

    def fires(v):
        return (not v["v4_integrity_ok"]) and bool(v["v4_findings_naming_G10"])

    controls = []
    # G10-1 / G10-2: the OPENED side
    for name, idx, role_name, key in (
            ("G10-1_stage0_input_opening_root_flipped", 0, "Input", "input_root"),
            ("G10-2_last_stage_output_opening_root_flipped", bundle.blocks - 1,
             "Output", "output_root")):
        r = bundle.stages[idx].role(role_name)
        saved = r["commitment"]["root"]
        r["commitment"]["root"] = _flip(saved)
        try:
            v = _verdicts(bundle, legacy)
        finally:
            r["commitment"]["root"] = saved
        controls.append({
            "control": name,
            "what": f"{bundle.stages[idx].name} {role_name}: the opened root's first "
            f"byte flipped; run.json's {key} untouched",
            "perturbed": v,
            "fires": fires(v),
        })
    # G10-3: the DECLARED side
    ee = bundle.run["external_endpoints"]
    saved_root = copy.deepcopy(ee["input_root"])
    ee["input_root"] = _flip(saved_root)
    try:
        v = _verdicts(bundle, legacy)
    finally:
        ee["input_root"] = saved_root      # in place: the same dict object
    controls.append({
        "control": "G10-3_declared_input_root_flipped",
        "what": "run.json's external_endpoints.input_root: first byte flipped; "
        "the stage's opening and the policy bytes untouched",
        "perturbed": v,
        "fires": fires(v),
    })
    # [v5, review P-21] G10-5..7: the comparisons v5 added, and a missing key
    for name, what, key, val in (
            ("G10-5_declared_data_rows_moved", "run.json's external_endpoints."
             "data_rows moved by one", "data_rows", None),
            ("G10-6_declared_scales_not_zero", "run.json's external_endpoints."
             "input_scale set to 1", "input_scale", 1),
            ("G10-7_declared_log_n_moved", "run.json's external_endpoints.log_n "
             "moved by one", "log_n", None)):
        saved_v = ee[key]
        ee[key] = (saved_v + 1) if val is None else val
        try:
            v = _verdicts(bundle, legacy)
        finally:
            ee[key] = saved_v
        controls.append({"control": name, "what": what, "perturbed": v,
                         "fires": fires(v)})
    saved_rows = ee.pop("rows")
    try:
        v = _verdicts(bundle, legacy)
    except Exception as e:  # noqa: BLE001 -- a crash is NOT a named refusal
        v = {"v4_integrity_ok": True, "v4_findings_naming_G10": [],
             "raised": f"{type(e).__name__}: {e}"[:200]}
    finally:
        ee["rows"] = saved_rows
    controls.append({"control": "G10-8_declared_rows_member_missing",
                     "what": "run.json's external_endpoints without its rows "
                     "member: refused by NAME, not by an exception",
                     "perturbed": v, "fires": fires(v)})
    # G10-4: control C5's swap, on the stage that carries the Input endpoint
    if other is not None:
        saved_stage = bundle.stages[0]
        bundle.stages[0] = Stage(other.stages[0].path, 0, bundle.blocks,
                                 schema=other.schema, store=other.store,
                                 refusals=[])
        try:
            v = _verdicts(bundle, legacy)
        finally:
            bundle.stages[0] = saved_stage
        controls.append({
            "control": "G10-4_stage0_swapped_for_the_other_runs_stage0",
            "what": f"stage 0 of {bundle.name} replaced by stage 0 of {other.name} "
            "(control C5's swap, on the stage that opens the Input endpoint)",
            "perturbed": v,
            "fires": fires(v),
        })
    else:
        controls.append({"control": "G10-4_stage0_swapped_for_the_other_runs_stage0",
                         "skipped": "no --other bundle", "fires": None})
    restored = _snapshot(bundle) == before
    applicable = [c for c in controls if c["fires"] is not None]
    out.update({
        "controls": controls,
        "honest_accepted_without_a_G10_finding": honest_ok,
        "all_fire": all(c["fires"] for c in applicable),
        "applicable": len(applicable),
        "v3_accepted": [c["control"] for c in applicable
                        if c["perturbed"].get("v3_integrity_ok") is True],
        "every_perturbation_undone": restored,
        "nothing_written": "every perturbation is in memory; no captured byte "
        "is touched",
    })
    out["ok"] = bool(honest_ok and out["all_fire"] and restored and applicable)
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--bundle", required=True)
    ap.add_argument("--other")
    ap.add_argument("--legacy", help="scripts directory of the v3 tools")
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--name", required=True)
    a = ap.parse_args(argv)
    bundle = load_bundle(a.bundle)
    if getattr(bundle, "standalone", False):
        raise SystemExit("a standalone block bundle: its reader already compares "
                         "the endpoint roots (block_integrity); G-10 is about runs")
    other = load_bundle(a.other) if a.other else None
    legacy, legacy_sha = _legacy_integrity(a.legacy)
    rec = {
        "what": "negative controls of the run integrity pass's external-endpoint "
        "check (finding G-10, tools v4)",
        "privacy_property_established": False,
        "privacy_acceptance": False,
        "tool_sha256": {
            n: hashlib.sha256(open(os.path.join(HERE, n), "rb").read()).hexdigest()
            for n in ("zk60_native_rg_g10controls.py", "zk60_native_rg_bundle.py")
        },
        "legacy_integrity_sha256": legacy_sha,
        "other_bundle": other.name if other is not None else None,
        **g10_controls(bundle, other=other, legacy=legacy),
    }
    os.makedirs(a.evidence, exist_ok=True)
    path = os.path.join(a.evidence, f"{a.name}.json")
    with open(path, "w") as fh:
        json.dump(rec, fh, indent=1, sort_keys=True)
        fh.write("\n")
    print(f"record: {path}   ok={rec['ok']}   fire "
          f"{sum(1 for c in rec['controls'] if c['fires'])} of {rec['applicable']}"
          f"   v3 accepted {rec['v3_accepted']}")
    return 0 if rec["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""[GATE ROUND 14, tools v17, 2026-10-20] The G-7 terminal surjection
(`EV/g7/ts_trained.py`, frozen, digest checked by
`zk60_native_rg_tokents.load_ts`) on EVERY commitment of a native R9 DD run
capture (D30): each stage's A (which now carries the dictionary's planes
P_dict, its limbs and M_dd, and slot 23's reserved pairs), H (with the tuple
helper and the dictionary's table helper inside the one value-0 sum claim),
and the IO commitments, at the bundle's own row width.

    python3 zk60_native_rg_ddts.py --bundle <DD capture> --evidence <dir> --name <name>

Per role: groups, surjective groups, disclosed Fp per group, joint components
(groups sharing a non-data row, i.e. H's zero-sum pair), and the PCS census.

CONTROLS, each predicted:
  the review's own (C1 / C2 / C3 / C6 / C8 / G7-D1..D3) on the first
      two-member group of stage 0's A, exactly as ts_trained runs them;
  DS-1  the group holding SLOT 23's A claims (the dictionary planes and
        A_SUM, located by the claim numbers the capture's slot-23 tables
        carry) with one claim's reserved pair removed: it must disclose,
        the honest group must not;
  DS-2  the group holding SLOT 17's H_STUPLE claim (the tuple helper),
        likewise, when that claim is outside the zero-sum rows.

NOTHING HERE ESTABLISHES A PRIVACY PROPERTY.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import resource
import sys
import time

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import zk60_native_rg_tokents as TSW  # noqa: E402

SC_SZC, SC_DD = 17, 23


def _sha(p):
    with open(p, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


def load_block_roles(TT, d):
    run = json.load(open(os.path.join(d, "run.json")))
    assert run["field_modulus"] == TT.P and run["extension_nonresidue"] == 7
    arr = TT.Arrays(os.path.join(d, "arrays.bin"))
    files = sorted(f for f in os.listdir(d) if f.startswith("stage-") and f.endswith(".json"))
    out, docs = [], []
    for k, sf in enumerate(files):
        st = json.load(open(os.path.join(d, sf)))
        docs.append(st)
        cap = {"proof_sha256": st["segment_sha256"], "profile": run["profile"], "roles": []}
        for r in st["roles"]:
            pr = r["params"]
            TSW.set_width(TT, pr["log_cols"], pr["inv_rate"])
            rr = arr.resolve({kk: r[kk] for kk in TT.KEEP if kk in r})
            cap["roles"].append(rr)
            out.append({"stage": k, "stage_kind": "BLOCK", "file": sf, "profile": run["profile"],
                        "log_cols": pr["log_cols"], "inv_rate": pr["inv_rate"],
                        "role": TT.T.Role(cap, rr)})
    return out, docs, arr.checked


def _claims_of_slot(doc, slot, role):
    return sorted({t["claim"] for t in doc["arguments"][slot]["tables"]
                   if t["kind"] == "private" and t.get("role") == role})


def _group_with(role, claims):
    """the index of the group that holds one of `claims` (the role's own
    claim numbering), and that claim's index in the role's claim list"""
    want = set(claims)
    for gi, g in enumerate(role.groups):
        for c in g:
            if c in want:
                return gi, c
    return None, None


def pair_removed(TT, ent, gi, c0):
    role = ent["role"]
    TSW.set_width(TT, ent["log_cols"], ent["inv_rate"])
    small = len({i for i in role.rws[c0] if role.kind[i] == "data"}) <= 4
    honest = TT.analyse_group(role, gi, None, also_original=small)
    rw0 = {i: v for i, v in role.rws[c0].items() if role.kind[i] == "data"}
    pert = TT.analyse_group(role, gi, {"rws": {c0: rw0}}, also_original=small)
    return {"stage": ent["stage"], "role": role.name, "group": gi, "claim": c0,
            "group_size": len(role.groups[gi]),
            "touches_zero_sum_rows": bool(set(role.rws[c0]) & set(role.u_rows)),
            "honest_disclosed_Fp": honest["disclosed_Fp"], "pair_removed_disclosed_Fp": pert["disclosed_Fp"],
            "fires": honest["disclosed_Fp"] == 0 and pert["disclosed_Fp"] > 0}


def run(bundle_dir, controls=True):
    TT = TSW.load_ts()
    t0 = time.time()
    ents, docs, nchk = load_block_roles(TT, bundle_dir)
    rec = {"what": "the G-7 terminal surjection on every commitment of a native R9 DD run capture; "
                   "NOT a privacy result",
           "privacy_acceptance": False, "privacy_property_established": False,
           "bundle": os.path.basename(bundle_dir), "arrays_checked": nchk,
           "ts_trained_sha256": TSW.TS_TRAINED_PIN, "stage0": TT.T.stage0_selftest(), "roles": []}
    for ent in ents:
        r = TSW.analyse(TT, ent)
        rec["roles"].append(r)
        print(f"{ent['file']} {r['role']}: groups {r['groups']}, surjective {r['surjective_groups']}, "
              f"disclosed {r['total_disclosed_Fp']} {r['disclosed_by_group']}, joint "
              f"{[(j['groups'], j['disclosed_Fp']) for j in r['joint_components']]} ({time.time() - t0:.1f} s)",
              flush=True)
    if controls:
        rec["controls"] = {}
        a0 = next(e for e in ents if e["stage"] == 0 and e["role"].name.startswith("A"))
        TSW.set_width(TT, a0["log_cols"], a0["inv_rate"])
        crow = TT.controls(a0["role"])
        fires = {r["control"]: r["fires"] for r in crow}
        want = {"honest reference": False, "C1 shared reserved pair": True, "C2 cm = 0 (pair removed)": True}
        rec["controls"]["review_controls_on_stage0_A"] = {"rows": crow, "fires": fires,
                                                          "ok": all(fires.get(k) is v for k, v in want.items())}
        ds = []
        for e in ents:
            nm = e["role"].name
            doc = docs[e["stage"]]
            if nm.startswith("A"):
                gi, c0 = _group_with(e["role"], _claims_of_slot(doc, SC_DD, "A"))
                if gi is None:
                    ds.append({"control": "DS-1", "stage": e["stage"], "not_found": "no group holds slot 23's A claims"})
                else:
                    ds.append({"control": "DS-1", **pair_removed(TT, e, gi, c0)})
            elif nm.startswith("H"):
                gi, c0 = _group_with(e["role"], _claims_of_slot(doc, SC_SZC, "H")[-1:])
                if gi is None:
                    ds.append({"control": "DS-2", "stage": e["stage"], "not_found": "no group holds slot 17's last H claim"})
                    continue
                row = {"control": "DS-2", **pair_removed(TT, e, gi, c0)}
                if row["touches_zero_sum_rows"]:
                    row["not_applicable"] = "the tuple helper's claim touches the zero-sum rows"
                    row["fires"] = None
                ds.append(row)
        live = [x for x in ds if x.get("fires") is not None and "not_found" not in x]
        rec["controls"]["DS_dd_groups_pair_removed"] = {
            "rows": ds, "ok": bool([x for x in live if x["control"] == "DS-1"]) and all(x["fires"] for x in live)}
        rec["controls"]["ok"] = all(v.get("ok") for v in rec["controls"].values() if isinstance(v, dict))
    rec["summary"] = {f"stage{r['stage']}:{r['role']}": {
        "groups": r["groups"], "surjective": r["surjective_groups"],
        "disclosed_Fp": r["total_disclosed_Fp"], "disclosed_by_group": r["disclosed_by_group"],
        "joint": [(j["groups"], j["disclosed_Fp"]) for j in r["joint_components"]],
        "census_identical_claims": r["census"].get("identical_claims"),
        "census_equal_published_values": r["census"].get("equal_published_values")}
        for r in rec["roles"]}
    rec["seconds"] = round(time.time() - t0, 1)
    rec["peak_rss_mb"] = round(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024)
    rec["tool_sha256"] = {os.path.basename(__file__): _sha(os.path.abspath(__file__)),
                          os.path.basename(TSW.__file__): _sha(TSW.__file__)}
    return rec


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--bundle", required=True)
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--name", required=True)
    ap.add_argument("--no-controls", action="store_true")
    a = ap.parse_args(argv)
    rec = run(a.bundle, controls=not a.no_controls)
    os.makedirs(a.evidence, exist_ok=True)
    out = os.path.join(a.evidence, a.name + ".json")
    with open(out, "w") as fh:
        json.dump(rec, fh, indent=1, default=str)
    print(json.dumps(rec["summary"], indent=1, default=str))
    print(f"record: {out}")
    return 0 if rec.get("controls", {}).get("ok", True) else 1


if __name__ == "__main__":
    raise SystemExit(main())

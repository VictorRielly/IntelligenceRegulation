#!/usr/bin/env python3
"""[gate round 22, item 3, 2026-10-29] The TERMINAL SURJECTION (G-7's computation, `EV/g7/ts_trained.py`
with its digest pin) on a CLASSIFIER capture (schema `hashline-native-capture/7-classify-run`): the stage
IN-C roles (A-in, H-in, E-token-in), the stage OUT-C roles (A-out, H-out, B-out) and the roles (A, H, Input) of
chosen R13 block stages; control TS-1 on EVERY role with a singleton site-pair group (one claim's reserved
pair removed: that group must disclose, the honest one must not); and the review's controls (C1 shared
reserved pair, C2 cm = 0) on a block A.  NOT a privacy result.

    python3 zk60_r22_classts.py --bundle <capture> --evidence <dir> --name <name> [--block-stages 1,2]
                                [--skip-classifier]

Imported read-only from frozen v23: `zk60_native_rg_tokents` (`load_ts`, `load_token_roles`, `analyse`,
`set_width`), whose loader reads a stage's roles with their OWN `params` (log_cols, inv_rate) and resolves the
arrays from `arrays.bin` against their SHA-256 names, so the row width is set per role (IN-C / OUT-C 2^12, the
token endpoint 2^8 with 2^11 encoded columns, block and boundary roles 2^14).
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
FROZEN = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/frozen_v23/scripts"
if FROZEN not in sys.path:
    sys.path.insert(0, FROZEN)
import zk60_native_rg_tokents as TS  # noqa: E402


def _sha(p):
    with open(p, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


def mmap_arrays(TT):
    """`ts_trained.Arrays` reads the WHOLE `arrays.bin` into memory (2.25 GB at the real values capture); this
    process gives it an mmap instead, with the same per-reference SHA-256 check and the same parsing (only the
    referenced slices become resident: O20-1)"""
    import mmap

    class MmapArrays(TT.Arrays):
        def __init__(self, path):
            self._fh = open(path, "rb")
            self.mm = mmap.mmap(self._fh.fileno(), 0, access=mmap.ACCESS_READ)
            self.checked = 0
    TT.Arrays = MmapArrays


def ts1(TT, ent):
    TS.set_width(TT, ent["log_cols"], ent["inv_rate"])
    role = ent["role"]
    gi = next((i for i, g in enumerate(role.groups)
               if len(g) == 1 and not set(role.rws[g[0]]) & set(role.u_rows)), None)
    if gi is None:
        return {"role": role.name, "stage": ent["stage"], "not_applicable": "no singleton site-pair group"}
    c0 = role.groups[gi][0]
    small = len({i for i in role.rws[c0] if role.kind[i] == "data"}) <= 4
    honest = TT.analyse_group(role, gi, None, also_original=small)
    rw0 = {i: v for i, v in role.rws[c0].items() if role.kind[i] == "data"}
    pert = TT.analyse_group(role, gi, {"rws": {c0: rw0}}, also_original=small)
    return {"role": role.name, "stage": ent["stage"], "stage_kind": ent["stage_kind"], "group": gi,
            "honest_disclosed_Fp": honest["disclosed_Fp"], "pair_removed_disclosed_Fp": pert["disclosed_Fp"],
            "fires": honest["disclosed_Fp"] == 0 and pert["disclosed_Fp"] > 0}


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--bundle", required=True)
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--name", required=True)
    ap.add_argument("--block-stages", default="")
    ap.add_argument("--skip-classifier", action="store_true")
    a = ap.parse_args(argv)
    TT = TS.load_ts()
    mmap_arrays(TT)
    t0 = time.time()
    run = json.load(open(os.path.join(a.bundle, "run.json")))
    assert run["schema"] == "hashline-native-capture/7-classify-run", run["schema"]
    n_st = run["stages"]
    bs = [int(x) for x in a.block_stages.split(",") if x]
    idx = ([] if a.skip_classifier else [0, n_st - 1]) + [k for k in bs if 0 < k < n_st - 1]
    ents, nchk = TS.load_token_roles(TT, a.bundle, idx)
    rec = {"what": "gate round 22 item 3: the G-7 terminal surjection on a classifier capture's IN-C / OUT-C roles and "
                   "R13 block roles, TS-1 on every role, the review controls on a block A; NOT a privacy result",
           "privacy_acceptance": False, "bundle": os.path.basename(a.bundle), "profile": run["profile"],
           "stages_read": idx, "arrays_checked": nchk, "ts_trained_sha256": TS.TS_TRAINED_PIN,
           "stage0": TT.T.stage0_selftest(), "roles": [], "controls": {}}
    for ent in ents:
        r = TS.analyse(TT, ent)
        r["width_log_cols"], r["inv_rate"] = ent["log_cols"], ent["inv_rate"]
        rec["roles"].append(r)
        print(f"{ent['file']} {ent['stage_kind']} {r['role']}: groups {r['groups']}, surjective {r['surjective_groups']}, "
              f"disclosed {r['total_disclosed_Fp']} {r['disclosed_by_group']}, joint "
              f"{[(j['groups'], j['disclosed_Fp']) for j in r['joint_components']]} ({time.time() - t0:.1f} s)",
              flush=True)
    rows = [ts1(TT, e) for e in ents]
    live = [r for r in rows if "fires" in r]
    rec["controls"]["TS_1_pair_removed_every_role"] = {"rows": rows, "fired": sum(1 for r in live if r["fires"]),
                                                       "live": len(live), "ok": bool(live) and all(r["fires"] for r in live)}
    print(f"TS-1: {rec['controls']['TS_1_pair_removed_every_role']['fired']}/{len(live)} fire "
          f"({time.time() - t0:.1f} s)", flush=True)
    blk = next((e for e in ents if e["stage_kind"] == "BLOCK" and any(len(g) == 2 for g in e["role"].groups)), None)
    if blk is not None:
        TS.set_width(TT, blk["log_cols"], blk["inv_rate"])
        crow = TT.controls(blk["role"])
        fires = {r["control"]: r["fires"] for r in crow}
        want = {"honest reference": False, "C1 shared reserved pair": True, "C2 cm = 0 (pair removed)": True}
        rec["controls"]["review_controls_on_block_A"] = {"role": blk["role"].name, "stage": blk["stage"], "rows": crow,
                                                         "fires": fires,
                                                         "ok": all(fires.get(kk) is v for kk, v in want.items())}
    rec["controls"]["ok"] = all(v.get("ok") for v in rec["controls"].values() if isinstance(v, dict))
    # expectation: every A / boundary / endpoint role onto with 0 disclosed; every H discloses exactly its
    # declared zero-sum pair (2 Fp) in one joint component
    exp_ok = []
    for r in rec["roles"]:
        is_h = r["role"].startswith("H")
        want = 2 if is_h else 0
        exp_ok.append({"stage": r["stage"], "role": r["role"], "disclosed_Fp": r["total_disclosed_Fp"], "expected": want,
                       "ok": r["total_disclosed_Fp"] == want and r["annihilator_kills_blinding"]})
    rec["expectation"] = exp_ok
    rec["summary"] = {f"{r['stage']}:{r['stage_kind']}:{r['role']}": {
        "width": r["width"], "rows": r["rows"], "groups": r["groups"], "surjective": r["surjective_groups"],
        "disclosed_Fp": r["total_disclosed_Fp"], "joint": [(j["groups"], j["disclosed_Fp"]) for j in r["joint_components"]],
        "census_identical_claims": r["census"].get("identical_claims"),
        "census_equal_published_values": r["census"].get("equal_published_values")} for r in rec["roles"]}
    rec["ok"] = bool(all(x["ok"] for x in exp_ok) and rec["controls"]["ok"])
    rec["status"] = "PASS" if rec["ok"] else "NOT-OK"
    rec["seconds"] = round(time.time() - t0, 1)
    rec["peak_rss_mb"] = round(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024)
    rec["tool_sha256"] = {os.path.basename(p): _sha(p) for p in (os.path.abspath(__file__), TS.__file__)}
    os.makedirs(a.evidence, exist_ok=True)
    path = os.path.join(a.evidence, f"{a.name}.json")
    with open(path, "w") as fh:
        json.dump(rec, fh, indent=1, sort_keys=True, default=str)
        fh.write("\n")
    print(json.dumps(rec["summary"], indent=1, default=str))
    print(f"record: {path}  status {rec['status']}")
    return 0 if rec["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())

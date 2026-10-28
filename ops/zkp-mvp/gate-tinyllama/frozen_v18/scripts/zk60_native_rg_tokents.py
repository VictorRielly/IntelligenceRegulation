#!/usr/bin/env python3
"""[GATE ROUND 10, tools v12, 2026-10-20] The TERMINAL SURJECTION (the
G-7 computation of `docs/zkmatrix-poc/ZK60_TERMINAL_SURJECTION_REVIEW.md`,
as the gate's G-7 helper ran it on R7's block stage files) on the token-I/O
stages' commitments: stage IN's A_in, H_in and the input token endpoint;
stage OUT's A_out, H_out, B_out and the output token endpoint; and,
optionally, block stages inside the same token capture.

    python3 zk60_native_rg_tokents.py --bundle <token capture> --evidence <dir> --name <name> \
        [--block-stages 1,2] [--controls]

NOTHING HERE IS A PRIVACY RESULT OR A PRIVACY ACCEPTANCE.

What it reuses, unchanged: `EV/g7/ts_trained.py` (the G-7 helper's restated
stage 2 at width N: per-group system, the null-space "disclosed", the
connected components for groups sharing a non-data row, the PCS census and
the controls C1 / C2 / C3 / C6 / C8 / G7-D1 / D2 / D3), which in turn
imports the frozen review scripts with their digests checked.  Its digest
is checked here before import.

What it adds: a loader for the token capture (schema
`hashline-native-capture/6-token-run`, arrays resolved from `arrays.bin` and
checked against their SHA-256 names), and the ROW WIDTH set PER ROLE before
the role is built: a stage commitment at 2^12 (B_in / B_out at the block's
boundary width, 2^13 at 8B), a token endpoint at 2^8 with 2^11 encoded
columns.  The helper's own width switch is the same three assignments
(`ts_trained.fidelity`).

Failing-first: the controls run on a token role (A_out) and must fire as
the review predicts (C1 shared pair, C2 cm = 0 and G7-D3 short or
disclosing; C3 / C6 / C8 / G7-D1 not).
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
EV = "/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017"
TS_TRAINED = os.path.join(EV, "g7", "ts_trained.py")
TS_TRAINED_PIN = "d6f6cf93ff1d5ad0dad6cb75671145b4e53bdd03be479841a72a0f2ae281f8bc"


def _sha(p):
    with open(p, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


def load_ts():
    got = _sha(TS_TRAINED)
    if got != TS_TRAINED_PIN:
        raise SystemExit(f"EV/g7/ts_trained.py moved: {got}")
    import importlib.util
    spec = importlib.util.spec_from_file_location("ts_trained_g7", TS_TRAINED)
    mod = importlib.util.module_from_spec(spec)
    argv = sys.argv
    sys.argv = [TS_TRAINED]
    try:
        spec.loader.exec_module(mod)
    finally:
        sys.argv = argv
    return mod


def set_width(TT, log_cols, inv_rate):
    n = 1 << log_cols
    TT.T.N_COLS, TT.T.LOG_COLS, TT.T.ENC_COLS = n, log_cols, n * inv_rate
    TT.N = n


def load_token_roles(TT, d, stage_indices):
    run = json.load(open(os.path.join(d, "run.json")))
    assert run["field_modulus"] == TT.P and run["extension_nonresidue"] == 7
    arr = TT.Arrays(os.path.join(d, "arrays.bin"))
    files = sorted(f for f in os.listdir(d) if f.startswith("stage-") and f.endswith(".json"))
    out = []
    for k in stage_indices:
        sf = files[k]
        st = json.load(open(os.path.join(d, sf)))
        cap = {"proof_sha256": st["segment_sha256"], "profile": run["profile"], "roles": []}
        for r in st["roles"]:
            pr = r["params"]
            set_width(TT, pr["log_cols"], pr["inv_rate"])
            rr = arr.resolve({kk: r[kk] for kk in TT.KEEP if kk in r})
            cap["roles"].append(rr)
            out.append({"stage": k, "stage_kind": st["stage_kind"], "file": sf, "profile": run["profile"],
                        "log_cols": pr["log_cols"], "inv_rate": pr["inv_rate"],
                        "role": TT.T.Role(cap, rr)})
    return out, arr.checked


def analyse(TT, ent):
    set_width(TT, ent["log_cols"], ent["inv_rate"])
    role = ent["role"]
    s1 = TT.T.stage1_structure([(ent["file"], ent["profile"], [role])])
    per = []
    for gi in range(len(role.groups)):
        small = len(role.groups[gi]) <= 2 and len(
            {i for c_ in role.groups[gi] for i in role.rws[c_] if role.kind[i] == "data"}) <= 4
        per.append(TT.analyse_group(role, gi, also_original=small))
    comps = TT.components(role)
    joint = [TT.analyse_component(role, gs) for gs in comps if len(gs) > 1]
    census = TT.pcs_census(role)
    return {
        "stage": ent["stage"], "stage_kind": ent["stage_kind"], "role": role.name,
        "width": 1 << ent["log_cols"], "rows": role.rows, "groups": len(per),
        "stage1": s1,
        "surjective_groups": sum(1 for g in per if g["surjective_onto_consistency_subspace"]),
        "short_groups": [i for i, g in enumerate(per) if not g["surjective_onto_consistency_subspace"]],
        "annihilator_kills_blinding": all(g["annihilator_kills_all_blinding_generators"] for g in per),
        "annihilator_kills_data": all(g["annihilator_kills_all_data_generators"] for g in per),
        "disclosed_by_group": {str(i): g["disclosed_Fp"] for i, g in enumerate(per) if g["disclosed_Fp"]},
        "total_disclosed_Fp": sum(g["disclosed_Fp"] for g in per),
        "original_form_checked": [(i, g["original_form_agrees"]) for i, g in enumerate(per) if "original_form_agrees" in g],
        "joint_components": joint,
        "census": census,
        "per_group": per,
    }


def run(bundle_dir, block_stages=(), controls=True):
    TT = load_ts()
    t0 = time.time()
    run_js = json.load(open(os.path.join(bundle_dir, "run.json")))
    n_st = run_js["stages"]
    idx = [0, n_st - 1] + [k for k in block_stages if 0 < k < n_st - 1]
    ents, nchk = load_token_roles(TT, bundle_dir, idx)
    rec = {"what": "the G-7 terminal surjection (ts_trained, per group and per joint component) "
                   "on the token stages' commitments; NOT a privacy result",
           "privacy_acceptance": False, "privacy_property_established": False,
           "bundle": os.path.basename(bundle_dir), "stages_read": idx, "arrays_checked": nchk,
           "ts_trained_sha256": TS_TRAINED_PIN, "stage0": TT.T.stage0_selftest(), "roles": []}
    for ent in ents:
        r = analyse(TT, ent)
        rec["roles"].append(r)
        print(f"{ent['file']} {r['role']}: groups {r['groups']}, surjective {r['surjective_groups']}, "
              f"disclosed {r['total_disclosed_Fp']} {r['disclosed_by_group']}, joint "
              f"{[(j['groups'], j['disclosed_Fp']) for j in r['joint_components']]} ({time.time() - t0:.1f} s)",
              flush=True)
    if controls:
        rec["controls"] = {}
        # (i) every token role's groups are SINGLETONS at these profiles, so
        # the review's two-member controls cannot run on them; the token
        # control TS-1 removes one claim's reserved pair (the review's C2 on
        # a singleton group) and must make that group disclose, on every
        # token role; the honest group must not
        rows = []
        for ent in ents:
            if ent["stage_kind"] == "BLOCK":
                continue
            set_width(TT, ent["log_cols"], ent["inv_rate"])
            role = ent["role"]
            gi = next((i for i, g in enumerate(role.groups)
                       if len(g) == 1 and not set(role.rws[g[0]]) & set(role.u_rows)), None)
            if gi is None:
                rows.append({"role": role.name, "not_applicable": "no singleton site-pair group"})
                continue
            c0 = role.groups[gi][0]
            small = len({i for i in role.rws[c0] if role.kind[i] == "data"}) <= 4
            honest = TT.analyse_group(role, gi, None, also_original=small)
            rw0 = {i: v for i, v in role.rws[c0].items() if role.kind[i] == "data"}
            pert = TT.analyse_group(role, gi, {"rws": {c0: rw0}}, also_original=small)
            rows.append({"role": role.name, "stage": ent["stage"], "group": gi,
                         "honest_disclosed_Fp": honest["disclosed_Fp"],
                         "pair_removed_disclosed_Fp": pert["disclosed_Fp"],
                         "fires": honest["disclosed_Fp"] == 0 and pert["disclosed_Fp"] > 0})
        live = [r for r in rows if "fires" in r]
        rec["controls"]["TS_1_pair_removed_on_token_roles"] = {
            "rows": rows, "ok": bool(live) and all(r["fires"] for r in live)}
        # (ii) the review's own controls on a two-member group, when a block
        # stage was read (the block A of the same capture)
        blk = next((e for e in ents if e["stage_kind"] == "BLOCK"
                    and any(len(g) == 2 for g in e["role"].groups)), None)
        if blk is not None:
            set_width(TT, blk["log_cols"], blk["inv_rate"])
            crow = TT.controls(blk["role"])
            fires = {r["control"]: r["fires"] for r in crow}
            want = {"honest reference": False, "C1 shared reserved pair": True,
                    "C2 cm = 0 (pair removed)": True}
            rec["controls"]["review_controls_on_block_A"] = {
                "role": blk["role"].name, "stage": blk["stage"], "rows": crow, "fires": fires,
                "ok": all(fires.get(k) is v for k, v in want.items())}
        rec["controls"]["ok"] = all(v.get("ok") for v in rec["controls"].values() if isinstance(v, dict))
    rec["summary"] = {f"{r['stage_kind']}:{r['role']}": {
        "groups": r["groups"], "surjective": r["surjective_groups"],
        "disclosed_Fp": r["total_disclosed_Fp"], "disclosed_by_group": r["disclosed_by_group"],
        "joint": [(j["groups"], j["disclosed_Fp"]) for j in r["joint_components"]],
        "census_identical_claims": r["census"].get("identical_claims"),
        "census_equal_published_values": r["census"].get("equal_published_values")}
        for r in rec["roles"]}
    rec["seconds"] = round(time.time() - t0, 1)
    rec["peak_rss_mb"] = round(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024)
    rec["tool_sha256"] = {os.path.basename(__file__): _sha(os.path.abspath(__file__))}
    return rec


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.strip().splitlines()[0])
    ap.add_argument("--bundle", required=True)
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--name", required=True)
    ap.add_argument("--block-stages", default="")
    ap.add_argument("--no-controls", action="store_true")
    a = ap.parse_args(argv)
    bs = tuple(int(x) for x in a.block_stages.split(",") if x)
    rec = run(a.bundle, bs, controls=not a.no_controls)
    os.makedirs(a.evidence, exist_ok=True)
    path = os.path.join(a.evidence, f"{a.name}.json")
    with open(path, "w") as fh:
        json.dump(rec, fh, indent=1, sort_keys=True, default=str)
        fh.write("\n")
    print(json.dumps(rec["summary"], indent=1, default=str))
    print(f"record: {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

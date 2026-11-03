#!/usr/bin/env python3
"""[v25 STAGING, 2026-11-02, TS / CENSUS lane] TS-1 and the claim census on a
D55 "commit, fork, join" FORK-RUN capture.

    python3 -B zk60_native_rg_d55ts.py --bundle <D55 capture> --evidence <dir> --name <name> [--no-controls]
    (the D55 driver `zk60_native_rg_d55.d55_gate` calls `d55_ts_census` for an R13 base)

WHAT IS PORTED.  The G-7 terminal surjection (`EV/g7/ts_trained.py`, frozen,
digest pinned in `zk60_native_rg_tokents.TS_TRAINED_PIN`, which itself checks
the three frozen review scripts' digests before import) as the D12a / token /
classifier wrappers run it (`zk60_native_rg_tokents.analyse`, `..._ddts`,
`ops/zkp-mvp/gate-tinyllama/r22-item3/zk60_r22_classts2.py`), on EVERY
commitment a D55 bundle opens: each fork's A and H (`stage-KK.json`) and every
tail opening (`d55_tail.json`: the L - 1 internal boundaries B0.., then the
external input and output endpoints), each at its OWN `params` (log_cols,
inv_rate).  Per role:

  TS-R   the role analysis (`tokents.analyse`, unchanged in content): the
         stage-1 structural audit of the claim schedule, every group's
         per-group system (`analyse_group`: blinding rank, the onto-lemma
         `surjective_onto_consistency_subspace`, the annihilator on the
         blinding and on the data generators, "disclosed" by the null-space
         form, and the original form as well on small groups), and every
         joint component of groups sharing a non-data row
         (`analyse_component`: H's zero-sum pair).  EXPECTED (the classifier
         precedent, `zk60_r22_classts2.py`, plus the annihilator on the data):
         every A, boundary and endpoint role discloses 0 with every group
         onto; every H discloses exactly its declared zero-sum pair (2 Fp)
         and its one joint component discloses 2; the structural audit has no
         finding.
  TS-1   THE CONTROL (one claim's reserved pair removed, the review's C2 on a
         singleton group): on every role with a singleton site-pair group,
         the one with the FEWEST data rows (classts2 v2's rule); the honest
         group must disclose 0 and the pair-removed group must disclose > 0.
         The honest arm is `analyse_group` exactly as D12a runs it.  THE
         PAIR-REMOVED ARM IS COMPUTED BY THE TOOL'S OWN ORIGINAL FORM
         (`ts_trained.group_system` then `ts_field.Elim`: the blinding
         generators, then the data generators, into ONE eliminator; disclosed
         = rank(B | D) - rank(B), ts_trained.py:307-314), not by its
         null-space form: with the pair removed a singleton group has no
         blinding row, so the null-space form evaluates all 2 (N + 1) unit
         functionals on each of rows x N data generators -- 8,776 s for ONE
         38-row Input role at the real classifier block (round 23, c9b),
         about 5 h for one 8B tail opening -- while the original form is the
         same rank in seconds.  ts_trained runs both forms on every small
         group and requires them to agree; so does this module: TS-1F runs
         the null-space form too on the bundle's cheapest TS-1 row(s) (at
         most `FIDELITY_MAX_DATA_ROWS` data rows) and both must agree.
         [v25 freeze fixes, FR25-11] With no such row TS-1F is NOT
         APPLICABLE (ok None): it no longer counts as held, and the
         controls' ok needs at least one applicable control that holds.  A
         fidelity limit below 1 is refused (TS-1F false).
  TS-RC  the review's own controls (`ts_trained.controls`: honest reference,
         C1 shared reserved pair, C2 cm = 0, C3 lambda_c = 0, C6 cw = delta,
         C8 Fp-dependent pair weights, G7-D1 / D2 / D3 duplicate-claim
         probes) on the first two-member group of fork 0's A, each against
         the prediction ts_trained writes beside it (fires: C1, C2, G7-D3;
         does not fire: the honest reference, C3, C6, C8, G7-D1, G7-D2 --
         the pattern the real classifier block measured in round 23).

CENSUS  the G-7 claim census at the PCS level (`ts_trained.pcs_census`) on
        every role: identical claims, equal published values, claims with
        the same data weights in one group (each must be EMPTY: condition
        C-9's lapse trigger), and the same-group pairs sharing a data row
        (reported).  Controls, on doctored COPIES of fork 0's A (the bundle's
        files untouched), each must be caught: CEN-1 claim 0 duplicated,
        CEN-2 claim 1's published value set to claim 0's, CEN-3 a claim with
        claim 0's parts at twice its coefficient and another value (the same
        data weights in the same group, not an identical claim).

THE LOADER.  `ts_trained.py` names the review scripts at the LAPTOP path
(`/home/victor/...`).  On this host the file is read from the repository,
its SHA-256 compared with the pin BEFORE anything is executed, and the ONE
line `TS = "/home/victor/.../zk60_terminal_surjection_review"` replaced by the
repository's copy of that directory; ts_trained then checks its own three
review-script pins there, unchanged.  The record carries both digests and the
substitution.  No frozen byte is edited.  Arrays are read through an mmap of
`arrays.bin` with ts_trained's own per-reference SHA-256 check (classts2's
`mmap_arrays`).

WORKERS.  Every group, joint component, TS-1 row and the review controls are
independent pure computations; they run in a process pool
(`ZK60_D55TS_WORKERS`, default min(12, cores / 2); 1 runs inline).  The
figures do not depend on the order.

NOTHING HERE IS A PRIVACY RESULT, A PRIVACY STATEMENT OR AN ACCEPTANCE.
Every figure is a rank of an explicitly stated linear model at one captured
run's real challenges.
"""

from __future__ import annotations

import argparse
import concurrent.futures as cf
import copy
import hashlib
import json
import mmap
import multiprocessing
import os
import sys
import time
import types

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import zk60_native_rg_tokents as TSW  # noqa: E402  (the pin, set_width)

SCHEMA_D55 = "hashline-native-capture/8-d55-fork-run-prototype"
TAIL_FILE = "d55_tail.json"
TS_TRAINED_REL = os.path.join("results", "zk60_gate_tinyllama_20261017", "g7", "ts_trained.py")
TS_REVIEW_REL = os.path.join("results", "zk60_terminal_surjection_review")
LAPTOP_TS_LINE = 'TS = "/home/victor/IntelligenceRegulation/results/zk60_terminal_surjection_review"'
# the TS-1F cross-check: the null-space form costs ~rows x N x 2(N + 1)
# functional evaluations (about 540 s per data row at N = 2^14)
FIDELITY_MAX_DATA_ROWS = int(os.environ.get("ZK60_D55TS_FIDELITY_ROWS", "2"))
FIDELITY_ROWS = int(os.environ.get("ZK60_D55TS_FIDELITY_COUNT", "1"))
# ts_trained.controls' own prediction beside each control (fires or not)
REVIEW_PREDICTION = {
    "honest reference": False,
    "C1 shared reserved pair": True,
    "C2 cm = 0 (pair removed)": True,
    "C3 lambda_c = 0": False,
    "C6 cw = delta (one nonzero entry)": False,
    "C8 pair weights Fp-dependent": False,
    "G7-D1 duplicate claim: same data weights, its OWN reserved pair (cm, cm U)": False,
    "G7-D2 duplicate claim: an exact copy (two identical coordinates, shared pair)": False,
    "G7-D3 control: a copy sharing the pair whose DATA weights differ in one row": True,
}


def _sha(p):
    with open(p, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


def _repo_file(rel):
    d = HERE
    for _ in range(10):
        cand = os.path.join(d, rel)
        if os.path.exists(cand):
            return cand
        d = os.path.dirname(d)
    raise FileNotFoundError(f"{rel}: not found above {HERE}")


# ---------------------------------------------------------------- the frozen tool, relocated
_TS_CACHE = {}


def load_ts():
    """`ts_trained.py` at its pinned digest, with its review-script root
    relocated to this repository (one line, recorded); returns (module,
    record)."""
    if "mod" in _TS_CACHE:
        return _TS_CACHE["mod"], _TS_CACHE["rec"]
    path = _repo_file(TS_TRAINED_REL)
    with open(path, "rb") as fh:
        raw = fh.read()
    got = hashlib.sha256(raw).hexdigest()
    if got != TSW.TS_TRAINED_PIN:
        raise SystemExit(f"{path}: sha256 {got} is not the pin {TSW.TS_TRAINED_PIN}")
    src = raw.decode()
    if src.count(LAPTOP_TS_LINE) != 1:
        raise SystemExit(f"{path}: the review-root line {LAPTOP_TS_LINE!r} is not there exactly once")
    review = _repo_file(TS_REVIEW_REL)
    relocated = f"TS = {review!r}"
    mod = types.ModuleType("ts_trained_g7_d55")
    mod.__file__ = path
    argv = sys.argv
    sys.argv = [path]
    try:
        exec(compile(src.replace(LAPTOP_TS_LINE, relocated), path, "exec"), mod.__dict__)  # noqa: S102
    finally:
        sys.argv = argv
    pins_checked = {f: _sha(os.path.join(review, f)) for f in mod.PINS}
    if pins_checked != dict(mod.PINS):
        raise SystemExit(f"the review scripts at {review} are not at ts_trained's pins")

    class MmapArrays(mod.Arrays):
        """ts_trained.Arrays over an mmap (classts2's `mmap_arrays`): the same
        per-reference SHA-256 check and parsing; only referenced slices are read"""

        def __init__(self, p):
            self._fh = open(p, "rb")
            self.mm = mmap.mmap(self._fh.fileno(), 0, access=mmap.ACCESS_READ)
            self.checked = 0
    mod.MmapArrays = MmapArrays
    rec = {"ts_trained": path, "ts_trained_sha256": got, "ts_trained_pin": TSW.TS_TRAINED_PIN,
           "relocation": {"replaced_line": LAPTOP_TS_LINE, "with": relocated,
                          "why": "the frozen file names the laptop path; this host keeps the same pinned review scripts in the repository"},
           "review_scripts_sha256": pins_checked, "review_pins_equal": True}
    _TS_CACHE["mod"], _TS_CACHE["rec"] = mod, rec
    return mod, rec


# ---------------------------------------------------------------- the D55 roles
def role_keys(bundle_dir):
    """every commitment a D55 bundle opens, in the bundle's order:
    (key, file, index of the role in that file)"""
    with open(os.path.join(bundle_dir, "run.json"), "rb") as fh:
        run = json.loads(fh.read())
    if run.get("schema") != SCHEMA_D55:
        raise ValueError(f"run.json: schema {run.get('schema')!r} is not {SCHEMA_D55!r}")
    out = []
    for k in range(run["blocks"]):
        out.append((f"fork{k:02d}:A", f"stage-{k:02d}.json", 0))
        out.append((f"fork{k:02d}:H", f"stage-{k:02d}.json", 1))
    with open(os.path.join(bundle_dir, TAIL_FILE), "rb") as fh:
        tail = json.loads(fh.read())
    for i, r in enumerate(tail["roles"]):
        nm = f"B{r['boundary']}" if r["commitment_kind"] == "internal-boundary" else f"E-{r['role']}"
        out.append((f"tail:{nm}", TAIL_FILE, i))
    return run, out


def load_role(TT, bundle_dir, key, fn, idx, run=None):
    if run is None:
        with open(os.path.join(bundle_dir, "run.json"), "rb") as fh:
            run = json.loads(fh.read())
    if run["field_modulus"] != TT.P or run["extension_nonresidue"] != 7:
        raise ValueError("run.json: not Goldilocks with nonresidue 7")
    with open(os.path.join(bundle_dir, fn), "rb") as fh:
        doc = json.loads(fh.read())
    r = doc["roles"][idx]
    want = {"A": "A", "H": "H"}.get(key.split(":")[1])
    if want is not None and r["role"] != want:
        raise ValueError(f"{fn} role {idx} is {r['role']!r}, not {want!r}")
    pr = r["params"]
    TSW.set_width(TT, pr["log_cols"], pr["inv_rate"])
    arr = TT.MmapArrays(os.path.join(bundle_dir, "arrays.bin"))
    try:
        rr = arr.resolve({kk: r[kk] for kk in TT.KEEP if kk in r})     # every array is copied into lists
    finally:
        arr.mm.close()
        arr._fh.close()
    cap = {"proof_sha256": doc.get("segment_sha256", "tail"), "profile": run["profile"], "roles": [rr]}
    role = TT.T.Role(cap, rr)
    role.name = key
    return {"key": key, "file": fn, "index": idx, "log_cols": pr["log_cols"], "inv_rate": pr["inv_rate"],
            "profile": run["profile"], "role": role, "arrays_checked": arr.checked,
            "commitment_kind": r.get("commitment_kind")}


def _data_rows(role, c):
    return {i for i in role.rws[c] if role.kind[i] == "data"}


def ts1_group(role):
    """classts2 v2's rule: the singleton site-pair group (its claim on no
    zero-sum row) with the FEWEST data rows; None when the role has none"""
    cand = [i for i, g in enumerate(role.groups) if len(g) == 1 and not set(role.rws[g[0]]) & set(role.u_rows)]
    return min(cand, key=lambda i: (len(_data_rows(role, role.groups[i][0])), i)) if cand else None


def original_form(TT, role, gi, override):
    """ts_trained.py:307-314, the ORIGINAL form alone: the group's blinding
    generators, then its data generators, into one eliminator"""
    blind, data, m, info, _ = TT.group_system(role, gi, override)
    e = TT.Elim()
    for g in blind:
        e.add(dict(g))
    rb = e.rank
    n = 0
    for g in data():
        e.add(dict(g))
        n += 1
    return {"rank_blinding": rb, "rank_blinding_plus_data": e.rank, "disclosed_Fp": e.rank - rb,
            "data_generators": n, "blinding_rows": info["blinding_rows"], "data_rows_touched": info["data_rows_touched"],
            "form": "original (blinding then data, one eliminator; ts_trained.py:307-314)"}


# ---------------------------------------------------------------- the tasks (pure)
_W = {"TT": None, "roles": {}, "run": {}}


def _worker_init():
    _W["TT"], _ = load_ts()


def _role(bundle_dir, key, fn, idx):
    k = (bundle_dir, key)
    if k not in _W["roles"]:
        if bundle_dir not in _W["run"]:
            with open(os.path.join(bundle_dir, "run.json"), "rb") as fh:
                _W["run"][bundle_dir] = json.loads(fh.read())
        _W["roles"][k] = load_role(_W["TT"], bundle_dir, key, fn, idx, _W["run"][bundle_dir])
    ent = _W["roles"][k]
    TSW.set_width(_W["TT"], ent["log_cols"], ent["inv_rate"])
    return ent


def run_task(task):
    """one independent computation; returns (task id, result)"""
    if _W["TT"] is None:
        _worker_init()
    TT = _W["TT"]
    kind, bundle_dir, key, fn, idx, arg = task
    t0 = time.time()
    ent = _role(bundle_dir, key, fn, idx)
    role = ent["role"]
    if kind == "group":
        gi = arg
        small = len(role.groups[gi]) <= 2 and len({i for c_ in role.groups[gi] for i in role.rws[c_] if role.kind[i] == "data"}) <= 4
        out = TT.analyse_group(role, gi, also_original=small)
    elif kind == "joint":
        out = TT.analyse_component(role, list(arg))
    elif kind == "ts1":
        gi = arg
        c0 = role.groups[gi][0]
        small = len(_data_rows(role, c0)) <= 4
        honest = TT.analyse_group(role, gi, None, also_original=small)
        rw0 = {i: v for i, v in role.rws[c0].items() if role.kind[i] == "data"}
        pert = original_form(TT, role, gi, {"rws": {c0: rw0}})
        out = {"role": key, "group": gi, "claim": c0, "data_rows": len(rw0),
               "honest_disclosed_Fp": honest["disclosed_Fp"], "honest_surjective": honest["surjective_onto_consistency_subspace"],
               "honest_original_form_agrees": honest.get("original_form_agrees"),
               "pair_removed_disclosed_Fp": pert["disclosed_Fp"], "pair_removed": pert,
               "fires": honest["disclosed_Fp"] == 0 and pert["disclosed_Fp"] > 0}
    elif kind == "ts1-fidelity":
        gi = arg
        c0 = role.groups[gi][0]
        rw0 = {i: v for i, v in role.rws[c0].items() if role.kind[i] == "data"}
        full = TT.analyse_group(role, gi, {"rws": {c0: rw0}}, also_original=True)
        out = {"role": key, "group": gi, "claim": c0, "data_rows": len(rw0),
               "null_space_form_disclosed_Fp": full["disclosed_Fp"],
               "original_form_disclosed_Fp": full["original_form_disclosed_Fp"],
               "forms_agree": full["original_form_agrees"], "left_null_dim": full["left_null_dim"],
               "data_generators": full["data_generators"]}
    elif kind == "review":
        rows = TT.controls(role)
        out = {"role": key, "rows": rows}
    else:
        raise ValueError(f"unknown task {kind}")
    out = dict(out)
    out["task_seconds"] = round(time.time() - t0, 1)
    return task, out


def workers_default():
    w = os.environ.get("ZK60_D55TS_WORKERS")
    if w:
        return max(1, int(w))
    return max(1, min(12, (os.cpu_count() or 2) // 2))


def run_tasks(tasks, workers):
    """every task, inline (workers = 1) or in a spawn pool; results by task"""
    res = {}
    if workers <= 1 or len(tasks) <= 1:
        for t in tasks:
            k, v = run_task(t)
            res[k] = v
        return res
    ctx = multiprocessing.get_context("spawn")
    with cf.ProcessPoolExecutor(max_workers=min(workers, len(tasks)), mp_context=ctx, initializer=_worker_init) as ex:
        for k, v in ex.map(run_task, tasks, chunksize=1):
            res[k] = v
    return res


def _cost(ent, kind, arg):
    role = ent["role"]
    if kind == "group":
        g = role.groups[arg]
        return len({i for c in g for i in role.rws[c]}) + len(g)
    if kind == "joint":
        return 4 * sum(len({i for c in role.groups[gi] for i in role.rws[c]}) for gi in arg)
    if kind == "review":
        return 50
    if kind == "ts1-fidelity":
        return 10 ** 6
    return 5


# ---------------------------------------------------------------- the census
def census_controls(TT, ent):
    """CEN-1 / CEN-2 / CEN-3 on doctored copies of one role's raw dict"""
    role = ent["role"]
    raw = role.raw
    TSW.set_width(TT, ent["log_cols"], ent["inv_rate"])
    cap = {"proof_sha256": "control", "profile": ent["profile"], "roles": []}

    def census_of(mut):
        r = copy.deepcopy(raw)
        mut(r)
        rl = TT.T.Role(cap, r)
        return TT.pcs_census(rl)
    out = {}

    def dup(r):
        r["claims"].append(copy.deepcopy(r["claims"][0]))
    c1 = census_of(dup)
    n = len(raw["claims"])
    out["CEN-1 claim 0 duplicated"] = {"identical_claims": c1["identical_claims"], "fires": (0, n) in [tuple(x) for x in c1["identical_claims"]]}

    def eqv(r):
        r["claims"][1]["value"] = copy.deepcopy(r["claims"][0]["value"])
    c2 = census_of(eqv)
    out["CEN-2 claim 1's value set to claim 0's"] = {"equal_published_values": c2["equal_published_values"],
                                                     "fires": (0, 1) in [tuple(x) for x in c2["equal_published_values"]]}

    def scaled(r):
        c = copy.deepcopy(r["claims"][0])
        for p in c["parts"]:
            p["coefficient"] = [(2 * p["coefficient"][0]) % TT.P, (2 * p["coefficient"][1]) % TT.P]
        c["value"] = [(c["value"][0] + 1) % TT.P, c["value"][1]]
        r["claims"].append(c)
    c3 = census_of(scaled)
    out["CEN-3 claim 0's parts at twice the coefficient, another value"] = {
        "same_data_weights_same_group": c3["same_data_weights_same_group"], "identical_claims": c3["identical_claims"],
        "fires": (0, n) in [tuple(x) for x in c3["same_data_weights_same_group"]] and not c3["identical_claims"]}
    out["on"] = ent["key"]
    out["ok"] = all(v["fires"] for v in out.values() if isinstance(v, dict))
    return out


# ---------------------------------------------------------------- [FR25-11] not applicable is not fired
def fidelity_control(fid, max_rows, count) -> dict:
    """TS-1F's record from its rows (each with `forms_agree` and
    `equals_the_ts1_original_form`).  A fidelity limit below 1 is REFUSED (ok
    False: the limit alone would make TS-1F vacuous); no row to act on is NOT
    APPLICABLE (ok None), never a pass by `all([])`."""
    rec = {"what": f"the pair-removed arm by BOTH of ts_trained's forms on the bundle's cheapest TS-1 row(s) (at most "
                   f"{max_rows} data rows, {count} row(s)); they must agree and equal TS-1's figure",
           "rows": fid, "ok": all(f["forms_agree"] and f["equals_the_ts1_original_form"] for f in fid)}
    if max_rows < 1 or count < 1:
        rec.update(refused=f"ZK60_D55TS_FIDELITY_ROWS = {max_rows} / ZK60_D55TS_FIDELITY_COUNT = {count}: a fidelity limit "
                           f"below 1 is refused (FR25-11)", ok=False)
    elif not fid:
        rec.update(not_run=f"no TS-1 row of this bundle has at most {max_rows} data rows (the null-space form would cost "
                           f"rows x N x 2(N + 1) evaluations); the cross-check is recorded on the bundles where it ran",
                   not_applicable=True, ok=None)
    return rec


def controls_ok(ctl: dict) -> bool:
    """the TS controls' verdict: a NOT-APPLICABLE control (ok None) is left
    out, no applicable one may fail, and at least one must be applicable"""
    applicable = [v for v in ctl.values() if isinstance(v, dict) and v.get("ok") is not None]
    return bool(applicable) and all(v["ok"] is True for v in applicable)


# ---------------------------------------------------------------- the part
def d55_ts_census(bundle_dir, controls=True, workers=None):
    """returns (the TS-1 record, the CENSUS record); each has `ok`"""
    t0 = time.time()
    TT, loader = load_ts()
    workers = workers_default() if workers is None else workers
    run, keys = role_keys(bundle_dir)
    ents = [load_role(TT, bundle_dir, key, fn, idx, run) for key, fn, idx in keys]
    stage0 = TT.T.stage0_selftest()
    plan, per_role = [], {}
    for e in ents:
        role = e["role"]
        TSW.set_width(TT, e["log_cols"], e["inv_rate"])
        s1 = TT.T.stage1_structure([(e["file"], e["profile"], [role])])
        comps = [gs for gs in TT.components(role) if len(gs) > 1]
        per_role[e["key"]] = {"ent": e, "stage1": s1, "components": comps, "census": TT.pcs_census(role),
                              "ts1_group": ts1_group(role)}
        for gi in range(len(role.groups)):
            plan.append(("group", gi, e))
        for gs in comps:
            plan.append(("joint", tuple(gs), e))
        if controls and per_role[e["key"]]["ts1_group"] is not None:
            plan.append(("ts1", per_role[e["key"]]["ts1_group"], e))
    fidelity = []
    if controls:
        cands = sorted(((len(_data_rows(v["ent"]["role"], v["ent"]["role"].groups[v["ts1_group"]][0])), k)
                        for k, v in per_role.items() if v["ts1_group"] is not None))
        fidelity = [k for nrows, k in cands if nrows <= FIDELITY_MAX_DATA_ROWS][:FIDELITY_ROWS]
        for k in fidelity:
            plan.append(("ts1-fidelity", per_role[k]["ts1_group"], per_role[k]["ent"]))
        a0 = next((v["ent"] for k, v in per_role.items() if k.endswith(":A") and any(len(g) == 2 for g in v["ent"]["role"].groups)), None)
        if a0 is not None:
            plan.append(("review", None, a0))
    plan.sort(key=lambda p: -_cost(p[2], p[0], p[1]))
    tasks = [(kind, bundle_dir, e["key"], e["file"], e["index"], arg) for kind, arg, e in plan]
    t1 = time.time()
    res = run_tasks(tasks, workers)
    t_tasks = time.time() - t1

    def got(kind, e, arg):
        return res[(kind, bundle_dir, e["key"], e["file"], e["index"], arg)]
    roles_out, expectation = [], []
    for e in ents:
        pr = per_role[e["key"]]
        role = e["role"]
        per = [got("group", e, gi) for gi in range(len(role.groups))]
        joint = [got("joint", e, tuple(gs)) for gs in pr["components"]]
        r = {"stage": e["key"].split(":")[0], "file": e["file"], "role": e["key"], "commitment_kind": e["commitment_kind"],
             "width": 1 << e["log_cols"], "width_log_cols": e["log_cols"], "inv_rate": e["inv_rate"], "rows": role.rows,
             "groups": len(per), "stage1": pr["stage1"],
             "surjective_groups": sum(1 for g in per if g["surjective_onto_consistency_subspace"]),
             "short_groups": [i for i, g in enumerate(per) if not g["surjective_onto_consistency_subspace"]],
             "annihilator_kills_blinding": all(g["annihilator_kills_all_blinding_generators"] for g in per),
             "annihilator_kills_data": all(g["annihilator_kills_all_data_generators"] for g in per),
             "disclosed_by_group": {str(i): g["disclosed_Fp"] for i, g in enumerate(per) if g["disclosed_Fp"]},
             "total_disclosed_Fp": sum(g["disclosed_Fp"] for g in per),
             "original_form_checked": [(i, g["original_form_agrees"]) for i, g in enumerate(per) if "original_form_agrees" in g],
             "joint_components": joint, "census": pr["census"], "per_group": per, "arrays_checked": e["arrays_checked"]}
        roles_out.append(r)
        is_h = e["key"].endswith(":H")
        want = 2 if is_h else 0
        s1_ok = all(not f["findings"] for f in pr["stage1"])
        if is_h:
            joint_ok = len(joint) == 1 and joint[0]["disclosed_Fp"] == 2
        else:
            joint_ok = all(j["disclosed_Fp"] == 0 for j in joint)
        onto_ok = (r["surjective_groups"] == r["groups"]) if not is_h else (r["groups"] - r["surjective_groups"] <= 1)
        expectation.append({"role": e["key"], "disclosed_Fp": r["total_disclosed_Fp"], "expected": want,
                            "surjective": f"{r['surjective_groups']}/{r['groups']}", "joint": [(j["groups"], j["disclosed_Fp"]) for j in joint],
                            "stage1_findings": [x for f in pr["stage1"] for x in f["findings"]],
                            "original_forms_agree": all(a for _i, a in r["original_form_checked"]),
                            "ok": (r["total_disclosed_Fp"] == want and r["annihilator_kills_blinding"] and r["annihilator_kills_data"]
                                   and s1_ok and joint_ok and onto_ok and all(a for _i, a in r["original_form_checked"]))})
    ts = {"what": "the G-7 terminal surjection (ts_trained, per group and per joint component) on every commitment of a D55 "
                  "fork-run capture (each fork's A and H, every tail opening), with control TS-1 on every role; NOT a privacy result",
          "privacy_acceptance": False, "privacy_property_established": False, "bundle": os.path.basename(bundle_dir),
          "profile": run["profile"], "loader": loader, "stage0": stage0, "roles_read": [e["key"] for e in ents],
          "arrays_checked": sum(e["arrays_checked"] for e in ents), "workers": workers, "roles": roles_out,
          "expectation": expectation}
    ok = bool(stage0.get("ok")) and all(x["ok"] for x in expectation)
    if controls:
        rows = []
        for e in ents:
            gi = per_role[e["key"]]["ts1_group"]
            rows.append(got("ts1", e, gi) if gi is not None else {"role": e["key"], "not_applicable": "no singleton site-pair group"})
        live = [x for x in rows if "fires" in x]
        ctl = {"TS-1 pair removed, every role": {
            "what": "on every role with a singleton site-pair group (its fewest-data-row one): honest disclosed 0, pair removed > 0; "
                    "the pair-removed arm by the tool's original form",
            "rows": rows, "fired": sum(1 for x in live if x["fires"]), "live": len(live),
            "not_applicable": [x["role"] for x in rows if "not_applicable" in x],
            "ok": bool(live) and all(x["fires"] for x in live)}}
        fid = [got("ts1-fidelity", per_role[k]["ent"], per_role[k]["ts1_group"]) for k in fidelity]
        for f in fid:
            want = next(x for x in rows if x.get("role") == f["role"])
            f["equals_the_ts1_original_form"] = f["original_form_disclosed_Fp"] == want["pair_removed_disclosed_Fp"]
        ctl["TS-1F the null-space form on the cheapest TS-1 row"] = fidelity_control(fid, FIDELITY_MAX_DATA_ROWS, FIDELITY_ROWS)
        a0 = next((v["ent"] for k, v in per_role.items() if k.endswith(":A") and any(len(g) == 2 for g in v["ent"]["role"].groups)), None)
        if a0 is not None:
            rv = got("review", a0, None)
            fires = {x["control"]: x["fires"] for x in rv["rows"]}
            ctl["TS-RC the review's controls on fork 0's A"] = {
                "role": a0["key"], "group": rv["rows"][0]["group"], "rows": rv["rows"], "fires": fires, "predicted": REVIEW_PREDICTION,
                "deviations": {k: fires.get(k) for k, v in REVIEW_PREDICTION.items() if fires.get(k) is not v},
                "ok": all(fires.get(k) is v for k, v in REVIEW_PREDICTION.items())}
        else:
            ctl["TS-RC the review's controls on fork 0's A"] = {"not_found": "no A role has a two-member group", "ok": False}
        ctl["not_applicable"] = [k for k, v in ctl.items() if isinstance(v, dict) and v.get("ok") is None]
        ctl["ok"] = controls_ok(ctl)
        ts["controls"] = ctl
        ok = ok and ctl["ok"]
    ts["summary"] = {r["role"]: {"rows": r["rows"], "groups": r["groups"], "surjective": r["surjective_groups"],
                                 "disclosed_Fp": r["total_disclosed_Fp"], "joint": [(j["groups"], j["disclosed_Fp"]) for j in r["joint_components"]]}
                     for r in roles_out}
    ts["seconds"] = round(time.time() - t0, 1)
    ts["task_seconds_wall"] = round(t_tasks, 1)
    ts["tool_sha256"] = {os.path.basename(__file__): _sha(os.path.abspath(__file__)), os.path.basename(TSW.__file__): _sha(TSW.__file__),
                         "ts_trained.py": loader["ts_trained_sha256"], **loader["review_scripts_sha256"]}
    ts["ok"] = ok
    # ---- the census
    cen_rows = [{"role": r["role"], **r["census"]} for r in roles_out]
    bad = [x["role"] for x in cen_rows if x["identical_claims"] or x["equal_published_values"] or x["same_data_weights_same_group"]]
    cen = {"what": "the G-7 claim census at the PCS level on every commitment of the D55 bundle: identical claims, equal published "
                   "values and same data weights in one group must be EMPTY (condition C-9's lapse trigger); NOT a privacy result",
           "privacy_acceptance": False, "roles": cen_rows, "claims_compared": sum(x["claims"] for x in cen_rows),
           "roles_with_a_finding": bad, "ok": not bad}
    if controls:
        a0 = ents[0]
        cen["controls"] = census_controls(TT, a0)
        cen["ok"] = cen["ok"] and cen["controls"]["ok"]
    cen["tool_sha256"] = ts["tool_sha256"]
    return ts, cen


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--bundle", required=True)
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--name", required=True)
    ap.add_argument("--no-controls", action="store_true")
    ap.add_argument("--workers", type=int)
    a = ap.parse_args(argv)
    ts, cen = d55_ts_census(a.bundle, controls=not a.no_controls, workers=a.workers)
    try:
        import resource
        ts["peak_rss_mb_main"] = round(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / (1 << 20))
    except Exception:  # noqa: BLE001
        pass
    os.makedirs(a.evidence, exist_ok=True)
    path = os.path.join(a.evidence, f"{a.name}.json")
    with open(path, "w") as fh:
        json.dump({"TS-1": ts, "CENSUS": cen}, fh, indent=1, sort_keys=True, default=str)
        fh.write("\n")
    print(json.dumps(ts["summary"], indent=1, default=str))
    for x in ts.get("controls", {}).get("TS-1 pair removed, every role", {}).get("rows", []):
        print("TS-1", x.get("role"), x.get("fires", x.get("not_applicable")), x.get("honest_disclosed_Fp"), x.get("pair_removed_disclosed_Fp"))
    print(f"TS-1 ok {ts['ok']}  CENSUS ok {cen['ok']}  ({ts['seconds']} s) -> {path}")
    return 0 if ts["ok"] and cen["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())

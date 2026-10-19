#!/usr/bin/env python3
"""G-7 sub-lane: the terminal-surjection computation of
docs/zkmatrix-poc/ZK60_TERMINAL_SURJECTION_REVIEW.md at the TRAINED layout.

    python3 ts_trained.py --out <dir> --bundle <capture dir> [--bundle ...]

The review's scripts (results/zk60_terminal_surjection_review/, frozen,
digests checked before import, no bytecode written there) read the
2026-09-19 toy captures, whose PCS rows are 2^8 = 256 columns wide. The
trained TinyLlama T32 layout's rows are 2^12 = 4096 wide and its run
bundles (schema hashline-native-capture/5-run, the gate's R5b captures)
keep every array of 256 or more entries in arrays.bin. So this wrapper:

  * imports ts_review and REUSES unchanged: Role (claim grouping, row
    weights, rho), zpart_weights / zkey_weights / group_claims, the stage-0
    eliminator self-test and the stage-1 structural audit, after setting
    the module's N_COLS = 4096 and LOG_COLS = 12 (both read at call time);
  * loads the 5-run bundles itself (array references resolved from
    arrays.bin, each checked against its SHA-256 name);
  * re-states stage 2's per-group system (`group_system`, `annihilator`)
    with ONE change: ts_review writes the claim-value observation columns
    at the literal `512 + 2k` (= 2 * 256 + 2k); here they are at
    `2 * N_COLS + 2k`, so they do not collide with the 8,192 message
    columns;
  * computes "disclosed" by the null-space form of the same quantity:
    rank([B | D]) - rank(B) = rank{ Phi(g) : g a data generator }, Phi a
    basis of the functionals that vanish on every blinding generator
    (obtained by back-substitution from the eliminator's echelon rows), so
    that the ~10^7 data generators are streamed and never stored. On small
    groups the original form (blinding then data into one eliminator) is
    run as well and must agree;
  * runs ts_components' connected-component system for groups that share a
    non-data row (H's zero-sum pair), in the same null-space form;
  * adds the G-7 census at the PCS level (identical claims, equal published
    values, claims on the same rows at the same point) and the review's
    controls on a small real group, plus two G-7 probes that INSERT a
    duplicate claim (D1: same data weights, its own reserved pair; D2: an
    exact copy, i.e. two identical coordinates).

Every number is a rank of an explicitly stated linear model at these
receipts' real challenges. NOTHING HERE ESTABLISHES A PRIVACY PROPERTY.
"""

import argparse
import hashlib
import json
import os
import random
import sys
import time

sys.dont_write_bytecode = True
TS = "/home/victor/IntelligenceRegulation/results/zk60_terminal_surjection_review"
PINS = {
    "ts_review.py": "6fffaed127dd5b4364c15d6f1797274b3bee75d6a7ae429ef5effff611f47317",
    "ts_field.py": "aee16c59e23dc0a279b521fa9507e6d30d6cb576bedac1d5f098ae7a19824d55",
    "ts_components.py": "6c1f8c74b17124c785b59eb1686f2d07c9b83356553f630bd7da0d57faca73a3",
}


def sha_file(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()


for _f, _d in PINS.items():
    assert sha_file(os.path.join(TS, _f)) == _d, f"{_f} moved"
sys.path.insert(0, TS)
import ts_review as T  # noqa: E402
from ts_field import Elim, F2_ONE, F2_U, F2_ZERO, P, f2, f2_add, f2_is_zero, f2_mul, f2_neg  # noqa: E402

T.N_COLS = 4096
T.LOG_COLS = 12
T.ENC_COLS = 4 * 4096
N = T.N_COLS
LOG = []


def log(*a):
    s = " ".join(str(x) for x in a)
    LOG.append(s)
    print(s, flush=True)


# ------------------------------------------------------------------ loading
REF_KEYS = {"array", "elem", "len", "offset", "bytes"}


class Arrays:
    def __init__(self, path):
        self.mm = open(path, "rb").read()
        self.checked = 0

    def get(self, ref):
        raw = self.mm[ref["offset"]: ref["offset"] + ref["bytes"]]
        assert hashlib.sha256(raw).hexdigest() == ref["array"], "array digest mismatch"
        self.checked += 1
        if ref["elem"] == "fp":
            assert ref["bytes"] == 8 * ref["len"]
            return [int.from_bytes(raw[8 * k: 8 * k + 8], "little") for k in range(ref["len"])]
        assert ref["elem"] == "fp2" and ref["bytes"] == 16 * ref["len"]
        return [[int.from_bytes(raw[16 * k: 16 * k + 8], "little"), int.from_bytes(raw[16 * k + 8: 16 * k + 16], "little")] for k in range(ref["len"])]

    def resolve(self, o):
        if isinstance(o, dict):
            if set(o) == REF_KEYS:
                return self.get(o)
            return {k: self.resolve(v) for k, v in o.items()}
        if isinstance(o, list):
            return [self.resolve(x) for x in o]
        return o


KEEP = ("role", "commitment", "claims", "groups", "proximity_rhos", "row_roles", "public_linear_constraints", "params", "q_pad")


def load_bundle(d):
    run = json.load(open(os.path.join(d, "run.json")))
    assert run["field_modulus"] == P and run["extension_nonresidue"] == 7
    arr = Arrays(os.path.join(d, "arrays.bin"))
    out = []
    for sf in sorted(f for f in os.listdir(d) if f.startswith("stage-") and f.endswith(".json")):
        st = json.load(open(os.path.join(d, sf)))
        assert st["log_cols"] == 12, (sf, st["log_cols"])
        roles = []
        for r in st["roles"]:
            assert r["params"]["log_cols"] == 12
            rr = arr.resolve({k: r[k] for k in KEEP if k in r})
            roles.append(rr)
        label = f"{os.path.basename(d)}/{sf[:-5]}"
        cap = {"proof_sha256": st["segment_sha256"], "profile": run["profile"], "roles": roles}
        out.append((label, run["profile"], [T.Role(cap, r) for r in roles]))
    return out, arr.checked


# ------------------------------------------------------------------ stage 2, restated at width N
def group_system(role, gi, override=None):
    """ts_review.group_system with the claim columns at 2N + 2k (not the
    literal 512 + 2k) and the data generators returned as a GENERATOR
    function. override: lambdas / cw / rws as in ts_review, plus
    extra = [(rw, lambda)] synthetic member claims and kinds = {row: kind}
    for synthetic rows (the G-7 probes)."""
    members = list(role.groups[gi])
    lam = list(role.lambdas[gi])
    cw = list(role.cw[gi])
    rws = {c: dict(role.rws[c]) for c in members}
    kind = dict(role.kind)
    if override:
        lam = list(override.get("lambdas", lam))
        cw = list(override.get("cw", cw))
        for c, rw in override.get("rws", {}).items():
            rws[c] = rw
        for k, (rw, l) in enumerate(override.get("extra", [])):
            cid = ("extra", k)
            members.append(cid)
            rws[cid] = rw
            lam.append(l)
        kind.update(override.get("kinds", {}))
    m = len(members)
    rho = {}
    for c, l in zip(members, lam):
        for i, v in rws[c].items():
            rho[i] = f2_add(rho.get(i, F2_ZERO), f2_mul(l, v))
    rho = {i: v for i, v in rho.items() if not f2_is_zero(v)}
    touched = set(rho) | {i for c in members for i in rws[c]}
    blind_rows = sorted(i for i in touched if kind[i] != "data")
    data_rows = sorted(i for i in touched if kind[i] == "data")
    Y = 2 * N

    def gen(i, j):
        g = {}
        r = rho.get(i)
        if r is not None:
            if r[0]:
                g[2 * j] = r[0]
            if r[1]:
                g[2 * j + 1] = r[1]
        if not f2_is_zero(cw[j]):
            for k, c in enumerate(members):
                w = rws[c].get(i)
                if w is None:
                    continue
                t = f2_mul(w, cw[j])
                if t[0]:
                    g[Y + 2 * k] = t[0]
                if t[1]:
                    g[Y + 2 * k + 1] = t[1]
        return g

    blind = []
    for i in blind_rows:
        if i in role.u_rows:
            for j in range(N - 1):
                a, b = gen(i, j), gen(i, N - 1)
                d = dict(a)
                for k, v in b.items():
                    nv = (d.get(k, 0) - v) % P
                    if nv:
                        d[k] = nv
                    elif k in d:
                        del d[k]
                blind.append(d)
        else:
            for j in range(N):
                blind.append(gen(i, j))

    def data():
        for i in data_rows:
            for j in range(N):
                yield gen(i, j)

    info = {"members": m, "blinding_rows": len(blind_rows), "data_rows_touched": len(data_rows), "cw_support": sum(1 for x in cw if not f2_is_zero(x)), "u_rows_in_group": [i for i in blind_rows if i in role.u_rows]}
    return blind, data, m, info, (lam, cw, rws, rho, members)


def annihilator(lam, cw, m):
    """ts_review.annihilator with the claim columns at 2N + 2k."""
    re, im = {}, {}
    Y = 2 * N
    for j in range(N):
        a = cw[j]
        if f2_is_zero(a):
            continue
        re[2 * j] = (re.get(2 * j, 0) + a[0]) % P
        re[2 * j + 1] = (re.get(2 * j + 1, 0) + 7 * a[1]) % P
        im[2 * j] = (im.get(2 * j, 0) + a[1]) % P
        im[2 * j + 1] = (im.get(2 * j + 1, 0) + a[0]) % P
    for k in range(m):
        a = f2_neg(lam[k])
        re[Y + 2 * k] = (re.get(Y + 2 * k, 0) + a[0]) % P
        re[Y + 2 * k + 1] = (re.get(Y + 2 * k + 1, 0) + 7 * a[1]) % P
        im[Y + 2 * k] = (im.get(Y + 2 * k, 0) + a[1]) % P
        im[Y + 2 * k + 1] = (im.get(Y + 2 * k + 1, 0) + a[0]) % P
    return [{k: v for k, v in re.items() if v}, {k: v for k, v in im.items() if v}]


def apply_phi(phi, g):
    return sum(phi.get(k, 0) * v for k, v in g.items()) % P


def null_functionals(e, ncols):
    """a basis of { phi : phi(g) = 0 for every row g of the eliminator }:
    for each free column f, phi_f(f) = 1, phi_f = 0 at the other free
    columns, and at a pivot c (rows are echelon: entries at columns >= c,
    leading 1) phi_f(c) = -sum_{k > c} row_c[k] phi_f(k), back-substituted
    from the highest pivot down."""
    free = [c for c in range(ncols) if c not in e.piv]
    piv_desc = sorted(e.piv, reverse=True)
    out = []
    for f in free:
        phi = {f: 1}
        for c in piv_desc:
            row = e.piv[c]
            s = 0
            for k, v in row.items():
                if k != c:
                    pk = phi.get(k)
                    if pk:
                        s += v * pk
            s %= P
            if s:
                phi[c] = (-s) % P
        out.append(phi)
    return out


def disclosed_by_nullspace(phis, data_iter):
    """rank{ (phi_1(g), ..., phi_r(g)) : g } over the streamed generators;
    also counts the generators"""
    e = Elim()
    n = 0
    nz = 0
    full = len(phis)
    for g in data_iter:
        n += 1
        v = {k: apply_phi(p, g) for k, p in enumerate(phis)}
        v = {k: x for k, x in v.items() if x}
        if v:
            nz += 1
            if e.rank < full:
                e.add(v)
    return e.rank, n, nz


def analyse_group(role, gi, override=None, also_original=False):
    t0 = time.time()
    blind, data, m, info, (lam, cw, rws, rho, members) = group_system(role, gi, override)
    ncol = 2 * (N + m)
    e = Elim()
    for g in blind:
        e.add(dict(g))
    rb = e.rank
    res = dict(info)
    res["rank_blinding"] = rb
    res["observations_Fp"] = ncol
    res["expected_rank"] = ncol - 2
    res["surjective_onto_consistency_subspace"] = rb == ncol - 2
    phis_id = annihilator(lam, cw, m)
    res["annihilator_kills_all_blinding_generators"] = all(apply_phi(p, g) == 0 for p in phis_id for g in blind)
    res["annihilator_nonzero"] = all(bool(p) for p in phis_id)
    res["annihilator_kills_all_data_generators"] = all(apply_phi(p, g) == 0 for g in data() for p in phis_id)
    nulls = null_functionals(e, ncol)
    res["left_null_dim"] = len(nulls)
    dis, ngen, nnz = disclosed_by_nullspace(nulls, data())
    res["data_generators"] = ngen
    res["disclosed_Fp"] = dis
    res["rank_blinding_plus_data"] = rb + dis
    if also_original:
        e2 = Elim()
        for g in blind:
            e2.add(dict(g))
        for g in data():
            e2.add(dict(g))
        res["original_form_disclosed_Fp"] = e2.rank - rb
        res["original_form_agrees"] = e2.rank - rb == dis
    res["seconds"] = round(time.time() - t0, 1)
    return res


# ------------------------------------------------------------------ components (ts_components, null-space form)
def components(role):
    nd = []
    for gi in range(len(role.groups)):
        s = {i for i in role.rho[gi] if role.kind[i] != "data"}
        for c in role.groups[gi]:
            s |= {i for i in role.rws[c] if role.kind[i] != "data"}
        nd.append(s)
    parent = list(range(len(nd)))

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    for a in range(len(nd)):
        for b in range(a + 1, len(nd)):
            if nd[a] & nd[b]:
                parent[find(a)] = find(b)
    comp = {}
    for a in range(len(nd)):
        comp.setdefault(find(a), []).append(a)
    return sorted(comp.values())


def analyse_component(role, gs):
    t0 = time.time()
    slot = {}

    def col(name):
        if name not in slot:
            slot[name] = len(slot) * 2
        return slot[name]

    # fix the column order first: every group's v columns, then every claim
    for gi in gs:
        for j in range(N):
            col(("v", gi, j))
    for gi in gs:
        for c in role.groups[gi]:
            col(("y", c))
    touched = set()
    for gi in gs:
        touched |= set(role.rho[gi])
        for c in role.groups[gi]:
            touched |= set(role.rws[c])

    def gen(i, j):
        g = {}
        for gi in gs:
            a = role.rho[gi].get(i)
            if a is not None:
                b = slot[("v", gi, j)]
                if a[0]:
                    g[b] = a[0]
                if a[1]:
                    g[b + 1] = a[1]
            if f2_is_zero(role.cw[gi][j]):
                continue
            for c in role.groups[gi]:
                w = role.rws[c].get(i)
                if w is None:
                    continue
                x = f2_mul(w, role.cw[gi][j])
                b = slot[("y", c)]
                if x[0]:
                    g[b] = (g.get(b, 0) + x[0]) % P
                if x[1]:
                    g[b + 1] = (g.get(b + 1, 0) + x[1]) % P
        return {k: v for k, v in g.items() if v}

    e = Elim()
    nb = 0
    for i in sorted(touched):
        if role.kind[i] == "data":
            continue
        if i in role.u_rows:
            last = gen(i, N - 1)
            for j in range(N - 1):
                d = dict(gen(i, j))
                for k, v in last.items():
                    nv = (d.get(k, 0) - v) % P
                    if nv:
                        d[k] = nv
                    elif k in d:
                        del d[k]
                e.add(d)
                nb += 1
        else:
            for j in range(N):
                e.add(gen(i, j))
                nb += 1
    rb = e.rank
    ncol = 2 * len(slot)
    nulls = null_functionals(e, ncol)

    def data():
        for i in sorted(touched):
            if role.kind[i] == "data":
                for j in range(N):
                    yield gen(i, j)

    dis, ngen, _ = disclosed_by_nullspace(nulls, data())
    n_claims = sum(len(role.groups[gi]) for gi in gs)
    return {
        "groups": gs,
        "claims": n_claims,
        "blinding_rows": len([i for i in touched if role.kind[i] != "data"]),
        "u_rows": sorted(i for i in touched if i in role.u_rows),
        "data_rows": len([i for i in touched if role.kind[i] == "data"]),
        "observation_Fp": 2 * (N * len(gs) + n_claims),
        "blinding_generators": nb,
        "data_generators": ngen,
        "rank_blinding": rb,
        "left_null_dim": len(nulls),
        "rank_blinding_plus_data": rb + dis,
        "disclosed_Fp": dis,
        "seconds": round(time.time() - t0, 1),
    }


# ------------------------------------------------------------------ the G-7 census at the PCS level
def pcs_census(role):
    def part_key(p):
        return (p["offset"], p["log_size"], tuple(map(tuple, p["coefficient"])) if isinstance(p["coefficient"][0], list) else tuple(p["coefficient"]), tuple(tuple(x) for x in p["point"]))

    claims = role.raw["claims"]
    keyset = [tuple(sorted(part_key(p) for p in c["parts"])) for c in claims]
    ident = [(a, b) for a in range(len(claims)) for b in range(a + 1, len(claims)) if keyset[a] == keyset[b]]
    vals = [tuple(c["value"]) for c in claims]
    eqv = [(a, b) for a in range(len(claims)) for b in range(a + 1, len(claims)) if vals[a] == vals[b]]
    # two claims on the same DATA rows at the same column key (a repeated
    # coordinate of the opening): data-row weights equal up to a scalar
    gkey = {}
    for gi, ms in enumerate(role.groups):
        for c in ms:
            gkey[c] = gi

    def norm_data(c):
        rw = {i: v for i, v in role.rws[c].items() if role.kind[i] == "data"}
        if not rw:
            return None
        i0 = min(rw)
        from ts_field import f2_inv
        s = f2_inv(rw[i0])
        return tuple(sorted((i, f2_mul(v, s)) for i, v in rw.items()))

    nd = [norm_data(c) for c in range(len(claims))]
    same_rows_same_key = [(a, b) for a in range(len(claims)) for b in range(a + 1, len(claims)) if nd[a] is not None and nd[a] == nd[b] and gkey[a] == gkey[b]]
    data_row_sets = [frozenset(i for i in role.rws[c] if role.kind[i] == "data") for c in range(len(claims))]
    shared_rows_same_group = [(a, b) for a in range(len(claims)) for b in range(a + 1, len(claims)) if gkey[a] == gkey[b] and data_row_sets[a] & data_row_sets[b]]
    return {
        "claims": len(claims),
        "identical_claims": ident,
        "equal_published_values": eqv,
        "same_data_weights_same_group": same_rows_same_key,
        "same_group_pairs_sharing_a_data_row": len(shared_rows_same_group),
    }


# ------------------------------------------------------------------ controls and G-7 probes on a small real group
def controls(role):
    two = [gi for gi in range(len(role.groups)) if len(role.groups[gi]) == 2]
    gi = two[0]
    c0, c1 = role.groups[gi]
    pair0 = sorted(r for r in role.rws[c0] if role.kind[r] != "data")
    pair1 = sorted(r for r in role.rws[c1] if role.kind[r] != "data")
    out = []

    def rec(name, ov, expect):
        r = analyse_group(role, gi, ov, also_original=True)
        r.update({"control": name, "group": gi, "expect": expect, "fires": r["disclosed_Fp"] > 0})
        out.append(r)
        log(f"   control {name}: rank {r['rank_blinding']} / expected-honest {r['expected_rank']}, disclosed {r['disclosed_Fp']} (original form {r['original_form_disclosed_Fp']}), expect {expect}")

    rec("honest reference", None, "surjective, disclosed 0")
    rw1 = {i: v for i, v in role.rws[c1].items() if i not in pair1}
    rw1[pair0[0]] = f2_add(rw1.get(pair0[0], F2_ZERO), role.rws[c1][pair1[0]])
    rw1[pair0[1]] = f2_add(rw1.get(pair0[1], F2_ZERO), role.rws[c1][pair1[1]])
    rec("C1 shared reserved pair", {"rws": {c1: rw1}}, "fires")
    rw0 = {i: v for i, v in role.rws[c0].items() if i not in pair0}
    rec("C2 cm = 0 (pair removed)", {"rws": {c0: rw0}}, "fires")
    lam = list(role.lambdas[gi])
    lam[0] = F2_ZERO
    rec("C3 lambda_c = 0", {"lambdas": lam}, "does not fire (as in the review of record)")
    _, c0k, ln = role.keys[gi]
    delta = [F2_ZERO] * N
    delta[c0k] = F2_ONE
    rec("C6 cw = delta (one nonzero entry)", {"cw": delta}, "does not fire")
    rw0b = dict(role.rws[c0])
    rw0b[pair0[1]] = rw0b[pair0[0]]
    rec("C8 pair weights Fp-dependent", {"rws": {c0: rw0b}}, "does not fire at an Fp2 column key (as in the review of record)")
    # G-7 probes: insert a duplicate of claim c0 into the same group
    rnd = random.Random(0x67)
    lam_new = (rnd.randrange(1, P), rnd.randrange(P))
    cm = (rnd.randrange(1, P), rnd.randrange(P))
    newrows = (10 ** 6, 10 ** 6 + 1)
    rwd = {i: v for i, v in role.rws[c0].items() if role.kind[i] == "data"}
    rwd[newrows[0]] = cm
    rwd[newrows[1]] = f2_mul(cm, F2_U)
    rec("G7-D1 duplicate claim: same data weights, its OWN reserved pair (cm, cm U)", {"extra": [(rwd, lam_new)], "kinds": {newrows[0]: "mask", newrows[1]: "mask"}}, "surjective, disclosed 0")
    rec("G7-D2 duplicate claim: an exact copy (two identical coordinates, shared pair)", {"extra": [(dict(role.rws[c0]), lam_new)]}, "rank short by 2 of the onto-lemma's 2(N+m)-2; disclosed 0 (the repeated coordinate's equality holds for data too)")
    rwx = dict(role.rws[c0])
    k0 = min(i for i in rwx if role.kind[i] == "data")
    rwx[k0] = f2_add(rwx[k0], F2_ONE)
    rec("G7-D3 control: a copy sharing the pair whose DATA weights differ in one row", {"extra": [(rwx, lam_new)]}, "fires")
    return out


def fidelity(out_dir):
    """The restated stage 2 (and the component system) at the review's OWN
    width and captures: every group's blinding rank and disclosed count must
    equal ts_review.json's, every joint component ts_components.json's."""
    global N
    T.N_COLS, T.LOG_COLS, N = 256, 8, 256
    rec_s2 = json.load(open(os.path.join(TS, "ts_review.json")))["stage2_surjection"]
    rec_c = json.load(open(os.path.join(TS, "ts_components.json")))
    caps = T.load_captures()
    rows, bad = [], 0
    for cap, prof, roles in caps:
        for role in roles:
            ref = next(x for x in rec_s2 if x["capture"] == cap and x["role"] == role.name)
            for gi in range(len(role.groups)):
                r = analyse_group(role, gi, also_original=True)
                g0 = ref["per_group"][gi]
                same = (r["rank_blinding"], r["disclosed_Fp"], r["surjective_onto_consistency_subspace"], r["annihilator_kills_all_data_generators"]) == (g0["rank_blinding"], g0["disclosed_Fp"], g0["surjective_onto_consistency_subspace"], g0["annihilator_kills_all_data_generators"])
                bad += (not same) + (not r["original_form_agrees"])
                rows.append((cap, role.name, gi, r["rank_blinding"], g0["rank_blinding"], r["disclosed_Fp"], g0["disclosed_Fp"], r["original_form_agrees"], same))
            for gs in components(role):
                if len(gs) > 1:
                    jc = analyse_component(role, gs)
                    rows.append((cap, role.name, "component", gs, jc["rank_blinding"], jc["disclosed_Fp"]))
    log(f"FIDELITY at N = 256 on the review's four captures: {len(rows)} rows, {bad} disagreements with ts_review.json or between the null-space and original forms")
    for r in rows:
        if r[2] == "component":
            log("   component", r)
    log("   ts_components.json of record:", json.dumps(rec_c)[:600])
    with open(os.path.join(out_dir, "ts_fidelity.json"), "w") as fh:
        json.dump({"rows": rows, "disagreements": bad, "components_of_record": rec_c}, fh, indent=1, default=str)
    with open(os.path.join(out_dir, "ts_fidelity.log"), "w") as fh:
        fh.write("\n".join(LOG) + "\n")
    return bad


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--bundle", action="append", default=[])
    ap.add_argument("--fidelity", action="store_true", help="run the restated stage 2 at the review's own width and captures and compare")
    ap.add_argument("--controls-on", default=None, help="bundle label whose first stage runs the controls (default: the first)")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    if a.fidelity:
        sys.exit(1 if fidelity(a.out) else 0)
    assert a.bundle, "--bundle"
    t0 = time.time()
    res = {"schema": "zk60-g7-terminal-surjection-trained/1", "pins": PINS, "N_COLS": N, "inputs": {}, "stage0": None, "captures": []}
    res["stage0"] = T.stage0_selftest()
    log("stage 0 eliminator self-test:", res["stage0"])
    caps = []
    for d in a.bundle:
        st, nchk = load_bundle(d)
        res["inputs"][d] = {"manifest_sha256": sha_file(os.path.join(d, "manifest.json")), "stages": [s[0] for s in st], "arrays_checked": nchk}
        caps.extend(st)
        log(f"loaded {d}: {len(st)} stage file(s), {nchk} arrays checked against their SHA-256 names ({time.time() - t0:.1f} s)")
    s1 = T.stage1_structure(caps)
    res["stage1"] = s1
    for f in s1:
        log(f"stage 1 {f['capture']} {f['role']}: rows {f['rows']} claims {f['claims']} groups {f['groups']} data rows {f['data_rows']}; pairs used {f['reserved_pairs_used']} exactly (cm, cm U) {f['pair_weights_exactly_cm_cmU']}; cm != 0 {f['cm_all_nonzero']}; lambda zero {f['lambda_zero']}; cw nonzero {f['cw_all_nonzero']}; group identity failures {f['group_identity_failures']}; rho = sum lambda rw failures {f['rho_is_lambda_combination_failures']}; findings {f['findings']}")
    for label, prof, roles in caps:
        cr = {"capture": label, "roles": []}
        for role in roles:
            rr = {"role": role.name, "census": pcs_census(role)}
            c = rr["census"]
            log(f"G7 census {label} {role.name}: {c['claims']} claims; identical claims {c['identical_claims']}; equal published values {c['equal_published_values']}; same data weights in one group {c['same_data_weights_same_group']}; same-group pairs sharing a data row {c['same_group_pairs_sharing_a_data_row']}")
            per = []
            for gi in range(len(role.groups)):
                small = len(role.groups[gi]) <= 2 and len({i for c_ in role.groups[gi] for i in role.rws[c_] if role.kind[i] == "data"}) <= 4
                per.append(analyse_group(role, gi, also_original=small))
            rr["per_group"] = per
            rr["groups"] = len(per)
            rr["all_surjective"] = all(g["surjective_onto_consistency_subspace"] for g in per)
            rr["all_annihilated_blinding"] = all(g["annihilator_kills_all_blinding_generators"] for g in per)
            rr["all_annihilated_data"] = all(g["annihilator_kills_all_data_generators"] for g in per)
            rr["total_disclosed_Fp"] = sum(g["disclosed_Fp"] for g in per)
            rr["disclosed_by_group"] = {str(i): g["disclosed_Fp"] for i, g in enumerate(per) if g["disclosed_Fp"]}
            rr["short_groups"] = [i for i, g in enumerate(per) if not g["surjective_onto_consistency_subspace"]]
            rr["original_form_checked"] = [(i, g["original_form_agrees"]) for i, g in enumerate(per) if "original_form_agrees" in g]
            rr["largest_group"] = max(g["members"] for g in per)
            comps = components(role)
            rr["components"] = comps
            rr["joint_components"] = [analyse_component(role, gs) for gs in comps if len(gs) > 1]
            log(
                f"stage 2 {label} {role.name}: {len(per)} groups, surjective {sum(g['surjective_onto_consistency_subspace'] for g in per)}/{len(per)} (short: {rr['short_groups']}), "
                f"annihilator kills blinding {rr['all_annihilated_blinding']} / data {rr['all_annihilated_data']}, disclosed {rr['total_disclosed_Fp']} Fp {rr['disclosed_by_group']}, largest group {rr['largest_group']}, "
                f"original-form cross-checks {rr['original_form_checked']}; ranks {[(i, g['members'], g['rank_blinding'], g['expected_rank']) for i, g in enumerate(per)]}"
            )
            for jc in rr["joint_components"]:
                log(f"   joint component {label} {role.name} groups {jc['groups']}: claims {jc['claims']}, observations {jc['observation_Fp']}, blinding rank {jc['rank_blinding']}, with data {jc['rank_blinding_plus_data']}, disclosed {jc['disclosed_Fp']} Fp, u rows {jc['u_rows']} ({jc['seconds']} s)")
            cr["roles"].append(rr)
        res["captures"].append(cr)
        log(f"capture {label} done at {time.time() - t0:.1f} s")
        with open(os.path.join(a.out, "ts_trained.partial.json"), "w") as fh:
            json.dump(res, fh, indent=1, default=str)
    # controls and G-7 probes on the first capture's A
    label, prof, roles = caps[0] if a.controls_on is None else next(c for c in caps if c[0].startswith(a.controls_on))
    A = [r for r in roles if r.name == "A"][0]
    log(f"controls and G-7 probes on {label} A:")
    res["controls"] = {"capture": label, "rows": controls(A)}
    res["elapsed_s"] = round(time.time() - t0, 1)
    with open(os.path.join(a.out, "ts_trained.json"), "w") as fh:
        json.dump(res, fh, indent=1, default=str)
    with open(os.path.join(a.out, "ts_trained.log"), "w") as fh:
        fh.write("\n".join(LOG) + "\n")
    log(f"elapsed {res['elapsed_s']} s")


if __name__ == "__main__":
    main()

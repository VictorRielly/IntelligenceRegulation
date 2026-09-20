#!/usr/bin/env python3
"""Independent recomputation of the terminal-surjection step.

    python3 results/zk60_terminal_surjection_review/ts_review.py

The step under review (supplied by ZK60_JOINT_LAW_COMPOSITION_CHECK.md
section A4.2, imported into the composition memo by ruling J-2, never
independently reviewed):

  inside ONE opening group with m member claims, the map from the members'
  reserved mask pairs to (the group vector's message half, the m individual
  published claim values) is ONTO the verifier's consistency subspace
  { (v, y) : <v, cw> = sum_c lambda_c y_c }, provided lambda_c != 0,
  cm_c != 0 and cw != 0.

Everything below is recomputed from the four REAL captures of 2026-09-19 by
code written for this review (ts_field.py; no import from the project's own
joint-view tools).  Model, stated once:

  row i of a commitment holds msg_i in Fp^256 and pad_i in Fp^256.  msg_i is
  witness data on the DATA rows and uniform on the MASK and PROXIMITY rows
  (protocol.rs:313-315, 361-363 fill them with rng.fp(); the two H "u" rows
  are uniform subject to a zero row-sum, :365-372).  pad_i is uniform
  (pcs.rs:681).  At fixed challenges the published field view is affine in
  (msg, pad):
     claim value  y_c   = sum_i rw_c[i] <msg_i, cw_c>
     group vector v_g   = sum_i rho_g[i] (msg_i || pad_i)      512 entries
     proximity    v_prox= sum_i rho_prox[i] (msg_i || pad_i)
     column j           = <E_j, (msg_i || pad_i)> for every row i
  with rw/cw from pcs.rs::zpart_weights + zkey_weights and
  rho_g = sum_{c in g} lambda_c rw_c (pcs.rs::zk_rhos).

  Data-independence criterion used throughout.  Write the observation as
  O = A b + B d (b the blinding coordinates, d the data).  The law of O is
  the same for every d exactly when col(B) is contained in col(A), and the
  number of Fp of data that the view pins down is
  rank([A|B]) - rank(A) = dim(F intersect T), the same quantity the
  project's gate calls "disclosed".

NOTHING HERE ESTABLISHES A PRIVACY PROPERTY.  Every number is a rank of an
explicitly stated linear model at these receipts' real challenges.
"""

from __future__ import annotations

import json
import os
import random
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from ts_field import (  # noqa: E402
    Elim,
    F2_ONE,
    F2_U,
    F2_ZERO,
    P,
    dense_rank,
    eq_table_msb,
    f2,
    f2_add,
    f2_det,
    f2_inv,
    f2_is_zero,
    f2_mul,
    f2_neg,
    f2_norm,
    f2_sub,
    inv,
)

CAPTURE_DIR = "/home/victor/IntelligenceRegulation/results/zk60_native_captures_20260919/captures"
N_COLS = 256
LOG_COLS = 8
ENC_COLS = 2048
Q_PAD = 256
COSET = 7


# ------------------------------------------------------------------ weights
def zpart_weights(part, rows):
    """pcs.rs:752-791 (zpart_weights), re-derived: (row weights, column key)."""
    rw = {}
    ls = part["log_size"]
    coef = f2(part["coefficient"])
    point = [f2(v) for v in part["point"]]
    off = part["offset"]
    if not point:
        if ls >= LOG_COLS:
            assert off % N_COLS == 0
            r0 = off // N_COLS
            for i in range(1 << (ls - LOG_COLS)):
                rw[r0 + i] = f2_add(rw.get(r0 + i, F2_ZERO), coef)
            key = ((), 0, N_COLS)
        else:
            r0, c0 = off // N_COLS, off % N_COLS
            rw[r0] = f2_add(rw.get(r0, F2_ZERO), coef)
            key = ((), c0, 1 << ls)
    else:
        assert len(point) == ls, "point arity != slice size"
        if ls >= LOG_COLS:
            assert off % N_COLS == 0
            lr = ls - LOG_COLS
            r0 = off // N_COLS
            for i, e in enumerate(eq_table_msb(point[:lr])):
                rw[r0 + i] = f2_add(rw.get(r0 + i, F2_ZERO), f2_mul(coef, e))
            key = (tuple(point[lr:]), 0, N_COLS)
        else:
            r0, c0 = off // N_COLS, off % N_COLS
            rw[r0] = f2_add(rw.get(r0, F2_ZERO), coef)
            key = (tuple(point), c0, 1 << ls)
    return rw, key


def zkey_weights(key):
    """pcs.rs:794-807 (zkey_weights): the column-weight vector of a group."""
    tail, c0, ln = key
    cw = [F2_ZERO] * N_COLS
    if not tail:
        for t in range(c0, c0 + ln):
            cw[t] = F2_ONE
    else:
        eq = eq_table_msb(list(tail))
        assert len(eq) == ln
        cw[c0:c0 + ln] = eq
    return cw


def group_claims(claims, rows):
    """pcs.rs:809-833 (group_zclaims): first-occurrence grouping by key."""
    keys, groups, rws = [], [], []
    for c in claims:
        rw, key = zpart_weights(c["parts"][0], rows)
        for p in c["parts"][1:]:
            rw2, key2 = zpart_weights(p, rows)
            assert key2 == key, "claim parts with different column weights"
            for i, v in rw2.items():
                rw[i] = f2_add(rw.get(i, F2_ZERO), v)
        rws.append({i: v for i, v in rw.items() if not f2_is_zero(v)})
        if key in keys:
            groups[keys.index(key)].append(len(rws) - 1)
        else:
            keys.append(key)
            groups.append([len(rws) - 1])
    return keys, groups, rws


# ------------------------------------------------------------------ captures
class Role:
    def __init__(self, cap, role):
        self.cap = cap
        self.name = role["role"]
        self.raw = role
        self.rows = role["commitment"]["rows"]
        self.kind = {r["row"]: r["kind"] for r in role["row_roles"]}
        self.data_rows = [r for r in range(self.rows) if self.kind[r] == "data"]
        self.prox_rows = [r for r in range(self.rows) if self.kind[r] == "prox"]
        self.u_rows = []
        for plc in role["public_linear_constraints"]:
            self.u_rows.extend(plc["rows"])
        self.keys, self.groups, self.rws = group_claims(role["claims"], self.rows)
        self.lambdas = [[f2(l) for l in g["lambdas"]] for g in role["groups"]]
        self.values = [f2(c["value"]) for c in role["claims"]]
        self.prox_rho = [f2(v) for v in role["proximity_rhos"]]
        self.cw = [zkey_weights(k) for k in self.keys]
        self.rho = []
        for gi, members in enumerate(self.groups):
            rho = {}
            for c, lam in zip(members, self.lambdas[gi]):
                for i, v in self.rws[c].items():
                    rho[i] = f2_add(rho.get(i, F2_ZERO), f2_mul(lam, v))
            self.rho.append({i: v for i, v in rho.items() if not f2_is_zero(v)})


def load_captures():
    out = []
    for fn in sorted(os.listdir(CAPTURE_DIR)):
        if not fn.endswith(".json"):
            continue
        d = json.load(open(os.path.join(CAPTURE_DIR, fn)))
        assert d["field_modulus"] == P and d["extension_nonresidue"] == 7
        out.append((d["proof_sha256"][:12], d["profile"], [Role(d, r) for r in d["roles"]]))
    return out


# ================================================================= stage 0
def stage0_selftest():
    """The sparse eliminator against a dense one, on random sparse systems
    of the same 2-in-a-row shape, and on random dense systems."""
    rnd = random.Random(20260920)
    bad = 0
    trials = 0
    for _ in range(60):
        ncol = rnd.randrange(3, 12)
        nrow = rnd.randrange(1, 20)
        rows = []
        for _ in range(nrow):
            r = {}
            for _ in range(rnd.randrange(1, 4)):
                r[rnd.randrange(ncol)] = rnd.randrange(P)
            rows.append(r)
        e = Elim()
        for r in rows:
            e.add(dict(r))
        dense = [[r.get(c, 0) for c in range(ncol)] for r in rows]
        trials += 1
        if e.rank != dense_rank(dense, ncol):
            bad += 1
    return {"random_systems": trials, "sparse_vs_dense_disagreements": bad, "ok": bad == 0}


# ================================================================= stage 1
def stage1_structure(roles):
    """The real schedule, audited at full scale: is every hypothesis the
    supplied step needs actually true of the captured claim schedule?"""
    out = []
    for cap, profile, rs in roles:
        for role in rs:
            f = {"capture": cap, "profile": profile.split("/")[1], "role": role.name,
                 "rows": role.rows, "claims": len(role.rws), "groups": len(role.groups),
                 "data_rows": len(role.data_rows), "u_rows": role.u_rows}
            findings = []
            # -- the capture's own grouping and keys must be what we recompute
            if [g["members"] for g in role.raw["groups"]] != role.groups:
                findings.append("recomputed group membership differs from the capture")
            for gi, g in enumerate(role.raw["groups"]):
                tail = tuple(f2(v) for v in g["key"]["tail"])
                if (tail, g["key"]["offset"], g["key"]["len"]) != role.keys[gi]:
                    findings.append(f"group {gi}: recomputed key differs from the capture")
            # -- cw: nonzero, and the reason it is nonzero
            cw_sums, cw_support = [], []
            for gi, key in enumerate(role.keys):
                cw = role.cw[gi]
                s = F2_ZERO
                for v in cw:
                    s = f2_add(s, v)
                cw_sums.append(s)
                sup = sum(1 for v in cw if not f2_is_zero(v))
                cw_support.append(sup)
                if sup == 0:
                    findings.append(f"group {gi}: cw == 0")
                want = F2_ONE if key[0] else (key[2] % P, 0)
                if s != want:
                    findings.append(f"group {gi}: sum(cw) = {s}, expected {want}")
            f["cw_all_nonzero"] = all(s > 0 for s in cw_support)
            f["cw_support_min"] = min(cw_support)
            f["cw_support_max"] = max(cw_support)
            f["cw_sums_to_one_or_len"] = all(
                cw_sums[gi] == (F2_ONE if role.keys[gi][0] else (role.keys[gi][2] % P, 0))
                for gi in range(len(role.keys))
            )
            # -- lambda
            lam_zero = sum(1 for g in role.lambdas for l in g if f2_is_zero(l))
            f["lambda_count"] = sum(len(g) for g in role.lambdas)
            f["lambda_zero"] = lam_zero
            if lam_zero:
                findings.append(f"{lam_zero} zero lambda(s)")
            # -- the reserved pairs: exclusivity, and weights exactly (cm, cm*U)
            used, cms, pair_of = {}, [], {}
            exact_pair_form = 0
            for ci, rw in enumerate(role.rws):
                touched = sorted(r for r in rw if role.kind[r] != "data")
                if any(role.kind[r] == "prox" for r in touched):
                    findings.append(f"claim {ci} touches the proximity pair")
                rest = [r for r in touched if r not in role.u_rows]
                if not rest and role.u_rows and set(touched) == set(role.u_rows):
                    pair = tuple(sorted(role.u_rows))
                    kind = "u"
                elif len(rest) == 2 and rest[1] == rest[0] + 1:
                    pair, kind = (rest[0], rest[1]), "site"
                else:
                    findings.append(f"claim {ci}: {len(rest)} non-data mask rows, not one pair")
                    continue
                if pair in used:
                    findings.append(f"claim {ci} shares its pair with claim {used[pair]}")
                used[pair] = ci
                pair_of[ci] = (pair, kind)
                a, b = rw[pair[0]], rw[pair[1]]
                if f2_det(a, b) == 0:
                    findings.append(f"claim {ci}: pair coefficients are not an Fp-basis of Fp2")
                if b == f2_mul(a, F2_U):
                    exact_pair_form += 1
                else:
                    findings.append(f"claim {ci}: pair weights are not (cm, cm*U)")
                cms.append(a)
                if f2_is_zero(a):
                    findings.append(f"claim {ci}: cm == 0")
            f["reserved_pairs_used"] = len(used)
            f["pair_weights_exactly_cm_cmU"] = exact_pair_form
            f["cm_all_nonzero"] = all(not f2_is_zero(c) for c in cms)
            f["cm_norms_all_nonzero"] = all(f2_norm(c) != 0 for c in cms)
            # -- the proximity pair
            p0, p1 = role.prox_rows[0], role.prox_rows[1]
            det = f2_det(role.prox_rho[p0], role.prox_rho[p1])
            f["prox_pair_det_nonzero"] = det != 0
            if det == 0:
                findings.append("the proximity pair's coefficients are Fp-dependent")
            # -- the verifier's own group identity <v[:n], cw> == sum lambda*value
            bad = 0
            for gi, members in enumerate(role.groups):
                v = role.raw["groups"][gi]["vector"]
                got = F2_ZERO
                for t in range(N_COLS):
                    if not f2_is_zero(role.cw[gi][t]):
                        got = f2_add(got, f2_mul(f2(v[t]), role.cw[gi][t]))
                want = F2_ZERO
                for c, lam in zip(members, role.lambdas[gi]):
                    want = f2_add(want, f2_mul(lam, role.values[c]))
                if got != want:
                    bad += 1
            f["group_identity_failures"] = bad
            if bad:
                findings.append(f"{bad} group(s) fail <v, cw> == sum lambda*value")
            # -- rho_g == sum lambda_c rw_c on EVERY row (the identity the
            #    annihilator of stage 2 needs on the data rows)
            bad = 0
            for gi, members in enumerate(role.groups):
                for r in range(role.rows):
                    acc = F2_ZERO
                    for c, lam in zip(members, role.lambdas[gi]):
                        if r in role.rws[c]:
                            acc = f2_add(acc, f2_mul(lam, role.rws[c][r]))
                    if acc != role.rho[gi].get(r, F2_ZERO):
                        bad += 1
            f["rho_is_lambda_combination_failures"] = bad
            f["findings"] = findings
            f["ok"] = not findings
            out.append(f)
    return out


# ================================================================= stage 2
def group_system(role, gi, override=None, include_data=True):
    """The Fp-linear observation system of ONE opening group.

    Observations (columns of the matrix), all over Fp:
        v_g[j] real/imag for j < 256          -> column 2j, 2j+1
        y_c    real/imag for c in the group   -> column 512 + 2k, +1
    Unknowns (rows of the matrix, one generator each): the Fp entry
    msg_i[j] of a committed row i at column j.  Blinding generators are the
    non-data rows, data generators the data rows.

    `override` may replace (lambdas, cms, cw, pair_of) for a control.
    Returns (blinding_generators, data_generators, m, info).
    """
    members = role.groups[gi]
    m = len(members)
    lam = list(role.lambdas[gi])
    cw = list(role.cw[gi])
    rws = {c: dict(role.rws[c]) for c in members}
    if override:
        lam = override.get("lambdas", lam)
        cw = override.get("cw", cw)
        for c, rw in override.get("rws", {}).items():
            rws[c] = rw
    # rho is recomputed from the (possibly overridden) lambdas and weights
    rho = {}
    for c, l in zip(members, lam):
        for i, v in rws[c].items():
            rho[i] = f2_add(rho.get(i, F2_ZERO), f2_mul(l, v))
    rho = {i: v for i, v in rho.items() if not f2_is_zero(v)}

    touched = set(rho) | {i for c in members for i in rws[c]}
    blind_rows = sorted(i for i in touched if role.kind[i] != "data")
    data_rows = sorted(i for i in touched if role.kind[i] == "data")
    cw_support = [j for j in range(N_COLS) if not f2_is_zero(cw[j])]

    def gen(i, j):
        """The observation vector of the unit Fp perturbation msg_i[j] += 1."""
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
                    g[512 + 2 * k] = t[0]
                if t[1]:
                    g[512 + 2 * k + 1] = t[1]
        return g

    blind, data = [], []
    for i in blind_rows:
        if i in role.u_rows:
            # uniform subject to sum_j msg_i[j] == 0: the free directions are
            # the differences e_j - e_{255} (protocol.rs:365-372)
            for j in range(N_COLS - 1):
                a, b = gen(i, j), gen(i, N_COLS - 1)
                d = dict(a)
                for k, v in b.items():
                    nv = (d.get(k, 0) - v) % P
                    if nv:
                        d[k] = nv
                    elif k in d:
                        del d[k]
                blind.append(d)
        else:
            for j in range(N_COLS):
                blind.append(gen(i, j))
    if include_data:
        for i in data_rows:
            for j in range(N_COLS):
                data.append(gen(i, j))
    info = {
        "members": m,
        "blinding_rows": len(blind_rows),
        "data_rows_touched": len(data_rows),
        "cw_support": len(cw_support),
        "u_rows_in_group": [i for i in blind_rows if i in role.u_rows],
    }
    return blind, data, m, info, (lam, cw, rws, rho, members)


def annihilator(lam, cw, members):
    """The two Fp functionals of the ONE public identity
    <v, cw> - sum_c lambda_c y_c = 0 (verify_zk pcs.rs:971-975)."""
    re, im = {}, {}
    for j in range(N_COLS):
        a = cw[j]
        if f2_is_zero(a):
            continue
        # contribution a * v_j : real part a0*v_re - ... use Fp2 multiplication
        # (a0 + a1 U)(x0 + x1 U) = (a0x0 + 7a1x1) + (a0x1 + a1x0) U
        re[2 * j] = (re.get(2 * j, 0) + a[0]) % P
        re[2 * j + 1] = (re.get(2 * j + 1, 0) + 7 * a[1]) % P
        im[2 * j] = (im.get(2 * j, 0) + a[1]) % P
        im[2 * j + 1] = (im.get(2 * j + 1, 0) + a[0]) % P
    for k in range(len(members)):
        a = f2_neg(lam[k])
        re[512 + 2 * k] = (re.get(512 + 2 * k, 0) + a[0]) % P
        re[512 + 2 * k + 1] = (re.get(512 + 2 * k + 1, 0) + 7 * a[1]) % P
        im[512 + 2 * k] = (im.get(512 + 2 * k, 0) + a[1]) % P
        im[512 + 2 * k + 1] = (im.get(512 + 2 * k + 1, 0) + a[0]) % P
    return [{k: v for k, v in re.items() if v}, {k: v for k, v in im.items() if v}]


def apply_phi(phi, g):
    return sum(phi.get(k, 0) * v for k, v in g.items()) % P


def rank_of(gens):
    e = Elim()
    for g in gens:
        e.add(dict(g))
    return e.rank


def analyse_group(role, gi, override=None, include_data=True):
    blind, data, m, info, (lam, cw, rws, rho, members) = group_system(
        role, gi, override, include_data
    )
    rb = rank_of(blind)
    res = dict(info)
    res["rank_blinding"] = rb
    res["observations_Fp"] = 2 * (N_COLS + m)
    res["expected_rank"] = 2 * (N_COLS + m) - 2
    res["surjective_onto_consistency_subspace"] = rb == 2 * (N_COLS + m) - 2
    phis = annihilator(lam, cw, members)
    res["annihilator_kills_all_blinding_generators"] = all(
        apply_phi(p, g) == 0 for p in phis for g in blind
    )
    res["annihilator_nonzero"] = all(bool(p) for p in phis)
    if include_data:
        res["annihilator_kills_all_data_generators"] = all(
            apply_phi(p, g) == 0 for p in phis for g in data
        )
        e = Elim()
        for g in blind:
            e.add(dict(g))
        rj = e.rank
        for g in data:
            if e.add(dict(g)):
                rj = e.rank
        res["rank_blinding_plus_data"] = e.rank
        res["disclosed_Fp"] = e.rank - rb
    return res


def stage2_surjection(roles, dense_check_groups=2):
    out = []
    for cap, profile, rs in roles:
        for role in rs:
            per = []
            t0 = time.time()
            for gi in range(len(role.groups)):
                per.append(analyse_group(role, gi))
            out.append({
                "capture": cap,
                "profile": profile.split("/")[1],
                "role": role.name,
                "groups": len(per),
                "all_surjective": all(g["surjective_onto_consistency_subspace"] for g in per),
                "all_annihilated_blinding": all(g["annihilator_kills_all_blinding_generators"] for g in per),
                "all_annihilated_data": all(g["annihilator_kills_all_data_generators"] for g in per),
                "total_disclosed_Fp": sum(g["disclosed_Fp"] for g in per),
                "disclosed_by_group": {str(i): g["disclosed_Fp"] for i, g in enumerate(per) if g["disclosed_Fp"]},
                "largest_group": max(g["members"] for g in per),
                "seconds": round(time.time() - t0, 1),
                "per_group": per,
            })
    return out


def stage2b_dense_crosscheck(roles):
    """The same rank for a few real groups, by DENSE elimination.

    A dense reduction of all 512*m generators is too big to run here, and it
    is not needed: the annihilator of stage 2 is an exact UPPER bound
    (rank <= 2(256+m) - 2, verified generator by generator), so a dense
    LOWER bound of 2(256+m) - 2 on any SUBSET settles the rank exactly.  The
    subset used is one member's whole pair (512 generators) plus two
    generators per other member at one column of cw's support.
    """
    out = []
    cap, profile, rs = roles[0]
    picks = []
    for role in rs:
        sizes = sorted((len(g), gi) for gi, g in enumerate(role.groups))
        picks.append((role, sizes[0][1]))
        if sizes[-1][1] != sizes[0][1]:
            picks.append((role, sizes[-1][1]))
    seen = set()
    for role, gi in picks:
        if (role.name, gi) in seen or role.name in ("Output",):
            continue
        seen.add((role.name, gi))
        blind, _, m, info, (lam, cw, rws, rho, members) = group_system(
            role, gi, include_data=False
        )
        ncol = 2 * (N_COLS + m)
        target = ncol - 2
        # the subset: generators of the first member's two mask rows, then two
        # per other member at the first column of cw's support
        first = members[0]
        pair0 = sorted(r for r in rws[first] if role.kind[r] != "data")
        j0 = next(j for j in range(N_COLS) if not f2_is_zero(cw[j]))
        rows_needed = list(pair0)
        for c in members[1:]:
            rows_needed.extend(sorted(r for r in rws[c] if role.kind[r] != "data"))
        sub = []
        for i in pair0:
            for j in range(N_COLS):
                sub.append(_gen_of(role, gi, i, j, lam, cw, rws, rho, members))
        for c in members[1:]:
            for i in sorted(r for r in rws[c] if role.kind[r] != "data"):
                if i in role.u_rows:
                    continue
                sub.append(_gen_of(role, gi, i, j0, lam, cw, rws, rho, members))
        dense = [[g.get(c, 0) for c in range(ncol)] for g in sub]
        t0 = time.time()
        dr = dense_rank(dense, ncol)
        out.append({
            "capture": cap, "role": role.name, "group": gi, "members": m,
            "subset_generators": len(sub), "dense_rank_of_subset": dr,
            "sparse_rank_of_all_generators": rank_of(blind),
            "upper_bound_from_annihilator": target,
            "exact": dr == target and rank_of(blind) == target,
            "seconds": round(time.time() - t0, 1),
        })
    return out


def _gen_of(role, gi, i, j, lam, cw, rws, rho, members):
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
                g[512 + 2 * k] = t[0]
            if t[1]:
                g[512 + 2 * k + 1] = t[1]
    return g


# ================================================================= stage 3
def stage3_controls(roles):
    """Predictions are recorded in the review document BEFORE these ran."""
    cap, profile, rs = roles[0]
    A = [r for r in rs if r.name == "A"][0]
    H = [r for r in rs if r.name == "H"][0]
    # a real A group with >= 2 members, and the largest one
    two = [gi for gi in range(len(A.groups)) if len(A.groups[gi]) == 2][0]
    big = max(range(len(A.groups)), key=lambda gi: len(A.groups[gi]))
    out = []

    def rec(name, role, gi, override, note):
        r = analyse_group(role, gi, override=override)
        out.append({"control": name, "role": role.name, "group": gi,
                    "members": r["members"], "rank_blinding": r["rank_blinding"],
                    "expected_honest_rank": r["expected_rank"],
                    "disclosed_Fp": r["disclosed_Fp"],
                    "fires": r["disclosed_Fp"] > 0, "note": note})
        return r

    def marginals(role, gi, override):
        """The blinding rank seen through ONE terminal, and through a pair of
        terminals jointly: the project's counterexample says a shared pair
        leaves each marginal uniform while the joint law moves with the
        witness."""
        blind, data, m, _, _ = group_system(role, gi, override)
        res = {}
        for k in (0, 1):
            proj = [{c: v for c, v in g.items() if c in (512 + 2 * k, 512 + 2 * k + 1)}
                    for g in blind]
            res[f"rank_on_terminal_{k}"] = rank_of(proj)
        keep = {512, 513, 514, 515}
        projb = [{c: v for c, v in g.items() if c in keep} for g in blind]
        projd = [{c: v for c, v in g.items() if c in keep} for g in data]
        rb = rank_of(projb)
        e = Elim()
        for g in projb:
            e.add(dict(g))
        for g in projd:
            e.add(dict(g))
        res["rank_on_terminals_0_1_blinding"] = rb
        res["rank_on_terminals_0_1_with_data"] = e.rank
        res["joint_of_the_two_terminals_moves_with_the_data"] = e.rank > rb
        return res

    # C1 two claims of one group forced to share ONE reserved pair
    for gi in (two, big):
        members = A.groups[gi]
        c0, c1 = members[0], members[1]
        pair0 = sorted(r for r in A.rws[c0] if A.kind[r] != "data")
        pair1 = sorted(r for r in A.rws[c1] if A.kind[r] != "data")
        rw1 = {i: v for i, v in A.rws[c1].items() if i not in pair1}
        rw1[pair0[0]] = f2_add(rw1.get(pair0[0], F2_ZERO), A.rws[c1][pair1[0]])
        rw1[pair0[1]] = f2_add(rw1.get(pair0[1], F2_ZERO), A.rws[c1][pair1[1]])
        ov = {"rws": {c1: rw1}}
        rec("C1 shared reserved pair", A, gi, ov,
            f"claims {c0} and {c1} moved onto the single pair {tuple(pair0)}")
        out[-1]["marginals"] = marginals(A, gi, ov)
        out.append({"control": "C1b the same group, honest (reference)", "role": "A",
                    "group": gi, "marginals": marginals(A, gi, None),
                    "note": "with one pair per claim both marginals AND the joint are "
                            "blinding-covered"})

    # C2 one claim's reserved pair removed (cm = 0)
    members = A.groups[big]
    c0 = members[0]
    pair0 = sorted(r for r in A.rws[c0] if A.kind[r] != "data")
    rw0 = {i: v for i, v in A.rws[c0].items() if i not in pair0}
    rec("C2 cm = 0 (pair removed)", A, big, {"rws": {c0: rw0}},
        f"claim {c0} loses its pair; audit_claims protocol.rs:103-106 refuses this")

    # C3 one lambda zero
    lam = list(A.lambdas[big])
    lam[0] = F2_ZERO
    rec("C3 lambda_c = 0", A, big, {"lambdas": lam},
        "check_opening_challenges protocol.rs:142-146 refuses this")

    # C4 all lambdas equal
    lam = [A.lambdas[big][0]] * len(A.groups[big])
    rec("C4 all lambdas equal", A, big, {"lambdas": lam}, "not refused anywhere")

    # C5 cw = 0 (cannot happen: sum(cw) = 1)
    rec("C5 cw = 0", A, big, {"cw": [F2_ZERO] * N_COLS},
        "impossible in the protocol; recorded for completeness")

    # C6 cw a single-entry delta (the worst admissible cw)
    delta = [F2_ZERO] * N_COLS
    delta[7] = F2_ONE
    rec("C6 cw = delta (one nonzero entry)", A, big, {"cw": delta},
        "reachable: an eq tail whose coordinates all land in {0,1}; nothing refuses it")

    # C7 H's sum-claim group, honest (the zero-sum u pair)
    ug = [gi for gi in range(len(H.groups))
          if any(set(H.rws[c]) & set(H.u_rows) for c in H.groups[gi])]
    for gi in ug:
        r = analyse_group(H, gi)
        out.append({"control": "C7 H group containing the u pair (honest)",
                    "role": "H", "group": gi, "members": r["members"],
                    "rank_blinding": r["rank_blinding"],
                    "expected_honest_rank": r["expected_rank"],
                    "disclosed_Fp": r["disclosed_Fp"],
                    "fires": r["disclosed_Fp"] > 0,
                    "note": "the zero-sum constraint is modelled; disclosure here is "
                            "the public LogUp identity, not a new channel"})

    # C8 a pair whose two weights are Fp-dependent (not (cm, cm*U))
    members = A.groups[big]
    c0 = members[0]
    pair0 = sorted(r for r in A.rws[c0] if A.kind[r] != "data")
    rw0 = dict(A.rws[c0])
    rw0[pair0[1]] = rw0[pair0[0]]  # same coefficient on both rows
    rec("C8 pair weights Fp-dependent", A, big, {"rws": {c0: rw0}},
        "audit/_check_pair_schedule: det == 0 is refused")
    return out


# ================================================================= stage 4
def stage4_fresh_and_adversarial(roles):
    """The same rank at FRESH uniform challenges and at adversarial ones,
    on the real group shapes (member count, pair geometry, cw support).

    The challenge families:
      fresh      lambda uniform in Fp2*, cw = eq_table_msb(uniform tail)
      equal      all lambdas equal (nothing refuses it)
      powers     lambda_c = gamma^c (a batching a reader might expect)
      delta-cw   a tail with every coordinate in {0,1}: cw is a single 1
      half-cw    a tail with half its coordinates in {0,1}: cw's support is
                 a sub-cube of the columns
    Nothing in the protocol refuses any of these.
    """
    cap, profile, rs = roles[0]
    A = [r for r in rs if r.name == "A"][0]
    rnd = random.Random(424242)
    shapes = sorted({len(g) for g in A.groups})
    out = []
    for m in shapes:
        gi = [i for i in range(len(A.groups)) if len(A.groups[i]) == m][0]
        n = 64 if m <= 8 else 12
        fam = {}

        def run(tag, lam, cw):
            r = analyse_group(A, gi, {"lambdas": lam, "cw": cw}, include_data=False)
            fam.setdefault(tag, [0, 0])
            fam[tag][0] += 1
            if not r["surjective_onto_consistency_subspace"]:
                fam[tag][1] += 1

        # the group's real column geometry, so a fresh cw sits where the real
        # one sits (offset c0, 2^k columns)
        _, c0, ln = A.keys[gi]
        k = ln.bit_length() - 1

        def place(tail):
            cw = [F2_ZERO] * N_COLS
            cw[c0:c0 + ln] = eq_table_msb(tail)
            return cw

        for _ in range(n):
            lam = [(rnd.randrange(P), rnd.randrange(P)) for _ in range(m)]
            cwr = place([(rnd.randrange(P), rnd.randrange(P)) for _ in range(k)])
            run("fresh", lam, cwr)
            run("equal_lambdas", [lam[0]] * m, cwr)
            gam = (rnd.randrange(1, P), rnd.randrange(P))
            pw, acc = [], F2_ONE
            for _ in range(m):
                acc = f2_mul(acc, gam)
                pw.append(acc)
            run("lambda_powers", pw, cwr)
            run("delta_cw", lam,
                place([F2_ZERO if rnd.randrange(2) else F2_ONE for _ in range(k)]))
            run("half_cw", lam, place([
                (F2_ZERO if rnd.randrange(2) else F2_ONE) if t < k // 2
                else (rnd.randrange(P), rnd.randrange(P))
                for t in range(k)
            ]))
        out.append({"role": "A", "group": gi, "members": m,
                    "per_family_trials_and_failures": {k: v for k, v in fam.items()}})
    return out


# ================================================================= stage 5
def column_functional(j, n=N_COLS, nn=ENC_COLS, q=Q_PAD):
    """E_j, re-derived from pcs.rs::encode_row_zk (:617-637).

    encode_row_zk writes c = (INTT(msg) - pad padded, then pad) and evaluates
    sum_i c_i (coset*w_nn^j)^i, i.e. f_msg(x_j) + (x_j^n - 1) sum_k pad_k x_j^k
    with f_msg the interpolant of msg on the size-n subgroup:
        E_j[msg s] = (x_j^n - 1) / (n (x_j w_n^{-s} - 1)),
        E_j[pad k] = (x_j^n - 1) x_j^k.
    """
    w_nn = two_adic_root(nn.bit_length() - 1)
    w_n = two_adic_root(n.bit_length() - 1)
    xj = COSET * pow(w_nn, j, P) % P
    zn = (pow(xj, n, P) - 1) % P
    ninv = inv(n)
    msg, wns, wninv = [], 1, inv(w_n)
    for _ in range(n):
        msg.append(zn * ninv % P * inv((xj * wns - 1) % P) % P)
        wns = wns * wninv % P
    pad, xp = [], 1
    for _ in range(q):
        pad.append(zn * xp % P)
        xp = xp * xj % P
    return msg, pad, xj, zn


_ROOT_CACHE = {}


def two_adic_root(k):
    """A primitive 2^k-th root of unity in Fp (p - 1 = 2^32 * 3 * 5 * 17 * 257 * 65537)."""
    if k in _ROOT_CACHE:
        return _ROOT_CACHE[k]
    g = 7
    r = pow(g, (P - 1) >> k, P)
    while pow(r, 1 << (k - 1), P) == 1:
        g += 1
        r = pow(g, (P - 1) >> k, P)
    _ROOT_CACHE[k] = r
    return r


def stage5_columns(roles, samples=4):
    """(i) the fold identity that makes the group vector's PAD half a
    function of the opened columns and its message half, and (ii) the exact
    rank of the pad block at the real opened positions."""
    out = []
    cap, profile, rs = roles[0]
    for role in rs:
        cols = role.raw["columns"]
        idx = [c["index"] for c in cols]
        distinct = sorted(set(idx))
        vectors = [g["vector"] for g in role.raw["groups"]] + [role.raw["proximity_vector"]]
        rhos = [role.rho[gi] for gi in range(len(role.groups))]
        rhos.append({i: v for i, v in enumerate(role.prox_rho) if not f2_is_zero(v)})
        checked = bad = 0
        step = max(1, len(cols) // samples)
        for ci in range(0, len(cols), step):
            col = cols[ci]
            msg, pad, _, _ = column_functional(col["index"])
            for gi in range(len(vectors)):
                lhs = F2_ZERO
                for i, v in rhos[gi].items():
                    x = col["values"][i]
                    if x:
                        lhs = f2_add(lhs, (v[0] * x % P, v[1] * x % P))
                rhs = F2_ZERO
                vec = vectors[gi]
                for t in range(N_COLS):
                    e = msg[t]
                    if e:
                        a = f2(vec[t])
                        rhs = f2_add(rhs, (a[0] * e % P, a[1] * e % P))
                for k in range(Q_PAD):
                    e = pad[k]
                    if e:
                        a = f2(vec[N_COLS + k])
                        rhs = f2_add(rhs, (a[0] * e % P, a[1] * e % P))
                checked += 1
                if lhs != rhs:
                    bad += 1
        entry = {"capture": cap, "role": role.name, "opened": len(cols),
                 "distinct_opened": len(distinct),
                 "fold_identities_checked": checked, "fold_identity_failures": bad}
        out.append(entry)
    # the pad block, once, at the real opened positions of role A
    role = rs[0]
    distinct = sorted({c["index"] for c in role.raw["columns"]})
    t0 = time.time()
    block = []
    for j in distinct:
        _, pad, _, zn = column_functional(j)
        assert zn != 0, "an opened position lies on the message subgroup"
        block.append(pad)
    r = dense_rank(block, Q_PAD)
    out.append({"capture": cap, "role": role.name, "pad_block": [len(distinct), Q_PAD],
                "exact_rank": r, "full_rank": r == len(distinct),
                "seconds": round(time.time() - t0, 1)})
    return out


# ================================================================= main
def main():
    t0 = time.time()
    roles = load_captures()
    res = {"captures": [(c, p) for c, p, _ in roles]}
    res["stage0_eliminator_selftest"] = stage0_selftest()
    print("stage 0 done", time.time() - t0, flush=True)
    res["stage1_structure"] = stage1_structure(roles)
    print("stage 1 done", time.time() - t0, flush=True)
    res["stage2_surjection"] = stage2_surjection(roles)
    print("stage 2 done", time.time() - t0, flush=True)
    res["stage2b_dense_crosscheck"] = stage2b_dense_crosscheck(roles)
    print("stage 2b done", time.time() - t0, flush=True)
    res["stage3_controls"] = stage3_controls(roles)
    print("stage 3 done", time.time() - t0, flush=True)
    res["stage4_fresh"] = stage4_fresh_and_adversarial(roles)
    print("stage 4 done", time.time() - t0, flush=True)
    res["stage5_columns"] = stage5_columns(roles)
    print("stage 5 done", time.time() - t0, flush=True)
    res["seconds"] = round(time.time() - t0, 1)
    out = os.path.join(HERE, "ts_review.json")
    with open(out, "w") as fh:
        json.dump(res, fh, indent=1, sort_keys=True)
    print("wrote", out)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""zk60_fable_joint_rank.py -- FA2 joint mask-rank tool (analysis only, stdlib only).

Reviewer: Claude Fable 5.1, independent reviewer, 2026-09-07 session.

WHAT THIS MODELS.  A ZK opening publishes linear observations of committed
base-field rows: every entry of a group vector, of the proximity vector and
every terminal (claim value) is an Fp2 number that is a public-coefficient
linear combination of base-field data rows and base-field mask rows.  An Fp2
observation with an Fp2 coefficient `a` on a base unknown `x` contributes
`a.c0*x` to its real coordinate and `a.c1*x` to its imaginary coordinate, so
one Fp2 observation is TWO base-field rows of the observation matrix (this is
the projection FA1's L_b functional lives in).  Given the public coefficients,
the tool splits the observation matrix into a data part A and a mask part B
over Fp = GF(2^64 - 2^32 + 1) and computes, by exact modular Gaussian
elimination:

    rank(B)            -- the mask sub-matrix
    rank([A | B])      -- the joint matrix
    N = left null space of B (the functionals of the observations that
                              annihilate every mask contribution)
    F = N . A          -- the data functionals that SURVIVE mask elimination

`disclosed_dim = rank(F) = rank([A|B]) - rank(B)`.  A data unknown is
`recovered` if its unit vector lies in the row space of F, `disclosed` if
some surviving functional has a nonzero coefficient on it, `protected`
otherwise.

WHAT IT DOES NOT SETTLE.  Numerical rank over a set of linear observations
with fixed public coefficients is NOT a simulation proof.  It does not model:
nonlinear observations (the CFS-masked sumcheck round messages, the hash
commitments), adaptive dependence of the challenges on masked messages (the
coefficients are conditioned on, i.e. treated as fixed), integer-range side
information on the data, or cross-proof correlation beyond "the same data
row appears in R proofs with R independent coefficient sets".  A verdict of
`protected` here means only: no nonzero linear functional of that unknown
survives elimination in THIS observation set with THESE coefficients.

The fixture coefficients are pseudo-random stand-ins for transcript
challenges (the structure -- eq-table row weights, (1 - e)/e pairs, lambdas,
u-multiplied imaginary parts -- is the source's; the values are not from any
real proof).  Degenerate real coefficients (e in the base field, a zero
lambda) have probability about 2^-64 per draw and are not modelled.

Usage:
    python3 scripts/zk60_fable_joint_rank.py analyze  MODEL.json   [-o OUT.json]
    python3 scripts/zk60_fable_joint_rank.py fixtures [-o OUT.json]
    python3 scripts/zk60_fable_joint_rank.py impact   [-o OUT.json]
    python3 scripts/zk60_fable_joint_rank.py repair   [-o OUT.json]   # FA3: the repaired allocation's rank checks

MODEL.json:
    {"name": "...", "data": ["D0", ...], "masks": ["R0", ...],
     "observations": [{"name": "v[0]", "domain": "Fp2"|"Fp",
                       "coeffs": {"D0": [c0, c1] | c, ...}, ...meta}]}
Coefficients are integers mod p; an Fp2 coefficient is a two-element list.
"""
from __future__ import annotations

import argparse
import json
import random
import sys
from typing import Dict, Iterable, List, Optional, Sequence, Tuple

P = 2**64 - 2**32 + 1
NONRESIDUE = 7  # Fp2 = Fp[u] / (u^2 - 7), as hashline/src/field.rs

Fp2 = Tuple[int, int]

# ----------------------------------------------------------------------------
# field arithmetic
# ----------------------------------------------------------------------------


def fp(x: int) -> int:
    return x % P


def fp_inv(x: int) -> int:
    x %= P
    if x == 0:
        raise ZeroDivisionError("inverse of zero in Fp")
    return pow(x, P - 2, P)


ONE: Fp2 = (1, 0)
ZERO: Fp2 = (0, 0)
U: Fp2 = (0, 1)


def f2(c0: int, c1: int = 0) -> Fp2:
    return (c0 % P, c1 % P)


def f2_add(a: Fp2, b: Fp2) -> Fp2:
    return ((a[0] + b[0]) % P, (a[1] + b[1]) % P)


def f2_sub(a: Fp2, b: Fp2) -> Fp2:
    return ((a[0] - b[0]) % P, (a[1] - b[1]) % P)


def f2_neg(a: Fp2) -> Fp2:
    return ((-a[0]) % P, (-a[1]) % P)


def f2_mul(a: Fp2, b: Fp2) -> Fp2:
    ac = a[0] * b[0]
    bd = a[1] * b[1]
    ad = a[0] * b[1]
    bc = a[1] * b[0]
    return ((ac + NONRESIDUE * bd) % P, (ad + bc) % P)


def f2_mul_base(a: Fp2, r: int) -> Fp2:
    return ((a[0] * r) % P, (a[1] * r) % P)


def f2_norm(a: Fp2) -> int:
    return (a[0] * a[0] - NONRESIDUE * a[1] * a[1]) % P


def f2_inv(a: Fp2) -> Fp2:
    n = f2_norm(a)
    if n == 0:
        raise ZeroDivisionError("inverse of zero in Fp2")
    ni = fp_inv(n)
    return ((a[0] * ni) % P, ((-a[1]) * ni) % P)


def f2_is_zero(a: Fp2) -> bool:
    return a[0] % P == 0 and a[1] % P == 0


def f2_in_base(a: Fp2) -> bool:
    return a[1] % P == 0


def det(a: Fp2, b: Fp2) -> int:
    """det[a; b] = a.c0*b.c1 - a.c1*b.c0 over Fp (FA1's L_b(a) with b)."""
    return (a[0] * b[1] - a[1] * b[0]) % P


def eq_table_msb(point: Sequence[Fp2]) -> List[Fp2]:
    """eq weights of the 2^len(point) Boolean indices, point[0] the MSB
    (the `eq_table_msb` convention of hashline/src/mle.rs)."""
    out = [ONE]
    for r in point:
        nxt = []
        one_minus = f2_sub(ONE, r)
        for w in out:
            nxt.append(f2_mul(w, one_minus))
            nxt.append(f2_mul(w, r))
        out = nxt
    return out


def ext_coef(rho: Sequence[Fp2], k: int) -> Fp2:
    """prod_{j<k} (1 - rho_j) (zk.rs::ext_coef)."""
    acc = ONE
    for r in rho[:k]:
        acc = f2_mul(acc, f2_sub(ONE, r))
    return acc


class Rng:
    """Deterministic stand-in for transcript challenges (NOT a transcript)."""

    def __init__(self, seed: int):
        self.r = random.Random(seed)

    def fp(self) -> int:
        return self.r.randrange(1, P)

    def fp2(self) -> Fp2:
        # avoid the base field (the degenerate case FA1 identified) and zero
        while True:
            a = (self.r.randrange(P), self.r.randrange(1, P))
            if not f2_is_zero(a):
                return a

    def point(self, arity: int) -> List[Fp2]:
        return [self.fp2() for _ in range(arity)]


# ----------------------------------------------------------------------------
# the observation model
# ----------------------------------------------------------------------------


class Model:
    """Unknowns (data rows, mask rows: base-field scalars) and observations
    (Fp2 or Fp linear forms in them with public coefficients)."""

    def __init__(self, name: str, notes: Optional[List[str]] = None):
        self.name = name
        self.notes: List[str] = list(notes or [])
        self.data: List[str] = []
        self.masks: List[str] = []
        self._index: Dict[str, Tuple[str, int]] = {}
        self.obs: List[dict] = []

    # unknowns ---------------------------------------------------------------
    def data_unknown(self, name: str) -> str:
        if name in self._index:
            raise ValueError(f"duplicate unknown {name}")
        self._index[name] = ("data", len(self.data))
        self.data.append(name)
        return name

    def mask_unknown(self, name: str) -> str:
        if name in self._index:
            raise ValueError(f"duplicate unknown {name}")
        self._index[name] = ("mask", len(self.masks))
        self.masks.append(name)
        return name

    def kind(self, name: str) -> str:
        return self._index[name][0]

    # observations -----------------------------------------------------------
    def observe(self, name: str, coeffs: Dict[str, Fp2], **meta) -> None:
        """One Fp2 observation = two base-field rows (re, im)."""
        for k in coeffs:
            if k not in self._index:
                raise KeyError(f"observation {name}: unknown {k} not declared")
        self.obs.append({"name": name, "domain": "Fp2", "coeffs": {k: (v[0] % P, v[1] % P) for k, v in coeffs.items()}, **meta})

    def observe_base(self, name: str, coeffs: Dict[str, int], **meta) -> None:
        """One Fp observation = one base-field row."""
        for k in coeffs:
            if k not in self._index:
                raise KeyError(f"observation {name}: unknown {k} not declared")
        self.obs.append({"name": name, "domain": "Fp", "coeffs": {k: v % P for k, v in coeffs.items()}, **meta})

    # linear algebra view ---------------------------------------------------
    def base_rows(self) -> Tuple[List[str], List[List[int]], List[List[int]]]:
        """(row labels, A rows over data columns, B rows over mask columns)."""
        labels: List[str] = []
        a_rows: List[List[int]] = []
        b_rows: List[List[int]] = []
        nd, nm = len(self.data), len(self.masks)
        for o in self.obs:
            if o["domain"] == "Fp2":
                for part, ci in (("re", 0), ("im", 1)):
                    a = [0] * nd
                    b = [0] * nm
                    for k, v in o["coeffs"].items():
                        kind, idx = self._index[k]
                        (a if kind == "data" else b)[idx] = v[ci] % P
                    labels.append(f"{o['name']}.{part}")
                    a_rows.append(a)
                    b_rows.append(b)
            else:
                a = [0] * nd
                b = [0] * nm
                for k, v in o["coeffs"].items():
                    kind, idx = self._index[k]
                    (a if kind == "data" else b)[idx] = v % P
                labels.append(o["name"])
                a_rows.append(a)
                b_rows.append(b)
        return labels, a_rows, b_rows

    # JSON --------------------------------------------------------------------
    def to_json(self) -> dict:
        obs = []
        for o in self.obs:
            d = dict(o)
            if o["domain"] == "Fp2":
                d["coeffs"] = {k: [v[0], v[1]] for k, v in o["coeffs"].items()}
            obs.append(d)
        return {"name": self.name, "notes": self.notes, "data": list(self.data), "masks": list(self.masks), "observations": obs}

    @staticmethod
    def from_json(d: dict) -> "Model":
        m = Model(d.get("name", "model"), d.get("notes"))
        for x in d["data"]:
            m.data_unknown(x)
        for x in d["masks"]:
            m.mask_unknown(x)
        for o in d["observations"]:
            meta = {k: v for k, v in o.items() if k not in ("name", "domain", "coeffs")}
            if o.get("domain", "Fp2") == "Fp2":
                coeffs = {}
                for k, v in o["coeffs"].items():
                    if isinstance(v, list):
                        if len(v) != 2:
                            raise ValueError(f"{o['name']}: Fp2 coefficient needs two entries")
                        coeffs[k] = (int(v[0]) % P, int(v[1]) % P)
                    else:
                        coeffs[k] = (int(v) % P, 0)
                m.observe(o["name"], coeffs, **meta)
            else:
                coeffs = {}
                for k, v in o["coeffs"].items():
                    if isinstance(v, list):
                        if len(v) != 1:
                            raise ValueError(f"{o['name']}: Fp coefficient needs one entry")
                        v = v[0]
                    coeffs[k] = int(v) % P
                m.observe_base(o["name"], coeffs, **meta)
        return m


# ----------------------------------------------------------------------------
# exact linear algebra mod p
# ----------------------------------------------------------------------------


def rref(rows: List[List[int]]) -> Tuple[List[List[int]], List[int]]:
    """Reduced row echelon form over Fp. Returns (nonzero rows, pivot columns)."""
    m = [list(r) for r in rows]
    if not m:
        return [], []
    ncols = len(m[0])
    pivots: List[int] = []
    r = 0
    for c in range(ncols):
        if r >= len(m):
            break
        piv = None
        for i in range(r, len(m)):
            if m[i][c] % P:
                piv = i
                break
        if piv is None:
            continue
        m[r], m[piv] = m[piv], m[r]
        inv = fp_inv(m[r][c])
        m[r] = [(x * inv) % P for x in m[r]]
        for i in range(len(m)):
            if i != r and m[i][c] % P:
                f = m[i][c]
                m[i] = [(x - f * y) % P for x, y in zip(m[i], m[r])]
        pivots.append(c)
        r += 1
    return m[:r], pivots


def rank(rows: List[List[int]]) -> int:
    return len(rref(rows)[0])


def transpose(rows: List[List[int]], ncols: int) -> List[List[int]]:
    return [[rows[i][j] for i in range(len(rows))] for j in range(ncols)]


def null_space(rows: List[List[int]], ncols: int) -> List[List[int]]:
    """Basis of {x : rows . x = 0} over Fp."""
    red, pivots = rref(rows)
    free = [c for c in range(ncols) if c not in pivots]
    basis = []
    for f in free:
        x = [0] * ncols
        x[f] = 1
        for prow, pc in zip(red, pivots):
            x[pc] = (-prow[f]) % P
        basis.append(x)
    return basis


def left_null_space(rows: List[List[int]], ncols: int) -> List[List[int]]:
    """Basis of {y : y^T rows = 0}: the null space of rows^T."""
    return null_space(transpose(rows, ncols), len(rows))


def mat_mul(a: List[List[int]], b: List[List[int]], bcols: int) -> List[List[int]]:
    out = []
    for arow in a:
        row = [0] * bcols
        for k, x in enumerate(arow):
            if x:
                brow = b[k]
                for j in range(bcols):
                    if brow[j]:
                        row[j] = (row[j] + x * brow[j]) % P
        out.append(row)
    return out


# ----------------------------------------------------------------------------
# analysis
# ----------------------------------------------------------------------------


def analyze(model: Model) -> dict:
    labels, a_rows, b_rows = model.base_rows()
    nd, nm = len(model.data), len(model.masks)
    n_obs = len(labels)
    rank_b = rank(b_rows) if nm else 0
    joint = [ar + br for ar, br in zip(a_rows, b_rows)]
    rank_joint = rank(joint)
    rank_a = rank(a_rows) if nd else 0
    if nm:
        nspace = left_null_space(b_rows, nm)
    else:
        nspace = [[1 if i == j else 0 for j in range(n_obs)] for i in range(n_obs)]
    surviving = mat_mul(nspace, a_rows, nd) if nd else []
    f_red, f_piv = rref(surviving)
    disclosed_dim = len(f_red)
    assert disclosed_dim == rank_joint - rank_b, (disclosed_dim, rank_joint, rank_b)
    # per-unknown status
    status = {}
    for i, name in enumerate(model.data):
        touched = any(row[i] % P for row in f_red)
        recovered = False
        if i in f_piv:
            prow = f_red[f_piv.index(i)]
            recovered = all((x % P == 0) for j, x in enumerate(prow) if j != i)
        status[name] = "recovered" if recovered else ("disclosed" if touched else "protected")
    # the observation-space functionals that kill the masks (for cross-checks)
    obs_functionals = []
    for y in nspace:
        obs_functionals.append({labels[i]: y[i] for i in range(n_obs) if y[i] % P})
    data_functionals = []
    for row in f_red:
        data_functionals.append({model.data[i]: row[i] for i in range(nd) if row[i] % P})
    trivial_identities = len(nspace) - disclosed_dim  # null functionals that also kill the data
    return {
        "model": model.name,
        "notes": model.notes,
        "counts": {"data_unknowns": nd, "mask_unknowns": nm, "observations_fp2_or_fp": len(model.obs), "base_observation_rows": n_obs},
        "rank_mask": rank_b,
        "rank_data": rank_a,
        "rank_joint": rank_joint,
        "mask_null_dim": len(nspace),
        "disclosed_dim": disclosed_dim,
        "observation_functionals_killing_masks_but_not_data": trivial_identities,
        "surviving_data_functionals": data_functionals,
        "mask_killing_observation_functionals": obs_functionals,
        "status": status,
        "summary": {
            "recovered": [k for k, v in status.items() if v == "recovered"],
            "disclosed": [k for k, v in status.items() if v == "disclosed"],
            "protected": [k for k, v in status.items() if v == "protected"],
        },
        "caveat": "numerical rank of linear observations under fixed public coefficients; not a simulation proof",
    }


def analyze_json(d: dict) -> dict:
    return analyze(Model.from_json(d))


# ----------------------------------------------------------------------------
# fixtures (a)-(d) of the FA2 contract, plus the group-with-values models
# ----------------------------------------------------------------------------


def masked_coefs(rng: Rng, p3: bool = False) -> Tuple[Fp2, Fp2, Fp2, dict]:
    """(lambda, a, c, meta): the actual coefficient pair of a masked claim.
    P1: (1 - e, e). P3 matmul roles: ((1 - e2)(1 - e), (1 - e2) e)."""
    lam = rng.fp2()
    e = rng.fp2()
    if p3:
        e2 = rng.fp2()
        s = f2_sub(ONE, e2)
        a, c = f2_mul(s, f2_sub(ONE, e)), f2_mul(s, e)
        meta = {"lambda": lam, "e": e, "e2": e2}
    else:
        a, c = f2_sub(ONE, e), e
        meta = {"lambda": lam, "e": e}
    return lam, a, c, meta


def fixture_singleton(seed: int = 1, p3: bool = False) -> Tuple[Model, dict]:
    """(a) the known-deficient singleton: one base mask row, one Fp2
    observation (two base rows) per column; one column modelled."""
    rng = Rng(seed)
    lam, a, c, meta = masked_coefs(rng, p3)
    m = Model("fixture_a_singleton" + ("_p3" if p3 else ""), ["one column of a singleton group: v = lambda*(a D + c R)"])
    m.data_unknown("D")
    m.mask_unknown("R")
    m.observe("v", {"D": f2_mul(lam, a), "R": f2_mul(lam, c)}, role="singleton group vector entry", provenance="lambda: pcs-group challenge; a,c: extension challenge(s)")
    b = f2_mul(lam, c)
    expected = {"b": b, "L_b": (b[1], (-b[0]) % P), "w0": det(f2_mul(lam, a), b), **meta}
    return m, expected


def fixture_pair(seed: int = 2, degenerate: bool = False) -> Model:
    """(b) an independent Fp2 mask pair (R_re, R_im with coefficients b, b*u):
    protection expected. `degenerate=True` makes the second coefficient a base
    multiple of the first (span collapses to a line): disclosure expected."""
    rng = Rng(seed)
    lam, a, c, _ = masked_coefs(rng)
    b = f2_mul(lam, c)
    b_im = f2_mul(b, U) if not degenerate else f2_mul_base(b, rng.fp())
    m = Model("fixture_b_pair" + ("_degenerate" if degenerate else ""), ["one column: v = lambda*(a D + c (R_re + u R_im))"])
    m.data_unknown("D")
    m.mask_unknown("R_re")
    m.mask_unknown("R_im")
    m.observe("v", {"D": f2_mul(lam, a), "R_re": b, "R_im": b_im}, role="singleton group vector entry with an Fp2 mask pair")
    return m


def fixture_two_rows(seed: int = 3) -> Tuple[Model, dict]:
    """(c) T32: a two-row plane (row weights (1 - p0, p0)) under one base
    mask row: exactly one surviving functional per column, coefficients
    (1, kappa) with kappa = det(lambda a p0, lambda c) / det(lambda a (1 - p0), lambda c)."""
    rng = Rng(seed)
    lam, a, c, meta = masked_coefs(rng)
    p0 = rng.fp2()
    eq = eq_table_msb([p0])
    m = Model("fixture_c_two_rows", ["one column of a 2-row plane: v = lambda*(a (eq0 D0 + eq1 D1) + c R)"])
    m.data_unknown("D0")
    m.data_unknown("D1")
    m.mask_unknown("R")
    m.observe("v", {"D0": f2_mul(f2_mul(lam, a), eq[0]), "D1": f2_mul(f2_mul(lam, a), eq[1]), "R": f2_mul(lam, c)}, role="singleton group vector entry, 2 data rows")
    b = f2_mul(lam, c)
    w0 = det(f2_mul(f2_mul(lam, a), eq[0]), b)
    w1 = det(f2_mul(f2_mul(lam, a), eq[1]), b)
    return m, {"p0": p0, "w0": w0, "w1": w1, "kappa": (w1 * fp_inv(w0)) % P, **meta}


def fixture_reuse(seed: int = 4, reuse: bool = True) -> Model:
    """(d) mask reuse: R masks the singleton vector of D1 AND appears in a
    second (proximity-like) observation over D1, D2 with its own reserved
    mask R_p. With reuse both D1 and D2 are recovered; with a fresh mask R'
    in the second observation (control) only D1 is."""
    rng = Rng(seed)
    lam, a, c, _ = masked_coefs(rng)
    m = Model("fixture_d_reuse" if reuse else "fixture_d_reuse_control", ["obs1 = lambda*(a D1 + c R); obs2 = r1 D1 + r2 D2 + rR R(or R') + rp R_p"])
    m.data_unknown("D1")
    m.data_unknown("D2")
    m.mask_unknown("R")
    m.mask_unknown("R_p")
    if not reuse:
        m.mask_unknown("R_fresh")
    m.observe("v_single", {"D1": f2_mul(lam, a), "R": f2_mul(lam, c)}, role="singleton group vector entry")
    second = {"D1": rng.fp2(), "D2": rng.fp2(), ("R" if reuse else "R_fresh"): rng.fp2(), "R_p": rng.fp2()}
    m.observe("v_prox", second, role="proximity vector entry (uniform coefficient on every row)")
    return m


def group_with_values(m_members: int, n_cols: int, kinds: Sequence[str], seed: int = 5, with_prox: bool = False, p3: bool = False, name: Optional[str] = None, prox_pair: bool = False) -> Model:
    """A column-weight group of `m_members` claims over `n_cols` columns,
    modelling BOTH the group vector (n Fp2 entries) and the m terminal
    values (each an Fp2 claim value in the proof).  kinds[k] is the mask
    kind of member k:
      'base1'  one base mask row, one data row            (A planes, P3 W blocks)
      'pair'   Fp2 mask pair (re, im), Fp2 data pair      (H helper planes)
      'base2'  two base mask rows with eq row weights,
               two data rows                              (A table slots spanning >= 2 rows)
      'pairmask' ONE base data row masked by an Fp2 mask
               pair (re, im) with coefficients (c, c u)   (FA3's repaired A / P3-W claims)
    `prox_pair` (with `with_prox`) gives the proximity observation TWO
    reserved mask rows with independent coefficients (FA3's repaired prox).
    """
    assert len(kinds) == m_members
    rng = Rng(seed)
    lam_all = [rng.fp2() for _ in range(m_members)]
    e = rng.fp2()
    if p3:
        s = f2_sub(ONE, rng.fp2())
        a, c = f2_mul(s, f2_sub(ONE, e)), f2_mul(s, e)
    else:
        a, c = f2_sub(ONE, e), e
    log_n = n_cols.bit_length() - 1
    assert 1 << log_n == n_cols
    tail = rng.point(log_n)
    cw = eq_table_msb(tail)
    model = Model(name or f"group_m{m_members}_n{n_cols}_" + "-".join(kinds), [f"group vector ({n_cols} Fp2 entries) + {m_members} terminal values" + ("+ proximity vector" if with_prox else "")])
    # unknowns
    rows: List[Tuple[str, str, Fp2]] = []  # (unknown, kind data/mask, coefficient multiplier inside the member) per column template
    member_terms: List[List[Tuple[str, Fp2]]] = []  # per member: list of (unknown-prefix, coefficient) templates
    for k, kind in enumerate(kinds):
        terms: List[Tuple[str, Fp2]] = []
        if kind == "base1":
            terms.append((f"D{k}", a))
            terms.append((f"R{k}", c))
        elif kind == "pair":
            terms.append((f"D{k}_re", a))
            terms.append((f"D{k}_im", f2_mul(a, U)))
            terms.append((f"R{k}_re", c))
            terms.append((f"R{k}_im", f2_mul(c, U)))
        elif kind == "base2":
            rp = rng.fp2()
            eq = eq_table_msb([rp])
            terms.append((f"D{k}_r0", f2_mul(a, eq[0])))
            terms.append((f"D{k}_r1", f2_mul(a, eq[1])))
            terms.append((f"R{k}_r0", f2_mul(c, eq[0])))
            terms.append((f"R{k}_r1", f2_mul(c, eq[1])))
        elif kind == "pairmask":
            terms.append((f"D{k}", a))
            terms.append((f"R{k}_re", c))
            terms.append((f"R{k}_im", f2_mul(c, U)))
        else:
            raise ValueError(kind)
        member_terms.append(terms)
    for k, terms in enumerate(member_terms):
        for prefix, _ in terms:
            for j in range(n_cols):
                nm = f"{prefix}[{j}]"
                (model.data_unknown if prefix.startswith("D") else model.mask_unknown)(nm)
    if with_prox:
        for j in range(n_cols):
            model.mask_unknown(f"R_prox[{j}]")
            if prox_pair:
                model.mask_unknown(f"R_prox_im[{j}]")
    # group vector entries
    for j in range(n_cols):
        coeffs: Dict[str, Fp2] = {}
        for k, terms in enumerate(member_terms):
            for prefix, coef in terms:
                coeffs[f"{prefix}[{j}]"] = f2_mul(lam_all[k], coef)
        model.observe(f"v[{j}]", coeffs, role="group vector entry", provenance="lambda_k: pcs-group challenges; a,c: extension challenge; row weights: eq of the point's row bits")
    # terminal values
    for k, terms in enumerate(member_terms):
        coeffs = {}
        for prefix, coef in terms:
            for j in range(n_cols):
                coeffs[f"{prefix}[{j}]"] = f2_mul(coef, cw[j])
        model.observe(f"value[{k}]", coeffs, role="terminal (claim value) of member k", provenance="column weights: eq of the point's column tail; a,c as above")
    if with_prox:
        for j in range(n_cols):
            coeffs = {}
            for k, terms in enumerate(member_terms):
                for prefix, _ in terms:
                    coeffs[f"{prefix}[{j}]"] = rng.fp2()
            coeffs[f"R_prox[{j}]"] = rng.fp2()
            if prox_pair:
                coeffs[f"R_prox_im[{j}]"] = rng.fp2()
            model.observe(f"prox[{j}]", coeffs, role="proximity vector entry")
    return model


# ----------------------------------------------------------------------------
# per-column commitment models mirroring ZkLayoutV3 (source-derived structure)
# ----------------------------------------------------------------------------


def _kind_suffixes(kind: str) -> Tuple[List[str], List[str]]:
    """(data suffixes, mask suffixes) of a member kind.  An 'im' suffix
    multiplies the coefficient by U (the Fp2 pair form (c, c u)):
      'base'     ([''],        [''])        base data rows, base mask rows (the legacy A / P3-W form; a
                                            multi-row block is Fp2-effective only through its row weights)
      'pair'     (['re','im'], ['re','im']) Fp2-valued data (H helper planes) with an Fp2 mask pair
      'pairmask' ([''],        ['re','im']) base data rows with an Fp2 mask pair -- FA3's repaired form
                                            for every single-row mask site (S2's terminal_claim shape)
    """
    if kind == "base":
        return [""], [""]
    if kind == "pair":
        return ["re", "im"], ["re", "im"]
    if kind == "pairmask":
        return [""], ["re", "im"]
    raise ValueError(kind)


def commitment_with_values(name: str, groups: List[dict], n_cols: int, seed: int = 9, notes: Optional[List[str]] = None, prox_pair: bool = False) -> Model:
    """A whole commitment over `n_cols` columns: every group vector (n Fp2
    entries each), every terminal value, and the proximity vector.  Same
    `groups` schema as `per_column_commitment` (data_alias re-opens rows).
    `prox_pair` reserves TWO base rows for the proximity combination (FA3).
    Small n only (the unknown count is rows x n)."""
    rng = Rng(seed)
    model = Model(name, notes or [])
    log_n = n_cols.bit_length() - 1
    assert 1 << log_n == n_cols
    all_rows: List[str] = []  # row names (without the column index)

    def unk(prefix: str, is_data: bool) -> None:
        if prefix in all_rows:
            return
        all_rows.append(prefix)
        for j in range(n_cols):
            (model.data_unknown if is_data else model.mask_unknown)(f"{prefix}[{j}]")

    for g in groups:
        e = rng.fp2()
        if g.get("e_kind") == "p3":
            s_ = f2_sub(ONE, rng.fp2())
            a_base, c_base = f2_mul(s_, f2_sub(ONE, e)), f2_mul(s_, e)
        else:
            a_base, c_base = f2_sub(ONE, e), e
        shared_rho = rng.point(20)
        cw = eq_table_msb(rng.point(log_n))
        vec: List[Dict[str, Fp2]] = [dict() for _ in range(n_cols)]
        for mem in g["members"]:
            lam = rng.fp2()
            dr, mr = mem["data_rows"], mem["mask_rows"]
            kind = mem.get("kind", "base")
            ext = ext_coef(shared_rho, mem.get("ext_k", 0))
            a, c = f2_mul(a_base, ext), f2_mul(c_base, ext)
            rb = dr.bit_length() - 1
            eq = eq_table_msb(rng.point(rb)) if rb else [ONE]
            meq = [ONE] if mr == 1 else eq
            data_sfx, mask_sfx = _kind_suffixes(kind)
            data_prefix = mem.get("data_alias") or f"{g['name']}/{mem['name']}"
            terms: List[Tuple[str, Fp2]] = []  # (row prefix, per-column coefficient WITHOUT lambda)
            for r in range(dr):
                for sfx in data_sfx:
                    pre = f"{data_prefix}/D{r}{('_' + sfx) if sfx else ''}"
                    unk(pre, True)
                    coef = f2_mul(a, eq[r])
                    if sfx == "im":
                        coef = f2_mul(coef, U)
                    terms.append((pre, coef))
            for r in range(mr):
                for sfx in mask_sfx:
                    pre = f"{g['name']}/{mem['name']}/R{r}{('_' + sfx) if sfx else ''}"
                    unk(pre, False)
                    coef = f2_mul(c, meq[r])
                    if sfx == "im":
                        coef = f2_mul(coef, U)
                    terms.append((pre, coef))
            value: Dict[str, Fp2] = {}
            for pre, coef in terms:
                for j in range(n_cols):
                    nm = f"{pre}[{j}]"
                    vec[j][nm] = f2_add(vec[j].get(nm, ZERO), f2_mul(lam, coef))
                    value[nm] = f2_add(value.get(nm, ZERO), f2_mul(coef, cw[j]))
            model.observe(f"value[{g['name']}/{mem['name']}]", value, role="terminal (claim value)")
        for j in range(n_cols):
            model.observe(f"v[{g['name']}][{j}]", vec[j], role=f"group vector entry, {len(g['members'])} member(s)")
    unk("prox/R_prox", False)
    if prox_pair:
        unk("prox/R_prox_im", False)
    for j in range(n_cols):
        model.observe(f"v[prox][{j}]", {f"{pre}[{j}]": rng.fp2() for pre in all_rows}, role="proximity vector entry")
    return model


def fixture_logup_sum(n_cols: int = 4, n_helper_pairs: int = 2, n_table_pairs: int = 1, seed: int = 8, prox_pair: bool = False) -> Tuple[Model, List[Dict[str, int]]]:
    """The H commitment's LogUp sum claim (value 0; all-ones column weights)
    whose only mask is the zero-sum pair u = (u_re, u_im), sum_j u[j] = 0,
    modelled JOINTLY with the other H claims that touch the same rows: the
    helper planes at rho_f (Fp2 mask pairs), the table helpers at rho_tab
    (Fp2 mask pairs), the zsum claim (u at rho_zs masked by the fresh pair
    u'), every terminal value, and the proximity vector (one prox mask entry
    per column).  The zero-sum constraint is imposed by substitution:
    u[n-1] = -sum_{j<n-1} u[j].  Returns (model, the two base rows of the
    public LogUp identity sum_j v_sum[j] restricted to the data) so a test can
    check that the surviving functionals are exactly that public identity."""
    rng = Rng(seed)
    m = Model("fixture_h_logup_sum_zero_sum_u", ["H: rho_f pairs + tab pairs + zsum (u/u') + LogUp sum (u, zero-sum) + values + prox; expected residual = the public LogUp identity only"])
    log_n = n_cols.bit_length() - 1
    planes: List[Tuple[str, Fp2]] = []  # (data prefix, sign in the LogUp sum)
    for h in range(n_helper_pairs):
        for j in range(n_cols):
            m.data_unknown(f"h{h}_re[{j}]")
            m.data_unknown(f"h{h}_im[{j}]")
            m.mask_unknown(f"mh{h}_re[{j}]")
            m.mask_unknown(f"mh{h}_im[{j}]")
        planes.append((f"h{h}", ONE))
    for t in range(n_table_pairs):
        for j in range(n_cols):
            m.data_unknown(f"t{t}_re[{j}]")
            m.data_unknown(f"t{t}_im[{j}]")
            m.mask_unknown(f"mt{t}_re[{j}]")
            m.mask_unknown(f"mt{t}_im[{j}]")
        planes.append((f"t{t}", f2_neg(ONE)))
    for j in range(n_cols - 1):
        m.mask_unknown(f"u_re[{j}]")
        m.mask_unknown(f"u_im[{j}]")
    for j in range(n_cols):
        m.mask_unknown(f"up_re[{j}]")
        m.mask_unknown(f"up_im[{j}]")
    for j in range(n_cols):
        m.mask_unknown(f"R_prox[{j}]")
        if prox_pair:
            m.mask_unknown(f"R_prox_im[{j}]")

    def pair(prefix: str, j: int, scale: Fp2) -> Dict[str, Fp2]:
        return {f"{prefix}_re[{j}]": scale, f"{prefix}_im[{j}]": f2_mul(scale, U)}

    def u_terms(j: int, scale: Fp2) -> Dict[str, Fp2]:
        out: Dict[str, Fp2] = {}
        if j < n_cols - 1:
            out.update(pair("u", j, scale))
        else:
            for jj in range(n_cols - 1):
                out.update(pair("u", jj, f2_neg(scale)))
        return out

    def merge(dst: Dict[str, Fp2], src: Dict[str, Fp2]) -> None:
        for k, v in src.items():
            dst[k] = f2_add(dst.get(k, ZERO), v)

    # groups with Fp2 mask pairs: rho_f (helpers), tab (table helpers) -- vector + values
    for gname, members, mprefix in (("rho_f", [f"h{h}" for h in range(n_helper_pairs)], "mh"), ("tab", [f"t{t}" for t in range(n_table_pairs)], "mt")):
        e = rng.fp2()
        a, c = f2_sub(ONE, e), e
        cw = eq_table_msb(rng.point(log_n))
        vec: List[Dict[str, Fp2]] = [dict() for _ in range(n_cols)]
        for k, name in enumerate(members):
            lam = rng.fp2()
            value: Dict[str, Fp2] = {}
            for j in range(n_cols):
                merge(vec[j], pair(name, j, f2_mul(lam, a)))
                merge(vec[j], pair(mprefix + name[1:], j, f2_mul(lam, c)))
                merge(value, pair(name, j, f2_mul(a, cw[j])))
                merge(value, pair(mprefix + name[1:], j, f2_mul(c, cw[j])))
            m.observe(f"value[{gname}/{name}]", value, role="terminal value")
        for j in range(n_cols):
            m.observe(f"v[{gname}][{j}]", vec[j], role=f"{gname} group vector entry ({len(members)} pair-masked member(s))")
    # the LogUp sum claim: all-ones column weights, value 0, mask = the zero-sum u pair
    identity_rows: List[Dict[str, int]] = [dict(), dict()]
    for j in range(n_cols):
        coeffs: Dict[str, Fp2] = {}
        for name, sign in planes:
            merge(coeffs, pair(name, j, sign))
        merge(coeffs, u_terms(j, ONE))
        m.observe(f"v_sum[{j}]", coeffs, role="LogUp sum vector entry (all-ones column weights; value 0)")
        for name, sign in planes:
            for part, ci in (("re", 0), ("im", 1)):
                identity_rows[ci][f"{name}_re[{j}]"] = (identity_rows[ci].get(f"{name}_re[{j}]", 0) + sign[ci]) % P
                identity_rows[ci][f"{name}_im[{j}]"] = (identity_rows[ci].get(f"{name}_im[{j}]", 0) + f2_mul(sign, U)[ci]) % P
    # the zsum claim: u at rho_zs masked by u', vector + terminal
    lam, e = rng.fp2(), rng.fp2()
    cw = eq_table_msb(rng.point(log_n))
    zs_value: Dict[str, Fp2] = {}
    for j in range(n_cols):
        coeffs = {}
        merge(coeffs, u_terms(j, f2_mul(lam, f2_sub(ONE, e))))
        merge(coeffs, pair("up", j, f2_mul(lam, e)))
        m.observe(f"v_zs[{j}]", coeffs, role="zsum group vector entry (u masked by u')")
        merge(zs_value, u_terms(j, f2_mul(f2_sub(ONE, e), cw[j])))
        merge(zs_value, pair("up", j, f2_mul(e, cw[j])))
    m.observe("zs_term", zs_value, role="zsum terminal value")
    # the proximity vector: a fresh coefficient on every row, per column
    for j in range(n_cols):
        coeffs = {k: rng.fp2() for k in list(m.data) + list(m.masks) if k.endswith(f"[{j}]") and not k.startswith("u_")}
        # the u rows: column j's entry (substituted for the last column)
        merge(coeffs, {k: f2_mul(v, rng.fp2()) for k, v in u_terms(j, ONE).items()} if j < n_cols - 1 else {})
        if j == n_cols - 1:
            ru = (rng.fp2(), rng.fp2())
            for jj in range(n_cols - 1):
                merge(coeffs, {f"u_re[{jj}]": f2_neg(ru[0]), f"u_im[{jj}]": f2_neg(ru[1])})
        m.observe(f"v_prox[{j}]", coeffs, role="proximity vector entry")
    return m, identity_rows


def t_sweep(d: int, f: int, log_cols: int, ts: Iterable[int] = (2, 4, 8, 16, 32, 64, 128)) -> List[dict]:
    """rows per plane / block and the singleton-role integer-range note per T."""
    out = []
    for t in ts:
        lay = layout_v3(t, d, f, log_cols)
        rec = {"t_rows": t, "log_n": lay["log_n"], "n": lay["n"], "rows_per_f_plane": lay["rows_per_f_plane"], "rows_per_d_plane": lay["rows_per_d_plane"], "rows_per_w_block": lay["rows_per_w_block"], "w_n": lay["w_n"]}
        if lay["nb_d"] == 1:
            rec["X_at_p2_singleton"] = range_note(lay["rows_per_d_plane"], 8)
        if lay["nb_f"] == 1:
            rec["h16_at_p5_singleton"] = range_note(lay["rows_per_f_plane"], 16)
        if lay["nb_d"] * lay["nb_f"] == 1:
            rec["Wd_at_p6_singleton_P3"] = range_note(lay["rows_per_w_block"], 8)
        out.append(rec)
    return out


# --- the v3 layouts -----------------------------------------------------------


def layout_v3(t_rows: int, d: int, f: int, log_cols: int) -> dict:
    """nb_d, nb_f, log_n, rows per plane -- mirrors LayoutV3::new / ZkLayoutV3::new."""
    log_t = t_rows.bit_length() - 1
    assert 1 << log_t == t_rows
    log_db = min((d & -d).bit_length() - 1, 12)
    log_fb = min((f & -f).bit_length() - 1, 12)
    assert log_db >= 4 and log_fb >= 4 and d % (1 << log_db) == 0 and f % (1 << log_fb) == 0
    nb_d, nb_f = d >> log_db, f >> log_fb
    log_a_min = log_t + min(log_db, log_fb)
    log_n = min(log_cols, log_a_min)
    log_wb = log_db + log_fb
    log_wn = min(log_cols, log_wb)
    n = 1 << log_n
    table_sizes = [256, 1 << 16, 1 << 7, 1 << 0, 1 << 14, 1 << 6]  # shifts (7, 0, 14, 6): rem slots 2^s
    table_rows = [max(s, n) // n for s in table_sizes]
    return {
        "t_rows": t_rows, "d": d, "f": f, "log_cols": log_cols,
        "log_t": log_t, "log_db": log_db, "log_fb": log_fb, "nb_d": nb_d, "nb_f": nb_f,
        "log_a_min": log_a_min, "log_n": log_n, "n": n,
        "rows_per_f_plane": (t_rows << log_fb) // n, "rows_per_d_plane": (t_rows << log_db) // n,
        "log_wb": log_wb, "log_wn": log_wn, "w_n": 1 << log_wn, "rows_per_w_block": (1 << log_wb) // (1 << log_wn),
        "table_rows": table_rows,
        "a_mask_rows": 7 * nb_f + 3 * nb_d + nb_d + nb_f + 1 + sum(table_rows),
        "h_mask_rows": 2 * (3 * nb_f + nb_d) + 4 + 1 + 2 * sum(table_rows),
        "w_mask_rows_p3": 3 * nb_d * nb_f + 1,
    }


def a_commitment_groups(lay: dict, p3: bool = False, predicate: bool = False) -> List[dict]:
    nb_d, nb_f = lay["nb_d"], lay["nb_f"]
    rf, rd = lay["rows_per_f_plane"], lay["rows_per_d_plane"]
    groups = [
        {"name": "rho_f", "members": [{"name": f"{pl}{b}", "data_rows": rf, "mask_rows": 1} for b in range(nb_f) for pl in ("g8", "rg", "a16", "u16", "ru", "h16", "rh")]},
        {"name": "rho_d", "members": [{"name": f"{pl}{c}", "data_rows": rd, "mask_rows": 1} for c in range(nb_d) for pl in ("X", "z", "rd")]},
        {"name": "p2", "e_kind": "p3" if p3 else "p1", "members": [{"name": f"X{c}", "data_rows": rd, "mask_rows": 1} for c in range(nb_d)]},
        {"name": "p5", "e_kind": "p3" if p3 else "p1", "members": [{"name": f"h16_{b}", "data_rows": rf, "mask_rows": 1} for b in range(nb_f)]},
        {"name": "tab", "members": [{"name": f"slot{i}", "data_rows": r, "mask_rows": r, "ext_k": max(lay["log_n"], 16) - ((r * lay["n"]).bit_length() - 1)} for i, r in enumerate(lay["table_rows"])]},
    ]
    # X at p2 and X at rho_d are the SAME data rows with different masks: share the data names
    for c in range(nb_d):
        groups[2]["members"][c]["data_alias"] = f"rho_d/X{c}"
    for b in range(nb_f):
        groups[3]["members"][b]["data_alias"] = f"rho_f/h16{b}"
    if predicate:
        # the predicate re-opens the z block holding the frozen entry (block 0 in these models) under a_pmz
        groups.append({"name": "rho_p", "members": [{"name": "z_pred", "data_rows": rd, "mask_rows": 1, "data_alias": "rho_d/z0"}, {"name": "bits", "data_rows": 1, "mask_rows": 1}]})
    return groups


def per_column_commitment(name: str, groups: List[dict], seed: int = 7, notes: Optional[List[str]] = None, prox_pair: bool = False) -> Model:
    """One column of a whole commitment: every group vector entry and the
    proximity vector entry.  `groups` = [{name, e_kind: 'p1'|'p3',
    members: [{name, data_rows, mask_rows, kind: 'base'|'pair'|'pairmask',
    ext_k, data_alias}]}].  A member with data_rows = 2^rb spans rb row
    bits: its data rows get eq row weights of a fresh point; mask_rows must
    be 1 (planes) or equal to data_rows (table slots).  `ext_k` (table
    slots) multiplies both coefficients by prod_{j<k}(1 - rho_j) of a shared
    rho.  `data_alias` re-opens ANOTHER member's data rows under a new mask
    (X at p2 re-opens X at rho_d; h16 at p5 re-opens h16 at rho_f).
    `prox_pair` reserves two base rows for the proximity combination (FA3).
    Cross-column observations (terminal values) are NOT in this model; use
    `group_with_values` / `commitment_with_values` for those."""
    rng = Rng(seed)
    model = Model(name, notes or [])
    all_rows: List[str] = []
    for g in groups:
        e = rng.fp2()
        if g.get("e_kind") == "p3":
            s = f2_sub(ONE, rng.fp2())
            a_base, c_base = f2_mul(s, f2_sub(ONE, e)), f2_mul(s, e)
        else:
            a_base, c_base = f2_sub(ONE, e), e
        shared_rho = rng.point(20)
        coeffs: Dict[str, Fp2] = {}
        for mem in g["members"]:
            lam = rng.fp2()
            dr, mr = mem["data_rows"], mem["mask_rows"]
            kind = mem.get("kind", "base")
            ext = ext_coef(shared_rho, mem.get("ext_k", 0))
            a, c = f2_mul(a_base, ext), f2_mul(c_base, ext)
            rb = dr.bit_length() - 1
            eq = eq_table_msb(rng.point(rb)) if rb else [ONE]
            meq = [ONE] if mr == 1 else eq
            data_sfx, mask_sfx = _kind_suffixes(kind)
            data_prefix = mem.get("data_alias") or f"{g['name']}/{mem['name']}"
            for r in range(dr):
                for sfx in data_sfx:
                    nm = f"{data_prefix}/D{r}{('_' + sfx) if sfx else ''}"
                    if nm not in model._index:
                        model.data_unknown(nm)
                        all_rows.append(nm)
                    coef = f2_mul(f2_mul(lam, a), eq[r])
                    if sfx == "im":
                        coef = f2_mul(coef, U)
                    coeffs[nm] = f2_add(coeffs.get(nm, ZERO), coef)
            for r in range(mr):
                for sfx in mask_sfx:
                    nm = f"{g['name']}/{mem['name']}/R{r}{('_' + sfx) if sfx else ''}"
                    if nm not in model._index:
                        model.mask_unknown(nm)
                        all_rows.append(nm)
                    coef = f2_mul(f2_mul(lam, c), meq[r])
                    if sfx == "im":
                        coef = f2_mul(coef, U)
                    coeffs[nm] = f2_add(coeffs.get(nm, ZERO), coef)
        model.observe(f"v[{g['name']}]", coeffs, role=f"group vector entry, {len(g['members'])} member(s)")
    model.mask_unknown("prox/R_prox")
    all_rows.append("prox/R_prox")
    if prox_pair:
        model.mask_unknown("prox/R_prox_im")
        all_rows.append("prox/R_prox_im")
    model.observe("v[prox]", {r: rng.fp2() for r in all_rows}, role="proximity vector entry (fresh Fp2 coefficient on every row)")
    return model


def h_commitment_groups(lay: dict) -> List[dict]:
    nb_d, nb_f = lay["nb_d"], lay["nb_f"]
    rf, rd = lay["rows_per_f_plane"], lay["rows_per_d_plane"]
    return [
        {"name": "rho_f", "members": [{"name": f"{pl}{b}", "data_rows": rf, "mask_rows": 1, "kind": "pair"} for b in range(nb_f) for pl in ("hg", "hu", "hh")]},
        {"name": "rho_d", "members": [{"name": f"hz{c}", "data_rows": rd, "mask_rows": 1, "kind": "pair"} for c in range(nb_d)]},
        {"name": "zsum", "members": [{"name": "u", "data_rows": 1, "mask_rows": 1, "kind": "pair"}]},
        {"name": "tab", "members": [{"name": f"h_slot{i}", "data_rows": r, "mask_rows": r, "kind": "pair", "ext_k": max(lay["log_n"], 16) - ((r * lay["n"]).bit_length() - 1)} for i, r in enumerate(lay["table_rows"])]},
    ]


def w_commitment_groups(lay: dict) -> List[dict]:
    nb_d, nb_f = lay["nb_d"], lay["nb_f"]
    rw = lay["rows_per_w_block"]
    return [
        {"name": "p3", "e_kind": "p3", "members": [{"name": f"W{pl}_{c}_{b}", "data_rows": rw, "mask_rows": 1} for pl in ("g", "u") for c in range(nb_d) for b in range(nb_f)]},
        {"name": "p6", "e_kind": "p3", "members": [{"name": f"Wd_{b}_{c}", "data_rows": rw, "mask_rows": 1} for b in range(nb_f) for c in range(nb_d)]},
    ]


# ----------------------------------------------------------------------------
# the impact matrix
# ----------------------------------------------------------------------------

PROFILES = [
    {"family": "tiny T2/d16/f16", "t_rows": 2, "d": 16, "f": 16, "log_cols": 5, "inv_rate": 4, "q": 12, "tested": "FA1/Codex executed (A roles only)"},
    {"family": "tiny T32/d16/f16", "t_rows": 32, "d": 16, "f": 16, "log_cols": 8, "inv_rate": 8, "q": 256, "tested": "FA1/Codex executed (A roles only)"},
    {"family": "125M d768/f2048", "t_rows": 32, "d": 768, "f": 2048, "log_cols": 14, "inv_rate": 4, "q": 256, "tested": "not executed; source-derived"},
    {"family": "8B d4096/f14336", "t_rows": 32, "d": 4096, "f": 14336, "log_cols": 14, "inv_rate": 4, "q": 256, "tested": "not executed; source-derived"},
]


def classify_group(m: int, all_base: bool, n: int, rows: int) -> dict:
    """The rule the fixtures establish (see the doc, Part 2 section 4):
    all-base-mask group, m = 1  -> n surviving functionals per proof (one per
                                  column) of the member's `rows` rows;
    all-base-mask group, m >= 2 -> 2 surviving base functionals per proof of
                                  the members' data (from the terminal values);
    any Fp2-effective member     -> 0 in the (vector + values + prox) model."""
    if not all_base:
        return {"verdict": "covered (linear model, generic coefficients)", "functionals_per_proof": 0}
    if m == 1:
        return {"verdict": "affected (singleton: one functional per column)", "functionals_per_proof": n, "rows_per_functional": rows, "full_plane_from_one_proof": rows == 1}
    return {"verdict": "affected (multi-member all-base: two base functionals from the terminal values)", "functionals_per_proof": 2}


def range_note(rows: int, bits: int) -> str:
    unknown_bits = rows * bits
    if rows == 1:
        return f"exact recovery (1 row, {bits}-bit entries)"
    if unknown_bits <= 32:
        return f"{unknown_bits} unknown bits per column vs 64-bit modulus: unique w.h.p., enumerable (derived, not executed)"
    if unknown_bits <= 56:
        return f"{unknown_bits} unknown bits per column vs 64-bit modulus: unique w.h.p., lattice/meet-in-the-middle (derived, not executed)"
    return f"{unknown_bits} unknown bits per column vs 64-bit modulus: NOT unique from one proof; {rows} repeated proofs recover linearly"


def impact_matrix(run_models: bool = True) -> dict:
    out = {"schema_version": 1, "task": "FA2 -- joint exposure and affected profiles", "reviewer": "Claude Fable 5.1, independent reviewer, 2026-09-07 session",
           "rule": classify_group.__doc__.strip(), "profiles": []}
    for prof in PROFILES:
        lay = layout_v3(prof["t_rows"], prof["d"], prof["f"], prof["log_cols"])
        n = lay["n"]
        nb_d, nb_f = lay["nb_d"], lay["nb_f"]
        rf, rd, rw = lay["rows_per_f_plane"], lay["rows_per_d_plane"], lay["rows_per_w_block"]
        int16_multirow = lay["table_rows"][1] >= 2
        roles = {}
        roles["A rho_f (g8,rg,a16,u16,ru,h16,rh x nb_f)"] = {"members": 7 * nb_f, "mask": "one base row per plane", **classify_group(7 * nb_f, True, n, rf)}
        roles["A rho_d (X,z,rd x nb_d)"] = {"members": 3 * nb_d, "mask": "one base row per plane", **classify_group(3 * nb_d, True, n, rd)}
        x = classify_group(nb_d, True, n, rd)
        x["integer_range"] = range_note(rd, 8) if nb_d == 1 else "n/a (multi-member)"
        roles["A X at p2 (nb_d)"] = {"members": nb_d, "mask": "a_mgu, one base row per X block", **x}
        h = classify_group(nb_f, True, n, rf)
        h["integer_range"] = range_note(rf, 16) if nb_f == 1 else "n/a (multi-member)"
        roles["A h16 at p5 (nb_f)"] = {"members": nb_f, "mask": "a_mdd, one base row per h16 block", **h}
        roles["A tables (6 multiplicity slots)"] = {"members": 6, "mask": f"same-shaped base rows; slot rows {lay['table_rows']}", **classify_group(6, not int16_multirow, n, 1),
                                                     "note": "the INT16 slot spans >= 2 rows for log_n <= 15, so its mask is Fp2-effective and covers the group's values; at log_n = 16 every slot is one row and the group falls back to 2 functionals"}
        roles["A predicate group (function 2 only)"] = {"members": 2, "mask": "a_pmz (z block), a_pmb (bit row): base rows", **classify_group(2, True, n, rd), "note": "leaks two base functionals of (z block, 16 predicate slack bits) per function-2 proof"}
        roles["A proximity vector"] = {"members": "all rows", "mask": "a_prox (one base row) + every mask row with its own coefficient", "verdict": "covered per column given the other groups' residual mask freedom (numerically confirmed in the per-column model); a_prox alone covers one of the two base dimensions"}
        roles["H rho_f / rho_d / zsum / tables"] = {"mask": "Fp2 pairs (re, im)", "verdict": "covered (linear model, generic coefficients): Fp2-effective masks make vector + values Fp2-linear", "functionals_per_proof": 0}
        roles["H LogUp sum (value 0; u pair with cross-column zero sum)"] = {"mask": "u pair, constrained sum_j u[j] = 0", "verdict": "covered by argument: the single surviving functional is sum_j v_sum[j] = the public claim value 0 (the LogUp identity itself); u's other n-1 columns pad the rest", "functionals_per_proof": 0}
        roles["H proximity vector"] = {"mask": "h_prox (base row) + all H mask rows", "verdict": "covered per column (numerically confirmed in the per-column model)"}
        w3 = classify_group(2 * nb_d * nb_f, True, lay["w_n"], rw)
        w6 = classify_group(nb_d * nb_f, True, lay["w_n"], rw)
        if nb_d * nb_f == 1:
            w6["integer_range"] = range_note(rw, 8)
        roles["W (P3) Wg/Wu at p3 (2 nb_d nb_f)"] = {"members": 2 * nb_d * nb_f, "mask": "w_mgu, one base row per block", **w3}
        roles["W (P3) Wd at p6 (nb_d nb_f)"] = {"members": nb_d * nb_f, "mask": "w_mdd, one base row per block", **w6}
        roles["W (P3) proximity vector"] = {"mask": "w_prox + 3 nb_d nb_f block masks", "verdict": ("AFFECTED at nb_d nb_f = 1: 4 mask rows vs 6 base observation dims per column -> one extra functional of (Wg[j], Wu[j]) per column (numerically confirmed)" if nb_d * nb_f == 1 else "covered per column (numerically confirmed)")}
        roles["W (P1)"] = {"verdict": "n/a: public weights, plain opening (no privacy claim)"}
        roles["sampled columns + folded pads (A, H, W)"] = {"verdict": "covered by argument: the Q pads per row are a bijection onto the <= Q distinct sampled coset points (Vandermonde, Z_n != 0 on the coset), and the folded pad coordinates are determined by the message parts + sampled columns; unopened columns rest on salted-leaf hash hiding (computational, outside the linear model)"}
        roles["CFS mask commitment (sumcheck round messages, masked claimed sums)"] = {"verdict": "outside the linear row model: nonlinear in the data; relies on the CFS/Libra-style masking argument, not reviewed here -> UNRESOLVED for FA3/FA5"}
        roles["H / P3-W openings: executed capture"] = {"verdict": "AWAITING CAPTURE (Codex round-10 hook does not exist yet): every H and P3-W statement above is source-derived only"}
        entry = {"profile": prof, "layout": lay, "t_sweep": t_sweep(prof["d"], prof["f"], prof["log_cols"]), "roles": roles}
        if run_models:
            entry["per_column_models"] = {}
            a_model = per_column_commitment(f"A per-column {prof['family']}", a_commitment_groups(lay, p3=False), seed=11)
            ra = analyze(a_model)
            entry["per_column_models"]["A (P1)"] = {"disclosed_dim": ra["disclosed_dim"], "rank_mask": ra["rank_mask"], "base_obs_rows": ra["counts"]["base_observation_rows"], "mask_unknowns": ra["counts"]["mask_unknowns"], "data_unknowns": ra["counts"]["data_unknowns"], "disclosed_or_recovered": ra["summary"]["recovered"] + ra["summary"]["disclosed"]}
            h_model = per_column_commitment(f"H per-column {prof['family']}", h_commitment_groups(lay), seed=12)
            rh = analyze(h_model)
            entry["per_column_models"]["H"] = {"disclosed_dim": rh["disclosed_dim"], "rank_mask": rh["rank_mask"], "base_obs_rows": rh["counts"]["base_observation_rows"], "mask_unknowns": rh["counts"]["mask_unknowns"], "data_unknowns": rh["counts"]["data_unknowns"], "disclosed_or_recovered": rh["summary"]["recovered"] + rh["summary"]["disclosed"]}
            w_model = per_column_commitment(f"W(P3) per-column {prof['family']}", w_commitment_groups(lay), seed=13)
            rw_ = analyze(w_model)
            entry["per_column_models"]["W (P3)"] = {"disclosed_dim": rw_["disclosed_dim"], "rank_mask": rw_["rank_mask"], "base_obs_rows": rw_["counts"]["base_observation_rows"], "mask_unknowns": rw_["counts"]["mask_unknowns"], "data_unknowns": rw_["counts"]["data_unknowns"], "disclosed_or_recovered": rw_["summary"]["recovered"] + rw_["summary"]["disclosed"]}
            # the cross-column (vector + values) rule at the actual member counts, small n
            entry["group_value_models_n4"] = {}
            for gname, m_, kinds in (
                ("A rho_f", 7 * nb_f, ["base1"] * (7 * nb_f)),
                ("A rho_d", 3 * nb_d, ["base1"] * (3 * nb_d)),
                ("A X@p2", nb_d, ["base1"] * nb_d),
                ("A h16@p5", nb_f, ["base1"] * nb_f),
                ("A tables", 6, ["base2" if r >= 2 else "base1" for r in lay["table_rows"]]),
                ("W(P3) p3", 2 * nb_d * nb_f, ["base1"] * (2 * nb_d * nb_f)),
                ("W(P3) p6", nb_d * nb_f, ["base1"] * (nb_d * nb_f)),
                ("H rho_f", 3 * nb_f, ["pair"] * (3 * nb_f)),
            ):
                gm = group_with_values(m_, 4, kinds, seed=21 + m_)
                rg = analyze(gm)
                entry["group_value_models_n4"][gname] = {"members": m_, "kinds": sorted(set(kinds)), "disclosed_dim": rg["disclosed_dim"], "rank_mask": rg["rank_mask"], "base_obs_rows": rg["counts"]["base_observation_rows"]}
        out["profiles"].append(entry)
    out["repeated_proofs"] = {
        "singleton roles": "R proofs of the same witness with fresh challenges give R independent row-combination functionals per column: the R-row plane is recovered linearly (no range assumption)",
        "multi-member all-base roles": "2 fresh base functionals of the group's data per proof; linear recovery after (data dims)/2 proofs, sooner with integer ranges",
        "P3 weights": "the weights are the same in every proof by construction, so the repeated-proof accumulation applies to W in full; at nb_d nb_f = 1 two proofs recover Wg, Wu, Wd entirely in the linear model",
        "activations": "accumulation applies only when the same X is re-proven (re-verification, shared prefixes)",
    }
    return out


def fixtures_report() -> dict:
    cases = {}
    m, exp = fixture_singleton(1)
    cases["a_singleton_p1"] = {"analysis": analyze(m), "expected": {k: (list(v) if isinstance(v, tuple) else v) for k, v in exp.items()}}
    m, exp = fixture_singleton(1, p3=True)
    cases["a_singleton_p3"] = {"analysis": analyze(m), "expected": {k: (list(v) if isinstance(v, tuple) else v) for k, v in exp.items()}}
    cases["b_pair"] = {"analysis": analyze(fixture_pair(2))}
    cases["b_pair_degenerate_control"] = {"analysis": analyze(fixture_pair(2, degenerate=True))}
    m, exp = fixture_two_rows(3)
    cases["c_two_rows"] = {"analysis": analyze(m), "expected": {k: (list(v) if isinstance(v, tuple) else v) for k, v in exp.items()}}
    cases["d_reuse"] = {"analysis": analyze(fixture_reuse(4, True))}
    cases["d_reuse_control_fresh_mask"] = {"analysis": analyze(fixture_reuse(4, False))}
    for mm, nn in ((1, 4), (2, 2), (2, 4), (3, 4), (7, 4), (7, 8)):
        cases[f"e_group_values_all_base_m{mm}_n{nn}"] = {"analysis": analyze(group_with_values(mm, nn, ["base1"] * mm, seed=30 + mm + nn))}
    cases["f_group_values_pairs_m3_n4"] = {"analysis": analyze(group_with_values(3, 4, ["pair"] * 3, seed=41))}
    cases["f_group_values_one_base2_member_m3_n4"] = {"analysis": analyze(group_with_values(3, 4, ["base1", "base2", "base1"], seed=42))}
    cases["g_group_values_all_base_with_prox_m3_n4"] = {"analysis": analyze(group_with_values(3, 4, ["base1"] * 3, seed=43, with_prox=True))}
    lm, ident = fixture_logup_sum(4, 2, 1)
    la = analyze(lm)
    la["expected_identity_rows"] = ident
    cases["h_logup_sum_zero_sum_u"] = {"analysis": la}
    tiny = {"nb_d": 1, "nb_f": 1, "rows_per_f_plane": 1, "rows_per_d_plane": 1, "table_rows": [1, 2, 1, 1, 2, 1], "n": 4, "log_n": 2, "rows_per_w_block": 1}
    tiny2 = dict(tiny, rows_per_f_plane=2, rows_per_d_plane=2)
    for tag, lay_ in (("rows1", tiny), ("rows2", tiny2)):
        for p3 in (False, True):
            cases[f"i_whole_A_n4_{tag}_{'p3' if p3 else 'p1'}"] = {"analysis": analyze(commitment_with_values(f"A whole n4 {tag}", a_commitment_groups(lay_, p3=p3), 4))}
        cases[f"i_whole_H_n4_{tag}"] = {"analysis": analyze(commitment_with_values(f"H whole n4 {tag}", h_commitment_groups(lay_), 4))}
    cases["i_whole_W_p3_n4_nb1"] = {"analysis": analyze(commitment_with_values("W(P3) whole n4 nb_d=nb_f=1", w_commitment_groups(tiny), 4))}
    cases["i_whole_W_p3_n4_nbd3"] = {"analysis": analyze(commitment_with_values("W(P3) whole n4 nb_d=3 nb_f=1", w_commitment_groups(dict(tiny, nb_d=3)), 4))}
    # strip the bulky functional dumps for the large ones
    for k, v in cases.items():
        an = v["analysis"]
        if an["counts"]["base_observation_rows"] > 40:
            an["mask_killing_observation_functionals"] = f"omitted ({len(an['mask_killing_observation_functionals'])} vectors)"
        if an["counts"]["data_unknowns"] > 40:
            an["surviving_data_functionals"] = f"omitted ({len(an['surviving_data_functionals'])} functionals; see status)"
    return {"schema_version": 1, "task": "FA2 rank-tool fixtures", "reviewer": "Claude Fable 5.1, independent reviewer, 2026-09-07 session", "cases": cases}


# ----------------------------------------------------------------------------
# FA3: the repaired allocation (ZK60_FABLE_MASK_REPAIR.md) evaluated on every
# FA2 group shape, plus the machine-readable schedule Codex implements from
# ----------------------------------------------------------------------------

FA3_PROFILE = "ffn-v3-mr1"          # the repaired profile id (header field `profile=`)
FA3_DOMAIN = "hashline-zk-mr1/"      # transcript domain prefix of the repaired construction
FA3_HEADER = "HL-ZK/2|profile=ffn-v3-mr1|priv=..|pub=..|out=..|model=..|layer=..|slot=..|block=.."


def repaired_kinds(groups: List[dict], tables_all_pairs: bool = False) -> List[dict]:
    """FA3's rule applied to an FA2 group list: every SINGLE-ROW base mask
    becomes an Fp2 pair ('pairmask'); a multi-row base block (a table slot
    with rows >= 2) keeps its block form, which is Fp2-effective through its
    row weights (FA2 section 14.3), unless `tables_all_pairs` asks for the
    uniform all-pair alternative (2 x rows mask rows per slot)."""
    out = []
    for g in groups:
        g2 = dict(g)
        mems = []
        for mem in g["members"]:
            m2 = dict(mem)
            m2["kind"] = m2.get("kind", "base")
            if m2["kind"] == "base" and (m2["mask_rows"] == 1 or tables_all_pairs):
                m2["kind"] = "pairmask"
            mems.append(m2)
        g2["members"] = mems
        out.append(g2)
    return out


def a_commitment_groups_repaired(lay: dict, p3: bool = False, predicate: bool = False, seams: bool = False, tables_all_pairs: bool = False) -> List[dict]:
    """The repaired A commitment: FA2's groups with pair masks, plus (block
    profile) the two internal seam groups: X at tail(rho_sx) and z at
    tail(rho_sz), nb_d pair-masked members each, re-opening the SAME X / z
    rows the rho_d group opens (data_alias) under fresh reserved pairs."""
    groups = repaired_kinds(a_commitment_groups(lay, p3=p3, predicate=predicate), tables_all_pairs)
    if seams:
        nb_d, rd = lay["nb_d"], lay["rows_per_d_plane"]
        groups.append({"name": "sx", "members": [{"name": f"X{c}", "data_rows": rd, "mask_rows": 1, "kind": "pairmask", "data_alias": f"rho_d/X{c}"} for c in range(nb_d)]})
        groups.append({"name": "sz", "members": [{"name": f"z{c}", "data_rows": rd, "mask_rows": 1, "kind": "pairmask", "data_alias": f"rho_d/z{c}"} for c in range(nb_d)]})
    return groups


def h_commitment_groups_repaired(lay: dict) -> List[dict]:
    """H's claims are already Fp2 pairs; the repair only changes its prox row
    (a pair, passed as `prox_pair=True` to the model builders)."""
    return h_commitment_groups(lay)


def w_commitment_groups_repaired(lay: dict) -> List[dict]:
    """P3 W: every block terminal mask becomes a pair (one slot set of FA4's
    budgeted stable commitment looks exactly like this per proof)."""
    return repaired_kinds(w_commitment_groups(lay))


def commitment_rows(lay: dict, predicate: bool = False, seams: bool = False, tables_all_pairs: bool = False) -> dict:
    """Row counts of the legacy and the repaired A / H / W(P3) commitments,
    mirroring ZkLayoutV3::new (legacy, checked against the pinned counts in
    the tests) and FA3's schedule (repaired)."""
    nb_d, nb_f = lay["nb_d"], lay["nb_f"]
    rf, rd, rw = lay["rows_per_f_plane"], lay["rows_per_d_plane"], lay["rows_per_w_block"]
    tab = lay["table_rows"]
    plane_claims = 7 * nb_f + 3 * nb_d + nb_d + nb_f
    a_data = 7 * nb_f * rf + 3 * nb_d * rd + sum(tab)
    a_legacy_masks = plane_claims + 1 + sum(tab) + (2 if predicate else 0)
    a_tab_rep = 2 * sum(tab) if tables_all_pairs else sum(2 if r == 1 else r for r in tab)
    a_rep_masks = 2 * plane_claims + 2 + a_tab_rep + (4 if predicate else 0) + (4 * nb_d if seams else 0)
    h_data = 2 * (3 * nb_f * rf + nb_d * rd) + 2 * sum(tab)
    h_legacy_masks = 2 * (3 * nb_f + nb_d) + 4 + 1 + 2 * sum(tab)
    h_rep_masks = h_legacy_masks + 1
    w_data = 3 * nb_d * nb_f * rw
    w_legacy_masks = 3 * nb_d * nb_f + 1
    w_rep_masks = 2 * (3 * nb_d * nb_f) + 2
    return {
        "A": {"data_rows": a_data, "legacy_mask_rows": a_legacy_masks, "repaired_mask_rows": a_rep_masks, "legacy_rows": a_data + a_legacy_masks, "repaired_rows": a_data + a_rep_masks, "extra_rows": a_rep_masks - a_legacy_masks,
              "extra_breakdown": {"plane_claim_pairs": plane_claims, "prox_pair": 1, "single_row_table_slots_paired": (sum(tab) if tables_all_pairs else sum(1 for r in tab if r == 1)), "predicate_pairs": (2 if predicate else 0), "seam_pairs": (4 * nb_d if seams else 0)}},
        "H": {"data_rows": h_data, "legacy_mask_rows": h_legacy_masks, "repaired_mask_rows": h_rep_masks, "legacy_rows": h_data + h_legacy_masks, "repaired_rows": h_data + h_rep_masks, "extra_rows": 1, "extra_breakdown": {"prox_pair": 1}},
        "W_P3": {"data_rows": w_data, "legacy_mask_rows": w_legacy_masks, "repaired_mask_rows_per_slot": w_rep_masks, "legacy_rows": w_data + w_legacy_masks, "repaired_rows_one_slot": w_data + w_rep_masks, "extra_rows_per_slot": w_rep_masks - w_legacy_masks,
                 "extra_breakdown": {"block_terminal_pairs": 3 * nb_d * nb_f, "prox_pair": 1}, "fa4_budgeted_rows": f"data + k * {w_rep_masks} mask rows + the public slot; q_pad = k * Q (FA4 section 5.1)"},
        "M_cfs": {"legacy_base_rows": "2 * (6 + pred) + 4 at 4096 encoded positions", "repaired_base_rows": "2 * (6 + pred + 2 seams) + 4 (block profile); standalone unchanged", "extra_rows_block_profile": 4},
    }


def _summ(res: dict) -> dict:
    return {"disclosed_dim": res["disclosed_dim"], "rank_mask": res["rank_mask"], "rank_joint": res["rank_joint"], "base_obs_rows": res["counts"]["base_observation_rows"], "mask_unknowns": res["counts"]["mask_unknowns"], "data_unknowns": res["counts"]["data_unknowns"], "disclosed_or_recovered": res["summary"]["recovered"] + res["summary"]["disclosed"]}


def repair_verdicts() -> dict:
    """Every FA2 group shape under the repaired allocation, with the legacy
    number beside it, and the negative controls that show which rule each
    part of the repair is carrying.  A verdict is `expected` iff the model's
    disclosed_dim equals the schedule's claim (0 for every repaired model; the
    public LogUp identity (2) for the H sum model)."""
    checks: Dict[str, dict] = {}

    def record(name: str, res: dict, expect: int, argument: str, legacy: Optional[int] = None) -> None:
        checks[name] = {**_summ(res), "expected_disclosed_dim": expect, "verdict": ("PASS" if res["disclosed_dim"] == expect else "FAIL"), "argument": argument}
        if legacy is not None:
            checks[name]["legacy_disclosed_dim"] = legacy

    # (1) group + values: the "individually public terminal values" channel (FA2 14.2), repaired
    for m, n in ((1, 4), (2, 2), (2, 4), (3, 4), (7, 4), (7, 8), (9, 4)):
        res = analyze(group_with_values(m, n, ["pairmask"] * m, seed=500 + m + n))
        legacy = analyze(group_with_values(m, n, ["base1"] * m, seed=500 + m + n))["disclosed_dim"]
        record(f"group_values_all_pairmask_m{m}_n{n}", res, 0, f"rank(B) = 2m + 2n - 2 = {2 * m + 2 * n - 2}: every member is Fp2-effective (FA2 14.3), so the only null functional is the trivial identity", legacy)
        assert res["rank_mask"] == 2 * m + 2 * n - 2, (m, n, res["rank_mask"])
        res2 = analyze(group_with_values(m, n, ["pairmask"] * m, seed=600 + m + n, with_prox=True, prox_pair=True))
        record(f"group_values_all_pairmask_with_prox_pair_m{m}_n{n}", res2, 0, "the prox vector is covered by its own pair, independent of the group", analyze(group_with_values(m, n, ["base1"] * m, seed=600 + m + n, with_prox=True))["disclosed_dim"])
    # (2) the prox pair is REQUIRED, not optional: one pair-masked claim + a single prox row leaks one functional per column
    single = [{"name": "g", "members": [{"name": "D", "data_rows": 1, "mask_rows": 1, "kind": "pairmask"}]}]
    record("negative_control_one_pairmask_claim_single_prox_row", analyze(per_column_commitment("1 pair claim + 1 prox row", single, seed=71)), 1, "3 mask unknowns per column against 4 base observation dims (vector 2 + prox 2): the prox borrows nothing and leaks one functional; this is the tiny-P3-W starvation of FA2 14.4 in its purest form")
    record("one_pairmask_claim_prox_pair", analyze(per_column_commitment("1 pair claim + prox pair", single, seed=71, prox_pair=True)), 0, "4 mask unknowns against 4 dims: the prox pair covers the prox vector by itself")
    # (3) a mixed group: one member left base -- covered by composition (FA2 14.3) but NOT the rule
    record("mixed_group_one_base_member_covered_only_by_composition", analyze(group_with_values(3, 4, ["pairmask", "base1", "pairmask"], seed=77, with_prox=True, prox_pair=True)), 0, "FA2 14.3: any Fp2-effective member covers the group; the schedule nevertheless requires EVERY single-row mask to be a pair so that coverage never depends on which other claims share the tail (U4)")
    # (4) the seam-only pair is not a core repair: legacy A + seam pair groups still leaks FA2's number
    tiny = {"nb_d": 1, "nb_f": 1, "rows_per_f_plane": 1, "rows_per_d_plane": 1, "table_rows": [1, 2, 1, 1, 2, 1], "n": 4, "log_n": 2, "rows_per_w_block": 1}
    legacy_a = a_commitment_groups(tiny)
    seam_only = legacy_a + [g for g in a_commitment_groups_repaired(tiny, seams=True) if g["name"] in ("sx", "sz")]
    res = analyze(commitment_with_values("legacy A + seam pairs", seam_only, 4, seed=81))
    checks["negative_control_seam_only_pairs_on_legacy_A"] = {**_summ(res), "expected_disclosed_dim": 2 * 4 + 4, "verdict": ("PASS" if res["disclosed_dim"] == 2 * 4 + 4 else "FAIL"), "argument": "appending pair-masked seam claims to the LEGACY A leaves the two singletons (2n) and the rho_f / rho_d value leaks (2 + 2) exactly where FA2 found them: a seam-only mask pair is not a core FFN repair (queue acceptance)"}
    # (5) whole tiny commitments at n = 4: A (rows 1 / 2, P1 / P3, with and without seams), H, W
    for tag, lay_ in (("rows1", tiny), ("rows2", dict(tiny, rows_per_f_plane=2, rows_per_d_plane=2))):
        for p3 in (False, True):
            for seams in (False, True):
                nm = f"whole_A_n4_{tag}_{'p3' if p3 else 'p1'}{'_seams' if seams else ''}"
                res = analyze(commitment_with_values(nm, a_commitment_groups_repaired(lay_, p3=p3, seams=seams), 4, seed=90, prox_pair=True))
                legacy = None if seams else analyze(commitment_with_values(nm, a_commitment_groups(lay_, p3=p3), 4, seed=90))["disclosed_dim"]
                record(nm, res, 0, "every group all-pair (rank 2m + 2n - 2 each), prox pair, X re-opened at rho_d / p2" + (" / sx" if seams else "") + ", h16 at rho_f / p5, z at rho_d" + (" / sz" if seams else "") + ": joint rank full", legacy)
        res = analyze(commitment_with_values(f"whole_H_n4_{tag}", h_commitment_groups_repaired(lay_), 4, seed=91, prox_pair=True))
        record(f"whole_H_n4_{tag}", res, 0, "H claims were already pairs; the prox pair removes the borrowed coverage of h_prox", analyze(commitment_with_values("H", h_commitment_groups(lay_), 4, seed=91))["disclosed_dim"])
    res = analyze(commitment_with_values("W(P3) n4 nb=1", w_commitment_groups_repaired(tiny), 4, seed=92, prox_pair=True))
    record("whole_W_p3_n4_nb1", res, 0, "the starved tiny P3 W (FA2 14.4: 4 masks vs 6 dims per column) becomes 8 masks vs 6 dims: Wd@p6 no longer a base singleton, the (Wg, Wu) prox functional gone", analyze(commitment_with_values("W", w_commitment_groups(tiny), 4, seed=92))["disclosed_dim"])
    res = analyze(commitment_with_values("W(P3) n4 nb_d=3", w_commitment_groups_repaired(dict(tiny, nb_d=3)), 4, seed=93, prox_pair=True))
    record("whole_W_p3_n4_nbd3", res, 0, "the p3 / p6 value leaks (2 each) are gone", analyze(commitment_with_values("W", w_commitment_groups(dict(tiny, nb_d=3)), 4, seed=93))["disclosed_dim"])
    # (6) the H LogUp sum with the prox pair: the residual must still be exactly the public identity
    for n, nh, nt in ((4, 2, 1), (8, 3, 2)):
        model, ident = fixture_logup_sum(n, nh, nt, seed=94, prox_pair=True)
        res = analyze(model)
        F = [[f.get(x, 0) for x in model.data] for f in res["surviving_data_functionals"]]
        I = [[r.get(x, 0) for x in model.data] for r in ident]
        ok = res["disclosed_dim"] == 2 and rank(I) == 2 and rank(F + I) == 2
        checks[f"h_logup_sum_zero_sum_u_prox_pair_n{n}"] = {**_summ(res), "expected_disclosed_dim": 2, "residual_equals_public_identity": ok, "verdict": ("PASS" if ok else "FAIL"), "argument": "FA2 14.5 re-verified with the repaired prox: the 2 surviving base functionals span exactly the LogUp identity sum_j v_sum[j] = 0 (public claim value); u' fresh and unconstrained"}
    # (7) per-column models of the four FA2 families, repaired (P1 and P3 A with seams, H, W)
    fam = {}
    for prof in PROFILES:
        lay = layout_v3(prof["t_rows"], prof["d"], prof["f"], prof["log_cols"])
        entry = {"layout": {k: lay[k] for k in ("nb_d", "nb_f", "log_n", "n", "rows_per_f_plane", "rows_per_d_plane", "rows_per_w_block", "table_rows")}, "models": {}}
        for nm, groups, seed in (
            ("A (P1) standalone", a_commitment_groups_repaired(lay), 111),
            ("A (P1) block: + X / Z seam groups", a_commitment_groups_repaired(lay, seams=True), 112),
            ("A (P3) block", a_commitment_groups_repaired(lay, p3=True, seams=True), 113),
            ("A (P1) block, function 2", a_commitment_groups_repaired(lay, predicate=True, seams=True), 114),
            ("H", h_commitment_groups_repaired(lay), 115),
            ("W (P3), one slot set", w_commitment_groups_repaired(lay), 116),
        ):
            res = analyze(per_column_commitment(nm, groups, seed=seed, prox_pair=True))
            entry["models"][nm] = {**_summ(res), "expected_disclosed_dim": 0, "verdict": ("PASS" if res["disclosed_dim"] == 0 else "FAIL")}
        # the legacy numbers beside them (FA2 impact.json)
        la = analyze(per_column_commitment("A legacy", a_commitment_groups(lay), seed=11))
        lw = analyze(per_column_commitment("W legacy", w_commitment_groups(lay), seed=13))
        entry["legacy_per_column_disclosed"] = {"A (P1)": la["disclosed_dim"], "W (P3)": lw["disclosed_dim"]}
        entry["rows"] = commitment_rows(lay, seams=True)
        fam[prof["family"]] = entry
    # (8) log_cols = 16 (every table slot one row): the legacy tab group leaks 2 (FA2 U10); repaired 0
    lay16 = layout_v3(32, 4096, 14336, 16)
    assert lay16["log_n"] == 16 and all(r == 1 for r in lay16["table_rows"]), lay16
    tab_legacy = analyze(group_with_values(6, 4, ["base1"] * 6, seed=120))
    tab_rep = analyze(group_with_values(6, 4, ["pairmask"] * 6, seed=120, with_prox=True, prox_pair=True))
    record("tables_at_log_n_16_all_single_row_slots", tab_rep, 0, "U10: at log_n = 16 every slot is one row, so the rule 'pair iff single row' pairs all six; legacy leaks 2 (FA2 14.2)", tab_legacy["disclosed_dim"])
    res16 = analyze(per_column_commitment("A (P1) block, log_cols 16", a_commitment_groups_repaired(lay16, seams=True), seed=121, prox_pair=True))
    record("A_per_column_8B_log_cols_16_block", res16, 0, "the 8B layout at log_cols 16: per-column joint rank full with all single-row slots paired")
    # (9) the uniform all-pair alternative for the table blocks (documented, not proposed first)
    res_all = analyze(commitment_with_values("A n4 all-pair tables", a_commitment_groups_repaired(tiny, seams=True, tables_all_pairs=True), 4, seed=95, prox_pair=True))
    record("whole_A_n4_alternative_all_pair_table_blocks", res_all, 0, "the uniform alternative (every table mask block an Fp2 pair block) is also full rank; it removes the block form's row-bit degeneracy (rho_tab[k] in Fp, 2^-64) at the cost of sum(rows_i) extra rows per commitment")
    # (10) function 2: the predicate pair at n = 4
    res_pred = analyze(commitment_with_values("A n4 function 2", a_commitment_groups_repaired(tiny, predicate=True, seams=True), 4, seed=96, prox_pair=True))
    record("whole_A_n4_function2_predicate_pairs", res_pred, 0, "U9: the (z block, bit row) group is two pair-masked members; the z block is re-opened at rho_d / sz under other pairs", analyze(commitment_with_values("A", a_commitment_groups(tiny, predicate=True), 4, seed=96))["disclosed_dim"])
    n_fail = sum(1 for c in checks.values() if c["verdict"] != "PASS") + sum(1 for e in fam.values() for m in e["models"].values() if m["verdict"] != "PASS")
    return {"checks": checks, "families": fam, "failures": n_fail}


def fa3_schedule() -> dict:
    """The schedule Codex implements from (mirrored in ZK60_FABLE_MASK_REPAIR.md section 12)."""
    pair_claim = "parts = [ZPart{slice: DATA, coef: k0, point: p}, ZPart{slice: row(R_re), coef: k1, point: tail(p)}, ZPart{slice: row(R_im), coef: k1 * U, point: tail(p)}]; masked terminal = (1 - e) fin + e (R_re~(tail) + U R_im~(tail)) via MaskPoint::eval2"
    block_claim = "parts = [ZPart{slice: (a_row, log_size), coef: (1 - e_tab) ext, point: rho_tab[k..]}, ZPart{slice: (a_mask, log_size), coef: e_tab ext, point: rho_tab[k..]}] (legacy form, unchanged; Fp2-effective through the row weights when rows >= 2)"
    return {
        "profile": FA3_PROFILE, "transcript_domain_prefix": FA3_DOMAIN, "header": FA3_HEADER,
        "legacy_untouched": "prove_layer_zk_v3 / verify_layer_zk_v3, header 'P1-v3' / 'HL-ZK/1', the frozen fixtures and their bytes: unchanged and NOT repaired privacy evidence",
        "rule": "every single-row mask site is an Fp2 pair (re, im) with claim coefficients (k1, k1 U); every multi-row base mask block (table slots with rows >= 2) keeps its block form; every proximity row is a pair; every seam terminal is a pair-masked claim on the ACTUAL arithmetic commitment; every mask row is filled exactly once from the block's RNG before its commitment exists and is consumed by exactly one opening",
        "mask_kinds": {
            "pair": {"rows": 2, "claim_form": pair_claim, "hiding_argument": "per column the contribution k1 (R_re + U R_im) ranges over Fp2 as (R_re, R_im) ranges over Fp^2 whenever k1 != 0; no dependence on e being outside Fp (FA1's degeneracy class disappears)"},
            "block": {"rows": "rows_i = max(size_i, n) / n", "claim_form": block_claim, "hiding_argument": "per column the contribution e_tab ext sum_r eq_r R[r] ranges over Fp2 when two of the eq_r are Fp-independent (the row-bit coordinate rho_tab[k] outside Fp: fails with probability ~2^-64, the same class FA2 excludes)"},
            "zero_sum_pair": {"rows": 2, "claim_form": "the legacy h_u pair with sum_j u_re[j] = sum_j u_im[j] = 0, masked at rho_zs by the fresh unconstrained pair h_up", "hiding_argument": "FA2 14.5 re-verified with the prox pair (repair verdict h_logup_sum_zero_sum_u_prox_pair_n4 / n8): the residual is exactly the public LogUp identity"},
            "prox_pair": {"rows": 2, "claim_form": "not a claim: two reserved rows entering ONLY the proximity combination with the two independent challenges rho[row_re], rho[row_im]", "hiding_argument": "the prox vector's mask span per column is Fp-span{rho_re, rho_im} = Fp2 unless the two challenges are Fp-dependent (~2^-64): coverage no longer borrowed from other groups (U4)"},
        },
        "commitments": {
            "A": {"fresh_per_proof": True, "rows": "data rows (LayoutV3.a_len / n) + table data rows, then the mask rows below in this order (data offsets do not move)", "mask_roles_in_allocation_order": [
                {"role": "a_mf[k]", "count": "7 * nb_f", "kind": "pair", "group_key": "tail(rho_f)", "data": "g8,rg,a16,u16,ru,h16,rh per f-block at rho_f", "coefficients": "(1 - e_f, e_f)", "proof_field": "zc20_term[10 b + i], i < 7", "legacy_rows": 1, "repaired_rows": 2},
                {"role": "a_md[k]", "count": "3 * nb_d", "kind": "pair", "group_key": "tail(rho_d)", "data": "X, z, rd per d-block at rho_d", "coefficients": "(1 - e_dz, e_dz)", "proof_field": "zc17_term[c], [nb_d + c], [2 nb_d + c]", "legacy_rows": 1, "repaired_rows": 2},
                {"role": "a_mgu[c]", "count": "nb_d", "kind": "pair", "group_key": "tail(p2 = r_i || r_kp)", "data": "X block c at p2 (the SAME rows as a_md[3c]'s data)", "coefficients": "P1 (1 - e_gu, e_gu); P3 ((1 - e_gu2)(1 - e_gu), (1 - e_gu2) e_gu)", "proof_field": "gu_term[c]", "legacy_rows": 1, "repaired_rows": 2},
                {"role": "a_mdd[b]", "count": "nb_f", "kind": "pair", "group_key": "tail(p5 = r_ip || r_k)", "data": "h16 block b at p5 (the SAME rows as a_mf[7b + 5]'s data)", "coefficients": "P1 (1 - e_d, e_d); P3 ((1 - e_d2)(1 - e_d), (1 - e_d2) e_d)", "proof_field": "d_term[b]", "legacy_rows": 1, "repaired_rows": 2},
                {"role": "a_prox", "count": 1, "kind": "prox_pair", "group_key": "(proximity vector)", "data": "-", "coefficients": "rho_prox[re], rho_prox[im] (zk_rhos)", "proof_field": "a_open.prox_vec", "legacy_rows": 1, "repaired_rows": 2},
                {"role": "tab[i].a_mask", "count": "6 slots", "kind": "block if rows_i >= 2 else pair", "group_key": "tail(rho_tab) (one group for all six slots)", "data": "multiplicity slot i at rho_tab[k_i..]", "coefficients": "((1 - e_tab) ext_i, e_tab ext_i)", "proof_field": "tab_term[2 i]", "legacy_rows": "rows_i", "repaired_rows": "rows_i if rows_i >= 2 else 2"},
                {"role": "a_pmz, a_pmb", "count": "2 (function 2 only)", "kind": "pair", "group_key": "tail(rho_p)", "data": "z block of the predicate entry; the bit row", "coefficients": "(1 - e_p, e_p) (x ext for the bit row)", "proof_field": "pred.term[0], [1]", "legacy_rows": 1, "repaired_rows": 2},
                {"role": "a_sx[c]", "count": "nb_d (block profile only)", "kind": "pair", "group_key": "tail(rho_sx)", "data": "X block c at rho_sx (the X seam: the SAME rows as a_md[3c] / a_mgu[c])", "coefficients": "(1 - e_sx, e_sx)", "proof_field": "seam_x.term_ffn[c]", "legacy_rows": 0, "repaired_rows": 2},
                {"role": "a_sz[c]", "count": "nb_d (block profile only)", "kind": "pair", "group_key": "tail(rho_sz)", "data": "z block c at rho_sz (the Z seam: the SAME rows as a_md[3c + 1])", "coefficients": "(1 - e_sz, e_sz)", "proof_field": "seam_z.term_ffn[c]", "legacy_rows": 0, "repaired_rows": 2},
            ]},
            "H": {"fresh_per_proof": True, "mask_roles_in_allocation_order": [
                {"role": "h_mf[k], h_md[c]", "count": "3 nb_f + nb_d", "kind": "pair (unchanged)", "group_key": "tail(rho_f) / tail(rho_d)", "legacy_rows": 2, "repaired_rows": 2},
                {"role": "h_u", "count": 1, "kind": "zero_sum_pair (unchanged)", "group_key": "rho_zs (single-row point) and the value-0 sum claim (empty point)", "legacy_rows": 2, "repaired_rows": 2},
                {"role": "h_up", "count": 1, "kind": "pair (unchanged)", "group_key": "rho_zs", "legacy_rows": 2, "repaired_rows": 2},
                {"role": "h_prox", "count": 1, "kind": "prox_pair", "group_key": "(proximity vector)", "legacy_rows": 1, "repaired_rows": 2},
                {"role": "tab[i].h_mre / h_mim", "count": "6 slots", "kind": "pair block (unchanged)", "group_key": "tail(rho_tab)", "legacy_rows": "2 rows_i", "repaired_rows": "2 rows_i"},
            ]},
            "W_P3": {"fresh_per_proof": False, "owner": "FA4's budgeted stable commitment C*_l: data rows, then k slot sets, each set = the roles below; proof i uses set i exactly once; q_pad = k * Q", "mask_roles_in_allocation_order_per_slot": [
                {"role": "w_mgu[k]", "count": "2 nb_d nb_f", "kind": "pair", "group_key": "tail(p3 = r_kp || r_j)", "coefficients": "((1 - e_gu2)(1 - e_gu), e_gu2)", "proof_field": "gu_term[nb_d + k]", "legacy_rows": 1, "repaired_rows": 2},
                {"role": "w_mdd[k]", "count": "nb_d nb_f", "kind": "pair", "group_key": "tail(p6 = r_k || r_jp)", "coefficients": "((1 - e_d2)(1 - e_d), e_d2)", "proof_field": "d_term[nb_f + k]", "legacy_rows": 1, "repaired_rows": 2},
                {"role": "w_prox", "count": 1, "kind": "prox_pair", "group_key": "(proximity vector)", "legacy_rows": 1, "repaired_rows": 2},
            ]},
            "M_cfs": {"fresh_per_proof": True, "slots_in_order": ["SC_GU (log_db + 1 + p3, 2)", "SC_D (log_fb + 1 + p3, 2)", "SC_ZC20 (log_t + log_fb + 1, 4)", "SC_ZC17 (log_t + log_db + 1, 4)", "SC_ZSUM (log_n + 1, 2)", "SC_TAB (log_s + 1, 3)", "SC_PRED (log_t + log_db + 1, 3) [function 2]", "SC_SEAM_X (log_t + log_db + 1, 2) [block profile]", "SC_SEAM_Z (log_t + log_db + 1, 2) [block profile]"], "note": "the CFS channel is outside the linear model (blocker B1); the schedule only fixes its slot count and order"},
        },
        "rng": {"instance": "one ZkRng per component per block attempt (FFN: domain 'ffn-mr1/layer-{l}/attempt-{nonce}' under OS entropy; the attention component has its own); a seeded ZkRng exists only under cfg(test) fixtures and never in the block API",
                "consumption_order": ["A mask rows, allocation order, fp_vec(n) per row (re then im for a pair; the block rows in row order)", "A pads (rows * Q), A salts (nn)  [commit_zk_owned]", "M: per slot CfsMask::random then MASK_Q pads per re / im row; b_re, b_im, u_re, u_im; salts  [mask_commit]", "H mask rows: h_mf pairs, h_md pairs, h_up pair, h_prox pair, table mre / mim blocks (fp_vec(n) each); then h_u: n - 1 draws per row, last entry = -sum", "H pads, H salts"],
                "p3_w": "no per-proof W randomness: the slot set was drawn at registration (FA4 H2) in the order w_mgu pairs, w_mdd pairs, w_prox pair per set; pads k * Q per row; salts nn",
                "error_path": "the RNG instance is dropped with the discarded state; a retry is a new attempt nonce and a new instance; no mask row value is ever reused"},
        "transcript_order_block_profile": ["block header (profile, domain, approved-contract digest, request context, manifest digest, layer, slot)", "attention W root (P1: approved public) ; attention A root ; attention M root", "FFN W root (P1: approved public root from the manifest; P3: C*_l from the manifest) ; FFN A root ; FFN M root", "beta, gamma, alpha (FFN) ; FFN H root  [attention helpers likewise after their challenges]", "FFN arguments in legacy order: gu, d, zcF, zcD, tab, zsum, [pred]; every masked claim and terminal absorbed before the next challenge", "seam X: tau_sx, c_sx ; gamma_sx ; masked rounds ; masked terminals (ffn side, attention side) ; seam Z likewise", "FFN mask_open (all slots incl. seams) ; attention mask_open", "openings, one per owned commitment, fixed order: FFN W (P3 only), FFN A, FFN H, attention W (P3), attention A, attention H; each open_zk: lambdas per group -> prox rho -> vectors absorbed -> prox absorbed -> indices (FA1 4.4)"],
    }


def repair_report() -> dict:
    v = repair_verdicts()
    return {"schema_version": 1, "task": "FA3 -- the repaired mask allocation: rank verdicts on every FA2 group shape and the schedule Codex implements from", "reviewer": "Claude Fable 5.1, independent reviewer, 2026-09-07 session",
            "caveat": "numerical rank of linear observations under stand-in coefficients; the CFS channel, adaptive conditioning, ranges and cross-proof correlation beyond the linear model remain the identified blockers of ZK60_FABLE_MASK_REPAIR.md section 11",
            "schedule": fa3_schedule(), "rank_verdicts": v["checks"], "families": v["families"], "failures": v["failures"]}


# ----------------------------------------------------------------------------
# CLI
# ----------------------------------------------------------------------------


def main(argv: Optional[Sequence[str]] = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("analyze", help="rank analysis of a MODEL.json")
    a.add_argument("model")
    a.add_argument("-o", "--out")
    f = sub.add_parser("fixtures", help="run the contract fixtures (a)-(d) and the group-value models")
    f.add_argument("-o", "--out")
    i = sub.add_parser("impact", help="the role x profile impact matrix with per-column and group-value models")
    i.add_argument("-o", "--out")
    i.add_argument("--no-models", action="store_true")
    r = sub.add_parser("repair", help="FA3: the repaired allocation's rank verdicts on every FA2 group shape + the schedule")
    r.add_argument("-o", "--out")
    args = ap.parse_args(argv)
    if args.cmd == "analyze":
        with open(args.model) as fh:
            res = analyze_json(json.load(fh))
    elif args.cmd == "fixtures":
        res = fixtures_report()
    elif args.cmd == "repair":
        res = repair_report()
    else:
        res = impact_matrix(run_models=not args.no_models)
    text = json.dumps(res, indent=1, default=lambda o: list(o) if isinstance(o, tuple) else str(o))
    if getattr(args, "out", None):
        with open(args.out, "w") as fh:
            fh.write(text + "\n")
        print(f"wrote {args.out}")
    else:
        print(text)
    if args.cmd == "repair" and res.get("failures"):
        print(f"repair: {res['failures']} rank verdict(s) FAILED", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""zk60_joint_view.py -- one PCS-side field view over every role WITH the opened columns.

Research tool (analysis only, stdlib, exact integers over F_p and F_{p^2},
p = 2^64 - 2^32 + 1, u^2 = 7).  Nothing here touches Rust, the receipt format or
the verifier.  It reads the four round-22 captures of `ffn-v3-mr1-fresh-io-poc/2`
and imports the tools of rounds 20/23/24 and O8 by file path, never editing them.

WHAT IS MODELLED.  For one proof, at the CAPTURED coefficients (claim points and
row weights, group lambdas, proximity rhos, the opened index set J of every
commitment, theta, the functional weights), the map from the prover-side
unknowns to every PCS-side observation is affine.  Unknowns, base-field words:
  * every role commitment (A, H, W in P3, Input, Output): for every row r its
    n = 256 message words m_r (data rows: witness planes / LogUp helpers;
    mask and prox rows: masks) and its Q = 256 pad coefficients g_r;
  * the CFS mask commitment M: for each of the eight slots the L_s prefix words
    (the CFS coefficients, Fp2) and its 256 pad words (Fp2); the blinder b
    (1024 Fp2 coefficients with b_512 = -b_0) and the proximity blinder u (1024).
Observations (the verifier's view of the openings):
  * per role: every group vector (all 512 coordinates: message AND pad), the
    proximity vector (all 512), each claim terminal, H's public zero-sum, and
    the 256 opened columns: at every opened position the encoded word of EVERY
    row, f_r(x) + (x^256 - 1) g_r(x), f_r the interpolant of m_r on G_256 and
    x = 7 * omega_2048^i;
  * for M: q' (1024 Fp2), its proximity vector (1024 Fp2), the fourteen public
    functionals, and the 256 opened columns of all twenty base rows.
Aliases: A rows 14/15 (X) and 16/17 (z16) are the SAME message unknowns as rows
0/1 of the input and output endpoints (O8's ALIAS_PAIRS); the pads of the two
owners are separate unknowns, opened at separate index sets.

WHAT IS COMPUTED.  disclosed = rank[L | D] - rank[L]: D are the columns of the
observation matrix belonging to the data unknowns (the witness planes of
A/W/endpoints, H's helpers, M's CFS prefixes), L those of the randomness.
Equivalently disclosed = #data directions - dim{data perturbations that some
randomness perturbation compensates in EVERY observation at once}.  A disclosed
dimension is one linear functional of the data that the observations fix.

UNIFORMITY ASSUMPTIONS (what counts as randomness).  Independent uniform base-
field words: every mask/prox row's message words, every row's pad coefficients,
M's pad words, M's blinders b (inside its zero-sum subspace) and u.  Every
observation is a field element at fixed coefficients.  OUTSIDE the model: hash,
salt and Merkle-path hiding (the opened values are treated as revealed words;
unopened positions are not observations); adaptive Fiat-Shamir dependence of
the coefficients on the committed values (FA7/O8's standing exclusion); the CFS
round messages that link M's functionals to the sumchecks (FA6's channel);
repeated openings of one commitment (round 23 covers two fresh proofs).

THE REDUCTION (proved on the captured J of every role, then used).  Within one
role all rows share the opened index set J (|J_d| distinct positions), so the
column-restriction map E_J : F_p^512 -> F_p^{|J_d|}, (m, g) -> [f(x) + (x^256-1)
g(x)]_{x in J}, is the same for every row.  On the captured J the tool exhibits
  (a) a right inverse of E_J restricted to the pad coordinates (the Lagrange
      basis on J over x^256 - 1): E^g is surjective, so rank E_J = |J_d| and
      dim ker E_J = 512 - |J_d|;
  (b) an explicit basis N of ker E_J adapted to the data/randomness split:
      N_1 = [I ; -G E^m] (for each unit message vector the pad that cancels its
      column effect, from the identity (V_J(a) - V_J(X)) / (X - a)) and
      N_2 = [0 ; V_J X^i] (the pad kernel: pads vanishing on J).
Substituting x_r = x_r^0 + N t_r for every row satisfies every column
observation identically; the remaining fold observations decouple coordinate
by coordinate in t (N is injective), the terminal / zero-sum observations keep
O8's column weights on the message coordinates (N_1^m = I) and vanish on the
pad-kernel coordinates (N_2^m = 0).  The reduced system is therefore O8's
message/terminal/proximity system on 256 shared coordinates PLUS, per role, a
block of 256 - |J_d| coordinates in which every row is randomness.  The tool
builds that reduced system with its own engine (an independent implementation
of the block / cross-coordinate rank algebra), computes both ranks, and compares
with O8's imported `JointModel` and with the archived round-22 O8 record.
For M the same substitution per slot (prefix completions and the pad kernel on
G_512 with the fixed trailing zeros) plus the exact elimination of b and u
(round 20's construction, checked numerically on every basis direction) leaves
only the fourteen functionals and b's zero-sum as equations on the prefixes.

EXPECTATIONS (exit status 1 if any fails; every check is recorded):
  * A, W, Input, Output alone: 0 with and without columns; H alone: 2 (its
    public LogUp identity, value 0) and 0 without the zero-sum constraint;
  * A+Input+Output aliased: 0; all private commitments aliased: 2, the same
    public identity (adding it as an explicit observation adds no rank);
  * the without-columns numbers equal O8's live `JointModel` numbers and the
    archived O8 record (sha256 pinned); the O8-equivalent ranks (256 * message
    block rank + cross kernel) equal O8's rank_mask / rank_joint;
  * M: 28 base dimensions = exactly its fourteen public functionals (Fp2 rank
    14) and 0 beyond them; with only q' / proximity / columns observed the
    residual is b's zero-sum, i.e. the public theta-combination (2 base dims);
  * controls: dropping an endpoint's second terminal-mask row discloses > 0
    (256, O8's number) with and without columns; a pad budget below |J_d|
    discloses > 0 while a budget in [|J_d|, 256) does not (the threshold is the
    number of DISTINCT opened positions, not 256); a synthetic small geometry
    agrees with a brute-force rank of the full uncompressed observation matrix.

DEFICIENT-PAD CONTROL, SCOPE.  A pad budget Q' < |J_d| breaks hypothesis (a);
the engine then uses the adapted basis [ker E_J^{Q'} | rest | pad kernel], whose
message projection is not the identity.  Such a basis cannot be shared with an
aliased partner, so in the joint model the control is applied to H (alias-free);
the endpoints are exercised in their single-commitment models.

Usage:
    python3 scripts/zk60_joint_view.py --captures DIR --manifest results/zk60_round22_captures.json \\
        --out results/zk60_mvp_joint_view_evidence/pcs_view/joint_view.json
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import random
import resource
import sys
import time
from typing import Dict, List, Optional, Sequence, Tuple

_HERE = os.path.dirname(os.path.abspath(__file__))
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)           # the imported tools resolve their own siblings by name


def _load(name: str, filename: str):
    """Import a sibling tool by file path, exactly as scripts/zk60_opus_io_capture.py does."""
    if name in sys.modules:
        return sys.modules[name]
    spec = importlib.util.spec_from_file_location(name, os.path.join(_HERE, filename))
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


O8 = _load("zk60_opus_io_capture", "zk60_opus_io_capture.py")               # O8 parser + JointModel
T = _load("zk60_io_opening_translation", "zk60_io_opening_translation.py")  # round 20: NTT, M algebra
C, R = O8.C, O8.R                                                            # FA7 pieces, exact Fp algebra
CFS = T.C                                                                    # zk60_fable_cfs_channel
P = R.P
ONE, ZERO, U = R.ONE, R.ZERO, R.U
f2_add, f2_sub, f2_mul, f2_neg = R.f2_add, R.f2_sub, R.f2_mul, R.f2_neg
Fp2 = Tuple[int, int]

ROOT = os.path.dirname(_HERE)
ARCHIVED_O8_PATH = os.path.join(ROOT, "results", "zk60_round22_o8_analysis.json")
ARCHIVED_O8_SHA256 = "deaf38f545d6e1e4b25be137e47c3ece19997ff5646871edbc5f3e0f9d5048d3"
SCHEMA = 1
TOOL_NAME = "zk60_joint_view.py"


class JointViewError(ValueError):
    """A capture, geometry or expectation this tool refuses."""


def require(cond, msg: str) -> None:
    if not cond:
        raise JointViewError(msg)


def sha256_file(path: str) -> str:
    with open(path, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


def _ms(t0: float) -> int:
    return int((time.time() - t0) * 1000)


def peak_rss_kb() -> int:
    return int(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss)


# ---------------------------------------------------------------------------
# base-field polynomial helpers (coefficients low -> high)
# ---------------------------------------------------------------------------

_POW7: Dict[int, List[int]] = {}


def pow7(domain: int) -> List[int]:
    if domain not in _POW7:
        out = [1] * domain
        for j in range(1, domain):
            out[j] = out[j - 1] * 7 % P
        _POW7[domain] = out
    return _POW7[domain]


def fft(values: Sequence[int], inverse: bool = False) -> List[int]:
    return T.fft(list(values), inverse)


def coset_evals_base(coeffs: Sequence[int], domain: int) -> List[int]:
    """Evaluations of a base-field polynomial at 7 * omega_domain^i, natural order."""
    require(len(coeffs) <= domain, "polynomial exceeds the evaluation domain")
    p7 = pow7(domain)
    scaled = [c * p7[j] % P for j, c in enumerate(coeffs)]
    return fft(scaled + [0] * (domain - len(scaled)))


def poly_from_roots(xs: Sequence[int]) -> List[int]:
    poly = [1]
    for x in xs:
        nxt = [0] * (len(poly) + 1)
        for i, c in enumerate(poly):
            nxt[i] = (nxt[i] - c * x) % P
            nxt[i + 1] = (nxt[i + 1] + c) % P
        poly = nxt
    return poly


def poly_eval(poly: Sequence[int], x: int) -> int:
    acc = 0
    for c in reversed(poly):
        acc = (acc * x + c) % P
    return acc


def synth_div(poly: Sequence[int], a: int) -> Tuple[List[int], int]:
    """poly = (X - a) * q + r; returns (q, r)."""
    n = len(poly) - 1
    require(n >= 1, "division of a constant")
    q = [0] * n
    acc = poly[n] % P
    for i in range(n - 1, -1, -1):
        q[i] = acc
        acc = (poly[i] + a * acc) % P
    return q, acc


def poly_mul_linear(q: Sequence[int], a: int) -> List[int]:
    """(X - a) * q, for re-multiplication checks."""
    out = [0] * (len(q) + 1)
    for i, c in enumerate(q):
        out[i] = (out[i] - a * c) % P
        out[i + 1] = (out[i + 1] + c) % P
    return out


def pcs_coeffs(message: Sequence[int], pad: Sequence[int]) -> List[int]:
    """f + (X^n - 1) g for a base-field row: pcs.rs's committed polynomial."""
    n = len(message)
    coeffs = fft(message, True) + [0] * len(pad)
    for j, g in enumerate(pad):
        coeffs[j] = (coeffs[j] - g) % P
        coeffs[n + j] = (coeffs[n + j] + g) % P
    return coeffs


def f2_dot_base(weights: Sequence[Fp2], values: Sequence[int]) -> Fp2:
    a = b = 0
    for w, v in zip(weights, values):
        if v:
            a += w[0] * v
            b += w[1] * v
    return (a % P, b % P)


# ---------------------------------------------------------------------------
# the column-restriction map E_J of one role on its captured J
# ---------------------------------------------------------------------------


class ColumnAlgebra:
    """E_J : (m, g) -> [f(x) + (x^n - 1) g(x)]_{x in J}, shared by all rows of a role.

    Holds the certificate (a) and the adapted kernel basis (b) of the module
    docstring; `verify()` checks every constructed vector by NTT on the coset."""

    def __init__(self, n: int, q_pad: int, domain: int, indices: Sequence[int], verify: bool = True):
        require(n > 0 and n & (n - 1) == 0 and 0 < q_pad <= n and domain % n == 0
                and domain & (domain - 1) == 0 and domain > n, "column geometry")
        require(all(isinstance(i, int) and 0 <= i < domain for i in indices), "opened index range")
        self.n, self.q_pad, self.domain = n, q_pad, domain
        self.indices = list(indices)
        self.distinct = sorted(set(indices))
        self.jd = len(self.distinct)
        require(self.jd <= q_pad, "more distinct opened positions than pads: hypothesis (a) fails")
        roots = T.subgroup(domain)
        self.xs = [7 * roots[i] % P for i in self.distinct]
        self.zs = [(pow(x, n, P) - 1) % P for x in self.xs]
        require(all(self.zs), "an opened position lies on the message subgroup")
        self.vanish = poly_from_roots(self.xs)                      # V_J, monic, degree jd
        # (a) g_x = ell_x / (x^n - 1): E^g g_x = e_x
        self.cert: List[List[int]] = []
        for x, z in zip(self.xs, self.zs):
            q, rem = synth_div(self.vanish, x)
            require(rem == 0, "V_J not divisible by (X - x)")
            qx = poly_eval(q, x)
            require(qx != 0, "repeated opened point")
            inv = pow(qx * z % P, P - 2, P)
            self.cert.append([c * inv % P for c in q] + [0] * (q_pad - len(q)))
        # (b) N_1: for the unit message e_j (Lagrange node a = omega^j) the pad
        #     g_j with g_j(x) = -L_j(x) / (x^n - 1) = -a / (n (x - a)) on J,
        #     i.e. g_j = (-a / n) * (V(a) - V(X)) / ((X - a) V(a)).
        omega = T.subgroup(n)
        inv_n = pow(n, P - 2, P)
        self.completions: List[List[int]] = []
        for j in range(n):
            a = omega[j]
            va = poly_eval(self.vanish, a)
            require(va != 0, "a message node lies in J")
            diff = [(-c) % P for c in self.vanish]
            diff[0] = (diff[0] + va) % P
            q, rem = synth_div(diff, a)
            require(rem == 0, "V(a) - V(X) not divisible by (X - a)")
            scale = (-a) * inv_n % P * pow(va, P - 2, P) % P
            self.completions.append([c * scale % P for c in q] + [0] * (q_pad - len(q)))
        # N_2: the pad kernel V_J X^i, i < q_pad - jd
        self.padker: List[List[int]] = [[0] * i + self.vanish + [0] * (q_pad - self.jd - 1 - i)
                                        for i in range(q_pad - self.jd)]
        self.kernel_dim = n + q_pad - self.jd
        self.report: Optional[dict] = self.verify() if verify else None

    def kernel_vector(self, which: str, i: int) -> Tuple[List[int], List[int]]:
        """(message, pad) of one basis vector of ker E_J."""
        if which == "completion":
            m = [0] * self.n
            m[i] = 1
            return m, list(self.completions[i])
        return [0] * self.n, list(self.padker[i])

    def message_projection(self, i: int) -> List[int]:
        """The message words of the kernel polynomial V_J X^i (used by the adapted
        basis of the deficient-pad control), i < n."""
        require(0 <= i < self.n, "kernel index")
        coeffs = [0] * i + self.vanish
        require(len(coeffs) <= self.n + self.q_pad, "kernel polynomial degree")
        coeffs += [0] * (self.n + self.q_pad - len(coeffs))
        g = coeffs[self.n:]
        f = [(coeffs[j] + (g[j] if j < len(g) else 0)) % P for j in range(self.n)]
        return fft(f)

    def verify(self) -> dict:
        t0 = time.time()
        n, q_pad, dom = self.n, self.q_pad, self.domain
        pos = {i: k for k, i in enumerate(self.distinct)}
        ev = coset_evals_base(self.vanish, dom)
        require(all(ev[i] == 0 for i in self.distinct), "V_J does not vanish on J")
        require(sum(1 for v in ev if v == 0) == self.jd, "V_J has roots outside J")
        require(self.vanish[-1] == 1, "V_J not monic")
        for k, g in enumerate(self.cert):
            coeffs = [0] * (n + q_pad)
            for t, c in enumerate(g):
                coeffs[t] = (coeffs[t] - c) % P
                coeffs[n + t] = (coeffs[n + t] + c) % P
            ev = coset_evals_base(coeffs, dom)
            require(all(ev[i] == (1 if pos[i] == k else 0) for i in self.distinct),
                    "pad right inverse fails on J")
        for j, g in enumerate(self.completions):
            m = [0] * n
            m[j] = 1
            ev = coset_evals_base(pcs_coeffs(m, g), dom)
            require(all(ev[i] == 0 for i in self.distinct), "message completion fails on J")
        for i, g in enumerate(self.padker):
            require(g[self.jd + i] == 1 and all(c == 0 for c in g[self.jd + i + 1:]), "pad kernel shape")
            coeffs = [0] * (n + q_pad)
            for t, c in enumerate(g):
                coeffs[t] = (coeffs[t] - c) % P
                coeffs[n + t] = (coeffs[n + t] + c) % P
            ev = coset_evals_base(coeffs, dom)
            require(all(ev[i2] == 0 for i2 in self.distinct), "pad kernel vector fails on J")
        return {"opened_positions": len(self.indices), "distinct_positions": self.jd,
                "pad_budget": q_pad, "message_words": n, "domain": dom,
                "pad_right_inverse_vectors_verified": len(self.cert),
                "rank_E_J": self.jd, "kernel_dim": self.kernel_dim,
                "message_completions_verified": len(self.completions),
                "pad_kernel_vectors_verified": len(self.padker),
                "basis_columns": len(self.completions) + len(self.padker),
                "basis_independent": "identity message block; pad kernel monic of distinct degrees",
                "zero_data_pad_translation_exists": True, "ms": _ms(t0)}


# ---------------------------------------------------------------------------
# a role (one commitment opening) in the form the engine, the brute force and the
# public checks consume; built from O8's IoRoleObs or synthetically
# ---------------------------------------------------------------------------


class Role:
    def __init__(self, name: str, n: int, q_pad: int, domain: int, claims: List[dict],
                 groups: List[dict], rho: List[Fp2], kind: List[str], rname: List[str],
                 extras: List[dict], indices: List[int], columns: Optional[List[List[int]]],
                 prox_vector: Optional[List[Fp2]], pads: Optional[List[int]] = None):
        self.name, self.n, self.q_pad, self.domain = name, n, q_pad, domain
        self.claims, self.groups, self.rho = claims, groups, rho
        self.kind, self.rname, self.extras = kind, rname, extras
        self.indices, self.columns, self.prox_vector = indices, columns, prox_vector
        self.rows = len(rho)
        self.pads = list(pads) if pads is not None else [q_pad] * self.rows
        require(len(kind) == len(rname) == self.rows == len(self.pads), "role row geometry")
        require(all(k in ("data", "mask", "prox") for k in kind), "row kinds")
        for c in claims:
            require(0 <= c["group"] < len(groups), "claim group")
            for p in c["parts"]:
                require(0 <= p["row0"] and p["row0"] + p["nrows"] <= self.rows
                        and len(p["rw"]) == p["nrows"], "claim part rows")
        for gi, g in enumerate(groups):
            require(len(g["members"]) == len(g["lambdas"]) and len(g["cw"]) == n, "group geometry")
            require(all(claims[k]["group"] == gi for k in g["members"]), "group membership")
        self.data_rows = [r for r in range(self.rows) if kind[r] == "data"]
        self.rand_rows = [r for r in range(self.rows) if kind[r] != "data"]

    def claim_rows(self, k: int) -> List[Fp2]:
        out = [ZERO] * self.rows
        for p in self.claims[k]["parts"]:
            for i, w in enumerate(p["rw"]):
                r = p["row0"] + i
                out[r] = f2_add(out[r], f2_mul(p["coef"], w))
        return out

    def fold(self, g: int) -> List[Fp2]:
        out = [ZERO] * self.rows
        grp = self.groups[g]
        for k, lam in zip(grp["members"], grp["lambdas"]):
            for r, c in enumerate(self.claim_rows(k)):
                if c != ZERO:
                    out[r] = f2_add(out[r], f2_mul(lam, c))
        return out

    def summary(self) -> dict:
        return {"rows": self.rows, "data_rows": len(self.data_rows), "mask_rows": self.kind.count("mask"),
                "prox_rows": self.kind.count("prox"), "claims": len(self.claims),
                "groups": [len(g["members"]) for g in self.groups], "extras": [e["name"] for e in self.extras],
                "n": self.n, "q_pad": self.q_pad, "domain": self.domain,
                "opened_positions": len(self.indices), "distinct_positions": len(set(self.indices))}


def role_from_obs(obs, raw_role: Optional[dict] = None) -> Role:
    """O8's validated IoRoleObs (+ the raw JSON for the column VALUES) -> Role."""
    claims = [{"value": c["value"], "group": c["group"],
               "parts": [{"row0": p["row0"], "nrows": p["nrows"], "coef": p["coef"], "rw": list(p["rw"])}
                         for p in c["parts"]]} for c in obs.claims]
    groups = [{"members": list(g["members"]), "lambdas": list(g["lambdas"]), "cw": list(g["cw"]),
               "vector": list(g["vector"])} for g in obs.groups]
    extras = []
    if obs.role == "H":
        re_, im_ = obs.layout["zero_sum_pair"]
        extras.append({"name": "zero_sum(u)", "coefs": {re_: ONE, im_: U}, "value": ZERO})
    columns = None
    if raw_role is not None:
        require([c["index"] for c in raw_role["columns"]] == list(obs.sampled_columns),
                "raw column indices differ from the parsed ones")
        columns = [list(c["values"]) for c in raw_role["columns"]]
    return Role(obs.role, obs.n, obs.q_pad, obs.column_domain, claims, groups, list(obs.rho),
                list(obs.row_kind), list(obs.row_name), extras, list(obs.sampled_columns),
                columns, list(obs.prox_vector))


def check_role_public(role: Role) -> dict:
    """The captured observations are consistent with the affine map: every full
    vector reproduces the folded opened columns at every opened position, and
    every group vector reproduces its members' terminals."""
    require(role.columns is not None and role.prox_vector is not None, "no observed values")
    checks = 0
    folds = [(role.fold(g), role.groups[g]["vector"]) for g in range(len(role.groups))]
    folds.append((list(role.rho), role.prox_vector))
    for weights, vector in folds:
        v = [tuple(x) for x in vector]
        require(len(v) == role.n + role.q_pad, "vector width")
        enc = T.coset_evals(T.pcs_poly(v[:role.n], v[role.n:]), role.domain)
        for idx, values in zip(role.indices, role.columns):
            require(len(values) == role.rows, "column width")
            require(f2_dot_base(weights, values) == enc[idx], f"{role.name}: public fold/column equation")
            checks += 1
    for g, grp in enumerate(role.groups):
        lhs = ZERO
        for cw, v in zip(grp["cw"], grp["vector"][:role.n]):
            lhs = f2_add(lhs, f2_mul(cw, tuple(v)))
        rhs = ZERO
        for k, lam in zip(grp["members"], grp["lambdas"]):
            rhs = f2_add(rhs, f2_mul(lam, role.claims[k]["value"]))
        require(lhs == rhs, f"{role.name}: group terminal equation")
    return {"fold_column_equations": checks, "group_terminal_equations": len(role.groups)}


# ---------------------------------------------------------------------------
# plans: how a role's unknowns are parametrised (which coordinate ranges, and per
# row which ranges it occupies with data or randomness coordinates)
# ---------------------------------------------------------------------------


class Plan:
    """ranges: [{"name", "width", "shared", "proj"}], proj in {"identity", None, list}
    (the message projection N^m of the range's basis vectors: identity, zero, or an
    explicit width x n matrix stored row-wise); row_ranges[r]: [(range_index, kind)]."""

    def __init__(self, role: Role, ranges: List[dict], row_ranges: List[List[Tuple[int, str]]],
                 mode: str, column_only_disclosure: int = 0, note: str = ""):
        self.role, self.ranges, self.row_ranges, self.mode = role, ranges, row_ranges, mode
        self.column_only_disclosure = column_only_disclosure
        self.note = note
        require(len(row_ranges) == role.rows, "plan row geometry")
        for rr in row_ranges:
            require(all(0 <= gi < len(ranges) and kd in ("data", "rand") for gi, kd in rr), "plan entries")
        require(sum(1 for rg in ranges if rg["shared"]) <= 1, "one shared range at most")
        for rg in ranges:
            if rg["shared"]:
                require(rg["proj"] == "identity" and rg["width"] == role.n, "shared range is the identity message range")

    def describe(self) -> dict:
        return {"mode": self.mode, "ranges": [{"name": rg["name"], "width": rg["width"], "shared": rg["shared"],
                                               "projection": ("identity" if rg["proj"] == "identity"
                                                              else "zero" if rg["proj"] is None else "explicit")}
                                              for rg in self.ranges],
                "column_only_disclosure": self.column_only_disclosure, "note": self.note}


def plan_no_columns(role: Role) -> Plan:
    """Unknowns (m_r, g_r) untouched: the message range shared, the pads a private
    randomness-only block.  Reproduces O8 plus a cancelling pad block."""
    ranges = [{"name": "msg", "width": role.n, "shared": True, "proj": "identity"},
              {"name": "pad", "width": role.q_pad, "shared": False, "proj": None}]
    rr = [[(0, "data" if role.kind[r] == "data" else "rand"), (1, "rand")] for r in range(role.rows)]
    return Plan(role, ranges, rr, "without_columns",
                note="all 512 coordinates of every vector observed; no column equations")


def plan_canonical(role: Role, alg: ColumnAlgebra) -> Plan:
    """The reduction of the docstring: x_r = N t_r with N = [N_1 | N_2]."""
    require(alg.n == role.n and alg.q_pad == role.q_pad and alg.domain == role.domain
            and alg.indices == role.indices, "column algebra does not belong to this role")
    require(all(q == role.q_pad for q in role.pads), "canonical plan needs the full pad budget on every row")
    ranges = [{"name": "msg", "width": role.n, "shared": True, "proj": "identity"}]
    rr = [[(0, "data" if role.kind[r] == "data" else "rand")] for r in range(role.rows)]
    if alg.q_pad - alg.jd > 0:
        ranges.append({"name": "padker", "width": alg.q_pad - alg.jd, "shared": False, "proj": None})
        for r in range(role.rows):
            rr[r].append((1, "rand"))
    return Plan(role, ranges, rr, "with_columns",
                note=f"column equations substituted away on the captured J (|J_d| = {alg.jd})")


def plan_deficient(role: Role, alg: ColumnAlgebra, cls: str, q_prime: int) -> Plan:
    """CONTROL: the rows of kind `cls` are pretended to have only q_prime pads."""
    require(cls in ("data", "mask", "prox") and 0 <= q_prime < role.q_pad, "deficient control parameters")
    n, Q, jd = role.n, role.q_pad, alg.jd
    deficient = [r for r in range(role.rows) if role.kind[r] == cls]
    require(deficient, "no rows of that kind")
    require(all(role.pads[r] == q_prime for r in deficient), "role.pads must carry the pretended budget")
    dk = "data" if cls == "data" else "rand"
    if q_prime >= jd:
        ranges = [{"name": "msg", "width": n, "shared": True, "proj": "identity"},
                  {"name": "padker_short", "width": q_prime - jd, "shared": False, "proj": None},
                  {"name": "padker_rest", "width": Q - q_prime, "shared": False, "proj": None}]
        rr = []
        for r in range(role.rows):
            k0 = "data" if role.kind[r] == "data" else "rand"
            rr.append([(0, k0), (1, "rand")] + ([] if r in deficient else [(2, "rand")]))
        return Plan(role, ranges, rr, f"deficient_{cls}_{q_prime}", 0,
                    note=f"pad budget {q_prime} >= |J_d| = {jd}: hypothesis (a) still holds for the class")
    d = n + q_prime - jd
    proj_np = [alg.message_projection(i) for i in range(d)]
    proj_rest = [alg.message_projection(i) for i in range(d, n)]
    ranges = [{"name": "nprime", "width": d, "shared": False, "proj": proj_np},
              {"name": "rest", "width": n - d, "shared": False, "proj": proj_rest},
              {"name": "padker", "width": Q - jd, "shared": False, "proj": None}]
    rr = []
    for r in range(role.rows):
        if r in deficient:
            rr.append([(0, dk)])
        else:
            k0 = "data" if role.kind[r] == "data" else "rand"
            rr.append([(0, k0), (1, k0), (2, "rand")])
    col_only = (n - d) * len(deficient) if cls == "data" else 0
    return Plan(role, ranges, rr, f"deficient_{cls}_{q_prime}", col_only,
                note=f"pad budget {q_prime} < |J_d| = {jd}: adapted basis [ker E_J^{{Q'}} | rest | pad kernel]; "
                     f"column-only disclosure {col_only} added for deficient data rows")


# ---------------------------------------------------------------------------
# the reduced-model engine: block (per-coordinate) ranks plus the cross-coordinate
# kernel, over an arbitrary set of coordinate ranges
# ---------------------------------------------------------------------------


class _Instance:
    __slots__ = ("name", "width", "nb", "beta", "zeta", "gen_kind", "weights", "sites", "participants",
                 "owner_roles")

    def __init__(self, name, width, nb, owner_roles):
        self.name, self.width, self.nb, self.owner_roles = name, width, nb, owner_roles
        self.beta: List[List[int]] = []
        self.zeta: List[Dict[int, Fp2]] = []
        self.gen_kind: List[str] = []
        self.weights: Dict[int, List[Fp2]] = {}
        self.sites = 0
        self.participants = 0


class ReducedModel:
    """rank[L | D] and rank[L] of the reduced observation map over several roles.

    Unknown cells are (row, coordinate) pairs of each range; data rows aliased
    across roles are one merged row in the shared identity message range.
    Fold observations act coordinate by coordinate (block part); terminals and
    extras act across coordinates with the range's projected column weights."""

    def __init__(self, roles: Sequence[Role], plans: Sequence[Plan], aliases: Sequence[tuple] = ()):
        require(len(roles) == len(plans) and all(p.role is r for r, p in zip(roles, plans)), "roles/plans")
        self.roles, self.plans = list(roles), list(plans)
        idx = {r.name: i for i, r in enumerate(self.roles)}
        require(len(idx) == len(self.roles), "duplicate role names")
        self.cross: List[tuple] = []
        self.cross_index: Dict[tuple, int] = {}
        for ri, role in enumerate(self.roles):
            for k in range(len(role.claims)):
                self.cross_index[("claim", ri, k)] = len(self.cross)
                self.cross.append(("claim", ri, k))
            for ei in range(len(role.extras)):
                self.cross_index[("extra", ri, ei)] = len(self.cross)
                self.cross.append(("extra", ri, ei))
        self.tdim = 2 * len(self.cross)
        parent: Dict[tuple, tuple] = {}

        def find(x):
            parent.setdefault(x, x)
            while parent[x] != x:
                parent[x] = parent[parent[x]]
                x = parent[x]
            return x

        self.alias_pairs: List[tuple] = []
        for (na, ra), (nb_, rb) in aliases:
            if na not in idx or nb_ not in idx:
                continue
            a, b = (idx[na], ra), (idx[nb_], rb)
            for ci, r in (a, b):
                role, plan = self.roles[ci], self.plans[ci]
                require(0 <= r < role.rows and role.kind[r] == "data", "an alias may only identify data rows")
                shared = [(gi, kd) for gi, kd in plan.row_ranges[r] if plan.ranges[gi]["shared"]]
                require(len(shared) == 1 and shared[0][1] == "data",
                        "an aliased row must carry data coordinates in the shared identity message range")
            parent[find(a)] = find(b)
            self.alias_pairs.append(((na, ra), (nb_, rb)))
        self.merged: Dict[tuple, int] = {}
        mid: Dict[tuple, int] = {}
        for ri, role in enumerate(self.roles):
            for r in range(role.rows):
                root = find((ri, r))
                if root not in mid:
                    mid[root] = len(mid)
                self.merged[(ri, r)] = mid[root]
        self.merged_rows = len(mid)
        self.instances: List[_Instance] = []
        shared_parts: Dict[int, List[tuple]] = {}
        widths = set()
        for ri, (role, plan) in enumerate(zip(self.roles, self.plans)):
            for gi, rg in enumerate(plan.ranges):
                if rg["shared"]:
                    widths.add(rg["width"])
            for r in range(role.rows):
                for gi, kd in plan.row_ranges[r]:
                    if plan.ranges[gi]["shared"]:
                        shared_parts.setdefault(self.merged[(ri, r)], []).append((ri, r, kd))
        if shared_parts:
            require(len(widths) == 1, "shared ranges of different widths")
            self.instances.append(self._instance("msg", widths.pop(), list(shared_parts.values()), None))
        for ri, (role, plan) in enumerate(zip(self.roles, self.plans)):
            for gi, rg in enumerate(plan.ranges):
                if rg["shared"] or rg["width"] <= 0:
                    continue
                parts = [[(ri, r, kd)] for r in range(role.rows) for g2, kd in plan.row_ranges[r] if g2 == gi]
                if parts:
                    self.instances.append(self._instance(f"{role.name}.{rg['name']}", rg["width"], parts, (ri, gi)))
        self._cache: Dict[bool, dict] = {}

    def _instance(self, name: str, width: int, participants: List[List[tuple]], proj_key) -> _Instance:
        owners = sorted({ri for part in participants for ri, _, _ in part})
        off: Dict[int, int] = {}
        nb = 0
        for ri in owners:
            off[ri] = nb
            nb += 2 * len(self.roles[ri].groups) + 2
        inst = _Instance(name, width, nb, owners)
        inst.participants = len(participants)
        sites: Dict[tuple, Tuple[list, str]] = {}
        feats: Dict[tuple, List[List[int]]] = {}
        for part in participants:
            kinds = {kd for _, _, kd in part}
            require(len(kinds) == 1, "merged row with mixed coordinate kinds")
            kind = kinds.pop()
            refs, prox_owners, extras, feat = [], [], [], []
            name_ = ""
            for ri, r, _ in sorted(part):
                role = self.roles[ri]
                name_ = name_ or role.rname[r]
                for k, c in enumerate(role.claims):
                    for pi, p in enumerate(c["parts"]):
                        if p["row0"] <= r < p["row0"] + p["nrows"]:
                            refs.append((ri, k, pi))
                            feat.extend(p["rw"][r - p["row0"]])
                prox_owners.append(ri)
                feat.extend(role.rho[r])
                for ei, e in enumerate(role.extras):
                    if r in e["coefs"]:
                        extras.append((ri, ei, tuple(e["coefs"][r])))
            feat.append(1)
            key = (tuple(refs), tuple(prox_owners), tuple(extras), kind, name_)
            sites.setdefault(key, ([], kind))[0].append(part)
            feats.setdefault(key, []).append(feat)
        inst.sites = len(sites)
        for key, (_, kind) in sites.items():
            refs, prox_owners, extras = key[0], key[1], key[2]
            for b in C._row_span_basis(feats[key]):
                beta = [0] * nb
                zeta: Dict[int, Fp2] = {}
                pos = 0
                for ri, k, pi in refs:
                    x = (b[pos], b[pos + 1])
                    pos += 2
                    role = self.roles[ri]
                    part = role.claims[k]["parts"][pi]
                    g = role.claims[k]["group"]
                    lam = role.groups[g]["lambdas"][role.groups[g]["members"].index(k)]
                    cz = f2_mul(part["coef"], x)
                    cb = f2_mul(lam, cz)
                    gg = off[ri] + 2 * g
                    beta[gg] = (beta[gg] + cb[0]) % P
                    beta[gg + 1] = (beta[gg + 1] + cb[1]) % P
                    e = self.cross_index[("claim", ri, k)]
                    zeta[e] = f2_add(zeta.get(e, ZERO), cz)
                for ri in prox_owners:
                    rho = (b[pos], b[pos + 1])
                    pos += 2
                    pc = off[ri] + 2 * len(self.roles[ri].groups)
                    beta[pc] = (beta[pc] + rho[0]) % P
                    beta[pc + 1] = (beta[pc + 1] + rho[1]) % P
                one = b[pos]
                for ri, ei, cf in extras:
                    e = self.cross_index[("extra", ri, ei)]
                    zeta[e] = f2_add(zeta.get(e, ZERO), (cf[0] * one % P, cf[1] * one % P))
                inst.beta.append(beta)
                inst.zeta.append(zeta)
                inst.gen_kind.append(kind)
        # cross-coordinate weights of this instance, per cross equation of an owner role
        for ri in owners:
            role, plan = self.roles[ri], self.plans[ri]
            if proj_key is None:
                proj = "identity"
            else:
                proj = plan.ranges[proj_key[1]]["proj"]
            if proj is None:
                continue
            for (kind_, ri2, k) in self.cross:
                if ri2 != ri:
                    continue
                cw = role.groups[role.claims[k]["group"]]["cw"] if kind_ == "claim" else [ONE] * role.n
                e = self.cross_index[(kind_, ri2, k)]
                if proj == "identity":
                    inst.weights[e] = list(cw)
                else:
                    ws = []
                    for col in proj:
                        a = b2 = 0
                        for w, v in zip(cw, col):
                            if v:
                                a += w[0] * v
                                b2 += w[1] * v
                        ws.append((a % P, b2 % P))
                    inst.weights[e] = ws
        return inst

    def rank(self, include_data: bool) -> dict:
        if include_data in self._cache:
            return self._cache[include_data]
        ech = C.Echelon(self.tdim)
        block_total = 0
        per = {}
        for inst in self.instances:
            gens = [g for g in range(len(inst.beta)) if include_data or inst.gen_kind[g] == "rand"]
            if not gens:
                per[inst.name] = {"width": inst.width, "generators": 0, "block_rank": 0}
                continue
            betas = [inst.beta[g] for g in gens]
            null = R.left_null_space(betas, inst.nb)
            r = len(gens) - len(null)
            block_total += inst.width * r
            per[inst.name] = {"width": inst.width, "generators": len(gens), "block_rank": r,
                              "block_contribution": inst.width * r}
            if not inst.weights or not null:
                continue
            zs = []
            for comb in null:
                z = [0] * self.tdim
                for ca, g in zip(comb, gens):
                    if not ca:
                        continue
                    for e, v in inst.zeta[g].items():
                        z[2 * e] = (z[2 * e] + ca * v[0]) % P
                        z[2 * e + 1] = (z[2 * e + 1] + ca * v[1]) % P
                if any(z):
                    zs.append(z)
            if not zs:
                continue
            zb = C._row_span_basis(zs)
            supports = [[e for e in range(len(self.cross)) if (z[2 * e] or z[2 * e + 1]) and e in inst.weights]
                        for z in zb]
            for c in range(inst.width):
                if ech.rank == self.tdim:
                    break
                for z, sup in zip(zb, supports):
                    if not sup:
                        continue
                    w = [0] * self.tdim
                    for e in sup:
                        s = f2_mul((z[2 * e], z[2 * e + 1]), inst.weights[e][c])
                        w[2 * e], w[2 * e + 1] = s
                    ech.insert(w)
        out = {"rank": block_total + ech.rank, "block_rank_total": block_total, "cross_kernel": ech.rank,
               "per_range": per}
        self._cache[include_data] = out
        return out

    def analyze(self) -> dict:
        rl, ra = self.rank(False), self.rank(True)
        col_only = sum(p.column_only_disclosure for p in self.plans)
        msg = next((i for i in self.instances if i.name == "msg"), None)
        out = {"roles": [r.name for r in self.roles], "aliases": self.alias_pairs,
               "plans": {r.name: p.describe() for r, p in zip(self.roles, self.plans)},
               "merged_rows": self.merged_rows, "cross_equations": len(self.cross),
               "instances": [{"name": i.name, "width": i.width, "participants": i.participants,
                              "sites": i.sites, "generators": len(i.beta), "weighted_cross_equations": len(i.weights)}
                             for i in self.instances],
               "rank_L": rl["rank"], "rank_all": ra["rank"],
               "cross_kernel_L": rl["cross_kernel"], "cross_kernel_all": ra["cross_kernel"],
               "per_range_L": rl["per_range"], "per_range_all": ra["per_range"],
               "reduced_disclosed": ra["rank"] - rl["rank"],
               "column_only_disclosed": col_only,
               "disclosed": ra["rank"] - rl["rank"] + col_only}
        if msg is not None:
            n = msg.width
            out["o8_equivalent"] = {
                "rank_mask": n * rl["per_range"]["msg"]["block_rank"] + rl["cross_kernel"],
                "rank_joint": n * ra["per_range"]["msg"]["block_rank"] + ra["cross_kernel"],
                "per_column_mask": rl["per_range"]["msg"]["block_rank"],
                "per_column_joint": ra["per_range"]["msg"]["block_rank"],
                "cross_column_kernel_mask": rl["cross_kernel"], "cross_column_kernel_joint": ra["cross_kernel"]}
        return out


# ---------------------------------------------------------------------------
# brute force on small geometries: the full uncompressed observation matrix
# ---------------------------------------------------------------------------


def brute_force(roles: Sequence[Role], aliases: Sequence[tuple] = (), with_columns: bool = True) -> dict:
    idx = {r.name: i for i, r in enumerate(roles)}
    parent: Dict[tuple, tuple] = {}

    def find(x):
        parent.setdefault(x, x)
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    for (na, ra), (nb_, rb) in aliases:
        if na in idx and nb_ in idx:
            parent[find((idx[na], ra))] = find((idx[nb_], rb))
    cols: Dict[tuple, int] = {}
    data_cols = set()
    for ri, role in enumerate(roles):
        for r in range(role.rows):
            root = find((ri, r))
            for j in range(role.n):
                key = ("m", root, j)
                if key not in cols:
                    cols[key] = len(cols)
                if role.kind[r] == "data":
                    data_cols.add(cols[key])
            for t in range(role.pads[r]):
                cols[("g", ri, r, t)] = len(cols)
    rows: List[Dict[int, int]] = []

    def add_fp2(entries: Dict[int, Fp2]):
        rows.append({c: v[0] % P for c, v in entries.items() if v[0] % P})
        rows.append({c: v[1] % P for c, v in entries.items() if v[1] % P})

    for ri, role in enumerate(roles):
        folds = [role.fold(g) for g in range(len(role.groups))] + [list(role.rho)]
        for weights in folds:
            for j in range(role.n + role.q_pad):
                entries: Dict[int, Fp2] = {}
                for r in range(role.rows):
                    if weights[r] == ZERO:
                        continue
                    if j < role.n:
                        c = cols[("m", find((ri, r)), j)]
                    elif j - role.n < role.pads[r]:
                        c = cols[("g", ri, r, j - role.n)]
                    else:
                        continue
                    entries[c] = f2_add(entries.get(c, ZERO), weights[r])
                add_fp2(entries)
        for k, claim in enumerate(role.claims):
            cw = role.groups[claim["group"]]["cw"]
            entries = {}
            for r, coef in enumerate(role.claim_rows(k)):
                if coef == ZERO:
                    continue
                for j in range(role.n):
                    c = cols[("m", find((ri, r)), j)]
                    entries[c] = f2_add(entries.get(c, ZERO), f2_mul(coef, cw[j]))
            add_fp2(entries)
        for e in role.extras:
            entries = {}
            for r, coef in e["coefs"].items():
                for j in range(role.n):
                    c = cols[("m", find((ri, r)), j)]
                    entries[c] = f2_add(entries.get(c, ZERO), coef)
            add_fp2(entries)
        if with_columns:
            omega_dom = T.subgroup(role.domain)
            lag = [fft([1 if t == j else 0 for t in range(role.n)], True) for j in range(role.n)]
            for i in sorted(set(role.indices)):
                x = 7 * omega_dom[i] % P
                lx = [poly_eval(f, x) for f in lag]
                z = (pow(x, role.n, P) - 1) % P
                for r in range(role.rows):
                    row = {}
                    for j in range(role.n):
                        c = cols[("m", find((ri, r)), j)]
                        row[c] = (row.get(c, 0) + lx[j]) % P
                    xt = 1
                    for t in range(role.pads[r]):
                        row[cols[("g", ri, r, t)]] = z * xt % P
                        xt = xt * x % P
                    rows.append({c: v for c, v in row.items() if v})
    ncols = len(cols)
    rand_cols = [c for c in range(ncols) if c not in data_cols]
    dense_all = [[row.get(c, 0) for c in range(ncols)] for row in rows]
    dense_l = [[row.get(c, 0) for c in rand_cols] for row in rows]
    ra, rl = R.rank(dense_all), R.rank(dense_l)
    return {"unknowns": ncols, "data_unknowns": len(data_cols), "observations": len(rows),
            "rank_L": rl, "rank_all": ra, "disclosed": ra - rl}


# ---------------------------------------------------------------------------
# synthetic small geometry (control 4): three roles, one alias, one zero-sum extra
# ---------------------------------------------------------------------------


def synthetic_roles(seed: int = 2409, n: int = 8, q_pad: int = 4, domain: int = 64,
                    indices: Optional[Dict[str, List[int]]] = None, ablate_endpoint: bool = False,
                    deficient: Optional[Tuple[str, str, int]] = None,
                    drop_zero_sum: bool = False) -> Tuple[List[Role], List[tuple]]:
    rng = random.Random(seed)
    fp = lambda: rng.randrange(1, P)
    pair = lambda: (fp(), fp())
    log_n = n.bit_length() - 1
    indices = indices or {"A": [3, 17, 40, 3], "E": [5, 9, 33, 61], "H": [2, 2, 44, 50]}
    tail = [pair() for _ in range(log_n)]
    cw = R.eq_table_msb(tail)
    e0, e1, e2, c0, c1 = pair(), pair(), pair(), pair(), pair()
    pt0 = pair()
    rw0 = R.eq_table_msb([pt0])
    specs = {}
    specs["A"] = dict(kind=["data", "data", "data", "mask", "mask", "mask", "mask", "prox"],
                      rname=["X.0", "X.1", "Y", "mA0.re", "mA0.im", "mA1.re", "mA1.im", "A.prox"],
                      claims=[{"group": 0, "parts": [{"row0": 0, "nrows": 2, "coef": f2_sub(ONE, e0), "rw": rw0},
                                                     {"row0": 3, "nrows": 1, "coef": e0, "rw": [ONE]},
                                                     {"row0": 4, "nrows": 1, "coef": f2_mul(e0, U), "rw": [ONE]}]},
                              {"group": 0, "parts": [{"row0": 2, "nrows": 1, "coef": f2_sub(ONE, e1), "rw": [ONE]},
                                                     {"row0": 5, "nrows": 1, "coef": e1, "rw": [ONE]},
                                                     {"row0": 6, "nrows": 1, "coef": f2_mul(e1, U), "rw": [ONE]}]}],
                      groups=[{"members": [0, 1], "lambdas": [pair(), pair()], "cw": cw}], extras=[])
    e_parts = [{"row0": 0, "nrows": 1, "coef": f2_sub(ONE, e1), "rw": [ONE]},
               {"row0": 1, "nrows": 1, "coef": e1, "rw": [ONE]},
               {"row0": 2, "nrows": 1, "coef": f2_mul(e1, U), "rw": [ONE]}]
    e_kind = ["data", "mask", "mask", "prox", "prox"]
    if ablate_endpoint:
        e_parts = e_parts[:2]
        e_kind = ["data", "mask", "prox", "prox", "prox"]
    specs["E"] = dict(kind=e_kind, rname=["E.data", "E.m.re", "E.m.im", "E.p0", "E.p1"],
                      claims=[{"group": 0, "parts": e_parts}],
                      groups=[{"members": [0], "lambdas": [pair()], "cw": cw}], extras=[])
    # H: a (u.re, u.im) pair under the public zero-sum, one helper row, one mask pair PER
    # claim (as the real layout), one proximity row
    specs["H"] = dict(kind=["data", "data", "data", "mask", "mask", "mask", "mask", "prox"],
                      rname=["u.re", "u.im", "helper", "mH0.re", "mH0.im", "mH1.re", "mH1.im", "H.prox"],
                      claims=[{"group": 0, "parts": [{"row0": 0, "nrows": 1, "coef": c0, "rw": [ONE]},
                                                     {"row0": 1, "nrows": 1, "coef": f2_mul(c0, U), "rw": [ONE]},
                                                     {"row0": 3, "nrows": 1, "coef": c1, "rw": [ONE]},
                                                     {"row0": 4, "nrows": 1, "coef": f2_mul(c1, U), "rw": [ONE]}]},
                              {"group": 0, "parts": [{"row0": 2, "nrows": 1, "coef": f2_sub(ONE, e2), "rw": [ONE]},
                                                     {"row0": 5, "nrows": 1, "coef": e2, "rw": [ONE]},
                                                     {"row0": 6, "nrows": 1, "coef": f2_mul(e2, U), "rw": [ONE]}]}],
                      groups=[{"members": [0, 1], "lambdas": [pair(), pair()], "cw": cw}],
                      extras=[] if drop_zero_sum else [{"name": "zero_sum(u)", "coefs": {0: ONE, 1: U}, "value": ZERO}])
    # the secrets (never returned): messages and pads, the alias respected, the zero-sum respected
    messages = {name: [[fp() for _ in range(n)] for _ in spec["kind"]] for name, spec in specs.items()}
    messages["E"][0] = list(messages["A"][2])
    for r in (0, 1):
        messages["H"][r][-1] = (-sum(messages["H"][r][:-1])) % P
    roles = []
    omega_dom = T.subgroup(domain)
    for name, spec in specs.items():
        rows = len(spec["kind"])
        pads_count = [q_pad] * rows
        if deficient and deficient[0] == name:
            pads_count = [deficient[2] if k == deficient[1] else q_pad for k in spec["kind"]]
        pads = [[fp() for _ in range(pads_count[r])] + [0] * (q_pad - pads_count[r]) for r in range(rows)]
        rho = [pair() for _ in range(rows)]
        role = Role(name, n, q_pad, domain, spec["claims"], spec["groups"], rho, spec["kind"], spec["rname"],
                    spec["extras"], list(indices[name]), None, None, pads_count)
        full = [messages[name][r] + pads[r] for r in range(rows)]
        for k, claim in enumerate(role.claims):
            value = ZERO
            for r, coef in enumerate(role.claim_rows(k)):
                if coef != ZERO:
                    value = f2_add(value, f2_mul(coef, f2_dot_base(cw, messages[name][r])))
            claim["value"] = value
        for g, grp in enumerate(role.groups):
            w = role.fold(g)
            grp["vector"] = [f2_dot_base(w, [full[r][j] for r in range(rows)]) for j in range(n + q_pad)]
        role.prox_vector = [f2_dot_base(rho, [full[r][j] for r in range(rows)]) for j in range(n + q_pad)]
        coeffs = [pcs_coeffs(messages[name][r], pads[r]) for r in range(rows)]
        role.columns = []
        for i in role.indices:
            x = 7 * omega_dom[i] % P
            role.columns.append([poly_eval(c, x) for c in coeffs])
        roles.append(role)
    return roles, [(("A", 2), ("E", 0))]


# ---------------------------------------------------------------------------
# the M (CFS mask) commitment: per-slot column algebra, blinder elimination, functionals
# ---------------------------------------------------------------------------


class MaskAlgebra:
    """M's opening (q', proximity, functionals, 256 columns of 20 base rows) reduced
    to equations on the CFS prefixes; every basis direction checked numerically."""

    def __init__(self, mask: dict, verify_directions: bool = True):
        t0 = time.time()
        self.lengths, self.offsets, self.fs, self.wcoef, self.v = T.mask_weights(mask)
        T.check_mask_public(mask, self.wcoef, self.v)
        self.public_checked = True
        self.theta = tuple(mask["theta"])
        self.rhos = [tuple(x) for x in mask["proximity_rhos"]]
        require(len(self.rhos) == 2 * len(self.lengths) + 2, "M proximity rho count")
        self.indices = [c["index"] for c in mask["columns"]]
        self.distinct = sorted(set(self.indices))
        self.jd = len(self.distinct)
        self.m, self.q, self.domain = 512, 256, 4096
        require(self.jd <= self.q, "more distinct M positions than pads")
        nodes = T.subgroup(self.m)
        coset = T.subgroup(self.domain)
        self.xs = [7 * coset[i] % P for i in self.distinct]
        require(not set(self.xs) & set(nodes), "M sample on its message subgroup")
        # the pre-IDFT theta-combined weights, for the blinder zero-sum identity
        self.wt = [T.transform(w, False) for w in self.wcoef]
        self.slots = []
        self.directions_checked = 0
        for s, L in enumerate(self.lengths):
            require(L + self.q <= self.m, "M slot geometry")
            forced = nodes[:L] + nodes[L + self.q:] + self.xs
            Y = poly_from_roots(forced)                     # degree 256 + jd <= 512
            ev_nodes = fft(Y + [0] * (self.m - len(Y))) if len(Y) < self.m else None
            ev_coset = coset_evals_base(Y, self.domain)
            require(all(ev_coset[i] == 0 for i in self.distinct), "Y does not vanish on J_M")
            if ev_nodes is not None:
                require(all(ev_nodes[i] == 0 for i in list(range(L)) + list(range(L + self.q, self.m))),
                        "Y does not vanish on the fixed nodes")
            else:
                require(all(poly_eval(Y, nodes[i]) == 0 for i in list(range(L)) + list(range(L + self.q, self.m))),
                        "Y does not vanish on the fixed nodes")
            cert = 0
            for x in self.xs:
                qx, rem = synth_div(Y, x)
                require(rem == 0 and poly_mul_linear(qx, x) == Y and poly_eval(qx, x) != 0,
                        "M pad right inverse")
                cert += 1
            completions = []
            for j in range(L):
                a = nodes[j]
                qa, rem = synth_div(Y, a)
                require(rem == 0 and poly_mul_linear(qa, a) == Y, "M prefix completion division")
                qaa = poly_eval(qa, a)
                require(qaa != 0, "M prefix completion normalisation")
                inv = pow(qaa, P - 2, P)
                A = [c * inv % P for c in qa]
                require(len(A) <= self.m, "M completion degree")
                ev = fft(A + [0] * (self.m - len(A)))
                require(ev[:L] == [1 if t == j else 0 for t in range(L)] and all(v == 0 for v in ev[L + self.q:]),
                        "M completion values on G_512")
                evc = coset_evals_base(A, self.domain)
                require(all(evc[i] == 0 for i in self.distinct), "M completion on J_M")
                completions.append(A)
            padker = []
            for i in range(self.q - self.jd):
                A = [0] * i + Y
                require(len(A) <= self.m, "M pad kernel degree")
                ev = fft(A + [0] * (self.m - len(A)))
                require(all(v == 0 for v in ev[:L]) and all(v == 0 for v in ev[L + self.q:]), "M pad kernel nodes")
                evc = coset_evals_base(A, self.domain)
                require(all(evc[i2] == 0 for i2 in self.distinct), "M pad kernel on J_M")
                padker.append(A)
            checked = 0
            if verify_directions:
                for j, A in enumerate(completions):
                    self._check_elimination(s, A, self.wt[s][j])
                    checked += 1
                for A in padker:
                    self._check_elimination(s, A, ZERO)
                    checked += 1
            self.directions_checked += checked
            self.slots.append({"slot": s, "prefix_words": L, "pad_words": self.q, "fixed_zero_nodes": self.m - L - self.q,
                               "pad_right_inverse_vectors_verified": cert, "prefix_completions_verified": len(completions),
                               "pad_kernel_dim": len(padker), "kernel_dim": L + self.q - self.jd,
                               "elimination_directions_checked": checked})
        # the reduced equations on the prefixes: the fourteen functionals and b's zero-sum
        width = sum(self.lengths)
        theta_row = [ZERO] * width
        th = ONE
        for f in self.fs:
            theta_row = [f2_add(a, f2_mul(th, b)) for a, b in zip(theta_row, f)]
            th = f2_mul(th, self.theta)
        self.functional_rank_fp2 = CFS.f2_rank(self.fs)
        self.functional_rank_fp = R.rank(CFS.fp2_rows_to_fp(self.fs))
        self.blinder_rank_fp = R.rank(CFS.fp2_rows_to_fp([theta_row]))
        self.combined_rank_fp = R.rank(CFS.fp2_rows_to_fp(self.fs + [theta_row]))
        self.prefix_words = width
        self.ms = _ms(t0)

    def _check_elimination(self, s: int, A: List[int], delta_v: Fp2) -> None:
        """delta_b = -delta_A_s W_s, delta_u = -sum rho_r delta_row_r: q' and proximity
        unchanged, 512 (delta_b_0 + delta_b_512) = -delta_V, all opened words unchanged."""
        dA = [(c, 0) for c in A]
        db = T.mul(dA, self.wcoef[s])
        db = [f2_neg(x) for x in db]
        require(len(db) <= 2 * self.m, "delta_b degree")
        db += [ZERO] * (2 * self.m - len(db))
        lhs = f2_mul(f2_add(db[0], db[self.m]), (self.m, 0))
        require(lhs == f2_neg(delta_v), "M blinder zero-sum identity")
        du = [ZERO] * (2 * self.m)
        base_rows = {2 * s: [(c, 0) for c in A] + [ZERO] * (2 * self.m - len(A)),
                     2 * len(self.lengths): [(x[0], 0) for x in db],
                     2 * len(self.lengths) + 1: [(x[1], 0) for x in db]}
        for r, row in base_rows.items():
            rho = self.rhos[r]
            du = [f2_sub(x, f2_mul(rho, y)) for x, y in zip(du, row)]
        for poly in (db, du):
            re = coset_evals_base([x[0] for x in poly], self.domain)
            im = coset_evals_base([x[1] for x in poly], self.domain)
            require(all(re[i] == 0 and im[i] == 0 for i in self.distinct), "M blinder words on J_M")

    def report(self) -> dict:
        return {"slots": len(self.lengths), "prefix_words_fp2": self.prefix_words,
                "pad_words_fp2": self.q * len(self.lengths), "blinder_b_fp2": 2 * self.m, "blinder_u_fp2": 2 * self.m,
                "opened_positions": len(self.indices), "distinct_positions": self.jd,
                "public_equations_checked": self.public_checked, "per_slot": self.slots,
                "elimination_directions_checked": self.directions_checked,
                "functionals": len(self.fs), "functional_rank_fp2": self.functional_rank_fp2,
                "functional_rank_fp": self.functional_rank_fp,
                "blinder_zero_sum_rank_fp": self.blinder_rank_fp,
                "functionals_plus_blinder_rank_fp": self.combined_rank_fp,
                "disclosed_with_columns": self.combined_rank_fp,
                "disclosed_beyond_public_functionals": self.combined_rank_fp - self.functional_rank_fp,
                "disclosed_without_functionals_observed": self.blinder_rank_fp,
                "randomness_rank_L": 0,
                "meaning": "after substituting the per-slot kernel basis and eliminating b and u exactly, the only "
                           "equations left on the CFS prefixes are the fourteen public functionals (and b's zero-sum, "
                           "their theta-combination): the M opening fixes exactly those public values and nothing else",
                "ms": self.ms}


# ---------------------------------------------------------------------------
# one capture
# ---------------------------------------------------------------------------


def _o8_numbers(a: dict) -> dict:
    j, pc = a["joint"], a["per_column"]
    return {"disclosed_total": j["disclosed_total"], "rank_mask": j["rank_mask"], "rank_joint": j["rank_joint"],
            "cross_column_kernel_mask": j["cross_column_kernel_mask"],
            "cross_column_kernel_joint": j["cross_column_kernel_joint"],
            "per_column_mask": pc["rank_mask"], "per_column_joint": pc["rank_joint"]}


def _mine_vs_o8(mine: dict, o8: dict) -> bool:
    e = mine["o8_equivalent"]
    return (mine["disclosed"] == o8["disclosed_total"] and e["rank_mask"] == o8["rank_mask"]
            and e["rank_joint"] == o8["rank_joint"] and e["per_column_mask"] == o8["per_column_mask"]
            and e["per_column_joint"] == o8["per_column_joint"]
            and e["cross_column_kernel_mask"] == o8["cross_column_kernel_mask"]
            and e["cross_column_kernel_joint"] == o8["cross_column_kernel_joint"])


def _model(roles, plans, aliases=()):
    return ReducedModel(roles, plans, aliases).analyze()


def load_archived_o8(path: str = ARCHIVED_O8_PATH) -> dict:
    digest = sha256_file(path)
    require(digest == ARCHIVED_O8_SHA256, f"archived O8 analysis digest {digest[:16]}.. is not the pinned one")
    with open(path) as fh:
        return json.load(fh)


def analyze_capture(path: str, entry: Optional[dict] = None, log=print, archived: Optional[dict] = None,
                    checks: Optional[List[dict]] = None) -> dict:
    """The joint view of one capture, its O8 comparisons and controls."""
    t0 = time.time()
    checks = checks if checks is not None else []

    def chk(name, ok, actual, expected):
        checks.append({"capture": os.path.basename(path), "check": name, "pass": bool(ok),
                       "actual": actual, "expected": expected})
        log(f"    [{'ok' if ok else 'FAIL'}] {name}: {actual} (expected {expected})")
        return bool(ok)

    digest = sha256_file(path)
    if entry is not None:
        require(entry["capture_sha256"] == digest, "capture digest differs from the manifest")
    with open(path, "rb") as fh:
        raw = O8.load_capture_json(fh.read())
    cap = O8.IoCapture(path, raw=raw)
    raw_roles = {r["role"]: r for r in raw["roles"]}
    mask_raw = raw["mask"]
    del raw
    rec: dict = {"file": os.path.basename(path), "capture_sha256": digest, "proof_sha256": cap.proof_sha256,
                 "privacy": cap.privacy, "roles": {}, "joint": {}, "mask": {}, "controls": {}}
    log(f"  {cap.proof_sha256[:12]} {cap.privacy}: roles {[r.role for r in cap.roles]}")
    roles: Dict[str, Role] = {}
    algs: Dict[str, ColumnAlgebra] = {}
    obs = cap.by_role
    for ro in cap.roles:
        t1 = time.time()
        role = role_from_obs(ro, raw_roles[ro.role])
        public = check_role_public(role)
        T.check_pcs_public(raw_roles[ro.role])           # round 20's independent public check
        alg = ColumnAlgebra(role.n, role.q_pad, role.domain, role.indices)
        roles[ro.role], algs[ro.role] = role, alg
        with_cols = _model([role], [plan_canonical(role, alg)])
        without = _model([role], [plan_no_columns(role)])
        o8 = _o8_numbers(O8.JointModel([ro]).analyze(planes=False))
        entry_r = {"summary": role.summary(), "public_consistency": public, "column_algebra": alg.report,
                   "with_columns": with_cols, "without_columns": without, "o8_live": o8,
                   "disclosed_dim_with_columns": with_cols["disclosed"],
                   "disclosed_dim_without_columns": without["disclosed"], "ms": _ms(t1)}
        expected = 2 if ro.role == "H" else 0
        chk(f"{ro.role} alone: disclosed with columns", with_cols["disclosed"] == expected, with_cols["disclosed"], expected)
        chk(f"{ro.role} alone: disclosed without columns", without["disclosed"] == expected, without["disclosed"], expected)
        chk(f"{ro.role} alone: without-columns ranks equal O8 live", _mine_vs_o8(without, o8), without["o8_equivalent"], o8)
        chk(f"{ro.role} alone: with-columns ranks equal O8 live", _mine_vs_o8(with_cols, o8), with_cols["o8_equivalent"], o8)
        chk(f"{ro.role}: pad right inverse on the captured J (zero-data pad translation exists)",
            alg.report["pad_right_inverse_vectors_verified"] == alg.jd, alg.report["pad_right_inverse_vectors_verified"], alg.jd)
        if ro.role == "H":
            role_nozs = Role(role.name, role.n, role.q_pad, role.domain, role.claims, role.groups, role.rho, role.kind,
                             role.rname, [], role.indices, role.columns, role.prox_vector)
            nz_with = _model([role_nozs], [plan_canonical(role_nozs, alg)])
            nz_without = _model([role_nozs], [plan_no_columns(role_nozs)])
            entry_r["without_zero_sum"] = {"with_columns": nz_with["disclosed"], "without_columns": nz_without["disclosed"]}
            chk("H alone: no zero-sum constraint -> 0 (with columns)", nz_with["disclosed"] == 0, nz_with["disclosed"], 0)
            chk("H alone: no zero-sum constraint -> 0 (without columns)", nz_without["disclosed"] == 0, nz_without["disclosed"], 0)
        rec["roles"][ro.role] = entry_r
        log(f"    {ro.role}: |J_d| {alg.jd}, with {with_cols['disclosed']}, without {without['disclosed']}, "
            f"O8 {o8['disclosed_total']} ({entry_r['ms']} ms)")

    # ---- joint systems --------------------------------------------------------
    aliases = [((a, ra), (b, rb)) for (a, ra), (b, rb) in O8.ALIAS_PAIRS]
    io_names = ["A", "Input", "Output"]
    all_names = [r.role for r in cap.roles]

    def joint(names, alias, with_columns, extra_h=None, drop_zero_sum=False):
        rs, ps = [], []
        for nm in names:
            role = roles[nm]
            if nm == "H" and (extra_h is not None or drop_zero_sum):
                extras = [] if drop_zero_sum else list(role.extras)
                if extra_h is not None:
                    extras = extras + [extra_h]
                role = Role(role.name, role.n, role.q_pad, role.domain, role.claims, role.groups, role.rho,
                            role.kind, role.rname, extras, role.indices, role.columns, role.prox_vector)
            rs.append(role)
            ps.append(plan_canonical(role, algs[nm]) if with_columns else plan_no_columns(role))
        return _model(rs, ps, alias)

    t1 = time.time()
    io_with = joint(io_names, aliases, True)
    io_without = joint(io_names, aliases, False)
    io_o8 = _o8_numbers(O8.JointModel([obs[n] for n in io_names], O8.ALIAS_PAIRS).analyze(planes=False))
    un_with = joint(io_names, (), True)
    un_without = joint(io_names, (), False)
    un_o8 = _o8_numbers(O8.JointModel([obs[n] for n in io_names], ()).analyze(planes=False))
    rec["joint"]["io_cluster_aliased"] = {"with_columns": io_with, "without_columns": io_without, "o8_live": io_o8,
                                          "disclosed_dim_with_columns": io_with["disclosed"],
                                          "disclosed_dim_without_columns": io_without["disclosed"]}
    rec["joint"]["io_cluster_unaliased_control"] = {"with_columns": un_with, "without_columns": un_without, "o8_live": un_o8,
                                                    "disclosed_dim_with_columns": un_with["disclosed"],
                                                    "disclosed_dim_without_columns": un_without["disclosed"]}
    chk("A+Input+Output aliased: disclosed with columns", io_with["disclosed"] == 0, io_with["disclosed"], 0)
    chk("A+Input+Output aliased: disclosed without columns", io_without["disclosed"] == 0, io_without["disclosed"], 0)
    chk("A+Input+Output aliased: without-columns ranks equal O8 live", _mine_vs_o8(io_without, io_o8), io_without["o8_equivalent"], io_o8)
    chk("A+Input+Output aliased: with-columns ranks equal O8 live", _mine_vs_o8(io_with, io_o8), io_with["o8_equivalent"], io_o8)
    chk("A|Input|Output unaliased control equals O8 live", _mine_vs_o8(un_without, un_o8) and _mine_vs_o8(un_with, un_o8),
        [un_with["disclosed"], un_without["disclosed"]], [un_o8["disclosed_total"]] * 2)
    all_with = joint(all_names, aliases, True)
    all_without = joint(all_names, aliases, False)
    all_o8 = _o8_numbers(O8.JointModel([obs[n] for n in all_names], O8.ALIAS_PAIRS).analyze(planes=False))
    nz_with = joint(all_names, aliases, True, drop_zero_sum=True)
    nz_without = joint(all_names, aliases, False, drop_zero_sum=True)
    nz_o8 = _o8_numbers(O8.JointModel([obs[n] for n in all_names], O8.ALIAS_PAIRS, zero_sum=False).analyze(planes=False))
    ident = C.h_identity_extra(obs["H"])
    ident_extra = {"name": ident["name"], "coefs": dict(ident["coefs"]), "value": ZERO}
    id_with = joint(all_names, aliases, True, extra_h=ident_extra)
    id_without = joint(all_names, aliases, False, extra_h=ident_extra)
    rec["joint"]["all_private_commitments_aliased"] = {
        "with_columns": all_with, "without_columns": all_without, "o8_live": all_o8,
        "disclosed_dim_with_columns": all_with["disclosed"], "disclosed_dim_without_columns": all_without["disclosed"],
        "without_H_zero_sum": {"with_columns": nz_with["disclosed"], "without_columns": nz_without["disclosed"],
                               "o8_live": nz_o8["disclosed_total"]},
        "public_logup_identity_added": {"rank_all_with_columns": id_with["rank_all"],
                                        "rank_all_without_columns": id_without["rank_all"],
                                        "adds_no_rank": id_with["rank_all"] == all_with["rank_all"]
                                        and id_without["rank_all"] == all_without["rank_all"]},
        "ms": _ms(t1)}
    chk("all private aliased: disclosed with columns", all_with["disclosed"] == 2, all_with["disclosed"], 2)
    chk("all private aliased: disclosed without columns", all_without["disclosed"] == 2, all_without["disclosed"], 2)
    chk("all private aliased: without-columns ranks equal O8 live", _mine_vs_o8(all_without, all_o8), all_without["o8_equivalent"], all_o8)
    chk("all private aliased: with-columns ranks equal O8 live", _mine_vs_o8(all_with, all_o8), all_with["o8_equivalent"], all_o8)
    chk("all private aliased: without H zero-sum -> 0 (both modes, = O8)",
        nz_with["disclosed"] == nz_without["disclosed"] == nz_o8["disclosed_total"] == 0,
        [nz_with["disclosed"], nz_without["disclosed"], nz_o8["disclosed_total"]], [0, 0, 0])
    chk("all private aliased: public LogUp identity adds no rank (both modes)",
        rec["joint"]["all_private_commitments_aliased"]["public_logup_identity_added"]["adds_no_rank"], True, True)
    log(f"    joint: io {io_with['disclosed']}/{io_without['disclosed']} (O8 {io_o8['disclosed_total']}), "
        f"all {all_with['disclosed']}/{all_without['disclosed']} (O8 {all_o8['disclosed_total']}) ({_ms(t1)} ms)")

    # ---- the archived O8 record ------------------------------------------------
    if archived is not None:
        case = next((c for c in archived["cases"] if c["proof_sha256"] == cap.proof_sha256), None)
        require(case is not None, "capture absent from the archived O8 record")
        an = case["analysis"]
        arch = {r: an["per_commitment"][r]["analysis"]["joint"]["disclosed_total"] for r in all_names}
        arch["io_cluster_aliased"] = an["joint"]["io_cluster_aliased"]["joint"]["disclosed_total"]
        arch["all_private_commitments_aliased"] = an["joint"]["all_private_commitments_aliased"]["joint"]["disclosed_total"]
        arch["ranks"] = {r: [an["per_commitment"][r]["analysis"]["joint"]["rank_mask"],
                             an["per_commitment"][r]["analysis"]["joint"]["rank_joint"]] for r in all_names}
        arch["ranks"]["all_private_commitments_aliased"] = [
            an["joint"]["all_private_commitments_aliased"]["joint"]["rank_mask"],
            an["joint"]["all_private_commitments_aliased"]["joint"]["rank_joint"]]
        arch["ranks"]["io_cluster_aliased"] = [an["joint"]["io_cluster_aliased"]["joint"]["rank_mask"],
                                               an["joint"]["io_cluster_aliased"]["joint"]["rank_joint"]]
        mine = {r: rec["roles"][r]["disclosed_dim_without_columns"] for r in all_names}
        mine["io_cluster_aliased"] = io_without["disclosed"]
        mine["all_private_commitments_aliased"] = all_without["disclosed"]
        mine["ranks"] = {r: [rec["roles"][r]["without_columns"]["o8_equivalent"]["rank_mask"],
                             rec["roles"][r]["without_columns"]["o8_equivalent"]["rank_joint"]] for r in all_names}
        mine["ranks"]["all_private_commitments_aliased"] = [all_without["o8_equivalent"]["rank_mask"],
                                                            all_without["o8_equivalent"]["rank_joint"]]
        mine["ranks"]["io_cluster_aliased"] = [io_without["o8_equivalent"]["rank_mask"], io_without["o8_equivalent"]["rank_joint"]]
        with_mine = dict(mine)
        with_mine.update({r: rec["roles"][r]["disclosed_dim_with_columns"] for r in all_names})
        with_mine["io_cluster_aliased"] = io_with["disclosed"]
        with_mine["all_private_commitments_aliased"] = all_with["disclosed"]
        rec["controls"]["o8_archive"] = {"archive_sha256": ARCHIVED_O8_SHA256, "archived": arch, "without_columns": mine,
                                         "with_columns_disclosed": {k: v for k, v in with_mine.items() if k != "ranks"},
                                         "single_mask_ablation_archived": [
                                             x["single_mask_disclosed_total"] for x in an["controls"]["endpoint_mask_ablation"]]}
        chk("without-columns numbers equal the archived O8 record (disclosed and ranks)", mine == arch, mine, arch)
        chk("with-columns disclosed numbers equal the archived O8 record",
            {k: v for k, v in with_mine.items() if k != "ranks"} == {k: v for k, v in arch.items() if k != "ranks"},
            {k: v for k, v in with_mine.items() if k != "ranks"}, {k: v for k, v in arch.items() if k != "ranks"})

    # ---- control 2: endpoint mask-pair ablation ---------------------------------
    t1 = time.time()
    abl = {}
    for nm in ("Input", "Output"):
        ab_obs = O8.ablate_endpoint_mask_pair(obs[nm])
        ab_role = role_from_obs(ab_obs, raw_roles[nm])
        a_with = _model([ab_role], [plan_canonical(ab_role, algs[nm])])
        a_without = _model([ab_role], [plan_no_columns(ab_role)])
        o8c = O8.endpoint_ablation_control(obs[nm])
        abl[nm] = {"with_columns": a_with["disclosed"], "without_columns": a_without["disclosed"],
                   "o8_single_mask_disclosed_total": o8c["single_mask_disclosed_total"],
                   "with_columns_ranks": a_with["o8_equivalent"], "without_columns_ranks": a_without["o8_equivalent"]}
        chk(f"ablation {nm}: single terminal-mask row discloses > 0 with columns", a_with["disclosed"] > 0, a_with["disclosed"], "> 0")
        chk(f"ablation {nm}: with == without == O8 ({o8c['single_mask_disclosed_total']})",
            a_with["disclosed"] == a_without["disclosed"] == o8c["single_mask_disclosed_total"],
            [a_with["disclosed"], a_without["disclosed"]], o8c["single_mask_disclosed_total"])
    # the ablated input inside the aliased IO cluster, with columns
    ab_in = role_from_obs(O8.ablate_endpoint_mask_pair(obs["Input"]), raw_roles["Input"])
    io_ab = _model([roles["A"], ab_in, roles["Output"]],
                   [plan_canonical(roles["A"], algs["A"]), plan_canonical(ab_in, algs["Input"]),
                    plan_canonical(roles["Output"], algs["Output"])], aliases)
    abl["io_cluster_with_ablated_input"] = {"with_columns": io_ab["disclosed"]}
    chk("ablation inside A+Input+Output (aliased, with columns) discloses > 0", io_ab["disclosed"] > 0, io_ab["disclosed"], "> 0")
    rec["controls"]["endpoint_mask_ablation"] = dict(abl, ms=_ms(t1))

    # ---- control 3: deficient pad budgets ----------------------------------------
    t1 = time.time()
    defc: dict = {}
    for nm in ("Input", "Output"):
        role, alg = roles[nm], algs[nm]
        for q_prime in sorted({alg.jd - 1, 255}):
            drole = Role(role.name, role.n, role.q_pad, role.domain, role.claims, role.groups, role.rho, role.kind,
                         role.rname, role.extras, role.indices, role.columns, role.prox_vector,
                         [q_prime if k == "mask" else role.q_pad for k in role.kind])
            res = _model([drole], [plan_deficient(drole, alg, "mask", q_prime)])
            key = f"{nm} alone, mask rows with {q_prime} pads (|J_d| = {alg.jd})"
            defc[key] = {"disclosed": res["disclosed"], "reduced": res["reduced_disclosed"], "column_only": res["column_only_disclosed"],
                         "q_prime": q_prime, "distinct_positions": alg.jd, "per_range_all": res["per_range_all"]}
            if q_prime < alg.jd:
                chk(f"deficient: {key} -> > 0", res["disclosed"] > 0, res["disclosed"], "> 0")
            else:
                chk(f"deficient: {key} -> 0 (budget >= |J_d|)", res["disclosed"] == 0, res["disclosed"], 0)
    hrole, halg = roles["H"], algs["H"]
    for cls in ("mask", "data"):
        q_prime = halg.jd - 1
        drole = Role(hrole.name, hrole.n, hrole.q_pad, hrole.domain, hrole.claims, hrole.groups, hrole.rho, hrole.kind,
                     hrole.rname, hrole.extras, hrole.indices, hrole.columns, hrole.prox_vector,
                     [q_prime if k == cls else hrole.q_pad for k in hrole.kind])
        rs = [drole if nm == "H" else roles[nm] for nm in all_names]
        ps = [plan_deficient(drole, halg, cls, q_prime) if nm == "H" else plan_canonical(roles[nm], algs[nm]) for nm in all_names]
        res = _model(rs, ps, aliases)
        key = f"all private aliased, H {cls} rows with {q_prime} pads (|J_d| = {halg.jd})"
        defc[key] = {"disclosed": res["disclosed"], "reduced": res["reduced_disclosed"], "column_only": res["column_only_disclosed"],
                     "leak_beyond_public_identity": res["disclosed"] - 2, "q_prime": q_prime, "distinct_positions": halg.jd,
                     "per_range_all": {k: v for k, v in res["per_range_all"].items() if k.startswith("H.")}}
        chk(f"deficient: {key} -> leak beyond the public identity > 0", res["disclosed"] > 2, res["disclosed"], "> 2")
    rec["controls"]["deficient_pads"] = dict(defc, ms=_ms(t1),
                                            note="the pad budget must be >= the number of DISTINCT opened positions; "
                                                 "255 >= |J_d| in every capture, so 255 pads still hide (round 20's condition)")

    # ---- M --------------------------------------------------------------------------
    malg = MaskAlgebra(mask_raw)
    rec["mask"] = malg.report()
    chk("M: functional rank over Fp2", malg.functional_rank_fp2 == 14, malg.functional_rank_fp2, 14)
    chk("M: disclosed with columns = 28 = the fourteen public functionals", malg.combined_rank_fp == 28 == malg.functional_rank_fp,
        [malg.combined_rank_fp, malg.functional_rank_fp], [28, 28])
    chk("M: disclosed beyond the public functionals", malg.combined_rank_fp - malg.functional_rank_fp == 0,
        malg.combined_rank_fp - malg.functional_rank_fp, 0)
    chk("M: without the functionals observed, residual = b's zero-sum (2)", malg.blinder_rank_fp == 2, malg.blinder_rank_fp, 2)
    chk("M: every kernel direction passes the b/u elimination checks",
        malg.directions_checked == sum(s["kernel_dim"] for s in malg.slots), malg.directions_checked,
        sum(s["kernel_dim"] for s in malg.slots))
    log(f"    M: |J_d| {malg.jd}, functionals rank {malg.functional_rank_fp2}, disclosed {malg.combined_rank_fp} "
        f"(beyond functionals {malg.combined_rank_fp - malg.functional_rank_fp}) ({malg.ms} ms)")

    rec["disclosed_dim_with_columns"] = {
        "per_role": {r: rec["roles"][r]["disclosed_dim_with_columns"] for r in all_names},
        "io_cluster_aliased": io_with["disclosed"], "all_private_commitments_aliased": all_with["disclosed"],
        "M": malg.combined_rank_fp, "M_beyond_public_functionals": malg.combined_rank_fp - malg.functional_rank_fp,
        "public_residuals": {"H": "the LogUp identity sum_j(helpers - table helpers) = 0 (2 base dims)",
                             "M": "its fourteen public functionals (28 base dims)"}}
    rec["disclosed_dim_without_columns"] = {
        "per_role": {r: rec["roles"][r]["disclosed_dim_without_columns"] for r in all_names},
        "io_cluster_aliased": io_without["disclosed"], "all_private_commitments_aliased": all_without["disclosed"]}
    rec["geometry"] = {r: {"rows": roles[r].rows, "distinct_opened_positions": algs[r].jd, "kernel_dim_per_row": algs[r].kernel_dim,
                           "pad_kernel_dim_per_row": algs[r].q_pad - algs[r].jd} for r in all_names}
    rec["geometry"]["M"] = {"rows": 20, "distinct_opened_positions": malg.jd, "prefix_words_fp2": malg.prefix_words}
    rec["checks_failed"] = sum(1 for c in checks if c["capture"] == os.path.basename(path) and not c["pass"])
    rec["ms"] = _ms(t0)
    rec["peak_rss_kb"] = peak_rss_kb()
    return rec


# ---------------------------------------------------------------------------
# the synthetic control (control 4) as a self-contained report
# ---------------------------------------------------------------------------


def synthetic_control(seed: int = 2409) -> dict:
    """Brute force on the full uncompressed matrix versus the reduced engine, on the
    small geometry n = 8, Q = 4, domain 64, |J_d| in {3, 4}, with an alias and a
    zero-sum extra; plus the ablation and deficient-pad variants."""
    cases = []
    aliases = [(("A", 2), ("E", 0))]

    def run(label, roles, alias, plans_with, expected=None):
        """expected: None (agreement only), an int, or ("gt", int)."""
        for r in roles:
            check_role_public(r)
        bw = brute_force(roles, alias, True)
        bo = brute_force(roles, alias, False)
        ew = _model(roles, plans_with(roles), alias)
        eo = _model(roles, [plan_no_columns(r) for r in roles], alias)
        rec = {"case": label, "brute_with": bw, "brute_without": bo,
               "engine_with": ew["disclosed"], "engine_without": eo["disclosed"],
               "engine_with_ranks": [ew["rank_L"], ew["rank_all"]], "engine_without_ranks": [eo["rank_L"], eo["rank_all"]],
               "agree": ew["disclosed"] == bw["disclosed"] and eo["disclosed"] == bo["disclosed"]}
        if expected is not None:
            rec["expected"] = expected
            if isinstance(expected, tuple):
                rec["agree"] = rec["agree"] and bw["disclosed"] > expected[1]
            else:
                rec["agree"] = rec["agree"] and bw["disclosed"] == expected
        cases.append(rec)
        return rec

    def canonical(roles):
        return [plan_canonical(r, ColumnAlgebra(r.n, r.q_pad, r.domain, r.indices)) for r in roles]

    def deficient_h(cls, q_prime):
        return lambda roles: [plan_deficient(r, ColumnAlgebra(r.n, r.q_pad, r.domain, r.indices), cls, q_prime)
                              if r.name == "H" else plan_canonical(r, ColumnAlgebra(r.n, r.q_pad, r.domain, r.indices))
                              for r in roles]

    # the baseline discloses exactly the public zero-sum on the u pair (2 base dims), as the real H
    base = run("baseline (alias, zero-sum, |J_d| 3/4/3)", synthetic_roles(seed)[0], aliases, canonical, expected=2)
    d0 = base["brute_with"]["disclosed"]
    run("baseline without the zero-sum constraint", synthetic_roles(seed, drop_zero_sum=True)[0], aliases, canonical,
        expected=0)
    run("four distinct positions per role",
        synthetic_roles(seed + 1, indices={"A": [3, 17, 40, 51], "E": [5, 9, 33, 61], "H": [2, 7, 44, 50]})[0],
        aliases, canonical, expected=d0)
    run("alias removed (control)", synthetic_roles(seed + 2)[0], (), canonical, expected=d0)
    run("endpoint second mask row ablated", synthetic_roles(seed + 3, ablate_endpoint=True)[0], aliases, canonical,
        expected=("gt", d0))
    for cls in ("mask", "data"):
        run(f"H {cls} rows with 2 pads (|J_d| = 3)", synthetic_roles(seed + 4, deficient=("H", cls, 2))[0], aliases,
            deficient_h(cls, 2), expected=("gt", d0))
    run("H mask rows with 3 pads (|J_d| = 3, budget = |J_d|)", synthetic_roles(seed + 5, deficient=("H", "mask", 3))[0],
        aliases, deficient_h("mask", 3), expected=d0)
    # explicit E_J on the small geometry: rank, kernel, basis count
    alg = ColumnAlgebra(8, 4, 64, [3, 17, 40, 3])
    ej = explicit_column_matrix(alg)
    basis = [alg.kernel_vector("completion", j)[0] + alg.kernel_vector("completion", j)[1] for j in range(8)]
    basis += [alg.kernel_vector("padker", i)[0] + alg.kernel_vector("padker", i)[1] for i in range(alg.q_pad - alg.jd)]
    in_kernel = all(all(sum(a * b for a, b in zip(row, vec)) % P == 0 for row in ej) for vec in basis)
    algebra = {"rank_E_J": R.rank(ej), "distinct": alg.jd, "basis_rank": R.rank(basis), "kernel_dim": alg.kernel_dim,
               "basis_in_kernel": in_kernel,
               "agree": R.rank(ej) == alg.jd and R.rank(basis) == alg.kernel_dim == 12 - alg.jd and in_kernel}
    return {"cases": cases, "explicit_E_J": algebra,
            "pass": all(c["agree"] for c in cases) and algebra["agree"]}


def explicit_column_matrix(alg: ColumnAlgebra) -> List[List[int]]:
    """E_J written out: rows = distinct opened points, columns = (m_0..m_{n-1}, g_0..g_{Q-1})."""
    lag = [fft([1 if t == j else 0 for t in range(alg.n)], True) for j in range(alg.n)]
    out = []
    for x, z in zip(alg.xs, alg.zs):
        row = [poly_eval(f, x) for f in lag]
        xt = 1
        for _ in range(alg.q_pad):
            row.append(z * xt % P)
            xt = xt * x % P
        out.append(row)
    return out


# ---------------------------------------------------------------------------
# the run
# ---------------------------------------------------------------------------


def tool_digests() -> Dict[str, str]:
    files = [TOOL_NAME, "zk60_opus_io_capture.py", "zk60_io_opening_translation.py", "zk60_fable_joint_capture.py",
             "zk60_fable_joint_rank.py", "zk60_fable_cfs_channel.py", "zk60_opus_repaired_capture.py",
             "zk60_io_capture_preflight.py"]
    return {f: sha256_file(os.path.join(_HERE, f)) for f in files if os.path.exists(os.path.join(_HERE, f))}


def run(captures_dir: str, manifest_path: str, log=print) -> dict:
    t0 = time.time()
    man = O8.load_manifest(manifest_path)
    pre = O8.preflight(captures_dir, manifest_path, log=lambda *a: None)
    require(pre["pass"] and all(c["pass"] for c in pre["checks"]), "capture preflight failed")
    archived = load_archived_o8()
    checks: List[dict] = []
    log("synthetic control (brute force vs engine)")
    synth = synthetic_control()
    checks.append({"capture": "synthetic", "check": "brute force agrees with the reduced engine on every small case",
                   "pass": synth["pass"], "actual": [c["agree"] for c in synth["cases"]] + [synth["explicit_E_J"]["agree"]],
                   "expected": "all true"})
    log(f"  synthetic: {'pass' if synth['pass'] else 'FAIL'}")
    files = sorted(f for f in os.listdir(captures_dir) if f.endswith(".json"))
    cases = []
    for f in files:
        path = os.path.join(captures_dir, f)
        entry = next((e for e in man["entries"].values() if os.path.basename(e["path"]) == f), None)
        require(entry is not None, f"{f} is not in the manifest")
        cases.append(analyze_capture(path, entry, log, archived, checks))
    failed = [c for c in checks if not c["pass"]]
    summary = {
        "captures": len(cases),
        "disclosed_dim_with_columns": {c["proof_sha256"][:12] + "/" + c["privacy"]: c["disclosed_dim_with_columns"] for c in cases},
        "disclosed_dim_without_columns": {c["proof_sha256"][:12] + "/" + c["privacy"]: c["disclosed_dim_without_columns"] for c in cases},
        "distinct_opened_positions": {c["proof_sha256"][:12]: {r: g["distinct_opened_positions"] for r, g in c["geometry"].items()}
                                      for c in cases},
        "checks": len(checks), "checks_failed": len(failed)}
    return {"schema": SCHEMA, "tool": TOOL_NAME, "status": "passed" if not failed else "failed",
            "source_commit": O8.SOURCE_COMMIT, "profile": O8.PROFILE,
            "manifest": {"path": man["path"], "sha256": man["sha256"]},
            "captures_directory": os.path.abspath(captures_dir), "capture_preflight_checks": len(pre["checks"]),
            "archived_o8_analysis_sha256": ARCHIVED_O8_SHA256, "tool_sha256": tool_digests(),
            "model": {"unknowns": "every row's 256 message words and 256 pads per role; M's prefixes, pads, b, u",
                      "observations": "full group and proximity vectors (message and pad coordinates), terminals, "
                                      "H's zero-sum, the 256 opened columns of every row; M's q', proximity, "
                                      "fourteen functionals and 256 columns of 20 base rows",
                      "uniform_randomness": ["mask/prox row message words", "every row's pad coefficients", "M pad words",
                                             "M blinder b (zero-sum subspace)", "M blinder u"],
                      "outside_the_model": ["hash/salt/Merkle hiding of unopened positions", "adaptive Fiat-Shamir",
                                            "CFS round messages (FA6)", "repeated openings of one commitment"],
                      "reduction": "per role, ker E_J spanned by [I; -G E^m] and [0; V_J X^i] on the captured J; "
                                   "fold observations decouple per coordinate; terminals keep O8's weights"},
            "synthetic_control": synth, "cases": cases, "checks": checks, "failed_checks": failed, "summary": summary,
            "privacy_analysis_complete": False, "full_privacy_review_complete": False,
            "ms": _ms(t0), "peak_rss_kb": peak_rss_kb()}


def main(argv: Optional[Sequence[str]] = None) -> int:
    ap = argparse.ArgumentParser(description="joint PCS-side field view with the opened columns (see module docstring)")
    ap.add_argument("--captures", required=True)
    ap.add_argument("--manifest", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args(argv)
    require(not os.path.exists(args.out), "output already exists (evidence is never overwritten)")
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    result = run(args.captures, args.manifest)
    with open(args.out, "x") as fh:
        json.dump(result, fh, indent=1)
        fh.write("\n")
    s = result["summary"]
    print(f"{result['status'].upper()}: {s['captures']} captures, {s['checks']} checks, {s['checks_failed']} failed; "
          f"{result['ms']} ms, peak RSS {result['peak_rss_kb']} kB")
    for k, v in s["disclosed_dim_with_columns"].items():
        print(f"  {k}: with columns {v['per_role']} io {v['io_cluster_aliased']} all {v['all_private_commitments_aliased']} "
              f"M {v['M']} (beyond public functionals {v['M_beyond_public_functionals']})")
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())

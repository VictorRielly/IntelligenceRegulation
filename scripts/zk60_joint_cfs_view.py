#!/usr/bin/env python3
"""The joint CFS view of an ffn-v3-mr1-fresh-io-poc/2 proof at the captured coefficients.

For each round-22 capture this tool treats ALL EIGHT masked sumcheck slots (the
six FFN slots gu, d, zc20, zc17, zs, tab in M order and the two IO slots 6, 7)
and the M opening TOGETHER, at the actual captured coefficients:

(i)   per slot (or batched pair, as zk.rs batches (gu, zc20) and (d, zc17)),
      the affine map a_s -> (masked rounds, claimed sum / Gamma, g_s(rho_s)) at
      the slot's (c_s, rho_s), and the fibre statement: every witness-side
      honest round vector in the consistency subspace S(claim, final) --
      round j's sum equals round j-1 at rho_{j-1}, the first round sums to the
      claim, the last round evaluates to the final value -- is consistent with
      the observed masked rounds and the SAME functional values, with a mask
      fibre of the same dimension (the kernel of the mask part) for every
      honest vector; existence is checked by solving for a_s explicitly.
(ii)  the M opening at the captured theta, q', proximity rhos, opened indices
      and pads, jointly over the 16 a-rows, b and u (FA6's joint model at the
      captured coefficients; organised as an exact block elimination because
      the dense 9216 x 8648 Fp system does not fit the box's memory/time): the
      a-rows are constrained through V = sum_i theta^i F_i only, which lies in
      the span of the 14 functionals (disclosed dimension beyond them = 0).
(iii) the composed statement: (i) and (ii) with shared a_s unknowns, ONE
      joint rank computation over all eight slots' a-rows and the honest
      rounds, with the observed rounds, sent claims / Gammas, the derived and
      sent evaluations and V as observations: the witness-side honest rounds
      of every slot are unconstrained by the whole view.

The two IO slots' zero-witness preimage / translation check of round 21
(zk60_io_cfs_composition.check_slot / controls) is carried unchanged.

Challenges.  The captures record (c, rho) for the two IO slots only, but the
verifier's mask functionals recorded in `mask.functionals` determine the six
FFN slots' challenges exactly: the eval functionals' weights are
CfsMask::eval_weights(rho_s) (so rho_s is read off), the Gamma weights are
c_s * sum_weights (so c20, c17, c_zs, c_tab are read off), the zero-check
round-0 chain h_0(0)+h_0(1) = nu * claim + Gamma gives nu0 / nu_z, and the
Gamma pair terms -nu c_gu sum_weights give c_gu, c_d.  This tool always derives
them and verifies the verifier's chain on the captured FFN rounds with them.
With --challenges <json> (the sibling transcript replay) the six FFN slots run
at those values, cross-checked against the derived ones (ffn_challenges:
"captured"); without it the main analysis runs the FFN slots at seeded
STAND-IN challenges with synthetic observations (ffn_challenges: "stand-in")
and the analysis at the derived challenges on the real FFN rounds is reported
under `derived_analysis`.

    python3 scripts/zk60_joint_cfs_view.py --captures <dir> --manifest <json> [--challenges <json>] --out <json>

Exit status 1 on any unmet expectation.  Nothing secret is read: the captures
are verifier observations; no proving seed, witness or mask coefficient exists
here.  Existing tools are imported by file path and not modified.
"""
import argparse
import copy
import hashlib
import importlib.util
import json
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))


def _load(name, filename):
    if name in sys.modules:
        return sys.modules[name]
    spec = importlib.util.spec_from_file_location(name, str(HERE / filename))
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


C = _load("zk60_fable_cfs_channel", "zk60_fable_cfs_channel.py")            # FA6: CFS weights, Fp2 rank, coset helpers
R = C.R                                                                      # FA2: field, int rref
OT = _load("zk60_io_opening_translation", "zk60_io_opening_translation.py")  # round 20: M public identities
IOC = _load("zk60_io_cfs_composition", "zk60_io_cfs_composition.py")         # round 21: IO fibre + controls
PRE = OT.pre                                                                 # round-19 preflight (require, digest, run)

P, ZERO, ONE, U = C.P, C.ZERO, C.ONE, C.U
f2_add, f2_sub, f2_mul, f2_neg, f2_inv, f2_is_zero = C.f2_add, C.f2_sub, C.f2_mul, C.f2_neg, C.f2_inv, C.f2_is_zero
require = PRE.require

SOURCE_COMMIT = "1f0ff3680c4cda88f1744343e24eb93cdddfcba4"
PROFILE = "ffn-v3-mr1-fresh-io-poc/2"
REVIEWER = "Claude Fable 5.1, 2026-09-15 session (joint CFS view)"
SLOT_NAMES = ["gu", "d", "zc20", "zc17", "zs", "tab", "io0", "io1"]   # M slot order: mask_specs_v3 + the two IO slots
FFN_SLOTS = {"gu": 0, "d": 1, "zc20": 2, "zc17": 3, "zs": 4, "tab": 5}
SLOT_ALIASES = {"gu": "gu", "sc_gu": "gu", "d": "d", "sc_d": "d", "zc20": "zc20", "zcf": "zc20", "sc_zc20": "zc20", "zero-check-f": "zc20",
                "zc17": "zc17", "zcd": "zc17", "sc_zc17": "zc17", "zero-check-d": "zc17", "zs": "zs", "zsum": "zs", "sc_zsum": "zs", "zero-sum": "zs",
                "tab": "tab", "table": "tab", "sc_tab": "tab"}
MODELLED_SOURCES = ["zkp-core/src/sumcheck.rs", "hashline/src/zk.rs", "hashline/src/zk_ffn_fresh_io.rs"]
MASK_LOG_MSG, MASK_LOG_DOM, MASK_Q = 9, 12, 256
M_ROWS = 20   # 2 * 8 a-rows + b_re, b_im, u_re, u_im

# The 14 mask functionals of this profile (hashline/src/zk.rs mask_functionals, zk_ffn_fresh_io.rs functionals),
# in the order prover and verifier push them.  `ffn_gammas` is in TRANSCRIPT order (zc20, zc17, tab, zs), the
# functionals in SLOT order (zs = slot 4, tab = slot 5).
FUNCTIONAL_ASSIGNMENT = [
    {"index": 0, "kind": "eval", "slots": [0], "weights": "eval_weights(rho_gu, 2)", "value": "g_gu(rho_gu), derived by the verifier as div(fin - want(gu_term), c_gu)"},
    {"index": 1, "kind": "eval", "slots": [1], "weights": "eval_weights(rho_d, 2)", "value": "g_d(rho_d), derived: div(fin - want(d_term), c_d)"},
    {"index": 2, "kind": "eval", "slots": [2], "weights": "eval_weights(rho_zc20, 4)", "value": "g_zc20(rho), derived: div(fin - want(zc20_term), c20)"},
    {"index": 3, "kind": "eval", "slots": [3], "weights": "eval_weights(rho_zc17, 4)", "value": "g_zc17(rho), derived: div(fin - want(zc17_term), c17)"},
    {"index": 4, "kind": "eval", "slots": [4], "weights": "eval_weights(rho_zs, 2)", "value": "g_zs(rho), derived: div(fin - (1-e) zs_term, c_zs)"},
    {"index": 5, "kind": "eval", "slots": [5], "weights": "eval_weights(rho_tab, 3)", "value": "g_tab(rho), derived: div(fin - want(tab_term), c_tab)"},
    {"index": 6, "kind": "gamma_pair", "slots": [2, 0], "weights": "c20 sum_weights(zc20) on slot 2; -nu0 c_gu sum_weights(gu) on slot 0", "value": "gamma20 (sent; ffn_gammas[0]); the zc20 claimed sum is nu0 gu_claim + gamma20"},
    {"index": 7, "kind": "gamma_pair", "slots": [3, 1], "weights": "c17 sum_weights(zc17) on slot 3; -nu_z c_d sum_weights(d) on slot 1", "value": "gamma17 (sent; ffn_gammas[1]); the zc17 claimed sum is nu_z d_claim + gamma17"},
    {"index": 8, "kind": "gamma", "slots": [4], "weights": "c_zs sum_weights(zs)", "value": "gamma_zs (sent; ffn_gammas[3])"},
    {"index": 9, "kind": "gamma", "slots": [5], "weights": "c_tab sum_weights(tab)", "value": "gamma_tab (sent; ffn_gammas[2])"},
    {"index": 10, "kind": "gamma", "slots": [6], "weights": "c_io0 sum_weights(10, 2)", "value": "io_arguments[0].gamma (sent)"},
    {"index": 11, "kind": "eval", "slots": [6], "weights": "eval_weights(rho_io0, 2)", "value": "io_arguments[0].mask_eval (sent; checked in the IO terminal identity)"},
    {"index": 12, "kind": "gamma", "slots": [7], "weights": "c_io1 sum_weights(10, 2)", "value": "io_arguments[1].gamma (sent)"},
    {"index": 13, "kind": "eval", "slots": [7], "weights": "eval_weights(rho_io1, 2)", "value": "io_arguments[1].mask_eval (sent)"},
]


# ----------------------------------------------------------------------------
# generic sparse linear algebra (field-parametrised so the brute-force test can run it over a tiny prime field)
# ----------------------------------------------------------------------------


class Field:
    def __init__(self, zero, one, add, sub, mul, inv, is_zero, neg):
        self.zero, self.one, self.add, self.sub, self.mul, self.inv, self.is_zero, self.neg = zero, one, add, sub, mul, inv, is_zero, neg


FP2 = Field(ZERO, ONE, f2_add, f2_sub, f2_mul, f2_inv, f2_is_zero, f2_neg)


def prime_field(q):
    return Field(0, 1, lambda a, b: (a + b) % q, lambda a, b: (a - b) % q, lambda a, b: (a * b) % q,
                 lambda a: pow(a % q, q - 2, q), lambda a: a % q == 0, lambda a: (-a) % q)


def echelon(rows, field=FP2):
    """Row echelon form of sparse rows ({column: value}); returns {pivot column: normalised row}.
    A normalised row has its pivot (value 1) at its smallest column.  Columns are eliminated left to
    right, so with mask columns before data columns the number of pivots inside the mask block is the
    rank of the mask block and the pivots inside the data block count rank([M | D]) - rank(M)."""
    pivots = {}
    for row in rows:
        r = {k: v for k, v in row.items() if not field.is_zero(v)}
        while r:
            c = min(r)
            p = pivots.get(c)
            if p is None:
                inv = field.inv(r[c])
                pivots[c] = {k: field.mul(v, inv) for k, v in r.items()}
                break
            f = r[c]
            for k, v in p.items():
                nv = field.sub(r.get(k, field.zero), field.mul(f, v))
                if field.is_zero(nv):
                    r.pop(k, None)
                else:
                    r[k] = nv
    return pivots


def back_substitute(pivots, ncols, rhs, field=FP2, free=None):
    """A solution of the echelon system with the rhs column `rhs`; free columns take free(c) (default 0).
    None when the system is inconsistent (a pivot in the rhs column)."""
    if rhs in pivots:
        return None
    x = [None] * ncols
    for c in range(ncols):
        if c not in pivots:
            x[c] = free(c) if free else field.zero
    for c in sorted(pivots, reverse=True):
        row = pivots[c]
        acc = row.get(rhs, field.zero)
        for k, v in row.items():
            if k != c and k != rhs:
                acc = field.sub(acc, field.mul(v, x[k]))
        x[c] = acc
    return x


def substitute(row, values, rhs, field=FP2):
    """Move the columns in `values` to the rhs: sum_k row[k] x_k = b  ->  sum_{k not fixed} row[k] x_k = b - sum_fixed row[k] v_k."""
    out = {}
    b = row.get(rhs, field.zero)
    for k, v in row.items():
        if k == rhs:
            continue
        if k in values:
            b = field.sub(b, field.mul(v, values[k]))
        else:
            out[k] = v
    if not field.is_zero(b):
        out[rhs] = b
    return out


def fp_rank(rows):
    """Rank of an integer matrix over Fp (forward elimination only; rows are copied)."""
    m = [list(r) for r in rows]
    if not m:
        return 0
    ncols = len(m[0])
    r = 0
    for col in range(ncols):
        piv = next((i for i in range(r, len(m)) if m[i][col] % P), None)
        if piv is None:
            continue
        m[r], m[piv] = m[piv], m[r]
        inv = pow(m[r][col], P - 2, P)
        prow = [(x * inv) % P for x in m[r]]
        m[r] = prow
        for i in range(r + 1, len(m)):
            f = m[i][col]
            if f:
                m[i] = [(x - f * y) % P for x, y in zip(m[i], prow)]
        r += 1
        if r == len(m):
            break
    return r


def block_disclosed(mask_block, data_block):
    """Fp observations obs = M mask + D data on one block: the dimension of the data functionals the block
    determines is rank([M | D]) - rank(M); rank([M | D]) <= rows gives 0 at once when M has full row rank."""
    rows = len(mask_block)
    rm = fp_rank(mask_block) if mask_block and mask_block[0] else 0
    if rm == rows:
        return {"rows": rows, "mask_rank": rm, "joint_rank": rows, "disclosed_fp": 0}
    rj = fp_rank([a + b for a, b in zip(mask_block, data_block)]) if mask_block and mask_block[0] else fp_rank(data_block)
    return {"rows": rows, "mask_rank": rm, "joint_rank": rj, "disclosed_fp": rj - rm}


# ----------------------------------------------------------------------------
# one masked sumcheck slot and the joint linear system
# ----------------------------------------------------------------------------


def _fp2(v, what="Fp2 value"):
    if isinstance(v, (list, tuple)) and len(v) == 2 and all(isinstance(x, int) for x in v):
        return (v[0] % P, v[1] % P)
    if isinstance(v, dict):
        for a, b in (("c0", "c1"), ("re", "im"), ("0", "1")):
            if a in v and b in v:
                return (int(v[a]) % P, int(v[b]) % P)
    if isinstance(v, int):
        return (v % P, 0)
    raise ValueError(f"not an Fp2 {what}: {v!r}")


class SlotModel:
    """One masked sumcheck slot as the verifier sees it: (n, d) from mask.specs, the challenge c and the
    round challenges rho, the observed masked rounds h (n x (d+1)), the sent claim (gu_claim / d_claim
    for kind 'matmul', Gamma for 'zero' and 'batched'), the functional value g(rho) (derived by the
    verifier for the FFN slots, sent as mask_eval for the IO slots).  kind 'batched' = a zero-check whose
    claimed sum is nu * (partner's claim) + Gamma with Gamma = c G - nu c_a G_a (the (gu, zc20), (d, zc17) pairs).
    Refusals mirror the source: c = 0 (zk.rs div / zk_ffn_fresh_poc.rs draw_mask_challenge) and
    rho[-1] = 0 (zk_ffn_fresh_io.rs: 'zero terminal mask challenge'; applied to every slot here)."""

    def __init__(self, name, index, n, d, c, rho, rounds, claim, eval_value, kind, nu=None, partner=None, allow_degenerate=False):
        require(kind in ("matmul", "zero", "batched"), "slot kind")
        require(len(rho) == n and len(rounds) == n and all(len(r) == d + 1 for r in rounds), f"{name}: slot geometry")
        if not allow_degenerate:
            require(c != ZERO, f"refused: zero mask challenge on slot {name}")
            require(rho[-1] != ZERO, f"refused: zero terminal mask challenge on slot {name}")
        self.name, self.index, self.n, self.d, self.c, self.rho = name, index, n, d, c, list(rho)
        self.L = C.cfs_len(n, d)
        self.rounds = [list(r) for r in rounds]
        self.claim, self.eval_value, self.kind, self.nu, self.partner = claim, eval_value, kind, nu, partner
        self.sum_weights = C.cfs_sum_weights(n, d)
        self.eval_weights = C.cfs_eval_weights(self.rho, d)
        self.round_weights = [C.cfs_round_weights(n, d, j, self.rho[:j]) for j in range(n)]
        self.final = C.interp_eval(self.rounds[-1], self.rho[-1])
        # the honest final value: fin = want(masked terminals) + c g(rho), so want = fin - c g(rho)
        self.want = f2_sub(self.final, f2_mul(c, eval_value))

    def claimed_sum(self):
        if self.kind == "batched":
            return f2_add(f2_mul(self.nu, self.partner.claim), self.claim)
        return self.claim

    def replay_chain(self):
        """zkp-core/src/sumcheck.rs verify: s_j(0) + s_j(1) == claim, claim <- interpolate_eval(s_j, r_j); then the terminal identity fin == want + c g(rho)."""
        current = self.claimed_sum()
        for j, vals in enumerate(self.rounds):
            require(f2_add(vals[0], vals[1]) == current, f"{self.name}: sumcheck round {j}: s(0) + s(1) != claim")
            current = C.interp_eval(vals, self.rho[j])
        require(current == f2_add(self.want, f2_mul(self.c, self.eval_value)), f"{self.name}: masked terminal identity")
        return current


class JointSystem:
    """Unknowns (Fp2 columns): the mask coefficients of every slot (mask block, first), then the honest
    round values f_s[j][x] and the private totals s of the matmul slots (data block), then the rhs.
    Observation rows: h = f + c W a (rounds), the sent claims / Gammas, the functional values, optionally V.
    Constraint rows (data only): the consistency subspace S(claim, final) of every slot."""

    def __init__(self, models, pairs=(), v_row=None):
        self.models = list(models)
        self.pairs = list(pairs)
        self.mask_off, self.f_off, self.s_col = {}, {}, {}
        col = 0
        for m in self.models:
            self.mask_off[m.name] = col
            col += m.L
        self.n_mask = col
        for m in self.models:
            self.f_off[m.name] = col
            col += m.n * (m.d + 1)
            if m.kind == "matmul":
                self.s_col[m.name] = col
                col += 1
        self.n_data = col - self.n_mask
        self.rhs = col
        self.ncols = col + 1
        self.obs_rows, self.obs_tags, self.cons_rows, self.cons_tags = [], [], [], []
        batched = {p["b"].name for p in self.pairs}
        for m in self.models:
            self._slot_rows(m, batched=m.name in batched)
        for p in self.pairs:
            self._pair_rows(p["a"], p["b"])
        if v_row is not None:
            weights, value = v_row
            row = dict(weights)
            row[self.rhs] = value
            self._obs(row, "V = sum theta^i F_i (the M opening)")

    def f_col(self, m, j, x):
        return self.f_off[m.name] + j * (m.d + 1) + x

    def mask_row(self, m, weights, scale=ONE):
        off = self.mask_off[m.name]
        return {off + k: f2_mul(scale, w) for k, w in enumerate(weights) if not f2_is_zero(f2_mul(scale, w))}

    def _obs(self, row, tag):
        self.obs_rows.append(row)
        self.obs_tags.append(tag)

    def _cons(self, row, tag):
        self.cons_rows.append(row)
        self.cons_tags.append(tag)

    def _slot_rows(self, m, batched):
        for j in range(m.n):
            for x in range(m.d + 1):
                row = self.mask_row(m, m.round_weights[j][x], m.c)
                row[self.f_col(m, j, x)] = ONE
                row[self.rhs] = m.rounds[j][x]
                self._obs(row, f"{m.name}.h{j}({x})")
        row = self.mask_row(m, m.eval_weights)
        row[self.rhs] = m.eval_value
        self._obs(row, f"{m.name}.g(rho)")
        if m.kind == "matmul":
            row = self.mask_row(m, m.sum_weights, m.c)
            row[self.s_col[m.name]] = ONE
            row[self.rhs] = m.claim
            self._obs(row, f"{m.name}.claim = s + c G")
        elif m.kind == "zero":
            row = self.mask_row(m, m.sum_weights, m.c)
            row[self.rhs] = m.claim
            self._obs(row, f"{m.name}.Gamma = c G")
        elif not batched:
            raise ValueError(f"{m.name}: a batched zero-check needs its pair")
        # the consistency subspace S(claim, final)
        row = {self.f_col(m, 0, 0): ONE, self.f_col(m, 0, 1): ONE}
        if m.kind == "matmul":
            row[self.s_col[m.name]] = f2_neg(ONE)
        elif m.kind == "batched":
            row[self.s_col[m.partner.name]] = f2_neg(m.nu)   # the honest total of the zero-check is nu * s_a
        self._cons(row, f"{m.name}.f0(0)+f0(1) = honest total")
        for j in range(1, m.n):
            row = {self.f_col(m, j, 0): ONE, self.f_col(m, j, 1): ONE}
            for x, lx in enumerate(C.lagrange_weights(m.d, m.rho[j - 1])):
                row[self.f_col(m, j - 1, x)] = f2_add(row.get(self.f_col(m, j - 1, x), ZERO), f2_neg(lx))
            self._cons(row, f"{m.name}.f{j}(0)+f{j}(1) = f{j - 1}(r{j - 1})")
        row = {self.f_col(m, m.n - 1, x): lx for x, lx in enumerate(C.lagrange_weights(m.d, m.rho[-1]))}
        row[self.rhs] = m.want
        self._cons(row, f"{m.name}.f{m.n - 1}(r{m.n - 1}) = want")

    def _pair_rows(self, a, b):
        require(b.kind == "batched" and b.partner is a and a.kind == "matmul", "pair geometry")
        row = self.mask_row(b, b.sum_weights, b.c)
        for k, v in self.mask_row(a, a.sum_weights, f2_neg(f2_mul(b.nu, a.c))).items():
            row[k] = f2_add(row.get(k, ZERO), v)
        row[self.rhs] = b.claim
        self._obs(row, f"{b.name}.Gamma = c_b G_b - nu c_a G_a")

    def data_cols(self):
        return range(self.n_mask, self.n_mask + self.n_data)


def analyze_system(system):
    piv_all = echelon(system.obs_rows + system.cons_rows)
    piv_cons = echelon(system.cons_rows)
    mask_rank = sum(1 for c in piv_all if c < system.n_mask)
    data_pivots = sum(1 for c in piv_all if system.n_mask <= c < system.rhs)
    rank_cons = len(piv_cons)
    consistent = system.rhs not in piv_all
    disclosed = data_pivots - rank_cons
    return {
        "slots": [m.name for m in system.models],
        "n_mask_unknowns_fp2": system.n_mask, "n_honest_unknowns_fp2": system.n_data,
        "n_observation_rows": len(system.obs_rows), "n_constraint_rows": len(system.cons_rows),
        "mask_rank_fp2": mask_rank, "mask_fibre_dim_fp2": system.n_mask - mask_rank,
        "constraints_rank_fp2": rank_cons, "honest_subspace_dim_fp2": system.n_data - rank_cons,
        "honest_disclosed_dim_fp2": disclosed, "observations_consistent": consistent,
        "honest_unconstrained": consistent and disclosed == 0,
    }


def preimage_check(system, rng, samples=2):
    """For random honest vectors (f, s) in S(claim, final), solve for the mask coefficients reproducing the
    observed rounds with the same functional values; verify with the closed forms of CfsMask; the mask
    fibre over each honest vector has the same dimension (the kernel of the mask block)."""
    out = []
    for _ in range(samples):
        piv = echelon(system.cons_rows)
        x = back_substitute(piv, system.ncols, system.rhs, free=lambda c: rng.fp2())
        require(x is not None, "constraints inconsistent")
        honest = {c: x[c] for c in system.data_cols()}
        mask_rows = [substitute(row, honest, system.rhs) for row in system.obs_rows]
        piv_m = echelon(mask_rows)
        a = back_substitute(piv_m, system.ncols, system.rhs, free=lambda c: rng.fp2())
        require(a is not None, "no mask coefficients reproduce the view for this honest vector")
        fibre = system.n_mask - len([c for c in piv_m if c < system.n_mask])
        for m in system.models:
            off = system.mask_off[m.name]
            coeffs = a[off:off + m.L]
            for j in range(m.n):
                g = C.cfs_round(coeffs, m.n, m.d, j, m.rho[:j])
                for xx in range(m.d + 1):
                    require(f2_add(honest[system.f_col(m, j, xx)], f2_mul(m.c, g[xx])) == m.rounds[j][xx], f"{m.name}: preimage rounds")
            require(C.cfs_eval(coeffs, m.rho, m.d) == m.eval_value, f"{m.name}: preimage g(rho)")
            total = C.cfs_total(coeffs, m.n, m.d)
            if m.kind == "matmul":
                require(f2_add(honest[system.s_col[m.name]], f2_mul(m.c, total)) == m.claim, f"{m.name}: preimage claim")
            elif m.kind == "zero":
                require(f2_mul(m.c, total) == m.claim, f"{m.name}: preimage Gamma")
        for p in system.pairs:
            a_, b_ = p["a"], p["b"]
            ta = C.cfs_total(a[system.mask_off[a_.name]:system.mask_off[a_.name] + a_.L], a_.n, a_.d)
            tb = C.cfs_total(a[system.mask_off[b_.name]:system.mask_off[b_.name] + b_.L], b_.n, b_.d)
            require(f2_sub(f2_mul(b_.c, tb), f2_mul(f2_mul(b_.nu, a_.c), ta)) == b_.claim, f"{b_.name}: preimage pair Gamma")
        out.append(fibre)
    return {"samples": samples, "preimages_verified": True, "fibre_dims": out, "same_fibre_dim": len(set(out)) == 1}


def chain_sample(n, d, rho, total, want, rng):
    """A random honest round vector in S(total, want): the chain constraints solved with random free coordinates."""
    cols = lambda j, x: j * (d + 1) + x
    rhs = n * (d + 1)
    rows = [{cols(0, 0): ONE, cols(0, 1): ONE, rhs: total}]
    for j in range(1, n):
        row = {cols(j, 0): ONE, cols(j, 1): ONE}
        for x, lx in enumerate(C.lagrange_weights(d, rho[j - 1])):
            row[cols(j - 1, x)] = f2_add(row.get(cols(j - 1, x), ZERO), f2_neg(lx))
        rows.append(row)
    row = {cols(n - 1, x): lx for x, lx in enumerate(C.lagrange_weights(d, rho[-1]))}
    row[rhs] = want
    rows.append(row)
    x = back_substitute(echelon(rows), rhs + 1, rhs, free=lambda c: rng.fp2())
    require(x is not None, "chain sample")
    return [[x[cols(j, xx)] for xx in range(d + 1)] for j in range(n)]


def synthetic_slot(name, index, n, d, c, rho, rng, kind, nu=None, partner=None, allow_degenerate=False, want=None):
    """A slot with a random mask, a random honest round vector and the resulting masked view (stand-in mode and controls)."""
    coeffs = [rng.fp2() for _ in range(C.cfs_len(n, d))]
    total, ev = C.cfs_total(coeffs, n, d), C.cfs_eval(coeffs, rho, d)
    if kind == "matmul":
        s = rng.fp2()
        claim, honest_total = f2_add(s, f2_mul(c, total)), s
    elif kind == "zero":
        s = None
        claim, honest_total = f2_mul(c, total), ZERO
    else:
        s = None
        honest_total = f2_mul(nu, partner.s)
        claim = f2_sub(f2_mul(c, total), f2_mul(f2_mul(nu, partner.c), partner.mask_total))
    want = rng.fp2() if want is None else want
    f = chain_sample(n, d, rho, honest_total, want, rng)
    rounds = [[f2_add(f[j][x], f2_mul(c, g)) for x, g in enumerate(C.cfs_round(coeffs, n, d, j, rho[:j]))] for j in range(n)]
    m = SlotModel(name, index, n, d, c, rho, rounds, claim, ev, kind, nu=nu, partner=partner, allow_degenerate=allow_degenerate)
    m.s, m.mask_total, m.synthetic = s, total, True
    return m


# ----------------------------------------------------------------------------
# the captures: functionals, challenges (derived / file / stand-in), slot models
# ----------------------------------------------------------------------------


def functional_rows(mask):
    """The 14 functionals as rows over the concatenated a-coefficients (Fp2), their values, the offsets, and V."""
    lengths = [C.cfs_len(n, d) for n, d in mask["specs"]]
    offsets = [sum(lengths[:i]) for i in range(len(lengths))]
    theta = _fp2(mask["theta"], "theta")
    rows, values, v, th = [], [], ZERO, ONE
    v_row = [ZERO] * sum(lengths)
    for f in mask["functionals"]:
        row = [ZERO] * sum(lengths)
        for t in f["terms"]:
            s = t["slot"]
            require(len(t["weights"]) == lengths[s], "functional weight length")
            for j, w in enumerate(t["weights"]):
                row[offsets[s] + j] = f2_add(row[offsets[s] + j], _fp2(w))
        rows.append(row)
        values.append(_fp2(f["value"]))
        v_row = [f2_add(a, f2_mul(th, b)) for a, b in zip(v_row, row)]
        v = f2_add(v, f2_mul(th, _fp2(f["value"])))
        th = f2_mul(th, theta)
    return {"lengths": lengths, "offsets": offsets, "rows": rows, "values": values, "v_row": v_row, "v": v, "theta": theta}


def verify_functional_assignment(capture):
    """Check the 14 recorded functionals against FUNCTIONAL_ASSIGNMENT: slots, weight forms and value sources."""
    mask, specs = capture["mask"], capture["mask"]["specs"]
    F = mask["functionals"]
    require(len(F) == 14 and len(specs) == 8, "14 functionals over 8 slots")
    require(specs[6] == [10, 2] and specs[7] == [10, 2], "IO slot specs")
    gammas = [_fp2(g) for g in capture["ffn_gammas"]]
    claims = [_fp2(x) for x in capture["ffn_matmul_claims"]]
    io = capture["io_arguments"]
    report = []
    for spec in FUNCTIONAL_ASSIGNMENT:
        f = F[spec["index"]]
        require([t["slot"] for t in f["terms"]] == spec["slots"], f"functional {spec['index']} slots")
        entry = dict(spec)
        for t in f["terms"]:
            n, d = specs[t["slot"]]
            w = [_fp2(x) for x in t["weights"]]
            if spec["kind"] == "eval":
                rho = [w[2 + j * d] for j in range(n)]
                require(w == C.cfs_eval_weights(rho, d), f"functional {spec['index']}: eval weight form")
            else:
                scale = w[1]
                require(w == [f2_mul(scale, x) for x in C.cfs_sum_weights(n, d)], f"functional {spec['index']}: sum weight form")
        value = _fp2(f["value"])
        if spec["index"] in (6, 7, 8, 9):
            require(value == gammas[{6: 0, 7: 1, 8: 3, 9: 2}[spec["index"]]], f"functional {spec['index']}: gamma value")
        if spec["index"] in (10, 12):
            require(value == _fp2(io[(spec["index"] - 10) // 2]["gamma"]), f"functional {spec['index']}: IO gamma value")
        if spec["index"] in (11, 13):
            require(value == _fp2(io[(spec["index"] - 10) // 2]["mask_eval"]), f"functional {spec['index']}: IO mask_eval value")
        entry["verified"] = True
        report.append(entry)
    require(len(claims) == 2, "two matmul claims")
    return report


def ffn_challenges_from_capture(capture):
    """The six FFN slots' (c, rho) and nu0, nu_z from the verifier's recorded functionals and the round-0 chain."""
    mask, specs, F = capture["mask"], capture["mask"]["specs"], capture["mask"]["functionals"]
    args = {a["name"]: a for a in capture["ffn_arguments"]}
    gu_claim, d_claim = (_fp2(x) for x in capture["ffn_matmul_claims"])
    out = {}
    for name, s in FFN_SLOTS.items():
        n, d = specs[s]
        w = [_fp2(x) for x in F[s]["terms"][0]["weights"]]
        rho = [w[2 + j * d] for j in range(n)]
        require(w == C.cfs_eval_weights(rho, d), f"{name}: eval weights are not eval_weights(rho)")
        out[name] = {"rho": rho, "n": n, "d": d}

    def scale(i, slot):
        for t in F[i]["terms"]:
            if t["slot"] == slot:
                return _fp2(t["weights"][1])
        raise ValueError("missing term")

    out["zc20"]["c"], out["zc17"]["c"], out["zs"]["c"], out["tab"]["c"] = scale(6, 2), scale(7, 3), scale(8, 4), scale(9, 5)
    for zc, mm, fi, claim in (("zc20", "gu", 6, gu_claim), ("zc17", "d", 7, d_claim)):
        r0 = [_fp2(v) for v in args[zc]["rounds"][0]]
        require(claim != ZERO, f"{mm}: zero matmul claim")
        nu = f2_mul(f2_sub(f2_add(r0[0], r0[1]), _fp2(F[fi]["value"])), f2_inv(claim))
        require(nu != ZERO, f"{zc}: zero nu")
        out[zc]["nu"] = nu
        out[mm]["c"] = f2_neg(f2_mul(scale(fi, FFN_SLOTS[mm]), f2_inv(nu)))
    return out


def challenge_file_entries(path):
    doc = json.loads(Path(path).read_bytes())
    entries = {}

    def visit(x):
        if isinstance(x, dict):
            if "ffn_slots" in x:
                for key in ("sha", "proof_sha256", "capture_sha256", "path", "capture", "name"):
                    if key in x:
                        entries[str(x[key])] = x
                        entries[Path(str(x[key])).stem] = x
            for v in x.values():
                visit(v)
        elif isinstance(x, list):
            for v in x:
                visit(v)

    visit(doc)
    return doc, entries


def ffn_challenges_from_file(entries, capture):
    key = capture["proof_sha256"]
    entry = entries.get(key)
    if entry is None:
        raise ValueError(f"challenge file has no entry for capture {key}")
    out = {}
    for s in entry["ffn_slots"]:
        name = SLOT_ALIASES.get(str(s.get("name", "")).lower())
        require(name is not None, f"challenge file: unknown slot name {s.get('name')!r}")
        out[name] = {"c": _fp2(s["c"], "c"), "rho": [_fp2(r, "rho") for r in s["rho"]]}
        if "mask_slot" in s:
            require(int(s["mask_slot"]) == FFN_SLOTS[name], f"challenge file: mask_slot of {name}")
        for k in ("nu", "nu0", "nu_z"):
            if k in s:
                out[name]["nu"] = _fp2(s[k], k)
    require(set(out) == set(FFN_SLOTS), "challenge file: six FFN slots")
    return out


def compare_challenges(derived, other):
    diffs = []
    for name in FFN_SLOTS:
        if other[name]["rho"] != derived[name]["rho"]:
            diffs.append(f"{name}.rho")
        if other[name]["c"] != derived[name]["c"]:
            diffs.append(f"{name}.c")
        if "nu" in other[name] and other[name]["nu"] != derived[name].get("nu"):
            diffs.append(f"{name}.nu")
    return diffs


def stand_in_challenges(specs, rng):
    out = {}
    for name, s in FFN_SLOTS.items():
        n, d = specs[s]
        rho = [rng.fp2() for _ in range(n)]
        while rho[-1] == ZERO:
            rho[-1] = rng.fp2()
        c = rng.fp2()
        while c == ZERO:
            c = rng.fp2()
        out[name] = {"rho": rho, "c": c, "n": n, "d": d}
    for zc in ("zc20", "zc17"):
        nu = rng.fp2()
        while nu == ZERO:
            nu = rng.fp2()
        out[zc]["nu"] = nu
    return out


def captured_ffn_models(capture, ch):
    """The six FFN SlotModels on the captured rounds at the challenges `ch` (derived or from the file)."""
    specs, F = capture["mask"]["specs"], capture["mask"]["functionals"]
    args = {a["name"]: a for a in capture["ffn_arguments"]}
    gu_claim, d_claim = (_fp2(x) for x in capture["ffn_matmul_claims"])
    rounds = lambda name: [[_fp2(v) for v in r] for r in args[name]["rounds"]]
    ev = lambda s: _fp2(F[s]["value"])
    gamma = lambda i: _fp2(F[i]["value"])
    models = {}
    models["gu"] = SlotModel("gu", 0, *specs[0], ch["gu"]["c"], ch["gu"]["rho"], rounds("gu"), gu_claim, ev(0), "matmul")
    models["d"] = SlotModel("d", 1, *specs[1], ch["d"]["c"], ch["d"]["rho"], rounds("d"), d_claim, ev(1), "matmul")
    models["zc20"] = SlotModel("zc20", 2, *specs[2], ch["zc20"]["c"], ch["zc20"]["rho"], rounds("zc20"), gamma(6), ev(2), "batched", nu=ch["zc20"]["nu"], partner=models["gu"])
    models["zc17"] = SlotModel("zc17", 3, *specs[3], ch["zc17"]["c"], ch["zc17"]["rho"], rounds("zc17"), gamma(7), ev(3), "batched", nu=ch["zc17"]["nu"], partner=models["d"])
    models["zs"] = SlotModel("zs", 4, *specs[4], ch["zs"]["c"], ch["zs"]["rho"], rounds("zs"), gamma(8), ev(4), "zero")
    models["tab"] = SlotModel("tab", 5, *specs[5], ch["tab"]["c"], ch["tab"]["rho"], rounds("tab"), gamma(9), ev(5), "zero")
    return models


def stand_in_ffn_models(capture, ch, rng):
    specs = capture["mask"]["specs"]
    models = {}
    models["gu"] = synthetic_slot("gu", 0, *specs[0], ch["gu"]["c"], ch["gu"]["rho"], rng, "matmul")
    models["d"] = synthetic_slot("d", 1, *specs[1], ch["d"]["c"], ch["d"]["rho"], rng, "matmul")
    models["zc20"] = synthetic_slot("zc20", 2, *specs[2], ch["zc20"]["c"], ch["zc20"]["rho"], rng, "batched", nu=ch["zc20"]["nu"], partner=models["gu"])
    models["zc17"] = synthetic_slot("zc17", 3, *specs[3], ch["zc17"]["c"], ch["zc17"]["rho"], rng, "batched", nu=ch["zc17"]["nu"], partner=models["d"])
    models["zs"] = synthetic_slot("zs", 4, *specs[4], ch["zs"]["c"], ch["zs"]["rho"], rng, "zero")
    models["tab"] = synthetic_slot("tab", 5, *specs[5], ch["tab"]["c"], ch["tab"]["rho"], rng, "zero")
    return models


def io_models(capture):
    out = {}
    for arg in capture["io_arguments"]:
        side, slot = arg["side"], arg["slot"]
        require(slot == 6 + side, "IO slot index")
        rounds = [[_fp2(v) for v in r] for r in arg["rounds"]]
        out[f"io{side}"] = SlotModel(f"io{side}", slot, 10, 2, _fp2(arg["c"]), [_fp2(r) for r in arg["rho"]], rounds, _fp2(arg["gamma"]), _fp2(arg["mask_eval"]), "zero")
    return out


def all_systems(models):
    """The six systems as the code batches them, in M order."""
    pairs = [{"a": models["gu"], "b": models["zc20"]}, {"a": models["d"], "b": models["zc17"]}]
    systems = {
        "gu+zc20": JointSystem([models["gu"], models["zc20"]], pairs=pairs[:1]),
        "d+zc17": JointSystem([models["d"], models["zc17"]], pairs=pairs[1:]),
        "zs": JointSystem([models["zs"]]), "tab": JointSystem([models["tab"]]),
        "io0": JointSystem([models["io0"]]), "io1": JointSystem([models["io1"]]),
    }
    return systems, pairs


def expected_numbers(models):
    exp = {}
    for key, names in (("gu+zc20", ["gu", "zc20"]), ("d+zc17", ["d", "zc17"]), ("zs", ["zs"]), ("tab", ["tab"]), ("io0", ["io0"]), ("io1", ["io1"])):
        nd = sum(models[n].n * models[n].d for n in names)
        exp[key] = {"mask_fibre_dim_fp2": len(names), "honest_subspace_dim_fp2": nd - 1, "honest_disclosed_dim_fp2": 0}
    nd = sum(m.n * m.d for m in models.values())
    exp["composed"] = {"mask_fibre_dim_fp2": 8, "honest_subspace_dim_fp2": nd - 6, "honest_disclosed_dim_fp2": 0}
    return exp


def model_functionals(models):
    """The 14 functionals (FUNCTIONAL_ASSIGNMENT order) as (terms, value) built from the slot models themselves:
    terms = [(slot model, weights)], exactly as zk.rs mask_functionals / zk_ffn_fresh_io.rs functionals form them."""
    gu, d, zc20, zc17, zs, tab, io0, io1 = (models[n] for n in SLOT_NAMES)
    scaled = lambda m, s: [f2_mul(s, w) for w in m.sum_weights]
    out = [([(m, m.eval_weights)], m.eval_value) for m in (gu, d, zc20, zc17, zs, tab)]
    out.append(([(zc20, scaled(zc20, zc20.c)), (gu, scaled(gu, f2_neg(f2_mul(zc20.nu, gu.c))))], zc20.claim))
    out.append(([(zc17, scaled(zc17, zc17.c)), (d, scaled(d, f2_neg(f2_mul(zc17.nu, d.c))))], zc17.claim))
    out.append(([(zs, scaled(zs, zs.c))], zs.claim))
    out.append(([(tab, scaled(tab, tab.c))], tab.claim))
    for io in (io0, io1):
        out.append(([(io, scaled(io, io.c))], io.claim))
        out.append(([(io, io.eval_weights)], io.eval_value))
    return out


def v_row_for(system, capture, models):
    """V = sum_i theta^i F_i as a row over the system's mask columns, the functionals formed from the models
    (so that in stand-in mode V combines the stand-in functionals); returns (row, value, weights_match_capture)."""
    theta = _fp2(capture["mask"]["theta"])
    recorded = capture["mask"]["functionals"]
    row, value, th, match = {}, ZERO, ONE, True
    for i, (terms, val) in enumerate(model_functionals(models)):
        rec_terms = recorded[i]["terms"]
        match = match and [t["slot"] for t in rec_terms] == [m.index for m, _ in terms] and \
            all([_fp2(w) for w in t["weights"]] == weights for t, (_, weights) in zip(rec_terms, terms))
        for m, weights in terms:
            off = system.mask_off[m.name]
            for j, w in enumerate(weights):
                row[off + j] = f2_add(row.get(off + j, ZERO), f2_mul(th, w))
        value = f2_add(value, f2_mul(th, val))
        th = f2_mul(th, theta)
    return {k: v for k, v in row.items() if not f2_is_zero(v)}, value, match


def run_message_channel(capture, models, rng, label):
    """(i) per slot / pair and (iii) composed, on the given models."""
    systems, pairs = all_systems(models)
    exp = expected_numbers(models)
    report, failures = {}, []
    for key, system in systems.items():
        res = analyze_system(system)
        res["preimage"] = preimage_check(system, rng)
        res["expected"] = exp[key]
        res["verifier_chain_replayed"] = True
        for m in system.models:
            m.replay_chain()
        res["meets_expectation"] = all(res[k] == v for k, v in exp[key].items()) and res["honest_unconstrained"] and res["preimage"]["same_fibre_dim"] and res["preimage"]["fibre_dims"][0] == res["mask_fibre_dim_fp2"]
        if not res["meets_expectation"]:
            failures.append(f"{label}:{key}")
        report[key] = res
    composed = JointSystem([models[n] for n in SLOT_NAMES], pairs=pairs)
    v_weights, v_value, v_match = v_row_for(composed, capture, models)
    composed = JointSystem([models[n] for n in SLOT_NAMES], pairs=pairs, v_row=(v_weights, v_value))
    res = analyze_system(composed)
    res["preimage"] = preimage_check(composed, rng, samples=1)
    res["expected"] = exp["composed"]
    res["v_row_included"] = True
    res["v_value_model"] = list(v_value)
    res["model_functional_weights_equal_recorded"] = v_match
    if label != "stand-in" and not v_match:
        failures.append(f"{label}: the functional weights formed from the slot models differ from the recorded mask.functionals")
    res["meets_expectation"] = all(res[k] == v for k, v in exp["composed"].items()) and res["honest_unconstrained"] and res["preimage"]["fibre_dims"][0] == 8
    if not res["meets_expectation"]:
        failures.append(f"{label}:composed")
    return {"systems": report, "composed": res, "failures": failures}


# ----------------------------------------------------------------------------
# (ii) the M opening at the captured coefficients: exact block elimination
# ----------------------------------------------------------------------------


def m_opening_analysis(capture, with_controls=True):
    mask = capture["mask"]
    fr = functional_rows(mask)
    lengths = fr["lengths"]
    require(len(mask["q"]) == 1024 and len(mask["prox"]) == 1024 and len(mask["proximity_rhos"]) == 2 * 8 + 2, "M opening geometry")
    require(len(mask["columns"]) == MASK_Q and all(len(c["values"]) == M_ROWS for c in mask["columns"]), "M column geometry")
    q = [_fp2(x) for x in mask["q"]]
    v_captured = C.f2_mul_base(f2_add(q[0], q[512]), 512)
    require(v_captured == fr["v"], "512 (q'_0 + q'_512) != sum theta^i F_i")
    # the verifier's field identities at every opened column (round 20's Python replay of mask_verify without Merkle)
    lengths_ot, _, fs_ot, weights_ot, v_ot = OT.mask_weights(mask)
    require(lengths_ot == lengths and v_ot == fr["v"], "round-20 functional weights agree")
    OT.check_mask_public(mask, weights_ot, v_ot)
    # the theta-combined weight vector of every a-row vanishes on its pad and zero positions
    for s, L in enumerate(lengths):
        require(L + MASK_Q <= 512, "mask row budget")
    # pad blocks: the Lagrange (Cauchy-type) map from the 256 pads of an a-row to its opened values
    indices = sorted(set(c["index"] for c in mask["columns"]))
    pts = C.coset_points(MASK_LOG_MSG)
    lag = {j: C.lagrange_on_subgroup(512, pts[j]) for j in indices}
    pad_blocks, pad_rank_total = {}, 0
    for L in sorted(set(lengths)):
        mb = [[lag[j][i] for i in range(L, L + MASK_Q)] for j in indices]
        db = [[lag[j][i] for i in range(L)] for j in indices]
        r = block_disclosed(mb, db)
        rows_with_L = sum(2 for l in lengths if l == L)
        pad_blocks[str(L)] = dict(r, coefficients=L, pads=MASK_Q, distinct_points=len(indices), a_rows_with_this_length=rows_with_L)
        pad_rank_total += r["mask_rank"] * rows_with_L
    pads_ok = all(b["disclosed_fp"] == 0 and b["mask_rank"] == len(indices) for b in pad_blocks.values())
    # the residual: V restricted to the a-coefficients, in the span of the 14 functionals
    rank_f = C.f2_rank(fr["rows"])
    rank_fv = C.f2_rank(fr["rows"] + [fr["v_row"]])
    disclosed_fp2 = 1 if any(not f2_is_zero(x) for x in fr["v_row"]) else 0
    u_rank, b_rank = 2 * 1024, 2 * (2 * 512 - 1)
    out = {
        "method": "exact block elimination of the Fp linear model of mask_open / mask_verify at the captured coefficients: "
                  "u is eliminated against prox (identity block), b against q' (identity on its 2046 free scalars; the residual 2 Fp rows are "
                  "512 (q'_0 + q'_512) = V whose pad weights vanish), the opened b and u words are then implied by q', prox and the opened a "
                  "words (verified numerically at every opened column), and each a-row's opened words are eliminated against its 256 pads "
                  "(Lagrange/Cauchy block, rank computed at the captured indices).",
        "public_identities_verified": True, "v_equals_512_q0_plus_q512": True,
        "distinct_opened_columns": len(indices), "opened_columns": MASK_Q, "pads_per_a_row": MASK_Q, "a_rows": 16,
        "unknowns_fp": {"a_coefficients": 2 * sum(lengths), "pads": 16 * MASK_Q, "b": b_rank, "u": u_rank, "total": 2 * sum(lengths) + 16 * MASK_Q + b_rank + u_rank},
        "observations_fp": {"q_prime": 2048, "prox": 2048, "columns": MASK_Q * M_ROWS, "total": 2048 + 2048 + MASK_Q * M_ROWS},
        "blocks": {
            "u_via_prox": {"unknowns_fp": u_rank, "rank": u_rank, "opened_u_words_implied": True},
            "b_via_qprime": {"free_scalars_fp": b_rank, "rank": b_rank, "residual_rows_fp": 2, "residual_is_V": True, "opened_b_words_implied": True},
            "pads_via_columns": {"per_coefficient_length": pad_blocks, "rank_total": pad_rank_total, "all_full_row_rank": pads_ok},
        },
        "mask_rank_total_fp": u_rank + b_rank + pad_rank_total,
        "joint_rank_total_fp": u_rank + b_rank + pad_rank_total + 2 * disclosed_fp2,
        "disclosed_a_row_dim_fp": 2 * disclosed_fp2, "disclosed_a_row_dim_fp2": disclosed_fp2,
        "disclosed_functional": "V = sum_i theta^i F_i over the 229 a-coefficients",
        "functionals": 14, "functionals_rank_fp2": rank_f, "rank_with_V_fp2": rank_fv,
        "disclosed_beyond_functionals_fp2": rank_fv - rank_f + (0 if disclosed_fp2 else 0),
        "a_rows_constrained_only_through_functionals": pads_ok and rank_fv == rank_f,
    }
    if with_controls:
        out["controls"] = m_opening_controls(mask, fr, lag, indices)
    return out


def m_opening_controls(mask, fr, lag, indices):
    lengths = fr["lengths"]
    L0 = min(lengths)
    ctl = {}
    # no pads: an a-row's opened words are an unmasked linear image of its coefficients
    db = [[lag[j][i] for i in range(L0)] for j in indices]
    r = block_disclosed([[] for _ in indices], db)
    ctl["nc_no_pads"] = dict(r, coefficients=L0, expect=f"all {L0} coefficients of the row disclosed", ok=r["disclosed_fp"] == L0)
    # more distinct opened points than pads: 255 pads against the captured distinct indices
    npads = len(indices) - 1
    mb = [[lag[j][i] for i in range(L0, L0 + npads)] for j in indices]
    r = block_disclosed(mb, db)
    ctl["nc_columns_exceed_pads"] = dict(r, coefficients=L0, pads=npads, expect="disclosed = distinct points - pads = 1", ok=r["disclosed_fp"] == len(indices) - npads)
    # no blinder b: the 512 G_512-evaluations of q' are unmasked (a lower bound on the disclosure; the pads vanish there)
    theta, F, specs = fr["theta"], mask["functionals"], mask["specs"]
    ws = [[ZERO] * 512 for _ in specs]
    th = ONE
    for f in F:
        for t in f["terms"]:
            for j, w in enumerate(t["weights"]):
                ws[t["slot"]][j] = f2_add(ws[t["slot"]][j], f2_mul(th, _fp2(w)))
        th = f2_mul(th, theta)
    require(all(f2_is_zero(w) for s, L in enumerate(lengths) for w in ws[s][L:]), "combined weights vanish beyond the coefficients")
    rows = []
    for i in range(max(lengths)):
        row = [ZERO] * sum(lengths)
        for s, L in enumerate(lengths):
            if i < L:
                row[fr["offsets"][s] + i] = ws[s][i]
        rows.append(row)
    lb = C.f2_rank(rows)
    ctl["nc_no_blinder_b_lower_bound"] = {"unmasked_position_functionals_fp2": lb, "expect": f"at least {max(lengths)} Fp2 functionals of the a-rows (one per coefficient position) in the clear, versus 1 (V) with b",
                                          "ok": lb >= 1 and lb == max(lengths)}
    # FA6's exact toy models (m = 8, 3 coefficients, 3 pads, 3 columns): with / without blinding, pads, one / two openings
    toy = C.controls_m_opening(C.Rng(6), log_m=3)
    ctl["fa6_toy_exact"] = {k: toy[k] for k in ("pc_qprime_one_opening", "nc_qprime_without_blinding", "pc_columns_q_distinct_under_q_pads", "nc_columns_without_pads", "nc_columns_exceed_pads", "pc_joint_qprime_prox_columns_one_opening", "nc_joint_two_openings_same_M")}
    ctl["fa6_toy_exact"]["ok"] = (toy["pc_qprime_one_opening"]["disclosed_fp_dim"] == 2 and toy["nc_qprime_without_blinding"]["disclosed_fp_dim"] == 6
                                  and toy["pc_columns_q_distinct_under_q_pads"]["disclosed_coefficient_functionals"] == 0
                                  and toy["nc_columns_without_pads"]["disclosed_coefficient_functionals"] == 3
                                  and toy["nc_columns_exceed_pads"]["disclosed_coefficient_functionals"] == 1
                                  and toy["pc_joint_qprime_prox_columns_one_opening"]["disclosed_fp_dim"] == 2
                                  and toy["nc_joint_two_openings_same_M"]["disclosed_fp_dim"] == 6)
    ctl["all_ok"] = all(v["ok"] for v in ctl.values() if isinstance(v, dict) and "ok" in v)
    return ctl


# ----------------------------------------------------------------------------
# message-channel controls (refusals, degenerate challenges, corrupted rounds)
# ----------------------------------------------------------------------------


def message_channel_controls(models, rng, n=4, d=3):
    ctl = {}
    rho = [rng.fp2() for _ in range(n)]
    c = rng.fp2()
    # c = 0: refused; forced, the honest rounds are the view (fully disclosed)
    try:
        synthetic_slot("ctl", 0, n, d, ZERO, rho, rng, "zero")
        ctl["nc_zero_mask_challenge"] = {"refused": False}
    except ValueError as err:
        m = synthetic_slot("ctl", 0, n, d, ZERO, rho, rng, "zero", allow_degenerate=True)
        res = analyze_system(JointSystem([m]))
        ctl["nc_zero_mask_challenge"] = {"refused": True, "reason": str(err), "forced": res,
                                         "expect": "refused (zk.rs div / draw_mask_challenge); forced: honest disclosed = honest dim",
                                         "ok": res["honest_disclosed_dim_fp2"] == res["honest_subspace_dim_fp2"] and res["honest_subspace_dim_fp2"] > 0}
    # rho[-1] = 0: refused; forced, the CFS fibre itself is unchanged (the refusal protects the terminal masking, FA6/FA8)
    rho0 = rho[:-1] + [ZERO]
    try:
        synthetic_slot("ctl", 0, n, d, c, rho0, rng, "zero")
        ctl["nc_zero_terminal_challenge"] = {"refused": False}
    except ValueError as err:
        m = synthetic_slot("ctl", 0, n, d, c, rho0, rng, "zero", allow_degenerate=True)
        res = analyze_system(JointSystem([m]))
        ctl["nc_zero_terminal_challenge"] = {"refused": True, "reason": str(err), "forced": res,
                                             "expect": "refused (zk_ffn_fresh_io.rs: zero terminal mask challenge); forced: fibre 1, honest disclosed 0 (FA6: surjective at every challenge sequence)",
                                             "ok": res["mask_fibre_dim_fp2"] == 1 and res["honest_disclosed_dim_fp2"] == 0}
    for label, chal in (("all_zero", [ZERO] * n), ("all_one", [ONE] * n), ("all_half", [(C.HALF, 0)] * n)):
        m = synthetic_slot("ctl", 0, n, d, c, chal, rng, "zero", allow_degenerate=True)
        res = analyze_system(JointSystem([m]))
        res["preimage"] = preimage_check(JointSystem([m]), rng, samples=1)
        ctl[f"pc_degenerate_rho_{label}"] = dict(res, ok=res["mask_fibre_dim_fp2"] == 1 and res["honest_disclosed_dim_fp2"] == 0 and res["preimage"]["preimages_verified"])
    # corrupted round messages on the REAL slots: the verifier's chain fails and the view leaves S(claim, final)
    corrupt = {}
    for name in ("io0", "gu", "tab"):
        m = models[name]
        for j, x in ((0, 0), (min(3, m.n - 2), m.d)):
            bad = copy.copy(m)
            bad.rounds = [list(r) for r in m.rounds]
            bad.rounds[j][x] = f2_add(bad.rounds[j][x], ONE)
            try:
                bad.replay_chain()
                corrupt[f"{name}.h{j}({x})"] = {"rejected": False}
            except ValueError as err:
                system = JointSystem([bad] if bad.kind != "matmul" else [bad, _rebatch(models, bad)], pairs=([] if bad.kind != "matmul" else [{"a": bad, "b": _rebatch(models, bad)}]))
                res = analyze_system(system)
                corrupt[f"{name}.h{j}({x})"] = {"rejected": True, "reason": str(err), "model_consistent": res["observations_consistent"], "ok": not res["observations_consistent"]}
    ctl["nc_corrupted_round_messages"] = dict(corrupt, ok=all(v.get("ok") for v in corrupt.values()))
    ctl["all_ok"] = all(v["ok"] for v in ctl.values() if isinstance(v, dict) and "ok" in v)
    return ctl


def _rebatch(models, bad_matmul):
    """The zero-check partner of a (corrupted) matmul model, re-pointed at it."""
    zc = models["zc20"] if bad_matmul.name == "gu" else models["zc17"]
    partner = copy.copy(zc)
    partner.partner = bad_matmul
    return partner


# ----------------------------------------------------------------------------
# driver
# ----------------------------------------------------------------------------


def sha256_file(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def bind_manifest(directory, manifest_path, allow_source_drift):
    manifest_bytes = Path(manifest_path).read_bytes()
    manifest = json.loads(manifest_bytes)
    require(manifest["source_commit"] == SOURCE_COMMIT, "manifest source commit")
    preflight = PRE.run(Path(directory), SOURCE_COMMIT)
    recorded = {c["proof_sha256"]: c for c in manifest["captures"]["cases"]}
    for item in preflight["cases"]:
        rec = recorded[item["proof_sha256"]]
        for key in ("capture_sha256", "capture_bytes", "proof_sha256", "proof_bytes", "expected_policy_sha256"):
            require(item[key] == rec[key], "round-22 manifest mismatch: " + key)
    sources = {}
    for rel, digest in manifest["source_sha256"].items():
        p = ROOT / rel
        got = sha256_file(p) if p.exists() else "missing"
        sources[rel] = {"manifest": digest, "worktree": got, "match": got == digest}
        if rel in MODELLED_SOURCES and got != digest and not allow_source_drift:
            raise ValueError(f"modelled source drifted from the manifest pin: {rel} (pass --allow-source-drift to proceed)")
    return manifest, preflight, sources, PRE.digest(manifest_bytes)


def analyze_capture(capture, challenge_entries, seed):
    t0 = time.time()
    rng = C.Rng(seed)
    out = {"proof_sha256": capture["proof_sha256"], "privacy": capture["privacy"], "profile": capture["profile"],
           "specs": capture["mask"]["specs"], "slot_names": SLOT_NAMES}
    require(capture["profile"] == PROFILE and capture["kind"] == "zk60-verifier-observations", "capture profile")
    out["functional_assignment"] = verify_functional_assignment(capture)
    derived = ffn_challenges_from_capture(capture)
    ios = io_models(capture)
    # the captured FFN rounds satisfy the verifier's chain at the derived challenges (78 equations + 6 terminal identities)
    derived_models = captured_ffn_models(capture, derived)
    for m in derived_models.values():
        m.replay_chain()
    out["ffn_challenges_derived_from_capture"] = {
        "source": "verifier mask functionals (eval weights -> rho_s; Gamma weights -> c_zc20, c_zc17, c_zs, c_tab; -nu c_gu / -nu_z c_d sum weights) and the zero-check round-0 chain (-> nu0, nu_z)",
        "captured_ffn_rounds_verify_chain": True,
        "chain_equations": sum(m.n for m in derived_models.values()), "terminal_identities": 6,
        "sha256_16": {name: hashlib.sha256(json.dumps({"c": derived[name]["c"], "rho": derived[name]["rho"]}).encode()).hexdigest()[:16] for name in FFN_SLOTS},
    }
    failures = []
    if challenge_entries is not None:
        filed = ffn_challenges_from_file(challenge_entries, capture)
        diffs = compare_challenges(derived, filed)
        out["ffn_challenges"] = "captured"
        out["challenge_file_agrees_with_derived"] = not diffs
        if diffs:
            failures.append("challenge file disagrees with the capture-derived challenges: " + ", ".join(diffs))
        for name in FFN_SLOTS:
            filed[name].setdefault("nu", derived[name].get("nu"))
        models = dict(captured_ffn_models(capture, filed), **ios)
        main = run_message_channel(capture, models, rng, "captured")
        out["ffn_observations"] = "captured rounds, claims, gammas and derived g(rho) values"
    else:
        out["ffn_challenges"] = "stand-in"
        out["challenge_file_agrees_with_derived"] = None
        models = dict(stand_in_ffn_models(capture, stand_in_challenges(capture["mask"]["specs"], rng), rng), **ios)
        main = run_message_channel(capture, models, rng, "stand-in")
        out["ffn_observations"] = "synthetic masked rounds at seeded stand-in (c, rho) for the six FFN slots; captured for the two IO slots"
        dm = dict(derived_models, **ios)
        out["derived_analysis"] = dict(run_message_channel(capture, dm, rng, "derived"),
                                       ffn_challenges="derived-from-capture", ffn_observations="captured rounds, claims, gammas and derived g(rho) values")
        failures += out["derived_analysis"].pop("failures")
    out["systems"], out["composed"] = main["systems"], main["composed"]
    failures += main["failures"]
    if out["ffn_challenges"] == "captured":
        vc = C.f2_mul_base(f2_add(_fp2(capture["mask"]["q"][0]), _fp2(capture["mask"]["q"][512])), 512)
        out["composed"]["v_value_equals_captured_512_q0_plus_q512"] = (tuple(out["composed"]["v_value_model"]) == vc)
        if not out["composed"]["v_value_equals_captured_512_q0_plus_q512"]:
            failures.append("V model value != captured")
    # (ii) the M opening
    out["m_opening"] = m_opening_analysis(capture)
    if not (out["m_opening"]["a_rows_constrained_only_through_functionals"] and out["m_opening"]["disclosed_a_row_dim_fp2"] == 1 and out["m_opening"]["controls"]["all_ok"]):
        failures.append("M opening")
    # the round-21 IO cross-check, unchanged
    io_cross = []
    for arg in capture["io_arguments"]:
        res = IOC.check_slot(arg, capture["mask"])
        ctl = IOC.controls(arg, capture["mask"])
        res["round21_controls_rejected"] = len(ctl)
        io_cross.append(res)
        if not (res["surjective"] and res["round_fibre_dim_fp2"] == 19 and len(ctl) == 9):
            failures.append(f"round-21 IO cross-check side {arg['side']}")
    out["io_crosscheck_round21"] = io_cross
    # controls on the message channel
    out["controls"] = message_channel_controls(models if out["ffn_challenges"] == "captured" else dict(derived_models, **ios), rng)
    if not out["controls"]["all_ok"]:
        failures.append("message-channel controls")
    out["failures"] = failures
    out["status"] = "passed" if not failures else "FAILED"
    out["seconds"] = round(time.time() - t0, 1)
    return out


def summary_line(cap):
    s = cap["systems"]
    comp = cap["composed"]
    parts = ", ".join(f"{k}: fibre {v['mask_fibre_dim_fp2']} honest {v['honest_subspace_dim_fp2']} disclosed {v['honest_disclosed_dim_fp2']}" for k, v in s.items())
    return (f"[{cap['proof_sha256'][:8]} {cap['privacy']}] ffn_challenges={cap['ffn_challenges']} {cap['status']} ({cap['seconds']}s)\n"
            f"    slots: {parts}\n"
            f"    composed: mask unknowns {comp['n_mask_unknowns_fp2']}, mask rank {comp['mask_rank_fp2']}, fibre {comp['mask_fibre_dim_fp2']}, honest dim {comp['honest_subspace_dim_fp2']}, "
            f"disclosed {comp['honest_disclosed_dim_fp2']}, consistent {comp['observations_consistent']}\n"
            f"    M opening: distinct columns {cap['m_opening']['distinct_opened_columns']}, mask rank {cap['m_opening']['mask_rank_total_fp']} Fp, disclosed a-row {cap['m_opening']['disclosed_a_row_dim_fp2']} Fp2 (V), "
            f"beyond functionals {cap['m_opening']['disclosed_beyond_functionals_fp2']}; controls ok {cap['m_opening']['controls']['all_ok']}; message controls ok {cap['controls']['all_ok']}")


def run(directory, manifest_path, challenges_path, seed, allow_source_drift):
    manifest, preflight, sources, manifest_sha = bind_manifest(directory, manifest_path, allow_source_drift)
    entries = None
    challenge_sha = None
    if challenges_path is not None:
        _, entries = challenge_file_entries(challenges_path)
        challenge_sha = sha256_file(challenges_path)
    captures = []
    for item in preflight["cases"]:
        capture = json.loads(Path(item["path"]).read_bytes())
        require(PRE.digest(Path(item["path"]).read_bytes()) == item["capture_sha256"], "capture digest")
        cap = analyze_capture(capture, entries, seed)
        cap["path"], cap["capture_sha256"] = item["path"], item["capture_sha256"]
        print(summary_line(cap), flush=True)
        captures.append(cap)
    failures = [f for c in captures for f in c["failures"]]
    tools = [Path(__file__), Path(C.__file__), Path(R.__file__), Path(OT.__file__), Path(IOC.__file__), Path(PRE.__file__)]
    return {
        "schema": 1, "tool": "zk60_joint_cfs_view.py", "reviewer": REVIEWER, "source_commit": SOURCE_COMMIT, "profile": PROFILE,
        "manifest_sha256": manifest_sha, "source_sha256": sources, "challenges_file": str(challenges_path) if challenges_path else None,
        "challenges_file_sha256": challenge_sha, "ffn_challenges": "captured" if challenges_path else "stand-in", "seed": seed,
        "scope": "the eight CFS slots and the M opening jointly at the captured coefficients: per-slot fibres, the M opening's disclosure, the composed rank; "
                 "fixed challenges (no adaptive transcript simulation), the masked terminals conditioned on (PCS side)",
        "full_privacy_review_complete": False, "adaptive_transcript_simulation_performed": False,
        "functional_assignment": FUNCTIONAL_ASSIGNMENT,
        "captures": captures, "status": "passed" if not failures else "FAILED", "failures": failures,
        "tools": {str(p.resolve().relative_to(ROOT)) if str(p.resolve()).startswith(str(ROOT)) else str(p): sha256_file(p) for p in tools},
    }


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--captures", type=Path, required=True)
    ap.add_argument("--manifest", type=Path, default=None)
    ap.add_argument("--challenges", type=Path, default=None)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--seed", type=int, default=2026)
    ap.add_argument("--allow-source-drift", action="store_true")
    args = ap.parse_args(argv)
    manifest = args.manifest or args.captures.parent / "zk60_round22_captures.json"
    result = run(args.captures, manifest, args.challenges, args.seed, args.allow_source_drift)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=1) + "\n")
    print(f"{result['status']}: {len(result['captures'])} captures, ffn_challenges={result['ffn_challenges']}; wrote {args.out}")
    if result["failures"]:
        for f in result["failures"]:
            print("  FAIL:", f)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

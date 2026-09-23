"""Tests for round 9l: ruling GC-2 of
`ZK60_GS4_GS5_GS11_GS12_CLOSURES_DISPOSITION.md` §3, on findings F-3, F-4
and F-6 of `ZK60_GS4_GS5_GS11_GS12_CLOSURES_CHECK.md`.

Run:
  python3 -m unittest discover -s tests -p "test_zk60_native_run_gate_gc2.py"

FOUR ARMS.

* The U-TERM arm (F-3): on constructed commitments of the check's `U-adm`
  family (the pairless sum claim's zero-sum weights `(1, a)`, `a` in Fp, so
  neither zero-sum indicator is reachable on its own and only
  `e_u0 + a*e_u1` is) a brute force of the WHOLE linear view -- every
  published claim value, both halves of every group vector and of the
  proximity vector, every opened column on every row, the zero-sum rows on
  their hyperplane -- reads `n*k0 + u*` with the EXACT
  `u* = rank Γ_{D∪N'} − rank Γ_{N'} − k0`, through the gate's own
  `RunRoleView._disclosed` and `RunJointSystem.disclosed`; the per-indicator
  term the gate used until this round reads exactly one less.  The honest
  twin (`(1, U)`) reads the same by both terms.
* The EXCLUSIVITY arm (F-4): on a synthetic opening, the overlapping pairs
  (4, 5) and (5, 6) that the OLD weight-level check accepted are refused by
  the new audit by name, and the honest schedule passes every clause.
* The LIVE arm (F-4, F-6), skipped when the lane's bundles are absent:
  stage 3 on the rung-G standalone block and on a three-block run -- every
  commitment passes all sixteen clauses, every per-clause control fires,
  every clause is exercised, and the F-4 control X10a is one the old check
  accepted.
* The RECORDED arm: the thirty records re-taken this round carry the same
  facts, and every u-term they hold is exact and equal to the per-indicator
  one (the prediction P-1 of the ledger's R9l.2).

Nothing here asserts a privacy property.
"""

from __future__ import annotations

import json
import os
import random
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))

import zk60_native_rg_exclusivity as ex  # noqa: E402
import zk60_native_rg_pcs as pcs  # noqa: E402
import zk60_native_run_gate as gate  # noqa: E402
from zk60_native_jv_field import P, f2_mul, f2_sub, rank  # noqa: E402
from zk60_native_jv_joint import Block  # noqa: E402
from zk60_native_jv_pcs import RoleView  # noqa: E402
from zk60_native_rg_joint import RunJointSystem  # noqa: E402

LANE = os.environ.get("ZK60_BLOCK125M_LANE", "/home/victor/wt-zk60-block125m")
RUNG_G_DENSE = os.path.join(LANE, "results", "zk60_block_captures_20260923", "rung-g",
                            "rung-g-dense")
RUN_A = os.path.join(LANE, "results", "zk60_run_captures_20260920", "run-a-tame")
RECORDS_TXT = os.path.join(ROOT, "results", "zk60_native_run_gate_9k", "records.txt")
EVIDENCE_9L = os.path.join(ROOT, "results", "zk60_native_run_gate_9l")

ONE, U, ZERO = (1, 0), (0, 1), (0, 0)


# =====================================================================
#  the U-TERM arm
# =====================================================================
def _rf2(rng):
    return (rng.randrange(P), rng.randrange(P))


def _commitment(rng, n, Q, d, sum_u):
    """An `H`-like commitment: 4 data rows, the zero-sum rows (4, 5), an
    evaluation claim on pair (6, 7), SC_ZS on pair (8, 9) with `(cd, cd*U)`
    on the zero-sum rows, the pairless UNPUBLISHED sum claim with +-1/+-U on
    the data rows and `sum_u` on the zero-sum rows, the proximity pair
    (10, 11).  Singleton groups, random nonzero lambdas, a random proximity
    combination, `d` generic opened columns."""
    rows, D, UR = 12, [0, 1, 2, 3], [4, 5]
    claims = []
    rw = [ZERO] * rows
    cd, x = _rf2(rng), _rf2(rng)
    rw[0], rw[1] = f2_mul(cd, f2_sub(ONE, x)), f2_mul(cd, x)
    cm = _rf2(rng)
    rw[6], rw[7] = cm, f2_mul(cm, U)
    claims.append((rw, [_rf2(rng) for _ in range(n)], True))
    rw = [ZERO] * rows
    cd, cm = _rf2(rng), _rf2(rng)
    rw[4], rw[5] = cd, f2_mul(cd, U)
    rw[8], rw[9] = cm, f2_mul(cm, U)
    claims.append((rw, [_rf2(rng) for _ in range(n)], True))
    rw = [ZERO] * rows
    for k in (0, 2):
        s = ONE if rng.random() < 0.5 else (P - 1, 0)
        rw[k], rw[k + 1] = s, f2_mul(s, U)
    rw[4], rw[5] = sum_u
    claims.append((rw, [ONE] * n, False))
    lams = [_rf2(rng) for _ in claims]
    rhos = [[f2_mul(lam, v) for v in c[0]] for lam, c in zip(lams, claims)]
    prho = [_rf2(rng) for _ in range(rows)]
    cols = [[rng.randrange(P) for _ in range(n + Q)] for _ in range(d)]
    return {"n": n, "Q": Q, "rows": rows, "D": D, "U": UR, "claims": claims,
            "rhos": rhos, "prho": prho, "E": cols}


def _brute(m):
    """rank(L) - rank(L_R) of the whole view, written from the model alone."""
    n, Q, rows, D, UR = m["n"], m["Q"], m["rows"], m["D"], m["U"]
    Np = [i for i in range(rows) if i not in D and i not in UR]
    col = {}
    for i in D:
        for t in range(n):
            col[("m", i, t)] = len(col)
    first_rand = len(col)
    for i in Np:
        for t in range(n):
            col[("m", i, t)] = len(col)
    for i in UR:  # the zero-sum rows: n - 1 free words, the last minus their sum
        for t in range(n - 1):
            col[("u", i, t)] = len(col)
    for i in range(rows):
        for k in range(Q):
            col[("p", i, k)] = len(col)
    L = []

    def emit(coefs):
        row = [0] * len(col)
        for (kind, i, t), c in coefs.items():
            if kind == "m" and i in UR:
                if t < n - 1:
                    j = col[("u", i, t)]
                    row[j] = (row[j] + c) % P
                else:
                    for t2 in range(n - 1):
                        j = col[("u", i, t2)]
                        row[j] = (row[j] - c) % P
            else:
                j = col[(kind, i, t)]
                row[j] = (row[j] + c) % P
        L.append(row)

    def emit2(coefs):
        emit({k: v[0] for k, v in coefs.items()})
        emit({k: v[1] for k, v in coefs.items()})

    for rw, cw, published in m["claims"]:
        if published:
            emit2({("m", i, t): f2_mul(rw[i], cw[t])
                   for i in range(rows) for t in range(n) if rw[i] != ZERO})
    for rho in m["rhos"] + [m["prho"]]:
        for t in range(n):
            emit2({("m", i, t): rho[i] for i in range(rows)})
        for k in range(Q):
            emit2({("p", i, k): rho[i] for i in range(rows)})
    for e in m["E"]:
        for i in range(rows):
            c = {("m", i, t): e[t] for t in range(n)}
            c.update({("p", i, k): e[n + k] for k in range(Q)})
            emit(c)
    return rank(L, len(col)) - rank([r[first_rand:] for r in L], len(col) - first_rand)


class _Sp:
    def __init__(self, n):
        self.n_cols = n


def _gate(m):
    """The gate's own two code paths on the constructed commitment."""
    rows, D, UR = m["rows"], m["D"], m["U"]
    v = pcs.RunRoleView.__new__(pcs.RunRoleView)
    v.rows, v.rhos, v.prox_rho = rows, m["rhos"], m["prho"]
    v.rws, v.facts, v.sp = [c[0] for c in m["claims"]], {}, _Sp(m["n"])
    per = v._disclosed(D, [i for i in range(rows) if i not in D], UR)
    js = RunJointSystem([Block("H", rows, D, UR, m["rhos"] + [m["prho"]])]).disclosed(
        msg_width=m["n"])
    return per, v.facts, js


GRID = [(4, 4, 3), (4, 6, 5), (8, 4, 4), (2, 3, 2)]


class TheExactUTermOnConstructedCases(unittest.TestCase):
    def test_u_adm_the_old_term_under_counts_and_the_exact_one_is_the_brute_force(self):
        seen = 0
        for (n, Q, d) in GRID:
            for seed in range(3):
                with self.subTest(n=n, Q=Q, d=d, seed=seed):
                    m = _commitment(random.Random(9001 + 97 * n + 13 * Q + seed), n, Q, d,
                                    (ONE, (5, 0)))
                    b = _brute(m)
                    per, facts, js = _gate(m)
                    ut = facts["u_row_term"]
                    k0 = facts["k0"]
                    # exact, through both code paths
                    self.assertEqual(per, b)
                    self.assertEqual(js["disclosed_fp"], b)
                    self.assertEqual(b, n * k0 + ut["extra_dimension_beyond_k0"])
                    # the per-indicator term reads exactly one short
                    self.assertEqual(ut["u_row_indicators_admissible"], 0)
                    self.assertEqual(ut["per_indicator_term"],
                                     ut["extra_dimension_beyond_k0"] - 1)
                    self.assertFalse(ut["per_indicator_equals_exact"])
                    self.assertEqual(js["u_row_detail"]["per_indicator_term_fp"],
                                     js["u_row_term_fp"] - 1)
                    self.assertFalse(js["u_row_detail"]["per_indicator_equals_exact"])
                    seen += 1
        self.assertEqual(seen, 12)

    def test_the_honest_twin_reads_the_same_by_both_terms(self):
        for (n, Q, d) in GRID:
            for seed in range(3):
                with self.subTest(n=n, Q=Q, d=d, seed=seed):
                    m = _commitment(random.Random(4242 + 97 * n + 13 * Q + seed), n, Q, d,
                                    (ONE, U))
                    b = _brute(m)
                    per, facts, js = _gate(m)
                    ut = facts["u_row_term"]
                    self.assertEqual(facts["k0"], 0)
                    self.assertEqual(per, b)
                    self.assertEqual(js["disclosed_fp"], b)
                    self.assertEqual(b, 2)
                    self.assertEqual(ut["u_row_indicators_admissible"], 2)
                    self.assertTrue(ut["per_indicator_equals_exact"])
                    self.assertTrue(js["u_row_detail"]["per_indicator_equals_exact"])

    def test_exact_u_term_is_the_two_ranks_minus_k0(self):
        # a system with no zero-sum row: u* is identically 0
        rng = random.Random(7)
        gens = [[rng.randrange(P) for _ in range(9)] for _ in range(4)]
        D, N = [0, 1, 2, 3], [4, 5, 6, 7, 8]
        k0 = rank(gens, 9) - rank([[g[i] for i in N] for g in gens], len(N))
        u, r_dn, r_n = pcs.exact_u_term(gens, D, N, k0)
        self.assertEqual(u, 0)
        self.assertEqual((r_dn, r_n), (rank(gens, 9), rank([[g[i] for i in N] for g in gens])))


# =====================================================================
#  the EXCLUSIVITY arm (synthetic)
# =====================================================================
def _part(row, coef, point, n=4):
    return {"offset": row * n, "log_size": 2, "point": point, "coefficient": list(coef)}


def _opening(pairs):
    """10 rows: data 0..3, sites 4..7, proximity 8, 9; row width 4.  Claim c
    evaluates data row c and carries the pair `pairs[c]` with (1, U)."""
    pts = [[[3 + c, 1], [5 + c, 2]] for c in range(len(pairs))]
    claims, rws = [], []
    for c, (s0, s1) in enumerate(pairs):
        claims.append({"parts": [_part(c, (7, 1), pts[c]), _part(s0, ONE, pts[c]),
                                 _part(s1, U, pts[c])]})
        rw = [ZERO] * 10
        rw[c], rw[s0], rw[s1] = (7, 1), ONE, U
        rws.append(rw)
    geom = ex.Geometry(name="S", kind="block", rows=10, data=range(4), sites=[4, 5, 6, 7],
                       u=[], prox=[8, 9], spare=[], sum_rows=None,
                       want_groups=len(pairs), log_n=2, reserved=[4, 5, 6, 7])
    return geom, claims, rws


class _Host:
    def __init__(self, rws):
        self.name, self.rws, self.findings, self.facts = "S", rws, [], {}

    def fail(self, what):
        self.findings.append(what)


class TheExclusivityAuditOnASyntheticOpening(unittest.TestCase):
    def test_the_honest_schedule_passes_every_clause(self):
        geom, claims, rws = _opening([(4, 5), (6, 7)])
        res = ex.audit(geom, claims, rws, [[ONE], [ONE]])
        self.assertTrue(res["ok"], res["findings"])
        self.assertEqual(len(res["clauses"]), 16)
        self.assertEqual(res["site_rows_used_exactly_once"], 4)

    def test_overlapping_pairs_the_old_check_accepted_are_refused(self):
        geom, claims, rws = _opening([(4, 5), (5, 6)])
        host = _Host(rws)
        old = RoleView._check_pair_schedule(host, list(range(4)), list(range(4, 10)),
                                            [8, 9], [])
        self.assertTrue(old, "finding F-4: the inherited check accepted the overlap")
        res = ex.audit(geom, claims, rws, [[ONE], [ONE]])
        self.assertFalse(res["ok"])
        self.assertIn("EX-10", res["failing"])  # row 5 carries two claims
        self.assertIn("EX-11", res["failing"])  # row 7 carries none
        self.assertIn("EX-6", res["failing"])   # (5, 6) starts at an odd offset

    def test_an_unused_pair_without_sharing_is_refused(self):
        geom, claims, rws = _opening([(4, 5)])
        geom.want_groups = 1
        res = ex.audit(geom, claims, rws, [[ONE]])
        self.assertEqual(res["failing"], ["EX-11"])

    def test_every_clause_has_a_source_and_a_name(self):
        self.assertEqual(ex.CLAUSE_IDS, [f"EX-{i}" for i in range(1, 17)])
        for cid, name, source, what in ex.CLAUSES:
            self.assertTrue(name and source and what, cid)


# =====================================================================
#  the LIVE arm
# =====================================================================
def _stage3(bundle_dir):
    from zk60_native_rg_block import BlockReplay, load_bundle
    from zk60_native_rg_replay import RunReplay
    b = load_bundle(bundle_dir)
    rp = (BlockReplay(b) if getattr(b, "standalone", False) else RunReplay(b)).run()
    s3, views = gate.stage3(b, rp, pad_rank=False)
    return b, s3, views


class _Live:
    BUNDLE = None
    CONTROLS = None

    @classmethod
    def setUpClass(cls):
        if not os.path.isdir(cls.BUNDLE):
            raise unittest.SkipTest(f"{cls.BUNDLE} is absent")
        cls.b, cls.s3, cls.views = _stage3(cls.BUNDLE)

    def test_every_commitment_passes_every_clause(self):
        for r in self.s3["per_commitment"]:
            with self.subTest(r["role"]):
                self.assertEqual(r["findings"], [])
                self.assertTrue(r["reduction_hypotheses"]["H-pair"])
                e = r["exclusivity"]
                self.assertEqual((e["clauses_checked"], e["clauses_passed"]), (16, 16))
                self.assertEqual(e["site_rows_used_exactly_once"], e["site_rows"])
                self.assertEqual(e["groups"], e["groups_the_schedule_declares"])
                if "u_row_term" in r:
                    self.assertTrue(r["u_row_term"]["per_indicator_equals_exact"])
                    self.assertEqual(r["u_row_term"]["extra_dimension_beyond_k0"], 2)
        self.assertTrue(self.s3["ok"])

    def test_every_control_fires_and_every_clause_is_exercised(self):
        xc = self.s3["exclusivity_controls"]
        self.assertEqual(len(xc["controls"]), self.CONTROLS)
        for k, c in xc["controls"].items():
            with self.subTest(k):
                self.assertTrue(c["fires"])
                self.assertTrue(c["honest"]["every_clause_holds"])
                self.assertIn(c["target_clause"], c["perturbed"]["clauses_that_fail"])
        self.assertEqual(xc["clauses_exercised"], ex.CLAUSE_IDS)
        self.assertTrue(xc["ok"])

    def test_the_F4_control_is_one_the_old_check_accepted(self):
        xc = self.s3["exclusivity_controls"]
        c = xc["controls"]["X10a_A_overlapping_pairs"]
        old = c["the_old_weight_level_check_on_the_same_weights"]
        self.assertTrue(old["applicable"])
        self.assertTrue(old["h_pair"])
        self.assertIn("EX-10", c["perturbed"]["clauses_that_fail"])
        self.assertIn("X10a_A_overlapping_pairs", xc["the_old_check_accepted"])


class LiveOnTheRungGBlock(_Live, unittest.TestCase):
    BUNDLE = RUNG_G_DENSE
    CONTROLS = 23


class LiveOnAThreeBlockRun(_Live, unittest.TestCase):
    BUNDLE = RUN_A
    CONTROLS = 24


# =====================================================================
#  the RECORDED arm
# =====================================================================
def _walk_u(x, out):
    if isinstance(x, dict):
        if "u_row_indicators_admissible" in x or x.get("u_classes"):
            out.append(x)
        for v in x.values():
            _walk_u(v, out)
    elif isinstance(x, list):
        for v in x:
            _walk_u(v, out)


class TheRecordsReTakenThisRound(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with open(RECORDS_TXT) as fh:
            names = [x.strip() for x in fh if x.strip()]
        cls.recs = {}
        for n in names:
            p = os.path.join(ROOT, "results", n + ".json")
            if os.path.exists(p):
                with open(p) as fh:
                    cls.recs[n] = json.load(fh)
        if not cls.recs:
            raise unittest.SkipTest("no record of round 9k's list is in the tree")

    def test_thirty_records(self):
        self.assertEqual(len(self.recs), 30)

    def test_every_commitment_carries_sixteen_passing_clauses(self):
        for n, r in self.recs.items():
            for c in r["stage3_per_commitment"]["per_commitment"]:
                with self.subTest(record=n, commitment=c["role"]):
                    self.assertEqual(c["exclusivity"]["clauses_passed"], 16)
                    self.assertTrue(c["reduction_hypotheses"]["H-pair"])

    def test_every_record_carries_every_control_firing(self):
        for n, r in self.recs.items():
            with self.subTest(n):
                xc = r["stage3_per_commitment"]["exclusivity_controls"]
                block = bool(r["stage1_integrity"].get("standalone_block"))
                self.assertEqual(len(xc["controls"]), 23 if block else 24)
                self.assertTrue(xc["all_fire"])
                self.assertTrue(xc["every_clause_exercised"])
                self.assertIn("X10a_A_overlapping_pairs", xc["the_old_check_accepted"])

    def test_every_u_term_is_exact_and_equals_the_per_indicator_one(self):
        count = 0
        for n, r in self.recs.items():
            out = []
            _walk_u(r, out)
            for x in out:
                with self.subTest(record=n):
                    self.assertTrue(x["per_indicator_equals_exact"])
                    count += 1
        self.assertGreater(count, 0)

    def test_the_records_came_from_the_tool_bytes_now_in_the_tree(self):
        now = gate.tool_hashes()
        self.assertIn("zk60_native_rg_exclusivity.py", now)
        for n, r in self.recs.items():
            self.assertEqual(r["tool_sha256"], now, n)


if __name__ == "__main__":
    unittest.main()

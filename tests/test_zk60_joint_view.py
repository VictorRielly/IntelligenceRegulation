#!/usr/bin/env python3
"""Tests for scripts/zk60_joint_view.py: the joint PCS-side field view WITH the opened columns.

  1. SmallGeometry  -- the reduced engine against a brute-force rank of the full uncompressed
     observation matrix (n = 8, Q = 4, domain 64, |J_d| in {3, 4}, an alias, a zero-sum extra),
     including the ablation and deficient-pad variants; the explicit E_J against the certificate
     and the kernel basis; refusals (alias on a non-identity range, too many distinct positions).
  2. RealCapture    -- one round-22 P1 capture: with-columns == without-columns == O8 live ==
     archived O8 record; the endpoint mask-pair ablation discloses (256); a pad budget below
     |J_d| discloses and one at 255 >= |J_d| does not; M discloses exactly its public functionals.
     The capture directory is the retained round-22 evidence; its absence FAILS (not skips).

    python3 -m unittest discover -s tests -p 'test_zk60_joint_view.py' -v
"""
import importlib.util
import json
import os
import random
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
_SPEC = importlib.util.spec_from_file_location("zk60_joint_view", ROOT / "scripts/zk60_joint_view.py")
V = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(V)
P, ONE, ZERO, U, R = V.P, V.ONE, V.ZERO, V.U, V.R

CAPTURES = "/home/victor/IntelligenceRegulation/results/zk60_round22_captures"
MANIFEST = "/home/victor/IntelligenceRegulation/results/zk60_round22_captures.json"
P1_CAPTURE = "c97457756c36cc9aace742ba36377230539ef54d66a5fb4ef59d0102db61ef7e.json"


def canonical(roles):
    return [V.plan_canonical(r, V.ColumnAlgebra(r.n, r.q_pad, r.domain, r.indices)) for r in roles]


class SmallGeometry(unittest.TestCase):
    ALIASES = [(("A", 2), ("E", 0))]

    def both(self, roles, plans, aliases):
        for r in roles:
            V.check_role_public(r)
        bw, bo = V.brute_force(roles, aliases, True), V.brute_force(roles, aliases, False)
        ew = V._model(roles, plans, aliases)
        eo = V._model(roles, [V.plan_no_columns(r) for r in roles], aliases)
        self.assertEqual(ew["disclosed"], bw["disclosed"], "engine (with columns) != brute force")
        self.assertEqual(eo["disclosed"], bo["disclosed"], "engine (without columns) != brute force")
        return bw["disclosed"], bo["disclosed"], ew, eo

    def test_baseline_discloses_only_the_public_zero_sum(self):
        roles, aliases = V.synthetic_roles(2409)
        with_, without, ew, eo = self.both(roles, canonical(roles), aliases)
        self.assertEqual((with_, without), (2, 2))
        self.assertEqual(ew["o8_equivalent"]["rank_mask"], eo["o8_equivalent"]["rank_mask"])
        self.assertEqual(ew["o8_equivalent"]["rank_joint"], eo["o8_equivalent"]["rank_joint"])
        roles0, _ = V.synthetic_roles(2409, drop_zero_sum=True)
        self.assertEqual(self.both(roles0, canonical(roles0), aliases)[:2], (0, 0))

    def test_the_brute_force_matrix_has_the_expected_shape(self):
        roles, aliases = V.synthetic_roles(2409)
        b = V.brute_force(roles, aliases, True)
        rows = sum(r.rows for r in roles)
        self.assertEqual(b["unknowns"], rows * 12 - 8)                       # one aliased row of 8 message words
        self.assertEqual(b["data_unknowns"], (3 + 1 + 3) * 8 - 8)
        cols = sum(len(set(r.indices)) * r.rows for r in roles)
        folds = sum((len(r.groups) + 1) * 24 for r in roles)
        self.assertEqual(b["observations"], folds + 2 * 5 + 2 + cols)        # 5 terminals, 1 extra

    def test_four_distinct_positions_and_no_alias(self):
        roles, aliases = V.synthetic_roles(2410, indices={"A": [3, 17, 40, 51], "E": [5, 9, 33, 61], "H": [2, 7, 44, 50]})
        self.assertEqual(self.both(roles, canonical(roles), aliases)[:2], (2, 2))
        roles, _ = V.synthetic_roles(2411)
        self.assertEqual(self.both(roles, canonical(roles), ())[:2], (2, 2))

    def test_ablated_endpoint_mask_pair_discloses(self):
        roles, aliases = V.synthetic_roles(2412, ablate_endpoint=True)
        with_, without, _, _ = self.both(roles, canonical(roles), aliases)
        self.assertGreater(with_, 2)
        self.assertEqual(with_, without)

    def test_deficient_pads_disclose_only_through_the_columns(self):
        for cls in ("mask", "data"):
            roles, aliases = V.synthetic_roles(2413, deficient=("H", cls, 2))
            plans = [V.plan_deficient(r, V.ColumnAlgebra(r.n, r.q_pad, r.domain, r.indices), cls, 2)
                     if r.name == "H" else V.plan_canonical(r, V.ColumnAlgebra(r.n, r.q_pad, r.domain, r.indices))
                     for r in roles]
            with_, without, ew, _ = self.both(roles, plans, aliases)
            self.assertGreater(with_, 2, cls)
            self.assertEqual(without, 2, cls)
            if cls == "data":
                self.assertEqual(ew["column_only_disclosed"], 3 * 1)          # 3 deficient data rows, |J_d| - Q' = 1
        roles, aliases = V.synthetic_roles(2414, deficient=("H", "mask", 3))
        plans = [V.plan_deficient(r, V.ColumnAlgebra(r.n, r.q_pad, r.domain, r.indices), "mask", 3)
                 if r.name == "H" else V.plan_canonical(r, V.ColumnAlgebra(r.n, r.q_pad, r.domain, r.indices))
                 for r in roles]
        self.assertEqual(self.both(roles, plans, aliases)[:2], (2, 2))

    def test_explicit_column_matrix_matches_the_certificate_and_kernel(self):
        for indices in ([3, 17, 40, 3], [3, 17, 40, 51], [9, 9, 9, 9]):
            alg = V.ColumnAlgebra(8, 4, 64, indices)
            ej = V.explicit_column_matrix(alg)
            self.assertEqual(R.rank(ej), alg.jd)
            basis = [sum(alg.kernel_vector("completion", j), []) for j in range(8)]
            basis += [sum(alg.kernel_vector("padker", i), []) for i in range(4 - alg.jd)]
            for vec in basis:
                self.assertTrue(all(sum(a * b for a, b in zip(row, vec)) % P == 0 for row in ej))
            self.assertEqual(R.rank(basis), 12 - alg.jd)
            self.assertEqual(alg.kernel_dim, 12 - alg.jd)
            pad_part = [row[8:] for row in ej]
            for k, g in enumerate(alg.cert):
                image = [sum(a * b for a, b in zip(row, g)) % P for row in pad_part]
                self.assertEqual(image, [1 if i == k else 0 for i in range(alg.jd)])

    def test_refusals(self):
        with self.assertRaisesRegex(ValueError, "hypothesis"):
            V.ColumnAlgebra(8, 2, 64, [3, 17, 40])
        roles, _ = V.synthetic_roles(2415, deficient=("A", "mask", 2))
        plans = [V.plan_deficient(r, V.ColumnAlgebra(r.n, r.q_pad, r.domain, r.indices), "mask", 2)
                 if r.name == "A" else V.plan_canonical(r, V.ColumnAlgebra(r.n, r.q_pad, r.domain, r.indices))
                 for r in roles]
        with self.assertRaisesRegex(ValueError, "identity message range"):
            V.ReducedModel(roles, plans, self.ALIASES)
        with self.assertRaisesRegex(ValueError, "full pad budget"):
            V.ReducedModel(roles, canonical(roles), self.ALIASES)
        roles, _ = V.synthetic_roles(2416)
        with self.assertRaisesRegex(ValueError, "data rows"):
            V.ReducedModel(roles, canonical(roles), [(("A", 3), ("E", 0))])

    def test_polynomial_helpers(self):
        rng = random.Random(7)
        xs = [rng.randrange(1, P) for _ in range(5)]
        v = V.poly_from_roots(xs)
        self.assertEqual(len(v), 6)
        self.assertEqual(v[-1], 1)
        for x in xs:
            self.assertEqual(V.poly_eval(v, x), 0)
            q, rem = V.synth_div(v, x)
            self.assertEqual(rem, 0)
            self.assertEqual(V.poly_mul_linear(q, x), v)
        y = rng.randrange(P)
        q, rem = V.synth_div(v, y)
        self.assertEqual(rem, V.poly_eval(v, y))


class RealCapture(unittest.TestCase):
    """One P1 capture, end to end (about a minute).  Missing evidence fails."""

    @classmethod
    def setUpClass(cls):
        path = os.path.join(CAPTURES, P1_CAPTURE)
        if not os.path.exists(path) or not os.path.exists(MANIFEST):
            raise AssertionError(f"round-22 capture evidence missing at {path}: not a skip, a failure")
        cls.checks = []
        cls.rec = V.analyze_capture(path, None, lambda *a: None, V.load_archived_o8(), cls.checks)

    def test_every_recorded_expectation_holds(self):
        failed = [c for c in self.checks if not c["pass"]]
        self.assertEqual(failed, [])
        self.assertGreaterEqual(len(self.checks), 40)

    def test_with_columns_equals_without_equals_o8(self):
        for role, e in self.rec["roles"].items():
            self.assertEqual(e["disclosed_dim_with_columns"], e["disclosed_dim_without_columns"], role)
            self.assertEqual(e["disclosed_dim_with_columns"], 2 if role == "H" else 0, role)
            self.assertEqual(e["with_columns"]["o8_equivalent"]["rank_mask"], e["o8_live"]["rank_mask"], role)
            self.assertEqual(e["with_columns"]["o8_equivalent"]["rank_joint"], e["o8_live"]["rank_joint"], role)
            self.assertEqual(e["column_algebra"]["distinct_positions"] + e["column_algebra"]["kernel_dim"], 512)
        j = self.rec["joint"]
        self.assertEqual(j["io_cluster_aliased"]["disclosed_dim_with_columns"], 0)
        self.assertEqual(j["all_private_commitments_aliased"]["disclosed_dim_with_columns"], 2)
        self.assertEqual(j["all_private_commitments_aliased"]["without_H_zero_sum"]["with_columns"], 0)
        self.assertTrue(j["all_private_commitments_aliased"]["public_logup_identity_added"]["adds_no_rank"])
        arch = self.rec["controls"]["o8_archive"]
        self.assertEqual(arch["archived"], arch["without_columns"])

    def test_controls_detect_the_known_leaks(self):
        abl = self.rec["controls"]["endpoint_mask_ablation"]
        for nm in ("Input", "Output"):
            self.assertEqual(abl[nm]["with_columns"], 256)
            self.assertEqual(abl[nm]["without_columns"], 256)
            self.assertEqual(abl[nm]["o8_single_mask_disclosed_total"], 256)
        self.assertGreater(abl["io_cluster_with_ablated_input"]["with_columns"], 0)
        defc = self.rec["controls"]["deficient_pads"]
        below = [v for k, v in defc.items() if isinstance(v, dict) and v.get("q_prime") == v.get("distinct_positions", 0) - 1]
        at255 = [v for k, v in defc.items() if isinstance(v, dict) and v.get("q_prime") == 255]
        self.assertEqual(len(below), 4)
        self.assertTrue(all(v["disclosed"] > (2 if "leak_beyond_public_identity" in v else 0) for v in below))
        self.assertEqual(len(at255), 2)
        self.assertTrue(all(v["disclosed"] == 0 for v in at255))

    def test_mask_commitment_discloses_exactly_its_public_functionals(self):
        m = self.rec["mask"]
        self.assertEqual(m["functional_rank_fp2"], 14)
        self.assertEqual(m["disclosed_with_columns"], 28)
        self.assertEqual(m["disclosed_beyond_public_functionals"], 0)
        self.assertEqual(m["disclosed_without_functionals_observed"], 2)
        self.assertEqual(m["elimination_directions_checked"], sum(s["kernel_dim"] for s in m["per_slot"]))
        self.assertEqual(len(m["per_slot"]), 8)


if __name__ == "__main__":
    unittest.main()

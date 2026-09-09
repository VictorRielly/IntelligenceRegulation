"""FA6 tests: the CFS mask model against brute force, the Rust cross-check
fixture (constants shared with hashline/tests/zk60_fable_cfs_channel.rs), the
actual slot tables' verdicts, the negative / positive controls, the M-opening
toy models and the report I/O.  Reviewer: Claude Fable 5.1, 2026-09-08 session.

    python3 -m unittest discover -s tests -p 'test_zk60_fable_cfs_channel.py' -v
"""
import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location("cfs_channel", Path(__file__).resolve().parents[1] / "scripts/zk60_fable_cfs_channel.py")
C = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(C)
R = C.R
P = C.P
ONE, ZERO = C.ONE, C.ZERO

# the constants embedded in hashline/tests/zk60_fable_cfs_channel.rs
RUST_COEFFS = [(P - c0, c1) for c0, c1 in zip([3, 5, 7, 11, 13, 17, 20, 23], [1, 2, 3, 4, 5, 6, 7, 9])]
RUST_RHO = [(2, 1), (5, P - 3), (7, 4)]
RUST_ROUNDS = [
    [(18446744069414584163, 58), (18446744069414584086, 88), (18446744069414583921, 150)],
    [(18446744069414584268, 16), (18446744069414584212, 37), (18446744069414584088, 82)],
    [(18446744069414581390, 1102), (18446744069414581388, 1101), (18446744069414581340, 1118)],
]
RUST_TOTAL = (18446744069414583928, 146)
RUST_EVAL = (18446744069414581082, 1277)


def rnd_coeffs(rng, n, d):
    return [rng.fp2() for _ in range(C.cfs_len(n, d))]


class RoundFormula(unittest.TestCase):
    """The closed form of CfsMask::round against the definition (sum over the
    boolean rest), mirroring zkp-core's cfs_mask_rounds_match_brute_force."""

    def test_closed_form_matches_brute_force_and_the_verifier_chain(self):
        rng = C.Rng(11)
        for n, d in [(3, 2), (4, 4), (5, 1)]:
            coeffs = rnd_coeffs(rng, n, d)
            total = C.cfs_total(coeffs, n, d)
            # sum over the cube by definition
            cube = ZERO
            for idx in range(1 << n):
                pt = [ONE if (idx >> (n - 1 - i)) & 1 else ZERO for i in range(n)]
                cube = C.f2_add(cube, C.cfs_eval(coeffs, pt, d))
            self.assertEqual(cube, total)
            prev = []
            for j in range(n):
                got = C.cfs_round(coeffs, n, d, j, prev)
                want = C.cfs_round_brute(coeffs, n, d, j, prev)
                self.assertEqual(got, want, f"n {n} d {d} round {j}")
                s01 = C.f2_add(got[0], got[1])
                if j == 0:
                    self.assertEqual(s01, total)
                else:
                    self.assertEqual(s01, C.interp_eval(C.cfs_round(coeffs, n, d, j - 1, prev[:-1]), prev[-1]))
                prev.append(rng.fp2())
            # terminal: the last message interpolated at the last challenge is g(rho)
            last = C.cfs_round(coeffs, n, d, n - 1, prev[:-1])
            self.assertEqual(C.interp_eval(last, prev[-1]), C.cfs_eval(coeffs, prev, d))

    def test_lagrange_weights_interpolate_a_known_polynomial(self):
        # p(x) = 3 + 2x + 5x^2 at nodes 0..2, evaluated at a random point
        rng = C.Rng(12)
        r = rng.fp2()
        vals = [C.f2(3 + 2 * x + 5 * x * x) for x in range(3)]
        want = C.f2_add(C.f2(3), C.f2_add(C.f2_mul_base(r, 2), C.f2_mul_base(C.f2_mul(r, r), 5)))
        self.assertEqual(C.interp_eval(vals, r), want)


class RustCrossCheck(unittest.TestCase):
    """The Python model at the Rust fixture equals the constants the Rust test asserts."""

    def test_fixture_constants(self):
        fx = C.rust_fixture()
        self.assertEqual(fx["coeffs"], [C.f2(a, b) for a, b in RUST_COEFFS])
        self.assertEqual(fx["rho"], [C.f2(a, b) for a, b in RUST_RHO])
        self.assertEqual(fx["rounds"], [[C.f2(a, b) for a, b in r] for r in RUST_ROUNDS])
        self.assertEqual(fx["total"], C.f2(*RUST_TOTAL))
        self.assertEqual(fx["eval"], C.f2(*RUST_EVAL))

    def test_fixture_values_are_full_width(self):
        # the negative representatives wrap: at least one value in every round is above 2^63
        for r in RUST_ROUNDS:
            self.assertTrue(any(a > 1 << 63 for a, _ in r))


class ExactAlgebra(unittest.TestCase):
    """The Fp2 elimination used here agrees with FA2's Fp elimination on the doubled matrix."""

    def test_f2_rank_matches_doubled_fp_rank(self):
        rng = C.Rng(13)
        for _ in range(4):
            rows = [[rng.fp2() for _ in range(5)] for _ in range(3)]
            rows.append([C.f2_add(a, b) for a, b in zip(rows[0], rows[1])])   # a dependent row
            r2 = C.f2_rank(rows)
            rf = R.rank(C.fp2_rows_to_fp(rows))
            self.assertEqual(rf, 2 * r2)
            self.assertEqual(r2, 3)

    def test_null_spaces_annihilate(self):
        rng = C.Rng(14)
        rows = [[rng.fp2() for _ in range(6)] for _ in range(3)]
        for v in C.f2_null_space(rows, 6):
            for row in rows:
                self.assertEqual(C.f2_dot(row, v), ZERO)
        for y in C.f2_left_null_space(rows, 6):
            comb = [ZERO] * 6
            for yi, row in zip(y, rows):
                comb = [C.f2_add(a, C.f2_mul(yi, b)) for a, b in zip(comb, row)]
            self.assertTrue(all(C.f2_is_zero(x) for x in comb))


class SlotTable(unittest.TestCase):
    """mask_specs / mask_specs_v3 reproduced at the review shapes; every system surjective."""

    @classmethod
    def setUpClass(cls):
        cls.report = C.slot_table_report(C.Rng(6))

    def _entry(self, shape_sub, mode):
        for e in self.report:
            if shape_sub in e["shape"] and e["mode"] == mode:
                return e
        raise AssertionError(f"no entry {shape_sub} / {mode}")

    def test_specs_at_the_fixture_shapes(self):
        e = self._entry("T2/d16/f16", "P1")
        want = {"SC_GU": (5, 2), "SC_D": (5, 2), "SC_ZC20": (6, 4), "SC_ZC17": (6, 4), "SC_ZSUM": (6, 2), "SC_TAB": (17, 3)}
        self.assertEqual({k: (v["n_vars"], v["degree"]) for k, v in e["slots"].items()}, want)
        e = self._entry("T2/d16/f16", "P3")
        self.assertEqual((e["slots"]["SC_GU"]["n_vars"], e["slots"]["SC_GU"]["ext_rounds"]), (6, 2))
        self.assertEqual((e["slots"]["SC_D"]["n_vars"], e["slots"]["SC_D"]["ext_rounds"]), (6, 2))
        e = self._entry("T2/d16/f16", "P1 + function-2 predicate")
        self.assertEqual((e["slots"]["SC_PRED"]["n_vars"], e["slots"]["SC_PRED"]["degree"]), (6, 3))
        e = self._entry("T32/d16/f16", "P1")
        self.assertEqual((e["slots"]["SC_ZC20"]["n_vars"], e["slots"]["SC_ZSUM"]["n_vars"], e["slots"]["SC_TAB"]["n_vars"]), (10, 9, 17))
        e = self._entry("8B block profile", "P1 block profile (+ seams)")
        want = {"SC_GU": (13, 2), "SC_D": (12, 2), "SC_ZC20": (17, 4), "SC_ZC17": (18, 4), "SC_ZSUM": (15, 2), "SC_TAB": (17, 3), "SC_SEAM_X": (18, 2), "SC_SEAM_Z": (18, 2)}
        self.assertEqual({k: (v["n_vars"], v["degree"]) for k, v in e["slots"].items()}, want)
        self.assertEqual(e["slots"]["SC_ZC17"]["len"], 74)
        e = self._entry("v2 legacy", "P1")
        want = {"SC_GU": (9, 2), "SC_D": (12, 2), "SC_ZC20": (17, 4), "SC_ZC17": (14, 4), "SC_ZSUM": (14, 2), "SC_TAB": (14, 3)}
        self.assertEqual({k: (v["n_vars"], v["degree"]) for k, v in e["slots"].items()}, want)
        # every mask row fits: coefficients + 256 pads <= 512 (mask_commit's assert)
        for e in self.report:
            for v in e["slots"].values():
                self.assertLessEqual(v["len"] + 256, 512)

    def test_every_system_is_surjective_with_the_predicted_dimensions(self):
        for e in self.report:
            self.assertTrue(e["all_surjective"], e["shape"] + " / " + e["mode"])
            for s, r in e["systems"]["standalone"].items():
                n, d = e["slots"][s]["n_vars"], e["slots"][s]["degree"]
                self.assertEqual(r["dim_consistency_subspace"], n * d + 1, s)
                self.assertEqual(r["rank_map"], n * d + 1, s)
                self.assertEqual(r["kernel_dim_fp2"], 1, s)
            for k, r in e["systems"].items():
                if k == "standalone":
                    continue
                self.assertTrue(r["image_inside_subspace"], k)
                self.assertEqual(r["leaked_dim_fp2"], 0, k)
                self.assertEqual(r["kernel_dim_fp2"], 2 if "+" in k else 1, k)
                self.assertTrue(all(r["m_functionals_in_view_span"].values()), k)
                self.assertTrue(r["theta_combination_in_view_span"], k)

    def test_batched_pair_view_dimension_is_the_sum_minus_two(self):
        e = self._entry("T32/d16/f16", "P1")
        r = e["systems"]["SC_GU+SC_ZC20 (batched as coded)"]
        la, lb = e["slots"]["SC_GU"]["len"], e["slots"]["SC_ZC20"]["len"]
        self.assertEqual(r["n_unknowns_fp2"], la + lb)
        self.assertEqual(r["dim_consistency_subspace"], la + lb - 2)
        self.assertEqual(r["rank_map"], la + lb - 2)


class Controls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.c = C.controls_message_channel(C.Rng(6), n=4, d=3)

    def test_negative_controls_are_deficient_with_the_predicted_leak(self):
        n, d = 4, 3
        dim_s = n * d + 1
        want = {
            "nc_mask_challenge_zero": dim_s,
            "nc_no_constant_a0_degenerate_challenge": 1,
            "nc_no_a0_no_aprime": 1,
            "nc_extension_degree_exceeds_mask": 1,
            "nc_mask_reuse_same_challenges": dim_s,
            "nc_mask_reuse_fresh_challenges": n * d,
            "nc_batched_pair_without_zero_check_mask": 4 * 4 + 1,
        }
        for k, leaked in want.items():
            r = self.c[k]
            self.assertEqual(r["verdict"], "DEFICIENT", k)
            self.assertEqual(r["leaked_dim_fp2"], leaked, k)
            self.assertTrue(r["leaked_functionals"], k)
            self.assertTrue(r["counterexample"]["phi_f2_nonzero"], k)

    def test_positive_controls_stay_surjective(self):
        for k in ("pc_no_aprime_libra_form", "pc_no_constant_a0_generic_challenges"):
            r = self.c[k]
            self.assertTrue(r["verdict"].startswith("surjective"), k)
            self.assertEqual(r["leaked_dim_fp2"], 0)
            self.assertEqual(r["kernel_dim_fp2"], 0, k)   # the redundant direction is the one removed
        # the full mask is surjective at degenerate challenges as well (challenge independence)
        for k in ("pc_full_mask_all_zero_challenges", "pc_full_mask_all_one_challenges"):
            r = self.c[k]
            self.assertTrue(r["verdict"].startswith("surjective"), k)
            self.assertEqual(r["kernel_dim_fp2"], 1, k)

    def test_extension_degree_gap_leaks_exactly_the_clear_top_value(self):
        r = self.c["nc_extension_degree_exceeds_mask"]
        (phi,) = r["leaked_functionals"]
        self.assertEqual(list(phi.keys()), ["s.h3(4)"])

    def test_counterexample_distinguishes_two_data_for_every_mask(self):
        """Direct: for a deficient channel, phi(f + L a) = phi(f) for every a."""
        ch = C.Channel()
        ch.add_mask("m", 3, 2)
        cc = C.Rng(21).fp2()
        rng = C.Rng(22)
        g = ch.add_view("Gamma", ch.mask_row("m", C.cfs_sum_weights(3, 2), cc))
        ch.add_masked_sumcheck("m", cc, {g: ONE}, rng, "s", last_round_degree=3)
        res = ch.analyze()
        self.assertEqual(res["leaked_dim_fp2"], 1)
        # recover the leaked functional as a dense vector and two consistent data sets
        cons = ch.cons_rows()
        ln = C.f2_left_null_space(ch.view_rows, ch.n_unk)
        base = C.f2_rank(cons)
        y = next(v for v in ln if C.f2_rank(cons + [v]) > base)
        s_basis = C.f2_null_space(cons, len(ch.view_rows))
        f2v = next(v for v in s_basis if not C.f2_is_zero(C.f2_dot(y, v)))
        f1v = [ZERO] * len(ch.view_rows)
        for _ in range(3):
            a = [rng.fp2() for _ in range(ch.n_unk)]
            la = [C.f2_dot(row, a) for row in ch.view_rows]
            v1 = [C.f2_add(x, z) for x, z in zip(f1v, la)]
            v2 = [C.f2_add(x, z) for x, z in zip(f2v, la)]
            self.assertEqual(C.f2_dot(y, v1), ZERO)
            self.assertEqual(C.f2_dot(y, v2), C.f2_dot(y, f2v))
            self.assertNotEqual(C.f2_dot(y, v1), C.f2_dot(y, v2))

    def test_mask_reuse_same_challenges_reveals_the_data_difference(self):
        """view1 - view2 = f1 - f2 exactly when one mask serves two sumchecks with the same challenges."""
        n, d = 3, 2
        rng = C.Rng(23)
        coeffs = rnd_coeffs(rng, n, d)
        c = rng.fp2()
        rho = [rng.fp2() for _ in range(n)]
        g = [[C.f2_mul(c, x) for x in C.cfs_round(coeffs, n, d, j, rho[:j])] for j in range(n)]
        f1 = [[rng.fp2() for _ in range(d + 1)] for _ in range(n)]
        f2_ = [[rng.fp2() for _ in range(d + 1)] for _ in range(n)]
        v1 = [[C.f2_add(a, b) for a, b in zip(fr, gr)] for fr, gr in zip(f1, g)]
        v2 = [[C.f2_add(a, b) for a, b in zip(fr, gr)] for fr, gr in zip(f2_, g)]
        for j in range(n):
            for x in range(d + 1):
                self.assertEqual(C.f2_sub(v1[j][x], v2[j][x]), C.f2_sub(f1[j][x], f2_[j][x]))


class MOpening(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.m = C.controls_m_opening(C.Rng(6))

    def test_seven_generates_and_the_coset_is_disjoint(self):
        self.assertTrue(self.m["seven_generates_fp_star"]["ok"])
        self.assertTrue(self.m["seven_generates_fp_star"]["coset_disjoint_from_G_m"])

    def test_sum_identity_of_the_product_polynomial(self):
        self.assertTrue(self.m["sum_identity"]["sum_over_G_m_equals_m(q0+qm)"])
        self.assertTrue(self.m["sum_identity"]["equals_<a,W>"])

    def test_columns_hidden_by_pads_up_to_the_pad_count(self):
        self.assertEqual(self.m["pc_columns_q_distinct_under_q_pads"]["disclosed_coefficient_functionals"], 0)
        self.assertEqual(self.m["pc_columns_duplicate_indices"]["disclosed_coefficient_functionals"], 0)
        self.assertEqual(self.m["nc_columns_exceed_pads"]["disclosed_coefficient_functionals"], 1)
        self.assertEqual(self.m["nc_columns_without_pads"]["disclosed_coefficient_functionals"], 3)

    def test_qprime_reveals_exactly_v_once_and_everything_twice(self):
        self.assertEqual(self.m["pc_qprime_one_opening"]["disclosed_fp2_dim"], 1)
        self.assertEqual(self.m["nc_qprime_two_openings_same_M"]["disclosed_fp2_dim"], 3)
        self.assertEqual(self.m["nc_qprime_without_blinding"]["disclosed_fp2_dim"], 3)

    def test_joint_view_qprime_prox_columns_reveals_exactly_v(self):
        j = self.m["pc_joint_qprime_prox_columns_one_opening"]
        self.assertEqual(j["disclosed_fp_dim"], 2)      # V = one Fp2 value, nothing about b, u or the pads beyond it
        self.assertEqual(j["opened_columns"], 3)
        j2 = self.m["nc_joint_two_openings_same_M"]
        self.assertEqual(j2["disclosed_fp_dim"], j2["data_scalars_fp"])   # a second opening of the same M discloses every coefficient

    def test_lagrange_on_subgroup_interpolates(self):
        m = 8
        rng = C.Rng(31)
        vals = [rng.fp() for _ in range(m)]
        # off the subgroup: the Lagrange form agrees with the coefficient (inverse-DFT) form
        x = C.coset_points(3)[5]
        lag = C.lagrange_on_subgroup(m, x)
        via_lag = sum(l * v for l, v in zip(lag, vals)) % P
        idft = C.idft_rows(m)
        coefs = [sum(r * v for r, v in zip(row, vals)) % P for row in idft]
        via_coef = sum(c * C._pow(x, k) for k, c in enumerate(coefs)) % P
        self.assertEqual(via_lag, via_coef)


class Report(unittest.TestCase):
    def test_main_writes_the_report_with_hashes_and_verdicts(self):
        with tempfile.TemporaryDirectory() as td:
            out = os.path.join(td, "fa6.json")
            self.assertEqual(C.main(["--out", out, "--quiet", "--seed", "6"]), 0)
            with open(out) as f:
                rep = json.load(f)
        self.assertEqual(rep["source_commit"], "cfa46f6")
        for k in ("zkp-core/src/sumcheck.rs", "hashline/src/zk.rs"):
            self.assertRegex(rep["source_sha256"][k], r"^[0-9a-f]{64}$")
        self.assertTrue(rep["all_slot_systems_surjective"])
        self.assertEqual(rep["rust_fixture"]["total"], list(RUST_TOTAL))
        self.assertIn("nc_mask_reuse_fresh_challenges", rep["controls_message_channel"])
        self.assertIn("nc_qprime_two_openings_same_M", rep["controls_m_opening"])


if __name__ == "__main__":
    unittest.main()

"""Conditional IO CFS checks; real captures are a separate mandatory CLI run."""
import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]/"scripts"))
import zk60_io_cfs_composition as T

C, ZERO, ONE = T.C, T.ZERO, T.ONE


def fixture():
    rng = C.Rng(2101)
    rho, coeffs, c = [rng.fp2() for _ in range(10)], [rng.fp2() for _ in range(22)], rng.fp2()
    gamma = C.f2_mul(c, C.cfs_total(coeffs, 10, 2))
    value = C.cfs_eval(coeffs, rho, 2)
    rounds = [[C.f2_mul(c, x) for x in C.cfs_round(coeffs, 10, 2, j, rho[:j])] for j in range(10)]
    # Equal terminals make the equality-polynomial part zero.
    arg = dict(side=0, slot=6, tau=[list(rng.fp2()) for _ in range(9)], c=list(c), gamma=list(gamma),
               rho=[list(x) for x in rho], rounds=[[list(x) for x in r] for r in rounds],
               mask_eval=list(value), terminals=[[17, 23], [17, 23]])
    fs = [{"terms": [{"slot": 6, "weights": [list(C.f2_mul(c, x)) for x in C.cfs_sum_weights(10, 2)]}], "value": list(gamma)},
          {"terms": [{"slot": 6, "weights": [list(x) for x in C.cfs_eval_weights(rho, 2)]}], "value": list(value)}]
    mask = {"specs": [[10, 2]]*8, "functionals": [None]*10+fs}
    return arg, mask


class ConditionalFibre(unittest.TestCase):
    def test_full_io_geometry_at_degenerate_and_random_points(self):
        rng = C.Rng(2102)
        for rho in ([ZERO]*10, [ONE]*10, [(C.HALF, 0)]*10, [rng.fp2() for _ in range(10)]):
            result, _ = T.fibre_model(rho, (3, 5))
            self.assertEqual(result["functionals_rank_fp2"], 2)
            self.assertEqual(result["coefficient_fibre_dim_fp2"], 20)
            self.assertEqual(result["round_fibre_dim_fp2"], 19)
            self.assertEqual(result["mask_image_rank_fp2"], 19)
            self.assertTrue(result["surjective"])

    def test_zero_multiplier_leaves_all_conditional_round_freedom_unmasked(self):
        result, _ = T.fibre_model([(3, 5)]*10, ZERO)
        self.assertEqual(result["mask_image_rank_fp2"], 0)
        self.assertEqual(result["round_fibre_dim_fp2"], 19)
        self.assertFalse(result["surjective"])

    def test_shortened_mask_cannot_cover_the_fibre(self):
        rho, c = [(3, 5)]*10, (7, 11)
        fs = [C.cfs_sum_weights(10, 2)[2:], C.cfs_eval_weights(rho, 2)[2:]]
        kernel = C.f2_null_space(fs, 20)
        image = []
        for v in kernel:
            coeffs = [ZERO, ZERO]+v
            image.append([C.f2_mul(c, x) for j in range(10) for x in C.cfs_round(coeffs, 10, 2, j, rho[:j])])
        self.assertLess(C.f2_rank(image), 19)

    def test_independent_round_formula_matches_weight_map(self):
        rng = C.Rng(2103)
        rho, c = [rng.fp2() for _ in range(10)], rng.fp2()
        _, image = T.fibre_model(rho, c)
        fs = [C.cfs_sum_weights(10, 2), C.cfs_eval_weights(rho, 2)]
        basis = C.f2_null_space(fs, 22)
        for coeffs, want in zip(basis, image):
            got = [C.f2_mul(c, x) for j in range(10) for x in C.cfs_round(coeffs, 10, 2, j, rho[:j])]
            self.assertEqual(got, want)


class PublicBinding(unittest.TestCase):
    def test_actual_cfs_rounds_and_mask_functionals_accept(self):
        arg, mask = fixture()
        result = T.check_slot(arg, mask)
        self.assertTrue(result["nonzero_round_translation_verified"])
        self.assertTrue(result["exact_m_functionals_verified"])

    def test_changed_functional_and_mask_challenge_refuse(self):
        arg, mask = fixture()
        bad = copy.deepcopy(mask)
        bad["functionals"][10]["terms"][0]["slot"] = 7
        with self.assertRaisesRegex(ValueError, "functional binding"):
            T.check_slot(arg, bad)
        arg["c"] = [0, 0]
        with self.assertRaisesRegex(ValueError, "refused mask challenge"):
            T.replay(arg)

    def test_changed_masked_terminal_and_round_refuse(self):
        arg, _ = fixture()
        bad = copy.deepcopy(arg)
        bad["terminals"][0][0] += 1
        with self.assertRaisesRegex(ValueError, "masked terminal equation"):
            T.replay(bad)
        bad = copy.deepcopy(arg)
        bad["rounds"][3][2][0] = (bad["rounds"][3][2][0]+1) % C.P
        with self.assertRaisesRegex(ValueError, "round chain equation"):
            T.replay(bad)


if __name__ == "__main__":
    unittest.main()

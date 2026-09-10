"""Independent arithmetic enumeration and standalone endpoint-view controls."""
from collections import Counter
import copy
from fractions import Fraction
import json
from pathlib import Path
import random
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]/"scripts"))
import zk60_endpoint_view as V
from test_zk60_endpoint_fibre import fixture


def empirical_tv(bits, modulus, shift=0, to_uniform=True):
    count = 1 << bits
    observed = Counter(x % modulus for x in range(count))
    target = ([Fraction(1, modulus)]*modulus if to_uniform else
              [Fraction(observed[(i-shift) % modulus], count) for i in range(modulus)])
    return sum(abs(Fraction(observed[i], count)-target[i]) for i in range(modulus))/2


class ReductionArithmetic(unittest.TestCase):
    def test_exact_formula_matches_exhaustive_small_domains(self):
        for bits in range(8):
            for modulus in range(1, 20):
                self.assertEqual(V.reduction_distance(bits, modulus), empirical_tv(bits, modulus))

    def test_shift_bound_is_not_a_distance_floor(self):
        for bits, modulus in ((4, 7), (6, 11), (3, 5)):
            delta = V.reduction_distance(bits, modulus)
            self.assertGreater(delta, 0)
            self.assertEqual(empirical_tv(bits, modulus, 0, False), 0)
            for shift in range(modulus):
                self.assertLessEqual(empirical_tv(bits, modulus, shift, False), 2*delta)
        # A constant visible output erases the entire input-distribution distance.
        self.assertEqual(Counter(0 for _ in range(16)), {0: 16})

    def test_two_independent_words_obey_product_upper_bound(self):
        modulus, count = 7, 16
        counts = Counter((a % modulus, b % modulus) for a in range(count) for b in range(count))
        distance = sum(abs(Fraction(counts[a,b], count*count)-Fraction(1, modulus*modulus))
                       for a in range(modulus) for b in range(modulus))/2
        self.assertLessEqual(distance, 2*V.reduction_distance(4, modulus))

    def test_goldilocks_ledger_uses_exact_fractions(self):
        p = V.P
        self.assertEqual((1 << 128) % p, p-(1 << 32))
        d = V.reduction_distance(128, p)
        self.assertEqual(d, Fraction(p-(1 << 32), p*(1 << 96)))
        self.assertLess(d, Fraction(1, 1 << 96))
        self.assertNotEqual(d, Fraction(1, 1 << 96)*(1-Fraction(1, 1 << 32)))
        ledger = V.arithmetic_ledger()
        self.assertEqual(ledger["endpoint_pair_words"], 6144)
        self.assertFalse(ledger["visible_view_lower_bound_claimed"])
        self.assertFalse(ledger["whole_protocol_bound_claimed"])


class EndpointGeneration(unittest.TestCase):
    def plan(self, deficient=False):
        view, _ = fixture(deficient=deficient)
        return V.EndpointPlan(view.folds, view.claim_weights, view.claim_cw,
                              view.indices, view.n, view.budget, view.domain)

    def test_generated_observations_have_nonzero_data_preimages(self):
        plan = self.plan()
        view = V.generate(plan, random.Random(2501).randrange)
        data = [[r+j*j+3 for j in range(plan.n)] for r in range(2)]
        sample = V.F.sample(view, data, random.Random(2502).randrange)
        self.assertEqual(V.F.verify_sample(view, data, sample), view.columns)
        self.assertEqual(sample["message"][:2], data)
        self.assertEqual(view.columns[0], view.columns[-1])

    def test_fresh_draws_change_public_observations_preserving_plan(self):
        plan = self.plan()
        before = copy.deepcopy(plan)
        first = V.generate(plan, random.Random(2503).randrange)
        second = V.generate(plan, random.Random(2504).randrange)
        self.assertNotEqual(first.vectors, second.vectors)
        self.assertNotEqual(first.columns, second.columns)
        self.assertEqual(plan, before)

    def test_deficient_masks_and_invalid_randomness_refuse(self):
        with self.assertRaisesRegex(ValueError, "deficient"):
            V.generate(self.plan(deficient=True))
        with self.assertRaisesRegex(ValueError, "random field"):
            V.generate(self.plan(), lambda _: True)

    def test_plan_does_not_read_captured_output_values(self):
        paths = sorted((V.ROOT/"results/zk60_round22_captures").glob("*.json"))
        self.assertEqual(len(paths), 4, "mandatory retained captures absent")
        cap = V.F.repeated.O.IoCapture(str(paths[0]))
        raw = json.loads(paths[0].read_text())
        role = next(r for r in raw["roles"] if r["role"] == "Input")
        original = V.plan_from_capture(role, cap.by_role["Input"])
        changed = copy.deepcopy(role)
        # Delete every field-valued observation consumed by the old fibre API.
        del changed["claims"][0]["value"]
        del changed["groups"][0]["vector"]
        del changed["proximity_vector"]
        for column in changed["columns"]:
            del column["values"]
        changed["commitment"]["root"] = "unused"
        self.assertEqual(V.plan_from_capture(changed, cap.by_role["Input"]), original)
        a = V.generate(original, random.Random(2505).randrange)
        b = V.generate(V.plan_from_capture(changed, cap.by_role["Input"]), random.Random(2505).randrange)
        self.assertEqual(a, b)


if __name__ == "__main__":
    unittest.main()

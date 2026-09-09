"""Small independent PCS fixtures and adversarial conditional-sampler checks."""
import copy
from pathlib import Path
import random
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import zk60_endpoint_fibre as F

C, T, P = F.C, F.T, F.P


def fixture(deficient=False, seed=2401):
    rng = random.Random(seed)
    fp = lambda: rng.randrange(P)
    pair = lambda: (fp(), fp())
    n, budget, domain = 8, 4, 64
    weights = [pair() for _ in range(7)]
    if deficient:
        weights[2:] = [(fp(), 0) for _ in range(5)]
    folds = [weights, [pair() for _ in range(7)]]
    messages = [[fp() for _ in range(n)] for _ in range(7)]
    pads = [[fp() for _ in range(budget)] for _ in range(7)]
    vectors = [[C.f2_dot(w, [(x, 0) for x in col])
                for col in zip(*[m+p for m, p in zip(messages, pads)])] for w in folds]
    cw = [pair() for _ in range(n)]
    terminal = C.f2_dot(cw, vectors[0][:n])  # lambda=1 in this fixture
    indices = [1, 5, 9, 1]
    # Independent definition: evaluate IDFT(message) + (X^n-1)*pad.
    coeffs = [T.transform([(x, 0) for x in row], True) for row in messages]
    columns = []
    roots = T.subgroup(domain)
    for index in indices:
        x = 7*roots[index] % P
        columns.append([(T.evaluate(f, x)[0] + (pow(x, n, P)-1)*T.evaluate([(v, 0) for v in pad], x)[0]) % P
                        for f, pad in zip(coeffs, pads)])
    view = F.EndpointView(folds, vectors, weights, cw, terminal, indices, columns, n, budget, domain)
    return view, messages[:2]


class AffineCoordinates(unittest.TestCase):
    def test_free_coordinates_are_bijective_and_equations_hold(self):
        matrix = [[2, 3, 4, 5], [7, 11, 13, 17]]
        fibre = F.LinearFibre(matrix)
        self.assertEqual(len(fibre.free), 2)
        seen = set()
        for a in range(5):
            for b in range(5):
                out = fibre.solve([19, 23], [a, b])
                self.assertEqual([sum(x*y for x, y in zip(row, out)) % P for row in matrix], [19, 23])
                self.assertEqual([out[i] for i in fibre.free], [a, b])
                seen.add(tuple(out))
        self.assertEqual(len(seen), 25)
        with self.assertRaisesRegex(ValueError, "deficient"):
            F.LinearFibre([[1, 2], [2, 4]])

    def test_polynomial_fibre_preserves_values_and_has_full_free_dimension(self):
        xs, ys, budget = [3, 7, 11], [17, 23, 31], 5
        rng = random.Random(2402)
        draws = [F.conditional_poly(xs, ys, budget, rng.randrange) for _ in range(3)]
        for poly in draws:
            self.assertEqual([T.evaluate([(v, 0) for v in poly], x)[0] for x in xs], ys)
        self.assertEqual(len({tuple(p) for p in draws}), 3)
        # Difference divided by the vanishing polynomial recovers two independent
        # free coefficients. Leading coefficient is the last sampled h coordinate.
        h = iter([41, 53])
        poly = F.conditional_poly(xs, ys, budget, lambda _: next(h))
        self.assertEqual(poly[-1], 53)
        particular = T.interpolate(xs, [(y, 0) for y in ys])
        vanish = T.roots_poly(xs)
        expected = [0]*budget
        for i, x in enumerate(particular):
            expected[i] = x[0]
        for i, x in enumerate(vanish):
            for j, y in enumerate([41, 53]):
                expected[i+j] = (expected[i+j] + x[0]*y) % P
        self.assertEqual(poly, expected)

    def test_full_budget_unique_polynomial_and_invalid_inputs(self):
        def no_random(_):
            self.fail("zero-dimensional fibre sampled randomness")
        poly = F.conditional_poly([3, 7], [11, 13], 2, no_random)
        self.assertEqual([T.evaluate([(x, 0) for x in poly], j)[0] for j in (3, 7)], [11, 13])
        self.assertEqual(F.conditional_poly([], [], 3, lambda _: 17), [17]*3)
        for xs, ys, budget in [([1, 1], [2, 2], 2), ([1, 2], [3, 4], 1), ([True], [2], 1)]:
            with self.assertRaises(ValueError):
                F.conditional_poly(xs, ys, budget)


class ConditionalEndpoint(unittest.TestCase):
    def test_two_different_data_choices_preserve_complete_public_view(self):
        view, original = fixture()
        snapshots = copy.deepcopy(view)
        results = []
        for data in (original, [[0]*view.n for _ in range(2)]):
            sampled = F.sample(view, data, random.Random(2403).randrange)
            self.assertEqual(sampled["message"][:2], data)
            self.assertEqual(sampled["message_free_dim"], 8)
            self.assertEqual(sampled["pad_free_dim"], 3)  # 3*(4-3 distinct columns)
            self.assertEqual(F.verify_sample(view, data, sampled), view.columns)
            results.append(sampled)
        self.assertNotEqual(results[0]["message"], results[1]["message"])
        self.assertEqual(view, snapshots)

    def test_fresh_draws_and_owners_keep_same_chosen_data(self):
        data = [[r + j*j for j in range(8)] for r in range(2)]
        views = [fixture(seed=seed)[0] for seed in (2404, 2405)]
        draws = [F.sample(view, data, random.Random(seed).randrange)
                 for view, seed in zip(views, (2406, 2407))]
        self.assertEqual(draws[0]["message"][:2], draws[1]["message"][:2])
        self.assertNotEqual(draws[0]["message"][2:], draws[1]["message"][2:])
        self.assertNotEqual(draws[0]["pads"], draws[1]["pads"])
        again = F.sample(views[0], data, random.Random(2408).randrange)
        self.assertNotEqual(draws[0]["message"][2:], again["message"][2:])

    def test_corrupted_terminal_vector_column_and_claim_refuse(self):
        view, data = fixture()
        bad = copy.deepcopy(view)
        bad.claim_value = C.f2_add(bad.claim_value, (1, 0))
        with self.assertRaisesRegex(ValueError, "terminal"):
            F.sample(bad, data)
        bad = copy.deepcopy(view)
        bad.vectors[1][0] = C.f2_add(bad.vectors[1][0], (1, 0))
        with self.assertRaisesRegex(ValueError, "fold/column"):
            F.sample(bad, data)
        bad = copy.deepcopy(view)
        bad.columns[1][0] = (bad.columns[1][0]+1) % P
        with self.assertRaisesRegex(ValueError, "fold/column"):
            F.sample(bad, data)
        bad = copy.deepcopy(view)
        bad.claim_weights = list(bad.claim_weights)
        bad.claim_weights[0] = C.f2_add(bad.claim_weights[0], (1, 0))
        with self.assertRaisesRegex(ValueError, "single folded claim"):
            F.sample(bad, data)

    def test_deficient_masks_duplicate_and_noncanonical_data_refuse(self):
        view, data = fixture(deficient=True)
        with self.assertRaisesRegex(ValueError, "deficient"):
            F.sample(view, data)
        view, data = fixture()
        view.columns[-1][0] = (view.columns[-1][0]+1) % P
        with self.assertRaisesRegex(ValueError, "duplicate"):
            F.sample(view, data)
        for value in (True, -1, P):
            view, data = fixture()
            data[0][0] = value
            with self.subTest(value=value), self.assertRaisesRegex(ValueError, "dummy data"):
                F.sample(view, data)

    def test_independent_verification_detects_changed_masks_pads_and_data(self):
        view, data = fixture()
        original = F.sample(view, data, random.Random(2409).randrange)
        for section, row in (("message", 2), ("pads", 0), ("message", 0)):
            bad = copy.deepcopy(original)
            bad[section][row][0] = (bad[section][row][0]+1) % P
            with self.subTest(section=section, row=row), self.assertRaises(ValueError):
                F.verify_sample(view, data, bad)


if __name__ == "__main__":
    unittest.main()

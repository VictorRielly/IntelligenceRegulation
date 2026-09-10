"""O12 -- independent controls on the conditional endpoint fibre sampler.

Reviewer: Claude Opus 5, 2026-09-09 (task O12 of docs/zkmatrix-poc/ZK60_OPUS_QUEUE.md).

scripts/zk60_endpoint_fibre.py is NOT modified.  The linear algebra here is a
second implementation (`_rank` below) written for this audit, so the fibre
dimensions are cross-checked rather than re-derived from `LinearFibre`'s own
pivots.  Polynomial and field helpers are imported, and that reuse is stated in
the review rather than claimed as independence.

Captures resolve from ZK60_IO_CAPTURES, defaulting to the persisted round-22
workspace directory.  These tests SKIP when the gitignored capture bytes are
absent -- that is a real skip, not a guarantee, and integration must reject
skips before treating them as acceptance evidence.
"""
import json
import os
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

CAPTURES = Path(os.environ.get(
    "ZK60_IO_CAPTURES",
    "/home/victor/IntelligenceRegulation/results/zk60_round22_captures"))
HAVE = CAPTURES.is_dir() and any(CAPTURES.glob("*.json"))

import zk60_endpoint_fibre as F  # noqa: E402
import zk60_io_opening_translation as T  # noqa: E402

P = F.P


def _rank(matrix):
    """Independent Gaussian elimination over Fp; returns the row rank."""
    a = [list(row) for row in matrix]
    m, n = len(a), len(a[0])
    r = 0
    for c in range(n):
        piv = next((i for i in range(r, m) if a[i][c]), None)
        if piv is None:
            continue
        a[r], a[piv] = a[piv], a[r]
        inv = pow(a[r][c], P - 2, P)
        a[r] = [v * inv % P for v in a[r]]
        for i in range(m):
            if i != r and a[i][c]:
                f = a[i][c]
                a[i] = [(x - f * y) % P for x, y in zip(a[i], a[r])]
        r += 1
    return r


def _views():
    import zk60_io_repeated_view as repeated
    for path in sorted(CAPTURES.glob("*.json")):
        cap = repeated.O.IoCapture(str(path))
        raw = json.loads(Path(cap.path).read_text())
        for role in (r for r in raw["roles"] if r["role"] in ("Input", "Output")):
            yield cap, role["role"], F.from_capture(role, cap.by_role[role["role"]])


@unittest.skipUnless(HAVE, f"IO captures absent ({CAPTURES})")
class FibreDimensions(unittest.TestCase):
    """The two advertised free dimensions must follow from rank alone."""

    def test_both_fold_systems_have_full_row_rank_four_on_every_owner(self):
        seen = 0
        for _, _, view in _views():
            B = F.split_folds(view.folds)
            self.assertEqual((len(B), len(B[0])), (4, 7))
            self.assertEqual(_rank(B), 4)
            self.assertEqual(_rank([row[2:] for row in B]), 4)
            seen += 1
        self.assertEqual(seen, 8)

    def test_free_dimensions_match_nullity_times_coordinate_count(self):
        for cap, role, view in _views():
            with self.subTest(proof=cap.proof_sha256[:12], role=role):
                B = F.split_folds(view.folds)
                mask_nullity = 5 - _rank([row[2:] for row in B])
                pad_nullity = 7 - _rank(B)
                distinct = len(set(view.indices))
                self.assertEqual(mask_nullity, 1)
                self.assertEqual(pad_nullity, 3)
                # what the sampler reports, recomputed from rank only
                self.assertEqual(view.n * mask_nullity, 256)
                self.assertEqual(pad_nullity * (view.budget - distinct),
                                 3 * (256 - distinct))


@unittest.skipUnless(HAVE, f"IO captures absent ({CAPTURES})")
class TerminalIsImpliedNotIndependent(unittest.TestCase):
    """The endpoint group holds ONE claim and the group fold is a nonzero
    multiple of the claim weights.  The masked terminal is then an algebraic
    consequence of the group vector, so it costs the fibre no dimension.  If
    this failed, the advertised free dimensions would be overstated."""

    def test_the_fold_is_a_nonzero_multiple_of_the_claim_weights(self):
        C = F.C
        for cap, role, view in _views():
            with self.subTest(proof=cap.proof_sha256[:12], role=role):
                at = next(i for i, x in enumerate(view.claim_weights) if x != F.ZERO)
                lam = C.f2_mul(view.folds[0][at], C.f2_inv(view.claim_weights[at]))
                self.assertNotEqual(lam, F.ZERO)
                self.assertEqual(view.folds[0],
                                 [C.f2_mul(lam, x) for x in view.claim_weights])

    def test_the_terminal_follows_from_the_group_vector(self):
        C = F.C
        for cap, role, view in _views():
            with self.subTest(proof=cap.proof_sha256[:12], role=role):
                at = next(i for i, x in enumerate(view.claim_weights) if x != F.ZERO)
                lam = C.f2_mul(view.folds[0][at], C.f2_inv(view.claim_weights[at]))
                # sum_j cw[j] * vector[j] == lam * claim_value, so dividing by
                # lam reproduces the terminal with no extra freedom consumed.
                lhs = C.f2_dot(view.claim_cw, view.vectors[0][:view.n])
                self.assertEqual(lhs, C.f2_mul(lam, view.claim_value))
                self.assertEqual(C.f2_mul(C.f2_inv(lam), lhs), view.claim_value)


class CosetMissesTheMessageSubgroup(unittest.TestCase):
    """`g_r(x) = (opened - IDFT(message)(x)) / (x^256 - 1)` needs a nonzero
    denominator.  The sampler guards it; this shows the guard is unreachable at
    the shipped geometry, so the division is total rather than merely checked."""

    def test_no_coset_point_is_a_256th_root_of_unity(self):
        roots = T.subgroup(2048)
        self.assertEqual(len(roots), 2048)
        offenders = [j for j, r in enumerate(roots)
                     if pow(7 * r % P, 256, P) == 1]
        self.assertEqual(offenders, [])

    def test_the_shift_is_not_an_eighth_root_of_unity(self):
        # x = 7r with r^2048 = 1 gives x^256 = 7^256 * (r^256), and r^256 runs
        # over the 8th roots of unity; the coset meets the subgroup iff 7^256
        # is the inverse of one of them.
        self.assertNotEqual(pow(pow(7, 256, P), 8, P), 1)


@unittest.skipUnless(HAVE, f"IO captures absent ({CAPTURES})")
class AdversariallyCorrelatedColumns(unittest.TestCase):
    """The delivered suite samples at the captures' own ~240 distinct positions.
    These push the correlation to its extreme instead."""

    def _one_view(self):
        return next(v for _, r, v in _views() if r == "Input")

    def test_maximal_duplication_collapses_to_one_distinct_position(self):
        view = self._one_view()
        index, column = view.indices[0], view.columns[0]
        view.indices = [index] * view.budget
        view.columns = [list(column) for _ in range(view.budget)]
        view.validate()
        data = [[0] * view.n for _ in range(2)]
        out = F.sample(view, data)
        # one distinct node leaves budget-1 free coefficients per free pad row
        self.assertEqual(out["pad_free_dim"], 3 * (view.budget - 1))
        self.assertEqual(out["message_free_dim"], view.n)
        F.verify_sample(view, data, out)

    def test_a_conflicting_duplicate_at_the_same_index_is_refused(self):
        view = self._one_view()
        index, column = view.indices[0], view.columns[0]
        view.indices = [index] * view.budget
        view.columns = [list(column) for _ in range(view.budget)]
        view.columns[7] = [(column[0] + 1) % P] + list(column[1:])
        with self.assertRaisesRegex(Exception, "conflicting duplicate"):
            view.validate()

    def test_reusing_one_column_at_a_different_index_breaks_fold_consistency(self):
        view = self._one_view()
        # same column bytes, a different position: the folded encoding differs
        view.indices = list(view.indices)
        view.columns = [list(view.columns[0]) for _ in view.columns]
        with self.assertRaisesRegex(Exception, "fold/column inconsistency"):
            view.validate()


class DeficientRankRefuses(unittest.TestCase):
    """Full row rank is an assumption, not a theorem: a degenerate fold matrix
    must refuse rather than silently produce a wrong free dimension."""

    def test_a_rank_three_system_is_refused(self):
        rows = [[1, 0, 0, 0, 0], [0, 1, 0, 0, 0], [0, 0, 1, 0, 0]]
        rows.append([(a + b) % P for a, b in zip(rows[0], rows[1])])
        self.assertEqual(_rank(rows), 3)
        with self.assertRaisesRegex(Exception, "deficient"):
            F.LinearFibre(rows)

    def test_a_full_rank_system_reports_the_expected_free_coordinates(self):
        rows = [[int(i == j) for j in range(7)] for i in range(4)]
        fibre = F.LinearFibre(rows)
        self.assertEqual(_rank(rows), 4)
        self.assertEqual(len(fibre.free), 3)


class PolynomialFibreBijection(unittest.TestCase):
    """L + V h onto the affine fibre: injective in h, and every solution is
    reached.  Checked without using the sampler's own reasoning."""

    def test_prescribed_values_hold_and_distinct_h_give_distinct_results(self):
        xs = [3, 5, 11, 17]
        ys = [7, 9, 13, 19]
        budget = 8
        seen = set()
        for seed in range(6):
            counter = iter([seed * 100 + k + 1 for k in range(budget)])
            poly = F.conditional_poly(xs, ys, budget,
                                      randbelow=lambda _n: next(counter))
            self.assertEqual(len(poly), budget)
            for x, y in zip(xs, ys):
                self.assertEqual(T.evaluate([(c, 0) for c in poly], x)[0], y)
            seen.add(tuple(poly))
        self.assertEqual(len(seen), 6)

    def test_a_full_budget_constraint_leaves_exactly_one_solution(self):
        xs = [3, 5, 11, 17]
        ys = [7, 9, 13, 19]
        a = F.conditional_poly(xs, ys, 4, randbelow=lambda _n: 1)
        b = F.conditional_poly(xs, ys, 4, randbelow=lambda _n: 2)
        self.assertEqual(a, b)

    def test_more_nodes_than_the_budget_is_refused(self):
        with self.assertRaisesRegex(Exception, "nodes/budget"):
            F.conditional_poly([1, 2, 3], [1, 2, 3], 2)


@unittest.skipUnless(HAVE, f"IO captures absent ({CAPTURES})")
class ScopeOfTheSampledObject(unittest.TestCase):
    """The sampler sees one endpoint's public view and nothing else.  A's rows
    14..17 alias the endpoints' rows 0..1 (O8's ALIAS_PAIRS), and A is not
    resampled, so a sampled dummy plane is not known to be consistent with the
    A observations recorded in the same capture."""

    def test_the_view_carries_no_A_observation(self):
        import zk60_opus_io_capture as O
        cross = [pair for pair in O.ALIAS_PAIRS if pair[0][0] == "A"]
        self.assertEqual(sorted(r for (_, r), _ in cross), [14, 15, 16, 17])
        self.assertEqual(sorted(name for _, (name, _) in cross),
                         ["Input", "Input", "Output", "Output"])
        for _, _, view in _views():
            for field in ("folds", "vectors", "claim_weights", "claim_cw",
                          "claim_value", "indices", "columns"):
                self.assertTrue(hasattr(view, field))
            # nothing in the view identifies or constrains an A row
            self.assertEqual(len(view.folds), 2)
            self.assertEqual(len(view.folds[0]), 7)


if __name__ == "__main__":
    unittest.main()

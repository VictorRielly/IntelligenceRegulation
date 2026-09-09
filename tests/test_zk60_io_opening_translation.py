"""Independent small-field-geometry checks and failure controls for round 20.

Goldilocks arithmetic remains full width. Real capture checks are a separate
mandatory CLI run; these unit tests do not silently skip when /tmp is absent.
"""
import importlib.util
import sys
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))
SPEC = importlib.util.spec_from_file_location("opening_translation", SCRIPTS / "zk60_io_opening_translation.py")
T = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(T)
C, P, ZERO, ONE = T.C, T.P, T.ZERO, T.ONE


def naive_mul(a, b):
    out = [ZERO] * (len(a) + len(b) - 1)
    for i, x in enumerate(a):
        for j, y in enumerate(b):
            out[i+j] = C.f2_add(out[i+j], C.f2_mul(x, y))
    return out


class PolynomialArithmetic(unittest.TestCase):
    def test_fft_matches_direct_dft(self):
        rng = C.Rng(2001)
        for n in (1, 2, 8, 32):
            coeffs = [rng.fp2() for _ in range(n)]
            direct = [T.evaluate(coeffs, x) for x in T.subgroup(n)]
            self.assertEqual(T.transform(coeffs), direct)
            self.assertEqual(T.transform(direct, True), coeffs)

    def test_inverse_matches_archived_dense_idft(self):
        rng = C.Rng(2002)
        values = [rng.fp2() for _ in range(16)]
        expected = [C.f2_dot([(x, 0) for x in row], values) for row in C.idft_rows(16)]
        self.assertEqual(T.transform(values, True), expected)

    def test_products_match_schoolbook(self):
        rng = C.Rng(2003)
        for a, b in ((1, 1), (7, 13), (32, 32)):
            x, y = [rng.fp2() for _ in range(a)], [rng.fp2() for _ in range(b)]
            self.assertEqual(T.mul(x, y), naive_mul(x, y))

    def test_interpolation_and_coset_order(self):
        poly = [(P-i-1, i+7) for i in range(13)]
        xs = [7*x % P for x in T.subgroup(128)]
        ys = [T.evaluate(poly, x) for x in xs]
        self.assertEqual(T.interpolate(xs[:13], ys[:13]), poly)
        self.assertEqual(T.coset_evals(poly, 128), ys)
        self.assertEqual(xs, C.coset_points(4))

    def test_duplicate_interpolation_nodes_refuse(self):
        with self.assertRaisesRegex(ValueError, "interpolation nodes"):
            T.interpolate([7, 7], [ONE, ZERO])


class PcsTranslation(unittest.TestCase):
    def test_general_multicolumn_kernel_preserves_both_full_vectors(self):
        # Two unrelated Fp2 folds over seven Fp rows, two independent kernel
        # directions with distinct column patterns: not a single tensor fixture.
        rng = C.Rng(2010)
        folds = [[rng.fp2() for _ in range(7)] for _ in range(2)]
        matrix = [[x[part] for x in row] for row in folds for part in (0, 1)]
        basis = C.R.null_space(matrix, 7)
        self.assertGreaterEqual(len(basis), 2)
        messages = [[((basis[0][r]*(j*j+2) + basis[1][r]*(j*j*j+3)) % P, 0)
                     for j in range(8)] for r in range(7)]
        indices = [0, 7, 13, 29, 7]
        pads = [T.pcs_pad(msg, indices, 64, 4) for msg in messages]
        for fold in folds:
            for j in range(12):
                got = ZERO
                for r in range(7):
                    got = C.f2_add(got, C.f2_mul(fold[r], (messages[r]+pads[r])[j]))
                self.assertEqual(got, ZERO)
        for msg, pad in zip(messages, pads):
            # Direct evaluation of f + (X^n - 1)g, without pcs_poly/FFT encoding.
            f = T.transform(msg, True)
            for j in set(indices):
                x = 7*T.subgroup(64)[j] % P
                got = C.f2_add(T.evaluate(f, x), C.f2_mul_base(T.evaluate(pad, x), (pow(x, 8, P)-1) % P))
                self.assertEqual(got, ZERO)

    def test_budget_counts_distinct_samples(self):
        msg = [(i+1, 0) for i in range(8)]
        self.assertEqual(T.pcs_pad(msg, [1, 1, 3], 64, 2), T.pcs_pad(msg, [1, 3], 64, 2))
        with self.assertRaisesRegex(ValueError, "exceed pad budget"):
            T.pcs_pad(msg, [1, 3, 7], 64, 2)

    def test_missing_pad_and_second_sample_set_reveal_difference(self):
        msg = [ONE] * 8  # f(X) = 1
        indices = [1, 5, 9]
        pad = T.pcs_pad(msg, indices, 64, 3)
        enc = T.coset_evals(T.pcs_poly(msg, pad), 64)
        self.assertTrue(all(enc[j] == ZERO for j in indices))
        self.assertTrue(any(enc[j] != ZERO for j in range(64) if j not in indices))
        no_pad = T.coset_evals(T.pcs_poly(msg, [ZERO]*3), 64)
        self.assertTrue(all(no_pad[j] != ZERO for j in indices))


class MaskTranslation(unittest.TestCase):
    def test_every_prefix_basis_extends_and_matches_dense_lagrange(self):
        m, length, pads, indices = 16, 4, 6, [0, 5, 11, 17, 29, 41, 5]
        for k in range(length):
            prefix = [ZERO] * length
            prefix[k] = (P-3, 19)
            a = T.mask_lift(prefix, indices, m, pads, 128)
            msg = T.transform(a)
            self.assertEqual(msg[:length], prefix)
            self.assertEqual(msg[length+pads:], [ZERO]*(m-length-pads))
            for j in set(indices):
                x = C.coset_points(4)[j]
                dense = C.f2_dot([(v, 0) for v in C.lagrange_on_subgroup(m, x)], msg)
                self.assertEqual(dense, ZERO)
                self.assertEqual(T.evaluate(a, x), ZERO)

    def test_joint_two_slot_blinders_and_all_column_rows(self):
        rng = C.Rng(2020)
        m, length, pads, indices = 16, 4, 6, [0, 3, 7, 13, 27, 55]
        weights = [[rng.fp2() for _ in range(length)] for _ in range(2)]
        kernel = C.f2_null_space([weights[0] + weights[1]], 2*length)
        delta = [C.f2_add(x, C.f2_mul((3, 9), y)) for x, y in zip(kernel[0], kernel[-1])]
        a = [T.mask_lift(delta[i*length:(i+1)*length], indices, m, pads, 128) for i in range(2)]
        w = [T.transform(v + [ZERO]*(m-length), True) for v in weights]
        rhos = [rng.fp2() for _ in range(6)]
        b, u = T.mask_blinders(a, w, rhos)
        self.assertEqual(C.f2_add(b[0], b[m]), ZERO)
        # Independently recompute every q/prox coefficient using schoolbook.
        qd = b[:]
        for x, y in zip(a, w):
            for j, v in enumerate(naive_mul(x, y)):
                qd[j] = C.f2_add(qd[j], v)
        self.assertEqual(qd, [ZERO]*(2*m))
        for j in range(2*m):
            base = [v for poly in a + [b] for v in (poly[j] if j < len(poly) else ZERO)]
            pd = u[j]
            for rho, val in zip(rhos, base):
                pd = C.f2_add(pd, C.f2_mul_base(rho, val))
            self.assertEqual(pd, ZERO)
        for poly in a + [b, u]:
            for j in indices:
                self.assertEqual(T.evaluate(poly, C.coset_points(4)[j]), ZERO)

    def test_nonzero_functional_forces_invalid_b(self):
        m, prefix, wmsg = 8, [ONE, ZERO], [ONE, ZERO]
        a = T.mask_lift(prefix, [0, 3], m, 2, 64)
        w = T.transform(wmsg + [ZERO]*(m-len(wmsg)), True)
        b, _ = T.mask_blinders([a], [w], [(2, 3)]*4)
        self.assertEqual(C.f2_mul_base(C.f2_add(b[0], b[m]), m), C.f2_neg(ONE))

    def test_omitting_b_or_u_breaks_full_vectors(self):
        a = T.mask_lift([ONE, C.f2_neg(ONE)], [0, 3], 8, 2, 64)
        w = T.transform([ONE, ONE]+[ZERO]*6, True)
        b, u = T.mask_blinders([a], [w], [(2, 3), (5, 7), (11, 13), (17, 19)])
        self.assertEqual(C.f2_add(b[0], b[8]), ZERO)
        self.assertTrue(any(x != ZERO for x in b))
        self.assertTrue(any(x != ZERO for x in u))

    def test_too_many_columns_have_dense_disclosure(self):
        good = C.m_columns_model(3, 2, 2, [0, 3])
        bad = C.m_columns_model(3, 2, 2, [0, 3, 7])
        self.assertEqual(good["disclosed_coefficient_functionals"], 0)
        self.assertGreater(bad["disclosed_coefficient_functionals"], 0)
        with self.assertRaisesRegex(ValueError, "exceed pad budget"):
            T.mask_lift([ONE, ZERO], [0, 3, 7], 8, 2, 64)

    def test_same_commitment_second_opening_needs_different_b(self):
        # Both W's have the same zero functional on this prefix, but the full
        # product polynomials differ. A single reused b cannot hide both.
        prefix = [ONE, C.f2_neg(ONE)]
        a = T.mask_lift(prefix, [0, 3], 8, 2, 64)
        w = T.transform([ONE, ONE]+[ZERO]*6, True)
        b1, _ = T.mask_blinders([a], [w], [(2, 3)]*4)
        b2, _ = T.mask_blinders([a], [[C.f2_mul_base(x, 2) for x in w]], [(2, 3)]*4)
        self.assertNotEqual(b1, b2)
        dense = C.m_joint_model(3, 2, 2, [ONE, ONE], [0, 3], [(2, 3)]*4)
        self.assertEqual(dense["disclosed_fp_dim"], 2)


if __name__ == "__main__":
    unittest.main()

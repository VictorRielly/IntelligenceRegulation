import unittest

import numpy as np

from gpu_integer import split_words


class SignedByteDecompositionTests(unittest.TestCase):
    def test_all_signed16_words_and_signed24_boundaries_reconstruct(self):
        values = np.concatenate((np.arange(-32768, 32768),
                                 np.array([-(1 << 23), -(1 << 23) + 1, -65537, 65535, 65536, (1 << 23) - 1])))
        for source in (values[:65536], values):
            parts, offset = split_words(source.astype(np.float64))
            got = sum(p.astype(np.int64) * (1 << (8 * i)) for i, p in enumerate(parts)) + offset
            np.testing.assert_array_equal(got, source)

    def test_dot_recombination_matches_independent_int64_dot(self):
        rng = np.random.default_rng(93)
        for bound in (32768, 1 << 23):
            x = rng.integers(-bound, bound, (17, 33), dtype=np.int64)
            weights = rng.integers(-127, 128, (33, 35), dtype=np.int8)
            parts, offset = split_words(x)
            actual = sum((p.astype(np.int64) @ weights.astype(np.int64)) * (1 << (8 * i)) for i, p in enumerate(parts))
            actual += offset * weights.astype(np.int64).sum(0)
            np.testing.assert_array_equal(actual, x @ weights.astype(np.int64))

    def test_noninteger_nonfinite_and_out_of_domain_inputs_refuse(self):
        for bad in (np.array([.5]), np.array([float('nan')]), np.array([float('inf')]), np.array([1 << 23]), np.array([-(1 << 23) - 1])):
            with self.assertRaises(ValueError):
                split_words(bad)


if __name__ == '__main__':
    unittest.main()

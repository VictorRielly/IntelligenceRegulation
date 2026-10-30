import unittest

import numpy as np

import calibration_port as P
from cached_integer import CachedMat, prepare


class CachedIntegerTests(unittest.TestCase):
    def test_signed_words_and_partial_last_block_are_bit_identical(self):
        rng = np.random.default_rng(7)
        weights = rng.integers(-127, 128, (9, 2053), dtype=np.int8)
        original = P.fl.Mat(weights)
        original.big, original.m64 = True, None
        cached = CachedMat(original)
        x = rng.integers(-(1 << 23), 1 << 23, (2, 3, 9)).astype(np.float64)
        np.testing.assert_array_equal(cached(x), original(x))
        np.testing.assert_array_equal(weights, original.m)
        self.assertEqual([block.shape[1] for _, block in cached.blocks], [2048, 5])

    def test_small_matrices_are_preserved_and_prepare_is_idempotent(self):
        class Model:
            pass
        model = Model()
        small = P.fl.Mat(np.eye(3, dtype=np.int8))
        large = P.fl.Mat(np.ones((3, 4), dtype=np.int8))
        large.big, large.m64 = True, None
        model.int = {'q': small, 'g': large}
        self.assertIs(prepare(model), model)
        self.assertIs(model.int['q'], small)
        cached = model.int['g']
        prepare(model)
        self.assertIs(model.int['g'], cached)


if __name__ == '__main__':
    unittest.main()

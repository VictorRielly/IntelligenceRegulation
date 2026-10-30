from fractions import Fraction
import unittest
import numpy as np
from fix_layer25 import extended_groups, requantize_up


class Layer25RepairTests(unittest.TestCase):
    def test_up_words_match_rational_rounding_and_keep_four_bit_multiplier(self):
        real = np.array([[-127, -2, 0, 127], [63, 1, 0, -65]], dtype=np.float32)
        words, mult = requantize_up(real)
        for i in range(2):
            for j in range(4):
                expected = Fraction(int(real[i, j]) * 8, int(mult[j])) + Fraction(1, 2)
                self.assertEqual(int(words[i, j]), expected.numerator // expected.denominator)
        self.assertTrue(np.all((mult >= 1) & (mult <= 16)))
        with self.assertRaises(ValueError):
            requantize_up(np.full((2, 4), 1000))

    def test_extra_range_fits_four_groups_with_exact_tables(self):
        maxima = np.array([.1, .5, 1, 3, 7, 15, 75.])
        st = {'gate_max': maxima, 'gate_pos': 40., 'gate_neg': 75.,
              'actc_max': maxima / 2, 'act_max': 40.}
        ej, eo, members, ids, tables = extended_groups(st)
        self.assertEqual(ej[-1], 0)
        self.assertEqual(eo[-1], -8)
        self.assertLessEqual(len(members), 4)
        self.assertEqual(tables.shape, (len(members), 4096))
        self.assertTrue(np.all(np.floor(-maxima / 2.**(ej-4) + .5) >= -2048))


if __name__ == '__main__':
    unittest.main()

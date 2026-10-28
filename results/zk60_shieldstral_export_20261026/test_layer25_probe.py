import unittest
import numpy as np

from probe_layer25 import CHANNELS, GateRecorder


class GateDiagnosticTests(unittest.TestCase):
    def test_preserves_preclamp_words_and_records_refusal(self):
        values = np.zeros((1, 2, 9216))
        values[0, 0, CHANNELS[0]] = -2300
        values[0, 1, CHANNELS[1]] = 2050
        rec = GateRecorder()
        clamped = rec.check('FFN gate', values, -2048, 2047, 0, True)
        self.assertEqual(clamped[0, 0, CHANNELS[0]], -2048)
        self.assertEqual(clamped[0, 1, CHANNELS[1]], 2047)
        self.assertEqual(rec.gate['channels'][str(CHANNELS[0])]['words'], [-2300, 0])
        self.assertEqual(rec.gate['violations_all_channels'], 2)
        self.assertIsNotNone(rec.first[0])

    def test_int12_endpoints_accepted_and_signed16_amendment_retained(self):
        values = np.zeros((1, 2, 9216))
        values[0, :, CHANNELS[0]] = [-2048, 2047]
        rec = GateRecorder()
        rec.check('FFN gate', values, -2048, 2047, 0, True)
        rec.check('Q', np.array([[[-32768.0]]]), -32767, 32767, 0, True)
        self.assertEqual(rec.gate['violations_all_channels'], 0)
        self.assertIsNone(rec.first[0])


if __name__ == '__main__':
    unittest.main()

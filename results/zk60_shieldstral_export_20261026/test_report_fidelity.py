import json
import unittest

import numpy as np

from report_fidelity import audit_journal, D


class CoverageAuditTests(unittest.TestCase):
    def setUp(self):
        self.offsets = np.array([0, 2, 5])
        self.entry = {'first_item': 0, 'end_item': 2, 'byte_start': 0, 'byte_end': 5 * D * 2,
                      'diagnostics': [{'item': i, 'refused': False, 'first_site': None, 'violations': {}} for i in range(2)]}

    def audit(self):
        return audit_journal((json.dumps(self.entry) + '\n').encode(), self.offsets)

    def test_missing_sequence_diagnostics_cannot_claim_zero_refusals(self):
        self.entry['diagnostics'].pop()
        with self.assertRaisesRegex(ValueError, 'omitted or duplicated'):
            self.audit()

    def test_hidden_refusal_is_rejected(self):
        self.entry['diagnostics'][1]['violations'] = {'FFN gate': {'violations': 3}}
        with self.assertRaisesRegex(ValueError, 'refusal flag'):
            self.audit()

    def test_range_and_refusal_count_preserved(self):
        self.entry['diagnostics'][1].update(refused=True, first_site='FFN gate', violations={'FFN gate': {'violations': 3}})
        result = self.audit()
        self.assertEqual(result['refused_items'], [1])
        self.assertEqual(result['violations_by_site'], {'FFN gate': 3})
        self.entry['byte_end'] -= 2
        with self.assertRaisesRegex(ValueError, 'byte range'):
            self.audit()

    def test_live_partial_tail_is_not_counted_or_repaired(self):
        raw = (json.dumps(self.entry) + '\n{"first_item":2').encode()
        result = audit_journal(raw, self.offsets)
        self.assertEqual(result['items'], 2)
        self.assertTrue(result['incomplete_journal_tail'])


if __name__ == '__main__':
    unittest.main()

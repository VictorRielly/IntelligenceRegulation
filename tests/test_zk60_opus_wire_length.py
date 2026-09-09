"""Tests for the independent fresh-FFN wire length model (review O5).

Reviewer: Opus 5.  Source pin 29d34362f54a8539799a6f7a74211dd43aed15cc.

These tests pin the model against the two frame sizes round 17 states for the
largest allowed shape, the two frame sizes its process check actually recorded,
and the committed row counts of the round-16 captures.  They compare three
independent transcriptions (the closed form in ``Shape::len``, the payload
writer and the decoder cursor) against each other over the whole allowed shift
window.  Nothing here is a cryptographic, soundness or privacy claim.
"""

import itertools
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))), "scripts"))

import zk60_opus_wire_length as wire  # noqa: E402

PROFILE_SHIFTS = (7, 0, 14, 6)
MAX_SHIFTS = (16, 16, 16, 16)

# ZK60_ROUND17.md "Format and trust boundary": the largest allowed shape.
STATED_MAX_P1 = 16_486_717
STATED_MAX_P3 = 16_523_677
STATED_MAX_A_ROWS = 2609
STATED_MAX_H_ROWS = 5154

# ZK60_ROUND17.md "Validation" / results/zk60_round17_validation.json: the
# frames the separate-process run actually wrote.
RECORDED_P1 = 4_733_245
RECORDED_P3 = 4_770_205

# results/zk60_round16_captures.json (O1): the committed row counts.
CAPTURED_A_ROWS = 698
CAPTURED_H_ROWS = 1326
CAPTURED_W_ROWS_P3 = 11
CAPTURED_W_ROWS_P1 = 3


class WireLengthModel(unittest.TestCase):
    def test_models_agree_on_the_profile_shape(self):
        for private in (False, True):
            got = wire.all_models(PROFILE_SHIFTS, private)
            self.assertEqual(len(set(got.values())), 1, got)

    def test_recorded_frames_reproduce_exactly(self):
        self.assertEqual(wire.shape_len(PROFILE_SHIFTS, False), RECORDED_P1)
        self.assertEqual(wire.shape_len(PROFILE_SHIFTS, True), RECORDED_P3)
        self.assertEqual(wire.writer_len(PROFILE_SHIFTS, False), RECORDED_P1)
        self.assertEqual(wire.writer_len(PROFILE_SHIFTS, True), RECORDED_P3)
        self.assertEqual(wire.reader_len(PROFILE_SHIFTS, False), RECORDED_P1)
        self.assertEqual(wire.reader_len(PROFILE_SHIFTS, True), RECORDED_P3)

    def test_stated_maxima_reproduce_exactly(self):
        zl = wire.zk_layout(MAX_SHIFTS)
        self.assertEqual(zl["a_rows"], STATED_MAX_A_ROWS)
        self.assertEqual(zl["h_rows"], STATED_MAX_H_ROWS)
        for name, value in wire.all_models(MAX_SHIFTS, False).items():
            self.assertEqual(value, STATED_MAX_P1, name)
        for name, value in wire.all_models(MAX_SHIFTS, True).items():
            self.assertEqual(value, STATED_MAX_P3, name)

    def test_maximum_uses_four_shift_16_remainder_tables(self):
        """All four remainder tables are at their largest in the max frame."""
        slots = wire.zk_layout(MAX_SHIFTS)["slots"]
        self.assertEqual(len(slots), 6)
        # ACT16 (256 entries -> 1 row), INT16 (2^16 -> 256 rows), then four
        # remainder windows of 2^16 rows each.
        self.assertEqual([s["rows"] for s in slots], [1, 256, 256, 256, 256, 256])
        self.assertEqual([s["size"] for s in slots[2:]], [1 << 16] * 4)

    def test_captured_row_counts(self):
        zl = wire.zk_layout(PROFILE_SHIFTS)
        self.assertEqual(zl["a_rows"], CAPTURED_A_ROWS)
        self.assertEqual(zl["h_rows"], CAPTURED_H_ROWS)
        self.assertEqual(zl["w_rows_p3"], CAPTURED_W_ROWS_P3)
        self.assertEqual(zl["w_rows_p1"], CAPTURED_W_ROWS_P1)

    def test_envelope_is_exactly_41_bytes_over_the_payload(self):
        for shifts in (PROFILE_SHIFTS, MAX_SHIFTS, (-8, -8, -8, -8)):
            for private in (False, True):
                terms = dict(wire.writer_terms(shifts, private))
                self.assertEqual(terms["envelope"], 41)
                payload = sum(v for k, v in terms.items() if k != "envelope")
                self.assertEqual(payload + 41,
                                 wire.shape_len(shifts, private))

    def test_terminal_counts_follow_from_the_fixed_profile(self):
        for shifts in (PROFILE_SHIFTS, MAX_SHIFTS, (-8, 0, 9, 16)):
            self.assertEqual(wire.terminal_counts(shifts), wire.TERMINALS)

    def test_mask_matrix_has_sixteen_base_rows_under_function_one(self):
        for private in (False, True):
            self.assertEqual(wire.mask_base_rows(private), 16)

    def test_p3_costs_exactly_two_extra_sumcheck_rounds(self):
        p1 = wire.mask_specs(False)
        p3 = wire.mask_specs(True)
        self.assertEqual([r for r, _ in p3], [r + (1 if i < 2 else 0)
                                              for i, (r, _) in enumerate(p1)])
        # Three Fp2 per extra degree-2 round, twice, plus the wider W opening.
        self.assertEqual(wire.shape_len(PROFILE_SHIFTS, True)
                         - wire.shape_len(PROFILE_SHIFTS, False),
                         2 * 3 * 16 + (147456 - 110592))

    def test_full_shift_window_sweep(self):
        result = wire.sweep()
        self.assertEqual(result["tuples_checked"], 25 ** 4 * 2)
        self.assertEqual(result["max_frame"]["P1"], STATED_MAX_P1)
        self.assertEqual(result["max_frame"]["P3"], STATED_MAX_P3)

    def test_every_allowed_frame_is_below_the_global_cap(self):
        # The 32 MiB cap is unreachable for this profile: the largest allowed
        # frame is under 16.6 MB, so `Shape::len`'s bound never fires here.
        self.assertLess(STATED_MAX_P3, wire.MAX_WIRE_BYTES)
        self.assertLess(STATED_MAX_P3 * 2, wire.MAX_WIRE_BYTES)

    def test_shift_window_is_enforced(self):
        for shifts in ((-9, 0, 0, 0), (0, 17, 0, 0), (0, 0, 1 << 31, 0)):
            with self.assertRaises(ValueError):
                wire.shape_len(shifts, False)

    def test_frame_is_monotone_in_each_shift(self):
        base = [0, 0, 0, 0]
        for slot in range(4):
            previous = None
            for shift in range(wire.SHIFT_MIN, wire.SHIFT_MAX + 1):
                shifts = list(base)
                shifts[slot] = shift
                got = wire.shape_len(tuple(shifts), False)
                if previous is not None:
                    self.assertGreaterEqual(got, previous)
                previous = got

    def test_row_counts_depend_only_on_the_shift_multiset(self):
        for shifts in itertools.permutations((16, 0, -8, 9)):
            self.assertEqual(wire.rows_triple(shifts, True),
                             wire.rows_triple((-8, 0, 9, 16), True))


if __name__ == "__main__":
    unittest.main()

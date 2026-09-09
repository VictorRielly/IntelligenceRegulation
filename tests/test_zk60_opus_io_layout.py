"""Tests for the independent bound-FFN IO layout model (review O7).

Reviewer: Opus 5.  Implementation pin 137b109296d9a4cc9a05792bfdbd91aa45850abe,
profile ``ffn-v3-mr1-fresh-io-poc/2``.

These pin the four fixture numbers the round-18 profile states -- 702 A rows,
IO mask pairs at 698/699 and 700/701, seven A opening groups, seven-row
endpoint commitments -- to a re-derivation from the layout rules, and pin the
receipt length to the frames the two process checks actually wrote (the current
``/2`` run and the superseded ``/1`` draft, whose only difference is where the
two equality CFS slots live).  They test this reviewer's model, so they stay
green across implementation changes: their job is to keep the reviewed numbers
from drifting silently.  Nothing here is a soundness, zero-knowledge or privacy
claim, and the ``/2`` combined validation was still in flight when they were
written.
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))), "scripts"))

import zk60_opus_io_layout as io  # noqa: E402
import zk60_opus_wire_length as wire  # noqa: E402

PROFILE_SHIFTS = (7, 0, 14, 6)

# ZK60_ROUND18.md "Construction and lifecycle" item 4.
STATED_A_ROWS = 702
STATED_IO_PAIRS = [[698, 699], [700, 701]]
STATED_A_GROUPS = 7
STATED_ENDPOINT_ROWS = 7

# zkp-core/src/ffn_v3/statement.rs:163 -- the FFN input and output planes.
STATED_X_OFFSET = 3584
STATED_Z_OFFSET = 4096

# /tmp/zk60-round18-final/bound-process/result.json: the two receipts the
# ``/2`` separate-process check wrote at 137b109 (31 cases, "passed"); that
# combined validation run was still in flight, so these are shape evidence,
# not acceptance.
RECORDED_IO_P1 = 5_029_244
RECORDED_IO_P3 = 5_066_204

# /tmp/zk60-round18/bound-process/result.json: the superseded ``/1`` draft's
# two receipts at e8d4261.  Never cite this run as validation of ``/2``.
RECORDED_DRAFT_P1 = 5_178_780
RECORDED_DRAFT_P3 = 5_215_740

# results/zk60_round17_validation.json: the round-17 frames the IO profile
# extends.  The difference is the review's byte-level cross-check.
RECORDED_ROUND17_P1 = 4_733_245
RECORDED_ROUND17_P3 = 4_770_205


class TestARowMap(unittest.TestCase):
    def test_base_layout_has_698_rows_and_io_appends_four(self):
        base = io.a_row_map(PROFILE_SHIFTS, io=False)
        full = io.a_row_map(PROFILE_SHIFTS, io=True)
        self.assertEqual(base["a_rows"], 698)
        self.assertEqual(full["base_rows"], 698)
        self.assertEqual(full["a_rows"], STATED_A_ROWS)
        self.assertIsNone(base["a_io"])

    def test_io_pairs_sit_at_698_699_and_700_701(self):
        full = io.a_row_map(PROFILE_SHIFTS)
        self.assertEqual([[h, h + 1] for h in full["a_io"]], STATED_IO_PAIRS)

    def test_the_four_io_rows_alias_no_existing_row(self):
        full = io.a_row_map(PROFILE_SHIFTS)
        io_rows = set(io.io_mask_rows(full))
        self.assertEqual(len(io_rows), 4)
        self.assertTrue(io_rows.isdisjoint(io.base_mask_rows(full)))
        for site in full["sites"]:
            rows = set(range(site["start"], site["start"] + site["rows"]))
            if site["name"].startswith("a_io"):
                continue
            self.assertTrue(io_rows.isdisjoint(rows), site["name"])

    def test_every_a_row_is_accounted_for_exactly_once(self):
        full = io.a_row_map(PROFILE_SHIFTS)
        covered = []
        for site in full["sites"]:
            covered.extend(range(site["start"], site["start"] + site["rows"]))
        self.assertEqual(sorted(covered), list(range(STATED_A_ROWS)))

    def test_the_equality_claims_bind_the_original_x_and_z_slices(self):
        full = io.a_row_map(PROFILE_SHIFTS)
        self.assertEqual(full["x_slice"], {"offset": STATED_X_OFFSET, "log_size": 9})
        self.assertEqual(full["z_slice"], {"offset": STATED_Z_OFFSET, "log_size": 9})
        # Rows 14-17 are data rows, not mask rows: the equality opens the real
        # committed planes and blinds them with rows 698-701.
        self.assertEqual(full["x_slice"]["offset"] // full["a_n"], 14)
        self.assertEqual(full["z_slice"]["offset"] // full["a_n"], 16)

    def test_the_row_map_holds_across_the_whole_shift_window(self):
        for sg in range(wire.SHIFT_MIN, wire.SHIFT_MAX + 1):
            shifts = (sg, 0, 14, 6)
            base = io.a_row_map(shifts, io=False)
            full = io.a_row_map(shifts, io=True)
            self.assertEqual(full["a_rows"], base["a_rows"] + 4, shifts)
            self.assertEqual(full["a_io"], [base["a_rows"], base["a_rows"] + 2])


class TestOpeningGroups(unittest.TestCase):
    def test_five_base_groups_become_seven(self):
        base = io.a_claim_groups(PROFILE_SHIFTS, io=False)
        full = io.a_claim_groups(PROFILE_SHIFTS, io=True)
        self.assertEqual(base["n_groups"], 5)
        self.assertEqual(full["n_groups"], STATED_A_GROUPS)
        self.assertEqual(base["total_claims"], 18)
        self.assertEqual(full["total_claims"], 20)

    def test_x_is_opened_at_three_tails_and_z_at_two(self):
        full = io.a_claim_groups(PROFILE_SHIFTS)
        x_claims = [c for c in full["claims"] if "x[" in c or "X equality" in c]
        z_claims = [c for c in full["claims"] if "z[" in c or "z16 equality" in c]
        self.assertEqual(len(x_claims), 3)  # zcD, gu, IO
        self.assertEqual(len(z_claims), 2)  # zcD, IO


class TestEndpointPlane(unittest.TestCase):
    def test_seven_rows_two_data_two_terminal_masks_three_proximity(self):
        plane = io.endpoint_plane()
        self.assertEqual(plane["values"], 512)
        self.assertEqual(plane["data_rows"], 2)
        self.assertEqual(plane["commitment_rows"], STATED_ENDPOINT_ROWS)
        self.assertEqual(plane["terminal_mask_rows"], [2, 3])
        self.assertEqual(plane["prox_mask_row"], 4)
        self.assertEqual(plane["prox_pair_checked"], [4, 5])
        self.assertEqual(plane["unused_random_rows"], [6])

    def test_the_equality_slot_is_ten_variables_degree_two(self):
        plane = io.endpoint_plane()
        self.assertEqual(plane["cfs_spec"], (10, 2))
        self.assertEqual(plane["cfs_coefficients"], 22)
        self.assertEqual(io.IO_SPECS, ((10, 2), (10, 2)))
        # zk.rs:442 -- coefficients plus MASK_Q pads must fit one mask row.
        self.assertLessEqual(plane["cfs_coefficients"] + 256, 512)

    def test_the_two_slots_join_the_ffn_mask_commitment(self):
        # zk.rs:2172 appends both to mask_specs_v3, so M holds eight slots and
        # 2*8+4 = 20 base rows before it is committed.
        for private in (False, True):
            self.assertEqual(len(wire.mask_specs(private)) + len(io.IO_SPECS), 8)
            self.assertEqual(io.mask_base_rows(private), 20)


class TestFrameLength(unittest.TestCase):
    def test_the_frame_reproduces_both_recorded_receipts(self):
        self.assertEqual(io.io_frame_len(PROFILE_SHIFTS, False), RECORDED_IO_P1)
        self.assertEqual(io.io_frame_len(PROFILE_SHIFTS, True), RECORDED_IO_P3)

    def test_the_superseded_draft_frame_also_reproduces(self):
        self.assertEqual(io.io_frame_len(PROFILE_SHIFTS, False, draft=True),
                         RECORDED_DRAFT_P1)
        self.assertEqual(io.io_frame_len(PROFILE_SHIFTS, True, draft=True),
                         RECORDED_DRAFT_P3)

    def test_consolidating_the_slots_is_the_only_frame_difference(self):
        # Dropping the draft's second mask root and opening, and widening the
        # FFN M's 256 sampled columns from 16 to 20 base rows, accounts for the
        # whole 149,536-byte difference between the two recorded frames.
        delta = 32 + io.draft_mask_bytes() - wire.CHECKS * 4 * 8
        self.assertEqual(delta, 149_536)
        for private, draft, current in ((False, RECORDED_DRAFT_P1, RECORDED_IO_P1),
                                        (True, RECORDED_DRAFT_P3, RECORDED_IO_P3)):
            self.assertEqual(draft - delta, current)

    def test_the_delta_from_round_17_is_exactly_the_stated_additions(self):
        for private, old, new in ((False, RECORDED_ROUND17_P1, RECORDED_DRAFT_P1),
                                  (True, RECORDED_ROUND17_P3, RECORDED_DRAFT_P3)):
            # two extra A group vectors and four extra rows in 256 columns
            a_delta = 2 * 512 * 16 + wire.CHECKS * 4 * 8
            # the 41-byte round-17 header drops; EXTRA_BYTES carries the IO
            # frame's own 8-byte magic and 32-byte statement binding
            self.assertEqual(old + a_delta - wire.HEADER
                             + io.extra_bytes(draft=True), new)
            self.assertEqual(wire.shape_len(PROFILE_SHIFTS, private) + a_delta
                             - wire.HEADER + io.extra_bytes(draft=True), new)

    def test_extra_bytes_decomposes_as_the_source_states(self):
        self.assertEqual(io.argument_bytes(), 544)
        self.assertEqual(io.endpoint_open_bytes(), 131_072)
        self.assertEqual(io.extra_bytes(), 263_272)
        self.assertEqual(io.draft_mask_bytes(), 157_696)
        self.assertEqual(io.extra_bytes(draft=True), 421_000)
        self.assertEqual(io.EXPECTED_BYTES, 112)

    def test_the_frame_stays_inside_the_bound_at_the_largest_shape(self):
        biggest = (wire.SHIFT_MAX,) * 4
        self.assertLess(io.io_frame_len(biggest, True), wire.MAX_WIRE_BYTES)


if __name__ == "__main__":
    unittest.main()

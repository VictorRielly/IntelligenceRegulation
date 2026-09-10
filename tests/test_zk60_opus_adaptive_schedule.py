"""O13 -- controls on the transcript schedule inventory.

Reviewer: Claude Opus 5, 2026-09-09 (task O13 of docs/zkmatrix-poc/ZK60_OPUS_QUEUE.md).

The schedule tool is a read-only inventory, so these check that its structural
cross-checks actually bind: that they pass on the real captures, and that each
one fails when the property it names is broken.

Captures resolve from ZK60_IO_CAPTURES, defaulting to the persisted round-22
workspace.  These tests SKIP when those gitignored bytes are absent; a skip is
not acceptance evidence.
"""
import copy
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

import zk60_opus_adaptive_schedule as S  # noqa: E402


def _load_one(privacy="P3"):
    for path in sorted(CAPTURES.glob("*.json")):
        cap = json.loads(path.read_text())
        if cap["privacy"] == privacy:
            return path, cap
    raise unittest.SkipTest(f"no {privacy} capture")


@unittest.skipUnless(HAVE, f"IO captures absent ({CAPTURES})")
class ScheduleHoldsOnRealCaptures(unittest.TestCase):
    def setUp(self):
        self.result = S.run(CAPTURES)

    def test_every_structural_check_passes_on_all_four_captures(self):
        self.assertEqual(len(self.result["capture_cross_checks"]), 4)
        self.assertTrue(self.result["every_structural_check_passes"])
        for name, ok in self.result["all_captures_agree"].items():
            with self.subTest(check=name):
                self.assertTrue(ok)

    def test_the_segment_order_is_M_W_A_H_Input_Output_in_both_modes(self):
        for check in self.result["capture_cross_checks"]:
            with self.subTest(privacy=check["privacy"]):
                names = check["segment_order"]
                self.assertEqual(names[0], "M")
                self.assertEqual(names[-2:], ["Input", "Output"])
                self.assertIn(names[1], ("W", "public_W"))
                self.assertEqual(names[2:4], ["A", "H"])
                # P1 routes through the public-W block, P3 through the commitment
                self.assertEqual(names[1] == "public_W", check["privacy"] == "P1")

    def test_slot_index_is_not_the_emission_order(self):
        for check in self.result["capture_cross_checks"]:
            with self.subTest(privacy=check["privacy"]):
                self.assertEqual(check["argument_to_slot"]["tab"], 5)
                self.assertEqual(check["argument_to_slot"]["zs"], 4)
                order = check["emission_order"]
                self.assertLess(order.index("tab"), order.index("zs"))
                self.assertNotEqual(check["emission_order_slot_indices"],
                                    sorted(check["emission_order_slot_indices"]))

    def test_the_io_arguments_own_the_last_two_slots(self):
        for check in self.result["capture_cross_checks"]:
            with self.subTest(privacy=check["privacy"]):
                self.assertEqual(check["argument_to_slot"]["io0"], 6)
                self.assertEqual(check["argument_to_slot"]["io1"], 7)


@unittest.skipUnless(HAVE, f"IO captures absent ({CAPTURES})")
class ChecksActuallyBind(unittest.TestCase):
    """Each cross-check must fail when its property is broken; otherwise the
    'pass' in the record means nothing."""

    def test_a_broken_chain_is_detected(self):
        path, cap = _load_one()
        cap = copy.deepcopy(cap)
        cap["roles"][1]["before"]["state"] = [0] * 32
        out = S.cross_check(path, cap)
        self.assertFalse(out["transcript_contiguous"])

    def test_a_changed_theta_is_detected(self):
        path, cap = _load_one()
        cap = copy.deepcopy(cap)
        cap["mask"]["theta"] = [1, 2]
        out = S.cross_check(path, cap)
        self.assertFalse(out["theta_is_the_peeked_next_challenge"])

    def test_a_dropped_slot_is_detected(self):
        path, cap = _load_one()
        cap = copy.deepcopy(cap)
        cap["mask"]["specs"] = cap["mask"]["specs"][:-1]
        out = S.cross_check(path, cap)
        self.assertFalse(out["eight_reserved_slots"])
        self.assertFalse(out["every_argument_matches_one_slot"])

    def test_a_relabelled_io_slot_is_detected(self):
        path, cap = _load_one()
        cap = copy.deepcopy(cap)
        cap["io_arguments"][0]["slot"] = 3
        out = S.cross_check(path, cap)
        self.assertFalse(out["io_slots_are_6_and_7"])

    def test_a_truncated_tau_is_detected(self):
        path, cap = _load_one()
        cap = copy.deepcopy(cap)
        cap["io_arguments"][0]["tau"] = cap["io_arguments"][0]["tau"][:-1]
        out = S.cross_check(path, cap)
        self.assertFalse(out["io_geometry_9_tau_10_rho_10_rounds"])

    def test_a_narrowed_vector_is_detected(self):
        path, cap = _load_one()
        cap = copy.deepcopy(cap)
        cap["roles"][0]["proximity_vector"] = cap["roles"][0]["proximity_vector"][:-1]
        out = S.cross_check(path, cap)
        self.assertFalse(out["role_vectors_are_n_plus_qpad"])

    def test_a_wrong_proximity_rho_count_is_detected(self):
        path, cap = _load_one()
        cap = copy.deepcopy(cap)
        cap["mask"]["proximity_rhos"] = cap["mask"]["proximity_rhos"][:-1]
        out = S.cross_check(path, cap)
        self.assertFalse(out["mask_proximity_rhos_is_2s_plus_2"])


class InventoryIsWellFormed(unittest.TestCase):
    """The document's tables and the record must not drift apart."""

    def test_the_schedule_is_ordered_and_labelled(self):
        kinds = {k for _, _, k in S.SCHEDULE}
        self.assertEqual(kinds, {"init", "absorb", "squeeze", "rounds",
                                 "callback", "open", "guard"})
        self.assertEqual(S.SCHEDULE[0][2], "init")
        self.assertEqual(S.SCHEDULE[-1][2], "open")

    def test_the_endpoint_policy_is_absorbed_before_any_squeeze(self):
        first_squeeze = next(i for i, (_, _, k) in enumerate(S.SCHEDULE)
                             if k == "squeeze")
        policy = next(i for i, (_, e, _) in enumerate(S.SCHEDULE)
                      if "expected-IO" in e)
        self.assertLess(policy, first_squeeze)

    def test_H_is_absorbed_after_beta_gamma_alpha(self):
        h = next(i for i, (_, e, _) in enumerate(S.SCHEDULE) if 'absorb_com "H"' in e)
        alpha = next(i for i, (_, e, _) in enumerate(S.SCHEDULE) if e == "challenge alpha")
        self.assertGreater(h, alpha)

    def test_M_is_absorbed_before_every_challenge_it_masks(self):
        m = next(i for i, (_, e, _) in enumerate(S.SCHEDULE) if e.startswith('absorb "M"'))
        first_squeeze = next(i for i, (_, _, k) in enumerate(S.SCHEDULE) if k == "squeeze")
        self.assertLess(m, first_squeeze)

    def test_all_circular_dependencies_are_recorded_unresolved(self):
        self.assertEqual(len(S.CIRCLES), 4)
        self.assertEqual({c["id"] for c in S.CIRCLES}, {"C1", "C2", "C3", "C4"})
        self.assertTrue(all(not c["resolved"] for c in S.CIRCLES))
        self.assertTrue(all(c["known_break"] for c in S.CIRCLES))

    def test_both_guards_are_witness_independent_and_do_not_resample(self):
        self.assertEqual(len(S.REJECTION_GUARDS), 2)
        for g in S.REJECTION_GUARDS:
            with self.subTest(site=g["site"]):
                self.assertFalse(g["resamples"])
                self.assertFalse(g["depends_on_witness"])
                self.assertTrue(g["simulator_can_reproduce"])


if __name__ == "__main__":
    unittest.main()

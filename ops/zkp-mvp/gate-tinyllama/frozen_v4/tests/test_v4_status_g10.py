"""Tests of tools v4 of the TinyLlama port (privacy-gate lane, round 3,
2026-10-17): the record STATUS (`zk60_native_rg_status`) and finding G-10's
external-endpoint check in the run integrity pass with its controls
(`zk60_native_rg_bundle.integrity`, `zk60_native_rg_g10controls`).

    python3 -m unittest discover -s ops/zkp-mvp/gate-tinyllama/tests

Pure reading of retained bundles and records; no proof is made, nothing on
disk is written.
"""

import copy
import importlib.util
import json
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
PORT = os.path.join(os.path.dirname(HERE), "scripts")
V3 = os.path.join(os.path.dirname(HERE), "frozen_v3", "scripts")
sys.path.insert(0, PORT)

import zk60_native_rg_status as S  # noqa: E402
from zk60_native_rg_block import load_bundle  # noqa: E402
from zk60_native_rg_bundle import integrity  # noqa: E402
from zk60_native_rg_g10controls import _legacy_integrity, g10_controls  # noqa: E402

EV = "/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017"
L22_ZERO_ARMS = os.path.join(EV, "l22", "tl-l22r2-zero-arms.json")
L2_ZERO_ARMS = os.path.join(EV, "l2", "tl-zero-arms.json")
L2_EVERYTHING = os.path.join(EV, "l2", "tl-dense-everything.json")
A = "/home/victor/zk60-artifacts"
TL1D = os.path.join(A, "tinyllama-trained-capture-dense-l1")
TL1Z = os.path.join(A, "tinyllama-trained-capture-zero-l1")
TL2D = os.path.join(A, "tinyllama-trained-capture-dense-l2")
TL2Z = os.path.join(A, "tinyllama-trained-capture-zero-l2")
K = "/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920"
K4D = os.path.join(K, "run-i-dense-k4")
K4Z = os.path.join(K, "run-j-zero-k4")


def _load(path):
    with open(path) as fh:
        return json.load(fh)


@unittest.skipUnless(os.path.exists(L2_ZERO_ARMS), "the L = 2 zero-arms record is not on disk")
class Status(unittest.TestCase):
    """ARMS-ONLY is exactly ONE state; everything else stays NOT-OK"""

    def setUp(self):
        self.rec = _load(L2_ZERO_ARMS)

    def status(self, rec, **kw):
        return S.classify(rec, **kw)["status"]

    def test_the_l2_zero_arms_record_is_arms_only(self):
        out = S.classify(self.rec)
        self.assertEqual(out["status"], "ARMS-ONLY")
        self.assertFalse(out["ok"])
        self.assertEqual(out["unexplained"], [])
        self.assertIn("stage12_mask_and_cfs", out["control_families_not_fired_in_this_pass"])

    @unittest.skipUnless(os.path.exists(L22_ZERO_ARMS), "the L = 22 record is not on disk")
    def test_the_l22_zero_arms_record_is_arms_only(self):
        out = S.classify(_load(L22_ZERO_ARMS))
        self.assertEqual(out["status"], "ARMS-ONLY")
        self.assertEqual(len(out["false_leaves"]), 7)
        self.assertEqual(out["unexplained"], [])

    def test_ok_true_is_pass_and_ok_is_never_changed(self):
        r = copy.deepcopy(self.rec)
        r["ok"] = True
        self.assertEqual(self.status(r), "PASS")
        out = S.classify(self.rec)
        self.assertIs(out["ok"], False)

    def test_controls_requested_is_never_arms_only(self):
        self.assertEqual(self.status(self.rec, controls_requested=True), "NOT-OK")

    def test_a_mask_entry_that_differs_is_not_ok(self):
        r = copy.deepcopy(self.rec)
        r["stage12_mask_and_cfs"]["entries_differing"] = 1
        self.assertEqual(self.status(r), "NOT-OK")

    def test_a_mask_stage_that_is_not_ok_is_not_ok(self):
        r = copy.deepcopy(self.rec)
        r["stage12_mask_and_cfs"]["per_stage"][0]["ok"] = False
        self.assertEqual(self.status(r), "NOT-OK")

    def test_mask_pins_refused_is_not_ok(self):
        r = copy.deepcopy(self.rec)
        r["stage12_mask_and_cfs"]["source_pins"]["ok"] = False
        self.assertEqual(self.status(r), "NOT-OK")

    def test_mask_controls_that_ran_and_failed_are_not_ok(self):
        r = copy.deepcopy(self.rec)
        r["stage12_mask_and_cfs"]["controls"] = {"all_fire": False, "ok": False,
                                                 "M1_x": {"fires": False}}
        self.assertEqual(self.status(r), "NOT-OK")

    def test_a_skip_for_another_reason_is_not_arms_only(self):
        r = copy.deepcopy(self.rec)
        r["stage12_mask_and_cfs"]["controls"] = {
            "skipped": "the mask layer's pins refused, so nothing was perturbed",
            "ok": False}
        self.assertEqual(self.status(r), "NOT-OK")

    def test_a_coupling_not_respected_is_not_ok(self):
        r = copy.deepcopy(self.rec)
        r["stage13_joint_run_preimage"]["couplings"]["C1_shared_planes"]["respected"] = False
        self.assertEqual(self.status(r), "NOT-OK")

    def test_a_pcs_entry_that_differs_is_not_ok(self):
        r = copy.deepcopy(self.rec)
        r["stage11_full_preimage"]["view_entries_differing"] = 1
        self.assertEqual(self.status(r), "NOT-OK")

    def test_a_restricted_pcs_arm_is_not_ok(self):
        r = copy.deepcopy(self.rec)
        r["stage11_full_preimage"]["arm_restricted_to"] = ["A@0"]
        self.assertEqual(self.status(r), "NOT-OK")

    def test_a_second_joint_finding_is_not_ok(self):
        r = copy.deepcopy(self.rec)
        r["stage13_joint_run_preimage"]["findings"].append("something else")
        self.assertEqual(self.status(r), "NOT-OK")

    def test_another_stage_false_is_not_ok(self):
        r = copy.deepcopy(self.rec)
        r["stage4_the_boundary"]["ok"] = False
        self.assertEqual(self.status(r), "NOT-OK")

    def test_a_stage_that_raised_is_not_ok(self):
        r = copy.deepcopy(self.rec)
        r["timings"][0]["raised"] = "ValueError: x"
        self.assertEqual(self.status(r), "NOT-OK")

    @unittest.skipUnless(os.path.exists(L2_EVERYTHING), "everything record not on disk")
    def test_by_name_skips_are_not_this_state(self):
        self.assertEqual(self.status(_load(L2_EVERYTHING)), "NOT-OK")


class G10(unittest.TestCase):
    """the v4 integrity pass refuses an external-endpoint root that is not
    run.json's, and is byte-for-byte the v3 pass on every honest bundle"""

    @classmethod
    def setUpClass(cls):
        fn, cls.legacy_sha = _legacy_integrity(V3) if os.path.isdir(V3) else (None, None)
        # a plain function stored on a class would bind as a method
        cls.legacy = staticmethod(fn) if fn is not None else None

    def _honest_equal_to_v3(self, path):
        b = load_bundle(path)
        new = integrity(b)
        self.assertTrue(new["ok"], new["findings"])
        if self.legacy is not None:
            self.assertEqual(json.dumps(new, sort_keys=True, default=str),
                             json.dumps(self.legacy(b), sort_keys=True, default=str))
        return b

    @unittest.skipUnless(os.path.isdir(TL1D) and os.path.isdir(TL1Z), "L = 1 bundles not on disk")
    def test_one_block_run_all_four_fire_and_v3_accepted_them(self):
        b = self._honest_equal_to_v3(TL1D)
        out = g10_controls(b, other=load_bundle(TL1Z), legacy=self.legacy)
        self.assertTrue(out["ok"])
        self.assertEqual(out["applicable"], 4)
        self.assertTrue(out["every_perturbation_undone"])
        if self.legacy is not None:
            # the failing-first state: v3 accepted every one at L = 1
            self.assertEqual(len(out["v3_accepted"]), 4)
        self.assertTrue(integrity(b)["ok"])

    @unittest.skipUnless(os.path.isdir(TL2D) and os.path.isdir(TL2Z), "L = 2 bundles not on disk")
    def test_two_block_run(self):
        b = self._honest_equal_to_v3(TL2D)
        out = g10_controls(b, other=load_bundle(TL2Z), legacy=self.legacy)
        self.assertTrue(out["ok"])
        if self.legacy is not None:
            # at L >= 2 the boundary-root check already refused the swap
            self.assertNotIn("G10-4_stage0_swapped_for_the_other_runs_stage0",
                             out["v3_accepted"])
            self.assertIn("G10-1_stage0_input_opening_root_flipped", out["v3_accepted"])

    @unittest.skipUnless(os.path.isdir(K4D) and os.path.isdir(K4Z), "rung-K4 bundles not on disk")
    def test_inert_and_firing_at_a_frozen_development_bundle(self):
        b = self._honest_equal_to_v3(K4D)
        out = g10_controls(b, other=load_bundle(K4Z), legacy=self.legacy)
        self.assertTrue(out["ok"])


if __name__ == "__main__":
    unittest.main()

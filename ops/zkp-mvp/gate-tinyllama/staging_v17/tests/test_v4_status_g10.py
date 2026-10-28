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
        out = S.classify(self.rec)
        self.assertIs(out["ok"], False)
        # [v5] ok true with arms-only explanations is NOT a PASS
        r = copy.deepcopy(self.rec)
        r["ok"] = True
        self.assertEqual(self.status(r), "NOT-OK")

    def test_v5_pass_needs_every_false_leaf_explained_by_e(self):
        clean = {"ok": True, "blocks": 2, "timings": [],
                 "stage1_integrity": {"ok": True}}
        self.assertEqual(self.status(clean), "PASS")
        ch6 = copy.deepcopy(clean)
        ch6["stage6_negative_controls"] = {"ok": True, "hash_rule_controls": {
            "ok": True, "controls": [{"control": "CH-6", "fires": False,
                                      "skipped": S.CH6_SKIP}]}}
        out = S.classify(ch6)
        self.assertEqual(out["status"], "PASS")
        self.assertEqual(out["unexplained"], [])
        # the same leaf when the family's ok is false is not explained
        bad = copy.deepcopy(ch6)
        bad["stage6_negative_controls"]["hash_rule_controls"]["ok"] = False
        self.assertEqual(self.status(bad), "NOT-OK")
        # a CH-6 that ran and did not fire is not a by-name skip
        ran = copy.deepcopy(ch6)
        del ran["stage6_negative_controls"]["hash_rule_controls"]["controls"][0]["skipped"]
        self.assertEqual(self.status(ran), "NOT-OK")
        # any other false leaf under ok true: NOT-OK
        other = copy.deepcopy(clean)
        other["stage9_hash_layer"] = {"ok": True, "x": {"fires": False}}
        self.assertEqual(self.status(other), "NOT-OK")

    def test_v5_a_non_bool_ok_is_not_ok(self):
        clean = {"ok": True, "blocks": 2, "timings": [],
                 "stage1_integrity": {"ok": None}}
        out = S.classify(clean)
        self.assertEqual(out["status"], "NOT-OK")
        self.assertEqual(out["non_bool_leaves"], ["/stage1_integrity/ok"])
        r = copy.deepcopy(self.rec)
        r["stage12_mask_and_cfs"]["per_stage"][0]["ok"] = None
        self.assertEqual(self.status(r), "NOT-OK")
        # a NAMED not-applicable null `fires` is allowed
        na = {"ok": True, "blocks": 1, "timings": [],
              "stage6_negative_controls": {"ok": True, "run_controls": {
                  "ok": True, "C1": {"not_applicable": "x", "fires": None}}}}
        self.assertEqual(self.status(na), "PASS")

    def test_v5_rule_a_only_for_the_control_families(self):
        r = copy.deepcopy(self.rec)
        r["stage4_the_boundary"]["controls"] = {"skipped": S.NOT_REQUESTED, "ok": False}
        self.assertEqual(self.status(r), "NOT-OK")

    def test_v5_arms_only_needs_stages_1_to_3_and_the_arms(self):
        for k in ("stage1_integrity", "stage2_transcript_replay",
                  "stage3_per_commitment", "stage11_full_preimage"):
            r = copy.deepcopy(self.rec)
            del r[k]
            self.assertEqual(self.status(r), "NOT-OK", k)
        r = copy.deepcopy(self.rec)
        r["stage2_transcript_replay"]["ok"] = False
        self.assertEqual(self.status(r), "NOT-OK")

    def test_v5_every_mask_arm_conjunct_has_a_negative(self):
        base = self.rec
        self.assertTrue(S.mask_arm_closed(base["stage12_mask_and_cfs"], base["blocks"]))
        cases = [("requested", False), ("stages_checked", 1), ("stages_that_refused", ["x"]),
                 ("entries_recomputed", 0), ("entries_differing", 1),
                 ("salted_leaves_authenticated", 0)]
        for key, val in cases:
            r = copy.deepcopy(base)
            r["stage12_mask_and_cfs"][key] = val
            self.assertFalse(S.mask_arm_closed(r["stage12_mask_and_cfs"], r["blocks"]), key)
            self.assertEqual(self.status(r), "NOT-OK", key)
        for mut in ("pins", "per_stage_len", "per_stage_ok"):
            r = copy.deepcopy(base)
            s12 = r["stage12_mask_and_cfs"]
            if mut == "pins":
                s12["source_pins"]["ok"] = False
            elif mut == "per_stage_len":
                s12["per_stage"] = s12["per_stage"][:-1]
            else:
                s12["per_stage"][-1]["ok"] = False
            self.assertFalse(S.mask_arm_closed(s12, r["blocks"]), mut)

    def test_v5_every_joint_conjunct_has_a_negative(self):
        base = self.rec
        s11, s12, s13 = (base["stage11_full_preimage"], base["stage12_mask_and_cfs"],
                         base["stage13_joint_run_preimage"])
        self.assertTrue(S.joint_closed(s13, s11, s12, base["blocks"]))
        muts13 = [("requested", False), ("all_four_couplings_respected", False),
                  ("entries_differing", 1), ("findings", [])]
        for key, val in muts13:
            r = copy.deepcopy(base); r["stage13_joint_run_preimage"][key] = val
            self.assertEqual(self.status(r), "NOT-OK", key)
        for key in ("pcs_entries_differing", "masking_entries_differing"):
            r = copy.deepcopy(base); r["stage13_joint_run_preimage"]["parts"][key] = 1
            self.assertEqual(self.status(r), "NOT-OK", key)
        for key in ("pcs_entries_compared", "masking_entries_compared"):
            r = copy.deepcopy(base); r["stage13_joint_run_preimage"]["parts"][key] = 0
            self.assertEqual(self.status(r), "NOT-OK", key)
        r = copy.deepcopy(base); r["stage13_joint_run_preimage"]["couplings"].pop("C2_shared_claim_values")
        self.assertEqual(self.status(r), "NOT-OK", "three couplings")
        muts11 = [("requested", False), ("ok", False), ("view_entries_compared", 0),
                  ("not_exhibited", ["A@0"]), ("exhibited", [])]
        for key, val in muts11:
            r = copy.deepcopy(base); r["stage11_full_preimage"][key] = val
            self.assertEqual(self.status(r), "NOT-OK", key)

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
        # [v5] G10-1..G10-4 and review P-21's G10-5..G10-8
        self.assertEqual(out["applicable"], 8)
        self.assertTrue(out["every_perturbation_undone"])
        if self.legacy is not None:
            # the failing-first state: v3 accepted every one at L = 1
            self.assertEqual(len(out["v3_accepted"]), 8)
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


class R5Pins(unittest.TestCase):
    """[tools v5, round 4] the R5 readings: every digest carries a reading,
    every one is the file's digest in the gate's R5 copy, the merge never
    replaces a round-1 reading, and the three G-2 files are checked only
    when a bundle pins them."""

    R5 = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-gate-r5-superseded/hashline"

    def test_every_r5_digest_carries_a_reading(self):
        import zk60_native_rg_tinyllama_r5_pins as R
        for path, digests in R.RUN_LAYER_PINS.items():
            for d in digests:
                self.assertIn((path, d), R.READINGS)
                self.assertTrue(R.READINGS[(path, d)].startswith("[TINYLLAMA PORT v5"))
        for table in (R.TERMINALS_ALSO_ACCEPTED, R.TERMINALS_PINNED_IF_PRESENT):
            for path, digests in table.items():
                for d, reading in digests.items():
                    self.assertEqual(len(d), 64)
                    self.assertIn("TINYLLAMA PORT v5", reading)
        for d, (name, reading) in R.ARGUMENT_DEFINITIONS.items():
            self.assertEqual(name, "repaired")
            self.assertIn("TINYLLAMA PORT v5", reading)

    @unittest.skipUnless(os.path.isdir(R5), "the gate's R5 copy is not on disk")
    def test_every_r5_digest_is_the_r5_copys_file(self):
        import hashlib
        import zk60_native_rg_tinyllama_r5_pins as R

        def sha(rel):
            with open(os.path.join(self.R5, rel), "rb") as fh:
                return hashlib.sha256(fh.read()).hexdigest()
        for table in (R.RUN_LAYER_PINS, R.TERMINALS_ALSO_ACCEPTED,
                      R.TERMINALS_PINNED_IF_PRESENT, R.MASK_LAYER_PINS):
            for path, digests in table.items():
                self.assertEqual(list(digests), [sha(path)], path)
        for path, e in R.SHARED_G2_PINS.items():
            self.assertEqual(e["sha256"], sha(path), path)
        for d in R.ARGUMENT_DEFINITIONS:
            self.assertEqual(d, sha("src/private_block/argument.rs"))
        for path, (d, _why) in R.REPORT_ONLY_OWN_FILES.items():
            self.assertEqual(d, sha(path), path)

    def test_round_one_readings_survive_and_r5_is_merged(self):
        import zk60_native_rg_gqa as GQ
        import zk60_native_rg_mask as MK
        import zk60_native_rg_runpins as RP
        import zk60_native_rg_terminals as TM
        import zk60_native_rg_tinyllama_pins as TP
        import zk60_native_rg_tinyllama_r5_pins as R
        for path, digests in TP.RUN_LAYER_PINS.items():
            for d in digests:
                self.assertIn(d, RP.RUN_LAYER_PINS[path])
        for path, digests in R.RUN_LAYER_PINS.items():
            for d in digests:
                self.assertIn(d, RP.RUN_LAYER_PINS[path])
        for d in list(TP.ARGUMENT_DEFINITIONS) + list(R.ARGUMENT_DEFINITIONS):
            self.assertEqual(GQ.ARGUMENT_DEFINITIONS[d][0], "repaired")
        for path, digests in R.TERMINALS_ALSO_ACCEPTED.items():
            for d in digests:
                self.assertIn(d, TM.ALSO_ACCEPTED[path])
        for path, digests in R.MASK_LAYER_PINS.items():
            for d in digests:
                self.assertIn(d, MK.MASK_LAYER_PINS[path])
        with self.assertRaises(ValueError):
            R.merge_two_level({"f": {"a" * 64: 1}}, {"f": {"a" * 64: 2}}, "t")

    @unittest.skipUnless(os.path.isdir(TL1D), "L = 1 bundle not on disk")
    def test_a_pre_r5_bundle_gains_no_g2_leaf(self):
        from zk60_native_rg_runpins import check_shared_pins
        out = check_shared_pins(load_bundle(TL1D))
        self.assertNotIn("g2_prover_path_files", out)


@unittest.skipUnless(os.path.isdir(TL1D), "L = 1 bundle not on disk")
class PinEnforcement(unittest.TestCase):
    """[v5, review P-2] the pin verdict on synthetic manifests (no bundle is
    loaded: the check reads only the manifest)"""

    def setUp(self):
        import types
        import zk60_native_rg_runpins as RP
        import zk60_native_rg_tinyllama_r5_pins as R
        self.RP, self.R, self.types = RP, R, types
        with open(os.path.join(TL1D, "manifest.json")) as fh:
            self.man = json.load(fh)

    def check(self, mutate=None):
        man = copy.deepcopy(self.man)
        if mutate:
            mutate(man["source_pins"])
        return self.RP.check_run_layer_pins(self.types.SimpleNamespace(manifest=man))

    def _set(self, pins, f, d):
        for p in pins:
            if p["file"] == f:
                p["sha256"] = d
                return
        pins.append({"file": f, "sha256": d})

    def test_honest_tree_a_bundle(self):
        out = self.check()
        self.assertTrue(out["ok"])
        self.assertEqual(out["stages_not_checked"], {})
        self.assertNotIn("g2_prover_path_files", out["shared_files"])

    def test_run_rs_moved_suspends_every_stage_and_the_arms(self):
        out = self.check(lambda p: self._set(p, "src/private_block/run.rs", "0" * 64))
        self.assertFalse(out["ok"])
        for s in ("stage1_integrity", "stage2_transcript_replay",
                  "stage11_full_preimage", "stage12_mask_and_cfs",
                  "stage13_joint_run_preimage"):
            self.assertIn(s, out["stages_not_checked"])

    def test_a_shared_file_no_port_reads_fails_ok_without_suspending(self):
        out = self.check(lambda p: self._set(p, "src/mle.rs", "0" * 64))
        self.assertFalse(out["ok"])
        self.assertEqual(out["stages_not_checked"], {})

    def test_a_dropped_shared_pin_is_refused(self):
        out = self.check(lambda p: p.__setitem__(slice(None), [x for x in p if x["file"] != "src/mle.rs"]))
        self.assertFalse(out["ok"])

    def test_a_shared_file_a_port_reads_suspends_its_stages(self):
        out = self.check(lambda p: self._set(p, "../zkp-core/src/merkle.rs", "0" * 64))
        self.assertFalse(out["ok"])
        self.assertIn("stage9_hash_layer", out["stages_not_checked"])
        self.assertNotIn("stage2_transcript_replay", out["stages_not_checked"])

    def _r5(self, p):
        R = self.R
        self._set(p, "src/private_block/run.rs", next(iter(R.RUN_LAYER_PINS["src/private_block/run.rs"])))
        self._set(p, "src/private_block/run_capture.rs", next(iter(R.RUN_LAYER_PINS["src/private_block/run_capture.rs"])))
        for f, e in R.SHARED_G2_PINS.items():
            self._set(p, f, e["sha256"])

    def test_an_r5_writer_with_its_g2_pins_is_ok(self):
        out = self.check(self._r5)
        self.assertTrue(out["ok"], out["shared_files"].get("pins_that_moved"))
        self.assertEqual(len(out["shared_files"]["g2_prover_path_files"]), 3)

    def test_an_r5_writer_missing_a_g2_pin_is_refused(self):
        def m(p):
            self._r5(p)
            p[:] = [x for x in p if x["file"] != "../zkp-core/src/pcs/encode_buffer.rs"]
        out = self.check(m)
        self.assertFalse(out["ok"])
        self.assertIn("stage11_full_preimage", out["stages_not_checked"])

    def test_a_g2_pin_at_another_digest_is_refused(self):
        def m(p):
            self._r5(p)
            self._set(p, "../zkp-core/src/sumcheck/grouped.rs", "0" * 64)
        out = self.check(m)
        self.assertFalse(out["ok"])
        self.assertIn("stage12_mask_and_cfs", out["stages_not_checked"])


class R5bPins(unittest.TestCase):
    """[v6, round 5] the R5b readings: every digest is the gate's R5b copy's
    file, and an R5b writer must pin the N-r4-d group as well as G-2's"""

    R5B = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-gate-r5b/hashline"

    def _sha(self, rel):
        import hashlib
        with open(os.path.join(self.R5B, rel), "rb") as fh:
            return hashlib.sha256(fh.read()).hexdigest()

    @unittest.skipUnless(os.path.isdir(R5B), "the gate's R5b copy is not on disk")
    def test_every_r5b_digest_is_the_r5b_copys_file(self):
        import zk60_native_rg_tinyllama_r5b_pins as R
        for table in (R.RUN_LAYER_PINS, R.TERMINALS_PINNED_IF_PRESENT, R.MASK_LAYER_PINS):
            for path, digests in table.items():
                self.assertEqual(list(digests), [self._sha(path)], path)
        for path, e in R.SHARED_NR4D_PINS.items():
            self.assertEqual(e["sha256"], self._sha(path), path)
        for path, (d, _why) in R.REPORT_ONLY_OWN_FILES.items():
            self.assertEqual(d, self._sha(path), path)
        # the files the ports transcribe that R5b did NOT change keep R5's digests
        import zk60_native_rg_tinyllama_r5_pins as R5
        self.assertIn(self._sha("src/private_block/layout.rs"), R5.TERMINALS_ALSO_ACCEPTED["src/private_block/layout.rs"])
        self.assertIn(self._sha("src/private_block/protocol.rs"), R5.TERMINALS_ALSO_ACCEPTED["src/private_block/protocol.rs"])
        self.assertIn(self._sha("src/private_block/argument.rs"), R5.ARGUMENT_DEFINITIONS)

    @unittest.skipUnless(os.path.isdir(TL1D), "L = 1 bundle not on disk")
    def test_an_r5b_writer_must_pin_the_nr4d_group(self):
        import types
        import zk60_native_rg_runpins as RP
        import zk60_native_rg_tinyllama_r5b_pins as R
        import zk60_native_rg_tinyllama_r5_pins as R5
        with open(os.path.join(TL1D, "manifest.json")) as fh:
            man = json.load(fh)

        def set_(pins, f, d):
            for p in pins:
                if p["file"] == f:
                    p["sha256"] = d
                    return
            pins.append({"file": f, "sha256": d})

        def r5b(pins):
            set_(pins, "src/private_block/run.rs", next(iter(R.RUN_LAYER_PINS["src/private_block/run.rs"])))
            set_(pins, "src/private_block/run_capture.rs", next(iter(R.RUN_LAYER_PINS["src/private_block/run_capture.rs"])))
            for f, e in R5.SHARED_G2_PINS.items():
                set_(pins, f, e["sha256"])
            for f, e in R.SHARED_NR4D_PINS.items():
                set_(pins, f, e["sha256"])

        def check(m):
            mm = copy.deepcopy(man)
            m(mm["source_pins"])
            return RP.check_run_layer_pins(types.SimpleNamespace(manifest=mm))
        out = check(r5b)
        self.assertTrue(out["ok"], out["shared_files"].get("pins_that_moved"))
        self.assertEqual(len(out["shared_files"]["nr4d_files"]), 3)

        def missing(p):
            r5b(p)
            p[:] = [x for x in p if x["file"] != "src/gpu/mod.rs"]
        out = check(missing)
        self.assertFalse(out["ok"])
        self.assertIn("stage9_hash_layer", out["stages_not_checked"])

        def moved(p):
            r5b(p)
            set_(p, "../zkp-core/src/tables.rs", "0" * 64)
        out = check(moved)
        self.assertFalse(out["ok"])
        self.assertIn("stage8_plane_index_and_terminals", out["stages_not_checked"])


class G4Criterion(unittest.TestCase):
    """[v7, finding G-4, tightened per review round 2 Q-8] M9-3's two arms"""

    TAB = "slot {}: the port declares {} public tables, the capture has {}"
    DRAW = ("slot {}: this slot consumes {} definition draws (tau 4 + mu 13+1 "
            "+ nu 2 + zeta 1) and the capture declares {}")

    def test_indicator_arm(self):
        from zk60_native_rg_m125controls import INDICATOR_SLOTS, g4_criterion
        ok = lambda *a: g4_criterion(*a)["ok"]  # noqa: E731
        self.assertTrue(ok("D", 14, "indicator", {0, 1, 14}, [self.TAB.format(14, 3, 2)]))
        self.assertFalse(ok("D", 14, "indicator", {14}, [self.TAB.format(14, 3, 2)]))
        self.assertFalse(ok("D", 14, "indicator", {0, 1, 14, 15}, [self.TAB.format(14, 3, 2)]))
        self.assertTrue(ok("S", 17, "indicator", {4, 17}, [self.TAB.format(17, 2, 1)]))
        self.assertFalse(ok("S", 17, "indicator", {17}, [self.TAB.format(17, 2, 1)]))
        # either indicator mechanism, recorded, with exactly its surplus
        r = g4_criterion("Q", 15, "indicator", {15}, [self.DRAW.format(15, 19, 17)])
        self.assertTrue(r["ok"])
        self.assertEqual(r["refusal_mechanism"], "definition-draw count")
        self.assertFalse(ok("Q", 15, "indicator", {15}, [self.TAB.format(15, 4, 2)]))
        self.assertFalse(ok("Q", 15, "indicator", {15}, [self.DRAW.format(15, 18, 17)]))
        for d, slots in INDICATOR_SLOTS.items():
            host = max(slots)
            self.assertTrue(ok(d, host, "indicator", set(slots),
                               [self.TAB.format(host, 2, 1)]), d)

    def test_draw_count_arm(self):
        from zk60_native_rg_m125controls import g4_criterion
        ok = lambda *a: g4_criterion(*a)["ok"]  # noqa: E731
        self.assertTrue(ok("D", 14, "draw-count", {14}, [self.DRAW.format(14, 19, 17)]))
        # the public-table count does NOT satisfy the draw-count arm
        self.assertFalse(ok("D", 14, "draw-count", {14}, [self.TAB.format(14, 3, 2)]))
        # only the host slot may stop
        self.assertFalse(ok("D", 14, "draw-count", {0, 1, 14}, [self.DRAW.format(14, 19, 17)]))
        # the surplus must be exactly the pad mu and zeta
        self.assertFalse(ok("D", 14, "draw-count", {14}, [self.DRAW.format(14, 18, 17)]))

    def test_a_refusal_not_by_mechanism_or_none_fails(self):
        from zk60_native_rg_m125controls import g4_criterion
        for arm in ("indicator", "draw-count"):
            self.assertFalse(g4_criterion("Q", 15, arm, {15}, [])["ok"])
            self.assertFalse(g4_criterion("Q", 15, arm, {15},
                                          ["Dom::Q refused by name"])["ok"])
            self.assertFalse(g4_criterion("Q", 15, arm, {15},
                                          ["slot 15: indicator of Q looks padded"])["ok"])
            # another slot's refusal text does not count for the host
            self.assertFalse(g4_criterion("Q", 15, arm, {15},
                                          [self.DRAW.format(16, 19, 17)])["ok"])


class R7Pins(unittest.TestCase):
    """[v8, round 6 part (B)] the R7 readings: every digest is the gate's R7
    copy's file; the R7 writer is R5b's (run_capture.rs 31557a27), so the
    shared set and the transcribed files R7 did not change keep their
    readings; an R7 pin set is accepted and a moved R7 pin is refused"""

    R7 = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-gate-r7/hashline"

    def _sha(self, rel):
        import hashlib
        with open(os.path.join(self.R7, rel), "rb") as fh:
            return hashlib.sha256(fh.read()).hexdigest()

    @unittest.skipUnless(os.path.isdir(R7), "the gate's R7 copy is not on disk")
    def test_every_r7_digest_is_the_r7_copys_file(self):
        import zk60_native_rg_tinyllama_r7_pins as R
        import zk60_native_rg_tinyllama_r5b_pins as R5B
        import zk60_native_rg_tinyllama_r5_pins as R5
        for table in (R.RUN_LAYER_PINS, R.TERMINALS_ALSO_ACCEPTED,
                      R.TERMINALS_PINNED_IF_PRESENT, R.MASK_LAYER_PINS):
            for path, digests in table.items():
                self.assertEqual(list(digests), [self._sha(path)], path)
        for path, (d, _why) in R.REPORT_ONLY_OWN_FILES.items():
            self.assertEqual(d, self._sha(path), path)
        rc = self._sha("src/private_block/run_capture.rs")
        self.assertIn(rc, R5B.RUN_LAYER_PINS["src/private_block/run_capture.rs"])
        for path, e in R5B.SHARED_NR4D_PINS.items():
            self.assertEqual(e["sha256"], self._sha(path), path)
        for path, e in R5.SHARED_G2_PINS.items():
            self.assertEqual(e["sha256"], self._sha(path), path)
        self.assertIn(self._sha("src/private_block/layout.rs"), R5.TERMINALS_ALSO_ACCEPTED["src/private_block/layout.rs"])
        self.assertIn(self._sha("src/private_block/argument.rs"), R5.ARGUMENT_DEFINITIONS)

    @unittest.skipUnless(os.path.isdir(TL1D), "L = 1 bundle not on disk")
    def test_an_r7_pin_set_is_accepted_and_a_moved_one_refused(self):
        import types
        import zk60_native_rg_runpins as RP
        import zk60_native_rg_tinyllama_r7_pins as R
        import zk60_native_rg_tinyllama_r5b_pins as R5B
        import zk60_native_rg_tinyllama_r5_pins as R5
        with open(os.path.join(TL1D, "manifest.json")) as fh:
            man = json.load(fh)

        def set_(pins, f, d):
            for p in pins:
                if p["file"] == f:
                    p["sha256"] = d
                    return
            pins.append({"file": f, "sha256": d})

        def r7(pins):
            set_(pins, "src/private_block/run.rs", next(iter(R.RUN_LAYER_PINS["src/private_block/run.rs"])))
            set_(pins, "src/private_block/run_capture.rs", next(iter(R5B.RUN_LAYER_PINS["src/private_block/run_capture.rs"])))
            for f, e in R5.SHARED_G2_PINS.items():
                set_(pins, f, e["sha256"])
            for f, e in R5B.SHARED_NR4D_PINS.items():
                set_(pins, f, e["sha256"])

        def check(m):
            mm = copy.deepcopy(man)
            m(mm["source_pins"])
            return RP.check_run_layer_pins(types.SimpleNamespace(manifest=mm))
        out = check(r7)
        self.assertTrue(out["ok"], out.get("shared_files", {}).get("pins_that_moved"))

        def moved(p):
            r7(p)
            set_(p, "src/private_block/run.rs", "1" * 64)
        out = check(moved)
        self.assertFalse(out["ok"])


class TK7Pins(unittest.TestCase):
    """[v11, gate round 8: the D33 re-pin] the tk7 readings.  Every digest
    the tk7 module adds is the gate's tk7 copy's file; every one of the 52
    pins a tk7 block bundle carries is either an R7 pin read in v8 at the
    same digest, a token r7c reading, or the tk7 capture writer; a tk7 pin
    set passes the run-layer, terminal and mask pin checks, and a moved tk7
    pin is refused"""

    TK7 = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-gate-tk7/hashline"
    PINS = ("/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/"
            "tk7/tk7-source-pins.v1.json")

    def _sha(self, rel):
        import hashlib
        with open(os.path.join(self.TK7, rel), "rb") as fh:
            return hashlib.sha256(fh.read()).hexdigest()

    def _tk7_pins(self):
        with open(self.PINS) as fh:
            return {p["pin"]: p["sha256_gate_copy"] for p in json.load(fh)["pins"]}

    @unittest.skipUnless(os.path.isdir(TK7) and os.path.isfile(PINS),
                         "the gate's tk7 copy or its pin list is not on disk")
    def test_every_tk7_digest_is_the_tk7_copys_file(self):
        import zk60_native_rg_tinyllama_tk7_pins as K
        import zk60_native_rg_tinyllama_r7_pins as R7
        import zk60_native_rg_tinyllama_r5b_pins as R5B
        import zk60_native_rg_tinyllama_r5_pins as R5
        import zk60_native_rg_tokenio_r7c_pins as TP
        for table in (K.RUN_LAYER_PINS, K.TERMINALS_PINNED_IF_PRESENT, K.MASK_LAYER_PINS):
            for path, digests in table.items():
                self.assertEqual(list(digests), [self._sha(path)], path)
        for path, e in R5B.SHARED_NR4D_PINS.items():
            self.assertEqual(e["sha256"], self._sha(path), path)
        for path, e in R5.SHARED_G2_PINS.items():
            self.assertEqual(e["sha256"], self._sha(path), path)
        self.assertIn(self._sha("src/private_block/layout.rs"),
                      R5.TERMINALS_ALSO_ACCEPTED["src/private_block/layout.rs"])
        self.assertIn(self._sha("src/private_block/protocol.rs"),
                      R7.TERMINALS_ALSO_ACCEPTED["src/private_block/protocol.rs"])
        self.assertIn(self._sha("src/private_block/argument.rs"), R5.ARGUMENT_DEFINITIONS)
        pins = self._tk7_pins()
        self.assertEqual(len(pins), 52)
        where = {}
        for f, d in pins.items():
            self.assertEqual(d, self._sha(f), f)
            if TP.R7_PINS_READ_IN_V8.get(f) == d:
                where[f] = "r7"
            elif d in TP.TOKEN_R7C_READINGS.get(f, {}):
                where[f] = "token"
            elif f == "src/private_block/run_capture.rs" and d == K.RUN_CAPTURE_RS:
                where[f] = "tk7"
            else:
                self.fail(f"{f} {d[:12]} has no reading")
        self.assertEqual(sorted(where.values()).count("r7"), 40)
        self.assertEqual(sorted(where.values()).count("token"), 11)
        self.assertEqual(sorted(where.values()).count("tk7"), 1)

    @unittest.skipUnless(os.path.isdir(TL1D) and os.path.isfile(PINS),
                         "L = 1 bundle or the tk7 pin list not on disk")
    def test_a_tk7_pin_set_is_accepted_and_a_moved_one_refused(self):
        import types
        import zk60_native_rg_runpins as RP
        import zk60_native_rg_terminals as T
        import zk60_native_rg_mask as M
        with open(os.path.join(TL1D, "manifest.json")) as fh:
            man = json.load(fh)
        pins = self._tk7_pins()

        def bundle(change=None):
            mm = copy.deepcopy(man)
            mm["source_pins"] = [{"file": f, "sha256": d} for f, d in pins.items()]
            if change:
                for p in mm["source_pins"]:
                    if p["file"] == change:
                        p["sha256"] = "1" * 64
            return types.SimpleNamespace(manifest=mm, name="tk7-pin-set")
        out = RP.check_run_layer_pins(bundle())
        self.assertTrue(out["ok"], (out["pins_that_moved"], out["pins_missing_from_the_bundle"],
                                    out.get("shared_files", {}).get("pins_that_moved")))
        self.assertTrue(T.check_source_pins(bundle())["ok"])
        self.assertTrue(M.check_mask_layer_pins(bundle())["ok"])
        for f in ("src/private_block/run.rs", "src/private_block/run_capture.rs"):
            self.assertFalse(RP.check_run_layer_pins(bundle(f))["ok"], f)
        self.assertFalse(T.check_source_pins(bundle("src/private_block/shape.rs"))["ok"])
        self.assertFalse(M.check_mask_layer_pins(bundle("src/private_block/shape.rs"))["ok"])


class TokenIoGeometry(unittest.TestCase):
    """[gate round 7] the token stages' geometry, re-derived, equals the token
    lane's own counted layouts (DESIGN §6.5) at R2 and R3"""

    def test_r2_and_r3_counted_layouts(self):
        import zk60_native_rg_tokenio as T
        r2, r3 = T.TokenGeom(**T.R2_TINYLLAMA_T32), T.TokenGeom(**T.R3_LLAMA3_8B_T32)
        for g, want in ((r2, (17, 28, 182, 110, 1_196_032)), (r3, (41, 76, 374, 302, 2_768_896))):
            si, so = g.stage_in(), g.stage_out()
            self.assertEqual((si.a_rows, si.h_rows, so.a_rows, so.h_rows, so.elems()), want, g.name)
            self.assertEqual(g.limbs, 7, g.name)
        self.assertEqual(r2.stage_in().elems(), 184_320)       # DESIGN §1: 0.18 M
        self.assertEqual(r3.stage_in().elems(), 479_232)       # DESIGN §1: 0.48 M

    def test_static_g_items(self):
        import zk60_native_rg_tokenio as T
        r2, r3 = T.TokenGeom(**T.R2_TINYLLAMA_T32), T.TokenGeom(**T.R3_LLAMA3_8B_T32)
        self.assertTrue(r2.g5()["stage OUT"]["holds"])
        self.assertTrue(r3.g5()["stage OUT"]["holds"])
        self.assertEqual(r2.g4()["vocabulary"]["pad_positions"], 768)      # 32,000 -> 32,768
        self.assertEqual(r3.g4()["vocabulary"]["pad_positions"], 2_816)    # 128,256 -> 131,072
        self.assertEqual(r2.g4()["endpoints"]["input"]["pad_words_in_plane"], 224)   # 256-word plane, T = 32
        self.assertEqual(r2.g4()["endpoints"]["output"]["pad_words_in_plane"], 255)  # one id in one row
        # a wider-than-tier byte table would break G-5
        import dataclasses
        bad = T.TokenGeom(**(T.R2_TINYLLAMA_T32 | {"tier": dataclasses.replace(T.R1_MVP, stage_log_n=16)}))
        self.assertTrue(bad.g5()["stage OUT"]["holds"])                       # Tab lifts UP to 2^16
        self.assertEqual(r2.g2()["B_out"]["fixed_bits_total"], 5)

    def test_plane_index_cross_check(self):
        import zk60_native_rg_tokenio as T
        g = T.TokenGeom(**T.R2_TINYLLAMA_T32)
        lay = g.stage_out()
        good = {"a_rows": lay.a_rows, "a_data_rows": lay.a_data_rows, "a_mask_base": lay.a_mask_base,
                "a_prox": lay.a_prox, "h_rows": lay.h_rows, "h_data_rows": lay.h_data_rows,
                "h_mask_base": lay.h_mask_base, "h_prox": lay.h_prox, "h_u": lay.h_u,
                "h_u_rows": lay.h_u_rows(), "log_n": lay.log_n}
        self.assertEqual(T.cross_check_plane_index(g, "OUT", good), [])
        self.assertEqual(len(T.cross_check_plane_index(g, "OUT", good | {"a_rows": lay.a_rows + 2})), 1)
        self.assertEqual(len(T.cross_check_plane_index(g, "OUT", {k: v for k, v in good.items() if k != "h_u"})), 1)


TOKEN_L1 = "/home/victor/zk60-artifacts/token-io/captures/tinyllama-t32-L1-dense-pt1"


class TokenGate(unittest.TestCase):
    """[gate round 7] the token-run loader, replay and G-items on a real capture"""

    @unittest.skipUnless(os.path.isdir(TOKEN_L1), "the token capture is not on disk")
    def test_replay_and_integrity_on_the_capture(self):
        import zk60_native_rg_tokengate as TG
        b = TG.load(TOKEN_L1)
        self.assertEqual([s.kind for s in b.stages], ["IN", "BLOCK", "OUT"])
        rp = TG.TokenRunReplay(b).run()
        self.assertTrue(rp.summary()["ok"], rp.failures[:3])
        self.assertTrue(TG.token_integrity(b)["ok"])
        self.assertTrue(TG.g2_claim_points(b)["ok"])
        self.assertTrue(TG.g4_support_tables(b)["ok"])
        self.assertTrue(TG.g5_tab_width(b)["ok"])

    @unittest.skipUnless(os.path.isdir(TOKEN_L1), "the token capture is not on disk")
    def test_a_block_run_bundle_is_refused(self):
        import zk60_native_rg_tokengate as TG
        if os.path.isdir(TL1D):
            with self.assertRaises(ValueError):
                TG.load(TL1D)


class TokenGateV10(unittest.TestCase):
    """[v10] the computed word-level joint and its controls on a real capture"""

    @unittest.skipUnless(os.path.isdir(TOKEN_L1), "the token capture is not on disk")
    def test_joint_figure_and_controls(self):
        import zk60_native_rg_tokengate as TG
        b = TG.load(TOKEN_L1)
        rp = TG.TokenRunReplay(b).run()
        s3, views = TG.token_stage3(b, rp, pad_rank=False)
        j = TG.token_joint_figure(b, views)
        self.assertTrue(j["ok"], j["findings"])
        self.assertEqual(j["joint_disclosed_fp"], 0)
        self.assertGreater(j["identified_word_pairs"], 0)
        c = TG.token_joint_controls(b, views)
        self.assertTrue(c["ok"], c)

class TokenBlocksV11(unittest.TestCase):
    """[v11, gate round 8] the shape.rs reading is now in the terminals port
    permanently: the block adapter adds nothing in memory, the block
    terminals still pass on a token run, NC-0 still fires (it removes the
    reading for its own call) and the reading is back afterwards"""

    @unittest.skipUnless(os.path.isdir(TOKEN_L1), "the token capture is not on disk")
    def test_block_terminals_and_nc0_with_the_permanent_reading(self):
        import zk60_native_rg_tokengate as TG
        import zk60_native_rg_tokenblocks as TB
        import zk60_native_rg_terminals as T
        import zk60_native_rg_tinyllama_tk7_pins as K
        self.assertIn(K.SHAPE_RS, T.PINNED_IF_PRESENT[TB.SHAPE_RS])
        b = TG.load(TOKEN_L1)
        rp = TG.TokenRunReplay(b).run()
        r = TB.token_block_terminals(b, rp, controls=True)
        self.assertTrue(r["ok"], r["false_parts"])
        self.assertEqual(r["status"], "PASS")
        nc0 = r["controls"]["controls"]["NC-0_shape_rs_reading_not_added"]
        self.assertTrue(nc0["ok"], nc0)
        self.assertEqual(nc0["slot_checks_attempted"], 0)
        self.assertIn(K.SHAPE_RS, T.PINNED_IF_PRESENT[TB.SHAPE_RS])


class TokenRound10(unittest.TestCase):
    """[v12, gate round 10] the NL-1 wrapper on the L1 token capture; the
    surjection wrapper on the two token endpoints (small) with TS-1; the
    calibration composition rule and the README parse"""

    @unittest.skipUnless(os.path.isdir(TOKEN_L1), "the token capture is not on disk")
    def test_nl1_s1_to_s5_on_the_new_slots(self):
        import zk60_native_rg_tokennl as NLT
        r = NLT.run(TOKEN_L1)
        self.assertTrue(r["ok"], r["summary"])
        self.assertEqual(r["summary"]["new_slots"], 15)
        self.assertTrue(r["S5_controls"]["ok"])
        for k, v in r["per_challenge_mode"].items():
            self.assertTrue(v["fidelity_all"], k)

    @unittest.skipUnless(os.path.isdir(TOKEN_L1), "the token capture is not on disk")
    def test_surjection_on_the_token_endpoints(self):
        import zk60_native_rg_tokents as TS
        TT = TS.load_ts()
        ents, _ = TS.load_token_roles(TT, TOKEN_L1, [0, 2])
        eps = [e for e in ents if e["role"].name.startswith("E-token")]
        self.assertEqual(len(eps), 2)
        for e in eps:
            r = TS.analyse(TT, e)
            self.assertEqual(r["surjective_groups"], r["groups"])
            self.assertEqual(r["total_disclosed_Fp"], 0)
            TS.set_width(TT, e["log_cols"], e["inv_rate"])
            role = e["role"]
            c0 = role.groups[0][0]
            rw0 = {i: v for i, v in role.rws[c0].items() if role.kind[i] == "data"}
            pert = TT.analyse_group(role, 0, {"rws": {c0: rw0}}, also_original=True)
            self.assertGreater(pert["disclosed_Fp"], 0)

    @unittest.skipUnless(os.path.isdir(TOKEN_L1), "the token capture is not on disk")
    def test_calibration_rule_and_readme(self):
        import blake3
        import zk60_native_rg_tokencal as TC
        i, d = "11" * 32, "22" * 32
        want = blake3.blake3(b"hashline/token-io-calibration/v1" + bytes.fromhex(i) + bytes.fromhex(d)).hexdigest()
        self.assertEqual(TC.compose(i, d), want)
        f = TC.readme_facts(TOKEN_L1)
        self.assertEqual(f["layers"], [0])
        self.assertTrue(f["export"].endswith("pg_rot1_b4_T32_cal128"))


class TokenR9Pins(unittest.TestCase):
    """[v13, gate round 10] the round-9 readings: each digest is the CLI-path
    capture's pin, each base is frozen-r7's file; the capture's pins pass the
    token pin check and the terminal port's; a moved digest is refused"""

    CLI9 = "/home/victor/zk60-artifacts/token-io/captures/tinyllama-t32-L2-dense-pt1-cli-r9"
    FR7 = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/frozen-r7/hashline"

    @unittest.skipUnless(os.path.isdir(CLI9) and os.path.isdir(FR7), "the CLI capture or frozen-r7 is not on disk")
    def test_readings_and_pin_checks(self):
        import hashlib
        import types
        import zk60_native_rg_tokenio_r9_pins as R9
        import zk60_native_rg_tokengate as TG
        import zk60_native_rg_tokenterminals as TT
        with open(os.path.join(self.CLI9, "manifest.json")) as fh:
            man = json.load(fh)
        pins = {p["file"]: p["sha256"] for p in man["source_pins"]}
        for f, rd in R9.TOKEN_R9_READINGS.items():
            (d, r), = rd.items()
            self.assertEqual(pins[f], d, f)
            with open(os.path.join(self.FR7, f), "rb") as fh:
                self.assertEqual(hashlib.sha256(fh.read()).hexdigest(), r["base"], f)
            self.assertIs(r["moves_a_receipt_byte"], False)
        out = TG.token_pins(man)
        self.assertTrue(out["ok"], out["refusals"])
        self.assertEqual(out["read_as_token_r9"], 6)
        tt = TT.check_source_pins(types.SimpleNamespace(manifest=man))
        self.assertTrue(tt["ok"], tt)
        self.assertEqual(len(tt["accepted_by_a_round_9_reading"]), 2)
        bad = copy.deepcopy(man)
        for p in bad["source_pins"]:
            if p["file"] == "src/private_block/token_io/run.rs":
                p["sha256"] = "1" * 64
        self.assertFalse(TG.token_pins(bad)["ok"])
        bad2 = copy.deepcopy(man)
        for p in bad2["source_pins"]:
            if p["file"] == "src/private_block/token_io/stage_in.rs":
                p["sha256"] = "2" * 64
        self.assertFalse(TT.check_source_pins(types.SimpleNamespace(manifest=bad2))["ok"])


class TokenGateExportOverride(unittest.TestCase):
    """[v14] the token gate passes an export override to the block-stage
    terminal check (a CLI-path capture's README names no export directory)"""

    def test_gate_takes_an_export(self):
        import inspect
        import zk60_native_rg_tokengate as TG
        self.assertIn("export_dir", inspect.signature(TG.gate).parameters)



class TK9Pins(unittest.TestCase):
    """[v15, gate round 10: the frozen-r9 re-pin] the tk9 reading.  The one
    digest the tk9 module adds is the tk9 copy's run.rs and frozen-r9's; the
    six pins a tk9 bundle moves against tk7 are frozen-r9's files and the v13
    readings' keys; the 52 pins split 40 R7 / 5 token r7c / 6 token r9 / 1
    tk7 writer; a tk9 pin set passes the run-layer, terminal and mask pin
    checks; without the tk9 entry (the v14 state) the same set is refused,
    naming run.rs; a moved run.rs is refused"""

    TK9 = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-gate-tk9/hashline"
    R9 = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/frozen-r9/hashline"
    PINS = ("/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/"
            "tk9/tk9-source-pins.v1.json")

    def _sha(self, root, rel):
        import hashlib
        with open(os.path.join(root, rel), "rb") as fh:
            return hashlib.sha256(fh.read()).hexdigest()

    def _tk9_pins(self):
        with open(self.PINS) as fh:
            return {p["pin"]: p["sha256_gate_copy"] for p in json.load(fh)["pins"]}

    @unittest.skipUnless(os.path.isdir(TK9) and os.path.isdir(R9) and os.path.isfile(PINS),
                         "the gate's tk9 copy, frozen-r9 or the tk9 pin list is not on disk")
    def test_every_tk9_digest_and_the_pin_split(self):
        import zk60_native_rg_tinyllama_tk9_pins as K9
        import zk60_native_rg_tinyllama_tk7_pins as K7
        import zk60_native_rg_tokenio_r7c_pins as TP
        import zk60_native_rg_tokenio_r9_pins as R9P
        for path, digests in K9.RUN_LAYER_PINS.items():
            self.assertEqual(list(digests), [self._sha(self.TK9, path)], path)
            self.assertEqual(list(digests), [self._sha(self.R9, path)], path)
        for path, d in K9.TK9_MOVED_PINS.items():
            self.assertEqual(d, self._sha(self.TK9, path), path)
            self.assertEqual(d, self._sha(self.R9, path), path)
            self.assertIn(d, R9P.TOKEN_R9_READINGS[path], path)
        pins = self._tk9_pins()
        self.assertEqual(len(pins), 52)
        where = {}
        for f, d in pins.items():
            self.assertEqual(d, self._sha(self.TK9, f), f)
            if TP.R7_PINS_READ_IN_V8.get(f) == d:
                where[f] = "r7"
            elif d in TP.TOKEN_R7C_READINGS.get(f, {}):
                where[f] = "token-r7c"
            elif d in R9P.TOKEN_R9_READINGS.get(f, {}):
                where[f] = "token-r9"
            elif f == "src/private_block/run_capture.rs" and d == K7.RUN_CAPTURE_RS:
                where[f] = "tk7-writer"
            else:
                self.fail(f"{f} {d[:12]} has no reading")
        got = sorted(where.values())
        self.assertEqual((got.count("r7"), got.count("token-r7c"), got.count("token-r9"),
                          got.count("tk7-writer")), (40, 5, 6, 1))
        self.assertEqual({f for f, w in where.items() if w == "token-r9"}, set(K9.TK9_MOVED_PINS))

    @unittest.skipUnless(os.path.isdir(TL1D) and os.path.isfile(PINS),
                         "L = 1 bundle or the tk9 pin list not on disk")
    def test_a_tk9_pin_set_is_accepted_refused_without_the_reading_and_a_moved_one_refused(self):
        import types
        import zk60_native_rg_runpins as RP
        import zk60_native_rg_terminals as T
        import zk60_native_rg_mask as M
        import zk60_native_rg_tinyllama_tk9_pins as K9
        with open(os.path.join(TL1D, "manifest.json")) as fh:
            man = json.load(fh)
        pins = self._tk9_pins()

        def bundle(change=None):
            mm = copy.deepcopy(man)
            mm["source_pins"] = [{"file": f, "sha256": d} for f, d in pins.items()]
            if change:
                for p in mm["source_pins"]:
                    if p["file"] == change:
                        p["sha256"] = "1" * 64
            return types.SimpleNamespace(manifest=mm, name="tk9-pin-set")
        out = RP.check_run_layer_pins(bundle())
        self.assertTrue(out["ok"], (out["pins_that_moved"], out["pins_missing_from_the_bundle"],
                                    out.get("shared_files", {}).get("pins_that_moved")))
        self.assertTrue(T.check_source_pins(bundle())["ok"])
        self.assertTrue(M.check_mask_layer_pins(bundle())["ok"])
        # failing first: the v14 state (no tk9 entry) refuses run.rs by name
        # and suspends every stage it affects
        entry = RP.RUN_LAYER_PINS["src/private_block/run.rs"].pop(K9.RUN_RS)
        try:
            off = RP.check_run_layer_pins(bundle())
        finally:
            RP.RUN_LAYER_PINS["src/private_block/run.rs"][K9.RUN_RS] = entry
        self.assertFalse(off["ok"])
        self.assertEqual(len(off["pins_that_moved"]), 1)
        self.assertTrue(off["pins_that_moved"][0].startswith("src/private_block/run.rs: the bundle pins cc2c420498b1"))
        self.assertEqual(set(off["stages_not_checked"]),
                         set(RP.AFFECTED_STAGES["src/private_block/run.rs"][0])
                         | set(RP.AFFECTED_ARM_STAGES.get("src/private_block/run.rs", ())))
        self.assertTrue(RP.check_run_layer_pins(bundle())["ok"])
        for f in ("src/private_block/run.rs", "src/private_block/run_capture.rs"):
            self.assertFalse(RP.check_run_layer_pins(bundle(f))["ok"], f)


class TokenCalAttributionParse(unittest.TestCase):
    """[v16, gate round 10] the attribution reader takes an object after
    libtest's `test <name> ... ` prefix (v12 missed the first object of each
    test and refused the L = 1 bundles by A1), and A1 still refuses a bundle
    whose layer range has no attribution line (failing first)"""

    LOG = ("/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/"
           "round10/r10-pr4-9-tinyllama.log")

    def test_prefixed_line_is_read(self):
        import tempfile
        import zk60_native_rg_tokencal as TC
        obj = {"event": "pr4-9-attribution", "tag": "t", "export": "/x", "layers": [0]}
        with tempfile.NamedTemporaryFile("w", suffix=".log", delete=False) as fh:
            fh.write("running 1 test\n")
            fh.write("test a::b::c ... " + json.dumps(obj, separators=(",", ":")) + "\n")
            fh.write(json.dumps(dict(obj, tag="u", layers=[0, 1]), separators=(",", ":")) + "\n")
            fh.write("ok\n")
            p = fh.name
        try:
            got = TC.read_attributions(p)
        finally:
            os.unlink(p)
        self.assertEqual([a["tag"] for a in got], ["t", "u"])

    @unittest.skipUnless(os.path.isfile(LOG) and os.path.isdir(TOKEN_L1),
                         "the round-10 attribution log or the L1 token capture is not on disk")
    def test_l1_bundle_attributed_and_a1_fires_without_its_line(self):
        import zk60_native_rg_tokencal as TC
        atts = TC.read_attributions(self.LOG)
        self.assertEqual([a["tag"] for a in atts], ["tinyllama-b4-L1", "tinyllama-b4-L2", "tinyllama-b4-L22"])
        rec = TC.check_one(TOKEN_L1, atts)
        self.assertTrue(rec["ok"], rec["findings"])
        rec = TC.check_one(TOKEN_L1, [a for a in atts if a["layers"] != [0]])
        self.assertFalse(rec["ok"])
        self.assertTrue(rec["findings"][0].startswith("A1: 0 attribution lines"), rec["findings"])


DD_RUNG_L1 = "/home/victor/zk60-artifacts/dd-gate-r9/dd-rung-l1-dense"


class R9Pins(unittest.TestCase):
    """[v17, gate round 14: DD, native R9] the R9 readings.  Every digest the
    r9 module adds is the R9 tree's file (production) or the gate copy's
    (the two test-only patched files); the 46 pins of an R9 gate bundle split
    32 R7 pins read in v8 + 14 read in the r9 module; the pin set passes the
    run-layer, terminal and mask checks; without the r9 run.rs entry (the
    v16 state) run.rs is refused; a moved run.rs is refused"""

    R9 = "/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r9/frozen-tree/hashline"
    GATE = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-gate-r9/hashline"
    PINS = ("/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/"
            "round14/r9-source-pins.v1.json")

    def _sha(self, root, rel):
        import hashlib
        with open(os.path.join(root, rel), "rb") as fh:
            return hashlib.sha256(fh.read()).hexdigest()

    @unittest.skipUnless(os.path.isdir(R9) and os.path.isdir(GATE) and os.path.isfile(PINS),
                         "R9, the gate's R9 copy or its pin list is not on disk")
    def test_every_r9_digest_and_the_pin_split(self):
        import zk60_native_rg_tinyllama_r9_pins as K
        import zk60_native_rg_tokenio_r7c_pins as TP
        patched = {"src/private_block/run_capture.rs", "src/private_block/plane_index.rs"}
        for table in (K.RUN_LAYER_PINS, K.TERMINALS_ALSO_ACCEPTED, K.TERMINALS_PINNED_IF_PRESENT, K.MASK_LAYER_PINS):
            for path, digests in table.items():
                root = self.GATE if path in patched else self.R9
                self.assertEqual(list(digests), [self._sha(root, path)], path)
        for path, (d, _why) in K.REPORT_ONLY.items():
            self.assertEqual(d, self._sha(self.R9, path), path)
        self.assertEqual(list(K.ARGUMENT_DEFINITIONS), [self._sha(self.R9, "src/private_block/argument.rs")])
        with open(self.PINS) as fh:
            pins = {p["pin"]: p["sha256_gate_copy"] for p in json.load(fh)["pins"]}
        self.assertEqual(len(pins), 46)
        read_here = set()
        for t in (K.RUN_LAYER_PINS, K.TERMINALS_ALSO_ACCEPTED, K.TERMINALS_PINNED_IF_PRESENT, K.MASK_LAYER_PINS):
            for path, digests in t.items():
                read_here |= {(path, d) for d in digests}
        read_here |= {(p, d) for p, (d, _w) in K.REPORT_ONLY.items()}
        where = {}
        for f, d in pins.items():
            if TP.R7_PINS_READ_IN_V8.get(f) == d:
                where[f] = "r7"
            elif (f, d) in read_here:
                where[f] = "r9"
            else:
                self.fail(f"{f} {d[:12]} has no reading")
        self.assertEqual((sorted(where.values()).count("r7"), sorted(where.values()).count("r9")), (32, 14))

    @unittest.skipUnless(os.path.isdir(DD_RUNG_L1), "the DD rung capture is not on disk")
    def test_the_r9_pin_set_is_accepted_and_refused_without_its_reading(self):
        import zk60_native_rg_runpins as RP
        import zk60_native_rg_terminals as T
        import zk60_native_rg_mask as M
        import zk60_native_rg_tinyllama_r9_pins as K
        b = load_bundle(DD_RUNG_L1)
        self.assertTrue(RP.check_run_layer_pins(b)["ok"])
        self.assertTrue(T.check_source_pins(b)["ok"])
        self.assertTrue(M.check_mask_layer_pins(b)["ok"])
        entry = RP.RUN_LAYER_PINS["src/private_block/run.rs"].pop(K.RUN_RS)
        try:
            off = RP.check_run_layer_pins(b)
        finally:
            RP.RUN_LAYER_PINS["src/private_block/run.rs"][K.RUN_RS] = entry
        self.assertFalse(off["ok"])
        self.assertTrue(off["pins_that_moved"][0].startswith("src/private_block/run.rs: the bundle pins cf80735dbea5"))


class DDPorts(unittest.TestCase):
    """[v17, gate round 14] the DD slot ports, statically and on the DD rung
    capture: the lookups at Dom::S / Dom::Dd; `ports_for` swaps slot 17 and
    appends slot 23 at DD only; the terminal identity covers and equals all
    24 slots; the e column is attributed to the stage's exp table; the DD
    controls and the DD NL-1 pass"""

    def test_lookups_at_dd(self):
        import zk60_native_rg_terminals as T
        raw = {"norm_wrho": 31, "wrho_s": 17, "dd_cap": 32}
        counts = {"ln": 4, "ls": 3, "lp": 2}
        s_dd = T.lookups_at("S", counts, raw)
        s_plain = T.lookups_at("S", counts, {"norm_wrho": 31, "wrho_s": 17})
        names = lambda lks: {nm for terms, _c in lks for nm, _x in terms}
        self.assertFalse(any(n.startswith(("A_PL", "A_SR", "A_SG")) for n in names(s_dd)))
        self.assertTrue(any(n.startswith("A_SR") for n in names(s_plain)))
        dd = T.lookups_at("Dd", counts, raw)
        self.assertEqual(len(dd), (2 + 1) + 2 * (3 + 1))
        with self.assertRaises(ValueError):
            T.lookups_at("Dd", counts, {"norm_wrho": 31, "wrho_s": 17})

    @unittest.skipUnless(os.path.isdir(DD_RUNG_L1), "the DD rung capture is not on disk")
    def test_terminals_attribution_controls_and_nl1_on_the_rung(self):
        import zk60_native_rg_terminals as T
        import zk60_native_rg_ddcontrols as DC
        import zk60_native_rg_ddnl as DN
        from zk60_native_rg_planes import plane_index_of
        from zk60_native_rg_replay import RunReplay
        b = load_bundle(DD_RUNG_L1)
        idx, _ = plane_index_of(b)
        self.assertIn("Dd", idx.domain_log)
        ports = T.ports_for(b)
        self.assertEqual([p[0] for p in ports][-1], T.SC_DD)
        self.assertIs(dict((p[0], p[2]) for p in ports)[T.SC_SZC], T.sc_szc_dd)
        r = T.check_terminals(b, idx, replay=RunReplay(b).run())
        self.assertTrue(r["ok"], r["findings"][:3])
        self.assertEqual((r["slot_checks_equal"], r["slot_checks_expected"]), (24, 24))
        self.assertTrue(all(a["ok"] for a in r["dd_e_column_attribution"]))
        c = DC.run(DD_RUNG_L1)
        self.assertTrue(c["ok"], [x["control"] for x in c["controls"] if not x["fires"]])
        n = DN.run(DD_RUNG_L1)
        self.assertTrue(n["ok"], n["summary"])

    def test_a_non_dd_bundle_keeps_its_ports(self):
        import types
        import zk60_native_rg_terminals as T
        b = types.SimpleNamespace(run={"shape": {}})
        self.assertIs(T.ports_for(b), T.PORTS)


TL128_L2 = "/home/victor/zk60-artifacts/dd-gate-r9/tl128dd-l2-dense"


class StageCal(unittest.TestCase):
    """[v17, gate round 14] each stage's calibration (native R8 / R9
    `stage_shape`): the stage-line reader on a synthetic run whose schedule
    digest is computed here, each refusal by its code, the token-run
    exemption, and (with the capture on disk) the T128 DD L = 2 run, whose
    stage 1 carries layer 1's own constants"""

    BASE = "stage 01: commits nothing; slot 21 claims boundary 0 at pair row 18; data rows 16"

    def _run(self, line1, bind=True):
        import zk60_native_rg_stagecal as SC
        shape = {"width": 2048, "trained_calibration": True, "norm_tn": 10, "norm_cn_a": 1253,
                 "norm_cn_m": 1444, "norm_ceps": 74429, "sh_ao": 7, "sh_qkv": 8, "sh_s": 6,
                 "sh_o": 9, "sh_g": 8, "sh_h": 14, "sh_z": 8, "d_max": 1482910, "norm_wrho": 32}
        run = {"shape": shape, "parameter_line": "p/sh-g8-u0-h14-z8/", "layout_description": ["l0", "l1"],
               "stage_lines": ["stage 00: commits boundary 0; data rows 16", line1]}
        if bind:
            run["schedule_digest"] = list(bytes.fromhex(SC.schedule_digest(run)["recomputed"]))
        else:
            run["schedule_digest"] = [0] * 32
        return run

    def test_reader_and_refusals(self):
        import zk60_native_rg_stagecal as SC
        own = self.BASE + "; score shift 8 (the layer's own; the run's is 6); ao shift 6 (the layer's own; the run's is 7)"
        r = self._run(own)
        shapes, rec = SC.stage_shapes(r)
        self.assertIs(shapes[0], r["shape"])
        self.assertEqual((shapes[1]["sh_s"], shapes[1]["sh_ao"], shapes[1]["norm_cn_a"]), (8, 6, 1253))
        self.assertEqual(rec["stages_at_their_own_calibration"], [1])
        self.assertTrue(rec["schedule_digest"]["equal"])
        # no clause: every stage IS the run shape
        r0 = self._run(self.BASE)
        s0, _ = SC.stage_shapes(r0)
        self.assertTrue(all(s is r0["shape"] for s in s0))
        cases = {
            "SC-5": self._run(own, bind=False),
            "SC-1": self._run(self.BASE + "; score shift 8 (the layer's own; the run's is 5)"),
            "SC-2": self._run(self.BASE + "; score shift 6 (the layer's own; the run's is 6)"),
            "SC-3": self._run(self.BASE + "; ao shift 6 (the layer's own; the run's is 7); score shift 8 (the layer's own; the run's is 6)"),
            "SC-4": self._run(self.BASE + "; Score shift 8 (the layer's own; the run's is 6)"),
            "SC-7": self._run(self.BASE + "; norm tn 16 (the layer's own; the run's is 10)"),
        }
        for code, run in cases.items():
            with self.assertRaises(ValueError, msg=code) as cm:
                SC.stage_shapes(run)
            self.assertTrue(str(cm.exception).startswith(code), (code, str(cm.exception)))
        frozen = self._run(own)
        frozen["shape"] = dict(frozen["shape"], trained_calibration=None)
        frozen["schedule_digest"] = list(bytes.fromhex(SC.schedule_digest(frozen)["recomputed"]))
        with self.assertRaises(ValueError) as cm:
            SC.stage_shapes(frozen)
        self.assertTrue(str(cm.exception).startswith("SC-6"))
        tok = self._run(own, bind=False)
        tok["token_io"] = {}
        self.assertEqual(SC.stage_shapes(tok)[0], [])

    @unittest.skipUnless(os.path.isdir(TL128_L2), "the T128 DD L = 2 capture is not on disk")
    def test_t128_dd_l2_stage_one_and_tl6(self):
        import zk60_native_rg_stagecal as SC
        import zk60_native_rg_tlcontrols as TL
        b = load_bundle(TL128_L2)
        shapes, rec = SC.stage_shapes(b.run)
        self.assertTrue(rec["schedule_digest"]["equal"])
        self.assertIs(shapes[0], b.run["shape"])
        self.assertEqual(rec["own_clauses"]["1"], {"sh_s": {"own": 8, "run": 6},
                                                   "norm_cn_a": {"own": 2198, "run": 1253},
                                                   "norm_cn_m": {"own": 1764, "run": 1444},
                                                   "sh_ao": {"own": 6, "run": 7}})
        rows = TL.tl6_stage_line_refusals(b)
        self.assertEqual(sorted(r["expected_code"] for r in rows), ["SC-1", "SC-2", "SC-3", "SC-4", "SC-5"])
        self.assertTrue(all(r["ok"] for r in rows), rows)

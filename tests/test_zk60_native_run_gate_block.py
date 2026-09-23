"""Tests for round 9j: the run gate reads a STANDALONE shaped block receipt
(lane stage 45, schema `hashline-native-capture/5-block-shaped`).

Run:
  python3 -m unittest discover -s tests \
      -p "test_zk60_native_run_gate_block.py"

WHY THERE IS A ROUND 9j.  `ZK60_SHAPED_PRIVACY_PATH_STATUS.md` obligation 3:
every 125M gate measurement so far was of a TWO-BLOCK RUN; no standalone
shaped block receipt had been gated.  Stage 45 wrote a verifier-side capture
for one; this round teaches the gate that schema through ONE adapter module,
`zk60_native_rg_block`, that presents a block as a run of one stage with no
boundary.

FOUR ARMS, as rounds 5 and 9i.

* A PURE arm: the block layer's pin table and readings, that a digest
  nobody read is STILL refused (a re-pin is not a weakening), the policy
  frame parser, the run replay's refactor into hooks, and the corrected
  channel texts.
* A LANE arm, skipped when the read-only lane worktree is absent: every
  pinned digest is the blob at every commit it names.
* The RECORDED arm: every figure the ledger quotes, from the tracked
  evidence under `results/zk60_native_run_gate_block/`, and that it was
  produced by the tool bytes now in the tree.
* The LIVE arm, skipped when the rung-G bundles are absent: the loader and
  its refusals by name, integrity and its perturbations, the replay, the
  pins, and the controls on real bytes.

Nothing here asserts a privacy property.
"""

from __future__ import annotations

import copy
import json
import os
import subprocess
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))

EVIDENCE = os.path.join(ROOT, "results", "zk60_native_run_gate_block")
LANE = os.environ.get("ZK60_BLOCK125M_LANE", "/home/victor/wt-zk60-block125m")
RUNG_G = os.path.join(LANE, "results", "zk60_block_captures_20260923", "rung-g")
DENSE = os.path.join(RUNG_G, "rung-g-dense")
ZERO = os.path.join(RUNG_G, "rung-g-zero")
RUNS = os.path.join(LANE, "results", "zk60_run_captures_20260920")
HAVE_BLOCKS = os.path.isdir(DENSE) and os.path.isdir(ZERO)
HAVE_RUN_G = os.path.isdir(os.path.join(RUNS, "run-g-dense-s20"))

import zk60_native_run_gate as gate  # noqa: E402
import zk60_native_rg_block as blk  # noqa: E402
import zk60_native_rg_mask as rgm  # noqa: E402
import zk60_native_rg_terminals as term  # noqa: E402
from zk60_native_rg_gqa import (  # noqa: E402
    ARGUMENT_DEFINITIONS,
    PRE_REPAIR,
    REPAIRED,
    definition_of_pin,
)

ARGUMENT_45 = "2cee0a2253d6ef91bea23f564d8e24a3362663da53a10182d6b0edaa8a10a013"
PROTOCOL_45 = "974892cc1c45f27e446e1fd4595c888b6a1be647105bfbab3fe6298f7a731ea7"
LAYOUT_45 = "64c37a4956ed221cb549d8e88257a14f5f332bb549fc4028c9a38246b111f23c"
SHAPE_45 = "5acecd8e431ea37d6669ab097be4e64c1102cff6617bd09712f4a742c658328f"
WRITER_45 = "37312d49ccea469dbea25936d11e1a54943274328efdf8759e39a0eef640fd8f"
WIRE = "99e69b5c92154ed2ba44c6c568d14704ecd66ae2ee85b13ae337b6501bffc8a1"
PB_45 = "58a73b4004ce11c6dd0d0cc2bbef9bce4f180e08797388883753d50c7ba1be1f"


class _Manifest:
    def __init__(self, pins, name="shadow"):
        self.manifest = {"source_pins": [{"file": f, "sha256": d}
                                         for f, d in pins.items()]}
        self.name = name


def _block_pins(**over):
    pins = {
        "src/private_block/block_capture_shaped.rs": WRITER_45,
        "src/private_block/wire.rs": WIRE,
        "src/private_block.rs": PB_45,
    }
    pins.update(over)
    return pins


# =====================================================================
#  the PURE arm
# =====================================================================
class TheBlockLayerPins(unittest.TestCase):
    """Three files, each pinned because a port of this module transcribes
    something from it, each with a written reading; a digest nobody read is
    refused and suspends exactly the stages its reason names."""

    def test_the_table_is_exactly_the_three_files_the_module_transcribes(self):
        self.assertEqual(sorted(blk.BLOCK_LAYER_PINS), sorted(blk.DEPENDS))
        self.assertEqual(sorted(blk.BLOCK_LAYER_PINS), sorted(blk.AFFECTED_STAGES))
        for path, table in blk.BLOCK_LAYER_PINS.items():
            for d, ent in table.items():
                self.assertIn((path, d), blk.READINGS)
                self.assertEqual(len(d), 64)
                self.assertEqual(ent["bundles"], blk.BLOCK_BUNDLES)
                self.assertEqual(ent["commits"], (blk.FEAE674, blk.C19F06BF))

    def test_the_honest_pins_pass_and_suspend_nothing(self):
        from zk60_native_rg_runpins import SHARED_LAYER_PINS
        pins = _block_pins()
        pins.update({f: v["sha256"] for f, v in SHARED_LAYER_PINS.items()})
        got = blk.check_block_layer_pins(_Manifest(pins))
        self.assertTrue(got["ok"])
        self.assertEqual(got["stages_not_checked"], {})
        self.assertEqual(got["run_layer_files_the_bundle_declares_anyway"], [])

    def test_a_writer_digest_nobody_read_suspends_every_stage(self):
        got = blk.check_block_layer_pins(_Manifest(_block_pins(**{
            "src/private_block/block_capture_shaped.rs": "7" * 64})))
        self.assertFalse(got["ok"])
        from zk60_native_rg_runpins import ALL_STAGES
        self.assertEqual(sorted(got["stages_not_checked"]), sorted(ALL_STAGES))
        self.assertTrue(any("block_capture_shaped.rs" in m
                            for m in got["pins_that_moved"]))

    def test_a_moved_wire_or_policy_file_suspends_integrity_and_channels(self):
        for path in ("src/private_block/wire.rs", "src/private_block.rs"):
            got = blk.check_block_layer_pins(_Manifest(_block_pins(**{path: "8" * 64})))
            self.assertFalse(got["ok"], path)
            self.assertEqual(sorted(got["stages_not_checked"]),
                             ["stage1_integrity", "stage7_channels"], path)

    def test_a_missing_writer_pin_is_refused_like_a_moved_one(self):
        pins = _block_pins()
        del pins["src/private_block/block_capture_shaped.rs"]
        got = blk.check_block_layer_pins(_Manifest(pins))
        self.assertFalse(got["ok"])
        self.assertTrue(got["pins_missing_from_the_bundle"])

    def test_a_block_that_declares_a_run_layer_file_is_not_passed(self):
        got = blk.check_block_layer_pins(_Manifest(_block_pins(**{
            "src/private_block/run.rs": "9" * 64})))
        self.assertFalse(got["ok"])
        self.assertEqual(got["run_layer_files_the_bundle_declares_anyway"],
                         ["src/private_block/run.rs"])

    def test_the_readings_say_what_was_read(self):
        w = blk.READINGS[("src/private_block/block_capture_shaped.rs", WRITER_45)]
        for needle in ("READ WHOLE", "begin_block", "TRANSCRIPT_LABELS",
                       "ARRAY_MIN", "ALLOWED_KEYS", "stage 0"):
            self.assertIn(needle, w)
        self.assertIn("HLPBLOK1", blk.READINGS[("src/private_block/wire.rs", WIRE)])
        pb = blk.READINGS[("src/private_block.rs", PB_45)]
        for needle in ("ENDPOINT_SCALES", "+220 / -12", "S38-F1(a)", "CS-8",
                       "nothing absorbed moves"):
            self.assertIn(needle, pb)


class ThePinsRoundNineJRead(unittest.TestCase):
    """The four files stages 38-45 moved that a PORT pins, each accepted with
    a reading, and a third digest of each still refused."""

    def test_the_stage_45_argument_digest_selects_the_repaired_definition(self):
        name, why = definition_of_pin(ARGUMENT_45)
        self.assertEqual(name, REPAIRED)
        for needle in ("6 added, 0 removed", "#[cfg(test)]", "byte-identical"):
            self.assertIn(needle, why)
        self.assertEqual(
            {d[:12]: v[0] for d, v in ARGUMENT_DEFINITIONS.items()},
            {"909670c96562": PRE_REPAIR, "dd8469cb0279": REPAIRED,
             "ec3f97443245": REPAIRED, "f7fa2ad4213d": REPAIRED,
             "2cee0a2253d6": REPAIRED})

    def test_protocol_layout_and_shape_are_read_second_values(self):
        self.assertIn(PROTOCOL_45, term.ALSO_ACCEPTED["src/private_block/protocol.rs"])
        self.assertIn("CS-3", term.ALSO_ACCEPTED["src/private_block/protocol.rs"][PROTOCOL_45])
        self.assertIn(LAYOUT_45, term.ALSO_ACCEPTED["src/private_block/layout.rs"])
        self.assertIn("CS-8", term.ALSO_ACCEPTED["src/private_block/layout.rs"][LAYOUT_45])
        self.assertIn(SHAPE_45, term.PINNED_IF_PRESENT["src/private_block/shape.rs"])
        self.assertIn("CS-9", term.PINNED_IF_PRESENT["src/private_block/shape.rs"][SHAPE_45])
        for f, d in (("src/private_block/argument.rs", ARGUMENT_45),
                     ("src/private_block/layout.rs", LAYOUT_45),
                     ("src/private_block/shape.rs", SHAPE_45)):
            ent = rgm.MASK_LAYER_PINS[f][d]
            self.assertEqual(ent["bundles"], blk.BLOCK_BUNDLES)
            self.assertIn("READ 2026-09-23 (round 9j)", ent["reading"])

    def _terminal_pins(self, **over):
        pins = {"src/private_block/argument.rs": ARGUMENT_45,
                "src/private_block/layout.rs": LAYOUT_45,
                "src/private_block/protocol.rs": PROTOCOL_45,
                "src/private_block/plane_index.rs": term.PORTED_FROM[
                    "src/private_block/plane_index.rs"],
                "src/private_block/shape.rs": SHAPE_45}
        pins.update(over)
        return _Manifest(pins)

    def test_the_stage_45_set_passes_the_terminal_port(self):
        self.assertTrue(term.check_source_pins(self._terminal_pins())["ok"])

    def test_a_third_digest_of_each_is_still_refused(self):
        for f in ("src/private_block/argument.rs", "src/private_block/layout.rs",
                  "src/private_block/protocol.rs", "src/private_block/shape.rs"):
            got = term.check_source_pins(self._terminal_pins(**{f: "4" * 64}))
            self.assertFalse(got["ok"], f)
            self.assertTrue(any(f in m for m in got["pins_that_moved"]), f)
        mask = rgm.check_mask_layer_pins(type("B", (), {
            "manifest": {"source_pins": [
                {"file": "src/private_block/argument.rs", "sha256": "5" * 64},
                {"file": "src/private_block/layout.rs", "sha256": LAYOUT_45},
                {"file": "src/private_block/shape.rs", "sha256": SHAPE_45}]},
            "name": "shadow"})())
        self.assertFalse(mask["ok"])


class TheReplayRefactorAndTheCorrectedChannels(unittest.TestCase):
    def test_the_run_replay_has_the_three_hooks_and_the_block_overrides_them(self):
        from zk60_native_rg_replay import RunReplay, replay_for
        for hook in ("_open_stage", "_sites_of", "_close_stage"):
            self.assertTrue(hasattr(RunReplay, hook))
            self.assertIsNot(getattr(blk.BlockReplay, hook),
                             getattr(RunReplay, hook), hook)
        self.assertIs(type(replay_for(type("R", (), {"blocks": 1})())), RunReplay)

    def test_the_policy_frame_parser(self):
        raw = (b"HBLKEXP1" + bytes(range(32)) + (3).to_bytes(4, "little", signed=True)
               + (-2).to_bytes(4, "little", signed=True) + bytes(32) + bytes([1]) * 32)
        got = blk.parse_policy(raw)
        self.assertEqual((got["input_scale"], got["output_scale"]), (3, -2))
        self.assertEqual(got["context"], list(range(32)))
        self.assertIsNone(blk.parse_policy(raw[:-1]))
        self.assertIsNone(blk.parse_policy(b"XXXXXXXX" + raw[8:]))

    def test_the_run_channel_texts_rows_26_to_28_are_corrected(self):
        """Read from a RUN record re-taken under this round's tools (the
        rung-K8 pair): the scale channel is ARGUED on D12b(3) / R-5, the two
        others keep OPEN with their reasons corrected, every correction is
        dated beside what it replaced, and the table reads 10 / 5 / 5 / 8."""
        r = _record_at("zk60_native_run_gate_k8", "run-s-dense-k8")
        if r is None:
            self.skipTest("the rung-K8 record is not in the tree")
        ch = {c["channel"]: c for c in r["stage7_channels"]["channels"]}
        sc = ch["the boundary scale tags and the one calibration identity"]
        self.assertEqual(sc["status"], "argued")
        self.assertIn("R-5", sc["assumption"])
        self.assertIn("2026-09-23", sc["corrected"])
        ref = ch["whether a proof attempt produced a receipt (refusal events)"]
        self.assertEqual(ref["status"], "open")
        self.assertNotIn("23 more", ref["reason"])
        self.assertIn("R-2", ref["reason"])
        self.assertIn("23 more", ref["corrected"])   # quoted, beside it
        jl = ch["the cross-block joint law beyond the linear rank"]
        self.assertEqual(jl["status"], "open")
        self.assertNotIn("which is unwritten", jl["reason"])
        self.assertIn("Theorem B", jl["reason"])
        self.assertIn("lane stage 36", jl["ruling_R3_as_of_2026_09_23"])
        self.assertEqual(r["stage7_channels"]["counts"],
                         {"constructed": 10, "derived": 5, "argued": 5, "open": 8})


# =====================================================================
#  the LANE arm -- the pins against the read-only lane's blobs
# =====================================================================
@unittest.skipUnless(os.path.isdir(os.path.join(LANE, ".git"))
                     or os.path.isfile(os.path.join(LANE, ".git")),
                     "the read-only lane worktree is not on this machine")
class TheDigestsAreTheLanesBlobs(unittest.TestCase):
    def _blob_sha(self, commit, path):
        raw = subprocess.run(
            ["git", "--no-pager", "-C", LANE, "show", f"{commit}:hashline/{path}"],
            capture_output=True, check=True).stdout
        import hashlib
        return hashlib.sha256(raw).hexdigest()

    def test_every_block_layer_digest_is_the_blob_at_every_commit_it_names(self):
        n = 0
        for path, table in blk.BLOCK_LAYER_PINS.items():
            for d, ent in table.items():
                for c in ent["commits"]:
                    self.assertEqual(self._blob_sha(c, path), d, (path, c))
                    n += 1
        self.assertEqual(n, 6)

    def test_the_four_port_digests_are_the_blobs_at_the_capture_commits(self):
        for path, d in (("src/private_block/argument.rs", ARGUMENT_45),
                        ("src/private_block/protocol.rs", PROTOCOL_45),
                        ("src/private_block/layout.rs", LAYOUT_45),
                        ("src/private_block/shape.rs", SHAPE_45)):
            for c in (blk.FEAE674, blk.C19F06BF):
                self.assertEqual(self._blob_sha(c, path), d, (path, c))


# =====================================================================
#  the RECORDED arm
# =====================================================================
def _record_at(directory, name):
    p = os.path.join(ROOT, "results", directory, f"{name}.json")
    if not os.path.exists(p):
        return None
    with open(p) as fh:
        return json.load(fh)


def _record(name):
    p = os.path.join(EVIDENCE, f"{name}.json")
    if not os.path.exists(p):
        return None
    with open(p) as fh:
        return json.load(fh)


class TheRecordedFiguresAtRungG(unittest.TestCase):
    NAMES = ("block-rung-g-dense", "block-rung-g-zero")

    def _recs(self):
        out = {n: _record(n) for n in self.NAMES}
        out = {k: v for k, v in out.items() if v is not None}
        if not out:
            self.skipTest("no rung-G block record is in the tree")
        return out

    def test_the_evidence_came_from_the_tool_bytes_now_in_the_tree(self):
        now = gate.tool_hashes()
        for n, r in self._recs().items():
            self.assertEqual(r["tool_sha256"], now, n)

    def test_every_stage_ok_and_no_privacy_claim(self):
        for n, r in self._recs().items():
            with self.subTest(n):
                self.assertTrue(r["ok"])
                for k in [k for k in r if k.startswith("stage")]:
                    self.assertTrue(r[k]["ok"], k)
                self.assertFalse(r["privacy_property_established"])
                self.assertFalse(r["privacy_acceptance"])
                self.assertTrue(r["block_layer_source_pins"]["ok"])
                self.assertNotIn("run_layer_source_pins", r)

    def test_the_prediction_held(self):
        for n, r in self._recs().items():
            with self.subTest(n):
                s2 = r["stage2_transcript_replay"]
                self.assertEqual((s2["positions_checked"], s2["challenges_checked"]),
                                 (127, 2036))
                self.assertTrue(s2["block_binding_reproduced"])
                self.assertEqual(s2["segment_position_tags"], [])
                t = r["stage8_plane_index_and_terminals"]["terminal_identity"]
                self.assertEqual((t["slot_checks_equal"], t["slot_checks_expected"],
                                  t["slot_checks_matching_the_stored_terminal_polynomial"]),
                                 (23, 23, 23))
                disc = {x["role"]: (x["disclosed_dimension"], x["rank_P1"])
                        for x in r["stage3_per_commitment"]["per_commitment"]}
                self.assertEqual(disc, {"A@0": (0, 74), "H@0": (2, 20),
                                        "E-Input": (0, 4), "E-Output": (0, 4)})
                s4 = r["stage4_the_boundary"]
                self.assertEqual(s4["per_boundary"], [])
                w = s4["whole_run"]
                self.assertEqual((w["generators"], w["coordinate_classes"],
                                  w["joint_fp"], w["sum_of_parts_fp"],
                                  w["identified_rows"]), (104, 1259, 2, 2, 8))
                s9 = r["stage9_hash_layer"]
                self.assertEqual((s9["openings"], s9["columns_checked"],
                                  s9["columns_authenticated"], s9["bytes_hashed"]),
                                 (5, 1280, 1280, 2594816))
                s12 = r["stage12_mask_and_cfs"]
                self.assertEqual((s12["entries_recomputed"], s12["entries_differing"],
                                  s12["salted_leaves_authenticated"]), (15960, 0, 256))
                s11 = r["stage11_full_preimage"]
                self.assertEqual((s11["view_entries_differing"],
                                  s11["salted_leaves_authenticated"]), (0, 1024))
                s13 = r["stage13_joint_run_preimage"]
                self.assertEqual((s13["entries_differing"],
                                  s13["salted_leaves_authenticated"]), (0, 1280))
                ch = r["stage7_channels"]
                self.assertEqual((ch["total"], ch["counts"]),
                                 (28, {"constructed": 10, "derived": 5,
                                       "argued": 5, "open": 8}))
                self.assertEqual(ch["grading_failures"], [])

    def test_every_control_family_fires(self):
        for n, r in self._recs().items():
            with self.subTest(n):
                s6 = r["stage6_negative_controls"]
                self.assertTrue(s6["all_fire"])
                self.assertEqual(len(s6["controls"]), 5)
                self.assertIn("C1_two_claims_share_one_reserved_pair",
                              s6["not_applicable"])
                ct = r["stage8_plane_index_and_terminals"]["controls"]
                self.assertEqual(sum(1 for c in ct["controls"] if c["fires"]), 9)
                gc = r["stage10_bilinear_group_factor"]["controls"]
                self.assertEqual((gc["controls_that_fire"], gc["controls_total"]), (8, 9))
                hc = r["stage9_hash_layer"]["controls"]
                self.assertTrue(hc["ok"])
                self.assertEqual(len(hc["controls"]), 7)


# =====================================================================
#  the LIVE arm
# =====================================================================
@unittest.skipUnless(HAVE_BLOCKS, "the rung-G block bundles are not on this machine")
class TheLiveRungGBlock(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.b = blk.BlockBundle(DENSE)

    def test_the_adapter_is_a_run_of_one_stage_with_no_boundary(self):
        b = self.b
        self.assertTrue(b.standalone)
        self.assertEqual((b.blocks, b.boundaries, len(b.stages)), (1, 0, 1))
        self.assertEqual([b.stages[0].key(r["role"]) for r in b.stages[0].roles],
                         ["A@0", "H@0", "E-Input", "E-Output"])
        self.assertIsNone(b.stages[0].boundary_opening())
        with self.assertRaises(KeyError):
            b.boundary(0)

    def test_each_loader_refuses_the_other_kind_by_name(self):
        from zk60_native_rg_bundle import RunBundle
        with self.assertRaisesRegex(ValueError, "no run.json"):
            RunBundle(DENSE)
        if HAVE_RUN_G:
            with self.assertRaisesRegex(ValueError, "no block.json"):
                blk.BlockBundle(os.path.join(RUNS, "run-g-dense-s20"))
            with self.assertRaisesRegex(ValueError, "schema"):
                blk.BlockStage(os.path.join(RUNS, "run-g-dense-s20", "stage-00.json"))
            self.assertIsInstance(blk.load_bundle(os.path.join(RUNS, "run-g-dense-s20")),
                                  RunBundle)
        self.assertIsInstance(blk.load_bundle(DENSE), blk.BlockBundle)

    def test_integrity_is_clean_and_each_perturbation_is_named(self):
        honest = blk.block_integrity(self.b)
        self.assertTrue(honest["ok"], honest["findings"])
        self.assertTrue(honest["receipt"]["envelope_is_the_magic_and_block_binding"])
        self.assertTrue(honest["endpoint_policy"]["scales_are_the_approved_calibrations"])
        self.assertTrue(all(honest["validation_file"]["flags"].values()))
        cases = (
            (("external_endpoints", "input_scale"), 3, "scales"),
            (("block_binding",), [0] * 32, "envelope"),
            (("public_statement_digest",), [0] * 32, "public statement"),
        )
        for path, value, needle in cases:
            d = self.b.run
            keep = copy.deepcopy(d)
            try:
                tgt = d
                for k in path[:-1]:
                    tgt = tgt[k]
                tgt[path[-1]] = value
                got = blk.block_integrity(self.b)
            finally:
                self.b.run = keep
            self.assertFalse(got["ok"], path)
            self.assertTrue(any(needle in f for f in got["findings"]), (path, got["findings"]))

    def test_the_replay_and_its_refusal_of_a_run_framing(self):
        r = blk.BlockReplay(self.b).run().summary()
        self.assertTrue(r["ok"], r["failures"][:3])
        self.assertEqual((r["positions_checked"], r["challenges_checked"]), (127, 2036))
        self.assertNotIn("run_binding_reproduced", r)
        doc = self.b.stages[0].doc
        keep = doc["transcript_sites"]
        doc["transcript_sites"] = [dict(s, stage=0) for s in keep]
        try:
            bad = blk.BlockReplay(self.b).run().summary()
        finally:
            doc["transcript_sites"] = keep
        self.assertFalse(bad["ok"])
        self.assertTrue(any("run's framing" in f for f in bad["failures"]))

    def test_the_bundle_pins_exactly_the_digests_this_round_read(self):
        got = blk.check_block_layer_pins(self.b)
        self.assertTrue(got["ok"])
        self.assertTrue(got["shared_files"]["ok"])
        pins = {p["file"]: p["sha256"] for p in self.b.manifest["source_pins"]}
        self.assertEqual(len(pins), 35)
        self.assertTrue(term.check_source_pins(self.b)["ok"])
        self.assertTrue(rgm.check_mask_layer_pins(self.b)["ok"])


if __name__ == "__main__":
    unittest.main()

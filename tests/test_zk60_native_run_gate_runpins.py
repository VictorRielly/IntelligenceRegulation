"""Tests for round 6: the RUN LAYER's own source pins (finding K4-F2).

Run:
  python3 -m unittest discover -s tests \
      -p "test_zk60_native_run_gate_runpins.py"

WHY THERE IS A ROUND 6.  Round 5 found that three of the eight files a run
bundle pins in its own manifest -- `run_capture.rs` (the capture WRITER),
`run.rs` (the run's header, stage order and position tags) and
`boundary.rs` (the internal boundary's derived rows) -- were pinned by NO
run-gate tool, while a comment in `zk60_native_rg_terminals` said they were
checked somewhere they are not.  The rung-K4 bundles' `run.rs` moved from
`65d55d25` to `73f68221` and nothing noticed.  Everything the gate says
about the run layer rested on the replay reproducing every challenge, which
is strong evidence and is not a pin: a change to the WRITER that altered
what is recorded without moving a challenge would be invisible.

FOUR ARMS.

* A PURE arm that needs nothing on disk: the pin table against the
  established dependency list in BOTH directions, one written reading per
  (file, digest) pair, the affected-stage table, and the round-5 figures
  this round corrects.
* A BUNDLE arm, skipped when the ~46 MB captures are absent: every one of
  the ten in-scope bundles' declared run-layer digests accepted, and the
  table's own (commit, bundle) cross-reference agreeing with what the
  manifests say.
* A REFUSAL arm: a changed byte in each newly pinned file refused BY NAME,
  and -- the point of the round, because round 5's finding K4-F1 was a
  refusal path that crashed -- the WHOLE GATE run on a bundle whose digest
  this table has not read, for a run-layer file and for an argument-layer
  file, leaving the affected stages NOT CHECKED without an exception.
* A LANE arm, skipped when the read-only Rust worktree is absent: each
  pinned digest recomputed from the committed blob, so the table is a
  statement about real bytes and not about itself.

Nothing here asserts a privacy property.
"""

from __future__ import annotations

import copy
import hashlib
import os
import subprocess
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))

BUNDLES = os.environ.get(
    "ZK60_RUN_BUNDLES",
    "/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920",
)
LANE = os.environ.get("ZK60_RUST_LANE", "/home/victor/wt-zk60-block125m")
IN_SCOPE = (
    "run-a-tame", "run-b-zero", "run-c-tame", "run-d-zero",
    "run-e-tame-tagged", "run-f-zero-tagged",
    "run-g-dense-s20", "run-h-zero-s20",
    "run-i-dense-k4", "run-j-zero-k4",
    # [ROUND 9b] the two rung-P2 bundles, lane stage 30 at `4ccbad1`
    "run-k-dense-p2", "run-l-zero-p2",
    # [ROUND 9c] lane stages 31 and 33.  The rung-W14 pair is NOT here:
    # like the 125M bundles it is 50 MB and lives outside the lane's
    # results directory, so it is in W14_IN_SCOPE below.
    "run-m-dense-c6", "run-n-zero-c6",
    "run-q-dense-e32", "run-r-zero-e32",
)
# [ROUND 9] the two 125M bundles are the first in scope that live OUTSIDE
# the Rust lane's results directory: they are 281 MB and 273 MB and are kept
# in `zk60-artifacts/`, never copied into a repository.  They are in scope
# for the pin tables all the same, so the cross-reference below has to reach
# them; when they are absent the table's claim about them is not checked and
# the test says which names it skipped rather than silently narrowing.
M125_DIR = os.environ.get("ZK60_M125_BUNDLES", "/home/victor/zk60-artifacts")
M125_IN_SCOPE = ("m125-capture-dense-l2", "m125-capture-zero-l2")
# [ROUND 9c] the rung-W14 pair, 50.6 MB and 49.5 MB, kept beside the 125M
# captures for the same reason and in scope for the pin tables the same way.
W14_IN_SCOPE = ("run-o-dense-w14", "run-p-zero-w14")
# [ROUND 9c] FINDING E32-F1: these two declare `source_commit: 4505ddf`,
# one commit BEFORE `Shape::rung_e32` exists, so their `run.rs` digest is
# not the blob at the commit they name.  The digests are honest -- all 38
# match at `6d71b40` and after -- and the label is what is stale.
E32_F1 = ("run-q-dense-e32", "run-r-zero-e32")
# [ROUND 9i] the rung-K8 pair (lane stage 37, `99a8de8`), the first bundles
# at THREE key-value group bits.  They live in their own dated directory of
# the lane's results, not in `zk60_run_captures_20260920`, so they are
# routed like the 125M and rung-W14 pairs: in scope for the tables, and
# named as skipped when absent rather than silently narrowing.
K8_DIR = os.environ.get(
    "ZK60_K8_BUNDLES",
    "/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260922_k8")
K8_IN_SCOPE = ("run-s-dense-k8", "run-t-zero-k8")
HAVE_K8 = all(os.path.isdir(os.path.join(K8_DIR, b)) for b in K8_IN_SCOPE)
HAVE_M125 = all(os.path.isdir(os.path.join(M125_DIR, b))
                for b in M125_IN_SCOPE)
HAVE_W14 = all(os.path.isdir(os.path.join(M125_DIR, b)) for b in W14_IN_SCOPE)
HAVE_BUNDLES = all(os.path.isdir(os.path.join(BUNDLES, b)) for b in IN_SCOPE)
HAVE_LANE = os.path.isdir(os.path.join(LANE, ".git")) or os.path.exists(
    os.path.join(LANE, ".git"))

import zk60_native_run_gate as gate  # noqa: E402
from zk60_native_rg_bundle import RunBundle  # noqa: E402
from zk60_native_rg_runpins import (  # noqa: E402
    AFFECTED_STAGES,
    ALL_STAGES,
    DEPENDS,
    NOT_PINNABLE_FROM_A_BUNDLE,
    PINNED_ELSEWHERE,
    READINGS,
    RUN_LAYER_PINS,
    check_run_layer_pins,
    not_checked,
)
from zk60_native_rg_terminals import (  # noqa: E402
    WAS_NOT_PINNED_BY_ANY_RUN_GATE_TOOL_UNTIL_20260921 as WAS_UNPINNED,
)

NEWLY_PINNED = (
    "src/private_block/run_capture.rs",
    "src/private_block/run.rs",
    "src/private_block/boundary.rs",
)


def _bundle(name):
    root = (M125_DIR if name in M125_IN_SCOPE or name in W14_IN_SCOPE
            else K8_DIR if name in K8_IN_SCOPE
            else BUNDLES)
    return RunBundle(os.path.join(root, name))


def _with_digest(bundle, path, digest):
    """A copy of the bundle's manifest with one source pin rewritten.  No
    captured file on disk is ever written."""
    man = copy.deepcopy(bundle.manifest)
    for p in man["source_pins"]:
        if p["file"] == path:
            p["sha256"] = digest
    return man


# =====================================================================
#  the PURE arm -- the table against the established list
# =====================================================================
class ThePinTableCoversExactlyTheEstablishedList(unittest.TestCase):
    """A pin for a file no port depends on is padding; a file a port depends
    on with no pin is the gap this round exists to close.  Both directions
    are asserted."""

    def test_every_file_a_port_depends_on_is_pinned_somewhere(self):
        pinned = set(RUN_LAYER_PINS) | set(PINNED_ELSEWHERE)
        self.assertEqual(
            set(DEPENDS), pinned,
            "a run-layer file a run-gate port depends on is pinned by "
            "nothing, or a pin exists for a file no port depends on")

    def test_the_three_newly_pinned_files_are_the_ones_k4_f2_named(self):
        self.assertEqual(set(RUN_LAYER_PINS), set(NEWLY_PINNED))
        self.assertEqual(set(WAS_UNPINNED), set(NEWLY_PINNED))

    def test_plane_index_is_pinned_elsewhere_and_not_twice(self):
        """Two tools pinning one file at two digests is how a pin quietly
        stops meaning anything."""
        self.assertIn("src/private_block/plane_index.rs", PINNED_ELSEWHERE)
        self.assertNotIn("src/private_block/plane_index.rs", RUN_LAYER_PINS)
        from zk60_native_rg_terminals import PORTED_FROM
        self.assertIn("src/private_block/plane_index.rs", PORTED_FROM)

    def test_every_dependency_names_a_port_and_a_reference(self):
        for path, entries in DEPENDS.items():
            self.assertTrue(entries, path)
            for module, what, ref in entries:
                self.assertTrue(module.startswith("zk60_native_"), module)
                self.assertGreater(len(what), 60, (path, module))
                self.assertTrue(ref.strip(), (path, module))

    def test_every_pinned_digest_has_a_written_reading(self):
        """A pin added without a reading is what this discipline forbids."""
        pairs = {(p, d) for p, t in RUN_LAYER_PINS.items() for d in t}
        self.assertEqual(pairs, set(READINGS))
        # [ROUND 9, DELIBERATE] nine (file, digest) pairs became twelve:
        # `run_capture.rs`, `run.rs` and `boundary.rs` each gained the
        # digest the 125M bundles pin at `f4697f9`, and each gained a
        # written reading with it -- which is what this test is for.
        # [ROUND 9b, DELIBERATE] twelve became THIRTEEN: at `4ccbad1`
        # only `run.rs` moved (stage 30 added `RUN_PROFILE_RUNG_P2` and
        # `RunShape::rung_p2`, seven added lines and nothing removed), so
        # the rung-P2 bundles add ONE pair and one reading.
        # `run_capture.rs` and `boundary.rs` are byte-identical there and
        # their existing entries gained the commit and the two bundles.
        # [ROUND 9c, DELIBERATE] thirteen became SIXTEEN: stages 31, 32
        # and 33 each added one run profile constant and one `RunShape`
        # constructor to `run.rs` and nothing else, so `run.rs` gains
        # THREE digests and three readings, and `run_capture.rs` and
        # `boundary.rs` are byte-identical at all three commits.
        self.assertEqual(len(pairs), 16)
        for (path, digest), text in READINGS.items():
            self.assertGreater(len(text), 200, (path, digest))
            self.assertEqual(len(digest), 64)

    def test_the_not_pinnable_files_are_named_and_disjoint(self):
        self.assertEqual(
            set(NOT_PINNABLE_FROM_A_BUNDLE),
            {"src/private_block/wire.rs", "src/private_block/run_sink.rs",
             "src/private_block/endpoint_g.rs",
             "src/private_block/hash_domain.rs"})
        self.assertFalse(set(NOT_PINNABLE_FROM_A_BUNDLE) & set(DEPENDS))
        for path, why in NOT_PINNABLE_FROM_A_BUNDLE.items():
            self.assertIn("(a)", why, path)
            self.assertIn("(b)", why, path)
            self.assertIn("writer does not pin it", why)

    def test_the_affected_stage_table_is_complete_and_names_real_stages(self):
        self.assertEqual(set(AFFECTED_STAGES), set(RUN_LAYER_PINS))
        for path, (stages, why) in AFFECTED_STAGES.items():
            self.assertTrue(stages, path)
            for s in stages:
                self.assertIn(s, ALL_STAGES, (path, s))
            self.assertIn("stage7_channels", stages,
                          "the channel table summarises the others, so it "
                          "must be suspended whenever any of them is")
            self.assertGreater(len(why), 80, path)

    def test_the_writer_and_the_run_suspend_everything(self):
        for path in ("src/private_block/run_capture.rs",
                     "src/private_block/run.rs"):
            self.assertEqual(set(AFFECTED_STAGES[path][0]), set(ALL_STAGES))

    def test_the_boundary_suspends_a_named_subset_not_everything(self):
        stages = set(AFFECTED_STAGES["src/private_block/boundary.rs"][0])
        self.assertEqual(stages, {
            "stage1_integrity", "stage3_per_commitment",
            "stage4_the_boundary", "stage5_zero_data_preimage",
            "stage6_negative_controls", "stage7_channels"})
        for kept in ("stage2_transcript_replay",
                     "stage8_plane_index_and_terminals",
                     "stage9_hash_layer", "stage10_bilinear_group_factor"):
            self.assertNotIn(kept, stages)

    def test_the_not_checked_record_says_the_absence_is_not_a_figure(self):
        r = not_checked("stage4_the_boundary", ["a reason"])
        self.assertFalse(r["ok"])
        self.assertFalse(r["checked"])
        self.assertIn("absence of a figure is not a figure",
                      r["what_the_absence_means"])
        self.assertIn("NOTHING HERE SAYS THE BUNDLE IS BAD",
                      r["what_the_absence_means"])


class TheRoundFiveFiguresThisRoundCorrects(unittest.TestCase):
    """A ledger is not rewritten and a wrong figure is not left standing."""

    def test_the_run_rs_line_count_is_corrected_to_nine(self):
        text = READINGS[("src/private_block/run.rs",
                         "73f6822192fa9aa83753cc20cbf867ede4fdfb75170bb58d24"
                         "60f2f6fb79a71c")]
        self.assertIn("9 added, 0 removed", text)
        self.assertIn("round 5's report and ledger said 12", text)
        self.assertIn("9** added", WAS_UNPINNED["src/private_block/run.rs"])

    def test_boundary_rs_is_not_byte_identical_at_every_capture_commit(self):
        # [ROUND 9, DELIBERATE] two digests became THREE: stage 26 added
        # `BoundarySpec::index()` and a doc comment (production +22/-0, not
        # one geometry accessor), which round 5's "byte-identical at every
        # capture commit so far" would have been wrong about a third time.
        self.assertEqual(len(RUN_LAYER_PINS["src/private_block/boundary.rs"]),
                         3)
        why = WAS_UNPINNED["src/private_block/boundary.rs"]
        self.assertIn("that is WRONG", why)
        self.assertIn("9860c35d", why)


# =====================================================================
#  the BUNDLE arm
# =====================================================================
@unittest.skipUnless(HAVE_BUNDLES, "the run capture bundles are not on this box")
class EveryInScopeBundlePasses(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        names = (list(IN_SCOPE) + (list(M125_IN_SCOPE) if HAVE_M125 else [])
                 + (list(W14_IN_SCOPE) if HAVE_W14 else [])
                 + (list(K8_IN_SCOPE) if HAVE_K8 else []))
        cls.names = tuple(names)
        cls.bundles = {n: _bundle(n) for n in names}

    def test_all_ten_bundles_run_layer_pins_are_read_digests(self):
        for name, b in self.bundles.items():
            r = check_run_layer_pins(b)
            self.assertTrue(r["ok"], (name, r["pins_that_moved"],
                                      r["pins_missing_from_the_bundle"]))
            self.assertEqual(len(r["pins_at_a_read_digest"]), 3, name)
            self.assertEqual(r["stages_not_checked"], {}, name)

    def test_the_tables_bundle_cross_reference_is_the_manifests(self):
        """The table says which bundles were written at each digest.  That
        claim is checked against the bundles themselves, in both
        directions."""
        for path, table in RUN_LAYER_PINS.items():
            for digest, entry in table.items():
                for name in entry["bundles"]:
                    if name not in self.bundles:
                        continue      # absent on this box: skipped below
                    pins = {p["file"]: p["sha256"]
                            for p in self.bundles[name].manifest["source_pins"]}
                    self.assertEqual(pins[path], digest, (path, name))
            claimed = {n for e in table.values() for n in e["bundles"]}
            # [ROUND 9] the tables now claim the two 125M bundles as well.
            # A box without them checks the ten it has and says so, rather
            # than asserting a narrower set and calling that a pass.
            # [ROUND 9i] and the rung-K8 pair, routed the same way.
            self.assertEqual(
                claimed,
                set(IN_SCOPE) | set(M125_IN_SCOPE) | set(W14_IN_SCOPE)
                | set(K8_IN_SCOPE), path)
        if not (HAVE_M125 and HAVE_W14 and HAVE_K8):
            self.skipTest("the 125M, rung-W14 and/or rung-K8 bundles are not "
                          "on this box, so the table's claim about them is "
                          "unchecked")

    def test_the_source_commit_a_bundle_declares_is_one_the_table_lists(self):
        """A bundle names its own lane commit in `run.json`; the digest it
        pins must be one the table read AT THAT COMMIT, so the two
        independent statements agree.

        **FINDING E32-F1 (round 9c) is the one recorded exception, and it
        is asserted rather than excused.**  `run-q-dense-e32` and
        `run-r-zero-e32` declare `source_commit: 4505ddf`, which is the
        commit BEFORE `6d71b40` -- the one that adds `Shape::rung_e32`.
        Their `run.rs` digest is therefore NOT the blob at the commit they
        name, and the test below asserts exactly that: the agreement fails
        for that one file, the digest they pin IS the blob at the commits
        the table lists instead, and the other two run-layer files agree
        at `4505ddf` because they did not move there."""
        for name, b in self.bundles.items():
            commit = b.run["source_commit"]
            pins = {p["file"]: p["sha256"] for p in b.manifest["source_pins"]}
            for path in NEWLY_PINNED:
                entry = RUN_LAYER_PINS[path][pins[path]]
                agrees = any(c.startswith(commit[:7])
                             for c in entry["commits"])
                if name in E32_F1 and path == "src/private_block/run.rs":
                    self.assertFalse(
                        agrees,
                        "finding E32-F1 has been fixed upstream -- the "
                        "exception below should be removed with it")
                    self.assertEqual(commit[:7], "4505ddf", name)
                    self.assertTrue(
                        all(not c.startswith("4505ddf")
                            for c in entry["commits"]), name)
                    continue
                self.assertTrue(agrees,
                                (name, path, commit, entry["commits"]))

    def test_finding_E32_F1_is_the_only_bundle_whose_commit_disagrees(self):
        """The exception above must stay ONE exception: no other bundle,
        and no other file of the rung-E32 pair, may drift from the commit
        it names."""
        disagreeing = set()
        for name, b in self.bundles.items():
            commit = b.run["source_commit"]
            pins = {p["file"]: p["sha256"] for p in b.manifest["source_pins"]}
            for path in NEWLY_PINNED:
                entry = RUN_LAYER_PINS[path][pins[path]]
                if not any(c.startswith(commit[:7])
                           for c in entry["commits"]):
                    disagreeing.add((name, path))
        self.assertEqual(
            disagreeing,
            {(n, "src/private_block/run.rs") for n in E32_F1},
            "finding E32-F1 is the only recorded disagreement between a "
            "bundle's declared commit and the commits its pinned digests "
            "were read at")


# =====================================================================
#  the REFUSAL arm
# =====================================================================
@unittest.skipUnless(HAVE_BUNDLES, "the run capture bundles are not on this box")
class AChangedByteIsRefusedByName(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.b = _bundle("run-i-dense-k4")
        cls.keep = cls.b.manifest

    def tearDown(self):
        self.b.manifest = self.keep

    def test_each_newly_pinned_file_is_refused_by_its_own_name(self):
        for path in NEWLY_PINNED:
            with self.subTest(path=path):
                # restore first: `subTest` does not run `tearDown`, and a
                # cumulative perturbation would refuse for the wrong reason
                self.b.manifest = self.keep
                self.b.manifest = _with_digest(self.b, path, "00" * 32)
                r = check_run_layer_pins(self.b)
                self.assertFalse(r["ok"])
                self.assertEqual(len(r["pins_that_moved"]), 1)
                self.assertTrue(r["pins_that_moved"][0].startswith(path))
                self.assertIn("not one of the", r["pins_that_moved"][0])
                self.assertEqual(
                    set(r["stages_not_checked"]),
                    set(AFFECTED_STAGES[path][0]))

    def test_the_control_nothing_flipped_passes(self):
        """So the refusals above are the perturbation's, not the copying's."""
        self.b.manifest = copy.deepcopy(self.keep)
        self.assertTrue(check_run_layer_pins(self.b)["ok"])

    def test_a_file_dropped_from_the_manifest_is_refused_too(self):
        man = copy.deepcopy(self.keep)
        man["source_pins"] = [p for p in man["source_pins"]
                              if not p["file"].endswith("run.rs")]
        self.b.manifest = man
        r = check_run_layer_pins(self.b)
        self.assertFalse(r["ok"])
        self.assertEqual(len(r["pins_missing_from_the_bundle"]), 1)
        self.assertIn("run.rs", r["pins_missing_from_the_bundle"][0])

    def test_a_digest_of_a_neighbouring_commit_is_still_accepted(self):
        """The table is a set of READ digests, not one value: a bundle from
        an earlier capture commit must keep passing."""
        for path, digest in (
            ("src/private_block/run.rs",
             "02f7ee7e922d83f66d77aa64540ee141305b3fe7a6c1127aca55739884cde6bb"),
            ("src/private_block/boundary.rs",
             "9860c35d4db93afa52ba4287ac949209dc3d93957da51a6aeee91b0951a215e6"),
        ):
            self.b.manifest = _with_digest(self.b, path, digest)
            self.assertTrue(check_run_layer_pins(self.b)["ok"], path)


@unittest.skipUnless(HAVE_BUNDLES, "the run capture bundles are not on this box")
class AnUnknownDigestLeavesStagesNotCheckedWithoutCrashing(unittest.TestCase):
    """Round 5's finding K4-F1 was a refusal path that CRASHED, because no
    bundle had ever moved a pin.  This round adds a second refusal path, so
    both are exercised end to end here, through the whole gate."""

    BUNDLE = os.path.join(BUNDLES, "run-i-dense-k4")

    def _gate_with(self, path, digest):
        orig = RunBundle.__init__

        def patched(self, directory):
            orig(self, directory)
            for p in self.manifest["source_pins"]:
                if p["file"] == path:
                    p["sha256"] = digest
        RunBundle.__init__ = patched
        try:
            return gate.run_gate(self.BUNDLE)
        finally:
            RunBundle.__init__ = orig

    def test_a_run_layer_digest_suspends_every_stage_by_name(self):
        rec = self._gate_with("src/private_block/run.rs", "00" * 32)
        self.assertFalse(rec["ok"])
        rlp = rec["run_layer_source_pins"]
        self.assertFalse(rlp["ok"])
        self.assertTrue(rlp["pins_that_moved"][0].startswith(
            "src/private_block/run.rs"))
        for stage in ALL_STAGES:
            self.assertIn(stage, rec, stage)
            self.assertFalse(rec[stage]["ok"], stage)
            self.assertFalse(rec[stage]["checked"], stage)
            self.assertTrue(rec[stage]["not_checked_because"], stage)
        self.assertIn("NOTHING WAS COMPUTED ABOUT THIS BUNDLE",
                      rec["what_it_does_not_show"][0])
        self.assertFalse(rec["privacy_property_established"])

    def test_the_boundary_suspends_six_stages_and_the_other_four_still_run(self):
        rec = self._gate_with("src/private_block/boundary.rs", "00" * 32)
        self.assertFalse(rec["ok"])
        suspended = set(rec["run_layer_source_pins"]["stages_not_checked"])
        self.assertEqual(len(suspended), 6)
        for stage in suspended:
            self.assertFalse(rec[stage].get("checked", True), stage)
        # the four that do not depend on boundary.rs really ran
        self.assertTrue(rec["stage2_transcript_replay"]["ok"])
        self.assertTrue(
            rec["stage8_plane_index_and_terminals"]["terminal_identity"]["ok"])
        self.assertTrue(rec["stage9_hash_layer"]["ok"])

    def test_an_argument_layer_digest_still_refuses_without_crashing(self):
        """The other refusal path, the one K4-F1 repaired: `shape.rs` is an
        ARGUMENT-layer pin, checked by `zk60_native_rg_terminals`.  The gate
        must survive it, the run-layer pins must stay OK, and stage 8 must
        report zeros that say they are zeros."""
        rec = self._gate_with("src/private_block/shape.rs", "11" * 32)
        self.assertFalse(rec["ok"])
        self.assertTrue(rec["run_layer_source_pins"]["ok"])
        ti = rec["stage8_plane_index_and_terminals"]["terminal_identity"]
        self.assertFalse(ti["ok"])
        self.assertEqual(ti["slot_checks_attempted"], 0)
        self.assertIn("absence of a check",
                      ti["refused_before_any_slot_was_evaluated"])
        # and the gate still produced a whole record
        self.assertIn("stage7_channels", rec)
        self.assertIn("seconds", rec)


# =====================================================================
#  the LANE arm -- the table against the committed Rust blobs
# =====================================================================
@unittest.skipUnless(HAVE_LANE, "the read-only Rust lane worktree is absent")
class TheDigestsAreTheCommittedBlobs(unittest.TestCase):
    """The table is a statement about real bytes at real commits, so it is
    checked against them.  The lane worktree is READ ONLY here."""

    def _show(self, commit, path):
        r = subprocess.run(
            ["git", "--no-pager", "-C", LANE, "show", f"{commit}:hashline/{path}"],
            capture_output=True)
        return r.stdout if r.returncode == 0 else None

    def test_every_pinned_digest_is_the_blob_at_every_commit_it_names(self):
        checked = 0
        for path, table in RUN_LAYER_PINS.items():
            for digest, entry in table.items():
                for commit in entry["commits"]:
                    raw = self._show(commit, path)
                    if raw is None:
                        self.skipTest(f"{commit} is not in this worktree")
                    self.assertEqual(hashlib.sha256(raw).hexdigest(), digest,
                                     (path, commit))
                    self.assertEqual(len(raw), entry["bytes"], (path, commit))
                    checked += 1
        # [ROUND 9, DELIBERATE] five capture commits became SIX: the 125M
        # bundles are written at `f4697f9`, and all three run-layer files
        # moved there.  Three files at six commits each is 18.
        # [ROUND 9b, DELIBERATE] and SEVEN: `4ccbad1` is the rung-P2
        # capture commit, where `run.rs` moved and the other two are
        # byte-identical -- so all three are checked at it, 21 in all, and
        # the two that did not move are checked at the new commit against
        # the digest they already had, which is the statement that they
        # did not move.
        # [ROUND 9c, DELIBERATE] 21 became 27.  `run.rs` gains three
        # digests and, between them, SIX commits: `3e106e1` (rung-C6),
        # `11703c9` and `4505ddf` (rung-W14's blob, which `4505ddf` also
        # carries), and `6d71b40`, `2d04d94` and `226f3b2` (rung-E32's).
        # `run_capture.rs` and `boundary.rs` gain no commit, because the
        # three new bundles pin the digests those two already have.
        # `run_capture.rs` and `boundary.rs` gain three commits each --
        # `3e106e1`, `11703c9` and `4505ddf` -- on the digest they
        # already had, which IS the statement that they did not move
        # there.  21 + 6 + 3 + 3 = 33.
        # [ROUND 9i, DELIBERATE] 33 became 36: the rung-K8 capture commit
        # `99a8de8` is appended to all three files' existing digests --
        # none of the three moved there (rung-K8 is built in a TEST file) --
        # so each is checked once more, at the new commit, against the
        # digest it already had.
        self.assertEqual(checked, 36,
                         "three files at SEVEN capture commits each, plus "
                         "run.rs at the six commits round 9c's three new "
                         "shapes are written at, plus the two unmoved "
                         "files at three of them, plus all three at the "
                         "rung-K8 capture commit")

    def test_one_flipped_byte_in_each_file_is_not_a_read_digest(self):
        """The refusal above is asserted on a made-up digest; this is the
        same refusal on a digest of REAL bytes with one byte changed."""
        for path, table in RUN_LAYER_PINS.items():
            digest, entry = sorted(table.items())[0]
            raw = self._show(entry["commits"][0], path)
            if raw is None:
                self.skipTest("the capture commits are not in this worktree")
            flipped = bytearray(raw)
            flipped[len(flipped) // 2] ^= 0x01
            self.assertNotIn(hashlib.sha256(bytes(flipped)).hexdigest(), table,
                             path)

    def test_the_four_unpinnable_files_are_really_not_in_source_files(self):
        """`NOT_PINNABLE_FROM_A_BUNDLE` claims the WRITER does not pin them.
        That is a fact about `run_capture.rs::SOURCE_FILES`, so it is read
        from the Rust rather than asserted."""
        raw = self._show("3247a89", "src/private_block/run_capture.rs")
        if raw is None:
            self.skipTest("the rung-K4 capture commit is not in this worktree")
        text = raw.decode()
        start = text.index("SOURCE_FILES")
        block = text[start:text.index("];", start)]
        for path in NOT_PINNABLE_FROM_A_BUNDLE:
            self.assertNotIn(path, block, path)
        for path in NEWLY_PINNED:
            self.assertIn(path, block, path)
        self.assertIn("src/private_block/plane_index.rs", block)


if __name__ == "__main__":
    unittest.main()
